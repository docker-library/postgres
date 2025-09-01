#!/usr/bin/env bash
set -euo pipefail
# zz-pgbackrest-env.sh
# Writes pgbackrest.conf from env/secrets and attempts stanza-create during initdb.
# Only runs when ENABLE_PGBACKREST=true.

# helper to read ENV or *_FILE secret
_get_secret() {
  local envname="$1"; local filevar="$2"
  if [ -n "${!envname:-}" ]; then
    printf '%s' "${!envname}"
  elif [ -n "${!filevar:-}" ] && [ -f "${!filevar:-}" ]; then
    < "${!filevar}"
  else
    printf ''
  fi
}

# Read the opt-in flag (default "false" should be set by docker-entrypoint via file_env)
: "${ENABLE_PGBACKREST:=false}"
# Normalize to lowercase
ENABLE_PGBACKREST="${ENABLE_PGBACKREST,,}"

if [ "$ENABLE_PGBACKREST" != "true" ]; then
  echo "PGBACKREST: disabled (ENABLE_PGBACKREST=${ENABLE_PGBACKREST}). Skipping pgBackRest setup."
  exit 0
fi

# When enabled, read vars (fallback defaults)
: "${PGBACKREST_REPO_PATH:=/var/lib/pgbackrest}"
: "${PGBACKREST_LOG_PATH:=/var/log/pgbackrest}"
: "${PGBACKREST_CONF_PATH:=/etc/pgbackrest/pgbackrest.conf}"
: "${PGBACKREST_REPO_TYPE:=local}"
: "${PGBACKREST_STANZA:=main}"
: "${PGBACKREST_REPO1_RETENTION_FULL:=}"
: "${PGBACKREST_LOG_LEVEL:=info}"
: "${ENABLE_PG_ALTER_SYSTEM:=false}"
: "${PG_WAL_LEVEL:=replica}"
: "${PG_ARCHIVE_MODE:=on}"
: "${PG_ARCHIVE_TIMEOUT:=60}"

# S3 secrets via env or *_FILE
: "${PGBACKREST_S3_BUCKET:=}"
: "${PGBACKREST_S3_REGION:=}"
: "${PGBACKREST_S3_ENDPOINT:=}"
: "${PGBACKREST_S3_KEY_FILE:=}"
: "${PGBACKREST_S3_KEY_SECRET_FILE:=}"
PGBACKREST_S3_KEY_REAL="$(_get_secret PGBACKREST_S3_KEY PGBACKREST_S3_KEY_FILE)"
PGBACKREST_S3_KEY_SECRET_REAL="$(_get_secret PGBACKREST_S3_KEY_SECRET PGBACKREST_S3_KEY_SECRET_FILE)"

# Basic validation: require either local repo mount or S3 bucket
if [ "$PGBACKREST_REPO_TYPE" = "local" ]; then
  if [ ! -d "$PGBACKREST_REPO_PATH" ]; then
    echo "PGBACKREST: warning - local repo path $PGBACKREST_REPO_PATH does not exist. Make sure you mount a volume there." >&2
  fi
elif [ "$PGBACKREST_REPO_TYPE" = "s3" ]; then
  if [ -z "${PGBACKREST_S3_BUCKET:-}" ]; then
    echo "PGBACKREST: ERROR - repo type 's3' selected but PGBACKREST_S3_BUCKET is empty." >&2
    echo "PGBACKREST: aborting setup." >&2
    exit 1
  fi
else
  echo "PGBACKREST: ERROR - unknown PGBACKREST_REPO_TYPE='$PGBACKREST_REPO_TYPE'." >&2
  exit 1
fi

# ensure dirs and owner
mkdir -p "$PGBACKREST_REPO_PATH" "$PGBACKREST_LOG_PATH" "$(dirname "$PGBACKREST_CONF_PATH")"
chown -R postgres:postgres "$PGBACKREST_REPO_PATH" "$PGBACKREST_LOG_PATH" "$(dirname "$PGBACKREST_CONF_PATH")"
chmod 0700 "$PGBACKREST_REPO_PATH" || true
chmod 0755 "$PGBACKREST_LOG_PATH" || true

