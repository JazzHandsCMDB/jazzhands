-- Copyright (c) 2021-2023 Todd M. Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--       http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-- Copyright (c) 2012-2014 Matthew Ragan
-- Copyright (c) 2005-2010, Vonage Holdings Corp.
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--     * Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--     * Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
-- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

/*
 * $Id$
 */

DO $$
DECLARE
        _tal INTEGER;
BEGIN
        select count(*)
        from pg_catalog.pg_namespace
        into _tal
        where nspname = 'service_manip';
        IF _tal = 0 THEN
			DROP SCHEMA IF EXISTS service_manip;
			CREATE SCHEMA service_manip AUTHORIZATION jazzhands;
			COMMENT ON SCHEMA service_manip IS 'part of jazzhands';

			REVOKE ALL on ALL FUNCTIONS IN SCHEMA service_manip FROM public;
			REVOKE ALL on SCHEMA service_manip FROM public;
			GRANT USAGE ON SCHEMA service_manip TO ro_role;
			GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA service_manip TO ro_role;
        END IF;
END;
$$;

---
--- Given an existing service_endpoint_id, create a new service endpoint
--- on the same node, given a different service_endpoint_uri_fragment and
--- either attach to the list of devices or, if NULL, look up all the existing
--- devices
---
--- service_endpoint_uri_fragment, add a new service_endpoint.  if not,
--- just add the new service_version to everything that has the same endpoint.
---
CREATE OR REPLACE FUNCTION service_manip.add_new_child_service_endpoint(
	service_endpoint_id				INTEGER,
	service_endpoint_uri_fragment	TEXT,
	service_version_id				INTEGER,
	service_environment_id			INTEGER,
	device_ids						INTEGER[] DEFAULT NULL
) RETURNS INTEGER[]
AS $$
DECLARE
	_in_service_endpoint_id		ALIAS FOR service_endpoint_id;
	_in_service_version_id		ALIAS FOR service_version_id;
	_in_service_environment_id	ALIAS FOR service_environment_id;
	_in_url_frag				ALIAS FOR service_endpoint_uri_fragment;
	_se							service_endpoint;
	_rv							INTEGER[];
	_dvs						INTEGER[];
	_sepid						INTEGER;
	_prid						INTEGER;
BEGIN
	IF service_endpoint_uri_fragment IS NULL THEN
		RAISE EXCEPTION 'must provide service_endpoint_uri_fragment'
			USING ERRCODE = 'not_null_violation';
	END IF;

	SELECT se.* INTO _se
	FROM service_endpoint se
	WHERE se.service_endpoint_uri_fragment = _in_url_frag
	AND (se.service_endpoint_id, se.dns_record_id)
		IN (
			SELECT ise.service_endpoint_id, ise.dns_record_id
			FROM service_endpoint ise
			WHERE ise.service_endpoint_id = _in_service_endpoint_id
		);

	IF NOT FOUND THEN
		INSERT INTO service_endpoint (
			service_id, dns_record_id, port_range_id, service_endpoint_uri_fragment
		) SELECT sv.service_id, se.dns_record_id, se.port_range_id, _in_url_frag
		FROM service_version sv, service_endpoint se
		WHERE sv.service_version_Id = _in_service_version_id
		AND se.service_endpoint_id = _in_service_endpoint_id
		RETURNING * INTO _se;

		INSERT INTO service_endpoint_service_endpoint_provider_collection (
			service_endpoint_id, service_endpoint_provider_collection_id,
			service_endpoint_relation_type, service_endpoint_relation_key,
			weight, maximum_capacity, is_enabled
		) SELECT _se.service_endpoint_id, service_endpoint_provider_collection_id,
			service_endpoint_relation_type, service_endpoint_relation_key,
			weight, maximum_capacity, is_enabled
		FROM service_endpoint_service_endpoint_provider_collection o
		WHERE o.service_endpoint_id = _in_service_endpoint_id;

		RAISE NOTICE 'se is %', to_jsonb(_se);
	END IF;

	_dvs := device_ids;
	IF _dvs IS NULL THEN
		SELECT service_endpoint_provider_id, se.port_range_id,
			array_agg(device_id ORDER BY device_id)
			INTO _sepid, _prid, _dvs
			FROM service_endpoint se
				JOIN service_endpoint_service_endpoint_provider_collection
					USING (service_endpoint_id)
				JOIN service_endpoint_provider_collection_service_endpoint_provider
					USING (service_endpoint_provider_collection_id)
				JOIN service_endpoint_provider
					USING (service_endpoint_provider_id)
				JOIN service_endpoint_provider_service_instance
					USING (service_endpoint_provider_id)
				JOIN service_instance USING (service_instance_id)
				JOIN service_version USING (service_version_id, service_id)
			WHERE se.service_endpoint_id = _in_service_endpoint_id
			GROUP BY 1, 2;
	RAISE NOTICE '% %', _in_service_endpoint_id, _dvs;
	END IF;


	WITH si AS (
		INSERT INTO service_instance (
			device_id, service_version_id, service_environment_id, is_primary
		) VALUES (
			unnest(_dvs), _in_service_version_id, service_environment_id, false
		) RETURNING *
	), sepsi AS (
		INSERT INTO service_endpoint_provider_service_instance (
			service_endpoint_provider_id, service_instance_id, port_range_id
		) SELECT _sepid, service_instance_id, _prid
			FROM si
			RETURNING *
	) SELECT array_agg(service_instance_id) INTO _rv FROM sepsi;

	RETURN _rv;
