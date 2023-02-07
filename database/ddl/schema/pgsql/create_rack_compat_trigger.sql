/* * Copyright (c) 2023 Todd Kover
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



CREATE OR REPLACE FUNCTION sync_device_rack_location_id()
RETURNS TRIGGER AS $$
DECLARE
	_id	INTEGER;
BEGIN
	IF pg_trigger_depth() >= 2 THEN
		RETURN NEW;
	END IF;
	IF TG_OP = 'INSERT' THEN
		IF NEW.component_id IS NOT NULL AND NEW.rack_location_id IS NOT NULL THEN
			UPDATE component c
			SET rack_location_id = NEW.rack_location_id
			WHERE c.rack_location_id IS DISTINCT FROM NEW.rack_location_id
			AND c.component_id = NEW.component_id;
		ELSIF NEW.rack_location_id IS NULL THEN
			SELECT rack_location_id
			INTO _id
			FROM component c
			WHERE c.component_id = NEW.component_id;
			NEW.rack_location_id := _id;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.component_id IS NULL THEN
			IF OLD.component_id IS NOT NULL THEN
				UPDATE component c
				SET rack_location_id = NULL
				WHERE c.rack_location_id  IS NOT NULL
				AND c.component_id = OLD.component_id;
			END IF;

			NEW.rack_location_id = NULL;
		ELSE
			UPDATE component
			SET rack_location_id = NEW.rack_location_id
			WHERE component_id = NEW.component_id
			AND rack_location_id IS DISTINCT FROM NEW.rack_location_id;
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_sync_device_rack_location_id ON device;
CREATE TRIGGER trigger_sync_device_rack_location_id
BEFORE INSERT OR UPDATE OF rack_location_id, component_id
ON device
FOR EACH ROW EXECUTE PROCEDURE sync_device_rack_location_id();

CREATE OR REPLACE FUNCTION sync_component_rack_location_id()
RETURNS TRIGGER AS $$
BEGIN
	IF pg_trigger_depth() >= 2 THEN
		RETURN NEW;
	END IF;
	IF OLD.component_id != NEW.component_id THEN
		UPDATE device d
		SET rack_location_id = NULL
		WHERE d.component_id = OLD.component_id
		AND d.rack_location_id IS NOT NULL;
	END IF;

	UPDATE device d
	SET rack_location_id = NEW.rack_location_id
	WHERE d.rack_location_id IS DISTINCT FROM NEW.rack_location_id
	AND d.component_id = NEW.component_id;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_sync_component_rack_location_id ON component;
CREATE TRIGGER trigger_sync_component_rack_location_id
AFTER UPDATE OF rack_location_id
ON component
FOR EACH ROW EXECUTE PROCEDURE sync_component_rack_location_id();
