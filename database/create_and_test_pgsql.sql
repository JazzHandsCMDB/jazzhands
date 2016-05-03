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

--
-- This runs through and creates records, runs test and what not.  
--
-- It assumes the user 'jazzhands' owns the schema, and the database is named
-- jazzhands_new .
--
-- This resembles what one may do for creating a fresh install for production
-- use except in would probably be in the jazzhands database and not have the
-- tests run
--
-- this script is normally run cd'd into the directiory its run in and:
-- psql -e --user=postgres postgres -f create_and_test_pgsql.sql
--
\set ON_ERROR_STOP

select timeofday(), now();

select set_config('jazzhands.appuser', 'createtester', false);
SET client_encoding = 'UTF8';

alter user jazzhands set search_path = public,pg_catalog;

drop database IF EXISTS jazzhands_new;
create database jazzhands_new;
grant create on database jazzhands_new to jazzhands;

-- drop database feedlogs;
-- create database feedlogs;
grant create on database jazzhands_new to jazzhands;

\c jazzhands_new jazzhands;

\ir create_pgsql_schema.sql

\ir init/initialize_currencies.sql
\ir init/initialize_country_codes.sql
\ir init/initialize_jazzhands.sql
\ir init/initialize_component.sql

\ir init/initialize_jazzhands_optional.sql
-- \ir init/insert_blacklist.sql
-- \ir init/oracle/submit_scheduler.sql

-- Things that are only done in migrations
-- \ir compat/pgsql/create_location_compatibility_view.sql

-- Example Data is used by the tests

begin;

-- set search_path=public;
\ir init/initialize_jazzhands_example.sql
-- example insertions with some real life looking test data
\ir tests/init/insert_records.sql
\ir tests/init/insert_devices.sql
-- deprecated
-- \ir tests/init/insert_records_later.sql
\ir tests/init/test_netblock_collection.sql
\ir tests/pgsql/location_regression_test.sql
\ir tests/pgsql/netblock_regression_test.sql
-- \ir tests/pgsql/netblock_regression_test-RETIRE.sql
\ir tests/pgsql/dns_record_regression_test.sql
-- will be in a point release
\ir tests/pgsql/network_interface_regression_test.sql
\ir tests/pgsql/property_regression_test.sql
\ir tests/pgsql/device_ticket_regression.sql
\ir tests/pgsql/device_power_regression.sql


\ir tests/pgsql/account_coll_hier_regression.sql
\ir tests/pgsql/company_coll_hier_regression.sql
\ir tests/pgsql/device_coll_hier_regression.sql
\ir tests/pgsql/dns_domain_coll_hier_regression.sql
\ir tests/pgsql/layer2_network_coll_hier_regression.sql
\ir tests/pgsql/layer3_network_coll_hier_regression.sql
\ir tests/pgsql/netblock_coll_hier_regression.sql
\ir tests/pgsql/property_coll_hier_regression.sql
\ir tests/pgsql/svcenv_coll_hier_regression.sql
\ir tests/pgsql/token_coll_hier_regression.sql
\ir tests/pgsql/account_coll_realm_regression.sql
\ir tests/pgsql/network_range_tests.sql

\ir tests/pgsql/account_enabled_test.sql
-- \ir tests/pgsql/v_corp_family_account_trigger.sql

rollback;
-- RAISE EXCEPTION 'need to put transactions back in testing';

select timeofday(), now();
