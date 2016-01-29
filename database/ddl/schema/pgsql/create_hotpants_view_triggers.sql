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

CREATE OR REPLACE FUNCTION upd_v_hotpants_token()
RETURNS TRIGGER AS $$
DECLARE
	acct_realm_id	account_realm.account_realm_id%TYPE;
BEGIN
	IF OLD.token_sequence != NEW.token_sequence THEN
		PERFORM token_utils.set_sequence(
			p_token_id := NEW.token_id,
			p_token_sequence := NEW.token_sequence,
			p_reset_time := NEW.last_updated
		);
	END IF;

	IF OLD.bad_logins != NEW.bad_logins THEN
		PERFORM token_utils.set_lock_status(
			p_token_id := NEW.token_id,
			p_lock_status := NEW.is_token_locked,
			p_unlock_time := NEW.token_unlock_time,
			p_bad_logins := NEW.bad_logins,
			p_last_updated :=NEW.last_updated
		);
	END IF;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_upd_v_hotpants_token
INSTEAD OF UPDATE ON v_hotpants_token
FOR EACH ROW EXECUTE PROCEDURE upd_v_hotpants_token();

-- --------------------------------------------------------------------------
