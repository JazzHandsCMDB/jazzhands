/*
 * Copyright (c) 2022 Todd Kover
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

--
-- This view is slated to go away after its use is removed from provisioning
--

CREATE OR REPLACE FUNCTION device_management_controller_ins()
RETURNS TRIGGER AS $$
DECLARE
	_c		jazzhands.component_management_controller.component_id%TYPE;
	_mc		jazzhands.component_management_controller.component_id%TYPE;
	_cmc	jazzhands.component_management_controller%ROWTYPE;
BEGIN
	SELECT	component_id
	INTO	_c
	FROM	device
	WHERE	device_id IS NOT DISTINCT FROM NEW.device_id;

	IF _c IS NULL THEN
			RAISE EXCEPTION 'device_id may not be NULL or there is no component associated with the device.'
			USING ERRCODE = 'not_null_violation';
	END IF;

	SELECT	component_id
	INTO	_mc
	FROM	device
	WHERE	device_id IS NOT DISTINCT FROM NEW.manager_device_id;

	IF _mc IS NULL THEN
			RAISE EXCEPTION 'manager_device_id may not be NULL or there is no component associated with the device.'
			USING ERRCODE = 'not_null_violation';
	END IF;

	INSERT INTO component_management_controller (
		manager_component_id, component_id,
		component_management_controller_type, description
	) VALUES (
		_mc, _c,
		NEW.device_management_control_type, NEW.description
	) RETURNING * INTO _cmc;

	NEW.data_ins_user := _cmc.data_ins_user;
	NEW.data_ins_date := _cmc.data_ins_date;
	NEW.data_upd_user := _cmc.data_upd_user;
	NEW.data_upd_date := _cmc.data_upd_date;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_device_management_controller_ins ON
	device_management_controller;

CREATE TRIGGER trigger_device_management_controller_ins
	INSTEAD OF INSERT ON device_management_controller
	FOR EACH ROW
	EXECUTE PROCEDURE device_management_controller_ins();

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION device_management_controller_upd()
RETURNS TRIGGER AS $$
DECLARE
	upd_query	TEXT[];
	_c			jazzhands.component_management_controller.component_id%TYPE;
	_oc			jazzhands.component_management_controller.component_id%TYPE;
	_omc		jazzhands.component_management_controller.component_id%TYPE;
	_cmc		jazzhands.component_management_controller%ROWTYPE;
BEGIN
	upd_query := NULL;
	IF OLD.device_id IS DISTINCT FROM NEW.device_id THEN
		SELECT	component_id
		INTO	_c
		FROM	device
		WHERE	device_id IS NOT DISTINCT FROM NEW.device_id;

		IF _c IS NULL THEN
				RAISE EXCEPTION 'device_id may not be NULL or there is no component associated with the device.'
				USING ERRCODE = 'not_null_violation';
		END IF;

		upd_query := array_append(upd_query,
			'component_id = ' || quote_nullable(_c));
	END IF;

	IF OLD.manager_device_id IS DISTINCT FROM NEW.manager_device_id THEN
		SELECT	component_id
		INTO	_c
		FROM	device
		WHERE	device_id IS NOT DISTINCT FROM NEW.manager_device_id;

		IF _c IS NULL THEN
				RAISE EXCEPTION 'manager_device_id may not be NULL or there is no component associated with the device.'
				USING ERRCODE = 'not_null_violation';
		END IF;

		upd_query := array_append(upd_query,
			'manager_component_id = ' || quote_nullable(_c));
	END IF;

	IF NEW.description IS DISTINCT FROM OLD.description THEN
		upd_query := array_append(upd_query,
		'description = ' || quote_nullable(NEW.description));
	END IF;

	IF NEW.device_management_control_type IS DISTINCT FROM OLD.device_management_control_type THEN
		upd_query := array_append(upd_query,
		'component_management_controller_type = ' || quote_nullable(NEW.device_management_control_type));
	END IF;

	IF upd_query IS NOT NULL THEN
		SELECT component_id INTO _cmc.component_id
		FROM device WHERE device_id = OLD.device_id;

		SELECT component_id INTO _cmc.manager_component_id
		FROM device WHERE device_id = OLD.manager_device_id;

		EXECUTE 'UPDATE component_management_controller SET ' ||
			array_to_string(upd_query, ', ') ||
			' WHERE component_id = $1 AND manager_component_id = $2 RETURNING *'
			USING _cmc.component_id, _cmc.manager_component_id
			INTO _cmc;

		NEW.device_management_control_type	= _cmc.component_management_controller_type;
	  	NEW.description					= _cmc.description;

		NEW.data_ins_user := _cmc.data_ins_user;
		NEW.data_ins_date := _cmc.data_ins_date;
		NEW.data_upd_user := _cmc.data_upd_user;
		NEW.data_upd_date := _cmc.data_upd_date;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_device_management_controller_upd ON
	device_management_controller;

CREATE TRIGGER trigger_device_management_controller_upd
	INSTEAD OF UPDATE ON device_management_controller
	FOR EACH ROW
	EXECUTE PROCEDURE device_management_controller_upd();

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION device_management_controller_del()
RETURNS TRIGGER AS $$
DECLARE
	_c			jazzhands.component_management_controller.component_id%TYPE;
	_mc			jazzhands.component_management_controller.component_id%TYPE;
	_cmc		jazzhands.component_management_controller%ROWTYPE;
BEGIN
	SELECT	component_id
	INTO	_c
	FROM	device
	WHERE	device_id = OLD.device_id;

	SELECT	component_id
	INTO	_mc
	FROM	device
	WHERE	device_id = OLD.manager_device_id;

	DELETE FROM component_management_controller
	WHERE component_id IS NOT DISTINCT FROM  _c
	AND manager_component_id IS NOT DISTINCT FROM _mc
	RETURNING * INTO _cmc;

	OLD.device_management_control_type	= _cmc.component_management_controller_type;
	OLD.description					= _cmc.description;

	OLD.data_ins_user := _cmc.data_ins_user;
	OLD.data_ins_date := _cmc.data_ins_date;
	OLD.data_upd_user := _cmc.data_upd_user;
	OLD.data_upd_date := _cmc.data_upd_date;

	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_device_management_controller_del ON
	device_management_controller;

CREATE TRIGGER trigger_device_management_controller_del
	INSTEAD OF DELETE ON device_management_controller
	FOR EACH ROW
	EXECUTE PROCEDURE device_management_controller_del();

---------------------------------------------------------------------------
---------------------------------------------------------------------------
