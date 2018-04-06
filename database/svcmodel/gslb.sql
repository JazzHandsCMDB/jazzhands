\set ON_ERROR_STOP
\set ECHO queries
rollback;
begin;
set search_path=cloudapi,jazzhands;



/*

 cloudapi | gslb_name_gslb_group

These two need to be considered after the configuration data is done.  They
are not presently restored in a default dev db.

 cloudapi | gslb_resource_state
 cloudapi | gslb_resource_state_log

*/

CREATE TABLE cloud_jazz.gslb_zone (
	dns_domain_Id	integer,
	customer_id		integer,
	metadata		TEXT,
	primary key (dns_domain_id)
);

CREATE TABLE cloud_jazz.gslb_name (
	service_endpoint_id	INTEGER,
	metadata						TEXT,
	ttl								INTEGER,
	PRIMARY KEY (service_endpoint_id)
);

CREATE TABLE cloud_jazz.gslb_group (
	service_endpoint_provider_collection_id		INTEGER,
	customer_Id									INTEGER,
	metadata									TEXT,
	PRIMARY KEY (service_endpoint_provider_collection_id)
);

----------------------------------------------------------------------------
--
-- stuff that needs to be cleaned up
--
-- XXX NOTE: Some zones were deleted and recreated and that needs to be handled
-- correctlyish, _including_ renumbering of zones.
--
--
-- also figure out how to deal with things that appear in both regular domains
-- and gslb (such as devnxs.net).
--

DELETE FROM gslb_ip_address WHERE gslb_group_id IN
	(SELECT id FROM gslb_group WHERE is_deleted = 1);

DELETE FROM gslb_group WHERE is_deleted = 1;

DELETE FROM gslb_name WHERE is_deleted = 1;

DELETE FROM gslb_zone WHERE is_deleted = 1;

DELETE FROM gslb_ip_address WHERE gslb_group_id
	NOT IN (SELECT gslb_group_id FROM gslb_name_gslb_group );

DELETE FROM gslb_group WHERE id
	NOT IN (SELECT gslb_group_id FROM gslb_name_gslb_group );

--
-- Probably need to think about this
--
DELETE FROM gslb_ip_address
WHERE gslb_group_id NOT IN
	(select gslb_group_id FROM gslb_name_gslb_group);
DELETE FROM gslb_group
WHERE id NOT IN
	(select gslb_group_id FROM gslb_name_gslb_group);

UPDATE gslb_group
SET name = concat(customer_id, '-', name)
WHERE name in ('prod_cq_auditor_lax1', 'prod_cq_auditor_nym2');

select name, count(*) from gslb_group where is_deleted = 0 group by name having count(*) > 1;

savepoint cleanup;

----------------------------------------------------------------------------

--- XXX need an enforced "can_generate" on this, I think.
INSERT INTO val_dns_domain_type (
	dns_domain_type, description
) VALUES (
	'gslb', 'domain used for gslb'
);

INSERT INTO jazzhands.val_netblock_type (
	netblock_type, description, db_forced_hierarchy, is_validated_hierarchy
) VALUES (
	'gslb', 'gslb related stragglers', 'N', 'N'
);

----------------------------------------------------------------------------

--
-- gslb_zone -> dns_domain
--
DO $$
DECLARE
	myrole	TEXT;
	_t		INTEGER;
