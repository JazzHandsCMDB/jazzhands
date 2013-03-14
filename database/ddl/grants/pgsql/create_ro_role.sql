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
--  Read only role
-- $Id$
--




create role ro_role;
grant connect to ro_role;

grant select on all tables in schema audit to ro_role;
grant select on all tables in schema jazzhands to ro_role;
grant execute on all functions in schema net_manip to ro_role;
grant execute on all functions in schema netblock_utils to ro_role;
grant execute on all functions in schema network_strings to ro_role;

grant usage on schema time_util to ro_role;
grant usage on schema audit to ro_role;
grant usage on schema jazzhands to ro_role;
grant usage on schema net_manip to ro_role;
grant usage on schema netblock_utils to ro_role;
grant usage on schema network_strings to ro_role;
grant usage on schema time_util to ro_role;
