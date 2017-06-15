\set ON_ERROR_STOP

-- things not done on insert:
--
-- short_name
-- can_build_rpm
-- default_nagios_service_set_id
-- use_release
-- starting_port_number
-- max_num_ports
-- build_type
-- inherited_application_id
--
-- some want to be in a maestro_jazz table.  Some want to just go away.

rollback;
begin;

DO $$
DECLARE
	_name TEXT;
	_active char(1);
	_a maestro.application%ROWTYPE;
	_sc integer;
BEGIN
	FOR _a IN SELECT * FROM maestro.application ORDER BY id
	LOOP
		IF _a.deleted != 0 THEN
			_active := 'N';
			_name := concat(_a.name, ' ( deleted ) -- ', _a.id);
		ELSE
			_name := _a.name;
			_active := 'Y';
		END IF;
		INSERT INTO service (
			service_id, service_name, description, is_active
		) VALUES ( _a.id, _name, _a.description, _active) ;

		-- created by trigger
		SELECT service_collection_id INTO _sc
        	FROM service_collection sc
			WHERE service_collection_name = _name
        	AND service_collection_type = 'all-services';

		IF _a.git_repo IS NOT NULL THEN
			WITH sr AS (
				INSERT INTO source_repository (
					source_repository_name, source_repository_type,
					source_repository_technology, source_repository_url
				) VALUES (
					concat(_name, ' git repo (', _a.id, ')'),
					'software', 'git', _a.git_repo
				) RETURNING *
			) INSERT INTO service_source_repository
				(service_Id, source_repository_id)
				SELECT _a.id, source_repository_id
				FROM sr;
		END IF;

		IF _a.git_repo IS NOT NULL THEN
			IF _a.has_config = 1 THEN
				WITH sr AS (
					INSERT INTO source_repository (
						source_repository_name, source_repository_type,
						source_repository_technology, source_repository_url
					) VALUES (
						concat(_name, ' git config repo (', _a.id, ')'),
						'confg', 'git', replace(_a.git_repo, ':app',':app-config')
					) RETURNING *
				) INSERT INTO service_source_repository
					(service_Id, source_repository_id)
					SELECT _a.id, source_repository_id
					FROM sr;
			END IF;
		END IF;

		IF _a.r_cores IS NOT NULL THEN
			INSERT INTO service_property (
				service_collection_id, service_property_name,
				service_property_type, value
			) VALUES (
				_sc, 'min_cpu',
				'launch', _a.r_cores
			);
		END IF;

		-- XXX deal with gb/mb/etc
		IF _a.r_memory_mb IS NOT NULL THEN
			INSERT INTO service_property (
				service_collection_id, service_property_name,
				service_property_type, value
			) VALUES (
				_sc, 'min_cpu',
				'launch', _a.r_memory_mb
			);
		END IF;

		-- XXX deal with gb/mb/etc
		IF _a.r_disk_gb IS NOT NULL THEN
			INSERT INTO service_property (
				service_collection_id, service_property_name,
				service_property_type, value
			) VALUES (
				_sc, 'min_disk',
				'launch', _a.r_disk_gb
			);
		END IF;

		-- XXX deal with gb/mb/etc
		IF _a.r_dedicated IS NOT NULL THEN
			INSERT INTO service_property (
				service_collection_id, service_property_name,
				service_property_type, value
			) VALUES (
				_sc, 'dedicated',
				'launch', 'Y'
			);
		END IF;

		IF _a.documentation IS NOT NULL THEN
			INSERT INTO service_property (
				service_collection_id, service_property_name,
				service_property_type, value
			) VALUES (
				_sc, 'manual',
				'docs', _a.documentation
			);
		END IF;

	END LOOP;
END;
$$
;
