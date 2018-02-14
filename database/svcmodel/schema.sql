DROP TABLE IF EXISTS service cascade;
CREATE TABLE service (
	service_id	serial		NOT NULL,
	service_name	text		NOT NULL,
	description	text		NULL,
	is_active	char(1) DEFAULT 'Y' NOT NULL,
	PRIMARY KEY (service_id)
);

--
-- source repository, it has a business type and a technology
--
-- type is business concept (software, config)
-- technology is git, svn, hg, Vv
--
-- url is where you go to checkout; the next table can be used for
-- relative paths within a checkout, if appropriate.
--
DROP TABLE IF EXISTS source_repository;
CREATE TABLE source_repository (
	source_repository_id		serial	NOT NULL,
	source_repository_name		text	NOT NULL,
	source_repository_type		text	NOT NULL,
	source_repository_technology	text	NOT NULL,
	source_repository_url		text	NOT NULL,
	description			text	NULL,
	PRIMARY KEY (source_repository_id),
	unique (source_repository_name, source_repository_type)
);

-- path is used to say where something is inside a repo
DROP TABLE IF EXISTS service_source_repository;
CREATE TABLE service_source_repository (
	service_id			integer NOT NULL,
	source_repository_id		integer	NOT NULL,
	source_repository_path		text	NULL,
	PRIMARY KEY (service_id, source_repository_id)
);

--
-- service_type is not yet clearly defined and may change  but at the moment
-- 'network', 'integration' (for things that just talk between services but
-- do not listen, like feeds).  possibly also 'process' for things that do not
-- leave the machine. 
--
DROP TABLE IF EXISTS service_version cascade;
CREATE TABLE service_version (
	service_version_id	serial		NOT NULL,
	service_id		integer		NOT NULL,
	service_type		text		NOT NULL,
	version_name		text		NOT NULL,
	is_enabled		char(1) DEFAULT 'Y',
	PRIMARY KEY (service_version_id),
	UNIQUE	 (service_id, version_name)
);

DROP TABLE IF EXISTS service_version_source_repository;
CREATE TABLE service_version_source_repository (
	service_version_id	integer		NOT NULL,
	source_repository_id	integer		NOT NULL,
	software_tag		text		NOT NULL,
	PRIMARY KEY (service_version_id, source_repository_id)
);

-----------------------

--
-- specifies current default for dealing with new repos.  this cloned into
-- the next table when a new release happens
--
DROP TABLE IF EXISTS service_software_repo;
CREATE TABLE service_software_repo (
	service_id		integer		NOT NULL,
	sw_package_repository_id	integer		NOT NULL,
	PRIMARY KEY (service_id, sw_package_repository_id)
);

DROP TABLE IF EXISTS service_version_sw_package_repository;
CREATE TABLE service_version_sw_package_repository (
	service_version_id	integer		NOT NULL,
	sw_package_repository_id	integer		NOT NULL,
	PRIMARY KEY (service_version_id, sw_package_repository_id)
);

--------------------------- shared netblock collections -------------------
-- this will need types, recursion and all that jazz.

DROP TABLE IF EXISTS shared_netblock_collection;
CREATE TABLE shared_netblock_collection (
	shared_netblock_collection_id	serial	NOT NULL,
	shared_netblock_collection_name	text	NOT NULL,
	shared_netblock_collection_type	text	NOT NULL,
	description			TEXT,
	PRIMARY KEY (shared_netblock_collection_id)
);

DROP TABLE IF EXISTS shared_netblock_coll_netblock;
CREATE TABLE shared_netblock_coll_netblock (
	shared_netblock_collection_id	integer	NOT NULL,
	shared_netblock_id		integer	NOT NULL,
	PRIMARY KEY (shared_netblock_collection_id, shared_netblock_id)
);

DROP TABLE IF EXISTS shared_netblock_collection_hier;
CREATE TABLE shared_netblock_collection_hier (
	shared_netblock_collection_id		integer	NOT NULL,
	child_shared_netblock_collection_id	integer	NOT NULL,
	PRIMARY KEY (shared_netblock_collection_id,
		child_shared_netblock_collection_id)
);


