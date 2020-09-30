-- Copyright (c) 2017, Matthew Ragan
-- All rights reserved.
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--       http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

DO $$
DECLARE
        _tal INTEGER;
BEGIN
        select count(*)
        from pg_catalog.pg_namespace
        into _tal
        where nspname = 'component_connection_utils';
        IF _tal = 0 THEN
                DROP SCHEMA IF EXISTS component_connection_utils;
                CREATE SCHEMA component_connection_utils AUTHORIZATION jazzhands;
		REVOKE ALL ON SCHEMA component_connection_utils FROM public;
                COMMENT ON SCHEMA component_connection_utils IS 'part of jazzhands';
        END IF;
END;
$$;

CREATE OR REPLACE FUNCTION component_connection_utils.create_inter_component_connection (
	device_id			INOUT jazzhands.device.device_id%TYPE,
	slot_name			INOUT jazzhands.slot.slot_name%TYPE,
	remote_slot_name	INOUT jazzhands.slot.slot_name%TYPE,
	remote_device_id	INOUT jazzhands.device.device_id%TYPE DEFAULT NULL,
	remote_host_id		jazzhands.device.host_id%TYPE DEFAULT NULL,
	remote_device_name	jazzhands.device.device_name%TYPE DEFAULT NULL,
	force				boolean DEFAULT false,
	inter_component_connection_id	OUT integer,
	slot_id							OUT integer,
	slot_index						OUT integer,
	mac_address						OUT macaddr,
	slot_type_id					OUT integer,
	slot_type						OUT text,
	slot_function					OUT text,
	remote_slot_id					OUT integer,
	remote_slot_index				OUT integer,
	remote_mac_address				OUT macaddr,
	remote_slot_type_id				OUT integer,
	remote_slot_type				OUT text,
	remote_slot_function			OUT text,
	changed							OUT boolean
) RETURNS SETOF RECORD AS $$
DECLARE
	remote_dev_rec		RECORD;
	slot_rec			RECORD;
	remote_slot_rec		RECORD;
	_device_id			ALIAS FOR device_id;
	_slot_name			ALIAS FOR slot_name;
	_remote_slot_name	ALIAS FOR remote_slot_name;
	_remote_device_id	ALIAS FOR remote_device_id;
	_remote_host_id		ALIAS FOR remote_host_id;
	_remote_device_name	ALIAS FOR remote_device_name;
