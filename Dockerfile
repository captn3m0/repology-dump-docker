FROM opensuse/leap:15.6

RUN zypper --non-interactive install postgresql14 postgresql14-libversion postgresql14-contrib zstd
RUN mkdir -p /var/run/postgresql && chown -R postgres /var/run/postgresql

USER postgres
RUN /usr/lib/postgresql14/bin/initdb -D /var/lib/pgsql/data
ENV PGDATA=/var/lib/pgsql/data
RUN pg_ctl --wait --mode immediate -D /var/lib/pgsql/data start -o "-F -c 'wal_level=minimal' -c 'max_wal_senders=0' -c 'max_replication_slots=0'" && \
	psql -c "CREATE DATABASE repology" && \
	psql -c "CREATE USER repology WITH PASSWORD 'repology'" && \
	psql -c "GRANT ALL ON DATABASE repology TO repology" && \
	psql --dbname repology -c "GRANT CREATE ON SCHEMA public TO PUBLIC" && \
	psql --dbname repology -c "CREATE EXTENSION pg_trgm" && \
	psql --dbname repology -c "CREATE EXTENSION libversion" && \
	echo "host    all             all             0.0.0.0/0            trust" >> /var/lib/pgsql/data/pg_hba.conf && \
	curl --silent https://dumps.repology.org/repology-database-dump-latest.sql.zst | zstd -d | \
	psql --dbname repology -v ON_ERROR_STOP=1 && \
	pg_ctl --wait --mode immediate -D /var/lib/pgsql/data stop

CMD postgres -c "listen_addresses=*" -D /var/lib/pgsql/data
EXPOSE 5432
HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --retries=3 CMD pg_isready