--------------------------- relationships ---------------------------------

--
-- role: master, slave, ro, rw
-- scope: internal, external, datacenter
-- availability - expected uptime (in integer percent)
DROP TABLE IF EXISTS service_sla;
CREATE TABLE service_sla (
	service_sla_id		serial		NOT NULL,
	service_sla_name	text		NOT NULL,
	availability		integer,
	service_role		text,
	service_scope		text,
	PRIMARY KEY (service_sla_id),
	UNIQUE (service_sla_name)
);

--
-- /etc/protocols
--
DROP TABLE IF EXISTS protocol;
CREATE TABLE protocol (
	protocol		text		NOT NULL,
	protocol_number		integer,
	description		text,
	PRIMARY KEY (protocol)
);

--
-- used by port_range.    trigger enforces range_permitted and there's also
-- a trigger tie to port_range.
--
DROP TABLE IF EXISTS val_port_range_type;
CREATE TABLE val_port_range_type (
	port_range_type		text		NOT NULL,
	protocol		text		NOT NULL,
	range_permitted		char(1) DEFAULT 'Y',
	description		text,
	PRIMARY KEY (port_range_type, protocol)
);

--
-- defines port ranges or single ports mostly for use by service end points
-- but can be used elsewhere.
--
-- is_singleton is maintained by trigger and is Y if start/end are the same.
--
-- protocol is in the /etc/protocols sense and also has a val table.
--
-- There will be a type, say 'services' with the contents of /etc/services,
-- although no support for port nicknames here.  (if we wanted that, it would
-- be another table, I think.
--
DROP TABLE IF EXISTS port_range;
CREATE TABLE port_range (
	port_range_id		serial		NOT NULL,
	port_range_name		text		NOT NULL,
	protocol		text		NOT NULL,
	port_range_type		text		NOT NULL,
	port_start		integer		NOT NULL,
	port_end		integer		NOT NULL,
	is_singleton		char(1)		NOT NULL,
	PRIMARY KEY (port_range_id),
	UNIQUE (port_range_name, protocol, port_range_type)
);

--
-- defines various types -- nat providers, load balancers, direct connections
-- triggers enforce some things based on this.
--
DROP TABLE IF EXISTS service_endpoint_provider_type;
CREATE TABLE service_endpoint_provider_type (
	service_endpoint_provider_type	text	NOT NULL,
	maximum_members			integer	NOT NULL,
	translates_addresses		char(1) DEFAULT 'N',
	proxies_connections		char(1) DEFAULT 'Y',
	PRIMARY KEY (service_endpoint_provider_type)
);

--
-- This describes where the service actually terminates.
--
-- This may be 1-1 with service_endpoint (trigger enforced)
-- likely many to many but not most cases
--
-- names are kind of irrelevent.
--
-- only one of shared_netblock_collection_id, netblock_id can be set
-- if device_id is set, netblock_id must be set and the must match
--
-- This probably does NOT need an sla column, we're 25% sure about that
-- because you would just create another service_endpoint.
--
DROP TABLE IF EXISTS service_endpoint_provider ;
CREATE TABLE service_endpoint_provider (
	service_endpoint_provider_id	serial	NOT NULL,
	service_endpoint_provider_name	text	NOT NULL,
	service_endpoint_provider_type	text	NOT NULL,
	service_endpoint_id		integer	NOT NULL,
	shared_netblock_collection_id	integer	NULL,
	netblock_id			integer NULL,
	device_id			integer	NULL,
	description			text,
	PRIMARY KEY (service_endpoint_provider_id),
	UNIQUE (service_endpoint_provider_name, service_endpoint_provider_type)
);

--
-- This does mapping from a service_endpoint_provider to an actual device
-- some sort of prioritization?
--
-- if this is non-proxied connection, the port range must match the port
-- range of the endpoint_provider (or endpoint?)
--
-- this is many-to-many glue, so NO port_range_id.
--
-- rank is used by upstream things to figure out how to direct traffic.
--
DROP TABLE IF EXISTS service_endpoint_provider_member ;
CREATE TABLE service_endpoint_provider_member (
	service_endpoint_provider_id	integer	NOT NULL,
	service_instance_id		integer NOT NULL,
	rank				integer NOT NULL DEFAULT 10,
	is_enabled			char(1) DEFAULT 'Y',
	PRIMARY KEY (service_endpoint_provider_id, service_instance_id)
);

--
-- possibly should have the device of the endpoint on it
-- (lb, if appropriate?)  however, arguably there also needs to be
-- a gslb overlay; have not entirely gotten my head around this
--
-- x509 certificates are broken out in order to support multiple types of
-- certifiates on the same endpoint (ECC, RSA).
--
DROP TABLE IF EXISTS service_endpoint cascade;
CREATE TABLE service_endpoint (
	service_endpoint_id	serial		NOT NULL,
	dns_record_id		integer,
	port_range_id		integer,
	uri			text,
	PRIMARY KEY (service_endpoint_id)
);

--
-- Its possible, (probable?) that the private_key_id should not be
-- here, although this this means sorting out encryption better since
-- private keys are encrypted by default.
--
DROP TABLE IF EXISTS service_endpoint_x509_certificate cascade;
CREATE TABLE service_endpoint_x509_certificate (
	service_endpoint_id	serial		NOT NULL,
	x509_signed_certificate_id	integer,
	private_key_id			integer,
	x509_certificate_rank		integer,
	PRIMARY KEY (service_endpoint_id,x509_signed_certificate_id),
	UNIQUE (service_endpoint_id, x509_certificate_rank)
);


--
-- This is used to implement health checks for load balancers and the like.
--
-- its possible to have multiple health checks per service_endpoint.
--
-- The gist is the thing that hosts a service_endpoint (generally
-- a service_endpoint_provider) checks the instances listed in
-- service_endpoint_provider_member.
--
-- I do not think this makes sense on direct connections.
--
--
DROP TABLE IF EXISTS service_endpoint_health_check;
CREATE TABLE service_endpoint_health_check (
	service_endpoint_health_check_id	serial	NOT NULL,
	service_endpoint_id			integer	NOT NULL,
	rank					integer NOT NULL DEFAULT 10,
	request_string				text,
	search_string				text,
	is_enabled				char(1) NOT NULL DEFAULT 'Y',
	primary key (service_endpoint_health_check_id),
	UNIQUE (service_endpoint_id, rank)
);

-- possibly also a link to netblock_id or just a link to that?  This would
-- allow for chaining providers.
--
-- mdr,kovert thought port_range_id belonged on
-- service_endpoint_provider_member but talked out that it did not.
--
-- netblock_id is probably not nullable but should be forced to be set if
-- the service is a network service
--
-- for things that do not have an endpoint (something that runs on a host
-- like a feed perhaps), service_endpoint_id may need to be nullable.
--
DROP TABLE IF EXISTS service_instance cascade;
CREATE TABLE service_instance (
	service_instance_id	serial		NOT NULL,
	device_id		integer		NOT NULL,
	netblock_id		integer		NOT NULL,
	service_endpoint_id	integer		NOT NULL,
	service_version_id	integer		NOT NULL,
	port_range_id		integer		NULL,
	PRIMARY KEY (service_instance_id),
	UNIQUE (device_id,service_endpoint_id,service_version_id)
);

DROP TABLE IF EXISTS service_endpoint_service_sla cascade;
CREATE TABLE service_endpoint_service_sla (
	service_endpoint_id	integer		NOT NULL,
	service_sla_id		integer		NOT NULL,
	service_environment_id	integer		NULL,
	PRIMARY KEY (service_endpoint_id,service_sla_id,service_environment_id)
);

DROP TABLE IF EXISTS service_depend;
CREATE TABLE service_depend (
	service_depend_id	serial		NOT NULL,
	service_version_id	integer		NOT NULL,
	service_id		integer 	NOT NULL,
	min_service_version_id	integer,
	max_service_version_id	integer,
	service_sla_id		integer,
	PRIMARY KEY (service_depend_id),
	UNIQUE (service_version_id, service_id, service_sla_id)
);

--
-- not sure if this needs to exist or not, but we're putting it here
-- to indicate the row can go into an acl (at least)
--
-- if we care about source ports, they'd go here
DROP TABLE IF EXISTS service_acl;
CREATE TABLE service_acl (
	service_depend_id	integer		NOT NULL,
	description		text,
	is_enabled		char(1) DEFAULT 'Y',
	PRIMARY KEY (service_depend_id)
);


--------------------------- binary distributions -----------------------------
--
-- points to something that takes the source and spits out binary releases.
--
-- name is the repository name inside a given build/release system.  This may
-- be an OBS project.
--
-- type is the build system, obs/bob/ospkg/maven/etc.
--
-- I can't think of any more than a default type.
--
-- group should possibly be called metadata, which is just something
-- meaningful within the build system.
--
DROP TABLE IF EXISTS sw_package_repository cascade;
CREATE TABLE sw_package_repository (
	sw_package_repository_id		serial	NOT NULL,
	sw_package_repository_name	text	NOT NULL,
	sw_package_repository_type	text	NOT NULL,
	sw_package_repository_group	text	NULL,
	PRIMARY KEY (sw_package_repository_id),
	UNIQUE (sw_package_repository_name, sw_package_repository_type)
);

-- XXX - perhaps this should be tied to service environments somehow.  how
-- to deal with "prod is here, dev is there"  .  also different people
-- doing dev builds might be different (in the OBS case).  This may be
-- some sort of magic pass-thru to the building interface.

--
-- service environment collections are more important on locations
--
-- possibility to promote a sw_package_repository to production or other
-- environments, or force a rebuild by moving it to a new places
--

--
-- type is yum, apt, I think.
-- sw_package type is rpm, deb, etc, which is in sw_package
--
-- its possible that this should be 1-m and have the pk be
-- sw_package_repository_id,repository_uri.
--
DROP TABLE IF EXISTS sw_package_repository_location cascade;
CREATE TABLE sw_package_repository_location (
	sw_package_repository_id			integer NOT NULL,
	sw_package_repository_location_type	text	NOT NULL,
	sw_package_type				text	NOT NULL,
	repository_uri				text	NOT NULL,
	service_environment_collection_id	integer	NULL,
	PRIMARY KEY (sw_package_repository_id, sw_package_repository_location_type)
);

--------------------------- collections ---------------------------------

--
-- These should arguably be called service_version_collections, and maybe they
-- will be.
--
-- There are two trigger-maintained special ones which are treated the same
-- by triggers but are meant to be different:
--
-- all-services - every version that has ever existed.  This is meant to
-- take the place of a proper service_collection.
--
-- current-services -- new versions are added to this.  Its meant to assign
-- properties to major groups of things, but if those need to be overhauled,
-- the existing can be renamed something like servicename-pre2.0 and a new
-- 'current-services' can be created so that new ones end up in the right
-- place.
--
-- it is expected that most properties are assigned to 'current-servicsw'
--
DROP TABLE IF EXISTS service_collection cascade;
CREATE TABLE service_collection (
	service_collection_id	serial		NOT NULL,
	service_collection_name	text		NOT NULL,
	service_collection_type	text		NOT NULL,
	description				TEXT,
	PRIMARY KEY (service_collection_id)
);

DROP TABLE IF EXISTS service_collection_hier cascade;
CREATE TABLE service_collection_hier (
	service_collection_id		integer	NOT NULL,
	child_service_collection_id	integer	NOT NULL,
	PRIMARY KEY (service_collection_id, child_service_collection_id)
);

DROP TABLE IF EXISTS service_collection_service cascade;
CREATE TABLE service_collection_service (
	service_collection_id		integer	NOT NULL,
	service_version_id		integer	NOT NULL,
	PRIMARY KEY (service_collection_id, service_version_id)
);

--
-- THere is a reasonable chance that this will just become property with
-- service_collection being added to the lhs (and possibly rhs).
--
-- This means you should assume every lhs and rhs in property are here, even
-- though they are not yet.
--
DROP TABLE IF EXISTS service_property;
CREATE TABLE service_property (
	service_property_id		serial		NOT NULL,
	service_collection_id		integer		NOT NULL,
	service_property_name		text		NOT NULL,
	service_property_type		text		NOT NULL,-- not sure
	value				text,
	value_sw_package_id		integer,
	value_netblock_collection_id	integer,
	value_layer2_network_collection_id	integer,
	value_layer3_network_collection_id	integer,
	value_account_collection_id	integer,
	PRIMARY KEY (service_property_id)
);

---------------------------- network acls  ---------------------------------

-- filter
DROP TABLE IF EXISTS acl_group;
CREATE TABLE acl_group (
	acl_group_id			serial	NOT NULL,
	acl_group_name			text,
	acl_group_type			text,
	description			text,
	PRIMARY KEY (acl_group_id)
);

-- term
--
-- XXX shouldn't be l3 networks, should be netblock collections
DROP TABLE IF EXISTS acl_rule;
CREATE TABLE acl_rule (
	acl_rule_id				serial NOT NULL,
	acl_group_id				integer NOT NULL,
	acl_rank				integer NOT NULL,
	service_depend_id			integer,
	description				text,
	action					text,	-- permit/deny
	source_layer3_network_collection_id	integer	NOT NULL,
	source_port_relation_restriction	text NOT NULL,
	source_port_range_id			integer NOT NULL,
	dest_layer3_network_collection_id	integer	NOT NULL,
	dest_port_relation_restriction		text NOT NULL,
	dest_port_range_Id			integer	NOT NULL,
	PRIMARY KEY (acl_rule_id),
	UNIQUE (acl_group_id, acl_rank)
);

DROP TABLE IF EXISTS network_interface_acl;
CREATE TABLE network_interface_acl (
	network_interface_acl_id		serial NOT NULL,
	network_interface_id			integer NOT NULL,
	traffic_direction			text NOT NULL,
	PRIMARY KEY (network_interface_acl_id),
	UNIQUE (network_interface_id, traffic_direction)
);

DROP TABLE IF EXISTS network_interface_acl_chain;
CREATE TABLE network_interface_acl_chain (
	network_interface_acl_id		integer NOT NULL,
	acl_group_id				integer NOT NULL,
	network_interface_acl_chain_rank	integer NOT NULL,
	PRIMARY KEY (network_interface_acl_id, acl_group_id),
	UNIQUE (network_interface_acl_id, network_interface_acl_chain_rank)
);

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION create_all_services_collection()
RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'INSERT' THEN
		INSERT INTO service_collection (
			service_collection_name, service_collection_type
		) VALUES
			( NEW.service_name, 'all-services' ),
			( NEW.service_name, 'current-services' );
	ELSIF TG_OP = 'UPDATE' THEN
		UPDATE service_collection
		SET service_collection_name = NEW.service_name
		WHERE service_collection_type
			IN ( 'all-services', 'current-services')
		AND service_collection_name = OLD.service_name;
	ELSIF TG_OP = 'DELETE' THEN
		RETURN OLD;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_create_all_services_collection
	ON service;
CREATE TRIGGER trigger_create_all_services_collection
	AFTER INSERT OR UPDATE OF service_name
	ON service
	FOR EACH ROW
	EXECUTE PROCEDURE create_all_services_collection();

DROP TRIGGER IF EXISTS trigger_create_all_services_collection_del
	ON service;
CREATE TRIGGER trigger_create_all_services_collection_del
	BEFORE DELETE
	ON service
	FOR EACH ROW
	EXECUTE PROCEDURE create_all_services_collection();

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION manip_all_svc_collection_members()
RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'INSERT' THEN
		INSERT INTO service_collection_service (
			service_collection_id, service_version_id
		) SELECT service_collection_id, NEW.service_version_id
		FROM service_collection
		WHERE service_collection_type = 'all-services'
		AND service_collection_name IN (SELECT service_name
			FROM service
			WHERE service_id = NEW.service_id
		);
		INSERT INTO service_collection_service (
			service_collection_id, service_version_id
		) SELECT service_collection_id, NEW.service_version_id
		FROM service_collection
		WHERE service_collection_type = 'current-services'
		AND service_collection_name IN (SELECT service_name
			FROM service
			WHERE service_id = NEW.service_id
		);
	ELSIF TG_OP = 'DELETE' THEN
		DELETE FROM service_collection_service
		WHERE service_collection_type = 'all-services'
		AND service_version_id = OLD.service_version_id
		AND service_collection_name IN (SELECT service_name
			FROM service
			WHERE service_id = OLD.service_id
		);
		DELETE FROM service_collection_service
		WHERE service_collection_type = 'current-services'
		AND service_version_id = OLD.service_version_id
		AND service_collection_name IN (SELECT service_name
			FROM service
			WHERE service_id = OLD.service_id
		);

		RETURN OLD;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_manip_all_svc_collection_members
	ON service_version;
CREATE TRIGGER trigger_manip_all_svc_collection_members
	AFTER INSERT
	ON service_version
	FOR EACH ROW
	EXECUTE PROCEDURE manip_all_svc_collection_members();

DROP TRIGGER IF EXISTS trigger_manip_all_svc_collection_members_del
	ON service_version;
CREATE TRIGGER trigger_manip_all_svc_collection_members_del
	BEFORE DELETE
	ON service_version
	FOR EACH ROW
	EXECUTE PROCEDURE manip_all_svc_collection_members();

-------------------------------------------------------------------------------

/*
Things not figured out yet:
	os versioning
	os snapshots
		- valid versions get added to property and linked to
			service_collection_ids
	appaal tiein
		- add service_collection_id to appaal?
		- appaal_instance links to service_instance somehow?
	version/feature advertisement
		- this may just be properties?  more complicated?
	should service_instance possibly become a property?
		- if not, should it point to a network interface + device and not just
			a device and pull in lb_node-style information?  how does that fit
			into geoip-encoded records
	non-network services
	lb tie in
		- this is either service_endpoint or, more likely, is another table
		  with service_endpoint as the pk/fk.  This essentially ends up with
		  missing columns from lb_pool.  The difference is lb_ip becomes tied
		  to a dns record and thus tied to an ip address rather than to an
		  optional ip address
	gslb tie in
		- I think this means enhancing dns_record to handle geoip data.
		  either a special record or a flag on existing records to say "this
		  is a special gslb record" (or zone).
	some way to tie service endpoints to service instances when they are
		not through some sort of intermediary.  Should this be trigger
		enforced?   probably.
needs cycles, perhaps not a lot of thought:
	tie into property (likely service_collection_id merges into property r/lhs)
	foreign keys (should be obvious)
	val tables (should also be pretty obviou)
	triggers - some done, more needed.  needs to be enumerated
needs thought:
	licensing

needed:
 - stored procedures to break off a service collections of versions in smart
   ways, some way to inherit everything from the old one plus new stuff
 - determine how to purge old versions, there's service_version.is_enabled and
   there's outright purging old information.

KUBERNETES:
 - services are kubernetes services.  They may need a different "outside"
			vs "inside" names since something like nginx is too general.
			The inside name would be a property override
 - pods are devices
 - cluter ips are service endpoints and each kubernetes cluster has its own
 		ip universe.
 - service versions are either a version tag, I think.
 - most tags are properties
 - container images are software packages.  sadly, their names are:
 	docker://sha256:c8c894ffc3010ca80e87226238d13cb99c7da857f3cecee43796624ea06ff781
	or similar.

DOCKER CONTAINERS:
 - services are containers, similar inside/outside thing as kubernetes
 - I am not sure if a container is a device. It probably should be if it
   consume its own IP
 - endpoints are the exposed ip/ports of the containers
 - container images are software packages as above, I think.
 */

grant select on all tables in schema jazzhands to ro_role;
grant insert,update,delete on all tables in schema jazzhands to iud_role;

grant select,usage on all sequences in schema jazzhands to iud_role;
