/*
 * XXX - NOTE THIS DOES NOT USED THE shared_endpoint stuff yet
 */
INSERT INTO sw_package (sw_package_name, sw_package_type)
VALUES ('obs-api', 'rpm');

INSERT INTO service_endpoint (dns_record_id, uri)
SELECT dns_record_id, concat('https://', dns_name, '.',soa_name,'/')
FROM dns_record join dns_domain using (dns_domain_id)
WHERE dns_name = 'obs' ORDER BY dns_domain_id limit 1;

INSERT INTO service_endpoint_service_sla (service_endpoint_id, service_sla_id, service_environment_id)
SELECT service_endpoint_id, service_sla_id, service_environment_id
FROM service_endpoint, service_sla, service_environment
WHERE service_environment_name = 'production'
AND production_state = 'production'
AND service_sla_name = 'always'
AND service_endpoint.uri LIKE '%obs.corp%';

INSERT INTO service (service_name)
VALUES ('obs-frontend');

INSERT INTO sw_package_repository (sw_package_repository_name, sw_package_repository_type)
VALUES ('opensuse_13.1', 'baseos');

/* This convention for modeling a OS mirror is something I made up.
   We haven't agreed this is right. */
INSERT INTO sw_package_repository_location (sw_package_repository_id, sw_package_repository_location_type, sw_package_type, repository_uri)
SELECT sw_package_repository_id, 'zypper', 'rpm','http://yum.local.appnexus.net/mirrors/opensuse/versioned/2015013000/13.1/suse/'
FROM sw_package_repository
WHERE sw_package_repository_name = 'opensuse_13.1'
AND sw_package_repository_type = 'baseos';

/* I used the package version of obs-api for the service_version name and tag.
   I did this only because it seemed to make sense and was the only thing I
   could think of. */
INSERT INTO service_version (service_id, service_type, version_name)
SELECT service_id, 'network', '2.5.5.1'
FROM service
WHERE service.service_name = 'obs-frontend';

--- XXX need to convert the sw_package_repository bits

INSERT INTO service_instance (device_id, netblock_id, service_endpoint_id, service_version_id)
SELECT device_id, netblock_id, service_endpoint_id, service_version_id
FROM device
	join network_interface_netblock using (device_id)
	join netblock using (netblock_id)
	, service_endpoint, service_version
WHERE device_name = 'obs02.lax1.appnexus.com'
AND service_endpoint.uri LIKE '%obs.corp%'
AND service_version.version_name = '2.5.5.1';

WITH svccol AS (
	SELECT * FROM service_collection WHERE service_collection_type = 'all-services' AND service_collection_name = 'obs-frontend'
) INSERT INTO service_property (service_collection_id, service_property_name, service_property_type, value)
VALUES
((SELECT service_collection_id FROM svccol),'location', 'launch', 'baremetal'),
((SELECT service_collection_id FROM svccol),'min_cpu', 'launch', '12'),
((SELECT service_collection_id FROM svccol),'min_disk', 'launch', '1500gb'),
((SELECT service_collection_id FROM svccol),'min_mem', 'launch', '64gb'),
((SELECT service_collection_id FROM svccol),'manual', 'docs', 'http://doc.opensuse.org/');

WITH svccol AS (
	SELECT * FROM service_collection WHERE service_collection_type = 'all-services' AND service_collection_name = 'obs-frontend'
) INSERT INTO service_property (service_collection_id, service_property_name, service_property_type, value_sw_package_id)
SELECT service_collection_id, 'software', 'pkg', sw_package_id
FROM sw_package, svccol
WHERE sw_package_name = 'obs-api';

INSERT INTO service_depend (service_version_id, service_id, service_sla_id)
SELECT service_version.service_version_id, service.service_id, service_sla.service_sla_id
FROM service_version, service, service_sla
WHERE service.service_name = 'obs-frontend'
  AND service_sla.service_sla_name = 'always'
  AND service_version.version_name = '2.5.5.1';
