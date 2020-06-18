\set ON_ERROR_STOP

-- XXX - need to deal with service, device collection integration

CREATE OR REPLACE VIEW vault_policy AS
SELECT
	vault_policy_id,
	vault_policy_name,
	coalesce(secret_ttl::int, 86400)		AS secret_ttl,
	coalesce(token_ttl::int, 86400)		AS token_ttl,
	coalesce(token_max_ttl::int, 86400)		AS token_max_ttl,
	secret_max_uses::int,
	token_max_uses::int,
	approle_disabled::boolean
FROM (
SELECT
	authorization_policy_collection_id as vault_policy_id,
	authorization_policy_collection_name as vault_policy_name,
	min(policy_definition->>'secret_ttl')
		FILTER (WHERE policy_type = 'vault-ttls') AS secret_ttl,
	min(policy_definition->>'token_ttl')
		FILTER (WHERE policy_type = 'vault-ttls') AS token_ttl,
	min(policy_definition->>'token_max_ttl')
		FILTER (WHERE policy_type = 'vault-ttls') AS token_max_ttl,
	min(policy_definition->>'secret_max_uses')
		FILTER (WHERE policy_type = 'vault-uses') AS secret_max_uses,
	min(policy_definition->>'token_max_uses')
		FILTER (WHERE policy_type = 'vault-uses') AS token_max_uses,
	coalesce(
		bool_or( (policy_definition->>'disabled')::boolean )
		FILTER (WHERE policy_type = 'disabled-approle')
	, false) AS approle_disabled
FROM	authorization_policy.authorization_policy_collection
	LEFT JOIN (
		SELECT authorization_policy_collection_id, p.*
		FROM authorization_policy.authorization_policy_collection_policy
			JOIN authorization_policy.policy p USING (policy_id)
	) pols USING (authorization_policy_collection_id)
WHERE authorization_policy_collection_type = 'vault-policy'
GROUP BY authorization_policy_collection_id,
	authorization_policy_collection_name
) inside
;

CREATE OR REPLACE VIEW vault_policy_path AS
SELECT
	authorization_policy_id	AS vault_policy_path_id,
	authorization_policy_collection_id AS vault_policy_id,
	authorization_policy_collection_name AS vault_policy_name,
	authorization_policy_scope AS vault_policy_path,
	array_agg(permission ORDER BY permission) as capabilities
FROM authorization_policy.authorization_policy
	JOIN authorization_policy.authorization_policy_collection_authorization_policy
		USING (authorization_policy_id)
	JOIN authorization_policy.authorization_policy_permission
		USING (authorization_policy_id)
	JOIN authorization_policy.authorization_policy_collection
		USING (authorization_policy_collection_id)
WHERE authorization_policy_type IN ('vault-policy-path','vault-metadata-path')
AND authorization_policy_collection_type = 'vault-policy'
GROUP BY authorization_policy_id,
	authorization_policy_collection_id,
	authorization_policy_collection_name,
	authorization_policy_scope
;

CREATE OR REPLACE VIEW vault_policy_mclass AS
SELECT authorization_policy_collection_id AS vault_policy_id,
	authorization_policy_collection_name AS vault_policy_name,
	device_collection_name AS mclass,
	coalesce(login, 'root') AS login,
	coalesce(account_collection_name, 'root') as group
FROM authorization_policy.authorization_policy_collection ac
JOIN authorization_policy.authorization_property azp
	USING (authorization_policy_collection_id)
JOIN jazzhands.device_collection USING (device_collection_id)
LEFT JOIN jazzhands.account USING (account_id)
LEFT JOIN jazzhands.account_collection u
	ON u.account_collection_id = azp.unix_group_account_collection_id
WHERE authorization_policy_collection_type IN ('vault-policy')
AND property_name = 'mclass-authorization-map'
AND property_type = 'authorization-mappings'
;

CREATE OR REPLACE VIEW vault_policy_kubernetes AS
SELECT authorization_policy_collection_id AS vault_policy_id,
	authorization_policy_collection_name AS vault_policy_name,
	kubernetes_cluster,
	kubernetes_namespace,
	kubernetes_service_account
FROM authorization_policy.authorization_policy_collection ac
JOIN authorization_policy.authorization_property azp
	USING (authorization_policy_collection_id)
JOIN jazzhands.device_collection USING (device_collection_id)
WHERE authorization_policy_collection_type IN ('vault-policy')
AND property_name = 'application-kubernetes-map'
AND property_type = 'authorization-mappings'
;

--- === === === ===
CREATE OR REPLACE FUNCTION vault_policy_ins()
RETURNS TRIGGER AS $$
DECLARE
	apc	authorization_policy_collection%ROWTYPE;
BEGIN

	IF NEW.vault_policy_id IS NOT NULL THEN
		INSERT INTO authorization_policy_collection (
			authorization_policy_collection_id,
			authorization_policy_collection_name,
			authorization_policy_collection_type
		) VALUES (
			NEW.vault_policy_id,
			NEW.vault_policy_name,
			'vault-policy'
		) RETURNING * INTO apc;

	ELSE
		INSERT INTO authorization_policy_collection (
			authorization_policy_collection_name,
			authorization_policy_collection_type
		) VALUES (
			NEW.vault_policy_name,
			'vault-policy'
		) RETURNING * INTO apc;
	END IF;

	NEW.vault_policy_id = apc.authorization_policy_collection_id;
	NEW.vault_policy_name = apc.authorization_policy_collection_name;

	INSERT INTO authorization_policy_collection_policy (
		authorization_policy_collection_id, policy_id
	) SELECT NEW.vault_policy_id, policy_id
	FROM policy
	WHERE (
    	policy_name = 'initial-vault-ttl-default' AND policy_type = 'vault-ttls'
	OR   policy_name = 'unlimited-uses' AND policy_type = 'vault-uses'
	OR   policy_name = 'vault-disabled-approles' AND policy_type = 'disabled-approle'
	);

	SELECT * INTO NEW FROM vault_policy
	WHERE vault_policy_id = NEW.vault_policy_id;

	RETURN NEW;