BEGIN
	SELECT current_role INTO myrole;
	SET role = dba;

	SET constraints ALL deferred;
	ALTER TABLE jazzhands.dns_domain DISABLE TRIGGER trig_userlog_dns_domain;
	ALTER TABLE gslb_name DROP CONSTRAINT gslb_name_gslb_zone_id_fkey;
	ALTER TABLE gslb_zone DROP CONSTRAINT gslb_zone_pkey;

	WITH gzone AS (
		SELECT *,
		row_number() OVER (ORDER BY id) AS rn
		FROM gslb_zone ORDER BY id
	), newdoms AS (
		INSERT INTO dns_domain (
			dns_domain_name, dns_domain_type, description,
			data_ins_user, data_ins_date
		) SELECT zone, 'gslb', description, myrole, created_on
		FROM gzone
		ORDER BY id
		RETURNING *
	), newrn AS (
		SELECT *,
		row_number() OVER (ORDER BY dns_domain_id) AS rn
		FROM newdoms
	), map AS (
		SELECT dns_domain_id, id as gslb_zone_id
		FROM gzone JOIN newrn USING (rn)
	), updatezonename  AS (
		UPDATE gslb_name n
		SET gslb_zone_id = map.dns_domain_id
		FROM map WHERE map.gslb_zone_id = n.gslb_zone_id
		RETURNING *
	), updatezone AS (
		UPDATE gslb_zone z
		SET id = map.dns_domain_id
		FROM map WHERE map.gslb_zone_id = z.id
		RETURNING *
	), u as (
		select count(*) FROM updatezonename
		UNION select count(*) FROM updatezone
	) select Count(*) INTO _t FROM u;

	ALTER TABLE gslb_zone
		ADD CONSTRAINT gslb_zone_pkey
		PRIMARY KEY (id);

	ALTER TABLE gslb_name
		ADD CONSTRAINT gslb_name_gslb_zone_id_fkey
		FOREIGN KEY (gslb_zone_id)
		REFERENCES gslb_zone(id);

	SET constraints ALL IMMEDIATE;

	ALTER TABLE jazzhands.dns_domain ENABLE TRIGGER trig_userlog_dns_domain;
	EXECUTE 'SET role ' || myrole;

	INSERT INTO cloud_jazz.gslb_zone (
		dns_domain_id, customer_id, metadata
	) SELECT id, customer_id,metadata FROM gslb_zone ORDER BY id;

END;
$$
;

CREATE VIEW gslb_zone_new AS
SELECT
	dns_domain_id AS id,
	data_ins_date::timestamp without time zone AS created_on,
	dns_domain_name AS zone,
	customer_id,
	description,
	metadata
FROM	jazzhands.dns_domain
	JOIN cloud_jazz.gslb_zone USING (dns_domain_id)
WHERE dns_domain_type = 'gslb'
;

savepoint gslbzone;
SELECT schema_support.relation_diff (
	schema := 'cloudapi',
	old_rel := 'gslb_zone',
	new_rel := 'gslb_zone_new',
	prikeys := ARRAY['id']
);


--------------------------------------------------------------------------
-- gslb_group -> service_provider_collection

DO $$
DECLARE
	_r RECORD;
	_tally INTEGER;
