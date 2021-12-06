-- Copyright (c) 2021, Todd M. Kover
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

\set ON_ERROR_STOP

DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'versioning_utils';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS versioning_utils;
		CREATE SCHEMA versioning_utils AUTHORIZATION jazzhands;
		REVOKE ALL ON SCHEMA versioning_utils FROM public;
		COMMENT ON SCHEMA versioning_utils IS 'part of jazzhands';
	END IF;
END;
$$;

------------------------------------------------------------------------------
--
-- checks to see if the best-guess schema version is satisfied
--
------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION versioning_utils.check_schema_version (
	version			TEXT,
	schema			TEXT DEFAULT NULL,
	raise_exception BOOLEAN DEFAULT true
) RETURNS boolean AS
$$
BEGIN
	RETURN schema_support.check_schema_version(
		version := version,
		schema := schema,
		raise_exception := raise_exception
	);
END;
$$
-- setting a search_path messes with the function, so do not.
SECURITY DEFINER
LANGUAGE plpgsql;

REVOKE ALL ON SCHEMA versioning_utils FROM public;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA versioning_utils FROM public;

GRANT ALL ON SCHEMA versioning_utils TO iud_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA versioning_utils TO iud_role;
