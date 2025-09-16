-------------------------------------------------------------------
--begin device_manip.monitoring_off_in_rack
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_manip.monitoring_off_in_rack (
	rack_id	rack.rack_id%type
) RETURNS boolean AS $$
DECLARE
	rid	ALIAS FOR rack_id;
BEGIN
	BEGIN
		PERFORM local_hooks.monitoring_off_in_rack_early(
			rack_id, false
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

	BEGIN
		PERFORM local_hooks.monitoring_off_in_rack_late(
			rack_id, false
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

	RETURN true;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end device_manip.monitoring_off_in_rack
-------------------------------------------------------------------

