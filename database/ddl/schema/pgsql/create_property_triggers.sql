/*
 * Copyright (c) 2011-2015 Matthew Ragan
 * Copyright (c) 2012-2021 Todd Kover
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

CREATE OR REPLACE FUNCTION validate_property() RETURNS TRIGGER AS $$
BEGIN
	RETURN property_utils.validate_property(NEW);
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_property ON property;
CREATE CONSTRAINT TRIGGER trigger_validate_property
	AFTER INSERT OR UPDATE
	ON property FOR EACH ROW
	EXECUTE PROCEDURE validate_property();


------------------------------------------------------------------------------
--
-- val_property validations
--
-- XXX should probably check all the various fields
--
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION validate_val_property() RETURNS TRIGGER AS $$
DECLARE
	_tally	INTEGER;
BEGIN

	PERFORM property_utils.validate_val_property(NEW);

	IF TG_OP = 'INSERT' AND NEW.permit_company_id != 'PROHIBITED' OR
		( TG_OP = 'UPDATE' AND NEW.permit_company_id != 'PROHIBITED' AND
			OLD.permit_company_id IS DISTINCT FROM NEW.permit_company_id )
	THEN
		RAISE 'property.company_id is being retired.  Please use per-company collections'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trigger_validate_val_property ON val_property;
CREATE TRIGGER trigger_validate_val_property
	BEFORE INSERT OR UPDATE OF property_data_type, property_value_json_schema,
		permit_company_id
	ON val_property
	FOR EACH ROW
	EXECUTE PROCEDURE validate_val_property();

CREATE OR REPLACE FUNCTION validate_val_property_after() RETURNS TRIGGER AS $$
DECLARE
	_r	property%ROWTYPE;
BEGIN
	FOR _r IN SELECT * FROM property
		WHERE property_name = NEW.property_name
		AND property_type = NEW.property_type
	LOOP
		PERFORM property_utils.validate_property(_r);
	END LOOP;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_val_property_after ON val_property;
CREATE CONSTRAINT TRIGGER trigger_validate_val_property_after
	AFTER UPDATE
	ON val_property
	DEFERRABLE INITIALLY IMMEDIATE
	FOR EACH ROW
	EXECUTE PROCEDURE validate_val_property_after();

------------------------------------------------------------------------------
--
-- val_property_value check
--
--
------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION val_property_value_del_check()
RETURNS TRIGGER AS $$
DECLARE
	_tal	INTEGER;
BEGIN

	SELECT COUNT(*)
	INTO _tal
	FROM property p
	WHERE p.property_name = OLD.property_name
	AND p.property_type = OLD.property_type
	AND p.property_value = OLD.valid_property_value;

	IF _tal > 0 THEN
		RAISE EXCEPTION '% instances of %:% with value %',
			_tal, OLD.property_type, OLD.property_name, OLD.valid_property_value
			USING ERRCODE = 'foreign_key_violation';
	END IF;

	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

--
-- CONSTRAINT makes this an after trigger.
--
DROP TRIGGER IF EXISTS trigger_val_property_value_del_check
	ON val_property_value;
CREATE CONSTRAINT TRIGGER trigger_val_property_value_del_check
	AFTER DELETE
	ON val_property_value
	DEFERRABLE INITIALLY IMMEDIATE
	FOR EACH ROW
	EXECUTE PROCEDURE val_property_value_del_check();

