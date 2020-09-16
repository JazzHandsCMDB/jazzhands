/*
 * Copyright (c) 2013-2020 Todd Kover
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

\set new_db_name :DBNAME
SET v.dbname TO :'new_db_name';
DO $$
BEGIN
	IF current_setting('v.dbname') ~ '^(public|template|postgres)' THEN
		RAISE EXCEPTION 'May not name the database %', current_setting('v.dbname');
	END IF;
END;
$$;

\c template1

select set_config('jazzhands.appuser', 'createtester', false);
SET client_encoding = 'UTF8';

alter user jazzhands set search_path = public,pg_catalog;

DROP DATABASE IF EXISTS :new_db_name;
CREATE DATABASE :new_db_name OWNER jazzhands;

\c :new_db_name

-- arguably should revoke public access to pgcrypto here but it
-- may already exist.  Tricky if it's not in a pgcrypto schema.
DO $$
BEGIN
	CREATE SCHEMA pgcrypto;
	CREATE EXTENSION IF NOT EXISTS pgcrypto WITH schema pgcrypto;
EXCEPTION WHEN duplicate_schema THEN
	NULL;
END;
$$;


\c :new_db_name jazzhands;

\ir create_pgsql_schema.sql

\ir init/initialize_currencies.sql
\ir init/initialize_country_codes.sql
\ir init/initialize_jazzhands.sql
\ir init/initialize_component.sql

-- goes away wtih jazzhands_legacy
\ir init/initialize_legacy.sql

\ir init/initialize_jazzhands_optional.sql
-- \ir init/insert_blacklist.sql
-- \ir init/oracle/submit_scheduler.sql

-- Things that are only done in migrations
-- \ir compat/pgsql/create_location_compatibility_view.sql

-- Example Data is used by the tests
GRANT USAGE ON SCHEMA schema_support TO schema_owners;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA schema_support TO schema_owners;

select timeofday(), now();
