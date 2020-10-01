/*
 * Copyright (c) 2011-2013 Matthew Ragan
 * Copyright (c) 2012-2015 Todd Kover
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

/*==============================================================*/
/* triggers and such for JazzHands PostgreSQL 9.3	       */
/*==============================================================*/


-- Since PostgreSQL does not have packages like Oracle does, we're using
-- schemas instead for namespace similarity.  Also, since PostgreSQL
-- does not have session variables, we have to use a temporary table
-- to hold our junk.  Yay.

--
-- Make sure there is only one department of type 'direct' for a given user
--

/* XXX REVISIT - there is no concept of direct/indirect members now.

CREATE OR REPLACE FUNCTION verify_direct_dept_member() RETURNS TRIGGER AS $$
BEGIN
	PERFORM count(*) FROM dept_member WHERE reporting_type = 'DIRECT'
		GROUP BY person_id HAVING count(*) > 1;
	IF FOUND THEN
		RAISE EXCEPTION 'Users may not directly report to multiple departments';
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

--
--
--

DROP TRIGGER IF EXISTS trigger_verify_direct_dept_member ON dept_member;
CREATE TRIGGER trigger_verify_direct_dept_member AFTER INSERT OR UPDATE
	ON dept_member EXECUTE PROCEDURE verify_direct_dept_member();

*/

/* XXX REVISIT

CREATE OR REPLACE FUNCTION populate_default_vendor_term() RETURNS TRIGGER AS $$
BEGIN
	-- set default termination date as the end of the following quarter
	IF (NEW.person_type = 'vendor' AND NEW.termination_date IS NULL) THEN
		NEW.termination_date := date_trunc('quarter', now()) + interval '6 months';
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;


DROP TRIGGER IF EXISTS trigger_populate_vendor_default_term ON person;
CREATE TRIGGER trigger_populate_vendor_default_term BEFORE INSERT OR UPDATE
	ON person FOR EACH ROW EXECUTE PROCEDURE populate_default_vendor_term();

*/


/*
 * enforces is_multivalue in val_person_image_usage
 *
 * Need to be ported to oracle XXX
 */
CREATE OR REPLACE FUNCTION check_person_image_usage_mv()
RETURNS TRIGGER AS $$
DECLARE
	ismv	char;
	tally	INTEGER;
BEGIN
	select  vpiu.is_multivalue, count(*)
	  into	ismv, tally
	  from  person_image pi
		inner join person_image_usage piu
			using (person_image_id)
		inner join val_person_image_usage vpiu
			using (person_image_usage)
	 where	pi.person_id in
		(select person_id from person_image
		 where person_image_id = NEW.person_image_id
		)
	  and	person_image_usage = NEW.person_image_usage
	group by vpiu.is_multivalue;

	IF ismv = false THEN
		IF tally > 1 THEN
			RAISE EXCEPTION
				'Person may only be assigned %s for one image',
				NEW.person_image_usage
			USING ERRCODE = 20705;
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_check_person_image_usage_mv ON person_image_usage;
CREATE TRIGGER trigger_check_person_image_usage_mv AFTER INSERT OR UPDATE
    ON person_image_usage
    FOR EACH ROW
    EXECUTE PROCEDURE check_person_image_usage_mv();

/*
 * deal with the insertion of images
 */

/*
 * enforces is_multivalue in val_person_image_usage
 *
 * no consideration for oracle, but probably not necessary
 */
CREATE OR REPLACE FUNCTION fix_person_image_oid_ownership()
RETURNS TRIGGER AS $$
DECLARE
   b	integer;
   str	varchar;
BEGIN
	b := NEW.image_blob;
	BEGIN
		str := 'GRANT SELECT on LARGE OBJECT ' || b || ' to picture_image_ro';
		EXECUTE str;
		str :=  'GRANT UPDATE on LARGE OBJECT ' || b || ' to picture_image_rw';
		EXECUTE str;
	EXCEPTION WHEN OTHERS THEN
		RAISE NOTICE 'Unable to grant on %', b;
	END;

	BEGIN
		EXECUTE 'ALTER large object ' || b || ' owner to jazzhands';
	EXCEPTION WHEN OTHERS THEN
		RAISE NOTICE 'Unable to adjust ownership of %', b;
	END;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY INVOKER;


DROP TRIGGER IF EXISTS trigger_fix_person_image_oid_ownership ON person_image;
CREATE TRIGGER trigger_fix_person_image_oid_ownership
BEFORE INSERT
    ON person_image
    FOR EACH ROW
    EXECUTE PROCEDURE fix_person_image_oid_ownership();


CREATE OR REPLACE FUNCTION create_new_unix_account()
RETURNS TRIGGER AS $$
DECLARE
	unix_id 		INTEGER;
	_account_collection_id 	INTEGER;
	_arid			INTEGER;
BEGIN
	--
	-- This should be a property that shows which account collections
	-- get unix accounts created by default, but the mapping of unix-groups
	-- to account collection across realms needs to be resolved
	--
	SELECT  account_realm_id
	INTO    _arid
	FROM    property
	WHERE   property_name = '_root_account_realm_id'
	AND     property_type = 'Defaults';

	IF _arid IS NOT NULL AND NEW.account_realm_id = _arid THEN
		IF NEW.person_id != 0 THEN
			PERFORM person_manip.setup_unix_account(
				in_account_id := NEW.account_id,
				in_account_type := NEW.account_type
			);
		END IF;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql
SET search_path=jazzhands
SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_create_new_unix_account ON account;
CREATE TRIGGER trigger_create_new_unix_account
AFTER INSERT
    ON account
    FOR EACH ROW
    EXECUTE PROCEDURE create_new_unix_account();


----------------------------------------------------------------------------
--
-- Enforce one and only one of logical_volume_id or component_id needing
-- to be set in physicalish_volume
--

CREATE OR REPLACE FUNCTION verify_physicalish_volume()
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.logical_volume_id IS NOT NULL AND NEW.component_Id IS NOT NULL THEN
		RAISE EXCEPTION 'One and only one of logical_volume_id or component_id must be set'
			USING ERRCODE = 'unique_violation';
	END IF;
	IF NEW.logical_volume_id IS NULL AND NEW.component_Id IS NULL THEN
		RAISE EXCEPTION 'One and only one of logical_volume_id or component_id must be set'
			USING ERRCODE = 'not_null_violation';
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_verify_physicalish_volume
	ON physicalish_volume;
CREATE TRIGGER trigger_verify_physicalish_volume
	BEFORE INSERT OR UPDATE
	ON physicalish_volume
	FOR EACH ROW
	EXECUTE PROCEDURE verify_physicalish_volume();


--
--
----------------------------------------------------------------------------

