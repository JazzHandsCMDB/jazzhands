/*
 * Copyright (c) 2016 Todd Kover
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


CREATE OR REPLACE FUNCTION account_status_per_row_after_hooks()
RETURNS TRIGGER AS $$
DECLARE
	_al	jazzhands_legacy.account%ROWTYPE;
BEGIN
	BEGIN
		BEGIN
			PERFORM local_hooks.account_status_per_row_after_hooks(account_record => NEW);
		EXCEPTION WHEN undefined_function THEN
			_al.account_id := NEW.account_id;
			_al.login := NEW.login;
			_al.person_id := NEW.person_id;
			_al.company_id := NEW.company_id;
			_al.is_enabled := CASE WHEN NEW.is_enabled THEN 'Y' ELSE 'N' END;
			_al.account_realm_id := NEW.account_realm_id;
			_al.account_status := NEW.account_status;
			_al.account_role := NEW.account_role;
			_al.account_type := NEW.account_type;
			_al.description := NEW.description;
			_al.external_id := NEW.external_id;

			PERFORM local_hooks.account_status_per_row_after_hooks(account_record => _al);
		END;
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;
	RETURN NULL;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=jazzhands;

DROP TRIGGER IF EXISTS trigger_account_status_per_row_after_hooks
	ON account;
CREATE TRIGGER trigger_account_status_per_row_after_hooks
AFTER UPDATE of account_status
	ON account
	FOR EACH ROW EXECUTE PROCEDURE account_status_per_row_after_hooks();

