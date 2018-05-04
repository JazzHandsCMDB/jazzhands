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

SET search_path=jazzhands,maestro;

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
						source_repository_technology, 
						source_repository_url
					) VALUES (
						concat(_name, ' git config repo (', _a.id, ')'),
						'config', 'git', 
						replace(_a.git_repo, ':app',':app-config')
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
				_sc, 'min_memory',
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

		INSERT INTO maestro_jazz.application (
			service_id, service_collection_id, short_name,
			abbreviation, can_build_rpm,
			default_nagios_service_set_id, use_release,
			starting_port_number, max_num_ports,
			build_type, inherited_application_id,
			legacy_has_config
		) VALUES (
			_a.id, _sc, _a.short_name,
			_a.abbreviation, _a.can_build_rpm,
			_a.default_nagios_service_set_id, _a.use_release,
			_a.starting_port_number, _a.max_num_ports,
			_a.build_type, _a.inherited_application_id,
			_a.has_config
		);

	END LOOP;
END;
$$
;

SELECT schema_support.save_grants_for_replay(
	schema := 'maestro',
	object := 'application'
);

ALTER TABLE maestro.application RENAME TO application_old;

SAVEPOINT preview;

--
-- the whole has_config thing is some bullshit.
--
CREATE VIEW maestro.application AS
SELECT
	mj.service_id AS id,
	regexp_replace(s.service_name, ' \( deleted \).*$', '')  AS name,
	mj.short_name,
	mj.abbreviation,
	sp.r_cores,
	sp.r_memory_mb,
	sp.r_disk_gb,
	CASE WHEN sp.r_dedicated = 'Y' THEN 1 ELSE 0 END as dedicated,
	CASE WHEN s.is_active = 'Y' THEN 0 ELSE 1 END as deleted,
	mj.can_build_rpm,
	mj.default_nagios_service_set_id,
	src.software AS git_repo,
	mj.use_release,
	mj.starting_port_number,
	mj.max_num_ports,
	s.description,
	sp.documentation,
	CASE WHEN src.config IS NULL THEN mj.legacy_has_config ELSE 1 END AS has_config,
	mj.build_type,
	mj.inherited_application_id
FROM maestro_jazz.application mj
	JOIN jazzhands.service s USING (service_id)
	LEFT JOIN (
		SELECT service_collection_id,
			MIN(value) FILTER (WHERE service_property_type = 'launch'
						AND service_property_name = 'min_cpu') AS r_cores,
			MIN(value) FILTER (WHERE service_property_type = 'launch'
						AND service_property_name = 'min_memory') AS r_memory_mb,
			MIN(value) FILTER (WHERE service_property_type = 'launch'
						AND service_property_name = 'min_disk') AS r_disk_gb,
			MIN(value) FILTER (WHERE service_property_type = 'launch'
						AND service_property_name = 'dedicated') AS r_dedicated,
			MIN(value) FILTER (WHERE service_property_type = 'docs'
						AND service_property_name = 'manual') AS documentation
		FROM service_property
		WHERE service_property_type IN ('docs', 'launch')
		GROUP BY service_collection_id
	) sp USING (service_collection_id)
	LEFT JOIN (
		SELECT service_id,
			MIN(source_repository_url) FILTER (
				WHERE source_repository_type = 'software') as software,
			MIN(source_repository_url) FILTER (
				WHERE source_repository_type = 'config') as config
		FROM source_repository
			JOIN service_source_repository USING (source_repository_id)
		WHERE source_repository_type IN ('software', 'config')
		GROUP BY service_id
	) src USING (service_id)
;

SAVEPOINT foo;

SELECT schema_support.relation_diff (
	schema := 'maestro',
	old_rel := 'application_old',
	new_rel := 'application',
	prikeys := ARRAY['id']
);

SELECT schema_support.replay_saved_grants();

--- XXX need to remove foreign keys
