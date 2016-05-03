--
-- Copyright (c) 2016 Todd Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

/*
Invoked:

	--suffix=v70
	--post
	currency
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance();
select timeofday(), now();
--
-- Process middle (non-trigger) schema jazzhands
--
-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_change_realm_aca_realm');
CREATE OR REPLACE FUNCTION jazzhands.account_change_realm_aca_realm()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	SELECT	count(*)
	INTO	_tally
	FROM	account_collection_account
			JOIN account_collection USING (account_collection_id)
			JOIN val_account_collection_type vt USING (account_collection_type)
	WHERE	vt.account_realm_id IS NOT NULL
	AND		vt.account_realm_id != NEW.account_realm_id
	AND		account_id = NEW.account_id;
	
	IF _tally > 0 THEN
		RAISE EXCEPTION 'New account realm (%) is part of % account collections with a type restriction',
			NEW.account_realm_id,
			_tally
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'device_collection_hier_enforce');
CREATE OR REPLACE FUNCTION jazzhands.device_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	dct	val_device_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	dct
	FROM	val_device_collection_type
	WHERE	device_collection_type =
		(select device_collection_type from device_collection
			where device_collection_id = NEW.parent_device_collection_id);

	IF dct.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Device Collections of type % may not be hierarcical',
			dct.device_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'device_collection_member_enforce');
CREATE OR REPLACE FUNCTION jazzhands.device_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	dct	val_device_collection_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	dct
	FROM	val_device_collection_type
	WHERE	device_collection_type =
		(select device_collection_type from device_collection
			where device_collection_id = NEW.device_collection_id);

	IF dct.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from device_collection_device
		  where device_collection_id = NEW.device_collection_id;
		IF tally > dct.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF dct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from device_collection_device
		  		inner join device_collection using (device_collection_id)
		  where device_id = NEW.device_id
		  and	device_collection_type = dct.device_collection_type;
		IF tally > dct.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Device may not be a member of more than % collections of type %',
				dct.MAX_NUM_COLLECTIONS, dct.device_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'net_int_netblock_to_nbn_compat_after');
CREATE OR REPLACE FUNCTION jazzhands.net_int_netblock_to_nbn_compat_after()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	SELECT  count(*)
	  INTO  _tally
	  FROM  pg_catalog.pg_class
	 WHERE  relname = '__network_interface_netblocks'
	   AND  relpersistence = 't';

	IF _tally = 0 THEN
		CREATE TEMPORARY TABLE IF NOT EXISTS __network_interface_netblocks (
			network_interface_id INTEGER, netblock_id INTEGER
		);
	END IF;

	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
		SELECT count(*) INTO _tally FROM __network_interface_netblocks
		WHERE network_interface_id = NEW.network_interface_id
		AND netblock_id IS NOT DISTINCT FROM ( NEW.netblock_id );
		if _tally >  0 THEN
			RETURN NEW;
		END IF;
		INSERT INTO __network_interface_netblocks
			(network_interface_id, netblock_id)
		VALUES (NEW.network_interface_id,NEW.netblock_id);
	ELSIF TG_OP = 'DELETE' THEN
		SELECT count(*) INTO _tally FROM __network_interface_netblocks
		WHERE network_interface_id = OLD.network_interface_id
		AND netblock_id IS NOT DISTINCT FROM ( OLD.netblock_id );
		if _tally >  0 THEN
			RETURN OLD;
		END IF;
		INSERT INTO __network_interface_netblocks
			(network_interface_id, netblock_id)
		VALUES (OLD.network_interface_id,OLD.netblock_id);
	END IF;

	IF TG_OP = 'INSERT' THEN
		IF NEW.netblock_id IS NOT NULL THEN
			SELECT COUNT(*)
			INTO _tally
			FROM	network_interface_netblock
			WHERE	network_interface_id = NEW.network_interface_id
			AND		netblock_id = NEW.netblock_id;

			IF _tally = 0 THEN
				SELECT COUNT(*)
				INTO _tally
				FROM	network_interface_netblock
				WHERE	network_interface_id != NEW.network_interface_id
				AND		netblock_id = NEW.netblock_id;

				IF _tally != 0  THEN
					UPDATE network_interface_netblock
					SET network_interface_id = NEW.network_interface_id
					WHERE netblock_id = NEW.netblock_id;
				ELSE
					INSERT INTO network_interface_netblock
						(network_interface_id, netblock_id)
					VALUES
						(NEW.network_interface_id, NEW.netblock_id);
				END IF;
			END IF;
		END IF;
	ELSIF TG_OP = 'UPDATE'  THEN
		IF OLD.netblock_id is NULL and NEW.netblock_ID is NOT NULL THEN
			SELECT COUNT(*)
			INTO _tally
			FROM	network_interface_netblock
			WHERE	network_interface_id = NEW.network_interface_id
			AND		netblock_id = NEW.netblock_id;

			IF _tally = 0 THEN
				INSERT INTO network_interface_netblock
					(network_interface_id, netblock_id)
				VALUES
					(NEW.network_interface_id, NEW.netblock_id);
			END IF;
		ELSIF OLD.netblock_id IS NOT NULL and NEW.netblock_id is NOT NULL THEN
			IF OLD.netblock_id != NEW.netblock_id THEN
				UPDATE network_interface_netblock
					SET network_interface_id = NEW.network_interface_Id,
						netblock_id = NEW.netblock_id
						WHERE network_interface_id = OLD.network_interface_id
						AND netblock_id = OLD.netblock_id
						AND netblock_id != NEW.netblock_id
				;
			END IF;
		END IF;
	ELSIF TG_OP = 'DELETE' THEN
		IF OLD.netblock_id IS NOT NULL THEN
			DELETE from network_interface_netblock
				WHERE network_interface_id = OLD.network_interface_id
				AND netblock_id = OLD.netblock_id;
		END IF;
		RETURN OLD;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'net_int_netblock_to_nbn_compat_before');
CREATE OR REPLACE FUNCTION jazzhands.net_int_netblock_to_nbn_compat_before()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	SET CONSTRAINTS FK_NETINT_NB_NETINT_ID DEFERRED;
	SET CONSTRAINTS FK_NETINT_NB_NBLK_ID DEFERRED;

	RETURN OLD;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'network_interface_drop_tt');
CREATE OR REPLACE FUNCTION jazzhands.network_interface_drop_tt()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally INTEGER;
BEGIN
	SELECT  count(*)
	  INTO  _tally
	  FROM  pg_catalog.pg_class
	 WHERE  relname = '__network_interface_netblocks'
	   AND  relpersistence = 't';

	SET CONSTRAINTS FK_NETINT_NB_NETINT_ID IMMEDIATE;
	SET CONSTRAINTS FK_NETINT_NB_NBLK_ID IMMEDIATE;

	IF _tally > 0 THEN
		DROP TABLE IF EXISTS __network_interface_netblocks;
	END IF;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_val_network_range_type');
CREATE OR REPLACE FUNCTION jazzhands.validate_val_network_range_type()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
END; $function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.device_collection_after_hooks()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	BEGIN
		PERFORM local_hooks.device_collection_after_hooks();
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
			PERFORM 1;
	END;
	RETURN NULL;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.layer2_network_collection_after_hooks()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	BEGIN
		PERFORM local_hooks.layer2_network_collection_after_hooks();
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
			PERFORM 1;
	END;
	RETURN NULL;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.validate_netblock_to_range_changes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
END; $function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.validate_network_range_dns()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
END; $function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.validate_network_range_ips()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
END; $function$
;

--
-- Process middle (non-trigger) schema bidder
--
--
-- Process middle (non-trigger) schema api
--
--
-- Process middle (non-trigger) schema schema_support
--
--
-- Process middle (non-trigger) schema net_manip
--
--
-- Process middle (non-trigger) schema network_strings
--
--
-- Process middle (non-trigger) schema time_util
--
--
-- Process middle (non-trigger) schema dns_utils
--
--
-- Process middle (non-trigger) schema person_manip
--
--
-- Process middle (non-trigger) schema auto_ac_manip
--
--
-- Process middle (non-trigger) schema company_manip
--
--
-- Process middle (non-trigger) schema token_utils
--
--
-- Process middle (non-trigger) schema port_support
--
--
-- Process middle (non-trigger) schema port_utils
--
--
-- Process middle (non-trigger) schema device_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('device_utils', 'retire_device');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS device_utils.retire_device ( in_device_id integer, retire_modules boolean );
CREATE OR REPLACE FUNCTION device_utils.retire_device(in_device_id integer, retire_modules boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally		INTEGER;
	_r			RECORD;
	_d			DEVICE%ROWTYPE;
	_mgrid		DEVICE.DEVICE_ID%TYPE;
	_purgedev	boolean;
BEGIN
	_purgedev := false;

	BEGIN
		PERFORM local_hooks.device_retire_early(in_Device_Id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	SELECT * INTO _d FROM device WHERE device_id = in_Device_id;
	delete from dns_record where netblock_id in (
		select netblock_id 
		from network_interface where device_id = in_Device_id
	);

	delete from network_interface_purpose where device_id = in_Device_id;

	WITH ni AS  (
		delete from network_interface where device_id = in_Device_id
		RETURNING *
	) delete from network_interface_netblock where network_interface_id 
		IN (
			SELECT network_interface_id
		 	FROM ni
		); 

	PERFORM device_utils.purge_physical_ports( in_Device_id);
--	PERFORM device_utils.purge_power_ports( in_Device_id);

	delete from property where device_collection_id in (
		SELECT	dc.device_collection_id 
		  FROM	device_collection dc
				INNER JOIN device_collection_device dcd
		 			USING (device_collection_id)
		WHERE	dc.device_collection_type = 'per-device'
		  AND	dcd.device_id = in_Device_id
	);

	delete from device_collection_device where device_id = in_Device_id;
	delete from snmp_commstr where device_id = in_Device_id;

		
	IF _d.rack_location_id IS NOT NULL  THEN
		UPDATE device SET rack_location_id = NULL 
		WHERE device_id = in_Device_id;

		-- This should not be permitted based on constraints, but in case
		-- that constraint had to be disabled...
		SELECT	count(*)
		  INTO	tally
		  FROM	device
		 WHERE	rack_location_id = _d.RACK_LOCATION_ID;

		IF tally = 0 THEN
			DELETE FROM rack_location 
			WHERE rack_location_id = _d.RACK_LOCATION_ID;
		END IF;
	END IF;

	IF _d.chassis_location_id IS NOT NULL THEN
		RAISE EXCEPTION 'Retiring modules is not supported yet.';
	END IF;

	SELECT	manager_device_id
	INTO	_mgrid
	 FROM	device_management_controller
	WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc'
	LIMIT 1;

	IF _mgrid IS NOT NULL THEN
		DELETE FROM device_management_controller
		WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc'
			AND manager_device_id = _mgrid;

		PERFORM device_utils.retire_device( manager_device_id)
		  FROM	device_management_controller
		WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc';
	END IF;

	BEGIN
		PERFORM local_hooks.device_retire_late(in_Device_Id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	SELECT count(*)
	INTO tally
	FROM device_note
	WHERE device_id = in_Device_id;

	--
	-- If there is no notes or serial number its save to remove
	-- 
	IF tally = 0 AND _d.ASSET_ID is NULL THEN
		_purgedev := true;
	END IF;

	IF _purgedev THEN
		--
		-- If there is an fk violation, we just preserve the record but
		-- delete all the identifying characteristics
		--
		BEGIN
			DELETE FROM device where device_id = in_Device_Id;
			return false;
		EXCEPTION WHEN foreign_key_violation THEN
			PERFORM 1;
		END;
	END IF;

	UPDATE device SET 
		device_name =NULL,
		service_environment_id = (
			select service_environment_id from service_environment
			where service_environment_name = 'unallocated'),
		device_status = 'removed',
		voe_symbolic_track_id = NULL,
		is_monitored = 'N',
		should_fetch_config = 'N',
		description = NULL
	WHERE device_id = in_Device_id;

	return true;
END;
$function$
;

--
-- Process middle (non-trigger) schema netblock_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_free_netblocks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.find_free_netblocks ( parent_netblock_list integer[], netmask_bits integer, single_address boolean, allocation_method text, max_addresses integer, desired_ip_address inet, rnd_masklen_threshold integer, rnd_max_count integer );
CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblocks(parent_netblock_list integer[], netmask_bits integer DEFAULT NULL::integer, single_address boolean DEFAULT false, allocation_method text DEFAULT NULL::text, max_addresses integer DEFAULT 1024, desired_ip_address inet DEFAULT NULL::inet, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024)
 RETURNS TABLE(ip_address inet, netblock_type character varying, ip_universe_id integer)
 LANGUAGE plpgsql
AS $function$
DECLARE
	parent_nbid		jazzhands.netblock.netblock_id%TYPE;
	netblock_rec	jazzhands.netblock%ROWTYPE;
	netrange_rec	RECORD;
	inet_list		inet[];
	current_ip		inet;
	saved_method	text;
	min_ip			inet;
	max_ip			inet;
	matches			integer;
	rnd_matches		integer;
	max_rnd_value	bigint;
	rnd_value		bigint;
	family_bits		integer;
BEGIN
	matches := 0;
	saved_method = allocation_method;

	IF allocation_method IS NOT NULL AND allocation_method
			NOT IN ('top', 'bottom', 'random', 'default') THEN
		RAISE 'address_type must be one of top, bottom, random, or default'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	--
	-- Sanitize masklen input.  This is a little complicated.
	--
	-- If a single address is desired, we always use a /32 or /128
	-- in the parent loop and everything else is ignored
	--
	-- Otherwise, if netmask_bits is passed, that wins, otherwise
	-- the netmask of whatever is passed with desired_ip_address wins
	--
	-- If none of these are the case, then things are wrong and we
	-- bail
	--

	IF NOT single_address THEN 
		IF desired_ip_address IS NOT NULL AND netmask_bits IS NULL THEN
			netmask_bits := masklen(desired_ip_address);
		ELSIF desired_ip_address IS NOT NULL AND 
				netmask_bits IS NOT NULL THEN
			desired_ip_address := set_masklen(desired_ip_address,
				netmask_bits);
		END IF;
		IF netmask_bits IS NULL THEN
			RAISE EXCEPTION 'netmask_bits must be set'
			USING ERRCODE = 'invalid_parameter_value';
		END IF;
		IF allocation_method = 'random' THEN
			RAISE EXCEPTION 'random netblocks may only be returned for single addresses'
			USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	FOREACH parent_nbid IN ARRAY parent_netblock_list LOOP
		rnd_matches := 0;
		--
		-- Restore this, because we may have overrridden it for a previous
		-- block
		--
		allocation_method = saved_method;
		SELECT 
			* INTO netblock_rec
		FROM
			jazzhands.netblock n
		WHERE
			n.netblock_id = parent_nbid;

		IF NOT FOUND THEN
			RAISE EXCEPTION 'Netblock % does not exist', parent_nbid;
		END IF;

		family_bits := 
			(CASE family(netblock_rec.ip_address) WHEN 4 THEN 32 ELSE 128 END);

		-- If desired_ip_address is passed, then allocation_method is
		-- irrelevant

		IF desired_ip_address IS NOT NULL THEN
			--
			-- If the IP address is not the same family as the parent block,
			-- we aren't going to find it
			--
			IF family(desired_ip_address) != 
					family(netblock_rec.ip_address) THEN
				CONTINUE;
			END IF;
			allocation_method := 'bottom';
		END IF;

		--
		-- If allocation_method is 'default' or NULL, then use 'bottom'
		-- unless it's for a single IPv6 address in a netblock larger than 
		-- rnd_masklen_threshold
		--
		IF allocation_method IS NULL OR allocation_method = 'default' THEN
			allocation_method := 
				CASE WHEN 
					single_address AND 
					family(netblock_rec.ip_address) = 6 AND
					masklen(netblock_rec.ip_address) <= rnd_masklen_threshold
				THEN
					'random'
				ELSE
					'bottom'
				END;
		END IF;

		IF allocation_method = 'random' AND 
				family_bits - masklen(netblock_rec.ip_address) < 2 THEN
			-- Random allocation doesn't work if we don't have enough
			-- bits to play with, so just do sequential.
			allocation_method := 'bottom';
		END IF;

		IF single_address THEN 
			netmask_bits := family_bits;
			IF desired_ip_address IS NOT NULL THEN
				desired_ip_address := set_masklen(desired_ip_address,
					masklen(netblock_rec.ip_address));
			END IF;
		ELSIF netmask_bits <= masklen(netblock_rec.ip_address) THEN
			-- If the netmask is not for a smaller netblock than this parent,
			-- then bounce to the next one, because maybe it's larger
			RAISE DEBUG
				'netblock (%) is not larger than netmask_bits of % - skipping',
				masklen(netblock_rec.ip_address),
				netmask_bits;
			CONTINUE;
		END IF;

		IF netmask_bits > family_bits THEN
			RAISE EXCEPTION 'netmask_bits must be no more than % for netblock %',
				family_bits,
				netblock_rec.ip_address;
		END IF;

		--
		-- Short circuit the check if we're looking for a specific address
		-- and it's not in this netblock
		--

		IF desired_ip_address IS NOT NULL AND
				NOT (desired_ip_address <<= netblock_rec.ip_address) THEN
			RAISE DEBUG 'desired_ip_address % is not in netblock %',
				desired_ip_address,
				netblock_rec.ip_address;
			CONTINUE;
		END IF;

		IF single_address AND netblock_rec.can_subnet = 'Y' THEN
			RAISE EXCEPTION 'single addresses may not be assigned to to a block where can_subnet is Y';
		END IF;

		IF (NOT single_address) AND netblock_rec.can_subnet = 'N' THEN
			RAISE EXCEPTION 'Netblock % (%) may not be subnetted',
				netblock_rec.ip_address,
				netblock_rec.netblock_id;
		END IF;

		RAISE DEBUG 'Searching netblock % (%) using the % allocation method',
			netblock_rec.netblock_id,
			netblock_rec.ip_address,
			allocation_method;

		IF desired_ip_address IS NOT NULL THEN
			min_ip := desired_ip_address;
			max_ip := desired_ip_address + 1;
		ELSE
			min_ip := netblock_rec.ip_address;
			max_ip := broadcast(min_ip) + 1;
		END IF;

		IF allocation_method = 'top' THEN
			current_ip := network(set_masklen(max_ip - 1, netmask_bits));
		ELSIF allocation_method = 'random' THEN
			max_rnd_value := (x'7fffffffffffffff'::bigint >> CASE 
				WHEN family_bits - masklen(netblock_rec.ip_address) >= 63
				THEN 0
				ELSE 63 - (family_bits - masklen(netblock_rec.ip_address))
				END) - 2;
			-- random() appears to only do 32-bits, which is dumb
			-- I'm pretty sure that all of the casts are not required here,
			-- but better to make sure
			current_ip := min_ip + 
					((((random() * x'7fffffff'::bigint)::bigint << 32) + 
					(random() * x'ffffffff'::bigint)::bigint + 1)
					% max_rnd_value) + 1;
		ELSE -- it's 'bottom'
			current_ip := set_masklen(min_ip, netmask_bits);
		END IF;

		-- For single addresses, make the netmask match the netblock of the
		-- containing block, and skip the network and broadcast addresses
		-- We shouldn't need to skip for IPv6 addresses, but some things
		-- apparently suck

		IF single_address THEN
			current_ip := set_masklen(current_ip, 
				masklen(netblock_rec.ip_address));
			--
			-- If we're not allocating a single /31 or /32 for IPv4 or
			-- /127 or /128 for IPv6, then we want to skip the all-zeros
			-- and all-ones addresses
			--
			IF masklen(netblock_rec.ip_address) < (family_bits - 1) AND
					desired_ip_address IS NULL THEN
				current_ip := current_ip + 
					CASE WHEN allocation_method = 'top' THEN -1 ELSE 1 END;
				min_ip := min_ip + 1;
				max_ip := max_ip - 1;
			END IF;
		END IF;

		RAISE DEBUG 'Starting with IP address % with step masklen of %',
			current_ip,
			netmask_bits;

		WHILE (
				current_ip >= min_ip AND
				current_ip < max_ip AND
				matches < max_addresses AND
				rnd_matches < rnd_max_count
		) LOOP
			RAISE DEBUG '   Checking netblock %', current_ip;

			IF single_address THEN
				--
				-- Check to see if netblock is in a network_range, and if it is,
				-- then set the value to the top or bottom of the range, or
				-- another random value as appropriate
				--
				SELECT 
					network_range_id,
					start_nb.ip_address AS start_ip_address,
					stop_nb.ip_address AS stop_ip_address
				INTO netrange_rec
				FROM
					jazzhands.network_range nr,
					jazzhands.netblock start_nb,
					jazzhands.netblock stop_nb
				WHERE
					nr.start_netblock_id = start_nb.netblock_id AND
					nr.stop_netblock_id = stop_nb.netblock_id AND
					nr.parent_netblock_id = netblock_rec.netblock_id AND
					start_nb.ip_address <= current_ip AND
					stop_nb.ip_address >= current_ip;

				IF FOUND THEN
					current_ip := CASE 
						WHEN allocation_method = 'bottom' THEN
							netrange_rec.stop_ip_address + 1
						WHEN allocation_method = 'top' THEN
							netrange_rec.start_ip_address - 1
						ELSE min_ip + ((
							((random() * x'7fffffff'::bigint)::bigint << 32) 
							+ 
							(random() * x'ffffffff'::bigint)::bigint + 1
							) % max_rnd_value) + 1 
					END;
					CONTINUE;
				END IF;
			END IF;
							
				
			PERFORM * FROM jazzhands.netblock n WHERE
				n.ip_universe_id = netblock_rec.ip_universe_id AND
				n.netblock_type = netblock_rec.netblock_type AND
				-- A block with the parent either contains or is contained
				-- by this block
				n.parent_netblock_id = netblock_rec.netblock_id AND
				CASE WHEN single_address THEN
					n.ip_address = current_ip
				ELSE
					(n.ip_address >>= current_ip OR current_ip >>= n.ip_address)
				END;
			IF NOT FOUND AND (inet_list IS NULL OR
					NOT (current_ip = ANY(inet_list))) THEN
				find_free_netblocks.netblock_type :=
					netblock_rec.netblock_type;
				find_free_netblocks.ip_universe_id :=
					netblock_rec.ip_universe_id;
				find_free_netblocks.ip_address := current_ip;
				RETURN NEXT;
				inet_list := array_append(inet_list, current_ip);
				matches := matches + 1;
				-- Reset random counter if we found something
				rnd_matches := 0;
			ELSIF allocation_method = 'random' THEN
				-- Increase random counter if we didn't find something
				rnd_matches := rnd_matches + 1;
			END IF;

			-- Select the next IP address
			current_ip := 
				CASE WHEN single_address THEN
					CASE 
						WHEN allocation_method = 'bottom' THEN current_ip + 1
						WHEN allocation_method = 'top' THEN current_ip - 1
						ELSE min_ip + ((
							((random() * x'7fffffff'::bigint)::bigint << 32) 
							+ 
							(random() * x'ffffffff'::bigint)::bigint + 1
							) % max_rnd_value) + 1 
					END
				ELSE
					CASE WHEN allocation_method = 'bottom' THEN 
						network(broadcast(current_ip) + 1)
					ELSE 
						network(current_ip - 1)
					END
				END;
		END LOOP;
	END LOOP;
	RETURN;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'list_unallocated_netblocks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.list_unallocated_netblocks ( netblock_id integer, ip_address inet, ip_universe_id integer, netblock_type text );
CREATE OR REPLACE FUNCTION netblock_utils.list_unallocated_netblocks(netblock_id integer DEFAULT NULL::integer, ip_address inet DEFAULT NULL::inet, ip_universe_id integer DEFAULT 0, netblock_type text DEFAULT 'default'::text)
 RETURNS TABLE(ip_addr inet)
 LANGUAGE plpgsql
AS $function$
DECLARE
	ip_array		inet[];
	netblock_rec	RECORD;
	parent_nbid		jazzhands.netblock.netblock_id%TYPE;
	family_bits		integer;
	idx				integer;
	subnettable		boolean;
BEGIN
	subnettable := true;
	IF netblock_id IS NOT NULL THEN
		SELECT * INTO netblock_rec FROM jazzhands.netblock n WHERE n.netblock_id = 
			list_unallocated_netblocks.netblock_id;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'netblock_id % not found', netblock_id;
		END IF;
		IF netblock_rec.is_single_address = 'Y' THEN
			RETURN;
		END IF;
		ip_address := netblock_rec.ip_address;
		ip_universe_id := netblock_rec.ip_universe_id;
		netblock_type := netblock_rec.netblock_type;
		subnettable := CASE WHEN netblock_rec.can_subnet = 'N' 
			THEN false ELSE true
			END;
	ELSIF ip_address IS NOT NULL THEN
		ip_universe_id := 0;
		netblock_type := 'default';
	ELSE
		RAISE EXCEPTION 'netblock_id or ip_address must be passed';
	END IF;
	IF (subnettable) THEN
		SELECT ARRAY(
			SELECT 
				n.ip_address
			FROM
				netblock n
			WHERE
				n.ip_address <<= list_unallocated_netblocks.ip_address AND
				n.ip_universe_id = list_unallocated_netblocks.ip_universe_id AND
				n.netblock_type = list_unallocated_netblocks.netblock_type AND
				is_single_address = 'N' AND
				can_subnet = 'N'
			ORDER BY
				n.ip_address
		) INTO ip_array;
	ELSE
		SELECT ARRAY(
			SELECT 
				set_masklen(n.ip_address, 
					CASE WHEN family(n.ip_address) = 4 THEN 32
					ELSE 128
					END)
			FROM
				netblock n
			WHERE
				n.ip_address <<= list_unallocated_netblocks.ip_address AND
				n.ip_address != list_unallocated_netblocks.ip_address AND
				n.ip_universe_id = list_unallocated_netblocks.ip_universe_id AND
				n.netblock_type = list_unallocated_netblocks.netblock_type
			ORDER BY
				n.ip_address
		) INTO ip_array;
	END IF;

	IF array_length(ip_array, 1) IS NULL THEN
		ip_addr := ip_address;
		RETURN NEXT;
		RETURN;
	END IF;

	ip_array := array_prepend(
		list_unallocated_netblocks.ip_address - 1, 
		array_append(
			ip_array, 
			broadcast(list_unallocated_netblocks.ip_address) + 1
			));

	idx := 1;
	WHILE idx < array_length(ip_array, 1) LOOP
		RETURN QUERY SELECT cin.ip_addr FROM
			netblock_utils.calculate_intermediate_netblocks(ip_array[idx], ip_array[idx + 1]) cin;
		idx := idx + 1;
	END LOOP;

	RETURN;
END;
$function$
;

--
-- Process middle (non-trigger) schema netblock_manip
--
-- New function
CREATE OR REPLACE FUNCTION netblock_manip.create_network_range(start_ip_address inet, stop_ip_address inet, network_range_type character varying, parent_netblock_id integer DEFAULT NULL::integer, description character varying DEFAULT NULL::character varying, allow_assigned boolean DEFAULT false)
 RETURNS network_range
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	par_netblock	RECORD;
	start_netblock	RECORD;
	stop_netblock	RECORD;
	netrange		RECORD;
	nrtype			ALIAS FOR network_range_type;
	pnbid			ALIAS FOR parent_netblock_id;
BEGIN
	--
	-- If the network range already exists, then just return it, even if the
	--
	SELECT 
		nr.* INTO netrange
	FROM
		network_range nr JOIN
		netblock startnb ON (nr.start_netblock_id = startnb.netblock_id) JOIN
		netblock stopnb ON (nr.stop_netblock_id = stopnb.netblock_id)
	WHERE
		nr.network_range_type = nrtype AND
		host(startnb.ip_address) = host(start_ip_address) AND
		host(stopnb.ip_address) = host(stop_ip_address) AND
		CASE WHEN pnbid IS NOT NULL THEN 
			(pnbid = nr.parent_netblock_id)
		ELSE
			true
		END;

	IF FOUND THEN
		RETURN netrange;
	END IF;

	--
	-- If any other network ranges exist that overlap this, then error
	--
	PERFORM 
		*
	FROM
		network_range nr JOIN
		netblock startnb ON (nr.start_netblock_id = startnb.netblock_id) JOIN
		netblock stopnb ON (nr.stop_netblock_id = stopnb.netblock_id)
	WHERE
		nr.network_range_type = nrtype AND ((
			host(startnb.ip_address)::inet <= host(start_ip_address)::inet AND
			host(stopnb.ip_address)::inet >= host(start_ip_address)::inet
		) OR (
			host(startnb.ip_address)::inet <= host(stop_ip_address)::inet AND
			host(stopnb.ip_address)::inet >= host(stop_ip_address)::inet
		));

	IF FOUND THEN
		RAISE 'create_network_range: a network_range of type % already exists that has addresses between % and %',
			nrtype, start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
	END IF;

	IF parent_netblock_id IS NOT NULL THEN
		SELECT * INTO par_netblock WHERE netblock_id = parent_netblock_id;
		IF NOT FOUND THEN
			RAISE 'create_network_range: parent_netblock_id % does not exist',
				parent_netblock_id USING ERRCODE = 'foreign_key_violation';
		END IF;
	ELSE
		SELECT * INTO par_netblock FROM netblock WHERE netblock_id = (
			SELECT 
				*
			FROM
				netblock_utils.find_best_parent_id(
					in_ipaddress := start_ip_address
				)
		);

		IF NOT FOUND THEN
			RAISE 'create_network_range: valid parent netblock for start_ip_address % does not exist',
				start_ip_address USING ERRCODE = 'check_violation';
		END IF;
	END IF;

	IF par_netblock.can_subnet != 'N' OR 
			par_netblock.is_single_address != 'N' THEN
		RAISE 'create_network_range: parent netblock % must not be subnettable or a single address',
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (start_ip_address <<= par_netblock.ip_address) THEN
		RAISE 'create_network_range: start_ip_address % is not contained by parent netblock % (%)',
			start_ip_address, par_netblock.ip_address,
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (stop_ip_address <<= par_netblock.ip_address) THEN
		RAISE 'create_network_range: stop_ip_address % is not contained by parent netblock % (%)',
			stop_ip_address, par_netblock.ip_address,
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (start_ip_address <= stop_ip_address) THEN
		RAISE 'create_network_range: start_ip_address % is not lower than stop_ip_address %',
			start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
	END IF;

	--
	-- Validate that there are not currently any addresses assigned in the
	-- range, unless allow_assigned is set
	--
	IF NOT allow_assigned THEN
		PERFORM 
			*
		FROM
			netblock n
		WHERE
			n.parent_netblock_id = par_netblock.netblock_id AND
			host(n.ip_address)::inet > host(start_ip_address)::inet AND
			host(n.ip_address)::inet < host(stop_ip_address)::inet;

		IF FOUND THEN
			RAISE 'create_network_range: netblocks are already present for parent netblock % betweeen % and %',
			par_netblock.netblock_id,
			start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
		END IF;
	END IF;

	--
	-- Ok, well, we should be able to insert things now
	--

	SELECT
		*
	FROM
		netblock n
	INTO
		start_netblock
	WHERE
		host(n.ip_address)::inet = start_ip_address AND
		n.netblock_type = 'network_range' AND
		n.can_subnet = 'N' AND
		n.is_single_address = 'Y' AND
		n.ip_universe_id = par_netblock.ip_universe_id;

	IF NOT FOUND THEN
		INSERT INTO netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			netblock_status,
			ip_universe_id
		) VALUES (
			host(start_ip_address)::inet,
			'network_range',
			'Y',
			'N',
			'Allocated',
			par_netblock.ip_universe_id
		) RETURNING * INTO start_netblock;
	END IF;

	SELECT
		*
	FROM
		netblock n
	INTO
		stop_netblock
	WHERE
		host(n.ip_address)::inet = stop_ip_address AND
		n.netblock_type = 'network_range' AND
		n.can_subnet = 'N' AND
		n.is_single_address = 'Y' AND
		n.ip_universe_id = par_netblock.ip_universe_id;

	IF NOT FOUND THEN
		INSERT INTO netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			netblock_status,
			ip_universe_id
		) VALUES (
			host(stop_ip_address)::inet,
			'network_range',
			'Y',
			'N',
			'Allocated',
			par_netblock.ip_universe_id
		) RETURNING * INTO stop_netblock;
	END IF;

	INSERT INTO network_range (
		network_range_type,
		description,
		parent_netblock_id,
		start_netblock_id,
		stop_netblock_id
	) VALUES (
		nrtype,
		description,
		par_netblock.netblock_id,
		start_netblock.netblock_id,
		stop_netblock.netblock_id
	) RETURNING * INTO netrange;

	RETURN netrange;

	RETURN NULL;
END;
$function$
;

--
-- Process middle (non-trigger) schema physical_address_utils
--
--
-- Process middle (non-trigger) schema component_utils
--
--
-- Process middle (non-trigger) schema snapshot_manip
--
--
-- Process middle (non-trigger) schema lv_manip
--
--
-- Process middle (non-trigger) schema approval_utils
--
--
-- Process middle (non-trigger) schema account_collection_manip
--
--
-- Process middle (non-trigger) schema salesforce
--
--
-- Process middle (non-trigger) schema script_hooks
--
-- Creating new sequences....


--------------------------------------------------------------------
-- DEALING WITH TABLE val_country_code [1102873]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_country_code', 'val_country_code');

-- FOREIGN KEYS FROM
ALTER TABLE person_contact DROP CONSTRAINT IF EXISTS fk_person_type_iso_code;
ALTER TABLE physical_address DROP CONSTRAINT IF EXISTS fk_physaddr_iso_cc;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_country_code');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_country_code DROP CONSTRAINT IF EXISTS pk_val_country_code;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_country_code ON jazzhands.val_country_code;
DROP TRIGGER IF EXISTS trigger_audit_val_country_code ON jazzhands.val_country_code;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_country_code');
---- BEGIN audit.val_country_code TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_country_code', 'val_country_code');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_country_code');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_country_code_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependent_objects_for_replay('audit', 'val_country_code');
---- DONE audit.val_country_code TEARDOWN


ALTER TABLE val_country_code RENAME TO val_country_code_v70;
ALTER TABLE audit.val_country_code RENAME TO val_country_code_v70;

CREATE TABLE val_country_code
(
	iso_country_code	character(2) NOT NULL,
	dial_country_code	varchar(4) NOT NULL,
	primary_iso_currency_code	character(3)  NULL,
	country_name	varchar(255)  NULL,
	display_priority	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_country_code', false);
INSERT INTO val_country_code (
	iso_country_code,
	dial_country_code,
	primary_iso_currency_code,		-- new column (primary_iso_currency_code)
	country_name,
	display_priority,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	iso_country_code,
	dial_country_code,
	NULL,		-- new column (primary_iso_currency_code)
	country_name,
	display_priority,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_country_code_v70;

INSERT INTO audit.val_country_code (
	iso_country_code,
	dial_country_code,
	primary_iso_currency_code,		-- new column (primary_iso_currency_code)
	country_name,
	display_priority,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	iso_country_code,
	dial_country_code,
	NULL,		-- new column (primary_iso_currency_code)
	country_name,
	display_priority,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_country_code_v70;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_country_code ADD CONSTRAINT pk_val_country_code PRIMARY KEY (iso_country_code);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif1val_country_code ON val_country_code USING btree (primary_iso_currency_code);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_country_code and person_contact
ALTER TABLE person_contact
	ADD CONSTRAINT fk_person_type_iso_code
	FOREIGN KEY (iso_country_code) REFERENCES val_country_code(iso_country_code);
-- consider FK val_country_code and physical_address
ALTER TABLE physical_address
	ADD CONSTRAINT fk_physaddr_iso_cc
	FOREIGN KEY (iso_country_code) REFERENCES val_country_code(iso_country_code);

-- FOREIGN KEYS TO
-- consider FK val_country_code and val_iso_currency_code
-- Skipping this FK since table does not exist yet
--ALTER TABLE val_country_code
--	ADD CONSTRAINT r_787
--	FOREIGN KEY (primary_iso_currency_code) REFERENCES val_iso_currency_code(iso_currency_code);


-- TRIGGERS
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_country_code');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_country_code');
DROP TABLE IF EXISTS val_country_code_v70;
DROP TABLE IF EXISTS audit.val_country_code_v70;
-- DONE DEALING WITH TABLE val_country_code [1112809]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_iso_currency_code
CREATE TABLE val_iso_currency_code
(
	iso_currency_code	character(3) NOT NULL,
	description	varchar(255)  NULL,
	currency_symbol	varchar(50) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_iso_currency_code', true);
--
-- Copying initialization data
--

INSERT INTO val_iso_currency_code (
iso_currency_code,description,currency_symbol
) VALUES
	('AFN','Afghanistan Afghani','؋'),
	('ALL','Albania Lek','Lek'),
	('ANG','Netherlands Antilles Guilder','ƒ'),
	('ARS','Argentina Peso','$'),
	('AUD','Australia Dollar','$'),
	('AWG','Aruba Guilder','ƒ'),
	('AZN','Azerbaijan New Manat','ман'),
	('BAM','Bosnia and Herzegovina Convertible Marka','KM'),
	('BBD','Barbados Dollar','$'),
	('BGN','Bulgaria Lev','лв'),
	('BMD','Bermuda Dollar','$'),
	('BND','Brunei Darussalam Dollar','$'),
	('BOB','Bolivia Bolíviano','$b'),
	('BRL','Brazil Real','R$'),
	('BSD','Bahamas Dollar','$'),
	('BWP','Botswana Pula','P'),
	('BYR','Belarus Ruble','p.'),
	('BZD','Belize Dollar','BZ$'),
	('CAD','Canada Dollar','$'),
	('CHF','Switzerland Franc','CHF'),
	('CLP','Chile Peso','$'),
	('CNY','China Yuan Renminbi','¥'),
	('COP','Colombia Peso','$'),
	('CRC','Costa Rica Colon','₡'),
	('CUP','Cuba Peso','₱'),
	('CZK','Czech Republic Koruna','Kč'),
	('DKK','Denmark Krone','kr'),
	('DOP','Dominican Republic Peso','RD$'),
	('EGP','Egypt Pound','£'),
	('EUR','Euro Member Countries','€'),
	('FJD','Fiji Dollar','$'),
	('FKP','Falkland Islands (Malvinas) Pound','£'),
	('GBP','United Kingdom Pound','£'),
	('GGP','Guernsey Pound','£'),
	('GHS','Ghana Cedi','¢'),
	('GIP','Gibraltar Pound','£'),
	('GTQ','Guatemala Quetzal','Q'),
	('GYD','Guyana Dollar','$'),
	('HKD','Hong Kong Dollar','$'),
	('HNL','Honduras Lempira','L'),
	('HRK','Croatia Kuna','kn'),
	('HUF','Hungary Forint','Ft'),
	('IDR','Indonesia Rupiah','Rp'),
	('ILS','Israel Shekel','₪'),
	('IMP','Isle of Man Pound','£'),
	('INR','India Rupee','₹'),
	('IRR','Iran Rial','﷼'),
	('ISK','Iceland Krona','kr'),
	('JEP','Jersey Pound','£'),
	('JMD','Jamaica Dollar','J$'),
	('JPY','Japan Yen','¥'),
	('KGS','Kyrgyzstan Som','лв'),
	('KHR','Cambodia Riel','៛'),
	('KPW','Korea (North) Won','₩'),
	('KRW','Korea (South) Won','₩'),
	('KYD','Cayman Islands Dollar','$'),
	('KZT','Kazakhstan Tenge','лв'),
	('LAK','Laos Kip','₭'),
	('LBP','Lebanon Pound','£'),
	('LKR','Sri Lanka Rupee','₨'),
	('LRD','Liberia Dollar','$'),
	('MKD','Macedonia Denar','ден'),
	('MNT','Mongolia Tughrik','₮'),
	('MUR','Mauritius Rupee','₨'),
	('MXN','Mexico Peso','$'),
	('MYR','Malaysia Ringgit','RM'),
	('MZN','Mozambique Metical','MT'),
	('NAD','Namibia Dollar','$'),
	('NGN','Nigeria Naira','₦'),
	('NIO','Nicaragua Cordoba','C$'),
	('NOK','Norway Krone','kr'),
	('NPR','Nepal Rupee','₨'),
	('NZD','New Zealand Dollar','$'),
	('OMR','Oman Rial','﷼'),
	('PAB','Panama Balboa','B/.'),
	('PEN','Peru Sol','S/.'),
	('PHP','Philippines Peso','₱'),
	('PKR','Pakistan Rupee','₨'),
	('PLN','Poland Zloty','zł'),
	('PYG','Paraguay Guarani','Gs'),
	('QAR','Qatar Riyal','﷼'),
	('RON','Romania New Leu','lei'),
	('RSD','Serbia Dinar','Дин.'),
	('RUB','Russia Ruble','руб'),
	('SAR','Saudi Arabia Riyal','﷼'),
	('SBD','Solomon Islands Dollar','$'),
	('SCR','Seychelles Rupee','₨'),
	('SEK','Sweden Krona','kr'),
	('SGD','Singapore Dollar','$'),
	('SHP','Saint Helena Pound','£'),
	('SOS','Somalia Shilling','S'),
	('SRD','Suriname Dollar','$'),
	('SVC','El Salvador Colon','$'),
	('SYP','Syria Pound','£'),
	('THB','Thailand Baht','฿'),
	('TRY','Turkey Lira','₺'),
	('TTD','Trinidad and Tobago Dollar','TT$'),
	('TVD','Tuvalu Dollar','$'),
	('TWD','Taiwan New Dollar','NT$'),
	('UAH','Ukraine Hryvnia','₴'),
	('USD','United States Dollar','$'),
	('UYU','Uruguay Peso','$U'),
	('UZS','Uzbekistan Som','лв'),
	('VEF','Venezuela Bolivar','Bs'),
	('VND','Viet Nam Dong','₫'),
	('XCD','East Caribbean Dollar','$'),
	('YER','Yemen Rial','﷼'),
	('ZAR','South Africa Rand','R'),
	('ZWD','Zimbabwe Dollar','Z$')
;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_iso_currency_code ADD CONSTRAINT pk_val_iso_currency_code PRIMARY KEY (iso_currency_code);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_iso_currency_code and val_country_code
ALTER TABLE val_country_code
	ADD CONSTRAINT r_787
	FOREIGN KEY (primary_iso_currency_code) REFERENCES val_iso_currency_code(iso_currency_code);

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_iso_currency_code');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_iso_currency_code');
-- DONE DEALING WITH TABLE val_iso_currency_code [1112975]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_netblock_collection_type [1103092]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_netblock_collection_type', 'val_netblock_collection_type');

-- FOREIGN KEYS FROM
ALTER TABLE netblock_collection DROP CONSTRAINT IF EXISTS fk_nblk_coll_v_nblk_c_typ;
ALTER TABLE val_property DROP CONSTRAINT IF EXISTS fk_val_prop_nblk_coll_type;
ALTER TABLE val_property DROP CONSTRAINT IF EXISTS fk_val_property_netblkcolltype;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_netblock_collection_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_netblock_collection_type DROP CONSTRAINT IF EXISTS pk_val_netblock_collection_typ;
-- INDEXES
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_netblock_collection_type DROP CONSTRAINT IF EXISTS check_any_yes_no_nc_singaddr_r;
ALTER TABLE jazzhands.val_netblock_collection_type DROP CONSTRAINT IF EXISTS check_yes_no_nct_chh;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_netblock_collection_type ON jazzhands.val_netblock_collection_type;
DROP TRIGGER IF EXISTS trigger_audit_val_netblock_collection_type ON jazzhands.val_netblock_collection_type;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_netblock_collection_type');
---- BEGIN audit.val_netblock_collection_type TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_netblock_collection_type', 'val_netblock_collection_type');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_netblock_collection_type');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_netblock_collection_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependent_objects_for_replay('audit', 'val_netblock_collection_type');
---- DONE audit.val_netblock_collection_type TEARDOWN


ALTER TABLE val_netblock_collection_type RENAME TO val_netblock_collection_type_v70;
ALTER TABLE audit.val_netblock_collection_type RENAME TO val_netblock_collection_type_v70;

CREATE TABLE val_netblock_collection_type
(
	netblock_collection_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	max_num_members	integer  NULL,
	max_num_collections	integer  NULL,
	can_have_hierarchy	character(1) NOT NULL,
	netblock_single_addr_restrict	varchar(3) NOT NULL,
	netblock_ip_family_restrict	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_netblock_collection_type', false);
ALTER TABLE val_netblock_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE val_netblock_collection_type
	ALTER netblock_single_addr_restrict
	SET DEFAULT 'ANY'::character varying;
INSERT INTO val_netblock_collection_type (
	netblock_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	netblock_single_addr_restrict,
	netblock_ip_family_restrict,		-- new column (netblock_ip_family_restrict)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	netblock_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	netblock_single_addr_restrict,
	NULL,		-- new column (netblock_ip_family_restrict)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_netblock_collection_type_v70;

INSERT INTO audit.val_netblock_collection_type (
	netblock_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	netblock_single_addr_restrict,
	netblock_ip_family_restrict,		-- new column (netblock_ip_family_restrict)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	netblock_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	netblock_single_addr_restrict,
	NULL,		-- new column (netblock_ip_family_restrict)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_netblock_collection_type_v70;

ALTER TABLE val_netblock_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE val_netblock_collection_type
	ALTER netblock_single_addr_restrict
	SET DEFAULT 'ANY'::character varying;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_netblock_collection_type ADD CONSTRAINT pk_val_netblock_collection_typ PRIMARY KEY (netblock_collection_type);

-- Table/Column Comments
COMMENT ON COLUMN val_netblock_collection_type.max_num_members IS 'Maximum INTEGER of members in a given collection of this type
';
COMMENT ON COLUMN val_netblock_collection_type.max_num_collections IS 'Maximum INTEGER of collections a given member can be a part of of this type.
';
COMMENT ON COLUMN val_netblock_collection_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';
COMMENT ON COLUMN val_netblock_collection_type.netblock_single_addr_restrict IS 'all collections of this types'' member netblocks must have is_single_address = ''Y''';
COMMENT ON COLUMN val_netblock_collection_type.netblock_ip_family_restrict IS 'all collections of this types'' member netblocks must have  and netblock collections must match this restriction, if set.';
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE val_netblock_collection_type ADD CONSTRAINT check_any_yes_no_nc_singaddr_r
	CHECK ((netblock_single_addr_restrict)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying, 'ANY'::character varying])::text[]));
ALTER TABLE val_netblock_collection_type ADD CONSTRAINT check_ip_family_v_nblk_col
	CHECK (netblock_ip_family_restrict = ANY (ARRAY[4, 6]));
ALTER TABLE val_netblock_collection_type ADD CONSTRAINT check_yes_no_nct_chh
	CHECK (can_have_hierarchy = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK val_netblock_collection_type and netblock_collection
ALTER TABLE netblock_collection
	ADD CONSTRAINT fk_nblk_coll_v_nblk_c_typ
	FOREIGN KEY (netblock_collection_type) REFERENCES val_netblock_collection_type(netblock_collection_type);
-- consider FK val_netblock_collection_type and val_property
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_nblk_coll_type
	FOREIGN KEY (prop_val_nblk_coll_type_rstrct) REFERENCES val_netblock_collection_type(netblock_collection_type);
-- consider FK val_netblock_collection_type and val_property
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_property_netblkcolltype
	FOREIGN KEY (netblock_collection_type) REFERENCES val_netblock_collection_type(netblock_collection_type);

-- FOREIGN KEYS TO

-- TRIGGERS
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_netblock_collection_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_netblock_collection_type');
DROP TABLE IF EXISTS val_netblock_collection_type_v70;
DROP TABLE IF EXISTS audit.val_netblock_collection_type_v70;
-- DONE DEALING WITH TABLE val_netblock_collection_type [1113044]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_network_range_type [1103138]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_network_range_type', 'val_network_range_type');

-- FOREIGN KEYS FROM
ALTER TABLE network_range DROP CONSTRAINT IF EXISTS fk_netrng_netrng_typ;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_network_range_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_network_range_type DROP CONSTRAINT IF EXISTS pk_val_network_range_type;
-- INDEXES
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_network_range_type DROP CONSTRAINT IF EXISTS check_prp_prmt_nrngty_ddom;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_network_range_type ON jazzhands.val_network_range_type;
DROP TRIGGER IF EXISTS trigger_audit_val_network_range_type ON jazzhands.val_network_range_type;
DROP TRIGGER IF EXISTS trigger_validate_val_network_range_type ON jazzhands.val_network_range_type;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'val_network_range_type');
---- BEGIN audit.val_network_range_type TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_network_range_type', 'val_network_range_type');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_network_range_type');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_network_range_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependent_objects_for_replay('audit', 'val_network_range_type');
---- DONE audit.val_network_range_type TEARDOWN


ALTER TABLE val_network_range_type RENAME TO val_network_range_type_v70;
ALTER TABLE audit.val_network_range_type RENAME TO val_network_range_type_v70;

CREATE TABLE val_network_range_type
(
	network_range_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	dns_domain_required	character(10) NOT NULL,
	default_dns_prefix	varchar(50)  NULL,
	netblock_type	varchar(50)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_network_range_type', false);
ALTER TABLE val_network_range_type
	ALTER dns_domain_required
	SET DEFAULT 'REQUIRED'::bpchar;
INSERT INTO val_network_range_type (
	network_range_type,
	description,
	dns_domain_required,
	default_dns_prefix,
	netblock_type,		-- new column (netblock_type)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	network_range_type,
	description,
	dns_domain_required,
	default_dns_prefix,
	NULL,		-- new column (netblock_type)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_network_range_type_v70;

INSERT INTO audit.val_network_range_type (
	network_range_type,
	description,
	dns_domain_required,
	default_dns_prefix,
	netblock_type,		-- new column (netblock_type)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	network_range_type,
	description,
	dns_domain_required,
	default_dns_prefix,
	NULL,		-- new column (netblock_type)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_network_range_type_v70;

ALTER TABLE val_network_range_type
	ALTER dns_domain_required
	SET DEFAULT 'REQUIRED'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_network_range_type ADD CONSTRAINT pk_val_network_range_type PRIMARY KEY (network_range_type);

-- Table/Column Comments
COMMENT ON COLUMN val_network_range_type.dns_domain_required IS 'indicates how dns_domain_id is required on network_range (thus a NOT NULL constraint)';
COMMENT ON COLUMN val_network_range_type.default_dns_prefix IS 'default dns prefix for ranges of this type, can be overridden in network_range.   Required if dns_domain_required is set.';
-- INDEXES
CREATE INDEX xif1val_network_range_type ON val_network_range_type USING btree (netblock_type);

-- CHECK CONSTRAINTS
ALTER TABLE val_network_range_type ADD CONSTRAINT check_prp_prmt_nrngty_ddom
	CHECK (dns_domain_required = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK val_network_range_type and network_range
ALTER TABLE network_range
	ADD CONSTRAINT fk_netrng_netrng_typ
	FOREIGN KEY (network_range_type) REFERENCES val_network_range_type(network_range_type);

-- FOREIGN KEYS TO
-- consider FK val_network_range_type and val_netblock_type
ALTER TABLE val_network_range_type
	ADD CONSTRAINT r_786
	FOREIGN KEY (netblock_type) REFERENCES val_netblock_type(netblock_type);

-- TRIGGERS
-- consider NEW oid 1120502
CREATE OR REPLACE FUNCTION jazzhands.validate_val_network_range_type()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
END; $function$
;
CREATE CONSTRAINT TRIGGER trigger_validate_val_network_range_type AFTER UPDATE OF dns_domain_required, netblock_type ON val_network_range_type DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE validate_val_network_range_type();

-- XXX - may need to include trigger function
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_network_range_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_network_range_type');
DROP TABLE IF EXISTS val_network_range_type_v70;
DROP TABLE IF EXISTS audit.val_network_range_type_v70;
-- DONE DEALING WITH TABLE val_network_range_type [1113091]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE layer3_network [1101661]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'layer3_network', 'layer3_network');

-- FOREIGN KEYS FROM
ALTER TABLE l3_network_coll_l3_network DROP CONSTRAINT IF EXISTS fk_l3netcol_l3_net_l3netid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.layer3_network DROP CONSTRAINT IF EXISTS fk_l3_net_def_gate_nbid;
ALTER TABLE jazzhands.layer3_network DROP CONSTRAINT IF EXISTS fk_l3net_l2net;
ALTER TABLE jazzhands.layer3_network DROP CONSTRAINT IF EXISTS fk_l3net_rndv_pt_nblk_id;
ALTER TABLE jazzhands.layer3_network DROP CONSTRAINT IF EXISTS fk_layer3_network_netblock_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'layer3_network');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.layer3_network DROP CONSTRAINT IF EXISTS ak_layer3_network_netblock_id;
ALTER TABLE jazzhands.layer3_network DROP CONSTRAINT IF EXISTS pk_layer3_network;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_l3_net_def_gate_nbid";
DROP INDEX IF EXISTS "jazzhands"."xif_l3net_l2net";
DROP INDEX IF EXISTS "jazzhands"."xif_l3net_rndv_pt_nblk_id";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_layer3_network ON jazzhands.layer3_network;
DROP TRIGGER IF EXISTS trigger_audit_layer3_network ON jazzhands.layer3_network;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'layer3_network');
---- BEGIN audit.layer3_network TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'layer3_network', 'layer3_network');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'layer3_network');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."layer3_network_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependent_objects_for_replay('audit', 'layer3_network');
---- DONE audit.layer3_network TEARDOWN


ALTER TABLE layer3_network RENAME TO layer3_network_v70;
ALTER TABLE audit.layer3_network RENAME TO layer3_network_v70;

CREATE TABLE layer3_network
(
	layer3_network_id	integer NOT NULL,
	netblock_id	integer NOT NULL,
	layer2_network_id	integer  NULL,
	default_gateway_netblock_id	integer  NULL,
	rendezvous_netblock_id	integer  NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'layer3_network', false);
ALTER TABLE layer3_network
	ALTER layer3_network_id
	SET DEFAULT nextval('layer3_network_layer3_network_id_seq'::regclass);
INSERT INTO layer3_network (
	layer3_network_id,
	netblock_id,
	layer2_network_id,
	default_gateway_netblock_id,
	rendezvous_netblock_id,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	layer3_network_id,
	netblock_id,
	layer2_network_id,
	default_gateway_netblock_id,
	rendezvous_netblock_id,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM layer3_network_v70;

INSERT INTO audit.layer3_network (
	layer3_network_id,
	netblock_id,
	layer2_network_id,
	default_gateway_netblock_id,
	rendezvous_netblock_id,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	layer3_network_id,
	netblock_id,
	layer2_network_id,
	default_gateway_netblock_id,
	rendezvous_netblock_id,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.layer3_network_v70;

ALTER TABLE layer3_network
	ALTER layer3_network_id
	SET DEFAULT nextval('layer3_network_layer3_network_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE layer3_network ADD CONSTRAINT ak_layer3_network_netblock_id UNIQUE (netblock_id) DEFERRABLE;
ALTER TABLE layer3_network ADD CONSTRAINT pk_layer3_network PRIMARY KEY (layer3_network_id);

-- Table/Column Comments
COMMENT ON COLUMN layer3_network.rendezvous_netblock_id IS 'Multicast Rendevous Point Address';
-- INDEXES
CREATE INDEX xif_l3_net_def_gate_nbid ON layer3_network USING btree (default_gateway_netblock_id);
CREATE INDEX xif_l3net_l2net ON layer3_network USING btree (layer2_network_id);
CREATE INDEX xif_l3net_rndv_pt_nblk_id ON layer3_network USING btree (rendezvous_netblock_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK layer3_network and l3_network_coll_l3_network
ALTER TABLE l3_network_coll_l3_network
	ADD CONSTRAINT fk_l3netcol_l3_net_l3netid
	FOREIGN KEY (layer3_network_id) REFERENCES layer3_network(layer3_network_id);

-- FOREIGN KEYS TO
-- consider FK layer3_network and netblock
ALTER TABLE layer3_network
	ADD CONSTRAINT fk_l3_net_def_gate_nbid
	FOREIGN KEY (default_gateway_netblock_id) REFERENCES netblock(netblock_id);
-- consider FK layer3_network and layer2_network
ALTER TABLE layer3_network
	ADD CONSTRAINT fk_l3net_l2net
	FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id);
-- consider FK layer3_network and netblock
ALTER TABLE layer3_network
	ADD CONSTRAINT fk_l3net_rndv_pt_nblk_id
	FOREIGN KEY (rendezvous_netblock_id) REFERENCES netblock(netblock_id);
-- consider FK layer3_network and netblock
ALTER TABLE layer3_network
	ADD CONSTRAINT fk_layer3_network_netblock_id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);

-- TRIGGERS
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'layer3_network');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'layer3_network');
ALTER SEQUENCE layer3_network_layer3_network_id_seq
	 OWNED BY layer3_network.layer3_network_id;
DROP TABLE IF EXISTS layer3_network_v70;
DROP TABLE IF EXISTS audit.layer3_network_v70;
-- DONE DEALING WITH TABLE layer3_network [1111592]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE netblock_collection [1101806]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'netblock_collection', 'netblock_collection');

-- FOREIGN KEYS FROM
ALTER TABLE ip_group DROP CONSTRAINT IF EXISTS fk_ip_proto_netblk_coll_id;
ALTER TABLE netblock_collection_hier DROP CONSTRAINT IF EXISTS fk_nblk_c_hier_chld_nc;
ALTER TABLE netblock_collection_hier DROP CONSTRAINT IF EXISTS fk_nblk_c_hier_prnt_nc;
ALTER TABLE netblock_collection_netblock DROP CONSTRAINT IF EXISTS fk_nblk_col_nblk_nbcolid;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_nblk_coll_id;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_pv_nblkcol_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.netblock_collection DROP CONSTRAINT IF EXISTS fk_nblk_coll_v_nblk_c_typ;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'netblock_collection');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.netblock_collection DROP CONSTRAINT IF EXISTS pk_netblock_collection;
ALTER TABLE jazzhands.netblock_collection DROP CONSTRAINT IF EXISTS uq_netblock_collection_name;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xifk_nb_col_val_nb_col_typ";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_netblock_collection ON jazzhands.netblock_collection;
DROP TRIGGER IF EXISTS trigger_audit_netblock_collection ON jazzhands.netblock_collection;
DROP TRIGGER IF EXISTS trigger_validate_netblock_collection_type_change ON jazzhands.netblock_collection;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'netblock_collection');
---- BEGIN audit.netblock_collection TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'netblock_collection', 'netblock_collection');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'netblock_collection');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."netblock_collection_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependent_objects_for_replay('audit', 'netblock_collection');
---- DONE audit.netblock_collection TEARDOWN


ALTER TABLE netblock_collection RENAME TO netblock_collection_v70;
ALTER TABLE audit.netblock_collection RENAME TO netblock_collection_v70;

CREATE TABLE netblock_collection
(
	netblock_collection_id	integer NOT NULL,
	netblock_collection_name	varchar(255) NOT NULL,
	netblock_collection_type	varchar(50)  NULL,
	netblock_ip_family_restrict	integer  NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'netblock_collection', false);
ALTER TABLE netblock_collection
	ALTER netblock_collection_id
	SET DEFAULT nextval('netblock_collection_netblock_collection_id_seq'::regclass);
INSERT INTO netblock_collection (
	netblock_collection_id,
	netblock_collection_name,
	netblock_collection_type,
	netblock_ip_family_restrict,		-- new column (netblock_ip_family_restrict)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	netblock_collection_id,
	netblock_collection_name,
	netblock_collection_type,
	NULL,		-- new column (netblock_ip_family_restrict)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM netblock_collection_v70;

INSERT INTO audit.netblock_collection (
	netblock_collection_id,
	netblock_collection_name,
	netblock_collection_type,
	netblock_ip_family_restrict,		-- new column (netblock_ip_family_restrict)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	netblock_collection_id,
	netblock_collection_name,
	netblock_collection_type,
	NULL,		-- new column (netblock_ip_family_restrict)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.netblock_collection_v70;

ALTER TABLE netblock_collection
	ALTER netblock_collection_id
	SET DEFAULT nextval('netblock_collection_netblock_collection_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE netblock_collection ADD CONSTRAINT pk_netblock_collection PRIMARY KEY (netblock_collection_id);
ALTER TABLE netblock_collection ADD CONSTRAINT uq_netblock_collection_name UNIQUE (netblock_collection_name, netblock_collection_type);

-- Table/Column Comments
COMMENT ON COLUMN netblock_collection.netblock_ip_family_restrict IS 'member netblocks must have  and netblock collections must match this restriction, if set.';
-- INDEXES
CREATE INDEX xifk_nb_col_val_nb_col_typ ON netblock_collection USING btree (netblock_collection_type);

-- CHECK CONSTRAINTS
ALTER TABLE netblock_collection ADD CONSTRAINT check_ip_family_1970633785
	CHECK (netblock_ip_family_restrict = ANY (ARRAY[4, 6]));

-- FOREIGN KEYS FROM
-- consider FK netblock_collection and ip_group
ALTER TABLE ip_group
	ADD CONSTRAINT fk_ip_proto_netblk_coll_id
	FOREIGN KEY (netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id);
-- consider FK netblock_collection and netblock_collection_hier
ALTER TABLE netblock_collection_hier
	ADD CONSTRAINT fk_nblk_c_hier_chld_nc
	FOREIGN KEY (child_netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id);
-- consider FK netblock_collection and netblock_collection_hier
ALTER TABLE netblock_collection_hier
	ADD CONSTRAINT fk_nblk_c_hier_prnt_nc
	FOREIGN KEY (netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id);
-- consider FK netblock_collection and netblock_collection_netblock
ALTER TABLE netblock_collection_netblock
	ADD CONSTRAINT fk_nblk_col_nblk_nbcolid
	FOREIGN KEY (netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id);
-- consider FK netblock_collection and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_nblk_coll_id
	FOREIGN KEY (netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id);
-- consider FK netblock_collection and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_pv_nblkcol_id
	FOREIGN KEY (property_value_nblk_coll_id) REFERENCES netblock_collection(netblock_collection_id);

-- FOREIGN KEYS TO
-- consider FK netblock_collection and val_netblock_collection_type
ALTER TABLE netblock_collection
	ADD CONSTRAINT fk_nblk_coll_v_nblk_c_typ
	FOREIGN KEY (netblock_collection_type) REFERENCES val_netblock_collection_type(netblock_collection_type);

-- TRIGGERS
-- consider NEW oid 1120350
CREATE OR REPLACE FUNCTION jazzhands.validate_netblock_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.netblock_collection_type != NEW.netblock_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.netblock_collection_type = OLD.netblock_collection_type
		AND	p.netblock_collection_id = NEW.netblock_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'netblock_collection % of type % is used by % restricted properties.',
				NEW.netblock_collection_id, NEW.netblock_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;	
END;
$function$
;
CREATE TRIGGER trigger_validate_netblock_collection_type_change BEFORE UPDATE OF netblock_collection_type ON netblock_collection FOR EACH ROW EXECUTE PROCEDURE validate_netblock_collection_type_change();

-- XXX - may need to include trigger function
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'netblock_collection');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'netblock_collection');
ALTER SEQUENCE netblock_collection_netblock_collection_id_seq
	 OWNED BY netblock_collection.netblock_collection_id;
DROP TABLE IF EXISTS netblock_collection_v70;
DROP TABLE IF EXISTS audit.netblock_collection_v70;
-- DONE DEALING WITH TABLE netblock_collection [1111738]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE person_company_attr [1102024]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'person_company_attr', 'person_company_attr');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.person_company_attr DROP CONSTRAINT IF EXISTS fk_pers_comp_attr_person_comp_;
ALTER TABLE jazzhands.person_company_attr DROP CONSTRAINT IF EXISTS fk_person_comp_att_pers_person;
ALTER TABLE jazzhands.person_company_attr DROP CONSTRAINT IF EXISTS fk_person_comp_attr_val_name;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'person_company_attr');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.person_company_attr DROP CONSTRAINT IF EXISTS ak_person_company_attr_name;
ALTER TABLE jazzhands.person_company_attr DROP CONSTRAINT IF EXISTS pk_person_company_attr;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1person_company_attr";
DROP INDEX IF EXISTS "jazzhands"."xif2person_company_attr";
DROP INDEX IF EXISTS "jazzhands"."xif3person_company_attr";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_person_company_attr ON jazzhands.person_company_attr;
DROP TRIGGER IF EXISTS trigger_audit_person_company_attr ON jazzhands.person_company_attr;
DROP TRIGGER IF EXISTS trigger_validate_pers_company_attr ON jazzhands.person_company_attr;
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'person_company_attr');
---- BEGIN audit.person_company_attr TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'person_company_attr', 'person_company_attr');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'person_company_attr');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."person_company_attr_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependent_objects_for_replay('audit', 'person_company_attr');
---- DONE audit.person_company_attr TEARDOWN


ALTER TABLE person_company_attr RENAME TO person_company_attr_v70;
ALTER TABLE audit.person_company_attr RENAME TO person_company_attr_v70;

CREATE TABLE person_company_attr
(
	company_id	integer NOT NULL,
	person_id	integer NOT NULL,
	person_company_attr_name	varchar(50) NOT NULL,
	attribute_value	varchar(50)  NULL,
	attribute_value_timestamp	timestamp with time zone  NULL,
	attribute_value_person_id	integer  NULL,
	start_date	timestamp with time zone  NULL,
	finish_date	timestamp with time zone  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'person_company_attr', false);
INSERT INTO person_company_attr (
	company_id,
	person_id,
	person_company_attr_name,
	attribute_value,
	attribute_value_timestamp,
	attribute_value_person_id,
	start_date,		-- new column (start_date)
	finish_date,		-- new column (finish_date)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	company_id,
	person_id,
	person_company_attr_name,
	attribute_value,
	attribute_value_timestamp,
	attribute_value_person_id,
	NULL,		-- new column (start_date)
	NULL,		-- new column (finish_date)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM person_company_attr_v70;

INSERT INTO audit.person_company_attr (
	company_id,
	person_id,
	person_company_attr_name,
	attribute_value,
	attribute_value_timestamp,
	attribute_value_person_id,
	start_date,		-- new column (start_date)
	finish_date,		-- new column (finish_date)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	company_id,
	person_id,
	person_company_attr_name,
	attribute_value,
	attribute_value_timestamp,
	attribute_value_person_id,
	NULL,		-- new column (start_date)
	NULL,		-- new column (finish_date)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.person_company_attr_v70;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE person_company_attr ADD CONSTRAINT ak_person_company_attr_name UNIQUE (company_id, person_id, person_company_attr_name);
ALTER TABLE person_company_attr ADD CONSTRAINT pk_person_company_attr PRIMARY KEY (company_id, person_id, person_company_attr_name);

-- Table/Column Comments
COMMENT ON COLUMN person_company_attr.attribute_value IS 'string value of the attribute.';
COMMENT ON COLUMN person_company_attr.attribute_value_person_id IS 'person_id value of the attribute.';
-- INDEXES
CREATE INDEX xif1person_company_attr ON person_company_attr USING btree (company_id, person_id);
CREATE INDEX xif2person_company_attr ON person_company_attr USING btree (attribute_value_person_id);
CREATE INDEX xif3person_company_attr ON person_company_attr USING btree (person_company_attr_name);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK person_company_attr and person_company
ALTER TABLE person_company_attr
	ADD CONSTRAINT fk_pers_comp_attr_person_comp_
	FOREIGN KEY (company_id, person_id) REFERENCES person_company(company_id, person_id) DEFERRABLE;
-- consider FK person_company_attr and person
ALTER TABLE person_company_attr
	ADD CONSTRAINT fk_person_comp_att_pers_person
	FOREIGN KEY (attribute_value_person_id) REFERENCES person(person_id);
-- consider FK person_company_attr and val_person_company_attr_name
ALTER TABLE person_company_attr
	ADD CONSTRAINT fk_person_comp_attr_val_name
	FOREIGN KEY (person_company_attr_name) REFERENCES val_person_company_attr_name(person_company_attr_name);

-- TRIGGERS
-- consider NEW oid 1120579
CREATE OR REPLACE FUNCTION jazzhands.validate_pers_company_attr()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally			integer;
	v_pc_atr		val_person_company_attr_name%ROWTYPE;
	v_listvalue		Property.Property_Value%TYPE;
BEGIN

	SELECT	*
	INTO	v_pc_atr
	FROM	val_person_company_attr_name
	WHERE	person_company_attr_name = NEW.person_company_attr_name;

	IF v_pc_atr.person_company_attr_data_type IN
			('boolean', 'number', 'string', 'list') THEN
		IF NEW.attribute_value IS NULL THEN
			RAISE EXCEPTION 'attribute_value must be set for %',
				v_pc_atr.person_company_attr_data_type
				USING ERRCODE = 'not_null_violation';
		END IF;
		IF v_pc_atr.person_company_attr_data_type = 'boolean' THEN
			IF NEW.attribute_value NOT IN ('Y', 'N') THEN
				RAISE EXCEPTION 'attribute_value must be boolean (Y,N)'
					USING ERRCODE = 'integrity_constraint_violation';
			END IF;
		ELSIF v_pc_atr.person_company_attr_data_type = 'number' THEN
			IF NEW.attribute_value !~ '^-?(\d*\.?\d*){1}$' THEN
				RAISE EXCEPTION 'attribute_value must be a number'
					USING ERRCODE = 'integrity_constraint_violation';
			END IF;
		ELSIF v_pc_atr.person_company_attr_data_type = 'timestamp' THEN
			IF NEW.attribute_value_timestamp IS NULL THEN
				RAISE EXCEPTION 'attribute_value_timestamp must be set for %',
					v_pc_atr.person_company_attr_data_type
					USING ERRCODE = 'not_null_violation';
			END IF;
		ELSIF v_pc_atr.person_company_attr_data_type = 'list' THEN
			PERFORM 1
			FROM	val_person_company_attr_value
			WHERE	(person_company_attr_name,person_company_attr_value)
					IN
					(NEW.person_company_attr_name,NEW.person_company_attr_value)
			;
			IF NOT FOUND THEN
				RAISE EXCEPTION 'attribute_value must be valid'
					USING ERRCODE = 'integrity_constraint_violation';
			END IF;
		END IF;
	ELSIF v_pc_atr.person_company_attr_data_type = 'person_id' THEN
		IF NEW.attribute_value_timestamp IS NULL THEN
			RAISE EXCEPTION 'attribute_value_timestamp must be set for %',
				v_pc_atr.person_company_attr_data_type
				USING ERRCODE = 'not_null_violation';
		END IF;
	END IF;

	IF NEW.attribute_value IS NOT NULL AND
			(NEW.attribute_value_person_id IS NOT NULL OR
			NEW.attribute_value_timestamp IS NOT NULL) THEN
		RAISE EXCEPTION 'only one attribute_value may be set'
			USING ERRCODE = 'integrity_constraint_violation';
	ELSIF NEW.attribute_value_person_id IS NOT NULL AND
			(NEW.attribute_value IS NOT NULL OR
			NEW.attribute_value_timestamp IS NOT NULL) THEN
		RAISE EXCEPTION 'only one attribute_value may be set'
			USING ERRCODE = 'integrity_constraint_violation';
	ELSIF NEW.attribute_value_timestamp IS NOT NULL AND
			(NEW.attribute_value_person_id IS NOT NULL OR
			NEW.attribute_value IS NOT NULL) THEN
		RAISE EXCEPTION 'only one attribute_value may be set'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_validate_pers_company_attr BEFORE INSERT OR UPDATE ON person_company_attr FOR EACH ROW EXECUTE PROCEDURE validate_pers_company_attr();

-- XXX - may need to include trigger function
-- this used to be at the end...
SELECT schema_support.replay_object_recreates();
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'person_company_attr');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'person_company_attr');
DROP TABLE IF EXISTS person_company_attr_v70;
DROP TABLE IF EXISTS audit.person_company_attr_v70;
-- DONE DEALING WITH TABLE person_company_attr [1111957]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_account_manager_map [1110021]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_account_manager_map', 'v_account_manager_map');
SELECT schema_support.save_dependent_objects_for_replay('jazzhands', 'v_account_manager_map');
DROP VIEW IF EXISTS jazzhands.v_account_manager_map;
CREATE VIEW jazzhands.v_account_manager_map AS
 WITH dude_base AS (
         SELECT a_1.login,
            a_1.account_id,
            a_1.person_id,
            a_1.company_id,
            a_1.account_realm_id,
            COALESCE(p.preferred_first_name, p.first_name) AS first_name,
            COALESCE(p.preferred_last_name, p.last_name) AS last_name,
            p.middle_name,
            pc.manager_person_id,
            pc.employee_id
           FROM account a_1
             JOIN person_company pc USING (company_id, person_id)
             JOIN person p USING (person_id)
          WHERE a_1.is_enabled = 'Y'::bpchar AND pc.person_company_relation::text = 'employee'::text AND a_1.account_role::text = 'primary'::text AND a_1.account_type::text = 'person'::text
        ), dude AS (
         SELECT dude_base.login,
            dude_base.account_id,
            dude_base.person_id,
            dude_base.company_id,
            dude_base.account_realm_id,
            dude_base.first_name,
            dude_base.last_name,
            dude_base.middle_name,
            dude_base.manager_person_id,
            dude_base.employee_id,
            concat(dude_base.first_name, ' ', dude_base.last_name, ' (', dude_base.login, ')') AS human_readable
           FROM dude_base
        )
 SELECT a.login,
    a.account_id,
    a.person_id,
    a.company_id,
    a.account_realm_id,
    a.first_name,
    a.last_name,
    a.middle_name,
    a.manager_person_id,
    a.employee_id,
    a.human_readable,
    mp.account_id AS manager_account_id,
    mp.login AS manager_login,
    concat(mp.first_name, ' ', mp.last_name, ' (', mp.login, ')') AS manager_human_readable,
    mp.last_name AS manager_last_name,
    mp.middle_name AS manager_middle_name,
    mp.first_name AS manger_first_name,
    mp.employee_id AS manager_employee_id,
    mp.company_id AS manager_company_id
   FROM dude a
     JOIN dude mp ON mp.person_id = a.manager_person_id AND mp.account_realm_id = a.account_realm_id;

delete from __recreate where type = 'view' and object = 'v_account_manager_map';
-- DONE DEALING WITH TABLE v_account_manager_map [1120051]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_person_company
DROP VIEW IF EXISTS jazzhands.v_person_company;
CREATE VIEW jazzhands.v_person_company AS
 SELECT person_company.company_id,
    person_company.person_id,
    person_company.person_company_status,
    person_company.person_company_relation,
    person_company.is_exempt,
    person_company.is_management,
    person_company.is_full_time,
    person_company.description,
    person_company.employee_id,
    person_company.payroll_id,
    person_company.external_hr_id,
    person_company.position_title,
    person_company.badge_system_id,
    person_company.hire_date,
    person_company.termination_date,
    person_company.manager_person_id,
    person_company.supervisor_person_id,
    person_company.nickname,
    person_company.data_ins_user,
    person_company.data_ins_date,
    person_company.data_upd_user,
    person_company.data_upd_date
   FROM person_company;

-- DONE DEALING WITH TABLE v_person_company [1120125]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_person
DROP VIEW IF EXISTS jazzhands.v_person;
CREATE VIEW jazzhands.v_person AS
 SELECT person.person_id,
    person.description,
    COALESCE(person.preferred_first_name, person.first_name) AS first_name,
    person.middle_name,
    COALESCE(person.preferred_last_name, person.last_name) AS last_name,
    person.name_suffix,
    person.gender,
    person.preferred_first_name,
    person.preferred_last_name,
    person.first_name AS legal_first_name,
    person.last_name AS legal_last_name,
    person.nickname,
    person.birth_date,
    person.diet,
    person.shirt_size,
    person.pant_size,
    person.hat_size,
    person.data_ins_user,
    person.data_ins_date,
    person.data_upd_user,
    person.data_upd_date
   FROM person;

-- DONE DEALING WITH TABLE v_person [1120121]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_l3_network_coll_expanded
DROP VIEW IF EXISTS jazzhands.v_l3_network_coll_expanded;
CREATE VIEW jazzhands.v_l3_network_coll_expanded AS
 WITH RECURSIVE l3_network_coll_recurse(level, root_l3_network_coll_id, layer3_network_collection_id, array_path, rvs_array_path, cycle) AS (
         SELECT 0 AS level,
            l3.layer3_network_collection_id AS root_l3_network_coll_id,
            l3.layer3_network_collection_id,
            ARRAY[l3.layer3_network_collection_id] AS array_path,
            ARRAY[l3.layer3_network_collection_id] AS rvs_array_path,
            false AS bool
           FROM layer3_network_collection l3
        UNION ALL
         SELECT x.level + 1 AS level,
            x.root_l3_network_coll_id,
            l3h.layer3_network_collection_id,
            x.array_path || l3h.layer3_network_collection_id AS array_path,
            l3h.layer3_network_collection_id || x.rvs_array_path AS rvs_array_path,
            l3h.layer3_network_collection_id = ANY (x.array_path) AS cycle
           FROM l3_network_coll_recurse x
             JOIN layer3_network_collection_hier l3h ON x.layer3_network_collection_id = l3h.child_l3_network_coll_id
          WHERE NOT x.cycle
        )
 SELECT l3_network_coll_recurse.level,
    l3_network_coll_recurse.layer3_network_collection_id,
    l3_network_coll_recurse.root_l3_network_coll_id,
    array_to_string(l3_network_coll_recurse.array_path, '/'::text) AS text_path,
    l3_network_coll_recurse.array_path,
    l3_network_coll_recurse.rvs_array_path
   FROM l3_network_coll_recurse;

-- DONE DEALING WITH TABLE v_l3_network_coll_expanded [1120116]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_l2_network_coll_expanded
DROP VIEW IF EXISTS jazzhands.v_l2_network_coll_expanded;
CREATE VIEW jazzhands.v_l2_network_coll_expanded AS
 WITH RECURSIVE l2_network_coll_recurse(level, root_l2_network_coll_id, layer2_network_collection_id, array_path, rvs_array_path, cycle) AS (
         SELECT 0 AS level,
            l2.layer2_network_collection_id AS root_l2_network_coll_id,
            l2.layer2_network_collection_id,
            ARRAY[l2.layer2_network_collection_id] AS array_path,
            ARRAY[l2.layer2_network_collection_id] AS rvs_array_path,
            false AS bool
           FROM layer2_network_collection l2
        UNION ALL
         SELECT x.level + 1 AS level,
            x.root_l2_network_coll_id,
            l2h.layer2_network_collection_id,
            x.array_path || l2h.layer2_network_collection_id AS array_path,
            l2h.layer2_network_collection_id || x.rvs_array_path AS rvs_array_path,
            l2h.layer2_network_collection_id = ANY (x.array_path) AS cycle
           FROM l2_network_coll_recurse x
             JOIN layer2_network_collection_hier l2h ON x.layer2_network_collection_id = l2h.child_l2_network_coll_id
          WHERE NOT x.cycle
        )
 SELECT l2_network_coll_recurse.level,
    l2_network_coll_recurse.layer2_network_collection_id,
    l2_network_coll_recurse.root_l2_network_coll_id,
    array_to_string(l2_network_coll_recurse.array_path, '/'::text) AS text_path,
    l2_network_coll_recurse.array_path,
    l2_network_coll_recurse.rvs_array_path
   FROM l2_network_coll_recurse;

-- DONE DEALING WITH TABLE v_l2_network_coll_expanded [1120111]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_account_collection_audit_results [1110042]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_account_collection_audit_results', 'v_account_collection_audit_results');
SELECT schema_support.save_dependent_objects_for_replay('approval_utils', 'v_account_collection_audit_results');
DROP VIEW IF EXISTS approval_utils.v_account_collection_audit_results;
CREATE VIEW approval_utils.v_account_collection_audit_results AS
 WITH membermap AS (
         SELECT aca.audit_seq_id,
            ac.account_collection_id,
            ac.account_collection_name,
            ac.account_collection_type,
            a.login,
            a.account_id,
            a.person_id,
            a.company_id,
            a.account_realm_id,
            a.first_name,
            a.last_name,
            a.middle_name,
            a.manager_person_id,
            a.employee_id,
            a.human_readable,
            a.manager_account_id,
            a.manager_login,
            a.manager_human_readable,
            a.manager_last_name,
            a.manager_middle_name,
            a.manger_first_name,
            a.manager_employee_id,
            a.manager_company_id
           FROM v_account_manager_map a
             JOIN approval_utils.v_account_collection_account_audit_map aca USING (account_id)
             JOIN account_collection ac USING (account_collection_id)
          WHERE a.account_id <> a.manager_account_id
          ORDER BY a.manager_login, a.last_name, a.first_name, a.account_id
        )
 SELECT membermap.audit_seq_id,
    membermap.account_collection_id,
    membermap.account_collection_name,
    membermap.account_collection_type,
    membermap.login,
    membermap.account_id,
    membermap.person_id,
    membermap.company_id,
    membermap.account_realm_id,
    membermap.first_name,
    membermap.last_name,
    membermap.middle_name,
    membermap.manager_person_id,
    membermap.employee_id,
    membermap.human_readable,
    membermap.manager_account_id,
    membermap.manager_login,
    membermap.manager_human_readable,
    membermap.manager_last_name,
    membermap.manager_middle_name,
    membermap.manger_first_name,
    membermap.manager_employee_id,
    membermap.manager_company_id
   FROM membermap;

delete from __recreate where type = 'view' and object = 'v_account_collection_audit_results';
-- DONE DEALING WITH TABLE v_account_collection_audit_results [1120072]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_account_collection_approval_process [1110047]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_account_collection_approval_process', 'v_account_collection_approval_process');
SELECT schema_support.save_dependent_objects_for_replay('approval_utils', 'v_account_collection_approval_process');
DROP VIEW IF EXISTS approval_utils.v_account_collection_approval_process;
CREATE VIEW approval_utils.v_account_collection_approval_process AS
 WITH combo AS (
         WITH foo AS (
                 SELECT mm.audit_seq_id,
                    mm.account_collection_id,
                    mm.account_collection_name,
                    mm.account_collection_type,
                    mm.login,
                    mm.account_id,
                    mm.person_id,
                    mm.company_id,
                    mm.account_realm_id,
                    mm.first_name,
                    mm.last_name,
                    mm.middle_name,
                    mm.manager_person_id,
                    mm.employee_id,
                    mm.human_readable,
                    mm.manager_account_id,
                    mm.manager_login,
                    mm.manager_human_readable,
                    mm.manager_last_name,
                    mm.manager_middle_name,
                    mm.manger_first_name,
                    mm.manager_employee_id,
                    mm.manager_company_id,
                    mx.approval_process_id,
                    mx.first_apprvl_process_chain_id,
                    mx.approval_process_name,
                    mx.approval_response_period,
                    mx.approval_expiration_action,
                    mx.attestation_frequency,
                    mx.attestation_offset,
                    mx.current_attestation_name,
                    mx.current_attestation_begins,
                    mx.property_id,
                    mx.property_name,
                    mx.property_type,
                    mx.property_value,
                    mx.property_val_lhs,
                    mx.property_val_rhs,
                    mx.approval_process_chain_id,
                    mx.approving_entity,
                    mx.approval_process_chain_name,
                    mx.approval_process_description,
                    mx.approval_chain_description
                   FROM approval_utils.v_account_collection_audit_results mm
                     JOIN approval_utils.v_approval_matrix mx ON mx.property_val_lhs = mm.account_collection_type::text
                  ORDER BY mm.manager_account_id, mm.account_id
                )
         SELECT foo.login,
            foo.account_id,
            foo.person_id,
            foo.company_id,
            foo.manager_account_id,
            foo.manager_login,
            'account_collection_account'::text AS audit_table,
            foo.audit_seq_id,
            foo.approval_process_id,
            foo.approval_process_chain_id,
            foo.approving_entity,
            foo.approval_process_description,
            foo.approval_chain_description,
            foo.approval_response_period,
            foo.approval_expiration_action,
            foo.attestation_frequency,
            foo.current_attestation_name,
            foo.current_attestation_begins,
            foo.attestation_offset,
            foo.approval_process_chain_name,
            foo.account_collection_type AS approval_category,
            concat('Verify ', foo.account_collection_type) AS approval_label,
            foo.human_readable AS approval_lhs,
            foo.account_collection_name AS approval_rhs
           FROM foo
        UNION
         SELECT mm.login,
            mm.account_id,
            mm.person_id,
            mm.company_id,
            mm.manager_account_id,
            mm.manager_login,
            'account_collection_account'::text AS audit_table,
            mm.audit_seq_id,
            mx.approval_process_id,
            mx.approval_process_chain_id,
            mx.approving_entity,
            mx.approval_process_description,
            mx.approval_chain_description,
            mx.approval_response_period,
            mx.approval_expiration_action,
            mx.attestation_frequency,
            mx.current_attestation_name,
            mx.current_attestation_begins,
            mx.attestation_offset,
            mx.approval_process_chain_name,
            mx.approval_process_name AS approval_category,
            'Verify Manager'::text AS approval_label,
            mm.human_readable AS approval_lhs,
            concat('Reports to ', mm.manager_human_readable) AS approval_rhs
           FROM approval_utils.v_approval_matrix mx
             JOIN property p ON p.property_name::text = mx.property_val_rhs AND p.property_type::text = mx.property_val_lhs
             JOIN approval_utils.v_account_collection_audit_results mm ON mm.account_collection_id = p.property_value_account_coll_id
          WHERE p.account_id <> mm.account_id
        UNION
         SELECT mm.login,
            mm.account_id,
            mm.person_id,
            mm.company_id,
            mm.manager_account_id,
            mm.manager_login,
            'person_company'::text AS audit_table,
            pcm.audit_seq_id,
            am.approval_process_id,
            am.approval_process_chain_id,
            am.approving_entity,
            am.approval_process_description,
            am.approval_chain_description,
            am.approval_response_period,
            am.approval_expiration_action,
            am.attestation_frequency,
            am.current_attestation_name,
            am.current_attestation_begins,
            am.attestation_offset,
            am.approval_process_chain_name,
            am.property_val_rhs AS approval_category,
                CASE
                    WHEN am.property_val_rhs = 'position_title'::text THEN 'Verify Position Title'::text
                    ELSE NULL::text
                END AS aproval_label,
            mm.human_readable AS approval_lhs,
                CASE
                    WHEN am.property_val_rhs = 'position_title'::text THEN pcm.position_title
                    ELSE NULL::character varying
                END AS approval_rhs
           FROM v_account_manager_map mm
             JOIN approval_utils.v_person_company_audit_map pcm USING (person_id, company_id)
             JOIN approval_utils.v_approval_matrix am ON am.property_val_lhs = 'person_company'::text AND am.property_val_rhs = 'position_title'::text
        )
 SELECT combo.login,
    combo.account_id,
    combo.person_id,
    combo.company_id,
    combo.manager_account_id,
    combo.manager_login,
    combo.audit_table,
    combo.audit_seq_id,
    combo.approval_process_id,
    combo.approval_process_chain_id,
    combo.approving_entity,
    combo.approval_process_description,
    combo.approval_chain_description,
    combo.approval_response_period,
    combo.approval_expiration_action,
    combo.attestation_frequency,
    combo.current_attestation_name,
    combo.current_attestation_begins,
    combo.attestation_offset,
    combo.approval_process_chain_name,
    combo.approval_category,
    combo.approval_label,
    combo.approval_lhs,
    combo.approval_rhs
   FROM combo
  WHERE combo.manager_account_id <> combo.account_id
  ORDER BY combo.manager_login, combo.account_id, combo.approval_label;

delete from __recreate where type = 'view' and object = 'v_account_collection_approval_process';
-- DONE DEALING WITH TABLE v_account_collection_approval_process [1120077]
--------------------------------------------------------------------
--
-- Process drops in jazzhands
--
-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_change_realm_aca_realm');
CREATE OR REPLACE FUNCTION jazzhands.account_change_realm_aca_realm()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	SELECT	count(*)
	INTO	_tally
	FROM	account_collection_account
			JOIN account_collection USING (account_collection_id)
			JOIN val_account_collection_type vt USING (account_collection_type)
	WHERE	vt.account_realm_id IS NOT NULL
	AND		vt.account_realm_id != NEW.account_realm_id
	AND		account_id = NEW.account_id;
	
	IF _tally > 0 THEN
		RAISE EXCEPTION 'New account realm (%) is part of % account collections with a type restriction',
			NEW.account_realm_id,
			_tally
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'device_collection_hier_enforce');
CREATE OR REPLACE FUNCTION jazzhands.device_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	dct	val_device_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	dct
	FROM	val_device_collection_type
	WHERE	device_collection_type =
		(select device_collection_type from device_collection
			where device_collection_id = NEW.parent_device_collection_id);

	IF dct.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Device Collections of type % may not be hierarcical',
			dct.device_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'device_collection_member_enforce');
CREATE OR REPLACE FUNCTION jazzhands.device_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	dct	val_device_collection_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	dct
	FROM	val_device_collection_type
	WHERE	device_collection_type =
		(select device_collection_type from device_collection
			where device_collection_id = NEW.device_collection_id);

	IF dct.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from device_collection_device
		  where device_collection_id = NEW.device_collection_id;
		IF tally > dct.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF dct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from device_collection_device
		  		inner join device_collection using (device_collection_id)
		  where device_id = NEW.device_id
		  and	device_collection_type = dct.device_collection_type;
		IF tally > dct.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Device may not be a member of more than % collections of type %',
				dct.MAX_NUM_COLLECTIONS, dct.device_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'net_int_netblock_to_nbn_compat_after');
CREATE OR REPLACE FUNCTION jazzhands.net_int_netblock_to_nbn_compat_after()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	SELECT  count(*)
	  INTO  _tally
	  FROM  pg_catalog.pg_class
	 WHERE  relname = '__network_interface_netblocks'
	   AND  relpersistence = 't';

	IF _tally = 0 THEN
		CREATE TEMPORARY TABLE IF NOT EXISTS __network_interface_netblocks (
			network_interface_id INTEGER, netblock_id INTEGER
		);
	END IF;

	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
		SELECT count(*) INTO _tally FROM __network_interface_netblocks
		WHERE network_interface_id = NEW.network_interface_id
		AND netblock_id IS NOT DISTINCT FROM ( NEW.netblock_id );
		if _tally >  0 THEN
			RETURN NEW;
		END IF;
		INSERT INTO __network_interface_netblocks
			(network_interface_id, netblock_id)
		VALUES (NEW.network_interface_id,NEW.netblock_id);
	ELSIF TG_OP = 'DELETE' THEN
		SELECT count(*) INTO _tally FROM __network_interface_netblocks
		WHERE network_interface_id = OLD.network_interface_id
		AND netblock_id IS NOT DISTINCT FROM ( OLD.netblock_id );
		if _tally >  0 THEN
			RETURN OLD;
		END IF;
		INSERT INTO __network_interface_netblocks
			(network_interface_id, netblock_id)
		VALUES (OLD.network_interface_id,OLD.netblock_id);
	END IF;

	IF TG_OP = 'INSERT' THEN
		IF NEW.netblock_id IS NOT NULL THEN
			SELECT COUNT(*)
			INTO _tally
			FROM	network_interface_netblock
			WHERE	network_interface_id = NEW.network_interface_id
			AND		netblock_id = NEW.netblock_id;

			IF _tally = 0 THEN
				SELECT COUNT(*)
				INTO _tally
				FROM	network_interface_netblock
				WHERE	network_interface_id != NEW.network_interface_id
				AND		netblock_id = NEW.netblock_id;

				IF _tally != 0  THEN
					UPDATE network_interface_netblock
					SET network_interface_id = NEW.network_interface_id
					WHERE netblock_id = NEW.netblock_id;
				ELSE
					INSERT INTO network_interface_netblock
						(network_interface_id, netblock_id)
					VALUES
						(NEW.network_interface_id, NEW.netblock_id);
				END IF;
			END IF;
		END IF;
	ELSIF TG_OP = 'UPDATE'  THEN
		IF OLD.netblock_id is NULL and NEW.netblock_ID is NOT NULL THEN
			SELECT COUNT(*)
			INTO _tally
			FROM	network_interface_netblock
			WHERE	network_interface_id = NEW.network_interface_id
			AND		netblock_id = NEW.netblock_id;

			IF _tally = 0 THEN
				INSERT INTO network_interface_netblock
					(network_interface_id, netblock_id)
				VALUES
					(NEW.network_interface_id, NEW.netblock_id);
			END IF;
		ELSIF OLD.netblock_id IS NOT NULL and NEW.netblock_id is NOT NULL THEN
			IF OLD.netblock_id != NEW.netblock_id THEN
				UPDATE network_interface_netblock
					SET network_interface_id = NEW.network_interface_Id,
						netblock_id = NEW.netblock_id
						WHERE network_interface_id = OLD.network_interface_id
						AND netblock_id = OLD.netblock_id
						AND netblock_id != NEW.netblock_id
				;
			END IF;
		END IF;
	ELSIF TG_OP = 'DELETE' THEN
		IF OLD.netblock_id IS NOT NULL THEN
			DELETE from network_interface_netblock
				WHERE network_interface_id = OLD.network_interface_id
				AND netblock_id = OLD.netblock_id;
		END IF;
		RETURN OLD;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'net_int_netblock_to_nbn_compat_before');
CREATE OR REPLACE FUNCTION jazzhands.net_int_netblock_to_nbn_compat_before()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	SET CONSTRAINTS FK_NETINT_NB_NETINT_ID DEFERRED;
	SET CONSTRAINTS FK_NETINT_NB_NBLK_ID DEFERRED;

	RETURN OLD;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'network_interface_drop_tt');
CREATE OR REPLACE FUNCTION jazzhands.network_interface_drop_tt()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally INTEGER;
BEGIN
	SELECT  count(*)
	  INTO  _tally
	  FROM  pg_catalog.pg_class
	 WHERE  relname = '__network_interface_netblocks'
	   AND  relpersistence = 't';

	SET CONSTRAINTS FK_NETINT_NB_NETINT_ID IMMEDIATE;
	SET CONSTRAINTS FK_NETINT_NB_NBLK_ID IMMEDIATE;

	IF _tally > 0 THEN
		DROP TABLE IF EXISTS __network_interface_netblocks;
	END IF;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$function$
;

DROP TRIGGER IF EXISTS trigger_validate_network_range ON jazzhands.network_range;
DROP FUNCTION IF EXISTS jazzhands.validate_network_range (  );
-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_val_network_range_type');
CREATE OR REPLACE FUNCTION jazzhands.validate_val_network_range_type()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
END; $function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.device_collection_after_hooks()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	BEGIN
		PERFORM local_hooks.device_collection_after_hooks();
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
			PERFORM 1;
	END;
	RETURN NULL;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.layer2_network_collection_after_hooks()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	BEGIN
		PERFORM local_hooks.layer2_network_collection_after_hooks();
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
			PERFORM 1;
	END;
	RETURN NULL;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.validate_netblock_to_range_changes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
END; $function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.validate_network_range_dns()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
END; $function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.validate_network_range_ips()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
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
END; $function$
;

--
-- Process drops in bidder
--
--
-- Process drops in api
--
--
-- Process drops in schema_support
--
DROP FUNCTION IF EXISTS schema_support.save_dependant_objects_for_replay ( schema character varying, object character varying, dropit boolean, doobjectdeps boolean );
--
-- Process drops in net_manip
--
--
-- Process drops in network_strings
--
--
-- Process drops in time_util
--
--
-- Process drops in dns_utils
--
--
-- Process drops in person_manip
--
--
-- Process drops in auto_ac_manip
--
--
-- Process drops in company_manip
--
--
-- Process drops in token_utils
--
--
-- Process drops in port_support
--
--
-- Process drops in port_utils
--
--
-- Process drops in device_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('device_utils', 'retire_device');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS device_utils.retire_device ( in_device_id integer, retire_modules boolean );
CREATE OR REPLACE FUNCTION device_utils.retire_device(in_device_id integer, retire_modules boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally		INTEGER;
	_r			RECORD;
	_d			DEVICE%ROWTYPE;
	_mgrid		DEVICE.DEVICE_ID%TYPE;
	_purgedev	boolean;
BEGIN
	_purgedev := false;

	BEGIN
		PERFORM local_hooks.device_retire_early(in_Device_Id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	SELECT * INTO _d FROM device WHERE device_id = in_Device_id;
	delete from dns_record where netblock_id in (
		select netblock_id 
		from network_interface where device_id = in_Device_id
	);

	delete from network_interface_purpose where device_id = in_Device_id;

	WITH ni AS  (
		delete from network_interface where device_id = in_Device_id
		RETURNING *
	) delete from network_interface_netblock where network_interface_id 
		IN (
			SELECT network_interface_id
		 	FROM ni
		); 

	PERFORM device_utils.purge_physical_ports( in_Device_id);
--	PERFORM device_utils.purge_power_ports( in_Device_id);

	delete from property where device_collection_id in (
		SELECT	dc.device_collection_id 
		  FROM	device_collection dc
				INNER JOIN device_collection_device dcd
		 			USING (device_collection_id)
		WHERE	dc.device_collection_type = 'per-device'
		  AND	dcd.device_id = in_Device_id
	);

	delete from device_collection_device where device_id = in_Device_id;
	delete from snmp_commstr where device_id = in_Device_id;

		
	IF _d.rack_location_id IS NOT NULL  THEN
		UPDATE device SET rack_location_id = NULL 
		WHERE device_id = in_Device_id;

		-- This should not be permitted based on constraints, but in case
		-- that constraint had to be disabled...
		SELECT	count(*)
		  INTO	tally
		  FROM	device
		 WHERE	rack_location_id = _d.RACK_LOCATION_ID;

		IF tally = 0 THEN
			DELETE FROM rack_location 
			WHERE rack_location_id = _d.RACK_LOCATION_ID;
		END IF;
	END IF;

	IF _d.chassis_location_id IS NOT NULL THEN
		RAISE EXCEPTION 'Retiring modules is not supported yet.';
	END IF;

	SELECT	manager_device_id
	INTO	_mgrid
	 FROM	device_management_controller
	WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc'
	LIMIT 1;

	IF _mgrid IS NOT NULL THEN
		DELETE FROM device_management_controller
		WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc'
			AND manager_device_id = _mgrid;

		PERFORM device_utils.retire_device( manager_device_id)
		  FROM	device_management_controller
		WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc';
	END IF;

	BEGIN
		PERFORM local_hooks.device_retire_late(in_Device_Id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	SELECT count(*)
	INTO tally
	FROM device_note
	WHERE device_id = in_Device_id;

	--
	-- If there is no notes or serial number its save to remove
	-- 
	IF tally = 0 AND _d.ASSET_ID is NULL THEN
		_purgedev := true;
	END IF;

	IF _purgedev THEN
		--
		-- If there is an fk violation, we just preserve the record but
		-- delete all the identifying characteristics
		--
		BEGIN
			DELETE FROM device where device_id = in_Device_Id;
			return false;
		EXCEPTION WHEN foreign_key_violation THEN
			PERFORM 1;
		END;
	END IF;

	UPDATE device SET 
		device_name =NULL,
		service_environment_id = (
			select service_environment_id from service_environment
			where service_environment_name = 'unallocated'),
		device_status = 'removed',
		voe_symbolic_track_id = NULL,
		is_monitored = 'N',
		should_fetch_config = 'N',
		description = NULL
	WHERE device_id = in_Device_id;

	return true;
END;
$function$
;

--
-- Process drops in netblock_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_free_netblocks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.find_free_netblocks ( parent_netblock_list integer[], netmask_bits integer, single_address boolean, allocation_method text, max_addresses integer, desired_ip_address inet, rnd_masklen_threshold integer, rnd_max_count integer );
CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblocks(parent_netblock_list integer[], netmask_bits integer DEFAULT NULL::integer, single_address boolean DEFAULT false, allocation_method text DEFAULT NULL::text, max_addresses integer DEFAULT 1024, desired_ip_address inet DEFAULT NULL::inet, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024)
 RETURNS TABLE(ip_address inet, netblock_type character varying, ip_universe_id integer)
 LANGUAGE plpgsql
AS $function$
DECLARE
	parent_nbid		jazzhands.netblock.netblock_id%TYPE;
	netblock_rec	jazzhands.netblock%ROWTYPE;
	netrange_rec	RECORD;
	inet_list		inet[];
	current_ip		inet;
	saved_method	text;
	min_ip			inet;
	max_ip			inet;
	matches			integer;
	rnd_matches		integer;
	max_rnd_value	bigint;
	rnd_value		bigint;
	family_bits		integer;
BEGIN
	matches := 0;
	saved_method = allocation_method;

	IF allocation_method IS NOT NULL AND allocation_method
			NOT IN ('top', 'bottom', 'random', 'default') THEN
		RAISE 'address_type must be one of top, bottom, random, or default'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	--
	-- Sanitize masklen input.  This is a little complicated.
	--
	-- If a single address is desired, we always use a /32 or /128
	-- in the parent loop and everything else is ignored
	--
	-- Otherwise, if netmask_bits is passed, that wins, otherwise
	-- the netmask of whatever is passed with desired_ip_address wins
	--
	-- If none of these are the case, then things are wrong and we
	-- bail
	--

	IF NOT single_address THEN 
		IF desired_ip_address IS NOT NULL AND netmask_bits IS NULL THEN
			netmask_bits := masklen(desired_ip_address);
		ELSIF desired_ip_address IS NOT NULL AND 
				netmask_bits IS NOT NULL THEN
			desired_ip_address := set_masklen(desired_ip_address,
				netmask_bits);
		END IF;
		IF netmask_bits IS NULL THEN
			RAISE EXCEPTION 'netmask_bits must be set'
			USING ERRCODE = 'invalid_parameter_value';
		END IF;
		IF allocation_method = 'random' THEN
			RAISE EXCEPTION 'random netblocks may only be returned for single addresses'
			USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	FOREACH parent_nbid IN ARRAY parent_netblock_list LOOP
		rnd_matches := 0;
		--
		-- Restore this, because we may have overrridden it for a previous
		-- block
		--
		allocation_method = saved_method;
		SELECT 
			* INTO netblock_rec
		FROM
			jazzhands.netblock n
		WHERE
			n.netblock_id = parent_nbid;

		IF NOT FOUND THEN
			RAISE EXCEPTION 'Netblock % does not exist', parent_nbid;
		END IF;

		family_bits := 
			(CASE family(netblock_rec.ip_address) WHEN 4 THEN 32 ELSE 128 END);

		-- If desired_ip_address is passed, then allocation_method is
		-- irrelevant

		IF desired_ip_address IS NOT NULL THEN
			--
			-- If the IP address is not the same family as the parent block,
			-- we aren't going to find it
			--
			IF family(desired_ip_address) != 
					family(netblock_rec.ip_address) THEN
				CONTINUE;
			END IF;
			allocation_method := 'bottom';
		END IF;

		--
		-- If allocation_method is 'default' or NULL, then use 'bottom'
		-- unless it's for a single IPv6 address in a netblock larger than 
		-- rnd_masklen_threshold
		--
		IF allocation_method IS NULL OR allocation_method = 'default' THEN
			allocation_method := 
				CASE WHEN 
					single_address AND 
					family(netblock_rec.ip_address) = 6 AND
					masklen(netblock_rec.ip_address) <= rnd_masklen_threshold
				THEN
					'random'
				ELSE
					'bottom'
				END;
		END IF;

		IF allocation_method = 'random' AND 
				family_bits - masklen(netblock_rec.ip_address) < 2 THEN
			-- Random allocation doesn't work if we don't have enough
			-- bits to play with, so just do sequential.
			allocation_method := 'bottom';
		END IF;

		IF single_address THEN 
			netmask_bits := family_bits;
			IF desired_ip_address IS NOT NULL THEN
				desired_ip_address := set_masklen(desired_ip_address,
					masklen(netblock_rec.ip_address));
			END IF;
		ELSIF netmask_bits <= masklen(netblock_rec.ip_address) THEN
			-- If the netmask is not for a smaller netblock than this parent,
			-- then bounce to the next one, because maybe it's larger
			RAISE DEBUG
				'netblock (%) is not larger than netmask_bits of % - skipping',
				masklen(netblock_rec.ip_address),
				netmask_bits;
			CONTINUE;
		END IF;

		IF netmask_bits > family_bits THEN
			RAISE EXCEPTION 'netmask_bits must be no more than % for netblock %',
				family_bits,
				netblock_rec.ip_address;
		END IF;

		--
		-- Short circuit the check if we're looking for a specific address
		-- and it's not in this netblock
		--

		IF desired_ip_address IS NOT NULL AND
				NOT (desired_ip_address <<= netblock_rec.ip_address) THEN
			RAISE DEBUG 'desired_ip_address % is not in netblock %',
				desired_ip_address,
				netblock_rec.ip_address;
			CONTINUE;
		END IF;

		IF single_address AND netblock_rec.can_subnet = 'Y' THEN
			RAISE EXCEPTION 'single addresses may not be assigned to to a block where can_subnet is Y';
		END IF;

		IF (NOT single_address) AND netblock_rec.can_subnet = 'N' THEN
			RAISE EXCEPTION 'Netblock % (%) may not be subnetted',
				netblock_rec.ip_address,
				netblock_rec.netblock_id;
		END IF;

		RAISE DEBUG 'Searching netblock % (%) using the % allocation method',
			netblock_rec.netblock_id,
			netblock_rec.ip_address,
			allocation_method;

		IF desired_ip_address IS NOT NULL THEN
			min_ip := desired_ip_address;
			max_ip := desired_ip_address + 1;
		ELSE
			min_ip := netblock_rec.ip_address;
			max_ip := broadcast(min_ip) + 1;
		END IF;

		IF allocation_method = 'top' THEN
			current_ip := network(set_masklen(max_ip - 1, netmask_bits));
		ELSIF allocation_method = 'random' THEN
			max_rnd_value := (x'7fffffffffffffff'::bigint >> CASE 
				WHEN family_bits - masklen(netblock_rec.ip_address) >= 63
				THEN 0
				ELSE 63 - (family_bits - masklen(netblock_rec.ip_address))
				END) - 2;
			-- random() appears to only do 32-bits, which is dumb
			-- I'm pretty sure that all of the casts are not required here,
			-- but better to make sure
			current_ip := min_ip + 
					((((random() * x'7fffffff'::bigint)::bigint << 32) + 
					(random() * x'ffffffff'::bigint)::bigint + 1)
					% max_rnd_value) + 1;
		ELSE -- it's 'bottom'
			current_ip := set_masklen(min_ip, netmask_bits);
		END IF;

		-- For single addresses, make the netmask match the netblock of the
		-- containing block, and skip the network and broadcast addresses
		-- We shouldn't need to skip for IPv6 addresses, but some things
		-- apparently suck

		IF single_address THEN
			current_ip := set_masklen(current_ip, 
				masklen(netblock_rec.ip_address));
			--
			-- If we're not allocating a single /31 or /32 for IPv4 or
			-- /127 or /128 for IPv6, then we want to skip the all-zeros
			-- and all-ones addresses
			--
			IF masklen(netblock_rec.ip_address) < (family_bits - 1) AND
					desired_ip_address IS NULL THEN
				current_ip := current_ip + 
					CASE WHEN allocation_method = 'top' THEN -1 ELSE 1 END;
				min_ip := min_ip + 1;
				max_ip := max_ip - 1;
			END IF;
		END IF;

		RAISE DEBUG 'Starting with IP address % with step masklen of %',
			current_ip,
			netmask_bits;

		WHILE (
				current_ip >= min_ip AND
				current_ip < max_ip AND
				matches < max_addresses AND
				rnd_matches < rnd_max_count
		) LOOP
			RAISE DEBUG '   Checking netblock %', current_ip;

			IF single_address THEN
				--
				-- Check to see if netblock is in a network_range, and if it is,
				-- then set the value to the top or bottom of the range, or
				-- another random value as appropriate
				--
				SELECT 
					network_range_id,
					start_nb.ip_address AS start_ip_address,
					stop_nb.ip_address AS stop_ip_address
				INTO netrange_rec
				FROM
					jazzhands.network_range nr,
					jazzhands.netblock start_nb,
					jazzhands.netblock stop_nb
				WHERE
					nr.start_netblock_id = start_nb.netblock_id AND
					nr.stop_netblock_id = stop_nb.netblock_id AND
					nr.parent_netblock_id = netblock_rec.netblock_id AND
					start_nb.ip_address <= current_ip AND
					stop_nb.ip_address >= current_ip;

				IF FOUND THEN
					current_ip := CASE 
						WHEN allocation_method = 'bottom' THEN
							netrange_rec.stop_ip_address + 1
						WHEN allocation_method = 'top' THEN
							netrange_rec.start_ip_address - 1
						ELSE min_ip + ((
							((random() * x'7fffffff'::bigint)::bigint << 32) 
							+ 
							(random() * x'ffffffff'::bigint)::bigint + 1
							) % max_rnd_value) + 1 
					END;
					CONTINUE;
				END IF;
			END IF;
							
				
			PERFORM * FROM jazzhands.netblock n WHERE
				n.ip_universe_id = netblock_rec.ip_universe_id AND
				n.netblock_type = netblock_rec.netblock_type AND
				-- A block with the parent either contains or is contained
				-- by this block
				n.parent_netblock_id = netblock_rec.netblock_id AND
				CASE WHEN single_address THEN
					n.ip_address = current_ip
				ELSE
					(n.ip_address >>= current_ip OR current_ip >>= n.ip_address)
				END;
			IF NOT FOUND AND (inet_list IS NULL OR
					NOT (current_ip = ANY(inet_list))) THEN
				find_free_netblocks.netblock_type :=
					netblock_rec.netblock_type;
				find_free_netblocks.ip_universe_id :=
					netblock_rec.ip_universe_id;
				find_free_netblocks.ip_address := current_ip;
				RETURN NEXT;
				inet_list := array_append(inet_list, current_ip);
				matches := matches + 1;
				-- Reset random counter if we found something
				rnd_matches := 0;
			ELSIF allocation_method = 'random' THEN
				-- Increase random counter if we didn't find something
				rnd_matches := rnd_matches + 1;
			END IF;

			-- Select the next IP address
			current_ip := 
				CASE WHEN single_address THEN
					CASE 
						WHEN allocation_method = 'bottom' THEN current_ip + 1
						WHEN allocation_method = 'top' THEN current_ip - 1
						ELSE min_ip + ((
							((random() * x'7fffffff'::bigint)::bigint << 32) 
							+ 
							(random() * x'ffffffff'::bigint)::bigint + 1
							) % max_rnd_value) + 1 
					END
				ELSE
					CASE WHEN allocation_method = 'bottom' THEN 
						network(broadcast(current_ip) + 1)
					ELSE 
						network(current_ip - 1)
					END
				END;
		END LOOP;
	END LOOP;
	RETURN;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_utils', 'list_unallocated_netblocks');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_utils.list_unallocated_netblocks ( netblock_id integer, ip_address inet, ip_universe_id integer, netblock_type text );
CREATE OR REPLACE FUNCTION netblock_utils.list_unallocated_netblocks(netblock_id integer DEFAULT NULL::integer, ip_address inet DEFAULT NULL::inet, ip_universe_id integer DEFAULT 0, netblock_type text DEFAULT 'default'::text)
 RETURNS TABLE(ip_addr inet)
 LANGUAGE plpgsql
AS $function$
DECLARE
	ip_array		inet[];
	netblock_rec	RECORD;
	parent_nbid		jazzhands.netblock.netblock_id%TYPE;
	family_bits		integer;
	idx				integer;
	subnettable		boolean;
BEGIN
	subnettable := true;
	IF netblock_id IS NOT NULL THEN
		SELECT * INTO netblock_rec FROM jazzhands.netblock n WHERE n.netblock_id = 
			list_unallocated_netblocks.netblock_id;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'netblock_id % not found', netblock_id;
		END IF;
		IF netblock_rec.is_single_address = 'Y' THEN
			RETURN;
		END IF;
		ip_address := netblock_rec.ip_address;
		ip_universe_id := netblock_rec.ip_universe_id;
		netblock_type := netblock_rec.netblock_type;
		subnettable := CASE WHEN netblock_rec.can_subnet = 'N' 
			THEN false ELSE true
			END;
	ELSIF ip_address IS NOT NULL THEN
		ip_universe_id := 0;
		netblock_type := 'default';
	ELSE
		RAISE EXCEPTION 'netblock_id or ip_address must be passed';
	END IF;
	IF (subnettable) THEN
		SELECT ARRAY(
			SELECT 
				n.ip_address
			FROM
				netblock n
			WHERE
				n.ip_address <<= list_unallocated_netblocks.ip_address AND
				n.ip_universe_id = list_unallocated_netblocks.ip_universe_id AND
				n.netblock_type = list_unallocated_netblocks.netblock_type AND
				is_single_address = 'N' AND
				can_subnet = 'N'
			ORDER BY
				n.ip_address
		) INTO ip_array;
	ELSE
		SELECT ARRAY(
			SELECT 
				set_masklen(n.ip_address, 
					CASE WHEN family(n.ip_address) = 4 THEN 32
					ELSE 128
					END)
			FROM
				netblock n
			WHERE
				n.ip_address <<= list_unallocated_netblocks.ip_address AND
				n.ip_address != list_unallocated_netblocks.ip_address AND
				n.ip_universe_id = list_unallocated_netblocks.ip_universe_id AND
				n.netblock_type = list_unallocated_netblocks.netblock_type
			ORDER BY
				n.ip_address
		) INTO ip_array;
	END IF;

	IF array_length(ip_array, 1) IS NULL THEN
		ip_addr := ip_address;
		RETURN NEXT;
		RETURN;
	END IF;

	ip_array := array_prepend(
		list_unallocated_netblocks.ip_address - 1, 
		array_append(
			ip_array, 
			broadcast(list_unallocated_netblocks.ip_address) + 1
			));

	idx := 1;
	WHILE idx < array_length(ip_array, 1) LOOP
		RETURN QUERY SELECT cin.ip_addr FROM
			netblock_utils.calculate_intermediate_netblocks(ip_array[idx], ip_array[idx + 1]) cin;
		idx := idx + 1;
	END LOOP;

	RETURN;
END;
$function$
;

--
-- Process drops in netblock_manip
--
-- New function
CREATE OR REPLACE FUNCTION netblock_manip.create_network_range(start_ip_address inet, stop_ip_address inet, network_range_type character varying, parent_netblock_id integer DEFAULT NULL::integer, description character varying DEFAULT NULL::character varying, allow_assigned boolean DEFAULT false)
 RETURNS network_range
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	par_netblock	RECORD;
	start_netblock	RECORD;
	stop_netblock	RECORD;
	netrange		RECORD;
	nrtype			ALIAS FOR network_range_type;
	pnbid			ALIAS FOR parent_netblock_id;
BEGIN
	--
	-- If the network range already exists, then just return it, even if the
	--
	SELECT 
		nr.* INTO netrange
	FROM
		network_range nr JOIN
		netblock startnb ON (nr.start_netblock_id = startnb.netblock_id) JOIN
		netblock stopnb ON (nr.stop_netblock_id = stopnb.netblock_id)
	WHERE
		nr.network_range_type = nrtype AND
		host(startnb.ip_address) = host(start_ip_address) AND
		host(stopnb.ip_address) = host(stop_ip_address) AND
		CASE WHEN pnbid IS NOT NULL THEN 
			(pnbid = nr.parent_netblock_id)
		ELSE
			true
		END;

	IF FOUND THEN
		RETURN netrange;
	END IF;

	--
	-- If any other network ranges exist that overlap this, then error
	--
	PERFORM 
		*
	FROM
		network_range nr JOIN
		netblock startnb ON (nr.start_netblock_id = startnb.netblock_id) JOIN
		netblock stopnb ON (nr.stop_netblock_id = stopnb.netblock_id)
	WHERE
		nr.network_range_type = nrtype AND ((
			host(startnb.ip_address)::inet <= host(start_ip_address)::inet AND
			host(stopnb.ip_address)::inet >= host(start_ip_address)::inet
		) OR (
			host(startnb.ip_address)::inet <= host(stop_ip_address)::inet AND
			host(stopnb.ip_address)::inet >= host(stop_ip_address)::inet
		));

	IF FOUND THEN
		RAISE 'create_network_range: a network_range of type % already exists that has addresses between % and %',
			nrtype, start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
	END IF;

	IF parent_netblock_id IS NOT NULL THEN
		SELECT * INTO par_netblock WHERE netblock_id = parent_netblock_id;
		IF NOT FOUND THEN
			RAISE 'create_network_range: parent_netblock_id % does not exist',
				parent_netblock_id USING ERRCODE = 'foreign_key_violation';
		END IF;
	ELSE
		SELECT * INTO par_netblock FROM netblock WHERE netblock_id = (
			SELECT 
				*
			FROM
				netblock_utils.find_best_parent_id(
					in_ipaddress := start_ip_address
				)
		);

		IF NOT FOUND THEN
			RAISE 'create_network_range: valid parent netblock for start_ip_address % does not exist',
				start_ip_address USING ERRCODE = 'check_violation';
		END IF;
	END IF;

	IF par_netblock.can_subnet != 'N' OR 
			par_netblock.is_single_address != 'N' THEN
		RAISE 'create_network_range: parent netblock % must not be subnettable or a single address',
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (start_ip_address <<= par_netblock.ip_address) THEN
		RAISE 'create_network_range: start_ip_address % is not contained by parent netblock % (%)',
			start_ip_address, par_netblock.ip_address,
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (stop_ip_address <<= par_netblock.ip_address) THEN
		RAISE 'create_network_range: stop_ip_address % is not contained by parent netblock % (%)',
			stop_ip_address, par_netblock.ip_address,
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (start_ip_address <= stop_ip_address) THEN
		RAISE 'create_network_range: start_ip_address % is not lower than stop_ip_address %',
			start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
	END IF;

	--
	-- Validate that there are not currently any addresses assigned in the
	-- range, unless allow_assigned is set
	--
	IF NOT allow_assigned THEN
		PERFORM 
			*
		FROM
			netblock n
		WHERE
			n.parent_netblock_id = par_netblock.netblock_id AND
			host(n.ip_address)::inet > host(start_ip_address)::inet AND
			host(n.ip_address)::inet < host(stop_ip_address)::inet;

		IF FOUND THEN
			RAISE 'create_network_range: netblocks are already present for parent netblock % betweeen % and %',
			par_netblock.netblock_id,
			start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
		END IF;
	END IF;

	--
	-- Ok, well, we should be able to insert things now
	--

	SELECT
		*
	FROM
		netblock n
	INTO
		start_netblock
	WHERE
		host(n.ip_address)::inet = start_ip_address AND
		n.netblock_type = 'network_range' AND
		n.can_subnet = 'N' AND
		n.is_single_address = 'Y' AND
		n.ip_universe_id = par_netblock.ip_universe_id;

	IF NOT FOUND THEN
		INSERT INTO netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			netblock_status,
			ip_universe_id
		) VALUES (
			host(start_ip_address)::inet,
			'network_range',
			'Y',
			'N',
			'Allocated',
			par_netblock.ip_universe_id
		) RETURNING * INTO start_netblock;
	END IF;

	SELECT
		*
	FROM
		netblock n
	INTO
		stop_netblock
	WHERE
		host(n.ip_address)::inet = stop_ip_address AND
		n.netblock_type = 'network_range' AND
		n.can_subnet = 'N' AND
		n.is_single_address = 'Y' AND
		n.ip_universe_id = par_netblock.ip_universe_id;

	IF NOT FOUND THEN
		INSERT INTO netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			netblock_status,
			ip_universe_id
		) VALUES (
			host(stop_ip_address)::inet,
			'network_range',
			'Y',
			'N',
			'Allocated',
			par_netblock.ip_universe_id
		) RETURNING * INTO stop_netblock;
	END IF;

	INSERT INTO network_range (
		network_range_type,
		description,
		parent_netblock_id,
		start_netblock_id,
		stop_netblock_id
	) VALUES (
		nrtype,
		description,
		par_netblock.netblock_id,
		start_netblock.netblock_id,
		stop_netblock.netblock_id
	) RETURNING * INTO netrange;

	RETURN netrange;

	RETURN NULL;
END;
$function$
;

--
-- Process drops in physical_address_utils
--
--
-- Process drops in component_utils
--
--
-- Process drops in snapshot_manip
--
--
-- Process drops in lv_manip
--
--
-- Process drops in approval_utils
--
--
-- Process drops in account_collection_manip
--
--
-- Process drops in salesforce
--
--
-- Process drops in script_hooks
--
-- Dropping obsoleted sequences....


-- Dropping obsoleted audit sequences....


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
-- index
-- triggers
DROP TRIGGER IF EXISTS trigger_member_device_collection_after_hooks ON device_collection_device;
CREATE TRIGGER trigger_member_device_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON device_collection_device FOR EACH STATEMENT EXECUTE PROCEDURE device_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_hier_device_collection_after_hooks ON device_collection_hier;
CREATE TRIGGER trigger_hier_device_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON device_collection_hier FOR EACH STATEMENT EXECUTE PROCEDURE device_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_member_layer2_network_collection_after_hooks ON l2_network_coll_l2_network;
CREATE TRIGGER trigger_member_layer2_network_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON l2_network_coll_l2_network FOR EACH STATEMENT EXECUTE PROCEDURE layer2_network_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_hier_layer2_network_collection_after_hooks ON layer2_network_collection_hier;
CREATE TRIGGER trigger_hier_layer2_network_collection_after_hooks AFTER INSERT OR DELETE OR UPDATE ON layer2_network_collection_hier FOR EACH STATEMENT EXECUTE PROCEDURE layer2_network_collection_after_hooks();
DROP TRIGGER IF EXISTS trigger_validate_netblock_to_range_changes ON netblock;
CREATE CONSTRAINT TRIGGER trigger_validate_netblock_to_range_changes AFTER UPDATE OF ip_address, is_single_address, can_subnet, netblock_type ON netblock DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE validate_netblock_to_range_changes();
DROP TRIGGER IF EXISTS trigger_net_int_netblock_to_nbn_compat_after ON network_interface;
CREATE TRIGGER trigger_net_int_netblock_to_nbn_compat_after AFTER INSERT OR UPDATE OF network_interface_id, netblock_id ON network_interface FOR EACH ROW EXECUTE PROCEDURE net_int_netblock_to_nbn_compat_after();
DROP TRIGGER IF EXISTS trigger_net_int_netblock_to_nbn_compat_before_del ON network_interface;
CREATE TRIGGER trigger_net_int_netblock_to_nbn_compat_before_del BEFORE DELETE ON network_interface FOR EACH ROW EXECUTE PROCEDURE net_int_netblock_to_nbn_compat_after();
DROP TRIGGER IF EXISTS trigger_validate_network_range ON network_range;
DROP TRIGGER IF EXISTS trigger_validate_network_range_dns ON network_range;
CREATE CONSTRAINT TRIGGER trigger_validate_network_range_dns AFTER INSERT OR UPDATE OF dns_domain_id ON network_range DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE validate_network_range_dns();
DROP TRIGGER IF EXISTS trigger_validate_network_range_ips ON network_range;
CREATE CONSTRAINT TRIGGER trigger_validate_network_range_ips AFTER INSERT OR UPDATE OF start_netblock_id, stop_netblock_id, parent_netblock_id ON network_range DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE validate_network_range_ips();


-- BEGIN Misc that does not apply to above
WITH x AS (
	SELECT lpad(iso_currency_code, 2, '') as iso_country_code,
		iso_currency_code
	FROM val_iso_currency_code
) UPDATE val_country_code count
SET primary_iso_currency_code = x.iso_currency_code
FROm x
WHERE x.iso_country_code = count.iso_country_code;



-- END Misc that does not apply to above


-- Clean Up
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_saved_grants();
GRANT select on all tables in schema jazzhands to ro_role;
GRANT insert,update,delete on all tables in schema jazzhands to iud_role;
GRANT select on all sequences in schema jazzhands to ro_role;
GRANT usage on all sequences in schema jazzhands to iud_role;
GRANT select on all tables in schema audit to ro_role;
GRANT select on all sequences in schema audit to ro_role;
SELECT schema_support.end_maintenance();
select timeofday(), now();
