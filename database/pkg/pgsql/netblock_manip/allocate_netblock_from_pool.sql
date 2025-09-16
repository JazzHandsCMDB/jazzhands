CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock_from_pool(
	netblock_allocation_pool	jazzhands.netblock_collection.netblock_collection_name%TYPE,
	site_code				jazzhands.site.site_code%TYPE DEFAULT NULL,
	address_family			integer DEFAULT 4,
	netmask_bits			integer DEFAULT NULL,
	address_type			text DEFAULT 'netblock',
	-- alternatives: 'single', 'loopback', 'uplink'
	can_subnet				boolean DEFAULT true,
	allocation_method		text DEFAULT NULL,
	-- alternatives: 'top', 'bottom', 'random',
	rnd_masklen_threshold	integer DEFAULT 110,
	rnd_max_count			integer DEFAULT 1024,
	ip_address				jazzhands.netblock.ip_address%TYPE DEFAULT NULL,
	description				jazzhands.netblock.description%TYPE DEFAULT NULL,
	netblock_status			jazzhands.netblock.netblock_status%TYPE
								DEFAULT 'Allocated'
) RETURNS SETOF jazzhands.netblock AS $$
DECLARE
	sc				ALIAS FOR site_code;
BEGIN
	RETURN QUERY
		SELECT * FROM netblock_manip.allocate_netblock(
		parent_netblock_list := ARRAY(
			SELECT
				netblock_id
			FROM
				netblock_collection nc JOIN
				netblock_collection_netblock ncn USING (netblock_collection_id) JOIN
				netblock n USING (netblock_id) JOIN
				v_site_netblock_expanded sne USING (netblock_id)
			WHERE
				netblock_collection_type = 'NetblockAllocationPool' AND
				netblock_collection_name = netblock_allocation_pool AND
				family(n.ip_address) = address_family AND
				(sc IS NULL OR sne.site_code = sc)
		),
		netmask_bits := netmask_bits,
		address_type := address_type,
		can_subnet := can_subnet,
		description := description,
		allocation_method := allocation_method,
		ip_address := ip_address,
		rnd_masklen_threshold := rnd_masklen_threshold,
		rnd_max_count := rnd_max_count,
		netblock_status := netblock_status
	);
END;
$$ LANGUAGE plpgsql
SET search_path = jazzhands
SECURITY DEFINER;

