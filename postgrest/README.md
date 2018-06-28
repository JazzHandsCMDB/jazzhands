# PostgREST on JazzHands

## Setting up the DB foo

All SQL scripts should be run from the src/sql directory

Bootstrap the DDL using the bootstrap script

```shell
psql -h <DBHOST> -d jazzhands < bootstrap.sql
```

You'll need to set a password for the authenticator role, it will be used when configuring puppet to deploy PostgREST endpoints

```sql
jazzhands=# ALTER USER postgrest_api_authenticator PASSWORD '<PASSWORD>';
```

## Cleaning up

Remove everything using cleanup

```shell
psql -h <DBHOST> -d jazzhands < cleanup.sql
```