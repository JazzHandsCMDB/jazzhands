
DROP TABLE IF EXISTS service cascade;
CREATE TABLE service (
	service_id	serial		NOT NULL,
	service_name	text		NOT NULL,
	PRIMARY KEY (service_id)
);

DROP TABLE IF EXISTS service_source_repository;
CREATE TABLE service_source_repository (
	service_id		integer,
	source_repository	text,
	PRIMARY KEY (service_id, source_repository)
);

DROP TABLE IF EXISTS service_version cascade;
CREATE TABLE service_version (
	service_version_id	serial		NOT NULL,
	service_id		integer		NOT NULL,
	version_name		text		NOT NULL,
	software_repository_id	integer,
	software_tag		text,
	is_enabled		char(1) DEFAULT 'Y',
	PRIMARY KEY (service_version_id),
	UNIQUE	 (service_id, version_name)
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
-- used by port_range.    trigger enforces range_permitted and there's also
-- a trigger tie to port_range.
--
DROP TABLE IF EXISTS val_port_range_type;
CREATE TABLE val_port_range_type (
	port_range_type		text		NOT NULL,
	port_range_protocol	text		NOT NULL,
	range_permitted		char(1) DEFAULT 'Y',
	description		text,
	PRIMARY KEY (port_range_type, port_range_protocol)
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
	port_range_protocol	text		NOT NULL,
	port_range_type		text		NOT NULL,
	port_start		integer		NOT NULL,
	port_end		integer		NOT NULL,
	is_singleton		char(1)		NOT NULL,
	PRIMARY KEY (port_range_id),
	UNIQUE (port_range_name, port_range_protocol, port_range_type)
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
-- This may be 1-1 with service_endpoint (not sure)
--
-- names are kind of irrelevent.
--
DROP TABLE IF EXISTS service_endpoint_provider ;
CREATE TABLE service_endpoint_provider (
	service_endpoint_provider_id	serial	NOT NULL,
	service_endpoint_provider_name	text	NOT NULL,
	service_endpoint_provider_type	text	NOT NULL,
	service_endpoint_id		integer	NOT NULL,
	device_id			integer	NOT NULL,
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
-- I think port_range_id belongs here instead of service_instance.
--
DROP TABLE IF EXISTS service_endpoint_provider_member ;
CREATE TABLE service_endpoint_provider_member (
	service_endpoint_provider_id	integer	NOT NULL,
	service_instance_id		integer NOT NULL,
	port_range_id			integer NOT NULL,
	PRIMARY KEY (service_endpoint_provider_id, service_instance_id,
			port_range_id)
);

--
-- possibly should have the device of the endpoint on it
-- (lb, if appropriate?)  however, arguably there also needs to be
-- a gslb overlay; have not entirely gotten my head around this
--
DROP TABLE IF EXISTS service_endpoint cascade;
CREATE TABLE service_endpoint (
	service_endpoint_id	serial		NOT NULL,
	dns_record_id		integer,
	port_range_id		integer,
	uri			text,
	x509_signed_certificate_id	integer,
	private_key_id			integer,
	PRIMARY KEY (service_endpoint_id)
);	

-- possibly also a link to netblock_id or just a link to that?  This would
-- allow for chaining providers.
--
-- I think port_range_id does not belong here but belongs in
-- service_endpoint_provider_member .
--
DROP TABLE IF EXISTS service_instance cascade;
CREATE TABLE service_instance (
	service_instance_id	serial		NOT NULL,
	device_id		integer		NOT NULL,
	service_endpoint_id	integer		NOT NULL,
	service_version_id	integer		NOT NULL,
	port_range_id		integer		NOT NULL,
	PRIMARY KEY (service_instance_id),
	UNIQUE (device_id,service_endpoint_id,service_version_id)
);

DROP TABLE IF EXISTS service_endpoint_service_sla cascade;
CREATE TABLE service_endpoint_service_sla (
	service_endpoint_id	integer		NOT NULL,
	service_sla_id		integer		NOT NULL,
	service_environment_id	integer		NOT NULL,
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

--------------------------- binary distributions -----------------------------
DROP TABLE IF EXISTS software_repository cascade;
CREATE TABLE software_repository (
	software_repository_id		serial	NOT NULL,
	software_repository_name	text	NOT NULL,
	software_repository_type	text	NOT NULL,
	PRIMARY KEY (software_repository_id)
);

DROP TABLE IF EXISTS software_repository_location cascade;
CREATE TABLE software_repository_location (
	software_repository_id			integer NOT NULL,
	software_repository_location_type	text	NOT NULL,
	repository_location			text	NOT NULL,
	PRIMARY KEY (software_repository_id, software_repository_location_type)
);

--------------------------- collections ---------------------------------

DROP TABLE IF EXISTS service_collection cascade;
CREATE TABLE service_collection (
	service_collection_id	serial		NOT NULL,
	service_collection_name	text		NOT NULL,
	service_collection_type	text		NOT NULL,
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

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION create_all_services_collection() 
RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'INSERT' THEN
		INSERT INTO service_collection (
			service_collection_name, service_collection_type
		) VALUES (
			NEW.service_name, 'all-services'
		);
	ELSIF TG_OP = 'UPDATE' THEN
		UPDATE service_collection
		SET service_collection_name = NEW.service_name
		WHERE service_collection_type = 'all-services'
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
	ELSIF TG_OP = 'DELETE' THEN
		DELETE FROM service_collection_service
		WHERE service_collection_type = 'all-services'
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
