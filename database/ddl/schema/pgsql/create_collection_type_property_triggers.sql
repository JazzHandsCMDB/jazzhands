/*
 * Copyright (c) 2015 Todd Kover
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

-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION validate_account_collection_type_change()
RETURNS TRIGGER AS $$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.account_collection_type != NEW.account_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.account_collection_type = OLD.account_collection_type
		AND	p.account_collection_id = NEW.account_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'account_collection % of type % is used by % restricted properties.',
				NEW.account_collection_id, NEW.account_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_account_collection_type_change
	ON account_collection;
CREATE TRIGGER trigger_validate_account_collection_type_change
	BEFORE UPDATE OF account_collection_type
	ON account_collection
	FOR EACH ROW
	EXECUTE PROCEDURE validate_account_collection_type_change();

-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION validate_company_collection_type_change()
RETURNS TRIGGER AS $$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.company_collection_type != NEW.company_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.company_collection_type = OLD.company_collection_type
		AND	p.company_collection_id = NEW.company_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'company_collection % of type % is used by % restricted properties.',
				NEW.company_collection_id, NEW.company_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_company_collection_type_change
	ON company_collection;
CREATE TRIGGER trigger_validate_company_collection_type_change
	BEFORE UPDATE OF company_collection_type
	ON company_collection
	FOR EACH ROW
	EXECUTE PROCEDURE validate_company_collection_type_change();

-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION validate_device_collection_type_change()
RETURNS TRIGGER AS $$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.device_collection_type != NEW.device_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.device_collection_type = OLD.device_collection_type
		AND	p.device_collection_id = NEW.device_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'device_collection % of type % is used by % restricted properties.',
				NEW.device_collection_id, NEW.device_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_device_collection_type_change
	ON device_collection;
CREATE TRIGGER trigger_validate_device_collection_type_change
	BEFORE UPDATE OF device_collection_type
	ON device_collection
	FOR EACH ROW
	EXECUTE PROCEDURE validate_device_collection_type_change();


-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION validate_dns_domain_collection_type_change()
RETURNS TRIGGER AS $$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.dns_domain_collection_type != NEW.dns_domain_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.dns_domain_collection_type = OLD.dns_domain_collection_type
		AND	p.dns_domain_collection_id = NEW.dns_domain_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'dns_domain_collection % of type % is used by % restricted properties.',
				NEW.dns_domain_collection_id, NEW.dns_domain_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_dns_domain_collection_type_change
	ON dns_domain_collection;
CREATE TRIGGER trigger_validate_dns_domain_collection_type_change
	BEFORE UPDATE OF dns_domain_collection_type
	ON dns_domain_collection
	FOR EACH ROW
	EXECUTE PROCEDURE validate_dns_domain_collection_type_change();


-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION validate_layer2_network_collection_type_change()
RETURNS TRIGGER AS $$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.layer2_network_collection_type != NEW.layer2_network_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.layer2_network_collection_type = OLD.layer2_network_collection_type
		AND	p.layer2_network_collection_id = NEW.layer2_network_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'layer2_network_collection % of type % is used by % restricted properties.',
				NEW.layer2_network_collection_id, NEW.layer2_network_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_layer2_network_collection_type_change
	ON layer2_network_collection;
CREATE TRIGGER trigger_validate_layer2_network_collection_type_change
	BEFORE UPDATE OF layer2_network_collection_type
	ON layer2_network_collection
	FOR EACH ROW
	EXECUTE PROCEDURE validate_layer2_network_collection_type_change();


-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION validate_layer3_network_collection_type_change()
RETURNS TRIGGER AS $$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.layer3_network_collection_type != NEW.layer3_network_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.layer3_network_collection_type = OLD.layer3_network_collection_type
		AND	p.layer3_network_collection_id = NEW.layer3_network_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'layer3_network_collection % of type % is used by % restricted properties.',
				NEW.layer3_network_collection_id, NEW.layer3_network_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_layer3_network_collection_type_change
	ON layer3_network_collection;
CREATE TRIGGER trigger_validate_layer3_network_collection_type_change
	BEFORE UPDATE OF layer3_network_collection_type
	ON layer3_network_collection
	FOR EACH ROW
	EXECUTE PROCEDURE validate_layer3_network_collection_type_change();


-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION validate_netblock_collection_type_change()
RETURNS TRIGGER AS $$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.netblock_collection_type != NEW.netblock_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.netblock_collection_type = OLD.netblock_collection_type
		AND	p.netblock_collection_id = NEW.netblock_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'netblock_collection % of type % is used by % restricted properties.',
				NEW.netblock_collection_id, NEW.netblock_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_netblock_collection_type_change
	ON netblock_collection;
CREATE TRIGGER trigger_validate_netblock_collection_type_change
	BEFORE UPDATE OF netblock_collection_type
	ON netblock_collection
	FOR EACH ROW
	EXECUTE PROCEDURE validate_netblock_collection_type_change();


-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION validate_property_collection_type_change()
RETURNS TRIGGER AS $$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.property_collection_type != NEW.property_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.property_collection_type = OLD.property_collection_type
		AND	p.property_collection_id = NEW.property_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'property_collection % of type % is used by % restricted properties.',
				NEW.property_collection_id, NEW.property_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_property_collection_type_change
	ON property_collection;
CREATE TRIGGER trigger_validate_property_collection_type_change
	BEFORE UPDATE OF property_collection_type
	ON property_collection
	FOR EACH ROW
	EXECUTE PROCEDURE validate_property_collection_type_change();


-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION validate_service_env_collection_type_change()
RETURNS TRIGGER AS $$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.service_env_collection_type != NEW.service_env_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.service_env_collection_type = OLD.service_env_collection_type
		AND	p.service_env_collection_id = NEW.service_env_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'service_env_collection % of type % is used by % restricted properties.',
				NEW.service_env_collection_id, NEW.service_env_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_service_env_collection_type_change
	ON service_environment_collection;
CREATE TRIGGER trigger_validate_service_env_collection_type_change
	BEFORE UPDATE OF service_env_collection_type
	ON service_environment_collection
	FOR EACH ROW
	EXECUTE PROCEDURE validate_service_env_collection_type_change();

