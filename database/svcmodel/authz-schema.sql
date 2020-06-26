\set ON_ERROR_STOP

/*
 * basically puts magic around jsob that describes policies.  The jsonb is
 * understood by the thing that process the policy which could be but is not
 * necessarily the databsae
 */
CREATE TABLE val_policy_type (
	policy_type	text NOT NULL,
	description	text,
	policy_schema	jsonb,
	PRIMARY KEY (policy_type)
);

/*
 * defines actual policies, schema enforced against type
 *
 * these can be applied to both authorization_policy and
 * authorization_policy_collections
 */
CREATE TABLE policy (
	policy_id		SERIAL NOT NULL,
	policy_name		text NOT NULL,
	policy_type		text NOT NULL,
	policy_definition	jsonb NOT NULL,
	description		text,
	PRIMARY KEY (policy_id),
	UNIQUE (policy_name, policy_type)
);

/*
 * typical
 *
 * unique_scope_per_type means that for this type, there should be a unique
 * constraint onfor things type in authorization_policy of the form:
 * UNIQUE (authorization_policy_type,authorization_policy_scope)
 *
 */
CREATE TABLE val_authorization_policy_type (
	authorization_policy_type	text NOT NULL,
	description					text,
	unique_scope_per_type		boolean DEFAULT false,
	PRIMARY KEY (authorization_policy_type)
);

/*
 * name of a policy that has permissions assocaited with it
 *
 * It is possible the type,scope unique constraint may need to be optional
 * based on type
 */
CREATE TABLE authorization_policy (
	authorization_policy_id		SERIAL,
	authorization_policy_name	TEXT NOT NULL,
	authorization_policy_type	TEXT NOT NULL,
	authorization_policy_scope	TEXT NOT NULL,
	description			TEXT,
	PRIMARY KEY (authorization_policy_id),
	UNIQUE (authorization_policy_name,authorization_policy_type)
);

/*
 * the various permissions that can be assoicated with the
 * policy by type  (read, write, update)
 */
CREATE TABLE authorization_policy_type_permitted_permission (
	authorization_policy_type	text NOT NULL,
	permission			text NOT NULL,
	description			text,
	PRIMARY KEY (authorization_policy_type, permission)
);

/*
 * relates various policies to the authorization policy.
 * This would be things like ttls, lifetimes, etc
 *
 * required means that there's they can't be removed and if a variable
 * is not set (which a stored procedure would do), it can't add a new one.
 *
 * having a row here means it's allowed
 */
CREATE TABLE authorization_type_policy_relation (
	authorization_policy_type	text NOT NULL,
	policy_id			integer,
	is_required			boolean,
	primary key (authorization_policy_type, policy_id)
);

/*
 * actual implementation of what's allowed above
 */
CREATE TABLE authorization_policy_relation (
	authorization_policy_id		INTEGER,
	policy_id			INTEGER,
	primary key (authorization_policy_id, policy_id)
);



/*
	TBD, probablyadded to properry
CREATE TABLE authorization_policy_property_type (
  - default
  - ttl and various properties go here - description

authorization_policy_property
  - id
  - ttl and various properties go here
*/

/*
 * which permissions the authorizaton policy speaks for
 * (read, write, update, etc)
 */
CREATE TABLE authorization_policy_permission (
	authorization_policy_id		INTEGER NOT NULL,
	permission			text NOT NULL,
	PRIMARY KEY (authorization_policy_id, permission)
);

/*
 * collections of authorization_policies
 *
 */
CREATE TABLE val_authorization_policy_collection_type (
	authorization_policy_collection_type	text NOT NULL,
	IS_INFRASTRUCTURE_TYPE 			boolean  NOT NULL DEFAULT false,
	MAX_NUM_MEMBERS      			INTEGER NULL,
	MAX_NUM_COLLECTIONS  			INTEGER NULL,
	CAN_HAVE_HIERARCHY   			boolean NOT NULL DEFAULT true,
	MAX_NUM_UNIQUE_SCOPES			INTEGER NULL,
	PRIMARY KEY (authorization_policy_collection_type)
);

CREATE TABLE authorization_policy_collection (
	authorization_policy_collection_id	SERIAL NOT NULL,
	authorization_policy_collection_name	text NOT NULL,
	authorization_policy_collection_type	text NOT NULL,
	description				text,
	PRIMARY KEY (authorization_policy_collection_id),
	UNIQUE (authorization_policy_collection_name,authorization_policy_collection_type)
);

CREATE TABLE authorization_policy_collection_policy (
	authorization_policy_collection_id	INTEGER,
	policy_id				INTEGER,
	primary key (authorization_policy_collection_id, policy_id)
);

