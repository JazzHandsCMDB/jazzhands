-- $HeadURL$
-- $Id$

set echo on
set termout on
set serveroutput on
select systimestamp from dual;
@@ddl/schema/oracle/create_schema.sql
@@ddl/schema/oracle/build_audit_tables.sql
-- (next item is generated above in the current directory)
@@generated_audit_tables.sql
@@ddl/schema/oracle/build_audit_triggers.sql
-- (next item generated above into the current directory)
@@generated_audit_triggers.sql
@@pkg/oracle/create_early_packages.sql
-- split out into oracle and common
@@ddl/views/oracle/create_oracle_views.sql
@@ddl/views/create_extra_views_oracle.sql
--
@@ddl/schema/oracle/create_audit_indexes.sql
@@ddl/schema/oracle/create_extra_objects.sql
@@pkg/oracle/create_all_packages.sql
@@ddl/schema/oracle/create_triggers.sql
select systimestamp from dual;
