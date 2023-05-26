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

--
-- These triggers enforce that things that are direct to host can't become
-- accidentaly not direct to host.  It's possible, even probable that these
-- should be folded into other triggers, but due to time constraints did not
-- want to do that now.
--

\set ON_ERROR_STOP

CREATE OR REPLACE FUNCTION filesystem_to_logical_volume_property_ins()
RETURNS TRIGGER AS $$
DECLARE
	_lv	logical_volume%ROWTYPE;
	_r RECORD;
BEGIN
	iF pg_trigger_depth() >= 2 THEN
		RETURN NEW;
	END IF;
	SELECT lv.* INTO _lv
	FROM logical_volume lv
		JOIN block_storage_device USING (logical_volume_id)
	WHERE block_storage_device_id = NEW.block_storage_device_id;

	IF NOT FOUND THEN
		RETURN NEW;
	END IF;

	UPDATE logical_volume
	SET filesystem_type = NEW.filesystem_type
	WHERE logical_volume_id = _lv.logical_volume_id
	AND filesystem_type != NEW.filesystem_type;

	IF NEW.mountpoint IS NOT NULL THEN
		INSERT INTO logical_volume_property (
			logical_volume_id, logical_volume_type, filesystem_type,
			logical_volume_property_name, logical_volume_property_value
		) VALUES (
			_lv.logical_volume_id, _lv.logical_volume_type, NEW.filesystem_type,
			'MountPoint', NEW.mountpoint
		) RETURNING * INTO _r;
	END IF;

	IF NEW.filesystem_serial IS NOT NULL THEN
		INSERT INTO logical_volume_property (
			logical_volume_id, logical_volume_type, filesystem_type,
			logical_volume_property_name, logical_volume_property_value
		) VALUES (
			_lv.logical_volume_id, _lv.logical_volume_type, NEW.filesystem_type,
			'Serial', NEW.filesystem_serial
		);
	END IF;

	IF NEW.filesystem_label IS NOT NULL THEN
		INSERT INTO logical_volume_property (
			logical_volume_id, logical_volume_type, filesystem_type,
			logical_volume_property_name, logical_volume_property_value
		) VALUES (
			_lv.logical_volume_id, _lv.logical_volume_type, NEW.filesystem_type,
			'Label', NEW.filesystem_label
		);
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_filesystem_to_logical_volume_property_ins
	ON filesystem;
CREATE TRIGGER trigger_filesystem_to_logical_volume_property_ins
	AFTER INSERT
	ON filesystem
	FOR EACH ROW
	EXECUTE PROCEDURE filesystem_to_logical_volume_property_ins();

----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION filesystem_to_logical_volume_property_upd()
RETURNS TRIGGER AS $$
DECLARE
	_lv		logical_volume%ROWTYPE;
