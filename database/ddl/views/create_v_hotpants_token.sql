-- Copyright (c) 2015, Todd M. Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--       http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

CREATE OR REPLACE VIEW v_hotpants_token AS
SELECT
	token_id,
	token_type,
	token_status,
	token_serial,
	token_key,
	zero_time,
	time_modulo,
	token_password,
	is_token_locked,
	token_unlock_time,
	bad_logins,
	token_sequence,
	ts.last_updated as last_updated,
	en.encryption_key_db_value,
	en.encryption_key_purpose,
	en.encryption_key_purpose_version,
	en.encryption_method
FROM	token t
	INNER JOIN token_sequence ts USING (token_id)
	LEFT JOIN encryption_key en USING (encryption_key_id)
