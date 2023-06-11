# Upgrade Dockerized Zulip Database

Upgrade from Zulip 5 to Zulip 6 requires updating PostgreSQL version from 10 to 14.

Upgrade is supposed to be done by following [these instructions](https://zulip.readthedocs.io/en/latest/production/upgrade.html#upgrading-postgresql). However, they are only possible, if Zulip installation is NOT dockerized. When installing [Zulip with Docker](https://github.com/zulip/docker-zulip), postgresql database runs in a separate container. Therefore, `pg_upgradecluster` command in Zulip container does not make sense and will fail, because the old database is not running locally.

This utility container based on [tianon/docker-postgres-upgrade](https://github.com/tianon/docker-postgres-upgrade) installs PostgreSQL versions 10 and 14 simultaneously. Additionally, the required `pgroonga`, `hunspell-en-us`, and Zulip stop words are installed. Container preparation and Zulip database upgrade could be performed, as explained below.

## Building

```
docker build -t zulip-postgres-upgrade .
```

## Usage

The command below shall perform the database upgrade, with the following notes:

1. Older releases of Zulip are storing database in `/opt/docker/zulip/postgresql` - please make sure it is also the case for you, and use a different path if it's not
2. `PGUSER` is set to `zulip` - please make sure the TODO in your `docker-compose.yml` is also `zulip`, and change it accordingly if not

```
docker run --rm \
        -e PGUSER=zulip \
        -e POSTGRES_INITDB_ARGS="-U zulip" \
        -v /opt/docker/zulip/postgresql/data:/var/lib/postgresql/10/data \
        -v /opt/docker/zulip/postgresql14/data:/var/lib/postgresql/14/data \
        zulip-postgres-upgrade
```

Finalize the upgrade by switching swapping the databases:

```
cd /opt/docker/zulip
sudo mv postgresql postgresql10
sudo mv postgresql14 postgresql
```

Lastly, we must address the following issues:

1. Fix `port 5432 failed: FATAL:  no pg_hba.conf entry for host "192.168.144.5", user "zulip", database "zulip", no encryption` error by adding the following config for the new database:

```
sudo sh -c 'echo "host all all all scram-sha-256" >>/opt/docker/zulip/postgresql/data/pg_hba.conf'
```

2. Fix `connection to server at "database" (192.168.160.5), port 5432 failed: FATAL:  password authentication failed for user "zulip"`:

```
docker-compose up -d
docker-compose stop zulip
docker-compose exec database bash
export DATABASE_USER=zulip
export PASSWORD=******
psql -U zulip -c "ALTER ROLE $DATABASE_USER PASSWORD '$PASSWORD';"
exit
docker-compose down
```

Now everything is ready for Zulip 6 deployment. We can rebase our settings to 6.2-0 branch and deploy Zulip:

```
git checkout 6.2-0
git am V6.2-Our-setup.patch
docker-compose up -d
```

## References

1. [Docker版PostgreSQL升级迁移（慎用Watchtower更新基础服务）](https://blog.nigzu.com/docker-postgres-watchtower-upgrade/)
2. [10 to 11 role "postgres" does not exist](https://github.com/tianon/docker-postgres-upgrade/issues/10#issuecomment-625484344)

## TODO

```
postgres@2419d8f284cc:~$ cat delete_old_cluster.sh
#!/bin/sh

rm -rf '/var/lib/postgresql/10/data'

postgres@2419d8f284cc:~$ cat update_extensions.sql
\connect zulip
ALTER EXTENSION "pgroonga" UPDATE;
```
