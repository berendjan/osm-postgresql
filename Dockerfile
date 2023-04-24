FROM debian:bookworm

ENV APP=osm
ENV PG_DBNAME=osmdb
ENV PG_DBUSER=osmuser
ENV DOWNLOAD_OSM_PBF=https://download.geofabrik.de/europe/luxembourg-latest.osm.pbf
ENV PLANET_OSM_PBF_TORRENT=https://planet.osm.org/pbf/planet-latest.osm.pbf.torrent
ENV PG_MAJOR=15
ENV PATH=$PATH:/usr/lib/postgresql/${PG_MAJOR}/bin

# Install packages
RUN echo "deb http://deb.debian.org/debian bookworm-backports main" > /etc/apt/sources.list.d/bookworm-backports.list
RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y \
    ca-certificates \
    cron \
    git \
    less \
    lua5.4 \
    osm2pgsql \
    postgis \
    postgresql-${PG_MAJOR} \
    postgresql-${PG_MAJOR}-postgis-3 \
    postgresql-${PG_MAJOR}-postgis-3-scripts \
    python3.11 \
    python3-pip \
    python3-psycopg \
    python3-pyosmium \
    sudo \
    vim \
    wget \
    && apt-get clean autoclean \
    && apt-get autoremove -y

# Add user
RUN groupadd --gid 1337 ${APP} \
    && adduser \
    --shell /bin/bash \
    --no-create-home \
    --uid 1337 \
    --ingroup ${APP} \
    --disabled-password \
    --gecos "Non-root user" \
    ${APP} \
    && mkdir -p /data/database/postgresql/ \
    && mkdir -p /data/scripts/ \
    && chown -R ${APP}: /data

# Configure PostgreSQL
COPY postgresql-osm.conf /etc/postgresql/${PG_MAJOR}/main/conf.d/
RUN mv /var/lib/postgresql/${PG_MAJOR}/main/* /data/database/postgresql/ \
    && rmdir /var/lib/postgresql/${PG_MAJOR}/main/ \
    && ln -s /data/database/postgresql/ /var/lib/postgresql/${PG_MAJOR}/main \
    && echo "host all all 0.0.0.0/0 md5" >> /etc/postgresql/${PG_MAJOR}/main/pg_hba.conf \
    && echo "host all all ::/0 md5"      >> /etc/postgresql/${PG_MAJOR}/main/pg_hba.conf \
    && chown -R postgres: /data/database/postgresql/ \
    && chown -R postgres: /var/lib/postgresql/ \
    && chmod 0700 /var/lib/postgresql/15/main

# Configure Cron Job for updating OSM
COPY --chown=${APP}:${APP} osm2pgsql-update.sh /data/scripts/

# Copy default lua script
COPY --chown=${APP}:${APP} generic.lua /data/style/config.lua

# Start script
COPY --chown=${APP}:${APP} run.sh /data/scripts/

EXPOSE 5432
ENTRYPOINT [ "/data/scripts/run.sh" ]

