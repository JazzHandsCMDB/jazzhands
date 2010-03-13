-- $HeadURL$
-- $Id$

set echo on
set termout on
set serveroutput on
select systimestamp from dual;
@@ddl/schema/create_schema.sql
@@ddl/schema/build_audit_tables.sql
-- (next item is generated above in the current directory)
@@generated_audit_tables.sql
@@ddl/schema/build_audit_triggers.sql
-- (next item generated above into the current directory)
@@generated_audit_triggers.sql
@@ddl/views/create_extra_views.sql
@@ddl/schema/create_audit_indexes.sql
@@ddl/schema/create_extra_objects.sql
@@pkg/create_all_packages.sql
@@ddl/schema/create_triggers.sql
select systimestamp from dual;
