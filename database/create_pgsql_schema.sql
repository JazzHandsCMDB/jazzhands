-- $HeadURL$
-- $Id$

-- set echo on
-- set termout on
-- set serveroutput on
select now();

\i ddl/schema/pgsql/create_schema_support.sql

\i ddl/schema/pgsql/create_schema_pgsql.sql

CREATE SCHEMA audit;

-- \i ddl/schema/pgsql/build_audit_tables.sql
-- \i ddl/schema/pgsql/build_ins_upd_triggers.sql

SELECT schema_support.rebuild_stamp_triggers('jazzhands');
SELECT schema_support.build_audit_tables('audit', 'jazzhands');

\cd pkg/pgsql
\i create_early_packages.sql
\cd ../..

\cd ddl/views
\i create_extra_views_pgsql.sql
\cd ../..

-- NEED TO PORT: @@ddl/schema/plpgsql/create_audit_indexes.sql

\i ddl/schema/pgsql/create_extra_objects.sql

\cd pkg/pgsql
\i create_all_packages.sql
\cd ../..

\i ddl/schema/pgsql/create_triggers.sql
\i ddl/schema/pgsql/create_netblock_triggers.sql
\i ddl/schema/pgsql/create_device_type_triggers.sql
\i ddl/schema/pgsql/create_device_triggers.sql
\i ddl/schema/pgsql/create_per_svc_env_coll_triggers.sql
\i ddl/schema/pgsql/create_dns_triggers.sql
\i ddl/schema/pgsql/create_device_type_triggers.sql
\i ddl/schema/pgsql/create_auto_account_coll_triggers.sql
select now();
