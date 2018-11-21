#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

function generate_o5m() {
	local poly_file="$1"
	local poly_name=$(echo $poly_file |awk 'BEGIN{FS="."}{print $1}')
	local source="view1,view3,srtm3"	
	[ -n "$SOURCE" ] && local source="$SOURCE"

	export PYTHONUNBUFFERED=1
	
	phyghtmap --version
	phyghtmap --max-nodes-per-tile=0 \
			-s 10 \
			-0 \
			--o5m \
			--polygon="$poly_file" \
			--output-prefix="$poly_name" \
			--hgtdir="$IMPORT_DIR/hgt/" \
			--source="$source" \
			--earthexplorer-user="$USER" \
			--earthexplorer-password="$PASSWORD"
		
	[ -n "$UID" ] && [ -n "$GID" ] && chown -R $UID:$GID $IMPORT_DIR/*
	echo "Copying height map files..."
	cp -avf $IMPORT_DIR/hgt/* $IMPORT_DIR/completed_hgt/
}

function generate_osm_with_poly() {
	if [ -z "$USER" ]; then
		echo "no USER found, please add one in env file .config"
		echo "USER=xxxx"
		echo "If you do not yet have an earthexplorer login, visit https://ers.cr.usgs.gov/register/ and create one"
		exit 404
	fi

	if [ -z "$PASSWORD" ]; then
		echo "no PASSWORD found, please add one in env file .config"
		echo "PASSWORD=xxxx"
		echo "If you do not yet have an earthexplorer login, visit https://ers.cr.usgs.gov/register/ and create one"
		exit 404
	fi

	echo "Ready..."
	[ ! -d $IMPORT_DIR/hgt ] && mkdir $IMPORT_DIR/hgt
	[ ! -d $IMPORT_DIR/completed_hgt ] && mkdir $IMPORT_DIR/completed_hgt
	[ -n "$UID" ] && [ -n "$GID" ] && chown -R $UID:$GID $IMPORT_DIR/*
	

	if [ "$(ls -A $IMPORT_DIR/*.poly 2> /dev/null)" ]; then
			echo "Processing poly files..."
			local poly_file
			for poly_file in "$IMPORT_DIR"/*.poly; do
				generate_o5m "$poly_file"
			done
	else
			echo "No poly file for import found."
			echo "Please mount the $IMPORT_DIR volume to a folder containing poly files."
			exit 404
	fi
}

generate_osm_with_poly
