-- $HeadURL$
-- $Id$

-- set echo on
-- set termout on
-- set serveroutput on
select now();

\i ddl/schema/pgsql/create_schema_pgsql.sql
\i ddl/schema/pgsql/build_audit_tables.sql


\cd pkg/pgsql
\i create_early_packages.sql
\cd ../..

\cd ddl/views
\i create_extra_views_pgsql.sql
\cd ../..

-- NEED TO PORT: @@ddl/schema/plpgsql/create_audit_indexes.sql

-- PROBABLY NOT APPLICABLE:: ddl/schema/create_extra_objects.sql

\cd pkg/pgsql
\i create_all_packages.sql
\cd ../..

\i ddl/schema/pgsql/create_triggers.sql
select now();
