/*
 * Copyright (c) 2013-2019 Todd Kover
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

\ir ddl/schema/pgsql/create_schema_support_tables.sql
\ir ddl/schema/pgsql/create_schema_support.sql
\ir ddl/schema/pgsql/create_schema_support_cache_tables.sql

\ir ddl/schema/pgsql/create_schema_pgsql.sql

CREATE SCHEMA jazzhands_audit;
COMMENT ON SCHEMA jazzhands_audit IS 'part of jazzhands project';


-- \ir ddl/schema/pgsql/build_audit_tables.sql
-- \ir ddl/schema/pgsql/build_ins_upd_triggers.sql

SELECT schema_support.rebuild_stamp_triggers('jazzhands'::text);
SELECT schema_support.build_audit_tables('jazzhands_audit'::text, 'jazzhands'::text);

CREATE SCHEMA jazzhands_cache;
COMMENT ON SCHEMA jazzhands_cache IS 'cache tables for jazzhands views';

\ir ddl/cache/create_cache_pgsql.sql

\ir pkg/pgsql/create_early_packages.sql

\ir ddl/views/create_extra_views_pgsql.sql

-- NEED TO PORT: @@ddl/schema/plpgsql/create_audit_indexes.sql

\ir ddl/schema/pgsql/create_extra_objects.sql

\ir pkg/pgsql/create_all_packages.sql

\ir ddl/schema/pgsql/postgres-json-schema/postgres-json-schema--0.1.0.sql

\ir ddl/schema/pgsql/create_account_coll_hier_triggers.sql
\ir ddl/schema/pgsql/create_account_triggers.sql
-- for now, need to do this after jazzhands_legacy is created.
\ir ddl/schema/pgsql/create_acct_coll_report_triggers.sql
\ir ddl/schema/pgsql/create_approval_triggers.sql
\ir ddl/schema/pgsql/create_auto_account_coll_triggers.sql
\ir ddl/schema/pgsql/create_collection_loop_triggers.sql
\ir ddl/schema/pgsql/create_collection_bytype_triggers.sql
\ir ddl/schema/pgsql/create_collection_type_property_triggers.sql
\ir ddl/schema/pgsql/create_company_coll_hier_triggers.sql
\ir ddl/schema/pgsql/create_company_triggers.sql
\ir ddl/schema/pgsql/create_component_triggers.sql
\ir ddl/schema/pgsql/create_device_coll_hier_triggers.sql
\ir ddl/schema/pgsql/create_device_triggers.sql
\ir ddl/schema/pgsql/create_device_type_triggers.sql
\ir ddl/schema/pgsql/create_device_type_triggers.sql
\ir ddl/schema/pgsql/create_dns_domain_coll_hier_triggers.sql
\ir ddl/schema/pgsql/create_dns_triggers.sql
\ir ddl/schema/pgsql/create_dns_triggers-RETIRE.sql
\ir ddl/schema/pgsql/create_layer3_network_triggers.sql
\ir ddl/schema/pgsql/create_layer2_network_coll_hier_triggers.sql
\ir ddl/schema/pgsql/create_layer2_network_coll_hier_triggers.sql
\ir ddl/schema/pgsql/create_layer3_network_coll_hier_triggers.sql
\ir ddl/schema/pgsql/create_layer3_network_coll_hier_triggers.sql
\ir ddl/schema/pgsql/create_legacy_port_triggers_RETIRE.sql
\ir ddl/schema/pgsql/create_netblock_coll_hier_triggers.sql
\ir ddl/schema/pgsql/create_netblock_triggers.sql
-- \ir ddl/schema/pgsql/create_netblock_triggers-RETIRE.sql
\ir ddl/schema/pgsql/create_layer3_interface_triggers.sql
\ir ddl/schema/pgsql/create_network_range_triggers.sql
\ir ddl/schema/pgsql/create_per_svc_env_coll_triggers.sql
\ir ddl/schema/pgsql/create_physical_conection_triggers.sql
\ir ddl/schema/pgsql/create_property_name_collection_hier_triggers.sql
\ir ddl/schema/pgsql/create_property_triggers.sql
\ir ddl/schema/pgsql/create_svcenv_coll_hier_triggers.sql
\ir ddl/schema/pgsql/create_token_coll_hier_triggers.sql
\ir ddl/schema/pgsql/create_triggers.sql
\ir ddl/schema/pgsql/create_v_corp_family_account_triggers.sql
\ir ddl/schema/pgsql/create_account_coll_realm_triggers.sql
\ir ddl/schema/pgsql/create_device_coll_hook_triggers.sql
\ir ddl/schema/pgsql/create_layer2_network_coll_hook_triggers.sql
\ir ddl/schema/pgsql/create_layer3_network_coll_hook_triggers.sql
\ir ddl/schema/pgsql/create_property_name_collection_hook_triggers.sql
\ir ddl/schema/pgsql/create_x509_triggers.sql
\ir ddl/schema/pgsql/create_account_coll_relation_triggers.sql
\ir ddl/schema/pgsql/create_x509_triggers-RETIRE.sql
\ir ddl/schema/pgsql/create_ip_universe_valid_triggers.sql
-- goes with the jazzhands_legacy schema
\ir ddl/schema/pgsql/create_jazzhands_legacy_triggers-RETIRE.sql

\ir ddl/schema/pgsql/create_site_netblock_triggers.sql
\ir ddl/schema/pgsql/create_network_range_triggers.sql

\ir ddl/schema/pgsql/create_person_company_attr_triggers.sql
\ir ddl/schema/pgsql/create_account_pgnotify_trigger.sql

\ir ddl/schema/pgsql/create_hotpants_view_triggers.sql
\ir ddl/schema/pgsql/create_v_person_company_triggers.sql

-- This could be done for backwards compatibility but is not.
-- \ir compat/pgsql/create_location_compatibility_view.sql

--
-- Backwards compatability for a few revisions
--
-- temporary comment out. This needs to be reconciled.
\ir ddl/legacy.sql
\ir ddl/legacy-audit.sql

\ir ddl/schema/pgsql/create_account_hook_triggers.sql
\ir ddl/schema/pgsql/create_person_company_attr_with_legacy.sql

select now();
