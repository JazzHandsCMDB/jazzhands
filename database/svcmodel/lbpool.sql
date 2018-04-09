\set ON_ERROR_STOP

savepoint startlbpool;

-- rollback;
-- begin;
set search_path=cloudapi,jazzhands;

/*
 *

cleans up two problem nodes in moving the pk to lb_ip:

set constraints all deferred;
update lb_pool
set id = 901
where id = 826
and datacenter_id = 'LAX1';

update lb_node
set lb_pool_id = 901
where lb_pool_id = 826
and datacenter_id = 'LAX1';

set constraints all immediate;



 */

/*

the ones in intended have a solution, those not should probably be in a
cloud_jazz table:

XXX port ranges need to be sorted out, its just a matter of looking for a
service and using it, otherwise creating a new one.

triggers will need to exist to handle changing ports gracefully.

*/

--
-- datacenter_id should get pulled from elsewhere
CREATE TABLE cloud_jazz.lb_pool (
	datacenter_id					varchar(5) NOT NULL,
	name							varchar(255),
	service_endpoint_provider_id	int NOT NULL,
	customer_id						bigint,
	method							lb_method_enum,
	type							varchar(255) NOT NULL,
	metadata						TEXT,
	use_legacy_ssl					boolean,
	ssl_certificate					TEXT,
	ssl_key							TEXT,
	ssl_chain						TEXT,
	load_threshold_override			double precision,
	ignore_node_status				smallint,
	redirect_to						TEXT,
	created_on						timestamp without time zone,
	primary key (service_endpoint_provider_id)
);


----------------------------------------------------------------------------
--
-- stuff that should have been done already in CSIP-462
--
DELETE  FROM cloud_jazz.lb_pool_config
	WHERE pool_id in (select id from lb_pool where is_deleted = 1
			OR managed_by_api = 0);
DELETE FROM lb_node WHERE is_deleted = 1;
UPDATE cloudapi_audit.lb_node set "aud#timestamp" = deleted_on where "aud#timestamp" = now();
DELETE FROM lb_pool WHERE is_deleted = 1;
UPDATE cloudapi_audit.lb_pool set "aud#timestamp" = deleted_on where "aud#timestamp" = now();

--
-- stuff I'm just considering deleted - XXX
--
DELETE FROM lb_node where lb_pool_id IN (
	SELECT id FROM lb_pool where managed_by_api = 0
);
DELETE FROM lb_pool WHERE managed_by_api = 0;

-- ALTER TABLE lb_pool DROP is_deleted;
-- ALTER TABLE lb_pool DROP deleted_on;

----------------------------------------------------------------------------

DO $$
DECLARE
	_p		cloudapi.lb_pool%ROWTYPE;
	_name TEXT;
	_active char(1);
	_svc integer;
	sei integer;
	sepi integer;
	pr integer;
	x INTEGER;
	crt TEXT;
	key TEXT;
	chn TEXT;
	useleg boolean;