BEGIN

	INSERT INTO cloud_jazz.gslb_group (
		service_endpoint_provider_collection_id,
		customer_id, metadata
	) SELECT id, customer_id, metadata
	FROM gslb_group
	ORDER BY id;

	INSERT INTO service_endpoint_provider_collection (
		service_endpoint_provider_collection_id,
		service_endpoint_provider_collection_name,
		service_endpoint_provider_collection_type,
		description
	) SELECT
		id,
		name,
		'gslb-group',
		description
	FROM gslb_group
	ORDER BY id;

	--
	-- Insert all CNAMEs
	--
	WITH grprn AS (
		SELECT *, row_number() OVER (ORDER BY id) AS rn
		FROM gslb_group WHERE cname IS NOT NULL ORDER BY id
	), sep AS (
		INSERT INTO service_endpoint_provider (
			service_endpoint_provider_name, service_endpoint_provider_type,
			dns_value
		) SELECT concat(name,'-cname'), 'gslb',
			cname
		FROM grprn
		ORDER BY id
		RETURNING *
	), seprn AS (
		SELECT *, row_number() OVER () AS rn
		FROM sep
	), map AS (
		SELECT grprn.id, service_endpoint_provider_id
		FROM seprn JOIN grprn USING (rn)
	), i AS (
		INSERT INTO service_endpoint_provider_collection_service_endpoint_provider (
			service_endpoint_provider_collection_id,
			service_endpoint_provider_id
		)  SELECT id, service_endpoint_provider_id
		FROM map
		RETURNING *
	) SELECT count(*) INTO _tally FROM i;

	RAISE NOTICE 'inserted % gslb cnames', _tally;

	--
	-- Now deal with all the ip addresses.
	-- first, just ones associated with netblocks and maybe devices
	--
	WITH base AS (
		SELECT gslb_group_id, inet_ntoa(g.ip_address)::Inet as ip,
			netblock_id, device_id,
		concat(gslb_group_id, '-', g.ip_address) AS  key
		FROM gslb_ip_address g
		LEFT JOIN (
			SELECT * FROM netblock where is_single_address = 'Y'
			AND netblock_type = 'default'
			) nb ON host(nb.ip_address) = inet_ntoa(g.ip_address)::text
		LEFT JOIN network_interface_netblock nin USING (netblock_id)
		WHERE netblock_id IS NOT NULL
		ORDER BY gslb_group_id, ip
	), sep AS (
		INSERT INTO service_endpoint_provider (
			service_endpoint_provider_name,
			service_endpoint_provider_type,
			netblock_id,
			device_id
		)
		SELECT
			key, 'gslb', netblock_id, device_id
		FROM base
		RETURNING *
	), i AS (
		INSERT INTO service_endpoint_provider_collection_service_endpoint_provider (
			service_endpoint_provider_collection_id,
			service_endpoint_provider_id
		) SELECT base.gslb_group_id, sep.service_endpoint_provider_id
		FROM sep JOIN base ON base.key = sep.service_endpoint_provider_name
		RETURNING *
	) SELECT count(*) INTO _tally FROM i;
	RAISE NOTICE 'inserted % gslb ip_addresses', _tally;

	--
	-- Same as above but those without netblocks
	--
	WITH base AS (
		SELECT gslb_group_id, inet_ntoa(g.ip_address)::Inet as ip,
			netblock_id, device_id,
		concat(gslb_group_id, '-', g.ip_address) AS  key
		FROM gslb_ip_address g
		LEFT JOIN (
			SELECT * FROM netblock where is_single_address = 'Y'
			AND netblock_type = 'default'
			) nb ON host(nb.ip_address) = inet_ntoa(g.ip_address)::text
		LEFT JOIN network_interface_netblock nin USING (netblock_id)
		WHERE netblock_id IS NULL
		ORDER BY gslb_group_id, ip
	), newnb AS (
		INSERT INTO netblock (
			ip_address, netblock_type, is_single_address, netblock_status
		) SELECT DISTINCT ip::inet, 'gslb', 'Y', 'Allocated'
		FROM base
		RETURNING *
	), sep AS (
		INSERT INTO service_endpoint_provider (
			service_endpoint_provider_name,
			service_endpoint_provider_type,
			netblock_id,
			device_id
		)
		SELECT
			key, 'gslb', newnb.netblock_id, device_id
		FROM base JOIN newnb ON newnb.ip_address = base.ip
		RETURNING *
	), i AS (
		INSERT INTO service_endpoint_provider_collection_service_endpoint_provider (
			service_endpoint_provider_collection_id,
			service_endpoint_provider_id
		) SELECT base.gslb_group_id, sep.service_endpoint_provider_id
		FROM base JOIN sep ON base.key = sep.service_endpoint_provider_name
		RETURNING *
	) SELECT count(*) INTO _tally FROM i;
	RAISE NOTICE 'inserted % gslb ip_addresses', _tally;

END;
$$;


CREATE VIEW gslb_group_new AS
SELECT
	service_endpoint_provider_collection_id AS id,
	service_endpoint_provider_collection_name AS name,
	cj.customer_id,
	sepc.description,
	cname.dns_value AS cname,
	cj.metadata
FROM service_endpoint_provider_collection sepc
	JOIN cloud_jazz.gslb_group cj
		USING (service_endpoint_provider_collection_id)
	LEFT JOIN (
		SELECT service_endpoint_provider_collection_id, sep.*
		FROM service_endpoint_provider sep
			JOIN service_endpoint_provider_collection_service_endpoint_provider
				sepcsep USING (service_endpoint_provider_id)
		WHERE dns_value IS NOT NULL
		AND service_endpoint_provider_type = 'gslb'
	) cname
		USING (service_endpoint_provider_collection_id)
WHERE service_endpoint_provider_collection_type = 'gslb-group'
;

savepoint gslbgroup;
SELECT schema_support.relation_diff (
	schema := 'cloudapi',
	old_rel := 'gslb_group',
	new_rel := 'gslb_group_new',
	prikeys := ARRAY['id']
);

