/*
 * Copyright (c) 2015-2020 Todd Kover
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

-----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION person_company_attribute_change_after_row_hooks() RETURNS TRIGGER AS $$
DECLARE
	tally			integer;
	_pca			jazzhands_legacy.person_company_attr%ROWTYPE;
BEGIN
	BEGIN
		BEGIN
			PERFORM local_hooks.person_company_attr_change_after_row_hooks(person_company_attr_row => NEW);
		EXCEPTION WHEN undefined_function THEN
			_pca.company_id	:= NEW.company_id;
			_pca.person_id	:= NEW.person_id;
			_pca.person_company_attr_name	:= NEW.person_company_attr_name;
			_pca.attribute_value	:= NEW.attribute_value;
			_pca.attribute_value_timestamp	:= NEW.attribute_value_timestamp;
			_pca.attribute_value_person_id	:= NEW.attribute_value_person_id;
			_pca.start_date	:= NEW.start_date;
			_pca.finish_date	:= NEW.finish_date;
			PERFORM local_hooks.person_company_attr_change_after_row_hooks(person_company_attr_row => _pca);
		END;
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;
	RETURN NULL;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_person_company_attribute_change_after_row_hooks
	ON val_person_company_attribute_value;
CREATE TRIGGER trigger_person_company_attribute_change_after_row_hooks
	AFTER INSERT OR UPDATE
	ON val_person_company_attribute_value
	FOR EACH ROW EXECUTE PROCEDURE
	person_company_attribute_change_after_row_hooks();


-----------------------------------------------------------------------------
