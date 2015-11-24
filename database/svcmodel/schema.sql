DROP TABLE IF EXISTS service cascade;
CREATE TABLE service (
	service_id	serial		NOT NULL,
	service_name	text		NOT NULL,
	software_repo	text,
	PRIMARY KEY (service_id)
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

DROP TABLE IF EXISTS service_property;
CREATE TABLE service_property (
	service_property_id		serial		NOT NULL,
	service_property_name		text		NOT NULL,
	service_property_type		text		NOT NULL,-- not sure
	value				text,
	value_sw_package_id		integer,
	value_network_collection_id	integer,
	value_account_collection_id	integer,
	PRIMARY KEY (service_property_id)
);

DROP TABLE IF EXISTS service_version_service_property;
CREATE TABLE service_version_service_property (
	service_version_id	integer,
	service_property_id	integer,
	PRIMARY KEY (service_version_id, service_property_id)
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
