FROM debian:jessie

RUN apt-get update && apt-get install -y \
		bison \
		build-essential \
		curl \
		flex \
		libreadline-dev \
		zlib1g-dev

RUN groupadd postgres && useradd -r -g postgres postgres
RUN curl -o /usr/local/bin/gosu -SL 'https://github.com/tianon/gosu/releases/download/1.0/gosu' \
	&& chmod +x /usr/local/bin/gosu

ADD . /usr/src/postgres
WORKDIR /usr/src/postgres

RUN ./configure
RUN make -j"$(nproc)"
RUN chown -R postgres src/test/regress \
	&& gosu postgres make check \
	|| { cat >&2 /usr/src/postgres/src/test/regress/log/initdb.log; false; }
RUN make install

ENV PATH $PATH:/usr/local/pgsql/bin:/usr/local/mysql/scripts

ENV PGDATA /var/lib/postgresql/data
VOLUME /var/lib/postgresql/data

ENTRYPOINT ["/usr/src/postgres/docker-entrypoint.sh"]

EXPOSE 5432
CMD ["postgres"]
