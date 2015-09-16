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

CREATE OR REPLACE VIEW approval_utils.v_approval_matrix AS
SELECT	ap.approval_process_id, ap.first_apprvl_process_chain_id,
		ap.approval_process_name,
		c.approval_chain_response_period as approval_response_period,
		ap.approval_expiration_action,
		ap.attestation_frequency,
		ap.attestation_offset,
		CASE WHEN ap.attestation_frequency = 'monthly' THEN
				to_char(now(), 'YYYY-MM')
			WHEN ap.attestation_frequency = 'weekly' THEN
				concat('week ', to_char(now(), 'WW'), ' - ', 
						to_char(now(), 'YYY-MM-DD'))	
			WHEN ap.attestation_frequency = 'quarterly' THEN
				concat( to_char(now(), 'YYYY'), 'q', to_char(now(), 'Q'))
			ELSE 'unknown'
			END as current_attestation_name,
		p.property_id, p.property_name, 
		p.property_type, p.property_value,
		split_part(p.property_value, ':', 1) as property_val_lhs,
		split_part(p.property_value, ':', 2) as property_val_rhs,
		c.approval_process_chain_id, c.approving_entity,
		c.approval_process_chain_name,
		ap.description as approval_process_description,
		c.description as approval_chain_description
from	approval_process ap
		INNER JOIN property_collection pc USING (property_collection_id)
		INNER JOIN property_collection_property pcp USING (property_collection_id)
		INNER JOIN property p USING (property_name, property_type)
		LEFT JOIN approval_process_chain c
			ON c.approval_process_chain_id = ap.first_apprvl_process_chain_id
where	ap.approval_process_name = 'ReportingAttest'
and		ap.approval_process_type = 'attestation'
;

