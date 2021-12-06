/*
 * Copyright (c) 2021 Todd Kover
 * All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

--
-- These triggers enforce that things that are direct to host can't become
-- accidentaly not direct to host.  It's possible, even probable that these
-- should be folded into other triggers, but due to time constraints did not
-- want to do that now.
--

\set ON_ERROR_STOP

/*

I think that means:
        service_endpoint
				- if direct, dns_record_id matches service_endpoint_provider
				- maybe later want a check on dns_domain_type?
        service_endpoint_service_endpoint_provider_collection
				- checks
        service_endpoint_provider_collection
				- checks, but brute force today
        service_endpoint_provider_collection_service_endpoint_provider
				- check to make upstream and downstream are single nodes
        service_endpoint_provider
				- make sure the dns record matches the endpoint
				- dns_record_id is only set on direct?
        service_endpoint_provider_service_instance
				- dns check and port ranges match (makes it 1:1)
        service_instance
				- XXX - make sure device_id maps all the way up to
				  dns_record_id/netblock/etc.  This requries more thought.

 */

CREATE OR REPLACE FUNCTION service_endpoint_direct_check()
RETURNS TRIGGER AS $$
DECLARE
	_r		RECORD;
BEGIN
	IF NEW.dns_record_id IS NOT NULL OR NEW.port_range_id IS NOT NULL THEN
		SELECT	sep.*
		INTO	_r
		FROM	service_endpoint_service_endpoint_provider_collection
				JOIN service_endpoint_provider_collection
					USING (service_endpoint_provider_collection_id)
				JOIN service_endpoint_provider_collection_service_endpoint_provider
					USING (service_endpoint_provider_collection_id)
				JOIN service_endpoint_provider sep
					USING (service_endpoint_provider_id)
		WHERE	service_endpoint_id = NEW.service_endpoint_id;

		IF FOUND THEN
			--
			-- It is possible that these don't need to match, but that use
			-- case needs to be thought through, so it is disallowed for now.
			--
			IF _r.service_endpoint_provider_type = 'direct' THEN
				IF _r.dns_record_id IS DISTINCT FROM NEW.dns_record_id THEN
					RAISE EXCEPTION 'dns_record_id of service_endpoint_provider and service_endpoint must match'
					USING ERRCODE = 'foreign_key_violation',
					HINT = 'This check may be overly agressive but applies only to diret connects';
				END IF;
				IF _r.port_range_id IS DISTINCT FROM NEW.port_range_id THEN
					RAISE EXCEPTION 'port_range_id of service_endpoint_provider and service_endpoint must match'
					USING ERRCODE = 'foreign_key_violation',
					HINT = 'This check may be overly agressive but applies only to diret connects';
				END IF;
			END IF;
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_service_endpoint_direct_check
	ON service_endpoint;
CREATE CONSTRAINT TRIGGER trigger_service_endpoint_direct_check
	AFTER INSERT OR UPDATE OF dns_record_id, port_range_id
	ON service_endpoint
	FOR EACH ROW
	EXECUTE PROCEDURE service_endpoint_direct_check();

-----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION svc_end_prov_svc_end_col_direct_check()
RETURNS TRIGGER AS $$
BEGIN
	-- At the moment, no checks "up" to service_endpoint
	--
	-- sanity checks for things to match
	--
	IF NEW.service_endpoint_relation_type = 'direct' THEN
		IF NEW.service_endpoint_relation_key != 'none' THEN
			RAISE EXCEPTION 'direct must have a key of none'
			USING ERRCODE = 'invalid_parameter_value',
			HINT = 'direct-to-host service configuration is very particular';
		END IF;

		PERFORM *
		FROM service_endpoint_provider_collection
		WHERE service_endpoint_provider_collection_type =
			'per-service-endpoint-provider'
		AND service_endpoint_provider_collection_id =
			NEW.service_endpoint_provider_collection_id;

		IF NOT FOUND THEN
			RAISE EXCEPTION 'direct must point to a service_collection_type of per-service-endpoint-provider'
			USING ERRCODE = 'foreign_key_violation',
			HINT = 'direct-to-host service configuration is very particular';
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_svc_end_prov_svc_end_col_direct_check
	ON service_endpoint_service_endpoint_provider_collection;
CREATE CONSTRAINT TRIGGER trigger_svc_end_prov_svc_end_col_direct_check
	AFTER INSERT OR UPDATE OF
		service_endpoint_provider_collection_id,
		service_endpoint_relation_type,
		service_endpoint_relation_key
	ON service_endpoint_service_endpoint_provider_collection
	FOR EACH ROW
	EXECUTE PROCEDURE svc_end_prov_svc_end_col_direct_check();