CREATE VIEW gslb_ip_address_new AS
SELECT	service_endpoint_provider_collection_id AS gslb_group_id,
	inet_aton(host(ip_address)) as ip_address
FROM service_endpoint_provider_collection sepc
	JOIN service_endpoint_provider_collection_service_endpoint_provider
		USING (service_endpoint_provider_collection_id)
	JOIN service_endpoint_provider sep
		USING (service_endpoint_provider_id)
	JOIN netblock nb
		USING (netblock_id)
WHERE family(ip_address) = 4;

savepoint gslbipaddr;
SELECT schema_support.relation_diff (
	schema := 'cloudapi',
	old_rel := 'gslb_ip_address',
	new_rel := 'gslb_ip_address_new',
	prikeys := ARRAY['gslb_group_id', 'ip_address']
);


--------------------------------------------------------------------------
--------------------------------------------------------------------------
-- gslb_name -> service_endpoint

--
-- probably others need to be dealt with.
--
DO $$
DECLARE
	x INTEGER;
	myrole TEXT;
BEGIN
	SELECT max(service_endpoint_provider_collection_id) + 1000
	INTO x
	FROM service_endpoint_provider_collection;

	SELECT current_role INTO myrole;
	SET role = dba;

	EXECUTE 'ALTER SEQUENCE IF EXISTS service_endpoint_provider_col_service_endpoint_provider_col_seq RESTART WITH ' || x;
	EXECUTE 'SET role ' || myrole;
END;
$$;


DO $$
DECLARE
	_tally	INTEGER;
	_name	TEXT;
	_r		RECORD;
	nb		netblock.netblock_id%TYPE;
	se		service_endpoint.service_endpoint_id%TYPE;
	sep		service_endpoint_provider.service_endpoint_provider_id%TYPE;
	pr		port_range.port_range_id%TYPE;
BEGIN
	_tally = 0;
	FOR _r IN SELECT *, host(inet_ntoa(failover_ip_address)::inet) as ip FROM gslb_name
	LOOP
		_tally := _tally + 1;
		IF _tally % 50  = 0 THEN
			RAISE NOTICE 'processed % gslb_name records', _tally;
		END IF;
		SELECT port_range_id
			INTO pr
			FROM port_range
			WHERE port_start = _r.port
			AND port_range_type = 'services'
			AND is_singleton = 'Y';

		IF NOT FOUND THEN
			_name := concat(_r.domain, '-', _r.id);
			INSERT INTO port_range (
				port_range_name, protocol, port_range_type,
				port_start, port_end, is_singleton
			) VALUES (
				_name, 'tcp', 'gslb',
				_r.port, _r.port, 'Y'
			) RETURNING port_range_id INTO pr;
		END IF;
		INSERT INTO service_endpoint (
			service_endpoint_id, dns_name, dns_domain_id, port_range_id,
			description
		) VALUES (
			_r.id, _r.domain, _r.gslb_zone_id, pr,
			_r.description
		) RETURNING service_endpoint_id INTO se;

		INSERT INTO service_endpoint_health_check (
			service_endpoint_id, protocol,
			request_string, search_string
		) VALUES (
			se, _r.monitor_type,
			_r.request_string, _r.search_string
		);

		-- ddl will move to dns_record, I think.
		INSERT INTO cloud_jazz.gslb_name (
			service_endpoint_id, metadata, ttl
		) VALUES (
			se, _r.metadata, _r.ttl
		);

		IF _r.failover_ip_address IS NOT NULL THEN
			_name := concat(_r.domain, '-', _r.id || '-faiover');
			SELECT netblock_id
				INTO nb
				FROM netblock
				WHERE netblock_type IN ('default', 'gslb')
				AND is_single_address = 'Y'
				AND host(ip_address) = _r.ip
				ORDER BY netblock_type
				LIMIT 1;

			IF NOT FOUND THEN
				INSERT INTO netblock (
					ip_address, netblock_type, is_single_address,
					netblock_status
				) VALUES (
					_r.ip::inet, 'gslb', 'Y',
					'Allocated'
				) RETURNING netblock_id INTO nb;
			END IF;

			WITH p AS (
				INSERT INTO service_endpoint_provider (
					service_endpoint_provider_name,
					service_endpoint_provider_type,
					service_endpoint_id,
					netblock_id
				) VALUES (
					_name,
					'gslb',	-- for now
					se,
					nb
				) RETURNING *
			), spc AS (
				INSERT INTO service_endpoint_provider_collection (
					service_endpoint_provider_collection_name,
					service_endpoint_provider_collection_type
				) VALUES  (
					_name,
					'gslb'
				) RETURNING *
			), spcsp AS (
				INSERT INTO service_endpoint_provider_collection_service_endpoint_provider (
					service_endpoint_provider_collection_id,
					service_endpoint_provider_id
				) SELECT service_endpoint_provider_collection_id,
					service_endpoint_provider_id
				FROM spc, p
				RETURNING *
			) INSERT INTO service_endpoint_provider_service_endpoint (
				service_endpoint_provider_id,
				service_endpoint_provider_collection_id,
				service_endpoint_provider_relation
			) SELECT service_endpoint_provider_id,
					service_endpoint_provider_collection_id,
					'failover'
				FROM p, spc
			;
		ELSIF _r.failover_cname IS NOT NULL THEN
			_name := concat(_r.domain, '-', _r.id || '-faiover');
			WITH p AS (
				INSERT INTO service_endpoint_provider (
					service_endpoint_provider_name,
					service_endpoint_provider_type,
					service_endpoint_id,
					dns_value
				) VALUES (
					_name,
					'gslb',	-- for now
					se,
					_r.failover_cname
				) RETURNING *
			), spc AS (
				INSERT INTO service_endpoint_provider_collection (
					service_endpoint_provider_collection_name,
					service_endpoint_provider_collection_type
				) VALUES  (
					_name,
					'gslb'
				) RETURNING *
			), spcsp AS (
				INSERT INTO service_endpoint_provider_collection_service_endpoint_provider (
					service_endpoint_provider_collection_id,
					service_endpoint_provider_id
				) SELECT service_endpoint_provider_collection_id,
					service_endpoint_provider_id
				FROM spc, p
				RETURNING *
			) INSERT INTO service_endpoint_provider_service_endpoint (
				service_endpoint_provider_id,
				service_endpoint_provider_collection_id,
				service_endpoint_provider_relation
			) SELECT service_endpoint_provider_id,
					service_endpoint_provider_collection_id,
					'failover'
				FROM p, spc
			;
		END IF;

	END LOOP;
