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

---------------------------------------------------------------------------
-- deal with device.asset_id going away - device
---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_asset_id_fix()
RETURNS TRIGGER AS $$
DECLARE
	v_asset	asset%ROWTYPE;
BEGIN
	IF TG_OP = 'INSERT' AND 
				NEW.asset_id IS NULL AND 
				NEW.component_id IS NULL THEN
		RETURN NEW;
	ELSIF ( TG_OP = 'UPDATE' AND 
				OLD.asset_id IS NOT DISTINCT FROM NEW.asset_id AND
				OLD.component_id IS NOT DISTINCT FROM NEW.component_id ) THEN
		RETURN NEW;
	END IF;

	IF NEW.asset_id IS NULL and NEW.component_id IS NOT NULL THEN
		SELECT a.asset_id
		INTO	NEW.asset_id
		FROM	asset a
		WHERE	a.component_id = NEW.component_id;
	ELSIF NEW.asset_id IS NOT NULL and NEW.component_id IS NULL THEN
		SELECT a.component_id
		INTO	NEW.component_id
		FROM	asset a
		WHERE	a.asset_id = NEW.asset_id;
	END IF;

	IF TG_OP = 'UPDATE' AND NEW.asset_id IS NOT NULL AND 
			OLD.component_id IS DISTINCT FROM NEW.component_id AND
			OLD.asset_id IS NOT DISTINCT FROM NEW.asset_id THEN
		SELECT	asset_id
		INTO	NEW.asset_id
		FROM	asset
		WHERE	component_id = NEW.component_id;

		IF NEW.asset_id IS NULL THEN
			RAISE 'If component id changes, there must be an asset for the new component' 
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	-- UPDATE asset a
	-- SET	component_id = NEW.component_id
	-- WHERE a.asset_id = NEW.asset_id
	-- AND a.component_id IS DISTINCT FROM NEW.component_id;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS aaa_trigger_device_asset_id_fix
	ON device;
CREATE TRIGGER aaa_trigger_device_asset_id_fix
	BEFORE INSERT OR UPDATE OF asset_id, component_id
	ON device
	FOR EACH ROW
	EXECUTE PROCEDURE device_asset_id_fix();

---------------------------------------------------------------------------
-- deal with device.asset_id going away - asset
---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION asset_component_id_fix()
RETURNS TRIGGER AS $$
DECLARE
	_tal INTEGER;
BEGIN
	IF TG_OP = 'INSERT' AND NEW.component_id IS NULL THEN
		RETURN NEW;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.component_id IS NOT NULL THEN
			IF OLD.asset_id != NEW.asset_id THEN
				RAISE 'Asset id may not change for now' USING
				ERRCODE = 'invalid_parameter_value';
			END IF;
		END IF;
		IF OLD.component_id IS NOT DISTINCT FROM NEW.component_id THEN
			RETURN NEW;
		END IF;
	END IF;

	--
	-- component id was changed to NULL, so clear from device
	--
	IF TG_OP = 'INSERT' THEN
		UPDATE device
		SET asset_id = NEW.asset_id
		WHERE component_id = NEW.component_id;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.component_id IS NULL THEN
			UPDATE device d
			SET component_id = NEW.component_id
			WHERE asset_id = NEW.asset_id
			AND NEW.component_id IS DISTINCT FROM d.component_id;
		ELSE		-- IF NEW.component_id IS NOT NULL THEN
			IF OLD.component_id IS NOT NULL THEN
				SELECT count(*)
				INTO	_tal
				FROM	device d
				WHERE	d.component_id = OLD.component_id
				OR		d.component_id = NEW.component_id;

				IF _tal > 1 THEN
					RAISE EXCEPTION 'This component already has a device.'
						USING ERRCODE = 'invalid_parameter_value';
				END IF;
			END IF;

			UPDATE device d
			SET component_id = NEW.component_id
			WHERE d.asset_id = NEW.asset_id 
			AND NEW.component_id IS DISTINCT FROM d.component_id;
		END IF;
	END IF;

	UPDATE device d
	SET	asset_id = NEW.asset_id
	WHERE d.component_id = NEW.component_id
	AND d.asset_id IS DISTINCT FROM NEW.asset_id;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS aaa_trigger_asset_component_id_fix
	ON asset;
CREATE TRIGGER aaa_trigger_asset_component_id_fix
	AFTER INSERT OR UPDATE OF component_id, asset_id
	ON asset
	FOR EACH ROW
	EXECUTE PROCEDURE asset_component_id_fix();
