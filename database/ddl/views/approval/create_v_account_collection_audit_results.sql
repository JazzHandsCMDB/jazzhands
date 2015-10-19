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


CREATE OR REPLACE VIEW approval_utils.v_account_collection_audit_results AS
WITH membermap AS (
    SELECT  aca.audit_seq_id,
	ac.account_collection_id,
	ac.account_collection_name, ac.account_collection_type,
	a.*
    FROM    v_account_manager_map a
	INNER JOIN approval_utils.v_account_collection_account_audit_map aca 
		USING (account_id)
	INNER JOIN account_collection ac USING (account_collection_id)
	WHERE a.account_id != a.manager_account_id
    ORDER BY manager_login, a.last_name, a.first_name, a.account_id
) select * from membermap ;

