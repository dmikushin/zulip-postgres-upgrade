FROM postgres:14-bullseye

RUN sed 's/$/ 10/' /etc/apt/sources.list.d/pgdg.list

RUN apt update && apt install -y --no-install-recommends \
	postgresql-10=10.23-1.pgdg110+1 \
	wget \
	ca-certificates

RUN echo "deb [trusted=yes] https://packages.groonga.org/debian bullseye main" | tee /etc/apt/sources.list.d/groonga.list

RUN apt update && apt install -y --no-install-recommends \
	postgresql-14-pgdg-pgroonga

# Install hunspell, Zulip stop words.
RUN apt update && apt install -y --no-install-recommends \
	hunspell-en-us
RUN ln -sf /usr/share/hunspell/en_US.dic /usr/share/postgresql/14/tsearch_data/en_us.dict && \
	ln -sf /usr/share/hunspell/en_US.aff /usr/share/postgresql/14/tsearch_data/en_us.affix
COPY zulip_english.stop /usr/share/postgresql/14/tsearch_data/zulip_english.stop

ENV PGBINOLD /usr/lib/postgresql/10/bin
ENV PGBINNEW /usr/lib/postgresql/14/bin

ENV PGDATAOLD /var/lib/postgresql/10/data
ENV PGDATANEW /var/lib/postgresql/14/data

RUN mkdir -p "$PGDATAOLD" "$PGDATANEW" && \
	chown -R postgres:postgres /var/lib/postgresql

WORKDIR /var/lib/postgresql

COPY docker-upgrade /usr/local/bin/

ENTRYPOINT ["docker-upgrade"]

CMD [ "pg_upgrade" ]
