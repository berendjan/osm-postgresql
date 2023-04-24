# osm-postgresql

osm-postgresql is a debian docker image that spins up a PostgreSQL database with PostGIS enabled
and imports a `osm.pbf` file.

## Quickstart

Using docker to serve osm data

```bash
# clone repo
git clone git@github.com:berendjan/osm-postgresql.git
cd osm-postgresql

# build container
docker build -t osm-pg -f Dockerfile .

# create volume 
docker volume create osm

# quickstart container
docker run --name osm-pg -v osm:/data -p 5432:5432 osm-pg import

### 
### Postgresql service ready at:
### postgresql://osmuser:osmpassword@172.17.0.2:5432/osmdb
```

start example server [pg_tileserv](https://github.com/CrunchyData/pg_tileserv).

```bash
# start server example pg_tileserv
docker run -e DATABASE_URL=postgresql://osmuser:osmpassword@172.17.0.2:5432/osmdb -p 7800:7800 pramsey/pg_tileserv:latest

curl http://localhost:7800/index.json
### {"public.boundaries": ...
```

stop and restart container

```bash
# to stop
docker stop osm-pg

# to start without importing
docker run --name osm-pg -v osm:/data -p 5432:5432 osm-pg run

### 
### Postgresql service ready at:
### postgresql://osmuser:osmpassword@172.17.0.2:5432/osmdb
```

## Configuration

At startup the container will check if the file `/data/region.osm.pbf` exists, else it will download from environment variable `DOWNLOAD_OSM_PBF`.

List of environment variables used with default value:
```bash
# postgresql user
PG_DBUSER               # 'osmuser'

# postgresql database
PG_DBNAME               # 'osmdb'

# postgresql password
PG_PASSWORD             # 'osmpassword'

# osm region download link
DOWNLOAD_OSM_PBF        # 'https://download.geofabrik.de/europe/luxembourg-latest.osm.pbf'

# lua script for osm2pgsql
STYLE_LUA               # '/data/style/config.lua'

# enable flatnodes for storing, set to 1 or 'enabled'
FLAT_NODES 

# extra osm2pgsql args
OSM2PGSQL_EXTRA_ARGS

# extra osm2pgsql args
OSM2PGSQL_REPLICATION_EXTRA_ARGS

# file to post-processing sql statements
INDEXES_SQL             # '/data/style/indexes.sql'

# let osm2pgsql-replication read url from osm.pbf file, set to 1 or 'enabled'
# this is supported for some excerpts, such as regions downloaded from geofabrik.de
REPLICATION_URL_FROM_PBF

# frequency of running osm2pgsql-replication script
REPLICATION_CRON_EXPR   # '0 * * * *'
```

See the [osm2pgsql documentation](https://osm2pgsql.org/doc/manual.html) for more information about `osm2pgsql`.

example with flat nodes enabled enabled for the Netherlands with daily updates and a styling config lua script.
```bash
docker run \
    --name osm-pg \
    -e DOWNLOAD_OSM_PBF="https://download.geofabrik.de/europe/netherlands-latest.osm.pbf" \
    -e FLAT_NODES="enabled" \
    -e REPLICATION_URL_FROM_PBF="enabled" \
    -e REPLICATION_CRON_EXPR="0 0 * * *" \
    -e STYLE_LUA="/opt/config.lua" \
    -v osm:/data \
    -v path/to/custom_config.lua:/opt/config.lua \
    -p 5432:5432 \
    osm-pg import

# on restarts
docker run \
    --name osm-pg \
    -v osm:/data \
    -v path/to/custom_config.lua:/opt/config.lua \
    -p 5432:5432 \
    osm-pg run
```

Note: the flag `FLAT_NODES` adds the following flags to `OSM2PGSQL_EXTRA_ARGS`
```bash
--flat-nodes /data/database/flat_nodes.bin --cache 0
```
Note: the flag `REPLICATION_URL_FROM_PBF` add the following flags to `OSM2PGSQL_REPLICATION_EXTRA_ARGS`
```bash
--osm-file /data/region.osm.pbf
```

## Contributing

Pull requests are welcome. For major changes, please open an issue first
to discuss what you would like to change.

## License

[MIT](https://choosealicense.com/licenses/mit/)
