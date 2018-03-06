/*
 * Copyright (c) 2011-2015 Matthew Ragan
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

CREATE OR REPLACE FUNCTION validate_property() RETURNS TRIGGER AS $$
BEGIN
	RETURN property_utils.validate_property(NEW);
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_property ON Property;
CREATE TRIGGER trigger_validate_property BEFORE INSERT OR UPDATE
	ON Property FOR EACH ROW EXECUTE PROCEDURE validate_property();


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
	IF NEW.property_data_type = 'json' AND NEW.property_value_json_schema IS NULL THEN
		RAISE 'property_data_type json requires a schema to be set'
			USING ERRCODE = 'invalid_parameter_value';
	ELSIF NEW.property_data_type != 'json' AND NEW.property_value_json_schema IS NOT NULL THEN
		RAISE 'property_data_type % may not have a json schema set',
			NEW.property_data_type
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF TG_OP = 'UPDATE' AND OLD.property_data_type != NEW.property_data_type THEN
		SELECT	count(*)
		INTO	_tally
		WHERE	property_name = NEW.property_name
		AND		property_type = NEW.property_type;

		IF _tally > 0  THEN
			RAISE 'May not change property type if there are existing proeprties'
				USING ERRCODE = 'foreign_key_violation';

		END IF;
	END IF;

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
