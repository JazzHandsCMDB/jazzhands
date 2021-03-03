/*
* Copyright (c) 2014 Todd Kover
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
-- $HeadURL$
-- $Id$
--

CREATE OR REPLACE FUNCTION dns_domain_collection_hier_enforce()
RETURNS TRIGGER AS $$
DECLARE
	dct	val_dns_domain_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	dct
	FROM	val_dns_domain_collection_type
	WHERE	dns_domain_collection_type =
		(select dns_domain_collection_type from dns_domain_collection
			where dns_domain_collection_id = NEW.dns_domain_collection_id);

	IF dct.can_have_hierarchy = false THEN
		RAISE EXCEPTION 'DNS Domain Collections of type % may not be hierarcical',
			dct.dns_domain_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_domain_collection_hier_enforce
	 ON dns_domain_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_dns_domain_collection_hier_enforce
        AFTER INSERT OR UPDATE
        ON dns_domain_collection_hier
		DEFERRABLE INITIALLY IMMEDIATE
        FOR EACH ROW
        EXECUTE PROCEDURE dns_domain_collection_hier_enforce();


-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION dns_domain_collection_member_enforce()
RETURNS TRIGGER AS $$
DECLARE
	dct	val_dns_domain_collection_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	dct
	FROM	val_dns_domain_collection_type
	WHERE	dns_domain_collection_type =
		(select dns_domain_collection_type from dns_domain_collection
			where dns_domain_collection_id = NEW.dns_domain_collection_id);

	IF dct.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from dns_domain_collection_dns_domain
		  where dns_domain_collection_id = NEW.dns_domain_collection_id;
		IF tally > dct.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF dct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from dns_domain_collection_dns_domain
		  		inner join dns_domain_collection using (dns_domain_collection_id)
		  where dns_domain_id = NEW.dns_domain_id
		  and	dns_domain_collection_type = dct.dns_domain_collection_type;
		IF tally > dct.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'DNS Domain may not be a member of more than % collections of type %',
				dct.MAX_NUM_COLLECTIONS, dct.dns_domain_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_domain_collection_member_enforce
	 ON dns_domain_collection_dns_domain;
CREATE CONSTRAINT TRIGGER trigger_dns_domain_collection_member_enforce
        AFTER INSERT OR UPDATE
        ON dns_domain_collection_dns_domain
		DEFERRABLE INITIALLY IMMEDIATE
        FOR EACH ROW
        EXECUTE PROCEDURE dns_domain_collection_member_enforce();