BEGIN
	SELECT lv.* INTO _lv
	FROM logical_volume lv
		JOIN block_storage_device USING (logical_volume_id)
	WHERE block_storage_device_id = NEW.block_storage_device_id;

	IF NOT FOUND THEN
		RETURN NEW;
	END IF;

	UPDATE logical_volume
	SET filesystem_type = NEW.filesystem_type
	WHERE logical_volume_id = _lv.logical_volume_id
	AND filesystem_type != NEW.filesystem_type;

	IF OLD.filesystem_type IS DISTINCT FROM NEW.filesystem_type THEN
		UPDATE logical_volume_property
			SET filesystem_type = NEW.filesystem_type
		WHERE logical_volume_id = _lv.logical_volume_id
		AND logical_volume_type = _lv.logical_volume_type
		AND filesystem_type = OLD.filesystem_type;
	END IF;

	IF OLD.mountpoint IS DISTINCT FROM NEW.mountpoint THEN
		IF NEW.mountpoint IS NULL THEN
			DELETE FROM logical_volume_property
			WHERE logical_volume_property_name = 'MountPoint'
			AND logical_volume_id = _lv.logical_volume_id
			AND logical_volume_type = _lv.logical_volume_type
			AND filesystem_type = NEW.filesystem_type;
		ELSE
			UPDATE logical_volume_property
				SET logical_volume_property_value = NEW.mountpoint
			WHERE logical_volume_property_name = 'MountPoint'
			AND logical_volume_id = _lv.logical_volume_id
			AND logical_volume_type = _lv.logical_volume_type
			AND filesystem_type = NEW.filesystem_type
			AND logical_volume_property_value IS DISTINCT FROM NEW.mountpoint;
		END IF;
	END IF;

	IF OLD.filesystem_label IS DISTINCT FROM NEW.filesystem_label THEN
		IF NEW.filesystem_label IS NULL THEN
			DELETE FROM logical_volume_property
			WHERE logical_volume_property_name = 'Label'
			AND logical_volume_id = _lv.logical_volume_id
			AND logical_volume_type = _lv.logical_volume_type
			AND filesystem_type = NEW.filesystem_type;
		ELSE
			UPDATE logical_volume_property
				SET logical_volume_property_value = NEW.filesystem_label
			WHERE logical_volume_property_name = 'Label'
			AND logical_volume_id = _lv.logical_volume_id
			AND logical_volume_type = _lv.logical_volume_type
			AND filesystem_type = NEW.filesystem_type
			AND logical_volume_property_value IS DISTINCT FROM NEW.filesystem_label;
		END IF;
	END IF;

	IF OLD.filesystem_serial IS DISTINCT FROM NEW.filesystem_serial THEN
		IF NEW.filesystem_serial IS NULL THEN
			DELETE FROM logical_volume_property
			WHERE logical_volume_property_name = 'Serial'
			AND logical_volume_id = _lv.logical_volume_id
			AND logical_volume_type = _lv.logical_volume_type
			AND filesystem_type = NEW.filesystem_type;
		ELSE
			UPDATE logical_volume_property
				SET logical_volume_property_value = NEW.filesystem_serial
			WHERE logical_volume_property_name = 'Serial'
			AND logical_volume_id = _lv.logical_volume_id
			AND logical_volume_type = _lv.logical_volume_type
			AND filesystem_type = NEW.filesystem_type
			AND logical_volume_property_value IS DISTINCT FROM NEW.filesystem_serial;
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_filesystem_to_logical_volume_property_upd
	ON filesystem;
CREATE TRIGGER trigger_filesystem_to_logical_volume_property_upd
	AFTER UPDATE
	ON filesystem
	FOR EACH ROW
	EXECUTE PROCEDURE filesystem_to_logical_volume_property_upd();

----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION filesystem_to_logical_volume_property_del()
RETURNS TRIGGER AS $$
DECLARE
	_lv	logical_volume%ROWTYPE;
BEGIN
	SELECT lv.* INTO _lv
	FROM logical_volume lv
		JOIN block_storage_device USING (logical_volume_id)
	WHERE block_storage_device_id = OLD.block_storage_device_id;

	IF FOUND THEN
		DELETE FROM logical_volume_property
		WHERE logical_volume_id = _lv.logical_volume_id
		AND logical_volume_type = _lv.logical_volume_type
		AND filesystem_type = _lv.filesystem_type
		AND logical_volume_property_name IN ('MountPoint', 'Serial', 'Label');
	END IF;

	RETURN OLD;

END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;


DROP TRIGGER IF EXISTS trigger_filesystem_to_logical_volume_property_del
	ON filesystem;
CREATE TRIGGER trigger_filesystem_to_logical_volume_property_del
	BEFORE DELETE
	ON filesystem
	FOR EACH ROW
	EXECUTE PROCEDURE filesystem_to_logical_volume_property_del();

----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION logical_volume_property_to_filesystem_insupd()
RETURNS TRIGGER AS $$
DECLARE
	_bsd		block_storage_device;
	_lv			logical_volume;
	_vg			volume_group;
	_fs			filesystem;
	upd_query	TEXT[];