-----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION svc_ep_svc_epp_coll_direct()
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.service_endpoint_relation_type = 'per-service-endpoint-provider' THEN
		IF NEW.service_endpoint_relation_key != 'none' THEN
			RAISE EXCEPTION 'per-service-endpoint-provider is immutable because of direct connection'
			USING ERRCODE = 'invalid_parameter_value',
			HINT = 'This check should be smarter';
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_svc_ep_svc_epp_coll_direct
	ON service_endpoint_service_endpoint_provider_collection;
CREATE CONSTRAINT TRIGGER trigger_svc_ep_svc_epp_coll_direct
	AFTER INSERT OR UPDATE OF service_endpoint_relation_type,
		service_endpoint_relation_key
	ON service_endpoint_service_endpoint_provider_collection
	FOR EACH ROW
	EXECUTE PROCEDURE svc_ep_svc_epp_coll_direct();

-----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION svc_ep_coll_sep_direct_check()
RETURNS TRIGGER AS $$
DECLARE
	_coltype	TEXT;
	_septype	TEXT;
BEGIN

	SELECT service_endpoint_provider_collection_type
	INTO _coltype
	FROM service_endpoint_provider_collection
	WHERE service_endpoint_provider_collection_id =
		NEW.service_endpoint_provider_collection_id;

	SELECT service_endpoint_provider_type
	INTO _septype
	FROM service_endpoint_provider
	WHERE service_endpoint_provider_id =
		NEW.service_endpoint_provider_id;

	IF _septype = 'direct' AND _coltype != 'per-service-endpoint-provider' THEN
		RAISE EXCEPTION 'direct providers must have an upstream collection of per-service-endpoint-provider type'
		USING ERRCODE = 'invalid_parameter_value',
		HINT = 'This check should be smarter';
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_svc_ep_coll_sep_direct_check
	ON service_endpoint_provider_collection_service_endpoint_provider;
CREATE CONSTRAINT TRIGGER trigger_svc_ep_coll_sep_direct_check
	AFTER INSERT OR UPDATE OF
			service_endpoint_provider_collection_id,
			service_endpoint_provider_id
	ON service_endpoint_provider_collection_service_endpoint_provider
	FOR EACH ROW
	EXECUTE PROCEDURE svc_ep_coll_sep_direct_check();

-----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION service_endpoint_provider_direct_check()
RETURNS TRIGGER AS $$
DECLARE
	_r		RECORD;
BEGIN
	IF NEW.service_endpoint_provider_type = 'direct' THEN
		IF NEW.dns_record_id IS NOT NULL THEN
			SELECT	se.*
			INTO	_r
			FROM	service_endpoint se
					JOIN service_endpoint_service_endpoint_provider_collection
						USING (service_endpoint_id)
					JOIN service_endpoint_provider_collection
						USING (service_endpoint_provider_collection_id)
					JOIN service_endpoint_provider_collection_service_endpoint_provider
						USING (service_endpoint_provider_collection_id)
			WHERE	service_endpoint_provider_id =
				NEW.service_endpoint_provider_id;

			IF FOUND THEN
				--
				-- It is possible that these don't need to match, but that use
				-- case needs to be thought through, so it is disallowed for now.
				--
				IF _r.dns_record_id IS DISTINCT FROM NEW.dns_record_id THEN
					RAISE EXCEPTION 'dns_record_id of service_endpoint_provider and service_endpoint must match (% %', _r.dns_record_id, NEW.dns_record_id
					USING ERRCODE = 'foreign_key_violation',
					HINT = 'This check may be overly agressive but applies only to direct connects';
				END IF;
				IF _r.port_range_id IS DISTINCT FROM NEW.port_range_id THEN
					RAISE EXCEPTION 'port_range of service_endpoint_provider and service_endpoint must match'
					USING ERRCODE = 'foreign_key_violation',
					HINT = 'This check may be overly agressive but applies only to diret connects';
				END IF;
			END IF;
		END IF;
	-- This doesn't work right with cname failver in gtm, so commenting out,
	-- but it's possible it needs to be rethought.
	-- ELSIF NEW.dns_record_id IS NOT NULL THEN
	--	RAISE EXCEPTION 'direct providers must have their dns record in sync with their endpoint'
	--	USING ERRCODE = 'foreign_key_violation',
	--	HINT = 'This check may be overly agressive';
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_service_endpoint_provider_direct_check
	ON service_endpoint_provider;
CREATE CONSTRAINT TRIGGER trigger_service_endpoint_provider_direct_check
	AFTER INSERT OR UPDATE OF service_endpoint_provider_type, dns_record_id
	ON service_endpoint_provider
	FOR EACH ROW
	EXECUTE PROCEDURE service_endpoint_provider_direct_check();

-----------------------------------------------------------------------------

