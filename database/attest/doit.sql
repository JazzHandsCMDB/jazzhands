\set ON_ERROR_STOP

\i create_tables.sql
\i pseudo_data.sql

grant select on all tables in schema jazzhands to ro_role;
grant insert,update,delete on all tables in schema jazzhands to iud_role;

\i approval_utils.sql

-- 
select nextval('approval_instance_link_approval_instance_link_id_seq');
select nextval('approval_instance_link_approval_instance_link_id_seq');
select nextval('approval_instance_link_approval_instance_link_id_seq');


select approval_utils.build_attest();

