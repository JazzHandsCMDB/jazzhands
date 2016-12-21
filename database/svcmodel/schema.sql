DROP TABLE IF EXISTS service cascade;
CREATE TABLE service (
	service_id	serial		NOT NULL,
	service_name	text		NOT NULL,
	PRIMARY KEY (service_id)
);

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
-- possibly should have the device of the endpoint on it
-- (lb, if appropriate?)  however, arguably there also needs to be
-- a gslb overlay; have not entirely gotten my head around this
--
DROP TABLE IF EXISTS service_endpoint cascade;
CREATE TABLE service_endpoint (
	service_endpoint_id	serial		NOT NULL,
	dns_record_id		integer,
	uri			text,
	PRIMARY KEY (service_endpoint_id)
);	

DROP TABLE IF EXISTS service_endpoint_service_sla cascade;
CREATE TABLE service_endpoint_service_sla (
	service_endpoint_id	integer		NOT NULL,
	service_sla_id		integer		NOT NULL,
	service_environment_id	integer		NOT NULL,
	PRIMARY KEY (service_endpoint_id,service_sla_id,service_environment_id)
);

DROP TABLE IF EXISTS service_instance cascade;
CREATE TABLE service_instance (
	service_instance_id	serial		NOT NULL,
	device_id		integer		NOT NULL,
	service_endpoint_id	integer		NOT NULL,
	service_version_id	integer		NOT NULL,
	PRIMARY KEY (service_instance_id),
	UNIQUE (device_id,service_endpoint_id,service_version_id)
);

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
	version/feature advertisement
	gslb/lb tie in
	os versioning
	os snapshots
	licensing
	appaal tiein
	x509_certificate tie in
	tie into property
	foreign keys
	val tables
	non-network services
	triggers
	netblock vs l2 vs l3 collections

 */
