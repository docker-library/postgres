# vim:set ft=dockerfile:
FROM alpine:3.5

# alpine includes "postgres" user/group in base install
# /etc/passwd:22:postgres:x:70:70::/var/lib/postgresql:/bin/sh
# /etc/group:34:postgres:x:70:

# su-exec (gosu-compatible) is installed further down

# make the "en_US.UTF-8" locale so postgres will be utf-8 enabled by default
# alpine doesn't require explicit locale-file generation
ENV LANG en_US.utf8

RUN mkdir /docker-entrypoint-initdb.d

ENV PG_MAJOR 9.6
ENV PG_VERSION 9.6.2
ENV PG_SHA256 0187b5184be1c09034e74e44761505e52357248451b0c854dddec6c231fe50c9

RUN set -ex \
	&& apk add --no-cache \
		ca-certificates \
		openssl \
		tar \
		bash \
		su-exec \
		tzdata \
	&& apk add --no-cache postgresql postgresql-contrib

# make the sample config easier to munge (and "correct by default")
RUN sed -ri "s!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '*'!" /usr/share/postgresql/postgresql.conf.sample

RUN mkdir -p /var/run/postgresql && chown -R postgres:postgres /var/run/postgresql && chmod g+s /var/run/postgresql

ENV PGDATA /var/lib/postgresql/data
RUN mkdir -p "$PGDATA" && chown -R postgres:postgres "$PGDATA" && chmod 777 "$PGDATA" # this 777 will be replaced by 700 at runtime (allows semi-arbitrary "--user" values)
VOLUME /var/lib/postgresql/data

COPY docker-entrypoint.sh /usr/local/bin/
RUN ln -s usr/local/bin/docker-entrypoint.sh / # backwards compat
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 5432
CMD ["postgres"]
