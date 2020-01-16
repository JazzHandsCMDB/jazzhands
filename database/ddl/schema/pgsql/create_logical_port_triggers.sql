/*
 * Copyright (c) 2019 Matthew Ragan
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

/*
 * Triggers related to validating logical port consistency
 */

\set ON_ERROR_STOP

/*
 * Make sure exactly one of device_id and mlag_peering_id are set on
 * logical_port.  Don't allow changing device_id.
 */

CREATE OR REPLACE FUNCTION jazzhands.validate_logical_port_base_data()
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.device_id IS NULL AND NEW.mlag_peering_id IS NULL THEN
		RAISE EXCEPTION 'Either device_id or mlag_peering_id must be set on logical_port (id %)',
			NEW.logical_port_id
			USING ERRCODE = 'check_violation';
	END IF;

	IF NEW.device_id IS NOT NULL AND NEW.mlag_peering_id IS NOT NULL THEN
		RAISE EXCEPTION 'Only one of device_id or mlag_peering_id may be set on logical_port (id %)',
			NEW.logical_port_id
			USING ERRCODE = 'check_violation';
	END IF;

	--
	-- check specific logical_port types
	--
	IF NEW.logical_port_type = 'MLAG' AND NEW.mlag_peering_id IS NULL THEN
		RAISE EXCEPTION 'logical_port.mlag_peering_id must be set for type "MLAG" (id %)',
			NEW.logical_port_id
			USING ERRCODE = 'check_violation';
	END IF;

	IF NEW.logical_port_type = 'LACP' AND NEW.device_id IS NULL THEN
		RAISE EXCEPTION 'logical_port.device_id must be set for type "LACP" (id %)',
			NEW.logical_port_id
			USING ERRCODE = 'check_violation';
	END IF;

	--
	-- On update, disallow changes to logical_port_id, logical_port_type, or
	-- device_id
	--
	IF TG_OP = 'UPDATE' THEN
		IF NEW.logical_port_id IS DISTINCT FROM OLD.logical_port_id THEN
			RAISE EXCEPTION 'logical_port.logical_port_id may not be changed (id %)',
				NEW.logical_port_id
				USING ERRCODE = 'check_violation';
		END IF;

		IF NEW.device_id IS DISTINCT FROM OLD.device_id THEN
			RAISE EXCEPTION 'logical_port.device_id may not be changed (id %)',
				NEW.logical_port_id
				USING ERRCODE = 'check_violation';
		END IF;

		IF NEW.logical_port_type IS DISTINCT FROM OLD.logical_port_type THEN
			RAISE EXCEPTION 'logical_port.logical_port_type may not be changed (id %)',
				NEW.logical_port_id
				USING ERRCODE = 'check_violation';
		END IF;

	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_logical_port_base_data
	ON jazzhands.logical_port;

CREATE CONSTRAINT TRIGGER trigger_validate_logical_port_base_data
AFTER INSERT OR UPDATE ON jazzhands.logical_port
DEFERRABLE INITIALLY IMMEDIATE
FOR EACH ROW EXECUTE PROCEDURE
	jazzhands.validate_logical_port_base_data();

/*
 * Ensure that the device of the logical_port_slot matches the device of
 * the logical_port
 */

CREATE OR REPLACE FUNCTION jazzhands.validate_logical_port_slot_device_id()
RETURNS TRIGGER AS $$
DECLARE
	lp_rec	RECORD;
	dev_id	jazzhands.device.device_id%TYPE;
BEGIN
	SELECT
		* INTO lp_rec
	FROM
		jazzhands.logical_port lp
	WHERE
		lp.logical_port_id = NEW.logical_port_id;

		
	IF lp_rec.device_id IS NULL THEN
        RAISE EXCEPTION 'logical_port_slot entry not allowed where logical_port.device_id is not set (logical_port_id %)',
			lp_rec.logical_port_id
        USING ERRCODE = 'check_violation';
    END IF;

	SELECT
		ds.device_id INTO dev_id
	FROM
		v_device_slots ds
	WHERE
		ds.slot_id = NEW.slot_id;
	
	IF NOT FOUND OR dev_id != lp_rec.device_id THEN
        RAISE EXCEPTION 'device % for logical port % does not match device for slot % (%)',
			lp_rec.device_id,
			lp_rec.logical_port_id,
			NEW.slot_id,
			dev_id
        USING ERRCODE = 'check_violation';
    END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_logical_port_slot_device_id
	ON jazzhands.logical_port_slot;

CREATE CONSTRAINT TRIGGER trigger_validate_logical_port_slot_device_id
AFTER INSERT OR UPDATE OF slot_id
ON jazzhands.logical_port_slot
DEFERRABLE INITIALLY IMMEDIATE
FOR EACH ROW EXECUTE PROCEDURE
	jazzhands.validate_logical_port_slot_device_id();


/*
 * Ensure that if a component moves slots and the device changes, if there
 * are any slots attached to logical ports then remove those ports from
 * the logical port
 */

CREATE OR REPLACE FUNCTION jazzhands.validate_component_logical_port()
RETURNS TRIGGER AS $$
DECLARE
	lp_rec	RECORD;
	dev_id	jazzhands.device.device_id%TYPE;
