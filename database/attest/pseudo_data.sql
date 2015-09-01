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

delete from property_collection_property where property_collection_id IN
	(select property_collection_id from property_collection
	 where property_collection_type = 'attestation'
	);

delete from property_collection 
	 where property_collection_type = 'attestation';

delete from val_property_collection_type
	 where property_collection_type = 'attestation';

delete from property where property_type = 'attestation';
delete from val_property where property_type = 'attestation';
delete from val_property_type where property_type = 'attestation';

/*
 * does something a bit more elaborate

WITH newptype AS (
	INSERT INTO val_property_type (
		property_type, description
	) VALUES (
		'attestation', 'properties related to regular attestation process'
	) RETURNING *
), newprops AS (
	INSERT INTO val_property (
		property_name, property_type, property_data_type
	) SELECT unnest(ARRAY['ReportAttest', 'FieldAttest', 
'account_collection_membership']),
		property_type, 'string'
	FROM newptype
	RETURNING *
), newpct AS (
	INSERT INTO val_property_collection_type (
		property_collection_type, description
	) VALUES (
		'attestation', 'define elements of regular attestation process'
	) RETURNING *
), newpc AS (
	INSERT INTO property_collection (
		property_collection_name, property_collection_type
	) SELECT 'ReportingAttestation', property_collection_type
	FROM newpct
	RETURNING *
), propcollprop AS (
	INSERT INTO property_collection_property (
		property_collection_id, property_name, property_type
	) SELECT property_collection_id, property_name, property_type
	FROM newpc, newprops
	RETURNING *
), backtrackchain as (
	INSERT INTO approval_process_chain ( 
		approval_process_chain_name, approving_entity, description, 
			refresh_all_data
	) VALUES (
		'Recertification', 'recertify', 'Changes sent to Jira', 'Y')
	RETURNING *
), jirachain as (
	INSERT into approval_process_chain (
		approval_process_chain_name,
		approving_entity, 
		description,
		accept_approval_process_chain_id,
		reject_approval_process_chain_id )
	SELECT 
		'Jira HR Project',
		'jira-hr', 
		'Changes sent to Jira ',
		c.approval_process_chain_id,
		r.approval_process_chain_id
	FROM backtrackchain c, backtrackchain r
	RETURNING *
), chain2 as (
	INSERT into approval_process_chain ( 
		approval_process_chain_name, approving_entity, description
	) values (
		'Manager Approval',
		'manager',
		'Approve organizational info approved by your direct report'
	) RETURNING *
), chain as (
	INSERT into approval_process_chain (
		approval_process_chain_name,
		approving_entity, 
		description,
		accept_approval_process_chain_id,
		reject_approval_process_chain_id )
	SELECT 
		'Reporting Attestation',
		'manager',
		'Approve your direct reports, their title and functional team',
		c.approval_process_chain_id,
		r.approval_process_chain_id
	FROM chain2 c, jirachain r
	RETURNING *
), process as  (
	INSERT INTO approval_process (
		first_approval_process_chain_id,
		approval_process_name,
		approval_process_type,
		approval_response_period,
		approval_expiration_action,
		attestation_frequency,
		attestation_offset,
		description,
		property_collection_id
	) SELECT approval_process_chain_id, 
		'ReportingAttest',
		'attestation',
		'1 week',
		'pester',
		'quarterly',
		0,
		'Company Wide Quarterly certification direct reports and thier information',
		property_collection_id
		FROM newpc, chain
	RETURNING *
) select * FROM process
;

*/

-- simple approval and possible jira integration

WITH newptype AS (
	INSERT INTO val_property_type (
		property_type, description
	) VALUES (
		'attestation', 'properties related to regular attestation process'
	) RETURNING *
), newprops AS (
	INSERT INTO val_property (
		property_name, property_type, property_data_type
	) SELECT unnest(ARRAY['ReportAttest', 'FieldAttest', 
'account_collection_membership']),
		property_type, 'string'
	FROM newptype
	RETURNING *
), newpct AS (
	INSERT INTO val_property_collection_type (
		property_collection_type, description
	) VALUES (
		'attestation', 'define elements of regular attestation process'
	) RETURNING *
), newpc AS (
	INSERT INTO property_collection (
		property_collection_name, property_collection_type
	) SELECT 'ReportingAttestation', property_collection_type
	FROM newpct
	RETURNING *
), propcollprop AS (
	INSERT INTO property_collection_property (
		property_collection_id, property_name, property_type
	) SELECT property_collection_id, property_name, property_type
	FROM newpc, newprops
	RETURNING *
), backtrackchain as (
	INSERT INTO approval_process_chain ( 
		approval_process_chain_name, approving_entity, description, 
			refresh_all_data,message
	) VALUES (
		'Recertification', 'recertify', 'Changes sent to Jira', 'Y',
		'The organizational changes you have requsted have been completed.  Please take a minute to review them and confirm that they are correct'
	) RETURNING *
), jirachain as (
	INSERT into approval_process_chain (
		approval_process_chain_name,
		approving_entity, 
		description,
		accept_approval_process_chain_id,
		reject_approval_process_chain_id )
	SELECT 
		'Jira HR Project',
		'jira-hr', 
		'Changes sent to Jira ',
		c.approval_process_chain_id,
		r.approval_process_chain_id
	FROM backtrackchain c, backtrackchain r
	RETURNING *
), chain as (
	INSERT into approval_process_chain (
		approval_process_chain_name,
		approving_entity, 
		description,
		message,
		accept_approval_process_chain_id,
		reject_approval_process_chain_id )
	SELECT 
		'Reporting Attestation',
		'manager',
		'Approve your direct reports, their title and functional team',
		'At AppNexus, we use organizational data to drive many automated
		processes, such as access to resources (servers,
		databases, file shares, wiki pages, etc), accounting
		approvals, and more.  In order to ensure we are relying
		on correct data, we ask that each manager certify the
		accuracy of their team''s information in HR on a quarterly
		basis.  Specifically, we ask that you confirm that you
		are still the manager for all of the people listed as reporting
		to you, as well as the title and functional team for each.
		This process is important for corporate security and is
		a key control that is verified in many audits.
		This review should take a maximum of five minutes, most 
		likely less than a minute.
		',
		NULL,
		r.approval_process_chain_id
	FROM jirachain r
	RETURNING *
), process as  (
	INSERT INTO approval_process (
		first_approval_process_chain_id,
		approval_process_name,
		approval_process_type,
		approval_expiration_action,
		attestation_frequency,
		attestation_offset,
		description,
		property_collection_id
	) SELECT approval_process_chain_id, 
		'ReportingAttest',
		'attestation',
		'pester',
		'quarterly',
		0,
		'Quarterly company-wide certification of direct reports and thier information',
		property_collection_id
		FROM newpc, chain
	RETURNING *
) select * FROM process
;

INSERT INTO property (
	property_name, property_type, property_value
) values
	('ReportAttest', 'attestation', 'auto_acct_coll:AutomatedDirectsAC'),
	('FieldAttest', 'attestation', 'person_company:position_title'),
	('account_collection_membership', 'attestation', 'department');
