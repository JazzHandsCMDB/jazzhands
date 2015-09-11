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


CREATE OR REPLACE VIEW v_account_collection_approval_process AS
WITH combo AS (
WITH foo AS (
	SELECT mm.*, mx.*
            FROM v_account_collection_audit_results mm
                INNER JOIN v_approval_matrix mx ON
                    mx.property_val_lhs = mm.account_collection_type
        ORDER BY manager_account_id, account_id
) SELECT  login,
		account_id,
		person_id,
		company_id,
		manager_account_id,
		manager_login,
		'account_collection_account'::text as audit_table,
		audit_seq_id,
		approval_process_id,
		approval_process_chain_id,
		approving_entity,
		approval_process_description,
		approval_chain_description,
		approval_response_period,
		approval_expiration_action,
		attestation_frequency,
		current_attestation_name,
		attestation_offset,
		approval_process_chain_name,
		account_collection_type as approval_category,
		concat('Verify ',account_collection_type) as approval_label,
		human_readable AS approval_lhs,
		account_collection_name as approval_rhs
FROM foo
UNION
SELECT  mm.login,
		mm.account_id,
		mm.person_id,
		mm.company_id,
		mm.manager_account_id,
		mm.manager_login,
		'account_collection_account'::text as audit_table,
		mm.audit_seq_id,
		approval_process_id,
		approval_process_chain_id,
		approving_entity,
		approval_process_description,
		approval_chain_description,
		approval_response_period,
		approval_expiration_action,
		attestation_frequency,
		current_attestation_name,
		attestation_offset,
		approval_process_chain_name,
		approval_process_name as approval_category,
		'Verify Manager' as approval_label,
		mm.human_readable AS approval_lhs,
		concat ('Reports to ',mm.manager_human_readable) AS approval_rhs	
FROM v_approval_matrix mx
	INNER JOIN property p ON
		p.property_name = mx.property_val_rhs AND
		p.property_type = mx.property_val_lhs
	INNER JOIN v_account_collection_audit_results mm ON
		mm.account_collection_id=p.property_value_account_coll_id
	WHERE p.account_id != mm.account_id
UNION
SELECT  login,
		account_id,
		person_id,
		company_id,
		manager_account_id,
		manager_login,
		'person_company'::text as audit_table,
		audit_seq_id,
		approval_process_id,
		approval_process_chain_id,
		approving_entity,
		approval_process_description,
		approval_chain_description,
		approval_response_period,
		approval_expiration_action,
		attestation_frequency,
		current_attestation_name,
		attestation_offset,
		approval_process_chain_name,
		property_val_rhs as approval_category,
		CASE 
			WHEN property_val_rhs = 'position_title' 
				THEN 'Verify Position Title'
		END as aproval_label,
		human_readable AS approval_lhs,
		CASE 
			WHEN property_val_rhs = 'position_title' THEN pcm.position_title
		END as approval_rhs
FROM	v_account_manager_map mm
		INNER JOIN v_person_company_audit_map pcm
			USING (person_id,company_id)
		INNER JOIN v_approval_matrix am
			ON property_val_lhs = 'person_company'
			AND property_val_rhs = 'position_title'
) select * from combo 
where manager_account_id != account_id
order by manager_login, account_id, approval_label
;

