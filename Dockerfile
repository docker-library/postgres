FROM debian:jessie

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r postgres && useradd -r -g postgres postgres

RUN apt-get update && apt-get install -y \
		bison \
		build-essential \
		curl \
		flex \
		libreadline-dev \
		zlib1g-dev

RUN curl -o /usr/local/bin/gosu -SL 'https://github.com/tianon/gosu/releases/download/1.0/gosu' \
	&& chmod +x /usr/local/bin/gosu

ADD . /usr/src/postgres

RUN cd /usr/src \
	&& cp -a postgres postgres-build \
	&& cd postgres-build \
	&& ./configure \
	&& make -j"$(nproc)" \
	&& chown -R postgres src/test/regress \
	&& (gosu postgres make check \
		|| { cat >&2 /usr/src/postgres/src/test/regress/log/initdb.log; false; }) \
	&& make install \
	&& cd .. \
	&& rm -rf postgres-build \
	&& find /usr/local/pgsql -type f -name "*.a" -delete \
	&& ((find /usr/local/pgsql -type f -print | xargs strip --strip-all) || true) \
	&& rm -rf /usr/local/pgsql/include \
	&& rm -rf /usr/local/pgsql/lib/pgxs

WORKDIR /usr/local/pgsql
ENV PATH $PATH:/usr/local/pgsql/bin:/usr/local/mysql/scripts

ENV PGDATA /var/lib/postgresql/data
VOLUME /var/lib/postgresql/data

ENTRYPOINT ["/usr/src/postgres/docker-entrypoint.sh"]

EXPOSE 5432
CMD ["postgres"]
