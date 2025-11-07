-------------------------------------------------------------------
--begin device_manip.set_operating_system
-------------------------------------------------------------------

CREATE OR REPLACE FUNCTION device_manip.set_operating_system (
	device_id						jazzhands.device.device_id%TYPE,
	operating_system_name			text,
	operating_system_version		text,
	operating_system_major_version	text DEFAULT NULL,
	operating_system_family			text DEFAULT NULL,
	operating_system_company_name	text DEFAULT NULL
) RETURNS jazzhands.operating_system.operating_system_id%TYPE AS $$
DECLARE
	did		ALIAS FOR device_id;
	osname	ALIAS FOR operating_system_name;
	osrec	RECORD;
	cid		jazzhands.company.company_id%TYPE;
BEGIN
	SELECT
		*
	FROM
		operating_system os
	INTO
		osrec
	WHERE
		os.operating_system_name = osname AND
		os.version = operating_system_version;

	IF NOT FOUND THEN
		--
		-- Don't care if this is NULL
		--
		SELECT
			company_id INTO cid
		FROM
			company
		WHERE
			company_name = operating_system_company_name;

		BEGIN
			INSERT INTO operating_system (
				operating_system_name,
				company_id,
				major_version,
				version,
				operating_system_family
			) VALUES (
				osname,
				cid,
				operating_system_major_version,
				operating_system_version,
				operating_system_family
			) RETURNING * INTO osrec;
		EXCEPTION
			WHEN unique_violation THEN
				RETURN -1;
		END;
	END IF;

	UPDATE
		device d
	SET
		operating_system_id = osrec.operating_system_id
	WHERE
		d.device_id = did;

	RETURN osrec.operating_system_id;
END;
$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;

-------------------------------------------------------------------
--end device_manip.set_operating_system
-------------------------------------------------------------------

