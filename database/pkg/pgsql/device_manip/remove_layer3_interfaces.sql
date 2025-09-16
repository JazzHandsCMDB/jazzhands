-------------------------------------------------------------------
--begin remove_layer3_interfaces
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_manip.remove_layer3_interfaces (
	layer3_interface_id_list	integer[]
) RETURNS boolean AS $$
DECLARE
	nb_list		integer[];
	sn_list		integer[];
	sn_rec		RECORD;
	nb_id		jazzhands.netblock.netblock_id%TYPE;
BEGIN
	--
	-- Save off some netblock information for now
	--

	RAISE LOG 'Removing layer3_interfaces with ids %',
		array_to_string(layer3_interface_id_list, ', ');

	RAISE LOG 'Retrieving netblock information...';

	SELECT
		array_agg(nin.netblock_id) INTO nb_list
	FROM
		layer3_interface_netblock nin
	WHERE
		nin.layer3_interface_id = ANY(layer3_interface_id_list);

	SELECT DISTINCT
		array_agg(shared_netblock_id) INTO sn_list
	FROM
		shared_netblock_layer3_interface snni
	WHERE
		snni.layer3_interface_id = ANY(layer3_interface_id_list);

	--
	-- Clean up network bits
	--

	RAISE LOG 'Removing shared netblocks...';

	DELETE FROM shared_netblock_layer3_interface WHERE
		layer3_interface_id IN (
			SELECT
				layer3_interface_id
			FROM
				layer3_interface ni
			WHERE
				ni.layer3_interface_id = ANY(layer3_interface_id_list)
		);

	--
	-- Clean up things for any shared_netblocks which are now orphaned
	-- Unfortunately, we have to do these as individual queries to catch
	-- exceptions
	--
	FOR sn_rec IN SELECT
		shared_netblock_id,
		netblock_id
	FROM
		shared_netblock s LEFT JOIN
		shared_netblock_layer3_interface USING (shared_netblock_id)
	WHERE
		shared_netblock_id = ANY(sn_list) AND
		layer3_interface_id IS NULL
	LOOP
		BEGIN
			DELETE FROM dns_record dr WHERE
				dr.netblock_id = sn_rec.netblock_id;
			DELETE FROM shared_netblock sn WHERE
				sn.shared_netblock_id = sn_rec.shared_netblock_id;
			BEGIN
				DELETE FROM netblock n WHERE
					n.netblock_id = sn_rec.netblock_id;
			EXCEPTION WHEN foreign_key_violation THEN
				NULL;
			END;
		EXCEPTION WHEN foreign_key_violation THEN
			NULL;
		END;
	END LOOP;

	DELETE FROM layer3_interface_netblock WHERE layer3_interface_id IN (
		SELECT
			layer3_interface_id
	 	FROM
			layer3_interface ni
		WHERE
			ni.layer3_interface_id = ANY (layer3_interface_id_list)
	);

	RAISE LOG 'Removing layer3_interfaces...';

	DELETE FROM layer3_interface_purpose nip WHERE
		nip.layer3_interface_id = ANY(layer3_interface_id_list);

	DELETE FROM layer3_interface ni WHERE ni.layer3_interface_id =
		ANY(layer3_interface_id_list);

	RAISE LOG 'Removing netblocks (%) ... ', nb_list;
	IF nb_list IS NOT NULL THEN
		FOREACH nb_id IN ARRAY nb_list LOOP
			BEGIN
				DELETE FROM dns_record WHERE netblock_id = nb_id;

				DELETE FROM netblock n WHERE
					n.netblock_id = nb_id;
			EXCEPTION WHEN foreign_key_violation THEN
				NULL;
			END;
		END LOOP;
	END IF;

	RETURN true;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end of remove_layer3_interfaces
-------------------------------------------------------------------