BEGIN
	SELECT
		* INTO lp_rec
	FROM
		jazzhands.logical_port lp
	WHERE
		lp.logical_port_id = NEW.logical_port_id;

		
	IF lp_rec.device_id IS NULL THEN
        RAISE EXCEPTION 'logical_port_slot entry not allowed where logical_port.device_id is not set (logical_port_id %)',
			lp_rec.logical_port_id
        USING ERRCODE = 'check_violation';
    END IF;

	SELECT
		ds.device_id INTO dev_id
	FROM
		v_device_slots ds
	WHERE
		ds.slot_id = NEW.slot_id;
	
	IF NOT FOUND OR dev_id != lp_rec.device_id THEN
        RAISE EXCEPTION 'device % for logical port % does not match device for slot % (%)',
			lp_rec.device_id,
			lp_rec.logical_port_id,
			NEW.slot_id,
			dev_id
        USING ERRCODE = 'check_violation';
    END IF;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_logical_port_slot_device_id
	ON jazzhands.logical_port_slot;

CREATE CONSTRAINT TRIGGER trigger_validate_logical_port_slot_device_id
AFTER INSERT OR UPDATE OF slot_id
ON jazzhands.logical_port_slot
DEFERRABLE INITIALLY IMMEDIATE
FOR EACH ROW EXECUTE PROCEDURE
	jazzhands.validate_logical_port_slot_device_id();

/*
 * Validate changing mlag_peering.devicex_id
 */

CREATE OR REPLACE FUNCTION jazzhands.validate_mlag_peering_devicex_id()
RETURNS TRIGGER AS $$
DECLARE
	mp_rec	RECORD;
BEGIN
	--
	-- device1_id and device2_id can't be the same unless they're both NULL
	--
	IF NEW.device1_id = NEW.device2_id THEN
        RAISE EXCEPTION 'mlag_peer.device1_id and mlag_peer.device2_id may not be the same'
        USING ERRCODE = 'check_violation';
	END IF;

	--
	-- If we're just swapping MLAG device_ids, let things go
	--
	IF TG_OP = 'UPDATE' AND
		NEW.device1_id IS NOT DISTINCT FROM OLD.device2_id AND
		NEW.device2_id IS NOT DISTINCT FROM OLD.device1_id
	THEN
		RETURN NEW;
	END IF;
	
	--
	-- Make sure that devicex_id is not assigned to a different mlag_peer
	--
	IF
		(
			TG_OP = 'INSERT' OR 
			NEW.device1_id IS DISTINCT FROM OLD.device1_id
		) AND
		NEW.device1_id IS NOT NULL
	THEN
		SELECT * INTO mp_rec FROM
			jazzhands.mlag_peering mp
		WHERE
			(
				mp.device1_id = NEW.device1_id OR
				mp.device2_id = NEW.device1_id
			) AND
			mp.mlag_peering_id != NEW.mlag_peering_id;

		IF FOUND THEN
			RAISE EXCEPTION 'device_id % is already a member of mlag_peering %',
				NEW.device1_id,
				mp_rec.mlag_peering_id
			USING ERRCODE = 'check_violation';
		END IF;

		IF TG_OP = 'UPDATE' THEN
			PERFORM * FROM
				logical_port mp JOIN
				logical_port lp ON (
					lp.parent_logical_port_id = 
					mp.logical_port_id
				)
			WHERE
				mp.mlag_peering_id = NEW.mlag_peering_id AND
				lp.device_id = OLD.device1_id;
			IF FOUND THEN
				RAISE EXCEPTION 'attempt to remove device_id % from mlag_peering % while child logical ports for this device are still attached',
					OLD.device1_id,
					NEW.mlag_peering_id
				USING ERRCODE = 'check_violation';
			END IF;
		END IF;
	END IF;

	IF
		(
			TG_OP = 'INSERT' OR 
			NEW.device2_id IS DISTINCT FROM OLD.device2_id
		) AND
		NEW.device2_id IS NOT NULL
	THEN
		SELECT * INTO mp_rec FROM
			jazzhands.mlag_peering mp
		WHERE
			(
				mp.device1_id = NEW.device2_id OR
				mp.device2_id = NEW.device2_id
			) AND
			mp.mlag_peering_id != NEW.mlag_peering_id;

		IF FOUND THEN
			RAISE EXCEPTION 'device_id % is already a member of mlag_peering %',
				NEW.device2_id,
				mp_rec.mlag_peering_id
			USING ERRCODE = 'check_violation';
		END IF;

		IF TG_OP = 'UPDATE' THEN
			PERFORM * FROM
				logical_port mp JOIN
				logical_port lp ON (
					lp.parent_logical_port_id = 
					mp.logical_port_id
				)
			WHERE
				mp.mlag_peering_id = NEW.mlag_peering_id AND
				lp.device_id = OLD.device1_id;
			IF FOUND THEN
				RAISE EXCEPTION 'attempt to remove device_id % from mlag_peering % while child logical ports for this device are still attached',
					OLD.device1_id,
					NEW.mlag_peering_id
				USING ERRCODE = 'check_violation';
			END IF;
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_mlag_peering_devicex_id
	ON jazzhands.mlag_peering;

CREATE CONSTRAINT TRIGGER trigger_validate_mlag_peering_devicex_id
AFTER INSERT OR UPDATE OF device1_id, device2_id
ON jazzhands.mlag_peering
DEFERRABLE INITIALLY IMMEDIATE
FOR EACH ROW EXECUTE PROCEDURE
	jazzhands.validate_mlag_peering_devicex_id();
