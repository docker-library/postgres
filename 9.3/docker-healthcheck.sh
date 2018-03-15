#!/usr/bin/env bash
source /usr/local/bin/docker-common.sh

# docker-entrypoint starts an postgres temporarily
# ensure the entrypoint script is over
if [ -e ${LOCK_PATH} ]; then
    echo "Entrypoint is still running"
    exit 1
fi

echo "Entrypoint has finished"

file_env 'POSTGRES_USER' 'postgres'
file_env 'POSTGRES_DB' "$POSTGRES_USER"
file_env 'POSTGRES_PASSWORD'
file_env 'POSTGRES_HEALTH_QUERY' "SELECT 'uptime: ' ||  now() - pg_postmaster_start_time();"

pg_isready=(pg_isready)

if [ "${POSTGRES_USER}" != "" ]; then
    pg_isready+=(--username "${POSTGRES_USER}")
fi

if [ "${POSTGRES_DB}" != "" ]; then
    pg_isready+=(--dbname "${POSTGRES_DB}")
fi

${pg_isready[@]} || exit 1

echo "Postgres accepts connections"

if [ "${POSTGRES_HEALTH_QUERY}" != "" ]; then
    health=(psql -t -v ON_ERROR_STOP=1)

    if [ "${POSTGRES_USER}" != "" ]; then
        health+=(--username "${POSTGRES_USER}")
    fi

    if [ "${POSTGRES_PASSWORD}" != "" ]; then
        export PGPASWORD=${POSTGRES_PASSWORD}
    fi
    
    if [ "${POSTGRES_DB}" != "" ]; then
        health+=(--dbname "${POSTGRES_DB}")
    fi
    echo ${POSTGRES_HEALTH_QUERY} | ${health[@]} || exit 1
    echo "Health query succeed"
fi

exit 0