END;
$$;

savepoint gslbname;
CREATE VIEW gslb_name_new AS
	SELECT
			se.service_endpoint_id AS id,
			se.dns_name AS domain,
			CASE WHEN f.ip_address IS NOT NULL THEN
				inet_aton(host(f.ip_address)) ELSE NULL END AS
				failover_ip_address,
			CASE WHEN f.dns_value IS NOT NULL THEN
				dns_value ELSE NULL END AS
				failover_cname,
			hc.request_string,
			hc.search_string,
			pr.port_start,
			se.description,
			hc.protocol AS monitor_type,
			cj.metadata,
			se.dns_domain_id AS gslb_zone_id,
			cj.ttl
	FROM	service_endpoint se
		INNER JOIN cloud_jazz.gslb_name cj USING (service_endpoint_id)
		INNER JOIN port_range pr USING (port_range_id)
		INNER JOIN service_endpoint_health_check hc USING
				(service_endpoint_id)
		LEFT JOIN (
			SELECT service_endpoint_id, ip_address, dns_value
			FROM service_endpoint
				JOIN service_endpoint_provider
					USING (service_endpoint_id)
				JOIN service_endpoint_provider_service_endpoint
					USING (service_endpoint_provider_id)
				JOIN service_endpoint_provider_collection_service_endpoint_provider
					USING (service_endpoint_provider_collection_id,service_endpoint_provider_id)
				JOIN service_endpoint_provider_collection
					USING (service_endpoint_provider_collection_id)
				LEFT JOIN netblock USING (netblock_id)
			WHERE service_endpoint_provider_relation = 'failover'
		) f USING (service_endpoint_id)
;

savepoint pretest;
SELECT schema_support.relation_diff (
    schema := 'cloudapi',
    old_rel := 'gslb_name',
    new_rel := 'gslb_name_new',
    prikeys := ARRAY['id']
);

----------------------------------------------------------------------------
\set ECHO ERRORS
