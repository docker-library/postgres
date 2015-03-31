#!/bin/bash
set -e

function alter_system {
    if [ ! -z "$2" -a "$2" != " " ]; then
        sed -ri "s/^#?($1\s*=\s*)\S+/\1'$2'/" "$PGDATA"/postgresql.conf
    fi
}

if [ "$1" = 'postgres' ]; then
	chown -R postgres "$PGDATA"
	
	chmod g+s /run/postgresql
	chown -R postgres:postgres /run/postgresql
	
	if [ -z "$(ls -A "$PGDATA")" ]; then
		gosu postgres initdb

        alter_system "listen_addresses" "*"
        alter_system "shared_buffers" $POSTGRES_SHARED_BUFFERS
        alter_system "max_connections" $POSTGRES_MAX_CONNECTIONS
        alter_system "wal_level" $POSTGRES_WAL_LEVEL
        alter_system "work_mem" $POSTGRES_WORK_MEM
        alter_system "effective_cache_size" $POSTGRES_EFFECTIVE_CACHE_SIZE
        alter_system "wal_buffers" $POSTGRES_WAL_BUFFERS

		# check password first so we can ouptut the warning before postgres
		# messes it up
		if [ "$POSTGRES_PASSWORD" ]; then
			pass="PASSWORD '$POSTGRES_PASSWORD'"
			authMethod=md5
		else
			# The - option suppresses leading tabs but *not* spaces. :)
			cat >&2 <<-'EOWARN'
				****************************************************
				WARNING: No password has been set for the database.
				         This will allow anyone with access to the
				         Postgres port to access your database. In
				         Docker's default configuration, this is
				         effectively any other container on the same
				         system.
				         
				         Use "-e POSTGRES_PASSWORD=password" to set
				         it in "docker run".
				****************************************************
			EOWARN
			
			pass=
			authMethod=trust
		fi
		
		: ${POSTGRES_USER:=postgres}
		: ${POSTGRES_DB:=$POSTGRES_USER}

		if [ "$POSTGRES_DB" != 'postgres' ]; then
			gosu postgres postgres --single -jE <<-EOSQL
				CREATE DATABASE "$POSTGRES_DB" ;
			EOSQL
			echo
		fi
		
		if [ "$POSTGRES_USER" = 'postgres' ]; then
			op='ALTER'
		else
			op='CREATE'
		fi

		gosu postgres postgres --single -jE <<-EOSQL
			$op USER "$POSTGRES_USER" WITH SUPERUSER $pass ;
		EOSQL
		echo
		
		{ echo; echo "host all all 0.0.0.0/0 $authMethod"; } >> "$PGDATA"/pg_hba.conf
		
		if [ -d /docker-entrypoint-initdb.d ]; then
			for f in /docker-entrypoint-initdb.d/*.sh; do
				[ -f "$f" ] && . "$f"
			done
		fi
	fi
	
	exec gosu postgres "$@"
fi

exec "$@"