BEGIN
	FOR _p IN SELECT * FROM cloudapi.lb_pool WHERE is_deleted = 0ORDER BY id
	LOOP
		_name := _p.datacenter_id || ':' || _p.id;

		-- insert a port range
		SELECT port_range_id
			INTO pr
			FROM port_range
			WHERE port_start = _p.port
			AND port_range_type = 'services'
			AND is_singleton = 'Y';

		IF NOT FOUND THEN
			INSERT INTO port_range (
				port_range_name, protocol, port_range_type,
				port_start, port_end, is_singleton
			) VALUES (
				_p.name, 'tcp', 'lbpool',
				_p.port, _p.port, 'Y'
			) RETURNING port_range_id INTO pr;
		END IF;

		INSERT INTO service_endpoint ( port_range_id ) VALUES ( pr )
			RETURNING service_endpoint_id INTO sei;

		-- insert service_endpoint_provider
		--
		-- XX should migrate to shared_netblock_id
		WITH sepi AS (
			INSERT INTO service_endpoint_provider (
				service_endpoint_provider_id,
				service_endpoint_provider_name, service_endpoint_provider_type,
				netblock_id
			) VALUES (
				_p.id,
				_name, 'loadbalancer',
				_p.lb_ip_id
			) RETURNING *
		), spc AS (
			INSERT INTO service_endpoint_provider_collection (
				service_endpoint_provider_collection_name,
				service_endpoint_provider_collection_type
			) VALUES (
				_name,
				'per-service-endpoint-provider'
			) RETURNING *
		), i AS (
			INSERT INTO service_endpoint_provider_collection_service_endpoint_provider (
				service_endpoint_provider_collection_id,
				service_endpoint_provider_id
			) SELECT
				service_endpoint_provider_collection_id,
				service_endpoint_provider_id
			FROM spc, sepi
		), i2 AS (
			INSERT INTO service_endpoint_service_endpoint_provider (
				service_endpoint_id,
				service_endpoint_provider_collection_id,
				service_endpoint_relation_type
			) SELECT
				sei,
				service_endpoint_provider_collection_id,
				'direct'
			FROM spc
			RETURNING *
		) SELECT service_endpoint_provider_id
			INTO sepi
			FROM sepi;

		--
		-- XXX - need to sort out health check and how it maps to gslb.
		-- probably allows for the more rich types inside nginx?
		--
		INSERT INTO jazzhands.service_endpoint_health_check (
			service_endpoint_id, protocol,
			request_string, search_string, is_enabled
		) VALUES (
			sei, 'tcp',
			_p.request_string, _p.search_string, 'Y'
		);

		-- set some defaults, if the certificate is found, it gets
		-- overridden in the next conditional.
		useleg := true;
		crt := _p.ssl_certificate;
		key := _p.ssl_key;
		chn := _p.ssl_chain;
		IF _p.ssl_certificate IS NOT NULL THEN
			--
			-- imperfect because different certs may exist with the same
			-- private key, but since subject_key_identifer stuff is not
			-- happening..
			--
			SELECT x509_signed_certificate_id
			INTO x
			FROM jazzhands.x509_signed_certificate
			WHERE public_key = _p.ssl_certificate
			AND is_active = 'Y'
			LIMIT 1;

			IF FOUND THEN
				INSERT INTO service_endpoint_x509_certificate (
					service_endpoint_id, x509_signed_certificate_id
				) VALUES (
					sei, x
				);

				useleg := false;
				crt := NULL;
				-- true until deencryption can be dealt with
				key := _p.ssl_key;

				-- true until the mess of chains in the db is cleaned
				chn := _p.ssl_chain;
			END IF;
		END IF;


		INSERT INTO cloud_jazz.lb_pool (
			datacenter_id, name, service_endpoint_provider_id,
			customer_id, method, type, metadata,
			use_legacy_ssl,
			ssl_certificate, ssl_key, ssl_chain,
			load_threshold_override, ignore_node_status,
			redirect_to, created_on
		) VALUES (
			_p.datacenter_id, _p.name, sepi,
			_p.customer_id, _p.method, _p.type, _p.metadata,
			useleg,
			crt, key, chn,
			_p.load_threshold_override, _p.ignore_node_status,
			_p.redirect_to, _p.created_on
		);

	END LOOP;

	--SELECT schema_support.reset_table_sequence(
	--	schema := 'jazzhands',
	--	table_name := 'service_endpoint_provider'
	--);
END;
$$
;

savepoint preview;
CREATE VIEW lb_pool_new AS
SELECT
	datacenter_id,
	service_endpoint_provider_id AS id,
	name,
	netblock_id AS lb_ip_id,
	customer_id,
	port,
	method,
	request_string,
	search_string,
	type,
	metadata,
	created_on,
	ssl_certificate,
	ssl_key,
	ssl_chain,
	1::smallint AS managed_by_api,
	load_threshold_override,
	ignore_node_status,
	redirect_to,
	rnk
FROM (
SELECT
	cj.datacenter_id,
	sep.service_endpoint_provider_id,
	COALESCE(cj.name, sep.service_endpoint_provider_name) AS name,
	sep.netblock_id,
	cj.customer_id,
	pr.port_start AS port,
	cj.method,
	sehc.request_string,
	sehc.search_string,
	cj.type,
	cj.metadata,
	cj.created_on,						--- XXX
	CASE WHEN cj.use_legacy_ssl THEN cj.ssl_certificate ELSE sub.public_key
		END as ssl_certificate,
	CASE WHEN cj.use_legacy_ssl THEN cj.ssl_key ELSE cj.ssl_key END as ssl_key,
	CASE WHEN cj.use_legacy_ssl THEN cj.ssl_chain ELSE cj.ssl_chain
		END as ssl_chain,
	cj.load_threshold_override,
	cj.ignore_node_status,
	cj.redirect_to,
	rank() OVER (PARTITION BY sep.service_endpoint_provider_id, sehc.rank) AS rnk
FROM	jazzhands.service_endpoint_provider sep
	INNER JOIN service_endpoint_provider_collection_service_endpoint_provider
		USING (service_endpoint_provider_id)
	INNER JOIN service_endpoint_service_endpoint_provider
		USING (service_endpoint_provider_collection_id)
	INNER JOIN jazzhands.service_endpoint USING (service_endpoint_id)
	INNER JOIN jazzhands.port_range pr USING (port_range_id)
	INNER JOIN cloud_jazz.lb_pool cj USING (service_endpoint_provider_id)
	LEFT JOIN jazzhands.service_endpoint_health_check sehc
		USING (service_endpoint_id)
	LEFT JOIN (
		SELECT *
		FROM (
			WITH RECURSIVE r AS (
				SELECT x.x509_signed_certificate_id,
					x.x509_signed_certificate_id as my_id,
					x.signing_cert_id,
					x.public_key,
					ARRAY[x.x509_signed_certificate_id] as array_path,
					false as cycle
					FROM x509_signed_certificate x
					WHERE x.is_certificate_authority = 'Y'
				UNION
				SELECT r.x509_signed_certificate_id,
						ca.x509_signed_certificate_id as my_id,
						ca.signing_cert_id,
						concat(r.public_key || '\n' || ca.public_key),
						ca.x509_signed_certificate_id ||
							r.array_path as array_path,
						ca.x509_signed_certificate_id =
							ANY(r.array_path) as cycle
				FROM r JOIN x509_signed_certificate ca
					ON r.signing_cert_id =
						ca.x509_signed_certificate_id
					AND ca.x509_signed_certificate_id != ca.signing_cert_id
				WHERE NOT r.cycle
			) SELECT service_endpoint_id, x.public_key, pk.private_key,
				ca.public_key as chain,
				rank() OVER (PARTITION BY service_endpoint_id,
					x509_certificate_rank) AS x509rnk
			FROM jazzhands.service_endpoint_x509_certificate
				JOIN jazzhands.x509_signed_certificate x
					USING (x509_signed_certificate_id)
				LEFT JOIN jazzhands.private_key pk
					USING (private_key_id)
				LEFT JOIN r ca
					ON ca.x509_signed_certificate_id =
						x.signing_cert_id
		) nasty
		WHERE x509rnk = 1
	) sub USING (service_endpoint_id)
) q
WHERE rnk = 1
;

