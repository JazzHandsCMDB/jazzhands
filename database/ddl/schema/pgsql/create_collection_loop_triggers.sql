/*
 * Copyright (c) 2012-2015 Todd Kover
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
 * Do not let hierarchy point to itself.  This shoudl probably be extended
 * to check up/down the hierarchy to prevent loops.  Needs to be ported to
 * oracle XXX
 */

CREATE OR REPLACE FUNCTION check_account_colllection_hier_loop()
	RETURNS TRIGGER AS $$
BEGIN
	IF NEW.account_collection_id = NEW.child_account_collection_id THEN
		RAISE EXCEPTION 'Account Collection Loops Not Pernitted '
			USING ERRCODE = 20704;	/* XXX */
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_check_account_collection_hier_loop
	ON account_collection_hier;
CREATE TRIGGER trigger_check_account_collection_hier_loop
AFTER INSERT OR UPDATE ON account_collection_hier
	FOR EACH ROW EXECUTE PROCEDURE check_account_colllection_hier_loop();

/*
 * Do not let hierarchy point to itself.  This shoudl probably be extended
 * to check up/down the hierarchy to prevent loops.  Needs to be ported to
 * oracle XXX
 */
CREATE OR REPLACE FUNCTION check_netblock_colllection_hier_loop()
	RETURNS TRIGGER AS $$
BEGIN
	IF NEW.netblock_collection_id = NEW.child_netblock_collection_id THEN
		RAISE EXCEPTION 'Netblock Collection Loops Not Pernitted '
			USING ERRCODE = 20704;	/* XXX */
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_check_netblock_collection_hier_loop
	ON netblock_collection_hier;
CREATE TRIGGER trigger_check_netblock_collection_hier_loop
AFTER INSERT OR UPDATE ON netblock_collection_hier
	FOR EACH ROW EXECUTE PROCEDURE check_netblock_colllection_hier_loop();

/*
 * Do not let hierarchy point to itself.  This shoudl probably be extended
 * to check up/down the hierarchy to prevent loops.  Needs to be ported to
 * oracle XXX
 */
CREATE OR REPLACE FUNCTION check_device_colllection_hier_loop()
	RETURNS TRIGGER AS $$
BEGIN
	IF NEW.device_collection_id = NEW.parent_device_collection_id THEN
		RAISE EXCEPTION 'device Collection Loops Not Pernitted '
			USING ERRCODE = 20704;	/* XXX */
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_check_device_collection_hier_loop
	ON device_collection_hier;
CREATE TRIGGER trigger_check_device_collection_hier_loop
AFTER INSERT OR UPDATE ON device_collection_hier
	FOR EACH ROW EXECUTE PROCEDURE check_device_colllection_hier_loop();

/*
 * Do not let hierarchy point to itself.  This shoudl probably be extended
 * to check up/down the hierarchy to prevent loops.  Needs to be ported to
 * oracle XXX
 */
CREATE OR REPLACE FUNCTION check_token_colllection_hier_loop()
	RETURNS TRIGGER AS $$
BEGIN
	IF NEW.token_collection_id = NEW.child_token_collection_id THEN
		RAISE EXCEPTION 'token Collection Loops Not Pernitted '
			USING ERRCODE = 20704;	/* XXX */
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_check_token_collection_hier_loop
	ON token_collection_hier;
CREATE TRIGGER trigger_check_token_collection_hier_loop
AFTER INSERT OR UPDATE ON token_collection_hier
	FOR EACH ROW EXECUTE PROCEDURE check_token_colllection_hier_loop();


/*
 * Do not let hierarchy point to itself.  This shoudl probably be extended
 * to check up/down the hierarchy to prevent loops.  Needs to be ported to
 * oracle XXX
 */
CREATE OR REPLACE FUNCTION check_svcenv_colllection_hier_loop()
	RETURNS TRIGGER AS $$
BEGIN
	IF NEW.service_env_collection_id =
		NEW.child_service_env_coll_id THEN
			RAISE EXCEPTION 'svcenv Collection Loops Not Pernitted '
			USING ERRCODE = 20704;	/* XXX */
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_check_svcenv_collection_hier_loop
	ON service_environment_coll_hier;
CREATE TRIGGER trigger_check_svcenv_collection_hier_loop
AFTER INSERT OR UPDATE ON service_environment_coll_hier
	FOR EACH ROW EXECUTE PROCEDURE check_svcenv_colllection_hier_loop();

