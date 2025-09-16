CREATE OR REPLACE FUNCTION netblock_manip.remove_network_range(
	network_range_id jazzhands.network_range.network_range_id%TYPE,
	force	boolean	DEFAULT false
) RETURNS boolean AS $$
DECLARE
	nrrec		RECORD;

	nr_id		ALIAS FOR network_range_id;
BEGIN

	SELECT
		* INTO nrrec
	FROM
		network_range nr
	WHERE
		nr.network_range_id = nr_id;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'network_range % does not exist', nr_id;
	END IF;

	IF force THEN
		DELETE FROM property p WHERE p.network_range_id = nr_id;
	END IF;

	DELETE FROM network_range nr WHERE nr.network_range_id = nr_id;

	RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

