CREATE OR REPLACE FUNCTION netblock_manip.recalculate_parentage(
	netblock_id	jazzhands.netblock.netblock_id%type
) RETURNS INTEGER AS $$
DECLARE
	nbrec		RECORD;
	childrec	RECORD;
	nbid		jazzhands.netblock.netblock_id%type;
	ipaddr		inet;

BEGIN
	SELECT * INTO nbrec FROM jazzhands.netblock WHERE
		netblock_id = recalculate_parentage.netblock_id;

	nbid := netblock_utils.find_best_parent_netblock_id(netblock_id);

	UPDATE jazzhands.netblock SET parent_netblock_id = nbid
		WHERE netblock_id = recalculate_parentage.netblock_id;

	FOR childrec IN SELECT *
		FROM jazzhands.netblock  p
		WHERE p.parent_netblock_id = nbid
		AND p.netblock_id != recalculate_parentage.netblock_id
	LOOP
		IF (childrec.ip_address <<= nbrec.ip_address) THEN
			UPDATE jazzhands.netblock  n
				SET parent_netblock_id = recalculate_parentage.netblock_id
				WHERE n.netblock_id = childrec.netblock_id;
		END IF;
	END LOOP;
	RETURN nbid;
END;
$$ LANGUAGE plpgsql SET search_path = jazzhands;

