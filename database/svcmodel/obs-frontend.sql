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

INSERT INTO software_repository (software_repository_name, software_repository_type)
VALUES ('opensuse_13.1', 'baseos');

/* This convention for modeling a OS mirror is something I made up.
   We haven't agreed this is right. */
INSERT INTO software_repository_location (software_repository_id, software_repository_location_type, repository_location)
SELECT software_repository_id, 'zypper', 'http://yum.local.appnexus.net/mirrors/opensuse/versioned/2015013000/13.1/suse/'
FROM software_repository
WHERE software_repository_name = 'opensuse_13.1'
AND software_repository_type = 'baseos';

/* I used the package version of obs-api for the service_version name and tag.
   I did this only because it seemed to make sense and was the only thing I
   could think of. */
INSERT INTO service_version (service_id, version_name, software_tag, software_repository_id)
SELECT service_id, '2.5.5.1', '2.5.5.1', software_repository_id
FROM service, software_repository
WHERE software_repository_name = 'opensuse_13.1' AND software_repository_type = 'baseos'
AND service.service_name = 'obs-frontend';

INSERT INTO service_instance (device_id, service_endpoint_id, service_version_id)
SELECT device_id, service_endpoint_id, service_version_id
FROM device, service_endpoint, service_version
WHERE device_name = 'obs02.lax1.appnexus.com'
AND service_endpoint.uri LIKE '%obs.corp%'
AND service_version.version_name = '2.5.5.1';

INSERT INTO service_property (service_property_name, service_property_type, value)
VALUES
('location', 'launch', 'baremetal'),
('min_cpu', 'launch', '12'),
('min_disk', 'launch', '1500gb'),
('min_mem', 'launch', '64gb'),
('manual', 'docs', 'http://doc.opensuse.org/');

INSERT INTO service_property (service_property_name, service_property_type, value_sw_package_id)
SELECT 'software', 'pkg', sw_package_id
FROM sw_package
WHERE sw_package_name = 'obs-api';

WITH props AS (
    SELECT service_property_id
    FROM service_property
    ORDER BY service_property_id DESC
    LIMIT 6 )
INSERT INTO service_version_service_property (service_version_id, service_property_id)
SELECT service_version_id, props.service_property_id
FROM service_version, props
WHERE service_version.version_name = '2.5.5.1';

INSERT INTO service_depend (service_version_id, service_id, service_sla_id)
SELECT service_version.service_version_id, service.service_id, service_sla.service_sla_id
FROM service_version, service, service_sla
WHERE service.service_name = 'obs-frontend'
  AND service_sla.service_sla_name = 'always'
  AND service_version.version_name = '2.5.5.1';
