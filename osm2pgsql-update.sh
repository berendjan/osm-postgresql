export $(xargs -a /data/scripts/cron-envs)

osm2pgsql-replication update
    --database ${DATABASE_CONN}
    --append \
    --slim \
    --output flex \
    --style ${STYLE_LUA:-/data/style/config.lua} \
    ${OSM2PGSQL_EXTRA_ARGS:-} \
    /data/region.osm.pbf
