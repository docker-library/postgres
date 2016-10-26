FROM alpine:latest

# make the "en_US.UTF-8" locale so postgres will be utf-8 enabled by default
ENV LANG en_US.utf8

RUN mkdir /docker-entrypoint-initdb.d

ENV PG_MAJOR 9.4
ENV PG_VERSION 9.4.9
ENV PG_SHA256 c120a62e90214c20d9160da3ca3fbaec97d5f1656f1dd033f60e7297b7a1e1c9

RUN set -x \
	&& apk add --no-cache --virtual .build-deps \
		su-exec \
		bash \
		bison \
		curl \
		flex \
		gcc \
		krb5-dev \
		libc-dev \
		libedit-dev \
		libxml2-dev \
		libxslt-dev \
		make \
		openldap-dev \
		openssl-dev \
		perl \
		perl-dev \
		python3-dev \
		tcl-dev \
		util-linux-dev \
		zlib-dev \
	&& curl -fSL "https://ftp.postgresql.org/pub/source/v$PG_VERSION/postgresql-$PG_VERSION.tar.bz2" -o postgresql.tar.bz2 \
	&& echo "$PG_SHA256  postgresql.tar.bz2" | sha256sum -c - \
	&& mkdir -p /usr/src \
	&& tar -jxf postgresql.tar.bz2 -C /usr/src \
	&& rm postgresql.tar.bz2 \
	&& cd /usr/src/postgresql-$PG_VERSION \
	&& ./configure \
		--enable-integer-datetimes \
		--enable-tap-tests \
		--enable-thread-safety \
		--prefix=/usr/local \
		--with-libedit-preferred \
		--with-openssl \
		--with-uuid=e2fs \
	&& make -j$(getconf _NPROCESSORS_ONLN) world \
	&& make install-world \
	&& make -C contrib install \
	&& runDeps="$( \
		scanelf --needed --nobanner --recursive /usr/local \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u \
	)" \
	&& apk add --virtual .postgresql-rundeps $runDeps su-exec \
	&& apk del .build-deps \
    bison \
    curl \
    flex \
    gcc \
    krb5-dev \
    libc-dev \
    libedit-dev \
    libxml2-dev \
    libxslt-dev \
    make \
    openldap-dev \
    openssl-dev \
    perl \
    perl-dev \
    python3-dev \
    tcl-dev \
    util-linux-dev \
    zlib-dev \
	&& cd / && rm -rf /usr/src/postgresql-* /usr/local/include/* \
	&& find /usr/local -name '*.a' -delete

RUN mkdir -p /var/run/postgresql && chown -R postgres /var/run/postgresql

ENV PATH /usr/lib/postgresql/$PG_MAJOR/bin:$PATH
ENV PGDATA /var/lib/postgresql/data
VOLUME /var/lib/postgresql/data

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 5432
CMD ["postgres"]