END
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

--
-- connects a service_endpoint to a device using set data.
-- If service_endpoint_id is SET, then the rest of the range and service
-- version are pulled from there.  If not, they and dns_record_id are
-- required.
--
-- If service_sla_id and service_environment_id are attached, then
-- linkage is created for that.
--
-- XXX: This needs to be smarter about network services requiring a dns name
-- and port range and others not, which probably means a val table change.
--
-- This creates a service_instance record and returns the id
--
CREATE OR REPLACE FUNCTION service_manip.direct_connect_endpoint_to_device(
	device_id				integer,
	service_version_id		integer,
	service_environment_id	integer,
	service_endpoint_id		integer DEFAULT NULL,
--
	port_range_id			integer DEFAULT NULL,
	dns_record_id			integer DEFAULT NULL,
--
	service_sla_id			integer DEFAULT NULL,
	is_primary			boolean DEFAULT true
)
RETURNS service_instance.service_instance_id%TYPE
AS $$
DECLARE
	_in_device_id			ALIAS FOR device_id;
	_in_service_endpoint_id	ALIAS FOR service_endpoint_id;
	_in_service_version_id	ALIAS FOR service_version_id;
	_in_port_range_id		ALIAS FOR port_range_id;
	_in_dns_record_id		ALIAS FOR dns_record_id;
	_s			service%ROWTYPE;
	_sv			service_version%ROWTYPE;
	_si			service_instance%ROWTYPE;
	_send		service_endpoint%ROWTYPE;
	_senv		service_endpoint%ROWTYPE;
	_sep		service_endpoint_provider%ROWTYPE;
	_sepc		service_endpoint_provider_collection%ROWTYPE;
BEGIN
	SELECT * INTO _sv
	FROM service_version sv
	WHERE sv.service_version_id = _in_service_version_id;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Did not find service_version'
			USING ERRCODE = 'foreign_key_violation';
	END IF;
	SELECT * INTO _s
	FROM service s
	WHERE s.service_id = _sv.service_version_id;

	IF _in_service_endpoint_id IS NOT NULL THEN
		SELECT * INTO _send
		FROM service_endpoint se
		WHERE se.service_endpoint_id = _in_service_endpoint_id;


		IF NOT FOUND THEN
			RAISE EXCEPTION 'service_endpoint_id not found'
			USING ERRCODE = 'foreign_key_violation';
		END IF;

		IF _send.service_id != _sv.service_id THEN
			RAISE EXCEPTION 'service of service_endpoint and service_version do not match'
			USING ERRCODE = 'foreign_key_violation',
			HINT = format('%s v %s', _send.service_id, _sv.service_id);
		END IF;
	ELSE
		--- XXX probably need to revisit.
		IF _in_dns_record_id IS NULL THEN
			RAISE EXCEPTION 'Need to set dns_record_id and port_range_id. This may be revisited'
				USING ERRCODE = 'not_null_violation';
		END IF;
		IF _in_port_range_id IS NULL THEN
			RAISE EXCEPTION 'Need to set port_range_id and dns_record_id. This may be revisited'
				USING ERRCODE = 'not_null_violation';
		END IF;

		INSERT INTO service_endpoint (
			service_id, dns_record_id, port_range_id
		) SELECT
			_sv.service_id, dr.dns_record_id, pr.port_range_id
		FROM port_range pr, dns_record dr
		WHERE pr.port_range_id = _in_port_range_id
		AND dr.dns_record_id = _in_dns_record_id
		RETURNING * INTO _send;
	END IF;

	IF _send IS NULL THEN
		RAISE EXCEPTION '_send is NULL.  This should not happen.';
	END IF;

	INSERT INTO service_endpoint_provider (
		service_endpoint_provider_name, service_endpoint_provider_type,
        dns_record_id
	) SELECT concat(_s.service_name, concat_ws('.', dns_name, dns_domain_name), '-', port_range_name), 'direct',
		dr.dns_record_id
	FROM    dns_record dr JOIN dns_domain dd USING (dns_domain_id),
		port_range pr
	WHERE dr.dns_record_id = _send.dns_record_id
	AND pr.port_range_id = _send.port_range_id
	RETURNING * INTO _sep;

	IF _sep IS NULL THEN
		RAISE EXCEPTION 'Failed to insert into service_endpoint_provider.  This should not happen';
	END IF;

	INSERT INTO service_endpoint_provider_collection (
		service_endpoint_provider_collection_name,
		service_endpoint_provider_collection_type
	) SELECT
		_sep.service_endpoint_provider_name,
		'per-service-endpoint-provider'
	RETURNING * INTO _sepc;

	INSERT INTO service_endpoint_service_endpoint_provider_collection (
		service_endpoint_id, service_endpoint_provider_collection_id,
		service_endpoint_relation_type
	) VALUES (
		_send.service_endpoint_id, _sepc.service_endpoint_provider_collection_id,
		'direct'
	);

	INSERT INTO service_endpoint_provider_collection_service_endpoint_provider(
		service_endpoint_provider_collection_id,
		service_endpoint_provider_id
	) VALUES (
		_sepc.service_endpoint_provider_collection_id,
		_sep.service_endpoint_provider_id
	);

	INSERT INTO service_instance (
		device_id,
		service_version_id, service_environment_id, is_primary
	) VALUES (
		_in_device_id,
		_sv.service_version_id, service_environment_id, is_primary
	) RETURNING * INTO _si;

	INSERT INTO service_endpoint_provider_service_instance (
		service_endpoint_provider_id,
		service_instance_id,
		port_range_id
	) VALUES (
		_sep.service_endpoint_provider_id,
		_si.service_instance_id,
		_send.port_range_id
	);

	-- XXX need to handle if one is set and the other is not
	IF service_sla_id IS NOT NULL AND service_environment_id IS NOT NULL
	THEN
		INSERT INTO service_endpoint_service_sla (
			service_endpoint_id, service_sla_id,
			service_environment_id
		) VALUES (
			_send.service_endpoint_id, service_sla_id,
			service_environment_id
		);
	END IF;

	RETURN _si.service_instance_id;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

