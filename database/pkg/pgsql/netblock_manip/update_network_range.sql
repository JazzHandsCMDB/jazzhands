CREATE OR REPLACE FUNCTION netblock_manip.update_network_range(
	network_range_id	jazzhands.network_range.network_range_id%TYPE,
	start_ip_address	inet DEFAULT NULL,
	stop_ip_address		inet DEFAULT NULL,
	parent_netblock_id	jazzhands.netblock.netblock_id%TYPE DEFAULT NULL,
	allow_assigned		boolean DEFAULT false,
	description			jazzhands.network_range.description%TYPE DEFAULT NULL,
	dns_prefix			TEXT DEFAULT NULL,
	dns_domain_id		jazzhands.dns_domain.dns_domain_id%TYPE DEFAULT NULL,
	lease_time			jazzhands.network_range.lease_time%TYPE DEFAULT NULL
) RETURNS boolean AS $$
DECLARE
	nbcheck					RECORD;
	start_netblock			RECORD;
	stop_netblock			RECORD;
	new_start_ip_address	inet;
	new_stop_ip_address		inet;
	new_parent_netblock_id	jazzhands.netblock.netblock_id%TYPE;
	netrange				RECORD;
	nrid					ALIAS FOR network_range_id;
	pnbid					ALIAS FOR parent_netblock_id;
BEGIN
	--
	-- Pull things about the network_range.  Fetch things out of the
	-- v_network_range_expanded view because it has everything we want in it.
	--
	SELECT
		nr.* INTO netrange
	FROM
		jazzhands.v_network_range_expanded nr
	WHERE
		nr.network_range_id = nrid;

	IF NOT FOUND THEN
		RAISE EXCEPTION
			'update_network_range: network_range %d does not exist',
			nrid
		USING ERRCODE = 'foreign_key_violation';
	END IF;

	--
	-- Validate things passed.  This will throw an exception if things aren't
	-- valid
	--

	--
	-- Check that the netblock_type for the {start,stop} netblock are
	-- valid if they are trying to be set.  If things are NULL, it's skipped.
	--
	IF
		host(start_ip_address) != host(netrange.start_ip_address) AND
		netrange.start_netblock_type != 'network_range'
	THEN
		RAISE EXCEPTION
			'Address changes of start_ip_address are only allowed if the netblock_type is "network_range"'
		USING ERRCODE = 'check_violation';
	END IF;

	IF
		host(stop_ip_address) != host(netrange.stop_ip_address) AND
		netrange.stop_netblock_type != 'network_range'
	THEN
		RAISE EXCEPTION
			'Address changes of stop_ip_address are only allowed if the netblock_type is "network_range"'
		USING ERRCODE = 'check_violation';
	END IF;

	new_start_ip_address := COALESCE(start_ip_address,
		netrange.start_ip_address);
	new_stop_ip_address := COALESCE(stop_ip_address,
		netrange.stop_ip_address);
	new_parent_netblock_id := COALESCE(parent_netblock_id,
		netrange.parent_netblock_id);

	SELECT * INTO nbcheck FROM netblock_manip.validate_network_range(
		network_range_id := nrid,
		network_range_type := netrange.network_range_type,
		start_ip_address := new_start_ip_address,
		stop_ip_address := new_stop_ip_address,
		parent_netblock_id := new_parent_netblock_id
	);

	--
	-- Validate that there are not currently any addresses assigned in the
	-- updated range, unless allow_assigned is set
	--
	IF NOT allow_assigned THEN
		PERFORM
			*
		FROM
			jazzhands.netblock n
		WHERE
			n.parent_netblock_id = nbcheck.parent_netblock_id AND
			host(n.ip_address)::inet > host(new_start_ip_address)::inet AND
			host(n.ip_address)::inet < host(new_stop_ip_address)::inet;

		IF FOUND THEN
			RAISE 'create_network_range: netblocks are already present for parent netblock % betweeen % and %',
				nbcheck.parent_netblock_id,
				new_start_ip_address,
				new_stop_ip_address
			USING ERRCODE = 'check_violation';
		END IF;
	END IF;

	--
	-- We should be able to update things now
	--

	IF
		host(start_ip_address) != host(netrange.start_ip_address)
	THEN
		UPDATE
			netblock n
		SET
			ip_address = (host(start_ip_address))::inet
		WHERE
			n.netblock_id = netrange.start_netblock_id;
	END IF;

	IF
		host(stop_ip_address) != host(netrange.stop_ip_address)
	THEN
		UPDATE
			netblock n
		SET
			ip_address = (host(stop_ip_address))::inet
		WHERE
			n.netblock_id = netrange.stop_netblock_id;
	END IF;

	IF
		description IS NOT NULL OR
		dns_prefix IS NOT NULL OR
		dns_domain_id IS NOT NULL OR
		lease_time IS NOT NULL
	THEN
		--
		-- This is a hack, but we shouldn't have empty descriptions anyways.
		-- Meh.
		--
		IF description = '' THEN
			description = NULL;
		END IF;

		UPDATE
			network_range nr
		SET
			description = update_network_range.description,
			dns_prefix = update_network_range.dns_prefix,
			dns_domain_id = update_network_range.dns_domain_id,
			lease_time = update_network_range.lease_time
		WHERE
			nr.network_range_id = nrid;
	END IF;

	RETURN true;
END;
$$ LANGUAGE plpgsql
SET search_path = jazzhands
SECURITY DEFINER;

