-- Copyright (c) 2015, Kurt Adam
-- Copyright (c) 2020, Todd Kover
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

\set ON_ERROR_STOP

DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'snapshot_manip';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS snapshot_manip CASCADE;
		-- CREATE SCHEMA snapshot_manip AUTHORIZATION jazzhands;
		CREATE SCHEMA snapshot_manip;
		REVOKE ALL ON SCHEMA snapshot_manip FROM public;
		COMMENT ON SCHEMA snapshot_manip IS 'part of jazzhands';
	END IF;
END;
$$;

CREATE OR REPLACE FUNCTION snapshot_manip.add_snapshot(
	os_name       operating_system.operating_system_name%type,
	os_version    operating_system.version%type,
	snapshot_name operating_system_snapshot.operating_system_snapshot_name%type,
	snapshot_type operating_system_snapshot.operating_system_snapshot_type%type
) RETURNS integer AS $$

DECLARE
	major_version text;
	companyid     company.company_id%type;
	osid          operating_system.operating_system_id%type;
	snapid        operating_system_snapshot.operating_system_snapshot_id%type;
	dcid          device_collection.device_collection_id%type;

BEGIN
	SELECT company.company_id INTO companyid FROM company
		INNER JOIN company_type USING (company_id)
		WHERE lower(company_short_name) = lower(os_name)
		AND company_type = 'os provider';

	IF NOT FOUND THEN
		RAISE 'Operating system vendor not found';
	END IF;

	SELECT operating_system_id INTO osid FROM operating_system
		WHERE operating_system_name = os_name
		AND version = os_version;

	IF NOT FOUND THEN
		major_version := substring(os_version, '^[^.]+');

		INSERT INTO operating_system (
			operating_system_name,
			company_id,
			major_version,
			version,
			operating_system_family
		) VALUES (
			os_name,
			companyid,
			major_version,
			os_version,
			'linux'
		) RETURNING * INTO osid;

		INSERT INTO property (
			property_type,
			property_name,
			operating_system_id,
			property_value_boolean
		) VALUES (
			'OperatingSystem',
			'AllowOSDeploy',
			osid,
			false
		);
	END IF;

	INSERT INTO operating_system_snapshot (
		operating_system_snapshot_name,
		operating_system_snapshot_type,
		operating_system_id
	) VALUES (
		snapshot_name,
		snapshot_type,
		osid
	) RETURNING * INTO snapid;

	INSERT INTO device_collection (
		device_collection_name,
		device_collection_type,
		description
	) VALUES (
		CONCAT(os_name, '-', os_version, '-', snapshot_name),
		'os-snapshot',
		NULL
	) RETURNING * INTO dcid;

	INSERT INTO property (
		property_type,
		property_name,
		device_collection_id,
		operating_system_snapshot_id,
		property_value_boolean
	) VALUES (
		'OperatingSystem',
		'DeviceCollection',
		dcid,
		snapid,
		NULL
	), (
		'OperatingSystem',
		'AllowSnapDeploy',
		NULL,
		snapid,
		false
	);

	RETURN snapid;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION snapshot_manip.set_default_snapshot(
	os_name       operating_system.operating_system_name%type,
	os_version    operating_system.version%type,
	snapshot_name operating_system_snapshot.operating_system_snapshot_name%type
) RETURNS void AS $$

DECLARE
	osrec           RECORD;
	previous_snapid operating_system_snapshot.operating_system_snapshot_id%type;

BEGIN
	SELECT os.operating_system_id, oss.operating_system_snapshot_id INTO osrec FROM operating_system os
		INNER JOIN operating_system_snapshot oss USING(operating_system_id)
		WHERE operating_system_name = os_name
		AND version = os_version
		AND operating_system_snapshot_name = snapshot_name;

	IF NOT FOUND THEN
		RAISE 'Operating system snapshot not found';
	END IF;

	SELECT oss.operating_system_snapshot_id INTO previous_snapid FROM operating_system_snapshot oss
		INNER JOIN operating_system USING (operating_system_id)
		INNER JOIN property USING (operating_system_snapshot_id)
		WHERE version = os_version
		AND operating_system_name = os_name
		AND property_type = 'OperatingSystem'
		AND property_name = 'DefaultSnapshot';

	IF previous_snapid IS NOT NULL THEN
		IF osrec.operating_system_snapshot_id = previous_snapid THEN
			RETURN;
		END IF;

		DELETE FROM property
			WHERE operating_system_snapshot_id = previous_snapid
			AND property_type = 'OperatingSystem'
			AND property_name = 'DefaultSnapshot';
	END IF;

	INSERT INTO property (
		property_type,
		property_name,
		operating_system_id,
		operating_system_snapshot_id
	) VALUES (
		'OperatingSystem',
		'DefaultSnapshot',
		osrec.operating_system_id,
		osrec.operating_system_snapshot_id
	);
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION snapshot_manip.set_default_os_version(
	os_name       operating_system.operating_system_name%type,
	os_version    operating_system.version%type
) RETURNS void AS $$

