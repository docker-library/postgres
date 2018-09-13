#!/usr/bin/env bash
set -Eeo pipefail
# TODO swap to -Eeuo pipefail above (after handling all potentially-unset variables)

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

# check to see if this file is being run or sourced from another script
_is_sourced() {
	# https://unix.stackexchange.com/a/215279
	[ "${FUNCNAME[${#FUNCNAME[@]} - 1]}" == 'source' ]
}

# used to create initial posgres directories and if run as root, ensure ownership to the "postgres" user
docker_create_database_dirs() {
	local user="$(id -u)"

	mkdir -p "$PGDATA"
	chmod 700 "$PGDATA"

	# ignore failure since it will be fine when using the image provided directory; see also https://github.com/docker-library/postgres/pull/289
	mkdir -p /var/run/postgresql || :
	chmod 775 /var/run/postgresql || :

	# Create the transaction log directory before initdb is run so the directory is owned by the correct user
	if [ "$POSTGRES_INITDB_WALDIR" ]; then
		mkdir -p "$POSTGRES_INITDB_WALDIR"
		[ "$user" = '0' ] && find "$POSTGRES_INITDB_WALDIR" \! -user postgres - exec chown postgres '{}' +
		chmod 700 "$POSTGRES_INITDB_WALDIR"
	fi

	# allow the container to be started with `--user`
	if [ "$user" = '0' ]; then
		find "$PGDATA" \! -user postgres -exec chown postgres '{}' +
		find /var/run/postgresql \! -user postgres -exec chown postgres '{}' +
	fi
}

# initialize empty PGDATA directory with new database via 'initdb'
docker_init_database_dir() {
	# "initdb" is particular about the current user existing in "/etc/passwd", so we use "nss_wrapper" to fake that if necessary
	# see https://github.com/docker-library/postgres/pull/253, https://github.com/docker-library/postgres/issues/359, https://cwrap.org/nss_wrapper.html
	if ! getent passwd "$(id -u)" &> /dev/null && [ -e /usr/lib/libnss_wrapper.so ]; then
		export LD_PRELOAD='/usr/lib/libnss_wrapper.so'
		export NSS_WRAPPER_PASSWD="$(mktemp)"
		export NSS_WRAPPER_GROUP="$(mktemp)"
		echo "postgres:x:$(id -u):$(id -g):PostgreSQL:$PGDATA:/bin/false" > "$NSS_WRAPPER_PASSWD"
		echo "postgres:x:$(id -g):" > "$NSS_WRAPPER_GROUP"
	fi

	file_env 'POSTGRES_INITDB_ARGS'
	if [ "$POSTGRES_INITDB_WALDIR" ]; then
		export POSTGRES_INITDB_ARGS="$POSTGRES_INITDB_ARGS --waldir $POSTGRES_INITDB_WALDIR"
	fi

	eval 'initdb --username="$POSTGRES_USER" --pwfile=<(echo "$POSTGRES_PASSWORD") '"$POSTGRES_INITDB_ARGS"

	# unset/cleanup "nss_wrapper" bits
	if [ "${LD_PRELOAD:-}" = '/usr/lib/libnss_wrapper.so' ]; then
		rm -f "$NSS_WRAPPER_PASSWD" "$NSS_WRAPPER_GROUP"
		unset LD_PRELOAD NSS_WRAPPER_PASSWD NSS_WRAPPER_GROUP
	fi
}

# print large warning if POSTGRES_PASSWORD is empty
docker_print_password_warning() {
	# check password first so we can output the warning before postgres
	# messes it up
	if [ "${#POSTGRES_PASSWORD}" -ge 100 ]; then
		cat >&2 <<-'EOWARN'

			WARNING: The supplied POSTGRES_PASSWORD is 100+ characters.

			  This will not work if used via PGPASSWORD with "psql".

			  https://www.postgresql.org/message-id/flat/E1Rqxp2-0004Qt-PL%40wrigleys.postgresql.org (BUG #6412)
			  https://github.com/docker-library/postgres/issues/507

		EOWARN
	fi
	if [ -z "$POSTGRES_PASSWORD" ]; then
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

	fi
}