savepoint lbpool;
SELECT schema_support.relation_diff (
        schema := 'cloudapi',
        old_rel := 'lb_pool',
        new_rel := 'lb_pool_new',
        prikeys := ARRAY['id']
);

-----------------------------------------------------------------------------
--
-- lb_node
--
-----------------------------------------------------------------------------



DO $$
DECLARE
	_r		RECORD;
	_nin	network_interface_netblock%ROWTYPE;
	_si		service_instance.service_instance_id%TYPE;
	_pr		port_range.port_range_id%TYPE;
	_svid	jazzhands.service_version.service_version_id%TYPE;
	_name TEXT;
BEGIN
	FOR _r IN SELECT * FROM lb_node
			WHERE inet_ntoa(ip_address) IN (
				select host(ip_address)
				from netblock
				join network_interface_netblock using (netblock_id)
			)
	LOOP

		_name := _r.datacenter_id || ':' || _r.id;

		WITH s AS (
			INSERT INTO service (
				service_name, description
			) VALUES (
				_name, 'imported from ' || _name
			) RETURNING *
		) INSERT INTO service_version (
				service_id, service_type, version_name
			) SELECT service_id, 'lbnode', _name
			FROM s
		RETURNING service_version_id INTO _svid;

		-- PORT RANGE
		SELECT port_range_id
			INTO _pr
			FROM port_range
			WHERE port_start = _r.port
			AND port_range_type = 'services'
			AND is_singleton = 'Y';
		IF NOT FOUND THEN
			INSERT INTO port_range (
				port_range_name, protocol, port_range_type,
				port_start, port_end, is_singleton
			) VALUES (
				concat(_r.datacenter_id,':',_r.id), 'tcp', 'lbnode',
				_r.port, _r.port, 'Y'
			) RETURNING port_range_id INTO _pr;
		END IF;

		SELECT nin.*
			INTO _nin
			FROM network_interface_netblock nin
				JOIN netblock USING (netblock_id)
			WHERE family(ip_address) = 4
			AND host(ip_address) = inet_ntoa(_r.ip_address);

		INSERT INTO service_instance (
			device_id, netblock_id, port_range_id,
			service_endpoint_id, service_version_id
		) VALUES (
			_nin.device_id, _nin.netblock_id, _pr,
			_r.lb_pool_id, _svid
		) RETURNING service_instance_id INTO _si;

		INSERT INTO service_endpoint_provider_member (
			service_endpoint_provider_id,
			service_instance_id,
			rank,
			is_enabled
		) VALUES (
			_r.id,
			_si,
			coalesce(_r.weight, -1),
			CASE WHEN _r.active = 0 THEN 'N' ELSE 'Y' END
		);
	END LOOP;
END;
$$
;

CREATE VIEW lb_node_legacy AS
	SELECT * FROM lb_node WHERE is_deleted = 0 AND
			inet_ntoa(ip_address) IN (
				select host(ip_address)
				from netblock
				join network_interface_netblock using (netblock_id)
			)
;

CREATE VIEW lb_node_new AS
SELECT	site_code,
	sepm.service_endpoint_provider_id AS id,
	sei.service_endpoint_id AS lb_pool_id,
	inet_aton(host(ip_address)) AS ip_address,
	pr.port_start AS port,
	CASE WHEN sepm.rank = -1 THEN NULL ELSE sepm.rank END AS weight,
	CASE WHEN sepm.is_enabled = 'Y' THEN 1 ELSE 0 END AS active
FROM jazzhands.service_endpoint_provider_member sepm
	JOIN jazzhands.service_instance sei USING (service_instance_id)
	JOIN jazzhands.network_interface_netblock USING (netblock_id, device_id)
	JOIN jazzhands.netblock USING (netblock_id)
	JOIN jazzhands.device USING (device_id)
	JOIN jazzhands.port_range pr USING (port_range_id)
;

savepoint lbnode;
SELECT schema_support.relation_diff (
        schema := 'cloudapi',
        old_rel := 'lb_node_legacy',
        new_rel := 'lb_node_new',
        prikeys := ARRAY['id']
);


