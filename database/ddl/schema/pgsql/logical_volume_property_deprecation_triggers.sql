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

-----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION logical_volume_property_scsi_id_sync()
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.logical_volume_property_name != 'SCSI_Id' THEN
		RETURN NEW;
	ELSIF TG_OP = 'INSERT' THEN
		BEGIN
			INSERT INTO component_property (
				component_id, component_property_type,
				component_property_name, property_value
			) SELECT component_id, 'disk',
				NEW.logical_volume_property_name, NEW.logical_volume_property_value
			FROM virtual_component_logical_volume
			WHERE  logical_volume_id = NEW.logical_volume_id;
		EXCEPTION WHEN unique_violation THEN
			NULL;
		END;
	ELSIF TG_OP = 'UPDATE' THEN
		IF OLD.logical_volume_id IS DISTINCT FROM  NEW.logical_volume_id THEN
			RAISE EXCEPTION 'May not change logical_volume_id'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		UPDATE component_property cp
		SET property_value = NEW.property_value
		FROM virtual_component_logical_volume vclv
		WHERE cp.component_id = lclv.component_id
		AND vclv.logical_volume_id = NEW.logical_volume_id
		AND cp.component_property_name = NEW.logical_volume_property_name
		AND cp.component_property_type = 'disk'
		AND cp.property_value IS DISTINCT FROM NEW.logical_volume_property_value;
	ELSIF TG_OP = 'DELETE' THEN
		DELETE FROM component_property cp
		WHERE component_id IN (
			SELECT component_id FROM virtual_component_logical_volume
			WHERE logical_volume_id = OLD.logical_volume_id
		)
		AND cp.component_property_name = OLD.logical_volume_property_name
		AND cp.component_property_type = 'disk'
		AND cp.property_value IS NOT DISTINCT FROM OLD.logical_volume_property_value;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_logical_volume_property_scsi_id_sync_ins_upd
        ON logical_volume_property;
CREATE TRIGGER trigger_logical_volume_property_scsi_id_sync_ins_upd
        AFTER INSERT OR UPDATE OF logical_volume_id, logical_volume_property_value
        ON logical_volume_property
        FOR EACH ROW
        EXECUTE PROCEDURE logical_volume_property_scsi_id_sync();

DROP TRIGGER IF EXISTS trigger_logical_volume_property_scsi_id_sync_del
        ON logical_volume_property;
CREATE TRIGGER trigger_logical_volume_property_scsi_id_sync_del
        AFTER DELETE
        ON logical_volume_property
        FOR EACH ROW
        EXECUTE PROCEDURE logical_volume_property_scsi_id_sync();

-----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION virtual_component_logical_volume_legacy_sync()
RETURNS TRIGGER AS $$
BEGIN
	--
	-- This does not fire on DELETE because deleting the SCSI_id would happen
	-- when it was removed from either logical_volume_properry OR
	-- component_property but for INSERT, the linkage mage not have existed
	-- yet.
	IF TG_OP = 'INSERT' THEN
/*
 * These are manipulated directly.
		INSERT INTO component_property (
			component_id, component_property_type,
			component_property_name, property_value
		) SELECT NEW.component_id, 'disk',
			logical_volume_property_name, logical_volume_property_value
		FROM logical_volume_property
		WHERE  logical_volume_id = NEW.logical_volume_id
		AND logical_volume_property_name = 'SCSI_Id'
		ON CONFLICT DO NOTHING;
 */

		INSERT INTO logical_volume_property (
			logical_volume_id, filesystem_type,
			logical_volume_property_name, logical_volume_property_value
		) SELECT NEW.logical_volume_id, filesystem_type,
			component_property_name, property_value
		FROM component_property, logical_volume
		WHERE logical_volume_id = NEW.logical_volume_id
		AND component_id = NEW.component_id
		AND component_property_type = 'disk'
		AND component_property_name = 'SCSI_Id'
		ON CONFLICT
			DO NOTHING;
	ELSIF TG_OP = 'UPDATE' THEN
			RAISE EXCEPTION 'May not change logical_volume_id or component_id'
				USING ERRCODE = 'invalid_parameter_value';
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_virtual_component_logical_volume_legacy_sync_ins_upd
        ON virtual_component_logical_volume;
CREATE TRIGGER trigger_virtual_component_logical_volume_legacy_sync_ins_upd
        AFTER INSERT OR UPDATE OF logical_volume_id, component_id
        ON virtual_component_logical_volume
        FOR EACH ROW
        EXECUTE PROCEDURE virtual_component_logical_volume_legacy_sync();


-----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION component_property_scsi_id_logical_volume_sync()
RETURNS TRIGGER AS $$
DECLARE
	_r RECORD;
BEGIN
	IF NEW.component_property_name != 'SCSI_Id' OR
		NEW.component_property_type != 'disk'
	THEN
		RETURN NEW;
	ELSIF TG_OP = 'INSERT' THEN
		BEGIN
			INSERT INTO logical_volume_property (
				logical_volume_id, filesystem_type,
				logical_volume_property_name, logical_volume_property_value
			) SELECT logical_volume_id, filesystem_type,
				NEW.component_property_name, NEW.property_value
			FROM virtual_component_logical_volume
				JOIN logical_volume USING (logical_volume_id)
			WHERE  component_id = NEW.component_id
			ON CONFLICT (logical_volume_id, logical_volume_property_name)
				DO NOTHING;
		END;
	ELSIF TG_OP = 'UPDATE' THEN
		IF OLD.component_id IS DISTINCT FROM  NEW.component_id THEN
			RAISE EXCEPTION 'May not update component_id on SCSI_Id'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		UPDATE logical_volume_property lv
		SET property_value = NEW.property_value
		FROM virtual_component_logical_volume vclv
		WHERE vclv.component_id = NEW.component_id
		AND vclv.logical_volume_id = lv.logical_volume_id
		AND lv.logical_volume_property_name = NEW.component_property_anme
		AND lv.logical_volume_property_value IS DISTINCT FROM NEW.property_value;
	ELSIF TG_OP = 'DELETE' THEN
		DELETE FROM logical_volume_property lvp
		WHERE logical_volume_id IN (
			SELECT logical_volume_id FROM virtual_component_logical_volume
			WHERE component_id = OLD.component_id
		)
		AND lvp.logical_volume_property_name = OLD.component_property_name
		AND lvp.logical_volume_property_value
			IS NOT DISTINCT FROM OLD.property_value;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_component_property_scsi_id_logical_volume_sync_ins_upd
        ON component_property;
CREATE TRIGGER trigger_component_property_scsi_id_logical_volume_sync_ins_upd
        AFTER INSERT OR UPDATE OF component_id, property_value
        ON component_property
        FOR EACH ROW
        EXECUTE PROCEDURE component_property_scsi_id_logical_volume_sync();

DROP TRIGGER IF EXISTS trigger_component_property_scsi_id_logical_volume_sync_del
        ON component_property;
CREATE TRIGGER trigger_component_property_scsi_id_logical_volume_sync_del
        AFTER DELETE
        ON component_property
        FOR EACH ROW
        EXECUTE PROCEDURE component_property_scsi_id_logical_volume_sync();

