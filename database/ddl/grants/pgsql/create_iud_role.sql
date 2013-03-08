-- Copyright (c) 2012 Todd M. Kover
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
--
--  Insert Update Delete role
-- $Id$
--



create role iud_role;
grant connect to iud_role;

grant ro_role to iud_role;

grant insert,update,delete on all tables in schema jazzhands to iud_role;
grant select,update on all sequences in schema jazzhands to iud_role;

grant execute on all functions in schema person_manip to iud_role;
grant execute on all functions in schema port_support to iud_role;
grant execute on all functions in schema port_utils to iud_role;
