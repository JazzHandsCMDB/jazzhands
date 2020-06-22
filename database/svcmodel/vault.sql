\set ON_ERROR_STOP

-- XXX - need to deal with service integration
-- XXX - need to deal with authorization_policy NULLability/required.

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
	coalesce(account_collection_name, 'root') as unix_group
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
WHERE authorization_policy_collection_type IN ('vault-policy')
AND property_name = 'application-kubernetes-map'
AND property_type = 'authorization-mappings'
;

--- === === === === === === === === === === === === === === === === === === ===
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

------------------

CREATE OR REPLACE FUNCTION vault_policy_upd()
RETURNS TRIGGER AS $$
DECLARE
	apc	authorization_policy_collection%ROWTYPE;
BEGIN

	IF OLD.secret_ttl IS DISTINCT FROM NEW.secret_ttl THEN
		RAISE EXCEPTION 'secret_ttl is not updatable.';
	END IF;

	IF OLD.token_ttl IS DISTINCT FROM NEW.token_ttl THEN
		RAISE EXCEPTION 'token_ttl is not updatable.';
	END IF;

	IF OLD.token_max_ttl IS DISTINCT FROM NEW.token_max_ttl THEN
		RAISE EXCEPTION 'token_max_ttl is not updatable.';
	END IF;

	IF OLD.secret_max_uses IS DISTINCT FROM NEW.secret_max_uses THEN
		RAISE EXCEPTION 'secret_max_uses is not updatable.';
	END IF;

	IF OLD.token_max_uses IS DISTINCT FROM NEW.token_max_uses THEN
		RAISE EXCEPTION 'token_max_uses is not updatable.';
	END IF;

	IF OLD.approle_disabled IS DISTINCT FROM NEW.approle_disabled THEN
		RAISE EXCEPTION 'approle_disabled is not updatable.';
	END IF;

	IF OLD.vault_policy_id IS DISTINCT FROM NEW.vault_policy_id THEN
		RAISE EXCEPTION 'vault_policy_id is not updatable.';
	END IF;

	IF OLD.vault_policy_name IS DISTINCT FROM NEW.vault_policy_name THEN
		UPDATE authorization_policy_collection
		SET authorization_policy_collection_name = NEW.vault_policy_name
		WHERE authorization_policy_id = NEW.vault_policy_id;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=authorization_policy,vault_policy
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_vault_policy_upd
        ON vault_policy;
CREATE TRIGGER trigger_vault_policy_upd
        INSTEAD OF UPDATE
        ON vault_policy
        FOR EACH ROW
        EXECUTE PROCEDURE vault_policy_upd();

------------------

CREATE OR REPLACE FUNCTION vault_policy_del()
RETURNS TRIGGER AS $$
DECLARE
	apc	authorization_policy_collection%ROWTYPE;
BEGIN
	DELETE FROM authorization_policy_collection_policy
	WHERE authorization_policy_collection_id = OLD.vault_policy_id;

	DELETE FROM authorization_policy_collection
	WHERE authorization_policy_collection_id = OLD.vault_policy_id;

	RETURN OLD;
END;
$$
SET search_path=authorization_policy,vault_policy
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_vault_policy_del
        ON vault_policy;
CREATE TRIGGER trigger_vault_policy_del
        INSTEAD OF DELETE
        ON vault_policy
        FOR EACH ROW
        EXECUTE PROCEDURE vault_policy_del();


--- === === === === === === === === === === === === === === === === === === ===
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

	IF NEW.vault_policy_id IS NOT NULL AND NEW.vault_policy_name IS NOT NULL THEN
		RAISE EXCEPTION 'May not set both vault_policy_id and vault_policy_name';
	ELSIF NEW.vault_policy_id IS NOT NULL THEN
		SELECT authorization_policy_collection_id, authorization_policy_collection_name
		INTO  NEW.vault_policy_id, NEW.vault_policy_name
		FROM authorization_policy_collection
		WHERE authorization_policy_collection_id = NEW.vault_policy_id;
	ELSIF NEW.vault_policy_name IS NOT NULL THEN
		SELECT authorization_policy_collection_id, authorization_policy_collection_name
		INTO  NEW.vault_policy_id, NEW.vault_policy_name
		FROM authorization_policy_collection
		WHERE authorization_policy_collection_name = NEW.vault_policy_name;
	ELSE
		RAISE EXCEPTION 'Must set vault_policy_id or vault_policy_name';
	END IF;
	

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
SET search_path=authorization_policy
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_vault_policy_path_ins
        ON vault_policy_path;
CREATE TRIGGER trigger_vault_policy_path_ins
        INSTEAD OF INSERT
        ON vault_policy_path
        FOR EACH ROW
        EXECUTE PROCEDURE vault_policy_path_ins();

