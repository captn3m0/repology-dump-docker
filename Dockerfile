FROM opensuse/tumbleweed:latest

RUN zypper --non-interactive install postgresql17 postgresql17-libversion postgresql17-contrib zstd
RUN mkdir -p /var/run/postgresql && chown -R postgres /var/run/postgresql

USER postgres
RUN /usr/lib/postgresql17/bin/initdb --encoding=UTF8 -D /var/lib/pgsql/data
ENV PGDATA=/var/lib/pgsql/data

# do not use "RUN curl ..." as this would be executed once and the layer would be cached
ADD --chown=postgres:postgres https://dumps.repology.org/repology-database-dump-latest.sql.zst /tmp/

RUN pg_ctl --wait --mode immediate -D /var/lib/pgsql/data start -o "-F -c 'wal_level=minimal' -c 'max_wal_senders=0' -c 'max_replication_slots=0'" && \
	psql -c "CREATE DATABASE repology encoding='UTF8'" && \
	psql -c "CREATE USER repology WITH PASSWORD 'repology'" && \
	psql --dbname repology -c "CREATE EXTENSION pg_trgm" && \
	psql --dbname repology -c "CREATE EXTENSION libversion" && \
	echo "host    all             all             0.0.0.0/0            trust" >> /var/lib/pgsql/data/pg_hba.conf && \
	zstd -dc /tmp/repology-database-dump-latest.sql.zst | psql --dbname repology -v ON_ERROR_STOP=1 && \
        psql --dbname repology -c "GRANT CREATE ON SCHEMA public TO PUBLIC" && \
 	psql -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO repology" && \
	pg_ctl --wait --mode immediate -D /var/lib/pgsql/data stop && \
        rm /tmp/repology-database-dump-latest.sql.zst

CMD postgres -c "listen_addresses=*" -D /var/lib/pgsql/data
EXPOSE 5432
HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --retries=3 CMD pg_isready
