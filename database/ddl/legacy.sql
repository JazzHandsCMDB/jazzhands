/*
 * Copyright (c) 2019-2021 Todd Kover
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
\set ON_ERROR_STOP

DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'jazzhands_legacy';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS jazzhands_legacy;
		CREATE SCHEMA jazzhands_legacy AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA jazzhands_legacy IS 'part of jazzhands';

	END IF;
END;
$$;


-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.account AS
SELECT
	account_id,
	login,
	person_id,
	company_id,
	CASE WHEN is_enabled IS NULL THEN NULL
		WHEN is_enabled = true THEN 'Y'
		WHEN is_enabled = false THEN 'N'
		ELSE NULL
	END AS is_enabled,
	account_realm_id,
	account_status,
	account_role,
	account_type,
	description,
	external_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.account;



CREATE OR REPLACE VIEW jazzhands_legacy.account_assignd_cert AS
SELECT account_id,
	x509_signed_certificate_id AS x509_cert_id,
	x509_key_usage AS x509_key_usg,
	key_usage_reason_for_assignment AS key_usage_reason_for_assign,
	data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account_assigned_certificate;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.account_auth_log AS
SELECT
	account_id,
	account_authentication_timestamp AS account_auth_ts,
	authentication_resource aS auth_resource,
	account_authentication_seq AS account_auth_seq,
	CASE WHEN was_authentication_successful IS NULL THEN NULL
		WHEN was_authentication_successful = true THEN 'Y'
		WHEN was_authentication_successful = false THEN 'N'
		ELSE NULL
	END AS was_auth_success,
	authentication_resource_instance AS auth_resource_instance,
	authentication_origin AS auth_origin,
	data_ins_date,
	data_ins_user
FROM jazzhands.account_authentication_log;



CREATE OR REPLACE VIEW jazzhands_legacy.account_coll_type_relation AS
SELECT account_collection_relation,account_collection_type,max_num_members,max_num_collections,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account_collection_type_relation;



CREATE OR REPLACE VIEW jazzhands_legacy.account_collection AS
SELECT account_collection_id,account_collection_name,account_collection_type,external_id,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account_collection;



CREATE OR REPLACE VIEW jazzhands_legacy.account_collection_account AS
SELECT account_collection_id,account_id,account_collection_relation,account_id_rank,start_date,finish_date,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account_collection_account;

CREATE OR REPLACE VIEW jazzhands_legacy.account_collection_hier AS
SELECT account_collection_id,child_account_collection_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account_collection_hier;



CREATE OR REPLACE VIEW jazzhands_legacy.account_password AS
SELECT account_id,account_realm_id,password_type,password,change_time,expire_time,unlock_time,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account_password;



CREATE OR REPLACE VIEW jazzhands_legacy.account_realm AS
SELECT account_realm_id,account_realm_name,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account_realm;



CREATE OR REPLACE VIEW jazzhands_legacy.account_realm_acct_coll_type AS
SELECT account_realm_id,account_collection_type,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account_realm_account_collection_type;



CREATE OR REPLACE VIEW jazzhands_legacy.account_realm_company AS
SELECT account_realm_id,company_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account_realm_company;



CREATE OR REPLACE VIEW jazzhands_legacy.account_realm_password_type AS
SELECT password_type,account_realm_id,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account_realm_password_type;



CREATE OR REPLACE VIEW jazzhands_legacy.account_ssh_key AS
SELECT account_id,ssh_key_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account_ssh_key;



CREATE OR REPLACE VIEW jazzhands_legacy.account_token AS
SELECT account_token_id,account_id,token_id,issued_date,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account_token;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.account_unix_info AS
SELECT
	account_id,
	unix_uid,
	unix_group_account_collection_id AS unix_group_acct_collection_id,
	shell,
	default_home,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.account_unix_info;



CREATE OR REPLACE VIEW jazzhands_legacy.appaal AS
SELECT appaal_id,appaal_name,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.appaal;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.appaal_instance AS
SELECT
	appaal_instance_id,
	appaal_id,
	service_environment_id,
	file_mode,
	file_owner_account_id,
	file_group_account_collection_id AS file_group_acct_collection_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.appaal_instance;



CREATE OR REPLACE VIEW jazzhands_legacy.appaal_instance_device_coll AS
SELECT device_collection_id,appaal_instance_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.appaal_instance_device_collection;



CREATE OR REPLACE VIEW jazzhands_legacy.appaal_instance_property AS
SELECT	appaal_instance_id,
	application_key AS app_key,
	appaal_group_name,
	appaal_group_rank,
	application_value AS app_value,
	encryption_key_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.appaal_instance_property;



CREATE OR REPLACE VIEW jazzhands_legacy.approval_instance AS
SELECT approval_instance_id,approval_process_id,approval_instance_name,description,approval_start,approval_end,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.approval_instance;

-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.approval_instance_item AS
SELECT
	approval_instance_item_id,
	approval_instance_link_id,
	approval_instance_step_id,
	next_approval_instance_item_id,
	approved_category,
	approved_label,
	approved_lhs,
	approved_rhs,
	CASE WHEN is_approved IS NULL THEN NULL
		WHEN is_approved = true THEN 'Y'
		WHEN is_approved = false THEN 'N'
		ELSE NULL
	END AS is_approved,
	approved_account_id,
	approval_note,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.approval_instance_item;



CREATE OR REPLACE VIEW jazzhands_legacy.approval_instance_link AS
SELECT approval_instance_link_id,acct_collection_acct_seq_id,person_company_seq_id,property_seq_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.approval_instance_link;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.approval_instance_step AS
SELECT
	approval_instance_step_id,
	approval_instance_id,
	approval_process_chain_id,
	approval_instance_step_name,
	approval_instance_step_due,
	approval_type,
	description,
	approval_instance_step_start,
	approval_instance_step_end,
	approver_account_id,
	external_reference_name,
	CASE WHEN is_completed IS NULL THEN NULL
		WHEN is_completed = true THEN 'Y'
		WHEN is_completed = false THEN 'N'
		ELSE NULL
	END AS is_completed,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.approval_instance_step;

ALTER TABLE jazzhands_legacy.approval_instance_step ALTER approval_instance_step_start SET DEFAULT now();
ALTER TABLE jazzhands_legacy.approval_instance_step ALTER is_completed SET DEFAULT 'N'::bpchar;

CREATE OR REPLACE VIEW jazzhands_legacy.approval_instance_step_notify AS
SELECT approv_instance_step_notify_id,approval_instance_step_id,approval_notify_type,account_id,approval_notify_whence,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.approval_instance_step_notify;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.approval_process AS
SELECT
	approval_process_id,
	approval_process_name,
	approval_process_type,
	description,
	first_approval_process_chain_id AS first_apprvl_process_chain_id,
	property_name_collection_id AS property_collection_id,
	approval_expiration_action,
	attestation_frequency,
	attestation_offset,
	max_escalation_level,
	escalation_delay,
	escalation_reminder_gap,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.approval_process;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.approval_process_chain AS
SELECT
	approval_process_chain_id,
	approval_process_chain_name,
	approval_chain_response_period,
	description,
	message,
	email_message,
	email_subject_prefix,
	email_subject_suffix,
	max_escalation_level,
	escalation_delay,
	escalation_reminder_gap,
	approving_entity,
	CASE WHEN refresh_all_data IS NULL THEN NULL
		WHEN refresh_all_data = true THEN 'Y'
		WHEN refresh_all_data = false THEN 'N'
		ELSE NULL
	END AS refresh_all_data,
	accept_approval_process_chain_id AS accept_app_process_chain_id,
	reject_approval_process_chain_id AS reject_app_process_chain_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.approval_process_chain;

ALTER TABLE jazzhands_legacy.approval_process_chain ALTER approval_chain_response_period SET DEFAULT '1 week'::character varying;
ALTER TABLE jazzhands_legacy.approval_process_chain ALTER refresh_all_data SET DEFAULT 'N'::bpchar;

CREATE OR REPLACE VIEW jazzhands_legacy.asset AS
SELECT asset_id,component_id,description,contract_id,serial_number,part_number,asset_tag,ownership_status,lease_expiration_date,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.asset;



CREATE OR REPLACE VIEW jazzhands_legacy.badge AS
SELECT card_number,badge_type_id,badge_status,date_assigned,date_reclaimed,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.badge;



CREATE OR REPLACE VIEW jazzhands_legacy.badge_type AS
SELECT badge_type_id,badge_type_name,description,badge_color,badge_template_name,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.badge_type;



CREATE OR REPLACE VIEW jazzhands_legacy.certificate_signing_request AS
SELECT certificate_signing_request_id,friendly_name,subject,certificate_signing_request,private_key_id,public_key_hash_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.certificate_signing_request;



CREATE OR REPLACE VIEW jazzhands_legacy.chassis_location AS
SELECT chassis_location_id,chassis_device_type_id,device_type_module_name,chassis_device_id,module_device_type_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.chassis_location;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.circuit AS
SELECT
	circuit_id,
	vendor_company_id,
	vendor_circuit_id_str,
	aloc_lec_company_id,
	aloc_lec_circuit_id_str,
	aloc_parent_circuit_id,
	zloc_lec_company_id,
	zloc_lec_circuit_id_str,
	zloc_parent_circuit_id,
	CASE WHEN is_locally_managed IS NULL THEN NULL
		WHEN is_locally_managed = true THEN 'Y'
		WHEN is_locally_managed = false THEN 'N'
		ELSE NULL
	END AS is_locally_managed,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.circuit;



CREATE OR REPLACE VIEW jazzhands_legacy.company AS
SELECT company_id,company_name,company_short_name,parent_company_id,description,external_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.company;



CREATE OR REPLACE VIEW jazzhands_legacy.company_collection AS
SELECT company_collection_id,company_collection_name,company_collection_type,description,external_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.company_collection;



CREATE OR REPLACE VIEW jazzhands_legacy.company_collection_company AS
SELECT company_collection_id,company_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.company_collection_company;



CREATE OR REPLACE VIEW jazzhands_legacy.company_collection_hier AS
SELECT company_collection_id,child_company_collection_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.company_collection_hier;



CREATE OR REPLACE VIEW jazzhands_legacy.company_type AS
SELECT company_id,company_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.company_type;



CREATE OR REPLACE VIEW jazzhands_legacy.component AS
SELECT component_id,component_type_id,component_name,rack_location_id,parent_slot_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.component;



CREATE OR REPLACE VIEW jazzhands_legacy.component_property AS
SELECT component_property_id,component_function,component_type_id,component_id,inter_component_connection_id,slot_function,slot_type_id,slot_id,component_property_name,component_property_type,property_value,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.component_property;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.component_type AS
SELECT
	component_type_id,
	company_id,
	model,
	slot_type_id,
	description,
	part_number,
	CASE WHEN is_removable IS NULL THEN NULL
		WHEN is_removable = true THEN 'Y'
		WHEN is_removable = false THEN 'N'
		ELSE NULL
	END AS is_removable,
	CASE WHEN asset_permitted IS NULL THEN NULL
		WHEN asset_permitted = true THEN 'Y'
		WHEN asset_permitted = false THEN 'N'
		ELSE NULL
	END AS asset_permitted,
	CASE WHEN is_rack_mountable IS NULL THEN NULL
		WHEN is_rack_mountable = true THEN 'Y'
		WHEN is_rack_mountable = false THEN 'N'
		ELSE NULL
	END AS is_rack_mountable,
	CASE WHEN is_virtual_component IS NULL THEN NULL
		WHEN is_virtual_component = true THEN 'Y'
		WHEN is_virtual_component = false THEN 'N'
		ELSE NULL
	END AS is_virtual_component,
	size_units,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.component_type;

ALTER TABLE jazzhands_legacy.component_type ALTER is_removable SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands_legacy.component_type ALTER asset_permitted SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands_legacy.component_type ALTER is_rack_mountable SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands_legacy.component_type ALTER is_virtual_component SET DEFAULT 'N'::bpchar;

CREATE OR REPLACE VIEW jazzhands_legacy.component_type_component_func AS
SELECT component_function,component_type_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.component_type_component_function;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.component_type_slot_tmplt AS
SELECT
	component_type_slot_template_id AS component_type_slot_tmplt_id,
	component_type_id,
	slot_type_id,
	slot_name_template,
	child_slot_name_template,
	child_slot_offset,
	slot_index,
	physical_label,
	slot_x_offset,
	slot_y_offset,
	slot_z_offset,
	slot_side,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.component_type_slot_template;

CREATE OR REPLACE VIEW jazzhands_legacy.contract AS
SELECT contract_id,company_id,contract_name,vendor_contract_name,description,contract_termination_date,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.contract;



CREATE OR REPLACE VIEW jazzhands_legacy.contract_type AS
SELECT contract_id,contract_type,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.contract_type;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.department AS
SELECT
	account_collection_id,
	company_id,
	manager_account_id,
	CASE WHEN is_active IS NULL THEN NULL
		WHEN is_active = true THEN 'Y'
		WHEN is_active = false THEN 'N'
		ELSE NULL
	END AS is_active,
	dept_code,
	cost_center_name,
	cost_center_number,
	default_badge_type_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.department;

CREATE OR REPLACE VIEW jazzhands_legacy.device AS
SELECT
	device_id,
	component_id,
	device_type_id,
	device_name,
	site_code,
	identifying_dns_record_id,
	host_id,
	physical_label,
	rack_location_id,
	chassis_location_id,
	parent_device_id,
	description,
	external_id,
	device_status,
	operating_system_id,
	service_environment_id,
	auto_mgmt_protocol,
	is_locally_managed,
	is_monitored,
	CASE WHEN is_virtual_device IS NULL THEN NULL
		WHEN is_virtual_device = true THEN 'Y'
		WHEN is_virtual_device = false THEN 'N'
		ELSE NULL
	END AS is_virtual_device,
	should_fetch_config,
	date_in_service,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.device
JOIN jazzhands_cache.ct_jazzhands_legacy_device_support USING (device_id)
;

ALTER TABLE jazzhands_legacy.device ALTER is_locally_managed SET DEFAULT 'Y'::bpchar;
ALTER TABLE jazzhands_legacy.device ALTER is_virtual_device SET DEFAULT 'N'::bpchar;

CREATE OR REPLACE VIEW jazzhands_legacy.device_collection AS
SELECT device_collection_id,device_collection_name,device_collection_type,description,external_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_collection;

-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.device_collection_assignd_cert AS
SELECT
	device_collection_id,
	x509_signed_certificate_id AS x509_cert_id,
	x509_key_usage AS x509_key_usg,
	x509_file_format,
	file_location_path,
	key_tool_label,
	file_access_mode,
	file_owner_account_id,
	file_group_account_collection_id AS file_group_acct_collection_id,
	file_passphrase_path,
	key_usage_reason_for_assignment AS key_usage_reason_for_assign,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.device_collection_assigned_certificate;



CREATE OR REPLACE VIEW jazzhands_legacy.device_collection_device AS
SELECT device_id,device_collection_id,device_id_rank,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_collection_device;



CREATE OR REPLACE VIEW jazzhands_legacy.device_collection_hier AS
SELECT device_collection_id,child_device_collection_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_collection_hier;



CREATE OR REPLACE VIEW jazzhands_legacy.device_collection_ssh_key AS
SELECT ssh_key_id,device_collection_id,account_collection_id,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_collection_ssh_key;



CREATE OR REPLACE VIEW jazzhands_legacy.device_encapsulation_domain AS
SELECT device_id,encapsulation_type,encapsulation_domain,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_encapsulation_domain;



CREATE OR REPLACE VIEW jazzhands_legacy.device_layer2_network AS
SELECT device_id,layer2_network_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_layer2_network;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.device_management_controller AS
SELECT
	manager_device_id,
	device_id,
	device_management_control_type AS device_mgmt_control_type,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.device_management_controller;



CREATE OR REPLACE VIEW jazzhands_legacy.device_note AS
SELECT device_note_id AS note_id,device_id,note_text,note_date,note_user,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_note;

create or replace view jazzhands_legacy.device_power_connection AS
WITH slotdev AS (
	SELECT	slot_id, slot_name, device_id
	FROM	jazzhands.slot
		INNER JOIN jazzhands.v_device_slots USING (slot_id)
		INNER JOIN jazzhands.slot_type st USING (slot_type_id)
	WHERE	slot_function = 'power'
) SELECT
	icc.inter_component_connection_id	AS device_power_connection_id,
	icc.inter_component_connection_id,
	s1.device_id				AS rpc_device_id,
	s1.slot_name				AS rpc_power_interface_port,
	s2.slot_name				AS power_interface_port,
	s2.device_id				AS device_id,
	icc.data_ins_user,
	icc.data_ins_date,
	icc.data_upd_user,
	icc.data_upd_date
FROM	jazzhands.inter_component_connection icc
	INNER JOIN slotdev s1 on icc.slot1_id = s1.slot_id
	INNER JOIN slotdev s2 on icc.slot2_id = s2.slot_id
;


CREATE OR REPLACE VIEW jazzhands_legacy.device_power_interface AS
WITH pdu AS (
	SELECT	slot_type_id, property_value::integer AS property_value
	FROM	jazzhands.component_property
	WHERE	component_property_type = 'PDU'
), provides AS (
	SELECT	slot_type_id, property_value
	FROM	jazzhands.component_property
	WHERE	component_property_type = 'power_supply'
	AND	component_property_name = 'Provides'
) SELECT
	d.device_id,
	s.slot_name			AS power_interface_port,
	st.slot_physical_interface_type	AS power_plug_style,
	vlt.property_value		AS voltage,
	amp.property_value		AS max_amperage,
	p.property_value::text	AS provides_power,
	s.data_ins_user,
	s.data_ins_date,
	s.data_upd_user,
	s.data_upd_date
FROM	jazzhands.slot s
	INNER JOIN jazzhands.slot_type st USING (slot_type_id)
	INNER JOIN provides p USING (slot_type_id)
	INNER JOIN pdu vlt USING (slot_type_id)
	INNER JOIN pdu amp USING (slot_type_id)
	INNER JOIN jazzhands.v_device_slots d USING (slot_id)
WHERE slot_function = 'power'
;



CREATE OR REPLACE VIEW jazzhands_legacy.device_ssh_key AS
SELECT device_id,ssh_key_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_ssh_key;



CREATE OR REPLACE VIEW jazzhands_legacy.device_ticket AS
SELECT device_id,ticketing_system_id,ticket_number,device_ticket_notes,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_ticket;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.device_type AS
SELECT
	device_type_id,
	component_type_id,
	device_type_name,
	template_device_id,
	idealized_device_id,
	description,
	company_id,
	model,
	device_type_depth_in_cm,
	processor_architecture,
	config_fetch_type,
	rack_units,
	CASE WHEN has_802_3_interface IS NULL THEN NULL
		WHEN has_802_3_interface = true THEN 'Y'
		WHEN has_802_3_interface = false THEN 'N'
		ELSE NULL
	END AS has_802_3_interface,
	CASE WHEN has_802_11_interface IS NULL THEN NULL
		WHEN has_802_11_interface = true THEN 'Y'
		WHEN has_802_11_interface = false THEN 'N'
		ELSE NULL
	END AS has_802_11_interface,
	CASE WHEN snmp_capable IS NULL THEN NULL
		WHEN snmp_capable = true THEN 'Y'
		WHEN snmp_capable = false THEN 'N'
		ELSE NULL
	END AS snmp_capable,
	CASE WHEN is_chassis IS NULL THEN NULL
		WHEN is_chassis = true THEN 'Y'
		WHEN is_chassis = false THEN 'N'
		ELSE NULL
	END AS is_chassis,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.device_type;

ALTER TABLE jazzhands_legacy.device_type ALTER has_802_3_interface SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands_legacy.device_type ALTER has_802_11_interface SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands_legacy.device_type ALTER snmp_capable SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands_legacy.device_type ALTER is_chassis SET DEFAULT 'N'::bpchar;

CREATE OR REPLACE VIEW jazzhands_legacy.device_type_module AS
SELECT device_type_id,device_type_module_name,description,device_type_x_offset,device_type_y_offset,device_type_z_offset,device_type_side,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_type_module;

CREATE OR REPLACE VIEW jazzhands_legacy.device_type_module_device_type AS
SELECT module_device_type_id,device_type_id,device_type_module_name,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_type_module_device_type;



CREATE OR REPLACE VIEW jazzhands_legacy.dns_change_record AS
SELECT dns_change_record_id,dns_domain_id,ip_universe_id,ip_address,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.dns_change_record;



CREATE OR REPLACE VIEW jazzhands_legacy.dns_domain AS
SELECT dns_domain_id,
	dns_domain_name AS soa_name,
	dns_domain_name,
	dns_domain_type,
	parent_dns_domain_id,
	description,
	external_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.dns_domain;


CREATE OR REPLACE VIEW jazzhands_legacy.dns_domain_collection AS
SELECT dns_domain_collection_id,dns_domain_collection_name,dns_domain_collection_type,description,external_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.dns_domain_collection;



CREATE OR REPLACE VIEW jazzhands_legacy.dns_domain_collection_dns_dom AS
SELECT dns_domain_collection_id,dns_domain_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.dns_domain_collection_dns_domain;



CREATE OR REPLACE VIEW jazzhands_legacy.dns_domain_collection_hier AS
SELECT dns_domain_collection_id,child_dns_domain_collection_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.dns_domain_collection_hier;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.dns_domain_ip_universe AS
SELECT
	dns_domain_id,
	ip_universe_id,
	soa_class,
	soa_ttl,
	soa_serial,
	soa_refresh,
	soa_retry,
	soa_expire,
	soa_minimum,
	soa_mname,
	soa_rname,
	CASE WHEN should_generate IS NULL THEN NULL
		WHEN should_generate = true THEN 'Y'
		WHEN should_generate = false THEN 'N'
		ELSE NULL
	END AS should_generate,
	last_generated,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.dns_domain_ip_universe;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.dns_record AS
SELECT
	dns_record_id,
	dns_name,
	dns_domain_id,
	dns_ttl,
	dns_class,
	dns_type,
	dns_value,
	dns_priority,
	dns_srv_service,
	dns_srv_protocol,
	dns_srv_weight,
	dns_srv_port,
	netblock_id,
	ip_universe_id,
	reference_dns_record_id,
	dns_value_record_id,
	CASE WHEN should_generate_ptr IS NULL THEN NULL
		WHEN should_generate_ptr = true THEN 'Y'
		WHEN should_generate_ptr = false THEN 'N'
		ELSE NULL
	END AS should_generate_ptr,
	CASE WHEN is_enabled IS NULL THEN NULL
		WHEN is_enabled = true THEN 'Y'
		WHEN is_enabled = false THEN 'N'
		ELSE NULL
	END AS is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.dns_record;

ALTER TABLE jazzhands_legacy.dns_record ALTER dns_class SET DEFAULT 'IN'::character varying;
ALTER TABLE jazzhands_legacy.dns_record ALTER should_generate_ptr SET DEFAULT 'Y'::bpchar;
ALTER TABLE jazzhands_legacy.dns_record ALTER is_enabled SET DEFAULT 'Y'::bpchar;

CREATE OR REPLACE VIEW jazzhands_legacy.dns_record_relation AS
SELECT dns_record_id,related_dns_record_id,dns_record_relation_type,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.dns_record_relation;



CREATE OR REPLACE VIEW jazzhands_legacy.encapsulation_domain AS
SELECT encapsulation_domain,encapsulation_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.encapsulation_domain;



CREATE OR REPLACE VIEW jazzhands_legacy.encapsulation_range AS
SELECT encapsulation_range_id,parent_encapsulation_range_id,site_code,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.encapsulation_range;



CREATE OR REPLACE VIEW jazzhands_legacy.encryption_key AS
SELECT encryption_key_id,encryption_key_db_value,encryption_key_purpose,encryption_key_purpose_version,encryption_method,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.encryption_key;



CREATE OR REPLACE VIEW jazzhands_legacy.inter_component_connection AS
SELECT inter_component_connection_id,slot1_id,slot2_id,circuit_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.inter_component_connection;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.ip_universe AS
SELECT
	ip_universe_id,
	ip_universe_name,
	ip_namespace,
	CASE WHEN should_generate_dns IS NULL THEN NULL
		WHEN should_generate_dns = true THEN 'Y'
		WHEN should_generate_dns = false THEN 'N'
		ELSE NULL
	END AS should_generate_dns,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.ip_universe;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.ip_universe_visibility AS
SELECT
	ip_universe_id,
	visible_ip_universe_id,
	CASE WHEN propagate_dns IS NULL THEN NULL
		WHEN propagate_dns = true THEN 'Y'
		WHEN propagate_dns = false THEN 'N'
		ELSE NULL
	END AS propagate_dns,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.ip_universe_visibility;

CREATE OR REPLACE VIEW jazzhands_legacy.kerberos_realm AS
SELECT krb_realm_id,realm_name,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.kerberos_realm;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.klogin AS
SELECT
	klogin_id,
	account_id,
	account_collection_id,
	krb_realm_id,
	krb_instance,
	destination_account_id AS dest_account_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.klogin;



CREATE OR REPLACE VIEW jazzhands_legacy.klogin_mclass AS
SELECT klogin_id,device_collection_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.klogin_mclass;



CREATE OR REPLACE VIEW jazzhands_legacy.l2_network_coll_l2_network AS
SELECT layer2_network_collection_id,layer2_network_id,layer2_network_id_rank,start_date,finish_date,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.layer2_network_collection_layer2_network;



CREATE OR REPLACE VIEW jazzhands_legacy.l3_network_coll_l3_network AS
SELECT layer3_network_collection_id,layer3_network_id,layer3_network_id_rank,start_date,finish_date,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.layer3_network_collection_layer3_network;



CREATE OR REPLACE VIEW jazzhands_legacy.layer1_connection AS
WITH conn_props AS (
	SELECT inter_component_connection_id,
			component_property_name, component_property_type,
			property_value
	FROM	jazzhands.component_property
	WHERE	component_property_type IN ('serial-connection')
), tcpsrv_device_id AS (
	SELECT inter_component_connection_id, device_id
	FROM	jazzhands.component_property
			INNER JOIN jazzhands.device USING (component_id)
	WHERE	component_property_type = 'tcpsrv-connections'
	AND		component_property_name = 'tcpsrv_device_id'
) , tcpsrv_enabled AS (
	SELECT inter_component_connection_id, property_value
	FROM	jazzhands.component_property
	WHERE	component_property_type = 'tcpsrv-connections'
	AND		component_property_name = 'tcpsrv_enabled'
) SELECT
	icc.inter_component_connection_id  AS layer1_connection_id,
	icc.slot1_id			AS physical_port1_id,
	icc.slot2_id			AS physical_port2_id,
	icc.circuit_id,
	baud.property_value::integer			AS baud,
	dbits.property_value::integer		AS data_bits,
	sbits.property_value::integer		AS stop_bits,
	parity.property_value		AS parity,
	flow.property_value			AS flow_control,
	tcpsrv.device_id			AS tcpsrv_device_id,
	coalesce(tcpsrvon.property_value,'N')::char(1)	AS is_tcpsrv_enabled,
	icc.data_ins_user,
	icc.data_ins_date,
	icc.data_upd_user,
	icc.data_upd_date
FROM jazzhands.inter_component_connection icc
	INNER JOIN jazzhands.slot s1 ON icc.slot1_id = s1.slot_id
	INNER JOIN jazzhands.slot_type st1 ON st1.slot_type_id = s1.slot_type_id
	INNER JOIN jazzhands.slot s2 ON icc.slot2_id = s2.slot_id
	INNER JOIN jazzhands.slot_type st2 ON st2.slot_type_id = s2.slot_type_id
	LEFT JOIN tcpsrv_device_id tcpsrv USING (inter_component_connection_id)
	LEFT JOIN tcpsrv_enabled tcpsrvon USING (inter_component_connection_id)
	LEFT JOIN conn_props baud ON baud.inter_component_connection_id =
		icc.inter_component_connection_id AND
		baud.component_property_name = 'baud'
	LEFT JOIN conn_props dbits ON dbits.inter_component_connection_id =
		icc.inter_component_connection_id AND
		dbits.component_property_name = 'data-bits'
	LEFT JOIN conn_props sbits ON sbits.inter_component_connection_id =
		icc.inter_component_connection_id AND
		sbits.component_property_name = 'stop-bits'
	LEFT JOIN conn_props parity ON parity.inter_component_connection_id =
		icc.inter_component_connection_id AND
		parity.component_property_name = 'parity'
	LEFT JOIN conn_props flow ON flow.inter_component_connection_id =
		icc.inter_component_connection_id AND
		flow.component_property_name = 'flow-control'
 WHERE  st1.slot_function in ('network', 'serial', 'patchpanel')
	OR
 	st1.slot_function in ('network', 'serial', 'patchpanel')
;



CREATE OR REPLACE VIEW jazzhands_legacy.layer2_connection AS
SELECT layer2_connection_id,logical_port1_id,logical_port2_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.layer2_connection;



CREATE OR REPLACE VIEW jazzhands_legacy.layer2_connection_l2_network AS
SELECT layer2_connection_id,layer2_network_id,encapsulation_mode,encapsulation_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.layer2_connection_layer2_network;



CREATE OR REPLACE VIEW jazzhands_legacy.layer2_network AS
SELECT layer2_network_id,encapsulation_name,encapsulation_domain,encapsulation_type,encapsulation_tag,description,external_id,encapsulation_range_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.layer2_network;



CREATE OR REPLACE VIEW jazzhands_legacy.layer2_network_collection AS
SELECT layer2_network_collection_id,layer2_network_collection_name,layer2_network_collection_type,description,external_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.layer2_network_collection;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.layer2_network_collection_hier AS
SELECT
	layer2_network_collection_id,
	child_layer2_network_collection_id AS child_l2_network_coll_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.layer2_network_collection_hier;



CREATE OR REPLACE VIEW jazzhands_legacy.layer3_network AS
SELECT layer3_network_id,netblock_id,layer2_network_id,default_gateway_netblock_id,rendezvous_netblock_id,description,external_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.layer3_network;



CREATE OR REPLACE VIEW jazzhands_legacy.layer3_network_collection AS
SELECT layer3_network_collection_id,layer3_network_collection_name,layer3_network_collection_type,description,external_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.layer3_network_collection;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.layer3_network_collection_hier AS
SELECT
	layer3_network_collection_id,
	child_layer3_network_collection_id AS child_l3_network_coll_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.layer3_network_collection_hier;



CREATE OR REPLACE VIEW jazzhands_legacy.logical_port AS
SELECT logical_port_id,logical_port_name,logical_port_type,device_id,mlag_peering_id,parent_logical_port_id,mac_address,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.logical_port;



CREATE OR REPLACE VIEW jazzhands_legacy.logical_port_slot AS
SELECT logical_port_id,slot_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.logical_port_slot;



CREATE OR REPLACE VIEW jazzhands_legacy.logical_volume AS
SELECT logical_volume_id,logical_volume_name,logical_volume_type,volume_group_id,device_id,logical_volume_size_in_bytes,logical_volume_offset_in_bytes,filesystem_type,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.logical_volume;

CREATE OR REPLACE VIEW jazzhands_legacy.logical_volume_property AS
SELECT logical_volume_property_id,logical_volume_id,logical_volume_type,logical_volume_purpose,filesystem_type,logical_volume_property_name,logical_volume_property_value,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.logical_volume_property;



CREATE OR REPLACE VIEW jazzhands_legacy.logical_volume_purpose AS
SELECT logical_volume_purpose,logical_volume_id,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.logical_volume_purpose;



CREATE OR REPLACE VIEW jazzhands_legacy.mlag_peering AS
SELECT mlag_peering_id,device1_id,device2_id,domain_id,system_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.mlag_peering;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.netblock AS
SELECT
	netblock_id,
	ip_address,
	netblock_type,
	CASE WHEN is_single_address IS NULL THEN NULL
		WHEN is_single_address = true THEN 'Y'
		WHEN is_single_address = false THEN 'N'
		ELSE NULL
	END AS is_single_address,
	CASE WHEN can_subnet IS NULL THEN NULL
		WHEN can_subnet = true THEN 'Y'
		WHEN can_subnet = false THEN 'N'
		ELSE NULL
	END AS can_subnet,
	parent_netblock_id,
	netblock_status,
	ip_universe_id,
	description,
	external_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.netblock;

-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.netblock_collection AS
SELECT
	netblock_collection_id,
	netblock_collection_name,
	netblock_collection_type,
	netblock_ip_family_restriction AS netblock_ip_family_restrict,
	description,
	external_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.netblock_collection;



CREATE OR REPLACE VIEW jazzhands_legacy.netblock_collection_hier AS
SELECT netblock_collection_id,child_netblock_collection_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.netblock_collection_hier;



CREATE OR REPLACE VIEW jazzhands_legacy.netblock_collection_netblock AS
SELECT netblock_collection_id,netblock_id,netblock_id_rank,start_date,finish_date,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.netblock_collection_netblock;



CREATE OR REPLACE VIEW jazzhands_legacy.network_interface AS
SELECT
	layer3_interface_id AS network_interface_id,
	device_id,
	layer3_interface_name AS network_interface_name,
	description,
	parent_layer3_interface_id AS parent_network_interface_id,
	parent_relation_type,
	slot_id AS physical_port_id,
	slot_id,
	logical_port_id,
	layer3_interface_type AS network_interface_type,
	CASE WHEN is_interface_up IS NULL THEN NULL
		WHEN is_interface_up = true THEN 'Y'
		WHEN is_interface_up = false THEN 'N'
		ELSE NULL
	END AS is_interface_up,
	mac_addr,
	CASE WHEN should_monitor IS NULL THEN NULL
		WHEN should_monitor = true THEN 'Y'
		WHEN should_monitor = false THEN 'N'
		ELSE NULL
	END AS should_monitor,
	CASE WHEN should_manage IS NULL THEN NULL
		WHEN should_manage = true THEN 'Y'
		WHEN should_manage = false THEN 'N'
		ELSE NULL
	END AS should_manage,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.layer3_interface;

ALTER TABLE jazzhands_legacy.network_interface ALTER is_interface_up SET DEFAULT 'Y'::bpchar;
ALTER TABLE jazzhands_legacy.network_interface ALTER should_monitor SET DEFAULT 'Y'::bpchar;
ALTER TABLE jazzhands_legacy.network_interface ALTER should_manage SET DEFAULT 'Y'::bpchar;

-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.network_interface_netblock AS
SELECT
	netblock_id,
	layer3_interface_id AS network_interface_id,
	device_id,
	layer3_interface_rank AS network_interface_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.layer3_interface_netblock;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.network_interface_purpose AS
SELECT
	device_id,
	layer3_interface_purpose AS network_interface_purpose,
	layer3_interface_id AS network_interface_id,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.layer3_interface_purpose;



CREATE OR REPLACE VIEW jazzhands_legacy.network_range AS
SELECT network_range_id,network_range_type,description,parent_netblock_id,start_netblock_id,stop_netblock_id,dns_prefix,dns_domain_id,lease_time,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.network_range;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.network_service AS
SELECT
	network_service_id,
	name,
	description,
	network_service_type,
	CASE WHEN is_monitored IS NULL THEN NULL
		WHEN is_monitored = true THEN 'Y'
		WHEN is_monitored = false THEN 'N'
		ELSE NULL
	END AS is_monitored,
	device_id,
	layer3_interface_id AS network_interface_id,
	dns_record_id,
	service_environment_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.network_service;



CREATE OR REPLACE VIEW jazzhands_legacy.operating_system AS
SELECT
	operating_system_id,
	operating_system_name,
	operating_system_short_name,
	company_id,
	major_version,
	version,
	operating_system_family,
	NULL::character varying(50) AS processor_architecture, -- Need to fill in
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.operating_system;



CREATE OR REPLACE VIEW jazzhands_legacy.operating_system_snapshot AS
SELECT operating_system_snapshot_id,operating_system_snapshot_name,operating_system_snapshot_type,operating_system_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.operating_system_snapshot;



CREATE OR REPLACE VIEW jazzhands_legacy.person AS
SELECT
	person_id,
	description,
	first_name,
	middle_name,
	last_name,
	name_suffix,
	CASE WHEN gender = 'male' THEN 'M'
		WHEN gender = 'female' THEN 'F'
		WHEN gender = 'unspecified' THEN 'U'
		WHEN gender is NULL THEN NULL
		ELSE 'U' END as gender,
	preferred_first_name,
	preferred_last_name,
	nickname,
	birth_date,
	diet,
	shirt_size,
	pant_size,
	hat_size,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.person;



CREATE OR REPLACE VIEW jazzhands_legacy.person_account_realm_company AS
SELECT person_id,company_id,account_realm_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.person_account_realm_company;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.person_auth_question AS
SELECT
	authentication_question_id AS auth_question_id,
	person_id,
	user_answer,
	CASE WHEN is_active IS NULL THEN NULL
		WHEN is_active = true THEN 'Y'
		WHEN is_active = false THEN 'N'
		ELSE NULL
	END AS is_active,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.person_authentication_question;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.person_company AS
SELECT
	company_id,
	person_id,
	person_company_status,
	person_company_relation,
	CASE WHEN is_exempt IS NULL THEN NULL
		WHEN is_exempt = true THEN 'Y'
		WHEN is_exempt = false THEN 'N'
		ELSE NULL
	END AS is_exempt,
	CASE WHEN is_management IS NULL THEN NULL
		WHEN is_management = true THEN 'Y'
		WHEN is_management = false THEN 'N'
		ELSE NULL
	END AS is_management,
	CASE WHEN is_full_time IS NULL THEN NULL
		WHEN is_full_time = true THEN 'Y'
		WHEN is_full_time = false THEN 'N'
		ELSE NULL
	END AS is_full_time,
	description,
	position_title,
	hire_date,
	termination_date,
	manager_person_id,
	nickname,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.person_company;

ALTER TABLE jazzhands_legacy.person_company ALTER is_exempt SET DEFAULT 'Y'::bpchar;
ALTER TABLE jazzhands_legacy.person_company ALTER is_management SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands_legacy.person_company ALTER is_full_time SET DEFAULT 'Y'::bpchar;

-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.person_company_attr AS
SELECT
	company_id,
	person_id,
	person_company_attribute_name AS person_company_attr_name,
	attribute_value,
	attribute_value_timestamp,
	attribute_value_person_id,
	start_date,
	finish_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.person_company_attribute;



CREATE OR REPLACE VIEW jazzhands_legacy.person_company_badge AS
SELECT company_id,person_id,badge_id,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.person_company_badge;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.person_contact AS
SELECT
	person_contact_id,
	person_id,
	person_contact_type,
	person_contact_technology,
	person_contact_location_type,
	person_contact_privacy,
	person_contact_carrier_company_id AS person_contact_cr_company_id,
	iso_country_code,
	phone_number,
	phone_extension,
	phone_pin,
	person_contact_account_name,
	person_contact_order,
	person_contact_notes,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.person_contact;



CREATE OR REPLACE VIEW jazzhands_legacy.person_image AS
SELECT person_image_id,person_id,person_image_order,image_type,image_blob,image_checksum,image_label,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.person_image;



CREATE OR REPLACE VIEW jazzhands_legacy.person_image_usage AS
SELECT person_image_id,person_image_usage,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.person_image_usage;



CREATE OR REPLACE VIEW jazzhands_legacy.person_location AS
SELECT person_location_id,person_id,person_location_type,site_code,physical_address_id,building,floor,section,seat_number,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.person_location;



CREATE OR REPLACE VIEW jazzhands_legacy.person_note AS
SELECT person_note_id AS note_id,person_id,note_text,note_date,note_user,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.person_note;



CREATE OR REPLACE VIEW jazzhands_legacy.person_parking_pass AS
SELECT person_parking_pass_id,person_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.person_parking_pass;



CREATE OR REPLACE VIEW jazzhands_legacy.person_vehicle AS
SELECT person_vehicle_id,person_id,vehicle_make,vehicle_model,vehicle_year,vehicle_color,vehicle_license_plate,vehicle_license_state,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.person_vehicle;



CREATE OR REPLACE VIEW jazzhands_legacy.physical_address AS
SELECT physical_address_id,physical_address_type,company_id,site_rank,description,display_label,address_agent,address_housename,address_street,address_building,address_pobox,address_neighborhood,address_city,address_subregion,address_region,postal_code,iso_country_code,address_freeform,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.physical_address;

CREATE OR REPLACE VIEW jazzhands_legacy.physical_connection AS
SELECT
	physical_connection_id,
	slot1_id::integer AS physical_port1_id,
	slot2_id::integer AS physical_port2_id,
	slot1_id,
	slot2_id,
	cable_type,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.physical_connection;



CREATE OR REPLACE VIEW jazzhands_legacy.physical_port AS
SELECT
	sl.slot_id			AS physical_port_id,
	d.device_id,
	sl.slot_name			AS port_name,
	st.slot_function		AS port_type,
	sl.description,
	st.slot_physical_interface_type	AS port_plug_style,
	NULL::text			AS port_medium,
	NULL::text			AS port_protocol,
	NULL::text			AS port_speed,
	sl.physical_label,
	NULL::text			AS port_purpose,
	NULL::integer			AS logical_port_id,
	NULL::integer			AS tcp_port,
	CASE WHEN ct.is_removable = 'Y' THEN 'N' ELSE 'Y' END AS is_hardwired,
	sl.data_ins_user,
	sl.data_ins_date,
	sl.data_upd_user,
	sl.data_upd_date
  FROM	jazzhands.slot sl
	INNER JOIN jazzhands.slot_type st USING (slot_type_id)
	INNER JOIN jazzhands.v_device_slots d USING (slot_id)
	INNER JOIN jazzhands.component c ON (sl.component_id = c.component_id)
	INNER JOIN jazzhands.component_type ct USING (component_type_id)
 WHERE	st.slot_function in ('network', 'serial', 'patchpanel')
;



CREATE OR REPLACE VIEW jazzhands_legacy.physicalish_volume AS
SELECT physicalish_volume_id,physicalish_volume_name,physicalish_volume_type,device_id,logical_volume_id,component_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.physicalish_volume;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.private_key AS
SELECT
	private_key_id,
	private_key_encryption_type,
	CASE WHEN is_active IS NULL THEN NULL
		WHEN is_active = true THEN 'Y'
		WHEN is_active = false THEN 'N'
		ELSE NULL
	END AS is_active,
	NULL::text AS subject_key_identifier,
	private_key,
	passphrase,
	encryption_key_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.private_key;

-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.property AS
SELECT
	property_id,
	account_collection_id,
	account_id,
	account_realm_id,
	company_collection_id,
	company_id,
	device_collection_id,
	dns_domain_collection_id,
	layer2_network_collection_id,
	layer3_network_collection_id,
	netblock_collection_id,
	network_range_id,
	operating_system_id,
	operating_system_snapshot_id,
	property_name_collection_id AS property_collection_id,
	service_environment_collection_id AS service_env_collection_id,
	site_code,
	x509_signed_certificate_id,
	property_name,
	property_type,
	CASE WHEN property_value_boolean = true THEN 'Y'
		WHEN property_value_boolean = false THEN 'N'
		ELSE property_value END AS property_value,
	property_value_timestamp,
	property_value_account_collection_id AS property_value_account_coll_id,
	property_value_device_collection_id AS property_value_device_coll_id,
	property_value_json,
	property_value_netblock_collection_id AS property_value_nblk_coll_id,
	property_value_password_type,
	NULL::integer AS property_value_sw_package_id,
	property_value_token_collection_id AS property_value_token_col_id,
	property_rank,
	start_date,
	finish_date,
	CASE WHEN is_enabled IS NULL THEN NULL
		WHEN is_enabled = true THEN 'Y'
		WHEN is_enabled = false THEN 'N'
		ELSE NULL
	END AS is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.property;

-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.property_collection AS
SELECT
	property_name_collection_id AS property_collection_id,
	property_name_collection_name AS property_collection_name,
	property_name_collection_type AS property_collection_type,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.property_name_collection;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.property_collection_hier AS
SELECT
	property_name_collection_id AS property_collection_id,
	child_property_name_collection_id AS child_property_collection_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.property_name_collection_hier;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.property_collection_property AS
SELECT
	property_name_collection_id AS property_collection_id,
	property_name,
	property_type,
	property_id_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.property_name_collection_property_name;



CREATE OR REPLACE VIEW jazzhands_legacy.pseudo_klogin AS
SELECT pseudo_klogin_id,principal,dest_account_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.pseudo_klogin;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.rack AS
SELECT
	rack_id,
	site_code,
	room,
	sub_room,
	rack_row,
	rack_name,
	rack_style,
	rack_type,
	description,
	rack_height_in_u,
	CASE WHEN display_from_bottom IS NULL THEN NULL
		WHEN display_from_bottom = true THEN 'Y'
		WHEN display_from_bottom = false THEN 'N'
		ELSE NULL
	END AS display_from_bottom,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.rack;



CREATE OR REPLACE VIEW jazzhands_legacy.rack_location AS
SELECT rack_location_id,rack_id,rack_u_offset_of_device_top,rack_side,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.rack_location;

CREATE OR REPLACE VIEW jazzhands_legacy.service_environment AS
SELECT service_environment_id,
	service_environment_name,
	production_state,
	description,
	external_id,
	data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.service_environment
WHERE service_environment_type = 'default';



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.service_environment_coll_hier AS
SELECT
	service_environment_collection_id AS service_env_collection_id,
	child_service_environment_collection_id AS child_service_env_coll_id,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.service_environment_collection_hier;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.service_environment_collection AS
SELECT
	service_environment_collection_id AS service_env_collection_id,
	service_environment_collection_name AS service_env_collection_name,
	service_environment_collection_type AS service_env_collection_type,
	description,
	external_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.service_environment_collection;



CREATE OR REPLACE VIEW jazzhands_legacy.shared_netblock AS
SELECT shared_netblock_id,shared_netblock_protocol,netblock_id,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.shared_netblock;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.shared_netblock_network_int AS
SELECT
	shared_netblock_id,
	layer3_interface_id AS network_interface_id,
	priority,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.shared_netblock_layer3_interface;



CREATE OR REPLACE VIEW jazzhands_legacy.site AS
SELECT site_code,colo_company_id,physical_address_id,site_status,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.site;



CREATE OR REPLACE VIEW jazzhands_legacy.site_netblock AS
SELECT site_code,netblock_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.site_netblock;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.slot AS
SELECT
	slot_id,
	component_id,
	slot_name,
	slot_index,
	slot_type_id,
	component_type_slot_template_id AS component_type_slot_tmplt_id,
	CASE WHEN is_enabled IS NULL THEN NULL
		WHEN is_enabled = true THEN 'Y'
		WHEN is_enabled = false THEN 'N'
		ELSE NULL
	END AS is_enabled,
	physical_label,
	mac_address,
	description,
	slot_x_offset,
	slot_y_offset,
	slot_z_offset,
	slot_side,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.slot;

-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.slot_type AS
SELECT
	slot_type_id,
	slot_type,
	slot_function,
	slot_physical_interface_type,
	description,
	CASE WHEN remote_slot_permitted IS NULL THEN NULL
		WHEN remote_slot_permitted = true THEN 'Y'
		WHEN remote_slot_permitted = false THEN 'N'
		ELSE NULL
	END AS remote_slot_permitted,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.slot_type;

CREATE OR REPLACE VIEW jazzhands_legacy.slot_type_prmt_comp_slot_type AS
SELECT slot_type_id,component_slot_type_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.slot_type_permitted_component_slot_type;



CREATE OR REPLACE VIEW jazzhands_legacy.slot_type_prmt_rem_slot_type AS
SELECT slot_type_id,remote_slot_type_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.slot_type_permitted_remote_slot_type;



CREATE OR REPLACE VIEW jazzhands_legacy.ssh_key AS
SELECT ssh_key_id,ssh_key_type,ssh_public_key,ssh_private_key,encryption_key_id,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.ssh_key;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.static_route AS
SELECT
	static_route_id,
	device_source_id AS device_src_id,
	layer3_interface_destination_id AS network_interface_dst_id,
	netblock_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.static_route;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.static_route_template AS
SELECT
	static_route_template_id,
	netblock_source_id AS netblock_src_id,
	layer3_interface_destination_id AS network_interface_dst_id,
	netblock_id,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.static_route_template;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.sudo_acct_col_device_collectio AS
SELECT
	sudo_alias_name,
	device_collection_id,
	account_collection_id,
	run_as_account_collection_id,
	CASE WHEN requires_password IS NULL THEN NULL
		WHEN requires_password = true THEN 'Y'
		WHEN requires_password = false THEN 'N'
		ELSE NULL
	END AS requires_password,
	CASE WHEN can_exec_child IS NULL THEN NULL
		WHEN can_exec_child = true THEN 'Y'
		WHEN can_exec_child = false THEN 'N'
		ELSE NULL
	END AS can_exec_child,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.sudo_account_collection_device_collection;



CREATE OR REPLACE VIEW jazzhands_legacy.sudo_alias AS
SELECT sudo_alias_name,sudo_alias_value,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.sudo_alias;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.svc_environment_coll_svc_env AS
SELECT
	service_environment_collection_id AS service_env_collection_id,
	service_environment_id,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.service_environment_collection_service_environment;



CREATE OR REPLACE VIEW jazzhands_legacy.sw_package AS
SELECT software_artifact_name_id AS sw_package_id,
	software_artifact_name sw_package_name,
	software_artifact_type sw_package_type,
	description,
	data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.software_artifact_name;



CREATE OR REPLACE VIEW jazzhands_legacy.ticketing_system AS
SELECT ticketing_system_id,ticketing_system_name,ticketing_system_url,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.ticketing_system;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.token AS
SELECT
	token_id,
	token_type,
	token_status,
	description,
	external_id,
	token_serial,
	zero_time,
	time_modulo,
	time_skew,
	token_key,
	encryption_key_id,
	token_password,
	expire_time,
	CASE WHEN is_token_locked IS NULL THEN NULL
		WHEN is_token_locked = true THEN 'Y'
		WHEN is_token_locked = false THEN 'N'
		ELSE NULL
	END AS is_token_locked,
	token_unlock_time,
	bad_logins,
	last_updated,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.token;

CREATE OR REPLACE VIEW jazzhands_legacy.token_collection AS
SELECT token_collection_id,token_collection_name,token_collection_type,description,external_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.token_collection;



CREATE OR REPLACE VIEW jazzhands_legacy.token_collection_hier AS
SELECT token_collection_id,child_token_collection_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.token_collection_hier;



CREATE OR REPLACE VIEW jazzhands_legacy.token_collection_token AS
SELECT token_collection_id,token_id,token_id_rank,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.token_collection_token;



CREATE OR REPLACE VIEW jazzhands_legacy.token_sequence AS
SELECT token_id,token_sequence,last_updated
FROM jazzhands.token_sequence;



CREATE OR REPLACE VIEW jazzhands_legacy.unix_group AS
SELECT account_collection_id,unix_gid,group_password,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.unix_group;



CREATE OR REPLACE VIEW jazzhands_legacy.v_account_collection_account AS
SELECT account_collection_id,account_id,account_collection_relation,account_id_rank,start_date,finish_date,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.v_account_collection_account;


--
-- NOTE NOTE NOTE: The version in jazzhands is DIFFERENT and that needs to be
-- cleaned up.
--
CREATE OR REPLACE VIEW jazzhands_legacy.v_account_collection_expanded AS
WITH RECURSIVE var_recurse (
        level,
        root_account_collection_id,
        account_collection_id,
        array_path,
        cycle
) as (
        SELECT
                0                               as level,
                a.account_collection_id         as root_account_collection_id,
                a.account_collection_id         as account_collection_id,
                ARRAY[a.account_collection_id]  as array_path,
                false                           as cycle
          FROM  account_collection a
UNION ALL
        SELECT
                x.level + 1                     as level,
                x.root_account_collection_id    as root_account_collection_id,
                ach.child_account_collection_id as account_collection_id,
                ach.child_account_collection_id ||
                        x.array_path            as array_path,
                ach.child_account_collection_id =
                        ANY(x.array_path)       as cycle
          FROM  var_recurse x
                inner join account_collection_hier ach
                        on x.account_collection_id =
                                ach.account_collection_id
        WHERE   NOT x.cycle
) SELECT        level,
                root_account_collection_id,
                account_collection_id
  from          var_recurse;


CREATE OR REPLACE VIEW jazzhands_legacy.v_account_collection_hier_from_ancestor AS
SELECT root_account_collection_id,account_collection_id,path,cycle
FROM jazzhands.v_account_collection_hier_from_ancestor;



CREATE OR REPLACE VIEW jazzhands_legacy.v_account_manager_hier AS
SELECT level,account_id,person_id,company_id,login,human_readable,account_realm_id,manager_account_id,manager_login,manager_person_id,manager_company_id,manager_human_readable,array_path
FROM jazzhands.v_account_manager_hier;


CREATE OR REPLACE VIEW jazzhands_legacy.v_account_name AS
SELECT account_id,first_name,last_name,display_name
FROM jazzhands.v_account_name;



CREATE OR REPLACE VIEW jazzhands_legacy.v_acct_coll_acct_expanded AS
SELECT account_collection_id,account_id
FROM jazzhands.v_account_collection_account_expanded;



CREATE OR REPLACE VIEW jazzhands_legacy.v_acct_coll_acct_expanded_detail AS
SELECT account_collection_id,root_account_collection_id,account_id,acct_coll_level,dept_level,assign_method,text_path,array_path
FROM jazzhands.v_account_collection_account_expanded_detail;



CREATE OR REPLACE VIEW jazzhands_legacy.v_acct_coll_expanded AS
SELECT level,account_collection_id,root_account_collection_id,text_path,array_path,rvs_array_path
FROM jazzhands.v_account_collection_expanded;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.v_acct_coll_expanded_detail AS
SELECT
	account_collection_id,
	root_account_collection_id,
	account_collection_level AS acct_coll_level,
	department_level AS dept_level,
	assignment_method AS assign_method,
	text_path,
	array_path
FROM jazzhands.v_account_collection_expanded_detail;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.v_acct_coll_prop_expanded AS
SELECT
	account_collection_id,
	property_id,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_account_collection_id AS property_value_account_coll_id,
	property_value_netblock_collection_id AS property_value_nblk_coll_id,
	property_value_password_type,
	property_value_token_collection_id AS property_value_token_col_id,
	property_rank,
	is_multivalue,
	assignment_rank AS assign_rank
FROM jazzhands.v_account_collection_property_expanded;



CREATE OR REPLACE VIEW jazzhands_legacy.v_application_role AS
SELECT role_level,role_id,parent_role_id,root_role_id,root_role_name,role_name,role_path,role_is_leaf,array_path,cycle
FROM jazzhands.v_application_role;



CREATE OR REPLACE VIEW jazzhands_legacy.v_application_role_member AS
SELECT device_id,role_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.v_application_role_member;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.v_approval_instance_step_expanded AS
SELECT
	first_approval_instance_item_id,
	root_step_id,
	approval_instance_item_id,
	approval_instance_step_id,
	tier,
	level,
	CASE WHEN is_approved IS NULL THEN NULL
		WHEN is_approved = true THEN 'Y'
		WHEN is_approved = false THEN 'N'
		ELSE NULL
	END AS is_approved
FROM jazzhands.v_approval_instance_step_expanded;



CREATE OR REPLACE VIEW jazzhands_legacy.v_company_hier AS
SELECT root_company_id,company_id
FROM jazzhands.v_company_hier;



CREATE OR REPLACE VIEW jazzhands_legacy.v_component_hier AS
SELECT component_id,child_component_id,component_path,level
FROM jazzhands.v_component_hier;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.v_corp_family_account AS
SELECT
	account_id,
	login,
	person_id,
	company_id,
	account_realm_id,
	account_status,
	account_role,
	account_type,
	description,
	CASE WHEN is_enabled IS NULL THEN NULL
		WHEN is_enabled = true THEN 'Y'
		WHEN is_enabled = false THEN 'N'
		ELSE NULL
	END AS is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.v_corp_family_account;



CREATE OR REPLACE VIEW jazzhands_legacy.v_department_company_expanded AS
SELECT company_id,account_collection_id
FROM jazzhands.v_department_company_expanded;



CREATE OR REPLACE VIEW jazzhands_legacy.v_dev_col_device_root AS
SELECT device_id,root_id,root_name,root_type,leaf_id,leaf_name,leaf_type
FROM jazzhands.v_device_collection_device_root;



CREATE OR REPLACE VIEW jazzhands_legacy.v_dev_col_root AS
SELECT root_id,root_name,root_type,leaf_id,leaf_name,leaf_type
FROM jazzhands.v_device_collection_root;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.v_dev_col_user_prop_expanded AS
SELECT
	property_id,
	device_collection_id,
	account_id,
	login,
	account_status,
	account_realm_id,
	account_realm_name,
	CASE WHEN is_enabled IS NULL THEN NULL
		WHEN is_enabled = true THEN 'Y'
		WHEN is_enabled = false THEN 'N'
		ELSE NULL
	END AS is_enabled,
	property_type,
	property_name,
	property_rank,
	property_value,
	is_multivalue,
	is_boolean
FROM jazzhands.v_device_collection_account_property_expanded;



CREATE OR REPLACE VIEW jazzhands_legacy.v_device_col_account_cart AS
SELECT device_collection_id,account_id,setting
FROM jazzhands.v_device_collection_account_cart;



CREATE OR REPLACE VIEW jazzhands_legacy.v_device_col_account_col_cart AS
SELECT device_collection_id,account_collection_id,setting
FROM jazzhands.v_device_collection_account_collection_cart;



CREATE OR REPLACE VIEW jazzhands_legacy.v_device_col_acct_col_expanded AS
SELECT device_collection_id,account_collection_id,account_id
FROM jazzhands.v_device_collection_account_collection_expanded;



CREATE OR REPLACE VIEW jazzhands_legacy.v_device_col_acct_col_unixgroup AS
SELECT device_collection_id,account_collection_id
FROM jazzhands.v_device_collection_account_collection_unix_group;



CREATE OR REPLACE VIEW jazzhands_legacy.v_device_col_acct_col_unixlogin AS
SELECT device_collection_id,account_collection_id,account_id
FROM jazzhands.v_device_collection_account_collection_unix_login;



CREATE OR REPLACE VIEW jazzhands_legacy.v_device_coll_device_expanded AS
SELECT device_collection_id,device_id
FROM jazzhands.v_device_collection_device_expanded;



CREATE OR REPLACE VIEW jazzhands_legacy.v_device_coll_hier_detail AS
SELECT device_collection_id,parent_device_collection_id,device_collection_level
FROM jazzhands.v_device_collection_hier_detail;



CREATE OR REPLACE VIEW jazzhands_legacy.v_device_collection_account_ssh_key AS
SELECT device_collection_id,account_id,ssh_public_key
FROM jazzhands.v_device_collection_account_ssh_key;



CREATE OR REPLACE VIEW jazzhands_legacy.v_device_collection_hier_from_ancestor AS
SELECT root_device_collection_id,device_collection_id,path,cycle
FROM jazzhands.v_device_collection_hier_from_ancestor;



CREATE OR REPLACE VIEW jazzhands_legacy.v_device_component_summary AS
SELECT device_id,cpu_model,cpu_count,core_count,memory_count,total_memory,disk_count,total_disk
FROM jazzhands.v_device_component_summary;



CREATE OR REPLACE VIEW jazzhands_legacy.v_device_components AS
SELECT device_id,component_id,component_path,level
FROM jazzhands.v_device_components;



CREATE OR REPLACE VIEW jazzhands_legacy.v_device_components_expanded AS
SELECT device_id,component_id,slot_id,vendor,model,serial_number,functions,slot_name,memory_size,memory_speed,disk_size,media_type
FROM jazzhands.v_device_components_expanded;



CREATE OR REPLACE VIEW jazzhands_legacy.v_device_components_json AS
SELECT device_id,components
FROM jazzhands.v_device_components_json;



CREATE OR REPLACE VIEW jazzhands_legacy.v_device_slot_connections AS
SELECT inter_component_connection_id,device_id,slot_id,slot_name,slot_index,mac_address,slot_type_id,slot_type,slot_function,remote_device_id,remote_slot_id,remote_slot_name,remote_slot_index,remote_mac_address,remote_slot_type_id,remote_slot_type,remote_slot_function
FROM jazzhands.v_device_slot_connections;



CREATE OR REPLACE VIEW jazzhands_legacy.v_device_slots AS
SELECT device_id,device_component_id,component_id,slot_id
FROM jazzhands.v_device_slots;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.v_dns AS
SELECT
	dns_record_id,
	network_range_id,
	dns_domain_id,
	dns_name,
	dns_ttl,
	dns_class,
	dns_type,
	dns_value,
	dns_priority,
	ip,
	netblock_id,
	ip_universe_id,
	ref_record_id,
	dns_srv_service,
	dns_srv_protocol,
	dns_srv_weight,
	dns_srv_port,
	CASE WHEN is_enabled IS NULL THEN NULL
		WHEN is_enabled = true THEN 'Y'
		WHEN is_enabled = false THEN 'N'
		ELSE NULL
	END AS is_enabled,
	CASE WHEN should_generate_ptr IS NULL THEN NULL
		WHEN should_generate_ptr = true THEN 'Y'
		WHEN should_generate_ptr = false THEN 'N'
		ELSE NULL
	END AS should_generate_ptr,
	dns_value_record_id
FROM jazzhands.v_dns;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.v_dns_changes_pending AS
SELECT
	dns_change_record_id,
	dns_domain_id,
	ip_universe_id,
	CASE WHEN should_generate IS NULL THEN NULL
		WHEN should_generate = true THEN 'Y'
		WHEN should_generate = false THEN 'N'
		ELSE NULL
	END AS should_generate,
	last_generated,
	dns_domain_name AS soa_name,
	ip_address
FROM jazzhands.v_dns_changes_pending;


--
-- show only ip universe zero.  Note that domains not in universe zero will
-- not show up here at all.
--
-- This is to be deprecated
--
CREATE OR REPLACE VIEW jazzhands_legacy.v_dns_domain_nouniverse AS
SELECT
	d.dns_domain_id,
	d.dns_domain_name AS soa_name,
	du.soa_class,
	du.soa_ttl,
	du.soa_serial,
	du.soa_refresh,
	du.soa_retry,
	du.soa_expire,
	du.soa_minimum,
	du.soa_mname,
	du.soa_rname,
	d.parent_dns_domain_id,
	CASE WHEN should_generate IS NULL THEN NULL
		WHEN should_generate = true THEN 'Y'
		WHEN should_generate = false THEN 'N'
		ELSE NULL
	END AS should_generate,
	du.last_generated,
	d.dns_domain_type,
	coalesce(d.data_ins_user, du.data_ins_user) as data_ins_user,
	coalesce(d.data_ins_date, du.data_ins_date) as data_ins_date,
	coalesce(du.data_upd_user, d.data_upd_user) as data_upd_user,
	coalesce(du.data_upd_date, d.data_upd_date) as data_upd_date
FROM jazzhands.dns_domain d
	JOIN jazzhands.dns_domain_ip_universe du USING (dns_domain_id)
WHERE ip_universe_id = 0
;


-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.v_dns_fwd AS
SELECT
	dns_record_id,
	network_range_id,
	dns_domain_id,
	dns_name,
	dns_ttl,
	dns_class,
	dns_type,
	dns_value,
	dns_priority,
	ip,
	netblock_id,
	ip_universe_id,
	ref_record_id,
	dns_srv_service,
	dns_srv_protocol,
	dns_srv_weight,
	dns_srv_port,
	CASE WHEN is_enabled IS NULL THEN NULL
		WHEN is_enabled = true THEN 'Y'
		WHEN is_enabled = false THEN 'N'
		ELSE NULL
	END AS is_enabled,
	CASE WHEN should_generate_ptr IS NULL THEN NULL
		WHEN should_generate_ptr = true THEN 'Y'
		WHEN should_generate_ptr = false THEN 'N'
		ELSE NULL
	END AS should_generate_ptr,
	dns_value_record_id
FROM jazzhands.v_dns_fwd;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.v_dns_rvs AS
SELECT
	dns_record_id,
	network_range_id,
	dns_domain_id,
	dns_name,
	dns_ttl,
	dns_class,
	dns_type,
	dns_value,
	dns_priority,
	ip,
	netblock_id,
	ip_universe_id,
	rdns_record_id,
	dns_srv_service,
	dns_srv_protocol,
	dns_srv_weight,
	dns_srv_srv_port,
	CASE WHEN is_enabled IS NULL THEN NULL
		WHEN is_enabled = true THEN 'Y'
		WHEN is_enabled = false THEN 'N'
		ELSE NULL
	END AS is_enabled,
	CASE WHEN should_generate_ptr IS NULL THEN NULL
		WHEN should_generate_ptr = true THEN 'Y'
		WHEN should_generate_ptr = false THEN 'N'
		ELSE NULL
	END AS should_generate_ptr,
	dns_value_record_id
FROM jazzhands.v_dns_rvs;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.v_dns_sorted AS
SELECT
	dns_record_id,
	network_range_id,
	dns_value_record_id,
	dns_name,
	dns_ttl,
	dns_class,
	dns_type,
	dns_value,
	dns_priority,
	ip,
	netblock_id,
	ref_record_id,
	dns_srv_service,
	dns_srv_protocol,
	dns_srv_weight,
	dns_srv_port,
	CASE WHEN should_generate_ptr IS NULL THEN NULL
		WHEN should_generate_ptr = true THEN 'Y'
		WHEN should_generate_ptr = false THEN 'N'
		ELSE NULL
	END AS should_generate_ptr,
	CASE WHEN is_enabled IS NULL THEN NULL
		WHEN is_enabled = true THEN 'Y'
		WHEN is_enabled = false THEN 'N'
		ELSE NULL
	END AS is_enabled,
	dns_domain_id,
	anchor_record_id,
	anchor_rank
FROM jazzhands.v_dns_sorted;



CREATE OR REPLACE VIEW jazzhands_legacy.v_hotpants_account_attribute AS
SELECT property_id,account_id,device_collection_id,login,property_name,property_type,property_value,property_rank,is_boolean
FROM jazzhands.v_hotpants_account_attribute;



CREATE OR REPLACE VIEW jazzhands_legacy.v_hotpants_client AS
SELECT device_id,device_name,ip_address,radius_secret
FROM jazzhands.v_hotpants_client;



CREATE OR REPLACE VIEW jazzhands_legacy.v_hotpants_dc_attribute AS
SELECT property_id,device_collection_id,property_name,property_type,property_rank,property_value
FROM jazzhands.v_hotpants_device_collection_attribute;



CREATE OR REPLACE VIEW jazzhands_legacy.v_hotpants_device_collection AS
SELECT device_id,device_name,device_collection_id,device_collection_name,device_collection_type,ip_address
FROM jazzhands.v_hotpants_device_collection;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.v_hotpants_token AS
SELECT
	token_id,
	token_type,
	token_status,
	token_serial,
	token_key,
	zero_time,
	time_modulo,
	token_password,
	CASE WHEN is_token_locked IS NULL THEN NULL
		WHEN is_token_locked = true THEN 'Y'
		WHEN is_token_locked = false THEN 'N'
		ELSE NULL
	END AS is_token_locked,
	token_unlock_time,
	bad_logins,
	token_sequence,
	last_updated,
	encryption_key_db_value,
	encryption_key_purpose,
	encryption_key_purpose_version,
	encryption_method
FROM jazzhands.v_hotpants_token;


CREATE OR REPLACE VIEW jazzhands_legacy.v_l1_all_physical_ports AS
WITH pp AS (
	SELECT
		sl.slot_id,
		ds.device_id,
		sl.slot_name,
		st.slot_function
	FROM
		jazzhands.slot sl JOIN
		jazzhands.slot_type st USING (slot_type_id) LEFT JOIN
		jazzhands.v_device_slots ds using (slot_id)
)
SELECT
	icc.inter_component_connection_id as layer1_connection_id,
	s1.slot_id as physical_port_id,
	s1.device_id as device_id,
	s1.slot_name as port_name,
	s1.slot_function as port_type,
	NULL as port_purpose,
	s2.slot_id as other_physical_port_id,
	s2.device_id as other_device_id,
	s2.slot_name as other_port_name,
	NULL as other_port_purpose,
	NULL::integer as baud,
	NULL::integer as data_bits,
	NULL::integer as stop_bits,
	NULL::varchar as parity,
	NULL::varchar as flow_control
FROM
	pp s1 JOIN
	jazzhands.inter_component_connection icc ON (s1.slot_id = icc.slot1_id) JOIN
	pp s2 ON (s2.slot_id = icc.slot2_id)
UNION
SELECT
	icc.inter_component_connection_id as layer1_connection_id,
	s2.slot_id as physical_port_id,
	s2.device_id as device_id,
	s2.slot_name as port_name,
	s2.slot_function as port_type,
	NULL as port_purpose,
	s1.slot_id as other_physical_port_id,
	s1.device_id as other_device_id,
	s1.slot_name as other_port_name,
	NULL as other_port_purpose,
	NULL::integer as baud,
	NULL::integer as data_bits,
	NULL::integer as stop_bits,
	NULL::varchar as parity,
	NULL::varchar as flow_control
FROM
	pp s1 JOIN
	jazzhands.inter_component_connection icc ON (s1.slot_id = icc.slot1_id) JOIN
	pp s2 ON (s2.slot_id = icc.slot2_id)
UNION
SELECT
	NULL as layer1_connection_id,
	s1.slot_id as physical_port_id,
	s1.device_id as device_id,
	s1.slot_name as port_name,
	s1.slot_function as port_type,
	NULL as port_purpose,
	NULL as other_physical_port_id,
	NULL as other_device_id,
	NULL as other_port_name,
	NULL as other_port_purpose,
	NULL::integer as baud,
	NULL::integer as data_bits,
	NULL::integer as stop_bits,
	NULL::varchar as parity,
	NULL::varchar as flow_control
FROM
	pp s1 LEFT JOIN
	jazzhands.inter_component_connection icc ON (s1.slot_id = icc.slot1_id OR
		s1.slot_id = icc.slot2_id)
WHERE
	inter_component_connection_id IS NULL;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.v_l2_network_coll_expanded AS
SELECT
	level,
	layer2_network_collection_id,
	root_layer2_network_collection_id AS root_l2_network_coll_id,
	text_path,
	array_path,
	rvs_array_path
FROM jazzhands.v_layer2_network_collection_expanded;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.v_l3_network_coll_expanded AS
SELECT
	level,
	layer3_network_collection_id,
	root_layer3_network_collection_id AS root_l3_network_coll_id,
	text_path,
	array_path,
	rvs_array_path
FROM jazzhands.v_layer3_network_collection_expanded;



CREATE OR REPLACE VIEW jazzhands_legacy.v_layerx_network_expanded AS
SELECT layer3_network_id,layer3_network_description,netblock_id,ip_address,netblock_type,ip_universe_id,default_gateway_netblock_id,default_gateway_ip_address,default_gateway_netblock_type,default_gateway_ip_universe_id,layer2_network_id,encapsulation_name,encapsulation_domain,encapsulation_type,encapsulation_tag,layer2_network_description
FROM jazzhands.v_layerx_network_expanded;



CREATE OR REPLACE VIEW jazzhands_legacy.v_lv_hier AS
SELECT physicalish_volume_id,volume_group_id,logical_volume_id,child_pv_id,child_vg_id,child_lv_id,pv_path,vg_path,lv_path
FROM jazzhands.v_lv_hier;



CREATE OR REPLACE VIEW jazzhands_legacy.v_nblk_coll_netblock_expanded AS
SELECT netblock_collection_id,netblock_id
FROM jazzhands.v_netblock_collection_netblock_expanded;



CREATE OR REPLACE VIEW jazzhands_legacy.v_netblock_coll_expanded AS
SELECT level,netblock_collection_id,root_netblock_collection_id,text_path,array_path,rvs_array_path
FROM jazzhands.v_netblock_collection_expanded;



CREATE OR REPLACE VIEW jazzhands_legacy.v_netblock_collection_hier_from_ancestor AS
SELECT root_netblock_collection_id,netblock_collection_id,path,cycle
FROM jazzhands.v_netblock_collection_hier_from_ancestor;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.v_netblock_hier AS
SELECT
	netblock_level,
	root_netblock_id,
	ip,
	netblock_id,
	ip_address,
	netblock_status,
	CASE WHEN is_single_address IS NULL THEN NULL
		WHEN is_single_address = true THEN 'Y'
		WHEN is_single_address = false THEN 'N'
		ELSE NULL
	END AS is_single_address,
	description,
	parent_netblock_id,
	site_code,
	text_path,
	array_path,
	array_ip_path
FROM jazzhands.v_netblock_hier;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.v_netblock_hier_expanded AS
SELECT
	netblock_level,
	root_netblock_id,
	site_code,
	path,
	netblock_id,
	ip_address,
	netblock_type,
	CASE WHEN is_single_address IS NULL THEN NULL
		WHEN is_single_address = true THEN 'Y'
		WHEN is_single_address = false THEN 'N'
		ELSE NULL
	END AS is_single_address,
	CASE WHEN can_subnet IS NULL THEN NULL
		WHEN can_subnet = true THEN 'Y'
		WHEN can_subnet = false THEN 'N'
		ELSE NULL
	END AS can_subnet,
	parent_netblock_id,
	netblock_status,
	ip_universe_id,
	description,
	external_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.v_netblock_hier_expanded;



CREATE OR REPLACE VIEW jazzhands_legacy.v_network_range_expanded AS
SELECT network_range_id,network_range_type,description,parent_netblock_id,ip_address,netblock_type,ip_universe_id,start_netblock_id,start_ip_address,start_netblock_type,start_ip_universe_id,stop_netblock_id,stop_ip_address,stop_netblock_type,stop_ip_universe_id,dns_prefix,dns_domain_id,dns_domain_name AS soa_name
FROM jazzhands.v_network_range_expanded;



CREATE OR REPLACE VIEW jazzhands_legacy.v_person AS
SELECT
	person_id,
	description,
	first_name,
	middle_name,
	last_name,
	name_suffix,
	CASE WHEN gender = 'male' THEN 'M'
		WHEN gender = 'female' THEN 'F'
		ELSE 'U' END as gender,
	preferred_first_name,
	preferred_last_name,
	legal_first_name,
	legal_last_name,
	nickname,
	birth_date,
	diet,
	shirt_size,
	pant_size,
	hat_size,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.v_person;

-- Deprecated table with some column renames
CREATE OR REPLACE VIEW jazzhands_legacy.v_person_company AS
SELECT pc.company_id,
	pc.person_id,
	pc.person_company_status,
	pc.person_company_relation,
	CASE WHEN pc.is_exempt IS NULL THEN NULL
		WHEN is_exempt = true THEN 'Y'
		WHEN is_exempt = false THEN 'N'
		ELSE NULL
	END AS is_exempt,
	CASE WHEN pc.is_management IS NULL THEN NULL
		WHEN is_management = true THEN 'Y'
		WHEN is_management = false THEN 'N'
		ELSE NULL
	END AS is_management,
	CASE WHEN pc.is_full_time IS NULL THEN NULL
		WHEN is_full_time = true THEN 'Y'
		WHEN is_full_time = false THEN 'N'
		ELSE NULL
	END AS is_full_time,
	pc.description,
	empid.attribute_value AS employee_id,
	payid.attribute_value AS payroll_id,
	hrid.attribute_value AS external_hr_id,
	pc.position_title,
	badge.attribute_value AS badge_system_id,
	pc.hire_date,
	pc.termination_date,
	pc.manager_person_id,
	super.attribute_value_person_id AS supervisor_person_id,
	pc.nickname,
	pc.data_ins_user,
	pc.data_ins_date,
	pc.data_upd_user,
	pc.data_upd_date
FROM	jazzhands.person_company pc
	LEFT JOIN (SELECT *
		FROM jazzhands.person_company_attribute
		WHERE person_company_attribute_name = 'employee_id'
		) empid USING (company_id, person_id)
	LEFT JOIN (SELECT *
		FROM jazzhands.person_company_attribute
		WHERE person_company_attribute_name = 'payroll_id'
		) payid USING (company_id, person_id)
	LEFT JOIN (SELECT *
		FROM jazzhands.person_company_attribute
		WHERE person_company_attribute_name = 'badge_system_id'
		) badge USING (company_id, person_id)
	LEFT JOIN (SELECT *
		FROM jazzhands.person_company_attribute
		WHERE person_company_attribute_name = 'supervisor_id'
		) super USING (company_id, person_id)
	LEFT JOIN (SELECT *
		FROM jazzhands.person_company_attribute
		WHERE person_company_attribute_name = 'external_hr_id'
		) hrid USING (company_id, person_id)
;

ALTER TABLE jazzhands_legacy.v_person_company ALTER is_exempt SET DEFAULT 'Y'::text;
ALTER TABLE jazzhands_legacy.v_person_company ALTER is_management SET DEFAULT 'N'::text;
ALTER TABLE jazzhands_legacy.v_person_company ALTER is_full_time SET DEFAULT 'Y'::text;

--
-- This is a hack but hopefully nothing is uesing it.
--
CREATE OR REPLACE VIEW jazzhands_legacy.v_account_manager_map AS
SELECT login, account_id, person_id, company_id, account_realm_id, first_name, last_name, middle_name, manager_person_id, employee_id, human_readable, manager_account_id, manager_login, manager_human_readable, manager_last_name, manager_middle_name, manger_first_name, manager_employee_id, manager_company_id
FROM jazzhands.v_account_manager_map  map
	JOIN ( SELECT company_id, person_id, employee_id
		FROM jazzhands_legacy.v_person_company
	) emp_pc USING (person_id, company_id)
	JOIN ( SELECT company_id AS manager_company_id,
		person_id AS manager_person_id,
		employee_id AS manager_employee_id
		FROM jazzhands_legacy.v_person_company
	) mgr_pc USING (manager_person_id, manager_company_id)
;


CREATE OR REPLACE VIEW jazzhands_legacy.v_person_company_expanded AS
SELECT company_id,person_id
FROM jazzhands.v_person_company_expanded;



CREATE OR REPLACE VIEW jazzhands_legacy.v_person_company_hier AS
SELECT level,person_id,subordinate_person_id,intermediate_person_id,person_company_relation,array_path,rvs_array_path,cycle
FROM jazzhands.v_person_company_hier;



CREATE OR REPLACE VIEW jazzhands_legacy.v_physical_connection AS
SELECT level,inter_component_connection_id,layer1_connection_id,physical_connection_id,inter_dev_conn_slot1_id,inter_dev_conn_slot2_id,layer1_physical_port1_id,layer1_physical_port2_id,slot1_id,slot2_id,physical_port1_id,physical_port2_id
FROM jazzhands.v_physical_connection;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.v_property AS
SELECT
	property_id,
	account_collection_id,
	account_id,
	account_realm_id,
	company_collection_id,
	company_id,
	device_collection_id,
	dns_domain_collection_id,
	layer2_network_collection_id,
	layer3_network_collection_id,
	netblock_collection_id,
	network_range_id,
	operating_system_id,
	operating_system_snapshot_id,
	property_name_collection_id AS property_collection_id,
	service_environment_collection_id AS service_env_collection_id,
	site_code,
	x509_signed_certificate_id,
	property_name,
	property_type,
	cast(CASE WHEN property_value_boolean = true THEN 'Y'
		WHEN property_value_boolean = false THEN 'N'
		ELSE property_value END AS varchar(1024)) AS property_value,
	property_value_timestamp,
	property_value_account_collection_id AS property_value_account_coll_id,
	property_value_device_collection_id AS property_value_device_coll_id,
	property_value_json,
	property_value_netblock_collection_id AS property_value_nblk_coll_id,
	property_value_password_type,
	NULL::integer AS property_value_sw_package_id,
	property_value_token_collection_id AS property_value_token_col_id,
	property_rank,
	start_date,
	finish_date,
	CASE WHEN is_enabled IS NULL THEN NULL
		WHEN is_enabled = true THEN 'Y'
		WHEN is_enabled = false THEN 'N'
		ELSE NULL
	END AS is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.v_property;



CREATE OR REPLACE VIEW jazzhands_legacy.v_site_netblock_expanded AS
SELECT site_code,netblock_id
FROM jazzhands.v_site_netblock_expanded;



CREATE OR REPLACE VIEW jazzhands_legacy.v_site_netblock_expanded_assigned AS
SELECT site_code,netblock_id
FROM jazzhands.v_site_netblock_expanded_assigned;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.v_token AS
SELECT
	token_id,
	token_type,
	token_status,
	token_serial,
	token_sequence,
	account_id,
	token_password,
	zero_time,
	time_modulo,
	time_skew,
	CASE WHEN is_token_locked IS NULL THEN NULL
		WHEN is_token_locked = true THEN 'Y'
		WHEN is_token_locked = false THEN 'N'
		ELSE NULL
	END AS is_token_locked,
	token_unlock_time,
	bad_logins,
	issued_date,
	token_last_updated,
	token_sequence_last_updated,
	lock_status_last_updated
FROM jazzhands.v_token;



CREATE OR REPLACE VIEW jazzhands_legacy.v_unix_account_overrides AS
SELECT device_collection_id,account_id,setting
FROM jazzhands.v_unix_account_overrides;



CREATE OR REPLACE VIEW jazzhands_legacy.v_unix_group_mappings AS
SELECT device_collection_id,account_collection_id,group_name,unix_gid,group_password,setting,mclass_setting,members
FROM jazzhands.v_unix_group_mappings;



CREATE OR REPLACE VIEW jazzhands_legacy.v_unix_group_overrides AS
SELECT device_collection_id,account_collection_id,setting
FROM jazzhands.v_unix_group_overrides;



CREATE OR REPLACE VIEW jazzhands_legacy.v_unix_mclass_settings AS
SELECT device_collection_id,mclass_setting
FROM jazzhands.v_unix_mclass_settings;



CREATE OR REPLACE VIEW jazzhands_legacy.v_unix_passwd_mappings AS
SELECT device_collection_id,account_id,login,crypt,unix_uid,unix_group_name,gecos,home,shell,ssh_public_key,setting,mclass_setting,extra_groups
FROM jazzhands.v_unix_passwd_mappings;



CREATE OR REPLACE VIEW jazzhands_legacy.val_account_collection_relatio AS
SELECT account_collection_relation,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_account_collection_relation;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_account_collection_type AS
SELECT
	account_collection_type,
	description,
	CASE WHEN is_infrastructure_type IS NULL THEN NULL
		WHEN is_infrastructure_type = true THEN 'Y'
		WHEN is_infrastructure_type = false THEN 'N'
		ELSE NULL
	END AS is_infrastructure_type,
	max_num_members,
	max_num_collections,
	CASE WHEN can_have_hierarchy IS NULL THEN NULL
		WHEN can_have_hierarchy = true THEN 'Y'
		WHEN can_have_hierarchy = false THEN 'N'
		ELSE NULL
	END AS can_have_hierarchy,
	account_realm_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_account_collection_type;

ALTER TABLE jazzhands_legacy.val_account_collection_type ALTER is_infrastructure_type SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands_legacy.val_account_collection_type ALTER can_have_hierarchy SET DEFAULT 'Y'::bpchar;

-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_account_role AS
SELECT
	account_role,
	CASE WHEN uid_gid_forced IS NULL THEN NULL
		WHEN uid_gid_forced = true THEN 'Y'
		WHEN uid_gid_forced = false THEN 'N'
		ELSE NULL
	END AS uid_gid_forced,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_account_role;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_account_type AS
SELECT
	account_type,
	CASE WHEN is_person IS NULL THEN NULL
		WHEN is_person = true THEN 'Y'
		WHEN is_person = false THEN 'N'
		ELSE NULL
	END AS is_person,
	CASE WHEN uid_gid_forced IS NULL THEN NULL
		WHEN uid_gid_forced = true THEN 'Y'
		WHEN uid_gid_forced = false THEN 'N'
		ELSE NULL
	END AS uid_gid_forced,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_account_type;



CREATE OR REPLACE VIEW jazzhands_legacy.val_app_key AS
SELECT appaal_group_name,
	application_key AS app_key,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_application_key;



CREATE OR REPLACE VIEW jazzhands_legacy.val_app_key_values AS
SELECT	appaal_group_name,
	application_key AS app_key,
	application_value AS app_value,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_application_key_values;



CREATE OR REPLACE VIEW jazzhands_legacy.val_appaal_group_name AS
SELECT appaal_group_name,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_appaal_group_name;



CREATE OR REPLACE VIEW jazzhands_legacy.val_approval_chain_resp_prd AS
SELECT approval_chain_response_period,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_approval_chain_response_period;



CREATE OR REPLACE VIEW jazzhands_legacy.val_approval_expiration_action AS
SELECT approval_expiration_action,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_approval_expiration_action;



CREATE OR REPLACE VIEW jazzhands_legacy.val_approval_notifty_type AS
SELECT approval_notify_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_approval_notifty_type;



CREATE OR REPLACE VIEW jazzhands_legacy.val_approval_process_type AS
SELECT approval_process_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_approval_process_type;



CREATE OR REPLACE VIEW jazzhands_legacy.val_approval_type AS
SELECT approval_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_approval_type;



CREATE OR REPLACE VIEW jazzhands_legacy.val_attestation_frequency AS
SELECT attestation_frequency,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_attestation_frequency;



CREATE OR REPLACE VIEW jazzhands_legacy.val_auth_question AS
SELECT authentication_question_id AS auth_question_id,
	question_text,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_authentication_question;



CREATE OR REPLACE VIEW jazzhands_legacy.val_auth_resource AS
SELECT	authentication_resource AS auth_resource,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_authentication_resource;



CREATE OR REPLACE VIEW jazzhands_legacy.val_badge_status AS
SELECT badge_status,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_badge_status;



CREATE OR REPLACE VIEW jazzhands_legacy.val_cable_type AS
SELECT cable_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_cable_type;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_company_collection_type AS
SELECT
	company_collection_type,
	description,
	CASE WHEN is_infrastructure_type IS NULL THEN NULL
		WHEN is_infrastructure_type = true THEN 'Y'
		WHEN is_infrastructure_type = false THEN 'N'
		ELSE NULL
	END AS is_infrastructure_type,
	max_num_members,
	max_num_collections,
	CASE WHEN can_have_hierarchy IS NULL THEN NULL
		WHEN can_have_hierarchy = true THEN 'Y'
		WHEN can_have_hierarchy = false THEN 'N'
		ELSE NULL
	END AS can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_company_collection_type;

ALTER TABLE jazzhands_legacy.val_company_collection_type ALTER is_infrastructure_type SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands_legacy.val_company_collection_type ALTER can_have_hierarchy SET DEFAULT 'Y'::bpchar;

CREATE OR REPLACE VIEW jazzhands_legacy.val_company_type AS
SELECT company_type,description,company_type_purpose,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_company_type;

CREATE OR REPLACE VIEW jazzhands_legacy.val_company_type_purpose AS
SELECT company_type_purpose,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_company_type_purpose;



CREATE OR REPLACE VIEW jazzhands_legacy.val_component_function AS
SELECT component_function,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_component_function;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_component_property AS
SELECT
	component_property_name,
	component_property_type,
	description,
	CASE WHEN is_multivalue IS NULL THEN NULL
		WHEN is_multivalue = true THEN 'Y'
		WHEN is_multivalue = false THEN 'N'
		ELSE NULL
	END AS is_multivalue,
	property_data_type,
	permit_component_type_id,
	required_component_type_id,
	permit_component_function,
	required_component_function,
	permit_component_id,
	permit_inter_component_connection_id AS permit_intcomp_conn_id,
	permit_slot_type_id,
	required_slot_type_id,
	permit_slot_function,
	required_slot_function,
	permit_slot_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_component_property;

ALTER TABLE jazzhands_legacy.val_component_property ALTER permit_component_type_id SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_component_property ALTER permit_component_function SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_component_property ALTER permit_component_id SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_component_property ALTER permit_intcomp_conn_id SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_component_property ALTER permit_slot_type_id SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_component_property ALTER permit_slot_function SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_component_property ALTER permit_slot_id SET DEFAULT 'PROHIBITED'::bpchar;

-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_component_property_type AS
SELECT
	component_property_type,
	description,
	CASE WHEN is_multivalue IS NULL THEN NULL
		WHEN is_multivalue = true THEN 'Y'
		WHEN is_multivalue = false THEN 'N'
		ELSE NULL
	END AS is_multivalue,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_component_property_type;

CREATE OR REPLACE VIEW jazzhands_legacy.val_component_property_value AS
SELECT component_property_name,component_property_type,valid_property_value,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_component_property_value;



CREATE OR REPLACE VIEW jazzhands_legacy.val_contract_type AS
SELECT contract_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_contract_type;



CREATE OR REPLACE VIEW jazzhands_legacy.val_country_code AS
SELECT iso_country_code,dial_country_code,primary_iso_currency_code,country_name,display_priority,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_country_code;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_device_collection_type AS
SELECT
	device_collection_type,
	description,
	max_num_members,
	max_num_collections,
	CASE WHEN can_have_hierarchy IS NULL THEN NULL
		WHEN can_have_hierarchy = true THEN 'Y'
		WHEN can_have_hierarchy = false THEN 'N'
		ELSE NULL
	END AS can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_device_collection_type;

CREATE OR REPLACE VIEW jazzhands_legacy.val_device_mgmt_ctrl_type AS
SELECT device_management_controller_type AS device_mgmt_control_type,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_device_management_controller_type;

CREATE OR REPLACE VIEW jazzhands_legacy.val_device_status AS
SELECT device_status,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_device_status;



CREATE OR REPLACE VIEW jazzhands_legacy.val_diet AS
SELECT diet,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_diet;



CREATE OR REPLACE VIEW jazzhands_legacy.val_dns_class AS
SELECT dns_class,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_dns_class;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_dns_domain_collection_type AS
SELECT
	dns_domain_collection_type,
	description,
	max_num_members,
	max_num_collections,
	CASE WHEN can_have_hierarchy IS NULL THEN NULL
		WHEN can_have_hierarchy = true THEN 'Y'
		WHEN can_have_hierarchy = false THEN 'N'
		ELSE NULL
	END AS can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_dns_domain_collection_type;

-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_dns_domain_type AS
SELECT
	dns_domain_type,
	CASE WHEN can_generate IS NULL THEN NULL
		WHEN can_generate = true THEN 'Y'
		WHEN can_generate = false THEN 'N'
		ELSE NULL
	END AS can_generate,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_dns_domain_type;

CREATE OR REPLACE VIEW jazzhands_legacy.val_dns_record_relation_type AS
SELECT dns_record_relation_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_dns_record_relation_type;



CREATE OR REPLACE VIEW jazzhands_legacy.val_dns_srv_service AS
SELECT dns_srv_service,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_dns_srv_service;



CREATE OR REPLACE VIEW jazzhands_legacy.val_dns_type AS
SELECT dns_type,description,id_type,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_dns_type;



CREATE OR REPLACE VIEW jazzhands_legacy.val_encapsulation_mode AS
SELECT encapsulation_mode,encapsulation_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_encapsulation_mode;



CREATE OR REPLACE VIEW jazzhands_legacy.val_encapsulation_type AS
SELECT encapsulation_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_encapsulation_type;



CREATE OR REPLACE VIEW jazzhands_legacy.val_encryption_key_purpose AS
SELECT encryption_key_purpose,encryption_key_purpose_version,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_encryption_key_purpose;



CREATE OR REPLACE VIEW jazzhands_legacy.val_encryption_method AS
SELECT encryption_method,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_encryption_method;



CREATE OR REPLACE VIEW jazzhands_legacy.val_filesystem_type AS
SELECT filesystem_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_filesystem_type;



CREATE OR REPLACE VIEW jazzhands_legacy.val_image_type AS
SELECT image_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_image_type;



CREATE OR REPLACE VIEW jazzhands_legacy.val_ip_namespace AS
SELECT ip_namespace,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_ip_namespace;



CREATE OR REPLACE VIEW jazzhands_legacy.val_iso_currency_code AS
SELECT iso_currency_code,description,currency_symbol,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_iso_currency_code;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_key_usg_reason_for_assgn AS
SELECT
	key_usage_reason_for_assignment AS key_usage_reason_for_assign,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_key_usage_reason_for_assignment;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_layer2_network_coll_type AS
SELECT
	layer2_network_collection_type,
	description,
	max_num_members,
	max_num_collections,
	CASE WHEN can_have_hierarchy IS NULL THEN NULL
		WHEN can_have_hierarchy = true THEN 'Y'
		WHEN can_have_hierarchy = false THEN 'N'
		ELSE NULL
	END AS can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_layer2_network_collection_type;

-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_layer3_network_coll_type AS
SELECT
	layer3_network_collection_type,
	description,
	max_num_members,
	max_num_collections,
	CASE WHEN can_have_hierarchy IS NULL THEN NULL
		WHEN can_have_hierarchy = true THEN 'Y'
		WHEN can_have_hierarchy = false THEN 'N'
		ELSE NULL
	END AS can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_layer3_network_collection_type;

CREATE OR REPLACE VIEW jazzhands_legacy.val_logical_port_type AS
SELECT logical_port_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_logical_port_type;



CREATE OR REPLACE VIEW jazzhands_legacy.val_logical_volume_property AS
SELECT logical_volume_property_name,filesystem_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_logical_volume_property;



CREATE OR REPLACE VIEW jazzhands_legacy.val_logical_volume_purpose AS
SELECT logical_volume_purpose,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_logical_volume_purpose;



CREATE OR REPLACE VIEW jazzhands_legacy.val_logical_volume_type AS
SELECT logical_volume_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_logical_volume_type;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_netblock_collection_type AS
SELECT
	netblock_collection_type,
	description,
	max_num_members,
	max_num_collections,
	CASE WHEN can_have_hierarchy IS NULL THEN NULL
		WHEN can_have_hierarchy = true THEN 'Y'
		WHEN can_have_hierarchy = false THEN 'N'
		ELSE NULL
	END AS can_have_hierarchy,
	netblock_is_single_address_restriction AS netblock_single_addr_restrict,
	netblock_ip_family_restriction AS netblock_ip_family_restrict,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_netblock_collection_type;

ALTER TABLE jazzhands_legacy.val_netblock_collection_type ALTER can_have_hierarchy SET DEFAULT 'Y'::bpchar;
ALTER TABLE jazzhands_legacy.val_netblock_collection_type ALTER netblock_single_addr_restrict SET DEFAULT 'ANY'::character varying;

CREATE OR REPLACE VIEW jazzhands_legacy.val_netblock_status AS
SELECT netblock_status,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_netblock_status;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_netblock_type AS
SELECT
	netblock_type,
	description,
	CASE WHEN db_forced_hierarchy IS NULL THEN NULL
		WHEN db_forced_hierarchy = true THEN 'Y'
		WHEN db_forced_hierarchy = false THEN 'N'
		ELSE NULL
	END AS db_forced_hierarchy,
	CASE WHEN is_validated_hierarchy IS NULL THEN NULL
		WHEN is_validated_hierarchy = true THEN 'Y'
		WHEN is_validated_hierarchy = false THEN 'N'
		ELSE NULL
	END AS is_validated_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_netblock_type;



CREATE OR REPLACE VIEW jazzhands_legacy.val_network_interface_purpose AS
SELECT layer3_interface_purpose AS network_interface_purpose,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_layer3_interface_purpose;



CREATE OR REPLACE VIEW jazzhands_legacy.val_network_interface_type AS
SELECT layer3_interface_type AS network_interface_type,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_layer3_interface_type;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_network_range_type AS
SELECT
	network_range_type,
	description,
	dns_domain_required,
	default_dns_prefix,
	netblock_type,
	CASE WHEN can_overlap IS NULL THEN NULL
		WHEN can_overlap = true THEN 'Y'
		WHEN can_overlap = false THEN 'N'
		ELSE NULL
	END AS can_overlap,
	CASE WHEN require_cidr_boundary IS NULL THEN NULL
		WHEN require_cidr_boundary = true THEN 'Y'
		WHEN require_cidr_boundary = false THEN 'N'
		ELSE NULL
	END AS require_cidr_boundary,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_network_range_type;

ALTER TABLE jazzhands_legacy.val_network_range_type ALTER dns_domain_required SET DEFAULT 'REQUIRED'::bpchar;
ALTER TABLE jazzhands_legacy.val_network_range_type ALTER can_overlap SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands_legacy.val_network_range_type ALTER require_cidr_boundary SET DEFAULT 'N'::bpchar;

CREATE OR REPLACE VIEW jazzhands_legacy.val_network_service_type AS
SELECT network_service_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_network_service_type;



CREATE OR REPLACE VIEW jazzhands_legacy.val_operating_system_family AS
SELECT operating_system_family,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_operating_system_family;



CREATE OR REPLACE VIEW jazzhands_legacy.val_os_snapshot_type AS
SELECT operating_system_snapshot_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_operating_system_snapshot_type;



CREATE OR REPLACE VIEW jazzhands_legacy.val_ownership_status AS
SELECT ownership_status,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_ownership_status;


CREATE OR REPLACE VIEW jazzhands_legacy.val_password_type AS
SELECT password_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_password_type;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_person_company_attr_dtype AS
SELECT
	person_company_attribute_data_type AS person_company_attr_data_type,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_person_company_attribute_data_type;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_person_company_attr_name AS
SELECT
	person_company_attribute_name AS person_company_attr_name,
	person_company_attribute_data_type AS person_company_attr_data_type,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_person_company_attribute_name;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_person_company_attr_value AS
SELECT
	person_company_attribute_name AS person_company_attr_name,
	person_company_attribute_value AS person_company_attr_value,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_person_company_attribute_value;



CREATE OR REPLACE VIEW jazzhands_legacy.val_person_company_relation AS
SELECT person_company_relation,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_person_company_relation;



CREATE OR REPLACE VIEW jazzhands_legacy.val_person_contact_loc_type AS
SELECT person_contact_location_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_person_contact_location_type;



CREATE OR REPLACE VIEW jazzhands_legacy.val_person_contact_technology AS
SELECT person_contact_technology,person_contact_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_person_contact_technology;



CREATE OR REPLACE VIEW jazzhands_legacy.val_person_contact_type AS
SELECT person_contact_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_person_contact_type;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_person_image_usage AS
SELECT
	person_image_usage,
	CASE WHEN is_multivalue IS NULL THEN NULL
		WHEN is_multivalue = true THEN 'Y'
		WHEN is_multivalue = false THEN 'N'
		ELSE NULL
	END AS is_multivalue,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_person_image_usage;



CREATE OR REPLACE VIEW jazzhands_legacy.val_person_location_type AS
SELECT person_location_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_person_location_type;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_person_status AS
SELECT
	person_status,
	description,
	CASE WHEN is_enabled IS NULL THEN NULL
		WHEN is_enabled = true THEN 'Y'
		WHEN is_enabled = false THEN 'N'
		ELSE NULL
	END AS is_enabled,
	CASE WHEN propagate_from_person IS NULL THEN NULL
		WHEN propagate_from_person = true THEN 'Y'
		WHEN propagate_from_person = false THEN 'N'
		ELSE NULL
	END AS propagate_from_person,
	CASE WHEN is_forced IS NULL THEN NULL
		WHEN is_forced = true THEN 'Y'
		WHEN is_forced = false THEN 'N'
		ELSE NULL
	END AS is_forced,
	CASE WHEN is_db_enforced IS NULL THEN NULL
		WHEN is_db_enforced = true THEN 'Y'
		WHEN is_db_enforced = false THEN 'N'
		ELSE NULL
	END AS is_db_enforced,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_person_status;

ALTER TABLE jazzhands_legacy.val_person_status ALTER is_forced SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands_legacy.val_person_status ALTER is_db_enforced SET DEFAULT 'N'::bpchar;

CREATE OR REPLACE VIEW jazzhands_legacy.val_physical_address_type AS
SELECT physical_address_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_physical_address_type;



CREATE OR REPLACE VIEW jazzhands_legacy.val_physicalish_volume_type AS
SELECT physicalish_volume_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_physicalish_volume_type;



CREATE OR REPLACE VIEW jazzhands_legacy.val_processor_architecture AS
SELECT processor_architecture,kernel_bits,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_processor_architecture;



CREATE OR REPLACE VIEW jazzhands_legacy.val_production_state AS
SELECT production_state,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_production_state;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_property AS
SELECT
	property_name,
	property_type,
	description,
	account_collection_type,
	company_collection_type,
	device_collection_type,
	dns_domain_collection_type,
	layer2_network_collection_type,
	layer3_network_collection_type,
	netblock_collection_type,
	network_range_type,
	property_name_collection_type AS property_collection_type,
	service_environment_collection_type AS service_env_collection_type,
	CASE WHEN is_multivalue IS NULL THEN NULL
		WHEN is_multivalue = true THEN 'Y'
		WHEN is_multivalue = false THEN 'N'
		ELSE NULL
	END AS is_multivalue,
	property_value_account_collection_type_restriction AS prop_val_acct_coll_type_rstrct,
	property_value_device_collection_type_restriction AS prop_val_dev_coll_type_rstrct,
	property_value_netblock_collection_type_restriction AS prop_val_nblk_coll_type_rstrct,
	property_data_type,
	property_value_json_schema,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_company_collection_id,
	permit_device_collection_id,
	permit_dns_domain_collection_id AS permit_dns_domain_coll_id,
	permit_layer2_network_collection_id AS permit_layer2_network_coll_id,
	permit_layer3_network_collection_id AS permit_layer3_network_coll_id,
	permit_netblock_collection_id,
	permit_network_range_id,
	permit_operating_system_id,
	permit_operating_system_snapshot_id AS permit_os_snapshot_id,
	permit_property_name_collection_id AS permit_property_collection_id,
	permit_service_environment_collection_id AS permit_service_env_collection,
	permit_site_code,
	permit_x509_signed_certificate_id AS permit_x509_signed_cert_id,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_property;

ALTER TABLE jazzhands_legacy.val_property ALTER is_multivalue SET DEFAULT 'N'::bpchar;
ALTER TABLE jazzhands_legacy.val_property ALTER permit_account_collection_id SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property ALTER permit_account_id SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property ALTER permit_account_realm_id SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property ALTER permit_company_id SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property ALTER permit_company_collection_id SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property ALTER permit_device_collection_id SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property ALTER permit_dns_domain_coll_id SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property ALTER permit_layer2_network_coll_id SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property ALTER permit_layer3_network_coll_id SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property ALTER permit_netblock_collection_id SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property ALTER permit_network_range_id SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property ALTER permit_operating_system_id SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property ALTER permit_os_snapshot_id SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property ALTER permit_property_collection_id SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property ALTER permit_service_env_collection SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property ALTER permit_site_code SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property ALTER permit_x509_signed_cert_id SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE jazzhands_legacy.val_property ALTER permit_property_rank SET DEFAULT 'PROHIBITED'::bpchar;

-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_property_collection_type AS
SELECT
	property_name_collection_type AS property_collection_type,
	description,
	max_num_members,
	max_num_collections,
	CASE WHEN can_have_hierarchy IS NULL THEN NULL
		WHEN can_have_hierarchy = true THEN 'Y'
		WHEN can_have_hierarchy = false THEN 'N'
		ELSE NULL
	END AS can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_property_name_collection_type;

CREATE OR REPLACE VIEW jazzhands_legacy.val_property_data_type AS
SELECT property_data_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_property_data_type;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_property_type AS
SELECT
	property_type,
	description,
	property_value_account_collection_type_restriction AS prop_val_acct_coll_type_rstrct,
	CASE WHEN is_multivalue IS NULL THEN NULL
		WHEN is_multivalue = true THEN 'Y'
		WHEN is_multivalue = false THEN 'N'
		ELSE NULL
	END AS is_multivalue,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_property_type;

CREATE OR REPLACE VIEW jazzhands_legacy.val_property_value AS
SELECT property_name,property_type,valid_property_value,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_property_value;



CREATE OR REPLACE VIEW jazzhands_legacy.val_pvt_key_encryption_type AS
SELECT private_key_encryption_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_private_key_encryption_type;



CREATE OR REPLACE VIEW jazzhands_legacy.val_rack_type AS
SELECT rack_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_rack_type;



CREATE OR REPLACE VIEW jazzhands_legacy.val_raid_type AS
SELECT raid_type,description,primary_raid_level,secondary_raid_level,raid_level_qualifier,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_raid_type;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_service_env_coll_type AS
SELECT
	service_environment_collection_type AS service_env_collection_type,
	description,
	max_num_members,
	max_num_collections,
	CASE WHEN can_have_hierarchy IS NULL THEN NULL
		WHEN can_have_hierarchy = true THEN 'Y'
		WHEN can_have_hierarchy = false THEN 'N'
		ELSE NULL
	END AS can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_service_environment_collection_type;

CREATE OR REPLACE VIEW jazzhands_legacy.val_shared_netblock_protocol AS
SELECT shared_netblock_protocol,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_shared_netblock_protocol;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_slot_function AS
SELECT
	slot_function,
	description,
	CASE WHEN can_have_mac_address IS NULL THEN NULL
		WHEN can_have_mac_address = true THEN 'Y'
		WHEN can_have_mac_address = false THEN 'N'
		ELSE NULL
	END AS can_have_mac_address,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_slot_function;

CREATE OR REPLACE VIEW jazzhands_legacy.val_slot_physical_interface AS
SELECT slot_physical_interface_type,slot_function,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_slot_physical_interface;



CREATE OR REPLACE VIEW jazzhands_legacy.val_ssh_key_type AS
SELECT ssh_key_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_ssh_key_type;



CREATE OR REPLACE VIEW jazzhands_legacy.val_sw_package_type AS
SELECT software_artifact_type AS sw_package_type,
	description,
	data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_software_artifact_type;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_token_collection_type AS
SELECT
	token_collection_type,
	description,
	max_num_members,
	max_num_collections,
	CASE WHEN can_have_hierarchy IS NULL THEN NULL
		WHEN can_have_hierarchy = true THEN 'Y'
		WHEN can_have_hierarchy = false THEN 'N'
		ELSE NULL
	END AS can_have_hierarchy,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_token_collection_type;

CREATE OR REPLACE VIEW jazzhands_legacy.val_token_status AS
SELECT token_status,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_token_status;



CREATE OR REPLACE VIEW jazzhands_legacy.val_token_type AS
SELECT token_type,description,token_digit_count,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_token_type;



CREATE OR REPLACE VIEW jazzhands_legacy.val_volume_group_purpose AS
SELECT volume_group_purpose,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_volume_group_purpose;



CREATE OR REPLACE VIEW jazzhands_legacy.val_volume_group_relation AS
SELECT volume_group_relation,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_volume_group_relation;



CREATE OR REPLACE VIEW jazzhands_legacy.val_volume_group_type AS
SELECT volume_group_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_volume_group_type;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_x509_certificate_file_fmt AS
SELECT
	x509_certificate_file_format AS x509_file_format,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_x509_certificate_file_format;



CREATE OR REPLACE VIEW jazzhands_legacy.val_x509_certificate_type AS
SELECT x509_certificate_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_x509_certificate_type;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_x509_key_usage AS
SELECT
	x509_key_usage AS x509_key_usg,
	description,
	CASE WHEN is_extended IS NULL THEN NULL
		WHEN is_extended = true THEN 'Y'
		WHEN is_extended = false THEN 'N'
		ELSE NULL
	END AS is_extended,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_x509_key_usage;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.val_x509_key_usage_category AS
SELECT
	x509_key_usage_category AS x509_key_usg_cat,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_x509_key_usage_category;



CREATE OR REPLACE VIEW jazzhands_legacy.val_x509_revocation_reason AS
SELECT x509_revocation_reason,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_x509_revocation_reason;



CREATE OR REPLACE VIEW jazzhands_legacy.volume_group AS
SELECT volume_group_id,device_id,component_id,volume_group_name,volume_group_type,volume_group_size_in_bytes,raid_type,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.volume_group;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.volume_group_physicalish_vol AS
SELECT
	physicalish_volume_id,
	volume_group_id,
	device_id,
	volume_group_primary_position AS volume_group_primary_pos,
	volume_group_secondary_position AS volume_group_secondary_pos,
	volume_group_relation,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.volume_group_physicalish_volume;



CREATE OR REPLACE VIEW jazzhands_legacy.volume_group_purpose AS
SELECT volume_group_id,volume_group_purpose,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.volume_group_purpose;


-- deprecated in earlier version of jazzhands.
CREATE OR REPLACE VIEW jazzhands_legacy.x509_certificate AS
	SELECT crt.x509_signed_certificate_id AS x509_cert_id,
	crt.friendly_name,
	CASE WHEN crt.is_active IS NULL THEN NULL
		WHEN crt.is_active = true THEN 'Y'
		WHEN crt.is_active = false THEN 'N'
		ELSE NULL
	END AS is_active,
	CASE WHEN crt.is_certificate_authority IS NULL THEN NULL
		WHEN crt.is_certificate_authority = true THEN 'Y'
		WHEN crt.is_certificate_authority = false THEN 'N'
		ELSE NULL
	END AS is_certificate_authority,
	crt.signing_cert_id,
	crt.x509_ca_cert_serial_number,
	crt.public_key,
	key.private_key,
	csr.certificate_signing_request AS certificate_sign_req,
	crt.subject,
	crt.subject_key_identifier,
	crt.public_key_hash_id,
	crt.description,
	crt.valid_from::timestamp,
	crt.valid_to::timestamp,
	crt.x509_revocation_date,
	crt.x509_revocation_reason,
	key.passphrase,
	key.encryption_key_id,
	crt.ocsp_uri,
	crt.crl_uri,
	crt.data_ins_user,
	crt.data_ins_date,
	crt.data_upd_user,
	crt.data_upd_date
FROM jazzhands.x509_signed_certificate crt
	LEFT JOIN jazzhands.private_key key USING (private_key_id)
	LEFT JOIN jazzhands.certificate_signing_request csr
		USING (certificate_signing_request_id);

ALTER TABLE jazzhands_legacy.x509_certificate ALTER is_active SET DEFAULT 'Y'::bpchar;
ALTER TABLE jazzhands_legacy.x509_certificate ALTER is_certificate_authority SET DEFAULT 'N'::bpchar;

-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.x509_key_usage_attribute AS
SELECT
	x509_signed_certificate_id AS x509_cert_id,
	x509_key_usage AS x509_key_usg,
	x509_key_usgage_category AS x509_key_usg_cat,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.x509_key_usage_attribute;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.x509_key_usage_categorization AS
SELECT
	x509_key_usage_category AS x509_key_usg_cat,
	x509_key_usage AS x509_key_usg,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.x509_key_usage_categorization;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.x509_key_usage_default AS
SELECT
	x509_signed_certificate_id,
	x509_key_usage AS x509_key_usg,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.x509_key_usage_default;



CREATE OR REPLACE VIEW jazzhands_legacy.public_key_hash AS
SELECT public_key_hash_id, description,	data_ins_user, data_ins_date, data_upd_user, data_upd_date
FROM jazzhands.public_key_hash;



CREATE OR REPLACE VIEW jazzhands_legacy.val_x509_fingerprint_hash_algorithm AS
SELECT x509_fingerprint_hash_algorighm, description, data_ins_user, data_ins_date, data_upd_user, data_upd_date
FROM jazzhands.val_x509_fingerprint_hash_algorithm;



CREATE OR REPLACE VIEW jazzhands_legacy.x509_signed_certificate_fingerprint AS
SELECT x509_signed_certificate_id, x509_fingerprint_hash_algorighm, fingerprint, description, data_ins_user, data_ins_date, data_upd_user, data_upd_date
FROM jazzhands.x509_signed_certificate_fingerprint;



CREATE OR REPLACE VIEW jazzhands_legacy.public_key_hash_hash AS
SELECT public_key_hash_id, x509_fingerprint_hash_algorighm, calculated_hash, data_ins_user, data_ins_date, data_upd_user, data_upd_date
FROM jazzhands.public_key_hash_hash;



-- Simple column rename
CREATE OR REPLACE VIEW jazzhands_legacy.x509_signed_certificate AS
SELECT
	x509_signed_certificate_id,
	x509_certificate_type,
	subject,
	friendly_name,
	subject_key_identifier,
	public_key_hash_id,
	description,
	CASE WHEN is_active IS NULL THEN NULL
		WHEN is_active = true THEN 'Y'
		WHEN is_active = false THEN 'N'
		ELSE NULL
	END AS is_active,
	CASE WHEN is_certificate_authority IS NULL THEN NULL
		WHEN is_certificate_authority = true THEN 'Y'
		WHEN is_certificate_authority = false THEN 'N'
		ELSE NULL
	END AS is_certificate_authority,
	signing_cert_id,
	x509_ca_cert_serial_number,
	public_key,
	private_key_id,
	certificate_signing_request_id,
	valid_from,
	valid_to,
	x509_revocation_date,
	x509_revocation_reason,
	ocsp_uri,
	crl_uri,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.x509_signed_certificate;

ALTER TABLE jazzhands_legacy.x509_signed_certificate ALTER x509_certificate_type SET DEFAULT 'default'::character varying;
ALTER TABLE jazzhands_legacy.x509_signed_certificate ALTER is_active SET DEFAULT 'Y'::bpchar;
ALTER TABLE jazzhands_legacy.x509_signed_certificate ALTER is_certificate_authority SET DEFAULT 'N'::bpchar;



-- Deal with dropped tables
CREATE OR REPLACE VIEW jazzhands_legacy.v_device_collection_hier_trans AS
 SELECT device_collection_id AS parent_device_collection_id,
    child_device_collection_id AS device_collection_id,
    data_ins_user,
    data_ins_date,
    data_upd_user,
    data_upd_date
   FROM jazzhands.device_collection_hier;

CREATE OR REPLACE VIEW jazzhands_legacy.v_network_interface_trans AS
WITH x as (
		SELECT base.layer3_interface_id AS network_interface_id,
			base.device_id,
			base.layer3_interface_name AS network_interface_name,
			base.description,
			base.parent_layer3_interface_id AS parent_network_interface_id,
			base.parent_relation_type,
			base.netblock_id,
			base.slot_id,
			base.logical_port_id,
			base.layer3_interface_type AS network_interface_type,
			base.is_interface_up,
			base.mac_addr,
			base.should_monitor,
			base.should_manage,
			base.data_ins_user,
			base.data_ins_date,
			base.data_upd_user,
			base.data_upd_date,
			rnk
		FROM ( SELECT  l3i.layer3_interface_id,
			l3i.layer3_interface_name,
			l3i.device_id,
			l3i.description,
			l3i.parent_layer3_interface_id,
			l3i.parent_relation_type,
			l3in.netblock_id,
			l3i.slot_id,
			l3i.logical_port_id,
			l3i.layer3_interface_type,
			l3i.is_interface_up,
			l3i.mac_addr,
			l3i.should_monitor,
			l3i.should_manage,
			l3i.data_ins_user,
			l3i.data_ins_date,
			l3i.data_upd_user,
			l3i.data_upd_date,
			rank() OVER (PARTITION BY l3i.layer3_interface_id
				ORDER BY l3in.layer3_interface_rank) AS rnk
		FROM jazzhands.layer3_interface l3i
			LEFT JOIN jazzhands.layer3_interface_netblock l3in
				USING (layer3_interface_id)
	) base
) SELECT x.network_interface_id,
	x.device_id,
	x.network_interface_name,
	x.description,
	x.parent_network_interface_id,
	x.parent_relation_type,
	x.netblock_id,
	x.slot_id AS physical_port_id,
	x.slot_id,
	x.logical_port_id,
	x.network_interface_type,
	CASE WHEN x.is_interface_up = true THEN 'Y'
		WHEN x.is_interface_up = false THEN 'N'
		ELSE NULL END as is_interface_up,
	x.mac_addr,
	CASE WHEN x.should_monitor = true THEN 'Y'
		WHEN x.should_monitor = false THEN 'N'
		ELSE NULL END as should_monitor,
	CASE WHEN x.should_manage = true THEN 'Y'
		WHEN x.should_manage = false THEN 'N'
		ELSE NULL END as should_manage,
	x.data_ins_user,
	x.data_ins_date,
	x.data_upd_user,
	x.data_upd_date
FROM  x
		WHERE rnk = 1
;


---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION v_network_interface_trans_ins()
RETURNS TRIGGER AS $$
DECLARE
	_ni	network_interface%ROWTYPE;
BEGIN
	INSERT INTO network_interface (
		device_id,
		network_interface_name, description,
		parent_network_interface_id,
		parent_relation_type, physical_port_id,
		slot_id, logical_port_id,
		network_interface_type, is_interface_up,
		mac_addr, should_monitor,
		should_manage
	) VALUES (
		NEW.device_id,
		NEW.network_interface_name, NEW.description,
		NEW.parent_network_interface_id,
		NEW.parent_relation_type, NEW.physical_port_id,
		NEW.slot_id, NEW.logical_port_id,
		NEW.network_interface_type, NEW.is_interface_up,
		NEW.mac_addr, NEW.should_monitor,
		NEW.should_manage
	) RETURNING * INTO _ni;

	IF NEW.netblock_id IS NOT NULL THEN
		INSERT INTO network_interface_netblock (
			network_interface_id, netblock_id
		) VALUES (
			_ni.network_interface_id, NEW.netblock_id
		);
	END IF;

	NEW.network_interface_id := _ni.network_interface_id;
	NEW.device_id := _ni.device_id;
	NEW.network_interface_name := _ni.network_interface_name;
	NEW.description := _ni.description;
	NEW.parent_network_interface_id := _ni.parent_network_interface_id;
	NEW.parent_relation_type := _ni.parent_relation_type;
	NEW.physical_port_id := _ni.physical_port_id;
	NEW.slot_id := _ni.slot_id;
	NEW.logical_port_id := _ni.logical_port_id;
	NEW.network_interface_type := _ni.network_interface_type;
	NEW.is_interface_up := _ni.is_interface_up;
	NEW.mac_addr := _ni.mac_addr;
	NEW.should_monitor := _ni.should_monitor;
	NEW.should_manage := _ni.should_manage;
	NEW.data_ins_user :=_ni.data_ins_user;
	NEW.data_ins_date := _ni.data_ins_date;
	NEW.data_upd_user := _ni.data_upd_user;
	NEW.data_upd_date := _ni.data_upd_date;


	RETURN NEW;
END;
$$
SET search_path=jazzhands_legacy
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_v_network_interface_trans_ins ON
	jazzhands_legacy.v_network_interface_trans;

CREATE TRIGGER trigger_v_network_interface_trans_ins
	INSTEAD OF INSERT ON jazzhands_legacy.v_network_interface_trans
	FOR EACH ROW
	EXECUTE PROCEDURE v_network_interface_trans_ins();

---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION v_network_interface_trans_del()
RETURNS TRIGGER AS $$
DECLARE
	_ni		network_interface%ROWTYPE;
BEGIN
	IF OLD.netblock_id IS NOT NULL THEN
		DELETE FROM network_interface_netblock
		WHERE network_interface_id = OLD.network_interface_id
		AND netblock_id = OLD.netblock_id;
	END IF;

	DELETE FROM network_interface
	WHERE network_interface_id = OLD.network_interface_id;

	RETURN OLD;
END;
$$
SET search_path=jazzhands_legacy
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_v_network_interface_trans_del ON
	jazzhands_legacy.v_network_interface_trans;

CREATE TRIGGER trigger_v_network_interface_trans_del
	INSTEAD OF DELETE ON jazzhands_legacy.v_network_interface_trans
	FOR EACH ROW
	EXECUTE PROCEDURE v_network_interface_trans_del();

---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION v_network_interface_trans_upd()
RETURNS TRIGGER AS $$
DECLARE
	upd_query		TEXT[];
	_ni				network_interface%ROWTYPE;
BEGIN
	IF OLD.network_interface_id IS DISTINCT FROM NEW.network_interface_id THEN
		RAISE EXCEPTION 'May not update network_interface_id'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF OLD.netblock_id IS DISTINCT FROM NEW.netblock_id THEN
		IF OLD.netblock_id IS NULL THEN
			INSERT INTO network_interface_netblock (
				network_interface_id, netblock_id
			) VALUES (
				NEW.network_interface_id, NEW.netblock_id
			);
		ELSIF NEW.netblock_id IS NULL THEN
			DELETE FROM network_interface_netblock
			WHERE network_interface_id = OLD.network_interface_id
			AND netblock_id = OLD.netblock_id;

			WITH x AS (
				SELECT *,
				rank() OVER (PARTITION BY
					network_interface_id ORDER BY
					network_interface_rank) AS rnk
				FROM network_interface_netblock
				WHERE network_interface_id = NEW.network_interface_id
			) SELECT netblock_id
			INTO NEW.netblock_id
				FROM x
				WHERE x.rnk = 1;
		ELSE
			UPDATE network_interface_netblock
			SET netblock_id = NEW.netblock_id
			WHERE netblock_id = OLD.netblock_id
			AND network_interface_id = NEW.network_interface_id;
		END IF;
	END IF;

	upd_query := NULL;
		IF NEW.device_id IS DISTINCT FROM OLD.device_id THEN
			upd_query := array_append(upd_query,
				'device_id = ' || quote_nullable(NEW.device_id));
		END IF;
		IF NEW.network_interface_name IS DISTINCT FROM OLD.network_interface_name THEN
			upd_query := array_append(upd_query,
				'network_interface_name = ' || quote_nullable(NEW.network_interface_name));
		END IF;
		IF NEW.description IS DISTINCT FROM OLD.description THEN
			upd_query := array_append(upd_query,
				'description = ' || quote_nullable(NEW.description));
		END IF;
		IF NEW.parent_network_interface_id IS DISTINCT FROM OLD.parent_network_interface_id THEN
			upd_query := array_append(upd_query,
				'parent_network_interface_id = ' || quote_nullable(NEW.parent_network_interface_id));
		END IF;
		IF NEW.parent_relation_type IS DISTINCT FROM OLD.parent_relation_type THEN
			upd_query := array_append(upd_query,
				'parent_relation_type = ' || quote_nullable(NEW.parent_relation_type));
		END IF;
		IF NEW.physical_port_id IS DISTINCT FROM OLD.physical_port_id THEN
			upd_query := array_append(upd_query,
				'physical_port_id = ' || quote_nullable(NEW.physical_port_id));
		END IF;
		IF NEW.slot_id IS DISTINCT FROM OLD.slot_id THEN
			upd_query := array_append(upd_query,
				'slot_id = ' || quote_nullable(NEW.slot_id));
		END IF;
		IF NEW.logical_port_id IS DISTINCT FROM OLD.logical_port_id THEN
			upd_query := array_append(upd_query,
				'logical_port_id = ' || quote_nullable(NEW.logical_port_id));
		END IF;
		IF NEW.network_interface_type IS DISTINCT FROM OLD.network_interface_type THEN
			upd_query := array_append(upd_query,
				'network_interface_type = ' || quote_nullable(NEW.network_interface_type));
		END IF;
		IF NEW.is_interface_up IS DISTINCT FROM OLD.is_interface_up THEN
			upd_query := array_append(upd_query,
				'is_interface_up = ' || quote_nullable(NEW.is_interface_Up));
		END IF;
		IF NEW.mac_addr IS DISTINCT FROM OLD.mac_addr THEN
			upd_query := array_append(upd_query,
				'mac_addr = ' || quote_nullable(NEW.mac_addr));
		END IF;
		IF NEW.should_monitor IS DISTINCT FROM OLD.should_monitor THEN
			upd_query := array_append(upd_query,
				'should_monitor = ' || quote_nullable(NEW.should_monitor));
		END IF;
		IF NEW.should_manage IS DISTINCT FROM OLD.should_manage THEN
			upd_query := array_append(upd_query,
				'should_manage = ' || quote_nullable(NEW.should_manage));
		END IF;

		IF upd_query IS NOT NULL THEN
			EXECUTE 'UPDATE network_interface SET ' ||
				array_to_string(upd_query, ', ') ||
				' WHERE network_interface_id = $1 RETURNING *'
			USING OLD.network_interface_id
			INTO _ni;

			NEW.device_id := _ni.device_id;
			NEW.network_interface_name := _ni.network_interface_name;
			NEW.description := _ni.description;
			NEW.parent_network_interface_id := _ni.parent_network_interface_id;
			NEW.parent_relation_type := _ni.parent_relation_type;
			NEW.physical_port_id := _ni.physical_port_id;
			NEW.slot_id := _ni.slot_id;
			NEW.logical_port_id := _ni.logical_port_id;
			NEW.network_interface_type := _ni.network_interface_type;
			NEW.is_interface_up := _ni.is_interface_up;
			NEW.mac_addr := _ni.mac_addr;
			NEW.should_monitor := _ni.should_monitor;
			NEW.should_manage := _ni.should_manage;
			NEW.data_ins_user := _ni.data_ins_user;
			NEW.data_ins_date := _ni.data_ins_date;
			NEW.data_upd_user := _ni.data_upd_user;
			NEW.data_upd_date := _ni.data_upd_date;
		END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands_legacy
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_v_network_interface_trans_upd ON
	jazzhands_legacy.v_network_interface_trans;

CREATE TRIGGER trigger_v_network_interface_trans_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.v_network_interface_trans
	FOR EACH ROW
	EXECUTE PROCEDURE v_network_interface_trans_upd();

---------------------------------------------------------------------------

--
-- going away, so a bit of a hack
CREATE OR REPLACE VIEW jazzhands_legacy.val_device_auto_mgmt_protocol AS
SELECT
	valid_property_value AS auto_mgmt_protocol,
	CASE WHEN valid_property_value = 'ssh' THEN 22
		WHEN valid_property_value = 'telnet'THEN 23
		ELSE 0 END  AS connection_port,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.val_property_value
WHERE property_name = 'AutoMgmtProtocol'
AND property_type = 'JazzHandsLegacySupport';

--- val_snmp_commstr_type going away
CREATE OR REPLACE VIEW jazzhands_legacy.val_snmp_commstr_type AS
SELECT
	device_collection_name AS snmp_commstr_type,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM jazzhands.device_collection
WHERE device_collection_type = 'SnmpCommStrClass';

--- snmp_commstr is going away
CREATE OR REPLACE VIEW jazzhands_legacy.snmp_commstr AS
SELECT
	property_id AS snmp_commstr_id,
	device_id,
	device_collection_name AS snmp_commstr_type,
	property_value_json->>'rd_string' as rd_string,
	property_value_json->>'wr_string' AS wr_string,
	property_value_json->>'purpose' AS purpose,
	p.data_ins_user,
	p.data_ins_date,
	p.data_upd_user,
	p.data_upd_date
FROM jazzhands.property p
	JOIN jazzhands.device_collection USING (device_collection_id)
	JOIN jazzhands.device_collection_device USING (device_collection_id)
WHERE device_collection_type = 'SnmpCommStrClass'
AND property_name = 'SnmpCommStr'
AND property_type = 'JazzHandsLegacySupport'
;


-- Triggers for account

CREATE OR REPLACE FUNCTION jazzhands_legacy.account_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.account%rowtype;
BEGIN

	IF NEW.account_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('account_id'));
		_vq := array_append(_vq, quote_nullable(NEW.account_id));
	END IF;

	IF NEW.login IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('login'));
		_vq := array_append(_vq, quote_nullable(NEW.login));
	END IF;

	IF NEW.person_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('person_id'));
		_vq := array_append(_vq, quote_nullable(NEW.person_id));
	END IF;

	IF NEW.company_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('company_id'));
		_vq := array_append(_vq, quote_nullable(NEW.company_id));
	END IF;

	IF NEW.is_enabled IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_enabled'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_enabled = 'Y' THEN true WHEN NEW.is_enabled = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.account_realm_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('account_realm_id'));
		_vq := array_append(_vq, quote_nullable(NEW.account_realm_id));
	END IF;

	IF NEW.account_status IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('account_status'));
		_vq := array_append(_vq, quote_nullable(NEW.account_status));
	END IF;

	IF NEW.account_role IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('account_role'));
		_vq := array_append(_vq, quote_nullable(NEW.account_role));
	END IF;

	IF NEW.account_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('account_type'));
		_vq := array_append(_vq, quote_nullable(NEW.account_type));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.external_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('external_id'));
		_vq := array_append(_vq, quote_nullable(NEW.external_id));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.account (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.account_id = _nr.account_id;
	NEW.login = _nr.login;
	NEW.person_id = _nr.person_id;
	NEW.company_id = _nr.company_id;
	NEW.is_enabled = CASE WHEN _nr.is_enabled = true THEN 'Y' WHEN _nr.is_enabled = false THEN 'N' ELSE NULL END;
	NEW.account_realm_id = _nr.account_realm_id;
	NEW.account_status = _nr.account_status;
	NEW.account_role = _nr.account_role;
	NEW.account_type = _nr.account_type;
	NEW.description = _nr.description;
	NEW.external_id = _nr.external_id;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_account_ins
	ON jazzhands_legacy.account;
CREATE TRIGGER trigger_account_ins
	INSTEAD OF INSERT ON jazzhands_legacy.account
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.account_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.account_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.account%rowtype;
	_nr	jazzhands.account%rowtype;
	_uq	text[];
BEGIN

	IF OLD.account_id IS DISTINCT FROM NEW.account_id THEN
_uq := array_append(_uq, 'account_id = ' || quote_nullable(NEW.account_id));
	END IF;

	IF OLD.login IS DISTINCT FROM NEW.login THEN
_uq := array_append(_uq, 'login = ' || quote_nullable(NEW.login));
	END IF;

	IF OLD.person_id IS DISTINCT FROM NEW.person_id THEN
_uq := array_append(_uq, 'person_id = ' || quote_nullable(NEW.person_id));
	END IF;

	IF OLD.company_id IS DISTINCT FROM NEW.company_id THEN
_uq := array_append(_uq, 'company_id = ' || quote_nullable(NEW.company_id));
	END IF;

	IF OLD.is_enabled IS DISTINCT FROM NEW.is_enabled THEN
IF NEW.is_enabled = 'Y' THEN
	_uq := array_append(_uq, 'is_enabled = true');
ELSIF NEW.is_enabled = 'N' THEN
	_uq := array_append(_uq, 'is_enabled = false');
ELSE
	_uq := array_append(_uq, 'is_enabled = NULL');
END IF;
	END IF;

	IF OLD.account_realm_id IS DISTINCT FROM NEW.account_realm_id THEN
_uq := array_append(_uq, 'account_realm_id = ' || quote_nullable(NEW.account_realm_id));
	END IF;

	IF OLD.account_status IS DISTINCT FROM NEW.account_status THEN
_uq := array_append(_uq, 'account_status = ' || quote_nullable(NEW.account_status));
	END IF;

	IF OLD.account_role IS DISTINCT FROM NEW.account_role THEN
_uq := array_append(_uq, 'account_role = ' || quote_nullable(NEW.account_role));
	END IF;

	IF OLD.account_type IS DISTINCT FROM NEW.account_type THEN
_uq := array_append(_uq, 'account_type = ' || quote_nullable(NEW.account_type));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.external_id IS DISTINCT FROM NEW.external_id THEN
_uq := array_append(_uq, 'external_id = ' || quote_nullable(NEW.external_id));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.account SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  account_id = $1 RETURNING *'  USING OLD.account_id
			INTO _nr;

		NEW.account_id = _nr.account_id;
		NEW.login = _nr.login;
		NEW.person_id = _nr.person_id;
		NEW.company_id = _nr.company_id;
		NEW.is_enabled = CASE WHEN _nr.is_enabled = true THEN 'Y' WHEN _nr.is_enabled = false THEN 'N' ELSE NULL END;
		NEW.account_realm_id = _nr.account_realm_id;
		NEW.account_status = _nr.account_status;
		NEW.account_role = _nr.account_role;
		NEW.account_type = _nr.account_type;
		NEW.description = _nr.description;
		NEW.external_id = _nr.external_id;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_account_upd
	ON jazzhands_legacy.account;
CREATE TRIGGER trigger_account_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.account
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.account_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.account_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.account%rowtype;
BEGIN
	DELETE FROM jazzhands.account
	WHERE  account_id = OLD.account_id  RETURNING *
	INTO _or;
	OLD.account_id = _or.account_id;
	OLD.login = _or.login;
	OLD.person_id = _or.person_id;
	OLD.company_id = _or.company_id;
	OLD.is_enabled = CASE WHEN _or.is_enabled = true THEN 'Y' WHEN _or.is_enabled = false THEN 'N' ELSE NULL END;
	OLD.account_realm_id = _or.account_realm_id;
	OLD.account_status = _or.account_status;
	OLD.account_role = _or.account_role;
	OLD.account_type = _or.account_type;
	OLD.description = _or.description;
	OLD.external_id = _or.external_id;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_account_del
	ON jazzhands_legacy.account;
CREATE TRIGGER trigger_account_del
	INSTEAD OF DELETE ON jazzhands_legacy.account
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.account_del();


-- Triggers for account_auth_log

CREATE OR REPLACE FUNCTION jazzhands_legacy.account_auth_log_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.account_authentication_log%rowtype;
BEGIN

	IF NEW.account_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('account_id'));
		_vq := array_append(_vq, quote_nullable(NEW.account_id));
	END IF;

	IF NEW.account_auth_ts IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('account_authentication_timestamp'));
		_vq := array_append(_vq, quote_nullable(NEW.account_auth_ts));
	END IF;

	IF NEW.auth_resource IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('authentication_resource'));
		_vq := array_append(_vq, quote_nullable(NEW.auth_resource));
	END IF;

	IF NEW.account_auth_seq IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('account_authentication_seq'));
		_vq := array_append(_vq, quote_nullable(NEW.account_auth_seq));
	END IF;

	IF NEW.was_auth_success IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('was_authentication_successful'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.was_auth_success = 'Y' THEN true WHEN NEW.was_auth_success = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.auth_resource_instance IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('authentication_resource_instance'));
		_vq := array_append(_vq, quote_nullable(NEW.auth_resource_instance));
	END IF;

	IF NEW.auth_origin IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('authentication_origin'));
		_vq := array_append(_vq, quote_nullable(NEW.auth_origin));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.account_authentication_log (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.account_id = _nr.account_id;
	NEW.account_auth_ts = _nr.account_authentication_timestamp;
	NEW.auth_resource = _nr.authentication_resource;
	NEW.account_auth_seq = _nr.account_authentication_seq;
	NEW.was_auth_success = CASE WHEN _nr.was_authentication_successful = true THEN 'Y' WHEN _nr.was_authentication_successful = false THEN 'N' ELSE NULL END;
	NEW.auth_resource_instance = _nr.authentication_resource_instance;
	NEW.auth_origin = _nr.authication_origin;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_ins_user = _nr.data_ins_user;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_account_auth_log_ins
	ON jazzhands_legacy.account_auth_log;
CREATE TRIGGER trigger_account_auth_log_ins
	INSTEAD OF INSERT ON jazzhands_legacy.account_auth_log
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.account_auth_log_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.account_auth_log_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.account_auth_log%rowtype;
	_nr	jazzhands.account_authentication_log%rowtype;
	_uq	text[];
BEGIN

	IF OLD.account_id IS DISTINCT FROM NEW.account_id THEN
_uq := array_append(_uq, 'account_id = ' || quote_nullable(NEW.account_id));
	END IF;

	IF OLD.account_auth_ts IS DISTINCT FROM NEW.account_auth_ts THEN
_uq := array_append(_uq, 'account_authentication_timestamp = ' || quote_nullable(NEW.account_auth_ts));
	END IF;

	IF OLD.auth_resource IS DISTINCT FROM NEW.auth_resource THEN
_uq := array_append(_uq, 'authentication_resource = ' || quote_nullable(NEW.auth_resource));
	END IF;

	IF OLD.account_auth_seq IS DISTINCT FROM NEW.account_auth_seq THEN
_uq := array_append(_uq, 'account_authentication_seq = ' || quote_nullable(NEW.account_auth_seq));
	END IF;

	IF OLD.was_auth_success IS DISTINCT FROM NEW.was_auth_success THEN
IF NEW.was_auth_success = 'Y' THEN
	_uq := array_append(_uq, 'was_authentication_successful = true');
ELSIF NEW.was_auth_success = 'N' THEN
	_uq := array_append(_uq, 'was_authentication_successful = false');
ELSE
	_uq := array_append(_uq, 'was_authentication_successful = NULL');
END IF;
	END IF;

	IF OLD.auth_resource_instance IS DISTINCT FROM NEW.auth_resource_instance THEN
		_uq := array_append(_uq, 'authentication_resource_instance = ' || quote_nullable(NEW.auth_resource_instance));
	END IF;

	IF OLD.auth_origin IS DISTINCT FROM NEW.auth_origin THEN
_uq := array_append(_uq, 'authentication_origin = ' || quote_nullable(NEW.auth_origin));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.account_authentication_log SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  account_id = $1 AND  account_auth_ts = $2 AND  auth_resource = $3 AND  account_auth_seq = $4 RETURNING *'  USING OLD.account_id, OLD.account_auth_ts, OLD.auth_resource, OLD.account_auth_seq
			INTO _nr;

		NEW.account_id = _nr.account_id;
		NEW.account_auth_ts = _nr.account_authentication_timestamp;
		NEW.auth_resource = _nr.authentication_resource;
		NEW.account_auth_seq = _nr.account_authentication_seq;
		NEW.was_auth_success = CASE WHEN _nr.was_authentication_successful = true THEN 'Y' WHEN _nr.was_auth_success = false THEN 'N' ELSE NULL END;
		NEW.auth_resource_instance = _nr.authentication_resource_instance;
		NEW.auth_origin = _nr.authentication_origin;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_ins_user = _nr.data_ins_user;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_account_auth_log_upd
	ON jazzhands_legacy.account_auth_log;
CREATE TRIGGER trigger_account_auth_log_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.account_auth_log
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.account_auth_log_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.account_auth_log_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.account_authentication_log%rowtype;
BEGIN
	DELETE FROM jazzhands.account_authentication_log
		WHERE  account_id = OLD.account_id
		AND  account_authentication_timestamp = OLD.account_auth_ts
		AND  authentication_resource = OLD.auth_resource
		AND  account_authentication_seq = OLD.account_auth_seq
		RETURNING *
		INTO _or;
	OLD.account_id = _or.account_id;
	OLD.account_auth_ts = _or.account_authentication_timestamp;
	OLD.auth_resource = _or.authentication_resource;
	OLD.account_auth_seq = _or.account_authentication_seq;
	OLD.was_auth_success = CASE WHEN _or.was_authentication_successful = true THEN 'Y' WHEN _or.was_auth_success = false THEN 'N' ELSE NULL END;
	OLD.auth_resource_instance = _or.authentication_resource_instance;
	OLD.auth_origin = _or.authentication_origin;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_ins_user = _or.data_ins_user;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_account_auth_log_del
	ON jazzhands_legacy.account_auth_log;
CREATE TRIGGER trigger_account_auth_log_del
	INSTEAD OF DELETE ON jazzhands_legacy.account_auth_log
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.account_auth_log_del();


-- Triggers for approval_instance_item

CREATE OR REPLACE FUNCTION jazzhands_legacy.approval_instance_item_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.approval_instance_item%rowtype;
BEGIN

	IF NEW.approval_instance_item_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('approval_instance_item_id'));
		_vq := array_append(_vq, quote_nullable(NEW.approval_instance_item_id));
	END IF;

	IF NEW.approval_instance_link_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('approval_instance_link_id'));
		_vq := array_append(_vq, quote_nullable(NEW.approval_instance_link_id));
	END IF;

	IF NEW.approval_instance_step_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('approval_instance_step_id'));
		_vq := array_append(_vq, quote_nullable(NEW.approval_instance_step_id));
	END IF;

	IF NEW.next_approval_instance_item_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('next_approval_instance_item_id'));
		_vq := array_append(_vq, quote_nullable(NEW.next_approval_instance_item_id));
	END IF;

	IF NEW.approved_category IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('approved_category'));
		_vq := array_append(_vq, quote_nullable(NEW.approved_category));
	END IF;

	IF NEW.approved_label IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('approved_label'));
		_vq := array_append(_vq, quote_nullable(NEW.approved_label));
	END IF;

	IF NEW.approved_lhs IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('approved_lhs'));
		_vq := array_append(_vq, quote_nullable(NEW.approved_lhs));
	END IF;

	IF NEW.approved_rhs IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('approved_rhs'));
		_vq := array_append(_vq, quote_nullable(NEW.approved_rhs));
	END IF;

	IF NEW.is_approved IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_approved'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_approved = 'Y' THEN true WHEN NEW.is_approved = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.approved_account_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('approved_account_id'));
		_vq := array_append(_vq, quote_nullable(NEW.approved_account_id));
	END IF;

	IF NEW.approval_note IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('approval_note'));
		_vq := array_append(_vq, quote_nullable(NEW.approval_note));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.approval_instance_item (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.approval_instance_item_id = _nr.approval_instance_item_id;
	NEW.approval_instance_link_id = _nr.approval_instance_link_id;
	NEW.approval_instance_step_id = _nr.approval_instance_step_id;
	NEW.next_approval_instance_item_id = _nr.next_approval_instance_item_id;
	NEW.approved_category = _nr.approved_category;
	NEW.approved_label = _nr.approved_label;
	NEW.approved_lhs = _nr.approved_lhs;
	NEW.approved_rhs = _nr.approved_rhs;
	NEW.is_approved = CASE WHEN _nr.is_approved = true THEN 'Y' WHEN _nr.is_approved = false THEN 'N' ELSE NULL END;
	NEW.approved_account_id = _nr.approved_account_id;
	NEW.approval_note = _nr.approval_note;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_approval_instance_item_ins
	ON jazzhands_legacy.approval_instance_item;
CREATE TRIGGER trigger_approval_instance_item_ins
	INSTEAD OF INSERT ON jazzhands_legacy.approval_instance_item
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.approval_instance_item_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.approval_instance_item_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.approval_instance_item%rowtype;
	_nr	jazzhands.approval_instance_item%rowtype;
	_uq	text[];
BEGIN

	IF OLD.approval_instance_item_id IS DISTINCT FROM NEW.approval_instance_item_id THEN
_uq := array_append(_uq, 'approval_instance_item_id = ' || quote_nullable(NEW.approval_instance_item_id));
	END IF;

	IF OLD.approval_instance_link_id IS DISTINCT FROM NEW.approval_instance_link_id THEN
_uq := array_append(_uq, 'approval_instance_link_id = ' || quote_nullable(NEW.approval_instance_link_id));
	END IF;

	IF OLD.approval_instance_step_id IS DISTINCT FROM NEW.approval_instance_step_id THEN
_uq := array_append(_uq, 'approval_instance_step_id = ' || quote_nullable(NEW.approval_instance_step_id));
	END IF;

	IF OLD.next_approval_instance_item_id IS DISTINCT FROM NEW.next_approval_instance_item_id THEN
_uq := array_append(_uq, 'next_approval_instance_item_id = ' || quote_nullable(NEW.next_approval_instance_item_id));
	END IF;

	IF OLD.approved_category IS DISTINCT FROM NEW.approved_category THEN
_uq := array_append(_uq, 'approved_category = ' || quote_nullable(NEW.approved_category));
	END IF;

	IF OLD.approved_label IS DISTINCT FROM NEW.approved_label THEN
_uq := array_append(_uq, 'approved_label = ' || quote_nullable(NEW.approved_label));
	END IF;

	IF OLD.approved_lhs IS DISTINCT FROM NEW.approved_lhs THEN
_uq := array_append(_uq, 'approved_lhs = ' || quote_nullable(NEW.approved_lhs));
	END IF;

	IF OLD.approved_rhs IS DISTINCT FROM NEW.approved_rhs THEN
_uq := array_append(_uq, 'approved_rhs = ' || quote_nullable(NEW.approved_rhs));
	END IF;

	IF OLD.is_approved IS DISTINCT FROM NEW.is_approved THEN
IF NEW.is_approved = 'Y' THEN
	_uq := array_append(_uq, 'is_approved = true');
ELSIF NEW.is_approved = 'N' THEN
	_uq := array_append(_uq, 'is_approved = false');
ELSE
	_uq := array_append(_uq, 'is_approved = NULL');
END IF;
	END IF;

	IF OLD.approved_account_id IS DISTINCT FROM NEW.approved_account_id THEN
_uq := array_append(_uq, 'approved_account_id = ' || quote_nullable(NEW.approved_account_id));
	END IF;

	IF OLD.approval_note IS DISTINCT FROM NEW.approval_note THEN
_uq := array_append(_uq, 'approval_note = ' || quote_nullable(NEW.approval_note));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.approval_instance_item SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  approval_instance_item_id = $1 RETURNING *'  USING OLD.approval_instance_item_id
			INTO _nr;

		NEW.approval_instance_item_id = _nr.approval_instance_item_id;
		NEW.approval_instance_link_id = _nr.approval_instance_link_id;
		NEW.approval_instance_step_id = _nr.approval_instance_step_id;
		NEW.next_approval_instance_item_id = _nr.next_approval_instance_item_id;
		NEW.approved_category = _nr.approved_category;
		NEW.approved_label = _nr.approved_label;
		NEW.approved_lhs = _nr.approved_lhs;
		NEW.approved_rhs = _nr.approved_rhs;
		NEW.is_approved = CASE WHEN _nr.is_approved = true THEN 'Y' WHEN _nr.is_approved = false THEN 'N' ELSE NULL END;
		NEW.approved_account_id = _nr.approved_account_id;
		NEW.approval_note = _nr.approval_note;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_approval_instance_item_upd
	ON jazzhands_legacy.approval_instance_item;
CREATE TRIGGER trigger_approval_instance_item_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.approval_instance_item
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.approval_instance_item_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.approval_instance_item_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.approval_instance_item%rowtype;
BEGIN
	DELETE FROM jazzhands.approval_instance_item
	WHERE  approval_instance_item_id = OLD.approval_instance_item_id  RETURNING *
	INTO _or;
	OLD.approval_instance_item_id = _or.approval_instance_item_id;
	OLD.approval_instance_link_id = _or.approval_instance_link_id;
	OLD.approval_instance_step_id = _or.approval_instance_step_id;
	OLD.next_approval_instance_item_id = _or.next_approval_instance_item_id;
	OLD.approved_category = _or.approved_category;
	OLD.approved_label = _or.approved_label;
	OLD.approved_lhs = _or.approved_lhs;
	OLD.approved_rhs = _or.approved_rhs;
	OLD.is_approved = CASE WHEN _or.is_approved = true THEN 'Y' WHEN _or.is_approved = false THEN 'N' ELSE NULL END;
	OLD.approved_account_id = _or.approved_account_id;
	OLD.approval_note = _or.approval_note;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_approval_instance_item_del
	ON jazzhands_legacy.approval_instance_item;
CREATE TRIGGER trigger_approval_instance_item_del
	INSTEAD OF DELETE ON jazzhands_legacy.approval_instance_item
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.approval_instance_item_del();


-- Triggers for approval_instance_step

CREATE OR REPLACE FUNCTION jazzhands_legacy.approval_instance_step_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.approval_instance_step%rowtype;
BEGIN

	IF NEW.approval_instance_step_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('approval_instance_step_id'));
		_vq := array_append(_vq, quote_nullable(NEW.approval_instance_step_id));
	END IF;

	IF NEW.approval_instance_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('approval_instance_id'));
		_vq := array_append(_vq, quote_nullable(NEW.approval_instance_id));
	END IF;

	IF NEW.approval_process_chain_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('approval_process_chain_id'));
		_vq := array_append(_vq, quote_nullable(NEW.approval_process_chain_id));
	END IF;

	IF NEW.approval_instance_step_name IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('approval_instance_step_name'));
		_vq := array_append(_vq, quote_nullable(NEW.approval_instance_step_name));
	END IF;

	IF NEW.approval_instance_step_due IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('approval_instance_step_due'));
		_vq := array_append(_vq, quote_nullable(NEW.approval_instance_step_due));
	END IF;

	IF NEW.approval_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('approval_type'));
		_vq := array_append(_vq, quote_nullable(NEW.approval_type));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.approval_instance_step_start IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('approval_instance_step_start'));
		_vq := array_append(_vq, quote_nullable(NEW.approval_instance_step_start));
	END IF;

	IF NEW.approval_instance_step_end IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('approval_instance_step_end'));
		_vq := array_append(_vq, quote_nullable(NEW.approval_instance_step_end));
	END IF;

	IF NEW.approver_account_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('approver_account_id'));
		_vq := array_append(_vq, quote_nullable(NEW.approver_account_id));
	END IF;

	IF NEW.external_reference_name IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('external_reference_name'));
		_vq := array_append(_vq, quote_nullable(NEW.external_reference_name));
	END IF;

	IF NEW.is_completed IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_completed'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_completed = 'Y' THEN true WHEN NEW.is_completed = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.approval_instance_step (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.approval_instance_step_id = _nr.approval_instance_step_id;
	NEW.approval_instance_id = _nr.approval_instance_id;
	NEW.approval_process_chain_id = _nr.approval_process_chain_id;
	NEW.approval_instance_step_name = _nr.approval_instance_step_name;
	NEW.approval_instance_step_due = _nr.approval_instance_step_due;
	NEW.approval_type = _nr.approval_type;
	NEW.description = _nr.description;
	NEW.approval_instance_step_start = _nr.approval_instance_step_start;
	NEW.approval_instance_step_end = _nr.approval_instance_step_end;
	NEW.approver_account_id = _nr.approver_account_id;
	NEW.external_reference_name = _nr.external_reference_name;
	NEW.is_completed = CASE WHEN _nr.is_completed = true THEN 'Y' WHEN _nr.is_completed = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_approval_instance_step_ins
	ON jazzhands_legacy.approval_instance_step;
CREATE TRIGGER trigger_approval_instance_step_ins
	INSTEAD OF INSERT ON jazzhands_legacy.approval_instance_step
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.approval_instance_step_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.approval_instance_step_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.approval_instance_step%rowtype;
	_nr	jazzhands.approval_instance_step%rowtype;
	_uq	text[];
BEGIN

	IF OLD.approval_instance_step_id IS DISTINCT FROM NEW.approval_instance_step_id THEN
_uq := array_append(_uq, 'approval_instance_step_id = ' || quote_nullable(NEW.approval_instance_step_id));
	END IF;

	IF OLD.approval_instance_id IS DISTINCT FROM NEW.approval_instance_id THEN
_uq := array_append(_uq, 'approval_instance_id = ' || quote_nullable(NEW.approval_instance_id));
	END IF;

	IF OLD.approval_process_chain_id IS DISTINCT FROM NEW.approval_process_chain_id THEN
_uq := array_append(_uq, 'approval_process_chain_id = ' || quote_nullable(NEW.approval_process_chain_id));
	END IF;

	IF OLD.approval_instance_step_name IS DISTINCT FROM NEW.approval_instance_step_name THEN
_uq := array_append(_uq, 'approval_instance_step_name = ' || quote_nullable(NEW.approval_instance_step_name));
	END IF;

	IF OLD.approval_instance_step_due IS DISTINCT FROM NEW.approval_instance_step_due THEN
_uq := array_append(_uq, 'approval_instance_step_due = ' || quote_nullable(NEW.approval_instance_step_due));
	END IF;

	IF OLD.approval_type IS DISTINCT FROM NEW.approval_type THEN
_uq := array_append(_uq, 'approval_type = ' || quote_nullable(NEW.approval_type));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.approval_instance_step_start IS DISTINCT FROM NEW.approval_instance_step_start THEN
_uq := array_append(_uq, 'approval_instance_step_start = ' || quote_nullable(NEW.approval_instance_step_start));
	END IF;

	IF OLD.approval_instance_step_end IS DISTINCT FROM NEW.approval_instance_step_end THEN
_uq := array_append(_uq, 'approval_instance_step_end = ' || quote_nullable(NEW.approval_instance_step_end));
	END IF;

	IF OLD.approver_account_id IS DISTINCT FROM NEW.approver_account_id THEN
_uq := array_append(_uq, 'approver_account_id = ' || quote_nullable(NEW.approver_account_id));
	END IF;

	IF OLD.external_reference_name IS DISTINCT FROM NEW.external_reference_name THEN
_uq := array_append(_uq, 'external_reference_name = ' || quote_nullable(NEW.external_reference_name));
	END IF;

	IF OLD.is_completed IS DISTINCT FROM NEW.is_completed THEN
IF NEW.is_completed = 'Y' THEN
	_uq := array_append(_uq, 'is_completed = true');
ELSIF NEW.is_completed = 'N' THEN
	_uq := array_append(_uq, 'is_completed = false');
ELSE
	_uq := array_append(_uq, 'is_completed = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.approval_instance_step SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  approval_instance_step_id = $1 RETURNING *'  USING OLD.approval_instance_step_id
			INTO _nr;

		NEW.approval_instance_step_id = _nr.approval_instance_step_id;
		NEW.approval_instance_id = _nr.approval_instance_id;
		NEW.approval_process_chain_id = _nr.approval_process_chain_id;
		NEW.approval_instance_step_name = _nr.approval_instance_step_name;
		NEW.approval_instance_step_due = _nr.approval_instance_step_due;
		NEW.approval_type = _nr.approval_type;
		NEW.description = _nr.description;
		NEW.approval_instance_step_start = _nr.approval_instance_step_start;
		NEW.approval_instance_step_end = _nr.approval_instance_step_end;
		NEW.approver_account_id = _nr.approver_account_id;
		NEW.external_reference_name = _nr.external_reference_name;
		NEW.is_completed = CASE WHEN _nr.is_completed = true THEN 'Y' WHEN _nr.is_completed = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_approval_instance_step_upd
	ON jazzhands_legacy.approval_instance_step;
CREATE TRIGGER trigger_approval_instance_step_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.approval_instance_step
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.approval_instance_step_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.approval_instance_step_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.approval_instance_step%rowtype;
BEGIN
	DELETE FROM jazzhands.approval_instance_step
	WHERE  approval_instance_step_id = OLD.approval_instance_step_id  RETURNING *
	INTO _or;
	OLD.approval_instance_step_id = _or.approval_instance_step_id;
	OLD.approval_instance_id = _or.approval_instance_id;
	OLD.approval_process_chain_id = _or.approval_process_chain_id;
	OLD.approval_instance_step_name = _or.approval_instance_step_name;
	OLD.approval_instance_step_due = _or.approval_instance_step_due;
	OLD.approval_type = _or.approval_type;
	OLD.description = _or.description;
	OLD.approval_instance_step_start = _or.approval_instance_step_start;
	OLD.approval_instance_step_end = _or.approval_instance_step_end;
	OLD.approver_account_id = _or.approver_account_id;
	OLD.external_reference_name = _or.external_reference_name;
	OLD.is_completed = CASE WHEN _or.is_completed = true THEN 'Y' WHEN _or.is_completed = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_approval_instance_step_del
	ON jazzhands_legacy.approval_instance_step;
CREATE TRIGGER trigger_approval_instance_step_del
	INSTEAD OF DELETE ON jazzhands_legacy.approval_instance_step
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.approval_instance_step_del();


-- Triggers for approval_process_chain

CREATE OR REPLACE FUNCTION jazzhands_legacy.approval_process_chain_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.approval_process_chain%rowtype;
BEGIN

	IF NEW.approval_process_chain_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('approval_process_chain_id'));
		_vq := array_append(_vq, quote_nullable(NEW.approval_process_chain_id));
	END IF;

	IF NEW.approval_process_chain_name IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('approval_process_chain_name'));
		_vq := array_append(_vq, quote_nullable(NEW.approval_process_chain_name));
	END IF;

	IF NEW.approval_chain_response_period IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('approval_chain_response_period'));
		_vq := array_append(_vq, quote_nullable(NEW.approval_chain_response_period));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.message IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('message'));
		_vq := array_append(_vq, quote_nullable(NEW.message));
	END IF;

	IF NEW.email_message IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('email_message'));
		_vq := array_append(_vq, quote_nullable(NEW.email_message));
	END IF;

	IF NEW.email_subject_prefix IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('email_subject_prefix'));
		_vq := array_append(_vq, quote_nullable(NEW.email_subject_prefix));
	END IF;

	IF NEW.email_subject_suffix IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('email_subject_suffix'));
		_vq := array_append(_vq, quote_nullable(NEW.email_subject_suffix));
	END IF;

	IF NEW.max_escalation_level IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('max_escalation_level'));
		_vq := array_append(_vq, quote_nullable(NEW.max_escalation_level));
	END IF;

	IF NEW.escalation_delay IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('escalation_delay'));
		_vq := array_append(_vq, quote_nullable(NEW.escalation_delay));
	END IF;

	IF NEW.escalation_reminder_gap IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('escalation_reminder_gap'));
		_vq := array_append(_vq, quote_nullable(NEW.escalation_reminder_gap));
	END IF;

	IF NEW.approving_entity IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('approving_entity'));
		_vq := array_append(_vq, quote_nullable(NEW.approving_entity));
	END IF;

	IF NEW.refresh_all_data IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('refresh_all_data'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.refresh_all_data = 'Y' THEN true WHEN NEW.refresh_all_data = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.accept_app_process_chain_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('accept_approval_process_chain_id'));
		_vq := array_append(_vq, quote_nullable(NEW.accept_app_process_chain_id));
	END IF;

	IF NEW.reject_app_process_chain_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('reject_approval_process_chain_id'));
		_vq := array_append(_vq, quote_nullable(NEW.reject_app_process_chain_id));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.approval_process_chain (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.approval_process_chain_id = _nr.approval_process_chain_id;
	NEW.approval_process_chain_name = _nr.approval_process_chain_name;
	NEW.approval_chain_response_period = _nr.approval_chain_response_period;
	NEW.description = _nr.description;
	NEW.message = _nr.message;
	NEW.email_message = _nr.email_message;
	NEW.email_subject_prefix = _nr.email_subject_prefix;
	NEW.email_subject_suffix = _nr.email_subject_suffix;
	NEW.max_escalation_level = _nr.max_escalation_level;
	NEW.escalation_delay = _nr.escalation_delay;
	NEW.escalation_reminder_gap = _nr.escalation_reminder_gap;
	NEW.approving_entity = _nr.approving_entity;
	NEW.refresh_all_data = CASE WHEN _nr.refresh_all_data = true THEN 'Y' WHEN _nr.refresh_all_data = false THEN 'N' ELSE NULL END;
	NEW.accept_app_process_chain_id = _nr.accept_approval_process_chain_id;
	NEW.reject_app_process_chain_id = _nr.reject_approval_process_chain_id;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_approval_process_chain_ins
	ON jazzhands_legacy.approval_process_chain;
CREATE TRIGGER trigger_approval_process_chain_ins
	INSTEAD OF INSERT ON jazzhands_legacy.approval_process_chain
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.approval_process_chain_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.approval_process_chain_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.approval_process_chain%rowtype;
	_nr	jazzhands.approval_process_chain%rowtype;
	_uq	text[];
BEGIN

	IF OLD.approval_process_chain_id IS DISTINCT FROM NEW.approval_process_chain_id THEN
_uq := array_append(_uq, 'approval_process_chain_id = ' || quote_nullable(NEW.approval_process_chain_id));
	END IF;

	IF OLD.approval_process_chain_name IS DISTINCT FROM NEW.approval_process_chain_name THEN
_uq := array_append(_uq, 'approval_process_chain_name = ' || quote_nullable(NEW.approval_process_chain_name));
	END IF;

	IF OLD.approval_chain_response_period IS DISTINCT FROM NEW.approval_chain_response_period THEN
_uq := array_append(_uq, 'approval_chain_response_period = ' || quote_nullable(NEW.approval_chain_response_period));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.message IS DISTINCT FROM NEW.message THEN
_uq := array_append(_uq, 'message = ' || quote_nullable(NEW.message));
	END IF;

	IF OLD.email_message IS DISTINCT FROM NEW.email_message THEN
_uq := array_append(_uq, 'email_message = ' || quote_nullable(NEW.email_message));
	END IF;

	IF OLD.email_subject_prefix IS DISTINCT FROM NEW.email_subject_prefix THEN
_uq := array_append(_uq, 'email_subject_prefix = ' || quote_nullable(NEW.email_subject_prefix));
	END IF;

	IF OLD.email_subject_suffix IS DISTINCT FROM NEW.email_subject_suffix THEN
_uq := array_append(_uq, 'email_subject_suffix = ' || quote_nullable(NEW.email_subject_suffix));
	END IF;

	IF OLD.max_escalation_level IS DISTINCT FROM NEW.max_escalation_level THEN
_uq := array_append(_uq, 'max_escalation_level = ' || quote_nullable(NEW.max_escalation_level));
	END IF;

	IF OLD.escalation_delay IS DISTINCT FROM NEW.escalation_delay THEN
_uq := array_append(_uq, 'escalation_delay = ' || quote_nullable(NEW.escalation_delay));
	END IF;

	IF OLD.escalation_reminder_gap IS DISTINCT FROM NEW.escalation_reminder_gap THEN
_uq := array_append(_uq, 'escalation_reminder_gap = ' || quote_nullable(NEW.escalation_reminder_gap));
	END IF;

	IF OLD.approving_entity IS DISTINCT FROM NEW.approving_entity THEN
_uq := array_append(_uq, 'approving_entity = ' || quote_nullable(NEW.approving_entity));
	END IF;

	IF OLD.refresh_all_data IS DISTINCT FROM NEW.refresh_all_data THEN
IF NEW.refresh_all_data = 'Y' THEN
	_uq := array_append(_uq, 'refresh_all_data = true');
ELSIF NEW.refresh_all_data = 'N' THEN
	_uq := array_append(_uq, 'refresh_all_data = false');
ELSE
	_uq := array_append(_uq, 'refresh_all_data = NULL');
END IF;
	END IF;

	IF OLD.accept_app_process_chain_id IS DISTINCT FROM NEW.accept_app_process_chain_id THEN
_uq := array_append(_uq, 'accept_approval_process_chain_id = ' || quote_nullable(NEW.accept_app_process_chain_id));
	END IF;

	IF OLD.reject_app_process_chain_id IS DISTINCT FROM NEW.reject_app_process_chain_id THEN
_uq := array_append(_uq, 'reject_approval_process_chain_id = ' || quote_nullable(NEW.reject_app_process_chain_id));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.approval_process_chain SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  approval_process_chain_id = $1 RETURNING *'  USING OLD.approval_process_chain_id
			INTO _nr;

		NEW.approval_process_chain_id = _nr.approval_process_chain_id;
		NEW.approval_process_chain_name = _nr.approval_process_chain_name;
		NEW.approval_chain_response_period = _nr.approval_chain_response_period;
		NEW.description = _nr.description;
		NEW.message = _nr.message;
		NEW.email_message = _nr.email_message;
		NEW.email_subject_prefix = _nr.email_subject_prefix;
		NEW.email_subject_suffix = _nr.email_subject_suffix;
		NEW.max_escalation_level = _nr.max_escalation_level;
		NEW.escalation_delay = _nr.escalation_delay;
		NEW.escalation_reminder_gap = _nr.escalation_reminder_gap;
		NEW.approving_entity = _nr.approving_entity;
		NEW.refresh_all_data = CASE WHEN _nr.refresh_all_data = true THEN 'Y' WHEN _nr.refresh_all_data = false THEN 'N' ELSE NULL END;
		NEW.accept_app_process_chain_id = _nr.accept_approval_process_chain_id;
		NEW.reject_app_process_chain_id = _nr.reject_app_process_chain_id;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_approval_process_chain_upd
	ON jazzhands_legacy.approval_process_chain;
CREATE TRIGGER trigger_approval_process_chain_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.approval_process_chain
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.approval_process_chain_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.approval_process_chain_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.approval_process_chain%rowtype;
BEGIN
	DELETE FROM jazzhands.approval_process_chain
	WHERE  approval_process_chain_id = OLD.approval_process_chain_id  RETURNING *
	INTO _or;
	OLD.approval_process_chain_id = _or.approval_process_chain_id;
	OLD.approval_process_chain_name = _or.approval_process_chain_name;
	OLD.approval_chain_response_period = _or.approval_chain_response_period;
	OLD.description = _or.description;
	OLD.message = _or.message;
	OLD.email_message = _or.email_message;
	OLD.email_subject_prefix = _or.email_subject_prefix;
	OLD.email_subject_suffix = _or.email_subject_suffix;
	OLD.max_escalation_level = _or.max_escalation_level;
	OLD.escalation_delay = _or.escalation_delay;
	OLD.escalation_reminder_gap = _or.escalation_reminder_gap;
	OLD.approving_entity = _or.approving_entity;
	OLD.refresh_all_data = CASE WHEN _or.refresh_all_data = true THEN 'Y' WHEN _or.refresh_all_data = false THEN 'N' ELSE NULL END;
	OLD.accept_app_process_chain_id = _or.accept_approval_process_chain_id;
	OLD.reject_app_process_chain_id = _or.reject_approval_process_chain_id;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_approval_process_chain_del
	ON jazzhands_legacy.approval_process_chain;
CREATE TRIGGER trigger_approval_process_chain_del
	INSTEAD OF DELETE ON jazzhands_legacy.approval_process_chain
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.approval_process_chain_del();


-- Triggers for circuit

CREATE OR REPLACE FUNCTION jazzhands_legacy.circuit_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.circuit%rowtype;
BEGIN

	IF NEW.circuit_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('circuit_id'));
		_vq := array_append(_vq, quote_nullable(NEW.circuit_id));
	END IF;

	IF NEW.vendor_company_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('vendor_company_id'));
		_vq := array_append(_vq, quote_nullable(NEW.vendor_company_id));
	END IF;

	IF NEW.vendor_circuit_id_str IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('vendor_circuit_id_str'));
		_vq := array_append(_vq, quote_nullable(NEW.vendor_circuit_id_str));
	END IF;

	IF NEW.aloc_lec_company_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('aloc_lec_company_id'));
		_vq := array_append(_vq, quote_nullable(NEW.aloc_lec_company_id));
	END IF;

	IF NEW.aloc_lec_circuit_id_str IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('aloc_lec_circuit_id_str'));
		_vq := array_append(_vq, quote_nullable(NEW.aloc_lec_circuit_id_str));
	END IF;

	IF NEW.aloc_parent_circuit_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('aloc_parent_circuit_id'));
		_vq := array_append(_vq, quote_nullable(NEW.aloc_parent_circuit_id));
	END IF;

	IF NEW.zloc_lec_company_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('zloc_lec_company_id'));
		_vq := array_append(_vq, quote_nullable(NEW.zloc_lec_company_id));
	END IF;

	IF NEW.zloc_lec_circuit_id_str IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('zloc_lec_circuit_id_str'));
		_vq := array_append(_vq, quote_nullable(NEW.zloc_lec_circuit_id_str));
	END IF;

	IF NEW.zloc_parent_circuit_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('zloc_parent_circuit_id'));
		_vq := array_append(_vq, quote_nullable(NEW.zloc_parent_circuit_id));
	END IF;

	IF NEW.is_locally_managed IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_locally_managed'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_locally_managed = 'Y' THEN true WHEN NEW.is_locally_managed = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.circuit (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.circuit_id = _nr.circuit_id;
	NEW.vendor_company_id = _nr.vendor_company_id;
	NEW.vendor_circuit_id_str = _nr.vendor_circuit_id_str;
	NEW.aloc_lec_company_id = _nr.aloc_lec_company_id;
	NEW.aloc_lec_circuit_id_str = _nr.aloc_lec_circuit_id_str;
	NEW.aloc_parent_circuit_id = _nr.aloc_parent_circuit_id;
	NEW.zloc_lec_company_id = _nr.zloc_lec_company_id;
	NEW.zloc_lec_circuit_id_str = _nr.zloc_lec_circuit_id_str;
	NEW.zloc_parent_circuit_id = _nr.zloc_parent_circuit_id;
	NEW.is_locally_managed = CASE WHEN _nr.is_locally_managed = true THEN 'Y' WHEN _nr.is_locally_managed = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_circuit_ins
	ON jazzhands_legacy.circuit;
CREATE TRIGGER trigger_circuit_ins
	INSTEAD OF INSERT ON jazzhands_legacy.circuit
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.circuit_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.circuit_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.circuit%rowtype;
	_nr	jazzhands.circuit%rowtype;
	_uq	text[];
BEGIN

	IF OLD.circuit_id IS DISTINCT FROM NEW.circuit_id THEN
_uq := array_append(_uq, 'circuit_id = ' || quote_nullable(NEW.circuit_id));
	END IF;

	IF OLD.vendor_company_id IS DISTINCT FROM NEW.vendor_company_id THEN
_uq := array_append(_uq, 'vendor_company_id = ' || quote_nullable(NEW.vendor_company_id));
	END IF;

	IF OLD.vendor_circuit_id_str IS DISTINCT FROM NEW.vendor_circuit_id_str THEN
_uq := array_append(_uq, 'vendor_circuit_id_str = ' || quote_nullable(NEW.vendor_circuit_id_str));
	END IF;

	IF OLD.aloc_lec_company_id IS DISTINCT FROM NEW.aloc_lec_company_id THEN
_uq := array_append(_uq, 'aloc_lec_company_id = ' || quote_nullable(NEW.aloc_lec_company_id));
	END IF;

	IF OLD.aloc_lec_circuit_id_str IS DISTINCT FROM NEW.aloc_lec_circuit_id_str THEN
_uq := array_append(_uq, 'aloc_lec_circuit_id_str = ' || quote_nullable(NEW.aloc_lec_circuit_id_str));
	END IF;

	IF OLD.aloc_parent_circuit_id IS DISTINCT FROM NEW.aloc_parent_circuit_id THEN
_uq := array_append(_uq, 'aloc_parent_circuit_id = ' || quote_nullable(NEW.aloc_parent_circuit_id));
	END IF;

	IF OLD.zloc_lec_company_id IS DISTINCT FROM NEW.zloc_lec_company_id THEN
_uq := array_append(_uq, 'zloc_lec_company_id = ' || quote_nullable(NEW.zloc_lec_company_id));
	END IF;

	IF OLD.zloc_lec_circuit_id_str IS DISTINCT FROM NEW.zloc_lec_circuit_id_str THEN
_uq := array_append(_uq, 'zloc_lec_circuit_id_str = ' || quote_nullable(NEW.zloc_lec_circuit_id_str));
	END IF;

	IF OLD.zloc_parent_circuit_id IS DISTINCT FROM NEW.zloc_parent_circuit_id THEN
_uq := array_append(_uq, 'zloc_parent_circuit_id = ' || quote_nullable(NEW.zloc_parent_circuit_id));
	END IF;

	IF OLD.is_locally_managed IS DISTINCT FROM NEW.is_locally_managed THEN
IF NEW.is_locally_managed = 'Y' THEN
	_uq := array_append(_uq, 'is_locally_managed = true');
ELSIF NEW.is_locally_managed = 'N' THEN
	_uq := array_append(_uq, 'is_locally_managed = false');
ELSE
	_uq := array_append(_uq, 'is_locally_managed = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.circuit SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  circuit_id = $1 RETURNING *'  USING OLD.circuit_id
			INTO _nr;

		NEW.circuit_id = _nr.circuit_id;
		NEW.vendor_company_id = _nr.vendor_company_id;
		NEW.vendor_circuit_id_str = _nr.vendor_circuit_id_str;
		NEW.aloc_lec_company_id = _nr.aloc_lec_company_id;
		NEW.aloc_lec_circuit_id_str = _nr.aloc_lec_circuit_id_str;
		NEW.aloc_parent_circuit_id = _nr.aloc_parent_circuit_id;
		NEW.zloc_lec_company_id = _nr.zloc_lec_company_id;
		NEW.zloc_lec_circuit_id_str = _nr.zloc_lec_circuit_id_str;
		NEW.zloc_parent_circuit_id = _nr.zloc_parent_circuit_id;
		NEW.is_locally_managed = CASE WHEN _nr.is_locally_managed = true THEN 'Y' WHEN _nr.is_locally_managed = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_circuit_upd
	ON jazzhands_legacy.circuit;
CREATE TRIGGER trigger_circuit_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.circuit
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.circuit_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.circuit_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.circuit%rowtype;
BEGIN
	DELETE FROM jazzhands.circuit
	WHERE  circuit_id = OLD.circuit_id  RETURNING *
	INTO _or;
	OLD.circuit_id = _or.circuit_id;
	OLD.vendor_company_id = _or.vendor_company_id;
	OLD.vendor_circuit_id_str = _or.vendor_circuit_id_str;
	OLD.aloc_lec_company_id = _or.aloc_lec_company_id;
	OLD.aloc_lec_circuit_id_str = _or.aloc_lec_circuit_id_str;
	OLD.aloc_parent_circuit_id = _or.aloc_parent_circuit_id;
	OLD.zloc_lec_company_id = _or.zloc_lec_company_id;
	OLD.zloc_lec_circuit_id_str = _or.zloc_lec_circuit_id_str;
	OLD.zloc_parent_circuit_id = _or.zloc_parent_circuit_id;
	OLD.is_locally_managed = CASE WHEN _or.is_locally_managed = true THEN 'Y' WHEN _or.is_locally_managed = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_circuit_del
	ON jazzhands_legacy.circuit;
CREATE TRIGGER trigger_circuit_del
	INSTEAD OF DELETE ON jazzhands_legacy.circuit
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.circuit_del();


-- Triggers for component_type

CREATE OR REPLACE FUNCTION jazzhands_legacy.component_type_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.component_type%rowtype;
BEGIN

	IF NEW.component_type_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('component_type_id'));
		_vq := array_append(_vq, quote_nullable(NEW.component_type_id));
	END IF;

	IF NEW.company_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('company_id'));
		_vq := array_append(_vq, quote_nullable(NEW.company_id));
	END IF;

	IF NEW.model IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('model'));
		_vq := array_append(_vq, quote_nullable(NEW.model));
	END IF;

	IF NEW.slot_type_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('slot_type_id'));
		_vq := array_append(_vq, quote_nullable(NEW.slot_type_id));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.part_number IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('part_number'));
		_vq := array_append(_vq, quote_nullable(NEW.part_number));
	END IF;

	IF NEW.is_removable IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_removable'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_removable = 'Y' THEN true WHEN NEW.is_removable = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.asset_permitted IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('asset_permitted'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.asset_permitted = 'Y' THEN true WHEN NEW.asset_permitted = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.is_rack_mountable IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_rack_mountable'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_rack_mountable = 'Y' THEN true WHEN NEW.is_rack_mountable = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.is_virtual_component IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_virtual_component'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_virtual_component = 'Y' THEN true WHEN NEW.is_virtual_component = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.size_units IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('size_units'));
		_vq := array_append(_vq, quote_nullable(NEW.size_units));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.component_type (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.component_type_id = _nr.component_type_id;
	NEW.company_id = _nr.company_id;
	NEW.model = _nr.model;
	NEW.slot_type_id = _nr.slot_type_id;
	NEW.description = _nr.description;
	NEW.part_number = _nr.part_number;
	NEW.is_removable = CASE WHEN _nr.is_removable = true THEN 'Y' WHEN _nr.is_removable = false THEN 'N' ELSE NULL END;
	NEW.asset_permitted = CASE WHEN _nr.asset_permitted = true THEN 'Y' WHEN _nr.asset_permitted = false THEN 'N' ELSE NULL END;
	NEW.is_rack_mountable = CASE WHEN _nr.is_rack_mountable = true THEN 'Y' WHEN _nr.is_rack_mountable = false THEN 'N' ELSE NULL END;
	NEW.is_virtual_component = CASE WHEN _nr.is_virtual_component = true THEN 'Y' WHEN _nr.is_virtual_component = false THEN 'N' ELSE NULL END;
	NEW.size_units = _nr.size_units;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_component_type_ins
	ON jazzhands_legacy.component_type;
CREATE TRIGGER trigger_component_type_ins
	INSTEAD OF INSERT ON jazzhands_legacy.component_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.component_type_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.component_type_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.component_type%rowtype;
	_nr	jazzhands.component_type%rowtype;
	_uq	text[];
BEGIN

	IF OLD.component_type_id IS DISTINCT FROM NEW.component_type_id THEN
_uq := array_append(_uq, 'component_type_id = ' || quote_nullable(NEW.component_type_id));
	END IF;

	IF OLD.company_id IS DISTINCT FROM NEW.company_id THEN
_uq := array_append(_uq, 'company_id = ' || quote_nullable(NEW.company_id));
	END IF;

	IF OLD.model IS DISTINCT FROM NEW.model THEN
_uq := array_append(_uq, 'model = ' || quote_nullable(NEW.model));
	END IF;

	IF OLD.slot_type_id IS DISTINCT FROM NEW.slot_type_id THEN
_uq := array_append(_uq, 'slot_type_id = ' || quote_nullable(NEW.slot_type_id));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.part_number IS DISTINCT FROM NEW.part_number THEN
_uq := array_append(_uq, 'part_number = ' || quote_nullable(NEW.part_number));
	END IF;

	IF OLD.is_removable IS DISTINCT FROM NEW.is_removable THEN
IF NEW.is_removable = 'Y' THEN
	_uq := array_append(_uq, 'is_removable = true');
ELSIF NEW.is_removable = 'N' THEN
	_uq := array_append(_uq, 'is_removable = false');
ELSE
	_uq := array_append(_uq, 'is_removable = NULL');
END IF;
	END IF;

	IF OLD.asset_permitted IS DISTINCT FROM NEW.asset_permitted THEN
IF NEW.asset_permitted = 'Y' THEN
	_uq := array_append(_uq, 'asset_permitted = true');
ELSIF NEW.asset_permitted = 'N' THEN
	_uq := array_append(_uq, 'asset_permitted = false');
ELSE
	_uq := array_append(_uq, 'asset_permitted = NULL');
END IF;
	END IF;

	IF OLD.is_rack_mountable IS DISTINCT FROM NEW.is_rack_mountable THEN
IF NEW.is_rack_mountable = 'Y' THEN
	_uq := array_append(_uq, 'is_rack_mountable = true');
ELSIF NEW.is_rack_mountable = 'N' THEN
	_uq := array_append(_uq, 'is_rack_mountable = false');
ELSE
	_uq := array_append(_uq, 'is_rack_mountable = NULL');
END IF;
	END IF;

	IF OLD.is_virtual_component IS DISTINCT FROM NEW.is_virtual_component THEN
IF NEW.is_virtual_component = 'Y' THEN
	_uq := array_append(_uq, 'is_virtual_component = true');
ELSIF NEW.is_virtual_component = 'N' THEN
	_uq := array_append(_uq, 'is_virtual_component = false');
ELSE
	_uq := array_append(_uq, 'is_virtual_component = NULL');
END IF;
	END IF;

	IF OLD.size_units IS DISTINCT FROM NEW.size_units THEN
_uq := array_append(_uq, 'size_units = ' || quote_nullable(NEW.size_units));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.component_type SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  component_type_id = $1 RETURNING *'  USING OLD.component_type_id
			INTO _nr;

		NEW.component_type_id = _nr.component_type_id;
		NEW.company_id = _nr.company_id;
		NEW.model = _nr.model;
		NEW.slot_type_id = _nr.slot_type_id;
		NEW.description = _nr.description;
		NEW.part_number = _nr.part_number;
		NEW.is_removable = CASE WHEN _nr.is_removable = true THEN 'Y' WHEN _nr.is_removable = false THEN 'N' ELSE NULL END;
		NEW.asset_permitted = CASE WHEN _nr.asset_permitted = true THEN 'Y' WHEN _nr.asset_permitted = false THEN 'N' ELSE NULL END;
		NEW.is_rack_mountable = CASE WHEN _nr.is_rack_mountable = true THEN 'Y' WHEN _nr.is_rack_mountable = false THEN 'N' ELSE NULL END;
		NEW.is_virtual_component = CASE WHEN _nr.is_virtual_component = true THEN 'Y' WHEN _nr.is_virtual_component = false THEN 'N' ELSE NULL END;
		NEW.size_units = _nr.size_units;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_component_type_upd
	ON jazzhands_legacy.component_type;
CREATE TRIGGER trigger_component_type_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.component_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.component_type_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.component_type_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.component_type%rowtype;
BEGIN
	DELETE FROM jazzhands.component_type
	WHERE  component_type_id = OLD.component_type_id  RETURNING *
	INTO _or;
	OLD.component_type_id = _or.component_type_id;
	OLD.company_id = _or.company_id;
	OLD.model = _or.model;
	OLD.slot_type_id = _or.slot_type_id;
	OLD.description = _or.description;
	OLD.part_number = _or.part_number;
	OLD.is_removable = CASE WHEN _or.is_removable = true THEN 'Y' WHEN _or.is_removable = false THEN 'N' ELSE NULL END;
	OLD.asset_permitted = CASE WHEN _or.asset_permitted = true THEN 'Y' WHEN _or.asset_permitted = false THEN 'N' ELSE NULL END;
	OLD.is_rack_mountable = CASE WHEN _or.is_rack_mountable = true THEN 'Y' WHEN _or.is_rack_mountable = false THEN 'N' ELSE NULL END;
	OLD.is_virtual_component = CASE WHEN _or.is_virtual_component = true THEN 'Y' WHEN _or.is_virtual_component = false THEN 'N' ELSE NULL END;
	OLD.size_units = _or.size_units;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_component_type_del
	ON jazzhands_legacy.component_type;
CREATE TRIGGER trigger_component_type_del
	INSTEAD OF DELETE ON jazzhands_legacy.component_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.component_type_del();


-- Triggers for department

CREATE OR REPLACE FUNCTION jazzhands_legacy.department_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.department%rowtype;
BEGIN

	IF NEW.account_collection_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('account_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.account_collection_id));
	END IF;

	IF NEW.company_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('company_id'));
		_vq := array_append(_vq, quote_nullable(NEW.company_id));
	END IF;

	IF NEW.manager_account_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('manager_account_id'));
		_vq := array_append(_vq, quote_nullable(NEW.manager_account_id));
	END IF;

	IF NEW.is_active IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_active'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_active = 'Y' THEN true WHEN NEW.is_active = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.dept_code IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('dept_code'));
		_vq := array_append(_vq, quote_nullable(NEW.dept_code));
	END IF;

	IF NEW.cost_center_name IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('cost_center_name'));
		_vq := array_append(_vq, quote_nullable(NEW.cost_center_name));
	END IF;

	IF NEW.cost_center_number IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('cost_center_number'));
		_vq := array_append(_vq, quote_nullable(NEW.cost_center_number));
	END IF;

	IF NEW.default_badge_type_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('default_badge_type_id'));
		_vq := array_append(_vq, quote_nullable(NEW.default_badge_type_id));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.department (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.account_collection_id = _nr.account_collection_id;
	NEW.company_id = _nr.company_id;
	NEW.manager_account_id = _nr.manager_account_id;
	NEW.is_active = CASE WHEN _nr.is_active = true THEN 'Y' WHEN _nr.is_active = false THEN 'N' ELSE NULL END;
	NEW.dept_code = _nr.dept_code;
	NEW.cost_center_name = _nr.cost_center_name;
	NEW.cost_center_number = _nr.cost_center_number;
	NEW.default_badge_type_id = _nr.default_badge_type_id;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_department_ins
	ON jazzhands_legacy.department;
CREATE TRIGGER trigger_department_ins
	INSTEAD OF INSERT ON jazzhands_legacy.department
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.department_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.department_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.department%rowtype;
	_nr	jazzhands.department%rowtype;
	_uq	text[];
BEGIN

	IF OLD.account_collection_id IS DISTINCT FROM NEW.account_collection_id THEN
_uq := array_append(_uq, 'account_collection_id = ' || quote_nullable(NEW.account_collection_id));
	END IF;

	IF OLD.company_id IS DISTINCT FROM NEW.company_id THEN
_uq := array_append(_uq, 'company_id = ' || quote_nullable(NEW.company_id));
	END IF;

	IF OLD.manager_account_id IS DISTINCT FROM NEW.manager_account_id THEN
_uq := array_append(_uq, 'manager_account_id = ' || quote_nullable(NEW.manager_account_id));
	END IF;

	IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
IF NEW.is_active = 'Y' THEN
	_uq := array_append(_uq, 'is_active = true');
ELSIF NEW.is_active = 'N' THEN
	_uq := array_append(_uq, 'is_active = false');
ELSE
	_uq := array_append(_uq, 'is_active = NULL');
END IF;
	END IF;

	IF OLD.dept_code IS DISTINCT FROM NEW.dept_code THEN
_uq := array_append(_uq, 'dept_code = ' || quote_nullable(NEW.dept_code));
	END IF;

	IF OLD.cost_center_name IS DISTINCT FROM NEW.cost_center_name THEN
_uq := array_append(_uq, 'cost_center_name = ' || quote_nullable(NEW.cost_center_name));
	END IF;

	IF OLD.cost_center_number IS DISTINCT FROM NEW.cost_center_number THEN
_uq := array_append(_uq, 'cost_center_number = ' || quote_nullable(NEW.cost_center_number));
	END IF;

	IF OLD.default_badge_type_id IS DISTINCT FROM NEW.default_badge_type_id THEN
_uq := array_append(_uq, 'default_badge_type_id = ' || quote_nullable(NEW.default_badge_type_id));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.department SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  account_collection_id = $1 RETURNING *'  USING OLD.account_collection_id
			INTO _nr;

		NEW.account_collection_id = _nr.account_collection_id;
		NEW.company_id = _nr.company_id;
		NEW.manager_account_id = _nr.manager_account_id;
		NEW.is_active = CASE WHEN _nr.is_active = true THEN 'Y' WHEN _nr.is_active = false THEN 'N' ELSE NULL END;
		NEW.dept_code = _nr.dept_code;
		NEW.cost_center_name = _nr.cost_center_name;
		NEW.cost_center_number = _nr.cost_center_number;
		NEW.default_badge_type_id = _nr.default_badge_type_id;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_department_upd
	ON jazzhands_legacy.department;
CREATE TRIGGER trigger_department_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.department
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.department_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.department_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.department%rowtype;
BEGIN
	DELETE FROM jazzhands.department
	WHERE  account_collection_id = OLD.account_collection_id  RETURNING *
	INTO _or;
	OLD.account_collection_id = _or.account_collection_id;
	OLD.company_id = _or.company_id;
	OLD.manager_account_id = _or.manager_account_id;
	OLD.is_active = CASE WHEN _or.is_active = true THEN 'Y' WHEN _or.is_active = false THEN 'N' ELSE NULL END;
	OLD.dept_code = _or.dept_code;
	OLD.cost_center_name = _or.cost_center_name;
	OLD.cost_center_number = _or.cost_center_number;
	OLD.default_badge_type_id = _or.default_badge_type_id;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_department_del
	ON jazzhands_legacy.department;
CREATE TRIGGER trigger_department_del
	INSTEAD OF DELETE ON jazzhands_legacy.department
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.department_del();


-- Triggers for device

CREATE OR REPLACE FUNCTION jazzhands_legacy.device_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.device%rowtype;
	_r	RECORD;
BEGIN
	IF NEW.device_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('device_id'));
		_vq := array_append(_vq, quote_nullable(NEW.device_id));
	END IF;

	IF NEW.component_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('component_id'));
		_vq := array_append(_vq, quote_nullable(NEW.component_id));
	END IF;

	IF NEW.device_type_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('device_type_id'));
		_vq := array_append(_vq, quote_nullable(NEW.device_type_id));
	END IF;

	IF NEW.device_name IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('device_name'));
		_vq := array_append(_vq, quote_nullable(NEW.device_name));
	END IF;

	IF NEW.site_code IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('site_code'));
		_vq := array_append(_vq, quote_nullable(NEW.site_code));
	END IF;

	IF NEW.identifying_dns_record_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('identifying_dns_record_id'));
		_vq := array_append(_vq, quote_nullable(NEW.identifying_dns_record_id));
	END IF;

	IF NEW.host_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('host_id'));
		_vq := array_append(_vq, quote_nullable(NEW.host_id));
	END IF;

	IF NEW.physical_label IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('physical_label'));
		_vq := array_append(_vq, quote_nullable(NEW.physical_label));
	END IF;

	IF NEW.rack_location_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('rack_location_id'));
		_vq := array_append(_vq, quote_nullable(NEW.rack_location_id));
	END IF;

	IF NEW.chassis_location_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('chassis_location_id'));
		_vq := array_append(_vq, quote_nullable(NEW.chassis_location_id));
	END IF;

	IF NEW.parent_device_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('parent_device_id'));
		_vq := array_append(_vq, quote_nullable(NEW.parent_device_id));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.external_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('external_id'));
		_vq := array_append(_vq, quote_nullable(NEW.external_id));
	END IF;

	IF NEW.device_status IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('device_status'));
		_vq := array_append(_vq, quote_nullable(NEW.device_status));
	END IF;

	IF NEW.operating_system_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('operating_system_id'));
		_vq := array_append(_vq, quote_nullable(NEW.operating_system_id));
	END IF;

	IF NEW.service_environment_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('service_environment_id'));
		_vq := array_append(_vq, quote_nullable(NEW.service_environment_id));
	END IF;

	IF NEW.is_virtual_device IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_virtual_device'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_virtual_device = 'Y' THEN true WHEN NEW.is_virtual_device = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.date_in_service IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('date_in_service'));
		_vq := array_append(_vq, quote_nullable(NEW.date_in_service));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.device (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	--
	-- Backwards compatability
	--
	IF NEW.is_monitored IS NOT DISTINCT FROM 'Y' THEN
		_r := NULL;
		INSERT INTO device_collection_device (
			device_collection_id, device_id
		) SELECT device_collection_id, _nr.device_id
		FROM device_collection
			JOIN property USING (device_collection_id)
		WHERE property_name = 'IsMonitoredDevice'
		AND property_type = 'JazzHandsLegacySupport'
		LIMIT 1 RETURNING * INTO _r;
		IF _r IS NULL THEN
			RAISE EXCEPTION 'Unable to set is_monitored'
				USING ERRCODE = 'error_in_assignment';
		END IF;
		NEW.is_monitored = 'Y';
	ELSE
		IF NEW.is_monitored != 'N' THEN
			RAISE EXCEPTION 'is_monitored must be Y or N'
				USING ERRCODE = 'check_violation';
		END IF;
		NEW.is_monitored = 'N';
	END IF;

	IF NEW.should_fetch_config IS NOT DISTINCT FROM 'Y' THEN
		_r := NULL;
		INSERT INTO device_collection_device (
			device_collection_id, device_id
		) SELECT device_collection_id, _nr.device_id
		FROM device_collection
			JOIN property USING (device_collection_id)
		WHERE property_name = 'ShouldConfigFetch'
		AND property_type = 'JazzHandsLegacySupport'
		LIMIT 1 RETURNING * INTO _r;
		IF _r IS NULL THEN
			RAISE EXCEPTION 'Unable to set should_fetch_config'
				USING ERRCODE = 'error_in_assignment';
		END IF;
		NEW.should_fetch_config = 'Y';
	ELSE
		IF NEW.should_fetch_config != 'N' THEN
			RAISE EXCEPTION 'should_fetch_config must be Y or N'
				USING ERRCODE = 'check_violation';
		END IF;
		NEW.should_fetch_config = 'N';
	END IF;

	IF NEW.is_locally_managed IS NOT DISTINCT FROM 'Y' THEN
		_r := NULL;
		INSERT INTO device_collection_device (
			device_collection_id, device_id
		) SELECT device_collection_id, _nr.device_id
		FROM device_collection
			JOIN property USING (device_collection_id)
		WHERE property_name = 'IsLocallyManagedDevice'
		AND property_type = 'JazzHandsLegacySupport'
		LIMIT 1 RETURNING * INTO _r;
		IF _r IS NULL THEN
			RAISE EXCEPTION 'Unable to set is_locally_managed'
				USING ERRCODE = 'error_in_assignment';
		END IF;
		NEW.is_locally_managed = 'Y';
	ELSE
		IF NEW.is_locally_managed != 'N' THEN
			RAISE EXCEPTION 'is_locally_managed must be Y or N'
				USING ERRCODE = 'check_violation';
		END IF;
		NEW.is_locally_managed = 'N';
	END IF;

	IF NEW.auto_mgmt_protocol IS NOT NULL THEN
		_r := NULL;
		INSERT INTO device_collection_device (
			device_collection_id, device_id
		) SELECT device_collection_id, _nr.device_id
		FROM device_collection
			JOIN property USING (device_collection_id)
		WHERE property_name = 'AutoMgmtProtocol'
		AND property_type = 'JazzHandsLegacySupport'
		AND property_value = NEW.auto_mgmt_protocol
		LIMIT 1 RETURNING * INTO _r;
		IF _r IS NULL THEN
			RAISE EXCEPTION 'Unable to set auto_mgmt_protocol'
				USING ERRCODE = 'error_in_assignment';
		END IF;
		-- NEW. is already set.
	END IF;

	NEW.device_id = _nr.device_id;
	NEW.component_id = _nr.component_id;
	NEW.device_type_id = _nr.device_type_id;
	NEW.device_name = _nr.device_name;
	NEW.site_code = _nr.site_code;
	NEW.identifying_dns_record_id = _nr.identifying_dns_record_id;
	NEW.host_id = _nr.host_id;
	NEW.physical_label = _nr.physical_label;
	NEW.rack_location_id = _nr.rack_location_id;
	NEW.chassis_location_id = _nr.chassis_location_id;
	NEW.parent_device_id = _nr.parent_device_id;
	NEW.description = _nr.description;
	NEW.external_id = _nr.external_id;
	NEW.device_status = _nr.device_status;
	NEW.operating_system_id = _nr.operating_system_id;
	NEW.service_environment_id = _nr.service_environment_id;
	NEW.is_virtual_device = CASE WHEN _nr.is_virtual_device = true THEN 'Y' WHEN _nr.is_virtual_device = false THEN 'N' ELSE NULL END;
	NEW.date_in_service = _nr.date_in_service;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_device_ins
	ON jazzhands_legacy.device;
CREATE TRIGGER trigger_device_ins
	INSTEAD OF INSERT ON jazzhands_legacy.device
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.device_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.device_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	RECORD;
	_nr	jazzhands.device%rowtype;
	_uq	text[];
	_dcids	integer[];
	_ndcids	integer[];
BEGIN
	IF OLD.device_id IS DISTINCT FROM NEW.device_id THEN
		RAISE EXCEPTION 'Can not change device_id'
			USING errcode ='invalid_parameter_value';
	END IF;

	IF OLD.component_id IS DISTINCT FROM NEW.component_id THEN
_uq := array_append(_uq, 'component_id = ' || quote_nullable(NEW.component_id));
	END IF;

	IF OLD.device_type_id IS DISTINCT FROM NEW.device_type_id THEN
_uq := array_append(_uq, 'device_type_id = ' || quote_nullable(NEW.device_type_id));
	END IF;

	IF OLD.device_name IS DISTINCT FROM NEW.device_name THEN
_uq := array_append(_uq, 'device_name = ' || quote_nullable(NEW.device_name));
	END IF;

	IF OLD.site_code IS DISTINCT FROM NEW.site_code THEN
_uq := array_append(_uq, 'site_code = ' || quote_nullable(NEW.site_code));
	END IF;

	IF OLD.identifying_dns_record_id IS DISTINCT FROM NEW.identifying_dns_record_id THEN
_uq := array_append(_uq, 'identifying_dns_record_id = ' || quote_nullable(NEW.identifying_dns_record_id));
	END IF;

	IF OLD.host_id IS DISTINCT FROM NEW.host_id THEN
_uq := array_append(_uq, 'host_id = ' || quote_nullable(NEW.host_id));
	END IF;

	IF OLD.physical_label IS DISTINCT FROM NEW.physical_label THEN
_uq := array_append(_uq, 'physical_label = ' || quote_nullable(NEW.physical_label));
	END IF;

	IF OLD.rack_location_id IS DISTINCT FROM NEW.rack_location_id THEN
_uq := array_append(_uq, 'rack_location_id = ' || quote_nullable(NEW.rack_location_id));
	END IF;

	IF OLD.chassis_location_id IS DISTINCT FROM NEW.chassis_location_id THEN
_uq := array_append(_uq, 'chassis_location_id = ' || quote_nullable(NEW.chassis_location_id));
	END IF;

	IF OLD.parent_device_id IS DISTINCT FROM NEW.parent_device_id THEN
_uq := array_append(_uq, 'parent_device_id = ' || quote_nullable(NEW.parent_device_id));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.external_id IS DISTINCT FROM NEW.external_id THEN
_uq := array_append(_uq, 'external_id = ' || quote_nullable(NEW.external_id));
	END IF;

	IF OLD.device_status IS DISTINCT FROM NEW.device_status THEN
_uq := array_append(_uq, 'device_status = ' || quote_nullable(NEW.device_status));
	END IF;

	IF OLD.operating_system_id IS DISTINCT FROM NEW.operating_system_id THEN
_uq := array_append(_uq, 'operating_system_id = ' || quote_nullable(NEW.operating_system_id));
	END IF;

	IF OLD.service_environment_id IS DISTINCT FROM NEW.service_environment_id THEN
_uq := array_append(_uq, 'service_environment_id = ' || quote_nullable(NEW.service_environment_id));
	END IF;

	IF OLD.is_virtual_device IS DISTINCT FROM NEW.is_virtual_device THEN
IF NEW.is_virtual_device = 'Y' THEN
	_uq := array_append(_uq, 'is_virtual_device = true');
ELSIF NEW.is_virtual_device = 'N' THEN
	_uq := array_append(_uq, 'is_virtual_device = false');
ELSE
	_uq := array_append(_uq, 'is_virtual_device = NULL');
END IF;
	END IF;

	IF OLD.date_in_service IS DISTINCT FROM NEW.date_in_service THEN
_uq := array_append(_uq, 'date_in_service = ' || quote_nullable(NEW.date_in_service));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.device SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  device_id = $1 RETURNING *'  USING OLD.device_id
			INTO _nr;

		NEW.device_id = _nr.device_id;
		NEW.component_id = _nr.component_id;
		NEW.device_type_id = _nr.device_type_id;
		NEW.device_name = _nr.device_name;
		NEW.site_code = _nr.site_code;
		NEW.identifying_dns_record_id = _nr.identifying_dns_record_id;
		NEW.host_id = _nr.host_id;
		NEW.physical_label = _nr.physical_label;
		NEW.rack_location_id = _nr.rack_location_id;
		NEW.chassis_location_id = _nr.chassis_location_id;
		NEW.parent_device_id = _nr.parent_device_id;
		NEW.description = _nr.description;
		NEW.external_id = _nr.external_id;
		NEW.device_status = _nr.device_status;
		NEW.operating_system_id = _nr.operating_system_id;
		NEW.service_environment_id = _nr.service_environment_id;
		NEW.is_virtual_device = CASE WHEN _nr.is_virtual_device = true THEN 'Y' WHEN _nr.is_virtual_device = false THEN 'N' ELSE NULL END;
		NEW.date_in_service = _nr.date_in_service;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;

	--
	-- backwards compatibility
	--
	IF OLD.is_monitored IS DISTINCT FROM NEW.is_monitored THEN
		IF NEW.is_monitored = 'Y' THEN
			_r := NULL;
			INSERT INTO device_collection_device (
				device_collection_id, device_id
			) SELECT device_collection_id, NEW.device_id
				FROM device_collection
				JOIN property USING (device_collection_id)
			WHERE property_name = 'IsMonitoredDevice'
			AND property_type = 'JazzHandsLegacySupport'
			LIMIT 1 RETURNING * INTO _r;
			IF _r IS NULL THEN
				RAISE EXCEPTION 'Unable to set is_monitored'
					USING ERRCODE = 'error_in_assignment';
			END IF;
			NEW.is_monitored = 'Y';
		ELSIF NEW.is_monitored = 'N' THEN
			DELETE FROM device_collection_device
			WHERE device_id = OLD.device_id
			AND device_collection_id IN
				( SELECT device_collection_id
					FROM device_collection
					JOIN property USING (device_collection_id)
					WHERE property_name = 'IsMonitoredDevice'
					AND property_type = 'JazzHandsLegacySupport'
			) RETURNING * INTO _r;
			IF _r IS NULL THEN
				RAISE EXCEPTION 'Unable to set is_monitored'
					USING ERRCODE = 'error_in_assignment';
			END IF;
			NEW.is_monitored = 'N';
		ELSE
			IF NEW.is_monitored IS NULL THEN
				RAISE EXCEPTION '% is not a valid is_monitored state',
					NEW.is_monitored
					USING ERRCODE = 'not_null_violation';
			ELSE
				RAISE EXCEPTION '% is not a valid is_monitored state',
					NEW.is_monitored
					USING ERRCODE = 'check_violation';
			END IF;
		END IF;
	END IF;

	IF OLD.should_fetch_config IS DISTINCT FROM NEW.should_fetch_config THEN
		IF NEW.should_fetch_config = 'Y' THEN
			_r := NULL;
			INSERT INTO device_collection_device (
				device_collection_id, device_id
			) SELECT device_collection_id, NEW.device_id
				FROM device_collection
				JOIN property USING (device_collection_id)
			WHERE property_name = 'ShouldConfigFetch'
			AND property_type = 'JazzHandsLegacySupport'
			LIMIT 1 RETURNING * INTO _r;
			IF _r IS NULL THEN
				RAISE EXCEPTION 'Unable to set should_fetch_config'
				USING ERRCODE = 'error_in_assignment';
			END IF;
			NEW.should_fetch_config = 'Y';
		ELSIF NEW.should_fetch_config = 'N' THEN
			DELETE FROM device_collection_device
			WHERE device_id = OLD.device_id
			AND device_collection_id IN
				( SELECT device_collection_id
					FROM device_collection
					JOIN property USING (device_collection_id)
					WHERE property_name = 'ShouldConfigFetch'
					AND property_type = 'JazzHandsLegacySupport'
			) RETURNING * INTO _r;
			IF _r IS NULL THEN
				RAISE EXCEPTION 'Unable to set should_fetch_config'
					USING ERRCODE = 'error_in_assignment';
			END IF;
			NEW.should_fetch_config = 'N';
		ELSE
			IF NEW.should_fetch_config IS NULL THEN
				RAISE EXCEPTION '% is not a valid should_fetch_config state',
					NEW.should_fetch_config
					USING ERRCODE = 'not_null_violation';
			ELSE
				RAISE EXCEPTION '% is not a valid should_fetch_config state',
					NEW.should_fetch_config
					USING ERRCODE = 'check_violation';
			END IF;
		END IF;
	END IF;

	IF OLD.is_locally_managed IS DISTINCT FROM NEW.is_locally_managed THEN
		IF NEW.is_locally_managed = 'Y' THEN
			_r := NULL;
			INSERT INTO device_collection_device (
				device_collection_id, device_id
			) SELECT device_collection_id, NEW.device_id
				FROM device_collection
				JOIN property USING (device_collection_id)
			WHERE property_name = 'IsLocallyManagedDevice'
			AND property_type = 'JazzHandsLegacySupport'
			LIMIT 1 RETURNING * INTO _r;
			IF _r IS NULL THEN
				RAISE EXCEPTION 'Unable to set is_locally_managed'
				USING ERRCODE = 'error_in_assignment';
			END IF;
			NEW.is_locally_managed = 'Y';
		ELSIF NEW.is_locally_managed = 'N' THEN
			DELETE FROM device_collection_device
			WHERE device_id = OLD.device_id
			AND device_collection_id IN
				( SELECT device_collection_id
					FROM device_collection
					JOIN property USING (device_collection_id)
					WHERE property_name = 'IsLocallyManagedDevice'
					AND property_type = 'JazzHandsLegacySupport'
			) RETURNING * INTO _r;
			IF _r IS NULL THEN
				RAISE EXCEPTION 'Unable to set is_locally_managed'
					USING ERRCODE = 'error_in_assignment';
			END IF;
			NEW.is_locally_managed = 'N';
		ELSE
			IF NEW.is_locally_managed IS NULL THEN
				RAISE EXCEPTION '% is not a valid is_locally_managed state',
					NEW.is_locally_managed
					USING ERRCODE = 'not_null_violation';
			ELSE
				RAISE EXCEPTION '% is not a valid is_locally_managed state',
					NEW.is_locally_managed
					USING ERRCODE = 'check_violation';
			END IF;
		END IF;
	END IF;

	IF OLD.auto_mgmt_protocol IS DISTINCT FROM NEW.auto_mgmt_protocol THEN
		IF OLD.auto_mgmt_protocol IS NULL THEN
			_r := NULL;
			INSERT INTO device_collection_device (
				device_collection_id, device_id
			) SELECT device_collection_id, NEW.device_id
				FROM device_collection
					JOIN property USING (device_collection_id)
				WHERE property_name = 'AutoMgmtProtocol'
				AND property_type = 'JazzHandsLegacySupport'
				AND property_value = NEW.auto_mgmt_protocol
				ORDER BY device_collection_id, property_id
				LIMIT 1 RETURNING * INTO _r;
			IF _r IS NULL THEN
				RAISE EXCEPTION 'Unable to set auto_mgmt_protocol'
					USING ERRCODE = 'error_in_assignment';
			END IF;
		ELSIF NEW.auto_mgmt_protocol IS NULL THEN
			DELETE FROM device_collection_device
			WHERE device_id = OLD.device_id
			AND device_collection_id IN
				( SELECT device_collection_id
					FROM device_collection
						JOIN property USING (device_collection_id)
					WHERE property_name = 'AutoMgmtProtocol'
					AND property_type = 'JazzHandsLegacySupport'
				);
		ELSE
			UPDATE device_collection_device
			SET device_collection_id = (
				( SELECT device_collection_id
					FROM device_collection
						JOIN property USING (device_collection_id)
					WHERE property_name = 'AutoMgmtProtocol'
					AND property_type = 'JazzHandsLegacySupport'
					AND property_value = NEW.auto_mgmt_protocol
					ORDER BY device_collection_id, property_id
					LIMIT 1
				)
			) WHERE device_id = NEW.device_id
			AND device_collection_id IN
				( SELECT device_collection_id
					FROM device_collection
					JOIN property USING (device_collection_id)
					WHERE property_name = 'AutoMgmtProtocol'
					AND property_type = 'JazzHandsLegacySupport'
					AND property_value = OLD.auto_mgmt_protocol
				) RETURNING * INTO _r;
			IF _r IS NULL THEN
				RAISE EXCEPTION 'Unable to set auto_mgmt_protocol'
					USING ERRCODE = 'error_in_assignment';
			END IF;
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_device_upd
	ON jazzhands_legacy.device;
CREATE TRIGGER trigger_device_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.device
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.device_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.device_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.device%rowtype;
BEGIN
	DELETE FROM jazzhands.device
	WHERE  device_id = OLD.device_id  RETURNING *
	INTO _or;
	OLD.device_id = _or.device_id;
	OLD.component_id = _or.component_id;
	OLD.device_type_id = _or.device_type_id;
	OLD.device_name = _or.device_name;
	OLD.site_code = _or.site_code;
	OLD.identifying_dns_record_id = _or.identifying_dns_record_id;
	OLD.host_id = _or.host_id;
	OLD.physical_label = _or.physical_label;
	OLD.rack_location_id = _or.rack_location_id;
	OLD.chassis_location_id = _or.chassis_location_id;
	OLD.parent_device_id = _or.parent_device_id;
	OLD.description = _or.description;
	OLD.external_id = _or.external_id;
	OLD.device_status = _or.device_status;
	OLD.operating_system_id = _or.operating_system_id;
	OLD.service_environment_id = _or.service_environment_id;
	OLD.is_virtual_device = CASE WHEN _or.is_virtual_device = true THEN 'Y' WHEN _or.is_virtual_device = false THEN 'N' ELSE NULL END;
	OLD.date_in_service = _or.date_in_service;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_device_del
	ON jazzhands_legacy.device;
CREATE TRIGGER trigger_device_del
	INSTEAD OF DELETE ON jazzhands_legacy.device
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.device_del();


-- Triggers for device_type

CREATE OR REPLACE FUNCTION jazzhands_legacy.device_type_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.device_type%rowtype;
BEGIN

	IF NEW.device_type_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('device_type_id'));
		_vq := array_append(_vq, quote_nullable(NEW.device_type_id));
	END IF;

	IF NEW.component_type_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('component_type_id'));
		_vq := array_append(_vq, quote_nullable(NEW.component_type_id));
	END IF;

	IF NEW.device_type_name IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('device_type_name'));
		_vq := array_append(_vq, quote_nullable(NEW.device_type_name));
	END IF;

	IF NEW.template_device_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('template_device_id'));
		_vq := array_append(_vq, quote_nullable(NEW.template_device_id));
	END IF;

	IF NEW.idealized_device_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('idealized_device_id'));
		_vq := array_append(_vq, quote_nullable(NEW.idealized_device_id));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.company_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('company_id'));
		_vq := array_append(_vq, quote_nullable(NEW.company_id));
	END IF;

	IF NEW.model IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('model'));
		_vq := array_append(_vq, quote_nullable(NEW.model));
	END IF;

	IF NEW.device_type_depth_in_cm IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('device_type_depth_in_cm'));
		_vq := array_append(_vq, quote_nullable(NEW.device_type_depth_in_cm));
	END IF;

	IF NEW.processor_architecture IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('processor_architecture'));
		_vq := array_append(_vq, quote_nullable(NEW.processor_architecture));
	END IF;

	IF NEW.config_fetch_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('config_fetch_type'));
		_vq := array_append(_vq, quote_nullable(NEW.config_fetch_type));
	END IF;

	IF NEW.rack_units IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('rack_units'));
		_vq := array_append(_vq, quote_nullable(NEW.rack_units));
	END IF;

	IF NEW.has_802_3_interface IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('has_802_3_interface'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.has_802_3_interface = 'Y' THEN true WHEN NEW.has_802_3_interface = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.has_802_11_interface IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('has_802_11_interface'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.has_802_11_interface = 'Y' THEN true WHEN NEW.has_802_11_interface = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.snmp_capable IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('snmp_capable'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.snmp_capable = 'Y' THEN true WHEN NEW.snmp_capable = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.is_chassis IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_chassis'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_chassis = 'Y' THEN true WHEN NEW.is_chassis = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.device_type (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.device_type_id = _nr.device_type_id;
	NEW.component_type_id = _nr.component_type_id;
	NEW.device_type_name = _nr.device_type_name;
	NEW.template_device_id = _nr.template_device_id;
	NEW.idealized_device_id = _nr.idealized_device_id;
	NEW.description = _nr.description;
	NEW.company_id = _nr.company_id;
	NEW.model = _nr.model;
	NEW.device_type_depth_in_cm = _nr.device_type_depth_in_cm;
	NEW.processor_architecture = _nr.processor_architecture;
	NEW.config_fetch_type = _nr.config_fetch_type;
	NEW.rack_units = _nr.rack_units;
	NEW.has_802_3_interface = CASE WHEN _nr.has_802_3_interface = true THEN 'Y' WHEN _nr.has_802_3_interface = false THEN 'N' ELSE NULL END;
	NEW.has_802_11_interface = CASE WHEN _nr.has_802_11_interface = true THEN 'Y' WHEN _nr.has_802_11_interface = false THEN 'N' ELSE NULL END;
	NEW.snmp_capable = CASE WHEN _nr.snmp_capable = true THEN 'Y' WHEN _nr.snmp_capable = false THEN 'N' ELSE NULL END;
	NEW.is_chassis = CASE WHEN _nr.is_chassis = true THEN 'Y' WHEN _nr.is_chassis = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_device_type_ins
	ON jazzhands_legacy.device_type;
CREATE TRIGGER trigger_device_type_ins
	INSTEAD OF INSERT ON jazzhands_legacy.device_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.device_type_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.device_type_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.device_type%rowtype;
	_nr	jazzhands.device_type%rowtype;
	_uq	text[];
BEGIN

	IF OLD.device_type_id IS DISTINCT FROM NEW.device_type_id THEN
_uq := array_append(_uq, 'device_type_id = ' || quote_nullable(NEW.device_type_id));
	END IF;

	IF OLD.component_type_id IS DISTINCT FROM NEW.component_type_id THEN
_uq := array_append(_uq, 'component_type_id = ' || quote_nullable(NEW.component_type_id));
	END IF;

	IF OLD.device_type_name IS DISTINCT FROM NEW.device_type_name THEN
_uq := array_append(_uq, 'device_type_name = ' || quote_nullable(NEW.device_type_name));
	END IF;

	IF OLD.template_device_id IS DISTINCT FROM NEW.template_device_id THEN
_uq := array_append(_uq, 'template_device_id = ' || quote_nullable(NEW.template_device_id));
	END IF;

	IF OLD.idealized_device_id IS DISTINCT FROM NEW.idealized_device_id THEN
_uq := array_append(_uq, 'idealized_device_id = ' || quote_nullable(NEW.idealized_device_id));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.company_id IS DISTINCT FROM NEW.company_id THEN
_uq := array_append(_uq, 'company_id = ' || quote_nullable(NEW.company_id));
	END IF;

	IF OLD.model IS DISTINCT FROM NEW.model THEN
_uq := array_append(_uq, 'model = ' || quote_nullable(NEW.model));
	END IF;

	IF OLD.device_type_depth_in_cm IS DISTINCT FROM NEW.device_type_depth_in_cm THEN
_uq := array_append(_uq, 'device_type_depth_in_cm = ' || quote_nullable(NEW.device_type_depth_in_cm));
	END IF;

	IF OLD.processor_architecture IS DISTINCT FROM NEW.processor_architecture THEN
_uq := array_append(_uq, 'processor_architecture = ' || quote_nullable(NEW.processor_architecture));
	END IF;

	IF OLD.config_fetch_type IS DISTINCT FROM NEW.config_fetch_type THEN
_uq := array_append(_uq, 'config_fetch_type = ' || quote_nullable(NEW.config_fetch_type));
	END IF;

	IF OLD.rack_units IS DISTINCT FROM NEW.rack_units THEN
_uq := array_append(_uq, 'rack_units = ' || quote_nullable(NEW.rack_units));
	END IF;

	IF OLD.has_802_3_interface IS DISTINCT FROM NEW.has_802_3_interface THEN
IF NEW.has_802_3_interface = 'Y' THEN
	_uq := array_append(_uq, 'has_802_3_interface = true');
ELSIF NEW.has_802_3_interface = 'N' THEN
	_uq := array_append(_uq, 'has_802_3_interface = false');
ELSE
	_uq := array_append(_uq, 'has_802_3_interface = NULL');
END IF;
	END IF;

	IF OLD.has_802_11_interface IS DISTINCT FROM NEW.has_802_11_interface THEN
IF NEW.has_802_11_interface = 'Y' THEN
	_uq := array_append(_uq, 'has_802_11_interface = true');
ELSIF NEW.has_802_11_interface = 'N' THEN
	_uq := array_append(_uq, 'has_802_11_interface = false');
ELSE
	_uq := array_append(_uq, 'has_802_11_interface = NULL');
END IF;
	END IF;

	IF OLD.snmp_capable IS DISTINCT FROM NEW.snmp_capable THEN
IF NEW.snmp_capable = 'Y' THEN
	_uq := array_append(_uq, 'snmp_capable = true');
ELSIF NEW.snmp_capable = 'N' THEN
	_uq := array_append(_uq, 'snmp_capable = false');
ELSE
	_uq := array_append(_uq, 'snmp_capable = NULL');
END IF;
	END IF;

	IF OLD.is_chassis IS DISTINCT FROM NEW.is_chassis THEN
IF NEW.is_chassis = 'Y' THEN
	_uq := array_append(_uq, 'is_chassis = true');
ELSIF NEW.is_chassis = 'N' THEN
	_uq := array_append(_uq, 'is_chassis = false');
ELSE
	_uq := array_append(_uq, 'is_chassis = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.device_type SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  device_type_id = $1 RETURNING *'  USING OLD.device_type_id
			INTO _nr;

		NEW.device_type_id = _nr.device_type_id;
		NEW.component_type_id = _nr.component_type_id;
		NEW.device_type_name = _nr.device_type_name;
		NEW.template_device_id = _nr.template_device_id;
		NEW.idealized_device_id = _nr.idealized_device_id;
		NEW.description = _nr.description;
		NEW.company_id = _nr.company_id;
		NEW.model = _nr.model;
		NEW.device_type_depth_in_cm = _nr.device_type_depth_in_cm;
		NEW.processor_architecture = _nr.processor_architecture;
		NEW.config_fetch_type = _nr.config_fetch_type;
		NEW.rack_units = _nr.rack_units;
		NEW.has_802_3_interface = CASE WHEN _nr.has_802_3_interface = true THEN 'Y' WHEN _nr.has_802_3_interface = false THEN 'N' ELSE NULL END;
		NEW.has_802_11_interface = CASE WHEN _nr.has_802_11_interface = true THEN 'Y' WHEN _nr.has_802_11_interface = false THEN 'N' ELSE NULL END;
		NEW.snmp_capable = CASE WHEN _nr.snmp_capable = true THEN 'Y' WHEN _nr.snmp_capable = false THEN 'N' ELSE NULL END;
		NEW.is_chassis = CASE WHEN _nr.is_chassis = true THEN 'Y' WHEN _nr.is_chassis = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_device_type_upd
	ON jazzhands_legacy.device_type;
CREATE TRIGGER trigger_device_type_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.device_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.device_type_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.device_type_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.device_type%rowtype;
BEGIN
	DELETE FROM jazzhands.device_type
	WHERE  device_type_id = OLD.device_type_id  RETURNING *
	INTO _or;
	OLD.device_type_id = _or.device_type_id;
	OLD.component_type_id = _or.component_type_id;
	OLD.device_type_name = _or.device_type_name;
	OLD.template_device_id = _or.template_device_id;
	OLD.idealized_device_id = _or.idealized_device_id;
	OLD.description = _or.description;
	OLD.company_id = _or.company_id;
	OLD.model = _or.model;
	OLD.device_type_depth_in_cm = _or.device_type_depth_in_cm;
	OLD.processor_architecture = _or.processor_architecture;
	OLD.config_fetch_type = _or.config_fetch_type;
	OLD.rack_units = _or.rack_units;
	OLD.has_802_3_interface = CASE WHEN _or.has_802_3_interface = true THEN 'Y' WHEN _or.has_802_3_interface = false THEN 'N' ELSE NULL END;
	OLD.has_802_11_interface = CASE WHEN _or.has_802_11_interface = true THEN 'Y' WHEN _or.has_802_11_interface = false THEN 'N' ELSE NULL END;
	OLD.snmp_capable = CASE WHEN _or.snmp_capable = true THEN 'Y' WHEN _or.snmp_capable = false THEN 'N' ELSE NULL END;
	OLD.is_chassis = CASE WHEN _or.is_chassis = true THEN 'Y' WHEN _or.is_chassis = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_device_type_del
	ON jazzhands_legacy.device_type;
CREATE TRIGGER trigger_device_type_del
	INSTEAD OF DELETE ON jazzhands_legacy.device_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.device_type_del();


-- Triggers for dns_domain_ip_universe

CREATE OR REPLACE FUNCTION jazzhands_legacy.dns_domain_ip_universe_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.dns_domain_ip_universe%rowtype;
BEGIN

	IF NEW.dns_domain_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('dns_domain_id'));
		_vq := array_append(_vq, quote_nullable(NEW.dns_domain_id));
	END IF;

	IF NEW.ip_universe_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('ip_universe_id'));
		_vq := array_append(_vq, quote_nullable(NEW.ip_universe_id));
	END IF;

	IF NEW.soa_class IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('soa_class'));
		_vq := array_append(_vq, quote_nullable(NEW.soa_class));
	END IF;

	IF NEW.soa_ttl IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('soa_ttl'));
		_vq := array_append(_vq, quote_nullable(NEW.soa_ttl));
	END IF;

	IF NEW.soa_serial IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('soa_serial'));
		_vq := array_append(_vq, quote_nullable(NEW.soa_serial));
	END IF;

	IF NEW.soa_refresh IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('soa_refresh'));
		_vq := array_append(_vq, quote_nullable(NEW.soa_refresh));
	END IF;

	IF NEW.soa_retry IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('soa_retry'));
		_vq := array_append(_vq, quote_nullable(NEW.soa_retry));
	END IF;

	IF NEW.soa_expire IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('soa_expire'));
		_vq := array_append(_vq, quote_nullable(NEW.soa_expire));
	END IF;

	IF NEW.soa_minimum IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('soa_minimum'));
		_vq := array_append(_vq, quote_nullable(NEW.soa_minimum));
	END IF;

	IF NEW.soa_mname IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('soa_mname'));
		_vq := array_append(_vq, quote_nullable(NEW.soa_mname));
	END IF;

	IF NEW.soa_rname IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('soa_rname'));
		_vq := array_append(_vq, quote_nullable(NEW.soa_rname));
	END IF;

	IF NEW.should_generate IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('should_generate'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.should_generate = 'Y' THEN true WHEN NEW.should_generate = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.last_generated IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('last_generated'));
		_vq := array_append(_vq, quote_nullable(NEW.last_generated));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.dns_domain_ip_universe (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.dns_domain_id = _nr.dns_domain_id;
	NEW.ip_universe_id = _nr.ip_universe_id;
	NEW.soa_class = _nr.soa_class;
	NEW.soa_ttl = _nr.soa_ttl;
	NEW.soa_serial = _nr.soa_serial;
	NEW.soa_refresh = _nr.soa_refresh;
	NEW.soa_retry = _nr.soa_retry;
	NEW.soa_expire = _nr.soa_expire;
	NEW.soa_minimum = _nr.soa_minimum;
	NEW.soa_mname = _nr.soa_mname;
	NEW.soa_rname = _nr.soa_rname;
	NEW.should_generate = CASE WHEN _nr.should_generate = true THEN 'Y' WHEN _nr.should_generate = false THEN 'N' ELSE NULL END;
	NEW.last_generated = _nr.last_generated;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_domain_ip_universe_ins
	ON jazzhands_legacy.dns_domain_ip_universe;
CREATE TRIGGER trigger_dns_domain_ip_universe_ins
	INSTEAD OF INSERT ON jazzhands_legacy.dns_domain_ip_universe
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.dns_domain_ip_universe_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.dns_domain_ip_universe_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.dns_domain_ip_universe%rowtype;
	_nr	jazzhands.dns_domain_ip_universe%rowtype;
	_uq	text[];
BEGIN

	IF OLD.dns_domain_id IS DISTINCT FROM NEW.dns_domain_id THEN
_uq := array_append(_uq, 'dns_domain_id = ' || quote_nullable(NEW.dns_domain_id));
	END IF;

	IF OLD.ip_universe_id IS DISTINCT FROM NEW.ip_universe_id THEN
_uq := array_append(_uq, 'ip_universe_id = ' || quote_nullable(NEW.ip_universe_id));
	END IF;

	IF OLD.soa_class IS DISTINCT FROM NEW.soa_class THEN
_uq := array_append(_uq, 'soa_class = ' || quote_nullable(NEW.soa_class));
	END IF;

	IF OLD.soa_ttl IS DISTINCT FROM NEW.soa_ttl THEN
_uq := array_append(_uq, 'soa_ttl = ' || quote_nullable(NEW.soa_ttl));
	END IF;

	IF OLD.soa_serial IS DISTINCT FROM NEW.soa_serial THEN
_uq := array_append(_uq, 'soa_serial = ' || quote_nullable(NEW.soa_serial));
	END IF;

	IF OLD.soa_refresh IS DISTINCT FROM NEW.soa_refresh THEN
_uq := array_append(_uq, 'soa_refresh = ' || quote_nullable(NEW.soa_refresh));
	END IF;

	IF OLD.soa_retry IS DISTINCT FROM NEW.soa_retry THEN
_uq := array_append(_uq, 'soa_retry = ' || quote_nullable(NEW.soa_retry));
	END IF;

	IF OLD.soa_expire IS DISTINCT FROM NEW.soa_expire THEN
_uq := array_append(_uq, 'soa_expire = ' || quote_nullable(NEW.soa_expire));
	END IF;

	IF OLD.soa_minimum IS DISTINCT FROM NEW.soa_minimum THEN
_uq := array_append(_uq, 'soa_minimum = ' || quote_nullable(NEW.soa_minimum));
	END IF;

	IF OLD.soa_mname IS DISTINCT FROM NEW.soa_mname THEN
_uq := array_append(_uq, 'soa_mname = ' || quote_nullable(NEW.soa_mname));
	END IF;

	IF OLD.soa_rname IS DISTINCT FROM NEW.soa_rname THEN
_uq := array_append(_uq, 'soa_rname = ' || quote_nullable(NEW.soa_rname));
	END IF;

	IF OLD.should_generate IS DISTINCT FROM NEW.should_generate THEN
IF NEW.should_generate = 'Y' THEN
	_uq := array_append(_uq, 'should_generate = true');
ELSIF NEW.should_generate = 'N' THEN
	_uq := array_append(_uq, 'should_generate = false');
ELSE
	_uq := array_append(_uq, 'should_generate = NULL');
END IF;
	END IF;

	IF OLD.last_generated IS DISTINCT FROM NEW.last_generated THEN
_uq := array_append(_uq, 'last_generated = ' || quote_nullable(NEW.last_generated));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.dns_domain_ip_universe SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  dns_domain_id = $1 AND  ip_universe_id = $2 RETURNING *'  USING OLD.dns_domain_id, OLD.ip_universe_id
			INTO _nr;

		NEW.dns_domain_id = _nr.dns_domain_id;
		NEW.ip_universe_id = _nr.ip_universe_id;
		NEW.soa_class = _nr.soa_class;
		NEW.soa_ttl = _nr.soa_ttl;
		NEW.soa_serial = _nr.soa_serial;
		NEW.soa_refresh = _nr.soa_refresh;
		NEW.soa_retry = _nr.soa_retry;
		NEW.soa_expire = _nr.soa_expire;
		NEW.soa_minimum = _nr.soa_minimum;
		NEW.soa_mname = _nr.soa_mname;
		NEW.soa_rname = _nr.soa_rname;
		NEW.should_generate = CASE WHEN _nr.should_generate = true THEN 'Y' WHEN _nr.should_generate = false THEN 'N' ELSE NULL END;
		NEW.last_generated = _nr.last_generated;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_domain_ip_universe_upd
	ON jazzhands_legacy.dns_domain_ip_universe;
CREATE TRIGGER trigger_dns_domain_ip_universe_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.dns_domain_ip_universe
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.dns_domain_ip_universe_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.dns_domain_ip_universe_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.dns_domain_ip_universe%rowtype;
BEGIN
	DELETE FROM jazzhands.dns_domain_ip_universe
	WHERE  dns_domain_id = OLD.dns_domain_id  AND  ip_universe_id = OLD.ip_universe_id  RETURNING *
	INTO _or;
	OLD.dns_domain_id = _or.dns_domain_id;
	OLD.ip_universe_id = _or.ip_universe_id;
	OLD.soa_class = _or.soa_class;
	OLD.soa_ttl = _or.soa_ttl;
	OLD.soa_serial = _or.soa_serial;
	OLD.soa_refresh = _or.soa_refresh;
	OLD.soa_retry = _or.soa_retry;
	OLD.soa_expire = _or.soa_expire;
	OLD.soa_minimum = _or.soa_minimum;
	OLD.soa_mname = _or.soa_mname;
	OLD.soa_rname = _or.soa_rname;
	OLD.should_generate = CASE WHEN _or.should_generate = true THEN 'Y' WHEN _or.should_generate = false THEN 'N' ELSE NULL END;
	OLD.last_generated = _or.last_generated;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_domain_ip_universe_del
	ON jazzhands_legacy.dns_domain_ip_universe;
CREATE TRIGGER trigger_dns_domain_ip_universe_del
	INSTEAD OF DELETE ON jazzhands_legacy.dns_domain_ip_universe
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.dns_domain_ip_universe_del();


-- Triggers for dns_record

CREATE OR REPLACE FUNCTION jazzhands_legacy.dns_record_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.dns_record%rowtype;
BEGIN

	IF NEW.dns_record_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('dns_record_id'));
		_vq := array_append(_vq, quote_nullable(NEW.dns_record_id));
	END IF;

	IF NEW.dns_name IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('dns_name'));
		_vq := array_append(_vq, quote_nullable(NEW.dns_name));
	END IF;

	IF NEW.dns_domain_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('dns_domain_id'));
		_vq := array_append(_vq, quote_nullable(NEW.dns_domain_id));
	END IF;

	IF NEW.dns_ttl IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('dns_ttl'));
		_vq := array_append(_vq, quote_nullable(NEW.dns_ttl));
	END IF;

	IF NEW.dns_class IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('dns_class'));
		_vq := array_append(_vq, quote_nullable(NEW.dns_class));
	END IF;

	IF NEW.dns_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('dns_type'));
		_vq := array_append(_vq, quote_nullable(NEW.dns_type));
	END IF;

	IF NEW.dns_value IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('dns_value'));
		_vq := array_append(_vq, quote_nullable(NEW.dns_value));
	END IF;

	IF NEW.dns_priority IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('dns_priority'));
		_vq := array_append(_vq, quote_nullable(NEW.dns_priority));
	END IF;

	IF NEW.dns_srv_service IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('dns_srv_service'));
		_vq := array_append(_vq, quote_nullable(NEW.dns_srv_service));
	END IF;

	IF NEW.dns_srv_protocol IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('dns_srv_protocol'));
		_vq := array_append(_vq, quote_nullable(NEW.dns_srv_protocol));
	END IF;

	IF NEW.dns_srv_weight IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('dns_srv_weight'));
		_vq := array_append(_vq, quote_nullable(NEW.dns_srv_weight));
	END IF;

	IF NEW.dns_srv_port IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('dns_srv_port'));
		_vq := array_append(_vq, quote_nullable(NEW.dns_srv_port));
	END IF;

	IF NEW.netblock_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('netblock_id'));
		_vq := array_append(_vq, quote_nullable(NEW.netblock_id));
	END IF;

	IF NEW.ip_universe_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('ip_universe_id'));
		_vq := array_append(_vq, quote_nullable(NEW.ip_universe_id));
	END IF;

	IF NEW.reference_dns_record_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('reference_dns_record_id'));
		_vq := array_append(_vq, quote_nullable(NEW.reference_dns_record_id));
	END IF;

	IF NEW.dns_value_record_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('dns_value_record_id'));
		_vq := array_append(_vq, quote_nullable(NEW.dns_value_record_id));
	END IF;

	IF NEW.should_generate_ptr IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('should_generate_ptr'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.should_generate_ptr = 'Y' THEN true WHEN NEW.should_generate_ptr = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.is_enabled IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_enabled'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_enabled = 'Y' THEN true WHEN NEW.is_enabled = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.dns_record (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.dns_record_id = _nr.dns_record_id;
	NEW.dns_name = _nr.dns_name;
	NEW.dns_domain_id = _nr.dns_domain_id;
	NEW.dns_ttl = _nr.dns_ttl;
	NEW.dns_class = _nr.dns_class;
	NEW.dns_type = _nr.dns_type;
	NEW.dns_value = _nr.dns_value;
	NEW.dns_priority = _nr.dns_priority;
	NEW.dns_srv_service = _nr.dns_srv_service;
	NEW.dns_srv_protocol = _nr.dns_srv_protocol;
	NEW.dns_srv_weight = _nr.dns_srv_weight;
	NEW.dns_srv_port = _nr.dns_srv_port;
	NEW.netblock_id = _nr.netblock_id;
	NEW.ip_universe_id = _nr.ip_universe_id;
	NEW.reference_dns_record_id = _nr.reference_dns_record_id;
	NEW.dns_value_record_id = _nr.dns_value_record_id;
	NEW.should_generate_ptr = CASE WHEN _nr.should_generate_ptr = true THEN 'Y' WHEN _nr.should_generate_ptr = false THEN 'N' ELSE NULL END;
	NEW.is_enabled = CASE WHEN _nr.is_enabled = true THEN 'Y' WHEN _nr.is_enabled = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_record_ins
	ON jazzhands_legacy.dns_record;
CREATE TRIGGER trigger_dns_record_ins
	INSTEAD OF INSERT ON jazzhands_legacy.dns_record
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.dns_record_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.dns_record_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.dns_record%rowtype;
	_nr	jazzhands.dns_record%rowtype;
	_uq	text[];
BEGIN

	IF OLD.dns_record_id IS DISTINCT FROM NEW.dns_record_id THEN
_uq := array_append(_uq, 'dns_record_id = ' || quote_nullable(NEW.dns_record_id));
	END IF;

	IF OLD.dns_name IS DISTINCT FROM NEW.dns_name THEN
_uq := array_append(_uq, 'dns_name = ' || quote_nullable(NEW.dns_name));
	END IF;

	IF OLD.dns_domain_id IS DISTINCT FROM NEW.dns_domain_id THEN
_uq := array_append(_uq, 'dns_domain_id = ' || quote_nullable(NEW.dns_domain_id));
	END IF;

	IF OLD.dns_ttl IS DISTINCT FROM NEW.dns_ttl THEN
_uq := array_append(_uq, 'dns_ttl = ' || quote_nullable(NEW.dns_ttl));
	END IF;

	IF OLD.dns_class IS DISTINCT FROM NEW.dns_class THEN
_uq := array_append(_uq, 'dns_class = ' || quote_nullable(NEW.dns_class));
	END IF;

	IF OLD.dns_type IS DISTINCT FROM NEW.dns_type THEN
_uq := array_append(_uq, 'dns_type = ' || quote_nullable(NEW.dns_type));
	END IF;

	IF OLD.dns_value IS DISTINCT FROM NEW.dns_value THEN
_uq := array_append(_uq, 'dns_value = ' || quote_nullable(NEW.dns_value));
	END IF;

	IF OLD.dns_priority IS DISTINCT FROM NEW.dns_priority THEN
_uq := array_append(_uq, 'dns_priority = ' || quote_nullable(NEW.dns_priority));
	END IF;

	IF OLD.dns_srv_service IS DISTINCT FROM NEW.dns_srv_service THEN
_uq := array_append(_uq, 'dns_srv_service = ' || quote_nullable(NEW.dns_srv_service));
	END IF;

	IF OLD.dns_srv_protocol IS DISTINCT FROM NEW.dns_srv_protocol THEN
_uq := array_append(_uq, 'dns_srv_protocol = ' || quote_nullable(NEW.dns_srv_protocol));
	END IF;

	IF OLD.dns_srv_weight IS DISTINCT FROM NEW.dns_srv_weight THEN
_uq := array_append(_uq, 'dns_srv_weight = ' || quote_nullable(NEW.dns_srv_weight));
	END IF;

	IF OLD.dns_srv_port IS DISTINCT FROM NEW.dns_srv_port THEN
_uq := array_append(_uq, 'dns_srv_port = ' || quote_nullable(NEW.dns_srv_port));
	END IF;

	IF OLD.netblock_id IS DISTINCT FROM NEW.netblock_id THEN
_uq := array_append(_uq, 'netblock_id = ' || quote_nullable(NEW.netblock_id));
	END IF;

	IF OLD.ip_universe_id IS DISTINCT FROM NEW.ip_universe_id THEN
_uq := array_append(_uq, 'ip_universe_id = ' || quote_nullable(NEW.ip_universe_id));
	END IF;

	IF OLD.reference_dns_record_id IS DISTINCT FROM NEW.reference_dns_record_id THEN
_uq := array_append(_uq, 'reference_dns_record_id = ' || quote_nullable(NEW.reference_dns_record_id));
	END IF;

	IF OLD.dns_value_record_id IS DISTINCT FROM NEW.dns_value_record_id THEN
_uq := array_append(_uq, 'dns_value_record_id = ' || quote_nullable(NEW.dns_value_record_id));
	END IF;

	IF OLD.should_generate_ptr IS DISTINCT FROM NEW.should_generate_ptr THEN
IF NEW.should_generate_ptr = 'Y' THEN
	_uq := array_append(_uq, 'should_generate_ptr = true');
ELSIF NEW.should_generate_ptr = 'N' THEN
	_uq := array_append(_uq, 'should_generate_ptr = false');
ELSE
	_uq := array_append(_uq, 'should_generate_ptr = NULL');
END IF;
	END IF;

	IF OLD.is_enabled IS DISTINCT FROM NEW.is_enabled THEN
IF NEW.is_enabled = 'Y' THEN
	_uq := array_append(_uq, 'is_enabled = true');
ELSIF NEW.is_enabled = 'N' THEN
	_uq := array_append(_uq, 'is_enabled = false');
ELSE
	_uq := array_append(_uq, 'is_enabled = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.dns_record SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  dns_record_id = $1 RETURNING *'  USING OLD.dns_record_id
			INTO _nr;

		NEW.dns_record_id = _nr.dns_record_id;
		NEW.dns_name = _nr.dns_name;
		NEW.dns_domain_id = _nr.dns_domain_id;
		NEW.dns_ttl = _nr.dns_ttl;
		NEW.dns_class = _nr.dns_class;
		NEW.dns_type = _nr.dns_type;
		NEW.dns_value = _nr.dns_value;
		NEW.dns_priority = _nr.dns_priority;
		NEW.dns_srv_service = _nr.dns_srv_service;
		NEW.dns_srv_protocol = _nr.dns_srv_protocol;
		NEW.dns_srv_weight = _nr.dns_srv_weight;
		NEW.dns_srv_port = _nr.dns_srv_port;
		NEW.netblock_id = _nr.netblock_id;
		NEW.ip_universe_id = _nr.ip_universe_id;
		NEW.reference_dns_record_id = _nr.reference_dns_record_id;
		NEW.dns_value_record_id = _nr.dns_value_record_id;
		NEW.should_generate_ptr = CASE WHEN _nr.should_generate_ptr = true THEN 'Y' WHEN _nr.should_generate_ptr = false THEN 'N' ELSE NULL END;
		NEW.is_enabled = CASE WHEN _nr.is_enabled = true THEN 'Y' WHEN _nr.is_enabled = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_record_upd
	ON jazzhands_legacy.dns_record;
CREATE TRIGGER trigger_dns_record_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.dns_record
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.dns_record_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.dns_record_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.dns_record%rowtype;
BEGIN
	DELETE FROM jazzhands.dns_record
	WHERE  dns_record_id = OLD.dns_record_id  RETURNING *
	INTO _or;
	OLD.dns_record_id = _or.dns_record_id;
	OLD.dns_name = _or.dns_name;
	OLD.dns_domain_id = _or.dns_domain_id;
	OLD.dns_ttl = _or.dns_ttl;
	OLD.dns_class = _or.dns_class;
	OLD.dns_type = _or.dns_type;
	OLD.dns_value = _or.dns_value;
	OLD.dns_priority = _or.dns_priority;
	OLD.dns_srv_service = _or.dns_srv_service;
	OLD.dns_srv_protocol = _or.dns_srv_protocol;
	OLD.dns_srv_weight = _or.dns_srv_weight;
	OLD.dns_srv_port = _or.dns_srv_port;
	OLD.netblock_id = _or.netblock_id;
	OLD.ip_universe_id = _or.ip_universe_id;
	OLD.reference_dns_record_id = _or.reference_dns_record_id;
	OLD.dns_value_record_id = _or.dns_value_record_id;
	OLD.should_generate_ptr = CASE WHEN _or.should_generate_ptr = true THEN 'Y' WHEN _or.should_generate_ptr = false THEN 'N' ELSE NULL END;
	OLD.is_enabled = CASE WHEN _or.is_enabled = true THEN 'Y' WHEN _or.is_enabled = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_record_del
	ON jazzhands_legacy.dns_record;
CREATE TRIGGER trigger_dns_record_del
	INSTEAD OF DELETE ON jazzhands_legacy.dns_record
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.dns_record_del();


-- Triggers for ip_universe

CREATE OR REPLACE FUNCTION jazzhands_legacy.ip_universe_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.ip_universe%rowtype;
BEGIN

	IF NEW.ip_universe_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('ip_universe_id'));
		_vq := array_append(_vq, quote_nullable(NEW.ip_universe_id));
	END IF;

	IF NEW.ip_universe_name IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('ip_universe_name'));
		_vq := array_append(_vq, quote_nullable(NEW.ip_universe_name));
	END IF;

	IF NEW.ip_namespace IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('ip_namespace'));
		_vq := array_append(_vq, quote_nullable(NEW.ip_namespace));
	END IF;

	IF NEW.should_generate_dns IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('should_generate_dns'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.should_generate_dns = 'Y' THEN true WHEN NEW.should_generate_dns = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.ip_universe (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.ip_universe_id = _nr.ip_universe_id;
	NEW.ip_universe_name = _nr.ip_universe_name;
	NEW.ip_namespace = _nr.ip_namespace;
	NEW.should_generate_dns = CASE WHEN _nr.should_generate_dns = true THEN 'Y' WHEN _nr.should_generate_dns = false THEN 'N' ELSE NULL END;
	NEW.description = _nr.description;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_ip_universe_ins
	ON jazzhands_legacy.ip_universe;
CREATE TRIGGER trigger_ip_universe_ins
	INSTEAD OF INSERT ON jazzhands_legacy.ip_universe
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.ip_universe_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.ip_universe_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.ip_universe%rowtype;
	_nr	jazzhands.ip_universe%rowtype;
	_uq	text[];
BEGIN

	IF OLD.ip_universe_id IS DISTINCT FROM NEW.ip_universe_id THEN
_uq := array_append(_uq, 'ip_universe_id = ' || quote_nullable(NEW.ip_universe_id));
	END IF;

	IF OLD.ip_universe_name IS DISTINCT FROM NEW.ip_universe_name THEN
_uq := array_append(_uq, 'ip_universe_name = ' || quote_nullable(NEW.ip_universe_name));
	END IF;

	IF OLD.ip_namespace IS DISTINCT FROM NEW.ip_namespace THEN
_uq := array_append(_uq, 'ip_namespace = ' || quote_nullable(NEW.ip_namespace));
	END IF;

	IF OLD.should_generate_dns IS DISTINCT FROM NEW.should_generate_dns THEN
IF NEW.should_generate_dns = 'Y' THEN
	_uq := array_append(_uq, 'should_generate_dns = true');
ELSIF NEW.should_generate_dns = 'N' THEN
	_uq := array_append(_uq, 'should_generate_dns = false');
ELSE
	_uq := array_append(_uq, 'should_generate_dns = NULL');
END IF;
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.ip_universe SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  ip_universe_id = $1 RETURNING *'  USING OLD.ip_universe_id
			INTO _nr;

		NEW.ip_universe_id = _nr.ip_universe_id;
		NEW.ip_universe_name = _nr.ip_universe_name;
		NEW.ip_namespace = _nr.ip_namespace;
		NEW.should_generate_dns = CASE WHEN _nr.should_generate_dns = true THEN 'Y' WHEN _nr.should_generate_dns = false THEN 'N' ELSE NULL END;
		NEW.description = _nr.description;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_ip_universe_upd
	ON jazzhands_legacy.ip_universe;
CREATE TRIGGER trigger_ip_universe_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.ip_universe
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.ip_universe_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.ip_universe_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.ip_universe%rowtype;
BEGIN
	DELETE FROM jazzhands.ip_universe
	WHERE  ip_universe_id = OLD.ip_universe_id  RETURNING *
	INTO _or;
	OLD.ip_universe_id = _or.ip_universe_id;
	OLD.ip_universe_name = _or.ip_universe_name;
	OLD.ip_namespace = _or.ip_namespace;
	OLD.should_generate_dns = CASE WHEN _or.should_generate_dns = true THEN 'Y' WHEN _or.should_generate_dns = false THEN 'N' ELSE NULL END;
	OLD.description = _or.description;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_ip_universe_del
	ON jazzhands_legacy.ip_universe;
CREATE TRIGGER trigger_ip_universe_del
	INSTEAD OF DELETE ON jazzhands_legacy.ip_universe
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.ip_universe_del();


-- Triggers for ip_universe_visibility

CREATE OR REPLACE FUNCTION jazzhands_legacy.ip_universe_visibility_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.ip_universe_visibility%rowtype;
BEGIN

	IF NEW.ip_universe_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('ip_universe_id'));
		_vq := array_append(_vq, quote_nullable(NEW.ip_universe_id));
	END IF;

	IF NEW.visible_ip_universe_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('visible_ip_universe_id'));
		_vq := array_append(_vq, quote_nullable(NEW.visible_ip_universe_id));
	END IF;

	IF NEW.propagate_dns IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('propagate_dns'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.propagate_dns = 'Y' THEN true WHEN NEW.propagate_dns = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.ip_universe_visibility (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.ip_universe_id = _nr.ip_universe_id;
	NEW.visible_ip_universe_id = _nr.visible_ip_universe_id;
	NEW.propagate_dns = CASE WHEN _nr.propagate_dns = true THEN 'Y' WHEN _nr.propagate_dns = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_ip_universe_visibility_ins
	ON jazzhands_legacy.ip_universe_visibility;
CREATE TRIGGER trigger_ip_universe_visibility_ins
	INSTEAD OF INSERT ON jazzhands_legacy.ip_universe_visibility
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.ip_universe_visibility_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.ip_universe_visibility_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.ip_universe_visibility%rowtype;
	_nr	jazzhands.ip_universe_visibility%rowtype;
	_uq	text[];
BEGIN

	IF OLD.ip_universe_id IS DISTINCT FROM NEW.ip_universe_id THEN
_uq := array_append(_uq, 'ip_universe_id = ' || quote_nullable(NEW.ip_universe_id));
	END IF;

	IF OLD.visible_ip_universe_id IS DISTINCT FROM NEW.visible_ip_universe_id THEN
_uq := array_append(_uq, 'visible_ip_universe_id = ' || quote_nullable(NEW.visible_ip_universe_id));
	END IF;

	IF OLD.propagate_dns IS DISTINCT FROM NEW.propagate_dns THEN
IF NEW.propagate_dns = 'Y' THEN
	_uq := array_append(_uq, 'propagate_dns = true');
ELSIF NEW.propagate_dns = 'N' THEN
	_uq := array_append(_uq, 'propagate_dns = false');
ELSE
	_uq := array_append(_uq, 'propagate_dns = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.ip_universe_visibility SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  ip_universe_id = $1 AND  visible_ip_universe_id = $2 RETURNING *'  USING OLD.ip_universe_id, OLD.visible_ip_universe_id
			INTO _nr;

		NEW.ip_universe_id = _nr.ip_universe_id;
		NEW.visible_ip_universe_id = _nr.visible_ip_universe_id;
		NEW.propagate_dns = CASE WHEN _nr.propagate_dns = true THEN 'Y' WHEN _nr.propagate_dns = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_ip_universe_visibility_upd
	ON jazzhands_legacy.ip_universe_visibility;
CREATE TRIGGER trigger_ip_universe_visibility_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.ip_universe_visibility
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.ip_universe_visibility_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.ip_universe_visibility_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.ip_universe_visibility%rowtype;
BEGIN
	DELETE FROM jazzhands.ip_universe_visibility
	WHERE  ip_universe_id = OLD.ip_universe_id  AND  visible_ip_universe_id = OLD.visible_ip_universe_id  RETURNING *
	INTO _or;
	OLD.ip_universe_id = _or.ip_universe_id;
	OLD.visible_ip_universe_id = _or.visible_ip_universe_id;
	OLD.propagate_dns = CASE WHEN _or.propagate_dns = true THEN 'Y' WHEN _or.propagate_dns = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_ip_universe_visibility_del
	ON jazzhands_legacy.ip_universe_visibility;
CREATE TRIGGER trigger_ip_universe_visibility_del
	INSTEAD OF DELETE ON jazzhands_legacy.ip_universe_visibility
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.ip_universe_visibility_del();


-- Triggers for netblock

CREATE OR REPLACE FUNCTION jazzhands_legacy.netblock_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.netblock%rowtype;
BEGIN

	IF NEW.netblock_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('netblock_id'));
		_vq := array_append(_vq, quote_nullable(NEW.netblock_id));
	END IF;

	IF NEW.ip_address IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('ip_address'));
		_vq := array_append(_vq, quote_nullable(NEW.ip_address));
	END IF;

	IF NEW.netblock_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('netblock_type'));
		_vq := array_append(_vq, quote_nullable(NEW.netblock_type));
	END IF;

	IF NEW.is_single_address IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_single_address'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_single_address = 'Y' THEN true WHEN NEW.is_single_address = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.can_subnet IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('can_subnet'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.can_subnet = 'Y' THEN true WHEN NEW.can_subnet = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.parent_netblock_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('parent_netblock_id'));
		_vq := array_append(_vq, quote_nullable(NEW.parent_netblock_id));
	END IF;

	IF NEW.netblock_status IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('netblock_status'));
		_vq := array_append(_vq, quote_nullable(NEW.netblock_status));
	END IF;

	IF NEW.ip_universe_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('ip_universe_id'));
		_vq := array_append(_vq, quote_nullable(NEW.ip_universe_id));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.external_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('external_id'));
		_vq := array_append(_vq, quote_nullable(NEW.external_id));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.netblock (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.netblock_id = _nr.netblock_id;
	NEW.ip_address = _nr.ip_address;
	NEW.netblock_type = _nr.netblock_type;
	NEW.is_single_address = CASE WHEN _nr.is_single_address = true THEN 'Y' WHEN _nr.is_single_address = false THEN 'N' ELSE NULL END;
	NEW.can_subnet = CASE WHEN _nr.can_subnet = true THEN 'Y' WHEN _nr.can_subnet = false THEN 'N' ELSE NULL END;
	NEW.parent_netblock_id = _nr.parent_netblock_id;
	NEW.netblock_status = _nr.netblock_status;
	NEW.ip_universe_id = _nr.ip_universe_id;
	NEW.description = _nr.description;
	NEW.external_id = _nr.external_id;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_netblock_ins
	ON jazzhands_legacy.netblock;
CREATE TRIGGER trigger_netblock_ins
	INSTEAD OF INSERT ON jazzhands_legacy.netblock
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.netblock_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.netblock_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.netblock%rowtype;
	_nr	jazzhands.netblock%rowtype;
	_uq	text[];
BEGIN

	IF OLD.netblock_id IS DISTINCT FROM NEW.netblock_id THEN
_uq := array_append(_uq, 'netblock_id = ' || quote_nullable(NEW.netblock_id));
	END IF;

	IF OLD.ip_address IS DISTINCT FROM NEW.ip_address THEN
_uq := array_append(_uq, 'ip_address = ' || quote_nullable(NEW.ip_address));
	END IF;

	IF OLD.netblock_type IS DISTINCT FROM NEW.netblock_type THEN
_uq := array_append(_uq, 'netblock_type = ' || quote_nullable(NEW.netblock_type));
	END IF;

	IF OLD.is_single_address IS DISTINCT FROM NEW.is_single_address THEN
IF NEW.is_single_address = 'Y' THEN
	_uq := array_append(_uq, 'is_single_address = true');
ELSIF NEW.is_single_address = 'N' THEN
	_uq := array_append(_uq, 'is_single_address = false');
ELSE
	_uq := array_append(_uq, 'is_single_address = NULL');
END IF;
	END IF;

	IF OLD.can_subnet IS DISTINCT FROM NEW.can_subnet THEN
IF NEW.can_subnet = 'Y' THEN
	_uq := array_append(_uq, 'can_subnet = true');
ELSIF NEW.can_subnet = 'N' THEN
	_uq := array_append(_uq, 'can_subnet = false');
ELSE
	_uq := array_append(_uq, 'can_subnet = NULL');
END IF;
	END IF;

	IF OLD.parent_netblock_id IS DISTINCT FROM NEW.parent_netblock_id THEN
_uq := array_append(_uq, 'parent_netblock_id = ' || quote_nullable(NEW.parent_netblock_id));
	END IF;

	IF OLD.netblock_status IS DISTINCT FROM NEW.netblock_status THEN
_uq := array_append(_uq, 'netblock_status = ' || quote_nullable(NEW.netblock_status));
	END IF;

	IF OLD.ip_universe_id IS DISTINCT FROM NEW.ip_universe_id THEN
_uq := array_append(_uq, 'ip_universe_id = ' || quote_nullable(NEW.ip_universe_id));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.external_id IS DISTINCT FROM NEW.external_id THEN
_uq := array_append(_uq, 'external_id = ' || quote_nullable(NEW.external_id));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.netblock SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  netblock_id = $1 RETURNING *'  USING OLD.netblock_id
			INTO _nr;

		NEW.netblock_id = _nr.netblock_id;
		NEW.ip_address = _nr.ip_address;
		NEW.netblock_type = _nr.netblock_type;
		NEW.is_single_address = CASE WHEN _nr.is_single_address = true THEN 'Y' WHEN _nr.is_single_address = false THEN 'N' ELSE NULL END;
		NEW.can_subnet = CASE WHEN _nr.can_subnet = true THEN 'Y' WHEN _nr.can_subnet = false THEN 'N' ELSE NULL END;
		NEW.parent_netblock_id = _nr.parent_netblock_id;
		NEW.netblock_status = _nr.netblock_status;
		NEW.ip_universe_id = _nr.ip_universe_id;
		NEW.description = _nr.description;
		NEW.external_id = _nr.external_id;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_netblock_upd
	ON jazzhands_legacy.netblock;
CREATE TRIGGER trigger_netblock_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.netblock
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.netblock_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.netblock_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.netblock%rowtype;
BEGIN
	DELETE FROM jazzhands.netblock
	WHERE  netblock_id = OLD.netblock_id  RETURNING *
	INTO _or;
	OLD.netblock_id = _or.netblock_id;
	OLD.ip_address = _or.ip_address;
	OLD.netblock_type = _or.netblock_type;
	OLD.is_single_address = CASE WHEN _or.is_single_address = true THEN 'Y' WHEN _or.is_single_address = false THEN 'N' ELSE NULL END;
	OLD.can_subnet = CASE WHEN _or.can_subnet = true THEN 'Y' WHEN _or.can_subnet = false THEN 'N' ELSE NULL END;
	OLD.parent_netblock_id = _or.parent_netblock_id;
	OLD.netblock_status = _or.netblock_status;
	OLD.ip_universe_id = _or.ip_universe_id;
	OLD.description = _or.description;
	OLD.external_id = _or.external_id;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_netblock_del
	ON jazzhands_legacy.netblock;
CREATE TRIGGER trigger_netblock_del
	INSTEAD OF DELETE ON jazzhands_legacy.netblock
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.netblock_del();


-- Triggers for network_interface

CREATE OR REPLACE FUNCTION jazzhands_legacy.network_interface_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.layer3_interface%rowtype;
BEGIN
	IF NEW.network_interface_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('layer3_interface_id'));
		_vq := array_append(_vq, quote_nullable(NEW.network_interface_id));
	END IF;

	IF NEW.device_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('device_id'));
		_vq := array_append(_vq, quote_nullable(NEW.device_id));
	END IF;

	IF NEW.network_interface_name IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('layer3_interface_name'));
		_vq := array_append(_vq, quote_nullable(NEW.network_interface_name));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.parent_network_interface_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('parent_layer3_interface_id'));
		_vq := array_append(_vq, quote_nullable(NEW.parent_network_interface_id));
	END IF;

	IF NEW.parent_relation_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('parent_relation_type'));
		_vq := array_append(_vq, quote_nullable(NEW.parent_relation_type));
	END IF;

	IF NEW.physical_port_id IS NOT NULL THEN
		IF NEW.slot_id IS NOT NULL THEN
			RAISE EXCEPTION 'Only slot_id should be updated.'
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
		_cq := array_append(_cq, quote_ident('slot_id'));
		_vq := array_append(_vq, quote_nullable(NEW.physical_port_Id));
	END IF;

	IF NEW.slot_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('slot_id'));
		_vq := array_append(_vq, quote_nullable(NEW.slot_id));
	END IF;

	IF NEW.logical_port_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('logical_port_id'));
		_vq := array_append(_vq, quote_nullable(NEW.logical_port_id));
	END IF;

	IF NEW.network_interface_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('layer3_interface_type'));
		_vq := array_append(_vq, quote_nullable(NEW.network_interface_type));
	END IF;

	IF NEW.is_interface_up IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_interface_up'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_interface_up = 'Y' THEN true WHEN NEW.is_interface_up = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.mac_addr IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('mac_addr'));
		_vq := array_append(_vq, quote_nullable(NEW.mac_addr));
	END IF;

	IF NEW.should_monitor IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('should_monitor'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.should_monitor = 'Y' THEN true WHEN NEW.should_monitor = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.should_manage IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('should_manage'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.should_manage = 'Y' THEN true WHEN NEW.should_manage = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.layer3_interface (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.network_interface_id = _nr.layer3_interface_id;
	NEW.device_id = _nr.device_id;
	NEW.network_interface_name = _nr.layer3_interface_name;
	NEW.description = _nr.description;
	NEW.parent_network_interface_id = _nr.parent_layer3_interface_id;
	NEW.parent_relation_type = _nr.parent_relation_type;
	NEW.physical_port_id = _nr.slot_id;
	NEW.slot_id = _nr.slot_id;
	NEW.logical_port_id = _nr.logical_port_id;
	NEW.network_interface_type = _nr.layer3_interface_type;
	NEW.is_interface_up = CASE WHEN _nr.is_interface_up = true THEN 'Y' WHEN _nr.is_interface_up = false THEN 'N' ELSE NULL END;
	NEW.mac_addr = _nr.mac_addr;
	NEW.should_monitor = CASE WHEN _nr.should_monitor = true THEN 'Y' WHEN _nr.should_monitor = false THEN 'N' ELSE NULL END;
	NEW.should_manage = CASE WHEN _nr.should_manage = true THEN 'Y' WHEN _nr.should_manage = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_network_interface_ins
	ON jazzhands_legacy.network_interface;
CREATE TRIGGER trigger_network_interface_ins
	INSTEAD OF INSERT ON jazzhands_legacy.network_interface
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.network_interface_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.network_interface_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.network_interface%rowtype;
	_nr	jazzhands.layer3_interface%rowtype;
	_uq	text[];
BEGIN
	IF OLD.network_interface_id IS DISTINCT FROM NEW.network_interface_id THEN
_uq := array_append(_uq, 'layer3_interface_id = ' || quote_nullable(NEW.network_interface_id));
	END IF;

	IF OLD.device_id IS DISTINCT FROM NEW.device_id THEN
_uq := array_append(_uq, 'device_id = ' || quote_nullable(NEW.device_id));
	END IF;

	IF OLD.network_interface_name IS DISTINCT FROM NEW.network_interface_name THEN
_uq := array_append(_uq, 'layer3_interface_name = ' || quote_nullable(NEW.network_interface_name));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.parent_network_interface_id IS DISTINCT FROM NEW.parent_network_interface_id THEN
_uq := array_append(_uq, 'parent_layer3_interface_id = ' || quote_nullable(NEW.parent_network_interface_id));
	END IF;

	IF OLD.parent_relation_type IS DISTINCT FROM NEW.parent_relation_type THEN
_uq := array_append(_uq, 'parent_relation_type = ' || quote_nullable(NEW.parent_relation_type));
	END IF;

	IF OLD.physical_port_id IS DISTINCT FROM NEW.physical_port_id THEN
		IF OLD.slot_id IS DISTINCT FROM NEW.slot_id THEN
			RAISE EXCEPTION 'Only slot_id should be updated.'
			USING ERRCODE = 'integrity_constraint_violation';
		END IF;
_uq := array_append(_uq, 'slot_id = ' || quote_nullable(NEW.physical_port_id));
	END IF;

	IF OLD.slot_id IS DISTINCT FROM NEW.slot_id THEN
_uq := array_append(_uq, 'slot_id = ' || quote_nullable(NEW.slot_id));
	END IF;

	IF OLD.logical_port_id IS DISTINCT FROM NEW.logical_port_id THEN
_uq := array_append(_uq, 'logical_port_id = ' || quote_nullable(NEW.logical_port_id));
	END IF;

	IF OLD.network_interface_type IS DISTINCT FROM NEW.network_interface_type THEN
_uq := array_append(_uq, 'layer3_interface_type = ' || quote_nullable(NEW.network_interface_type));
	END IF;

	IF OLD.is_interface_up IS DISTINCT FROM NEW.is_interface_up THEN
IF NEW.is_interface_up = 'Y' THEN
	_uq := array_append(_uq, 'is_interface_up = true');
ELSIF NEW.is_interface_up = 'N' THEN
	_uq := array_append(_uq, 'is_interface_up = false');
ELSE
	_uq := array_append(_uq, 'is_interface_up = NULL');
END IF;
	END IF;

	IF OLD.mac_addr IS DISTINCT FROM NEW.mac_addr THEN
_uq := array_append(_uq, 'mac_addr = ' || quote_nullable(NEW.mac_addr));
	END IF;

	IF OLD.should_monitor IS DISTINCT FROM NEW.should_monitor THEN
IF NEW.should_monitor = 'Y' THEN
	_uq := array_append(_uq, 'should_monitor = true');
ELSIF NEW.should_monitor = 'N' THEN
	_uq := array_append(_uq, 'should_monitor = false');
ELSE
	_uq := array_append(_uq, 'should_monitor = NULL');
END IF;
	END IF;

	IF OLD.should_manage IS DISTINCT FROM NEW.should_manage THEN
IF NEW.should_manage = 'Y' THEN
	_uq := array_append(_uq, 'should_manage = true');
ELSIF NEW.should_manage = 'N' THEN
	_uq := array_append(_uq, 'should_manage = false');
ELSE
	_uq := array_append(_uq, 'should_manage = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.layer3_interface SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  layer3_interface_id = $1 RETURNING *'  USING OLD.network_interface_id
			INTO _nr;

		NEW.network_interface_id = _nr.layer3_interface_id;
		NEW.device_id = _nr.device_id;
		NEW.network_interface_name = _nr.layer3_interface_name;
		NEW.description = _nr.description;
		NEW.parent_network_interface_id = _nr.parent_layer3_interface_id;
		NEW.parent_relation_type = _nr.parent_relation_type;
		NEW.slot_id = _nr.slot_id;
		NEW.physical_port_id = _nr.slot_id;
		NEW.logical_port_id = _nr.logical_port_id;
		NEW.network_interface_type = _nr.layer3_interface_type;
		NEW.is_interface_up = CASE WHEN _nr.is_interface_up = true THEN 'Y' WHEN _nr.is_interface_up = false THEN 'N' ELSE NULL END;
		NEW.mac_addr = _nr.mac_addr;
		NEW.should_monitor = CASE WHEN _nr.should_monitor = true THEN 'Y' WHEN _nr.should_monitor = false THEN 'N' ELSE NULL END;
		NEW.should_manage = CASE WHEN _nr.should_manage = true THEN 'Y' WHEN _nr.should_manage = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_network_interface_upd
	ON jazzhands_legacy.network_interface;
CREATE TRIGGER trigger_network_interface_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.network_interface
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.network_interface_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.network_interface_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.layer3_interface%rowtype;
BEGIN
	DELETE FROM jazzhands.layer3_interface
	WHERE  layer3_interface_id = OLD.network_interface_id  RETURNING *
	INTO _or;
	OLD.network_interface_id = _or.layer3_interface_id;
	OLD.device_id = _or.device_id;
	OLD.network_interface_name = _or.layer3_interface_name;
	OLD.description = _or.description;
	OLD.parent_network_interface_id = _or.parent_layer3_interface_id;
	OLD.parent_relation_type = _or.parent_relation_type;
	OLD.physical_port_id = _or.slot_id;
	OLD.slot_id = _or.slot_id;
	OLD.logical_port_id = _or.logical_port_id;
	OLD.network_interface_type = _or.layer3_interface_type;
	OLD.is_interface_up = CASE WHEN _or.is_interface_up = true THEN 'Y' WHEN _or.is_interface_up = false THEN 'N' ELSE NULL END;
	OLD.mac_addr = _or.mac_addr;
	OLD.should_monitor = CASE WHEN _or.should_monitor = true THEN 'Y' WHEN _or.should_monitor = false THEN 'N' ELSE NULL END;
	OLD.should_manage = CASE WHEN _or.should_manage = true THEN 'Y' WHEN _or.should_manage = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_network_interface_del
	ON jazzhands_legacy.network_interface;
CREATE TRIGGER trigger_network_interface_del
	INSTEAD OF DELETE ON jazzhands_legacy.network_interface
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.network_interface_del();


-- Triggers for network_service

CREATE OR REPLACE FUNCTION jazzhands_legacy.network_service_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.network_service%rowtype;
BEGIN

	IF NEW.network_service_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('network_service_id'));
		_vq := array_append(_vq, quote_nullable(NEW.network_service_id));
	END IF;

	IF NEW.name IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('name'));
		_vq := array_append(_vq, quote_nullable(NEW.name));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.network_service_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('network_service_type'));
		_vq := array_append(_vq, quote_nullable(NEW.network_service_type));
	END IF;

	IF NEW.is_monitored IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_monitored'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_monitored = 'Y' THEN true WHEN NEW.is_monitored = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.device_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('device_id'));
		_vq := array_append(_vq, quote_nullable(NEW.device_id));
	END IF;

	IF NEW.network_interface_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('network_interface_id'));
		_vq := array_append(_vq, quote_nullable(NEW.network_interface_id));
	END IF;

	IF NEW.dns_record_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('dns_record_id'));
		_vq := array_append(_vq, quote_nullable(NEW.dns_record_id));
	END IF;

	IF NEW.service_environment_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('service_environment_id'));
		_vq := array_append(_vq, quote_nullable(NEW.service_environment_id));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.network_service (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.network_service_id = _nr.network_service_id;
	NEW.name = _nr.name;
	NEW.description = _nr.description;
	NEW.network_service_type = _nr.network_service_type;
	NEW.is_monitored = CASE WHEN _nr.is_monitored = true THEN 'Y' WHEN _nr.is_monitored = false THEN 'N' ELSE NULL END;
	NEW.device_id = _nr.device_id;
	NEW.network_interface_id = _nr.network_interface_id;
	NEW.dns_record_id = _nr.dns_record_id;
	NEW.service_environment_id = _nr.service_environment_id;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_network_service_ins
	ON jazzhands_legacy.network_service;
CREATE TRIGGER trigger_network_service_ins
	INSTEAD OF INSERT ON jazzhands_legacy.network_service
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.network_service_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.network_service_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.network_service%rowtype;
	_nr	jazzhands.network_service%rowtype;
	_uq	text[];
BEGIN

	IF OLD.network_service_id IS DISTINCT FROM NEW.network_service_id THEN
_uq := array_append(_uq, 'network_service_id = ' || quote_nullable(NEW.network_service_id));
	END IF;

	IF OLD.name IS DISTINCT FROM NEW.name THEN
_uq := array_append(_uq, 'name = ' || quote_nullable(NEW.name));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.network_service_type IS DISTINCT FROM NEW.network_service_type THEN
_uq := array_append(_uq, 'network_service_type = ' || quote_nullable(NEW.network_service_type));
	END IF;

	IF OLD.is_monitored IS DISTINCT FROM NEW.is_monitored THEN
IF NEW.is_monitored = 'Y' THEN
	_uq := array_append(_uq, 'is_monitored = true');
ELSIF NEW.is_monitored = 'N' THEN
	_uq := array_append(_uq, 'is_monitored = false');
ELSE
	_uq := array_append(_uq, 'is_monitored = NULL');
END IF;
	END IF;

	IF OLD.device_id IS DISTINCT FROM NEW.device_id THEN
_uq := array_append(_uq, 'device_id = ' || quote_nullable(NEW.device_id));
	END IF;

	IF OLD.network_interface_id IS DISTINCT FROM NEW.network_interface_id THEN
_uq := array_append(_uq, 'network_interface_id = ' || quote_nullable(NEW.network_interface_id));
	END IF;

	IF OLD.dns_record_id IS DISTINCT FROM NEW.dns_record_id THEN
_uq := array_append(_uq, 'dns_record_id = ' || quote_nullable(NEW.dns_record_id));
	END IF;

	IF OLD.service_environment_id IS DISTINCT FROM NEW.service_environment_id THEN
_uq := array_append(_uq, 'service_environment_id = ' || quote_nullable(NEW.service_environment_id));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.network_service SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  network_service_id = $1 RETURNING *'  USING OLD.network_service_id
			INTO _nr;

		NEW.network_service_id = _nr.network_service_id;
		NEW.name = _nr.name;
		NEW.description = _nr.description;
		NEW.network_service_type = _nr.network_service_type;
		NEW.is_monitored = CASE WHEN _nr.is_monitored = true THEN 'Y' WHEN _nr.is_monitored = false THEN 'N' ELSE NULL END;
		NEW.device_id = _nr.device_id;
		NEW.network_interface_id = _nr.network_interface_id;
		NEW.dns_record_id = _nr.dns_record_id;
		NEW.service_environment_id = _nr.service_environment_id;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_network_service_upd
	ON jazzhands_legacy.network_service;
CREATE TRIGGER trigger_network_service_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.network_service
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.network_service_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.network_service_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.network_service%rowtype;
BEGIN
	DELETE FROM jazzhands.network_service
	WHERE  network_service_id = OLD.network_service_id  RETURNING *
	INTO _or;
	OLD.network_service_id = _or.network_service_id;
	OLD.name = _or.name;
	OLD.description = _or.description;
	OLD.network_service_type = _or.network_service_type;
	OLD.is_monitored = CASE WHEN _or.is_monitored = true THEN 'Y' WHEN _or.is_monitored = false THEN 'N' ELSE NULL END;
	OLD.device_id = _or.device_id;
	OLD.network_interface_id = _or.network_interface_id;
	OLD.dns_record_id = _or.dns_record_id;
	OLD.service_environment_id = _or.service_environment_id;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_network_service_del
	ON jazzhands_legacy.network_service;
CREATE TRIGGER trigger_network_service_del
	INSTEAD OF DELETE ON jazzhands_legacy.network_service
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.network_service_del();


-- Triggers for operating_system

CREATE OR REPLACE FUNCTION jazzhands_legacy.operating_system_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.operating_system%rowtype;
BEGIN
	IF NEW.operating_system_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('operating_system_id'));
		_vq := array_append(_vq, quote_nullable(NEW.operating_system_id));
	END IF;

	IF NEW.operating_system_name IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('operating_system_name'));
		_vq := array_append(_vq, quote_nullable(NEW.operating_system_name));
	END IF;

	IF NEW.operating_system_short_name IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('operating_system_short_name'));
		_vq := array_append(_vq, quote_nullable(NEW.operating_system_short_name));
	END IF;

	IF NEW.company_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('company_id'));
		_vq := array_append(_vq, quote_nullable(NEW.company_id));
	END IF;

	IF NEW.major_version IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('major_version'));
		_vq := array_append(_vq, quote_nullable(NEW.major_version));
	END IF;

	IF NEW.version IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('version'));
		_vq := array_append(_vq, quote_nullable(NEW.version));
	END IF;

	IF NEW.operating_system_family IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('operating_system_family'));
		_vq := array_append(_vq, quote_nullable(NEW.operating_system_family));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.operating_system (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.operating_system_id = _nr.operating_system_id;
	NEW.operating_system_name = _nr.operating_system_name;
	NEW.operating_system_short_name = _nr.operating_system_short_name;
	NEW.company_id = _nr.company_id;
	NEW.major_version = _nr.major_version;
	NEW.version = _nr.version;
	NEW.operating_system_family = _nr.operating_system_family;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_operating_system_ins
	ON jazzhands_legacy.operating_system;
CREATE TRIGGER trigger_operating_system_ins
	INSTEAD OF INSERT ON jazzhands_legacy.operating_system
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.operating_system_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.operating_system_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.operating_system%rowtype;
	_nr	jazzhands.operating_system%rowtype;
	_uq	text[];
BEGIN
	IF OLD.operating_system_id IS DISTINCT FROM NEW.operating_system_id THEN
_uq := array_append(_uq, 'operating_system_id = ' || quote_nullable(NEW.operating_system_id));
	END IF;

	IF OLD.operating_system_name IS DISTINCT FROM NEW.operating_system_name THEN
_uq := array_append(_uq, 'operating_system_name = ' || quote_nullable(NEW.operating_system_name));
	END IF;

	IF OLD.operating_system_short_name IS DISTINCT FROM NEW.operating_system_short_name THEN
_uq := array_append(_uq, 'operating_system_short_name = ' || quote_nullable(NEW.operating_system_short_name));
	END IF;

	IF OLD.company_id IS DISTINCT FROM NEW.company_id THEN
_uq := array_append(_uq, 'company_id = ' || quote_nullable(NEW.company_id));
	END IF;

	IF OLD.major_version IS DISTINCT FROM NEW.major_version THEN
_uq := array_append(_uq, 'major_version = ' || quote_nullable(NEW.major_version));
	END IF;

	IF OLD.version IS DISTINCT FROM NEW.version THEN
_uq := array_append(_uq, 'version = ' || quote_nullable(NEW.version));
	END IF;

	IF OLD.operating_system_family IS DISTINCT FROM NEW.operating_system_family THEN
_uq := array_append(_uq, 'operating_system_family = ' || quote_nullable(NEW.operating_system_family));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.operating_system SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  operating_system_id = $1 RETURNING *'  USING OLD.operating_system_id
			INTO _nr;

		NEW.operating_system_id = _nr.operating_system_id;
		NEW.operating_system_name = _nr.operating_system_name;
		NEW.operating_system_short_name = _nr.operating_system_short_name;
		NEW.company_id = _nr.company_id;
		NEW.major_version = _nr.major_version;
		NEW.version = _nr.version;
		NEW.operating_system_family = _nr.operating_system_family;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_operating_system_upd
	ON jazzhands_legacy.operating_system;
CREATE TRIGGER trigger_operating_system_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.operating_system
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.operating_system_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.operating_system_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.operating_system%rowtype;
BEGIN
	DELETE FROM jazzhands.operating_system
	WHERE  operating_system_id = OLD.operating_system_id  RETURNING *
	INTO _or;
	OLD.operating_system_id = _or.operating_system_id;
	OLD.operating_system_name = _or.operating_system_name;
	OLD.operating_system_short_name = _or.operating_system_short_name;
	OLD.company_id = _or.company_id;
	OLD.major_version = _or.major_version;
	OLD.version = _or.version;
	OLD.operating_system_family = _or.operating_system_family;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_operating_system_del
	ON jazzhands_legacy.operating_system;
CREATE TRIGGER trigger_operating_system_del
	INSTEAD OF DELETE ON jazzhands_legacy.operating_system
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.operating_system_del();


-- Triggers for person

CREATE OR REPLACE FUNCTION jazzhands_legacy.person_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.person%rowtype;
BEGIN

	IF NEW.person_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('person_id'));
		_vq := array_append(_vq, quote_nullable(NEW.person_id));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.first_name IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('first_name'));
		_vq := array_append(_vq, quote_nullable(NEW.first_name));
	END IF;

	IF NEW.middle_name IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('middle_name'));
		_vq := array_append(_vq, quote_nullable(NEW.middle_name));
	END IF;

	IF NEW.last_name IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('last_name'));
		_vq := array_append(_vq, quote_nullable(NEW.last_name));
	END IF;

	IF NEW.name_suffix IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('name_suffix'));
		_vq := array_append(_vq, quote_nullable(NEW.name_suffix));
	END IF;

	IF NEW.gender IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('gender'));
		IF NEW.gender = 'M' THEN
			_vq := array_append(_vq, quote_nullable('male'));
		ELSIF NEW.gender = 'F' THEN
			_vq := array_append(_vq, quote_nullable('femaile'));
		ELSIF NEW.gender = 'U' THEN
			_vq := array_append(_vq, quote_nullable('unspecified'));
		ELSE
			RAISE EXCEPTION 'Invalid gender % in legacy views', NEW.gender
				USING errcode ='invalid_parameter_value';
		END IF;
	END IF;

	IF NEW.preferred_first_name IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('preferred_first_name'));
		_vq := array_append(_vq, quote_nullable(NEW.preferred_first_name));
	END IF;

	IF NEW.preferred_last_name IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('preferred_last_name'));
		_vq := array_append(_vq, quote_nullable(NEW.preferred_last_name));
	END IF;

	IF NEW.nickname IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('nickname'));
		_vq := array_append(_vq, quote_nullable(NEW.nickname));
	END IF;

	IF NEW.birth_date IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('birth_date'));
		_vq := array_append(_vq, quote_nullable(NEW.birth_date));
	END IF;

	IF NEW.diet IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('diet'));
		_vq := array_append(_vq, quote_nullable(NEW.diet));
	END IF;

	IF NEW.shirt_size IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('shirt_size'));
		_vq := array_append(_vq, quote_nullable(NEW.shirt_size));
	END IF;

	IF NEW.pant_size IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('pant_size'));
		_vq := array_append(_vq, quote_nullable(NEW.pant_size));
	END IF;

	IF NEW.hat_size IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('hat_size'));
		_vq := array_append(_vq, quote_nullable(NEW.hat_size));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.person (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.person_id = _nr.person_id;
	NEW.description = _nr.description;
	NEW.first_name = _nr.first_name;
	NEW.middle_name = _nr.middle_name;
	NEW.last_name = _nr.last_name;
	NEW.name_suffix = _nr.name_suffix;
	NEW.gender = CASE WHEN _nr.gender = 'male' THEN 'M'
		WHEN _nr.gender = 'female' THEN 'F'
		ELSE 'U' END;
	NEW.preferred_first_name = _nr.preferred_first_name;
	NEW.preferred_last_name = _nr.preferred_last_name;
	NEW.nickname = _nr.nickname;
	NEW.birth_date = _nr.birth_date;
	NEW.diet = _nr.diet;
	NEW.shirt_size = _nr.shirt_size;
	NEW.pant_size = _nr.pant_size;
	NEW.hat_size = _nr.hat_size;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_person_ins
	ON jazzhands_legacy.person;
CREATE TRIGGER trigger_person_ins
	INSTEAD OF INSERT ON jazzhands_legacy.person
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.person_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.person_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.person%rowtype;
	_nr	jazzhands.person%rowtype;
	_uq	text[];
BEGIN

	IF OLD.person_id IS DISTINCT FROM NEW.person_id THEN
_uq := array_append(_uq, 'person_id = ' || quote_nullable(NEW.person_id));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.first_name IS DISTINCT FROM NEW.first_name THEN
_uq := array_append(_uq, 'first_name = ' || quote_nullable(NEW.first_name));
	END IF;

	IF OLD.middle_name IS DISTINCT FROM NEW.middle_name THEN
_uq := array_append(_uq, 'middle_name = ' || quote_nullable(NEW.middle_name));
	END IF;

	IF OLD.last_name IS DISTINCT FROM NEW.last_name THEN
_uq := array_append(_uq, 'last_name = ' || quote_nullable(NEW.last_name));
	END IF;

	IF OLD.name_suffix IS DISTINCT FROM NEW.name_suffix THEN
_uq := array_append(_uq, 'name_suffix = ' || quote_nullable(NEW.name_suffix));
	END IF;

	IF OLD.gender IS DISTINCT FROM NEW.gender THEN
		IF NEW.gender = 'M' THEN
			_uq := array_append(_uq, 'gender = ' || quote_nullable('male'));
		ELSIF NEW.gender = 'F' THEN
			_uq := array_append(_uq, 'gender = ' || quote_nullable('female'));
		ELSIF NEW.gender = 'U' THEN
			_uq := array_append(_uq, 'gender = ' || quote_nullable('unspecified'));
		ELSE
			RAISE EXCEPTION 'Invalid gender % in legacy views', NEW.gender
				USING errcode ='invalid_parameter_value';
		END IF;
	END IF;

	IF OLD.preferred_first_name IS DISTINCT FROM NEW.preferred_first_name THEN
_uq := array_append(_uq, 'preferred_first_name = ' || quote_nullable(NEW.preferred_first_name));
	END IF;

	IF OLD.preferred_last_name IS DISTINCT FROM NEW.preferred_last_name THEN
_uq := array_append(_uq, 'preferred_last_name = ' || quote_nullable(NEW.preferred_last_name));
	END IF;

	IF OLD.nickname IS DISTINCT FROM NEW.nickname THEN
_uq := array_append(_uq, 'nickname = ' || quote_nullable(NEW.nickname));
	END IF;

	IF OLD.birth_date IS DISTINCT FROM NEW.birth_date THEN
_uq := array_append(_uq, 'birth_date = ' || quote_nullable(NEW.birth_date));
	END IF;

	IF OLD.diet IS DISTINCT FROM NEW.diet THEN
_uq := array_append(_uq, 'diet = ' || quote_nullable(NEW.diet));
	END IF;

	IF OLD.shirt_size IS DISTINCT FROM NEW.shirt_size THEN
_uq := array_append(_uq, 'shirt_size = ' || quote_nullable(NEW.shirt_size));
	END IF;

	IF OLD.pant_size IS DISTINCT FROM NEW.pant_size THEN
_uq := array_append(_uq, 'pant_size = ' || quote_nullable(NEW.pant_size));
	END IF;

	IF OLD.hat_size IS DISTINCT FROM NEW.hat_size THEN
_uq := array_append(_uq, 'hat_size = ' || quote_nullable(NEW.hat_size));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.person SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  person_id = $1 RETURNING *'  USING OLD.person_id
			INTO _nr;

		NEW.person_id = _nr.person_id;
		NEW.description = _nr.description;
		NEW.first_name = _nr.first_name;
		NEW.middle_name = _nr.middle_name;
		NEW.last_name = _nr.last_name;
		NEW.name_suffix = _nr.name_suffix;
		NEW.gender = CASE WHEN _nr.gender = 'male' THEN 'M'
			WHEN _nr.gender = 'female' THEN 'F'
			ELSE 'U' END;
		NEW.preferred_first_name = _nr.preferred_first_name;
		NEW.preferred_last_name = _nr.preferred_last_name;
		NEW.nickname = _nr.nickname;
		NEW.birth_date = _nr.birth_date;
		NEW.diet = _nr.diet;
		NEW.shirt_size = _nr.shirt_size;
		NEW.pant_size = _nr.pant_size;
		NEW.hat_size = _nr.hat_size;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_person_upd
	ON jazzhands_legacy.person;
CREATE TRIGGER trigger_person_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.person
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.person_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.person_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.person%rowtype;
BEGIN
	DELETE FROM jazzhands.person
	WHERE  person_id = OLD.person_id  RETURNING *
	INTO _or;
	OLD.person_id = _or.person_id;
	OLD.description = _or.description;
	OLD.first_name = _or.first_name;
	OLD.middle_name = _or.middle_name;
	OLD.last_name = _or.last_name;
	OLD.name_suffix = _or.name_suffix;
	OLD.gender = CASE WHEN _or.gender = 'male' THEN 'M'
		WHEN _or.gender = 'female' THEN 'F'
		ELSE 'U' END;
	OLD.preferred_first_name = _or.preferred_first_name;
	OLD.preferred_last_name = _or.preferred_last_name;
	OLD.nickname = _or.nickname;
	OLD.birth_date = _or.birth_date;
	OLD.diet = _or.diet;
	OLD.shirt_size = _or.shirt_size;
	OLD.pant_size = _or.pant_size;
	OLD.hat_size = _or.hat_size;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_person_del
	ON jazzhands_legacy.person;
CREATE TRIGGER trigger_person_del
	INSTEAD OF DELETE ON jazzhands_legacy.person
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.person_del();


-- Triggers for person_auth_question

CREATE OR REPLACE FUNCTION jazzhands_legacy.person_auth_question_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.person_authentication_question%rowtype;
BEGIN

	IF NEW.auth_question_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('authentication_question_id'));
		_vq := array_append(_vq, quote_nullable(NEW.auth_question_id));
	END IF;

	IF NEW.person_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('person_id'));
		_vq := array_append(_vq, quote_nullable(NEW.person_id));
	END IF;

	IF NEW.user_answer IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('user_answer'));
		_vq := array_append(_vq, quote_nullable(NEW.user_answer));
	END IF;

	IF NEW.is_active IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_active'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_active = 'Y' THEN true WHEN NEW.is_active = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.person_authentication_question (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.auth_question_id = _nr.authentication_question_id;
	NEW.person_id = _nr.person_id;
	NEW.user_answer = _nr.user_answer;
	NEW.is_active = CASE WHEN _nr.is_active = true THEN 'Y' WHEN _nr.is_active = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_person_auth_question_ins
	ON jazzhands_legacy.person_auth_question;
CREATE TRIGGER trigger_person_auth_question_ins
	INSTEAD OF INSERT ON jazzhands_legacy.person_auth_question
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.person_auth_question_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.person_auth_question_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.person_auth_question%rowtype;
	_nr	jazzhands.person_authentication_question%rowtype;
	_uq	text[];
BEGIN

	IF OLD.auth_question_id IS DISTINCT FROM NEW.auth_question_id THEN
_uq := array_append(_uq, 'authentication_question_id = ' || quote_nullable(NEW.auth_question_id));
	END IF;

	IF OLD.person_id IS DISTINCT FROM NEW.person_id THEN
_uq := array_append(_uq, 'person_id = ' || quote_nullable(NEW.person_id));
	END IF;

	IF OLD.user_answer IS DISTINCT FROM NEW.user_answer THEN
_uq := array_append(_uq, 'user_answer = ' || quote_nullable(NEW.user_answer));
	END IF;

	IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
IF NEW.is_active = 'Y' THEN
	_uq := array_append(_uq, 'is_active = true');
ELSIF NEW.is_active = 'N' THEN
	_uq := array_append(_uq, 'is_active = false');
ELSE
	_uq := array_append(_uq, 'is_active = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.person_authentication_question SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  authentication_question_id = $1 AND  person_id = $2 RETURNING *'
			USING OLD.auth_question_id, OLD.person_id
			INTO _nr;

		NEW.auth_question_id = _nr.authentication_question_id;
		NEW.person_id = _nr.person_id;
		NEW.user_answer = _nr.user_answer;
		NEW.is_active = CASE WHEN _nr.is_active = true THEN 'Y' WHEN _nr.is_active = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_person_auth_question_upd
	ON jazzhands_legacy.person_auth_question;
CREATE TRIGGER trigger_person_auth_question_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.person_auth_question
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.person_auth_question_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.person_auth_question_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.person_authentication_question%rowtype;
BEGIN
	DELETE FROM jazzhands.person_authentication_question
	WHERE  authentication_question_id = OLD.auth_question_id  AND  person_id = OLD.person_id  RETURNING *
	INTO _or;
	OLD.auth_question_id = _or.authentication_question_id;
	OLD.person_id = _or.person_id;
	OLD.user_answer = _or.user_answer;
	OLD.is_active = CASE WHEN _or.is_active = true THEN 'Y' WHEN _or.is_active = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_person_auth_question_del
	ON jazzhands_legacy.person_auth_question;
CREATE TRIGGER trigger_person_auth_question_del
	INSTEAD OF DELETE ON jazzhands_legacy.person_auth_question
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.person_auth_question_del();


-- Triggers for person_company

CREATE OR REPLACE FUNCTION jazzhands_legacy.person_company_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.person_company%rowtype;
BEGIN

	IF NEW.company_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('company_id'));
		_vq := array_append(_vq, quote_nullable(NEW.company_id));
	END IF;

	IF NEW.person_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('person_id'));
		_vq := array_append(_vq, quote_nullable(NEW.person_id));
	END IF;

	IF NEW.person_company_status IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('person_company_status'));
		_vq := array_append(_vq, quote_nullable(NEW.person_company_status));
	END IF;

	IF NEW.person_company_relation IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('person_company_relation'));
		_vq := array_append(_vq, quote_nullable(NEW.person_company_relation));
	END IF;

	IF NEW.is_exempt IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_exempt'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_exempt = 'Y' THEN true WHEN NEW.is_exempt = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.is_management IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_management'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_management = 'Y' THEN true WHEN NEW.is_management = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.is_full_time IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_full_time'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_full_time = 'Y' THEN true WHEN NEW.is_full_time = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.position_title IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('position_title'));
		_vq := array_append(_vq, quote_nullable(NEW.position_title));
	END IF;

	IF NEW.hire_date IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('hire_date'));
		_vq := array_append(_vq, quote_nullable(NEW.hire_date));
	END IF;

	IF NEW.termination_date IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('termination_date'));
		_vq := array_append(_vq, quote_nullable(NEW.termination_date));
	END IF;

	IF NEW.manager_person_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('manager_person_id'));
		_vq := array_append(_vq, quote_nullable(NEW.manager_person_id));
	END IF;

	IF NEW.nickname IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('nickname'));
		_vq := array_append(_vq, quote_nullable(NEW.nickname));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.person_company (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.company_id = _nr.company_id;
	NEW.person_id = _nr.person_id;
	NEW.person_company_status = _nr.person_company_status;
	NEW.person_company_relation = _nr.person_company_relation;
	NEW.is_exempt = CASE WHEN _nr.is_exempt = true THEN 'Y' WHEN _nr.is_exempt = false THEN 'N' ELSE NULL END;
	NEW.is_management = CASE WHEN _nr.is_management = true THEN 'Y' WHEN _nr.is_management = false THEN 'N' ELSE NULL END;
	NEW.is_full_time = CASE WHEN _nr.is_full_time = true THEN 'Y' WHEN _nr.is_full_time = false THEN 'N' ELSE NULL END;
	NEW.description = _nr.description;
	NEW.position_title = _nr.position_title;
	NEW.hire_date = _nr.hire_date;
	NEW.termination_date = _nr.termination_date;
	NEW.manager_person_id = _nr.manager_person_id;
	NEW.nickname = _nr.nickname;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_person_company_ins
	ON jazzhands_legacy.person_company;
CREATE TRIGGER trigger_person_company_ins
	INSTEAD OF INSERT ON jazzhands_legacy.person_company
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.person_company_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.person_company_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.person_company%rowtype;
	_nr	jazzhands.person_company%rowtype;
	_uq	text[];
BEGIN

	IF OLD.company_id IS DISTINCT FROM NEW.company_id THEN
_uq := array_append(_uq, 'company_id = ' || quote_nullable(NEW.company_id));
	END IF;

	IF OLD.person_id IS DISTINCT FROM NEW.person_id THEN
_uq := array_append(_uq, 'person_id = ' || quote_nullable(NEW.person_id));
	END IF;

	IF OLD.person_company_status IS DISTINCT FROM NEW.person_company_status THEN
_uq := array_append(_uq, 'person_company_status = ' || quote_nullable(NEW.person_company_status));
	END IF;

	IF OLD.person_company_relation IS DISTINCT FROM NEW.person_company_relation THEN
_uq := array_append(_uq, 'person_company_relation = ' || quote_nullable(NEW.person_company_relation));
	END IF;

	IF OLD.is_exempt IS DISTINCT FROM NEW.is_exempt THEN
IF NEW.is_exempt = 'Y' THEN
	_uq := array_append(_uq, 'is_exempt = true');
ELSIF NEW.is_exempt = 'N' THEN
	_uq := array_append(_uq, 'is_exempt = false');
ELSE
	_uq := array_append(_uq, 'is_exempt = NULL');
END IF;
	END IF;

	IF OLD.is_management IS DISTINCT FROM NEW.is_management THEN
IF NEW.is_management = 'Y' THEN
	_uq := array_append(_uq, 'is_management = true');
ELSIF NEW.is_management = 'N' THEN
	_uq := array_append(_uq, 'is_management = false');
ELSE
	_uq := array_append(_uq, 'is_management = NULL');
END IF;
	END IF;

	IF OLD.is_full_time IS DISTINCT FROM NEW.is_full_time THEN
IF NEW.is_full_time = 'Y' THEN
	_uq := array_append(_uq, 'is_full_time = true');
ELSIF NEW.is_full_time = 'N' THEN
	_uq := array_append(_uq, 'is_full_time = false');
ELSE
	_uq := array_append(_uq, 'is_full_time = NULL');
END IF;
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.position_title IS DISTINCT FROM NEW.position_title THEN
_uq := array_append(_uq, 'position_title = ' || quote_nullable(NEW.position_title));
	END IF;

	IF OLD.hire_date IS DISTINCT FROM NEW.hire_date THEN
_uq := array_append(_uq, 'hire_date = ' || quote_nullable(NEW.hire_date));
	END IF;

	IF OLD.termination_date IS DISTINCT FROM NEW.termination_date THEN
_uq := array_append(_uq, 'termination_date = ' || quote_nullable(NEW.termination_date));
	END IF;

	IF OLD.manager_person_id IS DISTINCT FROM NEW.manager_person_id THEN
_uq := array_append(_uq, 'manager_person_id = ' || quote_nullable(NEW.manager_person_id));
	END IF;

	IF OLD.nickname IS DISTINCT FROM NEW.nickname THEN
_uq := array_append(_uq, 'nickname = ' || quote_nullable(NEW.nickname));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.person_company SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  company_id = $1 AND  person_id = $2 RETURNING *'  USING OLD.company_id, OLD.person_id
			INTO _nr;

		NEW.company_id = _nr.company_id;
		NEW.person_id = _nr.person_id;
		NEW.person_company_status = _nr.person_company_status;
		NEW.person_company_relation = _nr.person_company_relation;
		NEW.is_exempt = CASE WHEN _nr.is_exempt = true THEN 'Y' WHEN _nr.is_exempt = false THEN 'N' ELSE NULL END;
		NEW.is_management = CASE WHEN _nr.is_management = true THEN 'Y' WHEN _nr.is_management = false THEN 'N' ELSE NULL END;
		NEW.is_full_time = CASE WHEN _nr.is_full_time = true THEN 'Y' WHEN _nr.is_full_time = false THEN 'N' ELSE NULL END;
		NEW.description = _nr.description;
		NEW.position_title = _nr.position_title;
		NEW.hire_date = _nr.hire_date;
		NEW.termination_date = _nr.termination_date;
		NEW.manager_person_id = _nr.manager_person_id;
		NEW.nickname = _nr.nickname;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_person_company_upd
	ON jazzhands_legacy.person_company;
CREATE TRIGGER trigger_person_company_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.person_company
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.person_company_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.person_company_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.person_company%rowtype;
BEGIN
	DELETE FROM jazzhands.person_company
	WHERE  company_id = OLD.company_id  AND  person_id = OLD.person_id  RETURNING *
	INTO _or;
	OLD.company_id = _or.company_id;
	OLD.person_id = _or.person_id;
	OLD.person_company_status = _or.person_company_status;
	OLD.person_company_relation = _or.person_company_relation;
	OLD.is_exempt = CASE WHEN _or.is_exempt = true THEN 'Y' WHEN _or.is_exempt = false THEN 'N' ELSE NULL END;
	OLD.is_management = CASE WHEN _or.is_management = true THEN 'Y' WHEN _or.is_management = false THEN 'N' ELSE NULL END;
	OLD.is_full_time = CASE WHEN _or.is_full_time = true THEN 'Y' WHEN _or.is_full_time = false THEN 'N' ELSE NULL END;
	OLD.description = _or.description;
	OLD.position_title = _or.position_title;
	OLD.hire_date = _or.hire_date;
	OLD.termination_date = _or.termination_date;
	OLD.manager_person_id = _or.manager_person_id;
	OLD.nickname = _or.nickname;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_person_company_del
	ON jazzhands_legacy.person_company;
CREATE TRIGGER trigger_person_company_del
	INSTEAD OF DELETE ON jazzhands_legacy.person_company
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.person_company_del();


-- Triggers for physical_connection

CREATE OR REPLACE FUNCTION jazzhands_legacy.physical_connection_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.physical_connection%rowtype;
BEGIN
	IF NEW.physical_connection_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('physical_connection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.physical_connection_id));
	END IF;

	IF NEW.physical_port1_id IS NOT NULL THEN
		IF NEW.slot1_id IS NOT NULL  THEN
			RAISE EXCEPTION 'Only slot1_id OR slot2_id should be updated.'
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
		_cq := array_append(_cq, quote_ident('slot1_id'));
		_vq := array_append(_vq, quote_nullable(NEW.physical_port1_id));
	END IF;

	IF NEW.physical_port2_id IS NOT NULL THEN
		IF NEW.slot2_id IS NOT NULL  THEN
			RAISE EXCEPTION 'Only slot1_id OR slot2_id should be updated.'
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
		_cq := array_append(_cq, quote_ident('slot2_id'));
		_vq := array_append(_vq, quote_nullable(NEW.physical_port2_id));
	END IF;

	IF NEW.slot1_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('slot1_id'));
		_vq := array_append(_vq, quote_nullable(NEW.slot1_id));
	END IF;

	IF NEW.slot2_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('slot2_id'));
		_vq := array_append(_vq, quote_nullable(NEW.slot2_id));
	END IF;

	IF NEW.cable_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('cable_type'));
		_vq := array_append(_vq, quote_nullable(NEW.cable_type));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.physical_connection (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.physical_connection_id = _nr.physical_connection_id;
	NEW.physical_port1_id = _nr.slot1_id;
	NEW.physical_port2_id = _nr.slot2_id;
	NEW.slot1_id = _nr.slot1_id;
	NEW.slot2_id = _nr.slot2_id;
	NEW.cable_type = _nr.cable_type;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_physical_connection_ins
	ON jazzhands_legacy.physical_connection;
CREATE TRIGGER trigger_physical_connection_ins
	INSTEAD OF INSERT ON jazzhands_legacy.physical_connection
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.physical_connection_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.physical_connection_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.physical_connection%rowtype;
	_nr	jazzhands.physical_connection%rowtype;
	_uq	text[];
BEGIN
	IF OLD.physical_connection_id IS DISTINCT FROM NEW.physical_connection_id THEN
_uq := array_append(_uq, 'physical_connection_id = ' || quote_nullable(NEW.physical_connection_id));
	END IF;

	IF OLD.physical_port1_id IS DISTINCT FROM NEW.physical_port1_id THEN
		IF OLD.slot1_id IS DISTINCT FROM NEW.slot1_id THEN
			RAISE EXCEPTION 'Only slot1_id OR slot2_id should be updated.'
			USING ERRCODE = 'integrity_constraint_violation';
		END IF;
_uq := array_append(_uq, 'slot1_id = ' || quote_nullable(NEW.physical_port1_id));
	END IF;

	IF OLD.physical_port2_id IS DISTINCT FROM NEW.physical_port2_id THEN
		IF OLD.slot2_id IS DISTINCT FROM NEW.slot2_id THEN
			RAISE EXCEPTION 'Only slot1_id OR slot2_id should be updated.'
			USING ERRCODE = 'integrity_constraint_violation';
		END IF;
_uq := array_append(_uq, 'slot2_id = ' || quote_nullable(NEW.physical_port2_id));
	END IF;

	IF OLD.slot1_id IS DISTINCT FROM NEW.slot1_id THEN
_uq := array_append(_uq, 'slot1_id = ' || quote_nullable(NEW.slot1_id));
	END IF;

	IF OLD.slot2_id IS DISTINCT FROM NEW.slot2_id THEN
_uq := array_append(_uq, 'slot2_id = ' || quote_nullable(NEW.slot2_id));
	END IF;

	IF OLD.cable_type IS DISTINCT FROM NEW.cable_type THEN
_uq := array_append(_uq, 'cable_type = ' || quote_nullable(NEW.cable_type));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.physical_connection SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  physical_connection_id = $1 RETURNING *'  USING OLD.physical_connection_id
			INTO _nr;

		NEW.physical_connection_id = _nr.physical_connection_id;
		NEW.physical_port1_id = _nr.slot1_id;
		NEW.physical_port2_id = _nr.slot2_id;
		NEW.slot1_id = _nr.slot1_id;
		NEW.slot2_id = _nr.slot2_id;
		NEW.cable_type = _nr.cable_type;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_physical_connection_upd
	ON jazzhands_legacy.physical_connection;
CREATE TRIGGER trigger_physical_connection_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.physical_connection
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.physical_connection_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.physical_connection_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.physical_connection%rowtype;
BEGIN
	DELETE FROM jazzhands.physical_connection
	WHERE  physical_connection_id = OLD.physical_connection_id  RETURNING *
	INTO _or;
	OLD.physical_connection_id = _or.physical_connection_id;
	OLD.physical_port1_id = _or.slot1_id;
	OLD.physical_port2_id = _or.slot2_id;
	OLD.slot1_id = _or.slot1_id;
	OLD.slot2_id = _or.slot2_id;
	OLD.cable_type = _or.cable_type;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_physical_connection_del
	ON jazzhands_legacy.physical_connection;
CREATE TRIGGER trigger_physical_connection_del
	INSTEAD OF DELETE ON jazzhands_legacy.physical_connection
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.physical_connection_del();


-- Triggers for private_key

CREATE OR REPLACE FUNCTION jazzhands_legacy.private_key_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.private_key%rowtype;
BEGIN

	IF NEW.private_key_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('private_key_id'));
		_vq := array_append(_vq, quote_nullable(NEW.private_key_id));
	END IF;

	IF NEW.private_key_encryption_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('private_key_encryption_type'));
		_vq := array_append(_vq, quote_nullable(NEW.private_key_encryption_type));
	END IF;

	IF NEW.is_active IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_active'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_active = 'Y' THEN true WHEN NEW.is_active = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.subject_key_identifier IS NOT NULL THEN
		RAISE EXCEPTION 'subject_key_identifier has been deprecated and can not be set'
			USING ERRCODE = invalid_parameter_value;
	END IF;

	IF NEW.private_key IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('private_key'));
		_vq := array_append(_vq, quote_nullable(NEW.private_key));
	END IF;

	IF NEW.passphrase IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('passphrase'));
		_vq := array_append(_vq, quote_nullable(NEW.passphrase));
	END IF;

	IF NEW.encryption_key_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('encryption_key_id'));
		_vq := array_append(_vq, quote_nullable(NEW.encryption_key_id));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.private_key (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.private_key_id = _nr.private_key_id;
	NEW.private_key_encryption_type = _nr.private_key_encryption_type;
	NEW.is_active = CASE WHEN _nr.is_active = true THEN 'Y' WHEN _nr.is_active = false THEN 'N' ELSE NULL END;
	NEW.subject_key_identifier = NULL;
	NEW.private_key = _nr.private_key;
	NEW.passphrase = _nr.passphrase;
	NEW.encryption_key_id = _nr.encryption_key_id;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_private_key_ins
	ON jazzhands_legacy.private_key;
CREATE TRIGGER trigger_private_key_ins
	INSTEAD OF INSERT ON jazzhands_legacy.private_key
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.private_key_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.private_key_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.private_key%rowtype;
	_nr	jazzhands.private_key%rowtype;
	_uq	text[];
BEGIN

	IF OLD.private_key_id IS DISTINCT FROM NEW.private_key_id THEN
_uq := array_append(_uq, 'private_key_id = ' || quote_nullable(NEW.private_key_id));
	END IF;

	IF OLD.private_key_encryption_type IS DISTINCT FROM NEW.private_key_encryption_type THEN
_uq := array_append(_uq, 'private_key_encryption_type = ' || quote_nullable(NEW.private_key_encryption_type));
	END IF;

	IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
IF NEW.is_active = 'Y' THEN
	_uq := array_append(_uq, 'is_active = true');
ELSIF NEW.is_active = 'N' THEN
	_uq := array_append(_uq, 'is_active = false');
ELSE
	_uq := array_append(_uq, 'is_active = NULL');
END IF;
	END IF;

	IF OLD.subject_key_identifier IS DISTINCT FROM NEW.subject_key_identifier THEN
		IF NEW.subject_key_identifier IS NOT NULL THEN
			RAISE EXCEPTION 'subject_key_identifier has been deprecated and can not be set'
				USING ERRCODE = invalid_parameter_value;
		END IF;
	END IF;

	IF OLD.private_key IS DISTINCT FROM NEW.private_key THEN
_uq := array_append(_uq, 'private_key = ' || quote_nullable(NEW.private_key));
	END IF;

	IF OLD.passphrase IS DISTINCT FROM NEW.passphrase THEN
_uq := array_append(_uq, 'passphrase = ' || quote_nullable(NEW.passphrase));
	END IF;

	IF OLD.encryption_key_id IS DISTINCT FROM NEW.encryption_key_id THEN
_uq := array_append(_uq, 'encryption_key_id = ' || quote_nullable(NEW.encryption_key_id));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.private_key SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  private_key_id = $1 RETURNING *'  USING OLD.private_key_id
			INTO _nr;

		NEW.private_key_id = _nr.private_key_id;
		NEW.private_key_encryption_type = _nr.private_key_encryption_type;
		NEW.is_active = CASE WHEN _nr.is_active = true THEN 'Y' WHEN _nr.is_active = false THEN 'N' ELSE NULL END;
		NEW.subject_key_identifier = NULL;
		NEW.private_key = _nr.private_key;
		NEW.passphrase = _nr.passphrase;
		NEW.encryption_key_id = _nr.encryption_key_id;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_private_key_upd
	ON jazzhands_legacy.private_key;
CREATE TRIGGER trigger_private_key_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.private_key
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.private_key_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.private_key_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.private_key%rowtype;
BEGIN
	DELETE FROM jazzhands.private_key
	WHERE  private_key_id = OLD.private_key_id  RETURNING *
	INTO _or;
	OLD.private_key_id = _or.private_key_id;
	OLD.private_key_encryption_type = _or.private_key_encryption_type;
	OLD.is_active = CASE WHEN _or.is_active = true THEN 'Y' WHEN _or.is_active = false THEN 'N' ELSE NULL END;
	OLD.subject_key_identifier = NULL;
	OLD.private_key = _or.private_key;
	OLD.passphrase = _or.passphrase;
	OLD.encryption_key_id = _or.encryption_key_id;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_private_key_del
	ON jazzhands_legacy.private_key;
CREATE TRIGGER trigger_private_key_del
	INSTEAD OF DELETE ON jazzhands_legacy.private_key
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.private_key_del();


-- Triggers for property

CREATE OR REPLACE FUNCTION jazzhands_legacy.property_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.property%rowtype;
	_dt	TEXT;
BEGIN

	IF NEW.property_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('property_id'));
		_vq := array_append(_vq, quote_nullable(NEW.property_id));
	END IF;

	IF NEW.account_collection_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('account_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.account_collection_id));
	END IF;

	IF NEW.account_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('account_id'));
		_vq := array_append(_vq, quote_nullable(NEW.account_id));
	END IF;

	IF NEW.account_realm_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('account_realm_id'));
		_vq := array_append(_vq, quote_nullable(NEW.account_realm_id));
	END IF;

	IF NEW.company_collection_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('company_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.company_collection_id));
	END IF;

	IF NEW.company_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('company_id'));
		_vq := array_append(_vq, quote_nullable(NEW.company_id));
	END IF;

	IF NEW.device_collection_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('device_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.device_collection_id));
	END IF;

	IF NEW.dns_domain_collection_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('dns_domain_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.dns_domain_collection_id));
	END IF;

	IF NEW.layer2_network_collection_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('layer2_network_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.layer2_network_collection_id));
	END IF;

	IF NEW.layer3_network_collection_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('layer3_network_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.layer3_network_collection_id));
	END IF;

	IF NEW.netblock_collection_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('netblock_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.netblock_collection_id));
	END IF;

	IF NEW.network_range_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('network_range_id'));
		_vq := array_append(_vq, quote_nullable(NEW.network_range_id));
	END IF;

	IF NEW.operating_system_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('operating_system_id'));
		_vq := array_append(_vq, quote_nullable(NEW.operating_system_id));
	END IF;

	IF NEW.operating_system_snapshot_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('operating_system_snapshot_id'));
		_vq := array_append(_vq, quote_nullable(NEW.operating_system_snapshot_id));
	END IF;

	IF NEW.property_collection_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('property_name_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.property_collection_id));
	END IF;

	IF NEW.service_env_collection_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('service_environment_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.service_env_collection_id));
	END IF;

	IF NEW.site_code IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('site_code'));
		_vq := array_append(_vq, quote_nullable(NEW.site_code));
	END IF;

	IF NEW.x509_signed_certificate_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('x509_signed_certificate_id'));
		_vq := array_append(_vq, quote_nullable(NEW.x509_signed_certificate_id));
	END IF;

	IF NEW.property_name IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('property_name'));
		_vq := array_append(_vq, quote_nullable(NEW.property_name));
	END IF;

	IF NEW.property_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('property_type'));
		_vq := array_append(_vq, quote_nullable(NEW.property_type));
	END IF;

	IF NEW.property_value IS NOT NULL THEN
		SELECT property_data_type INTO _dt
			FROM val_property
			WHERE property_name = NEW.property_name
			AND property_type = NEW.property_type;

		IF _dt = 'boolean' THEN
			_cq := array_append(_cq, quote_ident('property_value_boolean'));
			_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.property_value = 'Y' THEN true WHEN NEW.property_value = 'N' THEN false ELSE NULL END) || '::boolean');
		ELSE
			_cq := array_append(_cq, quote_ident('property_value'));
			_vq := array_append(_vq, quote_nullable(NEW.property_value));
		END IF;
	END IF;

	IF NEW.property_value_timestamp IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('property_value_timestamp'));
		_vq := array_append(_vq, quote_nullable(NEW.property_value_timestamp));
	END IF;

	IF NEW.property_value_account_coll_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('property_value_account_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.property_value_account_coll_id));
	END IF;

	IF NEW.property_value_device_coll_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('property_value_device_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.property_value_device_coll_id));
	END IF;

	IF NEW.property_value_json IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('property_value_json'));
		_vq := array_append(_vq, quote_nullable(NEW.property_value_json));
	END IF;

	IF NEW.property_value_nblk_coll_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('property_value_netblock_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.property_value_nblk_coll_id));
	END IF;

	IF NEW.property_value_password_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('property_value_password_type'));
		_vq := array_append(_vq, quote_nullable(NEW.property_value_password_type));
	END IF;

	IF NEW.property_value_sw_package_id IS NOT NULL THEN
		RAISE EXCEPTION 'property_value_sw_package_id can not be set'
			USING ERRCODE = invalid_parameter_value,
			HINT = 'sw_package become software_artifacts and were dropped from property in 0.91';
	END IF;

	IF NEW.property_value_token_col_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('property_value_token_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.property_value_token_col_id));
	END IF;

	IF NEW.property_rank IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('property_rank'));
		_vq := array_append(_vq, quote_nullable(NEW.property_rank));
	END IF;

	IF NEW.start_date IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('start_date'));
		_vq := array_append(_vq, quote_nullable(NEW.start_date));
	END IF;

	IF NEW.finish_date IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('finish_date'));
		_vq := array_append(_vq, quote_nullable(NEW.finish_date));
	END IF;

	IF NEW.is_enabled IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_enabled'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_enabled = 'Y' THEN true WHEN NEW.is_enabled = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.property (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.property_id = _nr.property_id;
	NEW.account_collection_id = _nr.account_collection_id;
	NEW.account_id = _nr.account_id;
	NEW.account_realm_id = _nr.account_realm_id;
	NEW.company_collection_id = _nr.company_collection_id;
	NEW.company_id = _nr.company_id;
	NEW.device_collection_id = _nr.device_collection_id;
	NEW.dns_domain_collection_id = _nr.dns_domain_collection_id;
	NEW.layer2_network_collection_id = _nr.layer2_network_collection_id;
	NEW.layer3_network_collection_id = _nr.layer3_network_collection_id;
	NEW.netblock_collection_id = _nr.netblock_collection_id;
	NEW.network_range_id = _nr.network_range_id;
	NEW.operating_system_id = _nr.operating_system_id;
	NEW.operating_system_snapshot_id = _nr.operating_system_snapshot_id;
	NEW.property_collection_id = _nr.property_name_collection_id;
	NEW.service_env_collection_id = _nr.service_environment_collection_id;
	NEW.site_code = _nr.site_code;
	NEW.x509_signed_certificate_id = _nr.x509_signed_certificate_id;
	NEW.property_name = _nr.property_name;
	NEW.property_type = _nr.property_type;
	IF _dt IS NOT DISTINCT FROM 'boolean' THEN
		NEW.property_value = CASE
			WHEN _nr.property_value_boolean = true THEN 'Y'
			WHEN _nr.property_value_boolean = false THEN 'N'
			ELSE NULL END;
	ELSE
		NEW.property_value = _nr.property_value;
	END IF;
	NEW.property_value_timestamp = _nr.property_value_timestamp;
	NEW.property_value_account_coll_id = _nr.property_value_account_collection_id;
	NEW.property_value_device_coll_id = _nr.property_value_device_collection_id;
	NEW.property_value_json = _nr.property_value_json;
	NEW.property_value_nblk_coll_id = _nr.property_value_netblock_collection_id;
	NEW.property_value_password_type = _nr.property_value_password_type;
	NEW.property_value_sw_package_id = NULL;
	NEW.property_value_token_col_id = _nr.property_value_token_collection_id;
	NEW.property_rank = _nr.property_rank;
	NEW.start_date = _nr.start_date;
	NEW.finish_date = _nr.finish_date;
	NEW.is_enabled = CASE WHEN _nr.is_enabled = true THEN 'Y' WHEN _nr.is_enabled = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_property_ins
	ON jazzhands_legacy.property;
CREATE TRIGGER trigger_property_ins
	INSTEAD OF INSERT ON jazzhands_legacy.property
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.property_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.property_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.property%rowtype;
	_nr	jazzhands.property%rowtype;
	_uq	text[];
	_dt	TEXT;
BEGIN
	IF OLD.property_id IS DISTINCT FROM NEW.property_id THEN
_uq := array_append(_uq, 'property_id = ' || quote_nullable(NEW.property_id));
	END IF;

	IF OLD.account_collection_id IS DISTINCT FROM NEW.account_collection_id THEN
_uq := array_append(_uq, 'account_collection_id = ' || quote_nullable(NEW.account_collection_id));
	END IF;

	IF OLD.account_id IS DISTINCT FROM NEW.account_id THEN
_uq := array_append(_uq, 'account_id = ' || quote_nullable(NEW.account_id));
	END IF;

	IF OLD.account_realm_id IS DISTINCT FROM NEW.account_realm_id THEN
_uq := array_append(_uq, 'account_realm_id = ' || quote_nullable(NEW.account_realm_id));
	END IF;

	IF OLD.company_collection_id IS DISTINCT FROM NEW.company_collection_id THEN
_uq := array_append(_uq, 'company_collection_id = ' || quote_nullable(NEW.company_collection_id));
	END IF;

	IF OLD.company_id IS DISTINCT FROM NEW.company_id THEN
_uq := array_append(_uq, 'company_id = ' || quote_nullable(NEW.company_id));
	END IF;

	IF OLD.device_collection_id IS DISTINCT FROM NEW.device_collection_id THEN
_uq := array_append(_uq, 'device_collection_id = ' || quote_nullable(NEW.device_collection_id));
	END IF;

	IF OLD.dns_domain_collection_id IS DISTINCT FROM NEW.dns_domain_collection_id THEN
_uq := array_append(_uq, 'dns_domain_collection_id = ' || quote_nullable(NEW.dns_domain_collection_id));
	END IF;

	IF OLD.layer2_network_collection_id IS DISTINCT FROM NEW.layer2_network_collection_id THEN
_uq := array_append(_uq, 'layer2_network_collection_id = ' || quote_nullable(NEW.layer2_network_collection_id));
	END IF;

	IF OLD.layer3_network_collection_id IS DISTINCT FROM NEW.layer3_network_collection_id THEN
_uq := array_append(_uq, 'layer3_network_collection_id = ' || quote_nullable(NEW.layer3_network_collection_id));
	END IF;

	IF OLD.netblock_collection_id IS DISTINCT FROM NEW.netblock_collection_id THEN
_uq := array_append(_uq, 'netblock_collection_id = ' || quote_nullable(NEW.netblock_collection_id));
	END IF;

	IF OLD.network_range_id IS DISTINCT FROM NEW.network_range_id THEN
_uq := array_append(_uq, 'network_range_id = ' || quote_nullable(NEW.network_range_id));
	END IF;

	IF OLD.operating_system_id IS DISTINCT FROM NEW.operating_system_id THEN
_uq := array_append(_uq, 'operating_system_id = ' || quote_nullable(NEW.operating_system_id));
	END IF;

	IF OLD.operating_system_snapshot_id IS DISTINCT FROM NEW.operating_system_snapshot_id THEN
_uq := array_append(_uq, 'operating_system_snapshot_id = ' || quote_nullable(NEW.operating_system_snapshot_id));
	END IF;

	IF OLD.property_collection_id IS DISTINCT FROM NEW.property_collection_id THEN
_uq := array_append(_uq, 'property_name_collection_id = ' || quote_nullable(NEW.property_collection_id));
	END IF;

	IF OLD.service_env_collection_id IS DISTINCT FROM NEW.service_env_collection_id THEN
_uq := array_append(_uq, 'service_environment_collection_id = ' || quote_nullable(NEW.service_env_collection_id));
	END IF;

	IF OLD.site_code IS DISTINCT FROM NEW.site_code THEN
_uq := array_append(_uq, 'site_code = ' || quote_nullable(NEW.site_code));
	END IF;

	IF OLD.x509_signed_certificate_id IS DISTINCT FROM NEW.x509_signed_certificate_id THEN
_uq := array_append(_uq, 'x509_signed_certificate_id = ' || quote_nullable(NEW.x509_signed_certificate_id));
	END IF;

	IF OLD.property_name IS DISTINCT FROM NEW.property_name THEN
_uq := array_append(_uq, 'property_name = ' || quote_nullable(NEW.property_name));
	END IF;

	IF OLD.property_type IS DISTINCT FROM NEW.property_type THEN
_uq := array_append(_uq, 'property_type = ' || quote_nullable(NEW.property_type));
	END IF;

	IF OLD.property_value IS DISTINCT FROM NEW.property_value THEN
		SELECT property_data_type INTO _dt
		FROM val_property
		WHERE property_name = NEW.property_name
		AND property_type = NEW.property_type;

		IF _dt = 'boolean' THEN
			IF NEW.property_value = 'Y' THEN
				_uq := array_append(_uq, 'property_value_boolean = true');
			ELSIF NEW.property_value = 'N' THEN
				_uq := array_append(_uq, 'property_value_boolean = false');
			ELSE
				_uq := array_append(_uq, 'property_value = NULL');
			END IF;
		ELSE
			_uq := array_append(_uq, 'property_value = ' || quote_nullable(NEW.property_value));
			_uq := array_append(_uq, 'property_value_boolean = NULL');
		END IF;
	END IF;

	IF OLD.property_value_timestamp IS DISTINCT FROM NEW.property_value_timestamp THEN
_uq := array_append(_uq, 'property_value_timestamp = ' || quote_nullable(NEW.property_value_timestamp));
	END IF;

	IF OLD.property_value_account_coll_id IS DISTINCT FROM NEW.property_value_account_coll_id THEN
_uq := array_append(_uq, 'property_value_account_collection_id = ' || quote_nullable(NEW.property_value_account_coll_id));
	END IF;

	IF OLD.property_value_device_coll_id IS DISTINCT FROM NEW.property_value_device_coll_id THEN
_uq := array_append(_uq, 'property_value_device_collection_id = ' || quote_nullable(NEW.property_value_device_coll_id));
	END IF;

	IF OLD.property_value_json IS DISTINCT FROM NEW.property_value_json THEN
_uq := array_append(_uq, 'property_value_json = ' || quote_nullable(NEW.property_value_json));
	END IF;

	IF OLD.property_value_nblk_coll_id IS DISTINCT FROM NEW.property_value_nblk_coll_id THEN
_uq := array_append(_uq, 'property_value_netblock_collection_id = ' || quote_nullable(NEW.property_value_nblk_coll_id));
	END IF;

	IF OLD.property_value_password_type IS DISTINCT FROM NEW.property_value_password_type THEN
_uq := array_append(_uq, 'property_value_password_type = ' || quote_nullable(NEW.property_value_password_type));
	END IF;

	IF OLD.property_value_sw_package_id IS DISTINCT FROM NEW.property_value_sw_package_id THEN
		RAISE EXCEPTION 'property_value_sw_package_id can not be set'
			USING ERRCODE = invalid_parameter_value,
			HINT = 'sw_package become software_artifacts and were dropped from property in 0.91';
	END IF;

	IF OLD.property_value_token_col_id IS DISTINCT FROM NEW.property_value_token_col_id THEN
_uq := array_append(_uq, 'property_value_token_collection_id = ' || quote_nullable(NEW.property_value_token_col_id));
	END IF;

	IF OLD.property_rank IS DISTINCT FROM NEW.property_rank THEN
_uq := array_append(_uq, 'property_rank = ' || quote_nullable(NEW.property_rank));
	END IF;

	IF OLD.start_date IS DISTINCT FROM NEW.start_date THEN
_uq := array_append(_uq, 'start_date = ' || quote_nullable(NEW.start_date));
	END IF;

	IF OLD.finish_date IS DISTINCT FROM NEW.finish_date THEN
_uq := array_append(_uq, 'finish_date = ' || quote_nullable(NEW.finish_date));
	END IF;

	IF OLD.is_enabled IS DISTINCT FROM NEW.is_enabled THEN
IF NEW.is_enabled = 'Y' THEN
	_uq := array_append(_uq, 'is_enabled = true');
ELSIF NEW.is_enabled = 'N' THEN
	_uq := array_append(_uq, 'is_enabled = false');
ELSE
	_uq := array_append(_uq, 'is_enabled = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.property SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  property_id = $1 RETURNING *'  USING OLD.property_id
			INTO _nr;

		NEW.property_id = _nr.property_id;
		NEW.account_collection_id = _nr.account_collection_id;
		NEW.account_id = _nr.account_id;
		NEW.account_realm_id = _nr.account_realm_id;
		NEW.company_collection_id = _nr.company_collection_id;
		NEW.company_id = _nr.company_id;
		NEW.device_collection_id = _nr.device_collection_id;
		NEW.dns_domain_collection_id = _nr.dns_domain_collection_id;
		NEW.layer2_network_collection_id = _nr.layer2_network_collection_id;
		NEW.layer3_network_collection_id = _nr.layer3_network_collection_id;
		NEW.netblock_collection_id = _nr.netblock_collection_id;
		NEW.network_range_id = _nr.network_range_id;
		NEW.operating_system_id = _nr.operating_system_id;
		NEW.operating_system_snapshot_id = _nr.operating_system_snapshot_id;
		NEW.property_collection_id = _nr.property_name_collection_id;
		NEW.service_env_collection_id = _nr.service_environment_collection_id;
		NEW.site_code = _nr.site_code;
		NEW.x509_signed_certificate_id = _nr.x509_signed_certificate_id;
		NEW.property_name = _nr.property_name;
		NEW.property_type = _nr.property_type;

		IF _dt IS NOT DISTINCT FROM 'boolean' THEN
			NEW.property_value = CASE
			WHEN _nr.property_value_boolean = true THEN 'Y'
			WHEN _nr.property_value_boolean = false THEN 'N'
			ELSE NULL END;
		ELSE
			NEW.property_value = _nr.property_value;
		END IF;

		NEW.property_value_timestamp = _nr.property_value_timestamp;
		NEW.property_value_account_coll_id = _nr.property_value_account_collection_id;
		NEW.property_value_device_coll_id = _nr.property_value_device_collection_id;
		NEW.property_value_json = _nr.property_value_json;
		NEW.property_value_nblk_coll_id = _nr.property_value_netblock_collection_id;
		NEW.property_value_password_type = _nr.property_value_password_type;
		NEW.property_value_sw_package_id = NULL;
		NEW.property_value_token_col_id = _nr.property_value_token_collection_id;
		NEW.property_rank = _nr.property_rank;
		NEW.start_date = _nr.start_date;
		NEW.finish_date = _nr.finish_date;
		NEW.is_enabled = CASE WHEN _nr.is_enabled = true THEN 'Y' WHEN _nr.is_enabled = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_property_upd
	ON jazzhands_legacy.property;
CREATE TRIGGER trigger_property_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.property
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.property_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.property_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.property%rowtype;
	_dt	TEXT;
BEGIN
	DELETE FROM jazzhands.property
	WHERE  property_id = OLD.property_id  RETURNING *
	INTO _or;

	SELECT property_data_type INTO _dt
	FROM val_property
	WHERE property_name = OLD.property_name
	AND property_type = OLD.property_type;

	OLD.property_id = _or.property_id;
	OLD.account_collection_id = _or.account_collection_id;
	OLD.account_id = _or.account_id;
	OLD.account_realm_id = _or.account_realm_id;
	OLD.company_collection_id = _or.company_collection_id;
	OLD.company_id = _or.company_id;
	OLD.device_collection_id = _or.device_collection_id;
	OLD.dns_domain_collection_id = _or.dns_domain_collection_id;
	OLD.layer2_network_collection_id = _or.layer2_network_collection_id;
	OLD.layer3_network_collection_id = _or.layer3_network_collection_id;
	OLD.netblock_collection_id = _or.netblock_collection_id;
	OLD.network_range_id = _or.network_range_id;
	OLD.operating_system_id = _or.operating_system_id;
	OLD.operating_system_snapshot_id = _or.operating_system_snapshot_id;
	OLD.property_collection_id = _or.property_name_collection_id;
	OLD.service_env_collection_id = _or.service_environment_collection_id;
	OLD.site_code = _or.site_code;
	OLD.x509_signed_certificate_id = _or.x509_signed_certificate_id;
	OLD.property_name = _or.property_name;
	OLD.property_type = _or.property_type;
	IF _dt IS NOT DISTINCT FROM 'boolean' THEN
		OLD.property_value = CASE
			WHEN _or.property_value_boolean = true THEN 'Y'
			WHEN _or.property_value_boolean = false THEN 'N'
			ELSE NULL END;
	ELSE
		OLD.property_value = _or.property_value;
	END IF;
	OLD.property_value_timestamp = _or.property_value_timestamp;
	OLD.property_value_account_coll_id = _or.property_value_account_collection_id;
	OLD.property_value_device_coll_id = _or.property_value_device_collection_id;
	OLD.property_value_json = _or.property_value_json;
	OLD.property_value_nblk_coll_id = _or.property_value_netblock_collection_id;
	OLD.property_value_password_type = _or.property_value_password_type;
	OLD.property_value_sw_package_id = NULL;
	OLD.property_value_token_col_id = _or.property_value_token_collection_id;
	OLD.property_rank = _or.property_rank;
	OLD.start_date = _or.start_date;
	OLD.finish_date = _or.finish_date;
	OLD.is_enabled = CASE WHEN _or.is_enabled = true THEN 'Y' WHEN _or.is_enabled = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_property_del
	ON jazzhands_legacy.property;
CREATE TRIGGER trigger_property_del
	INSTEAD OF DELETE ON jazzhands_legacy.property
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.property_del();


-- Triggers for rack

CREATE OR REPLACE FUNCTION jazzhands_legacy.rack_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.rack%rowtype;
BEGIN

	IF NEW.rack_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('rack_id'));
		_vq := array_append(_vq, quote_nullable(NEW.rack_id));
	END IF;

	IF NEW.site_code IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('site_code'));
		_vq := array_append(_vq, quote_nullable(NEW.site_code));
	END IF;

	IF NEW.room IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('room'));
		_vq := array_append(_vq, quote_nullable(NEW.room));
	END IF;

	IF NEW.sub_room IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('sub_room'));
		_vq := array_append(_vq, quote_nullable(NEW.sub_room));
	END IF;

	IF NEW.rack_row IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('rack_row'));
		_vq := array_append(_vq, quote_nullable(NEW.rack_row));
	END IF;

	IF NEW.rack_name IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('rack_name'));
		_vq := array_append(_vq, quote_nullable(NEW.rack_name));
	END IF;

	IF NEW.rack_style IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('rack_style'));
		_vq := array_append(_vq, quote_nullable(NEW.rack_style));
	END IF;

	IF NEW.rack_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('rack_type'));
		_vq := array_append(_vq, quote_nullable(NEW.rack_type));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.rack_height_in_u IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('rack_height_in_u'));
		_vq := array_append(_vq, quote_nullable(NEW.rack_height_in_u));
	END IF;

	IF NEW.display_from_bottom IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('display_from_bottom'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.display_from_bottom = 'Y' THEN true WHEN NEW.display_from_bottom = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.rack (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.rack_id = _nr.rack_id;
	NEW.site_code = _nr.site_code;
	NEW.room = _nr.room;
	NEW.sub_room = _nr.sub_room;
	NEW.rack_row = _nr.rack_row;
	NEW.rack_name = _nr.rack_name;
	NEW.rack_style = _nr.rack_style;
	NEW.rack_type = _nr.rack_type;
	NEW.description = _nr.description;
	NEW.rack_height_in_u = _nr.rack_height_in_u;
	NEW.display_from_bottom = CASE WHEN _nr.display_from_bottom = true THEN 'Y' WHEN _nr.display_from_bottom = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_rack_ins
	ON jazzhands_legacy.rack;
CREATE TRIGGER trigger_rack_ins
	INSTEAD OF INSERT ON jazzhands_legacy.rack
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.rack_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.rack_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.rack%rowtype;
	_nr	jazzhands.rack%rowtype;
	_uq	text[];
BEGIN

	IF OLD.rack_id IS DISTINCT FROM NEW.rack_id THEN
_uq := array_append(_uq, 'rack_id = ' || quote_nullable(NEW.rack_id));
	END IF;

	IF OLD.site_code IS DISTINCT FROM NEW.site_code THEN
_uq := array_append(_uq, 'site_code = ' || quote_nullable(NEW.site_code));
	END IF;

	IF OLD.room IS DISTINCT FROM NEW.room THEN
_uq := array_append(_uq, 'room = ' || quote_nullable(NEW.room));
	END IF;

	IF OLD.sub_room IS DISTINCT FROM NEW.sub_room THEN
_uq := array_append(_uq, 'sub_room = ' || quote_nullable(NEW.sub_room));
	END IF;

	IF OLD.rack_row IS DISTINCT FROM NEW.rack_row THEN
_uq := array_append(_uq, 'rack_row = ' || quote_nullable(NEW.rack_row));
	END IF;

	IF OLD.rack_name IS DISTINCT FROM NEW.rack_name THEN
_uq := array_append(_uq, 'rack_name = ' || quote_nullable(NEW.rack_name));
	END IF;

	IF OLD.rack_style IS DISTINCT FROM NEW.rack_style THEN
_uq := array_append(_uq, 'rack_style = ' || quote_nullable(NEW.rack_style));
	END IF;

	IF OLD.rack_type IS DISTINCT FROM NEW.rack_type THEN
_uq := array_append(_uq, 'rack_type = ' || quote_nullable(NEW.rack_type));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.rack_height_in_u IS DISTINCT FROM NEW.rack_height_in_u THEN
_uq := array_append(_uq, 'rack_height_in_u = ' || quote_nullable(NEW.rack_height_in_u));
	END IF;

	IF OLD.display_from_bottom IS DISTINCT FROM NEW.display_from_bottom THEN
IF NEW.display_from_bottom = 'Y' THEN
	_uq := array_append(_uq, 'display_from_bottom = true');
ELSIF NEW.display_from_bottom = 'N' THEN
	_uq := array_append(_uq, 'display_from_bottom = false');
ELSE
	_uq := array_append(_uq, 'display_from_bottom = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.rack SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  rack_id = $1 RETURNING *'  USING OLD.rack_id
			INTO _nr;

		NEW.rack_id = _nr.rack_id;
		NEW.site_code = _nr.site_code;
		NEW.room = _nr.room;
		NEW.sub_room = _nr.sub_room;
		NEW.rack_row = _nr.rack_row;
		NEW.rack_name = _nr.rack_name;
		NEW.rack_style = _nr.rack_style;
		NEW.rack_type = _nr.rack_type;
		NEW.description = _nr.description;
		NEW.rack_height_in_u = _nr.rack_height_in_u;
		NEW.display_from_bottom = CASE WHEN _nr.display_from_bottom = true THEN 'Y' WHEN _nr.display_from_bottom = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_rack_upd
	ON jazzhands_legacy.rack;
CREATE TRIGGER trigger_rack_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.rack
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.rack_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.rack_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.rack%rowtype;
BEGIN
	DELETE FROM jazzhands.rack
	WHERE  rack_id = OLD.rack_id  RETURNING *
	INTO _or;
	OLD.rack_id = _or.rack_id;
	OLD.site_code = _or.site_code;
	OLD.room = _or.room;
	OLD.sub_room = _or.sub_room;
	OLD.rack_row = _or.rack_row;
	OLD.rack_name = _or.rack_name;
	OLD.rack_style = _or.rack_style;
	OLD.rack_type = _or.rack_type;
	OLD.description = _or.description;
	OLD.rack_height_in_u = _or.rack_height_in_u;
	OLD.display_from_bottom = CASE WHEN _or.display_from_bottom = true THEN 'Y' WHEN _or.display_from_bottom = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_rack_del
	ON jazzhands_legacy.rack;
CREATE TRIGGER trigger_rack_del
	INSTEAD OF DELETE ON jazzhands_legacy.rack
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.rack_del();


-- Triggers for slot

CREATE OR REPLACE FUNCTION jazzhands_legacy.slot_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.slot%rowtype;
BEGIN

	IF NEW.slot_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('slot_id'));
		_vq := array_append(_vq, quote_nullable(NEW.slot_id));
	END IF;

	IF NEW.component_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('component_id'));
		_vq := array_append(_vq, quote_nullable(NEW.component_id));
	END IF;

	IF NEW.slot_name IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('slot_name'));
		_vq := array_append(_vq, quote_nullable(NEW.slot_name));
	END IF;

	IF NEW.slot_index IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('slot_index'));
		_vq := array_append(_vq, quote_nullable(NEW.slot_index));
	END IF;

	IF NEW.slot_type_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('slot_type_id'));
		_vq := array_append(_vq, quote_nullable(NEW.slot_type_id));
	END IF;

	IF NEW.component_type_slot_tmplt_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('component_type_slot_template_id'));
		_vq := array_append(_vq, quote_nullable(NEW.component_type_slot_tmplt_id));
	END IF;

	IF NEW.is_enabled IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_enabled'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_enabled = 'Y' THEN true WHEN NEW.is_enabled = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.physical_label IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('physical_label'));
		_vq := array_append(_vq, quote_nullable(NEW.physical_label));
	END IF;

	IF NEW.mac_address IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('mac_address'));
		_vq := array_append(_vq, quote_nullable(NEW.mac_address));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.slot_x_offset IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('slot_x_offset'));
		_vq := array_append(_vq, quote_nullable(NEW.slot_x_offset));
	END IF;

	IF NEW.slot_y_offset IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('slot_y_offset'));
		_vq := array_append(_vq, quote_nullable(NEW.slot_y_offset));
	END IF;

	IF NEW.slot_z_offset IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('slot_z_offset'));
		_vq := array_append(_vq, quote_nullable(NEW.slot_z_offset));
	END IF;

	IF NEW.slot_side IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('slot_side'));
		_vq := array_append(_vq, quote_nullable(NEW.slot_side));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.slot (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.slot_id = _nr.slot_id;
	NEW.component_id = _nr.component_id;
	NEW.slot_name = _nr.slot_name;
	NEW.slot_index = _nr.slot_index;
	NEW.slot_type_id = _nr.slot_type_id;
	NEW.component_type_slot_tmplt_id = _nr.component_type_slot_template_id;
	NEW.is_enabled = CASE WHEN _nr.is_enabled = true THEN 'Y' WHEN _nr.is_enabled = false THEN 'N' ELSE NULL END;
	NEW.physical_label = _nr.physical_label;
	NEW.mac_address = _nr.mac_address;
	NEW.description = _nr.description;
	NEW.slot_x_offset = _nr.slot_x_offset;
	NEW.slot_y_offset = _nr.slot_y_offset;
	NEW.slot_z_offset = _nr.slot_z_offset;
	NEW.slot_side = _nr.slot_side;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_slot_ins
	ON jazzhands_legacy.slot;
CREATE TRIGGER trigger_slot_ins
	INSTEAD OF INSERT ON jazzhands_legacy.slot
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.slot_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.slot_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.slot%rowtype;
	_nr	jazzhands.slot%rowtype;
	_uq	text[];
BEGIN

	IF OLD.slot_id IS DISTINCT FROM NEW.slot_id THEN
_uq := array_append(_uq, 'slot_id = ' || quote_nullable(NEW.slot_id));
	END IF;

	IF OLD.component_id IS DISTINCT FROM NEW.component_id THEN
_uq := array_append(_uq, 'component_id = ' || quote_nullable(NEW.component_id));
	END IF;

	IF OLD.slot_name IS DISTINCT FROM NEW.slot_name THEN
_uq := array_append(_uq, 'slot_name = ' || quote_nullable(NEW.slot_name));
	END IF;

	IF OLD.slot_index IS DISTINCT FROM NEW.slot_index THEN
_uq := array_append(_uq, 'slot_index = ' || quote_nullable(NEW.slot_index));
	END IF;

	IF OLD.slot_type_id IS DISTINCT FROM NEW.slot_type_id THEN
_uq := array_append(_uq, 'slot_type_id = ' || quote_nullable(NEW.slot_type_id));
	END IF;

	IF OLD.component_type_slot_tmplt_id IS DISTINCT FROM NEW.component_type_slot_tmplt_id THEN
_uq := array_append(_uq, 'component_type_slot_template_id = ' || quote_nullable(NEW.component_type_slot_tmplt_id));
	END IF;

	IF OLD.is_enabled IS DISTINCT FROM NEW.is_enabled THEN
IF NEW.is_enabled = 'Y' THEN
	_uq := array_append(_uq, 'is_enabled = true');
ELSIF NEW.is_enabled = 'N' THEN
	_uq := array_append(_uq, 'is_enabled = false');
ELSE
	_uq := array_append(_uq, 'is_enabled = NULL');
END IF;
	END IF;

	IF OLD.physical_label IS DISTINCT FROM NEW.physical_label THEN
_uq := array_append(_uq, 'physical_label = ' || quote_nullable(NEW.physical_label));
	END IF;

	IF OLD.mac_address IS DISTINCT FROM NEW.mac_address THEN
_uq := array_append(_uq, 'mac_address = ' || quote_nullable(NEW.mac_address));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.slot_x_offset IS DISTINCT FROM NEW.slot_x_offset THEN
_uq := array_append(_uq, 'slot_x_offset = ' || quote_nullable(NEW.slot_x_offset));
	END IF;

	IF OLD.slot_y_offset IS DISTINCT FROM NEW.slot_y_offset THEN
_uq := array_append(_uq, 'slot_y_offset = ' || quote_nullable(NEW.slot_y_offset));
	END IF;

	IF OLD.slot_z_offset IS DISTINCT FROM NEW.slot_z_offset THEN
_uq := array_append(_uq, 'slot_z_offset = ' || quote_nullable(NEW.slot_z_offset));
	END IF;

	IF OLD.slot_side IS DISTINCT FROM NEW.slot_side THEN
_uq := array_append(_uq, 'slot_side = ' || quote_nullable(NEW.slot_side));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.slot SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  slot_id = $1 RETURNING *'  USING OLD.slot_id
			INTO _nr;

		NEW.slot_id = _nr.slot_id;
		NEW.component_id = _nr.component_id;
		NEW.slot_name = _nr.slot_name;
		NEW.slot_index = _nr.slot_index;
		NEW.slot_type_id = _nr.slot_type_id;
		NEW.component_type_slot_tmplt_id = _nr.component_type_slot_template_id;
		NEW.is_enabled = CASE WHEN _nr.is_enabled = true THEN 'Y' WHEN _nr.is_enabled = false THEN 'N' ELSE NULL END;
		NEW.physical_label = _nr.physical_label;
		NEW.mac_address = _nr.mac_address;
		NEW.description = _nr.description;
		NEW.slot_x_offset = _nr.slot_x_offset;
		NEW.slot_y_offset = _nr.slot_y_offset;
		NEW.slot_z_offset = _nr.slot_z_offset;
		NEW.slot_side = _nr.slot_side;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_slot_upd
	ON jazzhands_legacy.slot;
CREATE TRIGGER trigger_slot_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.slot
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.slot_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.slot_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.slot%rowtype;
BEGIN
	DELETE FROM jazzhands.slot
	WHERE  slot_id = OLD.slot_id  RETURNING *
	INTO _or;
	OLD.slot_id = _or.slot_id;
	OLD.component_id = _or.component_id;
	OLD.slot_name = _or.slot_name;
	OLD.slot_index = _or.slot_index;
	OLD.slot_type_id = _or.slot_type_id;
	OLD.component_type_slot_tmplt_id = _or.component_type_slot_template_id;
	OLD.is_enabled = CASE WHEN _or.is_enabled = true THEN 'Y' WHEN _or.is_enabled = false THEN 'N' ELSE NULL END;
	OLD.physical_label = _or.physical_label;
	OLD.mac_address = _or.mac_address;
	OLD.description = _or.description;
	OLD.slot_x_offset = _or.slot_x_offset;
	OLD.slot_y_offset = _or.slot_y_offset;
	OLD.slot_z_offset = _or.slot_z_offset;
	OLD.slot_side = _or.slot_side;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_slot_del
	ON jazzhands_legacy.slot;
CREATE TRIGGER trigger_slot_del
	INSTEAD OF DELETE ON jazzhands_legacy.slot
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.slot_del();


-- Triggers for slot_type

CREATE OR REPLACE FUNCTION jazzhands_legacy.slot_type_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.slot_type%rowtype;
BEGIN

	IF NEW.slot_type_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('slot_type_id'));
		_vq := array_append(_vq, quote_nullable(NEW.slot_type_id));
	END IF;

	IF NEW.slot_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('slot_type'));
		_vq := array_append(_vq, quote_nullable(NEW.slot_type));
	END IF;

	IF NEW.slot_function IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('slot_function'));
		_vq := array_append(_vq, quote_nullable(NEW.slot_function));
	END IF;

	IF NEW.slot_physical_interface_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('slot_physical_interface_type'));
		_vq := array_append(_vq, quote_nullable(NEW.slot_physical_interface_type));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.remote_slot_permitted IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('remote_slot_permitted'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.remote_slot_permitted = 'Y' THEN true WHEN NEW.remote_slot_permitted = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.slot_type (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.slot_type_id = _nr.slot_type_id;
	NEW.slot_type = _nr.slot_type;
	NEW.slot_function = _nr.slot_function;
	NEW.slot_physical_interface_type = _nr.slot_physical_interface_type;
	NEW.description = _nr.description;
	NEW.remote_slot_permitted = CASE WHEN _nr.remote_slot_permitted = true THEN 'Y' WHEN _nr.remote_slot_permitted = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_slot_type_ins
	ON jazzhands_legacy.slot_type;
CREATE TRIGGER trigger_slot_type_ins
	INSTEAD OF INSERT ON jazzhands_legacy.slot_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.slot_type_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.slot_type_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.slot_type%rowtype;
	_nr	jazzhands.slot_type%rowtype;
	_uq	text[];
BEGIN

	IF OLD.slot_type_id IS DISTINCT FROM NEW.slot_type_id THEN
_uq := array_append(_uq, 'slot_type_id = ' || quote_nullable(NEW.slot_type_id));
	END IF;

	IF OLD.slot_type IS DISTINCT FROM NEW.slot_type THEN
_uq := array_append(_uq, 'slot_type = ' || quote_nullable(NEW.slot_type));
	END IF;

	IF OLD.slot_function IS DISTINCT FROM NEW.slot_function THEN
_uq := array_append(_uq, 'slot_function = ' || quote_nullable(NEW.slot_function));
	END IF;

	IF OLD.slot_physical_interface_type IS DISTINCT FROM NEW.slot_physical_interface_type THEN
_uq := array_append(_uq, 'slot_physical_interface_type = ' || quote_nullable(NEW.slot_physical_interface_type));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.remote_slot_permitted IS DISTINCT FROM NEW.remote_slot_permitted THEN
IF NEW.remote_slot_permitted = 'Y' THEN
	_uq := array_append(_uq, 'remote_slot_permitted = true');
ELSIF NEW.remote_slot_permitted = 'N' THEN
	_uq := array_append(_uq, 'remote_slot_permitted = false');
ELSE
	_uq := array_append(_uq, 'remote_slot_permitted = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.slot_type SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  slot_type_id = $1 RETURNING *'  USING OLD.slot_type_id
			INTO _nr;

		NEW.slot_type_id = _nr.slot_type_id;
		NEW.slot_type = _nr.slot_type;
		NEW.slot_function = _nr.slot_function;
		NEW.slot_physical_interface_type = _nr.slot_physical_interface_type;
		NEW.description = _nr.description;
		NEW.remote_slot_permitted = CASE WHEN _nr.remote_slot_permitted = true THEN 'Y' WHEN _nr.remote_slot_permitted = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_slot_type_upd
	ON jazzhands_legacy.slot_type;
CREATE TRIGGER trigger_slot_type_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.slot_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.slot_type_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.slot_type_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.slot_type%rowtype;
BEGIN
	DELETE FROM jazzhands.slot_type
	WHERE  slot_type_id = OLD.slot_type_id  RETURNING *
	INTO _or;
	OLD.slot_type_id = _or.slot_type_id;
	OLD.slot_type = _or.slot_type;
	OLD.slot_function = _or.slot_function;
	OLD.slot_physical_interface_type = _or.slot_physical_interface_type;
	OLD.description = _or.description;
	OLD.remote_slot_permitted = CASE WHEN _or.remote_slot_permitted = true THEN 'Y' WHEN _or.remote_slot_permitted = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_slot_type_del
	ON jazzhands_legacy.slot_type;
CREATE TRIGGER trigger_slot_type_del
	INSTEAD OF DELETE ON jazzhands_legacy.slot_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.slot_type_del();


-- Triggers for sudo_acct_col_device_collectio

CREATE OR REPLACE FUNCTION jazzhands_legacy.sudo_acct_col_device_collectio_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.sudo_account_collection_device_collection%rowtype;
BEGIN

	IF NEW.sudo_alias_name IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('sudo_alias_name'));
		_vq := array_append(_vq, quote_nullable(NEW.sudo_alias_name));
	END IF;

	IF NEW.device_collection_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('device_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.device_collection_id));
	END IF;

	IF NEW.account_collection_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('account_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.account_collection_id));
	END IF;

	IF NEW.run_as_account_collection_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('run_as_account_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.run_as_account_collection_id));
	END IF;

	IF NEW.requires_password IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('requires_password'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.requires_password = 'Y' THEN true WHEN NEW.requires_password = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.can_exec_child IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('can_exec_child'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.can_exec_child = 'Y' THEN true WHEN NEW.can_exec_child = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.sudo_account_collection_device_collection (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.sudo_alias_name = _nr.sudo_alias_name;
	NEW.device_collection_id = _nr.device_collection_id;
	NEW.account_collection_id = _nr.account_collection_id;
	NEW.run_as_account_collection_id = _nr.run_as_account_collection_id;
	NEW.requires_password = CASE WHEN _nr.requires_password = true THEN 'Y' WHEN _nr.requires_password = false THEN 'N' ELSE NULL END;
	NEW.can_exec_child = CASE WHEN _nr.can_exec_child = true THEN 'Y' WHEN _nr.can_exec_child = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_sudo_acct_col_device_collectio_ins
	ON jazzhands_legacy.sudo_acct_col_device_collectio;
CREATE TRIGGER trigger_sudo_acct_col_device_collectio_ins
	INSTEAD OF INSERT ON jazzhands_legacy.sudo_acct_col_device_collectio
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.sudo_acct_col_device_collectio_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.sudo_acct_col_device_collectio_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.sudo_acct_col_device_collectio%rowtype;
	_nr	jazzhands.sudo_account_collection_device_collection%rowtype;
	_uq	text[];
BEGIN

	IF OLD.sudo_alias_name IS DISTINCT FROM NEW.sudo_alias_name THEN
_uq := array_append(_uq, 'sudo_alias_name = ' || quote_nullable(NEW.sudo_alias_name));
	END IF;

	IF OLD.device_collection_id IS DISTINCT FROM NEW.device_collection_id THEN
_uq := array_append(_uq, 'device_collection_id = ' || quote_nullable(NEW.device_collection_id));
	END IF;

	IF OLD.account_collection_id IS DISTINCT FROM NEW.account_collection_id THEN
_uq := array_append(_uq, 'account_collection_id = ' || quote_nullable(NEW.account_collection_id));
	END IF;

	IF OLD.run_as_account_collection_id IS DISTINCT FROM NEW.run_as_account_collection_id THEN
_uq := array_append(_uq, 'run_as_account_collection_id = ' || quote_nullable(NEW.run_as_account_collection_id));
	END IF;

	IF OLD.requires_password IS DISTINCT FROM NEW.requires_password THEN
IF NEW.requires_password = 'Y' THEN
	_uq := array_append(_uq, 'requires_password = true');
ELSIF NEW.requires_password = 'N' THEN
	_uq := array_append(_uq, 'requires_password = false');
ELSE
	_uq := array_append(_uq, 'requires_password = NULL');
END IF;
	END IF;

	IF OLD.can_exec_child IS DISTINCT FROM NEW.can_exec_child THEN
IF NEW.can_exec_child = 'Y' THEN
	_uq := array_append(_uq, 'can_exec_child = true');
ELSIF NEW.can_exec_child = 'N' THEN
	_uq := array_append(_uq, 'can_exec_child = false');
ELSE
	_uq := array_append(_uq, 'can_exec_child = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.sudo_account_collection_device_collection SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  sudo_alias_name = $1 AND  device_collection_id = $2 AND  account_collection_id = $3 RETURNING *'  USING OLD.sudo_alias_name, OLD.device_collection_id, OLD.account_collection_id
			INTO _nr;

		NEW.sudo_alias_name = _nr.sudo_alias_name;
		NEW.device_collection_id = _nr.device_collection_id;
		NEW.account_collection_id = _nr.account_collection_id;
		NEW.run_as_account_collection_id = _nr.run_as_account_collection_id;
		NEW.requires_password = CASE WHEN _nr.requires_password = true THEN 'Y' WHEN _nr.requires_password = false THEN 'N' ELSE NULL END;
		NEW.can_exec_child = CASE WHEN _nr.can_exec_child = true THEN 'Y' WHEN _nr.can_exec_child = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_sudo_acct_col_device_collectio_upd
	ON jazzhands_legacy.sudo_acct_col_device_collectio;
CREATE TRIGGER trigger_sudo_acct_col_device_collectio_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.sudo_acct_col_device_collectio
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.sudo_acct_col_device_collectio_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.sudo_acct_col_device_collectio_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.sudo_account_collection_device_collection%rowtype;
BEGIN
	DELETE FROM jazzhands.sudo_account_collection_device_collection
	WHERE  sudo_alias_name = OLD.sudo_alias_name  AND  device_collection_id = OLD.device_collection_id  AND  account_collection_id = OLD.account_collection_id  RETURNING *
	INTO _or;
	OLD.sudo_alias_name = _or.sudo_alias_name;
	OLD.device_collection_id = _or.device_collection_id;
	OLD.account_collection_id = _or.account_collection_id;
	OLD.run_as_account_collection_id = _or.run_as_account_collection_id;
	OLD.requires_password = CASE WHEN _or.requires_password = true THEN 'Y' WHEN _or.requires_password = false THEN 'N' ELSE NULL END;
	OLD.can_exec_child = CASE WHEN _or.can_exec_child = true THEN 'Y' WHEN _or.can_exec_child = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_sudo_acct_col_device_collectio_del
	ON jazzhands_legacy.sudo_acct_col_device_collectio;
CREATE TRIGGER trigger_sudo_acct_col_device_collectio_del
	INSTEAD OF DELETE ON jazzhands_legacy.sudo_acct_col_device_collectio
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.sudo_acct_col_device_collectio_del();


-- Triggers for token

CREATE OR REPLACE FUNCTION jazzhands_legacy.token_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.token%rowtype;
BEGIN

	IF NEW.token_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('token_id'));
		_vq := array_append(_vq, quote_nullable(NEW.token_id));
	END IF;

	IF NEW.token_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('token_type'));
		_vq := array_append(_vq, quote_nullable(NEW.token_type));
	END IF;

	IF NEW.token_status IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('token_status'));
		_vq := array_append(_vq, quote_nullable(NEW.token_status));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.external_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('external_id'));
		_vq := array_append(_vq, quote_nullable(NEW.external_id));
	END IF;

	IF NEW.token_serial IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('token_serial'));
		_vq := array_append(_vq, quote_nullable(NEW.token_serial));
	END IF;

	IF NEW.zero_time IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('zero_time'));
		_vq := array_append(_vq, quote_nullable(NEW.zero_time));
	END IF;

	IF NEW.time_modulo IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('time_modulo'));
		_vq := array_append(_vq, quote_nullable(NEW.time_modulo));
	END IF;

	IF NEW.time_skew IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('time_skew'));
		_vq := array_append(_vq, quote_nullable(NEW.time_skew));
	END IF;

	IF NEW.token_key IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('token_key'));
		_vq := array_append(_vq, quote_nullable(NEW.token_key));
	END IF;

	IF NEW.encryption_key_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('encryption_key_id'));
		_vq := array_append(_vq, quote_nullable(NEW.encryption_key_id));
	END IF;

	IF NEW.token_password IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('token_password'));
		_vq := array_append(_vq, quote_nullable(NEW.token_password));
	END IF;

	IF NEW.expire_time IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('expire_time'));
		_vq := array_append(_vq, quote_nullable(NEW.expire_time));
	END IF;

	IF NEW.is_token_locked IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_token_locked'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_token_locked = 'Y' THEN true WHEN NEW.is_token_locked = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.token_unlock_time IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('token_unlock_time'));
		_vq := array_append(_vq, quote_nullable(NEW.token_unlock_time));
	END IF;

	IF NEW.bad_logins IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('bad_logins'));
		_vq := array_append(_vq, quote_nullable(NEW.bad_logins));
	END IF;

	IF NEW.last_updated IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('last_updated'));
		_vq := array_append(_vq, quote_nullable(NEW.last_updated));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.token (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.token_id = _nr.token_id;
	NEW.token_type = _nr.token_type;
	NEW.token_status = _nr.token_status;
	NEW.description = _nr.description;
	NEW.external_id = _nr.external_id;
	NEW.token_serial = _nr.token_serial;
	NEW.zero_time = _nr.zero_time;
	NEW.time_modulo = _nr.time_modulo;
	NEW.time_skew = _nr.time_skew;
	NEW.token_key = _nr.token_key;
	NEW.encryption_key_id = _nr.encryption_key_id;
	NEW.token_password = _nr.token_password;
	NEW.expire_time = _nr.expire_time;
	NEW.is_token_locked = CASE WHEN _nr.is_token_locked = true THEN 'Y' WHEN _nr.is_token_locked = false THEN 'N' ELSE NULL END;
	NEW.token_unlock_time = _nr.token_unlock_time;
	NEW.bad_logins = _nr.bad_logins;
	NEW.last_updated = _nr.last_updated;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_token_ins
	ON jazzhands_legacy.token;
CREATE TRIGGER trigger_token_ins
	INSTEAD OF INSERT ON jazzhands_legacy.token
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.token_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.token_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.token%rowtype;
	_nr	jazzhands.token%rowtype;
	_uq	text[];
BEGIN

	IF OLD.token_id IS DISTINCT FROM NEW.token_id THEN
_uq := array_append(_uq, 'token_id = ' || quote_nullable(NEW.token_id));
	END IF;

	IF OLD.token_type IS DISTINCT FROM NEW.token_type THEN
_uq := array_append(_uq, 'token_type = ' || quote_nullable(NEW.token_type));
	END IF;

	IF OLD.token_status IS DISTINCT FROM NEW.token_status THEN
_uq := array_append(_uq, 'token_status = ' || quote_nullable(NEW.token_status));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.external_id IS DISTINCT FROM NEW.external_id THEN
_uq := array_append(_uq, 'external_id = ' || quote_nullable(NEW.external_id));
	END IF;

	IF OLD.token_serial IS DISTINCT FROM NEW.token_serial THEN
_uq := array_append(_uq, 'token_serial = ' || quote_nullable(NEW.token_serial));
	END IF;

	IF OLD.zero_time IS DISTINCT FROM NEW.zero_time THEN
_uq := array_append(_uq, 'zero_time = ' || quote_nullable(NEW.zero_time));
	END IF;

	IF OLD.time_modulo IS DISTINCT FROM NEW.time_modulo THEN
_uq := array_append(_uq, 'time_modulo = ' || quote_nullable(NEW.time_modulo));
	END IF;

	IF OLD.time_skew IS DISTINCT FROM NEW.time_skew THEN
_uq := array_append(_uq, 'time_skew = ' || quote_nullable(NEW.time_skew));
	END IF;

	IF OLD.token_key IS DISTINCT FROM NEW.token_key THEN
_uq := array_append(_uq, 'token_key = ' || quote_nullable(NEW.token_key));
	END IF;

	IF OLD.encryption_key_id IS DISTINCT FROM NEW.encryption_key_id THEN
_uq := array_append(_uq, 'encryption_key_id = ' || quote_nullable(NEW.encryption_key_id));
	END IF;

	IF OLD.token_password IS DISTINCT FROM NEW.token_password THEN
_uq := array_append(_uq, 'token_password = ' || quote_nullable(NEW.token_password));
	END IF;

	IF OLD.expire_time IS DISTINCT FROM NEW.expire_time THEN
_uq := array_append(_uq, 'expire_time = ' || quote_nullable(NEW.expire_time));
	END IF;

	IF OLD.is_token_locked IS DISTINCT FROM NEW.is_token_locked THEN
IF NEW.is_token_locked = 'Y' THEN
	_uq := array_append(_uq, 'is_token_locked = true');
ELSIF NEW.is_token_locked = 'N' THEN
	_uq := array_append(_uq, 'is_token_locked = false');
ELSE
	_uq := array_append(_uq, 'is_token_locked = NULL');
END IF;
	END IF;

	IF OLD.token_unlock_time IS DISTINCT FROM NEW.token_unlock_time THEN
_uq := array_append(_uq, 'token_unlock_time = ' || quote_nullable(NEW.token_unlock_time));
	END IF;

	IF OLD.bad_logins IS DISTINCT FROM NEW.bad_logins THEN
_uq := array_append(_uq, 'bad_logins = ' || quote_nullable(NEW.bad_logins));
	END IF;

	IF OLD.last_updated IS DISTINCT FROM NEW.last_updated THEN
_uq := array_append(_uq, 'last_updated = ' || quote_nullable(NEW.last_updated));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.token SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  token_id = $1 RETURNING *'  USING OLD.token_id
			INTO _nr;

		NEW.token_id = _nr.token_id;
		NEW.token_type = _nr.token_type;
		NEW.token_status = _nr.token_status;
		NEW.description = _nr.description;
		NEW.external_id = _nr.external_id;
		NEW.token_serial = _nr.token_serial;
		NEW.zero_time = _nr.zero_time;
		NEW.time_modulo = _nr.time_modulo;
		NEW.time_skew = _nr.time_skew;
		NEW.token_key = _nr.token_key;
		NEW.encryption_key_id = _nr.encryption_key_id;
		NEW.token_password = _nr.token_password;
		NEW.expire_time = _nr.expire_time;
		NEW.is_token_locked = CASE WHEN _nr.is_token_locked = true THEN 'Y' WHEN _nr.is_token_locked = false THEN 'N' ELSE NULL END;
		NEW.token_unlock_time = _nr.token_unlock_time;
		NEW.bad_logins = _nr.bad_logins;
		NEW.last_updated = _nr.last_updated;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_token_upd
	ON jazzhands_legacy.token;
CREATE TRIGGER trigger_token_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.token
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.token_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.token_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.token%rowtype;
BEGIN
	DELETE FROM jazzhands.token
	WHERE  token_id = OLD.token_id  RETURNING *
	INTO _or;
	OLD.token_id = _or.token_id;
	OLD.token_type = _or.token_type;
	OLD.token_status = _or.token_status;
	OLD.description = _or.description;
	OLD.external_id = _or.external_id;
	OLD.token_serial = _or.token_serial;
	OLD.zero_time = _or.zero_time;
	OLD.time_modulo = _or.time_modulo;
	OLD.time_skew = _or.time_skew;
	OLD.token_key = _or.token_key;
	OLD.encryption_key_id = _or.encryption_key_id;
	OLD.token_password = _or.token_password;
	OLD.expire_time = _or.expire_time;
	OLD.is_token_locked = CASE WHEN _or.is_token_locked = true THEN 'Y' WHEN _or.is_token_locked = false THEN 'N' ELSE NULL END;
	OLD.token_unlock_time = _or.token_unlock_time;
	OLD.bad_logins = _or.bad_logins;
	OLD.last_updated = _or.last_updated;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_token_del
	ON jazzhands_legacy.token;
CREATE TRIGGER trigger_token_del
	INSTEAD OF DELETE ON jazzhands_legacy.token
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.token_del();


-- Triggers for v_corp_family_account

CREATE OR REPLACE FUNCTION jazzhands_legacy.v_corp_family_account_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.v_corp_family_account%rowtype;
BEGIN

	IF NEW.account_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('account_id'));
		_vq := array_append(_vq, quote_nullable(NEW.account_id));
	END IF;

	IF NEW.login IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('login'));
		_vq := array_append(_vq, quote_nullable(NEW.login));
	END IF;

	IF NEW.person_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('person_id'));
		_vq := array_append(_vq, quote_nullable(NEW.person_id));
	END IF;

	IF NEW.company_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('company_id'));
		_vq := array_append(_vq, quote_nullable(NEW.company_id));
	END IF;

	IF NEW.account_realm_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('account_realm_id'));
		_vq := array_append(_vq, quote_nullable(NEW.account_realm_id));
	END IF;

	IF NEW.account_status IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('account_status'));
		_vq := array_append(_vq, quote_nullable(NEW.account_status));
	END IF;

	IF NEW.account_role IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('account_role'));
		_vq := array_append(_vq, quote_nullable(NEW.account_role));
	END IF;

	IF NEW.account_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('account_type'));
		_vq := array_append(_vq, quote_nullable(NEW.account_type));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.is_enabled IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_enabled'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_enabled = 'Y' THEN true WHEN NEW.is_enabled = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.v_corp_family_account (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.account_id = _nr.account_id;
	NEW.login = _nr.login;
	NEW.person_id = _nr.person_id;
	NEW.company_id = _nr.company_id;
	NEW.account_realm_id = _nr.account_realm_id;
	NEW.account_status = _nr.account_status;
	NEW.account_role = _nr.account_role;
	NEW.account_type = _nr.account_type;
	NEW.description = _nr.description;
	NEW.is_enabled = CASE WHEN _nr.is_enabled = true THEN 'Y' WHEN _nr.is_enabled = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_v_corp_family_account_ins
	ON jazzhands_legacy.v_corp_family_account;
CREATE TRIGGER trigger_v_corp_family_account_ins
	INSTEAD OF INSERT ON jazzhands_legacy.v_corp_family_account
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.v_corp_family_account_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.v_corp_family_account_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.v_corp_family_account%rowtype;
	_nr	jazzhands.v_corp_family_account%rowtype;
	_uq	text[];
BEGIN

	IF OLD.account_id IS DISTINCT FROM NEW.account_id THEN
_uq := array_append(_uq, 'account_id = ' || quote_nullable(NEW.account_id));
	END IF;

	IF OLD.login IS DISTINCT FROM NEW.login THEN
_uq := array_append(_uq, 'login = ' || quote_nullable(NEW.login));
	END IF;

	IF OLD.person_id IS DISTINCT FROM NEW.person_id THEN
_uq := array_append(_uq, 'person_id = ' || quote_nullable(NEW.person_id));
	END IF;

	IF OLD.company_id IS DISTINCT FROM NEW.company_id THEN
_uq := array_append(_uq, 'company_id = ' || quote_nullable(NEW.company_id));
	END IF;

	IF OLD.account_realm_id IS DISTINCT FROM NEW.account_realm_id THEN
_uq := array_append(_uq, 'account_realm_id = ' || quote_nullable(NEW.account_realm_id));
	END IF;

	IF OLD.account_status IS DISTINCT FROM NEW.account_status THEN
_uq := array_append(_uq, 'account_status = ' || quote_nullable(NEW.account_status));
	END IF;

	IF OLD.account_role IS DISTINCT FROM NEW.account_role THEN
_uq := array_append(_uq, 'account_role = ' || quote_nullable(NEW.account_role));
	END IF;

	IF OLD.account_type IS DISTINCT FROM NEW.account_type THEN
_uq := array_append(_uq, 'account_type = ' || quote_nullable(NEW.account_type));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.is_enabled IS DISTINCT FROM NEW.is_enabled THEN
IF NEW.is_enabled = 'Y' THEN
	_uq := array_append(_uq, 'is_enabled = true');
ELSIF NEW.is_enabled = 'N' THEN
	_uq := array_append(_uq, 'is_enabled = false');
ELSE
	_uq := array_append(_uq, 'is_enabled = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.v_corp_family_account SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  account_id = $1 RETURNING *'  USING OLD.account_id
			INTO _nr;

		NEW.account_id = _nr.account_id;
		NEW.login = _nr.login;
		NEW.person_id = _nr.person_id;
		NEW.company_id = _nr.company_id;
		NEW.account_realm_id = _nr.account_realm_id;
		NEW.account_status = _nr.account_status;
		NEW.account_role = _nr.account_role;
		NEW.account_type = _nr.account_type;
		NEW.description = _nr.description;
		NEW.is_enabled = CASE WHEN _nr.is_enabled = true THEN 'Y' WHEN _nr.is_enabled = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_v_corp_family_account_upd
	ON jazzhands_legacy.v_corp_family_account;
CREATE TRIGGER trigger_v_corp_family_account_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.v_corp_family_account
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.v_corp_family_account_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.v_corp_family_account_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.v_corp_family_account%rowtype;
BEGIN
	DELETE FROM jazzhands.v_corp_family_account
	WHERE  account_id = OLD.account_id  RETURNING *
	INTO _or;
	OLD.account_id = _or.account_id;
	OLD.login = _or.login;
	OLD.person_id = _or.person_id;
	OLD.company_id = _or.company_id;
	OLD.account_realm_id = _or.account_realm_id;
	OLD.account_status = _or.account_status;
	OLD.account_role = _or.account_role;
	OLD.account_type = _or.account_type;
	OLD.description = _or.description;
	OLD.is_enabled = CASE WHEN _or.is_enabled = true THEN 'Y' WHEN _or.is_enabled = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_v_corp_family_account_del
	ON jazzhands_legacy.v_corp_family_account;
CREATE TRIGGER trigger_v_corp_family_account_del
	INSTEAD OF DELETE ON jazzhands_legacy.v_corp_family_account
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.v_corp_family_account_del();


-- Triggers for v_dns_domain_nouniverse

CREATE OR REPLACE FUNCTION jazzhands_legacy.v_dns_domain_nouniverse_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_d	jazzhands.dns_domain%rowtype;
	_du	jazzhands.dns_domain_ip_universe%rowtype;
BEGIN
	IF NEW.dns_domain_id IS NULL THEN
		INSERT INTO jazzhands.dns_domain (
			dns_domain_name, dns_domain_type, parent_dns_domain_id
		) VALUES (
			NEW.soa_name, NEW.dns_domain_type, NEW.parent_dns_domain_id
		) RETURNING * INTO _d;
	ELSE
		INSERT INTO jazzhands.dns_domain (
			dns_domain_id, dns_domain_name, dns_domain_type,
			parent_dns_domain_id
		) VALUES (
			NEW.dns_domain_id, NEW.soa_name, NEW.dns_domain_type,
			NEW.parent_dns_domain_id
		) RETURNING * INTO _d;
	END IF;

	INSERT INTO dns_domain_ip_universe (
		dns_domain_id, ip_universe_id,
		soa_class, soa_ttl, soa_serial, soa_refresh,
		soa_retry,
		soa_expire, soa_minimum, soa_mname, soa_rname,
		should_generate,
		last_generated
	) VALUES (
		_d.dns_domain_id, 0,
		NEW.soa_class, NEW.soa_ttl, NEW.soa_serial, NEW.soa_refresh,
		NEW.soa_retry,
		NEW.soa_expire, NEW.soa_minimum, NEW.soa_mname, NEW.soa_rname,
		CASE WHEN NEW.should_generate = 'Y' THEN true
			WHEN NEW.should_generate = 'N' THEN false
			ELSE NULL
			END,
		NEW.last_generated
	) RETURNING * INTO _du;

	NEW.dns_domain_id = _d.dns_domain_id;
	NEW.soa_name = _d.dns_domain_name;
	NEW.soa_class = _du.soa_class;
	NEW.soa_ttl = _du.soa_ttl;
	NEW.soa_serial = _du.soa_serial;
	NEW.soa_refresh = _du.soa_refresh;
	NEW.soa_retry = _du.soa_retry;
	NEW.soa_expire = _du.soa_expire;
	NEW.soa_minimum = _du.soa_minimum;
	NEW.soa_mname = _du.soa_mname;
	NEW.soa_rname = _du.soa_rname;
	NEW.parent_dns_domain_id = _d.parent_dns_domain_id;
	NEW.should_generate = CASE WHEN _du.should_generate = true THEN 'Y' WHEN _du.should_generate = false THEN 'N' ELSE NULL END;
	NEW.last_generated = _du.last_generated;
	NEW.dns_domain_type = _d.dns_domain_type;

	NEW.data_ins_user = coalesce(_d.data_ins_user, _du.data_ins_user);
	NEW.data_ins_date = coalesce(_d.data_ins_date, _du.data_ins_date);
	NEW.data_upd_user = coalesce(_du.data_upd_user, _d.data_upd_user);
	NEW.data_upd_date = coalesce(_du.data_upd_date, _d.data_upd_date);
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_v_dns_domain_nouniverse_ins
	ON jazzhands_legacy.v_dns_domain_nouniverse;
CREATE TRIGGER trigger_v_dns_domain_nouniverse_ins
	INSTEAD OF INSERT ON jazzhands_legacy.v_dns_domain_nouniverse
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.v_dns_domain_nouniverse_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.v_dns_domain_nouniverse_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_d		jazzhands.dns_domain%rowtype;
	_du		jazzhands.dns_domain_ip_universe%rowtype;
	_duq	text[];
	_uq		text[];
BEGIN

	IF OLD.dns_domain_id IS DISTINCT FROM NEW.dns_domain_id THEN
		RAISE EXCEPTION 'Can not change dns_domain_id'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF OLD.soa_name IS DISTINCT FROM NEW.soa_name THEN
		_duq := array_append(_duq, 'dns_domain_name = ' || quote_nullable(NEW.soa_name));
	END IF;

	IF OLD.parent_dns_domain_id IS DISTINCT FROM NEW.parent_dns_domain_id THEN
		_duq := array_append(_duq, 'parent_dns_domain_id = ' || quote_nullable(NEW.parent_dns_domain_id));
	END IF;

	IF OLD.dns_domain_type IS DISTINCT FROM NEW.dns_domain_type THEN
		_duq := array_append(_duq, 'dns_domain_type = ' || quote_nullable(NEW.dns_domain_type));
	END IF;

	--

	IF OLD.soa_class IS DISTINCT FROM NEW.soa_class THEN
		_uq := array_append(_uq, 'soa_class = ' || quote_nullable(NEW.soa_class));
	END IF;

	IF OLD.soa_ttl IS DISTINCT FROM NEW.soa_ttl THEN
		_uq := array_append(_uq, 'soa_ttl = ' || quote_nullable(NEW.soa_ttl));
	END IF;

	IF OLD.soa_serial IS DISTINCT FROM NEW.soa_serial THEN
		_uq := array_append(_uq, 'soa_serial = ' || quote_nullable(NEW.soa_serial));
	END IF;

	IF OLD.soa_refresh IS DISTINCT FROM NEW.soa_refresh THEN
		_uq := array_append(_uq, 'soa_refresh = ' || quote_nullable(NEW.soa_refresh));
	END IF;

	IF OLD.soa_retry IS DISTINCT FROM NEW.soa_retry THEN
		_uq := array_append(_uq, 'soa_retry = ' || quote_nullable(NEW.soa_retry));
	END IF;

	IF OLD.soa_expire IS DISTINCT FROM NEW.soa_expire THEN
		_uq := array_append(_uq, 'soa_expire = ' || quote_nullable(NEW.soa_expire));
	END IF;

	IF OLD.soa_minimum IS DISTINCT FROM NEW.soa_minimum THEN
		_uq := array_append(_uq, 'soa_minimum = ' || quote_nullable(NEW.soa_minimum));
	END IF;

	IF OLD.soa_mname IS DISTINCT FROM NEW.soa_mname THEN
		_uq := array_append(_uq, 'soa_mname = ' || quote_nullable(NEW.soa_mname));
	END IF;

	IF OLD.soa_rname IS DISTINCT FROM NEW.soa_rname THEN
		_uq := array_append(_uq, 'soa_rname = ' || quote_nullable(NEW.soa_rname));
	END IF;

	IF OLD.should_generate IS DISTINCT FROM NEW.should_generate THEN
		IF NEW.should_generate = 'Y' THEN
			_uq := array_append(_uq, 'should_generate = true');
		ELSIF NEW.should_generate = 'N' THEN
			_uq := array_append(_uq, 'should_generate = false');
		ELSE
			_uq := array_append(_uq, 'should_generate = NULL');
		END IF;
	END IF;

	IF OLD.last_generated IS DISTINCT FROM NEW.last_generated THEN
		_uq := array_append(_uq, 'last_generated = ' || quote_nullable(NEW.last_generated));
	END IF;

	IF _duq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.dns_domain SET ' ||
			array_to_string(_duq, ', ') ||
			' WHERE  dns_domain_id = $1 RETURNING *'
			USING OLD.dns_domain_id
			INTO _d;

		NEW.dns_domain_id = _d.dns_domain_id;
		NEW.soa_name = _d.soa_name;
		NEW.dns_domain_type = _d.dns_domain_type;
		NEW.parent_dns_domain_id = _d.parent_dns_domain_id;
	ELSE
		SELECT * INTO _d  FROM jazzhands.dns_domain
		WHERE dns_domain_id = NEW.dns_domain_id;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.dns_domain_ip_universe SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  dns_domain_id = $1 AND ip_universe_id = 0 RETURNING *'
			USING OLD.dns_domain_id
			INTO _du;

		NEW.soa_class = _du.soa_class;
		NEW.soa_ttl = _du.soa_ttl;
		NEW.soa_serial = _du.soa_serial;
		NEW.soa_refresh = _du.soa_refresh;
		NEW.soa_retry = _du.soa_retry;
		NEW.soa_expire = _du.soa_expire;
		NEW.soa_minimum = _du.soa_minimum;
		NEW.soa_mname = _du.soa_mname;
		NEW.soa_rname = _du.soa_rname;
		NEW.should_generate = CASE WHEN _du.should_generate = true THEN 'Y' WHEN _du.should_generate = false THEN 'N' ELSE NULL END;
		NEW.last_generated = _du.last_generated;
	ELSE
		SELECT * INTO _du FROM jazzhands.dns_domain_ip_universe
			WHERE dns_domain_id = NEW.dns_domain_id
			AND ip_universe_id = 0;
	END IF;

	NEW.data_ins_user = coalesce(_d.data_ins_user, _du.data_ins_user);
	NEW.data_ins_date = coalesce(_d.data_ins_date, _du.data_ins_date);
	NEW.data_upd_user = coalesce(_du.data_upd_user, _d.data_upd_user);
	NEW.data_upd_date = coalesce(_du.data_upd_date, _d.data_upd_date);

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_v_dns_domain_nouniverse_upd
	ON jazzhands_legacy.v_dns_domain_nouniverse;
CREATE TRIGGER trigger_v_dns_domain_nouniverse_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.v_dns_domain_nouniverse
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.v_dns_domain_nouniverse_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.v_dns_domain_nouniverse_del()
RETURNS TRIGGER AS
$$
DECLARE
	_d		jazzhands.dns_domain%rowtype;
	_du		jazzhands.dns_domain_ip_universe%rowtype;
BEGIN
	DELETE FROM jazzhands.dns_domain_ip_universe
	WHERE  dns_domain_id = OLD.dns_domain_id
	AND ip_universe_id = 0
	RETURNING * INTO _du;

	DELETE FROM jazzhands.dns_domain
	WHERE  dns_domain_id = OLD.dns_domain_id
	RETURNING * INTO _d;

	OLD.dns_domain_id = _d.dns_domain_id;
	OLD.soa_name = _d.dns_domain_name;
	OLD.dns_domain_type = _d.dns_domain_type;
	OLD.parent_dns_domain_id = _d.parent_dns_domain_id;

	OLD.soa_class = _du.soa_class;
	OLD.soa_ttl = _du.soa_ttl;
	OLD.soa_serial = _du.soa_serial;
	OLD.soa_refresh = _du.soa_refresh;
	OLD.soa_retry = _du.soa_retry;
	OLD.soa_expire = _du.soa_expire;
	OLD.soa_minimum = _du.soa_minimum;
	OLD.soa_mname = _du.soa_mname;
	OLD.soa_rname = _du.soa_rname;
	OLD.should_generate = CASE WHEN _du.should_generate = true THEN 'Y' WHEN _du.should_generate = false THEN 'N' ELSE NULL END;
	OLD.last_generated = _du.last_generated;

	OLD.data_ins_user = coalesce(_d.data_ins_user, _du.data_ins_user);
	OLD.data_ins_date = coalesce(_d.data_ins_date, _du.data_ins_date);
	OLD.data_upd_user = coalesce(_du.data_upd_user, _d.data_upd_user);
	OLD.data_upd_date = coalesce(_du.data_upd_date, _d.data_upd_date);
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_v_dns_domain_nouniverse_del
	ON jazzhands_legacy.v_dns_domain_nouniverse;
CREATE TRIGGER trigger_v_dns_domain_nouniverse_del
	INSTEAD OF DELETE ON jazzhands_legacy.v_dns_domain_nouniverse
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.v_dns_domain_nouniverse_del();


-- Triggers for v_hotpants_token

CREATE OR REPLACE FUNCTION jazzhands_legacy.v_hotpants_token_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.v_hotpants_token%rowtype;
BEGIN

	IF NEW.token_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('token_id'));
		_vq := array_append(_vq, quote_nullable(NEW.token_id));
	END IF;

	IF NEW.token_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('token_type'));
		_vq := array_append(_vq, quote_nullable(NEW.token_type));
	END IF;

	IF NEW.token_status IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('token_status'));
		_vq := array_append(_vq, quote_nullable(NEW.token_status));
	END IF;

	IF NEW.token_serial IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('token_serial'));
		_vq := array_append(_vq, quote_nullable(NEW.token_serial));
	END IF;

	IF NEW.token_key IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('token_key'));
		_vq := array_append(_vq, quote_nullable(NEW.token_key));
	END IF;

	IF NEW.zero_time IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('zero_time'));
		_vq := array_append(_vq, quote_nullable(NEW.zero_time));
	END IF;

	IF NEW.time_modulo IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('time_modulo'));
		_vq := array_append(_vq, quote_nullable(NEW.time_modulo));
	END IF;

	IF NEW.token_password IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('token_password'));
		_vq := array_append(_vq, quote_nullable(NEW.token_password));
	END IF;

	IF NEW.is_token_locked IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_token_locked'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_token_locked = 'Y' THEN true WHEN NEW.is_token_locked = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.token_unlock_time IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('token_unlock_time'));
		_vq := array_append(_vq, quote_nullable(NEW.token_unlock_time));
	END IF;

	IF NEW.bad_logins IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('bad_logins'));
		_vq := array_append(_vq, quote_nullable(NEW.bad_logins));
	END IF;

	IF NEW.token_sequence IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('token_sequence'));
		_vq := array_append(_vq, quote_nullable(NEW.token_sequence));
	END IF;

	IF NEW.last_updated IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('last_updated'));
		_vq := array_append(_vq, quote_nullable(NEW.last_updated));
	END IF;

	IF NEW.encryption_key_db_value IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('encryption_key_db_value'));
		_vq := array_append(_vq, quote_nullable(NEW.encryption_key_db_value));
	END IF;

	IF NEW.encryption_key_purpose IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('encryption_key_purpose'));
		_vq := array_append(_vq, quote_nullable(NEW.encryption_key_purpose));
	END IF;

	IF NEW.encryption_key_purpose_version IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('encryption_key_purpose_version'));
		_vq := array_append(_vq, quote_nullable(NEW.encryption_key_purpose_version));
	END IF;

	IF NEW.encryption_method IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('encryption_method'));
		_vq := array_append(_vq, quote_nullable(NEW.encryption_method));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.v_hotpants_token (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.token_id = _nr.token_id;
	NEW.token_type = _nr.token_type;
	NEW.token_status = _nr.token_status;
	NEW.token_serial = _nr.token_serial;
	NEW.token_key = _nr.token_key;
	NEW.zero_time = _nr.zero_time;
	NEW.time_modulo = _nr.time_modulo;
	NEW.token_password = _nr.token_password;
	NEW.is_token_locked = CASE WHEN _nr.is_token_locked = true THEN 'Y' WHEN _nr.is_token_locked = false THEN 'N' ELSE NULL END;
	NEW.token_unlock_time = _nr.token_unlock_time;
	NEW.bad_logins = _nr.bad_logins;
	NEW.token_sequence = _nr.token_sequence;
	NEW.last_updated = _nr.last_updated;
	NEW.encryption_key_db_value = _nr.encryption_key_db_value;
	NEW.encryption_key_purpose = _nr.encryption_key_purpose;
	NEW.encryption_key_purpose_version = _nr.encryption_key_purpose_version;
	NEW.encryption_method = _nr.encryption_method;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_v_hotpants_token_ins
	ON jazzhands_legacy.v_hotpants_token;
CREATE TRIGGER trigger_v_hotpants_token_ins
	INSTEAD OF INSERT ON jazzhands_legacy.v_hotpants_token
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.v_hotpants_token_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.v_hotpants_token_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.v_hotpants_token%rowtype;
	_nr	jazzhands.v_hotpants_token%rowtype;
	_uq	text[];
BEGIN

	IF OLD.token_id IS DISTINCT FROM NEW.token_id THEN
_uq := array_append(_uq, 'token_id = ' || quote_nullable(NEW.token_id));
	END IF;

	IF OLD.token_type IS DISTINCT FROM NEW.token_type THEN
_uq := array_append(_uq, 'token_type = ' || quote_nullable(NEW.token_type));
	END IF;

	IF OLD.token_status IS DISTINCT FROM NEW.token_status THEN
_uq := array_append(_uq, 'token_status = ' || quote_nullable(NEW.token_status));
	END IF;

	IF OLD.token_serial IS DISTINCT FROM NEW.token_serial THEN
_uq := array_append(_uq, 'token_serial = ' || quote_nullable(NEW.token_serial));
	END IF;

	IF OLD.token_key IS DISTINCT FROM NEW.token_key THEN
_uq := array_append(_uq, 'token_key = ' || quote_nullable(NEW.token_key));
	END IF;

	IF OLD.zero_time IS DISTINCT FROM NEW.zero_time THEN
_uq := array_append(_uq, 'zero_time = ' || quote_nullable(NEW.zero_time));
	END IF;

	IF OLD.time_modulo IS DISTINCT FROM NEW.time_modulo THEN
_uq := array_append(_uq, 'time_modulo = ' || quote_nullable(NEW.time_modulo));
	END IF;

	IF OLD.token_password IS DISTINCT FROM NEW.token_password THEN
_uq := array_append(_uq, 'token_password = ' || quote_nullable(NEW.token_password));
	END IF;

	IF OLD.is_token_locked IS DISTINCT FROM NEW.is_token_locked THEN
IF NEW.is_token_locked = 'Y' THEN
	_uq := array_append(_uq, 'is_token_locked = true');
ELSIF NEW.is_token_locked = 'N' THEN
	_uq := array_append(_uq, 'is_token_locked = false');
ELSE
	_uq := array_append(_uq, 'is_token_locked = NULL');
END IF;
	END IF;

	IF OLD.token_unlock_time IS DISTINCT FROM NEW.token_unlock_time THEN
_uq := array_append(_uq, 'token_unlock_time = ' || quote_nullable(NEW.token_unlock_time));
	END IF;

	IF OLD.bad_logins IS DISTINCT FROM NEW.bad_logins THEN
_uq := array_append(_uq, 'bad_logins = ' || quote_nullable(NEW.bad_logins));
	END IF;

	IF OLD.token_sequence IS DISTINCT FROM NEW.token_sequence THEN
_uq := array_append(_uq, 'token_sequence = ' || quote_nullable(NEW.token_sequence));
	END IF;

	IF OLD.last_updated IS DISTINCT FROM NEW.last_updated THEN
_uq := array_append(_uq, 'last_updated = ' || quote_nullable(NEW.last_updated));
	END IF;

	IF OLD.encryption_key_db_value IS DISTINCT FROM NEW.encryption_key_db_value THEN
_uq := array_append(_uq, 'encryption_key_db_value = ' || quote_nullable(NEW.encryption_key_db_value));
	END IF;

	IF OLD.encryption_key_purpose IS DISTINCT FROM NEW.encryption_key_purpose THEN
_uq := array_append(_uq, 'encryption_key_purpose = ' || quote_nullable(NEW.encryption_key_purpose));
	END IF;

	IF OLD.encryption_key_purpose_version IS DISTINCT FROM NEW.encryption_key_purpose_version THEN
_uq := array_append(_uq, 'encryption_key_purpose_version = ' || quote_nullable(NEW.encryption_key_purpose_version));
	END IF;

	IF OLD.encryption_method IS DISTINCT FROM NEW.encryption_method THEN
_uq := array_append(_uq, 'encryption_method = ' || quote_nullable(NEW.encryption_method));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.v_hotpants_token SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  token_id = $1 RETURNING *'  USING OLD.token_id
			INTO _nr;

		NEW.token_id = _nr.token_id;
		NEW.token_type = _nr.token_type;
		NEW.token_status = _nr.token_status;
		NEW.token_serial = _nr.token_serial;
		NEW.token_key = _nr.token_key;
		NEW.zero_time = _nr.zero_time;
		NEW.time_modulo = _nr.time_modulo;
		NEW.token_password = _nr.token_password;
		NEW.is_token_locked = CASE WHEN _nr.is_token_locked = true THEN 'Y' WHEN _nr.is_token_locked = false THEN 'N' ELSE NULL END;
		NEW.token_unlock_time = _nr.token_unlock_time;
		NEW.bad_logins = _nr.bad_logins;
		NEW.token_sequence = _nr.token_sequence;
		NEW.last_updated = _nr.last_updated;
		NEW.encryption_key_db_value = _nr.encryption_key_db_value;
		NEW.encryption_key_purpose = _nr.encryption_key_purpose;
		NEW.encryption_key_purpose_version = _nr.encryption_key_purpose_version;
		NEW.encryption_method = _nr.encryption_method;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_v_hotpants_token_upd
	ON jazzhands_legacy.v_hotpants_token;
CREATE TRIGGER trigger_v_hotpants_token_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.v_hotpants_token
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.v_hotpants_token_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.v_hotpants_token_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.v_hotpants_token%rowtype;
BEGIN
	DELETE FROM jazzhands.v_hotpants_token
	WHERE  token_id = OLD.token_id  RETURNING *
	INTO _or;
	OLD.token_id = _or.token_id;
	OLD.token_type = _or.token_type;
	OLD.token_status = _or.token_status;
	OLD.token_serial = _or.token_serial;
	OLD.token_key = _or.token_key;
	OLD.zero_time = _or.zero_time;
	OLD.time_modulo = _or.time_modulo;
	OLD.token_password = _or.token_password;
	OLD.is_token_locked = CASE WHEN _or.is_token_locked = true THEN 'Y' WHEN _or.is_token_locked = false THEN 'N' ELSE NULL END;
	OLD.token_unlock_time = _or.token_unlock_time;
	OLD.bad_logins = _or.bad_logins;
	OLD.token_sequence = _or.token_sequence;
	OLD.last_updated = _or.last_updated;
	OLD.encryption_key_db_value = _or.encryption_key_db_value;
	OLD.encryption_key_purpose = _or.encryption_key_purpose;
	OLD.encryption_key_purpose_version = _or.encryption_key_purpose_version;
	OLD.encryption_method = _or.encryption_method;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_v_hotpants_token_del
	ON jazzhands_legacy.v_hotpants_token;
CREATE TRIGGER trigger_v_hotpants_token_del
	INSTEAD OF DELETE ON jazzhands_legacy.v_hotpants_token
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.v_hotpants_token_del();


-- Triggers for v_person_company

CREATE OR REPLACE FUNCTION jazzhands_legacy.v_person_company_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.person_company%rowtype;
BEGIN

	IF NEW.company_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('company_id'));
		_vq := array_append(_vq, quote_nullable(NEW.company_id));
	END IF;

	IF NEW.person_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('person_id'));
		_vq := array_append(_vq, quote_nullable(NEW.person_id));
	END IF;

	IF NEW.person_company_status IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('person_company_status'));
		_vq := array_append(_vq, quote_nullable(NEW.person_company_status));
	END IF;

	IF NEW.person_company_relation IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('person_company_relation'));
		_vq := array_append(_vq, quote_nullable(NEW.person_company_relation));
	END IF;

	IF NEW.is_exempt IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_exempt'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_exempt = 'Y' THEN true WHEN NEW.is_exempt = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.is_management IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_management'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_management = 'Y' THEN true WHEN NEW.is_management = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.is_full_time IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_full_time'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_full_time = 'Y' THEN true WHEN NEW.is_full_time = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.position_title IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('position_title'));
		_vq := array_append(_vq, quote_nullable(NEW.position_title));
	END IF;

	IF NEW.hire_date IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('hire_date'));
		_vq := array_append(_vq, quote_nullable(NEW.hire_date));
	END IF;

	IF NEW.termination_date IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('termination_date'));
		_vq := array_append(_vq, quote_nullable(NEW.termination_date));
	END IF;

	IF NEW.manager_person_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('manager_person_id'));
		_vq := array_append(_vq, quote_nullable(NEW.manager_person_id));
	END IF;

	IF NEW.nickname IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('nickname'));
		_vq := array_append(_vq, quote_nullable(NEW.nickname));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.person_company (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	--
	-- These are the backwards compatability columns no longer in jazzhands.
	--

	IF NEW.employee_id IS NOT NULL THEN
		INSERT INTO jazzhands.person_company_attribute (
			company_id, person_id, person_company_attribute_name,
			attribute_value
		) VALUES  (
			NEW.company_id, NEW.person_id, 'employee_id',
			NEW.employee_id
		) RETURNING attribute_value INTO NEW.employee_id;
	END IF;

	IF NEW.payroll_id IS NOT NULL THEN
		INSERT INTO jazzhands.person_company_attribute (
			company_id, person_id, person_company_attribute_name,
			attribute_value
		) VALUES  (
			NEW.company_id, NEW.person_id, 'payroll_id',
			NEW.payroll_id
		) RETURNING attribute_value INTO NEW.payroll_id;
	END IF;

	IF NEW.external_hr_id IS NOT NULL THEN
		INSERT INTO jazzhands.person_company_attribute (
			company_id, person_id, person_company_attribute_name,
			attribute_value
		) VALUES  (
			NEW.company_id, NEW.person_id, 'external_hr_id',
			NEW.external_hr_id
		) RETURNING attribute_value INTO NEW.external_hr_id;
	END IF;

	IF NEW.badge_system_id IS NOT NULL THEN
		INSERT INTO jazzhands.person_company_attribute (
			company_id, person_id, person_company_attribute_name,
			attribute_value
		) VALUES  (
			NEW.company_id, NEW.person_id, 'badge_system_id',
			NEW.badge_system_id
		) RETURNING attribute_value INTO NEW.badge_system_id;
	END IF;

	IF NEW.supervisor_person_id IS NOT NULL THEN
		INSERT INTO jazzhands.person_company_attribute (
			company_id, person_id, person_company_attribute_name,
			attribute_value_person_id
		) VALUES  (
			NEW.company_id, NEW.person_id, 'supervisor_person_id',
			NEW.attribute_value_person_id
		) RETURNING attribute_value_person_id INTO NEW.supervisor_person_id;
	END IF;

	--
	-- End of backwards compatability columns no longer in jazzhands
	--

	NEW.company_id = _nr.company_id;
	NEW.person_id = _nr.person_id;
	NEW.person_company_status = _nr.person_company_status;
	NEW.person_company_relation = _nr.person_company_relation;
	NEW.is_exempt = CASE WHEN _nr.is_exempt = true THEN 'Y' WHEN _nr.is_exempt = false THEN 'N' ELSE NULL END;
	NEW.is_management = CASE WHEN _nr.is_management = true THEN 'Y' WHEN _nr.is_management = false THEN 'N' ELSE NULL END;
	NEW.is_full_time = CASE WHEN _nr.is_full_time = true THEN 'Y' WHEN _nr.is_full_time = false THEN 'N' ELSE NULL END;
	NEW.description = _nr.description;
	NEW.position_title = _nr.position_title;
	NEW.hire_date = _nr.hire_date;
	NEW.termination_date = _nr.termination_date;
	NEW.manager_person_id = _nr.manager_person_id;
	NEW.nickname = _nr.nickname;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_v_person_company_ins
	ON jazzhands_legacy.v_person_company;
CREATE TRIGGER trigger_v_person_company_ins
	INSTEAD OF INSERT ON jazzhands_legacy.v_person_company
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.v_person_company_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.v_person_company_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.v_person_company%rowtype;
	_nr	jazzhands.person_company%rowtype;
	_uq	text[];
BEGIN

	IF OLD.company_id IS DISTINCT FROM NEW.company_id THEN
_uq := array_append(_uq, 'company_id = ' || quote_nullable(NEW.company_id));
	END IF;

	IF OLD.person_id IS DISTINCT FROM NEW.person_id THEN
_uq := array_append(_uq, 'person_id = ' || quote_nullable(NEW.person_id));
	END IF;

	IF OLD.person_company_status IS DISTINCT FROM NEW.person_company_status THEN
_uq := array_append(_uq, 'person_company_status = ' || quote_nullable(NEW.person_company_status));
	END IF;

	IF OLD.person_company_relation IS DISTINCT FROM NEW.person_company_relation THEN
_uq := array_append(_uq, 'person_company_relation = ' || quote_nullable(NEW.person_company_relation));
	END IF;

	IF OLD.is_exempt IS DISTINCT FROM NEW.is_exempt THEN
IF NEW.is_exempt = 'Y' THEN
	_uq := array_append(_uq, 'is_exempt = true');
ELSIF NEW.is_exempt = 'N' THEN
	_uq := array_append(_uq, 'is_exempt = false');
ELSE
	_uq := array_append(_uq, 'is_exempt = NULL');
END IF;
	END IF;

	IF OLD.is_management IS DISTINCT FROM NEW.is_management THEN
IF NEW.is_management = 'Y' THEN
	_uq := array_append(_uq, 'is_management = true');
ELSIF NEW.is_management = 'N' THEN
	_uq := array_append(_uq, 'is_management = false');
ELSE
	_uq := array_append(_uq, 'is_management = NULL');
END IF;
	END IF;

	IF OLD.is_full_time IS DISTINCT FROM NEW.is_full_time THEN
IF NEW.is_full_time = 'Y' THEN
	_uq := array_append(_uq, 'is_full_time = true');
ELSIF NEW.is_full_time = 'N' THEN
	_uq := array_append(_uq, 'is_full_time = false');
ELSE
	_uq := array_append(_uq, 'is_full_time = NULL');
END IF;
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.position_title IS DISTINCT FROM NEW.position_title THEN
_uq := array_append(_uq, 'position_title = ' || quote_nullable(NEW.position_title));
	END IF;

	IF OLD.hire_date IS DISTINCT FROM NEW.hire_date THEN
_uq := array_append(_uq, 'hire_date = ' || quote_nullable(NEW.hire_date));
	END IF;

	IF OLD.termination_date IS DISTINCT FROM NEW.termination_date THEN
_uq := array_append(_uq, 'termination_date = ' || quote_nullable(NEW.termination_date));
	END IF;

	IF OLD.manager_person_id IS DISTINCT FROM NEW.manager_person_id THEN
_uq := array_append(_uq, 'manager_person_id = ' || quote_nullable(NEW.manager_person_id));
	END IF;

	IF OLD.nickname IS DISTINCT FROM NEW.nickname THEN
_uq := array_append(_uq, 'nickname = ' || quote_nullable(NEW.nickname));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.person_company SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  person_id = $1 AND  company_id = $2 RETURNING *'  USING OLD.person_id, OLD.company_id
			INTO _nr;

		NEW.company_id = _nr.company_id;
		NEW.person_id = _nr.person_id;
		NEW.person_company_status = _nr.person_company_status;
		NEW.person_company_relation = _nr.person_company_relation;
		NEW.is_exempt = CASE WHEN _nr.is_exempt = true THEN 'Y' WHEN _nr.is_exempt = false THEN 'N' ELSE NULL END;
		NEW.is_management = CASE WHEN _nr.is_management = true THEN 'Y' WHEN _nr.is_management = false THEN 'N' ELSE NULL END;
		NEW.is_full_time = CASE WHEN _nr.is_full_time = true THEN 'Y' WHEN _nr.is_full_time = false THEN 'N' ELSE NULL END;
		NEW.description = _nr.description;
		NEW.position_title = _nr.position_title;
		NEW.hire_date = _nr.hire_date;
		NEW.termination_date = _nr.termination_date;
		NEW.manager_person_id = _nr.manager_person_id;
		NEW.nickname = _nr.nickname;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;

       IF NEW.employee_id IS NOT NULL AND OLD.employee_id IS DISTINCT FROM NEW.employee_id  THEN
		INSERT INTO jazzhands.person_company_attribute AS pca (
			company_id, person_id, person_company_attribute_name, attribute_value
		) VALUES (
			NEW.company_id, NEW.person_id, 'employee_id', NEW.employee_id
		) ON CONFLICT ON CONSTRAINT pk_person_company_attribute
		DO UPDATE
			SET     attribute_value = NEW.employee_id
			WHERE pca.person_company_attribute_name = 'employee_id'
			AND pca.person_id = NEW.person_id
			AND pca.company_id = NEW.company_id
		RETURNING attribute_value INTO NEW.employee_id;

	END IF;

	IF NEW.payroll_id IS NOT NULL AND OLD.payroll_id IS DISTINCT FROM NEW.payroll_id THEN
		INSERT INTO jazzhands.person_company_attribute AS pca (
			company_id, person_id, person_company_attribute_name, attribute_value
		) VALUES (
			NEW.company_id, NEW.person_id, 'payroll_id', NEW.payroll_id
		) ON CONFLICT ON CONSTRAINT pk_person_company_attribute
		DO
			UPDATE
			SET     attribute_value = NEW.payroll_id
			WHERE pca.person_company_attribute_name = 'payroll_id'
			AND pca.person_id = NEW.person_id
			AND pca.company_id = NEW.company_id
		RETURNING attribute_value INTO NEW.payroll_id;
	END IF;

	IF NEW.external_hr_id IS NOT NULL AND OLD.external_hr_id IS DISTINCT FROM NEW.external_hr_id THEN
		INSERT INTO jazzhands.person_company_attribute AS pca (
			company_id, person_id, person_company_attribute_name, attribute_value
		) VALUES (
			NEW.company_id, NEW.person_id, 'external_hr_id', NEW.external_hr_id
		) ON CONFLICT ON CONSTRAINT pk_person_company_attribute
		DO
			UPDATE
			SET     attribute_value = NEW.external_hr_id
			WHERE pca.person_company_attribute_name = 'external_hr_id'
			AND pca.person_id = NEW.person_id
			AND pca.company_id = NEW.company_id
		RETURNING attribute_value INTO NEW.external_hr_id;
	END IF;

	IF NEW.badge_system_id IS NOT NULL AND OLD.badge_system_id IS DISTINCT FROM NEW.badge_system_id THEN
		INSERT INTO jazzhands.person_company_attribute AS pca (
			company_id, person_id, person_company_attribute_name, attribute_value
		) VALUES (
			NEW.company_id, NEW.person_id, 'badge_system_id', NEW.badge_system_id
		) ON CONFLICT ON CONSTRAINT pk_person_company_attribute
		DO
			UPDATE
			SET     attribute_value = NEW.badge_system_id
			WHERE pca.person_company_attribute_name = 'badge_system_id'
			AND pca.person_id = NEW.person_id
			AND pca.company_id = NEW.company_id
		RETURNING attribute_value INTO NEW.badge_system_id;
	END IF;

	IF NEW.supervisor_person_id IS NOT NULL AND OLD.supervisor_person_id IS DISTINCT FROM NEW.supervisor_person_id THEN
		INSERT INTO jazzhands.person_company_attribute AS pca (
			company_id, person_id, person_company_attribute_name, attribute_value
		) VALUES (
			NEW.company_id, NEW.person_id, 'supervisor__id', NEW.supervisor_person_id
		) ON CONFLICT ON CONSTRAINT pk_person_company_attribute
		DO
			UPDATE
			SET     attribute_value = NEW.supervisor_person_id
			WHERE pca.person_company_attribute_name = 'supervisor_id'
			AND pca.person_id = NEW.person_id
			AND pca.company_id = NEW.company_id
		RETURNING attribute_value_person_id INTO NEW.supervisor_person_id;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_v_person_company_upd
	ON jazzhands_legacy.v_person_company;
CREATE TRIGGER trigger_v_person_company_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.v_person_company
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.v_person_company_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.v_person_company_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.person_company%rowtype;
BEGIN

	DELETE FROM person_company_attribute
	WHERE person_id = OLD.person_id
	AND company_id = OLD.company_id
	AND person_company_attribute_name = 'employee_id'
	RETURNING attribute_value INTO OLD.employee_id;

	DELETE FROM person_company_attribute
	WHERE person_id = OLD.person_id
	AND company_id = OLD.company_id
	AND person_company_attribute_name = 'payroll_id'
	RETURNING attribute_value INTO OLD.payroll_id;

	DELETE FROM person_company_attribute
	WHERE person_id = OLD.person_id
	AND company_id = OLD.company_id
	AND person_company_attribute_name = 'external_hr_id'
	RETURNING attribute_value INTO OLD.external_hr_id;

	DELETE FROM person_company_attribute
	WHERE person_id = OLD.person_id
	AND company_id = OLD.company_id
	AND person_company_attribute_name = 'badge_system_id'
	RETURNING attribute_value INTO OLD.badge_system_id;

	DELETE FROM person_company_attribute
	WHERE person_id = OLD.person_id
	AND company_id = OLD.company_id
	AND person_company_attribute_name = 'supervisor_person_id'
	RETURNING attribute_value_person_id INTO OLD.supervisor_person_id;

	DELETE FROM jazzhands.person_company
	WHERE  person_id = OLD.person_id  AND  company_id = OLD.company_id  RETURNING *
	INTO _or;
	OLD.company_id = _or.company_id;
	OLD.person_id = _or.person_id;
	OLD.person_company_status = _or.person_company_status;
	OLD.person_company_relation = _or.person_company_relation;
	OLD.is_exempt = CASE WHEN _or.is_exempt = true THEN 'Y' WHEN _or.is_exempt = false THEN 'N' ELSE NULL END;
	OLD.is_management = CASE WHEN _or.is_management = true THEN 'Y' WHEN _or.is_management = false THEN 'N' ELSE NULL END;
	OLD.is_full_time = CASE WHEN _or.is_full_time = true THEN 'Y' WHEN _or.is_full_time = false THEN 'N' ELSE NULL END;
	OLD.description = _or.description;
	OLD.position_title = _or.position_title;
	OLD.hire_date = _or.hire_date;
	OLD.termination_date = _or.termination_date;
	OLD.manager_person_id = _or.manager_person_id;
	OLD.nickname = _or.nickname;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_v_person_company_del
	ON jazzhands_legacy.v_person_company;
CREATE TRIGGER trigger_v_person_company_del
	INSTEAD OF DELETE ON jazzhands_legacy.v_person_company
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.v_person_company_del();


-- Triggers for val_account_collection_type

CREATE OR REPLACE FUNCTION jazzhands_legacy.val_account_collection_type_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.val_account_collection_type%rowtype;
BEGIN

	IF NEW.account_collection_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('account_collection_type'));
		_vq := array_append(_vq, quote_nullable(NEW.account_collection_type));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.is_infrastructure_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_infrastructure_type'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_infrastructure_type = 'Y' THEN true WHEN NEW.is_infrastructure_type = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.max_num_members IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('max_num_members'));
		_vq := array_append(_vq, quote_nullable(NEW.max_num_members));
	END IF;

	IF NEW.max_num_collections IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('max_num_collections'));
		_vq := array_append(_vq, quote_nullable(NEW.max_num_collections));
	END IF;

	IF NEW.can_have_hierarchy IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('can_have_hierarchy'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.can_have_hierarchy = 'Y' THEN true WHEN NEW.can_have_hierarchy = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.account_realm_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('account_realm_id'));
		_vq := array_append(_vq, quote_nullable(NEW.account_realm_id));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.val_account_collection_type (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.account_collection_type = _nr.account_collection_type;
	NEW.description = _nr.description;
	NEW.is_infrastructure_type = CASE WHEN _nr.is_infrastructure_type = true THEN 'Y' WHEN _nr.is_infrastructure_type = false THEN 'N' ELSE NULL END;
	NEW.max_num_members = _nr.max_num_members;
	NEW.max_num_collections = _nr.max_num_collections;
	NEW.can_have_hierarchy = CASE WHEN _nr.can_have_hierarchy = true THEN 'Y' WHEN _nr.can_have_hierarchy = false THEN 'N' ELSE NULL END;
	NEW.account_realm_id = _nr.account_realm_id;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_account_collection_type_ins
	ON jazzhands_legacy.val_account_collection_type;
CREATE TRIGGER trigger_val_account_collection_type_ins
	INSTEAD OF INSERT ON jazzhands_legacy.val_account_collection_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_account_collection_type_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_account_collection_type_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.val_account_collection_type%rowtype;
	_nr	jazzhands.val_account_collection_type%rowtype;
	_uq	text[];
BEGIN

	IF OLD.account_collection_type IS DISTINCT FROM NEW.account_collection_type THEN
_uq := array_append(_uq, 'account_collection_type = ' || quote_nullable(NEW.account_collection_type));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.is_infrastructure_type IS DISTINCT FROM NEW.is_infrastructure_type THEN
IF NEW.is_infrastructure_type = 'Y' THEN
	_uq := array_append(_uq, 'is_infrastructure_type = true');
ELSIF NEW.is_infrastructure_type = 'N' THEN
	_uq := array_append(_uq, 'is_infrastructure_type = false');
ELSE
	_uq := array_append(_uq, 'is_infrastructure_type = NULL');
END IF;
	END IF;

	IF OLD.max_num_members IS DISTINCT FROM NEW.max_num_members THEN
_uq := array_append(_uq, 'max_num_members = ' || quote_nullable(NEW.max_num_members));
	END IF;

	IF OLD.max_num_collections IS DISTINCT FROM NEW.max_num_collections THEN
_uq := array_append(_uq, 'max_num_collections = ' || quote_nullable(NEW.max_num_collections));
	END IF;

	IF OLD.can_have_hierarchy IS DISTINCT FROM NEW.can_have_hierarchy THEN
IF NEW.can_have_hierarchy = 'Y' THEN
	_uq := array_append(_uq, 'can_have_hierarchy = true');
ELSIF NEW.can_have_hierarchy = 'N' THEN
	_uq := array_append(_uq, 'can_have_hierarchy = false');
ELSE
	_uq := array_append(_uq, 'can_have_hierarchy = NULL');
END IF;
	END IF;

	IF OLD.account_realm_id IS DISTINCT FROM NEW.account_realm_id THEN
_uq := array_append(_uq, 'account_realm_id = ' || quote_nullable(NEW.account_realm_id));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.val_account_collection_type SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  account_collection_type = $1 RETURNING *'  USING OLD.account_collection_type
			INTO _nr;

		NEW.account_collection_type = _nr.account_collection_type;
		NEW.description = _nr.description;
		NEW.is_infrastructure_type = CASE WHEN _nr.is_infrastructure_type = true THEN 'Y' WHEN _nr.is_infrastructure_type = false THEN 'N' ELSE NULL END;
		NEW.max_num_members = _nr.max_num_members;
		NEW.max_num_collections = _nr.max_num_collections;
		NEW.can_have_hierarchy = CASE WHEN _nr.can_have_hierarchy = true THEN 'Y' WHEN _nr.can_have_hierarchy = false THEN 'N' ELSE NULL END;
		NEW.account_realm_id = _nr.account_realm_id;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_account_collection_type_upd
	ON jazzhands_legacy.val_account_collection_type;
CREATE TRIGGER trigger_val_account_collection_type_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.val_account_collection_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_account_collection_type_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_account_collection_type_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.val_account_collection_type%rowtype;
BEGIN
	DELETE FROM jazzhands.val_account_collection_type
	WHERE  account_collection_type = OLD.account_collection_type  RETURNING *
	INTO _or;
	OLD.account_collection_type = _or.account_collection_type;
	OLD.description = _or.description;
	OLD.is_infrastructure_type = CASE WHEN _or.is_infrastructure_type = true THEN 'Y' WHEN _or.is_infrastructure_type = false THEN 'N' ELSE NULL END;
	OLD.max_num_members = _or.max_num_members;
	OLD.max_num_collections = _or.max_num_collections;
	OLD.can_have_hierarchy = CASE WHEN _or.can_have_hierarchy = true THEN 'Y' WHEN _or.can_have_hierarchy = false THEN 'N' ELSE NULL END;
	OLD.account_realm_id = _or.account_realm_id;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_account_collection_type_del
	ON jazzhands_legacy.val_account_collection_type;
CREATE TRIGGER trigger_val_account_collection_type_del
	INSTEAD OF DELETE ON jazzhands_legacy.val_account_collection_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_account_collection_type_del();


-- Triggers for val_account_role

CREATE OR REPLACE FUNCTION jazzhands_legacy.val_account_role_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.val_account_role%rowtype;
BEGIN

	IF NEW.account_role IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('account_role'));
		_vq := array_append(_vq, quote_nullable(NEW.account_role));
	END IF;

	IF NEW.uid_gid_forced IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('uid_gid_forced'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.uid_gid_forced = 'Y' THEN true WHEN NEW.uid_gid_forced = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.val_account_role (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.account_role = _nr.account_role;
	NEW.uid_gid_forced = CASE WHEN _nr.uid_gid_forced = true THEN 'Y' WHEN _nr.uid_gid_forced = false THEN 'N' ELSE NULL END;
	NEW.description = _nr.description;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_account_role_ins
	ON jazzhands_legacy.val_account_role;
CREATE TRIGGER trigger_val_account_role_ins
	INSTEAD OF INSERT ON jazzhands_legacy.val_account_role
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_account_role_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_account_role_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.val_account_role%rowtype;
	_nr	jazzhands.val_account_role%rowtype;
	_uq	text[];
BEGIN

	IF OLD.account_role IS DISTINCT FROM NEW.account_role THEN
_uq := array_append(_uq, 'account_role = ' || quote_nullable(NEW.account_role));
	END IF;

	IF OLD.uid_gid_forced IS DISTINCT FROM NEW.uid_gid_forced THEN
IF NEW.uid_gid_forced = 'Y' THEN
	_uq := array_append(_uq, 'uid_gid_forced = true');
ELSIF NEW.uid_gid_forced = 'N' THEN
	_uq := array_append(_uq, 'uid_gid_forced = false');
ELSE
	_uq := array_append(_uq, 'uid_gid_forced = NULL');
END IF;
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.val_account_role SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  account_role = $1 RETURNING *'  USING OLD.account_role
			INTO _nr;

		NEW.account_role = _nr.account_role;
		NEW.uid_gid_forced = CASE WHEN _nr.uid_gid_forced = true THEN 'Y' WHEN _nr.uid_gid_forced = false THEN 'N' ELSE NULL END;
		NEW.description = _nr.description;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_account_role_upd
	ON jazzhands_legacy.val_account_role;
CREATE TRIGGER trigger_val_account_role_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.val_account_role
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_account_role_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_account_role_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.val_account_role%rowtype;
BEGIN
	DELETE FROM jazzhands.val_account_role
	WHERE  account_role = OLD.account_role  RETURNING *
	INTO _or;
	OLD.account_role = _or.account_role;
	OLD.uid_gid_forced = CASE WHEN _or.uid_gid_forced = true THEN 'Y' WHEN _or.uid_gid_forced = false THEN 'N' ELSE NULL END;
	OLD.description = _or.description;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_account_role_del
	ON jazzhands_legacy.val_account_role;
CREATE TRIGGER trigger_val_account_role_del
	INSTEAD OF DELETE ON jazzhands_legacy.val_account_role
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_account_role_del();


-- Triggers for val_account_type

CREATE OR REPLACE FUNCTION jazzhands_legacy.val_account_type_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.val_account_type%rowtype;
BEGIN

	IF NEW.account_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('account_type'));
		_vq := array_append(_vq, quote_nullable(NEW.account_type));
	END IF;

	IF NEW.is_person IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_person'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_person = 'Y' THEN true WHEN NEW.is_person = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.uid_gid_forced IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('uid_gid_forced'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.uid_gid_forced = 'Y' THEN true WHEN NEW.uid_gid_forced = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.val_account_type (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.account_type = _nr.account_type;
	NEW.is_person = CASE WHEN _nr.is_person = true THEN 'Y' WHEN _nr.is_person = false THEN 'N' ELSE NULL END;
	NEW.uid_gid_forced = CASE WHEN _nr.uid_gid_forced = true THEN 'Y' WHEN _nr.uid_gid_forced = false THEN 'N' ELSE NULL END;
	NEW.description = _nr.description;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_account_type_ins
	ON jazzhands_legacy.val_account_type;
CREATE TRIGGER trigger_val_account_type_ins
	INSTEAD OF INSERT ON jazzhands_legacy.val_account_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_account_type_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_account_type_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.val_account_type%rowtype;
	_nr	jazzhands.val_account_type%rowtype;
	_uq	text[];
BEGIN

	IF OLD.account_type IS DISTINCT FROM NEW.account_type THEN
_uq := array_append(_uq, 'account_type = ' || quote_nullable(NEW.account_type));
	END IF;

	IF OLD.is_person IS DISTINCT FROM NEW.is_person THEN
IF NEW.is_person = 'Y' THEN
	_uq := array_append(_uq, 'is_person = true');
ELSIF NEW.is_person = 'N' THEN
	_uq := array_append(_uq, 'is_person = false');
ELSE
	_uq := array_append(_uq, 'is_person = NULL');
END IF;
	END IF;

	IF OLD.uid_gid_forced IS DISTINCT FROM NEW.uid_gid_forced THEN
IF NEW.uid_gid_forced = 'Y' THEN
	_uq := array_append(_uq, 'uid_gid_forced = true');
ELSIF NEW.uid_gid_forced = 'N' THEN
	_uq := array_append(_uq, 'uid_gid_forced = false');
ELSE
	_uq := array_append(_uq, 'uid_gid_forced = NULL');
END IF;
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.val_account_type SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  account_type = $1 RETURNING *'  USING OLD.account_type
			INTO _nr;

		NEW.account_type = _nr.account_type;
		NEW.is_person = CASE WHEN _nr.is_person = true THEN 'Y' WHEN _nr.is_person = false THEN 'N' ELSE NULL END;
		NEW.uid_gid_forced = CASE WHEN _nr.uid_gid_forced = true THEN 'Y' WHEN _nr.uid_gid_forced = false THEN 'N' ELSE NULL END;
		NEW.description = _nr.description;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_account_type_upd
	ON jazzhands_legacy.val_account_type;
CREATE TRIGGER trigger_val_account_type_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.val_account_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_account_type_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_account_type_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.val_account_type%rowtype;
BEGIN
	DELETE FROM jazzhands.val_account_type
	WHERE  account_type = OLD.account_type  RETURNING *
	INTO _or;
	OLD.account_type = _or.account_type;
	OLD.is_person = CASE WHEN _or.is_person = true THEN 'Y' WHEN _or.is_person = false THEN 'N' ELSE NULL END;
	OLD.uid_gid_forced = CASE WHEN _or.uid_gid_forced = true THEN 'Y' WHEN _or.uid_gid_forced = false THEN 'N' ELSE NULL END;
	OLD.description = _or.description;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_account_type_del
	ON jazzhands_legacy.val_account_type;
CREATE TRIGGER trigger_val_account_type_del
	INSTEAD OF DELETE ON jazzhands_legacy.val_account_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_account_type_del();


-- Triggers for val_company_collection_type

CREATE OR REPLACE FUNCTION jazzhands_legacy.val_company_collection_type_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.val_company_collection_type%rowtype;
BEGIN

	IF NEW.company_collection_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('company_collection_type'));
		_vq := array_append(_vq, quote_nullable(NEW.company_collection_type));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.is_infrastructure_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_infrastructure_type'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_infrastructure_type = 'Y' THEN true WHEN NEW.is_infrastructure_type = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.max_num_members IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('max_num_members'));
		_vq := array_append(_vq, quote_nullable(NEW.max_num_members));
	END IF;

	IF NEW.max_num_collections IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('max_num_collections'));
		_vq := array_append(_vq, quote_nullable(NEW.max_num_collections));
	END IF;

	IF NEW.can_have_hierarchy IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('can_have_hierarchy'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.can_have_hierarchy = 'Y' THEN true WHEN NEW.can_have_hierarchy = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.val_company_collection_type (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.company_collection_type = _nr.company_collection_type;
	NEW.description = _nr.description;
	NEW.is_infrastructure_type = CASE WHEN _nr.is_infrastructure_type = true THEN 'Y' WHEN _nr.is_infrastructure_type = false THEN 'N' ELSE NULL END;
	NEW.max_num_members = _nr.max_num_members;
	NEW.max_num_collections = _nr.max_num_collections;
	NEW.can_have_hierarchy = CASE WHEN _nr.can_have_hierarchy = true THEN 'Y' WHEN _nr.can_have_hierarchy = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_company_collection_type_ins
	ON jazzhands_legacy.val_company_collection_type;
CREATE TRIGGER trigger_val_company_collection_type_ins
	INSTEAD OF INSERT ON jazzhands_legacy.val_company_collection_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_company_collection_type_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_company_collection_type_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.val_company_collection_type%rowtype;
	_nr	jazzhands.val_company_collection_type%rowtype;
	_uq	text[];
BEGIN

	IF OLD.company_collection_type IS DISTINCT FROM NEW.company_collection_type THEN
_uq := array_append(_uq, 'company_collection_type = ' || quote_nullable(NEW.company_collection_type));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.is_infrastructure_type IS DISTINCT FROM NEW.is_infrastructure_type THEN
IF NEW.is_infrastructure_type = 'Y' THEN
	_uq := array_append(_uq, 'is_infrastructure_type = true');
ELSIF NEW.is_infrastructure_type = 'N' THEN
	_uq := array_append(_uq, 'is_infrastructure_type = false');
ELSE
	_uq := array_append(_uq, 'is_infrastructure_type = NULL');
END IF;
	END IF;

	IF OLD.max_num_members IS DISTINCT FROM NEW.max_num_members THEN
_uq := array_append(_uq, 'max_num_members = ' || quote_nullable(NEW.max_num_members));
	END IF;

	IF OLD.max_num_collections IS DISTINCT FROM NEW.max_num_collections THEN
_uq := array_append(_uq, 'max_num_collections = ' || quote_nullable(NEW.max_num_collections));
	END IF;

	IF OLD.can_have_hierarchy IS DISTINCT FROM NEW.can_have_hierarchy THEN
IF NEW.can_have_hierarchy = 'Y' THEN
	_uq := array_append(_uq, 'can_have_hierarchy = true');
ELSIF NEW.can_have_hierarchy = 'N' THEN
	_uq := array_append(_uq, 'can_have_hierarchy = false');
ELSE
	_uq := array_append(_uq, 'can_have_hierarchy = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.val_company_collection_type SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  company_collection_type = $1 RETURNING *'  USING OLD.company_collection_type
			INTO _nr;

		NEW.company_collection_type = _nr.company_collection_type;
		NEW.description = _nr.description;
		NEW.is_infrastructure_type = CASE WHEN _nr.is_infrastructure_type = true THEN 'Y' WHEN _nr.is_infrastructure_type = false THEN 'N' ELSE NULL END;
		NEW.max_num_members = _nr.max_num_members;
		NEW.max_num_collections = _nr.max_num_collections;
		NEW.can_have_hierarchy = CASE WHEN _nr.can_have_hierarchy = true THEN 'Y' WHEN _nr.can_have_hierarchy = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_company_collection_type_upd
	ON jazzhands_legacy.val_company_collection_type;
CREATE TRIGGER trigger_val_company_collection_type_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.val_company_collection_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_company_collection_type_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_company_collection_type_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.val_company_collection_type%rowtype;
BEGIN
	DELETE FROM jazzhands.val_company_collection_type
	WHERE  company_collection_type = OLD.company_collection_type  RETURNING *
	INTO _or;
	OLD.company_collection_type = _or.company_collection_type;
	OLD.description = _or.description;
	OLD.is_infrastructure_type = CASE WHEN _or.is_infrastructure_type = true THEN 'Y' WHEN _or.is_infrastructure_type = false THEN 'N' ELSE NULL END;
	OLD.max_num_members = _or.max_num_members;
	OLD.max_num_collections = _or.max_num_collections;
	OLD.can_have_hierarchy = CASE WHEN _or.can_have_hierarchy = true THEN 'Y' WHEN _or.can_have_hierarchy = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_company_collection_type_del
	ON jazzhands_legacy.val_company_collection_type;
CREATE TRIGGER trigger_val_company_collection_type_del
	INSTEAD OF DELETE ON jazzhands_legacy.val_company_collection_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_company_collection_type_del();


-- Triggers for val_component_property

CREATE OR REPLACE FUNCTION jazzhands_legacy.val_component_property_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.val_component_property%rowtype;
BEGIN

	IF NEW.component_property_name IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('component_property_name'));
		_vq := array_append(_vq, quote_nullable(NEW.component_property_name));
	END IF;

	IF NEW.component_property_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('component_property_type'));
		_vq := array_append(_vq, quote_nullable(NEW.component_property_type));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.is_multivalue IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_multivalue'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_multivalue = 'Y' THEN true WHEN NEW.is_multivalue = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.property_data_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('property_data_type'));
		_vq := array_append(_vq, quote_nullable(NEW.property_data_type));
	END IF;

	IF NEW.permit_component_type_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('permit_component_type_id'));
		_vq := array_append(_vq, quote_nullable(NEW.permit_component_type_id));
	END IF;

	IF NEW.required_component_type_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('required_component_type_id'));
		_vq := array_append(_vq, quote_nullable(NEW.required_component_type_id));
	END IF;

	IF NEW.permit_component_function IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('permit_component_function'));
		_vq := array_append(_vq, quote_nullable(NEW.permit_component_function));
	END IF;

	IF NEW.required_component_function IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('required_component_function'));
		_vq := array_append(_vq, quote_nullable(NEW.required_component_function));
	END IF;

	IF NEW.permit_component_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('permit_component_id'));
		_vq := array_append(_vq, quote_nullable(NEW.permit_component_id));
	END IF;

	IF NEW.permit_intcomp_conn_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('permit_inter_component_connection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.permit_intcomp_conn_id));
	END IF;

	IF NEW.permit_slot_type_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('permit_slot_type_id'));
		_vq := array_append(_vq, quote_nullable(NEW.permit_slot_type_id));
	END IF;

	IF NEW.required_slot_type_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('required_slot_type_id'));
		_vq := array_append(_vq, quote_nullable(NEW.required_slot_type_id));
	END IF;

	IF NEW.permit_slot_function IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('permit_slot_function'));
		_vq := array_append(_vq, quote_nullable(NEW.permit_slot_function));
	END IF;

	IF NEW.required_slot_function IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('required_slot_function'));
		_vq := array_append(_vq, quote_nullable(NEW.required_slot_function));
	END IF;

	IF NEW.permit_slot_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('permit_slot_id'));
		_vq := array_append(_vq, quote_nullable(NEW.permit_slot_id));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.val_component_property (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.component_property_name = _nr.component_property_name;
	NEW.component_property_type = _nr.component_property_type;
	NEW.description = _nr.description;
	NEW.is_multivalue = CASE WHEN _nr.is_multivalue = true THEN 'Y' WHEN _nr.is_multivalue = false THEN 'N' ELSE NULL END;
	NEW.property_data_type = _nr.property_data_type;
	NEW.permit_component_type_id = _nr.permit_component_type_id;
	NEW.required_component_type_id = _nr.required_component_type_id;
	NEW.permit_component_function = _nr.permit_component_function;
	NEW.required_component_function = _nr.required_component_function;
	NEW.permit_component_id = _nr.permit_component_id;
	NEW.permit_intcomp_conn_id = _nr.permit_inter_component_connection_id;
	NEW.permit_slot_type_id = _nr.permit_slot_type_id;
	NEW.required_slot_type_id = _nr.required_slot_type_id;
	NEW.permit_slot_function = _nr.permit_slot_function;
	NEW.required_slot_function = _nr.required_slot_function;
	NEW.permit_slot_id = _nr.permit_slot_id;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_component_property_ins
	ON jazzhands_legacy.val_component_property;
CREATE TRIGGER trigger_val_component_property_ins
	INSTEAD OF INSERT ON jazzhands_legacy.val_component_property
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_component_property_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_component_property_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.val_component_property%rowtype;
	_nr	jazzhands.val_component_property%rowtype;
	_uq	text[];
BEGIN

	IF OLD.component_property_name IS DISTINCT FROM NEW.component_property_name THEN
_uq := array_append(_uq, 'component_property_name = ' || quote_nullable(NEW.component_property_name));
	END IF;

	IF OLD.component_property_type IS DISTINCT FROM NEW.component_property_type THEN
_uq := array_append(_uq, 'component_property_type = ' || quote_nullable(NEW.component_property_type));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.is_multivalue IS DISTINCT FROM NEW.is_multivalue THEN
IF NEW.is_multivalue = 'Y' THEN
	_uq := array_append(_uq, 'is_multivalue = true');
ELSIF NEW.is_multivalue = 'N' THEN
	_uq := array_append(_uq, 'is_multivalue = false');
ELSE
	_uq := array_append(_uq, 'is_multivalue = NULL');
END IF;
	END IF;

	IF OLD.property_data_type IS DISTINCT FROM NEW.property_data_type THEN
_uq := array_append(_uq, 'property_data_type = ' || quote_nullable(NEW.property_data_type));
	END IF;

	IF OLD.permit_component_type_id IS DISTINCT FROM NEW.permit_component_type_id THEN
_uq := array_append(_uq, 'permit_component_type_id = ' || quote_nullable(NEW.permit_component_type_id));
	END IF;

	IF OLD.required_component_type_id IS DISTINCT FROM NEW.required_component_type_id THEN
_uq := array_append(_uq, 'required_component_type_id = ' || quote_nullable(NEW.required_component_type_id));
	END IF;

	IF OLD.permit_component_function IS DISTINCT FROM NEW.permit_component_function THEN
_uq := array_append(_uq, 'permit_component_function = ' || quote_nullable(NEW.permit_component_function));
	END IF;

	IF OLD.required_component_function IS DISTINCT FROM NEW.required_component_function THEN
_uq := array_append(_uq, 'required_component_function = ' || quote_nullable(NEW.required_component_function));
	END IF;

	IF OLD.permit_component_id IS DISTINCT FROM NEW.permit_component_id THEN
_uq := array_append(_uq, 'permit_component_id = ' || quote_nullable(NEW.permit_component_id));
	END IF;

	IF OLD.permit_intcomp_conn_id IS DISTINCT FROM NEW.permit_intcomp_conn_id THEN
_uq := array_append(_uq, 'permit_inter_component_connection_id = ' || quote_nullable(NEW.permit_intcomp_conn_id));
	END IF;

	IF OLD.permit_slot_type_id IS DISTINCT FROM NEW.permit_slot_type_id THEN
_uq := array_append(_uq, 'permit_slot_type_id = ' || quote_nullable(NEW.permit_slot_type_id));
	END IF;

	IF OLD.required_slot_type_id IS DISTINCT FROM NEW.required_slot_type_id THEN
_uq := array_append(_uq, 'required_slot_type_id = ' || quote_nullable(NEW.required_slot_type_id));
	END IF;

	IF OLD.permit_slot_function IS DISTINCT FROM NEW.permit_slot_function THEN
_uq := array_append(_uq, 'permit_slot_function = ' || quote_nullable(NEW.permit_slot_function));
	END IF;

	IF OLD.required_slot_function IS DISTINCT FROM NEW.required_slot_function THEN
_uq := array_append(_uq, 'required_slot_function = ' || quote_nullable(NEW.required_slot_function));
	END IF;

	IF OLD.permit_slot_id IS DISTINCT FROM NEW.permit_slot_id THEN
_uq := array_append(_uq, 'permit_slot_id = ' || quote_nullable(NEW.permit_slot_id));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.val_component_property SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  component_property_name = $1 AND  component_property_type = $2 RETURNING *'  USING OLD.component_property_name, OLD.component_property_type
			INTO _nr;

		NEW.component_property_name = _nr.component_property_name;
		NEW.component_property_type = _nr.component_property_type;
		NEW.description = _nr.description;
		NEW.is_multivalue = CASE WHEN _nr.is_multivalue = true THEN 'Y' WHEN _nr.is_multivalue = false THEN 'N' ELSE NULL END;
		NEW.property_data_type = _nr.property_data_type;
		NEW.permit_component_type_id = _nr.permit_component_type_id;
		NEW.required_component_type_id = _nr.required_component_type_id;
		NEW.permit_component_function = _nr.permit_component_function;
		NEW.required_component_function = _nr.required_component_function;
		NEW.permit_component_id = _nr.permit_component_id;
		NEW.permit_intcomp_conn_id = _nr.permit_inter_component_connection_id;
		NEW.permit_slot_type_id = _nr.permit_slot_type_id;
		NEW.required_slot_type_id = _nr.required_slot_type_id;
		NEW.permit_slot_function = _nr.permit_slot_function;
		NEW.required_slot_function = _nr.required_slot_function;
		NEW.permit_slot_id = _nr.permit_slot_id;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_component_property_upd
	ON jazzhands_legacy.val_component_property;
CREATE TRIGGER trigger_val_component_property_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.val_component_property
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_component_property_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_component_property_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.val_component_property%rowtype;
BEGIN
	DELETE FROM jazzhands.val_component_property
	WHERE  component_property_name = OLD.component_property_name  AND  component_property_type = OLD.component_property_type  RETURNING *
	INTO _or;
	OLD.component_property_name = _or.component_property_name;
	OLD.component_property_type = _or.component_property_type;
	OLD.description = _or.description;
	OLD.is_multivalue = CASE WHEN _or.is_multivalue = true THEN 'Y' WHEN _or.is_multivalue = false THEN 'N' ELSE NULL END;
	OLD.property_data_type = _or.property_data_type;
	OLD.permit_component_type_id = _or.permit_component_type_id;
	OLD.required_component_type_id = _or.required_component_type_id;
	OLD.permit_component_function = _or.permit_component_function;
	OLD.required_component_function = _or.required_component_function;
	OLD.permit_component_id = _or.permit_component_id;
	OLD.permit_intcomp_conn_id = _or.permit_inter_component_connection_id;
	OLD.permit_slot_type_id = _or.permit_slot_type_id;
	OLD.required_slot_type_id = _or.required_slot_type_id;
	OLD.permit_slot_function = _or.permit_slot_function;
	OLD.required_slot_function = _or.required_slot_function;
	OLD.permit_slot_id = _or.permit_slot_id;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_component_property_del
	ON jazzhands_legacy.val_component_property;
CREATE TRIGGER trigger_val_component_property_del
	INSTEAD OF DELETE ON jazzhands_legacy.val_component_property
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_component_property_del();


-- Triggers for val_component_property_type

CREATE OR REPLACE FUNCTION jazzhands_legacy.val_component_property_type_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.val_component_property_type%rowtype;
BEGIN

	IF NEW.component_property_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('component_property_type'));
		_vq := array_append(_vq, quote_nullable(NEW.component_property_type));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.is_multivalue IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_multivalue'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_multivalue = 'Y' THEN true WHEN NEW.is_multivalue = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.val_component_property_type (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.component_property_type = _nr.component_property_type;
	NEW.description = _nr.description;
	NEW.is_multivalue = CASE WHEN _nr.is_multivalue = true THEN 'Y' WHEN _nr.is_multivalue = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_component_property_type_ins
	ON jazzhands_legacy.val_component_property_type;
CREATE TRIGGER trigger_val_component_property_type_ins
	INSTEAD OF INSERT ON jazzhands_legacy.val_component_property_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_component_property_type_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_component_property_type_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.val_component_property_type%rowtype;
	_nr	jazzhands.val_component_property_type%rowtype;
	_uq	text[];
BEGIN

	IF OLD.component_property_type IS DISTINCT FROM NEW.component_property_type THEN
_uq := array_append(_uq, 'component_property_type = ' || quote_nullable(NEW.component_property_type));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.is_multivalue IS DISTINCT FROM NEW.is_multivalue THEN
IF NEW.is_multivalue = 'Y' THEN
	_uq := array_append(_uq, 'is_multivalue = true');
ELSIF NEW.is_multivalue = 'N' THEN
	_uq := array_append(_uq, 'is_multivalue = false');
ELSE
	_uq := array_append(_uq, 'is_multivalue = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.val_component_property_type SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  component_property_type = $1 RETURNING *'  USING OLD.component_property_type
			INTO _nr;

		NEW.component_property_type = _nr.component_property_type;
		NEW.description = _nr.description;
		NEW.is_multivalue = CASE WHEN _nr.is_multivalue = true THEN 'Y' WHEN _nr.is_multivalue = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_component_property_type_upd
	ON jazzhands_legacy.val_component_property_type;
CREATE TRIGGER trigger_val_component_property_type_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.val_component_property_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_component_property_type_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_component_property_type_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.val_component_property_type%rowtype;
BEGIN
	DELETE FROM jazzhands.val_component_property_type
	WHERE  component_property_type = OLD.component_property_type  RETURNING *
	INTO _or;
	OLD.component_property_type = _or.component_property_type;
	OLD.description = _or.description;
	OLD.is_multivalue = CASE WHEN _or.is_multivalue = true THEN 'Y' WHEN _or.is_multivalue = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_component_property_type_del
	ON jazzhands_legacy.val_component_property_type;
CREATE TRIGGER trigger_val_component_property_type_del
	INSTEAD OF DELETE ON jazzhands_legacy.val_component_property_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_component_property_type_del();


-- Triggers for val_device_collection_type

CREATE OR REPLACE FUNCTION jazzhands_legacy.val_device_collection_type_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.val_device_collection_type%rowtype;
BEGIN

	IF NEW.device_collection_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('device_collection_type'));
		_vq := array_append(_vq, quote_nullable(NEW.device_collection_type));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.max_num_members IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('max_num_members'));
		_vq := array_append(_vq, quote_nullable(NEW.max_num_members));
	END IF;

	IF NEW.max_num_collections IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('max_num_collections'));
		_vq := array_append(_vq, quote_nullable(NEW.max_num_collections));
	END IF;

	IF NEW.can_have_hierarchy IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('can_have_hierarchy'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.can_have_hierarchy = 'Y' THEN true WHEN NEW.can_have_hierarchy = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.val_device_collection_type (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.device_collection_type = _nr.device_collection_type;
	NEW.description = _nr.description;
	NEW.max_num_members = _nr.max_num_members;
	NEW.max_num_collections = _nr.max_num_collections;
	NEW.can_have_hierarchy = CASE WHEN _nr.can_have_hierarchy = true THEN 'Y' WHEN _nr.can_have_hierarchy = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_device_collection_type_ins
	ON jazzhands_legacy.val_device_collection_type;
CREATE TRIGGER trigger_val_device_collection_type_ins
	INSTEAD OF INSERT ON jazzhands_legacy.val_device_collection_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_device_collection_type_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_device_collection_type_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.val_device_collection_type%rowtype;
	_nr	jazzhands.val_device_collection_type%rowtype;
	_uq	text[];
BEGIN

	IF OLD.device_collection_type IS DISTINCT FROM NEW.device_collection_type THEN
_uq := array_append(_uq, 'device_collection_type = ' || quote_nullable(NEW.device_collection_type));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.max_num_members IS DISTINCT FROM NEW.max_num_members THEN
_uq := array_append(_uq, 'max_num_members = ' || quote_nullable(NEW.max_num_members));
	END IF;

	IF OLD.max_num_collections IS DISTINCT FROM NEW.max_num_collections THEN
_uq := array_append(_uq, 'max_num_collections = ' || quote_nullable(NEW.max_num_collections));
	END IF;

	IF OLD.can_have_hierarchy IS DISTINCT FROM NEW.can_have_hierarchy THEN
IF NEW.can_have_hierarchy = 'Y' THEN
	_uq := array_append(_uq, 'can_have_hierarchy = true');
ELSIF NEW.can_have_hierarchy = 'N' THEN
	_uq := array_append(_uq, 'can_have_hierarchy = false');
ELSE
	_uq := array_append(_uq, 'can_have_hierarchy = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.val_device_collection_type SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  device_collection_type = $1 RETURNING *'  USING OLD.device_collection_type
			INTO _nr;

		NEW.device_collection_type = _nr.device_collection_type;
		NEW.description = _nr.description;
		NEW.max_num_members = _nr.max_num_members;
		NEW.max_num_collections = _nr.max_num_collections;
		NEW.can_have_hierarchy = CASE WHEN _nr.can_have_hierarchy = true THEN 'Y' WHEN _nr.can_have_hierarchy = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_device_collection_type_upd
	ON jazzhands_legacy.val_device_collection_type;
CREATE TRIGGER trigger_val_device_collection_type_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.val_device_collection_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_device_collection_type_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_device_collection_type_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.val_device_collection_type%rowtype;
BEGIN
	DELETE FROM jazzhands.val_device_collection_type
	WHERE  device_collection_type = OLD.device_collection_type  RETURNING *
	INTO _or;
	OLD.device_collection_type = _or.device_collection_type;
	OLD.description = _or.description;
	OLD.max_num_members = _or.max_num_members;
	OLD.max_num_collections = _or.max_num_collections;
	OLD.can_have_hierarchy = CASE WHEN _or.can_have_hierarchy = true THEN 'Y' WHEN _or.can_have_hierarchy = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_device_collection_type_del
	ON jazzhands_legacy.val_device_collection_type;
CREATE TRIGGER trigger_val_device_collection_type_del
	INSTEAD OF DELETE ON jazzhands_legacy.val_device_collection_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_device_collection_type_del();


-- Triggers for val_dns_domain_collection_type

CREATE OR REPLACE FUNCTION jazzhands_legacy.val_dns_domain_collection_type_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.val_dns_domain_collection_type%rowtype;
BEGIN

	IF NEW.dns_domain_collection_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('dns_domain_collection_type'));
		_vq := array_append(_vq, quote_nullable(NEW.dns_domain_collection_type));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.max_num_members IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('max_num_members'));
		_vq := array_append(_vq, quote_nullable(NEW.max_num_members));
	END IF;

	IF NEW.max_num_collections IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('max_num_collections'));
		_vq := array_append(_vq, quote_nullable(NEW.max_num_collections));
	END IF;

	IF NEW.can_have_hierarchy IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('can_have_hierarchy'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.can_have_hierarchy = 'Y' THEN true WHEN NEW.can_have_hierarchy = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.val_dns_domain_collection_type (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.dns_domain_collection_type = _nr.dns_domain_collection_type;
	NEW.description = _nr.description;
	NEW.max_num_members = _nr.max_num_members;
	NEW.max_num_collections = _nr.max_num_collections;
	NEW.can_have_hierarchy = CASE WHEN _nr.can_have_hierarchy = true THEN 'Y' WHEN _nr.can_have_hierarchy = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_dns_domain_collection_type_ins
	ON jazzhands_legacy.val_dns_domain_collection_type;
CREATE TRIGGER trigger_val_dns_domain_collection_type_ins
	INSTEAD OF INSERT ON jazzhands_legacy.val_dns_domain_collection_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_dns_domain_collection_type_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_dns_domain_collection_type_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.val_dns_domain_collection_type%rowtype;
	_nr	jazzhands.val_dns_domain_collection_type%rowtype;
	_uq	text[];
BEGIN

	IF OLD.dns_domain_collection_type IS DISTINCT FROM NEW.dns_domain_collection_type THEN
_uq := array_append(_uq, 'dns_domain_collection_type = ' || quote_nullable(NEW.dns_domain_collection_type));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.max_num_members IS DISTINCT FROM NEW.max_num_members THEN
_uq := array_append(_uq, 'max_num_members = ' || quote_nullable(NEW.max_num_members));
	END IF;

	IF OLD.max_num_collections IS DISTINCT FROM NEW.max_num_collections THEN
_uq := array_append(_uq, 'max_num_collections = ' || quote_nullable(NEW.max_num_collections));
	END IF;

	IF OLD.can_have_hierarchy IS DISTINCT FROM NEW.can_have_hierarchy THEN
IF NEW.can_have_hierarchy = 'Y' THEN
	_uq := array_append(_uq, 'can_have_hierarchy = true');
ELSIF NEW.can_have_hierarchy = 'N' THEN
	_uq := array_append(_uq, 'can_have_hierarchy = false');
ELSE
	_uq := array_append(_uq, 'can_have_hierarchy = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.val_dns_domain_collection_type SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  dns_domain_collection_type = $1 RETURNING *'  USING OLD.dns_domain_collection_type
			INTO _nr;

		NEW.dns_domain_collection_type = _nr.dns_domain_collection_type;
		NEW.description = _nr.description;
		NEW.max_num_members = _nr.max_num_members;
		NEW.max_num_collections = _nr.max_num_collections;
		NEW.can_have_hierarchy = CASE WHEN _nr.can_have_hierarchy = true THEN 'Y' WHEN _nr.can_have_hierarchy = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_dns_domain_collection_type_upd
	ON jazzhands_legacy.val_dns_domain_collection_type;
CREATE TRIGGER trigger_val_dns_domain_collection_type_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.val_dns_domain_collection_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_dns_domain_collection_type_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_dns_domain_collection_type_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.val_dns_domain_collection_type%rowtype;
BEGIN
	DELETE FROM jazzhands.val_dns_domain_collection_type
	WHERE  dns_domain_collection_type = OLD.dns_domain_collection_type  RETURNING *
	INTO _or;
	OLD.dns_domain_collection_type = _or.dns_domain_collection_type;
	OLD.description = _or.description;
	OLD.max_num_members = _or.max_num_members;
	OLD.max_num_collections = _or.max_num_collections;
	OLD.can_have_hierarchy = CASE WHEN _or.can_have_hierarchy = true THEN 'Y' WHEN _or.can_have_hierarchy = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_dns_domain_collection_type_del
	ON jazzhands_legacy.val_dns_domain_collection_type;
CREATE TRIGGER trigger_val_dns_domain_collection_type_del
	INSTEAD OF DELETE ON jazzhands_legacy.val_dns_domain_collection_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_dns_domain_collection_type_del();


-- Triggers for val_dns_domain_type

CREATE OR REPLACE FUNCTION jazzhands_legacy.val_dns_domain_type_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.val_dns_domain_type%rowtype;
BEGIN

	IF NEW.dns_domain_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('dns_domain_type'));
		_vq := array_append(_vq, quote_nullable(NEW.dns_domain_type));
	END IF;

	IF NEW.can_generate IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('can_generate'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.can_generate = 'Y' THEN true WHEN NEW.can_generate = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.val_dns_domain_type (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.dns_domain_type = _nr.dns_domain_type;
	NEW.can_generate = CASE WHEN _nr.can_generate = true THEN 'Y' WHEN _nr.can_generate = false THEN 'N' ELSE NULL END;
	NEW.description = _nr.description;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_dns_domain_type_ins
	ON jazzhands_legacy.val_dns_domain_type;
CREATE TRIGGER trigger_val_dns_domain_type_ins
	INSTEAD OF INSERT ON jazzhands_legacy.val_dns_domain_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_dns_domain_type_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_dns_domain_type_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.val_dns_domain_type%rowtype;
	_nr	jazzhands.val_dns_domain_type%rowtype;
	_uq	text[];
BEGIN

	IF OLD.dns_domain_type IS DISTINCT FROM NEW.dns_domain_type THEN
_uq := array_append(_uq, 'dns_domain_type = ' || quote_nullable(NEW.dns_domain_type));
	END IF;

	IF OLD.can_generate IS DISTINCT FROM NEW.can_generate THEN
IF NEW.can_generate = 'Y' THEN
	_uq := array_append(_uq, 'can_generate = true');
ELSIF NEW.can_generate = 'N' THEN
	_uq := array_append(_uq, 'can_generate = false');
ELSE
	_uq := array_append(_uq, 'can_generate = NULL');
END IF;
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.val_dns_domain_type SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  dns_domain_type = $1 RETURNING *'  USING OLD.dns_domain_type
			INTO _nr;

		NEW.dns_domain_type = _nr.dns_domain_type;
		NEW.can_generate = CASE WHEN _nr.can_generate = true THEN 'Y' WHEN _nr.can_generate = false THEN 'N' ELSE NULL END;
		NEW.description = _nr.description;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_dns_domain_type_upd
	ON jazzhands_legacy.val_dns_domain_type;
CREATE TRIGGER trigger_val_dns_domain_type_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.val_dns_domain_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_dns_domain_type_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_dns_domain_type_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.val_dns_domain_type%rowtype;
BEGIN
	DELETE FROM jazzhands.val_dns_domain_type
	WHERE  dns_domain_type = OLD.dns_domain_type  RETURNING *
	INTO _or;
	OLD.dns_domain_type = _or.dns_domain_type;
	OLD.can_generate = CASE WHEN _or.can_generate = true THEN 'Y' WHEN _or.can_generate = false THEN 'N' ELSE NULL END;
	OLD.description = _or.description;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_dns_domain_type_del
	ON jazzhands_legacy.val_dns_domain_type;
CREATE TRIGGER trigger_val_dns_domain_type_del
	INSTEAD OF DELETE ON jazzhands_legacy.val_dns_domain_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_dns_domain_type_del();


-- Triggers for val_layer2_network_coll_type

CREATE OR REPLACE FUNCTION jazzhands_legacy.val_layer2_network_coll_type_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.val_layer2_network_collection_type%rowtype;
BEGIN

	IF NEW.layer2_network_collection_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('layer2_network_collection_type'));
		_vq := array_append(_vq, quote_nullable(NEW.layer2_network_collection_type));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.max_num_members IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('max_num_members'));
		_vq := array_append(_vq, quote_nullable(NEW.max_num_members));
	END IF;

	IF NEW.max_num_collections IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('max_num_collections'));
		_vq := array_append(_vq, quote_nullable(NEW.max_num_collections));
	END IF;

	IF NEW.can_have_hierarchy IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('can_have_hierarchy'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.can_have_hierarchy = 'Y' THEN true WHEN NEW.can_have_hierarchy = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.val_layer2_network_collection_type (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.layer2_network_collection_type = _nr.layer2_network_collection_type;
	NEW.description = _nr.description;
	NEW.max_num_members = _nr.max_num_members;
	NEW.max_num_collections = _nr.max_num_collections;
	NEW.can_have_hierarchy = CASE WHEN _nr.can_have_hierarchy = true THEN 'Y' WHEN _nr.can_have_hierarchy = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_layer2_network_coll_type_ins
	ON jazzhands_legacy.val_layer2_network_coll_type;
CREATE TRIGGER trigger_val_layer2_network_coll_type_ins
	INSTEAD OF INSERT ON jazzhands_legacy.val_layer2_network_coll_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_layer2_network_coll_type_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_layer2_network_coll_type_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.val_layer2_network_coll_type%rowtype;
	_nr	jazzhands.val_layer2_network_collection_type%rowtype;
	_uq	text[];
BEGIN

	IF OLD.layer2_network_collection_type IS DISTINCT FROM NEW.layer2_network_collection_type THEN
_uq := array_append(_uq, 'layer2_network_collection_type = ' || quote_nullable(NEW.layer2_network_collection_type));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.max_num_members IS DISTINCT FROM NEW.max_num_members THEN
_uq := array_append(_uq, 'max_num_members = ' || quote_nullable(NEW.max_num_members));
	END IF;

	IF OLD.max_num_collections IS DISTINCT FROM NEW.max_num_collections THEN
_uq := array_append(_uq, 'max_num_collections = ' || quote_nullable(NEW.max_num_collections));
	END IF;

	IF OLD.can_have_hierarchy IS DISTINCT FROM NEW.can_have_hierarchy THEN
IF NEW.can_have_hierarchy = 'Y' THEN
	_uq := array_append(_uq, 'can_have_hierarchy = true');
ELSIF NEW.can_have_hierarchy = 'N' THEN
	_uq := array_append(_uq, 'can_have_hierarchy = false');
ELSE
	_uq := array_append(_uq, 'can_have_hierarchy = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.val_layer2_network_collection_type SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  layer2_network_collection_type = $1 RETURNING *'  USING OLD.layer2_network_collection_type
			INTO _nr;

		NEW.layer2_network_collection_type = _nr.layer2_network_collection_type;
		NEW.description = _nr.description;
		NEW.max_num_members = _nr.max_num_members;
		NEW.max_num_collections = _nr.max_num_collections;
		NEW.can_have_hierarchy = CASE WHEN _nr.can_have_hierarchy = true THEN 'Y' WHEN _nr.can_have_hierarchy = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_layer2_network_coll_type_upd
	ON jazzhands_legacy.val_layer2_network_coll_type;
CREATE TRIGGER trigger_val_layer2_network_coll_type_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.val_layer2_network_coll_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_layer2_network_coll_type_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_layer2_network_coll_type_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.val_layer2_network_collection_type%rowtype;
BEGIN
	DELETE FROM jazzhands.val_layer2_network_collection_type
	WHERE  layer2_network_collection_type = OLD.layer2_network_collection_type  RETURNING *
	INTO _or;
	OLD.layer2_network_collection_type = _or.layer2_network_collection_type;
	OLD.description = _or.description;
	OLD.max_num_members = _or.max_num_members;
	OLD.max_num_collections = _or.max_num_collections;
	OLD.can_have_hierarchy = CASE WHEN _or.can_have_hierarchy = true THEN 'Y' WHEN _or.can_have_hierarchy = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_layer2_network_coll_type_del
	ON jazzhands_legacy.val_layer2_network_coll_type;
CREATE TRIGGER trigger_val_layer2_network_coll_type_del
	INSTEAD OF DELETE ON jazzhands_legacy.val_layer2_network_coll_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_layer2_network_coll_type_del();


-- Triggers for val_layer3_network_coll_type

CREATE OR REPLACE FUNCTION jazzhands_legacy.val_layer3_network_coll_type_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.val_layer3_network_collection_type%rowtype;
BEGIN

	IF NEW.layer3_network_collection_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('layer3_network_collection_type'));
		_vq := array_append(_vq, quote_nullable(NEW.layer3_network_collection_type));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.max_num_members IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('max_num_members'));
		_vq := array_append(_vq, quote_nullable(NEW.max_num_members));
	END IF;

	IF NEW.max_num_collections IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('max_num_collections'));
		_vq := array_append(_vq, quote_nullable(NEW.max_num_collections));
	END IF;

	IF NEW.can_have_hierarchy IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('can_have_hierarchy'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.can_have_hierarchy = 'Y' THEN true WHEN NEW.can_have_hierarchy = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.val_layer3_network_collection_type (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.layer3_network_collection_type = _nr.layer3_network_collection_type;
	NEW.description = _nr.description;
	NEW.max_num_members = _nr.max_num_members;
	NEW.max_num_collections = _nr.max_num_collections;
	NEW.can_have_hierarchy = CASE WHEN _nr.can_have_hierarchy = true THEN 'Y' WHEN _nr.can_have_hierarchy = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_layer3_network_coll_type_ins
	ON jazzhands_legacy.val_layer3_network_coll_type;
CREATE TRIGGER trigger_val_layer3_network_coll_type_ins
	INSTEAD OF INSERT ON jazzhands_legacy.val_layer3_network_coll_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_layer3_network_coll_type_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_layer3_network_coll_type_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.val_layer3_network_coll_type%rowtype;
	_nr	jazzhands.val_layer3_network_collection_type%rowtype;
	_uq	text[];
BEGIN

	IF OLD.layer3_network_collection_type IS DISTINCT FROM NEW.layer3_network_collection_type THEN
_uq := array_append(_uq, 'layer3_network_collection_type = ' || quote_nullable(NEW.layer3_network_collection_type));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.max_num_members IS DISTINCT FROM NEW.max_num_members THEN
_uq := array_append(_uq, 'max_num_members = ' || quote_nullable(NEW.max_num_members));
	END IF;

	IF OLD.max_num_collections IS DISTINCT FROM NEW.max_num_collections THEN
_uq := array_append(_uq, 'max_num_collections = ' || quote_nullable(NEW.max_num_collections));
	END IF;

	IF OLD.can_have_hierarchy IS DISTINCT FROM NEW.can_have_hierarchy THEN
IF NEW.can_have_hierarchy = 'Y' THEN
	_uq := array_append(_uq, 'can_have_hierarchy = true');
ELSIF NEW.can_have_hierarchy = 'N' THEN
	_uq := array_append(_uq, 'can_have_hierarchy = false');
ELSE
	_uq := array_append(_uq, 'can_have_hierarchy = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.val_layer3_network_collection_type SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  layer3_network_collection_type = $1 RETURNING *'  USING OLD.layer3_network_collection_type
			INTO _nr;

		NEW.layer3_network_collection_type = _nr.layer3_network_collection_type;
		NEW.description = _nr.description;
		NEW.max_num_members = _nr.max_num_members;
		NEW.max_num_collections = _nr.max_num_collections;
		NEW.can_have_hierarchy = CASE WHEN _nr.can_have_hierarchy = true THEN 'Y' WHEN _nr.can_have_hierarchy = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_layer3_network_coll_type_upd
	ON jazzhands_legacy.val_layer3_network_coll_type;
CREATE TRIGGER trigger_val_layer3_network_coll_type_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.val_layer3_network_coll_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_layer3_network_coll_type_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_layer3_network_coll_type_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.val_layer3_network_collection_type%rowtype;
BEGIN
	DELETE FROM jazzhands.val_layer3_network_collection_type
	WHERE  layer3_network_collection_type = OLD.layer3_network_collection_type  RETURNING *
	INTO _or;
	OLD.layer3_network_collection_type = _or.layer3_network_collection_type;
	OLD.description = _or.description;
	OLD.max_num_members = _or.max_num_members;
	OLD.max_num_collections = _or.max_num_collections;
	OLD.can_have_hierarchy = CASE WHEN _or.can_have_hierarchy = true THEN 'Y' WHEN _or.can_have_hierarchy = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_layer3_network_coll_type_del
	ON jazzhands_legacy.val_layer3_network_coll_type;
CREATE TRIGGER trigger_val_layer3_network_coll_type_del
	INSTEAD OF DELETE ON jazzhands_legacy.val_layer3_network_coll_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_layer3_network_coll_type_del();


-- Triggers for val_netblock_collection_type

CREATE OR REPLACE FUNCTION jazzhands_legacy.val_netblock_collection_type_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.val_netblock_collection_type%rowtype;
BEGIN

	IF NEW.netblock_collection_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('netblock_collection_type'));
		_vq := array_append(_vq, quote_nullable(NEW.netblock_collection_type));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.max_num_members IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('max_num_members'));
		_vq := array_append(_vq, quote_nullable(NEW.max_num_members));
	END IF;

	IF NEW.max_num_collections IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('max_num_collections'));
		_vq := array_append(_vq, quote_nullable(NEW.max_num_collections));
	END IF;

	IF NEW.can_have_hierarchy IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('can_have_hierarchy'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.can_have_hierarchy = 'Y' THEN true WHEN NEW.can_have_hierarchy = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.netblock_single_addr_restrict IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('netblock_is_single_address_restriction'));
		_vq := array_append(_vq, quote_nullable(NEW.netblock_single_addr_restrict));
	END IF;

	IF NEW.netblock_ip_family_restrict IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('netblock_ip_family_restriction'));
		_vq := array_append(_vq, quote_nullable(NEW.netblock_ip_family_restrict));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.val_netblock_collection_type (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.netblock_collection_type = _nr.netblock_collection_type;
	NEW.description = _nr.description;
	NEW.max_num_members = _nr.max_num_members;
	NEW.max_num_collections = _nr.max_num_collections;
	NEW.can_have_hierarchy = CASE WHEN _nr.can_have_hierarchy = true THEN 'Y' WHEN _nr.can_have_hierarchy = false THEN 'N' ELSE NULL END;
	NEW.netblock_single_addr_restrict = _nr.netblock_is_single_address_restriction;
	NEW.netblock_ip_family_restrict = _nr.netblock_ip_family_restriction;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_netblock_collection_type_ins
	ON jazzhands_legacy.val_netblock_collection_type;
CREATE TRIGGER trigger_val_netblock_collection_type_ins
	INSTEAD OF INSERT ON jazzhands_legacy.val_netblock_collection_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_netblock_collection_type_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_netblock_collection_type_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.val_netblock_collection_type%rowtype;
	_nr	jazzhands.val_netblock_collection_type%rowtype;
	_uq	text[];
BEGIN

	IF OLD.netblock_collection_type IS DISTINCT FROM NEW.netblock_collection_type THEN
_uq := array_append(_uq, 'netblock_collection_type = ' || quote_nullable(NEW.netblock_collection_type));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.max_num_members IS DISTINCT FROM NEW.max_num_members THEN
_uq := array_append(_uq, 'max_num_members = ' || quote_nullable(NEW.max_num_members));
	END IF;

	IF OLD.max_num_collections IS DISTINCT FROM NEW.max_num_collections THEN
_uq := array_append(_uq, 'max_num_collections = ' || quote_nullable(NEW.max_num_collections));
	END IF;

	IF OLD.can_have_hierarchy IS DISTINCT FROM NEW.can_have_hierarchy THEN
IF NEW.can_have_hierarchy = 'Y' THEN
	_uq := array_append(_uq, 'can_have_hierarchy = true');
ELSIF NEW.can_have_hierarchy = 'N' THEN
	_uq := array_append(_uq, 'can_have_hierarchy = false');
ELSE
	_uq := array_append(_uq, 'can_have_hierarchy = NULL');
END IF;
	END IF;

	IF OLD.netblock_single_addr_restrict IS DISTINCT FROM NEW.netblock_single_addr_restrict THEN
_uq := array_append(_uq, 'netblock_is_single_address_restriction = ' || quote_nullable(NEW.netblock_single_addr_restrict));
	END IF;

	IF OLD.netblock_ip_family_restrict IS DISTINCT FROM NEW.netblock_ip_family_restrict THEN
_uq := array_append(_uq, 'netblock_ip_family_restriction = ' || quote_nullable(NEW.netblock_ip_family_restrict));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.val_netblock_collection_type SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  netblock_collection_type = $1 RETURNING *'  USING OLD.netblock_collection_type
			INTO _nr;

		NEW.netblock_collection_type = _nr.netblock_collection_type;
		NEW.description = _nr.description;
		NEW.max_num_members = _nr.max_num_members;
		NEW.max_num_collections = _nr.max_num_collections;
		NEW.can_have_hierarchy = CASE WHEN _nr.can_have_hierarchy = true THEN 'Y' WHEN _nr.can_have_hierarchy = false THEN 'N' ELSE NULL END;
		NEW.netblock_single_addr_restrict = _nr.netblock_is_single_address_restriction;
		NEW.netblock_ip_family_restrict = _nr.netblock_ip_family_restriction;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_netblock_collection_type_upd
	ON jazzhands_legacy.val_netblock_collection_type;
CREATE TRIGGER trigger_val_netblock_collection_type_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.val_netblock_collection_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_netblock_collection_type_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_netblock_collection_type_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.val_netblock_collection_type%rowtype;
BEGIN
	DELETE FROM jazzhands.val_netblock_collection_type
	WHERE  netblock_collection_type = OLD.netblock_collection_type  RETURNING *
	INTO _or;
	OLD.netblock_collection_type = _or.netblock_collection_type;
	OLD.description = _or.description;
	OLD.max_num_members = _or.max_num_members;
	OLD.max_num_collections = _or.max_num_collections;
	OLD.can_have_hierarchy = CASE WHEN _or.can_have_hierarchy = true THEN 'Y' WHEN _or.can_have_hierarchy = false THEN 'N' ELSE NULL END;
	OLD.netblock_single_addr_restrict = _or.netblock_is_single_address_restriction;
	OLD.netblock_ip_family_restrict = _or.netblock_ip_family_restriction;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_netblock_collection_type_del
	ON jazzhands_legacy.val_netblock_collection_type;
CREATE TRIGGER trigger_val_netblock_collection_type_del
	INSTEAD OF DELETE ON jazzhands_legacy.val_netblock_collection_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_netblock_collection_type_del();


-- Triggers for val_netblock_type

CREATE OR REPLACE FUNCTION jazzhands_legacy.val_netblock_type_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.val_netblock_type%rowtype;
BEGIN

	IF NEW.netblock_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('netblock_type'));
		_vq := array_append(_vq, quote_nullable(NEW.netblock_type));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.db_forced_hierarchy IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('db_forced_hierarchy'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.db_forced_hierarchy = 'Y' THEN true WHEN NEW.db_forced_hierarchy = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.is_validated_hierarchy IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_validated_hierarchy'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_validated_hierarchy = 'Y' THEN true WHEN NEW.is_validated_hierarchy = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.val_netblock_type (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.netblock_type = _nr.netblock_type;
	NEW.description = _nr.description;
	NEW.db_forced_hierarchy = CASE WHEN _nr.db_forced_hierarchy = true THEN 'Y' WHEN _nr.db_forced_hierarchy = false THEN 'N' ELSE NULL END;
	NEW.is_validated_hierarchy = CASE WHEN _nr.is_validated_hierarchy = true THEN 'Y' WHEN _nr.is_validated_hierarchy = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_netblock_type_ins
	ON jazzhands_legacy.val_netblock_type;
CREATE TRIGGER trigger_val_netblock_type_ins
	INSTEAD OF INSERT ON jazzhands_legacy.val_netblock_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_netblock_type_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_netblock_type_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.val_netblock_type%rowtype;
	_nr	jazzhands.val_netblock_type%rowtype;
	_uq	text[];
BEGIN

	IF OLD.netblock_type IS DISTINCT FROM NEW.netblock_type THEN
_uq := array_append(_uq, 'netblock_type = ' || quote_nullable(NEW.netblock_type));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.db_forced_hierarchy IS DISTINCT FROM NEW.db_forced_hierarchy THEN
IF NEW.db_forced_hierarchy = 'Y' THEN
	_uq := array_append(_uq, 'db_forced_hierarchy = true');
ELSIF NEW.db_forced_hierarchy = 'N' THEN
	_uq := array_append(_uq, 'db_forced_hierarchy = false');
ELSE
	_uq := array_append(_uq, 'db_forced_hierarchy = NULL');
END IF;
	END IF;

	IF OLD.is_validated_hierarchy IS DISTINCT FROM NEW.is_validated_hierarchy THEN
IF NEW.is_validated_hierarchy = 'Y' THEN
	_uq := array_append(_uq, 'is_validated_hierarchy = true');
ELSIF NEW.is_validated_hierarchy = 'N' THEN
	_uq := array_append(_uq, 'is_validated_hierarchy = false');
ELSE
	_uq := array_append(_uq, 'is_validated_hierarchy = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.val_netblock_type SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  netblock_type = $1 RETURNING *'  USING OLD.netblock_type
			INTO _nr;

		NEW.netblock_type = _nr.netblock_type;
		NEW.description = _nr.description;
		NEW.db_forced_hierarchy = CASE WHEN _nr.db_forced_hierarchy = true THEN 'Y' WHEN _nr.db_forced_hierarchy = false THEN 'N' ELSE NULL END;
		NEW.is_validated_hierarchy = CASE WHEN _nr.is_validated_hierarchy = true THEN 'Y' WHEN _nr.is_validated_hierarchy = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_netblock_type_upd
	ON jazzhands_legacy.val_netblock_type;
CREATE TRIGGER trigger_val_netblock_type_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.val_netblock_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_netblock_type_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_netblock_type_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.val_netblock_type%rowtype;
BEGIN
	DELETE FROM jazzhands.val_netblock_type
	WHERE  netblock_type = OLD.netblock_type  RETURNING *
	INTO _or;
	OLD.netblock_type = _or.netblock_type;
	OLD.description = _or.description;
	OLD.db_forced_hierarchy = CASE WHEN _or.db_forced_hierarchy = true THEN 'Y' WHEN _or.db_forced_hierarchy = false THEN 'N' ELSE NULL END;
	OLD.is_validated_hierarchy = CASE WHEN _or.is_validated_hierarchy = true THEN 'Y' WHEN _or.is_validated_hierarchy = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_netblock_type_del
	ON jazzhands_legacy.val_netblock_type;
CREATE TRIGGER trigger_val_netblock_type_del
	INSTEAD OF DELETE ON jazzhands_legacy.val_netblock_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_netblock_type_del();


-- Triggers for val_network_range_type

CREATE OR REPLACE FUNCTION jazzhands_legacy.val_network_range_type_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.val_network_range_type%rowtype;
BEGIN

	IF NEW.network_range_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('network_range_type'));
		_vq := array_append(_vq, quote_nullable(NEW.network_range_type));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.dns_domain_required IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('dns_domain_required'));
		_vq := array_append(_vq, quote_nullable(NEW.dns_domain_required));
	END IF;

	IF NEW.default_dns_prefix IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('default_dns_prefix'));
		_vq := array_append(_vq, quote_nullable(NEW.default_dns_prefix));
	END IF;

	IF NEW.netblock_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('netblock_type'));
		_vq := array_append(_vq, quote_nullable(NEW.netblock_type));
	END IF;

	IF NEW.can_overlap IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('can_overlap'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.can_overlap = 'Y' THEN true WHEN NEW.can_overlap = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.require_cidr_boundary IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('require_cidr_boundary'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.require_cidr_boundary = 'Y' THEN true WHEN NEW.require_cidr_boundary = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.val_network_range_type (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.network_range_type = _nr.network_range_type;
	NEW.description = _nr.description;
	NEW.dns_domain_required = _nr.dns_domain_required;
	NEW.default_dns_prefix = _nr.default_dns_prefix;
	NEW.netblock_type = _nr.netblock_type;
	NEW.can_overlap = CASE WHEN _nr.can_overlap = true THEN 'Y' WHEN _nr.can_overlap = false THEN 'N' ELSE NULL END;
	NEW.require_cidr_boundary = CASE WHEN _nr.require_cidr_boundary = true THEN 'Y' WHEN _nr.require_cidr_boundary = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_network_range_type_ins
	ON jazzhands_legacy.val_network_range_type;
CREATE TRIGGER trigger_val_network_range_type_ins
	INSTEAD OF INSERT ON jazzhands_legacy.val_network_range_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_network_range_type_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_network_range_type_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.val_network_range_type%rowtype;
	_nr	jazzhands.val_network_range_type%rowtype;
	_uq	text[];
BEGIN

	IF OLD.network_range_type IS DISTINCT FROM NEW.network_range_type THEN
_uq := array_append(_uq, 'network_range_type = ' || quote_nullable(NEW.network_range_type));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.dns_domain_required IS DISTINCT FROM NEW.dns_domain_required THEN
_uq := array_append(_uq, 'dns_domain_required = ' || quote_nullable(NEW.dns_domain_required));
	END IF;

	IF OLD.default_dns_prefix IS DISTINCT FROM NEW.default_dns_prefix THEN
_uq := array_append(_uq, 'default_dns_prefix = ' || quote_nullable(NEW.default_dns_prefix));
	END IF;

	IF OLD.netblock_type IS DISTINCT FROM NEW.netblock_type THEN
_uq := array_append(_uq, 'netblock_type = ' || quote_nullable(NEW.netblock_type));
	END IF;

	IF OLD.can_overlap IS DISTINCT FROM NEW.can_overlap THEN
IF NEW.can_overlap = 'Y' THEN
	_uq := array_append(_uq, 'can_overlap = true');
ELSIF NEW.can_overlap = 'N' THEN
	_uq := array_append(_uq, 'can_overlap = false');
ELSE
	_uq := array_append(_uq, 'can_overlap = NULL');
END IF;
	END IF;

	IF OLD.require_cidr_boundary IS DISTINCT FROM NEW.require_cidr_boundary THEN
IF NEW.require_cidr_boundary = 'Y' THEN
	_uq := array_append(_uq, 'require_cidr_boundary = true');
ELSIF NEW.require_cidr_boundary = 'N' THEN
	_uq := array_append(_uq, 'require_cidr_boundary = false');
ELSE
	_uq := array_append(_uq, 'require_cidr_boundary = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.val_network_range_type SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  network_range_type = $1 RETURNING *'  USING OLD.network_range_type
			INTO _nr;

		NEW.network_range_type = _nr.network_range_type;
		NEW.description = _nr.description;
		NEW.dns_domain_required = _nr.dns_domain_required;
		NEW.default_dns_prefix = _nr.default_dns_prefix;
		NEW.netblock_type = _nr.netblock_type;
		NEW.can_overlap = CASE WHEN _nr.can_overlap = true THEN 'Y' WHEN _nr.can_overlap = false THEN 'N' ELSE NULL END;
		NEW.require_cidr_boundary = CASE WHEN _nr.require_cidr_boundary = true THEN 'Y' WHEN _nr.require_cidr_boundary = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_network_range_type_upd
	ON jazzhands_legacy.val_network_range_type;
CREATE TRIGGER trigger_val_network_range_type_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.val_network_range_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_network_range_type_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_network_range_type_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.val_network_range_type%rowtype;
BEGIN
	DELETE FROM jazzhands.val_network_range_type
	WHERE  network_range_type = OLD.network_range_type  RETURNING *
	INTO _or;
	OLD.network_range_type = _or.network_range_type;
	OLD.description = _or.description;
	OLD.dns_domain_required = _or.dns_domain_required;
	OLD.default_dns_prefix = _or.default_dns_prefix;
	OLD.netblock_type = _or.netblock_type;
	OLD.can_overlap = CASE WHEN _or.can_overlap = true THEN 'Y' WHEN _or.can_overlap = false THEN 'N' ELSE NULL END;
	OLD.require_cidr_boundary = CASE WHEN _or.require_cidr_boundary = true THEN 'Y' WHEN _or.require_cidr_boundary = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_network_range_type_del
	ON jazzhands_legacy.val_network_range_type;
CREATE TRIGGER trigger_val_network_range_type_del
	INSTEAD OF DELETE ON jazzhands_legacy.val_network_range_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_network_range_type_del();


-- Triggers for val_person_image_usage

CREATE OR REPLACE FUNCTION jazzhands_legacy.val_person_image_usage_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.val_person_image_usage%rowtype;
BEGIN

	IF NEW.person_image_usage IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('person_image_usage'));
		_vq := array_append(_vq, quote_nullable(NEW.person_image_usage));
	END IF;

	IF NEW.is_multivalue IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_multivalue'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_multivalue = 'Y' THEN true WHEN NEW.is_multivalue = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.val_person_image_usage (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.person_image_usage = _nr.person_image_usage;
	NEW.is_multivalue = CASE WHEN _nr.is_multivalue = true THEN 'Y' WHEN _nr.is_multivalue = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_person_image_usage_ins
	ON jazzhands_legacy.val_person_image_usage;
CREATE TRIGGER trigger_val_person_image_usage_ins
	INSTEAD OF INSERT ON jazzhands_legacy.val_person_image_usage
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_person_image_usage_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_person_image_usage_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.val_person_image_usage%rowtype;
	_nr	jazzhands.val_person_image_usage%rowtype;
	_uq	text[];
BEGIN

	IF OLD.person_image_usage IS DISTINCT FROM NEW.person_image_usage THEN
_uq := array_append(_uq, 'person_image_usage = ' || quote_nullable(NEW.person_image_usage));
	END IF;

	IF OLD.is_multivalue IS DISTINCT FROM NEW.is_multivalue THEN
IF NEW.is_multivalue = 'Y' THEN
	_uq := array_append(_uq, 'is_multivalue = true');
ELSIF NEW.is_multivalue = 'N' THEN
	_uq := array_append(_uq, 'is_multivalue = false');
ELSE
	_uq := array_append(_uq, 'is_multivalue = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.val_person_image_usage SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  person_image_usage = $1 RETURNING *'  USING OLD.person_image_usage
			INTO _nr;

		NEW.person_image_usage = _nr.person_image_usage;
		NEW.is_multivalue = CASE WHEN _nr.is_multivalue = true THEN 'Y' WHEN _nr.is_multivalue = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_person_image_usage_upd
	ON jazzhands_legacy.val_person_image_usage;
CREATE TRIGGER trigger_val_person_image_usage_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.val_person_image_usage
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_person_image_usage_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_person_image_usage_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.val_person_image_usage%rowtype;
BEGIN
	DELETE FROM jazzhands.val_person_image_usage
	WHERE  person_image_usage = OLD.person_image_usage  RETURNING *
	INTO _or;
	OLD.person_image_usage = _or.person_image_usage;
	OLD.is_multivalue = CASE WHEN _or.is_multivalue = true THEN 'Y' WHEN _or.is_multivalue = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_person_image_usage_del
	ON jazzhands_legacy.val_person_image_usage;
CREATE TRIGGER trigger_val_person_image_usage_del
	INSTEAD OF DELETE ON jazzhands_legacy.val_person_image_usage
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_person_image_usage_del();


-- Triggers for val_person_status

CREATE OR REPLACE FUNCTION jazzhands_legacy.val_person_status_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.val_person_status%rowtype;
BEGIN

	IF NEW.person_status IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('person_status'));
		_vq := array_append(_vq, quote_nullable(NEW.person_status));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.is_enabled IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_enabled'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_enabled = 'Y' THEN true WHEN NEW.is_enabled = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.propagate_from_person IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('propagate_from_person'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.propagate_from_person = 'Y' THEN true WHEN NEW.propagate_from_person = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.is_forced IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_forced'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_forced = 'Y' THEN true WHEN NEW.is_forced = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.is_db_enforced IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_db_enforced'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_db_enforced = 'Y' THEN true WHEN NEW.is_db_enforced = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.val_person_status (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.person_status = _nr.person_status;
	NEW.description = _nr.description;
	NEW.is_enabled = CASE WHEN _nr.is_enabled = true THEN 'Y' WHEN _nr.is_enabled = false THEN 'N' ELSE NULL END;
	NEW.propagate_from_person = CASE WHEN _nr.propagate_from_person = true THEN 'Y' WHEN _nr.propagate_from_person = false THEN 'N' ELSE NULL END;
	NEW.is_forced = CASE WHEN _nr.is_forced = true THEN 'Y' WHEN _nr.is_forced = false THEN 'N' ELSE NULL END;
	NEW.is_db_enforced = CASE WHEN _nr.is_db_enforced = true THEN 'Y' WHEN _nr.is_db_enforced = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_person_status_ins
	ON jazzhands_legacy.val_person_status;
CREATE TRIGGER trigger_val_person_status_ins
	INSTEAD OF INSERT ON jazzhands_legacy.val_person_status
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_person_status_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_person_status_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.val_person_status%rowtype;
	_nr	jazzhands.val_person_status%rowtype;
	_uq	text[];
BEGIN

	IF OLD.person_status IS DISTINCT FROM NEW.person_status THEN
_uq := array_append(_uq, 'person_status = ' || quote_nullable(NEW.person_status));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.is_enabled IS DISTINCT FROM NEW.is_enabled THEN
IF NEW.is_enabled = 'Y' THEN
	_uq := array_append(_uq, 'is_enabled = true');
ELSIF NEW.is_enabled = 'N' THEN
	_uq := array_append(_uq, 'is_enabled = false');
ELSE
	_uq := array_append(_uq, 'is_enabled = NULL');
END IF;
	END IF;

	IF OLD.propagate_from_person IS DISTINCT FROM NEW.propagate_from_person THEN
IF NEW.propagate_from_person = 'Y' THEN
	_uq := array_append(_uq, 'propagate_from_person = true');
ELSIF NEW.propagate_from_person = 'N' THEN
	_uq := array_append(_uq, 'propagate_from_person = false');
ELSE
	_uq := array_append(_uq, 'propagate_from_person = NULL');
END IF;
	END IF;

	IF OLD.is_forced IS DISTINCT FROM NEW.is_forced THEN
IF NEW.is_forced = 'Y' THEN
	_uq := array_append(_uq, 'is_forced = true');
ELSIF NEW.is_forced = 'N' THEN
	_uq := array_append(_uq, 'is_forced = false');
ELSE
	_uq := array_append(_uq, 'is_forced = NULL');
END IF;
	END IF;

	IF OLD.is_db_enforced IS DISTINCT FROM NEW.is_db_enforced THEN
IF NEW.is_db_enforced = 'Y' THEN
	_uq := array_append(_uq, 'is_db_enforced = true');
ELSIF NEW.is_db_enforced = 'N' THEN
	_uq := array_append(_uq, 'is_db_enforced = false');
ELSE
	_uq := array_append(_uq, 'is_db_enforced = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.val_person_status SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  person_status = $1 RETURNING *'  USING OLD.person_status
			INTO _nr;

		NEW.person_status = _nr.person_status;
		NEW.description = _nr.description;
		NEW.is_enabled = CASE WHEN _nr.is_enabled = true THEN 'Y' WHEN _nr.is_enabled = false THEN 'N' ELSE NULL END;
		NEW.propagate_from_person = CASE WHEN _nr.propagate_from_person = true THEN 'Y' WHEN _nr.propagate_from_person = false THEN 'N' ELSE NULL END;
		NEW.is_forced = CASE WHEN _nr.is_forced = true THEN 'Y' WHEN _nr.is_forced = false THEN 'N' ELSE NULL END;
		NEW.is_db_enforced = CASE WHEN _nr.is_db_enforced = true THEN 'Y' WHEN _nr.is_db_enforced = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_person_status_upd
	ON jazzhands_legacy.val_person_status;
CREATE TRIGGER trigger_val_person_status_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.val_person_status
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_person_status_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_person_status_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.val_person_status%rowtype;
BEGIN
	DELETE FROM jazzhands.val_person_status
	WHERE  person_status = OLD.person_status  RETURNING *
	INTO _or;
	OLD.person_status = _or.person_status;
	OLD.description = _or.description;
	OLD.is_enabled = CASE WHEN _or.is_enabled = true THEN 'Y' WHEN _or.is_enabled = false THEN 'N' ELSE NULL END;
	OLD.propagate_from_person = CASE WHEN _or.propagate_from_person = true THEN 'Y' WHEN _or.propagate_from_person = false THEN 'N' ELSE NULL END;
	OLD.is_forced = CASE WHEN _or.is_forced = true THEN 'Y' WHEN _or.is_forced = false THEN 'N' ELSE NULL END;
	OLD.is_db_enforced = CASE WHEN _or.is_db_enforced = true THEN 'Y' WHEN _or.is_db_enforced = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_person_status_del
	ON jazzhands_legacy.val_person_status;
CREATE TRIGGER trigger_val_person_status_del
	INSTEAD OF DELETE ON jazzhands_legacy.val_person_status
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_person_status_del();


-- Triggers for val_property

CREATE OR REPLACE FUNCTION jazzhands_legacy.val_property_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.val_property%rowtype;
BEGIN

	IF NEW.property_name IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('property_name'));
		_vq := array_append(_vq, quote_nullable(NEW.property_name));
	END IF;

	IF NEW.property_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('property_type'));
		_vq := array_append(_vq, quote_nullable(NEW.property_type));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.account_collection_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('account_collection_type'));
		_vq := array_append(_vq, quote_nullable(NEW.account_collection_type));
	END IF;

	IF NEW.company_collection_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('company_collection_type'));
		_vq := array_append(_vq, quote_nullable(NEW.company_collection_type));
	END IF;

	IF NEW.device_collection_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('device_collection_type'));
		_vq := array_append(_vq, quote_nullable(NEW.device_collection_type));
	END IF;

	IF NEW.dns_domain_collection_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('dns_domain_collection_type'));
		_vq := array_append(_vq, quote_nullable(NEW.dns_domain_collection_type));
	END IF;

	IF NEW.layer2_network_collection_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('layer2_network_collection_type'));
		_vq := array_append(_vq, quote_nullable(NEW.layer2_network_collection_type));
	END IF;

	IF NEW.layer3_network_collection_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('layer3_network_collection_type'));
		_vq := array_append(_vq, quote_nullable(NEW.layer3_network_collection_type));
	END IF;

	IF NEW.netblock_collection_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('netblock_collection_type'));
		_vq := array_append(_vq, quote_nullable(NEW.netblock_collection_type));
	END IF;

	IF NEW.network_range_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('network_range_type'));
		_vq := array_append(_vq, quote_nullable(NEW.network_range_type));
	END IF;

	IF NEW.property_collection_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('property_name_collection_type'));
		_vq := array_append(_vq, quote_nullable(NEW.property_collection_type));
	END IF;

	IF NEW.service_env_collection_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('service_environment_collection_type'));
		_vq := array_append(_vq, quote_nullable(NEW.service_env_collection_type));
	END IF;

	IF NEW.is_multivalue IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_multivalue'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_multivalue = 'Y' THEN true WHEN NEW.is_multivalue = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.prop_val_acct_coll_type_rstrct IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('property_value_account_collection_type_restriction'));
		_vq := array_append(_vq, quote_nullable(NEW.prop_val_acct_coll_type_rstrct));
	END IF;

	IF NEW.prop_val_dev_coll_type_rstrct IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('property_value_device_collection_type_restriction'));
		_vq := array_append(_vq, quote_nullable(NEW.prop_val_dev_coll_type_rstrct));
	END IF;

	IF NEW.prop_val_nblk_coll_type_rstrct IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('property_value_netblock_collection_type_restriction'));
		_vq := array_append(_vq, quote_nullable(NEW.prop_val_nblk_coll_type_rstrct));
	END IF;

	IF NEW.property_data_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('property_data_type'));
		_vq := array_append(_vq, quote_nullable(NEW.property_data_type));
	END IF;

	IF NEW.property_value_json_schema IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('property_value_json_schema'));
		_vq := array_append(_vq, quote_nullable(NEW.property_value_json_schema));
	END IF;

	IF NEW.permit_account_collection_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('permit_account_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.permit_account_collection_id));
	END IF;

	IF NEW.permit_account_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('permit_account_id'));
		_vq := array_append(_vq, quote_nullable(NEW.permit_account_id));
	END IF;

	IF NEW.permit_account_realm_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('permit_account_realm_id'));
		_vq := array_append(_vq, quote_nullable(NEW.permit_account_realm_id));
	END IF;

	IF NEW.permit_company_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('permit_company_id'));
		_vq := array_append(_vq, quote_nullable(NEW.permit_company_id));
	END IF;

	IF NEW.permit_company_collection_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('permit_company_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.permit_company_collection_id));
	END IF;

	IF NEW.permit_device_collection_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('permit_device_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.permit_device_collection_id));
	END IF;

	IF NEW.permit_dns_domain_coll_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('permit_dns_domain_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.permit_dns_domain_coll_id));
	END IF;

	IF NEW.permit_layer2_network_coll_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('permit_layer2_network_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.permit_layer2_network_coll_id));
	END IF;

	IF NEW.permit_layer3_network_coll_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('permit_layer3_network_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.permit_layer3_network_coll_id));
	END IF;

	IF NEW.permit_netblock_collection_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('permit_netblock_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.permit_netblock_collection_id));
	END IF;

	IF NEW.permit_network_range_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('permit_network_range_id'));
		_vq := array_append(_vq, quote_nullable(NEW.permit_network_range_id));
	END IF;

	IF NEW.permit_operating_system_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('permit_operating_system_id'));
		_vq := array_append(_vq, quote_nullable(NEW.permit_operating_system_id));
	END IF;

	IF NEW.permit_os_snapshot_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('permit_operating_system_snapshot_id'));
		_vq := array_append(_vq, quote_nullable(NEW.permit_os_snapshot_id));
	END IF;

	IF NEW.permit_property_collection_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('permit_property_name_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.permit_property_collection_id));
	END IF;

	IF NEW.permit_service_env_collection IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('permit_service_environment_collection_id'));
		_vq := array_append(_vq, quote_nullable(NEW.permit_service_env_collection));
	END IF;

	IF NEW.permit_site_code IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('permit_site_code'));
		_vq := array_append(_vq, quote_nullable(NEW.permit_site_code));
	END IF;

	IF NEW.permit_x509_signed_cert_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('permit_x509_signed_certificate_id'));
		_vq := array_append(_vq, quote_nullable(NEW.permit_x509_signed_cert_id));
	END IF;

	IF NEW.permit_property_rank IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('permit_property_rank'));
		_vq := array_append(_vq, quote_nullable(NEW.permit_property_rank));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.val_property (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.property_name = _nr.property_name;
	NEW.property_type = _nr.property_type;
	NEW.description = _nr.description;
	NEW.account_collection_type = _nr.account_collection_type;
	NEW.company_collection_type = _nr.company_collection_type;
	NEW.device_collection_type = _nr.device_collection_type;
	NEW.dns_domain_collection_type = _nr.dns_domain_collection_type;
	NEW.layer2_network_collection_type = _nr.layer2_network_collection_type;
	NEW.layer3_network_collection_type = _nr.layer3_network_collection_type;
	NEW.netblock_collection_type = _nr.netblock_collection_type;
	NEW.network_range_type = _nr.network_range_type;
	NEW.property_collection_type = _nr.property_name_collection_type;
	NEW.service_env_collection_type = _nr.service_environment_collection_type;
	NEW.is_multivalue = CASE WHEN _nr.is_multivalue = true THEN 'Y' WHEN _nr.is_multivalue = false THEN 'N' ELSE NULL END;
	NEW.prop_val_acct_coll_type_rstrct = _nr.property_value_account_collection_type_restriction;
	NEW.prop_val_dev_coll_type_rstrct = _nr.property_value_device_collection_type_restriction;
	NEW.prop_val_nblk_coll_type_rstrct = _nr.property_value_netblock_collection_type_restriction;
	NEW.property_data_type = _nr.property_data_type;
	NEW.property_value_json_schema = _nr.property_value_json_schema;
	NEW.permit_account_collection_id = _nr.permit_account_collection_id;
	NEW.permit_account_id = _nr.permit_account_id;
	NEW.permit_account_realm_id = _nr.permit_account_realm_id;
	NEW.permit_company_id = _nr.permit_company_id;
	NEW.permit_company_collection_id = _nr.permit_company_collection_id;
	NEW.permit_device_collection_id = _nr.permit_device_collection_id;
	NEW.permit_dns_domain_coll_id = _nr.permit_dns_domain_collection_id;
	NEW.permit_layer2_network_coll_id = _nr.permit_layer2_network_collection_id;
	NEW.permit_layer3_network_coll_id = _nr.permit_layer3_network_collection_id;
	NEW.permit_netblock_collection_id = _nr.permit_netblock_collection_id;
	NEW.permit_network_range_id = _nr.permit_network_range_id;
	NEW.permit_operating_system_id = _nr.permit_operating_system_id;
	NEW.permit_os_snapshot_id = _nr.permit_operating_system_snapshot_id;
	NEW.permit_property_collection_id = _nr.permit_property_name_collection_id;
	NEW.permit_service_env_collection = _nr.permit_service_environment_collection_id;
	NEW.permit_site_code = _nr.permit_site_code;
	NEW.permit_x509_signed_cert_id = _nr.permit_x509_signed_certificate_id;
	NEW.permit_property_rank = _nr.permit_property_rank;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_property_ins
	ON jazzhands_legacy.val_property;
CREATE TRIGGER trigger_val_property_ins
	INSTEAD OF INSERT ON jazzhands_legacy.val_property
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_property_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_property_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.val_property%rowtype;
	_nr	jazzhands.val_property%rowtype;
	_uq	text[];
BEGIN

	IF OLD.property_name IS DISTINCT FROM NEW.property_name THEN
_uq := array_append(_uq, 'property_name = ' || quote_nullable(NEW.property_name));
	END IF;

	IF OLD.property_type IS DISTINCT FROM NEW.property_type THEN
_uq := array_append(_uq, 'property_type = ' || quote_nullable(NEW.property_type));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.account_collection_type IS DISTINCT FROM NEW.account_collection_type THEN
_uq := array_append(_uq, 'account_collection_type = ' || quote_nullable(NEW.account_collection_type));
	END IF;

	IF OLD.company_collection_type IS DISTINCT FROM NEW.company_collection_type THEN
_uq := array_append(_uq, 'company_collection_type = ' || quote_nullable(NEW.company_collection_type));
	END IF;

	IF OLD.device_collection_type IS DISTINCT FROM NEW.device_collection_type THEN
_uq := array_append(_uq, 'device_collection_type = ' || quote_nullable(NEW.device_collection_type));
	END IF;

	IF OLD.dns_domain_collection_type IS DISTINCT FROM NEW.dns_domain_collection_type THEN
_uq := array_append(_uq, 'dns_domain_collection_type = ' || quote_nullable(NEW.dns_domain_collection_type));
	END IF;

	IF OLD.layer2_network_collection_type IS DISTINCT FROM NEW.layer2_network_collection_type THEN
_uq := array_append(_uq, 'layer2_network_collection_type = ' || quote_nullable(NEW.layer2_network_collection_type));
	END IF;

	IF OLD.layer3_network_collection_type IS DISTINCT FROM NEW.layer3_network_collection_type THEN
_uq := array_append(_uq, 'layer3_network_collection_type = ' || quote_nullable(NEW.layer3_network_collection_type));
	END IF;

	IF OLD.netblock_collection_type IS DISTINCT FROM NEW.netblock_collection_type THEN
_uq := array_append(_uq, 'netblock_collection_type = ' || quote_nullable(NEW.netblock_collection_type));
	END IF;

	IF OLD.network_range_type IS DISTINCT FROM NEW.network_range_type THEN
_uq := array_append(_uq, 'network_range_type = ' || quote_nullable(NEW.network_range_type));
	END IF;

	IF OLD.property_collection_type IS DISTINCT FROM NEW.property_collection_type THEN
_uq := array_append(_uq, 'property_name_collection_type = ' || quote_nullable(NEW.property_collection_type));
	END IF;

	IF OLD.service_env_collection_type IS DISTINCT FROM NEW.service_env_collection_type THEN
_uq := array_append(_uq, 'service_environment_collection_type = ' || quote_nullable(NEW.service_env_collection_type));
	END IF;

	IF OLD.is_multivalue IS DISTINCT FROM NEW.is_multivalue THEN
IF NEW.is_multivalue = 'Y' THEN
	_uq := array_append(_uq, 'is_multivalue = true');
ELSIF NEW.is_multivalue = 'N' THEN
	_uq := array_append(_uq, 'is_multivalue = false');
ELSE
	_uq := array_append(_uq, 'is_multivalue = NULL');
END IF;
	END IF;

	IF OLD.prop_val_acct_coll_type_rstrct IS DISTINCT FROM NEW.prop_val_acct_coll_type_rstrct THEN
_uq := array_append(_uq, 'property_value_account_collection_type_restriction = ' || quote_nullable(NEW.prop_val_acct_coll_type_rstrct));
	END IF;

	IF OLD.prop_val_dev_coll_type_rstrct IS DISTINCT FROM NEW.prop_val_dev_coll_type_rstrct THEN
_uq := array_append(_uq, 'property_value_device_collection_type_restriction = ' || quote_nullable(NEW.prop_val_dev_coll_type_rstrct));
	END IF;

	IF OLD.prop_val_nblk_coll_type_rstrct IS DISTINCT FROM NEW.prop_val_nblk_coll_type_rstrct THEN
_uq := array_append(_uq, 'property_value_netblock_collection_type_restriction = ' || quote_nullable(NEW.prop_val_nblk_coll_type_rstrct));
	END IF;

	IF OLD.property_data_type IS DISTINCT FROM NEW.property_data_type THEN
		_uq := array_append(_uq, 'property_data_type = ' || quote_nullable(NEW.property_data_type));
	END IF;

	IF OLD.property_value_json_schema IS DISTINCT FROM NEW.property_value_json_schema THEN
_uq := array_append(_uq, 'property_value_json_schema = ' || quote_nullable(NEW.property_value_json_schema));
	END IF;

	IF OLD.permit_account_collection_id IS DISTINCT FROM NEW.permit_account_collection_id THEN
_uq := array_append(_uq, 'permit_account_collection_id = ' || quote_nullable(NEW.permit_account_collection_id));
	END IF;

	IF OLD.permit_account_id IS DISTINCT FROM NEW.permit_account_id THEN
_uq := array_append(_uq, 'permit_account_id = ' || quote_nullable(NEW.permit_account_id));
	END IF;

	IF OLD.permit_account_realm_id IS DISTINCT FROM NEW.permit_account_realm_id THEN
_uq := array_append(_uq, 'permit_account_realm_id = ' || quote_nullable(NEW.permit_account_realm_id));
	END IF;

	IF OLD.permit_company_id IS DISTINCT FROM NEW.permit_company_id THEN
_uq := array_append(_uq, 'permit_company_id = ' || quote_nullable(NEW.permit_company_id));
	END IF;

	IF OLD.permit_company_collection_id IS DISTINCT FROM NEW.permit_company_collection_id THEN
_uq := array_append(_uq, 'permit_company_collection_id = ' || quote_nullable(NEW.permit_company_collection_id));
	END IF;

	IF OLD.permit_device_collection_id IS DISTINCT FROM NEW.permit_device_collection_id THEN
_uq := array_append(_uq, 'permit_device_collection_id = ' || quote_nullable(NEW.permit_device_collection_id));
	END IF;

	IF OLD.permit_dns_domain_coll_id IS DISTINCT FROM NEW.permit_dns_domain_coll_id THEN
_uq := array_append(_uq, 'permit_dns_domain_collection_id = ' || quote_nullable(NEW.permit_dns_domain_coll_id));
	END IF;

	IF OLD.permit_layer2_network_coll_id IS DISTINCT FROM NEW.permit_layer2_network_coll_id THEN
_uq := array_append(_uq, 'permit_layer2_network_collection_id = ' || quote_nullable(NEW.permit_layer2_network_coll_id));
	END IF;

	IF OLD.permit_layer3_network_coll_id IS DISTINCT FROM NEW.permit_layer3_network_coll_id THEN
_uq := array_append(_uq, 'permit_layer3_network_collection_id = ' || quote_nullable(NEW.permit_layer3_network_coll_id));
	END IF;

	IF OLD.permit_netblock_collection_id IS DISTINCT FROM NEW.permit_netblock_collection_id THEN
_uq := array_append(_uq, 'permit_netblock_collection_id = ' || quote_nullable(NEW.permit_netblock_collection_id));
	END IF;

	IF OLD.permit_network_range_id IS DISTINCT FROM NEW.permit_network_range_id THEN
_uq := array_append(_uq, 'permit_network_range_id = ' || quote_nullable(NEW.permit_network_range_id));
	END IF;

	IF OLD.permit_operating_system_id IS DISTINCT FROM NEW.permit_operating_system_id THEN
_uq := array_append(_uq, 'permit_operating_system_id = ' || quote_nullable(NEW.permit_operating_system_id));
	END IF;

	IF OLD.permit_os_snapshot_id IS DISTINCT FROM NEW.permit_os_snapshot_id THEN
_uq := array_append(_uq, 'permit_operating_system_snapshot_id = ' || quote_nullable(NEW.permit_os_snapshot_id));
	END IF;

	IF OLD.permit_property_collection_id IS DISTINCT FROM NEW.permit_property_collection_id THEN
_uq := array_append(_uq, 'permit_property_name_collection_id = ' || quote_nullable(NEW.permit_property_collection_id));
	END IF;

	IF OLD.permit_service_env_collection IS DISTINCT FROM NEW.permit_service_env_collection THEN
_uq := array_append(_uq, 'permit_service_environment_collection_id = ' || quote_nullable(NEW.permit_service_env_collection));
	END IF;

	IF OLD.permit_site_code IS DISTINCT FROM NEW.permit_site_code THEN
_uq := array_append(_uq, 'permit_site_code = ' || quote_nullable(NEW.permit_site_code));
	END IF;

	IF OLD.permit_x509_signed_cert_id IS DISTINCT FROM NEW.permit_x509_signed_cert_id THEN
_uq := array_append(_uq, 'permit_x509_signed_certificate_id = ' || quote_nullable(NEW.permit_x509_signed_cert_id));
	END IF;

	IF OLD.permit_property_rank IS DISTINCT FROM NEW.permit_property_rank THEN
_uq := array_append(_uq, 'permit_property_rank = ' || quote_nullable(NEW.permit_property_rank));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.val_property SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  property_name = $1 AND  property_type = $2 RETURNING *'  USING OLD.property_name, OLD.property_type
			INTO _nr;

		NEW.property_name = _nr.property_name;
		NEW.property_type = _nr.property_type;
		NEW.description = _nr.description;
		NEW.account_collection_type = _nr.account_collection_type;
		NEW.company_collection_type = _nr.company_collection_type;
		NEW.device_collection_type = _nr.device_collection_type;
		NEW.dns_domain_collection_type = _nr.dns_domain_collection_type;
		NEW.layer2_network_collection_type = _nr.layer2_network_collection_type;
		NEW.layer3_network_collection_type = _nr.layer3_network_collection_type;
		NEW.netblock_collection_type = _nr.netblock_collection_type;
		NEW.network_range_type = _nr.network_range_type;
		NEW.property_collection_type = _nr.property_name_collection_type;
		NEW.service_env_collection_type = _nr.service_environment_collection_type;
		NEW.is_multivalue = CASE WHEN _nr.is_multivalue = true THEN 'Y' WHEN _nr.is_multivalue = false THEN 'N' ELSE NULL END;
		NEW.prop_val_acct_coll_type_rstrct = _nr.property_value_account_collection_type_restriction;
		NEW.prop_val_dev_coll_type_rstrct = _nr.property_value_device_collection_type_restriction;
		NEW.prop_val_nblk_coll_type_rstrct = _nr.property_value_netblock_collection_type_restriction;
		NEW.property_data_type = _nr.property_data_type;
		NEW.property_value_json_schema = _nr.property_value_json_schema;
		NEW.permit_account_collection_id = _nr.permit_account_collection_id;
		NEW.permit_account_id = _nr.permit_account_id;
		NEW.permit_account_realm_id = _nr.permit_account_realm_id;
		NEW.permit_company_id = _nr.permit_company_id;
		NEW.permit_company_collection_id = _nr.permit_company_collection_id;
		NEW.permit_device_collection_id = _nr.permit_device_collection_id;
		NEW.permit_dns_domain_coll_id = _nr.permit_dns_domain_collection_id;
		NEW.permit_layer2_network_coll_id = _nr.permit_layer2_network_collection_id;
		NEW.permit_layer3_network_coll_id = _nr.permit_layer3_network_collection_id;
		NEW.permit_netblock_collection_id = _nr.permit_netblock_collection_id;
		NEW.permit_network_range_id = _nr.permit_network_range_id;
		NEW.permit_operating_system_id = _nr.permit_operating_system_id;
		NEW.permit_os_snapshot_id = _nr.permit_operating_system_snapshot_id;
		NEW.permit_property_collection_id = _nr.permit_property_name_collection_id;
		NEW.permit_service_env_collection = _nr.permit_service_environment_collection_id;
		NEW.permit_site_code = _nr.permit_site_code;
		NEW.permit_x509_signed_cert_id = _nr.permit_x509_signed_certificate_id;
		NEW.permit_property_rank = _nr.permit_property_rank;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_property_upd
	ON jazzhands_legacy.val_property;
CREATE TRIGGER trigger_val_property_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.val_property
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_property_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_property_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.val_property%rowtype;
BEGIN
	DELETE FROM jazzhands.val_property
	WHERE  property_name = OLD.property_name  AND  property_type = OLD.property_type  RETURNING *
	INTO _or;
	OLD.property_name = _or.property_name;
	OLD.property_type = _or.property_type;
	OLD.description = _or.description;
	OLD.account_collection_type = _or.account_collection_type;
	OLD.company_collection_type = _or.company_collection_type;
	OLD.device_collection_type = _or.device_collection_type;
	OLD.dns_domain_collection_type = _or.dns_domain_collection_type;
	OLD.layer2_network_collection_type = _or.layer2_network_collection_type;
	OLD.layer3_network_collection_type = _or.layer3_network_collection_type;
	OLD.netblock_collection_type = _or.netblock_collection_type;
	OLD.network_range_type = _or.network_range_type;
	OLD.property_collection_type = _or.property_name_collection_type;
	OLD.service_env_collection_type = _or.service_environment_collection_type;
	OLD.is_multivalue = CASE WHEN _or.is_multivalue = true THEN 'Y' WHEN _or.is_multivalue = false THEN 'N' ELSE NULL END;
	OLD.prop_val_acct_coll_type_rstrct = _or.property_value_account_collection_type_restriction;
	OLD.prop_val_dev_coll_type_rstrct = _or.property_value_device_collection_type_restriction;
	OLD.prop_val_nblk_coll_type_rstrct = _or.property_value_netblock_collection_type_restriction;
	OLD.property_data_type = _or.property_data_type;
	OLD.property_value_json_schema = _or.property_value_json_schema;
	OLD.permit_account_collection_id = _or.permit_account_collection_id;
	OLD.permit_account_id = _or.permit_account_id;
	OLD.permit_account_realm_id = _or.permit_account_realm_id;
	OLD.permit_company_id = _or.permit_company_id;
	OLD.permit_company_collection_id = _or.permit_company_collection_id;
	OLD.permit_device_collection_id = _or.permit_device_collection_id;
	OLD.permit_dns_domain_coll_id = _or.permit_dns_domain_collection_id;
	OLD.permit_layer2_network_coll_id = _or.permit_layer2_network_collection_id;
	OLD.permit_layer3_network_coll_id = _or.permit_layer3_network_collection_id;
	OLD.permit_netblock_collection_id = _or.permit_netblock_collection_id;
	OLD.permit_network_range_id = _or.permit_network_range_id;
	OLD.permit_operating_system_id = _or.permit_operating_system_id;
	OLD.permit_os_snapshot_id = _or.permit_operating_system_snapshot_id;
	OLD.permit_property_collection_id = _or.permit_property_name_collection_id;
	OLD.permit_service_env_collection = _or.permit_service_environment_collection_id;
	OLD.permit_site_code = _or.permit_site_code;
	OLD.permit_x509_signed_cert_id = _or.permit_x509_signed_certificate_id;
	OLD.permit_property_rank = _or.permit_property_rank;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_property_del
	ON jazzhands_legacy.val_property;
CREATE TRIGGER trigger_val_property_del
	INSTEAD OF DELETE ON jazzhands_legacy.val_property
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_property_del();


-- Triggers for val_property_collection_type

CREATE OR REPLACE FUNCTION jazzhands_legacy.val_property_collection_type_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.val_property_name_collection_type%rowtype;
BEGIN

	IF NEW.property_collection_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('property_name_collection_type'));
		_vq := array_append(_vq, quote_nullable(NEW.property_collection_type));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.max_num_members IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('max_num_members'));
		_vq := array_append(_vq, quote_nullable(NEW.max_num_members));
	END IF;

	IF NEW.max_num_collections IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('max_num_collections'));
		_vq := array_append(_vq, quote_nullable(NEW.max_num_collections));
	END IF;

	IF NEW.can_have_hierarchy IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('can_have_hierarchy'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.can_have_hierarchy = 'Y' THEN true WHEN NEW.can_have_hierarchy = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.val_property_name_collection_type (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.property_collection_type = _nr.property_name_collection_type;
	NEW.description = _nr.description;
	NEW.max_num_members = _nr.max_num_members;
	NEW.max_num_collections = _nr.max_num_collections;
	NEW.can_have_hierarchy = CASE WHEN _nr.can_have_hierarchy = true THEN 'Y' WHEN _nr.can_have_hierarchy = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_property_collection_type_ins
	ON jazzhands_legacy.val_property_collection_type;
CREATE TRIGGER trigger_val_property_collection_type_ins
	INSTEAD OF INSERT ON jazzhands_legacy.val_property_collection_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_property_collection_type_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_property_collection_type_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.val_property_collection_type%rowtype;
	_nr	jazzhands.val_property_name_collection_type%rowtype;
	_uq	text[];
BEGIN

	IF OLD.property_collection_type IS DISTINCT FROM NEW.property_collection_type THEN
_uq := array_append(_uq, 'property_name_collection_type = ' || quote_nullable(NEW.property_collection_type));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.max_num_members IS DISTINCT FROM NEW.max_num_members THEN
_uq := array_append(_uq, 'max_num_members = ' || quote_nullable(NEW.max_num_members));
	END IF;

	IF OLD.max_num_collections IS DISTINCT FROM NEW.max_num_collections THEN
_uq := array_append(_uq, 'max_num_collections = ' || quote_nullable(NEW.max_num_collections));
	END IF;

	IF OLD.can_have_hierarchy IS DISTINCT FROM NEW.can_have_hierarchy THEN
IF NEW.can_have_hierarchy = 'Y' THEN
	_uq := array_append(_uq, 'can_have_hierarchy = true');
ELSIF NEW.can_have_hierarchy = 'N' THEN
	_uq := array_append(_uq, 'can_have_hierarchy = false');
ELSE
	_uq := array_append(_uq, 'can_have_hierarchy = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.val_property_name_collection_type SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  property_name_collection_type = $1 RETURNING *'  USING OLD.property_collection_type
			INTO _nr;

		NEW.property_collection_type = _nr.property_name_collection_type;
		NEW.description = _nr.description;
		NEW.max_num_members = _nr.max_num_members;
		NEW.max_num_collections = _nr.max_num_collections;
		NEW.can_have_hierarchy = CASE WHEN _nr.can_have_hierarchy = true THEN 'Y' WHEN _nr.can_have_hierarchy = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_property_collection_type_upd
	ON jazzhands_legacy.val_property_collection_type;
CREATE TRIGGER trigger_val_property_collection_type_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.val_property_collection_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_property_collection_type_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_property_collection_type_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.val_property_name_collection_type%rowtype;
BEGIN
	DELETE FROM jazzhands.val_property_name_collection_type
	WHERE  property_name_collection_type = OLD.property_collection_type  RETURNING *
	INTO _or;
	OLD.property_collection_type = _or.property_name_collection_type;
	OLD.description = _or.description;
	OLD.max_num_members = _or.max_num_members;
	OLD.max_num_collections = _or.max_num_collections;
	OLD.can_have_hierarchy = CASE WHEN _or.can_have_hierarchy = true THEN 'Y' WHEN _or.can_have_hierarchy = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_property_collection_type_del
	ON jazzhands_legacy.val_property_collection_type;
CREATE TRIGGER trigger_val_property_collection_type_del
	INSTEAD OF DELETE ON jazzhands_legacy.val_property_collection_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_property_collection_type_del();


-- Triggers for val_property_type

CREATE OR REPLACE FUNCTION jazzhands_legacy.val_property_type_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.val_property_type%rowtype;
BEGIN

	IF NEW.property_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('property_type'));
		_vq := array_append(_vq, quote_nullable(NEW.property_type));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.prop_val_acct_coll_type_rstrct IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('property_value_account_collection_type_restriction'));
		_vq := array_append(_vq, quote_nullable(NEW.prop_val_acct_coll_type_rstrct));
	END IF;

	IF NEW.is_multivalue IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_multivalue'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_multivalue = 'Y' THEN true WHEN NEW.is_multivalue = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.val_property_type (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.property_type = _nr.property_type;
	NEW.description = _nr.description;
	NEW.prop_val_acct_coll_type_rstrct = _nr.property_value_account_collection_type_restriction;
	NEW.is_multivalue = CASE WHEN _nr.is_multivalue = true THEN 'Y' WHEN _nr.is_multivalue = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_property_type_ins
	ON jazzhands_legacy.val_property_type;
CREATE TRIGGER trigger_val_property_type_ins
	INSTEAD OF INSERT ON jazzhands_legacy.val_property_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_property_type_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_property_type_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.val_property_type%rowtype;
	_nr	jazzhands.val_property_type%rowtype;
	_uq	text[];
BEGIN

	IF OLD.property_type IS DISTINCT FROM NEW.property_type THEN
_uq := array_append(_uq, 'property_type = ' || quote_nullable(NEW.property_type));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.prop_val_acct_coll_type_rstrct IS DISTINCT FROM NEW.prop_val_acct_coll_type_rstrct THEN
_uq := array_append(_uq, 'property_value_account_collection_type_restriction = ' || quote_nullable(NEW.prop_val_acct_coll_type_rstrct));
	END IF;

	IF OLD.is_multivalue IS DISTINCT FROM NEW.is_multivalue THEN
IF NEW.is_multivalue = 'Y' THEN
	_uq := array_append(_uq, 'is_multivalue = true');
ELSIF NEW.is_multivalue = 'N' THEN
	_uq := array_append(_uq, 'is_multivalue = false');
ELSE
	_uq := array_append(_uq, 'is_multivalue = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.val_property_type SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  property_type = $1 RETURNING *'  USING OLD.property_type
			INTO _nr;

		NEW.property_type = _nr.property_type;
		NEW.description = _nr.description;
		NEW.prop_val_acct_coll_type_rstrct = _nr.property_value_account_collection_type_restriction;
		NEW.is_multivalue = CASE WHEN _nr.is_multivalue = true THEN 'Y' WHEN _nr.is_multivalue = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_property_type_upd
	ON jazzhands_legacy.val_property_type;
CREATE TRIGGER trigger_val_property_type_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.val_property_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_property_type_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_property_type_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.val_property_type%rowtype;
BEGIN
	DELETE FROM jazzhands.val_property_type
	WHERE  property_type = OLD.property_type  RETURNING *
	INTO _or;
	OLD.property_type = _or.property_type;
	OLD.description = _or.description;
	OLD.prop_val_acct_coll_type_rstrct = _or.property_value_account_collection_type_restriction;
	OLD.is_multivalue = CASE WHEN _or.is_multivalue = true THEN 'Y' WHEN _or.is_multivalue = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_property_type_del
	ON jazzhands_legacy.val_property_type;
CREATE TRIGGER trigger_val_property_type_del
	INSTEAD OF DELETE ON jazzhands_legacy.val_property_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_property_type_del();


-- Triggers for val_service_env_coll_type

CREATE OR REPLACE FUNCTION jazzhands_legacy.val_service_env_coll_type_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.val_service_environment_collection_type%rowtype;
BEGIN

	IF NEW.service_env_collection_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('service_environment_collection_type'));
		_vq := array_append(_vq, quote_nullable(NEW.service_env_collection_type));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.max_num_members IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('max_num_members'));
		_vq := array_append(_vq, quote_nullable(NEW.max_num_members));
	END IF;

	IF NEW.max_num_collections IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('max_num_collections'));
		_vq := array_append(_vq, quote_nullable(NEW.max_num_collections));
	END IF;

	IF NEW.can_have_hierarchy IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('can_have_hierarchy'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.can_have_hierarchy = 'Y' THEN true WHEN NEW.can_have_hierarchy = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.val_service_environment_collection_type (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.service_env_collection_type = _nr.service_environment_collection_type;
	NEW.description = _nr.description;
	NEW.max_num_members = _nr.max_num_members;
	NEW.max_num_collections = _nr.max_num_collections;
	NEW.can_have_hierarchy = CASE WHEN _nr.can_have_hierarchy = true THEN 'Y' WHEN _nr.can_have_hierarchy = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_service_env_coll_type_ins
	ON jazzhands_legacy.val_service_env_coll_type;
CREATE TRIGGER trigger_val_service_env_coll_type_ins
	INSTEAD OF INSERT ON jazzhands_legacy.val_service_env_coll_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_service_env_coll_type_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_service_env_coll_type_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.val_service_env_coll_type%rowtype;
	_nr	jazzhands.val_service_environment_collection_type%rowtype;
	_uq	text[];
BEGIN

	IF OLD.service_env_collection_type IS DISTINCT FROM NEW.service_env_collection_type THEN
_uq := array_append(_uq, 'service_environment_collection_type = ' || quote_nullable(NEW.service_env_collection_type));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.max_num_members IS DISTINCT FROM NEW.max_num_members THEN
_uq := array_append(_uq, 'max_num_members = ' || quote_nullable(NEW.max_num_members));
	END IF;

	IF OLD.max_num_collections IS DISTINCT FROM NEW.max_num_collections THEN
_uq := array_append(_uq, 'max_num_collections = ' || quote_nullable(NEW.max_num_collections));
	END IF;

	IF OLD.can_have_hierarchy IS DISTINCT FROM NEW.can_have_hierarchy THEN
IF NEW.can_have_hierarchy = 'Y' THEN
	_uq := array_append(_uq, 'can_have_hierarchy = true');
ELSIF NEW.can_have_hierarchy = 'N' THEN
	_uq := array_append(_uq, 'can_have_hierarchy = false');
ELSE
	_uq := array_append(_uq, 'can_have_hierarchy = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.val_service_environment_collection_type SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  service_environment_collection_type = $1 RETURNING *'  USING OLD.service_env_collection_type
			INTO _nr;

		NEW.service_env_collection_type = _nr.service_environment_collection_type;
		NEW.description = _nr.description;
		NEW.max_num_members = _nr.max_num_members;
		NEW.max_num_collections = _nr.max_num_collections;
		NEW.can_have_hierarchy = CASE WHEN _nr.can_have_hierarchy = true THEN 'Y' WHEN _nr.can_have_hierarchy = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_service_env_coll_type_upd
	ON jazzhands_legacy.val_service_env_coll_type;
CREATE TRIGGER trigger_val_service_env_coll_type_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.val_service_env_coll_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_service_env_coll_type_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_service_env_coll_type_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.val_service_environment_collection_type%rowtype;
BEGIN
	DELETE FROM jazzhands.val_service_environment_collection_type
	WHERE  service_environment_collection_type = OLD.service_env_collection_type  RETURNING *
	INTO _or;
	OLD.service_env_collection_type = _or.service_environment_collection_type;
	OLD.description = _or.description;
	OLD.max_num_members = _or.max_num_members;
	OLD.max_num_collections = _or.max_num_collections;
	OLD.can_have_hierarchy = CASE WHEN _or.can_have_hierarchy = true THEN 'Y' WHEN _or.can_have_hierarchy = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_service_env_coll_type_del
	ON jazzhands_legacy.val_service_env_coll_type;
CREATE TRIGGER trigger_val_service_env_coll_type_del
	INSTEAD OF DELETE ON jazzhands_legacy.val_service_env_coll_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_service_env_coll_type_del();


-- Triggers for val_slot_function

CREATE OR REPLACE FUNCTION jazzhands_legacy.val_slot_function_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.val_slot_function%rowtype;
BEGIN

	IF NEW.slot_function IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('slot_function'));
		_vq := array_append(_vq, quote_nullable(NEW.slot_function));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.can_have_mac_address IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('can_have_mac_address'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.can_have_mac_address = 'Y' THEN true WHEN NEW.can_have_mac_address = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.val_slot_function (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.slot_function = _nr.slot_function;
	NEW.description = _nr.description;
	NEW.can_have_mac_address = CASE WHEN _nr.can_have_mac_address = true THEN 'Y' WHEN _nr.can_have_mac_address = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_slot_function_ins
	ON jazzhands_legacy.val_slot_function;
CREATE TRIGGER trigger_val_slot_function_ins
	INSTEAD OF INSERT ON jazzhands_legacy.val_slot_function
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_slot_function_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_slot_function_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.val_slot_function%rowtype;
	_nr	jazzhands.val_slot_function%rowtype;
	_uq	text[];
BEGIN

	IF OLD.slot_function IS DISTINCT FROM NEW.slot_function THEN
_uq := array_append(_uq, 'slot_function = ' || quote_nullable(NEW.slot_function));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.can_have_mac_address IS DISTINCT FROM NEW.can_have_mac_address THEN
IF NEW.can_have_mac_address = 'Y' THEN
	_uq := array_append(_uq, 'can_have_mac_address = true');
ELSIF NEW.can_have_mac_address = 'N' THEN
	_uq := array_append(_uq, 'can_have_mac_address = false');
ELSE
	_uq := array_append(_uq, 'can_have_mac_address = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.val_slot_function SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  slot_function = $1 RETURNING *'  USING OLD.slot_function
			INTO _nr;

		NEW.slot_function = _nr.slot_function;
		NEW.description = _nr.description;
		NEW.can_have_mac_address = CASE WHEN _nr.can_have_mac_address = true THEN 'Y' WHEN _nr.can_have_mac_address = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_slot_function_upd
	ON jazzhands_legacy.val_slot_function;
CREATE TRIGGER trigger_val_slot_function_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.val_slot_function
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_slot_function_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_slot_function_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.val_slot_function%rowtype;
BEGIN
	DELETE FROM jazzhands.val_slot_function
	WHERE  slot_function = OLD.slot_function  RETURNING *
	INTO _or;
	OLD.slot_function = _or.slot_function;
	OLD.description = _or.description;
	OLD.can_have_mac_address = CASE WHEN _or.can_have_mac_address = true THEN 'Y' WHEN _or.can_have_mac_address = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_slot_function_del
	ON jazzhands_legacy.val_slot_function;
CREATE TRIGGER trigger_val_slot_function_del
	INSTEAD OF DELETE ON jazzhands_legacy.val_slot_function
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_slot_function_del();


-- Triggers for val_token_collection_type

CREATE OR REPLACE FUNCTION jazzhands_legacy.val_token_collection_type_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.val_token_collection_type%rowtype;
BEGIN

	IF NEW.token_collection_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('token_collection_type'));
		_vq := array_append(_vq, quote_nullable(NEW.token_collection_type));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.max_num_members IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('max_num_members'));
		_vq := array_append(_vq, quote_nullable(NEW.max_num_members));
	END IF;

	IF NEW.max_num_collections IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('max_num_collections'));
		_vq := array_append(_vq, quote_nullable(NEW.max_num_collections));
	END IF;

	IF NEW.can_have_hierarchy IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('can_have_hierarchy'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.can_have_hierarchy = 'Y' THEN true WHEN NEW.can_have_hierarchy = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.val_token_collection_type (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.token_collection_type = _nr.token_collection_type;
	NEW.description = _nr.description;
	NEW.max_num_members = _nr.max_num_members;
	NEW.max_num_collections = _nr.max_num_collections;
	NEW.can_have_hierarchy = CASE WHEN _nr.can_have_hierarchy = true THEN 'Y' WHEN _nr.can_have_hierarchy = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_token_collection_type_ins
	ON jazzhands_legacy.val_token_collection_type;
CREATE TRIGGER trigger_val_token_collection_type_ins
	INSTEAD OF INSERT ON jazzhands_legacy.val_token_collection_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_token_collection_type_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_token_collection_type_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.val_token_collection_type%rowtype;
	_nr	jazzhands.val_token_collection_type%rowtype;
	_uq	text[];
BEGIN

	IF OLD.token_collection_type IS DISTINCT FROM NEW.token_collection_type THEN
_uq := array_append(_uq, 'token_collection_type = ' || quote_nullable(NEW.token_collection_type));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.max_num_members IS DISTINCT FROM NEW.max_num_members THEN
_uq := array_append(_uq, 'max_num_members = ' || quote_nullable(NEW.max_num_members));
	END IF;

	IF OLD.max_num_collections IS DISTINCT FROM NEW.max_num_collections THEN
_uq := array_append(_uq, 'max_num_collections = ' || quote_nullable(NEW.max_num_collections));
	END IF;

	IF OLD.can_have_hierarchy IS DISTINCT FROM NEW.can_have_hierarchy THEN
IF NEW.can_have_hierarchy = 'Y' THEN
	_uq := array_append(_uq, 'can_have_hierarchy = true');
ELSIF NEW.can_have_hierarchy = 'N' THEN
	_uq := array_append(_uq, 'can_have_hierarchy = false');
ELSE
	_uq := array_append(_uq, 'can_have_hierarchy = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.val_token_collection_type SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  token_collection_type = $1 RETURNING *'  USING OLD.token_collection_type
			INTO _nr;

		NEW.token_collection_type = _nr.token_collection_type;
		NEW.description = _nr.description;
		NEW.max_num_members = _nr.max_num_members;
		NEW.max_num_collections = _nr.max_num_collections;
		NEW.can_have_hierarchy = CASE WHEN _nr.can_have_hierarchy = true THEN 'Y' WHEN _nr.can_have_hierarchy = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_token_collection_type_upd
	ON jazzhands_legacy.val_token_collection_type;
CREATE TRIGGER trigger_val_token_collection_type_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.val_token_collection_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_token_collection_type_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_token_collection_type_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.val_token_collection_type%rowtype;
BEGIN
	DELETE FROM jazzhands.val_token_collection_type
	WHERE  token_collection_type = OLD.token_collection_type  RETURNING *
	INTO _or;
	OLD.token_collection_type = _or.token_collection_type;
	OLD.description = _or.description;
	OLD.max_num_members = _or.max_num_members;
	OLD.max_num_collections = _or.max_num_collections;
	OLD.can_have_hierarchy = CASE WHEN _or.can_have_hierarchy = true THEN 'Y' WHEN _or.can_have_hierarchy = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_token_collection_type_del
	ON jazzhands_legacy.val_token_collection_type;
CREATE TRIGGER trigger_val_token_collection_type_del
	INSTEAD OF DELETE ON jazzhands_legacy.val_token_collection_type
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_token_collection_type_del();


-- Triggers for val_x509_key_usage

CREATE OR REPLACE FUNCTION jazzhands_legacy.val_x509_key_usage_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.val_x509_key_usage%rowtype;
BEGIN

	IF NEW.x509_key_usg IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('x509_key_usage'));
		_vq := array_append(_vq, quote_nullable(NEW.x509_key_usg));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.is_extended IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_extended'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_extended = 'Y' THEN true WHEN NEW.is_extended = 'N' THEN false ELSE NULL END));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.val_x509_key_usage (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.x509_key_usg = _nr.x509_key_usage;
	NEW.description = _nr.description;
	NEW.is_extended = CASE WHEN _nr.is_extended = true THEN 'Y' WHEN _nr.is_extended = false THEN 'N' ELSE NULL END;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_x509_key_usage_ins
	ON jazzhands_legacy.val_x509_key_usage;
CREATE TRIGGER trigger_val_x509_key_usage_ins
	INSTEAD OF INSERT ON jazzhands_legacy.val_x509_key_usage
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_x509_key_usage_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_x509_key_usage_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.val_x509_key_usage%rowtype;
	_nr	jazzhands.val_x509_key_usage%rowtype;
	_uq	text[];
BEGIN

	IF OLD.x509_key_usg IS DISTINCT FROM NEW.x509_key_usg THEN
_uq := array_append(_uq, 'x509_key_usage = ' || quote_nullable(NEW.x509_key_usg));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.is_extended IS DISTINCT FROM NEW.is_extended THEN
IF NEW.is_extended = 'Y' THEN
	_uq := array_append(_uq, 'is_extended = true');
ELSIF NEW.is_extended = 'N' THEN
	_uq := array_append(_uq, 'is_extended = false');
ELSE
	_uq := array_append(_uq, 'is_extended = NULL');
END IF;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.val_x509_key_usage SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  x509_key_usage = $1 RETURNING *'  USING OLD.x509_key_usg
			INTO _nr;

		NEW.x509_key_usg = _nr.x509_key_usage;
		NEW.description = _nr.description;
		NEW.is_extended = CASE WHEN _nr.is_extended = true THEN 'Y' WHEN _nr.is_extended = false THEN 'N' ELSE NULL END;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_x509_key_usage_upd
	ON jazzhands_legacy.val_x509_key_usage;
CREATE TRIGGER trigger_val_x509_key_usage_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.val_x509_key_usage
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_x509_key_usage_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.val_x509_key_usage_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.val_x509_key_usage%rowtype;
BEGIN
	DELETE FROM jazzhands.val_x509_key_usage
	WHERE  x509_key_usage = OLD.x509_key_usg  RETURNING *
	INTO _or;
	OLD.x509_key_usg = _or.x509_key_usage;
	OLD.description = _or.description;
	OLD.is_extended = CASE WHEN _or.is_extended = true THEN 'Y' WHEN _or.is_extended = false THEN 'N' ELSE NULL END;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_x509_key_usage_del
	ON jazzhands_legacy.val_x509_key_usage;
CREATE TRIGGER trigger_val_x509_key_usage_del
	INSTEAD OF DELETE ON jazzhands_legacy.val_x509_key_usage
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.val_x509_key_usage_del();


-- Triggers for x509_certificate

CREATE OR REPLACE FUNCTION jazzhands_legacy.x509_certificate_ins()
RETURNS TRIGGER AS
$$
DECLARE
	key	jazzhands.private_key%rowtype;
	csr	jazzhands.certificate_signing_request%rowtype;
	crt	jazzhands.x509_signed_certificate%rowtype;
BEGIN
	IF NEW.private_key IS NOT NULL THEN
		INSERT INTO jazzhands.private_key (
			private_key_encryption_type,
			is_active,
			public_key_hash_id,
			private_key,
			passphrase,
			encryption_key_id
		) VALUES (
			'rsa',
			CASE WHEN NEW.is_active = 'Y' THEN true
				WHEN NEW.is_active = 'N' THEN false
				ELSE NULL END,
			NEW.public_key_hash_id,
			NEW.private_key,
			NEW.passphrase,
			NEW.encryption_key_id
		) RETURNING * INTO key;
		NEW.x509_cert_id := key.private_key_id;
	ELSE
		IF NEW.public_key_hash_id IS NOT NULL THEN
			SELECT *
			INTO key
			FROM private_key
			WHERE public_key_hash_id = NEW.public_key_hash_id;

			IF key IS NOT NULL THEN
				SELECT private_key
				INTO NEW.private_key
				FROM private_key
				WHERE private_key_id = key.private_key_id;
			END IF;
		END IF;
	END IF;

	IF NEW.certificate_sign_req IS NOT NULL THEN
		INSERT INTO jazzhands.certificate_signing_request (
			friendly_name,
			subject,
			certificate_signing_request,
			private_key_id,
			public_key_hash_id
		) VALUES (
			NEW.friendly_name,
			NEW.subject,
			NEW.certificate_sign_req,
			key.private_key_id,
			NEW.public_key_hash_id
		) RETURNING * INTO csr;
		IF NEW.x509_cert_id IS NULL THEN
			NEW.x509_cert_id := csr.certificate_signing_request_id;
		END IF;
	ELSE
		IF NEW.subject_key_identifier IS NOT NULL THEN
			SELECT c.*
			INTO csr
			FROM certificate_signing_request c
			WHERE c.public_key_hash_id = NEW.public_key_hash_id
			ORDER BY certificate_signing_request_id
			LIMIT 1;

			SELECT certificate_signing_request
			INTO NEW.certificate_sign_req
			FROM certificate_signing_request
			WHERE certificate_signing_request_id  = csr.certificate_signing_request_id;
		END IF;
	END IF;

	IF NEW.public_key IS NOT NULL THEN
		INSERT INTO jazzhands.x509_signed_certificate (
			friendly_name,
			is_active,
			is_certificate_authority,
			signing_cert_id,
			x509_ca_cert_serial_number,
			public_key,
			subject,
			subject_key_identifier,
			public_key_hash_id,
			description,
			valid_from,
			valid_to,
			x509_revocation_date,
			x509_revocation_reason,
			ocsp_uri,
			crl_uri,
			private_key_id,
			certificate_signing_request_id
		) VALUES (
			NEW.friendly_name,
			CASE WHEN NEW.is_active = 'Y' THEN true
				WHEN NEW.is_active = 'N' THEN false
				ELSE NULL END,
			CASE WHEN NEW.is_certificate_authority = 'Y' THEN true
				WHEN NEW.is_certificate_authority = 'N' THEN false
				ELSE NULL END,
			NEW.signing_cert_id,
			NEW.x509_ca_cert_serial_number,
			NEW.public_key,
			NEW.subject,
			NEW.subject_key_identifier,
			NEW.public_key_hash_id,
			NEW.description,
			NEW.valid_from,
			NEW.valid_to,
			NEW.x509_revocation_date,
			NEW.x509_revocation_reason,
			NEW.ocsp_uri,
			NEW.crl_uri,
			key.private_key_id,
			csr.certificate_signing_request_id
		) RETURNING * INTO crt;

		NEW.x509_cert_id 		= crt.x509_signed_certificate_id;
		NEW.friendly_name 		= crt.friendly_name;
		NEW.is_active 			= CASE WHEN crt.is_active = true THEN 'Y'
									WHEN crt.is_active = false THEN 'N'
									ELSE NULL END;
		NEW.is_certificate_authority = CASE WHEN crt.is_certificate_authority =
										true THEN 'Y'
									WHEN crt.is_certificate_authority = false
										THEN 'N'
									ELSE NULL END;

		NEW.signing_cert_id 			= crt.signing_cert_id;
		NEW.x509_ca_cert_serial_number	= crt.x509_ca_cert_serial_number;
		NEW.public_key 					= crt.public_key;
		NEW.private_key 				= key.private_key;
		NEW.certificate_sign_req 		= csr.certificate_signing_request;
		NEW.subject 					= crt.subject;
		NEW.subject_key_identifier 		= crt.subject_key_identifier;
		NEW.public_key_hash_id 			= crt.public_key_hash_id;
		NEW.description 				= crt.description;
		NEW.valid_from 					= crt.valid_from;
		NEW.valid_to 					= crt.valid_to;
		NEW.x509_revocation_date 		= crt.x509_revocation_date;
		NEW.x509_revocation_reason 		= crt.x509_revocation_reason;
		NEW.passphrase 					= key.passphrase;
		NEW.encryption_key_id 			= key.encryption_key_id;
		NEW.ocsp_uri 					= crt.ocsp_uri;
		NEW.crl_uri 					= crt.crl_uri;
		NEW.data_ins_user 				= crt.data_ins_user;
		NEW.data_ins_date 				= crt.data_ins_date;
		NEW.data_upd_user 				= crt.data_upd_user;
		NEW.data_upd_date 				= crt.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_x509_certificate_ins
	ON jazzhands_legacy.x509_certificate;
CREATE TRIGGER trigger_x509_certificate_ins
	INSTEAD OF INSERT ON jazzhands_legacy.x509_certificate
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.x509_certificate_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.x509_certificate_upd()
RETURNS TRIGGER AS
$$
DECLARE
	crt	jazzhands.x509_signed_certificate%rowtype;
	key	jazzhands.private_key%rowtype;
	csr	jazzhands.certificate_signing_request%rowtype;
	_uq	text[];
BEGIN
	SELECT * INTO crt FROM jazzhands.x509_signed_certificate
        WHERE x509_signed_certificate_id = OLD.x509_cert_id;

	IF crt.private_key_ID IS NULL AND NEW.private_key IS NOT NULL THEN
		INSERT INTO private_key (
			private_key_encryption_type,
			is_active,
			subject_key_identifier,
			private_key,
			passphrase,
			encryption_key_id
		) VALUES (
			'rsa',
			NEW.is_active,
			NEW.subject_key_identifier,
			NEW.private_key,
			NEW.passphrase,
			NEW.encryption_key_id
		) RETURNING * INTO key;
	ELSE IF crt.private_key_id IS NOT NULL THEN
		SELECT * INTO key FROM jazzhands.private_key k
			WHERE k.private_key_id =  crt.private_key_id;

		-- delete happens at the end, after update
		IF NEW.private_key IS NOT NULL THEN
			IF OLD.subject_key_identifier IS DISTINCT FROM NEW.subject_key_identifier THEN
				_uq := array_append(_uq,
					'subject_key_identifier = ' || quote_nullable(NEW.subject_key_identifier)
				);
			END IF;
			IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
				IF NEW.is_active = 'Y' THEN
					_uq := array_append(_uq, 'is_active = true');
				ELSIF NEW.is_active = 'N' THEN
					_uq := array_append(_uq, 'is_active = false');
				ELSE
					_uq := array_append(_uq, 'is_active = NULL');
				END IF;
			END IF;
			IF OLD.private_key IS DISTINCT FROM NEW.private_key THEN
				_uq := array_append(_uq,
					'private_key = ' || quote_nullable(NEW.private_key)
				);
			END IF;
			IF OLD.passphrase IS DISTINCT FROM NEW.passphrase THEN
				_uq := array_append(_uq,
					'passphrase = ' || quote_nullable(NEW.passphrase)
				);
			END IF;
			IF OLD.encryption_key_id IS DISTINCT FROM NEW.encryption_key_id THEN
				_uq := array_append(_uq,
					'encryption_key_id = ' || quote_nullable(NEW.encryption_key_id)
				);
			END IF;
			IF OLD.public_key_hash_id IS DISTINCT FROM NEW.public_key_hash_id THEN
				_uq := array_append(_uq,
					'public_key_hash_id = ' || quote_nullable(NEW.public_key_hash_id)
				);
			END IF;

			IF array_length(_uq, 1) > 0 THEN
				EXECUTE format('UPDATE private_key SET %s WHERE private_key_id = $1 RETURNING *',
					array_to_string(_uq, ', '))
					USING crt.private_key_id
					INTO key;
			END IF;
		END IF;

		NEW.private_key 		= key.private_key;
		NEW.is_active 			= CASE WHEN key.is_active THEN 'Y' ELSE 'N' END;
		NEW.passphrase 			= key.passphrase;
		NEW.encryption_key_id	= key.encryption_key_id;
	END IF;

	-- private_key pieces are now what it is supposed to be.
	_uq := NULL;

	IF crt.certificate_signing_request_id IS NULL AND NEW.certificate_sign_req IS NOT NULL THEN
		INSERT INTO jazzhands.certificate_signing_request (
			friendly_name,
			subject,
			certificate_signing_request,
			private_key_id,
			public_key_hash_id
		) VALUES (
			NEW.friendly_name,
			NEW.subject,
			NEW.certificate_sign_req,
			key.private_key_id,
			NEW.public_key_hash_id
		) RETURNING * INTO csr;
	ELSIF crt.certificate_signing_request_id IS NOT NULL THEN
		SELECT * INTO csr FROM jazzhands.certificate_signing_request c
			WHERE c.certificate_signing_request_id =  crt.certificate_signing_request_id;

		-- delete happens at the end, after update
		IF NEW.certificate_sign_req IS NOT NULL THEN
			IF OLD.certificate_sign_req IS DISTINCT FROM NEW.certificate_sign_req THEN
				_uq := array_append(_uq,
					'certificate_signing_request = ' || quote_nullable(NEW.certificate_sign_req)
				);
			END IF;
			IF OLD.subject IS DISTINCT FROM NEW.subject THEN
				_uq := array_append(_uq,
					'subject = ' || quote_nullable(NEW.subject)
				);
			END IF;
			IF OLD.friendly_name IS DISTINCT FROM NEW.friendly_name THEN
				_uq := array_append(_uq,
					'friendly_name = ' || quote_nullable(NEW.friendly_name)
				);
			END IF;
			IF OLD.certificate_signing_request IS DISTINCT FROM key.certificate_signing_request THEN
				_uq := array_append(_uq,
					'certificate_signing_request = ' || quote_nullable(NEW.certificate_signing_request)
				);
			END IF;
			IF OLD.public_key_hash_id IS DISTINCT FROM key.public_key_hash_id THEN
				_uq := array_append(_uq,
					'public_key_hash_id = ' || quote_nullable(NEW.public_key_hash_id)
				);
			END IF;

			IF array_length(_uq, 1) > 0 THEN
				EXECUTE format('UPDATE certificate_signing_request SET %s WHERE certificate_signing_request_id = $1 RETURNING *',
					array_to_string(_uq, ', '))
					USING crt.certificate_signing_request_id
					INTO csr;
			END IF;
		END IF;

		NEW.certificate_sign_req 	= csr.certificate_signing_request;
	END IF;

	-- csr and private_key pieces are now what it is supposed to be.
	_uq := NULL;

	IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
		IF NEW.is_active = 'Y' THEN
			_uq := array_append(_uq, 'is_active = true');
		ELSIF NEW.is_active = 'N' THEN
			_uq := array_append(_uq, 'is_active = false');
		ELSE
			_uq := array_append(_uq, 'is_active = NULL');
		END IF;
	END IF;

	END IF;
	IF OLD.friendly_name IS DISTINCT FROM NEW.friendly_name THEN
		_uq := array_append(_uq,
			'friendly_name = ' || quote_literal(NEW.friendly_name)
		);
	END IF;
	IF OLD.subject IS DISTINCT FROM NEW.subject THEN
		_uq := array_append(_uq,
			'subject = ' || quote_literal(NEW.subject)
		);
	END IF;
	IF OLD.subject_key_identifier IS DISTINCT FROM NEW.subject_key_identifier THEN
		_uq := array_append(_uq,
			'subject_key_identifier = ' || quote_nullable(NEW.subject_key_identifier)
		);
	END IF;
	IF OLD.public_key_hash_id IS DISTINCT FROM NEW.public_key_hash_id THEN
		_uq := array_append(_uq,
			'public_key_hash_id = ' || quote_nullable(NEW.public_key_hash_id)
		);
	END IF;
	IF OLD.description IS DISTINCT FROM NEW.description THEN
		_uq := array_append(_uq,
			'description = ' || quote_nullable(NEW.description)
		);
	END IF;

	IF OLD.is_certificate_authority IS DISTINCT FROM NEW.is_certificate_authority THEN
		IF NEW.is_certificate_authority = 'Y' THEN
			_uq := array_append(_uq, 'is_certificate_authority = true');
		ELSIF NEW.is_certificate_authority = 'N' THEN
			_uq := array_append(_uq, 'is_certificate_authority = false');
		ELSE
			_uq := array_append(_uq, 'is_certificate_authority = NULL');
		END IF;
	END IF;

	IF OLD.signing_cert_id IS DISTINCT FROM NEW.signing_cert_id THEN
		_uq := array_append(_uq,
			'signing_cert_id = ' || quote_nullable(NEW.signing_cert_id)
		);
	END IF;
	IF OLD.x509_ca_cert_serial_number IS DISTINCT FROM NEW.x509_ca_cert_serial_number THEN
		_uq := array_append(_uq,
			'x509_ca_cert_serial_number = ' || quote_nullable(NEW.x509_ca_cert_serial_number)
		);
	END IF;
	IF OLD.public_key IS DISTINCT FROM NEW.public_key THEN
		_uq := array_append(_uq,
			'public_key = ' || quote_nullable(NEW.public_key)
		);
	END IF;
	IF OLD.valid_from IS DISTINCT FROM NEW.valid_from THEN
		_uq := array_append(_uq,
			'valid_from = ' || quote_nullable(NEW.valid_from)
		);
	END IF;
	IF OLD.valid_to IS DISTINCT FROM NEW.valid_to THEN
		_uq := array_append(_uq,
			'valid_to = ' || quote_nullable(NEW.valid_to)
		);
	END IF;
	IF OLD.x509_revocation_date IS DISTINCT FROM NEW.x509_revocation_date THEN
		_uq := array_append(_uq,
			'x509_revocation_date = ' || quote_nullable(NEW.x509_revocation_date)
		);
	END IF;
	IF OLD.x509_revocation_reason IS DISTINCT FROM NEW.x509_revocation_reason THEN
		_uq := array_append(_uq,
			'x509_revocation_reason = ' || quote_nullable(NEW.x509_revocation_reason)
		);
	END IF;
	IF OLD.ocsp_uri IS DISTINCT FROM NEW.ocsp_uri THEN
		_uq := array_append(_uq,
			'ocsp_uri = ' || quote_nullable(NEW.ocsp_uri)
		);
	END IF;
	IF OLD.crl_uri IS DISTINCT FROM NEW.crl_uri THEN
		_uq := array_append(_uq,
			'crl_uri = ' || quote_nullable(NEW.crl_uri)
		);
	END IF;

	IF array_length(_uq, 1) > 0 THEN
		EXECUTE 'UPDATE x509_signed_certificate SET '
			|| array_to_string(_uq, ', ')
			|| ' WHERE x509_signed_certificate_id = '
			|| NEW.x509_cert_id;
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.x509_signed_certificate SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  x509_signed_certificate_id = $1 RETURNING *'  USING OLD.x509_cert_id
			INTO crt;

		NEW.x509_cert_id = crt.x509_signed_certificate_id;
		NEW.friendly_name = crt.friendly_name;
		NEW.is_active = CASE WHEN crt.is_active = true THEN 'Y' WHEN crt.is_active = false THEN 'N' ELSE NULL END;
		NEW.is_certificate_authority = CASE WHEN crt.is_certificate_authority = true THEN 'Y' WHEN crt.is_certificate_authority = false THEN 'N' ELSE NULL END;
		NEW.signing_cert_id = crt.signing_cert_id;
		NEW.x509_ca_cert_serial_number = crt.x509_ca_cert_serial_number;
		NEW.public_key = crt.public_key;
		NEW.subject = crt.subject;
		NEW.subject_key_identifier = crt.subject_key_identifier;
		NEW.public_key_hash_id = crt.public_key_hash_id;
		NEW.description = crt.description;
		NEW.valid_from = crt.valid_from;
		NEW.valid_to = crt.valid_to;
		NEW.x509_revocation_date = crt.x509_revocation_date;
		NEW.x509_revocation_reason = crt.x509_revocation_reason;
		NEW.ocsp_uri = crt.ocsp_uri;
		NEW.crl_uri = crt.crl_uri;
		NEW.data_ins_user = crt.data_ins_user;
		NEW.data_ins_date = crt.data_ins_date;
		NEW.data_upd_user = crt.data_upd_user;
		NEW.data_upd_date = crt.data_upd_date;
	END IF;

	IF OLD.certificate_sign_req IS NOT NULL AND NEW.certificate_sign_req IS NULL THEN
		DELETE FROM jazzhands.certificate_signing_request
		WHERE certificate_signing_request_id = crt.certificate_signing_request_id;
	END IF;

	IF OLD.private_key IS NOT NULL AND NEW.private_key IS NULL THEN
		DELETE FROM jazzhands.private_key
		WHERE private_key_id = crt.private_key_id;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;


DROP TRIGGER IF EXISTS trigger_x509_certificate_upd
	ON jazzhands_legacy.x509_certificate;
CREATE TRIGGER trigger_x509_certificate_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.x509_certificate
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.x509_certificate_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.x509_certificate_del()
RETURNS TRIGGER AS
$$
DECLARE
	crt     jazzhands.x509_signed_certificate%ROWTYPE;
	key     jazzhands.private_key%ROWTYPE;
	csr     jazzhands.certificate_signing_request%ROWTYPE;
BEGIN
	SELECT * INTO crt FROM jazzhands.x509_signed_certificate
		WHERE x509_signed_certificate_id = OLD.x509_cert_id;

	IF crt.private_key_id IS NOT NULL THEN
		DELETE FROM jazzhands.private_key
		WHERE private_key_id = crt.private_key_id
		RETURNING * INTO key;
	END IF;

	IF crt.private_key_id IS NOT NULL THEN
		DELETE FROM jazzhands.certificate_signing_request
		WHERE certificate_signing_request_id =
		crt.certificate_signing_request_id
		RETURNING * INTO crt;
	END IF;

	OLD.x509_cert_id = crt.x509_signed_certiciate_id;
	OLD.friendly_name = crt.friendly_name;
	OLD.is_active = CASE WHEN crt.is_active = true THEN 'Y' WHEN crt.is_active = false THEN 'N' ELSE NULL END;
	OLD.is_certificate_authority = CASE WHEN crt.is_certificate_authority = true THEN 'Y' WHEN crt.is_certificate_authority = false THEN 'N' ELSE NULL END;
	OLD.signing_cert_id = crt.signing_cert_id;
	OLD.x509_ca_cert_serial_number = crt.x509_ca_cert_serial_number;
	OLD.public_key = crt.public_key;
	OLD.private_key = key.private_key;
	OLD.certificate_sign_req = crt.certificate_signing_request;
	OLD.subject = crt.subject;
	OLD.subject_key_identifier = crt.subject_key_identifier;
	OLD.public_key_hash_id = crt.public_key_hash_id;
	OLD.description = crt.description;
	OLD.valid_from = crt.valid_from;
	OLD.valid_to = crt.valid_to;
	OLD.x509_revocation_date = crt.x509_revocation_date;
	OLD.x509_revocation_reason = crt.x509_revocation_reason;
	OLD.passphrase = key.passphrase;
	OLD.encryption_key_id = key.encryption_key_id;
	OLD.ocsp_uri = crt.ocsp_uri;
	OLD.crl_uri = crt.crl_uri;
	OLD.data_ins_user = crt.data_ins_user;
	OLD.data_ins_date = crt.data_ins_date;
	OLD.data_upd_user = crt.data_upd_user;
	OLD.data_upd_date = crt.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_x509_certificate_del
	ON jazzhands_legacy.x509_certificate;
CREATE TRIGGER trigger_x509_certificate_del
	INSTEAD OF DELETE ON jazzhands_legacy.x509_certificate
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.x509_certificate_del();


-- Triggers for x509_signed_certificate

CREATE OR REPLACE FUNCTION jazzhands_legacy.x509_signed_certificate_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_cq	text[];
	_vq	text[];
	_nr	jazzhands.x509_signed_certificate%rowtype;
BEGIN

	IF NEW.x509_signed_certificate_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('x509_signed_certificate_id'));
		_vq := array_append(_vq, quote_nullable(NEW.x509_signed_certificate_id));
	END IF;

	IF NEW.x509_certificate_type IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('x509_certificate_type'));
		_vq := array_append(_vq, quote_nullable(NEW.x509_certificate_type));
	END IF;

	IF NEW.subject IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('subject'));
		_vq := array_append(_vq, quote_nullable(NEW.subject));
	END IF;

	IF NEW.friendly_name IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('friendly_name'));
		_vq := array_append(_vq, quote_nullable(NEW.friendly_name));
	END IF;

	IF NEW.subject_key_identifier IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('subject_key_identifier'));
		_vq := array_append(_vq, quote_nullable(NEW.subject_key_identifier));
	END IF;

	IF NEW.public_key_hash_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('public_key_hash_id'));
		_vq := array_append(_vq, quote_nullable(NEW.public_key_hash_id));
	END IF;

	IF NEW.description IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('description'));
		_vq := array_append(_vq, quote_nullable(NEW.description));
	END IF;

	IF NEW.is_active IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_active'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_active = 'Y' THEN true WHEN NEW.is_active = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.is_certificate_authority IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('is_certificate_authority'));
		_vq := array_append(_vq, quote_nullable(CASE WHEN NEW.is_certificate_authority = 'Y' THEN true WHEN NEW.is_certificate_authority = 'N' THEN false ELSE NULL END));
	END IF;

	IF NEW.signing_cert_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('signing_cert_id'));
		_vq := array_append(_vq, quote_nullable(NEW.signing_cert_id));
	END IF;

	IF NEW.x509_ca_cert_serial_number IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('x509_ca_cert_serial_number'));
		_vq := array_append(_vq, quote_nullable(NEW.x509_ca_cert_serial_number));
	END IF;

	IF NEW.public_key IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('public_key'));
		_vq := array_append(_vq, quote_nullable(NEW.public_key));
	END IF;

	IF NEW.private_key_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('private_key_id'));
		_vq := array_append(_vq, quote_nullable(NEW.private_key_id));
	END IF;

	IF NEW.certificate_signing_request_id IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('certificate_signing_request_id'));
		_vq := array_append(_vq, quote_nullable(NEW.certificate_signing_request_id));
	END IF;

	IF NEW.valid_from IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('valid_from'));
		_vq := array_append(_vq, quote_nullable(NEW.valid_from));
	END IF;

	IF NEW.valid_to IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('valid_to'));
		_vq := array_append(_vq, quote_nullable(NEW.valid_to));
	END IF;

	IF NEW.x509_revocation_date IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('x509_revocation_date'));
		_vq := array_append(_vq, quote_nullable(NEW.x509_revocation_date));
	END IF;

	IF NEW.x509_revocation_reason IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('x509_revocation_reason'));
		_vq := array_append(_vq, quote_nullable(NEW.x509_revocation_reason));
	END IF;

	IF NEW.ocsp_uri IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('ocsp_uri'));
		_vq := array_append(_vq, quote_nullable(NEW.ocsp_uri));
	END IF;

	IF NEW.crl_uri IS NOT NULL THEN
		_cq := array_append(_cq, quote_ident('crl_uri'));
		_vq := array_append(_vq, quote_nullable(NEW.crl_uri));
	END IF;

	EXECUTE 'INSERT INTO jazzhands.x509_signed_certificate (' ||
		array_to_string(_cq, ', ') ||
		') VALUES ( ' ||
		array_to_string(_vq, ', ') ||
		') RETURNING *' INTO _nr;

	NEW.x509_signed_certificate_id = _nr.x509_signed_certificate_id;
	NEW.x509_certificate_type = _nr.x509_certificate_type;
	NEW.subject = _nr.subject;
	NEW.friendly_name = _nr.friendly_name;
	NEW.subject_key_identifier = _nr.subject_key_identifier;
	NEW.public_key_hash_id = _nr.public_key_hash_id;
	NEW.description = _nr.description;
	NEW.is_active = CASE WHEN _nr.is_active = true THEN 'Y' WHEN _nr.is_active = false THEN 'N' ELSE NULL END;
	NEW.is_certificate_authority = CASE WHEN _nr.is_certificate_authority = true THEN 'Y' WHEN _nr.is_certificate_authority = false THEN 'N' ELSE NULL END;
	NEW.signing_cert_id = _nr.signing_cert_id;
	NEW.x509_ca_cert_serial_number = _nr.x509_ca_cert_serial_number;
	NEW.public_key = _nr.public_key;
	NEW.private_key_id = _nr.private_key_id;
	NEW.certificate_signing_request_id = _nr.certificate_signing_request_id;
	NEW.valid_from = _nr.valid_from;
	NEW.valid_to = _nr.valid_to;
	NEW.x509_revocation_date = _nr.x509_revocation_date;
	NEW.x509_revocation_reason = _nr.x509_revocation_reason;
	NEW.ocsp_uri = _nr.ocsp_uri;
	NEW.crl_uri = _nr.crl_uri;
	NEW.data_ins_user = _nr.data_ins_user;
	NEW.data_ins_date = _nr.data_ins_date;
	NEW.data_upd_user = _nr.data_upd_user;
	NEW.data_upd_date = _nr.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_x509_signed_certificate_ins
	ON jazzhands_legacy.x509_signed_certificate;
CREATE TRIGGER trigger_x509_signed_certificate_ins
	INSTEAD OF INSERT ON jazzhands_legacy.x509_signed_certificate
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.x509_signed_certificate_ins();


CREATE OR REPLACE FUNCTION jazzhands_legacy.x509_signed_certificate_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_r	jazzhands_legacy.x509_signed_certificate%rowtype;
	_nr	jazzhands.x509_signed_certificate%rowtype;
	_uq	text[];
BEGIN

	IF OLD.x509_signed_certificate_id IS DISTINCT FROM NEW.x509_signed_certificate_id THEN
_uq := array_append(_uq, 'x509_signed_certificate_id = ' || quote_nullable(NEW.x509_signed_certificate_id));
	END IF;

	IF OLD.x509_certificate_type IS DISTINCT FROM NEW.x509_certificate_type THEN
_uq := array_append(_uq, 'x509_certificate_type = ' || quote_nullable(NEW.x509_certificate_type));
	END IF;

	IF OLD.subject IS DISTINCT FROM NEW.subject THEN
_uq := array_append(_uq, 'subject = ' || quote_nullable(NEW.subject));
	END IF;

	IF OLD.friendly_name IS DISTINCT FROM NEW.friendly_name THEN
_uq := array_append(_uq, 'friendly_name = ' || quote_nullable(NEW.friendly_name));
	END IF;

	IF OLD.subject_key_identifier IS DISTINCT FROM NEW.subject_key_identifier THEN
_uq := array_append(_uq, 'subject_key_identifier = ' || quote_nullable(NEW.subject_key_identifier));
	END IF;

	IF OLD.public_key_hash_id IS DISTINCT FROM NEW.public_key_hash_id THEN
_uq := array_append(_uq, 'public_key_hash_id = ' || quote_nullable(NEW.public_key_hash_id));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
IF NEW.is_active = 'Y' THEN
	_uq := array_append(_uq, 'is_active = true');
ELSIF NEW.is_active = 'N' THEN
	_uq := array_append(_uq, 'is_active = false');
ELSE
	_uq := array_append(_uq, 'is_active = NULL');
END IF;
	END IF;

	IF OLD.is_certificate_authority IS DISTINCT FROM NEW.is_certificate_authority THEN
IF NEW.is_certificate_authority = 'Y' THEN
	_uq := array_append(_uq, 'is_certificate_authority = true');
ELSIF NEW.is_certificate_authority = 'N' THEN
	_uq := array_append(_uq, 'is_certificate_authority = false');
ELSE
	_uq := array_append(_uq, 'is_certificate_authority = NULL');
END IF;
	END IF;

	IF OLD.signing_cert_id IS DISTINCT FROM NEW.signing_cert_id THEN
_uq := array_append(_uq, 'signing_cert_id = ' || quote_nullable(NEW.signing_cert_id));
	END IF;

	IF OLD.x509_ca_cert_serial_number IS DISTINCT FROM NEW.x509_ca_cert_serial_number THEN
_uq := array_append(_uq, 'x509_ca_cert_serial_number = ' || quote_nullable(NEW.x509_ca_cert_serial_number));
	END IF;

	IF OLD.public_key IS DISTINCT FROM NEW.public_key THEN
_uq := array_append(_uq, 'public_key = ' || quote_nullable(NEW.public_key));
	END IF;

	IF OLD.private_key_id IS DISTINCT FROM NEW.private_key_id THEN
_uq := array_append(_uq, 'private_key_id = ' || quote_nullable(NEW.private_key_id));
	END IF;

	IF OLD.certificate_signing_request_id IS DISTINCT FROM NEW.certificate_signing_request_id THEN
_uq := array_append(_uq, 'certificate_signing_request_id = ' || quote_nullable(NEW.certificate_signing_request_id));
	END IF;

	IF OLD.valid_from IS DISTINCT FROM NEW.valid_from THEN
_uq := array_append(_uq, 'valid_from = ' || quote_nullable(NEW.valid_from));
	END IF;

	IF OLD.valid_to IS DISTINCT FROM NEW.valid_to THEN
_uq := array_append(_uq, 'valid_to = ' || quote_nullable(NEW.valid_to));
	END IF;

	IF OLD.x509_revocation_date IS DISTINCT FROM NEW.x509_revocation_date THEN
_uq := array_append(_uq, 'x509_revocation_date = ' || quote_nullable(NEW.x509_revocation_date));
	END IF;

	IF OLD.x509_revocation_reason IS DISTINCT FROM NEW.x509_revocation_reason THEN
_uq := array_append(_uq, 'x509_revocation_reason = ' || quote_nullable(NEW.x509_revocation_reason));
	END IF;

	IF OLD.ocsp_uri IS DISTINCT FROM NEW.ocsp_uri THEN
_uq := array_append(_uq, 'ocsp_uri = ' || quote_nullable(NEW.ocsp_uri));
	END IF;

	IF OLD.crl_uri IS DISTINCT FROM NEW.crl_uri THEN
_uq := array_append(_uq, 'crl_uri = ' || quote_nullable(NEW.crl_uri));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.x509_signed_certificate SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  x509_signed_certificate_id = $1 RETURNING *'  USING OLD.x509_signed_certificate_id
			INTO _nr;

		NEW.x509_signed_certificate_id = _nr.x509_signed_certificate_id;
		NEW.x509_certificate_type = _nr.x509_certificate_type;
		NEW.subject = _nr.subject;
		NEW.friendly_name = _nr.friendly_name;
		NEW.subject_key_identifier = _nr.subject_key_identifier;
		NEW.public_key_hash_id = _nr.public_key_hash_id;
		NEW.description = _nr.description;
		NEW.is_active = CASE WHEN _nr.is_active = true THEN 'Y' WHEN _nr.is_active = false THEN 'N' ELSE NULL END;
		NEW.is_certificate_authority = CASE WHEN _nr.is_certificate_authority = true THEN 'Y' WHEN _nr.is_certificate_authority = false THEN 'N' ELSE NULL END;
		NEW.signing_cert_id = _nr.signing_cert_id;
		NEW.x509_ca_cert_serial_number = _nr.x509_ca_cert_serial_number;
		NEW.public_key = _nr.public_key;
		NEW.private_key_id = _nr.private_key_id;
		NEW.certificate_signing_request_id = _nr.certificate_signing_request_id;
		NEW.valid_from = _nr.valid_from;
		NEW.valid_to = _nr.valid_to;
		NEW.x509_revocation_date = _nr.x509_revocation_date;
		NEW.x509_revocation_reason = _nr.x509_revocation_reason;
		NEW.ocsp_uri = _nr.ocsp_uri;
		NEW.crl_uri = _nr.crl_uri;
		NEW.data_ins_user = _nr.data_ins_user;
		NEW.data_ins_date = _nr.data_ins_date;
		NEW.data_upd_user = _nr.data_upd_user;
		NEW.data_upd_date = _nr.data_upd_date;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_x509_signed_certificate_upd
	ON jazzhands_legacy.x509_signed_certificate;
CREATE TRIGGER trigger_x509_signed_certificate_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.x509_signed_certificate
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.x509_signed_certificate_upd();


CREATE OR REPLACE FUNCTION jazzhands_legacy.x509_signed_certificate_del()
RETURNS TRIGGER AS
$$
DECLARE
	_or	jazzhands.x509_signed_certificate%rowtype;
BEGIN
	DELETE FROM jazzhands.x509_signed_certificate
	WHERE  x509_signed_certificate_id = OLD.x509_signed_certificate_id  RETURNING *
	INTO _or;
	OLD.x509_signed_certificate_id = _or.x509_signed_certificate_id;
	OLD.x509_certificate_type = _or.x509_certificate_type;
	OLD.subject = _or.subject;
	OLD.friendly_name = _or.friendly_name;
	OLD.subject_key_identifier = _or.subject_key_identifier;
	OLD.public_key_hash_id = _or.public_key_hash_id;
	OLD.description = _or.description;
	OLD.is_active = CASE WHEN _or.is_active = true THEN 'Y' WHEN _or.is_active = false THEN 'N' ELSE NULL END;
	OLD.is_certificate_authority = CASE WHEN _or.is_certificate_authority = true THEN 'Y' WHEN _or.is_certificate_authority = false THEN 'N' ELSE NULL END;
	OLD.signing_cert_id = _or.signing_cert_id;
	OLD.x509_ca_cert_serial_number = _or.x509_ca_cert_serial_number;
	OLD.public_key = _or.public_key;
	OLD.private_key_id = _or.private_key_id;
	OLD.certificate_signing_request_id = _or.certificate_signing_request_id;
	OLD.valid_from = _or.valid_from;
	OLD.valid_to = _or.valid_to;
	OLD.x509_revocation_date = _or.x509_revocation_date;
	OLD.x509_revocation_reason = _or.x509_revocation_reason;
	OLD.ocsp_uri = _or.ocsp_uri;
	OLD.crl_uri = _or.crl_uri;
	OLD.data_ins_user = _or.data_ins_user;
	OLD.data_ins_date = _or.data_ins_date;
	OLD.data_upd_user = _or.data_upd_user;
	OLD.data_upd_date = _or.data_upd_date;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_x509_signed_certificate_del
	ON jazzhands_legacy.x509_signed_certificate;
CREATE TRIGGER trigger_x509_signed_certificate_del
	INSTEAD OF DELETE ON jazzhands_legacy.x509_signed_certificate
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.x509_signed_certificate_del();


---------------------------------------------------------------------------
---------------------------------------------------------------------------


CREATE OR REPLACE FUNCTION jazzhands_legacy.dns_domain_ins()
RETURNS TRIGGER AS
$$
DECLARE
	_d	jazzhands.dns_domain%ROWTYPE;
BEGIN
	IF NEW.dns_domain_name IS NOT NULL and NEW.soa_name IS NOT NULL THEN
		RAISE EXCEPTION 'Must only set dns_domain_name, not soa_name'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF NEW.dns_domain_id IS NULL THEN
		INSERT INTO jazzhands.dns_domain (
			dns_domain_name,
			dns_domain_type,
			parent_dns_domain_id,
			description,
			external_id,
			data_ins_user,
			data_ins_date,
			data_upd_user,
			data_upd_date
		) VALUES (
			coalesce(NEW.dns_domain_name, NEW.soa_name),
			NEW.dns_domain_type,
			NEW.parent_dns_domain_id,
			NEW.description,
			NEW.external_id,
			NEW.data_ins_user,
			NEW.data_ins_date,
			NEW.data_upd_user,
			NEW.data_upd_date
		) RETURNING * INTO _d;
	ELSE
		INSERT INTO jazzhands.dns_domain (
			dns_domain_id,
			dns_domain_name,
			dns_domain_type,
			parent_dns_domain_id,
			description,
			external_id,
			data_ins_user,
			data_ins_date,
			data_upd_user,
			data_upd_date
		) VALUES (
			NEW.dns_domain_id,
			coalesce(NEW.dns_domain_name, NEW.soa_name),
			NEW.dns_domain_type,
			NEW.parent_dns_domain_id,
			NEW.description,
			NEW.external_id,
			NEW.data_ins_user,
			NEW.data_ins_date,
			NEW.data_upd_user,
			NEW.data_upd_date
		) RETURNING * INTO _d;
	END IF;

	NEW.dns_domain_id			= _d.dns_domain_id;
	NEW.soa_name				= _d.dns_domain_name;
	NEW.dns_domain_name			= _d.dns_domain_name;
	NEW.dns_domain_type			= _d.dns_domain_type;
	NEW.parent_dns_domain_id	= _d.parent_dns_domain_id;
	NEW.description				= _d.description;
	NEW.external_id				= _d.external_id;
	NEW.data_ins_user			= _d.data_ins_user;
	NEW.data_ins_date			= _d.data_ins_date;
	NEW.data_upd_user			= _d.data_upd_user;
	NEW.data_upd_date			= _d.data_upd_date;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_domain_ins
	ON jazzhands_legacy.dns_domain;
CREATE TRIGGER trigger_dns_domain_ins
	INSTEAD OF INSERT ON jazzhands_legacy.dns_domain
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.dns_domain_ins();

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION jazzhands_legacy.dns_domain_upd()
RETURNS TRIGGER AS
$$
DECLARE
	_d	jazzhands.dns_domain%ROWTYPE;
	_uq	TEXT[];
BEGIN
	IF OLD.dns_domain_name IS DISTINCT FROM NEW.dns_domain_name
		AND OLD.soa_name IS DISTINCT FROM NEW.soa_name
	 THEN
		RAISE EXCEPTION 'Must only change dns_domain_name OR soa_name'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF OLD.dns_domain_id IS DISTINCT FROM NEW.dns_domain_id THEN
		_uq := array_append(_uq, 'dns_domain_id = ' || quote_nullable(NEW.dns_domain_id));
	END IF;

	IF OLD.dns_domain_name IS DISTINCT FROM NEW.dns_domain_name THEN
		_uq := array_append(_uq, 'dns_domain_name = ' || quote_nullable(NEW.dns_domain_name));
	END IF;

	IF OLD.soa_name IS DISTINCT FROM NEW.soa_name THEN
		_uq := array_append(_uq, 'dns_domain_name = ' || quote_nullable(NEW.soa_name));
	END IF;

	IF OLD.dns_domain_type IS DISTINCT FROM NEW.dns_domain_type THEN
		_uq := array_append(_uq, 'dns_domain_type = ' || quote_nullable(NEW.dns_domain_type));
	END IF;

	IF OLD.parent_dns_domain_id IS DISTINCT FROM NEW.parent_dns_domain_id THEN
		_uq := array_append(_uq, 'parent_dns_domain_id = ' || quote_nullable(NEW.parent_dns_domain_id));
	END IF;

	IF OLD.description IS DISTINCT FROM NEW.description THEN
		_uq := array_append(_uq, 'description = ' || quote_nullable(NEW.description));
	END IF;

	IF OLD.external_id IS DISTINCT FROM NEW.external_id THEN
		_uq := array_append(_uq, 'dns_domain_type = ' || quote_nullable(NEW.dns_domain_type));
	END IF;

	IF _uq IS NOT NULL THEN
		EXECUTE 'UPDATE jazzhands.dns_domain SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  dns_domain_id = $1 RETURNING *'
			USING OLD.dns_domain_id
			INTO _d;

		NEW.dns_domain_id			= _d.dns_domain_id;
		NEW.soa_name				= _d.dns_domain_name;
		NEW.dns_domain_name			= _d.dns_domain_name;
		NEW.dns_domain_type			= _d.dns_domain_type;
		NEW.parent_dns_domain_id	= _d.parent_dns_domain_id;
		NEW.description				= _d.description;
		NEW.external_id				= _d.external_id;
		NEW.data_ins_user			= _d.data_ins_user;
		NEW.data_ins_date			= _d.data_ins_date;
		NEW.data_upd_user			= _d.data_upd_user;
		NEW.data_upd_date			= _d.data_upd_date;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_domain_upd
	ON jazzhands_legacy.dns_domain;
CREATE TRIGGER trigger_dns_domain_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.dns_domain
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_legacy.dns_domain_upd();

-- There is no delete trigger because that should just work since it's
-- bascially column renames.  These triggers exist so that
-- soa_name/dns_domain_name aren't both updated.

---------------------------------------------------------------------------
---------------------------------------------------------------------------


--
-- Copyright (c) 2015-2020 Matthew Ragan
-- Copyright (c) 2015-2020 Todd Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
CREATE OR REPLACE FUNCTION jazzhands_legacy.do_layer1_connection_trigger()
RETURNS TRIGGER
AS $$
BEGIN
	IF TG_OP = 'INSERT' THEN
		INSERT INTO inter_component_connection (
			slot1_id,
			slot2_id,
			circuit_id
		) VALUES (
			NEW.physical_port1_id,
			NEW.physical_port2_id,
			NEW.circuit_id
		) RETURNING inter_component_connection_id INTO NEW.layer1_connection_id;
		RETURN NEW;
	ELSIF TG_OP = 'UPDATE' THEN
		IF (NEW.layer1_connection_id IS DISTINCT FROM
				OLD.layer1_connection_id) OR
			(NEW.physical_port1_id IS DISTINCT FROM OLD.physical_port1_id) OR
			(NEW.physical_port2_id IS DISTINCT FROM OLD.physical_port2_id) OR
			(NEW.circuit_id IS DISTINCT FROM OLD.circuit_id)
		THEN
			UPDATE inter_component_connection
			SET
				inter_component_connection_id = NEW.layer1_connection_id,
				slot1_id = NEW.physical_port1_id,
				slot2_id = NEW.physical_port2_id,
				circuit_id = NEW.circuit_id
			WHERE
				inter_component_connection_id = OLD.layer1_connection_id;
		END IF;
		RETURN NEW;
	ELSIF TG_OP = 'DELETE' THEN
		DELETE FROM inter_component_connection WHERE
			inter_component_connection_id = OLD.layer1_connection_id;
		RETURN OLD;
	END IF;
END; $$
SET search_path=jazzhands
LANGUAGE plpgsql
SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_layer1_connection_insteadof ON
	jazzhands_legacy.layer1_connection;
CREATE TRIGGER trigger_layer1_connection_insteadof
	INSTEAD OF INSERT OR UPDATE OR DELETE
	ON jazzhands_legacy.layer1_connection
	FOR EACH ROW EXECUTE PROCEDURE
		jazzhands_legacy.do_layer1_connection_trigger();


CREATE OR REPLACE FUNCTION jazzhands_legacy.do_physical_port_trigger()
RETURNS TRIGGER
AS $$
BEGIN
	IF TG_OP = 'INSERT' THEN
		RAISE EXCEPTION 'Physical ports must be inserted as component slots';
	ELSIF TG_OP = 'UPDATE' THEN
		IF (NEW.physical_port_id IS DISTINCT FROM OLD.physical_port_id) OR
			(NEW.device_id IS DISTINCT FROM OLD.device_id) OR
			(NEW.port_type IS DISTINCT FROM OLD.port_type) OR
			(NEW.port_plug_style IS DISTINCT FROM OLD.port_plug_style) OR
			(NEW.port_medium IS DISTINCT FROM OLD.port_medium) OR
			(NEW.port_protocol IS DISTINCT FROM OLD.port_protocol) OR
			(NEW.port_speed IS DISTINCT FROM OLD.port_speed) OR
			(NEW.port_purpose IS DISTINCT FROM OLD.port_purpose) OR
			(NEW.logical_port_id IS DISTINCT FROM OLD.logical_port_id) OR
			(NEW.tcp_port IS DISTINCT FROM OLD.tcp_port) OR
			(NEW.is_hardwired IS DISTINCT FROM OLD.is_hardwired)
		THEN
			RAISE EXCEPTION 'Attempted to update a deprecated physical_port attribute that must be changed on the slot now';
		END IF;
		IF (NEW.port_name IS DISTINCT FROM OLD.port_name) OR
			(NEW.description IS DISTINCT FROM OLD.description) OR
			(NEW.physical_label IS DISTINCT FROM OLD.physical_label)
		THEN
			UPDATE slot
			SET
				slot_name = NEW.port_name,
				description = NEW.description,
				physical_label = NEW.physical_label
			WHERE
				slot_id = NEW.physical_port_id;
		END IF;
		RETURN NEW;
	ELSIF TG_OP = 'DELETE' THEN
		DELETE FROM slot WHERE
			slot_id = OLD.physical_port_id;
		RETURN OLD;
	END IF;
END; $$
SET search_path=jazzhands
LANGUAGE plpgsql
SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_physical_port_insteadof
	ON jazzhands_legacy.physical_port;
CREATE TRIGGER trigger_physical_port_insteadof
	INSTEAD OF INSERT OR UPDATE OR DELETE
	ON jazzhands_legacy.physical_port
	FOR EACH ROW EXECUTE PROCEDURE
		jazzhands_legacy.do_physical_port_trigger();

---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION service_environment_ins()
RETURNS TRIGGER AS $$
DECLARE
	_se	service_environment%ROWTYPE;
BEGIN
	IF NEW.service_environment_id IS NOT NULL THEN
		INSERT INTO service_environment (
				service_environment_id,
        		service_environment_name,
        		service_environment_type,
        		production_state,
        		description,
        		external_id
		) VALUES (
				NEW.service_environment_id,
        		NEW.service_environment_name,
        		'default',
        		NEW.production_state,
        		NEW.description,
        		NEW.external_id
		) RETURNING * INTO _se;
	ELSE
		INSERT INTO service_environment (
        		service_environment_name,
        		service_environment_type,
        		production_state,
        		description,
        		external_id
		) VALUES (
        		NEW.service_environment_name,
        		'default',
        		NEW.production_state,
        		NEW.description,
        		NEW.external_id
		) RETURNING * INTO _se;

	END IF;

	NEW.service_environment_id		:= _se.service_environment_id;
	NEW.service_environment_name	:= _se.service_environment_name;
	NEW.production_state			:= _se.production_state;
	NEW.description					:= _se.description;
	NEW.external_id					:= _se.external_id;
	NEW.data_ins_user 				:= _se.data_ins_user;
	NEW.data_ins_date 				:= _se.data_ins_date;
	NEW.data_upd_user 				:= _se.data_upd_user;
	NEW.data_upd_date 				:= _se.data_upd_date;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_service_environment_ins ON
	jazzhands_legacy.service_environment;

CREATE TRIGGER trigger_service_environment_ins
	INSTEAD OF INSERT ON jazzhands_legacy.service_environment
	FOR EACH ROW
	EXECUTE PROCEDURE service_environment_ins();

---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION service_environment_del()
RETURNS TRIGGER AS $$
DECLARE
	_se		service_environment%ROWTYPE;
BEGIN
	DELETE FROM service_environment_id
	WHERE service_environment_id = OLD.service_environment_id;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_service_environment_del ON
	jazzhands_legacy.service_environment;

CREATE TRIGGER trigger_service_environment_del
	INSTEAD OF DELETE ON jazzhands_legacy.service_environment
	FOR EACH ROW
	EXECUTE PROCEDURE service_environment_del();

---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION service_environment_upd()
RETURNS TRIGGER AS $$
DECLARE
	upd_query		TEXT[];
	_se			service_environment%ROWTYPE;
BEGIN
	IF OLD.service_environment_id IS DISTINCT FROM NEW.service_environment_id THEN
		RAISE EXCEPTION 'May not update service_environment_id'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	upd_query := NULL;
	IF NEW.service_environment_name IS DISTINCT FROM OLD.service_environment_name THEN
		upd_query := array_append(upd_query,
			'service_environment_name = ' || quote_nullable(NEW.service_environment_name));
	END IF;
	IF NEW.production_state IS DISTINCT FROM OLD.production_state THEN
		upd_query := array_append(upd_query,
			'production_state = ' || quote_nullable(NEW.production_state));
	END IF;
	IF NEW.description IS DISTINCT FROM OLD.description THEN
		upd_query := array_append(upd_query,
			'description = ' || quote_nullable(NEW.description));
	END IF;
	IF NEW.external_id IS DISTINCT FROM OLD.external_id THEN
		upd_query := array_append(upd_query,
			'external_id = ' || quote_nullable(NEW.external_id));
	END IF;

	IF upd_query IS NOT NULL THEN
		EXECUTE 'UPDATE service_environment SET ' ||
			array_to_string(upd_query, ', ') ||
			' WHERE service_environment_id = $1 RETURNING *'
		USING OLD.service_environment_id
		INTO _se;

		NEW.service_environment_id		:= _se.service_environment_id;
		NEW.service_environment_name	:= _se.service_environment_name;
		NEW.production_state			:= _se.production_state;
		NEW.description					:= _se.description;
		NEW.external_id					:= _se.external_id;
		NEW.data_ins_user 				:= _se.data_ins_user;
		NEW.data_ins_date 				:= _se.data_ins_date;
		NEW.data_upd_user 				:= _se.data_upd_user;
		NEW.data_upd_date 				:= _se.data_upd_date;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_service_environment_upd ON
	jazzhands_legacy.service_environment;

CREATE TRIGGER trigger_service_environment_upd
	INSTEAD OF UPDATE ON jazzhands_legacy.service_environment
	FOR EACH ROW
	EXECUTE PROCEDURE service_environment_upd();


---------------------------------------------------------------------------
---------------------------------------------------------------------------