--------------------------------------

CREATE OR REPLACE FUNCTION vault_policy_path_upd()
RETURNS TRIGGER AS $$
DECLARE
	ap	authorization_policy%ROWTYPE;
	policy_type TEXT;
	perm TEXT;
BEGIN
	IF NEW.vault_policy_path_id IS DISTINCT FROM OLD.vault_policy_path_id THEN
		RAISE EXCEPTION 'Can not update vault_policy_path_id';
	END IF;
	IF NEW.vault_policy_name IS DISTINCT FROM OLD.vault_policy_name THEN
		RAISE EXCEPTION 'Can not update vault_policy_name';
	END IF;

	IF OLD.vault_policy_path IS DISTINCT FROM NEW.vault_policy_path THEN
		UPDATE authorization_policy
		SET authorization_policy_scope = NEW.vault_policy_path
		WHERE authorization_policy_scope = OLD.vault_policy_path
		AND authorization_policy_id = OLD.vault_policy_path_id;
	END IF;

	--
	-- fix capabilities
	--
	FOR perm IN SELECT unnest(NEW.capabilities)
	LOOP
		IF array_position(OLD.capabilities, perm) IS NULL THEN
			RAISE NOTICE 'removing %', perm;
		END IF;
	END LOOP;

	FOR perm IN SELECT unnest(OLD.capabilities)
	LOOP
		IF array_position(NEW.capabilities, perm) IS NULL THEN
			RAISE NOTICE 'adding %', perm;
		END IF;
	END LOOP;

	RETURN NEW;
END;
$$
SET search_path=authorization_policy,jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_vault_policy_path_upd
        ON vault_policy_path;
CREATE TRIGGER trigger_vault_policy_path_upd
        INSTEAD OF UPDATE
        ON vault_policy_path
        FOR EACH ROW
        EXECUTE PROCEDURE vault_policy_path_upd();


--------------------------------------

CREATE OR REPLACE FUNCTION vault_policy_path_del()
RETURNS TRIGGER AS $$
DECLARE
	ap	authorization_policy%ROWTYPE;
	policy_type TEXT;
BEGIN
	DELETE FROM authorization_policy_collection_authorization_policy
	WHERE authorization_policy_collection_id = OLD.vault_policy_id
	AND authorization_policy_id = OLD.vault_policy_path_id;

	DELETE FROM authorization_policy_permission
	WHERE authorization_policy_id = OLD.vault_policy_path_id;

	DELETE FROM authorization_policy
	WHERE authorization_policy_id = OLD.vault_policy_path_id;

	RETURN OLD;
END;
$$
SET search_path=authorization_policy,jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_vault_policy_path_del
        ON vault_policy_path;
CREATE TRIGGER trigger_vault_policy_path_del
        INSTEAD OF DELETE
        ON vault_policy_path
        FOR EACH ROW
        EXECUTE PROCEDURE vault_policy_path_del();

--- === === === === === === === === === === === === === === === === === === ===
CREATE OR REPLACE FUNCTION vault_policy_mclass_ins()
RETURNS TRIGGER AS $$
DECLARE
	azp	authorization_property%ROWTYPE;
BEGIN
	SELECT	device_collection_id
	INTO	azp.device_collection_Id
	FROM	jazzhands.device_collection
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
		AND		a.login = NEW.login;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'bad account';
		END IF;
	ELSE
		NEW.login = 'root';
	END IF;

	IF NEW.unix_group IS NOT NULL THEN
		SELECT	account_collection_Id
		INTO	azp.unix_group_account_collection_id
		FROM	jazzhands.account_collection a
		WHERE	account_collection_type = 'unix-group'
		AND		account_collection_name = NEW.unix_group;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'bad account';
		END IF;
	ELSE
		NEW.unix_group = 'root';
	END IF;

	IF ( NEW.vault_policy_id IS NOT NULL AND
		NEW.vault_policy_name IS NOT NULL )
	THEN
		RAISE EXCEPTION 'Only set vault_policy_id or vault_policy_name';
	ELSIF NEW.vault_policy_name IS NOT NULL THEN
		SELECT authorization_policy_collection_id
		INTO NEW.vault_policy_id
		FROM authorization_policy_collection
		WHERE authorization_policy_collection_name = NEW.vault_policy_name
		AND authorization_policy_collection_type = 'vault-policy';
	ELSIF NEW.vault_policy_id IS NOT NULL THEN
		SELECT authorization_policy_collection_name
		INTO NEW.vault_policy_name
		FROM authorization_policy_collection
		WHERE authorization_policy_collection_id = NEW.vault_policy_id;
	END IF;

	azp.authorization_policy_collection_id = NEW.vault_policy_id;
	INSERT INTO authorization_property (
		device_collection_id,
		authorization_policy_collection_id,
		property_type,
		property_name,
		account_id,
		unix_group_account_collection_id
	) VALUES (
		azp.device_collection_id,
		azp.authorization_policy_collection_id,
		azp.property_type,
		azp.property_name,
		azp.account_id,
		azp.unix_group_account_collection_id
	);

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

