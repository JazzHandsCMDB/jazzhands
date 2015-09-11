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


CREATE OR REPLACE VIEW v_account_collection_account_audit_map AS
WITH all_audrecs AS (
    select acaa.*,
	row_number() OVER
	    (partition BY account_collection_id,account_id ORDER BY
	    "aud#timestamp" desc) as rownum
    from    account_collection_account aca
	join audit.account_collection_account acaa
	    using (account_collection_id, account_id)
    where "aud#action" in ('UPD', 'INS')
) SELECT "aud#seq" as audit_seq_id, * from all_audrecs WHERE rownum = 1;

CREATE OR REPLACE VIEW v_person_company_audit_map AS
WITH all_audrecs AS (
    select pca.*,
	row_number() OVER
	    (partition BY person_id,company_id ORDER BY
	    "aud#timestamp" desc) as rownum
    from    person_company pc
	join audit.person_company pca
	    using (person_id, company_id)
    where "aud#action" in ('UPD', 'INS')
) SELECT "aud#seq" as audit_seq_id, * from all_audrecs WHERE rownum = 1;

