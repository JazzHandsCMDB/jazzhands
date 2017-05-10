/*
 * Copyright (c) 2017 Todd Kover
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

/*
TODO:
   - deal with soa_name getting retired
*/

---------------------------------------------------------------------------
--
-- This shall replace all the aforementioned triggers
--

CREATE OR REPLACE FUNCTION dns_domain_soa_name_retire()
RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'INSERT' THEN
		IF NEW.dns_domain_name IS NOT NULL and NEW.soa_name IS NOT NULL THEN
			RAISE EXCEPTION 'Must only set dns_domain_name, not soa_name'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF NEW.soa_name IS NULL THEN
			NEW.soa_name = NEW.dns_domain_name;
		ELSIF NEW.dns_domain_name IS NULL THEN
			NEW.dns_domain_name = NEW.soa_name;
		ELSE
			RAISE EXCEPTION 'DNS DOMAIN NAME insert checker failed';
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF OLD.dns_domain_name IS DISTINCT FROM NEW.dns_domain_name AND
			OLD.soa_name IS DISTINCT FROM NEW.soa_name
		THEN
			RAISE EXCEPTION 'Must only change dns_domain_name, not soa_name'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF OLD.dns_domain_name IS DISTINCT FROM NEW.dns_domain_name THEN
			NEW.soa_name = NEW.dns_domain_name;
		ELSIF OLD.soa_name IS DISTINCT FROM NEW.soa_name THEN
			NEW.dns_domain_name = NEW.soa_name;
		END IF;
	END IF;

	-- RAISE EXCEPTION 'Need to write this trigger.';
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_domain_soa_name_retire ON dns_record;
CREATE TRIGGER trigger_dns_domain_soa_name_retire
	BEFORE INSERT OR UPDATE OF soa_name, dns_domain_name
	ON dns_domain
	FOR EACH ROW
	EXECUTE PROCEDURE dns_domain_soa_name_retire();

---------------------------------------------------------------------------
--
-- These goes away once vearious tools become up universe aware and this view
-- can go away
--
---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_domain_nouniverse_del()
RETURNS TRIGGER AS $$
BEGIN
	DELETE FROM dns_domain_ip_universe
	WHERE ip_universe_id = 0
	AND dns_domain_id = NEW.dns_domain_id;

	DELETE FROM dns_domain
	WHERE ip_universe_id = 0
	AND dns_domain_id = NEW.dns_domain_id;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_domain_nouniverse_del
	ON v_dns_domain_nouniverse;
CREATE TRIGGER trigger_dns_domain_nouniverse_del
	INSTEAD OF DELETE
	ON v_dns_domain_nouniverse
	FOR EACH ROW
	EXECUTE PROCEDURE dns_domain_nouniverse_del();

---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_domain_nouniverse_ins()
RETURNS TRIGGER AS $$
DECLARE
	_d	dns_domain.dns_domain_id%TYPE;
BEGIN
	IF NEW.dns_domain_id IS NULL THEN
		INSERT INTO dns_domain (
			dns_domain_name, dns_domain_type, parent_dns_domain_id
		) VALUES (
			NEW.soa_name, NEW.dns_domain_type, NEW.parent_dns_domain_id
		) RETURNING dns_domain_id INTO _d;
	ELSE
		INSERT INTO dns_domain (
			dns_domain_id, dns_domain_name, dns_domain_type,
			parent_dns_domain_id
		) VALUES (
			NEW.dns_domain_id, NEW.soa_name, NEW.dns_domain_type,
			NEW.parent_dns_domain_id
		) RETURNING dns_domain_id INTO _d;
	END IF;

	INSERT INTO dns_domain_ip_universe (
		dns_domain_id, ip_universe_id,
		soa_class, soa_ttl, soa_serial, soa_refresh,
		soa_retry,
		soa_expire, soa_minimum, soa_mname, soa_rname,
		should_generate, last_generated
	) VALUES (
		_d, 0,
		NEW.soa_class, NEW.soa_ttl, NEW.soa_serial, NEW.soa_refresh,
		NEW.soa_retry,
		NEW.soa_expire, NEW.soa_minimum, NEW.soa_mname, NEW.soa_rname,
		NEW.should_generate, NEW.last_generated
	);
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_domain_nouniverse_ins
	ON v_dns_domain_nouniverse;
CREATE TRIGGER trigger_dns_domain_nouniverse_ins
	INSTEAD OF INSERT
	ON v_dns_domain_nouniverse
	FOR EACH ROW
	EXECUTE PROCEDURE dns_domain_nouniverse_ins();

---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_domain_nouniverse_upd()
RETURNS TRIGGER AS
$$
DECLARE
	upd_query	TEXT[];
