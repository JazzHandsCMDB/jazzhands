\pager off
\set ON_ERROR_STOP

\c - postgres
DO $$
BEGIN
	CREATE ROLE dba SUPERUSER NOINHERIT;
EXCEPTION WHEN duplicate_object THEN
	RAISE NOTICE 'dba already exists';
END;
$$;
grant dba to cloudapi;

\c - jazzhands
\set ON_ERROR_STOP
begin;

-- same as what would be in 
-- \i ddl-only.sql
\i schema.sql
\i data.sql

commit;

\c - postgres
\set ON_ERROR_STOP
begin;
\i setup.sql
commit;

\c - maestro_v2
\set ON_ERROR_STOP
begin;
\i maestro_jazz.sql
\i maestro-environment.sql
\i maestro-application.sql
commit;
\c - jazzhands
\set ON_ERROR_STOP

SELECT schema_support.reset_table_sequence(
	schema := 'jazzhands',
	table_name := 'service'
);

SELECT schema_support.reset_table_sequence(
	schema := 'jazzhands',
	table_name := 'service_environment'
);

SELECT schema_support.reset_table_sequence(
	schema := 'jazzhands',
	table_name := 'service_environment_collection'
);

\c - cloudapi
\set ON_ERROR_STOP

begin;
\i all-lbgslb.sql
commit;
\c - jazzhands
\set ON_ERROR_STOP
begin;
\i fks.sql

\i jazzhands-db.sql
\i stab.sql
\i recursing-dns.sql
\i obs-frontend.sql

\i xen.sql
\i kvm.sql

\c - postgres
begin;
SET search_path=jazzhands,cloudapi;
\i consolidate-puppet4.sql

commit;
\c - jazzhands
\i helpful-queries.sql
commit;

\c - postgres
revoke dba from cloudapi;
\pager on
