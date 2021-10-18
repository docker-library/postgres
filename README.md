# OpenSQL-PostgreSQL

Dockerfile source for postgresql docker image originated from [docker library](https://github.com/docker-library/postgres).

## How to use 

``` shell
$ docker run --name some-postgres -e POSTGRES_PASSWORD=mysecretpassword -d postgres
```

The default postgres user and database are created in the entrypoint with initdb. The only required environment variable is `POSTGRES_PASSWORD`, the rest are optional.

### Environment Variables

| **Variable** | **Short Description** |
|:-------------|:----------------|
| POSTGRES_PASSWORD | The password for the superuser. It must not be empty or undefined. |
| POSTGRES_USER | (Optional) Creates user with superuser power and a database with the same name. Default value is `postgres`. |
| POSTGRES_DB | (Optional) Defines the name of the default database to be created. Default value is same as `POSTGRES_USER`. |
| POSTGRES_INITDB_ARGS | (Optional) Specifies arguments to send to `postgres initdb`. For example. `--data-checksums --encoding=UTF8`. |
| POSTGRES_INITDB_WALDIR | (Optional) Defines a location for the Postgres transaction log. Default value is a subdirectory of the main Postgres data folder (`PGDATA`). |
| POSTGRES_HOST_AUTH_METHOD | (Optional) Defines `auth-method` for host connections for all databases, all users, and all addresses. Default value is md5 passsword authentication. |
| PGDATA | (Optional) Defines the directory location of the database files. Defaults value is `/var/lib/postgresql/data`. |

**PGDATA**

If the data volume you're using is a filesystem mountpoint (like with GCE persistent disks) or remote folder that cannot be chowned to the postgres user (like some NFS mounts), Postgres initdb recommends a subdirectory be created to contain the data.

``` shell
$ docker run -d \
    --name some-postgres \
    -e POSTGRES_PASSWORD=mysecretpassword \
    -e PGDATA=/var/lib/postgresql/data/pgdata \
    -v /custom/mount:/var/lib/postgresql/data \
    postgres
```