BEGIN
	IF OLD.dns_domain_id IS DISTINCT FROM NEW.dns_domain_id THEN
		RAISE EXCEPTION 'dns_domain_id can not be updated';
	END IF;

	upd_query := NULL;
	IF OLD.soa_name IS DISTINCT FROM NEW.soa_name THEN
		upd_query := array_append( upd_query,
			'dns_domain_id = ' || quote_nullable(NEW.soa_name));
	END IF;
	IF OLD.parent_dns_domain_id IS DISTINCT FROM NEW.parent_dns_domain_id THEN
		upd_query := array_append( upd_query,
			'dns_domain_id = ' || quote_nullable(NEW.parent_dns_domain_id));
	END IF;
	IF OLD.dns_domain_type IS DISTINCT FROM NEW.dns_domain_type THEN
		upd_query := array_append( upd_query,
			'dns_domain_id = ' || quote_nullable(NEW.dns_domain_type));
	END IF;
	IF upd_query IS NOT NULL THEN
		EXECUTE 'UPDATE dns_domain SET ' ||
			array_to_string(upd_query, ', ') ||
			' WHERE dns_domain_id = $1'
		USING
			NEW.dns_domain_id;
	END IF;

	upd_query := NULL;
	IF OLD.soa_class IS DISTINCT FROM NEW.soa_class THEN
		upd_query := array_append( upd_query,
			'soa_class = ' || quote_nullable(NEW.soa_class));
	END IF;

	upd_query := NULL;
	IF OLD.soa_ttl IS DISTINCT FROM NEW.soa_ttl THEN
		upd_query := array_append( upd_query,
			'soa_ttl = ' || quote_nullable(NEW.soa_ttl));
	END IF;

	upd_query := NULL;
	IF OLD.soa_serial IS DISTINCT FROM NEW.soa_serial THEN
		upd_query := array_append( upd_query,
			'soa_serial = ' || quote_nullable(NEW.soa_serial));
	END IF;

	upd_query := NULL;
	IF OLD.soa_refresh IS DISTINCT FROM NEW.soa_refresh THEN
		upd_query := array_append( upd_query,
			'soa_refresh = ' || quote_nullable(NEW.soa_refresh));
	END IF;

	upd_query := NULL;
	IF OLD.soa_retry IS DISTINCT FROM NEW.soa_retry THEN
		upd_query := array_append( upd_query,
			'soa_retry = ' || quote_nullable(NEW.soa_retry));
	END IF;

	upd_query := NULL;
	IF OLD.soa_expire IS DISTINCT FROM NEW.soa_expire THEN
		upd_query := array_append( upd_query,
			'soa_expire = ' || quote_nullable(NEW.soa_expire));
	END IF;

	upd_query := NULL;
	IF OLD.soa_minimum IS DISTINCT FROM NEW.soa_minimum THEN
		upd_query := array_append( upd_query,
			'soa_minimum = ' || quote_nullable(NEW.soa_minimum));
	END IF;

	upd_query := NULL;
	IF OLD.soa_mname IS DISTINCT FROM NEW.soa_mname THEN
		upd_query := array_append( upd_query,
			'soa_mname = ' || quote_nullable(NEW.soa_mname));
	END IF;

	upd_query := NULL;
	IF OLD.soa_rname IS DISTINCT FROM NEW.soa_rname THEN
		upd_query := array_append( upd_query,
			'soa_rname = ' || quote_nullable(NEW.soa_rname));
	END IF;

	upd_query := NULL;
	IF OLD.should_generate IS DISTINCT FROM NEW.should_generate THEN
		upd_query := array_append( upd_query,
			'should_generate = ' || quote_nullable(NEW.should_generate));
	END IF;

	upd_query := NULL;
	IF OLD.last_generated IS DISTINCT FROM NEW.last_generated THEN
		upd_query := array_append( upd_query,
			'last_generated = ' || quote_nullable(NEW.last_generated));
	END IF;


	IF upd_query IS NOT NULL THEN
		EXECUTE 'UPDATE dns_domain_ip_universe SET ' ||
			array_to_string(upd_query, ', ') ||
			' WHERE ip_universe_id = 0 AND dns_domain_id = $1'
		USING
			NEW.dns_domain_id;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_domain_nouniverse_upd
	ON v_dns_domain_nouniverse;
CREATE TRIGGER trigger_dns_domain_nouniverse_upd
	INSTEAD OF UPDATE
	ON v_dns_domain_nouniverse
	FOR EACH ROW
	EXECUTE PROCEDURE dns_domain_nouniverse_upd();