----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION vault_policy_mclass_upd()
RETURNS TRIGGER AS $$
DECLARE
	azp	authorization_property%ROWTYPE;
	upd_query	TEXT[];
	old_device_collection_id	INTEGER;
BEGIN
	SELECT	device_collection_id
	INTO	old_device_collection_id
	FROM	jazzhands.device_collection
	WHERE	device_collection_type = 'mclass'
	AND		device_collection_name IS NOT DISTINCT FROM OLD.mclass;

	IF OLD.mclass IS DISTINCT FROM NEW.mclass THEN
		SELECT	device_collection_id
		INTO	azp.device_collection_Id
		FROM	jazzhands.device_collection
		WHERE	device_collection_type = 'mclass'
		AND		device_collection_name IS NOT DISTINCT FROM NEW.mclass;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'bad mclass';
		END IF;

		upd_query := array_append(upd_query,
			'device_collection_id  = ' ||
			quote_nullable(azp.device_collection_id));
	END IF;

	IF OLD.login IS DISTINCT FROM NEW.login THEN
		IF NEW.login IS NULL OR NEW.login = 'root' THEN
			upd_query := array_append(upd_query,
				'account_id  = NULL');
		ELSE
			SELECT	account_id, login
			INTO	azp.account_id, NEW.login
			FROM	jazzhands.account a
			WHERE	account_realm_id = 1
			AND		a.login = NEW.login;
			IF NOT FOUND THEN
				RAISE EXCEPTION 'bad account';
			END IF;
			upd_query := array_append(upd_query,
				'account_id  = ' ||
				quote_nullable(azp.account_id));
		END IF;
	END IF;

	IF OLD.unix_group IS DISTINCT FROM NEW.unix_group THEN
		IF NEW.unix_group IS NULL OR NEW.unix_group = 'root' THEN
			upd_query := array_append(upd_query,
				'unix_group_account_collection_id  = NULL');
		ELSE
			SELECT	account_collection_Id
			INTO	azp.unix_group_account_collection_id
			FROM	jazzhands.account_collection a
			WHERE	account_collection_type = 'unix-group'
			AND		account_collection_name = NEW.unix_group;
			IF NOT FOUND THEN
				RAISE EXCEPTION 'bad account';
			END IF;
			upd_query := array_append(upd_query,
				'unix_group_account_collection_id  = ' ||
				quote_nullable(azp.unix_group_account_collection_id));
		END IF;
	END IF;

	azp.property_name = 'mclass-authorization-map';
	azp.property_type = 'authorization-mappings';

	IF ( OLD.vault_policy_id IS DISTINCT FROM NEW.vault_policy_id  ) OR
		( OLD.vault_policy_name IS DISTINCT FROM NEW.vault_policy_name )
	THEN
		IF ( OLD.vault_policy_id IS DISTINCT FROM NEW.vault_policy_id ) AND
			( OLD.vault_policy_name IS DISTINCT FROM NEW.vault_policy_name )
		THEN
			RAISE EXCEPTION 'Only change vault_policy_id or vault_policy_name';
		ELSIF OLD.vault_policy_name IS DISTINCT FROM NEW.vault_policy_name THEN
			SELECT authorization_policy_collection_id
			INTO NEW.vault_policy_id
			FROM authorization_policy_collection
			WHERE authorization_policy_collection_name = NEW.vault_policy_name
			AND authorization_policy_collection_type = 'vault-policy';
		ELSIF OLD.vault_policy_id IS DISTINCT FROM NEW.vault_policy_id THEN
			SELECT authorization_policy_collection_name
			INTO NEW.vault_policy_name
			FROM authorization_policy_collection
			WHERE authorization_policy_collection_id = NEW.vault_policy_id;
		END IF;
		azp.authorization_policy_collection_id = NEW.vault_policy_id;
		upd_query := array_append(upd_query,
			'authorization_policy_collection_id  = ' ||
			quote_nullable(azp.authorization_policy_collection_id));
	END IF;

	IF upd_query IS NOT NULL THEN
		EXECUTE 'UPDATE authorization_property SET ' ||
			array_to_string(upd_query, ', ') ||
			' WHERE property_name = ''mclass-authorization-map'' ' ||
			' AND property_type = ''authorization-mappings'' '||
			' AND device_collection_id = $1 ' ||
			' AND authorization_policy_collection_id = $2'
		USING old_device_collection_id, OLD.vault_policy_id;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=authorization_policy,jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_vault_policy_mclass_upd
        ON vault_policy_mclass;
