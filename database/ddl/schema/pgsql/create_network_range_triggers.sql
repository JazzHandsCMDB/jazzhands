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
	startip	inet;
	stopip	inet;
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
				NEW.network_range_type, v_nrt.netblock_type, v_nbt
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;

	--
	-- Check to ensure both stop and start have is_single_address = true
	--
	PERFORM
	FROM	netblock
	WHERE	( netblock_id = NEW.start_netblock_id
				OR netblock_id = NEW.stop_netblock_id
			) AND is_single_address = false;

	IF FOUND THEN
		RAISE EXCEPTION 'Start and stop types must be single addresses'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	PERFORM
	FROM	netblock
	WHERE	netblock_id = NEW.parent_netblock_id
	AND can_subnet = true;

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
		RAISE EXCEPTION 'start or stop address not within parent netblock'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	IF v_nrt.can_overlap = false THEN
		SELECT host(ip_address) INTO startip
			FROM netblock where netblock_id = NEW.start_netblock_id;
		SELECT host(ip_address) INTO stopip
			FROM netblock where netblock_id = NEW.stop_netblock_id;

		PERFORM *
		FROM (
			SELECT nr.*, host(start.ip_address)::inet AS start_ip,
				host(stop.ip_address)::inet AS stop_ip
			FROM network_range nr
			JOIN netblock start ON start.netblock_id = nr.start_netblock_id
			JOIN netblock stop ON stop.netblock_id = nr.stop_netblock_id
		) nr
		WHERE nr.network_range_type = NEW.network_range_type
		AND nr.network_range_id != NEW.network_range_id
		AND (
			( startip >= start_ip AND startip <= stop_ip)
			OR
			( stopip >= start_ip AND stopip <= stop_ip)
		);

		IF FOUND THEN
			RAISE EXCEPTION 'overlapping network ranges not permitted for type %',
				NEW.network_range_type
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;

	IF v_nrt.require_cidr_boundary = true THEN
		SELECT host(ip_address) INTO startip
			FROM netblock where netblock_id = NEW.start_netblock_id;
		SELECT host(ip_address) INTO stopip
			FROM netblock where netblock_id = NEW.stop_netblock_id;

		PERFORM *
		FROM (
			SELECT nr.*, start.ip_address AS start_ip,
				stop.ip_address AS stop_ip
			FROM network_range nr
			JOIN netblock start ON start.netblock_id = nr.start_netblock_id
			JOIN netblock stop ON stop.netblock_id = nr.stop_netblock_id
		) nr
		WHERE nr.network_range_id = NEW.network_range_id
		AND (
			masklen(start_ip) != masklen(stop_ip)
			OR start_ip != network(start_ip)
			OR stop_ip != broadcast(stop_ip)
		);
		IF FOUND THEN
			RAISE EXCEPTION 'start/stop must be on matching CIDR boundaries'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	--
	-- make sure that the order of start/stop is not backwards
	--
	PERFORM
	FROM (
		SELECT nr.*, host(start.ip_address)::inet AS start_ip,
				host(stop.ip_address)::inet AS stop_ip
			FROM network_range nr
			JOIN netblock start ON start.netblock_id = nr.start_netblock_id
			JOIN netblock stop ON stop.netblock_id = nr.stop_netblock_id
		) nr
	WHERE network_range_id = NEW.network_range_id
	AND stop_ip < start_ip;

	IF FOUND THEN
		RAISE EXCEPTION 'stop ip address can not be before start in network ranges.'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	RETURN NEW;
END; $$
SET search_path=jazzhands
LANGUAGE plpgsql
SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_network_range_ips
	ON network_range;
CREATE CONSTRAINT TRIGGER trigger_validate_network_range_ips
	AFTER INSERT OR UPDATE OF start_netblock_id, stop_netblock_id, parent_netblock_id, network_range_type
	ON network_range
	DEFERRABLE INITIALLY IMMEDIATE
	FOR EACH ROW EXECUTE PROCEDURE
		jazzhands.validate_network_range_ips();


