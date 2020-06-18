WITH v AS (
	INSERT INTO vault_policy (
		vault_policy_name
	) VALUES (
		'tang-a-production-consumer'
	) RETURNING *
), first AS (
	INSERT INTO vault_policy_path (
		vault_policy_id, capabilities, vault_policy_path
	) SELECT vault_policy_id, array['read'],
		'global/kv/data/services/tang/environments/production/a/*'
	FROM v
	RETURNING *
), second AS (
	INSERT INTO vault_policy_path (
		vault_policy_id, capabilities, vault_policy_path
	) SELECT vault_policy_id, ARRAY['list'],
		'global/kv/metadata/services/tang/environments/production/a/*'
	FROM v
	RETURNING *
) SELECT * FROM first UNION SELECT * FROM second;

WITH v AS (
	INSERT INTO vault_policy (
		vault_policy_name
	) VALUES (
		'drivescale-development-admin-consumer'
	) RETURNING *
), first AS (
	INSERT INTO vault_policy_path (
		vault_policy_id, capabilities, vault_policy_path
	) SELECT vault_policy_id, ARRAY['read'],
		'global/kv/data/services/drivescale/environments/development/admin/*'
	FROM v
	RETURNING *
), second AS (
	INSERT INTO vault_policy_path (
		vault_policy_id, capabilities, vault_policy_path
	) SELECT vault_policy_id, ARRAY['list'],
		'global/kv/metadata/services/drivescale/environments/development/admin/*'
	FROM v
	RETURNING *
) SELECT * FROM first UNION SELECT * FROM second;


--- === === === ===

\set ECHO queries

SELECT * FROM vault_policy ORDER BY 1;
SELECT * FROM vault_policy_path ORDER BY 1;

SELECT * FROM vault_policy_mclass;

-- XXX need to incrporate user and group for mclass

\set ECHO none