# write pgbackrest.conf (no secrets baked into image if you used *_FILE)
cat > "$PGBACKREST_CONF_PATH" <<-CONF
[global]
repo1-path=${PGBACKREST_REPO_PATH}
log-path=${PGBACKREST_LOG_PATH}
log-level-console=${PGBACKREST_LOG_LEVEL}
CONF

if [ -n "$PGBACKREST_REPO1_RETENTION_FULL" ]; then
  printf "repo1-retention-full=%s\n" "$PGBACKREST_REPO1_RETENTION_FULL" >> "$PGBACKREST_CONF_PATH"
fi

if [ "$PGBACKREST_REPO_TYPE" = "s3" ]; then
  cat >> "$PGBACKREST_CONF_PATH" <<-S3CONF

repo1-type=s3
repo1-s3-bucket=${PGBACKREST_S3_BUCKET}
S3CONF
  [ -n "$PGBACKREST_S3_REGION" ] && printf "repo1-s3-region=%s\n" "$PGBACKREST_S3_REGION" >> "$PGBACKREST_CONF_PATH"
  [ -n "$PGBACKREST_S3_ENDPOINT" ] && printf "repo1-s3-endpoint=%s\n" "$PGBACKREST_CONF_PATH"
  if [ -n "$PGBACKREST_S3_KEY_REAL" ]; then
    printf "repo1-s3-key=%s\n" "$PGBACKREST_S3_KEY_REAL" >> "$PGBACKREST_CONF_PATH"
  fi
  if [ -n "$PGBACKREST_S3_KEY_SECRET_REAL" ]; then
    printf "repo1-s3-key-secret=%s\n" "$PGBACKREST_S3_KEY_SECRET_REAL" >> "$PGBACKREST_CONF_PATH"
  fi
fi

cat >> "$PGBACKREST_CONF_PATH" <<-CONF
[${PGBACKREST_STANZA}]
pg1-path=/var/lib/postgresql/data
CONF

chown postgres:postgres "$PGBACKREST_CONF_PATH"
chmod 0600 "$PGBACKREST_CONF_PATH"

export PGBACKREST_CONFIG="$PGBACKREST_CONF_PATH"

# find pgbackrest binary
PGBACKREST_BIN="$(command -v pgbackrest || true)"
if [ -z "$PGBACKREST_BIN" ]; then
  echo "PGBACKREST: ERROR - pgbackrest binary not found in image PATH. Install pgbackrest or rebuild image with it." >&2
  exit 1
fi

# archive_command built with absolute path (safe)
ARCHIVE_CMD="${PGBACKREST_BIN} --stanza=${PGBACKREST_STANZA} --log-level-console=${PGBACKREST_LOG_LEVEL} archive-push %p"
ARCHIVE_CMD_SQL="$(printf "%s" "$ARCHIVE_CMD" | sed "s/'/'\\\\''/g")"

# only ALTER SYSTEM if explicitly allowed
if [ "${ENABLE_PG_ALTER_SYSTEM,,}" = "true" ]; then
  : "${POSTGRES_USER:=postgres}"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-PSQL || true
    ALTER SYSTEM SET wal_level = '${PG_WAL_LEVEL}';
    ALTER SYSTEM SET archive_mode = '${PG_ARCHIVE_MODE}';
    ALTER SYSTEM SET archive_command = '${ARCHIVE_CMD_SQL}';
    ALTER SYSTEM SET archive_timeout = '${PG_ARCHIVE_TIMEOUT}';
PSQL
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -c "SELECT pg_reload_conf();" || true
else
  echo "PGBACKREST: not altering Postgres configuration (ENABLE_PG_ALTER_SYSTEM=${ENABLE_PG_ALTER_SYSTEM})"
fi

# Create stanza (best-effort)
if "$PGBACKREST_BIN" --stanza="${PGBACKREST_STANZA}" --log-level-console="${PGBACKREST_LOG_LEVEL}" info >/dev/null 2>&1; then
  echo "PGBACKREST: stanza present"
else
  echo "PGBACKREST: attempting stanza-create..."
  "$PGBACKREST_BIN" --stanza="${PGBACKREST_STANZA}" --log-level-console="${PGBACKREST_LOG_LEVEL}" stanza-create || true
fi

exit 0
