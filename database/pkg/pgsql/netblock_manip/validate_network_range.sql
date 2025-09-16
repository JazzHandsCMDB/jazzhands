CREATE OR REPLACE FUNCTION netblock_manip.validate_network_range(
	network_range_id	jazzhands.network_range.network_range_id%TYPE DEFAULT NULL,
	start_ip_address	inet DEFAULT NULL,
	stop_ip_address		inet DEFAULT NULL,
	network_range_type	jazzhands.val_network_range_type.network_range_type%TYPE DEFAULT NULL,
	parent_netblock_id	jazzhands.netblock.netblock_id%TYPE DEFAULT NULL
) RETURNS jazzhands.v_network_range_expanded AS $$
DECLARE
	proposed_range	jazzhands.v_network_range_expanded%ROWTYPE;
	current_range	jazzhands.v_network_range_expanded%ROWTYPE;
	par_netblock	RECORD;
	start_netblock	RECORD;
	stop_netblock	RECORD;
	nrt				RECORD;
	temprange		RECORD;

	nr_id			ALIAS FOR network_range_id;
	nr_type			ALIAS FOR network_range_type;
	nr_start_addr	ALIAS FOR start_ip_address;
	nr_stop_addr	ALIAS FOR stop_ip_address;
	pnbid			ALIAS FOR parent_netblock_id;
