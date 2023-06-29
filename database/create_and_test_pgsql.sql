/*
 * Copyright (c) 2013-2022 Todd Kover
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
-- It assumes the user 'jazzhands' owns the schema, and the database is the
-- one to which you initially connect (it will switch to template1 before
-- making it happen.
--
-- This resembles what one may do for creating a fresh install for production
-- use except in would probably be in the jazzhands database and not have the
-- tests run
--
-- this script is normally run cd'd into the directiory its run in and:
-- psql -e --user=postgres postgres -f create_and_test_pgsql.sql
--
\set ON_ERROR_STOP

\pset pager off

select timeofday(), now();

--
-- The relevant places will succeed regardless of if pl/perl is available,
-- only using if it if's there.  This being set to true will cause the
-- process to die if the pl/perl bits are not configured right, any other
-- setting will cause it to silently not do pl/perl things.
-- 
-- It is set here so that all the tests run with and without pl/perl.
--
\set global_failonnoplperl true

--
-- make everything
--

\ir create_pgsql_from_scratch.sql

--
-- Everything aftrer this is a test
--

-- end pl/perlmagic

begin;

-- set search_path=public;
\ir init/initialize_jazzhands_example.sql
-- example insertions with some real life looking test data
\ir tests/init/insert_records.sql
\ir tests/init/insert_devices.sql
-- deprecated
-- \ir tests/init/insert_records_later.sql
\ir tests/init/test_netblock_collection.sql

-- rudimentary
\ir tests/pgsql/schema_support.sql

\ir tests/pgsql/location_regression_test.sql
\ir tests/pgsql/netblock_regression_test.sql
\ir tests/pgsql/dns_record_regression_test.sql
\ir tests/pgsql/ip_universe_validation_regression.sql
\ir tests/pgsql/netblock_defaults_regression.sql
-- will be in a point release
\ir tests/pgsql/layer3_interface_regression_test.sql
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
\ir tests/pgsql/x509_tests.sql
\ir tests/pgsql/devices_regression.sql

\ir tests/pgsql/ct_netblock_tests.sql
\ir tests/pgsql/ct_site_netblock_tests.sql
\ir tests/pgsql/ct_account_collection_tests_ancestor.sql
\ir tests/pgsql/ct_netblock_collection_tests_ancestor.sql
\ir tests/pgsql/ct_device_collection_tests_ancestor.sql

\ir tests/pgsql/account_enabled_test.sql
\ir tests/pgsql/approval_process_regression.sql
\ir tests/pgsql/port_range_checks.sql
\ir tests/pgsql/service_base_regression.sql
\ir tests/pgsql/source_repository_triggers.sql
\ir tests/pgsql/service_relationship_triggers.sql
\ir tests/pgsql/service_manip_tests.sql
\ir tests/pgsql/filesystem_logical_volume_tests.sql
\ir tests/pgsql/storage_tests.sql
\ir tests/pgsql/dns_child_zone_checks.sql
\ir tests/pgsql/encryption_key_tests.sql

\ir tests/pgsql/dns_domain_regression_test.sql
-- \ir tests/pgsql/v_corp_family_account_trigger.sql

\ir tests/pgsql/device_management_controller_regression.sql
\ir tests/pgsql/scsi_id_compat_regression.sql

savepoint preplperl;
DROP SCHEMA IF EXISTS x509_plperl_cert_utils CASCADE;
\ir tests/pgsql/x509_tests.sql
rollback to preplperl;


rollback;

-- now run all the tests from the last version against jazhands_legacy
begin;

set search_path=jazzhands_legacy;

\ir init/initialize_jazzhands_example.sql
\ir tests/pgsql/jhlegacy/insert_records.sql
\ir tests/pgsql/jhlegacy/insert_devices.sql
\ir tests/pgsql/jhlegacy/test_netblock_collection.sql
\ir tests/pgsql/jhlegacy/location_regression_test.sql
\ir tests/pgsql/jhlegacy/netblock_regression_test.sql
\ir tests/pgsql/jhlegacy/dns_record_regression_test.sql
\ir tests/pgsql/jhlegacy/ip_universe_validation_regression.sql
\ir tests/pgsql/jhlegacy/netblock_defaults_regression.sql
\ir tests/pgsql/jhlegacy/network_interface_regression_test.sql
\ir tests/pgsql/jhlegacy/property_regression_test.sql
\ir tests/pgsql/jhlegacy/device_ticket_regression.sql
\ir tests/pgsql/jhlegacy/device_power_regression.sql
\ir tests/pgsql/jhlegacy/account_coll_hier_regression.sql
\ir tests/pgsql/jhlegacy/company_coll_hier_regression.sql
\ir tests/pgsql/jhlegacy/device_coll_hier_regression.sql
\ir tests/pgsql/jhlegacy/dns_domain_coll_hier_regression.sql
\ir tests/pgsql/jhlegacy/dns_domain_name_tests-RETIRE.sql
\ir tests/pgsql/jhlegacy/v_dns_domain_nouniverse_regression.sql
\ir tests/pgsql/jhlegacy/layer2_network_coll_hier_regression.sql
\ir tests/pgsql/jhlegacy/layer3_network_coll_hier_regression.sql
\ir tests/pgsql/jhlegacy/netblock_coll_hier_regression.sql
\ir tests/pgsql/jhlegacy/property_coll_hier_regression.sql
\ir tests/pgsql/jhlegacy/svcenv_coll_hier_regression.sql
\ir tests/pgsql/jhlegacy/token_coll_hier_regression.sql
\ir tests/pgsql/jhlegacy/account_coll_realm_regression.sql
\ir tests/pgsql/jhlegacy/network_range_tests.sql
-- the bits in here are in the process of being retired
-- \ir tests/pgsql/jhlegacy/x509_tests.sql
\ir tests/pgsql/jhlegacy/x509_certificate.sql
\ir tests/pgsql/jhlegacy/v_person_company_regression.sql
\ir tests/pgsql/jhlegacy/account_enabled_test.sql
\ir tests/pgsql/jhlegacy/devices_regression.sql
\ir tests/pgsql/jhlegacy/x509_tests.sql
\ir tests/pgsql/jhlegacy/deprecated_x509_tests.sql

\ir tests/pgsql/jhlegacy/device_management_controller_regression.sql

\ir tests/pgsql/jhlegacy/jazzhands_legacy_device.sql

set search_path=jazzhands;

savepoint preplperl;
DROP SCHEMA IF EXISTS x509_plperl_cert_utils CASCADE;
set search_path=jazzhands_legacy;
\ir tests/pgsql/jhlegacy/x509_certificate.sql
\ir tests/pgsql/jhlegacy/deprecated_x509_tests.sql
set search_path=jazzhands;
rollback to preplperl;

rollback;

select timeofday(), now();
