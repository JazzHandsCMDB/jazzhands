
-- Copyright (c) 2018-2024, Todd Kover
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

\ir pgsql/create_ct_component_hier.sql
\ir pgsql/create_ct_device_components.sql

\ir pgsql/create_ct_netblock_hier.sql

--- These three are to be deleted once the "recurse" tables are deployed.
\ir pgsql/create_ct_account_collection_hier_from_ancestor.sql
\ir pgsql/create_ct_device_collection_hier_from_ancestor.sql
\ir pgsql/create_ct_netblock_collection_hier_from_ancestor.sql

\ir pgsql/create_ct_account_collection_hier_recurse.sql
\ir pgsql/create_ct_device_collection_hier_recurse.sql
\ir pgsql/create_ct_netblock_collection_hier_recurse.sql
\ir pgsql/create_ct_company_collection_hier_recurse.sql
\ir pgsql/create_ct_dns_domain_collection_hier_recurse.sql
\ir pgsql/create_ct_layer2_network_collection_hier_recurse.sql
\ir pgsql/create_ct_layer3_network_collection_hier_recurse.sql
\ir pgsql/create_ct_netblock_collection_hier_recurse.sql
\ir pgsql/create_ct_service_environment_collection_hier_recurse.sql
\ir pgsql/create_ct_service_version_collection_hier_recurse.sql
\ir pgsql/create_ct_token_collection_hier_recurse.sql

\ir pgsql/create_ct_property_name_collection_hier_recurse.sql

\ir pgsql/create_ct_jazzhands_legacy_device.sql