----------------------------------------------------------------------------
--
-- if a type is switching to true, make sure that this does not create
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
-- if switching on non-overlapping, check to see if that creates an error
-- condition.
--
CREATE OR REPLACE FUNCTION validate_net_range_toggle_nonoverlap()
RETURNS TRIGGER
AS $$
DECLARE
	_tally INTEGER;
BEGIN
	IF NEW.can_overlap = false THEN
		SELECT COUNT(*)
		INTO _tally
		FROM (
				SELECT nr.*, host(start.ip_address)::inet AS start_ip,
					host(stop.ip_address)::inet AS stop_ip
				FROM network_range nr
				JOIN netblock start ON start.netblock_id = nr.start_netblock_id
				JOIN netblock stop ON stop.netblock_id = nr.stop_netblock_id
			) n1 JOIN (
				SELECT nr.*, host(start.ip_address)::inet AS start_ip,
					host(stop.ip_address)::inet AS stop_ip
				FROM network_range nr
				JOIN netblock start ON start.netblock_id = nr.start_netblock_id
				JOIN netblock stop ON stop.netblock_id = nr.stop_netblock_id
			) n2 USING (network_range_type)
		WHERE n1.network_range_id != n2.network_range_id
		AND network_range_type = NEW.network_range_type
		AND (
			( n1.start_ip >= n2.start_ip AND n1.start_ip <= n2.stop_ip)
			OR
			( n1.stop_ip >= n2.start_ip AND n1.stop_ip <= n2.stop_ip)
		);

		IF _tally > 0 THEN
			RAISE EXCEPTION '% has % overlapping network ranges',
				NEW.network_range_type, _tally
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;

	IF NEW.require_cidr_boundary = true THEN
		SELECT COUNT(*)
		INTO _tally
		FROM (
				SELECT nr.*, host(start.ip_address)::inet AS start_ip,
					host(stop.ip_address)::inet AS stop_ip
				FROM network_range nr
				JOIN netblock start ON start.netblock_id = nr.start_netblock_id
				JOIN netblock stop ON stop.netblock_id = nr.stop_netblock_id
			) nr
		WHERE network_range_type = NEW.network_range_type
		AND (
			masklen(start_ip) != masklen(stop_ip)
			OR
			start_ip != network(start_ip)
			OR
			stop_ip != broadcast(stop_ip)
		);

		IF _tally > 0 THEN
			RAISE EXCEPTION '% has % cidr issues in network ranges',
				NEW.network_range_type, _tally
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	RETURN NEW;
END; $$
SET search_path=jazzhands
LANGUAGE plpgsql
SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_net_range_toggle_nonoverlap
	ON val_network_range_type;
CREATE CONSTRAINT TRIGGER trigger_validate_net_range_toggle_nonoverlap
	AFTER UPDATE OF can_overlap, require_cidr_boundary
	ON val_network_range_type
	DEFERRABLE INITIALLY IMMEDIATE
	FOR EACH ROW EXECUTE PROCEDURE
		jazzhands.validate_net_range_toggle_nonoverlap();


----------------------------------------------------------------------------
--
-- if a type is switching to true, make sure that this does not create
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
DECLARE
	_vnrt	val_network_range_type%ROWTYPE;
	_r		RECORD;
	_tally	INTEGER;
