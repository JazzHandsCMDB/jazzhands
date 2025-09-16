CREATE OR REPLACE FUNCTION netblock_manip.delete_netblock(
	netblock_id	jazzhands.netblock.netblock_id%type
) RETURNS VOID AS $$
DECLARE
	par_nbid	jazzhands.netblock.netblock_id%type;
BEGIN
	/*
	 * Update netblocks that use this as a parent to point to my parent
	 */
	SELECT
		netblock_id INTO par_nbid
	FROM
		jazzhands.netblock n
	WHERE
		n.netblock_id = delete_netblock.netblock_id;

	UPDATE
		jazzhands.netblock n
	SET
		parent_netblock_id = par_nbid
	WHERE
		n.parent_netblock_id = delete_netblock.netblock_id;

	/*
	 * Now delete the record
	 */
	DELETE FROM jazzhands.netblock WHERE netblock_id = delete_netblock.netblock_id;
END;
$$ LANGUAGE plpgsql SET search_path = jazzhands;