# run, source, or read files from /docker-entrypoint-initdb.d (or specified directory)
docker_process_init_files() {
	# psql here for backwards compatiblilty "${psql[@]}"
	psql=( docker_psql_run )

	local initDir="${1:-/docker-entrypoint-initdb.d}"

	echo
	for f in "${initDir%/}"/*; do
		case "$f" in
			*.sh)
				# https://github.com/docker-library/postgres/issues/450#issuecomment-393167936
				# https://github.com/docker-library/postgres/pull/452
				if [ -x "$f" ]; then
					echo "$0: running $f"
					"$f"
				else
					echo "$0: sourcing $f"
					. "$f"
				fi
				;;
			*.sql)    echo "$0: running $f"; docker_psql_run -f "$f"; echo ;;
			*.sql.gz) echo "$0: running $f"; gunzip -c "$f" | docker_psql_run; echo ;;
			*)        echo "$0: ignoring $f" ;;
		esac
		echo
	done
}

# run `psql` with proper arguments for user and db
docker_psql_run() {
	local query_runner=( psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --no-password )
	if [ -n "$POSTGRES_DB" ]; then
		query_runner+=( --dbname "$POSTGRES_DB" )
	fi

	"${query_runner[@]}" "$@"
}

# create initial postgresql superuser with password and database
# uses environment variables for input: POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB
docker_setup_database() {
	if [ "$POSTGRES_DB" != 'postgres' ]; then
		POSTGRES_DB= docker_psql_run --dbname postgres --set db="$POSTGRES_DB" <<-'EOSQL'
			CREATE DATABASE :"db" ;
		EOSQL
		echo
	fi
}

# get user/pass and db from env vars or via file
docker_setup_env_vars() {
	file_env 'POSTGRES_PASSWORD'

	file_env 'POSTGRES_USER' 'postgres'
	file_env 'POSTGRES_DB' "$POSTGRES_USER"
}

# append md5 or trust auth to pg_hba.conf based on existence of POSTGRES_PASSWORD
docker_setup_pg_hba() {
	local authMethod
	if [ "$POSTGRES_PASSWORD" ]; then
		authMethod='md5'
	else
		authMethod='trust'
	fi

	{
		echo
		echo "host all all all $authMethod"
	} >> "$PGDATA/pg_hba.conf"
}

# start socket-only postgresql server for setting up user or running scripts
# all arguments will be passed along as arguments to `postgres` (via pg_ctl)
docker_temporary_pgserver_start() {
	# internal start of server in order to allow set-up using psql-client
	# does not listen on external TCP/IP and waits until start finishes (can be overridden via args)
	PGUSER="${PGUSER:-$POSTGRES_USER}" \
	pg_ctl -D "$PGDATA" \
		-o "-c listen_addresses='' $([ "$#" -gt 0 ] && printf '%q ' "$@")" \
		-w start
}

# stop postgresql server after done setting up user and running scripts
docker_temporary_pgserver_stop() {
	PGUSER="${PGUSER:-postgres}" \
	pg_ctl -D "$PGDATA" -m fast -w stop
}

_main() {
	# if first arg looks like a flag, assume we want to run postgres server
	if [ "${1:0:1}" = '-' ]; then
		set -- postgres "$@"
	fi

	# setup data directories and permissions, then restart script as postgres user
	if [ "$1" = 'postgres' ] && [ "$(id -u)" = '0' ]; then
		docker_create_database_dirs
		exec gosu postgres "$BASH_SOURCE" "$@"
	fi

	if [ "$1" = 'postgres' ]; then
		docker_create_database_dirs

		# only run initialization on an empty data directory
		# look specifically for PG_VERSION, as it is expected in the DB dir
		if [ ! -s "$PGDATA/PG_VERSION" ]; then
			docker_init_database_dir

			docker_setup_env_vars
			docker_print_password_warning
			docker_setup_pg_hba

			# PGPASSWORD is required for psql when authentication is required for 'local' connections via pg_hba.conf and is otherwise harmless
			# e.g. when '--auth=md5' or '--auth-local=md5' is used in POSTGRES_INITDB_ARGS
			export PGPASSWORD="${PGPASSWORD:-$POSTGRES_PASSWORD}"
			docker_temporary_pgserver_start "${@:2}"

			docker_setup_database

			docker_process_init_files

			docker_temporary_pgserver_stop
			unset PGPASSWORD

			echo
			echo 'PostgreSQL init process complete; ready for start up.'
			echo
		else
			echo
			echo 'PostgreSQL Database directory appears to contain a database; Skipping initialization'
			echo
		fi
	fi

	exec "$@"
}

if ! _is_sourced; then
	_main "$@"
fi
