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

--


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
	_s		service%ROWTYPE;
	_sv		service_version%ROWTYPE;
	_si		service_instance%ROWTYPE;
	_send		service_endpoint%ROWTYPE;
	_senv		service_endpoint%ROWTYPE;
	_sep	service_endpoint_provider%ROWTYPE;
	_sepc	service_endpoint_provider_collection%ROWTYPE;
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