CREATE TABLE authorization_policy_collection_authorization_policy (
	authorization_policy_collection_id	INTEGER NOT NULL,
	authorization_policy_id			INTEGER NOT NULL,
	PRIMARY KEY (authorization_policy_collection_id,authorization_policy_id)
);

CREATE TABLE authorization_policy_collection_hier (
	authorization_policy_collection_id		INTEGER NOT NULL,
	child_authorization_policy_collection_id	INTEGER NOT NULL,
	PRIMARY KEY (authorization_policy_collection_id,child_authorization_policy_collection_id)
);

/*
 * Will merge into property
 * application_id will become a collection
 *
 * NOTE - There are multiple RHS that need to be reconciled before this
 * gets merged into property.
 *
 */
CREATE TABLE authorization_property (
	authorization_property_id		SERIAL  NOT NULL,
	account_collection_id			INTEGER,
	device_collection_id			INTEGER,
	application_id				INTEGER,
	authorization_policy_collection_id	INTEGER NOT NULL,
	property_type				TEXT,
	property_name				TEXT,
	account_id				INTEGER,
	kubernetes_cluster			TEXT,
	kubernetes_namespace			TEXT,
	kubernetes_service_account		TEXT,
	unix_group_account_collection_id	INTEGER,
	primary key(authorization_property_id),
	unique (authorization_policy_collection_id, device_collection_id),
	unique (authorization_policy_collection_id, kubernetes_cluster,kubernetes_namespace,kubernetes_service_account)
);

--- fks
ALTER TABLE authorization_property
	ADD CONSTRAINT fk_authorization_property_property_name
	FOREIGN KEY (property_name, property_type)
	REFERENCES jazzhands.val_property(property_name, property_type)
	DEFERRABLE;

ALTER TABLE authorization_property
	ADD CONSTRAINT fk_authz_property_auth_p_collection
	FOREIGN KEY (authorization_policy_collection_id)
	REFERENCES authorization_policy_collection(authorization_policy_collection_id)
	DEFERRABLE;

ALTER TABLE authorization_property
	ADD CONSTRAINT fk_authz_prop_account_collection_id
	FOREIGN KEY (account_collection_id)
	REFERENCES jazzhands.account_collection(account_collection_id)
	DEFERRABLE;

ALTER TABLE authorization_property
	ADD CONSTRAINT fk_authz_prop_ug_account_collection_id
	FOREIGN KEY (unix_group_account_collection_id)
	REFERENCES jazzhands.unix_group(account_collection_id)
	DEFERRABLE;

ALTER TABLE authorization_property
	ADD CONSTRAINT fk_authz_prop_device_collection_id
	FOREIGN KEY (device_collection_id)
	REFERENCES jazzhands.device_collection(device_collection_id)
	DEFERRABLE;

ALTER TABLE authorization_property
	ADD CONSTRAINT fk_authz_prop_account_id
	FOREIGN KEY (account_id)
	REFERENCES jazzhands.account(account_id)
	DEFERRABLE;

ALTER TABLE authorization_property
	ADD CONSTRAINT fk_authz_property_application
	FOREIGN KEY (application_id)
	REFERENCES maestro.application(id)
	DEFERRABLE;

ALTER TABLE policy
	ADD CONSTRAINT fk_policy_policy_type
	FOREIGN KEY (policy_type)
	REFERENCES val_policy_type(policy_type)
	DEFERRABLE;

ALTER TABLE authorization_policy
	ADD CONSTRAINT fk_authorization_policy_authorization_policy_type
	FOREIGN KEY (authorization_policy_type)
	REFERENCES val_authorization_policy_type(authorization_policy_type)
	DEFERRABLE;

ALTER TABLE authorization_policy_type_permitted_permission
	ADD CONSTRAINT fk_aptype_permitted_perm
	FOREIGN KEY (authorization_policy_type)
	REFERENCES val_authorization_policy_type(authorization_policy_type)
	DEFERRABLE;

ALTER TABLE authorization_type_policy_relation
	ADD CONSTRAINT fk_authorization_type_policy_relation_ap_type
	FOREIGN KEY (authorization_policy_type)
	REFERENCES val_authorization_policy_type(authorization_policy_type)
	DEFERRABLE;

ALTER TABLE authorization_type_policy_relation
	ADD CONSTRAINT fk_authz_type_policy_relation_policy
	FOREIGN KEY (policy_id)
	REFERENCES policy(policy_id)
	DEFERRABLE;

ALTER TABLE authorization_policy_relation
	ADD CONSTRAINT fk_authorization_policy_relation_ap_type
	FOREIGN KEY (authorization_policy_id)
	REFERENCES authorization_policy(authorization_policy_id)
	DEFERRABLE;

