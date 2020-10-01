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
		REVOKE ALL ON schema backend_utils FROM public;
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

------------------------------------------------------------------------------
--
-- returns the last time an object was changed, based on audit tables, either
-- for the object itself in the case of tables, or dependent objects, in the
-- case of materialized views and views.
--
CREATE OR REPLACE FUNCTION backend_utils.relation_last_changed(
	view TEXT,
	schema TEXT DEFAULT 'jazzhands_legacy'
) RETURNS timestamp AS
$$
BEGIN
	RETURN schema_support.relation_last_changed(view, schema);
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

------------------------------------------------------------------------------
--
-- returns an opque identifier that can be passed to the next function
--
-- returns NULL if this is not possible, which means you're already connected
-- to a ro slave.
-- 
--
CREATE OR REPLACE FUNCTION backend_utils.get_opaque_txid()
RETURNS text AS
$$
DECLARE
	rv	text;
BEGIN
	SELECT txid_current()::text INTO rv;
	RETURN rv;
EXCEPTION WHEN read_only_sql_transaction THEN
	RETURN NULL;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

------------------------------------------------------------------------------
--
-- wait for the opaque id from previous call to show up on system.  If
-- passed a NULL, returns immediately, otherwise returns when transaction
-- id is available.  Will wait indefinitely unless second argument is
-- passed.
--
-- returns false if it was definitely not applied, true if it was applied or
-- if connected to ro slave.
-- 
--
CREATE OR REPLACE FUNCTION backend_utils.block_for_opaque_txid(
	opaqueid text,
	maxdelay integer DEFAULT NULL
) RETURNS boolean AS
$$
DECLARE
	count	integer;
BEGIN
	IF opaqueid IS NULL THEN
		RETURN true;
	END IF;
	count := 0;
	WHILE maxdelay IS NULL OR count < maxdelay 
	LOOP
		IF txid_visible_in_snapshot(opaqueid::bigint,txid_current_snapshot()) THEN
			RETURN true;
		END IF;
		count := count + 1;
		PERFORM pg_sleep(1);
	END LOOP;
	RETURN false;
END;
$$ 
SET search_path=pg_catalog
LANGUAGE plpgsql SECURITY DEFINER;

------------------------------------------------------------------------------
REVOKE ALL ON schema backend_utils FROM public;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA backend_utils FROM public;

GRANT USAGE ON SCHEMA backend_utils TO iud_role;
GRANT SELECT ON ALL TABLES IN SCHEMA backend_utils TO iud_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA backend_utils TO iud_role;
