/*
 * Copyright (c) 2023 Todd Kover
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


CREATE OR REPLACE FUNCTION check_component_type_device_virtual_match()
RETURNS TRIGGER AS $$
BEGIN
	PERFORM *
	FROM device
	JOIN component USING (component_id)
	WHERE is_virtual_device != NEW.is_virtual_component;

	IF FOUND THEN
		RAISE EXCEPTION 'There are devices with a component of this type that do not match is_virtual_component'
			USING ERRCODE = 'foreign_key_violation';
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_check_component_type_device_virtual_match
	ON component_type;
CREATE CONSTRAINT TRIGGER trigger_check_component_type_device_virtual_match
AFTER UPDATE OF is_virtual_component
ON component_type
FOR EACH ROW EXECUTE PROCEDURE check_component_type_device_virtual_match();

-----------------------------------------------------------------------

CREATE OR REPLACE FUNCTION check_device_component_type_virtual_match()
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.component_id IS NOT NULL THEN
		PERFORM *
		FROM component c
		JOIN component_type ct USING (component_type_id)
		WHERE c.component_id = NEW.component_id
		AND NEW.is_virtual_device != ct.is_virtual_component;

		IF FOUND THEN
			RAISE EXCEPTION 'There are devices with a component of this type that do not match is_virtual_component'
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_check_device_component_type_virtual_match
	ON device;
CREATE CONSTRAINT TRIGGER trigger_check_device_component_type_virtual_match
AFTER INSERT OR UPDATE OF is_virtual_device
ON device
FOR EACH ROW EXECUTE PROCEDURE check_device_component_type_virtual_match();
