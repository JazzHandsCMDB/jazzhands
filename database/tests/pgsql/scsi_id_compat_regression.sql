-- Copyright (c) 2023 Todd Kover
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

-- $Id$

\set ON_ERROR_STOP

\ir ../../../database/ddl/schema/pgsql/create_physicalish_volume_triggers.sql
\ir ../../../database/ddl/schema/pgsql/logical_volume_property_deprecation_triggers.sql

\t on

savepoint pretest;
DROP FUNCTION IF EXISTS check_scsi_id_property();
CREATE FUNCTION check_scsi_id_property() RETURNS BOOLEAN AS $$
DECLARE
	_r		RECORD;
	_d		RECORD;
	_pv		physicalish_volume%ROWTYPE;
	_se		service_environment.service_environment_id%TYPE;
	_dt		device_type%ROWTYPE;
	_dev	device%ROWTYPE;
	_vg		volume_group%ROWTYPE;
	_lv		logical_volume%ROWTYPE;
	_comp	component%ROWTYPE;
	_ctid	component_type.component_type_id%TYPE;
	_vclv	virtual_component_logical_volume%ROWTYPE;
BEGIN
	-- delete some stuff
	RAISE NOTICE '++ Checking if SCSI Id compatibility Works';

	INSERT INTO service_environment (
		service_environment_name, service_environment_type, production_state
	) VALUES (
		'jhtest', 'default', 'development'
	) RETURNING service_environment_id INTO _se;

	RAISE NOTICE '++ Inserting Test Data';
	INSERT INTO site (
		site_code, site_status
	) VALUES (
		'JHTEST01', 'ACTIVE'
	);

	INSERT INTO component_type (
		model, is_virtual_component
	) VALUES ('jh comp1', false) RETURNING component_type_id INTO _ctid;

	INSERT INTO device_type (device_type_name, component_type_id)
		VALUES ('test', _ctid )
		RETURNING * INTO _dt;

	INSERT INTO device (device_type_id, device_status, component_id,
		service_environment_id
	) VALUES (
		_dt.device_type_id, 'up', _comp.component_id, _se
	) RETURNING * INTO _dev;

	--- End of Setup

	INSERT INTO val_logical_volume_type ( logical_volume_type )
		VALUES ('jhlvtype');
	INSERT INTO val_volume_group_type ( volume_group_type )
		VALUES ('jhvgtype');
	INSERT INTO val_filesystem_type ( filesystem_type )
		VALUES ('jhfstype');
	INSERT INTO val_block_storage_device_type ( block_storage_device_type, permit_component_id  )
		VALUES ('jhdisk', 'REQUIRED');

	INSERT INTO val_logical_volume_property (
		logical_volume_property_name, filesystem_type
		) VALUES ( 'SCSI_Id', 'jhfstype');

	INSERT INTO volume_group (
		device_id, volume_group_name, volume_group_type,
		volume_group_size_in_bytes
	) VALUES (
		_dev.device_id, 'jhvg1', 'jhvgtype', 123456
	) RETURNING * INTO _vg;

	INSERT INTO logical_volume (
		logical_volume_name, logical_volume_type, volume_group_id, device_id,
		logical_volume_size_in_bytes, filesystem_type
	) VALUES (
		'lv00', 'jhlvtype', _vg.volume_group_id, _dev.device_id,
		123456, 'jhfstype'
	) RETURNING * INTO _lv;

	RAISE NOTICE 'Testing logical volume property to component property';
	BEGIN
		INSERT INTO logical_volume_property (
			logical_volume_id, filesystem_type, logical_volume_property_name,
			logical_volume_property_value
		) VALUES (
			_lv.logical_volume_id, _lv.filesystem_type, 'SCSI_Id',
			'55'
		) RETURNING * INTO _r;

		INSERT INTO physicalish_volume (
			physicalish_volume_name, physicalish_volume_type,
			device_id, logical_volume_id
		) VALUES (
			'foo', 'jhdisk',
			_dev.device_id, _lv.logical_volume_id
		);

		SELECT * INTO _d FROM logical_volume_property
			WHERE logical_volume_property_id = _r.logical_volume_property_id;

		IF _r != _d THEN
			RAISE EXCEPTION 'mismatch on insert to logical_volume_property';
		END IF;

		SELECT * INTO _vclv FROM virtual_component_logical_volume
		WHERE logical_volume_id = _lv.logical_volume_id;

		iF _vclv IS NULL THEN
			RAISE EXCEPTION 'No entry in virtual_component_logical_volume';
		END IF;

		SELECT * INTO _r FROM component_property
		WHERE component_id = _vclv.component_id
		AND component_property_type = 'disk'
		AND component_property_name = 'SCSI_Id';

		IF _r IS NULL THEN
			RAISE EXCEPTION 'No component property was created!';
		ELSIF _r.property_value != '55' THEN
			RAISE EXCEPTION 'SCSI Id does not match %', to_json(_r);
		END IF;

		BEGIN
			SELECT cp.* INTO _d FROM component_property cp
			WHERE component_id = _vclv.component_id
			AND component_property_name = 'SCSI_Id'
			AND component_property_type = 'disk';

			IF _d IS NULL THEN
				RAISE EXCEPTION 'component property is not there at start of delete';
			END IF;

			DELETE FROM logical_volume_property
			WHERE logical_volume_id = _vclv.logical_volume_id
			AND logical_volume_property_name = 'SCSI_Id'
			RETURNING * INTO _r;

			SELECT cp.* INTO _d FROM component_property cp
			WHERE component_id = _vclv.component_id
			AND component_property_name = 'SCSI_Id'
			AND component_property_type = 'disk';

			IF _d IS NOT NULL THEN
				RAISE EXCEPTION 'component property was not deleted.';
			END IF;
			RAISE EXCEPTION 'worked' USING ERRCODE = 'JH998';
		EXCEPTION WHEN SQLSTATE 'JH998' THEN
			NULL;
		END;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	RAISE NOTICE 'Testing component property to logical volume property adding virual_component_logical_volume first';
	BEGIN
		WITH c AS (
			INSERT INTO component ( component_type_id )
			SELECT component_type_id
			FROM component_type
			WHERE model = 'Virtual Disk'
			AND is_virtual_component
			ORDER BY component_type_id
			LIMIT 1
			RETURNING *
		) INSERT INTO virtual_component_logical_volume (
			component_id, logical_volume_id, component_type_id
		) SELECT component_id, _lv.logical_volume_id, component_type_id
		FROM c
		RETURNING * INTO _vclv;

		INSERT INTO component_property (
			component_property_type, component_property_name, component_id,
			property_value
		) VALUES (
			'disk', 'SCSI_Id', _vclv.component_id,
			'42'
		) RETURNING * INTO _r;

		SELECT * INTO _d FROM component_property
			WHERE component_property_id = _r.component_property_id;

		IF _r != _d THEN
				RAISE EXCEPTION 'inserted did not match % v %', _r, _d;
		END IF;

		SELECT * INTO _r
			FROM logical_volume_property
			WHERE logical_volume_id = _lv.logical_volume_id
			AND logical_volume_property_name = 'SCSI_Id';

		IF _r IS NULL THEN
			RAISE EXCEPTION 'There is no logical_volume_property for %', _lv.logical_volume_id;
		ELSIF _r.logical_volume_property_value != '42' THEN
			RAISE EXCEPTION 'SCSI id in lvp does not match: %', to_json(_r);
		END IF;

		BEGIN
			SELECT * INTO _d FROM logical_volume_property
			WHERE logical_volume_id = _vclv.logical_volume_id
			AND logical_volume_property_name = 'SCSI_Id';

			IF _d IS NULL THEN
				RAISE EXCEPTION 'logical_volume is not ther ebefore test';
			END IF;

			DELETE FROM component_property
			WHERE component_id = _vclv.component_id
			AND component_property_name = 'SCSI_Id'
			AND component_property_type = 'disk'
			RETURNING * INTO _r;

			SELECT * INTO _d FROM logical_volume_property
			WHERE logical_volume_id = _vclv.logical_volume_id
			AND logical_volume_property_name = 'SCSI_Id';

			IF _d IS NOT NULL THEN
				RAISE EXCEPTION 'component property was not deleted.';
			END IF;
			RAISE EXCEPTION 'worked' USING ERRCODE = 'JH998';
		EXCEPTION WHEN SQLSTATE 'JH998' THEN
			NULL;
		END;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	RAISE NOTICE 'Testing component property to logical volume property adding component_property first';
	BEGIN
		INSERT INTO component ( component_type_id )
			SELECT component_type_id
			FROM component_type
			WHERE model = 'Virtual Disk'
			AND is_virtual_component
			ORDER BY component_type_id
			LIMIT 1
			RETURNING * INTO _comp;

		INSERT INTO component_property (
			component_property_type, component_property_name, component_id,
			property_value
		) VALUES (
			'disk', 'SCSI_Id', _comp.component_id,
			'42'
		) RETURNING * INTO _r;

		INSERT INTO virtual_component_logical_volume (
			component_id, logical_volume_id,
			component_type_id
		) VALUES (
			_comp.component_id, _lv.logical_volume_id,
			_comp.component_type_id
		);

		SELECT * INTO _d FROM component_property
			WHERE component_property_id = _r.component_property_id;

		IF _r != _d THEN
				RAISE EXCEPTION 'inserted did not match % v %', _r, _d;
		END IF;

		SELECT * INTO _r
			FROM logical_volume_property
			WHERE logical_volume_id = _lv.logical_volume_id
			AND logical_volume_property_name = 'SCSI_Id';

		IF _r IS NULL THEN
			RAISE EXCEPTION 'There is no logical_volume_property for %', _lv.logical_volume_id;
		ELSIF _r.logical_volume_property_value != '42' THEN
			RAISE EXCEPTION 'SCSI id in lvp does not match: %', to_json(_r);
		END IF;

		BEGIN
			SELECT * INTO _d FROM logical_volume_property
			WHERE logical_volume_id = _vclv.logical_volume_id
			AND logical_volume_property_name = 'SCSI_Id';

			IF _d IS NULL THEN
				RAISE EXCEPTION 'logical_volume is not ther ebefore test';
			END IF;

			DELETE FROM component_property
			WHERE component_id = _vclv.component_id
			AND component_property_name = 'SCSI_Id'
			AND component_property_type = 'disk'
			RETURNING * INTO _r;

			SELECT * INTO _d FROM logical_volume_property
			WHERE logical_volume_id = _vclv.logical_volume_id
			AND logical_volume_property_name = 'SCSI_Id';

			IF _d IS NOT NULL THEN
				RAISE EXCEPTION 'component property was not deleted.';
			END IF;
			RAISE EXCEPTION 'worked' USING ERRCODE = 'JH998';
		EXCEPTION WHEN SQLSTATE 'JH998' THEN
			NULL;
		END;


		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;


	RAISE NOTICE '++ End  of SCSI Id compatibility check';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT check_scsi_id_property();
DROP FUNCTION check_scsi_id_property();

ROLLBACK TO pretest;
\t off