ALTER TABLE authorization_policy_relation
	ADD CONSTRAINT fk_authz_policy_relation_policy
	FOREIGN KEY (policy_id)
	REFERENCES policy(policy_id)
	DEFERRABLE;

ALTER TABLE authorization_policy_permission
	ADD CONSTRAINT fk_authorization_policy_permission_authz_policy
	FOREIGN KEY (authorization_policy_id)
	REFERENCES authorization_policy(authorization_policy_id)
	DEFERRABLE;

ALTER TABLE authorization_policy_collection
	ADD CONSTRAINT fk_authorization_policy_collection_type
	FOREIGN KEY (authorization_policy_collection_type)
	REFERENCES val_authorization_policy_collection_type(authorization_policy_collection_type)
	DEFERRABLE;

ALTER TABLE authorization_policy_collection_policy
	ADD CONSTRAINT fk_authz_policy_collection_policy_authz_policy
	FOREIGN KEY (authorization_policy_collection_id)
	REFERENCES authorization_policy_collection(authorization_policy_collection_id)
	DEFERRABLE;

ALTER TABLE authorization_policy_collection_policy
	ADD CONSTRAINT fk_authorization_policy_collection_policy_policy
	FOREIGN KEY (policy_id)
	REFERENCES policy(policy_id)
	DEFERRABLE;

ALTER TABLE authorization_policy_collection_authorization_policy
	ADD CONSTRAINT fk_authz_pol_collection_authz_policy_coll
	FOREIGN KEY (authorization_policy_collection_id)
	REFERENCES authorization_policy_collection(authorization_policy_collection_id)
	DEFERRABLE;

ALTER TABLE authorization_policy_collection_authorization_policy
	ADD CONSTRAINT fk_authz_pol_collection_authz_policy
	FOREIGN KEY (authorization_policy_id)
	REFERENCES authorization_policy(authorization_policy_id)
	DEFERRABLE;

ALTER TABLE authorization_policy_collection_hier
	ADD CONSTRAINT fk_authorization_policy_collection_id_authz_policy
	FOREIGN KEY (authorization_policy_collection_id)
	REFERENCES authorization_policy_collection(authorization_policy_collection_id)
	DEFERRABLE;

ALTER TABLE authorization_policy_collection_hier
	ADD CONSTRAINT fk_authorization_policy_collection_id_child_authz_policy
	FOREIGN KEY (child_authorization_policy_collection_id)
	REFERENCES authorization_policy_collection(authorization_policy_collection_id)
	DEFERRABLE;

CREATE OR REPLACE VIEW maestro_application AS
SELECT	id as application_id,
	name as application_name
FROM	maestro.application;

CREATE OR REPLACE VIEW mclass AS
SELECT	device_collection_id,
	device_collection_name
FROM	jazzhands.device_collection
WHERE	device_collection_type = 'mclass';

-- === === === === === === === === === === == === === === === === === === ===

CREATE OR REPLACE FUNCTION authorization_policy_scope_unique()
RETURNS TRIGGER AS $$
DECLARE
	scope_uq	boolean;
	tally		integer;
BEGIN
	--
	-- only relevant if scope changes
	--
	IF TG_OP = 'UPDATE' AND
		OLD.authorization_policy_scope  = NEW.authorization_policy_scope
	THEN
		RETURN NEW;
	END IF;

	SELECT	unique_scope_per_type
	INTO	scope_uq
	FROM	val_authorization_policy_type
	WHERE	authorization_policy_type = NEW.authorization_policy_type;


	IF scope_uq THEN
		SELECT	count(*)
		INTO	tally
		FROM	authorization_policy ap
		WHERE	ap.authorization_policy_scope = NEW.authorization_policy_scope
		AND		ap.authorization_policy_type = NEW.authorization_policy_type
		AND		ap.authorization_policy_id != NEW.authorization_policy_id;

		IF tally > 0 THEN
			RAISE EXCEPTION
				'authorization_policy_scope % must be unique within % [%]',
				NEW.authorization_policy_scope,
				NEW.authorization_policy_type, tally
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;


	RETURN NEW;
END;
$$
SET search_path=authorization_policy,vault_policy
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_authorization_policy_scope_unique
	ON authorization_policy;
CREATE CONSTRAINT TRIGGER trigger_authorization_policy_scope_unique
	AFTER INSERT OR UPDATE
	ON authorization_policy
	DEFERRABLE INITIALLY IMMEDIATE
	FOR EACH ROW
	EXECUTE PROCEDURE authorization_policy_scope_unique();

------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION val_authorization_policy_type_scope_unique()
RETURNS TRIGGER AS $$
DECLARE
	tally		integer;
