/*
 * Copyright (c) 2016-2024 Todd Kover
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
-- $HeadURL$
-- $Id$
--


-- Create schema if it does not exist, do nothing otherwise.
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'schema_support';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS schema_support;
		CREATE SCHEMA schema_support AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA schema_support IS 'part of jazzhands';

	END IF;
END;
$$;

--
-- These tables are meant to be used solely by schema_support functions.
--
CREATE TABLE schema_support.schema_audit_map (
	schema	text,
	audit_schema text,
	primary key(schema, audit_schema)
);

CREATE TABLE schema_support.mv_refresh (
	schema	text,
	view 	text,
	refresh	timestamp,
	primary key(schema, view)
);


CREATE TABLE schema_support.schema_version (
	schema	text,
	version	text,
	primary key(schema)
);

CREATE TABLE schema_support.cache_table (
	cache_table_schema		text	NOT NULL,
	cache_table				text	NOT NULL,
	defining_view_schema	text	NOT NULL,
	defining_view			text	NOT NULL,
	updates_enabled			boolean	NOT NULL,
	create_options			jsonb,
	PRIMARY KEY (cache_table_schema, cache_table)
);

CREATE TABLE schema_support.cache_table_update_log (
	cache_table_schema		text	NOT NULL,
	cache_table				text	NOT NULL,
	update_timestamp		timestamp with time zone NOT NULL,
	rows_inserted			integer	NOT NULL,
	rows_deleted			integer	NOT NULL,
	forced					boolean NOT NULL
);

