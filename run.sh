#!/bin/bash

set -euo pipefail

USAGE="""usage: <import|run>
commands:
    import: Starts database and import /data/region.osm.pbf
    run: Starts database without importing
environment variables:
    PG_DBUSER: postgresql user
    PG_DBNAME: postgresql database name
    PG_PASSWORD: postgresql password
    DOWNLOAD_OSM_PBF: osm region download link
    STYLE_LUA: path to lua config (style) script
    FLAT_NODES: adds flags to use flat nodes cache file
    OSM2PGSQL_EXTRA_ARGS: extra osm2pgsql arg
    OSM2PGSQL_REPLICATION_EXTRA_ARGS: extra osm2pgsql-repliction args
    INDEXES_SQL: path to post-importing sql statements file
    REPLICATION_URL_FROM_PBF: adds flags to retrieve update url from pbf
    REPLICATION_CRON_EXPR: frequency of running osm2pgsql-replication script
"""


if [ "$#" -ne 1 ]; then
    echo "${USAGE}"
    exit 0
fi

if [[ "$1" == "import" ]]; then

    # Ensure that database directory is in right state
    chown ${APP}: /data/database/ /data/style/
    mkdir -p /data/database/postgresql/
    chown -R postgres: /var/lib/postgresql /data/database/postgresql/
    if [[ ! -f /data/database/postgresql/PG_VERSION ]]; then
        sudo -u postgres /usr/lib/postgresql/${PG_MAJOR}/bin/pg_ctl -D /data/database/postgresql/ initdb -o "--locale C.UTF-8"
    fi

    service postgresql start
    sudo -u postgres createuser ${PG_DBUSER}
    sudo -u postgres createdb ${PG_DBNAME}
    sudo -u postgres psql -d ${PG_DBNAME} -c "CREATE EXTENSION postgis;"
    sudo -u postgres psql -d ${PG_DBNAME} -c "CREATE EXTENSION hstore;"
    sudo -u postgres psql -d ${PG_DBNAME} -c "ALTER TABLE geometry_columns OWNER TO ${PG_DBUSER};"
    sudo -u postgres psql -d ${PG_DBNAME} -c "ALTER TABLE spatial_ref_sys OWNER TO ${PG_DBUSER};"
    sudo -u postgres psql -d ${PG_DBNAME} -c "ALTER USER ${PG_DBUSER} PASSWORD '${PG_PASSWORD:-osmpassword}';"
    sudo -u postgres psql -d ${PG_DBNAME} -c "GRANT ALL ON SCHEMA public TO ${PG_DBUSER};"

    if [[ ! -f /data/region.osm.pbf ]]; then
        echo 'No region provided at /data/region.osm.pbf, downloading from $DOWNLOAD_OSM_PBF:' ${DOWNLOAD_OSM_PBF}
        wget ${DOWNLOAD_OSM_PBF} -qO /data/region.osm.pbf
    fi

    if [[ ${FLAT_NODES:-} == "enabled" || ${FLAT_NODES:-} == 1 ]]; then
        OSM2PGSQL_EXTRA_ARGS="${OSM2PGSQL_EXTRA_ARGS:-} --flat-nodes /data/database/flat_nodes.bin --cache 0"
    fi

    DATABASE_CONN="postgresql://${PG_DBUSER}:${PG_PASSWORD:-osmpassword}@localhost:5432/${PG_DBNAME}"

    echo "Starting osm2pgsql"
    echo "With Lua config: ${STYLE_LUA:-/data/style/config.lua}"
    echo 'With extra args: $OSM2PGSQL_EXTRA_ARGS: ' "${OSM2PGSQL_EXTRA_ARGS:-}"
    sudo -u ${APP} osm2pgsql \
        --create \
        --slim \
        --database ${DATABASE_CONN} \
        --output flex \
        --style ${STYLE_LUA:-/data/style/config.lua} \
        ${OSM2PGSQL_EXTRA_ARGS:-} \
        /data/region.osm.pbf

    # Create indexes
    if [[ -f ${INDEXES_SQL:-/data/style/indexes.sql} ]]; then
        sudo -u postgres psql -d ${PG_DBNAME} -f ${INDEXES_SQL:-/data/style/indexes.sql}
    fi

    if [[ ${REPLICATION_URL_FROM_PBF:-} == "enabled" || ${REPLICATION_URL_FROM_PBF:-} == 1 ]]; then
        OSM2PGSQL_REPLICATION_EXTRA_ARGS="${OSM2PGSQL_REPLICATION_EXTRA_ARGS:-} --osm-file /data/region.osm.pbf"
    fi

    echo "Initializing osm2pgsql-replication updates"
    echo 'With extra args: $OSM2PGSQL_REPLICATION_EXTRA_ARGS:' "${OSM2PGSQL_REPLICATION_EXTRA_ARGS:-}"
    sudo -u ${APP} osm2pgsql-replication init \
        --database ${DATABASE_CONN} \
        ${OSM2PGSQL_REPLICATION_EXTRA_ARGS:-}

    echo "Initializing osm2pgsql-replication cronjob"
    echo ${REPLICATION_CRON_EXPR:-0 * * * *} ${APP} "/data/scripts/osm2pgsql-update.sh" >> /etc/cron.d/osm2pgsql-cronjob
    echo "export DATABASE_CONN=${DATABASE_CONN}" >> /data/scripts/cron-envs
    echo "export OSM2PGSQL_EXTRA_ARGS=${OSM2PGSQL_EXTRA_ARGS:-}" >> /data/scripts/cron-envs
    echo "export STYLE_LUA=${STYLE_LUA:-/data/style/config.lua}" >> /data/scripts/cron-envs

    service cron start

    export HOST_IP=$(awk 'END{print $1}' /etc/hosts)
    
    echo "Postgresql service ready at:"
    echo "${DATABASE_CONN}" | sed "s/localhost/${HOST_IP}/1"
    
    # Run while handling docker stop's SIGTERM
    stop_handler() {
        service cron stop
        service postgresql stop
        echo "done"
    }
    trap stop_handler SIGTERM
    sleep infinity & wait

    exit 0
fi

if [[ "$1" == "run" ]]; then
    
    export $(xargs -a /data/scripts/cron-envs)

    service postgresql start
    service cron start

    export HOST_IP=$(awk 'END{print $1}' /etc/hosts)

    echo "Postgresql service ready at:"
    echo "${DATABASE_CONN}" | sed "s/localhost/${HOST_IP}/1"
    
    # Run while handling docker stop's SIGTERM
    stop_handler() {
        service cron stop
        service postgresql stop
        echo "done"
    }
    trap stop_handler SIGTERM
    sleep infinity & wait

    exit 0
fi

echo "${USAGE}"
exit 1
