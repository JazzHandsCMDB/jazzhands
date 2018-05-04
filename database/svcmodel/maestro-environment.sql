
\set ON_ERROR_STOP

SET constraints all deferred;

UPDATE jazzhands.service_environment set
	service_environment_name = 'prod'
WHERE
	service_environment_name = 'production';
UPDATE jazzhands.service_environment set
	service_environment_name = 'dev'
WHERE
	service_environment_name = 'development';
UPDATE jazzhands.service_environment set
	service_environment_name = 'stage'
WHERE
	service_environment_name = 'staging';

WITH map AS (
	SELECT	e.*,
		se.*
	FROM	maestro.environment e
		left join jazzhands.service_environment se
			ON se.service_environment_name = e.name
), nose AS (
	UPDATE jazzhands.service_environment set
		service_environment_id = service_environment_id + 10
	WHERE service_environment_id NOT IN (
		SELECT service_environment_id FROM map
		WHERE service_environment_id IS NOT NULL
	) RETURNING *
), nodev AS (
	UPDATE jazzhands.device set
		service_environment_id = service_environment_id + 10
	WHERE service_environment_id NOT IN (
		SELECT service_environment_id FROM map
		WHERE service_environment_id IS NOT NULL
	) RETURNING *
), nocol AS (
	UPDATE jazzhands.svc_environment_coll_svc_env set
		service_environment_id = service_environment_id + 10
	WHERE service_environment_id NOT IN (
		SELECT service_environment_id FROM map
		WHERE service_environment_id IS NOT NULL
	) RETURNING *
) SELECT count(*) FROM nose
;

WITH map AS (
	SELECT	e.*,
		se.*
	FROM	maestro.environment e
		INNER join jazzhands.service_environment se
			ON se.service_environment_name = e.name
), nose AS (
	UPDATE jazzhands.service_environment se set
		service_environment_id = m.id
	FROM map m
	WHERE m.service_environment_id = se.service_environment_id
	RETURNING *
), nodev AS (
	UPDATE jazzhands.device d set
		service_environment_id = m.id
	FROM map m
	WHERE m.service_environment_id = d.service_environment_id
	RETURNING *
), nocol AS (
	UPDATE jazzhands.svc_environment_coll_svc_env sc set
		service_environment_id = m.id
	FROM map m
	WHERE m.service_environment_id = sc.service_environment_id
	RETURNING *
) SELECT count(*) FROM nose
;

WITH map AS (
	SELECT	e.*,
		se.*
	FROM	maestro.environment e
		LEFT join jazzhands.service_environment se
			ON se.service_environment_name = e.name
	WHERE	service_environment_id IS NULL
) INSERT INTO jazzhands.service_environment (
		service_environment_Id, service_environment_name,
		production_state)
	SELECT id, name, CASE
		WHEN name = 'mgmt' THEN 'production'
		WHEN name = 'user' THEN 'development'
		ELSE 'test'
	END as production_state
	FROM map
;


SET constraints all immediate;

DO $$
BEGIN
	INSERT INTO jazzhands.val_service_env_coll_type (
		service_env_collection_type, description
	) VALUES (
		'maestro', 'groupings of environments for use with maestro'
	);
EXCEPTION WHEN unique_violation THEN
	NULL;
END
$$;

WITH se AS (
	INSERT INTO jazzhands.service_environment_collection (
		service_env_collection_name, service_env_collection_type,
		description
	) VALUES (
		'visible', 'maestro',
		'visible inside maestro'
	) RETURNING *
) INSERT INTO jazzhands.svc_environment_coll_svc_env (
	service_env_collection_id, service_environment_id
) SELECT service_env_collection_id, id
FROM se, environment;

SELECT schema_support.save_grants_for_replay(
	schema := 'maestro',
	object := 'environment'
);

ALTER TABLE maestro.environment RENAME TO environment_old;
SAVEPOINT preview;

CREATE OR REPLACE VIEW environment AS
SELECT service_environment_id AS id,
	service_environment_name AS name
FROM jazzhands.service_environment
	JOIN jazzhands.svc_environment_coll_svc_env
		USING (service_environment_id)
	JOIN jazzhands.service_environment_collection
		USING (service_env_collection_id)
WHERE service_env_collection_name = 'visible'
AND service_env_collection_type = 'maestro'
;

SAVEPOINT precheck;
SELECT schema_support.relation_diff (
        schema := 'maestro',
        old_rel := 'environment_old',
        new_rel := 'environment',
        prikeys := ARRAY['id']
);

SELECT schema_support.replay_saved_grants();

-- XXX - need to move foreign keys
