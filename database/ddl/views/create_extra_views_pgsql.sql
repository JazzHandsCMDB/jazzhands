-- Copyright (c) 2005-2010, Vonage Holdings Corp.
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--     * Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--     * Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
-- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--

-- Copyright (c) 2018, Matthew Ragan
-- Copyright (c) 2010-2023 Toed M. Kover
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

\ir pgsql/create_v_property.sql
\ir pgsql/create_v_netblock_collection_netblock_expanded.sql
\ir pgsql/create_v_person_company_expanded.sql
-- \ir pgsql/create_v_acct_collection_user_expanded_detail.sql

\ir create_token_views.sql
-- not sure that we need these anymore.

-- XXX - not sure if this is still needed.  Leaving out until it is.

-- components

\ir pgsql/create_device_management_controller.sql

\ir pgsql/create_v_device_slots.sql
\ir pgsql/create_v_device_components_expanded.sql
\ir pgsql/create_v_device_components_json.sql
\ir pgsql/create_v_device_component_summary.sql

\ir pgsql/create_v_account_collection_account.sql
\ir pgsql/create_v_account_collection_expanded.sql
\ir pgsql/create_v_account_collection_account_expanded.sql

\ir pgsql/create_v_device_slot_connections.sql

\ir pgsql/create_v_device_collection_device_expanded.sql
\ir pgsql/create_v_account_collection_account.sql

\ir pgsql/create_v_netblock_collection_expanded.sql

\ir pgsql/create_v_application_role.sql

\ir pgsql/create_v_company_hier.sql
\ir create_site_netblock.sql
\ir pgsql/create_v_site_netblock_expanded.sql
\ir create_v_site_netblock_expanded_assigned.sql
\ir pgsql/create_v_netblock_hier.sql
\ir pgsql/create_v_netblock_hier_expanded.sql
\ir pgsql/create_v_physical_connection.sql

\ir create_v_corp_family_account.sql

\ir pgsql/create_v_person_company_hier.sql
\ir create_v_person.sql
\ir create_v_account_name.sql

\ir create_v_account_manager_map.sql
\ir pgsql/create_v_account_manager_hier.sql
\ir approval/create_approval_views.sql
-- not clear if this belongs in the approval views or not.  probably?
\ir pgsql/create_v_approval_instance_step_expanded.sql

\ir pgsql/create_v_layer2_network_collection_expanded.sql
\ir pgsql/create_v_layer3_network_collection_expanded.sql
\ir pgsql/create_v_layerx_network_expanded.sql
\ir pgsql/create_v_network_range_expanded.sql

\ir pgsql/create_v_source_repository_uri.sql
\ir pgsql/create_v_service_source_repository_uri.sql
\ir create_v_service_endpoint_service_instance.sql
\ir create_v_service_endpoint_expanded.sql