---
--- delete service instances and if they're directly connected to an
--- endpoint, also purge that
---
CREATE OR REPLACE FUNCTION service_manip.remove_service_instance(
	service_instance_id				INTEGER
) RETURNS boolean AS $$
DECLARE
	_in_si_id	ALIAS FOR service_instance_id;
	_r			RECORD;
	_sep		service_endpoint_provider;
	_sepcsep	service_endpoint_provider_collection_service_endpoint_provider;
	_sesepc		service_endpoint_service_endpoint_provider_collection;
BEGIN
	FOR _r IN SELECT * FROM service_endpoint_provider_service_instance sepsi
		WHERE sepsi.service_instance_id = _in_si_id
	LOOP
		SELECT * INTO _sep FROM service_endpoint_provider sep WHERE
			sep.service_endpoint_provider_id = _r.service_endpoint_provider_id;

		DELETE FROM service_endpoint_provider_service_instance
			WHERE service_endpoint_provider_service_instance_id =
				_r.service_endpoint_provider_service_instance_id;

		DELETE FROM service_endpoint_provider_collection_service_endpoint_provider sepcsep
		WHERE sepcsep.service_endpoint_provider_id =
			_r.service_endpoint_provider_id
			AND sepcsep.service_endpoint_provider_id NOT IN (
				SELECT service_endpoint_provider_id
				FROM service_endpoint_provider_service_instance
				WHERE service_endpoint_provider_id = _r.service_endpoint_provider_id
				GROUP BY 1 HAVING count(*) > 1
			)
			RETURNING * INTO _sepcsep;

		RAISE NOTICE '%', to_json(_sepcsep);

		IF _sep.service_endpoint_provider_type = 'direct' THEN

			DELETE FROM service_endpoint_service_endpoint_provider_collection sesepc
			WHERE sesepc.service_endpoint_provider_collection_id =
				_sepcsep.service_endpoint_provider_collection_id
				RETURNING * INTO _sesepc;

			DELETE FROM service_endpoint_provider_collection
			WHERE service_endpoint_provider_collection_id =
				_sepcsep.service_endpoint_provider_collection_id;


			DELETE FROM service_endpoint_provider WHERE
				service_endpoint_provider_id = _sep.service_endpoint_provider_id;

			DELETE FROM service_endpoint_service_sla
			WHERE service_endpoint_id = _sesepc.service_endpoint_id;

			DELETE FROM service_endpoint
			WHERE service_endpoint_id = _sesepc.service_endpoint_id;
		ELSE
			--
			-- This is associated via some load balancer or other mux, so
			-- just removing membership in that.
			DELETE FROM service_endpoint_provider_service_instance  x
			WHERE x.service_endpoint_provider_id
				= _sep.service_endpoint_provider_id
			AND x.service_instance_id = _in_si_id;
		END IF;

	END LOOP;

	DELETE FROM service_instance si WHERE si.service_instance_id = _in_si_id;
	RETURN true;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

---
--- Create direct NAT service relationships from public addresses to a device.
---
CREATE OR REPLACE FUNCTION service_manip.create_direct_nat_relationship(
	device_id			device.device_id%TYPE,
	public_ip_addresses	JSONB
) RETURNS INTEGER[] AS $$
DECLARE
	_in_device_id		ALIAS FOR device_id;
	_in_addresses		ALIAS FOR public_ip_addresses;
	_device				device%ROWTYPE;
	_item				JSONB;
	_ip					INET;
	_seen_ips			TEXT[] := ARRAY[]::TEXT[];
	_service_id			service.service_id%TYPE;
	_service_version_id	service_version.service_version_id%TYPE;
	_port_range_id		port_range.port_range_id%TYPE;
	_service_instance_id	service_instance.service_instance_id%TYPE;
	_dns				JSONB;
	_dns_name			TEXT;
	_fqdn				TEXT;
	_dns_type			TEXT;
	_netblock_id		netblock.netblock_id%TYPE;
	_dns_record_id		dns_record.dns_record_id%TYPE;
	_service_endpoint_id	service_endpoint.service_endpoint_id%TYPE;
	_provider_id		service_endpoint_provider.service_endpoint_provider_id%TYPE;
	_collection_id		service_endpoint_provider_collection.service_endpoint_provider_collection_id%TYPE;
	_provider_name		TEXT;
	_candidate			TEXT;
	_counter			INTEGER;
	_return_ids			INTEGER[] := ARRAY[]::INTEGER[];
	_provider			service_endpoint_provider%ROWTYPE;
	_service_instance	service_instance%ROWTYPE;
