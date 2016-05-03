/*
* Copyright (c) 2014 Todd Kover
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
-- $HeadURL$
-- $Id$
--

--
-- Basics about network_ranges and dns:
--
-- Ensure that dns_domain_id is set when its supposed to be
--
CREATE OR REPLACE FUNCTION validate_network_range_dns()
RETURNS TRIGGER
AS $$
DECLARE
	v_nrt	val_network_range_type%ROWTYPE;
	v_nbt	val_netblock_type.netblock_type%TYPE;
BEGIN
	SELECT	*
	INTO	v_nrt
	FROM	val_network_range_type
	WHERE	network_range_type = NEW.network_range_type;

	IF NEW.dns_domain_id IS NULL AND v_nrt.dns_domain_required = 'REQUIRED' THEN
		RAISE EXCEPTION 'For type %, dns_domain_id is required.',
			NEW.network_range_type
			USING ERRCODE = 'not_null_violation';
	ELSIF NEW.dns_domain_id IS NOT NULL AND
			v_nrt.dns_domain_required = 'PROHIBITED' THEN
		RAISE EXCEPTION 'For type %, dns_domain_id is prohibited.',
			NEW.network_range_type
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;


	RETURN NEW;
END; $$
SET search_path=jazzhands
LANGUAGE plpgsql
SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_network_range_dns
	ON network_range;
CREATE CONSTRAINT TRIGGER trigger_validate_network_range_dns
	AFTER INSERT OR UPDATE OF dns_domain_id
	ON network_range
	DEFERRABLE INITIALLY IMMEDIATE
	FOR EACH ROW EXECUTE PROCEDURE
		jazzhands.validate_network_range_dns();

--
-- Basics about network_ranges and netblocks:
--
-- Ensure types patch propertly and the start/stop are within the parent
--
CREATE OR REPLACE FUNCTION validate_network_range_ips()
RETURNS TRIGGER
AS $$
DECLARE
	v_nrt	val_network_range_type%ROWTYPE;
	v_nbt	val_netblock_type.netblock_type%TYPE;
BEGIN
	SELECT	*
	INTO	v_nrt
	FROM	val_network_range_type
	WHERE	network_range_type = NEW.network_range_type;

	--
	-- check to make sure type mapping works
	--
	IF v_nrt.netblock_type IS NOT NULL THEN
		SELECT	netblock_type
		INTO	v_nbt
		FROM	netblock
		WHERE	netblock_id = NEW.start_netblock_id
		AND		netblock_type != v_nrt.netblock_type;

		IF FOUND THEN
			RAISE EXCEPTION 'For range %, start netblock_type must be %, not %',
				NEW.network_range_type, v_nrt.netblock_type, v_nbt
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

		SELECT	netblock_type
		INTO	v_nbt
		FROM	netblock
		WHERE	netblock_id = NEW.stop_netblock_id
		AND		netblock_type != v_nrt.netblock_type;

		IF FOUND THEN
			RAISE EXCEPTION 'For range %, stop netblock_type must be %, not %',
				NEW.network_range_type, v_brt.netblock_type, v_nbt
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;

	--
	-- Check to ensure both stop and start have is_single_address = 'Y'
	--
	PERFORM
	FROM	netblock
	WHERE	( netblock_id = NEW.start_netblock_id 
				OR netblock_id = NEW.stop_netblock_id
			) AND is_single_address = 'N';

	IF FOUND THEN
		RAISE EXCEPTION 'Start and stop types must be single addresses'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	PERFORM
	FROM	netblock
	WHERE	netblock_id = NEW.parent_netblock_id
	AND can_subnet = 'Y';

	IF FOUND THEN
		RAISE EXCEPTION 'Can not set ranges on subnetable netblocks'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	PERFORM
	FROM	netblock parent
			JOIN netblock start ON start.netblock_id = NEW.start_netblock_id
			JOIN netblock stop ON stop.netblock_id = NEW.stop_netblock_id
	WHERE	
			parent.netblock_id = NEW.parent_netblock_id
			AND NOT ( host(start.ip_address)::inet <<= parent.ip_address
				AND host(stop.ip_address)::inet <<= parent.ip_address
			)
	;

	IF FOUND THEN
		RAISE EXCEPTION 'Start and stop must be within parents'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	RETURN NEW;
END; $$
SET search_path=jazzhands
LANGUAGE plpgsql
SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_network_range_ips
	ON network_range;
CREATE CONSTRAINT TRIGGER trigger_validate_network_range_ips
	AFTER INSERT OR UPDATE OF start_netblock_id, stop_netblock_id,parent_netblock_id
	ON network_range
	DEFERRABLE INITIALLY IMMEDIATE
	FOR EACH ROW EXECUTE PROCEDURE
		jazzhands.validate_network_range_ips();


----------------------------------------------------------------------------
--
-- if a type is switching to 'Y', make sure that this does not create
-- invalid data.
--
CREATE OR REPLACE FUNCTION validate_val_network_range_type()
RETURNS TRIGGER
AS $$
BEGIN
	IF NEW.dns_domain_required = 'REQUIRED' THEN
		PERFORM
		FROM	network_range
		WHERE	network_range_type = NEW.network_range_type
		AND		dns_domain_id IS NULL;

		IF FOUND THEN
			RAISE EXCEPTION 'dns_domain_id is not set on some ranges'
				USING ERRCODE = 'not_null_violation';
		END IF;
	ELSIF NEW.dns_domain_required = 'PROHIBITED' THEN
		PERFORM
		FROM	network_range
		WHERE	network_range_type = NEW.network_range_type
		AND		dns_domain_id IS NOT NULL;

		IF FOUND THEN
			RAISE EXCEPTION 'dns_domain_id is set on some ranges'
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;

	IF NEW.netblock_type IS NOT NULL THEN
		PERFORM
		FROM	netblock_range nr
				JOIN netblock start ON start.netblock_id = nr.start_netblock_id
				JOIN netblock stop ON stop.netblock_id = nr.stop_netblock_id
		WHERE	nr.network_range_type = NEW.network_range_type
				(
					start.netblock_type != NEW.netblock_type
					OR		stop.netblock_type != NEW.netblock_type
				);

		IF FOUND THEN
			RAISE EXCEPTION 'netblock type is not set to % on some % ranges',
				NEW.netblock_type, NEW.network_range_type
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;

	RETURN NEW;
END; $$
SET search_path=jazzhands
LANGUAGE plpgsql
SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_val_network_range_type
	ON val_network_range_type;
CREATE CONSTRAINT TRIGGER trigger_validate_val_network_range_type
	AFTER UPDATE OF dns_domain_required, netblock_type
	ON val_network_range_type
	DEFERRABLE INITIALLY IMMEDIATE
	FOR EACH ROW EXECUTE PROCEDURE
		jazzhands.validate_val_network_range_type();

----------------------------------------------------------------------------
--
-- if a type is switching to 'Y', make sure that this does not create
-- invalid data.
--
CREATE OR REPLACE FUNCTION validate_val_network_range_type()
RETURNS TRIGGER
AS $$
BEGIN
	IF NEW.dns_domain_required = 'REQUIRED' THEN
		PERFORM
		FROM	network_range
		WHERE	network_range_type = NEW.network_range_type
		AND		dns_domain_id IS NULL;

		IF FOUND THEN
			RAISE EXCEPTION 'dns_domain_id is not set on some ranges'
				USING ERRCODE = 'not_null_violation';
		END IF;
	ELSIF NEW.dns_domain_required = 'PROHIBITED' THEN
		PERFORM
		FROM	network_range
		WHERE	network_range_type = NEW.network_range_type
		AND		dns_domain_id IS NOT NULL;

		IF FOUND THEN
			RAISE EXCEPTION 'dns_domain_id is set on some ranges'
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;

	IF NEW.netblock_type IS NOT NULL THEN
		PERFORM
		FROM	netblock_range nr
				JOIN netblock start ON start.netblock_id = nr.start_netblock_id
				JOIN netblock stop ON stop.netblock_id = nr.stop_netblock_id
		WHERE	nr.network_range_type = NEW.network_range_type
				(
					start.netblock_type != NEW.netblock_type
					OR		stop.netblock_type != NEW.netblock_type
				);

		IF FOUND THEN
			RAISE EXCEPTION 'netblock type is not set to % on some % ranges',
				NEW.netblock_type, NEW.network_range_type
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;

	RETURN NEW;
END; $$
SET search_path=jazzhands
LANGUAGE plpgsql
SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_val_network_range_type
	ON val_network_range_type;
CREATE CONSTRAINT TRIGGER trigger_validate_val_network_range_type
	AFTER UPDATE OF dns_domain_required, netblock_type
	ON val_network_range_type
	DEFERRABLE INITIALLY IMMEDIATE
	FOR EACH ROW EXECUTE PROCEDURE
		jazzhands.validate_val_network_range_type();

----------------------------------------------------------------------------
----------------------------------------------------------------------------
--
-- netblock changes (back to netblock_range)
--
----------------------------------------------------------------------------
----------------------------------------------------------------------------
----------------------------------------------------------------------------
--
-- if a netblock is changing interesting fields, make sure it still works if
-- it is in any network ranges.
--
CREATE OR REPLACE FUNCTION validate_netblock_to_range_changes()
RETURNS TRIGGER
AS $$
BEGIN
	PERFORM
	FROM	network_range nr
			JOIN netblock p on p.netblock_id = nr.parent_netblock_id
			JOIN netblock start on start.netblock_id = nr.start_netblock_id
			JOIN netblock stop on stop.netblock_id = nr.stop_netblock_id
			JOIN val_network_range_type vnrt USING (network_range_type)
	WHERE	( p.netblock_id = NEW.netblock_id 
				OR start.netblock_id = NEW.netblock_id
				OR stop.netblock_id = NEW.netblock_id
			) AND (
					p.can_subnet = 'Y'
				OR 	start.is_single_address = 'N'
				OR 	stop.is_single_address = 'N'
				OR NOT (
					host(start.ip_address)::inet <<= p.ip_address
					AND host(stop.ip_address)::inet <<= p.ip_address
				)
				OR ( vnrt.netblock_type IS NOT NULL
				OR NOT 
					( start.netblock_type IS NOT DISTINCT FROM vnrt.netblock_type
					AND	stop.netblock_type IS NOT DISTINCT FROM vnrt.netblock_type
					)
				)
			)
	;

	IF FOUND THEN
		RAISE EXCEPTION 'Netblock changes conflict with network range requirements '
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;
	RETURN NEW;
END; $$
SET search_path=jazzhands
LANGUAGE plpgsql
SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_netblock_to_range_changes
	ON netblock;
CREATE CONSTRAINT TRIGGER trigger_validate_netblock_to_range_changes
	AFTER UPDATE OF ip_address, is_single_address, can_subnet, netblock_type
	ON netblock
	DEFERRABLE INITIALLY IMMEDIATE
	FOR EACH ROW EXECUTE PROCEDURE
	jazzhands.validate_netblock_to_range_changes();

