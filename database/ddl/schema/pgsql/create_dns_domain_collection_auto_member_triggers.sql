/*
* Copyright (c) 2023 Todd Kover
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
-- Arguably these should be smarter about delaing with thinsg moving to
-- different parentage but that generally doesn't happen, so I'm ignoring
-- that case, for now.
--

CREATE OR REPLACE FUNCTION dns_domain_collection_child_automation()
RETURNS TRIGGER AS $$
DECLARE
	_r RECORD;
BEGIN

	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
		INSERT INTO dns_domain_collection_dns_domain (
			dns_domain_collection_id, dns_domain_id
		) SELECT dns_domain_collection_id, NEW.dns_domain_id
		FROM dns_domain dd
			JOIN dns_domain_collection_dns_domain ddcdd ON
				ddcdd.dns_domain_id = dd.parent_dns_domain_id
			JOIN dns_domain_collection USING (dns_domain_collection_id)
			JOIN val_dns_domain_collection_type
				USING (dns_domain_collection_type)
		WHERE dd.dns_domain_id = NEW.dns_domain_id
		AND manage_child_domains_automatically;

		RETURN NEW;
	ELSIF TG_OP = 'DELETE' THEN

		DELETE FROM dns_domain_collection_dns_domain
		WHERE (dns_domain_collection_id, dns_domain_id) IN
		(	SELECT dns_domain_collection_id, dd.dns_domain_id
			FROM dns_domain dd
				JOIN dns_domain_collection_dns_domain ddcdd ON
					ddcdd.dns_domain_id = dd.parent_dns_domain_id
				JOIN dns_domain_collection USING (dns_domain_collection_id)
				JOIN val_dns_domain_collection_type
					USING (dns_domain_collection_type)
			WHERE dd.dns_domain_id = OLD.dns_domain_id
			AND manage_child_domains_automatically
		) RETURNING * INTO _r;
		raise notice '%', to_jsonb(_r);

		RETURN OLD;
	END IF;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_domain_collection_child_automation_ins
	 ON dns_domain;
CREATE TRIGGER trigger_dns_domain_collection_child_automation_ins
	AFTER INSERT OR UPDATE OF parent_dns_domain_id
	ON dns_domain
	FOR EACH ROW
	EXECUTE PROCEDURE dns_domain_collection_child_automation();

DROP TRIGGER IF EXISTS trigger_dns_domain_collection_child_automation_del
	 ON dns_domain;
CREATE TRIGGER trigger_dns_domain_collection_child_automation_del
	BEFORE DELETE
	ON dns_domain
	FOR EACH ROW
	EXECUTE PROCEDURE dns_domain_collection_child_automation();

-----------------------------------------------------------------------------
