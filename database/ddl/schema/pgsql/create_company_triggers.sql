/*
 * Copyright (c) 2015 Todd Kover
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


-- Manage per-company company collections.
--
-- When a company is added, updated or removed, there is a per-company
-- company-collection that goes along with it

-- XXX Need automated test cases

-- before a company is deleted, remove the per-company company collections,
-- if appropriate
CREATE OR REPLACE FUNCTION delete_per_company_company_collection()
RETURNS TRIGGER AS $$
DECLARE
	dcid			company_collection.company_collection_id%TYPE;
BEGIN
	SELECT	company_collection_id
	  FROM  company_collection
	  INTO	dcid
	 WHERE	company_collection_type = 'per-company'
	   AND	company_collection_id in
		(select company_collection_id
		 from company_collection_company
		where company_id = OLD.company_id
		)
	ORDER BY company_collection_id
	LIMIT 1;

	IF dcid IS NOT NULL THEN
		DELETE FROM company_collection_company
		WHERE company_collection_id = dcid;

		DELETE from company_collection
		WHERE company_collection_id = dcid;
	END IF;

	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_delete_per_company_company_collection ON company;
CREATE TRIGGER trigger_delete_per_company_company_collection
BEFORE DELETE
ON company
FOR EACH ROW EXECUTE PROCEDURE delete_per_company_company_collection();

------------------------------------------------------------------------------


-- On inserts and updates, ensure the per-company company collection is updated
-- correctly.
CREATE OR REPLACE FUNCTION update_per_company_company_collection()
RETURNS TRIGGER AS $$
DECLARE
	dcid		company_collection.company_collection_id%TYPE;
	newname		company_collection.company_collection_name%TYPE;
BEGIN
	IF NEW.company_name IS NOT NULL THEN
		newname = NEW.company_name || '_' || NEW.company_id;
	ELSE
		newname = 'per_d_dc_contrived_' || NEW.company_id;
	END IF;

	IF TG_OP = 'INSERT' THEN
		insert into company_collection
			(company_collection_name, company_collection_type)
		values
			(newname, 'per-company')
		RETURNING company_collection_id INTO dcid;
		insert into company_collection_company
			(company_collection_id, company_id)
		VALUES
			(dcid, NEW.company_id);
	ELSIF TG_OP = 'UPDATE'  THEN
		UPDATE	company_collection
		   SET	company_collection_name = newname
		 WHERE	company_collection_name != newname
		   AND	company_collection_type = 'per-company'
		   AND	company_collection_id in (
			SELECT	company_collection_id
			  FROM	company_collection_company
			 WHERE	company_id = NEW.company_id
			);
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_per_company_company_collection ON company;
CREATE TRIGGER trigger_update_per_company_company_collection
AFTER INSERT OR UPDATE
ON company
FOR EACH ROW EXECUTE PROCEDURE update_per_company_company_collection();


------------------------------------------------------------------------------

--
-- Only allow insertions to company via stored procedure; this is easily
-- worked around but is meant to serve as a reminder.
--
CREATE OR REPLACE FUNCTION company_insert_function_nudge()
RETURNS TRIGGER AS $$
BEGIN
	BEGIN
		IF current_setting('jazzhands.permit_company_insert') != 'permit' THEN
			RAISE EXCEPTION  'You may not directly insert into company.'
				USING ERRCODE = 'insufficient_privilege';
		END IF;
	EXCEPTION WHEN undefined_object THEN
			RAISE EXCEPTION  'You may not directly insert into company'
				USING ERRCODE = 'insufficient_privilege';
	END;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_company_insert_function_nudge ON company;
CREATE TRIGGER trigger_company_insert_function_nudge
BEFORE INSERT
ON company
FOR EACH ROW EXECUTE PROCEDURE company_insert_function_nudge();
