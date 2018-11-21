# osm-contours
Create Postgresql contour data with help from a docker image and make hillshade geotiffs.


Firstly copy .config-example to .config and edit as appropriate. Put the email and password you use to login
to USGS EROS to get the SRTM3 elevation data, if srtm3 is one of your SOURCEs.
The UID and GID should be the numeric id of the current user you are logged in as. (Use id -u  and id -g to
find these).


Now change into the generate-osm-contours-docker directory and run ./build.sh to build the docker image.
The docker system daemon must be running, your local user account must belong to the docker group and you must
login to the docker hub using the command 'docker login'.
This will build the docker image that does the contour generation work.

You need to make sure your postgresql database has a database called 'contours'.

As the postgres user:
~~~~
createdb -E UTF8 -O ${local_account} contours
psql -c "CREATE EXTENSION postgis;" -d contours
~~~~
replace ${local_account} with the local user account you are using.


Once this is done, you can change back to the top level directory, grab some .poly files from 
http://download.geofabrik.de/europe.html and place them in the poly/ directory.

Now run ./build_contours_from_poly.sh
