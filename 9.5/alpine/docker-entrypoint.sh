#!/bin/bash
set -e

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

if [ "${1:0:1}" = '-' ]; then
	set -- postgres "$@"
fi

if [ "$1" = 'postgres' ]; then
	mkdir -p "$PGDATA"
	chmod 700 "$PGDATA"
	chown -R postgres "$PGDATA"

	mkdir -p /run/postgresql
	chmod g+s /run/postgresql
	chown -R postgres /run/postgresql

	# look specifically for PG_VERSION, as it is expected in the DB dir
	if [ ! -s "$PGDATA/PG_VERSION" ]; then
		file_env 'POSTGRES_INITDB_ARGS'
		eval "su-exec postgres initdb $POSTGRES_INITDB_ARGS"

		authMethod=trust
		if [ "$POSTGRES_USERS" ]; then
			USERS_ARR=$(echo $POSTGRES_USERS | tr "|" "\n")
			for USER in $USERS_ARR
			do
				USER_PASSWORD=`echo $USER | cut -d: -f2`
				if [ "$USER_PASSWORD" ]; then
					authMethod=md5
				fi
			done
		fi

		# check password first so we can output the warning before postgres
		# messes it up
		file_env 'POSTGRES_PASSWORD'
		if [ "$POSTGRES_PASSWORD" ]; then
			pass="PASSWORD '$POSTGRES_PASSWORD'"
			authMethod=md5
		else
			pass=
		fi

		if [ "$authMethod" == "trust" ]; then
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
		fi

		{ echo; echo "host all all all $authMethod"; } | su-exec postgres tee -a "$PGDATA/pg_hba.conf" > /dev/null

		# internal start of server in order to allow set-up using psql-client		
		# does not listen on external TCP/IP and waits until start finishes
		su-exec postgres pg_ctl -D "$PGDATA" \
			-o "-c listen_addresses='localhost'" \
			-w start

		file_env 'POSTGRES_USER' 'postgres'
		file_env 'POSTGRES_DB' "$POSTGRES_USER"

		psql=( psql -v ON_ERROR_STOP=1 )

		if [ "$POSTGRES_DB" != 'postgres' ]; then
			"${psql[@]}" --username postgres <<-EOSQL
				CREATE DATABASE "$POSTGRES_DB" ;
			EOSQL
			echo
		fi

		if [ "$POSTGRES_USER" = 'postgres' ]; then
			op='ALTER'
		else
			op='CREATE'
		fi
		"${psql[@]}" --username postgres <<-EOSQL
			$op USER "$POSTGRES_USER" WITH SUPERUSER $pass ;
		EOSQL
		echo

		psql+=( --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" )

		# If you want to create more than one user, please use that variable
		# Variable example: POSTGRES_USERS="user1:user1pass|user2:user2pass|user3:user3password"
		if [ "$POSTGRES_USERS" ]; then
			USERS_ARR=$(echo $POSTGRES_USERS | tr "|" "\n")
			for USER in $USERS_ARR
			do
				USER_NAME=`echo $USER | cut -d: -f1`
				USER_PASSWORD=`echo $USER | cut -d: -f2`
				if [ "$USER_NAME" = 'postgres' ]; then
					op='ALTER'
				else
					op='CREATE'
				fi
				"${psql[@]}" --username postgres <<-EOSQL
					$op USER "$USER_NAME" WITH SUPERUSER PASSWORD '$USER_PASSWORD' ;
				EOSQL
			done
		fi

		# If you want to create more than one database, please use that variable
		# Variable example: POSTGRES_DATABASES="database1:user1|database2:user2|database3:user3"
		if [ "$POSTGRES_DATABASES" ]; then
			DATABASES_ARR=$(echo $POSTGRES_DATABASES | tr "|" "\n")
			for DATABASE in $DATABASES_ARR
			do
				DATABASE_NAME=`echo $DATABASE | cut -d: -f1`
				DATABASE_OWNER=`echo $DATABASE | cut -d: -f2`
				if [ "$DATABASE_NAME" != 'postgres' ]; then
					if [ "$DATABASE_OWNER" ]; then
						"${psql[@]}" --username postgres <<-EOSQL
						CREATE DATABASE "$DATABASE_NAME" owner "$DATABASE_OWNER" ;
						EOSQL
						echo
					else
						"${psql[@]}" --username postgres <<-EOSQL
							CREATE DATABASE "$DATABASE_NAME" ;
						EOSQL
						echo
					fi
				fi
			done
		fi

		# If you want to set up initial postgresql.conf parameters, please use that variable
		# Variable example: POSTGRES_CONFIGS="work_mem:15MB|fsync:off|full_page_writes:off"
		if [ "$POSTGRES_CONFIGS" ]; then
			CONFIGS_ARR=$(echo $POSTGRES_CONFIGS | tr "|" "\n")
			for CONFIG in $CONFIGS_ARR
			do
				CONFIG_NAME=`echo $CONFIG | cut -d: -f1`
				CONFIG_VALUE=`echo $CONFIG | cut -d: -f2`
				"${psql[@]}" --username postgres <<-EOSQL
					ALTER SYSTEM SET $CONFIG_NAME = "$CONFIG_VALUE" ;
				EOSQL
			done
		fi

		echo
		for f in /docker-entrypoint-initdb.d/*; do
			case "$f" in
				*.sh)     echo "$0: running $f"; . "$f" ;;
				*.sql)    echo "$0: running $f"; "${psql[@]}" -f "$f"; echo ;;
				*.sql.gz) echo "$0: running $f"; gunzip -c "$f" | "${psql[@]}"; echo ;;
				*)        echo "$0: ignoring $f" ;;
			esac
			echo
		done

		su-exec postgres pg_ctl -D "$PGDATA" -m fast -w stop

		echo
		echo 'PostgreSQL init process complete; ready for start up.'
		echo
	fi

	exec su-exec postgres "$@"
fi

exec "$@"
