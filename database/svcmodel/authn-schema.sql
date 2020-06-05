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
	authorization_policy_name	text NOT NULL,
	authorization_policy_type	text NOT NULL,
	description			text,
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
 */
CREATE TABLE authz_property_base (
	property_id				INTEGER NOT NULL,
	authorization_policy_collection_id	INTEGER NOT NULL,
	primary key(property_id)
);

CREATE OR REPLACE VIEW authz_property AS SELECT
	property_id, account_collection_id, account_id, account_realm_id,
	authorization_policy_collection_id, company_collection_id, company_id,
	device_collection_id, dns_domain_collection_id,
	layer2_network_collection_id, layer3_network_collection_id,
	netblock_collection_id, network_range_id, operating_system_id,
	operating_system_snapshot_id, person_id, property_collection_id,
	service_env_collection_id, site_code, x509_signed_certificate_id,
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


