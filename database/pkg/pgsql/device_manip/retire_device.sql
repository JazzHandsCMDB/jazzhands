-------------------------------------------------------------------
--begin retire_device
-- returns t/f if the device was removed or not
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_manip.retire_device (
	device_id device.device_id%type,
	retire_modules boolean DEFAULT false
) RETURNS boolean AS $$
DECLARE
	rv	boolean;
BEGIN
	-- return what the table has for this device
	SELECT success FROM device_manip.retire_devices(
			device_id_list := ARRAY[ retire_device.device_id ]
		)
	INTO rv;

	RETURN rv;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end of retire_device
-------------------------------------------------------------------

