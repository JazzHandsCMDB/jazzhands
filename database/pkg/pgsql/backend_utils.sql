/*
 * Copyright (c) 2016 Todd Kover
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

/*
 * $Id$
 */

\set ON_ERROR_STOP

-- Create schema if it does not exist, do nothing otherwise.
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'backend_utils';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS backend_utils;
		CREATE SCHEMA backend_utils AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA backend_utils IS 'part of jazzhands';
	END IF;
END;
$$;

		COMMENT ON SCHEMA backend_utils IS 'part of jazzhands';
------------------------------------------------------------------------------

--
-- used to trigger refreshes of materialized views
--
CREATE OR REPLACE FUNCTION backend_utils.refresh_if_needed(object text)
RETURNS void AS
$$
DECLARE
	rk char;
BEGIN
	SELECT  relkind
	INTO    rk
	FROM    pg_catalog.pg_class c
		JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
	WHERE   n.nspname = 'jazzhands'
	AND     c.relname = object;

	-- silently ignore things that are not materialized views
	IF rk = 'm' THEN
		PERFORM schema_support.refresh_mv_if_needed(object, 'jazzhands');
	END IF;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

--
-- returns the last time an object was changed, based on audit tables, either
-- for the object itself in the case of tables, or dependent objects, in the
-- case of materialized views and views.
--
CREATE OR REPLACE FUNCTION backend_utils.relation_last_changed(view text)
RETURNS timestamp AS
$$
BEGIN
	RETURN schema_support.relation_last_changed(view);
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

grant select on all tables in schema backend_utils to iud_role;
grant usage on schema backend_utils to iud_role;
revoke all on schema backend_utils from public;
revoke all on  all functions in schema backend_utils from public;
grant execute on all functions in schema backend_utils to iud_role;

