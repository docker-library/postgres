#!/bin/bash
set -e

if [ "$1" = 'postgres' ]; then
	if [ -z "$(ls -A "$PGDATA")" ]; then
		chown -R postgres "$PGDATA"
		sudo -E -u postgres initdb
		
		sed -ri "s/^#(listen_addresses\s*=\s*)\S+/\1'*'/" "$PGDATA"/postgresql.conf
		
		{ echo; echo 'host all all 0.0.0.0/0 trust'; } >> "$PGDATA"/pg_hba.conf
	fi
	
	exec sudo -E -u postgres "$@"
fi

exec "$@"