BEGIN
	IF _in_device_id IS NULL THEN
		RAISE EXCEPTION 'device_id may not be NULL'
			USING ERRCODE = 'not_null_violation';
	END IF;

	SELECT d.* INTO _device
	FROM device d
	WHERE d.device_id = _in_device_id;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Unknown device_id %', _in_device_id
			USING ERRCODE = 'foreign_key_violation';
	END IF;

	IF _in_addresses IS NULL
		OR jsonb_typeof(_in_addresses) != 'array'
		OR jsonb_array_length(_in_addresses) = 0
	THEN
		RAISE EXCEPTION 'public_ip_addresses must be a nonempty JSON array'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	FOR _item IN
		SELECT value FROM jsonb_array_elements(_in_addresses) AS a(value)
	LOOP
		IF _item IS NULL OR jsonb_typeof(_item) != 'object' THEN
			RAISE EXCEPTION 'Each public_ip_addresses element must be an object'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF NOT (_item ? 'ip')
			OR jsonb_typeof(_item->'ip') != 'string'
			OR btrim(_item->>'ip') = ''
		THEN
			RAISE EXCEPTION 'Each public_ip_addresses element must contain a nonempty string ip'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF _item ? 'dns_name' AND (
			jsonb_typeof(_item->'dns_name') != 'string'
			OR btrim(_item->>'dns_name') = ''
		) THEN
			RAISE EXCEPTION 'dns_name must be a nonempty string when specified'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF EXISTS (
			SELECT 1
			FROM jsonb_object_keys(_item) AS k(key)
			WHERE k.key NOT IN ('ip', 'dns_name')
		) THEN
			RAISE EXCEPTION 'public_ip_addresses elements may contain only ip and dns_name'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		BEGIN
			_ip := (_item->>'ip')::INET;
		EXCEPTION WHEN invalid_text_representation THEN
			RAISE EXCEPTION '% is not a valid IP address', _item->>'ip'
				USING ERRCODE = 'invalid_parameter_value';
		END;

		IF host(_ip) = ANY(_seen_ips) THEN
			RAISE EXCEPTION 'Duplicate public IP address %', host(_ip)
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
		_seen_ips := array_append(_seen_ips, host(_ip));
	END LOOP;

	BEGIN
		SELECT s.service_id INTO STRICT _service_id
		FROM service s
		WHERE s.service_name = 'nat'
		AND s.service_type = 'network';
	EXCEPTION
		WHEN no_data_found THEN
			RAISE EXCEPTION 'The nat network service is not configured'
				USING ERRCODE = 'foreign_key_violation';
		WHEN too_many_rows THEN
			RAISE EXCEPTION 'The nat network service is ambiguous'
				USING ERRCODE = 'integrity_constraint_violation';
	END;

	BEGIN
		SELECT sv.service_version_id INTO STRICT _service_version_id
		FROM service_version sv
		WHERE sv.service_id = _service_id
		AND sv.service_type = 'network'
		AND sv.service_version_name = '1.0';
	EXCEPTION
		WHEN no_data_found THEN
			RAISE EXCEPTION 'The nat network service version 1.0 is not configured'
				USING ERRCODE = 'foreign_key_violation';
		WHEN too_many_rows THEN
			RAISE EXCEPTION 'The nat network service version 1.0 is ambiguous'
				USING ERRCODE = 'integrity_constraint_violation';
	END;

	BEGIN
		SELECT pr.port_range_id INTO STRICT _port_range_id
		FROM port_range pr
		WHERE pr.port_range_name = 'all'
		AND pr.port_range_type = 'all'
		AND pr.protocol = 'all';
	EXCEPTION
		WHEN no_data_found THEN
			RAISE EXCEPTION 'The all/all/all port range is not configured'
				USING ERRCODE = 'foreign_key_violation';
		WHEN too_many_rows THEN
			RAISE EXCEPTION 'The all/all/all port range is ambiguous'
				USING ERRCODE = 'integrity_constraint_violation';
	END;

	SELECT si.* INTO _service_instance
	FROM service_instance si
	WHERE si.device_id = _in_device_id
	AND si.service_version_id = _service_version_id;

	IF FOUND THEN
		IF _service_instance.service_environment_id !=
				_device.service_environment_id
			OR _service_instance.is_primary
		THEN
			RAISE EXCEPTION 'Existing NAT service instance for device_id % has conflicting attributes',
				_in_device_id
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
		_service_instance_id := _service_instance.service_instance_id;
	ELSE
		INSERT INTO service_instance (
			device_id, service_version_id, service_environment_id, is_primary
		) VALUES (
			_in_device_id, _service_version_id,
			_device.service_environment_id, false
		) RETURNING service_instance_id INTO _service_instance_id;
	END IF;

	FOR _item IN
		SELECT value FROM jsonb_array_elements(_in_addresses) AS a(value)
	LOOP
		_ip := (_item->>'ip')::INET;
		_fqdn := _item->>'dns_name';

		IF _fqdn IS NULL THEN
			_service_endpoint_id := NULL;
			BEGIN
				SELECT se.service_endpoint_id INTO STRICT _service_endpoint_id
				FROM service_endpoint se
					JOIN service_endpoint_service_endpoint_provider_collection sesepc
						USING (service_endpoint_id)
					JOIN service_endpoint_provider_collection_service_endpoint_provider sepcsep
						USING (service_endpoint_provider_collection_id)
					JOIN service_endpoint_provider sep
						USING (service_endpoint_provider_id)
					JOIN service_endpoint_provider_service_instance sepsi
						USING (service_endpoint_provider_id)
					JOIN netblock n ON n.netblock_id = sep.netblock_id
				WHERE se.service_id = _service_id
				AND se.port_range_id = _port_range_id
				AND se.service_environment_id = _device.service_environment_id
				AND sesepc.service_endpoint_relation_type = 'direct'
				AND sep.service_endpoint_provider_type = 'direct-nat'
				AND sepsi.service_instance_id = _service_instance_id
				AND sepsi.port_range_id = _port_range_id
				AND host(n.ip_address) = host(_ip);
			EXCEPTION
				WHEN no_data_found THEN NULL;
				WHEN too_many_rows THEN
					RAISE EXCEPTION 'Multiple direct NAT relationships exist for device_id %, IP %',
						_in_device_id, host(_ip)
						USING ERRCODE = 'integrity_constraint_violation';
			END;

			IF _service_endpoint_id IS NOT NULL THEN
				_return_ids := array_append(_return_ids, _service_endpoint_id);
				CONTINUE;
			END IF;

			IF _device.device_name IS NULL OR btrim(_device.device_name) = '' THEN
				RAISE EXCEPTION 'device_id % must have a device_name to synthesize DNS names',
					_in_device_id
					USING ERRCODE = 'invalid_parameter_value';
			END IF;

			_fqdn := NULL;
			FOR _counter IN -1..49
			LOOP
				IF _counter = -1 THEN
					_candidate := concat('public.', _device.device_name);
				ELSE
					_candidate := concat('public', _counter, '.', _device.device_name);
				END IF;

				_dns := dns_utils.find_dns_domain_from_fqdn(_candidate);
				IF _dns IS NULL THEN
					CONTINUE;
				END IF;

				PERFORM 1
				FROM dns_record dr
				WHERE dr.dns_domain_id = (_dns->>'dns_domain_id')::INTEGER
				AND dr.dns_name IS NOT DISTINCT FROM _dns->>'dns_name';

				IF NOT FOUND THEN
					_fqdn := _candidate;
					EXIT;
				END IF;
			END LOOP;

			IF _fqdn IS NULL THEN
				RAISE EXCEPTION 'Unable to synthesize an unused DNS name for device_id %',
					_in_device_id
					USING ERRCODE = 'unique_violation';
			END IF;
		END IF;

		IF length(_fqdn) > 251 THEN
			RAISE EXCEPTION 'DNS name % is too long to form a NAT provider name', _fqdn
				USING ERRCODE = 'string_data_right_truncation';
		END IF;

		_dns := dns_utils.find_dns_domain_from_fqdn(_fqdn);
		IF _dns IS NULL OR _dns->>'dns_domain_id' IS NULL THEN
			RAISE EXCEPTION 'No DNS domain found for %', _fqdn
				USING ERRCODE = 'foreign_key_violation';
		END IF;
		_dns_name := _dns->>'dns_name';

		BEGIN
			SELECT n.netblock_id INTO STRICT _netblock_id
			FROM netblock n
			WHERE n.netblock_type = 'default'
			AND n.is_single_address
			AND host(n.ip_address) = host(_ip);
		EXCEPTION
			WHEN no_data_found THEN
				INSERT INTO netblock (
					ip_address, is_single_address
				) VALUES (
					_ip, true
				) RETURNING netblock_id INTO _netblock_id;
			WHEN too_many_rows THEN
				RAISE EXCEPTION 'Multiple default single-address netblocks contain %', host(_ip)
					USING ERRCODE = 'integrity_constraint_violation';
		END;

		IF family(_ip) = 4 THEN
			_dns_type := 'A';
		ELSIF family(_ip) = 6 THEN
			_dns_type := 'AAAA';
		ELSE
			RAISE EXCEPTION 'Unknown address family for %', _ip
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		PERFORM 1
		FROM dns_record dr
		WHERE dr.netblock_id = _netblock_id
		AND (
			dr.dns_type IS DISTINCT FROM _dns_type
			OR dr.dns_name IS DISTINCT FROM _dns_name
			OR dr.dns_domain_id IS DISTINCT FROM
				(_dns->>'dns_domain_id')::INTEGER
		);
		IF FOUND THEN
			RAISE EXCEPTION 'IP address % already has another DNS record', host(_ip)
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

		BEGIN
			SELECT dr.dns_record_id INTO STRICT _dns_record_id
			FROM dns_record dr
			WHERE dr.dns_type = _dns_type
			AND dr.dns_name IS NOT DISTINCT FROM _dns_name
			AND dr.dns_domain_id = (_dns->>'dns_domain_id')::INTEGER
			AND dr.netblock_id = _netblock_id;
		EXCEPTION
			WHEN no_data_found THEN
				INSERT INTO dns_record (
					dns_name, dns_domain_id, dns_type, netblock_id
				) VALUES (
					_dns_name, (_dns->>'dns_domain_id')::INTEGER,
					_dns_type, _netblock_id
				) RETURNING dns_record_id INTO _dns_record_id;
			WHEN too_many_rows THEN
				RAISE EXCEPTION 'Multiple matching DNS records exist for % and %',
					_fqdn, host(_ip)
					USING ERRCODE = 'integrity_constraint_violation';
		END;

		_service_endpoint_id := NULL;
		BEGIN
			SELECT se.service_endpoint_id INTO STRICT _service_endpoint_id
			FROM service_endpoint se
				JOIN service_endpoint_service_endpoint_provider_collection sesepc
					USING (service_endpoint_id)
				JOIN service_endpoint_provider_collection sepc
					USING (service_endpoint_provider_collection_id)
				JOIN service_endpoint_provider_collection_service_endpoint_provider sepcsep
					USING (service_endpoint_provider_collection_id)
				JOIN service_endpoint_provider sep
					USING (service_endpoint_provider_id)
				JOIN service_endpoint_provider_service_instance sepsi
					USING (service_endpoint_provider_id)
			WHERE se.service_id = _service_id
			AND se.dns_record_id = _dns_record_id
			AND se.port_range_id = _port_range_id
			AND se.service_environment_id = _device.service_environment_id
			AND sesepc.service_endpoint_relation_type = 'direct'
			AND sepc.service_endpoint_provider_collection_type =
				'per-service-endpoint-provider'
			AND sep.service_endpoint_provider_type = 'direct-nat'
			AND sep.netblock_id = _netblock_id
			AND sepsi.service_instance_id = _service_instance_id
			AND sepsi.port_range_id = _port_range_id;
		EXCEPTION
			WHEN no_data_found THEN NULL;
			WHEN too_many_rows THEN
				RAISE EXCEPTION 'Multiple direct NAT relationships exist for device_id %, IP %',
					_in_device_id, host(_ip)
					USING ERRCODE = 'integrity_constraint_violation';
		END;

		IF _service_endpoint_id IS NOT NULL THEN
			_return_ids := array_append(_return_ids, _service_endpoint_id);
			CONTINUE;
		END IF;

		INSERT INTO service_endpoint (
			service_id, dns_record_id, port_range_id,
			service_environment_id, is_synthesized
		) VALUES (
			_service_id, _dns_record_id, _port_range_id,
			_device.service_environment_id, false
		) RETURNING service_endpoint_id INTO _service_endpoint_id;

		_provider_name := concat(_fqdn, '-nat');
		SELECT sep.* INTO _provider
		FROM service_endpoint_provider sep
		WHERE sep.service_endpoint_provider_name = _provider_name
		AND sep.service_endpoint_provider_type = 'direct-nat';

		IF FOUND THEN
			IF _provider.netblock_id IS DISTINCT FROM _netblock_id
				OR NOT _provider.is_synthesized
			THEN
				RAISE EXCEPTION 'Existing direct-nat provider % has conflicting attributes',
					_provider_name
					USING ERRCODE = 'integrity_constraint_violation';
			END IF;
			_provider_id := _provider.service_endpoint_provider_id;
		ELSE
			INSERT INTO service_endpoint_provider (
				service_endpoint_provider_name,
				service_endpoint_provider_type,
				netblock_id, is_synthesized
			) VALUES (
				_provider_name, 'direct-nat', _netblock_id, true
			) RETURNING service_endpoint_provider_id INTO _provider_id;
		END IF;

		PERFORM 1
		FROM service_endpoint_provider_service_instance sepsi
		WHERE sepsi.service_endpoint_provider_id = _provider_id
		AND sepsi.service_instance_id != _service_instance_id;
		IF FOUND THEN
			RAISE EXCEPTION 'Direct NAT provider % is attached to another service instance',
				_provider_name
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

		SELECT sepc.service_endpoint_provider_collection_id
		INTO _collection_id
		FROM service_endpoint_provider_collection sepc
		WHERE sepc.service_endpoint_provider_collection_name = _provider_name
		AND sepc.service_endpoint_provider_collection_type =
			'per-service-endpoint-provider';

		IF NOT FOUND THEN
			INSERT INTO service_endpoint_provider_collection (
				service_endpoint_provider_collection_name,
				service_endpoint_provider_collection_type
			) VALUES (
				_provider_name, 'per-service-endpoint-provider'
			) RETURNING service_endpoint_provider_collection_id
				INTO _collection_id;
		END IF;

		PERFORM 1
		FROM service_endpoint_provider_collection_service_endpoint_provider sepcsep
		WHERE sepcsep.service_endpoint_provider_collection_id = _collection_id
		AND sepcsep.service_endpoint_provider_id != _provider_id;
		IF FOUND THEN
			RAISE EXCEPTION 'Direct NAT provider collection % contains another provider',
				_provider_name
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

		PERFORM 1
		FROM service_endpoint_service_endpoint_provider_collection sesepc
		WHERE sesepc.service_endpoint_provider_collection_id = _collection_id
		AND sesepc.service_endpoint_id != _service_endpoint_id;
		IF FOUND THEN
			RAISE EXCEPTION 'Direct NAT provider collection % is attached to another endpoint',
				_provider_name
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

		INSERT INTO service_endpoint_service_endpoint_provider_collection (
			service_endpoint_id, service_endpoint_provider_collection_id,
			service_endpoint_relation_type
		) VALUES (
			_service_endpoint_id, _collection_id, 'direct'
		) ON CONFLICT DO NOTHING;

		INSERT INTO service_endpoint_provider_collection_service_endpoint_provider (
			service_endpoint_provider_collection_id, service_endpoint_provider_id
		) VALUES (
			_collection_id, _provider_id
		) ON CONFLICT DO NOTHING;

		INSERT INTO service_endpoint_provider_service_instance (
			is_enabled, service_endpoint_provider_id,
			service_instance_id, port_range_id
		) VALUES (
			true, _provider_id, _service_instance_id, _port_range_id
		) ON CONFLICT (
			service_endpoint_provider_id, service_instance_id, port_range_id
		) DO UPDATE SET is_enabled = true;

		_return_ids := array_append(_return_ids, _service_endpoint_id);
	END LOOP;

	RETURN _return_ids;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