END;
$$
SET search_path=authorization_policy,vault_policy
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_vault_policy_ins
        ON vault_policy;
CREATE TRIGGER trigger_vault_policy_ins
        INSTEAD OF INSERT
        ON vault_policy
        FOR EACH ROW
        EXECUTE PROCEDURE vault_policy_ins();

--- === === === ===
CREATE OR REPLACE FUNCTION vault_policy_path_ins()
RETURNS TRIGGER AS $$
DECLARE
	ap	authorization_policy%ROWTYPE;
	policy_type TEXT;
BEGIN
	IF NEW.vault_policy_path ~ '/metadata/' THEN
		policy_type := 'vault-metadata-path';
	ELSE
		policy_type := 'vault-policy-path';
	END IF;
	IF NEW.vault_policy_path_id IS NULL THEN
		INSERT INTO authorization_policy (
			authorization_policy_name, authorization_policy_type,
			authorization_policy_scope
		) VALUES (
			pgcrypto.gen_random_uuid(), policy_type,
			NEW.vault_policy_path
		) RETURNING * INTO ap;
	ELSE
		INSERT INTO authorization_policy (
			authorization_policy_id,
			authorization_policy_name, authorization_policy_type,
			authorization_policy_scope
		) VALUES (
			NEW.vault_policy_path_id,
			pgcrypto.gen_random_uuid(), policy_type,
			NEW.vault_policy_path
		) RETURNING * INTO ap;
	END IF;
	NEW.vault_policy_path_id = ap.authorization_policy_id;

	INSERT INTO authorization_policy_permission (
		authorization_policy_id, permission
	) VALUES (
		ap.authorization_policy_id, unnest(NEW.capabilities)
	);

	INSERT INTO authorization_policy_collection_authorization_policy (
		authorization_policy_collection_id, authorization_policy_id
	) VALUES (
		NEW.vault_policy_id, NEW.vault_policy_path_id
	);

	RETURN NEW;
END;
$$
SET search_path=authorization_policy,jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_vault_policy_path_ins
        ON vault_policy_path;
CREATE TRIGGER trigger_vault_policy_path_ins
        INSTEAD OF INSERT
        ON vault_policy_path
        FOR EACH ROW
        EXECUTE PROCEDURE vault_policy_path_ins();

--- === === === ===
CREATE OR REPLACE FUNCTION vault_policy_mclass_ins()
RETURNS TRIGGER AS $$
DECLARE
	azp	authorization_property%ROWTYPE;
BEGIN
	SELECT	device_collectio_id
	INTO	azp.device_collection_Id
	FROM	jazzhands.device_collection_id
	WHERE	device_collection_type = 'mclass'
	AND		device_collection_name IS NOT DISTINCT FROM NEW.mclass;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'bad mclass';
	END IF;

	azp.property_name = 'mclass-authorization-map';
	azp.property_type = 'authorization-mappings';

	IF NEW.login IS NOT NULL THEN
		SELECT	account_id, login
		INTO	azp.account_id, NEW.login
		FROM	jazzhands.account a
		WHERE	account_realm_id = 1
		AND		a.login = HEW.login;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'bad account';
		END IF;
	END IF;

	IF NEW.group IS NOT NULL THEN
		SELECT	account_collection_Id
		INTO	azp.unix_group_account_collection_id
		FROM	jazzhands.account_collection a
		WHERE	account_collection_type = 'unix-group'
		AND		account_collection_name = NEW.group;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'bad account';
		END IF;
	END IF;

	azp.authorization_policy_collection_id = NEW.vault_policy_id;

	INSERT INTO authorization_property VALUES (azp);
	RETURN NEW;
END;
$$
SET search_path=authorization_policy,jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_vault_policy_mclass_ins
        ON vault_policy_mclass;
CREATE TRIGGER trigger_vault_policy_mclass_ins
        INSTEAD OF INSERT
        ON vault_policy_mclass
        FOR EACH ROW
        EXECUTE PROCEDURE vault_policy_mclass_ins();

--- === === === ===
CREATE OR REPLACE FUNCTION vault_policy_kubernetes_ins()
RETURNS TRIGGER AS $$
DECLARE
	azp	authorization_property%ROWTYPE;
BEGIN
	INSERT INTO authorization_property (
		property_name,
		property_type,
		kubernetes_cluster,
		kubernetes_namespace,
		kubernetes_service_account
	) VALUES (
	    'application-kubernetes-map',
	    'authorization-mappings',
		NEW.kubernetes_cluster,
		NEW.kubernetes_namespace,
		NEW.kubernetes_service_account
	) RETURNING * INTO azp;

	NEW.vault_policy_id = azp.authorization_policy_collection_id;
	NEW.kubernetes_cluster = azp.kubernetes_cluster;
	NEW.kubernetes_namespace = azp.kubernetes_namespace;
	NEW.kubernetes_service_account = azp.kubernetes_service_account;

	RETURN NEW;
END;
$$
SET search_path=authorization_policy,jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_vault_policy_kubernetes_ins
        ON vault_policy_kubernetes;
CREATE TRIGGER trigger_vault_policy_kubernetes_ins
        INSTEAD OF INSERT
        ON vault_policy_kubernetes
        FOR EACH ROW
        EXECUTE PROCEDURE vault_policy_kubernetes_ins();
