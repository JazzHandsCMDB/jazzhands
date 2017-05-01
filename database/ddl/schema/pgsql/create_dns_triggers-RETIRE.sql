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
-- This goes away once vearious tools become up universe aware and this view
-- can go away
--
CREATE OR REPLACE FUNCTION dns_domain_nouniverse_del()
RETURNS TRIGGER AS $$
BEGIN;
	RAISE EXCEPTION 'Need to write this trigger.';
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
	EXECUTE PROCEDURE dns_domain_soa_name_retire();