BEGIN
	--
	-- Validate what's passed
	--
	IF remote_device_id IS NULL AND remote_host_id IS NULL AND
		remote_device_name IS NULL
	THEN
		RAISE 'Must pass remote_device_id, remote_host_id, or remote_device_name to create_inter_component_connection()' 
			USING ERRCODE = 'null_value_not_allowed';
	END IF;

	--
	-- For selecting a device, prefer passed device_id
	--
	IF remote_device_id IS NOT NULL THEN
		SELECT
			d.device_id,
			d.device_name,
			d.host_id
		INTO remote_dev_rec
		FROM
			device d
		WHERE
			d.device_id = remote_device_id;

		IF NOT FOUND THEN
			RETURN;
		END IF;
	ELSIF remote_device_name IS NOT NULL THEN
		BEGIN
			SELECT
				d.device_id,
				d.device_name,
				d.host_id
			INTO STRICT remote_dev_rec
			FROM
				device d
			WHERE
				device_name = remote_device_name AND
				device_status != 'removed';
		EXCEPTION
			WHEN NO_DATA_FOUND THEN RETURN;
			WHEN TOO_MANY_ROWS THEN
				RAISE EXCEPTION 'Multiple devices have device_name %',
					remote_device_name;
		END;
	ELSIF remote_host_id IS NOT NULL THEN
		BEGIN
			SELECT
				d.device_id,
				d.device_name,
				d.host_id
			INTO STRICT remote_dev_rec
			FROM
				device d
			WHERE
				host_id = remote_host_id AND
				device_status != 'removed';
		EXCEPTION
			WHEN NO_DATA_FOUND THEN RETURN;
			WHEN TOO_MANY_ROWS THEN
				RAISE EXCEPTION 'Multiple devices have host_id %',
					remote_host_id;
		END;
	END IF;

	RAISE DEBUG 'Remote device is %', row_to_json(remote_dev_rec, true);
	--
	-- Now look to make sure both slots exist and whether there is a current
	-- connection for the remote side
	--

	SELECT
		*
	INTO
		slot_rec
	FROM
		jazzhands.v_device_slot_connections dsc
	WHERE
		dsc.device_id = _device_id AND
		dsc.slot_name = _slot_name AND
		dsc.slot_function = 'network';

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Network slot % does not exist on device %',
			_slot_name,
			_device_id;
	END IF;

	RAISE DEBUG 'Local slot is %', row_to_json(slot_rec, true);
	
	SELECT
		*
	INTO
		remote_slot_rec
	FROM
		jazzhands.v_device_slot_connections dsc
	WHERE
		dsc.device_id = remote_dev_rec.device_id AND
		dsc.slot_name = _remote_slot_name AND
		dsc.slot_function = 'network';

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Network slot % does not exist on device %',
			_slot_name,
			_device_id;
	END IF;

	RAISE DEBUG 'Remote slot is %', row_to_json(remote_slot_rec, true);
	
	--
	-- See if these are already connected
	--
	IF slot_rec.inter_component_connection_id = 
		remote_slot_rec.inter_component_connection_id
	THEN
		inter_component_connection_id := slot_rec.inter_component_connection_id;
		slot_id := slot_rec.slot_id;
		slot_name := slot_rec.slot_name;
		slot_index := slot_rec.slot_index;
		mac_address := slot_rec.mac_address;
		slot_type_id := slot_rec.slot_type_id;
		slot_type := slot_rec.slot_type;
		slot_function := slot_rec.slot_function;
		remote_device_id := slot_rec.remote_device_id;
		remote_slot_id := slot_rec.remote_slot_id;
		remote_slot_name := slot_rec.remote_slot_name;
		remote_slot_index := slot_rec.remote_slot_index;
		remote_mac_address := slot_rec.remote_mac_address;
		remote_slot_type_id := slot_rec.remote_slot_type_id;
		remote_slot_type := slot_rec.remote_slot_type;
		remote_slot_function := slot_rec.remote_slot_function;
		changed := false;
		RETURN NEXT;
		RETURN;
	END IF;

	--
	-- See if we can create a new connection
	--
	IF remote_slot_rec.inter_component_connection_id IS NOT NULL THEN
		IF
			force OR
			remote_host_id = remote_dev_rec.host_id
		THEN
			DELETE FROM
				inter_component_connection icc
			WHERE
				icc.inter_component_connection_id = 
					remote_slot_rec.inter_component_connection_id;
		ELSE
			RAISE EXCEPTION 'Slot % for device % is already connected to slot % on device %',
				remote_slot_rec.slot_name,
				remote_slot_rec.device_id,
				remote_slot_rec.remote_slot_name,
				remote_slot_rec.remote_device_id;
			RETURN;
		END IF;
	END IF;

	IF slot_rec.inter_component_connection_id IS NOT NULL THEN
		DELETE FROM
			inter_component_connection icc
		WHERE
			icc.inter_component_connection_id = 
				slot_rec.inter_component_connection_id;
	END IF;

	INSERT INTO inter_component_connection (
		slot1_id,
		slot2_id
	) VALUES (
		slot_rec.slot_id,
		remote_slot_rec.slot_id
	);

	SELECT
		* INTO slot_rec
	FROM
		jazzhands.v_device_slot_connections dsc
	WHERE
		dsc.slot_id = slot_rec.slot_id;
		
	inter_component_connection_id := slot_rec.inter_component_connection_id;
	slot_id := slot_rec.slot_id;
	slot_name := slot_rec.slot_name;
	slot_index := slot_rec.slot_index;
	mac_address := slot_rec.mac_address;
	slot_type_id := slot_rec.slot_type_id;
	slot_type := slot_rec.slot_type;
	slot_function := slot_rec.slot_function;
	remote_device_id := slot_rec.remote_device_id;
	remote_slot_id := slot_rec.remote_slot_id;
	remote_slot_name := slot_rec.remote_slot_name;
	remote_slot_index := slot_rec.remote_slot_index;
	remote_mac_address := slot_rec.remote_mac_address;
	remote_slot_type_id := slot_rec.remote_slot_type_id;
	remote_slot_type := slot_rec.remote_slot_type;
	remote_slot_function := slot_rec.remote_slot_function;
	changed := true;
	RETURN NEXT;
	RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

REVOKE ALL ON SCHEMA component_connection_utils FROM public;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA component_connection_utils FROM public;

GRANT USAGE ON SCHEMA component_connection_utils TO iud_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA component_connection_utils TO iud_role;
