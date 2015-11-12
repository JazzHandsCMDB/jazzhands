/*
 * Copyright (c) 2013-2015 Todd Kover
 * All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

-- $HeadURL$
-- $Id$

-- set echo on
-- set termout on
-- set serveroutput on
select now();

\i ddl/schema/pgsql/create_schema_support.sql

\i ddl/schema/pgsql/create_schema_pgsql.sql

CREATE SCHEMA audit;
COMMENT ON SCHEMA audit IS 'part of jazzhands project';


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
\i ddl/schema/pgsql/create_collection_loop_triggers.sql
\i ddl/schema/pgsql/create_account_triggers.sql
\i ddl/schema/pgsql/create_property_triggers.sql
\i ddl/schema/pgsql/create_netblock_triggers.sql
-- \i ddl/schema/pgsql/create_netblock_triggers-RETIRE.sql
\i ddl/schema/pgsql/create_device_type_triggers.sql
\i ddl/schema/pgsql/create_device_triggers.sql
\i ddl/schema/pgsql/create_per_svc_env_coll_triggers.sql
\i ddl/schema/pgsql/create_dns_triggers.sql
\i ddl/schema/pgsql/create_network_interface_triggers.sql
\i ddl/schema/pgsql/create_network_interface_triggers_RETIRE.sql
\i ddl/schema/pgsql/create_device_type_triggers.sql
\i ddl/schema/pgsql/create_auto_account_coll_triggers.sql
\i ddl/schema/pgsql/create_acct_coll_report_triggers.sql
\i ddl/schema/pgsql/create_device_coll_hier_triggers.sql
\i ddl/schema/pgsql/create_property_coll_hier_triggers.sql
\i ddl/schema/pgsql/create_account_coll_hier_triggers.sql
\i ddl/schema/pgsql/create_netblock_coll_hier_triggers.sql
\i ddl/schema/pgsql/create_token_coll_hier_triggers.sql
\i ddl/schema/pgsql/create_svcenv_coll_hier_triggers.sql
\i ddl/schema/pgsql/create_v_corp_family_account_triggers.sql
\i ddl/schema/pgsql/create_component_triggers.sql
\i ddl/schema/pgsql/create_approval_triggers.sql
\i ddl/schema/pgsql/create_legacy_port_triggers_RETIRE.sql
\i ddl/schema/pgsql/create_physical_conection_triggers.sql
\i ddl/schema/pgsql/create_physical_conection_triggers_RETIRE.sql

-- This could be done for backwards compatibility but is not.
-- \i compat/pgsql/create_location_compatibility_view.sql
select now();
