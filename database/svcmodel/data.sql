
DO $$
BEGIN
	INSERT INTO service_sla (
		service_sla_name, availability, service_role, service_scope
	) VALUES (
		'always', 100, 'master', 'internal'
	);
EXCEPTION WHEN unique_violation THEN
	NULL;
END
$$;

DO $$
BEGIN
	INSERT INTO val_sw_package_type (sw_package_type) values ('rpm');
EXCEPTION WHEN unique_violation THEN
	NULL;
END
$$;

DO $$
DECLARE
	_tal	integer;
BEGIN
WITH repo AS (
	INSERT INTO software_repository (
		software_repository_name, software_repository_type
	) values (
		'common', 'default'
	) RETURNING *
), repoloc AS (
	INSERT INTO software_repository_location
		(software_repository_id, software_repository_location_type,
		repository_location
	) SELECT software_repository_id,
		unnest(ARRAY['obs', 'yum', 'apt']),
		unnest(ARRAY['common', 'https:/yum.example.com/blahblah', 
			'https://apt.example.com/blahblah'])
	FROM repo
	RETURNING *
) SELECT count(*) INTO _tal FROM repoloc;
EXCEPTION WHEN unique_violation THEN
	NULL;
END
$$;
DO $$
BEGIN
	--
	-- groups of networks for launching hosts.  
	--
	INSERT INTO val_layer2_network_coll_type (
		layer2_network_collection_type
	) VALUES (
		'service'
	);
EXCEPTION WHEN unique_violation THEN
	NULL;
END
$$;

DO $$
BEGIN
	INSERT INTO layer2_network_collection (
		layer2_network_collection_name, layer2_network_collection_type,
		description)
	VALUES 
		('internal-nets', 'service',
		'places to launch internal facing hosts'),
		('dmz-nets', 'service',
		'places to launch dmzish hosts')
	;
EXCEPTION WHEN unique_violation THEN
	NULL;
END
$$;


DO $$
BEGIN
	INSERT INTO port_range (
		port_range_name, protocol, port_range_type,
		port_start, port_end, is_singleton
	) VALUES 
		('postgresql', 'tcp', 'services', 5432, 5432, 'Y'),
		('http', 'tcp', 'services', 80, 80, 'Y'),
		('https', 'tcp', 'services', 443, 443, 'Y'),
		('domain', 'tcp', 'services', 53, 53, 'Y'),
		('domain', 'udp', 'services', 53, 53, 'Y')
	;
EXCEPTION WHEN unique_violation THEN
	NULL;
END
$$;
