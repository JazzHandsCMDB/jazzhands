CREATE OR REPLACE FUNCTION netblock_manip.create_network_range(
	start_ip_address	inet,
	stop_ip_address		inet,
	network_range_type	jazzhands.val_network_range_type.network_range_type%TYPE,
	parent_netblock_id	jazzhands.netblock.netblock_id%TYPE DEFAULT NULL,
	description			jazzhands.network_range.description%TYPE DEFAULT NULL,
	allow_assigned		boolean DEFAULT false,
	dns_prefix			TEXT DEFAULT NULL,
	dns_domain_id		jazzhands.dns_domain.dns_domain_id%TYPE DEFAULT NULL,
	lease_time			jazzhands.network_range.lease_time%TYPE DEFAULT NULL
) RETURNS jazzhands.network_range AS $$
DECLARE
	nbcheck			RECORD;
	start_netblock	RECORD;
	stop_netblock	RECORD;
	netrange		RECORD;
	nrtype			ALIAS FOR network_range_type;
	pnbid			ALIAS FOR parent_netblock_id;
BEGIN
	--
	-- If the network range already exists, then just return it
	--
	SELECT
		nr.* INTO netrange
	FROM
		jazzhands.network_range nr JOIN
		jazzhands.netblock startnb ON (nr.start_netblock_id =
			startnb.netblock_id) JOIN
		jazzhands.netblock stopnb ON (nr.stop_netblock_id = stopnb.netblock_id)
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
	-- Validate things passed.  This will throw an exception if things aren't
	-- valid
	--

	SELECT * INTO nbcheck FROM netblock_manip.validate_network_range(
		network_range_type := nrtype,
		start_ip_address := start_ip_address,
		stop_ip_address := stop_ip_address,
		parent_netblock_id := parent_netblock_id
	);

	--
	-- Validate that there are not currently any addresses assigned in the
	-- range, unless allow_assigned is set
	--
	IF NOT allow_assigned THEN
		PERFORM
			*
		FROM
			jazzhands.netblock n
		WHERE
			n.parent_netblock_id = nbcheck.parent_netblock_id AND
			host(n.ip_address)::inet > host(start_ip_address)::inet AND
			host(n.ip_address)::inet < host(stop_ip_address)::inet;

		IF FOUND THEN
			RAISE 'create_network_range: netblocks are already present for parent netblock % betweeen % and %',
			nbcheck.parent_netblock_id,
			start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
		END IF;
	END IF;

	--
	-- We should be able to insert things now
	--

	SELECT
		*
	FROM
		jazzhands.netblock n
	INTO
		start_netblock
	WHERE
		host(n.ip_address)::inet = start_ip_address AND
		n.netblock_type = 'network_range' AND
		n.can_subnet = false AND
		n.is_single_address = true AND
		n.ip_universe_id = nbcheck.ip_universe_id;

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
			true,
			false,
			'Allocated',
			nbcheck.ip_universe_id
		) RETURNING * INTO start_netblock;
	END IF;

	SELECT
		*
	FROM
		jazzhands.netblock n
	INTO
		stop_netblock
	WHERE
		host(n.ip_address)::inet = stop_ip_address AND
		n.netblock_type = 'network_range' AND
		n.can_subnet = false AND
		n.is_single_address = true AND
		n.ip_universe_id = nbcheck.ip_universe_id;

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
			true,
			false,
			'Allocated',
			nbcheck.ip_universe_id
		) RETURNING * INTO stop_netblock;
	END IF;

	INSERT INTO network_range (
		network_range_type,
		description,
		parent_netblock_id,
		start_netblock_id,
		stop_netblock_id,
		dns_prefix,
		dns_domain_id,
		lease_time
	) VALUES (
		nrtype,
		description,
		nbcheck.parent_netblock_id,
		start_netblock.netblock_id,
		stop_netblock.netblock_id,
		create_network_range.dns_prefix,
		create_network_range.dns_domain_id,
		create_network_range.lease_time
	) RETURNING * INTO netrange;

	RETURN netrange;

	RETURN NULL;
END;
$$ LANGUAGE plpgsql
SET search_path = jazzhands
SECURITY DEFINER;