BEGIN
	iF pg_trigger_depth() >= 2 THEN
		RETURN NEW;
	END IF;
	IF NEW.logical_volume_property_name NOT IN ('MountPoint','Serial','Label')
	THEN
		RETURN NEW;
	END IF;

	SELECT bsd.* INTO _bsd
	FROM logical_volume lv
		JOIN block_storage_device bsd USING (logical_volume_id)
	WHERE logical_volume_id = NEW.logical_volume_id;

	IF NOT FOUND THEN
		SELECT * INTO _lv FROM logical_volume
			WHERE logical_volume_id = NEW.logical_volume_id;

		SELECT * INTO _vg FROM volume_group
			WHERE volume_group_id = _lv.volume_group_id;

		---
		--- This is fragile
		---
		INSERT INTO block_storage_device (
				block_storage_device_name, block_storage_device_type,
                device_id, logical_volume_id,
				block_device_size_in_bytes,
				uuid
		) VALUES (
			(CASE WHEN _vg.volume_group_type = 'Linux LVM' THEN concat_ws('-', _vg.volume_group_name, _lv.logical_volume_name)
				ELSE _lv.logical_volume_name END),
			(CASE WHEN _vg.volume_group_type = 'Linux LVM' THEN 'LVM volume'
				WHEN _vg.volume_group_type = 'partitioned disk' THEN 'disk partition'
			ELSE 'disk partition' END),		--- this is hackish
			_lv.device_id, NEW.logical_volume_id,
			_lv.logical_volume_size_in_bytes,
			(CASE WHEN NEW.logical_volume_property_name = 'Serial'
				THEN NEW.logical_volume_property_value
				ELSE NULL END)
		) RETURNING * INTO _bsd;
	END IF;

	SELECT * INTO _fs FROM filesystem
		WHERE block_storage_device_id = _bsd.block_storage_device_id;

	IF NOT FOUND THEN
		INSERT INTO filesystem (
			block_storage_device_id, filesystem_type, device_id,
			mountpoint,
			filesystem_label,
			filesystem_serial
		) VALUES (
			_bsd.block_storage_device_id, NEW.filesystem_type, _bsd.device_id,
			(CASE WHEN NEW.logical_volume_property_name = 'MountPoint'
				THEN NEW.logical_volume_property_value
				ELSE NULL END),
			(CASE WHEN NEW.logical_volume_property_name = 'Label'
				THEN NEW.logical_volume_property_value
				ELSE NULL END),
			(CASE WHEN NEW.logical_volume_property_name = 'Serial'
				THEN NEW.logical_volume_property_value
				ELSE NULL END)
		) RETURNING * INTO _fs;
	ELSE
		IF _fs.filesystem_type != NEW.filesystem_type THEN
			upd_query := array_append(upd_query,
				'filesystem_type = ' || quote_nullable(NEW.filesystem_type));
		END IF;
		IF NEW.logical_volume_property_name = 'MountPoint' AND
			_fs.mountpoint IS DISTINCT FROM NEW.logical_volume_property_value
		THEN
			upd_query := array_append(upd_query,
				'mountpoint = ' || quote_nullable(NEW.logical_volume_property_value));
		END IF;

		IF NEW.logical_volume_property_name = 'Serial' AND
			_fs.filesystem_serial IS DISTINCT FROM NEW.logical_volume_property_value
		THEN
			upd_query := array_append(upd_query,
				'filesystem_serial = ' || quote_nullable(NEW.logical_volume_property_value));
		END IF;

		IF NEW.logical_volume_property_name = 'Label' AND
			_fs.filesystem_label IS DISTINCT FROM NEW.logical_volume_property_value
		THEN
			upd_query := array_append(upd_query,
				'filesystem_label = ' || quote_nullable(NEW.logical_volume_property_value));
		END IF;

		IF TG_OP = 'UPDATE' AND
			OLD.logical_volume_property_name IS DISTINCT FROM NEW.logical_volume_property_name
		THEN
			IF NEW.logical_volume_property_name = 'MountPoint' THEN
				upd_query := array_append(upd_query,
					'mountpoint = NULL');
			END IF;
			IF NEW.logical_volume_property_name = 'Serial' THEN
				upd_query := array_append(upd_query,
					'filesystem_serial = NULL');
			END IF;
			IF NEW.logical_volume_property_name = 'Label' THEN
				upd_query := array_append(upd_query,
					'filesystem_label = NULL');
			END IF;
		END IF;

		IF upd_query IS NOT NULL THEN
			EXECUTE 'UPDATE filesystem SET ' ||
				array_to_string(upd_query, ', ') ||
			' WHERE block_storage_device_id = $1 RETURNING *'
			USING _bsd.block_storage_device_Id INTO _fs;
		END IF;

	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_logical_volume_property_to_filesystem_insupd
	ON logical_volume_property;
