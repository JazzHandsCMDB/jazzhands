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
 */
CREATE TABLE val_authorization_policy_type (
	authorization_policy_type	text NOT NULL,
	description			text,
	PRIMARY KEY (authorization_policy_type)
);

/*
 * name of a policy that has permissions assocaited with it
 */
CREATE TABLE authorization_policy (
	authorization_policy_id		SERIAL,
	authorization_policy_name	TExt NOT NULL,
	authorization_policy_type	TExt NOT NULL,
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
 */
CREATE TABLE val_authorization_policy_collection_type (
	authorization_policy_collection_type	text NOT NULL,
        IS_INFRASTRUCTURE_TYPE 			boolean  NOT NULL DEFAULT false,
        MAX_NUM_MEMBERS      			INTEGER NULL,
        MAX_NUM_COLLECTIONS  			INTEGER NULL,
        CAN_HAVE_HIERARCHY   			boolean NOT NULL DEFAULT true,
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
 * applciation_id will become a collection
 */
CREATE TABLE authz_property_base (
	property_id				INTEGER NOT NULL,
	authorization_policy_collection_id	INTEGER NOT NULL,
	application_id				INTEGER,
	kubernetes_cluster			TEXT,
	kubernetes_namespace			TEXT,
	kubernetes_service_account		TEXT,
	primary key(property_id)
);

--- fks
ALTER TABLE authz_property_base
	ADD CONSTRAINT fk_authz_property_base_property
	FOREIGN KEY (property_id)
	REFERENCES jazzhands.property(property_id)
	DEFERRABLE;

ALTER TABLE authz_property_base
	ADD CONSTRAINT fk_authz_property_base_auth_p_collection
	FOREIGN KEY (authorization_policy_collection_id)
	REFERENCES authorization_policy_collection(authorization_policy_collection_id)
	DEFERRABLE;

ALTER TABLE authz_property_base
	ADD CONSTRAINT fk_authz_property_base_application
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
	ADD CONSTRAINT fk_authn_type_policy_relation_policy
	FOREIGN KEY (policy_id)
	REFERENCES policy(policy_id)
	DEFERRABLE;

ALTER TABLE authorization_policy_relation
	ADD CONSTRAINT fk_authorization_policy_relation_ap_type
	FOREIGN KEY (authorization_policy_id)
	REFERENCES authorization_policy(authorization_policy_id)
	DEFERRABLE;

ALTER TABLE authorization_policy_relation
	ADD CONSTRAINT fk_authn_policy_relation_policy
	FOREIGN KEY (policy_id)
	REFERENCES policy(policy_id)
	DEFERRABLE;

ALTER TABLE authorization_policy_permission
	ADD CONSTRAINT fk_authorization_policy_permission_authn_policy
	FOREIGN KEY (authorization_policy_id)
	REFERENCES authorization_policy(authorization_policy_id)
	DEFERRABLE;

ALTER TABLE authorization_policy_collection
	ADD CONSTRAINT fk_authorization_policy_collection_type
	FOREIGN KEY (authorization_policy_collection_type)
	REFERENCES val_authorization_policy_collection_type(authorization_policy_collection_type)
	DEFERRABLE;

ALTER TABLE authorization_policy_collection_policy
	ADD CONSTRAINT fk_authn_policy_collection_policy_authn_policy
	FOREIGN KEY (authorization_policy_collection_id)
	REFERENCES authorization_policy_collection(authorization_policy_collection_id)
	DEFERRABLE;

ALTER TABLE authorization_policy_collection_policy
	ADD CONSTRAINT fk_authorization_policy_collection_policy_policy
	FOREIGN KEY (policy_id)
	REFERENCES policy(policy_id)
	DEFERRABLE;

ALTER TABLE authorization_policy_collection_authorization_policy
	ADD CONSTRAINT fk_authn_pol_collection_authn_policy_coll
	FOREIGN KEY (authorization_policy_collection_id)
	REFERENCES authorization_policy_collection(authorization_policy_collection_id)
	DEFERRABLE;

ALTER TABLE authorization_policy_collection_authorization_policy
	ADD CONSTRAINT fk_authn_pol_collection_authn_policy
	FOREIGN KEY (authorization_policy_id)
	REFERENCES authorization_policy(authorization_policy_id)
	DEFERRABLE;

ALTER TABLE authorization_policy_collection_hier
	ADD CONSTRAINT fk_authorization_policy_collection_id_authn_policy
	FOREIGN KEY (authorization_policy_collection_id)
	REFERENCES authorization_policy_collection(authorization_policy_collection_id)
	DEFERRABLE;

ALTER TABLE authorization_policy_collection_hier
	ADD CONSTRAINT fk_authorization_policy_collection_id_child_authn_policy
	FOREIGN KEY (child_authorization_policy_collection_id)
	REFERENCES authorization_policy_collection(authorization_policy_collection_id)
	DEFERRABLE;

CREATE OR REPLACE VIEW authz_property AS SELECT
	property_id, account_collection_id, account_id, account_realm_id,
	authorization_policy_collection_id, company_collection_id, company_id,
	device_collection_id, dns_domain_collection_id,
	layer2_network_collection_id, layer3_network_collection_id,
	netblock_collection_id, network_range_id, operating_system_id,
	operating_system_snapshot_id, person_id, property_collection_id,
	service_env_collection_id, site_code, x509_signed_certificate_id,
	application_Id,
	kubernetes_cluster,
	kubernetes_namespace,
	kubernetes_service_account,
	property_name, property_type, property_value, property_value_timestamp,
	property_value_account_coll_id, property_value_device_coll_id,
	property_value_json, property_value_nblk_coll_id,
	property_value_password_type, property_value_person_id,
	property_value_sw_package_id, property_value_token_col_id,
	property_rank, start_date, finish_date, is_enabled, data_ins_user,
	data_ins_date, data_upd_user, data_upd_date
FROM	jazzhands.property
	JOIN authz_property_base USING (property_id)
;

CREATE OR REPLACE VIEW maestro_application AS
SELECT	id as application_id,
	name as application_name
FROM	maestro.application;

CREATE OR REPLACE VIEW mclass AS
SELECT	device_collection_id,
	device_collection_name
FROM	jazzhands.device_collection
WHERE	device_collection_type = 'mclass';


INSERT INTO jazzhands.val_property_type (
	property_type,
	description
) VALUES (
	'authorization-mappings',
	'prototype authorization mappings for authn schema'
);

INSERT INTO jazzhands.val_property (
	property_name,
	property_type,
	permit_device_collection_id,
	device_collection_type,
	is_multivalue,
	property_data_type
) VALUES (
	'mclass-authorization-map',
	'authorization-mappings',
	'REQUIRED',
	'mclass',
	'Y',
	'none'
);

INSERT INTO jazzhands.val_property (
	property_name,
	property_type,
	is_multivalue,
	property_data_type
) VALUES (
	'application-authorization-map',
	'authorization-mappings',
	'Y',
	'none'
);

INSERT INTO jazzhands.val_property (
	property_name,
	property_type,
	is_multivalue,
	property_data_type
) VALUES (
	'application-kubernetes-map',
	'authorization-mappings',
	'Y',
	'none'
);
