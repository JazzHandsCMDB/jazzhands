-- Copyright (c) 2015, Todd M. Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--       http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

\set ON_ERROR_STOP

drop schema IF EXISTS approval_utils cascade;

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