CREATE TRIGGER trigger_vault_policy_mclass_upd
        INSTEAD OF UPDATE
        ON vault_policy_mclass
        FOR EACH ROW
        EXECUTE PROCEDURE vault_policy_mclass_upd();


-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION vault_policy_mclass_del()
RETURNS TRIGGER AS $$
DECLARE
	azp	authorization_property%ROWTYPE;
BEGIN
	--
	-- note, there is a unique constraint on
	-- (authorization_policy_id, device_collection_id) that this assumes
	-- is there.
	--
	DELETE FROM authorization_property
	WHERE property_type = 'authorization-mappings'
	AND property_name = 'mclass-authorization-map'
	AND authorization_policy_collection_id = OLD.vault_policy_id
	AND device_collection_id = (
		SElECT device_collection_id
		FROM jazzhands.device_collection
		WHERE	device_collection_type = 'mclass'
		AND	device_collection_name = OLD.mclass
	);

	RETURN OLD;
END;
$$
SET search_path=authorization_policy,jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_vault_policy_mclass_del
        ON vault_policy_mclass;
CREATE TRIGGER trigger_vault_policy_mclass_del
        INSTEAD OF DELETE
        ON vault_policy_mclass
        FOR EACH ROW
        EXECUTE PROCEDURE vault_policy_mclass_del();


--- === === === === === === === === === === === === === === === === === === ===
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
		kubernetes_service_account,
		authorization_policy_collection_id
	) VALUES (
	    'application-kubernetes-map',
	    'authorization-mappings',
		NEW.kubernetes_cluster,
		NEW.kubernetes_namespace,
		NEW.kubernetes_service_account,
		NEW.vault_policy_id
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

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION vault_policy_kubernetes_upd()
RETURNS TRIGGER AS $$
DECLARE
	_upd_query	TEXT[];
BEGIN
	IF OLD.kubernetes_cluster IS DISTINCT FROM NEW.kubernetes_cluster THEN
		_upd_query := array_append(_upd_query,
			'kubernetes_cluster = ' ||
			quote_nullable(NEW.kubernetes_cluster));
	END IF;

	IF OLD.kubernetes_namespace IS DISTINCT FROM NEW.kubernetes_namespace THEN
		_upd_query := array_append(_upd_query,
			'kubernetes_namespace = ' ||
			quote_nullable(NEW.kubernetes_namespace));
	END IF;

	IF OLD.kubernetes_service_account IS DISTINCT FROM NEW.kubernetes_service_account THEN
		_upd_query := array_append(_upd_query,
			'kubernetes_service_account = ' ||
			quote_nullable(NEW.kubernetes_service_account));
	END IF;

	IF _upd_query IS NOT NULL THEN
		EXECUTE 'UPDATE authorization_property SET ' ||
                array_to_string(_upd_query, ', ') ||
				' WHERE kubernetes_cluster = $1 AND ' ||
				' kubernetes_namespace = $2 AND ' ||
				' kubernetes_service_account = $3'
				USING OLD.kubernetes_cluster,
					OLD.kubernetes_namespace,
					OLD.kubernetes_service_account
		;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=authorization_policy,jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_vault_policy_kubernetes_upd
        ON vault_policy_kubernetes;
CREATE TRIGGER trigger_vault_policy_kubernetes_upd
        INSTEAD OF UPDATE
        ON vault_policy_kubernetes
        FOR EACH ROW
        EXECUTE PROCEDURE vault_policy_kubernetes_upd();



-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION vault_policy_kubernetes_del()
RETURNS TRIGGER AS $$
BEGIN
	DELETE FROM authorization_property
		WHERE property_name = 'application-kubernetes-map'
		AND property_type = 'authorization-mappings'
		AND kubernetes_cluster = OLD.kubernetes_cluster
		AND kubernetes_namespace = OLD.kubernetes_namespace
		AND kubernetes_service_account= OLD.kubernetes_service_account
	;

	RETURN OLD;
END;
$$
SET search_path=authorization_policy,jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_vault_policy_kubernetes_del
        ON vault_policy_kubernetes;
CREATE TRIGGER trigger_vault_policy_kubernetes_del
        INSTEAD OF DELETE
        ON vault_policy_kubernetes
        FOR EACH ROW
        EXECUTE PROCEDURE vault_policy_kubernetes_del();


--- === === === === === === === === === === === === === === === === === === ===
