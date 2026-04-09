-------------------------------------------------------------------
--begin insert_device
-- returns device record of the inserted device
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION device_manip.insert_device (
	device_name		jazzhands.device.device_name%TYPE,
	model			jazzhands.device_type.model%TYPE,
	company_name	jazzhands.company.company_name%TYPE DEFAULT NULL,
	site_code		jazzhands.site.site_code%TYPE DEFAULT NULL,
	device_status	jazzhands.val_device_status.device_status%TYPE
		DEFAULT 'up',
	service_environment_name
		jazzhands.service_environment.service_environment_name%TYPE
		DEFAULT 'production',
	device_function	jazzhands.device_collection.device_collection_name%TYPE
		DEFAULT NULL
) RETURNS jazzhands.device AS $$
#variable_conflict use_variable
DECLARE
	dev_type_id	jazzhands.device_type.device_type_id%TYPE;
	svc_env_id	jazzhands.service_environment.service_environment_id%TYPE;
	dc_id		jazzhands.device_collection.device_collection_id%TYPE;
	dev_rec		RECORD;
BEGIN
	SELECT
		device_type_id
	INTO
		dev_type_id
	FROM
		device_type dt JOIN
		company c USING (company_id)
	WHERE
		dt.model = model AND
		(
			CASE
				WHEN company_name IS NULL THEN true
				ELSE company_name = c.company_name
			END
		);
	
	IF dev_type_id IS NULL THEN
		RAISE '%',
			format('device_type_id not found for model %s%s',
				model,
				CASE
					WHEN company_name IS NULL THEN ''
					ELSE format('company_name "%s"', company_name)
				END
			);
	END IF;

	SELECT
		service_environment_id
	INTO
		svc_env_id
	FROM
		service_environment se
	WHERE
		se.service_environment_name = service_environment_name;
	
	IF svc_env_id IS NULL THEN
		RAISE 'service_environment_name "%s" not found',
			service_environment_name;
	END IF;

	INSERT INTO device (
		device_name,
		physical_label,
		device_type_id,
		site_code,
		device_status,
		service_environment_id
	) VALUES (
		device_name,
		device_name,
		dev_type_id,
		site_code,
		device_status,
		svc_env_id
	)
	RETURNING * INTO dev_rec;

	IF device_function IS NOT NULL THEN
		SELECT
			device_collection_id
		INTO
			dc_id
		FROM
			device_collection dc
		WHERE
			device_collection_type = 'device-function' AND
			device_collection_name = device_function;

		IF NOT FOUND THEN
			RAISE 'device_collection "%s" of type "device-function" does not exist',
				device_function;
		END IF;

		INSERT INTO device_collection_device(
			device_collection_id,
			device_id
		) VALUES (
			dc_id,
			dev_rec.device_id
		);
	END IF;

	RETURN dev_rec;
END;

$$ LANGUAGE plpgsql set search_path=jazzhands SECURITY DEFINER;
-------------------------------------------------------------------
--end of insert_device
-------------------------------------------------------------------