DECLARE
	osid          operating_system.operating_system_id%type;
	previous_osid operating_system.operating_system_id%type;

BEGIN
	SELECT os.operating_system_id INTO osid FROM operating_system os
		WHERE operating_system_name = os_name
		AND version = os_version;

	IF NOT FOUND THEN
		RAISE 'Operating system not found';
	END IF;

	SELECT os.operating_system_id INTO previous_osid FROM operating_system os
		INNER JOIN property USING (operating_system_id)
		WHERE operating_system_name = os_name
		AND property_type = 'OperatingSystem'
		AND property_name = 'DefaultVersion';

	IF previous_osid IS NOT NULL THEN
		IF osid = previous_osid THEN
			RETURN;
		END IF;

		DELETE FROM property
			WHERE operating_system_id = previous_osid
			AND property_type = 'OperatingSystem'
			AND property_name = 'DefaultVersion';
	END IF;

	INSERT INTO property (
		property_type,
		property_name,
		operating_system_id,
		property_value
	) VALUES (
		'OperatingSystem',
		'DefaultVersion',
		osid,
		os_name
	);
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION snapshot_manip.delete_snapshot(
	os_name       operating_system.operating_system_name%type,
	os_version    operating_system.version%type,
	snapshot_name operating_system_snapshot.operating_system_snapshot_name%type
) RETURNS void AS $$

DECLARE
	snapid  operating_system_snapshot.operating_system_snapshot_id%type;
	dcid    device_collection.device_collection_id%type;
	dccount integer;

BEGIN
	SELECT operating_system_snapshot_id INTO snapid FROM operating_system
		INNER JOIN operating_system_snapshot USING (operating_system_id)
		WHERE operating_system_name = os_name
		AND operating_system_snapshot_name = snapshot_name
		AND version = os_version;

	IF NOT FOUND THEN
		RAISE 'Operating system snapshot not found';
	END IF;

	SELECT device_collection_id INTO dcid FROM property
		INNER JOIN operating_system_snapshot USING (operating_system_snapshot_id)
		WHERE property_type = 'OperatingSystem'
		AND property_name = 'DeviceCollection'
		AND property.operating_system_snapshot_id = snapid;

	SELECT COUNT(*) INTO dccount FROM device_collection_device where device_collection_id = dcid;

	IF dccount != 0 THEN
		RAISE 'Operating system snapshot still in use by some devices';
	END IF;

	DELETE FROM property WHERE operating_system_snapshot_id = snapid;
	DELETE FROM device_collection WHERE device_collection_name = CONCAT(os_name, '-', os_version, '-', snapshot_name);
	DELETE FROM operating_system_snapshot WHERE operating_system_snapshot_id = snapid;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION snapshot_manip.set_device_snapshot(
	input_device  device.device_id%type,
	os_name       operating_system.operating_system_name%type,
	os_version    operating_system.version%type,
	snapshot_name operating_system_snapshot.operating_system_snapshot_name%type
) RETURNS void AS $$

DECLARE
	snapid        operating_system_snapshot.operating_system_snapshot_id%type;
	previous_dcid device_collection.device_collection_id%type;
	new_dcid      device_collection.device_collection_id%type;

