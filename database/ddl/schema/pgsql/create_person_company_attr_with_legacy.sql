/*
 * Copyright (c) 2019-2020 Todd Kover
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
CREATE OR REPLACE FUNCTION person_company_attr_change_after_row_hooks() RETURNS TRIGGER AS $$
DECLARE
	tally			integer;
	_pca			jazzhands_legacy.person_company_attr%ROWTYPE;
BEGIN
	BEGIN
		BEGIN
			PERFORM local_hooks.person_company_attr_change_after_row_hooks(person_company_attr_row => NEW);
		EXCEPTION WHEN undefined_function THEN
			_pca := NEW;
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

DROP TRIGGER IF EXISTS trigger_person_company_attr_change_after_row_hooks
	ON val_person_company_attr_value;
CREATE TRIGGER trigger_person_company_attr_change_after_row_hooks
	AFTER INSERT OR UPDATE
	ON val_person_company_attr_value
	FOR EACH ROW EXECUTE PROCEDURE
	person_company_attr_change_after_row_hooks();


-----------------------------------------------------------------------------