---
--- Destroy selected or all direct NAT service relationships for a device.
---
CREATE OR REPLACE FUNCTION service_manip.destroy_direct_nat_relationship(
	device_id			device.device_id%TYPE,
	public_ip_addresses	INET[] DEFAULT NULL
) RETURNS INTEGER[] AS $$
DECLARE
	_in_device_id		ALIAS FOR device_id;
	_in_addresses		ALIAS FOR public_ip_addresses;
	_ip			INET;
	_seen_ips		TEXT[] := ARRAY[]::TEXT[];
	_endpoint_ids		INTEGER[] := ARRAY[]::INTEGER[];
	_matched_ids		INTEGER[];
	_endpoint_id		service_endpoint.service_endpoint_id%TYPE;
	_provider_id		service_endpoint_provider.service_endpoint_provider_id%TYPE;
	_collection_id		service_endpoint_provider_collection.service_endpoint_provider_collection_id%TYPE;
	_service_instance_id	service_instance.service_instance_id%TYPE;
	_dns_record_id		dns_record.dns_record_id%TYPE;
	_netblock_id		netblock.netblock_id%TYPE;
BEGIN
	IF _in_device_id IS NULL THEN
		RAISE EXCEPTION 'device_id may not be NULL'
			USING ERRCODE = 'not_null_violation';
	END IF;

	PERFORM 1 FROM device d WHERE d.device_id = _in_device_id;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Unknown device_id %', _in_device_id
			USING ERRCODE = 'foreign_key_violation';
	END IF;

	IF _in_addresses IS NOT NULL AND cardinality(_in_addresses) = 0 THEN
		RAISE EXCEPTION 'public_ip_addresses may not be empty'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF _in_addresses IS NULL THEN
		SELECT coalesce(array_agg(DISTINCT se.service_endpoint_id
			ORDER BY se.service_endpoint_id), ARRAY[]::INTEGER[])
		INTO _endpoint_ids
		FROM service_endpoint se
			JOIN service_endpoint_service_endpoint_provider_collection sesepc
				USING (service_endpoint_id)
			JOIN service_endpoint_provider_collection_service_endpoint_provider sepcsep
				USING (service_endpoint_provider_collection_id)
			JOIN service_endpoint_provider sep USING (service_endpoint_provider_id)
			JOIN service_endpoint_provider_service_instance sepsi
				USING (service_endpoint_provider_id)
			JOIN service_instance si USING (service_instance_id)
		WHERE si.device_id = _in_device_id
		AND sep.service_endpoint_provider_type = 'direct-nat'
		AND sesepc.service_endpoint_relation_type = 'direct';
	ELSE
		FOREACH _ip IN ARRAY _in_addresses
		LOOP
			IF _ip IS NULL THEN
				RAISE EXCEPTION 'public_ip_addresses may not contain NULL'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;

			IF host(_ip) = ANY(_seen_ips) THEN
				RAISE EXCEPTION 'Duplicate public IP address %', host(_ip)
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
			_seen_ips := array_append(_seen_ips, host(_ip));

			SELECT array_agg(DISTINCT se.service_endpoint_id
				ORDER BY se.service_endpoint_id)
			INTO _matched_ids
			FROM service_endpoint se
				JOIN service_endpoint_service_endpoint_provider_collection sesepc
					USING (service_endpoint_id)
				JOIN service_endpoint_provider_collection_service_endpoint_provider sepcsep
					USING (service_endpoint_provider_collection_id)
				JOIN service_endpoint_provider sep USING (service_endpoint_provider_id)
				JOIN service_endpoint_provider_service_instance sepsi
					USING (service_endpoint_provider_id)
				JOIN service_instance si USING (service_instance_id)
				JOIN netblock n ON n.netblock_id = sep.netblock_id
			WHERE si.device_id = _in_device_id
			AND sep.service_endpoint_provider_type = 'direct-nat'
			AND sesepc.service_endpoint_relation_type = 'direct'
			AND host(n.ip_address) = host(_ip);

			IF _matched_ids IS NULL THEN
				RAISE EXCEPTION 'No direct NAT relationship exists for device_id %, IP %',
					_in_device_id, host(_ip)
					USING ERRCODE = 'no_data_found';
			END IF;
			_endpoint_ids := _endpoint_ids || _matched_ids;
		END LOOP;
	END IF;

	FOREACH _endpoint_id IN ARRAY _endpoint_ids
	LOOP
		BEGIN
			SELECT sep.service_endpoint_provider_id,
				sesepc.service_endpoint_provider_collection_id,
				sepsi.service_instance_id, se.dns_record_id, sep.netblock_id
			INTO STRICT _provider_id, _collection_id,
				_service_instance_id, _dns_record_id, _netblock_id
			FROM service_endpoint se
				JOIN service_endpoint_service_endpoint_provider_collection sesepc
					USING (service_endpoint_id)
				JOIN service_endpoint_provider_collection_service_endpoint_provider sepcsep
					USING (service_endpoint_provider_collection_id)
				JOIN service_endpoint_provider sep USING (service_endpoint_provider_id)
				JOIN service_endpoint_provider_service_instance sepsi
					USING (service_endpoint_provider_id)
				JOIN service_instance si USING (service_instance_id)
			WHERE se.service_endpoint_id = _endpoint_id
			AND si.device_id = _in_device_id
			AND sep.service_endpoint_provider_type = 'direct-nat'
			AND sesepc.service_endpoint_relation_type = 'direct';
		EXCEPTION
			WHEN no_data_found THEN
				RAISE EXCEPTION 'Direct NAT relationship for service_endpoint_id % disappeared',
					_endpoint_id
					USING ERRCODE = 'no_data_found';
			WHEN too_many_rows THEN
				RAISE EXCEPTION 'Direct NAT relationship for service_endpoint_id % is ambiguous',
					_endpoint_id
					USING ERRCODE = 'integrity_constraint_violation';
		END;

		DELETE FROM service_endpoint_provider_service_instance sepsi
		WHERE sepsi.service_endpoint_provider_id = _provider_id
		AND sepsi.service_instance_id = _service_instance_id;

		DELETE FROM service_endpoint_service_endpoint_provider_collection sesepc
		WHERE sesepc.service_endpoint_id = _endpoint_id
		AND sesepc.service_endpoint_provider_collection_id = _collection_id
		AND sesepc.service_endpoint_relation_type = 'direct';

		DELETE FROM service_endpoint_provider_collection_service_endpoint_provider sepcsep
		WHERE sepcsep.service_endpoint_provider_collection_id = _collection_id
		AND sepcsep.service_endpoint_provider_id = _provider_id;

		DELETE FROM service_endpoint_provider_collection sepc
		WHERE sepc.service_endpoint_provider_collection_id = _collection_id
		AND NOT EXISTS (
			SELECT 1
			FROM service_endpoint_provider_collection_service_endpoint_provider x
			WHERE x.service_endpoint_provider_collection_id = _collection_id
		)
		AND NOT EXISTS (
			SELECT 1
			FROM service_endpoint_service_endpoint_provider_collection x
			WHERE x.service_endpoint_provider_collection_id = _collection_id
		);

		DELETE FROM service_endpoint_provider sep
		WHERE sep.service_endpoint_provider_id = _provider_id
		AND NOT EXISTS (
			SELECT 1
			FROM service_endpoint_provider_service_instance x
			WHERE x.service_endpoint_provider_id = _provider_id
		)
		AND NOT EXISTS (
			SELECT 1
			FROM service_endpoint_provider_collection_service_endpoint_provider x
			WHERE x.service_endpoint_provider_id = _provider_id
		);

		DELETE FROM service_endpoint se
		WHERE se.service_endpoint_id = _endpoint_id
		AND NOT EXISTS (
			SELECT 1
			FROM service_endpoint_service_endpoint_provider_collection x
			WHERE x.service_endpoint_id = _endpoint_id
		);

		DELETE FROM service_instance si
		WHERE si.service_instance_id = _service_instance_id
		AND NOT EXISTS (
			SELECT 1
			FROM service_endpoint_provider_service_instance x
			WHERE x.service_instance_id = _service_instance_id
		);

		BEGIN
			DELETE FROM dns_record dr
			WHERE dr.dns_record_id = _dns_record_id;
		EXCEPTION WHEN foreign_key_violation THEN NULL;
		END;

		BEGIN
			DELETE FROM netblock n
			WHERE n.netblock_id = _netblock_id;
		EXCEPTION WHEN foreign_key_violation THEN NULL;
		END;
	END LOOP;

	RETURN _endpoint_ids;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

REVOKE ALL ON SCHEMA service_manip FROM public;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA service_manip FROM public;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA service_manip TO iud_role