BEGIN
	IF snapshot_name = 'default' THEN
		SELECT oss.operating_system_snapshot_id INTO snapid FROM operating_system_snapshot oss
			INNER JOIN operating_system os USING (operating_system_id)
			INNER JOIN property p USING (operating_system_snapshot_id)
			WHERE os.version = os_version
			AND os.operating_system_name = os_name
			AND p.property_type = 'OperatingSystem'
			AND p.property_name = 'DefaultSnapshot';
	ELSE
		SELECT oss.operating_system_snapshot_id INTO snapid FROM operating_system_snapshot oss
			INNER JOIN operating_system os USING(operating_system_id)
			WHERE os.operating_system_name = os_name
			AND os.version = os_version
			AND oss.operating_system_snapshot_name = snapshot_name;
	END IF;

	IF NOT FOUND THEN
		RAISE 'Operating system snapshot not found';
	END IF;

	SELECT property.device_collection_id INTO new_dcid FROM property
		WHERE operating_system_snapshot_id = snapid
		AND property_type = 'OperatingSystem'
		AND property_name = 'DeviceCollection';

	SELECT device_collection_id INTO previous_dcid FROM device_collection_device
		INNER JOIN device_collection USING(device_collection_id)
		WHERE device_id = input_device
		AND device_collection_type = 'os-snapshot';

	IF FOUND THEN
		IF new_dcid = previous_dcid THEN
			RETURN;
		END IF;

		DELETE FROM device_collection_device
			WHERE device_id = input_device
			AND device_collection_id = previous_dcid;
	END IF;

	INSERT INTO device_collection_device (
		device_id,
		device_collection_id
	) VALUES (
		input_device,
		new_dcid
	);
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION snapshot_manip.get_default_snapshot(
	os_name       operating_system.operating_system_name%type,
	os_version    operating_system.version%type
) RETURNS varchar AS $$

DECLARE
	major_version text;
	companyid     company.company_id%type;
	osid          operating_system.operating_system_id%type;
	snapname      operating_system_snapshot.operating_system_snapshot_name%type;

BEGIN
	SELECT operating_system_id INTO osid FROM operating_system
		WHERE operating_system_name = os_name
		AND version = os_version;

	IF NOT FOUND THEN
		RAISE 'Operating system not found';
	END IF;

	SELECT operating_system_snapshot_name INTO snapname FROM operating_system_snapshot oss
		INNER JOIN property p USING (operating_system_snapshot_id)
		WHERE oss.operating_system_id = osid
		AND property_type = 'OperatingSystem'
		AND property_name = 'DefaultSnapshot';

	IF NOT FOUND THEN
		RAISE 'Default snapshot not found';
	END IF;

	RETURN snapname;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION snapshot_manip.get_device_snapshot(
	input_device   device.device_id%type
) RETURNS varchar AS $$

DECLARE
	snapname      operating_system_snapshot.operating_system_snapshot_name%type;

BEGIN
	SELECT oss.operating_system_snapshot_name INTO snapname FROM device d
	INNER JOIN device_collection_device dcd USING (device_id)
	INNER JOIN device_collection dc USING (device_collection_id)
	INNER JOIN property p USING (device_collection_id)
	INNER JOIN operating_system_snapshot oss USING (operating_system_snapshot_id)
	INNER JOIN operating_system os ON os.operating_system_id = oss.operating_system_id
	WHERE dc.device_collection_type::text = 'os-snapshot'::text
		AND p.property_type::text = 'OperatingSystem'::text
		AND p.property_name::text = 'DeviceCollection'::text
		AND device_id = input_device;

	IF NOT FOUND THEN
		RAISE 'Snapshot not set for device';
	END IF;

	RETURN snapname;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION snapshot_manip.get_default_os_version(
	os_name       operating_system.operating_system_name%type
) RETURNS varchar AS $$

DECLARE
	osid          operating_system.operating_system_id%type;
	os_version    operating_system.version%type;

BEGIN
	SELECT os.operating_system_id INTO osid FROM operating_system os
		WHERE operating_system_name = os_name;

	IF NOT FOUND THEN
		RAISE 'Operating system not found';
	END IF;

	SELECT os.version INTO os_version FROM operating_system os
		INNER JOIN property USING (operating_system_id)
		WHERE operating_system_name = os_name
		AND property_type = 'OperatingSystem'
		AND property_name = 'DefaultVersion';

	IF NOT FOUND THEN
		RAISE 'Default version not found for operating system';
	END IF;

	RETURN os_version;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

REVOKE ALL ON SCHEMA snapshot_manip FROM public;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA snapshot_manip FROM public;

GRANT USAGE ON SCHEMA snapshot_manip TO iud_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA snapshot_manip TO iud_role;
