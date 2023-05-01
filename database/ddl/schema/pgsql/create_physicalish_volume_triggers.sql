/*
 * Copyright (c) 2023 Todd Kover
 * All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *	  http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

-------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION physicalish_volume_ins() RETURNS TRIGGER AS $$
DECLARE
	_cid		component.component_id%TYPE;
	_c			component%ROWTYPE;
	_bsd		block_storage_device%ROWTYPE;
BEGIN
	IF NEW.logical_volume_id IS NOT NULL THEN
		IF NEW.component_id IS NOT NULL THEN
			RAISE EXCEPTION
				'May not set both logical_volume_id and component_id'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
		INSERT INTO component ( component_type_id )
			SELECT component_type_id
			FROM component_type
			WHERE model = 'Virtual Disk'
			AND is_virtual_component
			ORDER BY component_type_id lIMIT 1
		RETURNING * INTO _c;

		_cid := _c.component_id;

		INSERT INTO virtual_component_logical_volume (
			component_id, component_type_id, is_virtual_component,
		logical_volume_id
		) VALUES (
			_c.component_id, _c.component_type_id, true,
			NEW.logical_volume_id
		);


		INSERT INTO component_property (
			component_id, component_property_type,
			component_property_name, property_value
		) SELECT _c.component_id, 'disk',
			logical_volume_property_name, logical_volume_property_value
		FROM logical_volume_property
		WHERE  logical_volume_id = NEW.logical_volume_id
		AND logical_volume_property_name = 'SCSI_Id';
	ELSE
		_cid := NULL;
	END IF;

	INSERT INTO block_storage_device (
	   	block_storage_device_name,
	   	block_storage_device_type,
	   	device_id,
	   	component_id
	) VALUES (
		NEW.physicalish_volume_name,
		NEW.physicalish_volume_type,
		NEW.device_id,
		coalesce(NEW.component_id, _cid)
	) RETURNING * INTO _bsd;

	NEW.physicalish_volume_id	:= _bsd.block_storage_device_id;
	NEW.physicalish_volume_name	:= _bsd.block_storage_device_name;
	NEW.physicalish_volume_type	:= _bsd.block_storage_device_type;
	NEW.device_id				:= _bsd.device_id;

	NEW.data_ins_user 			:= _bsd.data_ins_user;
	NEW.data_ins_date 			:= _bsd.data_ins_date;
	NEW.data_upd_user 			:= _bsd.data_upd_user;
	NEW.data_upd_date 			:= _bsd.data_upd_date;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_physicalish_volume_ins
	ON physicalish_volume;
CREATE TRIGGER trigger_physicalish_volume_ins
	INSTEAD OF INSERT ON physicalish_volume
	FOR EACH ROW
	EXECUTE PROCEDURE physicalish_volume_ins();

-------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION physicalish_volume_upd() RETURNS TRIGGER AS $$
DECLARE
	_n			block_storage_device%ROWTYPE;
	upd_query	TEXT[];
BEGIN
	IF NEW.logical_volume_id IS NOT NULL THEN
		IF NEW.component_id IS NOT NULL THEN
			RAISE EXCEPTION
				'May not set both logical_volume_id and component_id'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF OLD.logical_volume_id IS DISTINCT FROM NEW.logical_volume_id THEN
			RAISE EXCEPTION
				'May not change logical_volume_id'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	upd_query := NULL;
	IF OLD.physicalish_volume_id IS DISTINCT FROM NEW.physicalish_volume_id
	THEN
		upd_query := array_append(upd_query,
			'block_storage_device_id = ' || quote_nullable(NEW.physicalish_volume_id));
	END IF;
	IF OLD.physicalish_volume_name IS DISTINCT FROM NEW.physicalish_volume_name
	THEN
		upd_query := array_append(upd_query,
			'block_storage_device_name = ' || quote_nullable(NEW.physicalish_volume_name));
	END IF;
	IF OLD.physicalish_volume_type IS DISTINCT FROM NEW.physicalish_volume_type
	THEN
		upd_query := array_append(upd_query,
			'block_storage_device_type = ' || quote_nullable(NEW.physicalish_volume_type));
	END IF;
	IF OLD.device_id IS DISTINCT FROM NEW.device_id
	THEN
		upd_query := array_append(upd_query,
			'device_id = ' || quote_nullable(NEW.device_id));
	END IF;
	IF OLD.component_id IS DISTINCT FROM NEW.component_id
	THEN
		upd_query := array_append(upd_query,
			'component_id = ' || quote_nullable(NEW.component_id));
	END IF;

	IF upd_query IS NOT NULL THEN
		EXECUTE 'UPDATE block_storage_device SET ' ||
			array_to_string(upd_query, ', ') ||
			' WHERE block_storage_device_id = $1 RETURNING *'
			USING NEW.physicalish_volume_id
			INTO _n;

		NEW.physicalish_volume_id	:= _n.block_storage_device_id;
		NEW.physicalish_volume_name	:= _n.block_storage_device_name;
		NEW.physicalish_volume_type	:= _n.block_storage_device_type;
		NEW.device_id				:= _n.device_id;
		NEW.component_id			:= _n.component_id;

		NEW.data_ins_user 			:= _n.data_ins_user;
		NEW.data_ins_date 			:= _n.data_ins_date;
		NEW.data_upd_user 			:= _n.data_upd_user;
		NEW.data_upd_date 			:= _n.data_upd_date;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_physicalish_volume_upd
	ON physicalish_volume;
CREATE TRIGGER trigger_physicalish_volume_upd
	INSTEAD OF UPDATE ON physicalish_volume
	FOR EACH ROW
	EXECUTE PROCEDURE physicalish_volume_upd();

-------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION physicalish_volume_del() RETURNS TRIGGER AS $$
DECLARE
	_o			block_storage_device%ROWTYPE;
	upd_query	TEXT[];
BEGIN

	DELETE FROM block_storage_device
		WHERE block_storage_device_id = OLD.physicalish_volume_id
		RETURNING * INTO _o;

	OLD.physicalish_volume_id	:= _o.block_storage_device_id;
	OLD.physicalish_volume_name	:= _o.block_storage_device_name;
	OLD.physicalish_volume_type	:= _o.block_storage_device_type;
	OLD.device_id				:= _o.device_id;
	OLD.component_id				:= _o.component_id;

	OLD.data_del_user 			:= _o.data_del_user;
	OLD.data_del_date 			:= _o.data_del_date;
	OLD.data_upd_user 			:= _o.data_upd_user;
	OLD.data_upd_date 			:= _o.data_upd_date;

	IF OLD.logical_volume_id IS NOT NULL AND _o.component_id IS NOT NULL THEN
		DELETE FROM virtual_component_logical_volume
		WHERE component_id = _o.compnent_id
		RETURNING logical_volume_id INTO OLD.logical_volume_id;

		OLD.component_id := NULL;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_physicalish_volume_del
	ON physicalish_volume;
CREATE TRIGGER trigger_physicalish_volume_del
	INSTEAD OF DELETE ON physicalish_volume
	FOR EACH ROW
	EXECUTE PROCEDURE physicalish_volume_del();

-------------------------------------------------------------------------
-------------------------------------------------------------------------
