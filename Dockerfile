FROM debian:jessie

RUN apt-get update && apt-get install -y \
		bison \
		build-essential \
		flex \
		libreadline-dev \
		sudo \
		zlib1g-dev

RUN groupadd postgres && useradd -r -g postgres postgres
RUN sed -ri 's/^Defaults\s+secure_path/#&/' /etc/sudoers

ADD . /usr/src/postgres
WORKDIR /usr/src/postgres

RUN ./configure
RUN make -j"$(nproc)"
RUN chown -R postgres src/test/regress \
	&& sudo -u postgres make check \
	|| { cat >&2 /usr/src/postgres/src/test/regress/log/initdb.log; false; }
RUN make install

ENV PATH $PATH:/usr/local/pgsql/bin:/usr/local/mysql/scripts

ENV PGDATA /var/lib/postgresql/data
VOLUME /var/lib/postgresql/data

ENTRYPOINT ["/usr/src/postgres/docker-entrypoint.sh"]

EXPOSE 5432
CMD ["postgres"]