BEGIN
	--
	-- only relevant if scope changes
	--
	IF TG_OP = 'UPDATE' AND
		OLD.unique_scope_per_type  = NEW.unique_scope_per_type
	THEN
		RETURN NEW;
	END IF;

	IF NEW.unique_scope_per_type THEN
		PERFORM	authorization_policy_scope, count(*)
		FROM	authorization_policy ap
		WHERE	ap.authorization_policy_type = NEW.authorization_policy_type
		GROUP BY authorization_policy_scope
		HAVING count(*) > 1;

		IF FOUND THEN
			RAISE EXCEPTION
				'authorization_policy_scope must be unique within %',
				NEW.authorization_policy_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;


	RETURN NEW;
END;
$$
SET search_path=authorization_policy,vault_policy
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_authorization_policy_type_scope_unique
	ON val_authorization_policy_type;
CREATE CONSTRAINT TRIGGER trigger_val_authorization_policy_type_scope_unique
	AFTER INSERT OR UPDATE
	ON val_authorization_policy_type
	DEFERRABLE INITIALLY IMMEDIATE
	FOR EACH ROW
	EXECUTE PROCEDURE val_authorization_policy_type_scope_unique();

-- === === === === === === === === === === == === === === === === === === ===

CREATE OR REPLACE FUNCTION authz_policy_collection_scope_uniq()
RETURNS TRIGGER AS $$
DECLARE
	numscopes	INTEGER;
	_scope		TEXT;
	tally		INTEGER;
	typ			TEXT;
BEGIN
	SELECT	max_num_unique_scopes, authorization_policy_collection_type
	INTO	numscopes, typ
	FROM	val_authorization_policy_collection_type
			JOIN authorization_policy_collection
			USING (authorization_policy_collection_type)
	WHERE	authorization_policy_collection_id =
			NEW.authorization_policy_collection_id
	;

	IF numscopes IS NOT NULL THEN
		SELECT count(*)
		INTO tally
		FROM (
			SELECT	authorization_policy_scope, count(*)
			FROM	authorization_policy_collection_authorization_policy
					JOIN authorization_policy_collection
						USING (authorization_policy_collection_id)
					JOIN authorization_policy
						USING (authorization_policy_id)
			WHERE	authorization_policy_collection_id = 1
			GROUP BY 1
			HAVING count(*) >  numscopes
		) inside;

		IF tally > 0 THEN
			RAISE EXCEPTION 'Maximum number of unique authorization_policy_scopes can not exeed % for collection type % [%]', numscopes, typ, tally
			USING ERRCODE =  'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=authorization_policy
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS
	trigger_authz_policy_collection_authorization_policy_scope_uniq
	ON authorization_policy_collection_authorization_policy;
CREATE CONSTRAINT TRIGGER trigger_authz_policy_collection_scope_uniq
	AFTER INSERT OR UPDATE
	ON authorization_policy_collection_authorization_policy
	DEFERRABLE INITIALLY IMMEDIATE
	FOR EACH ROW
	EXECUTE PROCEDURE authz_policy_collection_scope_uniq();

------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION val_authorization_policy_collection_type_scope_unique()
RETURNS TRIGGER AS $$
DECLARE
	tally		integer;
BEGIN
	--
	-- only relevant if scope changes
	--
	IF TG_OP = 'UPDATE' AND
		OLD.max_num_unique_scopes IS NOT DISTINCT FROM NEW.max_num_unique_scopes
	THEN
		RETURN NEW;
	END IF;

	IF NEW.max_num_unique_scopes IS  NOT NULL THEN
		SELECT count(*)
		INTO	tally
		FROM (
			SELECT authorization_policy_scope, count(*)
			FROM	authorization_policy_collection apc
					JOIN authorization_policy_collection_authorization_policy
						appcap USING (authorization_policy_collection_id)
					JOIN authorization_policy ap USING (authorization_policy_id)
			WHERE	authorization_policy_collection_type =
						NEW.authorization_policy_collection_type
			GROUP BY authorization_policy_scope
			HAVING count(*) > NEW.max_num_unique_scopes
		) inside;

		IF tally > 0 THEN
			RAISE EXCEPTION
				'authorization_policy_collection_scope must be unique within %',
				NEW.authorization_policy_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=authorization_policy
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_authorization_policy_collection_type_scope_unique
	ON val_authorization_policy_collection_type;
CREATE CONSTRAINT TRIGGER trigger_val_authorization_policy_collection_type_scope_unique
	AFTER INSERT OR UPDATE
	ON val_authorization_policy_collection_type
	DEFERRABLE INITIALLY IMMEDIATE
	FOR EACH ROW
	EXECUTE PROCEDURE val_authorization_policy_collection_type_scope_unique();

------------------------------------------------------------------------------
