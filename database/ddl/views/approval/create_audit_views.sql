-- Copyright (c) 2015-2023, Todd M. Kover
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


CREATE OR REPLACE VIEW approval_utils.v_account_collection_account_audit_map AS
SELECT "aud#seq" as audit_seq_id, *
FROM  (
	SELECT acaa.account_collection_id, acaa.account_id, acaa.account_collection_relation,
		 acaa.account_id_rank, acaa.start_date, acaa.finish_date, "aud#seq",
		row_number() OVER
		(partition BY account_collection_id,account_id ORDER BY
		"aud#seq" desc) as rownum
	FROM    account_collection_account aca
		JOIN jazzhands_audit.account_collection_account acaa
			USING (account_collection_id, account_id)
	WHERE "aud#action" in ('UPD', 'INS')
) all_audrecs
WHERE rownum = 1;

CREATE OR REPLACE VIEW approval_utils.v_person_company_audit_map AS
SELECT "aud#seq" as audit_seq_id, *
FROM  (
	SELECT pca.company_id, pca.person_id, pca.person_company_status, pca.person_company_relation, pca.is_exempt, pca.is_management, pca.is_full_time, pca.description, pca.position_title, pca.hire_date, pca.termination_date, pca.manager_person_id, pca.nickname, "aud#seq",
		row_number() OVER
		(partition BY person_id,company_id ORDER BY
		"aud#seq" desc) as rownum
	FROM    person_company pc
		JOIN jazzhands_audit.person_company pca
			USING (person_id, company_id)
	WHERE "aud#action" in ('UPD', 'INS')
	) all_audrecs
WHERE rownum = 1;
