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

-- Create schema if it does not exist, do nothing otherwise.
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'script_hooks';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS script_hooks;
		CREATE SCHEMA script_hooks AUTHORIZATION jazzhands;
		REVOKE ALL ON SCHEMA script_hooks FROM public;
		COMMENT ON SCHEMA script_hooks IS 'part of jazzhands';

	END IF;
END;
$$;


-------------------------------------------------------------------
-- returns the Id tag for CM
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION script_hooks.id_tag()
RETURNS VARCHAR AS $$
BEGIN
	RETURN('<-- $Id$ -->');
END;
$$ LANGUAGE plpgsql;
--end of procedure id_tag
-------------------------------------------------------------------

-------------------------------------------------------------------
--begin script_hooks.mkpasswdfiles_pre
-- run before mkpasswdfiles does any real work
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION script_hooks.mkpasswdfiles_pre (
) RETURNS void AS $$
BEGIN
	BEGIN
		PERFORM local_hooks.mkpasswdfiles_pre();
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end of script_hooks.mkpasswdfiles_pre
-------------------------------------------------------------------
-------------------------------------------------------------------
--begin script_hooks.mkpasswdfiles_post
-- run after mkpasswdfiles does work, before commit
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION script_hooks.mkpasswdfiles_post (
) RETURNS void AS $$
BEGIN
	BEGIN
		PERFORM local_hooks.mkpasswdfiles_post();
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end of script_hooks.mkpasswdfiles_post
-------------------------------------------------------------------

-------------------------------------------------------------------
--begin script_hooks.zonegen_pre
-- run before zonegen does any real work
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION script_hooks.zonegen_pre (
) RETURNS void AS $$
BEGIN
	BEGIN
		PERFORM local_hooks.zonegen_pre();
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end of script_hooks.zonegen_pre
-------------------------------------------------------------------
-------------------------------------------------------------------
--begin script_hooks.zonegen_post
-- run after zonegen does work, before commit
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION script_hooks.zonegen_post (
) RETURNS void AS $$
BEGIN
	BEGIN
		PERFORM local_hooks.zonegen_post();
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end of script_hooks.zonegen_post
-------------------------------------------------------------------

REVOKE ALL ON SCHEMA script_hooks FROM public;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA script_hooks FROM public;

GRANT USAGE ON SCHEMA script_hooks TO iud_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA script_hooks TO iud_role;
