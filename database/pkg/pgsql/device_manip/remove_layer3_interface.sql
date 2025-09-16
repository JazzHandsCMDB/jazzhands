-------------------------------------------------------------------
--begin remove_layer3_interface
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_manip.remove_layer3_interface (
	layer3_interface_id	jazzhands.layer3_interface.layer3_interface_id%TYPE DEFAULT NULL,
	device_id				device.device_id%TYPE DEFAULT NULL,
	layer3_interface_name	jazzhands.layer3_interface.layer3_interface_name%TYPE DEFAULT NULL
) RETURNS boolean AS $$
DECLARE
	ni_id		ALIAS FOR layer3_interface_id;
	dev_id		ALIAS FOR device_id;
	ni_name		ALIAS FOR layer3_interface_name;
BEGIN
	IF layer3_interface_id IS NULL THEN
		IF device_id IS NULL OR layer3_interface_name IS NULL THEN
			RAISE 'Must pass either layer3_interface_id or device_id and layer3_interface_name to device_manip.delete_layer3_interface'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		SELECT
			ni.layer3_interface_id INTO ni_id
		FROM
			layer3_interface ni
		WHERE
			ni.device_id = dev_id AND
			ni.layer3_interface_name = ni_name;

		IF NOT FOUND THEN
			RETURN false;
		END IF;
	END IF;

	PERFORM * FROM device_manip.remove_layer3_interfaces(
			layer3_interface_id_list := ARRAY[ layer3_interface_id ]
		);

	RETURN true;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end of remove_layer3_interface
-------------------------------------------------------------------