BEGIN
	--
	-- If network_range_id is passed, because we're modifying an existing
	-- one, pull it in, otherwise populate a new one
	--
	IF nr_id IS NOT NULL THEN
		SELECT
			* INTO current_range
		FROM
			v_network_range_expanded nr
		WHERE
			nr.network_range_id = nr_id;

		IF NOT FOUND THEN
			RAISE 'network_range with network_range_id % does not exist',
				nr_id
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	--
	-- Make a copy of the current range if it exists.
	--
	proposed_range := current_range;

	--
	-- Don't allow network_range_type to be changed
	--
	IF
		nr_type != proposed_range.network_range_type
	THEN
		RAISE 'network_range_type may not be changed'
			USING ERRCODE = 'check_violation';
	END IF;

	--
	-- Set anything that's passed into the proposed network_range
	--
	proposed_range.network_range_type :=
		COALESCE(nr_type, proposed_range.network_range_type);

	SELECT
		* INTO nrt
	FROM
		val_network_range_type v
	WHERE
		v.network_range_type = proposed_range.network_range_type;

	IF NOT FOUND THEN
		RAISE 'invalid network_range_type'
			USING ERRCODE = 'check_violation';
	END IF;

	IF (start_ip_address IS DISTINCT FROM proposed_range.start_ip_address) THEN
		proposed_range.start_ip_address = start_ip_address;
		proposed_range.start_netblock_id = NULL;
		proposed_range.start_netblock_type = NULL;
		proposed_range.start_ip_universe_id = NULL;
	END IF;

	IF (stop_ip_address IS DISTINCT FROM proposed_range.stop_ip_address) THEN
		proposed_range.stop_ip_address = stop_ip_address;
		proposed_range.stop_netblock_id = NULL;
		proposed_range.stop_netblock_type = NULL;
		proposed_range.stop_ip_universe_id = NULL;
	END IF;

	IF parent_netblock_id IS NOT NULL AND
		parent_netblock_id IS DISTINCT FROM proposed_range.parent_netblock_id
	THEN
		proposed_range.parent_netblock_id = parent_netblock_id;
		proposed_range.ip_address = NULL;
		proposed_range.netblock_type = NULL;
		proposed_range.ip_universe_id = NULL;
	END IF;
	proposed_range.parent_netblock_id :=
		COALESCE(pnbid, proposed_range.parent_netblock_id);

	IF (
		proposed_range.start_ip_address IS NULL OR
		proposed_range.stop_ip_address IS NULL
	) THEN
		RAISE 'start_ip_address and stop_ip_address must both be set for a network_range'
			USING ERRCODE = 'check_violation';
	END IF;

	--
	-- If any other network ranges of this type exist that overlap this one,
	-- and the network_range_type doesn't allow that, then error.  This gets
	-- the situation where an address has changed or if it's a new range
	--
	IF NOT nrt.can_overlap AND
		(proposed_range.start_ip_address IS DISTINCT FROM
			current_range.start_ip_address) OR
		(proposed_range.stop_ip_address IS DISTINCT FROM
			current_range.stop_ip_address)
	THEN
		SELECT
			nr.network_range_id,
			startnb.ip_address as start_ip_address,
			stopnb.ip_address as stop_ip_address
		INTO temprange
		FROM
			jazzhands.network_range nr JOIN
			jazzhands.netblock startnb ON
				(nr.start_netblock_id = startnb.netblock_id) JOIN
			jazzhands.netblock stopnb ON (nr.stop_netblock_id = stopnb.netblock_id)
		WHERE
			nr.network_range_id IS DISTINCT FROM nr_id AND
			nr.network_range_type = proposed_range.network_range_type AND ((
				host(startnb.ip_address)::inet <=
					host(proposed_range.start_ip_address)::inet AND
				host(stopnb.ip_address)::inet >=
					host(proposed_range.start_ip_address)::inet
			) OR (
				host(startnb.ip_address)::inet <=
					host(proposed_range.stop_ip_address)::inet AND
				host(stopnb.ip_address)::inet >=
					host(proposed_range.stop_ip_address)::inet
			));

		IF FOUND THEN
			RAISE 'validate_network_range: network_range % of type % already exists that has addresses between % and % (% through %)',
				temprange.network_range_id,
				proposed_range.network_range_type,
				proposed_range.start_ip_address,
				proposed_range.stop_ip_address,
				temprange.start_ip_address,
				temprange.stop_ip_address
				USING ERRCODE = 'check_violation';
		END IF;
	END IF;

	IF parent_netblock_id IS NOT NULL THEN
		SELECT * INTO par_netblock FROM jazzhands.netblock WHERE
			netblock_id = pnbid;
		IF NOT FOUND THEN
			RAISE 'validate_network_range: parent_netblock_id % does not exist',
				parent_netblock_id USING ERRCODE = 'foreign_key_violation';
		END IF;
	ELSE
		SELECT * INTO par_netblock FROM jazzhands.netblock WHERE netblock_id = (
			SELECT
				*
			FROM
				netblock_utils.find_best_parent_netblock_id(
					ip_address := start_ip_address,
					is_single_address := true
				)
		);

		IF NOT FOUND THEN
			RAISE 'validate_network_range: valid parent netblock for start_ip_address % does not exist',
				start_ip_address USING ERRCODE = 'check_violation';
		END IF;
	END IF;

	IF par_netblock.can_subnet != false OR
			par_netblock.is_single_address != false THEN
		RAISE 'validate_network_range: parent netblock % must not be subnettable or a single address',
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (start_ip_address <<= par_netblock.ip_address) THEN
		RAISE 'validate_network_range: start_ip_address % is not contained by parent netblock % (%)',
			start_ip_address, par_netblock.ip_address,
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (stop_ip_address <<= par_netblock.ip_address) THEN
		RAISE 'validate_network_range: stop_ip_address % is not contained by parent netblock % (%)',
			stop_ip_address, par_netblock.ip_address,
			par_netblock.netblock_id USING ERRCODE = 'check_violation';
	END IF;

	IF NOT (start_ip_address <= stop_ip_address) THEN
		RAISE 'validate_network_range: start_ip_address % is not lower than stop_ip_address %',
			start_ip_address, stop_ip_address
			USING ERRCODE = 'check_violation';
	END IF;

	proposed_range.parent_netblock_id := par_netblock.netblock_id;
    proposed_range.ip_address := par_netblock.ip_address;
    proposed_range.netblock_type := par_netblock.netblock_type;
    proposed_range.ip_universe_id := par_netblock.ip_universe_id;
	RETURN proposed_range;
END;
$$ LANGUAGE plpgsql
SET search_path = jazzhands
SECURITY DEFINER;