BEGIN
	--
	-- Check to see if changing these things causes any of the defined
	-- rules about the netblocks to change
	--
	PERFORM
	FROM	network_range nr
			JOIN netblock p ON p.netblock_id = nr.parent_netblock_id
			JOIN netblock start ON start.netblock_id = nr.start_netblock_id
			JOIN netblock stop ON stop.netblock_id = nr.stop_netblock_id
			JOIN val_network_range_type vnrt USING (network_range_type)
	WHERE	-- Check if this IP is even related to a range
			( p.netblock_id = NEW.netblock_id
				OR start.netblock_id = NEW.netblock_id
				OR stop.netblock_id = NEW.netblock_id
			) AND (
				-- If so, check to make usre that its the right type.
					p.can_subnet = true
				OR 	start.is_single_address = false
				OR 	stop.is_single_address = false
				-- and the start/stop is in the parent
				OR NOT (
					host(start.ip_address)::inet <<= p.ip_address
					AND host(stop.ip_address)::inet <<= p.ip_address
				)
				-- and if a type is forced, start/top have it
				OR ( vnrt.netblock_type IS NOT NULL
					AND NOT
					( start.netblock_type IS NOT DISTINCT FROM
						vnrt.netblock_type
					AND	stop.netblock_type IS NOT DISTINCT FROM
						vnrt.netblock_type
					)
				) -- and if a cidr boundary is required and its not on AS such
				OR ( vnrt.require_cidr_boundary = true
					AND NOT (
						start.ip_address = network(start.ip_address)
						AND
						stop.ip_address = broadcast(stop.ip_address)
					)
				)
				OR ( vnrt.require_cidr_boundary = true
					AND NOT (
						masklen(start.ip_address) !=
							masklen(stop.ip_address)
					)
				)

			)
	;

	IF FOUND THEN
		RAISE EXCEPTION 'Netblock changes conflict with network range requirements '
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	--
	-- If an IP changed, check to see if that made ranges overlap
	--
	IF OLD.ip_address IS DISTINCT FROM NEW.ip_address THEN
		FOR _r IN SELECT nr.*, host(start.ip_address)::inet AS start_ip,
					host(stop.ip_address)::inet AS stop_ip
				FROM network_range nr
					JOIN netblock start
						ON start.netblock_id = nr.start_netblock_id
					JOIN netblock stop
						ON stop.netblock_id = nr.stop_netblock_id
				WHERE nr.start_netblock_id = NEW.netblock_id
				OR nr.stop_netblock_id = NEW.netblock_id
		LOOP
			IF _r.stop_ip < _r.start_ip THEN
				RAISE EXCEPTION 'stop ip address can not be before start in network ranges.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
		END LOOP;
		FOR _vnrt IN SELECT *
				FROM val_network_range_type
				WHERE network_range_type IN (
					SELECT network_range_type
					FROM	network_range nr
					WHERE parent_netblock_id = NEW.netblock_id
					OR start_netblock_id = NEW.netblock_id
					OR stop_netblock_id = NEW.netblock_id
				) AND can_overlap = false
		LOOP
			SELECT count(*)
			INTO _tally
			FROM	network_range nr
				JOIN netblock start ON start.netblock_id = nr.start_netblock_id
				JOIN netblock stop ON stop.netblock_id = nr.stop_netblock_id
			WHERE	network_range_type = _vnrt.network_range_type
			AND (
				start.ip_address <<= NEW.ip_address AND
				stop.ip_address <<= NEW.ip_address
			)
			;

			IF _tally > 1 THEN
				RAISE EXCEPTION 'Netblock changes network range overlap with type % (%)',
					_vnrt.network_range_type, _tally
					USING ERRCODE = 'integrity_constraint_violation';
			END IF;
		END LOOP;

		SELECT count(*)
		INTO _tally
		FROM	network_range nr
			JOIN netblock start ON start.netblock_id = nr.start_netblock_id
			JOIN netblock stop ON stop.netblock_id = nr.stop_netblock_id
			JOIN val_network_range_type USING (network_range_type)
		WHERE require_cidr_boundary = true
		AND (
			nr.parent_netblock_id = NEW.netblock_id
			OR start_netblock_id = NEW.netblock_id
			OR stop_netblock_id = NEW.netblock_id
		) AND (
			masklen(start.ip_address) != masklen(stop.ip_address)
			OR start.ip_address != network(start.ip_address)
			OR stop.ip_address != broadcast(stop.ip_address)
		);

		IF _tally > 0 THEN
			RAISE EXCEPTION 'netblock is part of network_range_type % and creates % violations',
				_vnrt.network_range_type, _tally
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

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