CREATE TRIGGER trigger_logical_volume_property_to_filesystem_insupd
	AFTER INSERT OR UPDATE
	ON logical_volume_property
	FOR EACH ROW
	EXECUTE PROCEDURE logical_volume_property_to_filesystem_insupd();

----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION logical_volume_property_to_filesystem_del()
RETURNS TRIGGER AS $$
DECLARE
	_bsd		block_storage_device;
	_fs			filesystem;
	_tally		INTEGER;
	upd_query	TEXT[];
BEGIN
	iF pg_trigger_depth() >= 2 THEN
		RETURN OLD;
	END IF;
	IF OLD.logical_volume_property_name NOT IN ('MountPoint','Serial','Label')
	THEN
		RETURN OLD;
	END IF;

	SELECT bsd.* INTO _bsd
	FROM logical_volume lv
		JOIN block_storage_device bsd USING (logical_volume_id)
	WHERE logical_volume_id = OLD.logical_volume_id;

	---
	--- This should generally not happen
	---
	IF NOT FOUND THEN
		RETURN OLD;
	END IF;

	SELECT * INTO _fs FROM filesystem
		WHERE block_storage_device_id = _bsd.block_storage_device_id;

	IF FOUND THEN
		_tally := 0;
		IF _fs.mountpoint IS NOT NULL THEN
			_tally := _tally + 1;
		END IF;
		IF _fs.filesystem_serial IS NOT NULL THEN
			_tally := _tally + 1;
		END IF;
		IF _fs.filesystem_label IS NOT NULL THEN
			_tally := _tally + 1;
		END IF;

		IF OLD.logical_volume_property_name = 'MountPoint'
		THEN
			upd_query := array_append(upd_query,
				'mountpoint = NULL');
		END IF;

		IF OLD.logical_volume_property_name = 'Serial'
		THEN
			upd_query := array_append(upd_query,
				'filesystem_serial = NULL');
		END IF;

		IF OLD.logical_volume_property_name = 'Label'
		THEN
			upd_query := array_append(upd_query,
				'filesystem_label = NULL');
		END IF;

		IF _tally = 1 THEN
			DELETE FROM filesystem
				WHERE block_storage_device_id = _bsd.block_storage_device_id;
			DELETE FROM block_storage_device
			WHERE block_storage_device_id = _bsd.block_storage_device_id;
		ELSIF upd_query IS NOT NULL THEN
			EXECUTE 'UPDATE filesystem SET ' ||
				array_to_string(upd_query, ', ') ||
			' WHERE block_storage_device_id = $1 RETURNING *'
			USING _bsd.block_storage_device_Id INTO _fs;
		END IF;
	END IF;


	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_logical_volume_property_to_filesystem_del
	ON logical_volume_property;
CREATE TRIGGER trigger_logical_volume_property_to_filesystem_del
	AFTER DELETE
	ON logical_volume_property
	FOR EACH ROW
	EXECUTE PROCEDURE logical_volume_property_to_filesystem_del();

----------------------------------------------------------------------------
