/*
 * Copyright (c) 2019-2024 Todd Kover
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
CREATE SCHEMA audit;

-- XXX - Type change
CREATE OR REPLACE VIEW audit.account AS
SELECT
	"account_id",
	"login",
	"person_id",
	"company_id",
	CASE WHEN is_enabled IS NULL THEN NULL
		WHEN is_enabled = true THEN 'Y'
		WHEN is_enabled = false THEN 'N'
		ELSE NULL
	END AS is_enabled,
	"account_realm_id",
	"account_status",
	"account_role",
	"account_type",
	"description",
	"external_id",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.account;



CREATE OR REPLACE VIEW audit.account_assignd_cert AS
SELECT "account_id",
	x509_signed_certificate_id AS x509_cert_id,
	x509_key_usage AS x509_key_usg,
	key_usage_reason_for_assignment AS key_usage_reason_for_assign,
	"data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.account_assigned_certificate;


CREATE OR REPLACE VIEW audit.account_coll_type_relation AS
SELECT "account_collection_relation","account_collection_type","max_num_members","max_num_collections","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.account_collection_type_relation;



CREATE OR REPLACE VIEW audit.account_collection AS
SELECT "account_collection_id","account_collection_name","account_collection_type","external_id","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.account_collection;



CREATE OR REPLACE VIEW audit.account_collection_account AS
SELECT "account_collection_id","account_id","account_collection_relation","account_id_rank","start_date","finish_date","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.account_collection_account;



CREATE OR REPLACE VIEW audit.account_collection_hier AS
SELECT "account_collection_id","child_account_collection_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.account_collection_hier;



CREATE OR REPLACE VIEW audit.account_password AS
SELECT "account_id","account_realm_id","password_type","password","change_time","expire_time","unlock_time","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.account_password;



CREATE OR REPLACE VIEW audit.account_realm AS
SELECT "account_realm_id","account_realm_name","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.account_realm;



CREATE OR REPLACE VIEW audit.account_realm_acct_coll_type AS
SELECT "account_realm_id","account_collection_type","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.account_realm_account_collection_type;



CREATE OR REPLACE VIEW audit.account_realm_company AS
SELECT "account_realm_id","company_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.account_realm_company;



CREATE OR REPLACE VIEW audit.account_realm_password_type AS
SELECT "password_type","account_realm_id","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.account_realm_password_type;



CREATE OR REPLACE VIEW audit.account_ssh_key AS
SELECT "account_id","ssh_key_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.account_ssh_key;



CREATE OR REPLACE VIEW audit.account_token AS
SELECT "account_token_id","account_id","token_id","issued_date","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.account_token;



-- Simple column rename
CREATE OR REPLACE VIEW audit.account_unix_info AS
SELECT
	"account_id",
	"unix_uid",
	"unix_group_account_collection_id" AS unix_group_acct_collection_id,
	"shell",
	"default_home",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.account_unix_info;



CREATE OR REPLACE VIEW audit.appaal AS
SELECT "appaal_id","appaal_name","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.appaal;



-- Simple column rename
CREATE OR REPLACE VIEW audit.appaal_instance AS
SELECT
	"appaal_instance_id",
	"appaal_id",
	"service_environment_id",
	"file_mode",
	"file_owner_account_id",
	"file_group_account_collection_id" AS file_group_acct_collection_id,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.appaal_instance;



CREATE OR REPLACE VIEW audit.appaal_instance_device_coll AS
SELECT "device_collection_id","appaal_instance_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.appaal_instance_device_collection;



CREATE OR REPLACE VIEW audit.appaal_instance_property AS
SELECT	"appaal_instance_id",
	application_key AS "app_key",
	"appaal_group_name",
	"appaal_group_rank",
	application_value AS "app_value",
	"encryption_key_id",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user","data_upd_date",
	"aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.appaal_instance_property;



CREATE OR REPLACE VIEW audit.approval_instance AS
SELECT "approval_instance_id","approval_process_id","approval_instance_name","description","approval_start","approval_end","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.approval_instance;



-- XXX - Type change
CREATE OR REPLACE VIEW audit.approval_instance_item AS
SELECT
	"approval_instance_item_id",
	"approval_instance_link_id",
	"approval_instance_step_id",
	"next_approval_instance_item_id",
	"approved_category",
	"approved_label",
	"approved_lhs",
	"approved_rhs",
	CASE WHEN is_approved IS NULL THEN NULL
		WHEN is_approved = true THEN 'Y'
		WHEN is_approved = false THEN 'N'
		ELSE NULL
	END AS is_approved,
	"approved_account_id",
	"approval_note",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.approval_instance_item;



CREATE OR REPLACE VIEW audit.approval_instance_link AS
SELECT "approval_instance_link_id","acct_collection_acct_seq_id","person_company_seq_id","property_seq_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.approval_instance_link;



-- XXX - Type change
CREATE OR REPLACE VIEW audit.approval_instance_step AS
SELECT
	"approval_instance_step_id",
	"approval_instance_id",
	"approval_process_chain_id",
	"approval_instance_step_name",
	"approval_instance_step_due",
	"approval_type",
	"description",
	"approval_instance_step_start",
	"approval_instance_step_end",
	"approver_account_id",
	"external_reference_name",
	CASE WHEN is_completed IS NULL THEN NULL
		WHEN is_completed = true THEN 'Y'
		WHEN is_completed = false THEN 'N'
		ELSE NULL
	END AS is_completed,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.approval_instance_step;



CREATE OR REPLACE VIEW audit.approval_instance_step_notify AS
SELECT "approv_instance_step_notify_id","approval_instance_step_id","approval_notify_type","account_id","approval_notify_whence","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.approval_instance_step_notify;



-- Simple column rename
CREATE OR REPLACE VIEW audit.approval_process AS
SELECT
	"approval_process_id",
	"approval_process_name",
	"approval_process_type",
	"description",
	"first_approval_process_chain_id" AS first_apprvl_process_chain_id,
	"property_name_collection_id" AS property_collection_id,
	"approval_expiration_action",
	"attestation_frequency",
	"attestation_offset",
	"max_escalation_level",
	"escalation_delay",
	"escalation_reminder_gap",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.approval_process;



-- XXX - Type change
CREATE OR REPLACE VIEW audit.approval_process_chain AS
SELECT
	"approval_process_chain_id",
	"approval_process_chain_name",
	"approval_chain_response_period",
	"description",
	"message",
	"email_message",
	"email_subject_prefix",
	"email_subject_suffix",
	"max_escalation_level",
	"escalation_delay",
	"escalation_reminder_gap",
	"approving_entity",
	CASE WHEN refresh_all_data IS NULL THEN NULL
		WHEN refresh_all_data = true THEN 'Y'
		WHEN refresh_all_data = false THEN 'N'
		ELSE NULL
	END AS refresh_all_data,
	accept_approval_process_chain_id AS "accept_app_process_chain_id",
	reject_approval_process_chain_id AS "reject_app_process_chain_id",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.approval_process_chain;



CREATE OR REPLACE VIEW audit.asset AS
SELECT "asset_id","component_id","description","contract_id","serial_number","part_number","asset_tag","ownership_status","lease_expiration_date","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.asset;



CREATE OR REPLACE VIEW audit.badge AS
SELECT "card_number","badge_type_id","badge_status","date_assigned","date_reclaimed","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.badge;



CREATE OR REPLACE VIEW audit.badge_type AS
SELECT "badge_type_id","badge_type_name","description","badge_color","badge_template_name","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.badge_type;



CREATE OR REPLACE VIEW audit.certificate_signing_request AS
SELECT "certificate_signing_request_id","friendly_name","subject","certificate_signing_request","private_key_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.certificate_signing_request;



CREATE OR REPLACE VIEW audit.chassis_location AS
SELECT "chassis_location_id","chassis_device_type_id","device_type_module_name","chassis_device_id","module_device_type_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.chassis_location;



-- XXX - Type change
CREATE OR REPLACE VIEW audit.circuit AS
SELECT
	"circuit_id",
	"vendor_company_id",
	"vendor_circuit_id_str",
	"aloc_lec_company_id",
	"aloc_lec_circuit_id_str",
	"aloc_parent_circuit_id",
	"zloc_lec_company_id",
	"zloc_lec_circuit_id_str",
	"zloc_parent_circuit_id",
	CASE WHEN is_locally_managed IS NULL THEN NULL
		WHEN is_locally_managed = true THEN 'Y'
		WHEN is_locally_managed = false THEN 'N'
		ELSE NULL
	END AS is_locally_managed,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.circuit;



CREATE OR REPLACE VIEW audit.company AS
SELECT "company_id","company_name","company_short_name","parent_company_id","description","external_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.company;



CREATE OR REPLACE VIEW audit.company_collection AS
SELECT "company_collection_id","company_collection_name","company_collection_type","description","external_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.company_collection;



CREATE OR REPLACE VIEW audit.company_collection_company AS
SELECT "company_collection_id","company_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.company_collection_company;



CREATE OR REPLACE VIEW audit.company_collection_hier AS
SELECT "company_collection_id","child_company_collection_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.company_collection_hier;



CREATE OR REPLACE VIEW audit.company_type AS
SELECT "company_id","company_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.company_type;



CREATE OR REPLACE VIEW audit.component AS
SELECT "component_id","component_type_id","component_name","rack_location_id","parent_slot_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.component;



CREATE OR REPLACE VIEW audit.component_property AS
SELECT "component_property_id","component_function","component_type_id","component_id","inter_component_connection_id","slot_function","slot_type_id","slot_id","component_property_name","component_property_type","property_value","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.component_property;



-- XXX - Type change
CREATE OR REPLACE VIEW audit.component_type AS
SELECT
	"component_type_id",
	"company_id",
	"model",
	"slot_type_id",
	"description",
	"part_number",
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
	"size_units",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.component_type;



CREATE OR REPLACE VIEW audit.component_type_component_func AS
SELECT "component_function","component_type_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.component_type_component_function;



CREATE OR REPLACE VIEW audit.component_type_slot_tmplt AS
SELECT "component_type_slot_template_id" AS component_type_slot_tmplt_id,
	"component_type_id",
	"slot_type_id",
	"slot_name_template",
	"child_slot_name_template",
	"child_slot_offset",
	"slot_index",
	"physical_label",
	"slot_x_offset",
	"slot_y_offset",
	"slot_z_offset",
	"slot_side",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.component_type_slot_template;



CREATE OR REPLACE VIEW audit.contract AS
SELECT "contract_id","company_id","contract_name","vendor_contract_name","description","contract_termination_date","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.contract;



CREATE OR REPLACE VIEW audit.contract_type AS
SELECT "contract_id","contract_type","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.contract_type;



-- XXX - Type change
CREATE OR REPLACE VIEW audit.department AS
SELECT
	"account_collection_id",
	"company_id",
	"manager_account_id",
	CASE WHEN is_active IS NULL THEN NULL
		WHEN is_active = true THEN 'Y'
		WHEN is_active = false THEN 'N'
		ELSE NULL
	END AS is_active,
	"dept_code",
	"cost_center_name",
	"cost_center_number",
	"default_badge_type_id",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.department;



CREATE OR REPLACE VIEW audit.device AS
SELECT
	"device_id",
	"component_id",
	"device_type_id",
	"device_name",
	"site_code",
	"identifying_dns_record_id",
	"host_id",
	"physical_label",
	"rack_location_id",
	"chassis_location_id",
	"parent_device_id",
	"description",
	"external_id",
	"device_status",
	"operating_system_id",
	"service_environment_id",
	CASE WHEN is_virtual_device IS NULL THEN NULL
		WHEN is_virtual_device = true THEN 'Y'
		WHEN is_virtual_device = false THEN 'N'
		ELSE NULL
	END AS is_virtual_device,
	"date_in_service",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.device;



CREATE OR REPLACE VIEW audit.device_collection AS
SELECT "device_collection_id","device_collection_name","device_collection_type","description","external_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.device_collection;



-- Simple column rename
CREATE OR REPLACE VIEW audit.device_collection_assignd_cert AS
SELECT
	"device_collection_id",
	"x509_signed_certificate_id" AS x509_cert_id,
	"x509_key_usage" AS x509_key_usg,
	"x509_file_format",
	"file_location_path",
	"key_tool_label",
	"file_access_mode",
	"file_owner_account_id",
	"file_group_account_collection_id" AS file_group_acct_collection_id,
	"file_passphrase_path",
	"key_usage_reason_for_assignment" AS key_usage_reason_for_assign,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.device_collection_assigned_certificate;



CREATE OR REPLACE VIEW audit.device_collection_device AS
SELECT "device_id","device_collection_id","device_id_rank","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.device_collection_device;



CREATE OR REPLACE VIEW audit.device_collection_hier AS
SELECT "device_collection_id","child_device_collection_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.device_collection_hier;



CREATE OR REPLACE VIEW audit.device_collection_ssh_key AS
SELECT "ssh_key_id","device_collection_id","account_collection_id","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.device_collection_ssh_key;



CREATE OR REPLACE VIEW audit.device_encapsulation_domain AS
SELECT "device_id","encapsulation_type","encapsulation_domain","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.device_encapsulation_domain;





CREATE OR REPLACE VIEW audit.device_management_controller AS
WITH p AS NOT MATERIALIZED (
	SELECT device_id, component_id
	FROM (
		SELECT	device_id, component_id,
			rank() OVER 
			(PARTITION BY device_id ORDER BY "aud#timestamp" DESC) as rnk
		FROM	jazzhands_audit.device
		WHERE	component_id IS NOT NULL
	) q WHERE rnk = 1
) SELECT
	"manager_device_id",
	device_id,
	component_management_controller_type AS device_mgmt_control_type,
	"description",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.component_management_controller c
	JOIN (SELECT device_id, component_id FROM p) d
		USING (component_id)
	JOIN (SELECT device_id AS manager_device_id, 
			component_id AS manager_component_id 
			FROM p) md
		USING (manager_component_id)
;



CREATE OR REPLACE VIEW audit.device_note AS
SELECT device_note_id AS note_id,"device_id","note_text","note_date","note_user","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.device_note;



CREATE OR REPLACE VIEW audit.device_ssh_key AS
SELECT "device_id","ssh_key_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.device_ssh_key;



CREATE OR REPLACE VIEW audit.device_ticket AS
SELECT "device_id","ticketing_system_id","ticket_number","device_ticket_notes","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.device_ticket;



-- XXX - Type change
CREATE OR REPLACE VIEW audit.device_type AS
SELECT
	"device_type_id",
	"component_type_id",
	"device_type_name",
	"template_device_id",
	"idealized_device_id",
	"description",
	"company_id",
	"model",
	"device_type_depth_in_cm",
	"processor_architecture",
	"config_fetch_type",
	"rack_units",
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
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.device_type;



CREATE OR REPLACE VIEW audit.device_type_module AS
SELECT "device_type_id","device_type_module_name","description","device_type_x_offset","device_type_y_offset","device_type_z_offset","device_type_side","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.device_type_module;



CREATE OR REPLACE VIEW audit.device_type_module_device_type AS
SELECT "module_device_type_id","device_type_id","device_type_module_name","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.device_type_module_device_type;



CREATE OR REPLACE VIEW audit.dns_change_record AS
SELECT "dns_change_record_id","dns_domain_id","ip_universe_id","ip_address","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.dns_change_record;



CREATE OR REPLACE VIEW audit.dns_domain AS
SELECT "dns_domain_id",dns_domain_name AS soa_name,"dns_domain_name","dns_domain_type","parent_dns_domain_id","description","external_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.dns_domain;



CREATE OR REPLACE VIEW audit.dns_domain_collection AS
SELECT "dns_domain_collection_id","dns_domain_collection_name","dns_domain_collection_type","description","external_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.dns_domain_collection;



CREATE OR REPLACE VIEW audit.dns_domain_collection_dns_dom AS
SELECT "dns_domain_collection_id","dns_domain_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.dns_domain_collection_dns_domain;



CREATE OR REPLACE VIEW audit.dns_domain_collection_hier AS
SELECT "dns_domain_collection_id","child_dns_domain_collection_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.dns_domain_collection_hier;



-- XXX - Type change
CREATE OR REPLACE VIEW audit.dns_domain_ip_universe AS
SELECT
	"dns_domain_id",
	"ip_universe_id",
	"soa_class",
	"soa_ttl",
	"soa_serial",
	"soa_refresh",
	"soa_retry",
	"soa_expire",
	"soa_minimum",
	"soa_mname",
	"soa_rname",
	CASE WHEN should_generate IS NULL THEN NULL
		WHEN should_generate = true THEN 'Y'
		WHEN should_generate = false THEN 'N'
		ELSE NULL
	END AS should_generate,
	"last_generated",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.dns_domain_ip_universe;



-- XXX - Type change
CREATE OR REPLACE VIEW audit.dns_record AS
SELECT
	"dns_record_id",
	"dns_name",
	"dns_domain_id",
	"dns_ttl",
	"dns_class",
	"dns_type",
	"dns_value",
	"dns_priority",
	"dns_srv_service",
	"dns_srv_protocol",
	"dns_srv_weight",
	"dns_srv_port",
	"netblock_id",
	"ip_universe_id",
	"reference_dns_record_id",
	"dns_value_record_id",
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
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.dns_record;



CREATE OR REPLACE VIEW audit.dns_record_relation AS
SELECT "dns_record_id","related_dns_record_id","dns_record_relation_type","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.dns_record_relation;



CREATE OR REPLACE VIEW audit.encapsulation_domain AS
SELECT "encapsulation_domain","encapsulation_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.encapsulation_domain;



CREATE OR REPLACE VIEW audit.encapsulation_range AS
SELECT "encapsulation_range_id","parent_encapsulation_range_id","site_code","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.encapsulation_range;



CREATE OR REPLACE VIEW audit.encryption_key AS
SELECT "encryption_key_id","encryption_key_db_value","encryption_key_purpose","encryption_key_purpose_version","encryption_method","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.encryption_key;



CREATE OR REPLACE VIEW audit.inter_component_connection AS
SELECT "inter_component_connection_id","slot1_id","slot2_id","circuit_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.inter_component_connection;



-- XXX - Type change
CREATE OR REPLACE VIEW audit.ip_universe AS
SELECT
	"ip_universe_id",
	"ip_universe_name",
	"ip_namespace",
	CASE WHEN should_generate_dns IS NULL THEN NULL
		WHEN should_generate_dns = true THEN 'Y'
		WHEN should_generate_dns = false THEN 'N'
		ELSE NULL
	END AS should_generate_dns,
	"description",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.ip_universe;



-- XXX - Type change
CREATE OR REPLACE VIEW audit.ip_universe_visibility AS
SELECT
	"ip_universe_id",
	"visible_ip_universe_id",
	CASE WHEN propagate_dns IS NULL THEN NULL
		WHEN propagate_dns = true THEN 'Y'
		WHEN propagate_dns = false THEN 'N'
		ELSE NULL
	END AS propagate_dns,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.ip_universe_visibility;



CREATE OR REPLACE VIEW audit.kerberos_realm AS
SELECT "krb_realm_id","realm_name","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.kerberos_realm;



-- Simple column rename
CREATE OR REPLACE VIEW audit.klogin AS
SELECT
	"klogin_id",
	"account_id",
	"account_collection_id",
	"krb_realm_id",
	"krb_instance",
	"destination_account_id" AS dest_account_id,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.klogin;



CREATE OR REPLACE VIEW audit.klogin_mclass AS
SELECT "klogin_id","device_collection_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.klogin_mclass;



CREATE OR REPLACE VIEW audit.l2_network_coll_l2_network AS
SELECT "layer2_network_collection_id","layer2_network_id","layer2_network_id_rank","start_date","finish_date","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.layer2_network_collection_layer2_network;



CREATE OR REPLACE VIEW audit.l3_network_coll_l3_network AS
SELECT "layer3_network_collection_id","layer3_network_id","layer3_network_id_rank","start_date","finish_date","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.layer3_network_collection_layer3_network;



CREATE OR REPLACE VIEW audit.layer2_connection AS
SELECT "layer2_connection_id","logical_port1_id","logical_port2_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.layer2_connection;



CREATE OR REPLACE VIEW audit.layer2_connection_l2_network AS
SELECT "layer2_connection_id","layer2_network_id","encapsulation_mode","encapsulation_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.layer2_connection_layer2_network;



CREATE OR REPLACE VIEW audit.layer2_network AS
SELECT "layer2_network_id","encapsulation_name","encapsulation_domain","encapsulation_type","encapsulation_tag","description","external_id","encapsulation_range_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.layer2_network;



CREATE OR REPLACE VIEW audit.layer2_network_collection AS
SELECT "layer2_network_collection_id","layer2_network_collection_name","layer2_network_collection_type","description","external_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.layer2_network_collection;



-- Simple column rename
CREATE OR REPLACE VIEW audit.layer2_network_collection_hier AS
SELECT
	"layer2_network_collection_id",
	"child_layer2_network_collection_id" AS child_l2_network_coll_id,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.layer2_network_collection_hier;



CREATE OR REPLACE VIEW audit.layer3_network AS
SELECT "layer3_network_id","netblock_id","layer2_network_id","default_gateway_netblock_id","rendezvous_netblock_id","description","external_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.layer3_network;



CREATE OR REPLACE VIEW audit.layer3_network_collection AS
SELECT "layer3_network_collection_id","layer3_network_collection_name","layer3_network_collection_type","description","external_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.layer3_network_collection;



-- Simple column rename
CREATE OR REPLACE VIEW audit.layer3_network_collection_hier AS
SELECT
	"layer3_network_collection_id",
	"child_layer3_network_collection_id" AS child_l3_network_coll_id,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.layer3_network_collection_hier;



CREATE OR REPLACE VIEW audit.logical_port AS
SELECT "logical_port_id","logical_port_name","logical_port_type","device_id","mlag_peering_id","parent_logical_port_id","mac_address","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.logical_port;



CREATE OR REPLACE VIEW audit.logical_port_slot AS
SELECT "logical_port_id","slot_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.logical_port_slot;



CREATE OR REPLACE VIEW audit.logical_volume AS
SELECT "logical_volume_id","logical_volume_name","logical_volume_type","volume_group_id","device_id","logical_volume_size_in_bytes","logical_volume_offset_in_bytes","filesystem_type","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.logical_volume;



CREATE OR REPLACE VIEW audit.logical_volume_property AS
SELECT "logical_volume_property_id","logical_volume_id","logical_volume_type","logical_volume_purpose","filesystem_type","logical_volume_property_name","logical_volume_property_value","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.logical_volume_property;



CREATE OR REPLACE VIEW audit.logical_volume_purpose AS
SELECT "logical_volume_purpose","logical_volume_id","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.logical_volume_purpose;



CREATE OR REPLACE VIEW audit.mlag_peering AS
SELECT "mlag_peering_id","device1_id","device2_id","domain_id","system_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.mlag_peering;



-- XXX - Type change
CREATE OR REPLACE VIEW audit.netblock AS
SELECT
	"netblock_id",
	"ip_address",
	"netblock_type",
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
	"parent_netblock_id",
	"netblock_status",
	"ip_universe_id",
	"description",
	"external_id",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.netblock;



-- Simple column rename
CREATE OR REPLACE VIEW audit.netblock_collection AS
SELECT
	"netblock_collection_id",
	"netblock_collection_name",
	"netblock_collection_type",
	"netblock_ip_family_restriction" AS netblock_ip_family_restrict,
	"description",
	"external_id",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.netblock_collection;



CREATE OR REPLACE VIEW audit.netblock_collection_hier AS
SELECT "netblock_collection_id","child_netblock_collection_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.netblock_collection_hier;



CREATE OR REPLACE VIEW audit.netblock_collection_netblock AS
SELECT "netblock_collection_id","netblock_id","netblock_id_rank","start_date","finish_date","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.netblock_collection_netblock;



CREATE OR REPLACE VIEW audit.network_interface AS
SELECT
	"layer3_interface_id" AS network_interface_id,
	"device_id",
	"layer3_interface_name" AS network_interface_name,
	"description",
	"parent_layer3_interface_id" AS parent_network_interface_id,
	"parent_relation_type",
	slot_id AS physical_port_id,
	"slot_id",
	"logical_port_id",
	"layer3_interface_type" AS network_interface_type,
	CASE WHEN is_interface_up IS NULL THEN NULL
		WHEN is_interface_up = true THEN 'Y'
		WHEN is_interface_up = false THEN 'N'
		ELSE NULL
	END AS is_interface_up,
	"mac_addr",
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
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.layer3_interface;



-- Simple column rename
CREATE OR REPLACE VIEW audit.network_interface_netblock AS
SELECT
	"netblock_id",
	"layer3_interface_id" AS network_interface_id,
	"device_id",
	"layer3_interface_rank",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.layer3_interface_netblock;



-- Simple column rename
CREATE OR REPLACE VIEW audit.network_interface_purpose AS
SELECT
	"device_id",
	"layer3_interface_purpose",
	"layer3_interface_id" AS network_interface_id,
	"description",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.layer3_interface_purpose;



CREATE OR REPLACE VIEW audit.network_range AS
SELECT "network_range_id","network_range_type","description","parent_netblock_id","start_netblock_id","stop_netblock_id","dns_prefix","dns_domain_id","lease_time","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.network_range;



-- XXX - Type change
CREATE OR REPLACE VIEW audit.network_service AS
SELECT
	"network_service_id",
	"name",
	"description",
	"network_service_type",
	CASE WHEN is_monitored IS NULL THEN NULL
		WHEN is_monitored = true THEN 'Y'
		WHEN is_monitored = false THEN 'N'
		ELSE NULL
	END AS is_monitored,
	"device_id",
	"layer3_interface_id",
	"dns_record_id",
	"service_environment_id",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.network_service;



CREATE OR REPLACE VIEW audit.operating_system AS
SELECT
	"operating_system_id",
	"operating_system_name",
	"operating_system_short_name",
	"company_id",
	"major_version",
	"version",
	"operating_system_family",
	NULL::character varying(50) AS processor_architecture,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.operating_system;



CREATE OR REPLACE VIEW audit.operating_system_snapshot AS
SELECT "operating_system_snapshot_id","operating_system_snapshot_name","operating_system_snapshot_type","operating_system_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.operating_system_snapshot;



CREATE OR REPLACE VIEW audit.person AS
SELECT
	"person_id",
	"description",
	"first_name",
	"middle_name",
	"last_name",
	"name_suffix",
	CASE WHEN gender = 'male' THEN 'M'
		WHEN gender = 'female' THEN 'F'
		WHEN gender = 'unspecified' THEN 'U'
		WHEN gender is NULL THEN NULL
		ELSE 'U' END as gender,
	"preferred_first_name",
	"preferred_last_name",
	"nickname",
	"birth_date",
	"diet",
	"shirt_size",
	"pant_size",
	"hat_size",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.person;



CREATE OR REPLACE VIEW audit.person_account_realm_company AS
SELECT "person_id","company_id","account_realm_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.person_account_realm_company;



CREATE OR REPLACE VIEW audit.person_auth_question AS
SELECT
	authentication_question_id AS "auth_question_id",
	"person_id",
	"user_answer",
	CASE WHEN is_active IS NULL THEN NULL
		WHEN is_active = true THEN 'Y'
		WHEN is_active = false THEN 'N'
		ELSE NULL
	END AS is_active,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.person_authentication_question;



CREATE OR REPLACE VIEW audit.person_company AS
SELECT
	"company_id",
	"person_id",
	"person_company_status",
	"person_company_relation",
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
	"description",
	"position_title",
	"hire_date",
	"termination_date",
	"manager_person_id",
	"nickname",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.person_company;



-- Simple column rename
CREATE OR REPLACE VIEW audit.person_company_attr AS
SELECT
	"company_id",
	"person_id",
	"person_company_attribute_name" AS person_company_attr_name,
	"attribute_value",
	"attribute_value_timestamp",
	"attribute_value_person_id",
	"start_date",
	"finish_date",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.person_company_attribute;



CREATE OR REPLACE VIEW audit.person_company_badge AS
SELECT "company_id","person_id","badge_id","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.person_company_badge;



-- Simple column rename
CREATE OR REPLACE VIEW audit.person_contact AS
SELECT
	"person_contact_id",
	"person_id",
	"person_contact_type",
	"person_contact_technology",
	"person_contact_location_type",
	"person_contact_privacy",
	"person_contact_carrier_company_id" AS person_contact_cr_company_id,
	"iso_country_code",
	"phone_number",
	"phone_extension",
	"phone_pin",
	"person_contact_account_name",
	"person_contact_order",
	"person_contact_notes",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.person_contact;



CREATE OR REPLACE VIEW audit.person_image AS
SELECT "person_image_id","person_id","person_image_order","image_type","image_blob","image_checksum","image_label","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.person_image;



CREATE OR REPLACE VIEW audit.person_image_usage AS
SELECT "person_image_id","person_image_usage","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.person_image_usage;



CREATE OR REPLACE VIEW audit.person_location AS
SELECT "person_location_id","person_id","person_location_type","site_code","physical_address_id","building","floor","section","seat_number","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.person_location;



CREATE OR REPLACE VIEW audit.person_note AS
SELECT person_note_id AS note_id,"person_id","note_text","note_date","note_user","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.person_note;



CREATE OR REPLACE VIEW audit.person_parking_pass AS
SELECT "person_parking_pass_id","person_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.person_parking_pass;



CREATE OR REPLACE VIEW audit.person_vehicle AS
SELECT "person_vehicle_id","person_id","vehicle_make","vehicle_model","vehicle_year","vehicle_color","vehicle_license_plate","vehicle_license_state","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.person_vehicle;



CREATE OR REPLACE VIEW audit.physical_address AS
SELECT "physical_address_id","physical_address_type","company_id","site_rank","description","display_label","address_agent","address_housename","address_street","address_building","address_pobox","address_neighborhood","address_city","address_subregion","address_region","postal_code","iso_country_code","address_freeform","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.physical_address;



CREATE OR REPLACE VIEW audit.physical_connection AS
SELECT
	"physical_connection_id",
	slot1_id AS physical_port1_id,
	slot2_id AS physical_port2_id,
	"slot1_id",
	"slot2_id",
	"cable_type",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.physical_connection;

--
-- logical_volume_id is being phased out.  It is possible to go through
-- unholy things to get to it but not worth the effort.  I think.
--
CREATE OR REPLACE VIEW audit.physicalish_volume AS
SELECT	block_storage_device_id		AS physicalish_volume_id,
	block_storage_device_name	AS physicalish_volume_name,
	block_storage_device_type	AS physicalish_volume_type,
	device_id,
	NULL::integer			AS logical_volume_id,
	component_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.block_storage_device;



CREATE OR REPLACE VIEW audit.private_key AS
SELECT
	"private_key_id",
	"private_key_encryption_type",
	CASE WHEN is_active IS NULL THEN NULL
		WHEN is_active = true THEN 'Y'
		WHEN is_active = false THEN 'N'
		ELSE NULL
	END AS is_active,
	NULL::text AS "subject_key_identifier",
	"private_key",
	"passphrase",
	"encryption_key_id",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.private_key;



CREATE OR REPLACE VIEW audit.property AS
SELECT
	"property_id",
	"account_collection_id",
	"account_id",
	"account_realm_id",
	"company_collection_id",
	"company_id",
	"device_collection_id",
	"dns_domain_collection_id",
	"layer2_network_collection_id",
	"layer3_network_collection_id",
	"netblock_collection_id",
	"network_range_id",
	"operating_system_id",
	"operating_system_snapshot_id",
	"property_name_collection_id" AS property_collection_id,
	"service_environment_collection_id" AS service_env_collection_id,
	"site_code",
	"x509_signed_certificate_id",
	"property_name",
	"property_type",
	"property_value",
	"property_value_timestamp",
	"property_value_account_collection_id" AS property_value_account_coll_id,
	"property_value_device_collection_id" AS property_value_device_coll_id,
	"property_value_json",
	"property_value_netblock_collection_id" AS property_value_nblk_coll_id,
	"property_value_password_type",
	NULL::integer AS property_value_sw_package_id,
	"property_value_token_collection_id" AS property_value_token_col_id,
	"property_rank",
	"start_date",
	"finish_date",
	CASE WHEN is_enabled IS NULL THEN NULL
		WHEN is_enabled = true THEN 'Y'
		WHEN is_enabled = false THEN 'N'
		ELSE NULL
	END AS is_enabled,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.property;



-- Simple column rename
CREATE OR REPLACE VIEW audit.property_collection AS
SELECT
	"property_name_collection_id" AS property_collection_id,
	"property_name_collection_name" AS property_collection_name,
	"property_name_collection_type" AS property_collection_type,
	"description",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.property_name_collection;



-- Simple column rename
CREATE OR REPLACE VIEW audit.property_collection_hier AS
SELECT
	"property_name_collection_id" AS property_collection_id,
	"child_property_name_collection_id" AS child_property_collection_id,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.property_name_collection_hier;



-- Simple column rename
CREATE OR REPLACE VIEW audit.property_collection_property AS
SELECT
	"property_name_collection_id" AS property_collection_id,
	"property_name",
	"property_type",
	"property_id_rank",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.property_name_collection_property_name;



CREATE OR REPLACE VIEW audit.pseudo_klogin AS
SELECT "pseudo_klogin_id","principal","dest_account_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.pseudo_klogin;



CREATE OR REPLACE VIEW audit.rack AS
SELECT
	"rack_id",
	"site_code",
	"room",
	"sub_room",
	"rack_row",
	"rack_name",
	"rack_style",
	"rack_type",
	"description",
	"rack_height_in_u",
	CASE WHEN display_from_bottom IS NULL THEN NULL
		WHEN display_from_bottom = true THEN 'Y'
		WHEN display_from_bottom = false THEN 'N'
		ELSE NULL
	END AS display_from_bottom,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.rack;



CREATE OR REPLACE VIEW audit.rack_location AS
SELECT "rack_location_id","rack_id","rack_u_offset_of_device_top","rack_side","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.rack_location;



CREATE OR REPLACE VIEW audit.service_environment AS
SELECT "service_environment_id","service_environment_name","production_state","description","external_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.service_environment;



-- Simple column rename
CREATE OR REPLACE VIEW audit.service_environment_coll_hier AS
SELECT
	"service_environment_collection_id" AS service_env_collection_id,
	"child_service_environment_collection_id" AS child_service_env_coll_id,
	"description",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.service_environment_collection_hier;



-- Simple column rename
CREATE OR REPLACE VIEW audit.service_environment_collection AS
SELECT
	"service_environment_collection_id" AS service_env_collection_id,
	"service_environment_collection_name" AS service_env_collection_name,
	"service_environment_collection_type" AS service_env_collection_type,
	"description",
	"external_id",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.service_environment_collection;



CREATE OR REPLACE VIEW audit.shared_netblock AS
SELECT "shared_netblock_id","shared_netblock_protocol","netblock_id","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.shared_netblock;



-- Simple column rename
CREATE OR REPLACE VIEW audit.shared_netblock_network_int AS
SELECT
	"shared_netblock_id",
	"layer3_interface_id" AS network_interface_id,
	"priority",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.shared_netblock_layer3_interface;



CREATE OR REPLACE VIEW audit.site AS
SELECT "site_code","colo_company_id","physical_address_id","site_status","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.site;



CREATE OR REPLACE VIEW audit.slot AS
SELECT
	"slot_id",
	"component_id",
	"slot_name",
	"slot_index",
	"slot_type_id",
	"component_type_slot_template_id" AS component_type_slot_tmplt_id,
	CASE WHEN is_enabled IS NULL THEN NULL
		WHEN is_enabled = true THEN 'Y'
		WHEN is_enabled = false THEN 'N'
		ELSE NULL
	END AS is_enabled,
	"physical_label",
	"mac_address",
	"description",
	"slot_x_offset",
	"slot_y_offset",
	"slot_z_offset",
	"slot_side",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.slot;



CREATE OR REPLACE VIEW audit.slot_type AS
SELECT
	"slot_type_id",
	"slot_type",
	"slot_function",
	"slot_physical_interface_type",
	"description",
	CASE WHEN remote_slot_permitted IS NULL THEN NULL
		WHEN remote_slot_permitted = true THEN 'Y'
		WHEN remote_slot_permitted = false THEN 'N'
		ELSE NULL
	END AS remote_slot_permitted,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.slot_type;



CREATE OR REPLACE VIEW audit.slot_type_prmt_comp_slot_type AS
SELECT "slot_type_id","component_slot_type_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.slot_type_permitted_component_slot_type;



CREATE OR REPLACE VIEW audit.slot_type_prmt_rem_slot_type AS
SELECT "slot_type_id","remote_slot_type_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.slot_type_permitted_remote_slot_type;



CREATE OR REPLACE VIEW audit.ssh_key AS
SELECT "ssh_key_id","ssh_key_type","ssh_public_key","ssh_private_key","encryption_key_id","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.ssh_key;



-- Simple column rename
CREATE OR REPLACE VIEW audit.static_route AS
SELECT
	"static_route_id",
	"device_source_id" AS device_src_id,
	"layer3_interface_destination_id" AS network_interface_dst_id,
	"netblock_id",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.static_route;



-- Simple column rename
CREATE OR REPLACE VIEW audit.static_route_template AS
SELECT
	"static_route_template_id",
	"netblock_source_id" AS netblock_src_id,
	"layer3_interface_destination_id" AS network_interface_dst_id,
	"netblock_id",
	"description",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.static_route_template;



CREATE OR REPLACE VIEW audit.sudo_acct_col_device_collectio AS
SELECT
	"sudo_alias_name",
	"device_collection_id",
	"account_collection_id",
	"run_as_account_collection_id",
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
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.sudo_account_collection_device_collection;



CREATE OR REPLACE VIEW audit.sudo_alias AS
SELECT "sudo_alias_name","sudo_alias_value","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.sudo_alias;



-- Simple column rename
CREATE OR REPLACE VIEW audit.svc_environment_coll_svc_env AS
SELECT
	"service_environment_collection_id" AS service_env_collection_id,
	"service_environment_id",
	"description",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.service_environment_collection_service_environment;




CREATE OR REPLACE VIEW audit.sw_package AS
SELECT software_artifact_name_id AS sw_package_id,
       software_artifact_name sw_package_name,
       software_artifact_type sw_package_type,
       description,
       data_ins_user,data_ins_date,data_upd_user,data_upd_date,
	"aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.software_artifact_name;



CREATE OR REPLACE VIEW audit.ticketing_system AS
SELECT "ticketing_system_id","ticketing_system_name","ticketing_system_url","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.ticketing_system;



CREATE OR REPLACE VIEW audit.token AS
SELECT
	"token_id",
	"token_type",
	"token_status",
	"description",
	"external_id",
	"token_serial",
	"zero_time",
	"time_modulo",
	"time_skew",
	"token_key",
	"encryption_key_id",
	"token_password",
	"expire_time",
	CASE WHEN is_token_locked IS NULL THEN NULL
		WHEN is_token_locked = true THEN 'Y'
		WHEN is_token_locked = false THEN 'N'
		ELSE NULL
	END AS is_token_locked,
	"token_unlock_time",
	"bad_logins",
	"last_updated",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.token;



CREATE OR REPLACE VIEW audit.token_collection AS
SELECT "token_collection_id","token_collection_name","token_collection_type","description","external_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.token_collection;



CREATE OR REPLACE VIEW audit.token_collection_hier AS
SELECT "token_collection_id","child_token_collection_id","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.token_collection_hier;



CREATE OR REPLACE VIEW audit.token_collection_token AS
SELECT "token_collection_id","token_id","token_id_rank","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.token_collection_token;



CREATE OR REPLACE VIEW audit.token_sequence AS
SELECT "token_id","token_sequence","last_updated","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.token_sequence;



CREATE OR REPLACE VIEW audit.unix_group AS
SELECT "account_collection_id","unix_gid","group_password","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.unix_group;



CREATE OR REPLACE VIEW audit.val_account_collection_relatio AS
SELECT "account_collection_relation","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_account_collection_relation;



CREATE OR REPLACE VIEW audit.val_account_collection_type AS
SELECT
	"account_collection_type",
	"description",
	CASE WHEN is_infrastructure_type IS NULL THEN NULL
		WHEN is_infrastructure_type = true THEN 'Y'
		WHEN is_infrastructure_type = false THEN 'N'
		ELSE NULL
	END AS is_infrastructure_type,
	"max_num_members",
	"max_num_collections",
	CASE WHEN can_have_hierarchy IS NULL THEN NULL
		WHEN can_have_hierarchy = true THEN 'Y'
		WHEN can_have_hierarchy = false THEN 'N'
		ELSE NULL
	END AS can_have_hierarchy,
	"account_realm_id",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_account_collection_type;



CREATE OR REPLACE VIEW audit.val_account_role AS
SELECT
	"account_role",
	CASE WHEN uid_gid_forced IS NULL THEN NULL
		WHEN uid_gid_forced = true THEN 'Y'
		WHEN uid_gid_forced = false THEN 'N'
		ELSE NULL
	END AS uid_gid_forced,
	"description",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_account_role;



CREATE OR REPLACE VIEW audit.val_account_type AS
SELECT
	"account_type",
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
	"description",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_account_type;



CREATE OR REPLACE VIEW audit.val_app_key AS
SELECT "appaal_group_name",
	application_key AS "app_key",
	"description",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_application_key;



CREATE OR REPLACE VIEW audit.val_app_key_values AS
SELECT "appaal_group_name",
	application_key AS "app_key",
	application_value AS "app_value",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_application_key_values;



CREATE OR REPLACE VIEW audit.val_appaal_group_name AS
SELECT "appaal_group_name","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_appaal_group_name;



CREATE OR REPLACE VIEW audit.val_approval_chain_resp_prd AS
SELECT "approval_chain_response_period","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_approval_chain_response_period;



CREATE OR REPLACE VIEW audit.val_approval_expiration_action AS
SELECT "approval_expiration_action","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_approval_expiration_action;



CREATE OR REPLACE VIEW audit.val_approval_notifty_type AS
SELECT "approval_notify_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_approval_notifty_type;



CREATE OR REPLACE VIEW audit.val_approval_process_type AS
SELECT "approval_process_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_approval_process_type;



CREATE OR REPLACE VIEW audit.val_approval_type AS
SELECT "approval_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_approval_type;



CREATE OR REPLACE VIEW audit.val_attestation_frequency AS
SELECT "attestation_frequency","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_attestation_frequency;



CREATE OR REPLACE VIEW audit.val_auth_question AS
SELECT	authentication_question_id AS "auth_question_id",
	"question_text",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_authentication_question;



CREATE OR REPLACE VIEW audit.val_auth_resource AS
SELECT	authentication_resource AS "auth_resource",
	"description",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_authentication_resource;



CREATE OR REPLACE VIEW audit.val_badge_status AS
SELECT "badge_status","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_badge_status;



CREATE OR REPLACE VIEW audit.val_cable_type AS
SELECT "cable_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_cable_type;



CREATE OR REPLACE VIEW audit.val_company_collection_type AS
SELECT
	"company_collection_type",
	"description",
	CASE WHEN is_infrastructure_type IS NULL THEN NULL
		WHEN is_infrastructure_type = true THEN 'Y'
		WHEN is_infrastructure_type = false THEN 'N'
		ELSE NULL
	END AS is_infrastructure_type,
	"max_num_members",
	"max_num_collections",
	CASE WHEN can_have_hierarchy IS NULL THEN NULL
		WHEN can_have_hierarchy = true THEN 'Y'
		WHEN can_have_hierarchy = false THEN 'N'
		ELSE NULL
	END AS can_have_hierarchy,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_company_collection_type;



CREATE OR REPLACE VIEW audit.val_company_type AS
SELECT "company_type","description","company_type_purpose","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_company_type;



CREATE OR REPLACE VIEW audit.val_company_type_purpose AS
SELECT "company_type_purpose","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_company_type_purpose;



CREATE OR REPLACE VIEW audit.val_component_function AS
SELECT "component_function","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_component_function;



CREATE OR REPLACE VIEW audit.val_component_property AS
SELECT
	"component_property_name",
	"component_property_type",
	"description",
	CASE WHEN is_multivalue IS NULL THEN NULL
		WHEN is_multivalue = true THEN 'Y'
		WHEN is_multivalue = false THEN 'N'
		ELSE NULL
	END AS is_multivalue,
	"property_data_type",
	"permit_component_type_id",
	"required_component_type_id",
	"permit_component_function",
	"required_component_function",
	"permit_component_id",
	"permit_inter_component_connection_id" AS permit_intcomp_conn_id,
	"permit_slot_type_id",
	"required_slot_type_id",
	"permit_slot_function",
	"required_slot_function",
	"permit_slot_id",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_component_property;



CREATE OR REPLACE VIEW audit.val_component_property_type AS
SELECT
	"component_property_type",
	"description",
	CASE WHEN is_multivalue IS NULL THEN NULL
		WHEN is_multivalue = true THEN 'Y'
		WHEN is_multivalue = false THEN 'N'
		ELSE NULL
	END AS is_multivalue,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_component_property_type;



CREATE OR REPLACE VIEW audit.val_component_property_value AS
SELECT "component_property_name","component_property_type","valid_property_value","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_component_property_value;



CREATE OR REPLACE VIEW audit.val_contract_type AS
SELECT "contract_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_contract_type;



CREATE OR REPLACE VIEW audit.val_country_code AS
SELECT "iso_country_code","dial_country_code","primary_iso_currency_code","country_name","display_priority","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_country_code;



CREATE OR REPLACE VIEW audit.val_device_collection_type AS
SELECT
	"device_collection_type",
	"description",
	"max_num_members",
	"max_num_collections",
	CASE WHEN can_have_hierarchy IS NULL THEN NULL
		WHEN can_have_hierarchy = true THEN 'Y'
		WHEN can_have_hierarchy = false THEN 'N'
		ELSE NULL
	END AS can_have_hierarchy,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_device_collection_type;



CREATE OR REPLACE VIEW audit.val_device_mgmt_ctrl_type AS
SELECT component_management_controller_type AS device_mgmt_control_type,
	"description",
	"data_ins_user","data_ins_date","data_upd_user","data_upd_date",
	"aud#action","aud#timestamp","aud#realtime","aud#txid",
	"aud#user","aud#seq"
FROM jazzhands_audit.val_component_management_controller_type;

CREATE OR REPLACE VIEW audit.val_device_status AS
SELECT "device_status","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_device_status;



CREATE OR REPLACE VIEW audit.val_diet AS
SELECT "diet","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_diet;



CREATE OR REPLACE VIEW audit.val_dns_class AS
SELECT "dns_class","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_dns_class;



CREATE OR REPLACE VIEW audit.val_dns_domain_collection_type AS
SELECT
	"dns_domain_collection_type",
	"description",
	"max_num_members",
	"max_num_collections",
	CASE WHEN can_have_hierarchy IS NULL THEN NULL
		WHEN can_have_hierarchy = true THEN 'Y'
		WHEN can_have_hierarchy = false THEN 'N'
		ELSE NULL
	END AS can_have_hierarchy,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_dns_domain_collection_type;



CREATE OR REPLACE VIEW audit.val_dns_domain_type AS
SELECT
	"dns_domain_type",
	CASE WHEN can_generate IS NULL THEN NULL
		WHEN can_generate = true THEN 'Y'
		WHEN can_generate = false THEN 'N'
		ELSE NULL
	END AS can_generate,
	"description",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_dns_domain_type;



CREATE OR REPLACE VIEW audit.val_dns_record_relation_type AS
SELECT "dns_record_relation_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_dns_record_relation_type;



CREATE OR REPLACE VIEW audit.val_dns_srv_service AS
SELECT "dns_srv_service","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_dns_srv_service;



CREATE OR REPLACE VIEW audit.val_dns_type AS
SELECT "dns_type","description","id_type","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_dns_type;



CREATE OR REPLACE VIEW audit.val_encapsulation_mode AS
SELECT "encapsulation_mode","encapsulation_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_encapsulation_mode;



CREATE OR REPLACE VIEW audit.val_encapsulation_type AS
SELECT "encapsulation_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_encapsulation_type;



CREATE OR REPLACE VIEW audit.val_encryption_key_purpose AS
SELECT "encryption_key_purpose","encryption_key_purpose_version","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_encryption_key_purpose;



CREATE OR REPLACE VIEW audit.val_encryption_method AS
SELECT "encryption_method","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_encryption_method;



CREATE OR REPLACE VIEW audit.val_filesystem_type AS
SELECT "filesystem_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_filesystem_type;



CREATE OR REPLACE VIEW audit.val_image_type AS
SELECT "image_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_image_type;



CREATE OR REPLACE VIEW audit.val_ip_namespace AS
SELECT "ip_namespace","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_ip_namespace;



CREATE OR REPLACE VIEW audit.val_iso_currency_code AS
SELECT "iso_currency_code","description","currency_symbol","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_iso_currency_code;



-- Simple column rename
CREATE OR REPLACE VIEW audit.val_key_usg_reason_for_assgn AS
SELECT
	"key_usage_reason_for_assignment" AS key_usage_reason_for_assign,
	"description",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_key_usage_reason_for_assignment;



CREATE OR REPLACE VIEW audit.val_layer2_network_coll_type AS
SELECT
	"layer2_network_collection_type",
	"description",
	"max_num_members",
	"max_num_collections",
	CASE WHEN can_have_hierarchy IS NULL THEN NULL
		WHEN can_have_hierarchy = true THEN 'Y'
		WHEN can_have_hierarchy = false THEN 'N'
		ELSE NULL
	END AS can_have_hierarchy,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_layer2_network_collection_type;



CREATE OR REPLACE VIEW audit.val_layer3_network_coll_type AS
SELECT
	"layer3_network_collection_type",
	"description",
	"max_num_members",
	"max_num_collections",
	CASE WHEN can_have_hierarchy IS NULL THEN NULL
		WHEN can_have_hierarchy = true THEN 'Y'
		WHEN can_have_hierarchy = false THEN 'N'
		ELSE NULL
	END AS can_have_hierarchy,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_layer3_network_collection_type;



CREATE OR REPLACE VIEW audit.val_logical_port_type AS
SELECT "logical_port_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_logical_port_type;



CREATE OR REPLACE VIEW audit.val_logical_volume_property AS
SELECT "logical_volume_property_name","filesystem_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_logical_volume_property;



CREATE OR REPLACE VIEW audit.val_logical_volume_purpose AS
SELECT "logical_volume_purpose","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_logical_volume_purpose;



CREATE OR REPLACE VIEW audit.val_logical_volume_type AS
SELECT "logical_volume_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_logical_volume_type;



CREATE OR REPLACE VIEW audit.val_netblock_collection_type AS
SELECT
	"netblock_collection_type",
	"description",
	"max_num_members",
	"max_num_collections",
	CASE WHEN can_have_hierarchy IS NULL THEN NULL
		WHEN can_have_hierarchy = true THEN 'Y'
		WHEN can_have_hierarchy = false THEN 'N'
		ELSE NULL
	END AS can_have_hierarchy,
	"netblock_is_single_address_restriction" AS netblock_single_addr_restrict,
	"netblock_ip_family_restriction" AS netblock_ip_family_restrict,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_netblock_collection_type;



CREATE OR REPLACE VIEW audit.val_netblock_status AS
SELECT "netblock_status","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_netblock_status;



CREATE OR REPLACE VIEW audit.val_netblock_type AS
SELECT
	"netblock_type",
	"description",
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
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_netblock_type;



CREATE OR REPLACE VIEW audit.val_network_interface_purpose AS
SELECT layer3_interface_purpose AS network_interface_purpose,
	"description",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_layer3_interface_purpose;



CREATE OR REPLACE VIEW audit.val_network_interface_type AS
SELECT layer3_interface_type AS network_interface_type,
	"description",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date"
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_layer3_interface_type;



CREATE OR REPLACE VIEW audit.val_network_range_type AS
SELECT
	"network_range_type",
	"description",
	"dns_domain_required",
	"default_dns_prefix",
	"netblock_type",
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
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_network_range_type;



CREATE OR REPLACE VIEW audit.val_network_service_type AS
SELECT "network_service_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_network_service_type;



CREATE OR REPLACE VIEW audit.val_operating_system_family AS
SELECT "operating_system_family","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_operating_system_family;



CREATE OR REPLACE VIEW audit.val_os_snapshot_type AS
SELECT "operating_system_snapshot_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_operating_system_snapshot_type;



CREATE OR REPLACE VIEW audit.val_ownership_status AS
SELECT "ownership_status","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_ownership_status;

CREATE OR REPLACE VIEW audit.val_password_type AS
SELECT "password_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_password_type;



-- Simple column rename
CREATE OR REPLACE VIEW audit.val_person_company_attr_dtype AS
SELECT
	"person_company_attribute_data_type" AS person_company_attr_data_type,
	"description",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_person_company_attribute_data_type;



-- Simple column rename
CREATE OR REPLACE VIEW audit.val_person_company_attr_name AS
SELECT
	"person_company_attribute_name" AS person_company_attr_name,
	"person_company_attribute_data_type" AS person_company_attr_data_type,
	"description",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_person_company_attribute_name;



-- Simple column rename
CREATE OR REPLACE VIEW audit.val_person_company_attr_value AS
SELECT
	"person_company_attribute_name" AS person_company_attr_name,
	"person_company_attribute_value" AS person_company_attr_value,
	"description",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_person_company_attribute_value;



CREATE OR REPLACE VIEW audit.val_person_company_relation AS
SELECT "person_company_relation","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_person_company_relation;



CREATE OR REPLACE VIEW audit.val_person_contact_loc_type AS
SELECT "person_contact_location_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_person_contact_location_type;



CREATE OR REPLACE VIEW audit.val_person_contact_technology AS
SELECT "person_contact_technology","person_contact_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_person_contact_technology;



CREATE OR REPLACE VIEW audit.val_person_contact_type AS
SELECT "person_contact_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_person_contact_type;



CREATE OR REPLACE VIEW audit.val_person_image_usage AS
SELECT
	"person_image_usage",
	CASE WHEN is_multivalue IS NULL THEN NULL
		WHEN is_multivalue = true THEN 'Y'
		WHEN is_multivalue = false THEN 'N'
		ELSE NULL
	END AS is_multivalue,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_person_image_usage;



CREATE OR REPLACE VIEW audit.val_person_location_type AS
SELECT "person_location_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_person_location_type;



CREATE OR REPLACE VIEW audit.val_person_status AS
SELECT
	"person_status",
	"description",
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
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_person_status;



CREATE OR REPLACE VIEW audit.val_physical_address_type AS
SELECT "physical_address_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_physical_address_type;



CREATE OR REPLACE VIEW audit.val_physicalish_volume_type AS
SELECT	block_storage_device_type AS physicalish_volume_type,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_block_storage_device_type;



CREATE OR REPLACE VIEW audit.val_processor_architecture AS
SELECT "processor_architecture","kernel_bits","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_processor_architecture;



CREATE OR REPLACE VIEW audit.val_production_state AS
SELECT "production_state","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_production_state;



CREATE OR REPLACE VIEW audit.val_property AS
SELECT
	"property_name",
	"property_type",
	"description",
	"account_collection_type",
	"company_collection_type",
	"device_collection_type",
	"dns_domain_collection_type",
	"layer2_network_collection_type",
	"layer3_network_collection_type",
	"netblock_collection_type",
	"network_range_type",
	"property_name_collection_type" AS property_collection_type,
	"service_environment_collection_type" AS service_env_collection_type,
	CASE WHEN is_multivalue IS NULL THEN NULL
		WHEN is_multivalue = true THEN 'Y'
		WHEN is_multivalue = false THEN 'N'
		ELSE NULL
	END AS is_multivalue,
	"property_value_account_collection_type_restriction" AS prop_val_acct_coll_type_rstrct,
	"property_value_device_collection_type_restriction" AS prop_val_dev_coll_type_rstrct,
	"property_value_netblock_collection_type_restriction" AS prop_val_nblk_coll_type_rstrct,
	"property_data_type",
	"property_value_json_schema",
	"permit_account_collection_id",
	"permit_account_id",
	"permit_account_realm_id",
	"permit_company_id",
	"permit_company_collection_id",
	"permit_device_collection_id",
	"permit_dns_domain_collection_id" AS permit_dns_domain_coll_id,
	"permit_layer2_network_collection_id" AS permit_layer2_network_coll_id,
	"permit_layer3_network_collection_id" AS permit_layer3_network_coll_id,
	"permit_netblock_collection_id",
	"permit_network_range_id",
	"permit_operating_system_id",
	"permit_operating_system_snapshot_id" AS permit_os_snapshot_id,
	"permit_property_name_collection_id" AS permit_property_collection_id,
	"permit_service_environment_collection_id" AS permit_service_env_collection,
	"permit_site_code",
	"permit_x509_signed_certificate_id" AS permit_x509_signed_cert_id,
	"permit_property_rank",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_property;



CREATE OR REPLACE VIEW audit.val_property_collection_type AS
SELECT
	"property_name_collection_type" AS property_collection_type,
	"description",
	"max_num_members",
	"max_num_collections",
	CASE WHEN can_have_hierarchy IS NULL THEN NULL
		WHEN can_have_hierarchy = true THEN 'Y'
		WHEN can_have_hierarchy = false THEN 'N'
		ELSE NULL
	END AS can_have_hierarchy,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_property_name_collection_type;



CREATE OR REPLACE VIEW audit.val_property_data_type AS
SELECT "property_data_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_property_data_type;



CREATE OR REPLACE VIEW audit.val_property_type AS
SELECT
	"property_type",
	"description",
	"property_value_account_collection_type_restriction" AS prop_val_acct_coll_type_rstrct,
	CASE WHEN is_multivalue IS NULL THEN NULL
		WHEN is_multivalue = true THEN 'Y'
		WHEN is_multivalue = false THEN 'N'
		ELSE NULL
	END AS is_multivalue,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_property_type;



CREATE OR REPLACE VIEW audit.val_property_value AS
SELECT "property_name","property_type","valid_property_value","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_property_value;



CREATE OR REPLACE VIEW audit.val_pvt_key_encryption_type AS
SELECT "private_key_encryption_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_private_key_encryption_type;



CREATE OR REPLACE VIEW audit.val_rack_type AS
SELECT "rack_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_rack_type;



CREATE OR REPLACE VIEW audit.val_raid_type AS
SELECT "raid_type","description","primary_raid_level","secondary_raid_level","raid_level_qualifier","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_raid_type;



CREATE OR REPLACE VIEW audit.val_service_env_coll_type AS
SELECT
	"service_environment_collection_type" AS service_env_collection_type,
	"description",
	"max_num_members",
	"max_num_collections",
	CASE WHEN can_have_hierarchy IS NULL THEN NULL
		WHEN can_have_hierarchy = true THEN 'Y'
		WHEN can_have_hierarchy = false THEN 'N'
		ELSE NULL
	END AS can_have_hierarchy,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_service_environment_collection_type;



CREATE OR REPLACE VIEW audit.val_shared_netblock_protocol AS
SELECT "shared_netblock_protocol","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_shared_netblock_protocol;



CREATE OR REPLACE VIEW audit.val_slot_function AS
SELECT
	"slot_function",
	"description",
	CASE WHEN can_have_mac_address IS NULL THEN NULL
		WHEN can_have_mac_address = true THEN 'Y'
		WHEN can_have_mac_address = false THEN 'N'
		ELSE NULL
	END AS can_have_mac_address,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_slot_function;



CREATE OR REPLACE VIEW audit.val_slot_physical_interface AS
SELECT "slot_physical_interface_type","slot_function","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_slot_physical_interface;



CREATE OR REPLACE VIEW audit.val_ssh_key_type AS
SELECT "ssh_key_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_ssh_key_type;



CREATE OR REPLACE VIEW audit.val_sw_package_type AS
SELECT software_artifact_type AS sw_package_type,
	description,
	data_ins_user,data_ins_date,data_upd_user,data_upd_date,
	"aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_software_artifact_type;



CREATE OR REPLACE VIEW audit.val_token_collection_type AS
SELECT
	"token_collection_type",
	"description",
	"max_num_members",
	"max_num_collections",
	CASE WHEN can_have_hierarchy IS NULL THEN NULL
		WHEN can_have_hierarchy = true THEN 'Y'
		WHEN can_have_hierarchy = false THEN 'N'
		ELSE NULL
	END AS can_have_hierarchy,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_token_collection_type;



CREATE OR REPLACE VIEW audit.val_token_status AS
SELECT "token_status","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_token_status;



CREATE OR REPLACE VIEW audit.val_token_type AS
SELECT "token_type","description","token_digit_count","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_token_type;



CREATE OR REPLACE VIEW audit.val_volume_group_purpose AS
SELECT "volume_group_purpose","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_volume_group_purpose;



CREATE OR REPLACE VIEW audit.val_volume_group_relation AS
SELECT "volume_group_relation","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_volume_group_relation;



CREATE OR REPLACE VIEW audit.val_volume_group_type AS
SELECT "volume_group_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_volume_group_type;



-- Simple column rename
CREATE OR REPLACE VIEW audit.val_x509_certificate_file_fmt AS
SELECT
	"x509_certificate_file_format" AS x509_file_format,
	"description",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_x509_certificate_file_format;



CREATE OR REPLACE VIEW audit.val_x509_certificate_type AS
SELECT "x509_certificate_type","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_x509_certificate_type;



CREATE OR REPLACE VIEW audit.val_x509_key_usage AS
SELECT
	"x509_key_usage" AS x509_key_usg,
	"description",
	CASE WHEN is_extended IS NULL THEN NULL
		WHEN is_extended = true THEN 'Y'
		WHEN is_extended = false THEN 'N'
		ELSE NULL
	END AS is_extended,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_x509_key_usage;



-- Simple column rename
CREATE OR REPLACE VIEW audit.val_x509_key_usage_category AS
SELECT
	"x509_key_usage_category" AS x509_key_usg_cat,
	"description",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.val_x509_key_usage_category;



CREATE OR REPLACE VIEW audit.val_x509_revocation_reason AS
SELECT "x509_revocation_reason","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.val_x509_revocation_reason;



CREATE OR REPLACE VIEW audit.volume_group AS
SELECT "volume_group_id","device_id","component_id","volume_group_name","volume_group_type","volume_group_size_in_bytes","raid_type","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.volume_group;



-- Simple column rename
CREATE OR REPLACE VIEW audit.volume_group_physicalish_vol AS
SELECT
	block_storage_device_id AS physicalish_volume_id,
	volume_group_id,
	device_id,
	volume_group_primary_position AS volume_group_primary_pos,
	volume_group_secondary_position AS volume_group_secondary_pos,
	volume_group_relation,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.volume_group_block_storage_device;



CREATE OR REPLACE VIEW audit.volume_group_purpose AS
SELECT "volume_group_id","volume_group_purpose","description","data_ins_user","data_ins_date","data_upd_user","data_upd_date","aud#action","aud#timestamp","aud#realtime","aud#txid","aud#user","aud#seq"
FROM jazzhands_audit.volume_group_purpose;



-- Simple column rename
CREATE OR REPLACE VIEW audit.x509_key_usage_attribute AS
SELECT
	"x509_signed_certificate_id" AS x509_cert_id,
	"x509_key_usage" AS x509_key_usg,
	"x509_key_usgage_category" AS x509_key_usg_cat,
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.x509_key_usage_attribute;



-- Simple column rename
CREATE OR REPLACE VIEW audit.x509_key_usage_categorization AS
SELECT
	"x509_key_usage_category" AS x509_key_usg_cat,
	"x509_key_usage" AS x509_key_usg,
	"description",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.x509_key_usage_categorization;



CREATE OR REPLACE VIEW audit.x509_key_usage_default AS
SELECT
	"x509_signed_certificate_id",
	"x509_key_usage" AS x509_key_usg,
	"description",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.x509_key_usage_default;



CREATE OR REPLACE VIEW audit.x509_signed_certificate AS
SELECT
	"x509_signed_certificate_id",
	"x509_certificate_type",
	"subject",
	"friendly_name",
	"subject_key_identifier",
	"public_key_hash_id",
	"description",
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
	"signing_cert_id",
	"x509_ca_cert_serial_number",
	"public_key",
	"private_key_id",
	"certificate_signing_request_id",
	"valid_from",
	"valid_to",
	"x509_revocation_date",
	"x509_revocation_reason",
	"ocsp_uri",
	"crl_uri",
	"data_ins_user",
	"data_ins_date",
	"data_upd_user",
	"data_upd_date",
	"aud#action",
	"aud#timestamp",
	"aud#realtime",
	"aud#txid",
	"aud#user",
	"aud#seq"
FROM jazzhands_audit.x509_signed_certificate;


-- These are all just dropped in the audit schema:
--- snmp_commstr
--- v_device_collection_hier_trans
--- v_network_interface_trans
--- val_device_auto_mgmt_protocol
--- val_snmp_commstr_type

