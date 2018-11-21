#!/bin/bash
# build all of the contours and heightmaps
# uses a docker image to build the contours
# 2018-11-10 simon@ateb.co.uk


exec > >(awk '{print strftime("%Y-%m-%d %H:%M:%S [1] "),$0; fflush();}')
exec 2> >(awk '{print strftime("%Y-%m-%d %H:%M:%S [2] "),$0; fflush();}' >&2)

starttime=$(date +%s)

COMBINED_PBF_FILE=combined_elevation_data.osm.pbf
COMBINED_HEIGHTMAP=heightmap.tif
OPEN_TOPO_MAP_DIR=~/OpenTopoMap

if [ -n "$(find ./poly -maxdepth 1 -name '*.poly' -print -quit)" ]; then

	docker run --rm --env-file=.config --mount type=bind,source=poly,target=/import generate-osm-contours

	if [ $? = 0 ]; then
		mv -f poly/*.poly completed_poly/
		mv -f poly/*.o5m .
		mv -f poly/completed_hgt/* hgt/
		rm -Rf poly/hgt/*
		rm -f ${COMBINED_PBF_FILE}
	fi
fi

if [ ! -f ${COMBINED_PBF_FILE} ]; then
	if [ -n "$(find . -maxdepth 1 -name '*.o5m' -print -quit)" ]; then
		echo "Combining the datasets..."
		osmconvert -v *.o5m --out-pbf -o=${COMBINED_PBF_FILE}
		echo "Erasing and writing data to the 'contours' db in Postgres..."
		osm2pgsql -c --slim -d contours -C 8000 --number-processes 8 --style ${OPEN_TOPO_MAP_DIR}/mapnik/osm2pgsql/contours.style ${COMBINED_PBF_FILE}
		
	fi
fi

if [ ! -f ${COMBINED_HEIGHTMAP} ]; then
	echo "Filling voids in height data..."
	for hgtfile in hgt/SRTM3v3.0/*.hgt;do gdal_fillnodata.py $hgtfile $hgtfile.tif; done
	for hgtfile in hgt/VIEW3/*.hgt;do gdal_fillnodata.py $hgtfile $hgtfile.tif; done

	echo "Merging SRTM data to WGS84 (EPSG:4326) GeoTiff heightmap..."
	gdal_merge.py -v -n 32767 -co BIGTIFF=YES -co TILED=YES -co COMPRESS=LZW -co PREDICTOR=2 -o ${COMBINED_HEIGHTMAP} hgt/SRTM3v3.0/*.hgt.tif hgt/VIEW3/*.hgt.tif
	
	rm -f warp-*.tif 2>/dev/null
	rm -f warped.tif 2>/dev/null

	export COMBINED_HEIGHTMAP
	export OPEN_TOPO_MAP_DIR

	tmux new-session -d -s Contours -n "Generating Colour Relief and Hillshade" -x 132 -y 25 \
	 'echo "(1)..." && \
		gdalwarp -co BIGTIFF=YES -co TILED=YES -co COMPRESS=LZW -co PREDICTOR=2 -t_srs "+proj=merc +ellps=sphere +R=6378137 +a=6378137 +units=m" -r bilinear -tr 30 30 ${COMBINED_HEIGHTMAP} warp-30.tif'

	tmux split-window -d -t Contours \
	 'echo "(4)..." && \
		gdalwarp -co BIGTIFF=YES -co TILED=YES -co COMPRESS=LZW -co PREDICTOR=2 -t_srs "+proj=merc +ellps=sphere +R=6378137 +a=6378137 +units=m" -r bilinear -tr 5000 5000 ${COMBINED_HEIGHTMAP} warp-5000.tif && \
		gdalwarp -co BIGTIFF=YES -co TILED=YES -co COMPRESS=LZW -co PREDICTOR=2 -t_srs "+proj=merc +ellps=sphere +R=6378137 +a=6378137 +units=m" -r bilinear -tr 700 700 ${COMBINED_HEIGHTMAP} warp-700.tif && \
		gdaldem color-relief -co COMPRESS=LZW -co PREDICTOR=2 -alpha warp-5000.tif relief_color_text_file.txt relief-5000.tif && \
		gdaldem hillshade -z 7 -compute_edges -co COMPRESS=JPEG warp-5000.tif hillshade-5000.tif && \
		gdaldem hillshade -z 4 -compute_edges -co BIGTIFF=YES -co TILED=YES -co COMPRESS=JPEG warp-700.tif hillshade-700.tif'

	tmux split-window -d -t Contours \
	 'echo "(3)..." && \
		gdalwarp -co BIGTIFF=YES -co TILED=YES -co COMPRESS=LZW -co PREDICTOR=2 -t_srs "+proj=merc +ellps=sphere +R=6378137 +a=6378137 +units=m" -r bilinear -tr 500 500 ${COMBINED_HEIGHTMAP} warp-500.tif && \
		gdalwarp -co BIGTIFF=YES -co TILED=YES -co COMPRESS=LZW -co PREDICTOR=2 -t_srs "+proj=merc +ellps=sphere +R=6378137 +a=6378137 +units=m" -r bilinear -tr 1000 1000 ${COMBINED_HEIGHTMAP} warp-1000.tif && \
		gdaldem color-relief -co COMPRESS=LZW -co PREDICTOR=2 -alpha warp-500.tif relief_color_text_file.txt relief-500.tif && \
		gdaldem hillshade -z 7 -compute_edges -co BIGTIFF=YES -co TILED=YES -co COMPRESS=JPEG warp-1000.tif hillshade-1000.tif && \
		gdaldem hillshade -z 5 -compute_edges -co BIGTIFF=YES -co TILED=YES -co COMPRESS=JPEG warp-500.tif hillshade-500.tif'

	tmux split-window -d -t Contours \
	 'echo "(2)..." && \
	 gdalwarp -co BIGTIFF=YES -co TILED=YES -co COMPRESS=LZW -co PREDICTOR=2 -t_srs "+proj=merc +ellps=sphere +R=6378137 +a=6378137 +units=m" -r bilinear -tr 90 90 ${COMBINED_HEIGHTMAP} warp-90.tif && \
	 gdaldem hillshade -z 2 -co compress=lzw -co predictor=2 -co bigtiff=yes -compute_edges warp-90.tif hillshade-90.tif && \
	 gdal_translate -co compress=JPEG -co bigtiff=yes -co TILED=yes hillshade-90.tif hillshade-90-jpeg.tif && \
	 gdaldem hillshade -z 3 -compute_edges -co BIGTIFF=YES -co TILED=YES -co COMPRESS=JPEG warp-90.tif hillshade-30m-jpeg.tif'

	tmux select-layout -t Contours even-vertical
	tmux attach-session -t Contours
fi

endtime=$(date +%s)
echo "Done in $[${endtime}-${starttime}] seconds! All your Maps Belong to Us!"
exit 0
