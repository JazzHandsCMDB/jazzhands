/*
Invoked:

	jazzhands
	jazzhands_legacy
*/

\set ON_ERROR_STOP
CREATE SCHEMA jazzhands_legacy;

CREATE OR REPLACE VIEW jazzhands_legacy.account AS
SELECT account_id,login,person_id,company_id,is_enabled,account_realm_id,account_status,account_role,account_type,description,external_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account;

SELECT schema_support.save_grants_for_replay('jazzhands', 'account');
CREATE OR REPLACE VIEW jazzhands_legacy.account_assignd_cert AS
SELECT account_id,x509_cert_id,x509_key_usg,key_usage_reason_for_assign,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account_assignd_cert;

SELECT schema_support.save_grants_for_replay('jazzhands', 'account_assignd_cert');
CREATE OR REPLACE VIEW jazzhands_legacy.account_auth_log AS
SELECT account_id,account_auth_ts,auth_resource,account_auth_seq,was_auth_success,auth_resource_instance,auth_origin,data_ins_date,data_ins_user
FROM jazzhands.account_auth_log;

SELECT schema_support.save_grants_for_replay('jazzhands', 'account_auth_log');
CREATE OR REPLACE VIEW jazzhands_legacy.account_coll_type_relation AS
SELECT account_collection_relation,account_collection_type,max_num_members,max_num_collections,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account_coll_type_relation;

SELECT schema_support.save_grants_for_replay('jazzhands', 'account_coll_type_relation');
CREATE OR REPLACE VIEW jazzhands_legacy.account_collection AS
SELECT account_collection_id,account_collection_name,account_collection_type,external_id,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account_collection;

SELECT schema_support.save_grants_for_replay('jazzhands', 'account_collection');
CREATE OR REPLACE VIEW jazzhands_legacy.account_collection_account AS
SELECT account_collection_id,account_id,account_collection_relation,account_id_rank,start_date,finish_date,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account_collection_account;

ALTER TABLE jazzhands_legacy.account_collection_account
	ALTER account_collection_relation SET DEFAULT 'direct'::character varying;

SELECT schema_support.save_grants_for_replay('jazzhands', 'account_collection_account');
CREATE OR REPLACE VIEW jazzhands_legacy.account_collection_hier AS
SELECT account_collection_id,child_account_collection_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account_collection_hier;

SELECT schema_support.save_grants_for_replay('jazzhands', 'account_collection_hier');
CREATE OR REPLACE VIEW jazzhands_legacy.account_password AS
SELECT account_id,account_realm_id,password_type,password,change_time,expire_time,unlock_time,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account_password;

SELECT schema_support.save_grants_for_replay('jazzhands', 'account_password');
CREATE OR REPLACE VIEW jazzhands_legacy.account_realm AS
SELECT account_realm_id,account_realm_name,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account_realm;

SELECT schema_support.save_grants_for_replay('jazzhands', 'account_realm');
CREATE OR REPLACE VIEW jazzhands_legacy.account_realm_acct_coll_type AS
SELECT account_realm_id,account_collection_type,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account_realm_acct_coll_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'account_realm_acct_coll_type');
CREATE OR REPLACE VIEW jazzhands_legacy.account_realm_company AS
SELECT account_realm_id,company_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account_realm_company;

SELECT schema_support.save_grants_for_replay('jazzhands', 'account_realm_company');
CREATE OR REPLACE VIEW jazzhands_legacy.account_realm_password_type AS
SELECT password_type,account_realm_id,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account_realm_password_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'account_realm_password_type');
CREATE OR REPLACE VIEW jazzhands_legacy.account_ssh_key AS
SELECT account_id,ssh_key_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account_ssh_key;

SELECT schema_support.save_grants_for_replay('jazzhands', 'account_ssh_key');
CREATE OR REPLACE VIEW jazzhands_legacy.account_token AS
SELECT account_token_id,account_id,token_id,issued_date,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account_token;

SELECT schema_support.save_grants_for_replay('jazzhands', 'account_token');
CREATE OR REPLACE VIEW jazzhands_legacy.account_unix_info AS
SELECT account_id,unix_uid,unix_group_acct_collection_id,shell,default_home,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.account_unix_info;

SELECT schema_support.save_grants_for_replay('jazzhands', 'account_unix_info');
CREATE OR REPLACE VIEW jazzhands_legacy.appaal AS
SELECT appaal_id,appaal_name,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.appaal;

SELECT schema_support.save_grants_for_replay('jazzhands', 'appaal');
CREATE OR REPLACE VIEW jazzhands_legacy.appaal_instance AS
SELECT appaal_instance_id,appaal_id,service_environment_id,file_mode,file_owner_account_id,file_group_acct_collection_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.appaal_instance;

SELECT schema_support.save_grants_for_replay('jazzhands', 'appaal_instance');
CREATE OR REPLACE VIEW jazzhands_legacy.appaal_instance_device_coll AS
SELECT device_collection_id,appaal_instance_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.appaal_instance_device_coll;

SELECT schema_support.save_grants_for_replay('jazzhands', 'appaal_instance_device_coll');
CREATE OR REPLACE VIEW jazzhands_legacy.appaal_instance_property AS
SELECT appaal_instance_id,app_key,appaal_group_name,appaal_group_rank,app_value,encryption_key_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.appaal_instance_property;

SELECT schema_support.save_grants_for_replay('jazzhands', 'appaal_instance_property');
CREATE OR REPLACE VIEW jazzhands_legacy.approval_instance AS
SELECT approval_instance_id,approval_process_id,approval_instance_name,description,approval_start,approval_end,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.approval_instance;

ALTER TABLE jazzhands_legacy.approval_instance
	ALTER approval_start SET DEFAULT now();

SELECT schema_support.save_grants_for_replay('jazzhands', 'approval_instance');
CREATE OR REPLACE VIEW jazzhands_legacy.approval_instance_item AS
SELECT approval_instance_item_id,approval_instance_link_id,approval_instance_step_id,next_approval_instance_item_id,approved_category,approved_label,approved_lhs,approved_rhs,is_approved,approved_account_id,approval_note,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.approval_instance_item;

SELECT schema_support.save_grants_for_replay('jazzhands', 'approval_instance_item');
CREATE OR REPLACE VIEW jazzhands_legacy.approval_instance_link AS
SELECT approval_instance_link_id,acct_collection_acct_seq_id,person_company_seq_id,property_seq_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.approval_instance_link;

SELECT schema_support.save_grants_for_replay('jazzhands', 'approval_instance_link');
CREATE OR REPLACE VIEW jazzhands_legacy.approval_instance_step AS
SELECT approval_instance_step_id,approval_instance_id,approval_process_chain_id,approval_instance_step_name,approval_instance_step_due,approval_type,description,approval_instance_step_start,approval_instance_step_end,approver_account_id,external_reference_name,is_completed,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.approval_instance_step;

ALTER TABLE jazzhands_legacy.approval_instance_step
	ALTER approval_instance_step_start SET DEFAULT now();

ALTER TABLE jazzhands_legacy.approval_instance_step
	ALTER is_completed SET DEFAULT 'N'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'approval_instance_step');
CREATE OR REPLACE VIEW jazzhands_legacy.approval_instance_step_notify AS
SELECT approv_instance_step_notify_id,approval_instance_step_id,approval_notify_type,account_id,approval_notify_whence,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.approval_instance_step_notify;

SELECT schema_support.save_grants_for_replay('jazzhands', 'approval_instance_step_notify');
CREATE OR REPLACE VIEW jazzhands_legacy.approval_process AS
SELECT approval_process_id,approval_process_name,approval_process_type,description,first_apprvl_process_chain_id,property_collection_id,approval_expiration_action,attestation_frequency,attestation_offset,max_escalation_level,escalation_delay,escalation_reminder_gap,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.approval_process;

SELECT schema_support.save_grants_for_replay('jazzhands', 'approval_process');
CREATE OR REPLACE VIEW jazzhands_legacy.approval_process_chain AS
SELECT approval_process_chain_id,approval_process_chain_name,approval_chain_response_period,description,message,email_message,email_subject_prefix,email_subject_suffix,max_escalation_level,escalation_delay,escalation_reminder_gap,approving_entity,refresh_all_data,accept_app_process_chain_id,reject_app_process_chain_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.approval_process_chain;

ALTER TABLE jazzhands_legacy.approval_process_chain
	ALTER approval_chain_response_period SET DEFAULT '1 week'::character varying;

ALTER TABLE jazzhands_legacy.approval_process_chain
	ALTER refresh_all_data SET DEFAULT 'N'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'approval_process_chain');
CREATE OR REPLACE VIEW jazzhands_legacy.asset AS
SELECT asset_id,component_id,description,contract_id,serial_number,part_number,asset_tag,ownership_status,lease_expiration_date,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.asset;

SELECT schema_support.save_grants_for_replay('jazzhands', 'asset');
CREATE OR REPLACE VIEW jazzhands_legacy.badge AS
SELECT card_number,badge_type_id,badge_status,date_assigned,date_reclaimed,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.badge;

SELECT schema_support.save_grants_for_replay('jazzhands', 'badge');
CREATE OR REPLACE VIEW jazzhands_legacy.badge_type AS
SELECT badge_type_id,badge_type_name,description,badge_color,badge_template_name,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.badge_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'badge_type');
CREATE OR REPLACE VIEW jazzhands_legacy.certificate_signing_request AS
SELECT certificate_signing_request_id,friendly_name,subject,certificate_signing_request,private_key_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.certificate_signing_request;

SELECT schema_support.save_grants_for_replay('jazzhands', 'certificate_signing_request');
CREATE OR REPLACE VIEW jazzhands_legacy.chassis_location AS
SELECT chassis_location_id,chassis_device_type_id,device_type_module_name,chassis_device_id,module_device_type_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.chassis_location;

SELECT schema_support.save_grants_for_replay('jazzhands', 'chassis_location');
CREATE OR REPLACE VIEW jazzhands_legacy.circuit AS
SELECT circuit_id,vendor_company_id,vendor_circuit_id_str,aloc_lec_company_id,aloc_lec_circuit_id_str,aloc_parent_circuit_id,zloc_lec_company_id,zloc_lec_circuit_id_str,zloc_parent_circuit_id,is_locally_managed,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.circuit;

SELECT schema_support.save_grants_for_replay('jazzhands', 'circuit');
CREATE OR REPLACE VIEW jazzhands_legacy.company AS
SELECT company_id,company_name,company_short_name,parent_company_id,description,external_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.company;

SELECT schema_support.save_grants_for_replay('jazzhands', 'company');
CREATE OR REPLACE VIEW jazzhands_legacy.company_collection AS
SELECT company_collection_id,company_collection_name,company_collection_type,description,external_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.company_collection;

SELECT schema_support.save_grants_for_replay('jazzhands', 'company_collection');
CREATE OR REPLACE VIEW jazzhands_legacy.company_collection_company AS
SELECT company_collection_id,company_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.company_collection_company;

SELECT schema_support.save_grants_for_replay('jazzhands', 'company_collection_company');
CREATE OR REPLACE VIEW jazzhands_legacy.company_collection_hier AS
SELECT company_collection_id,child_company_collection_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.company_collection_hier;

SELECT schema_support.save_grants_for_replay('jazzhands', 'company_collection_hier');
CREATE OR REPLACE VIEW jazzhands_legacy.company_type AS
SELECT company_id,company_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.company_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'company_type');
CREATE OR REPLACE VIEW jazzhands_legacy.component AS
SELECT component_id,component_type_id,component_name,rack_location_id,parent_slot_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.component;

SELECT schema_support.save_grants_for_replay('jazzhands', 'component');
CREATE OR REPLACE VIEW jazzhands_legacy.component_property AS
SELECT component_property_id,component_function,component_type_id,component_id,inter_component_connection_id,slot_function,slot_type_id,slot_id,component_property_name,component_property_type,property_value,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.component_property;

SELECT schema_support.save_grants_for_replay('jazzhands', 'component_property');
CREATE OR REPLACE VIEW jazzhands_legacy.component_type AS
SELECT component_type_id,company_id,model,slot_type_id,description,part_number,is_removable,asset_permitted,is_rack_mountable,is_virtual_component,size_units,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.component_type;

ALTER TABLE jazzhands_legacy.component_type
	ALTER is_removable SET DEFAULT 'N'::bpchar;

ALTER TABLE jazzhands_legacy.component_type
	ALTER asset_permitted SET DEFAULT 'N'::bpchar;

ALTER TABLE jazzhands_legacy.component_type
	ALTER is_rack_mountable SET DEFAULT 'N'::bpchar;

ALTER TABLE jazzhands_legacy.component_type
	ALTER is_virtual_component SET DEFAULT 'N'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'component_type');
CREATE OR REPLACE VIEW jazzhands_legacy.component_type_component_func AS
SELECT component_function,component_type_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.component_type_component_func;

SELECT schema_support.save_grants_for_replay('jazzhands', 'component_type_component_func');
CREATE OR REPLACE VIEW jazzhands_legacy.component_type_slot_tmplt AS
SELECT component_type_slot_tmplt_id,component_type_id,slot_type_id,slot_name_template,child_slot_name_template,child_slot_offset,slot_index,physical_label,slot_x_offset,slot_y_offset,slot_z_offset,slot_side,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.component_type_slot_tmplt;

ALTER TABLE jazzhands_legacy.component_type_slot_tmplt
	ALTER slot_side SET DEFAULT 'FRONT'::character varying;

SELECT schema_support.save_grants_for_replay('jazzhands', 'component_type_slot_tmplt');
CREATE OR REPLACE VIEW jazzhands_legacy.contract AS
SELECT contract_id,company_id,contract_name,vendor_contract_name,description,contract_termination_date,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.contract;

SELECT schema_support.save_grants_for_replay('jazzhands', 'contract');
CREATE OR REPLACE VIEW jazzhands_legacy.contract_type AS
SELECT contract_id,contract_type,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.contract_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'contract_type');
CREATE OR REPLACE VIEW jazzhands_legacy.department AS
SELECT account_collection_id,company_id,manager_account_id,is_active,dept_code,cost_center_name,cost_center_number,default_badge_type_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.department;

ALTER TABLE jazzhands_legacy.department
	ALTER is_active SET DEFAULT 'Y'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'department');
CREATE OR REPLACE VIEW jazzhands_legacy.device AS
SELECT device_id,component_id,device_type_id,device_name,site_code,identifying_dns_record_id,host_id,physical_label,rack_location_id,chassis_location_id,parent_device_id,description,external_id,device_status,operating_system_id,service_environment_id,auto_mgmt_protocol,is_locally_managed,is_monitored,is_virtual_device,should_fetch_config,date_in_service,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device;

ALTER TABLE jazzhands_legacy.device
	ALTER is_locally_managed SET DEFAULT 'Y'::bpchar;

ALTER TABLE jazzhands_legacy.device
	ALTER is_virtual_device SET DEFAULT 'N'::bpchar;

ALTER TABLE jazzhands_legacy.device
	ALTER should_fetch_config SET DEFAULT 'Y'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'device');
CREATE OR REPLACE VIEW jazzhands_legacy.device_collection AS
SELECT device_collection_id,device_collection_name,device_collection_type,description,external_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_collection;

SELECT schema_support.save_grants_for_replay('jazzhands', 'device_collection');
CREATE OR REPLACE VIEW jazzhands_legacy.device_collection_assignd_cert AS
SELECT device_collection_id,x509_cert_id,x509_key_usg,x509_file_format,file_location_path,key_tool_label,file_access_mode,file_owner_account_id,file_group_acct_collection_id,file_passphrase_path,key_usage_reason_for_assign,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_collection_assignd_cert;

SELECT schema_support.save_grants_for_replay('jazzhands', 'device_collection_assignd_cert');
CREATE OR REPLACE VIEW jazzhands_legacy.device_collection_device AS
SELECT device_id,device_collection_id,device_id_rank,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_collection_device;

SELECT schema_support.save_grants_for_replay('jazzhands', 'device_collection_device');
CREATE OR REPLACE VIEW jazzhands_legacy.device_collection_hier AS
SELECT device_collection_id,child_device_collection_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_collection_hier;

SELECT schema_support.save_grants_for_replay('jazzhands', 'device_collection_hier');
CREATE OR REPLACE VIEW jazzhands_legacy.device_collection_ssh_key AS
SELECT ssh_key_id,device_collection_id,account_collection_id,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_collection_ssh_key;

SELECT schema_support.save_grants_for_replay('jazzhands', 'device_collection_ssh_key');
CREATE OR REPLACE VIEW jazzhands_legacy.device_encapsulation_domain AS
SELECT device_id,encapsulation_type,encapsulation_domain,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_encapsulation_domain;

SELECT schema_support.save_grants_for_replay('jazzhands', 'device_encapsulation_domain');
CREATE OR REPLACE VIEW jazzhands_legacy.device_layer2_network AS
SELECT device_id,layer2_network_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_layer2_network;

SELECT schema_support.save_grants_for_replay('jazzhands', 'device_layer2_network');
CREATE OR REPLACE VIEW jazzhands_legacy.device_management_controller AS
SELECT manager_device_id,device_id,device_mgmt_control_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_management_controller;

SELECT schema_support.save_grants_for_replay('jazzhands', 'device_management_controller');
CREATE OR REPLACE VIEW jazzhands_legacy.device_note AS
SELECT note_id,device_id,note_text,note_date,note_user,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_note;

SELECT schema_support.save_grants_for_replay('jazzhands', 'device_note');
CREATE OR REPLACE VIEW jazzhands_legacy.device_ssh_key AS
SELECT device_id,ssh_key_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_ssh_key;

SELECT schema_support.save_grants_for_replay('jazzhands', 'device_ssh_key');
CREATE OR REPLACE VIEW jazzhands_legacy.device_ticket AS
SELECT device_id,ticketing_system_id,ticket_number,device_ticket_notes,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_ticket;

SELECT schema_support.save_grants_for_replay('jazzhands', 'device_ticket');
CREATE OR REPLACE VIEW jazzhands_legacy.device_type AS
SELECT device_type_id,component_type_id,device_type_name,template_device_id,idealized_device_id,description,company_id,model,device_type_depth_in_cm,processor_architecture,config_fetch_type,rack_units,has_802_3_interface,has_802_11_interface,snmp_capable,is_chassis,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_type;

ALTER TABLE jazzhands_legacy.device_type
	ALTER has_802_3_interface SET DEFAULT 'N'::bpchar;

ALTER TABLE jazzhands_legacy.device_type
	ALTER has_802_11_interface SET DEFAULT 'N'::bpchar;

ALTER TABLE jazzhands_legacy.device_type
	ALTER snmp_capable SET DEFAULT 'N'::bpchar;

ALTER TABLE jazzhands_legacy.device_type
	ALTER is_chassis SET DEFAULT 'N'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'device_type');
CREATE OR REPLACE VIEW jazzhands_legacy.device_type_module AS
SELECT device_type_id,device_type_module_name,description,device_type_x_offset,device_type_y_offset,device_type_z_offset,device_type_side,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_type_module;

ALTER TABLE jazzhands_legacy.device_type_module
	ALTER device_type_side SET DEFAULT 'FRONT'::character varying;

SELECT schema_support.save_grants_for_replay('jazzhands', 'device_type_module');
CREATE OR REPLACE VIEW jazzhands_legacy.device_type_module_device_type AS
SELECT module_device_type_id,device_type_id,device_type_module_name,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_type_module_device_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'device_type_module_device_type');
CREATE OR REPLACE VIEW jazzhands_legacy.dns_change_record AS
SELECT dns_change_record_id,dns_domain_id,ip_universe_id,ip_address,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.dns_change_record;

SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_change_record');
CREATE OR REPLACE VIEW jazzhands_legacy.dns_domain AS
SELECT dns_domain_id,soa_name,dns_domain_name,dns_domain_type,parent_dns_domain_id,description,external_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.dns_domain;

SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_domain');
CREATE OR REPLACE VIEW jazzhands_legacy.dns_domain_collection AS
SELECT dns_domain_collection_id,dns_domain_collection_name,dns_domain_collection_type,description,external_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.dns_domain_collection;

SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_domain_collection');
CREATE OR REPLACE VIEW jazzhands_legacy.dns_domain_collection_dns_dom AS
SELECT dns_domain_collection_id,dns_domain_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.dns_domain_collection_dns_dom;

SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_domain_collection_dns_dom');
CREATE OR REPLACE VIEW jazzhands_legacy.dns_domain_collection_hier AS
SELECT dns_domain_collection_id,child_dns_domain_collection_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.dns_domain_collection_hier;

SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_domain_collection_hier');
CREATE OR REPLACE VIEW jazzhands_legacy.dns_domain_ip_universe AS
SELECT dns_domain_id,ip_universe_id,soa_class,soa_ttl,soa_serial,soa_refresh,soa_retry,soa_expire,soa_minimum,soa_mname,soa_rname,should_generate,last_generated,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.dns_domain_ip_universe;

SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_domain_ip_universe');
CREATE OR REPLACE VIEW jazzhands_legacy.dns_record AS
SELECT dns_record_id,dns_name,dns_domain_id,dns_ttl,dns_class,dns_type,dns_value,dns_priority,dns_srv_service,dns_srv_protocol,dns_srv_weight,dns_srv_port,netblock_id,ip_universe_id,reference_dns_record_id,dns_value_record_id,should_generate_ptr,is_enabled,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.dns_record;

ALTER TABLE jazzhands_legacy.dns_record
	ALTER dns_class SET DEFAULT 'IN'::character varying;

ALTER TABLE jazzhands_legacy.dns_record
	ALTER should_generate_ptr SET DEFAULT 'Y'::bpchar;

ALTER TABLE jazzhands_legacy.dns_record
	ALTER is_enabled SET DEFAULT 'Y'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_record');
CREATE OR REPLACE VIEW jazzhands_legacy.dns_record_relation AS
SELECT dns_record_id,related_dns_record_id,dns_record_relation_type,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.dns_record_relation;

SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_record_relation');
CREATE OR REPLACE VIEW jazzhands_legacy.encapsulation_domain AS
SELECT encapsulation_domain,encapsulation_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.encapsulation_domain;

SELECT schema_support.save_grants_for_replay('jazzhands', 'encapsulation_domain');
CREATE OR REPLACE VIEW jazzhands_legacy.encapsulation_range AS
SELECT encapsulation_range_id,parent_encapsulation_range_id,site_code,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.encapsulation_range;

SELECT schema_support.save_grants_for_replay('jazzhands', 'encapsulation_range');
CREATE OR REPLACE VIEW jazzhands_legacy.encryption_key AS
SELECT encryption_key_id,encryption_key_db_value,encryption_key_purpose,encryption_key_purpose_version,encryption_method,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.encryption_key;

SELECT schema_support.save_grants_for_replay('jazzhands', 'encryption_key');
CREATE OR REPLACE VIEW jazzhands_legacy.inter_component_connection AS
SELECT inter_component_connection_id,slot1_id,slot2_id,circuit_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.inter_component_connection;

SELECT schema_support.save_grants_for_replay('jazzhands', 'inter_component_connection');
CREATE OR REPLACE VIEW jazzhands_legacy.ip_universe AS
SELECT ip_universe_id,ip_universe_name,ip_namespace,should_generate_dns,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.ip_universe;

SELECT schema_support.save_grants_for_replay('jazzhands', 'ip_universe');
CREATE OR REPLACE VIEW jazzhands_legacy.ip_universe_visibility AS
SELECT ip_universe_id,visible_ip_universe_id,propagate_dns,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.ip_universe_visibility;

ALTER TABLE jazzhands_legacy.ip_universe_visibility
	ALTER propagate_dns SET DEFAULT 'Y'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'ip_universe_visibility');
CREATE OR REPLACE VIEW jazzhands_legacy.kerberos_realm AS
SELECT krb_realm_id,realm_name,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.kerberos_realm;

SELECT schema_support.save_grants_for_replay('jazzhands', 'kerberos_realm');
CREATE OR REPLACE VIEW jazzhands_legacy.klogin AS
SELECT klogin_id,account_id,account_collection_id,krb_realm_id,krb_instance,dest_account_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.klogin;

SELECT schema_support.save_grants_for_replay('jazzhands', 'klogin');
CREATE OR REPLACE VIEW jazzhands_legacy.klogin_mclass AS
SELECT klogin_id,device_collection_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.klogin_mclass;

SELECT schema_support.save_grants_for_replay('jazzhands', 'klogin_mclass');
CREATE OR REPLACE VIEW jazzhands_legacy.l2_network_coll_l2_network AS
SELECT layer2_network_collection_id,layer2_network_id,layer2_network_id_rank,start_date,finish_date,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.l2_network_coll_l2_network;

SELECT schema_support.save_grants_for_replay('jazzhands', 'l2_network_coll_l2_network');
CREATE OR REPLACE VIEW jazzhands_legacy.l3_network_coll_l3_network AS
SELECT layer3_network_collection_id,layer3_network_id,layer3_network_id_rank,start_date,finish_date,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.l3_network_coll_l3_network;

SELECT schema_support.save_grants_for_replay('jazzhands', 'l3_network_coll_l3_network');
CREATE OR REPLACE VIEW jazzhands_legacy.layer2_connection AS
SELECT layer2_connection_id,logical_port1_id,logical_port2_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.layer2_connection;

SELECT schema_support.save_grants_for_replay('jazzhands', 'layer2_connection');
CREATE OR REPLACE VIEW jazzhands_legacy.layer2_connection_l2_network AS
SELECT layer2_connection_id,layer2_network_id,encapsulation_mode,encapsulation_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.layer2_connection_l2_network;

SELECT schema_support.save_grants_for_replay('jazzhands', 'layer2_connection_l2_network');
CREATE OR REPLACE VIEW jazzhands_legacy.layer2_network AS
SELECT layer2_network_id,encapsulation_name,encapsulation_domain,encapsulation_type,encapsulation_tag,description,external_id,encapsulation_range_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.layer2_network;

SELECT schema_support.save_grants_for_replay('jazzhands', 'layer2_network');
CREATE OR REPLACE VIEW jazzhands_legacy.layer2_network_collection AS
SELECT layer2_network_collection_id,layer2_network_collection_name,layer2_network_collection_type,description,external_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.layer2_network_collection;

SELECT schema_support.save_grants_for_replay('jazzhands', 'layer2_network_collection');
CREATE OR REPLACE VIEW jazzhands_legacy.layer2_network_collection_hier AS
SELECT layer2_network_collection_id,child_l2_network_coll_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.layer2_network_collection_hier;

SELECT schema_support.save_grants_for_replay('jazzhands', 'layer2_network_collection_hier');
CREATE OR REPLACE VIEW jazzhands_legacy.layer3_network AS
SELECT layer3_network_id,netblock_id,layer2_network_id,default_gateway_netblock_id,rendezvous_netblock_id,description,external_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.layer3_network;

SELECT schema_support.save_grants_for_replay('jazzhands', 'layer3_network');
CREATE OR REPLACE VIEW jazzhands_legacy.layer3_network_collection AS
SELECT layer3_network_collection_id,layer3_network_collection_name,layer3_network_collection_type,description,external_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.layer3_network_collection;

SELECT schema_support.save_grants_for_replay('jazzhands', 'layer3_network_collection');
CREATE OR REPLACE VIEW jazzhands_legacy.layer3_network_collection_hier AS
SELECT layer3_network_collection_id,child_l3_network_coll_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.layer3_network_collection_hier;

SELECT schema_support.save_grants_for_replay('jazzhands', 'layer3_network_collection_hier');
CREATE OR REPLACE VIEW jazzhands_legacy.logical_port AS
SELECT logical_port_id,logical_port_name,logical_port_type,parent_logical_port_id,mac_address,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.logical_port;

SELECT schema_support.save_grants_for_replay('jazzhands', 'logical_port');
CREATE OR REPLACE VIEW jazzhands_legacy.logical_port_slot AS
SELECT logical_port_id,slot_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.logical_port_slot;

SELECT schema_support.save_grants_for_replay('jazzhands', 'logical_port_slot');
CREATE OR REPLACE VIEW jazzhands_legacy.logical_volume AS
SELECT logical_volume_id,logical_volume_name,logical_volume_type,volume_group_id,device_id,logical_volume_size_in_bytes,logical_volume_offset_in_bytes,filesystem_type,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.logical_volume;

ALTER TABLE jazzhands_legacy.logical_volume
	ALTER logical_volume_type SET DEFAULT 'legacy'::character varying;

SELECT schema_support.save_grants_for_replay('jazzhands', 'logical_volume');
CREATE OR REPLACE VIEW jazzhands_legacy.logical_volume_property AS
SELECT logical_volume_property_id,logical_volume_id,logical_volume_type,logical_volume_purpose,filesystem_type,logical_volume_property_name,logical_volume_property_value,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.logical_volume_property;

SELECT schema_support.save_grants_for_replay('jazzhands', 'logical_volume_property');
CREATE OR REPLACE VIEW jazzhands_legacy.logical_volume_purpose AS
SELECT logical_volume_purpose,logical_volume_id,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.logical_volume_purpose;

SELECT schema_support.save_grants_for_replay('jazzhands', 'logical_volume_purpose');
CREATE OR REPLACE VIEW jazzhands_legacy.mlag_peering AS
SELECT mlag_peering_id,device1_id,device2_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.mlag_peering;

SELECT schema_support.save_grants_for_replay('jazzhands', 'mlag_peering');
CREATE OR REPLACE VIEW jazzhands_legacy.netblock AS
SELECT netblock_id,ip_address,netblock_type,is_single_address,can_subnet,parent_netblock_id,netblock_status,ip_universe_id,description,external_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.netblock;

ALTER TABLE jazzhands_legacy.netblock
	ALTER netblock_type SET DEFAULT 'default'::character varying;

SELECT schema_support.save_grants_for_replay('jazzhands', 'netblock');
CREATE OR REPLACE VIEW jazzhands_legacy.netblock_collection AS
SELECT netblock_collection_id,netblock_collection_name,netblock_collection_type,netblock_ip_family_restrict,description,external_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.netblock_collection;

SELECT schema_support.save_grants_for_replay('jazzhands', 'netblock_collection');
CREATE OR REPLACE VIEW jazzhands_legacy.netblock_collection_hier AS
SELECT netblock_collection_id,child_netblock_collection_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.netblock_collection_hier;

SELECT schema_support.save_grants_for_replay('jazzhands', 'netblock_collection_hier');
CREATE OR REPLACE VIEW jazzhands_legacy.netblock_collection_netblock AS
SELECT netblock_collection_id,netblock_id,netblock_id_rank,start_date,finish_date,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.netblock_collection_netblock;

SELECT schema_support.save_grants_for_replay('jazzhands', 'netblock_collection_netblock');
CREATE OR REPLACE VIEW jazzhands_legacy.network_interface AS
SELECT network_interface_id,device_id,network_interface_name,description,parent_network_interface_id,parent_relation_type,physical_port_id,slot_id,logical_port_id,network_interface_type,is_interface_up,mac_addr,should_monitor,should_manage,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.network_interface;

ALTER TABLE jazzhands_legacy.network_interface
	ALTER is_interface_up SET DEFAULT 'Y'::bpchar;

ALTER TABLE jazzhands_legacy.network_interface
	ALTER should_monitor SET DEFAULT 'Y'::bpchar;

ALTER TABLE jazzhands_legacy.network_interface
	ALTER should_manage SET DEFAULT 'Y'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'network_interface');
CREATE OR REPLACE VIEW jazzhands_legacy.network_interface_netblock AS
SELECT netblock_id,network_interface_id,device_id,network_interface_rank,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.network_interface_netblock;

SELECT schema_support.save_grants_for_replay('jazzhands', 'network_interface_netblock');
CREATE OR REPLACE VIEW jazzhands_legacy.network_interface_purpose AS
SELECT device_id,network_interface_purpose,network_interface_id,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.network_interface_purpose;

SELECT schema_support.save_grants_for_replay('jazzhands', 'network_interface_purpose');
CREATE OR REPLACE VIEW jazzhands_legacy.network_range AS
SELECT network_range_id,network_range_type,description,parent_netblock_id,start_netblock_id,stop_netblock_id,dns_prefix,dns_domain_id,lease_time,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.network_range;

SELECT schema_support.save_grants_for_replay('jazzhands', 'network_range');
CREATE OR REPLACE VIEW jazzhands_legacy.network_service AS
SELECT network_service_id,name,description,network_service_type,is_monitored,device_id,network_interface_id,dns_record_id,service_environment_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.network_service;

SELECT schema_support.save_grants_for_replay('jazzhands', 'network_service');
CREATE OR REPLACE VIEW jazzhands_legacy.operating_system AS
SELECT operating_system_id,operating_system_name,operating_system_short_name,company_id,major_version,version,operating_system_family,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.operating_system;

SELECT schema_support.save_grants_for_replay('jazzhands', 'operating_system');
CREATE OR REPLACE VIEW jazzhands_legacy.operating_system_snapshot AS
SELECT operating_system_snapshot_id,operating_system_snapshot_name,operating_system_snapshot_type,operating_system_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.operating_system_snapshot;

SELECT schema_support.save_grants_for_replay('jazzhands', 'operating_system_snapshot');
CREATE OR REPLACE VIEW jazzhands_legacy.person AS
SELECT person_id,description,first_name,middle_name,last_name,name_suffix,gender,preferred_first_name,preferred_last_name,nickname,birth_date,diet,shirt_size,pant_size,hat_size,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.person;

SELECT schema_support.save_grants_for_replay('jazzhands', 'person');
CREATE OR REPLACE VIEW jazzhands_legacy.person_account_realm_company AS
SELECT person_id,company_id,account_realm_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.person_account_realm_company;

SELECT schema_support.save_grants_for_replay('jazzhands', 'person_account_realm_company');
CREATE OR REPLACE VIEW jazzhands_legacy.person_auth_question AS
SELECT auth_question_id,person_id,user_answer,is_active,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.person_auth_question;

SELECT schema_support.save_grants_for_replay('jazzhands', 'person_auth_question');
CREATE OR REPLACE VIEW jazzhands_legacy.person_company AS
SELECT company_id,person_id,person_company_status,person_company_relation,is_exempt,is_management,is_full_time,description,position_title,hire_date,termination_date,manager_person_id,nickname,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.person_company;

ALTER TABLE jazzhands_legacy.person_company
	ALTER is_exempt SET DEFAULT 'Y'::bpchar;

ALTER TABLE jazzhands_legacy.person_company
	ALTER is_management SET DEFAULT 'N'::bpchar;

ALTER TABLE jazzhands_legacy.person_company
	ALTER is_full_time SET DEFAULT 'Y'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'person_company');
CREATE OR REPLACE VIEW jazzhands_legacy.person_company_attr AS
SELECT company_id,person_id,person_company_attr_name,attribute_value,attribute_value_timestamp,attribute_value_person_id,start_date,finish_date,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.person_company_attr;

SELECT schema_support.save_grants_for_replay('jazzhands', 'person_company_attr');
CREATE OR REPLACE VIEW jazzhands_legacy.person_company_badge AS
SELECT company_id,person_id,badge_id,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.person_company_badge;

SELECT schema_support.save_grants_for_replay('jazzhands', 'person_company_badge');
CREATE OR REPLACE VIEW jazzhands_legacy.person_contact AS
SELECT person_contact_id,person_id,person_contact_type,person_contact_technology,person_contact_location_type,person_contact_privacy,person_contact_cr_company_id,iso_country_code,phone_number,phone_extension,phone_pin,person_contact_account_name,person_contact_order,person_contact_notes,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.person_contact;

SELECT schema_support.save_grants_for_replay('jazzhands', 'person_contact');
CREATE OR REPLACE VIEW jazzhands_legacy.person_image AS
SELECT person_image_id,person_id,person_image_order,image_type,image_blob,image_checksum,image_label,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.person_image;

SELECT schema_support.save_grants_for_replay('jazzhands', 'person_image');
CREATE OR REPLACE VIEW jazzhands_legacy.person_image_usage AS
SELECT person_image_id,person_image_usage,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.person_image_usage;

SELECT schema_support.save_grants_for_replay('jazzhands', 'person_image_usage');
CREATE OR REPLACE VIEW jazzhands_legacy.person_location AS
SELECT person_location_id,person_id,person_location_type,site_code,physical_address_id,building,floor,section,seat_number,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.person_location;

SELECT schema_support.save_grants_for_replay('jazzhands', 'person_location');
CREATE OR REPLACE VIEW jazzhands_legacy.person_note AS
SELECT note_id,person_id,note_text,note_date,note_user,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.person_note;

SELECT schema_support.save_grants_for_replay('jazzhands', 'person_note');
CREATE OR REPLACE VIEW jazzhands_legacy.person_parking_pass AS
SELECT person_parking_pass_id,person_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.person_parking_pass;

SELECT schema_support.save_grants_for_replay('jazzhands', 'person_parking_pass');
CREATE OR REPLACE VIEW jazzhands_legacy.person_vehicle AS
SELECT person_vehicle_id,person_id,vehicle_make,vehicle_model,vehicle_year,vehicle_color,vehicle_license_plate,vehicle_license_state,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.person_vehicle;

SELECT schema_support.save_grants_for_replay('jazzhands', 'person_vehicle');
CREATE OR REPLACE VIEW jazzhands_legacy.physical_address AS
SELECT physical_address_id,physical_address_type,company_id,site_rank,description,display_label,address_agent,address_housename,address_street,address_building,address_pobox,address_neighborhood,address_city,address_subregion,address_region,postal_code,iso_country_code,address_freeform,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.physical_address;

ALTER TABLE jazzhands_legacy.physical_address
	ALTER physical_address_type SET DEFAULT 'location'::character varying;

SELECT schema_support.save_grants_for_replay('jazzhands', 'physical_address');
CREATE OR REPLACE VIEW jazzhands_legacy.physical_connection AS
SELECT physical_connection_id,physical_port1_id,physical_port2_id,slot1_id,slot2_id,cable_type,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.physical_connection;

SELECT schema_support.save_grants_for_replay('jazzhands', 'physical_connection');
CREATE OR REPLACE VIEW jazzhands_legacy.physicalish_volume AS
SELECT physicalish_volume_id,physicalish_volume_name,physicalish_volume_type,device_id,logical_volume_id,component_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.physicalish_volume;

SELECT schema_support.save_grants_for_replay('jazzhands', 'physicalish_volume');
CREATE OR REPLACE VIEW jazzhands_legacy.private_key AS
SELECT private_key_id,private_key_encryption_type,is_active,subject_key_identifier,private_key,passphrase,encryption_key_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.private_key;

ALTER TABLE jazzhands_legacy.private_key
	ALTER is_active SET DEFAULT 'Y'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'private_key');
CREATE OR REPLACE VIEW jazzhands_legacy.property AS
SELECT property_id,account_collection_id,account_id,account_realm_id,company_collection_id,company_id,device_collection_id,dns_domain_collection_id,layer2_network_collection_id,layer3_network_collection_id,netblock_collection_id,network_range_id,operating_system_id,operating_system_snapshot_id,person_id,property_collection_id,service_env_collection_id,site_code,x509_signed_certificate_id,property_name,property_type,property_value,property_value_timestamp,property_value_account_coll_id,property_value_device_coll_id,property_value_json,property_value_nblk_coll_id,property_value_password_type,property_value_person_id,property_value_sw_package_id,property_value_token_col_id,property_rank,start_date,finish_date,is_enabled,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.property;

ALTER TABLE jazzhands_legacy.property
	ALTER is_enabled SET DEFAULT 'Y'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'property');
CREATE OR REPLACE VIEW jazzhands_legacy.property_collection AS
SELECT property_collection_id,property_collection_name,property_collection_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.property_collection;

SELECT schema_support.save_grants_for_replay('jazzhands', 'property_collection');
CREATE OR REPLACE VIEW jazzhands_legacy.property_collection_hier AS
SELECT property_collection_id,child_property_collection_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.property_collection_hier;

SELECT schema_support.save_grants_for_replay('jazzhands', 'property_collection_hier');
CREATE OR REPLACE VIEW jazzhands_legacy.property_collection_property AS
SELECT property_collection_id,property_name,property_type,property_id_rank,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.property_collection_property;

SELECT schema_support.save_grants_for_replay('jazzhands', 'property_collection_property');
CREATE OR REPLACE VIEW jazzhands_legacy.pseudo_klogin AS
SELECT pseudo_klogin_id,principal,dest_account_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.pseudo_klogin;

SELECT schema_support.save_grants_for_replay('jazzhands', 'pseudo_klogin');
CREATE OR REPLACE VIEW jazzhands_legacy.rack AS
SELECT rack_id,site_code,room,sub_room,rack_row,rack_name,rack_style,rack_type,description,rack_height_in_u,display_from_bottom,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.rack;

SELECT schema_support.save_grants_for_replay('jazzhands', 'rack');
CREATE OR REPLACE VIEW jazzhands_legacy.rack_location AS
SELECT rack_location_id,rack_id,rack_u_offset_of_device_top,rack_side,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.rack_location;

ALTER TABLE jazzhands_legacy.rack_location
	ALTER rack_side SET DEFAULT 'FRONT'::character varying;

SELECT schema_support.save_grants_for_replay('jazzhands', 'rack_location');
CREATE OR REPLACE VIEW jazzhands_legacy.service_environment AS
SELECT service_environment_id,service_environment_name,production_state,description,external_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.service_environment;

SELECT schema_support.save_grants_for_replay('jazzhands', 'service_environment');
CREATE OR REPLACE VIEW jazzhands_legacy.service_environment_coll_hier AS
SELECT service_env_collection_id,child_service_env_coll_id,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.service_environment_coll_hier;

SELECT schema_support.save_grants_for_replay('jazzhands', 'service_environment_coll_hier');
CREATE OR REPLACE VIEW jazzhands_legacy.service_environment_collection AS
SELECT service_env_collection_id,service_env_collection_name,service_env_collection_type,description,external_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.service_environment_collection;

SELECT schema_support.save_grants_for_replay('jazzhands', 'service_environment_collection');
CREATE OR REPLACE VIEW jazzhands_legacy.shared_netblock AS
SELECT shared_netblock_id,shared_netblock_protocol,netblock_id,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.shared_netblock;

SELECT schema_support.save_grants_for_replay('jazzhands', 'shared_netblock');
CREATE OR REPLACE VIEW jazzhands_legacy.shared_netblock_network_int AS
SELECT shared_netblock_id,network_interface_id,priority,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.shared_netblock_network_int;

SELECT schema_support.save_grants_for_replay('jazzhands', 'shared_netblock_network_int');
CREATE OR REPLACE VIEW jazzhands_legacy.site AS
SELECT site_code,colo_company_id,physical_address_id,site_status,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.site;

SELECT schema_support.save_grants_for_replay('jazzhands', 'site');
CREATE OR REPLACE VIEW jazzhands_legacy.slot AS
SELECT slot_id,component_id,slot_name,slot_index,slot_type_id,component_type_slot_tmplt_id,is_enabled,physical_label,mac_address,description,slot_x_offset,slot_y_offset,slot_z_offset,slot_side,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.slot;

ALTER TABLE jazzhands_legacy.slot
	ALTER is_enabled SET DEFAULT 'Y'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'slot');
CREATE OR REPLACE VIEW jazzhands_legacy.slot_type AS
SELECT slot_type_id,slot_type,slot_function,slot_physical_interface_type,description,remote_slot_permitted,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.slot_type;

ALTER TABLE jazzhands_legacy.slot_type
	ALTER remote_slot_permitted SET DEFAULT 'N'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'slot_type');
CREATE OR REPLACE VIEW jazzhands_legacy.slot_type_prmt_comp_slot_type AS
SELECT slot_type_id,component_slot_type_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.slot_type_prmt_comp_slot_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'slot_type_prmt_comp_slot_type');
CREATE OR REPLACE VIEW jazzhands_legacy.slot_type_prmt_rem_slot_type AS
SELECT slot_type_id,remote_slot_type_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.slot_type_prmt_rem_slot_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'slot_type_prmt_rem_slot_type');
CREATE OR REPLACE VIEW jazzhands_legacy.snmp_commstr AS
SELECT snmp_commstr_id,device_id,snmp_commstr_type,rd_string,wr_string,purpose,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.snmp_commstr;

SELECT schema_support.save_grants_for_replay('jazzhands', 'snmp_commstr');
CREATE OR REPLACE VIEW jazzhands_legacy.ssh_key AS
SELECT ssh_key_id,ssh_key_type,ssh_public_key,ssh_private_key,encryption_key_id,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.ssh_key;

SELECT schema_support.save_grants_for_replay('jazzhands', 'ssh_key');
CREATE OR REPLACE VIEW jazzhands_legacy.static_route AS
SELECT static_route_id,device_src_id,network_interface_dst_id,netblock_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.static_route;

SELECT schema_support.save_grants_for_replay('jazzhands', 'static_route');
CREATE OR REPLACE VIEW jazzhands_legacy.static_route_template AS
SELECT static_route_template_id,netblock_src_id,network_interface_dst_id,netblock_id,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.static_route_template;

SELECT schema_support.save_grants_for_replay('jazzhands', 'static_route_template');
CREATE OR REPLACE VIEW jazzhands_legacy.sudo_acct_col_device_collectio AS
SELECT sudo_alias_name,device_collection_id,account_collection_id,run_as_account_collection_id,requires_password,can_exec_child,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.sudo_acct_col_device_collectio;

SELECT schema_support.save_grants_for_replay('jazzhands', 'sudo_acct_col_device_collectio');
CREATE OR REPLACE VIEW jazzhands_legacy.sudo_alias AS
SELECT sudo_alias_name,sudo_alias_value,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.sudo_alias;

SELECT schema_support.save_grants_for_replay('jazzhands', 'sudo_alias');
CREATE OR REPLACE VIEW jazzhands_legacy.svc_environment_coll_svc_env AS
SELECT service_env_collection_id,service_environment_id,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.svc_environment_coll_svc_env;

SELECT schema_support.save_grants_for_replay('jazzhands', 'svc_environment_coll_svc_env');
CREATE OR REPLACE VIEW jazzhands_legacy.sw_package AS
SELECT sw_package_id,sw_package_name,sw_package_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.sw_package;

SELECT schema_support.save_grants_for_replay('jazzhands', 'sw_package');
CREATE OR REPLACE VIEW jazzhands_legacy.ticketing_system AS
SELECT ticketing_system_id,ticketing_system_name,ticketing_system_url,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.ticketing_system;

SELECT schema_support.save_grants_for_replay('jazzhands', 'ticketing_system');
CREATE OR REPLACE VIEW jazzhands_legacy.token AS
SELECT token_id,token_type,token_status,description,external_id,token_serial,zero_time,time_modulo,time_skew,token_key,encryption_key_id,token_password,expire_time,is_token_locked,token_unlock_time,bad_logins,last_updated,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.token;

ALTER TABLE jazzhands_legacy.token
	ALTER is_token_locked SET DEFAULT 'N'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'token');
CREATE OR REPLACE VIEW jazzhands_legacy.token_collection AS
SELECT token_collection_id,token_collection_name,token_collection_type,description,external_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.token_collection;

SELECT schema_support.save_grants_for_replay('jazzhands', 'token_collection');
CREATE OR REPLACE VIEW jazzhands_legacy.token_collection_hier AS
SELECT token_collection_id,child_token_collection_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.token_collection_hier;

SELECT schema_support.save_grants_for_replay('jazzhands', 'token_collection_hier');
CREATE OR REPLACE VIEW jazzhands_legacy.token_collection_token AS
SELECT token_collection_id,token_id,token_id_rank,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.token_collection_token;

SELECT schema_support.save_grants_for_replay('jazzhands', 'token_collection_token');
CREATE OR REPLACE VIEW jazzhands_legacy.token_sequence AS
SELECT token_id,token_sequence,last_updated
FROM jazzhands.token_sequence;

SELECT schema_support.save_grants_for_replay('jazzhands', 'token_sequence');
CREATE OR REPLACE VIEW jazzhands_legacy.unix_group AS
SELECT account_collection_id,unix_gid,group_password,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.unix_group;

SELECT schema_support.save_grants_for_replay('jazzhands', 'unix_group');
CREATE OR REPLACE VIEW jazzhands_legacy.val_account_collection_relatio AS
SELECT account_collection_relation,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_account_collection_relatio;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_account_collection_relatio');
CREATE OR REPLACE VIEW jazzhands_legacy.val_account_collection_type AS
SELECT account_collection_type,description,is_infrastructure_type,max_num_members,max_num_collections,can_have_hierarchy,account_realm_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_account_collection_type;

ALTER TABLE jazzhands_legacy.val_account_collection_type
	ALTER is_infrastructure_type SET DEFAULT 'N'::bpchar;

ALTER TABLE jazzhands_legacy.val_account_collection_type
	ALTER can_have_hierarchy SET DEFAULT 'Y'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_account_collection_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_account_role AS
SELECT account_role,uid_gid_forced,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_account_role;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_account_role');
CREATE OR REPLACE VIEW jazzhands_legacy.val_account_type AS
SELECT account_type,is_person,uid_gid_forced,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_account_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_account_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_app_key AS
SELECT appaal_group_name,app_key,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_app_key;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_app_key');
CREATE OR REPLACE VIEW jazzhands_legacy.val_app_key_values AS
SELECT appaal_group_name,app_key,app_value,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_app_key_values;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_app_key_values');
CREATE OR REPLACE VIEW jazzhands_legacy.val_appaal_group_name AS
SELECT appaal_group_name,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_appaal_group_name;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_appaal_group_name');
CREATE OR REPLACE VIEW jazzhands_legacy.val_approval_chain_resp_prd AS
SELECT approval_chain_response_period,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_approval_chain_resp_prd;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_approval_chain_resp_prd');
CREATE OR REPLACE VIEW jazzhands_legacy.val_approval_expiration_action AS
SELECT approval_expiration_action,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_approval_expiration_action;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_approval_expiration_action');
CREATE OR REPLACE VIEW jazzhands_legacy.val_approval_notifty_type AS
SELECT approval_notify_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_approval_notifty_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_approval_notifty_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_approval_process_type AS
SELECT approval_process_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_approval_process_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_approval_process_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_approval_type AS
SELECT approval_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_approval_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_approval_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_attestation_frequency AS
SELECT attestation_frequency,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_attestation_frequency;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_attestation_frequency');
CREATE OR REPLACE VIEW jazzhands_legacy.val_auth_question AS
SELECT auth_question_id,question_text,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_auth_question;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_auth_question');
CREATE OR REPLACE VIEW jazzhands_legacy.val_auth_resource AS
SELECT auth_resource,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_auth_resource;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_auth_resource');
CREATE OR REPLACE VIEW jazzhands_legacy.val_badge_status AS
SELECT badge_status,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_badge_status;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_badge_status');
CREATE OR REPLACE VIEW jazzhands_legacy.val_cable_type AS
SELECT cable_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_cable_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_cable_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_company_collection_type AS
SELECT company_collection_type,description,is_infrastructure_type,max_num_members,max_num_collections,can_have_hierarchy,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_company_collection_type;

ALTER TABLE jazzhands_legacy.val_company_collection_type
	ALTER is_infrastructure_type SET DEFAULT 'N'::bpchar;

ALTER TABLE jazzhands_legacy.val_company_collection_type
	ALTER can_have_hierarchy SET DEFAULT 'Y'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_company_collection_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_company_type AS
SELECT company_type,description,company_type_purpose,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_company_type;

ALTER TABLE jazzhands_legacy.val_company_type
	ALTER company_type_purpose SET DEFAULT 'default'::character varying;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_company_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_company_type_purpose AS
SELECT company_type_purpose,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_company_type_purpose;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_company_type_purpose');
CREATE OR REPLACE VIEW jazzhands_legacy.val_component_function AS
SELECT component_function,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_component_function;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_component_function');
CREATE OR REPLACE VIEW jazzhands_legacy.val_component_property AS
SELECT component_property_name,component_property_type,description,is_multivalue,property_data_type,permit_component_type_id,required_component_type_id,permit_component_function,required_component_function,permit_component_id,permit_intcomp_conn_id,permit_slot_type_id,required_slot_type_id,permit_slot_function,required_slot_function,permit_slot_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_component_property;

ALTER TABLE jazzhands_legacy.val_component_property
	ALTER permit_component_type_id SET DEFAULT 'PROHIBITED'::bpchar;

ALTER TABLE jazzhands_legacy.val_component_property
	ALTER permit_component_function SET DEFAULT 'PROHIBITED'::bpchar;

ALTER TABLE jazzhands_legacy.val_component_property
	ALTER permit_component_id SET DEFAULT 'PROHIBITED'::bpchar;

ALTER TABLE jazzhands_legacy.val_component_property
	ALTER permit_intcomp_conn_id SET DEFAULT 'PROHIBITED'::bpchar;

ALTER TABLE jazzhands_legacy.val_component_property
	ALTER permit_slot_type_id SET DEFAULT 'PROHIBITED'::bpchar;

ALTER TABLE jazzhands_legacy.val_component_property
	ALTER permit_slot_function SET DEFAULT 'PROHIBITED'::bpchar;

ALTER TABLE jazzhands_legacy.val_component_property
	ALTER permit_slot_id SET DEFAULT 'PROHIBITED'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_component_property');
CREATE OR REPLACE VIEW jazzhands_legacy.val_component_property_type AS
SELECT component_property_type,description,is_multivalue,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_component_property_type;

ALTER TABLE jazzhands_legacy.val_component_property_type
	ALTER is_multivalue SET DEFAULT 'N'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_component_property_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_component_property_value AS
SELECT component_property_name,component_property_type,valid_property_value,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_component_property_value;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_component_property_value');
CREATE OR REPLACE VIEW jazzhands_legacy.val_contract_type AS
SELECT contract_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_contract_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_contract_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_country_code AS
SELECT iso_country_code,dial_country_code,primary_iso_currency_code,country_name,display_priority,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_country_code;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_country_code');
CREATE OR REPLACE VIEW jazzhands_legacy.val_device_auto_mgmt_protocol AS
SELECT auto_mgmt_protocol,connection_port,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_device_auto_mgmt_protocol;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_device_auto_mgmt_protocol');
CREATE OR REPLACE VIEW jazzhands_legacy.val_device_collection_type AS
SELECT device_collection_type,description,max_num_members,max_num_collections,can_have_hierarchy,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_device_collection_type;

ALTER TABLE jazzhands_legacy.val_device_collection_type
	ALTER can_have_hierarchy SET DEFAULT 'Y'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_device_collection_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_device_mgmt_ctrl_type AS
SELECT device_mgmt_control_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_device_mgmt_ctrl_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_device_mgmt_ctrl_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_device_status AS
SELECT device_status,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_device_status;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_device_status');
CREATE OR REPLACE VIEW jazzhands_legacy.val_diet AS
SELECT diet,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_diet;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_diet');
CREATE OR REPLACE VIEW jazzhands_legacy.val_dns_class AS
SELECT dns_class,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_dns_class;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_dns_class');
CREATE OR REPLACE VIEW jazzhands_legacy.val_dns_domain_collection_type AS
SELECT dns_domain_collection_type,description,max_num_members,max_num_collections,can_have_hierarchy,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_dns_domain_collection_type;

ALTER TABLE jazzhands_legacy.val_dns_domain_collection_type
	ALTER can_have_hierarchy SET DEFAULT 'Y'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_dns_domain_collection_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_dns_domain_type AS
SELECT dns_domain_type,can_generate,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_dns_domain_type;

ALTER TABLE jazzhands_legacy.val_dns_domain_type
	ALTER can_generate SET DEFAULT 'Y'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_dns_domain_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_dns_record_relation_type AS
SELECT dns_record_relation_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_dns_record_relation_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_dns_record_relation_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_dns_srv_service AS
SELECT dns_srv_service,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_dns_srv_service;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_dns_srv_service');
CREATE OR REPLACE VIEW jazzhands_legacy.val_dns_type AS
SELECT dns_type,description,id_type,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_dns_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_dns_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_encapsulation_mode AS
SELECT encapsulation_mode,encapsulation_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_encapsulation_mode;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_encapsulation_mode');
CREATE OR REPLACE VIEW jazzhands_legacy.val_encapsulation_type AS
SELECT encapsulation_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_encapsulation_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_encapsulation_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_encryption_key_purpose AS
SELECT encryption_key_purpose,encryption_key_purpose_version,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_encryption_key_purpose;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_encryption_key_purpose');
CREATE OR REPLACE VIEW jazzhands_legacy.val_encryption_method AS
SELECT encryption_method,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_encryption_method;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_encryption_method');
CREATE OR REPLACE VIEW jazzhands_legacy.val_filesystem_type AS
SELECT filesystem_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_filesystem_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_filesystem_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_image_type AS
SELECT image_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_image_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_image_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_ip_namespace AS
SELECT ip_namespace,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_ip_namespace;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_ip_namespace');
CREATE OR REPLACE VIEW jazzhands_legacy.val_iso_currency_code AS
SELECT iso_currency_code,description,currency_symbol,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_iso_currency_code;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_iso_currency_code');
CREATE OR REPLACE VIEW jazzhands_legacy.val_key_usg_reason_for_assgn AS
SELECT key_usage_reason_for_assign,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_key_usg_reason_for_assgn;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_key_usg_reason_for_assgn');
CREATE OR REPLACE VIEW jazzhands_legacy.val_layer2_network_coll_type AS
SELECT layer2_network_collection_type,description,max_num_members,max_num_collections,can_have_hierarchy,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_layer2_network_coll_type;

ALTER TABLE jazzhands_legacy.val_layer2_network_coll_type
	ALTER can_have_hierarchy SET DEFAULT 'Y'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_layer2_network_coll_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_layer3_network_coll_type AS
SELECT layer3_network_collection_type,description,max_num_members,max_num_collections,can_have_hierarchy,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_layer3_network_coll_type;

ALTER TABLE jazzhands_legacy.val_layer3_network_coll_type
	ALTER can_have_hierarchy SET DEFAULT 'Y'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_layer3_network_coll_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_logical_port_type AS
SELECT logical_port_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_logical_port_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_logical_port_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_logical_volume_property AS
SELECT logical_volume_property_name,filesystem_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_logical_volume_property;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_logical_volume_property');
CREATE OR REPLACE VIEW jazzhands_legacy.val_logical_volume_purpose AS
SELECT logical_volume_purpose,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_logical_volume_purpose;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_logical_volume_purpose');
CREATE OR REPLACE VIEW jazzhands_legacy.val_logical_volume_type AS
SELECT logical_volume_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_logical_volume_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_logical_volume_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_netblock_collection_type AS
SELECT netblock_collection_type,description,max_num_members,max_num_collections,can_have_hierarchy,netblock_single_addr_restrict,netblock_ip_family_restrict,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_netblock_collection_type;

ALTER TABLE jazzhands_legacy.val_netblock_collection_type
	ALTER can_have_hierarchy SET DEFAULT 'Y'::bpchar;

ALTER TABLE jazzhands_legacy.val_netblock_collection_type
	ALTER netblock_single_addr_restrict SET DEFAULT 'ANY'::character varying;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_netblock_collection_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_netblock_status AS
SELECT netblock_status,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_netblock_status;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_netblock_status');
CREATE OR REPLACE VIEW jazzhands_legacy.val_netblock_type AS
SELECT netblock_type,description,db_forced_hierarchy,is_validated_hierarchy,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_netblock_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_netblock_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_network_interface_purpose AS
SELECT network_interface_purpose,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_network_interface_purpose;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_network_interface_purpose');
CREATE OR REPLACE VIEW jazzhands_legacy.val_network_interface_type AS
SELECT network_interface_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_network_interface_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_network_interface_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_network_range_type AS
SELECT network_range_type,description,dns_domain_required,default_dns_prefix,netblock_type,can_overlap,require_cidr_boundary,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_network_range_type;

ALTER TABLE jazzhands_legacy.val_network_range_type
	ALTER dns_domain_required SET DEFAULT 'REQUIRED'::bpchar;

ALTER TABLE jazzhands_legacy.val_network_range_type
	ALTER can_overlap SET DEFAULT 'N'::bpchar;

ALTER TABLE jazzhands_legacy.val_network_range_type
	ALTER require_cidr_boundary SET DEFAULT 'N'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_network_range_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_network_service_type AS
SELECT network_service_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_network_service_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_network_service_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_operating_system_family AS
SELECT operating_system_family,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_operating_system_family;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_operating_system_family');
CREATE OR REPLACE VIEW jazzhands_legacy.val_os_snapshot_type AS
SELECT operating_system_snapshot_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_os_snapshot_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_os_snapshot_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_ownership_status AS
SELECT ownership_status,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_ownership_status;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_ownership_status');
CREATE OR REPLACE VIEW jazzhands_legacy.val_package_relation_type AS
SELECT package_relation_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_package_relation_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_package_relation_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_password_type AS
SELECT password_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_password_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_password_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_person_company_attr_dtype AS
SELECT person_company_attr_data_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_person_company_attr_dtype;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_person_company_attr_dtype');
CREATE OR REPLACE VIEW jazzhands_legacy.val_person_company_attr_name AS
SELECT person_company_attr_name,person_company_attr_data_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_person_company_attr_name;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_person_company_attr_name');
CREATE OR REPLACE VIEW jazzhands_legacy.val_person_company_attr_value AS
SELECT person_company_attr_name,person_company_attr_value,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_person_company_attr_value;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_person_company_attr_value');
CREATE OR REPLACE VIEW jazzhands_legacy.val_person_company_relation AS
SELECT person_company_relation,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_person_company_relation;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_person_company_relation');
CREATE OR REPLACE VIEW jazzhands_legacy.val_person_contact_loc_type AS
SELECT person_contact_location_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_person_contact_loc_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_person_contact_loc_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_person_contact_technology AS
SELECT person_contact_technology,person_contact_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_person_contact_technology;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_person_contact_technology');
CREATE OR REPLACE VIEW jazzhands_legacy.val_person_contact_type AS
SELECT person_contact_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_person_contact_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_person_contact_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_person_image_usage AS
SELECT person_image_usage,is_multivalue,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_person_image_usage;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_person_image_usage');
CREATE OR REPLACE VIEW jazzhands_legacy.val_person_location_type AS
SELECT person_location_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_person_location_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_person_location_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_person_status AS
SELECT person_status,description,is_enabled,propagate_from_person,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_person_status;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_person_status');
CREATE OR REPLACE VIEW jazzhands_legacy.val_physical_address_type AS
SELECT physical_address_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_physical_address_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_physical_address_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_physicalish_volume_type AS
SELECT physicalish_volume_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_physicalish_volume_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_physicalish_volume_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_processor_architecture AS
SELECT processor_architecture,kernel_bits,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_processor_architecture;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_processor_architecture');
CREATE OR REPLACE VIEW jazzhands_legacy.val_production_state AS
SELECT production_state,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_production_state;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_production_state');
CREATE OR REPLACE VIEW jazzhands_legacy.val_property AS
SELECT property_name,property_type,description,account_collection_type,company_collection_type,device_collection_type,dns_domain_collection_type,layer2_network_collection_type,layer3_network_collection_type,netblock_collection_type,network_range_type,property_collection_type,service_env_collection_type,is_multivalue,prop_val_acct_coll_type_rstrct,prop_val_dev_coll_type_rstrct,prop_val_nblk_coll_type_rstrct,property_data_type,property_value_json_schema,permit_account_collection_id,permit_account_id,permit_account_realm_id,permit_company_id,permit_company_collection_id,permit_device_collection_id,permit_dns_domain_coll_id,permit_layer2_network_coll_id,permit_layer3_network_coll_id,permit_netblock_collection_id,permit_network_range_id,permit_operating_system_id,permit_os_snapshot_id,permit_person_id,permit_property_collection_id,permit_service_env_collection,permit_site_code,permit_x509_signed_cert_id,permit_property_rank,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_property;

ALTER TABLE jazzhands_legacy.val_property
	ALTER is_multivalue SET DEFAULT 'N'::bpchar;

ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_account_collection_id SET DEFAULT 'PROHIBITED'::bpchar;

ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_account_id SET DEFAULT 'PROHIBITED'::bpchar;

ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_account_realm_id SET DEFAULT 'PROHIBITED'::bpchar;

ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_company_id SET DEFAULT 'PROHIBITED'::bpchar;

ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_company_collection_id SET DEFAULT 'PROHIBITED'::bpchar;

ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_device_collection_id SET DEFAULT 'PROHIBITED'::bpchar;

ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_dns_domain_coll_id SET DEFAULT 'PROHIBITED'::bpchar;

ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_layer2_network_coll_id SET DEFAULT 'PROHIBITED'::bpchar;

ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_layer3_network_coll_id SET DEFAULT 'PROHIBITED'::bpchar;

ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_netblock_collection_id SET DEFAULT 'PROHIBITED'::bpchar;

ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_network_range_id SET DEFAULT 'PROHIBITED'::bpchar;

ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_operating_system_id SET DEFAULT 'PROHIBITED'::bpchar;

ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_os_snapshot_id SET DEFAULT 'PROHIBITED'::bpchar;

ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_person_id SET DEFAULT 'PROHIBITED'::bpchar;

ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_property_collection_id SET DEFAULT 'PROHIBITED'::bpchar;

ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_service_env_collection SET DEFAULT 'PROHIBITED'::bpchar;

ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_site_code SET DEFAULT 'PROHIBITED'::bpchar;

ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_x509_signed_cert_id SET DEFAULT 'PROHIBITED'::bpchar;

ALTER TABLE jazzhands_legacy.val_property
	ALTER permit_property_rank SET DEFAULT 'PROHIBITED'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_property');
CREATE OR REPLACE VIEW jazzhands_legacy.val_property_collection_type AS
SELECT property_collection_type,description,max_num_members,max_num_collections,can_have_hierarchy,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_property_collection_type;

ALTER TABLE jazzhands_legacy.val_property_collection_type
	ALTER can_have_hierarchy SET DEFAULT 'Y'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_property_collection_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_property_data_type AS
SELECT property_data_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_property_data_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_property_data_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_property_type AS
SELECT property_type,description,prop_val_acct_coll_type_rstrct,is_multivalue,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_property_type;

ALTER TABLE jazzhands_legacy.val_property_type
	ALTER is_multivalue SET DEFAULT 'Y'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_property_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_property_value AS
SELECT property_name,property_type,valid_property_value,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_property_value;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_property_value');
CREATE OR REPLACE VIEW jazzhands_legacy.val_pvt_key_encryption_type AS
SELECT private_key_encryption_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_pvt_key_encryption_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_pvt_key_encryption_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_rack_type AS
SELECT rack_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_rack_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_rack_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_raid_type AS
SELECT raid_type,description,primary_raid_level,secondary_raid_level,raid_level_qualifier,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_raid_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_raid_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_service_env_coll_type AS
SELECT service_env_collection_type,description,max_num_members,max_num_collections,can_have_hierarchy,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_service_env_coll_type;

ALTER TABLE jazzhands_legacy.val_service_env_coll_type
	ALTER can_have_hierarchy SET DEFAULT 'Y'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_service_env_coll_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_shared_netblock_protocol AS
SELECT shared_netblock_protocol,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_shared_netblock_protocol;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_shared_netblock_protocol');
CREATE OR REPLACE VIEW jazzhands_legacy.val_slot_function AS
SELECT slot_function,description,can_have_mac_address,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_slot_function;

ALTER TABLE jazzhands_legacy.val_slot_function
	ALTER can_have_mac_address SET DEFAULT 'N'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_slot_function');
CREATE OR REPLACE VIEW jazzhands_legacy.val_slot_physical_interface AS
SELECT slot_physical_interface_type,slot_function,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_slot_physical_interface;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_slot_physical_interface');
CREATE OR REPLACE VIEW jazzhands_legacy.val_snmp_commstr_type AS
SELECT snmp_commstr_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_snmp_commstr_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_snmp_commstr_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_ssh_key_type AS
SELECT ssh_key_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_ssh_key_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_ssh_key_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_sw_package_type AS
SELECT sw_package_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_sw_package_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_sw_package_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_token_collection_type AS
SELECT token_collection_type,description,max_num_members,max_num_collections,can_have_hierarchy,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_token_collection_type;

ALTER TABLE jazzhands_legacy.val_token_collection_type
	ALTER can_have_hierarchy SET DEFAULT 'Y'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_token_collection_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_token_status AS
SELECT token_status,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_token_status;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_token_status');
CREATE OR REPLACE VIEW jazzhands_legacy.val_token_type AS
SELECT token_type,description,token_digit_count,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_token_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_token_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_volume_group_purpose AS
SELECT volume_group_purpose,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_volume_group_purpose;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_volume_group_purpose');
CREATE OR REPLACE VIEW jazzhands_legacy.val_volume_group_relation AS
SELECT volume_group_relation,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_volume_group_relation;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_volume_group_relation');
CREATE OR REPLACE VIEW jazzhands_legacy.val_volume_group_type AS
SELECT volume_group_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_volume_group_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_volume_group_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_x509_certificate_file_fmt AS
SELECT x509_file_format,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_x509_certificate_file_fmt;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_x509_certificate_file_fmt');
CREATE OR REPLACE VIEW jazzhands_legacy.val_x509_certificate_type AS
SELECT x509_certificate_type,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_x509_certificate_type;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_x509_certificate_type');
CREATE OR REPLACE VIEW jazzhands_legacy.val_x509_key_usage AS
SELECT x509_key_usg,description,is_extended,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_x509_key_usage;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_x509_key_usage');
CREATE OR REPLACE VIEW jazzhands_legacy.val_x509_key_usage_category AS
SELECT x509_key_usg_cat,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_x509_key_usage_category;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_x509_key_usage_category');
CREATE OR REPLACE VIEW jazzhands_legacy.val_x509_revocation_reason AS
SELECT x509_revocation_reason,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.val_x509_revocation_reason;

SELECT schema_support.save_grants_for_replay('jazzhands', 'val_x509_revocation_reason');
CREATE OR REPLACE VIEW jazzhands_legacy.volume_group AS
SELECT volume_group_id,device_id,component_id,volume_group_name,volume_group_type,volume_group_size_in_bytes,raid_type,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.volume_group;

SELECT schema_support.save_grants_for_replay('jazzhands', 'volume_group');
CREATE OR REPLACE VIEW jazzhands_legacy.volume_group_physicalish_vol AS
SELECT physicalish_volume_id,volume_group_id,device_id,volume_group_primary_pos,volume_group_secondary_pos,volume_group_relation,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.volume_group_physicalish_vol;

SELECT schema_support.save_grants_for_replay('jazzhands', 'volume_group_physicalish_vol');
CREATE OR REPLACE VIEW jazzhands_legacy.volume_group_purpose AS
SELECT volume_group_id,volume_group_purpose,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.volume_group_purpose;

SELECT schema_support.save_grants_for_replay('jazzhands', 'volume_group_purpose');
CREATE OR REPLACE VIEW jazzhands_legacy.x509_key_usage_attribute AS
SELECT x509_cert_id,x509_key_usg,x509_key_usg_cat,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.x509_key_usage_attribute;

SELECT schema_support.save_grants_for_replay('jazzhands', 'x509_key_usage_attribute');
CREATE OR REPLACE VIEW jazzhands_legacy.x509_key_usage_categorization AS
SELECT x509_key_usg_cat,x509_key_usg,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.x509_key_usage_categorization;

SELECT schema_support.save_grants_for_replay('jazzhands', 'x509_key_usage_categorization');
CREATE OR REPLACE VIEW jazzhands_legacy.x509_key_usage_default AS
SELECT x509_signed_certificate_id,x509_key_usg,description,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.x509_key_usage_default;

SELECT schema_support.save_grants_for_replay('jazzhands', 'x509_key_usage_default');
CREATE OR REPLACE VIEW jazzhands_legacy.x509_signed_certificate AS
SELECT x509_signed_certificate_id,x509_certificate_type,subject,friendly_name,subject_key_identifier,is_active,is_certificate_authority,signing_cert_id,x509_ca_cert_serial_number,public_key,private_key_id,certificate_signing_request_id,valid_from,valid_to,x509_revocation_date,x509_revocation_reason,ocsp_uri,crl_uri,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.x509_signed_certificate;

ALTER TABLE jazzhands_legacy.x509_signed_certificate
	ALTER x509_certificate_type SET DEFAULT 'default'::character varying;

ALTER TABLE jazzhands_legacy.x509_signed_certificate
	ALTER is_active SET DEFAULT 'Y'::bpchar;

ALTER TABLE jazzhands_legacy.x509_signed_certificate
	ALTER is_certificate_authority SET DEFAULT 'N'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'x509_signed_certificate');
CREATE OR REPLACE VIEW jazzhands_legacy.layer1_connection AS
SELECT layer1_connection_id,physical_port1_id,physical_port2_id,circuit_id,baud,data_bits,stop_bits,parity,flow_control,tcpsrv_device_id,is_tcpsrv_enabled,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.layer1_connection;

SELECT schema_support.save_grants_for_replay('jazzhands', 'layer1_connection');
CREATE OR REPLACE VIEW jazzhands_legacy.site_netblock AS
SELECT site_code,netblock_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.site_netblock;

SELECT schema_support.save_grants_for_replay('jazzhands', 'site_netblock');
CREATE OR REPLACE VIEW jazzhands_legacy.v_account_collection_account AS
SELECT account_collection_id,account_id,account_collection_relation,account_id_rank,start_date,finish_date,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.v_account_collection_account;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_account_collection_account');
CREATE OR REPLACE VIEW jazzhands_legacy.v_account_collection_expanded AS
SELECT level,root_account_collection_id,account_collection_id
FROM jazzhands.v_account_collection_expanded;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_account_collection_expanded');
CREATE OR REPLACE VIEW jazzhands_legacy.v_acct_coll_expanded AS
SELECT level,account_collection_id,root_account_collection_id,text_path,array_path,rvs_array_path
FROM jazzhands.v_acct_coll_expanded;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_acct_coll_expanded');
CREATE OR REPLACE VIEW jazzhands_legacy.v_acct_coll_expanded_detail AS
SELECT account_collection_id,root_account_collection_id,acct_coll_level,dept_level,assign_method,text_path,array_path
FROM jazzhands.v_acct_coll_expanded_detail;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_acct_coll_expanded_detail');
CREATE OR REPLACE VIEW jazzhands_legacy.v_application_role_member AS
SELECT device_id,role_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.v_application_role_member;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_application_role_member');
CREATE OR REPLACE VIEW jazzhands_legacy.v_approval_instance_step_expanded AS
SELECT first_approval_instance_item_id,root_step_id,approval_instance_item_id,approval_instance_step_id,tier,level,is_approved
FROM jazzhands.v_approval_instance_step_expanded;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_approval_instance_step_expanded');
CREATE OR REPLACE VIEW jazzhands_legacy.v_company_hier AS
SELECT root_company_id,company_id
FROM jazzhands.v_company_hier;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_company_hier');
CREATE OR REPLACE VIEW jazzhands_legacy.v_component_hier AS
SELECT component_id,child_component_id,component_path,level
FROM jazzhands.v_component_hier;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_component_hier');
CREATE OR REPLACE VIEW jazzhands_legacy.v_corp_family_account AS
SELECT account_id,login,person_id,company_id,account_realm_id,account_status,account_role,account_type,description,is_enabled,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.v_corp_family_account;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_corp_family_account');
CREATE OR REPLACE VIEW jazzhands_legacy.v_department_company_expanded AS
SELECT company_id,account_collection_id
FROM jazzhands.v_department_company_expanded;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_department_company_expanded');
CREATE OR REPLACE VIEW jazzhands_legacy.v_device_collection_hier_trans AS
SELECT parent_device_collection_id,device_collection_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.v_device_collection_hier_trans;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_collection_hier_trans');
CREATE OR REPLACE VIEW jazzhands_legacy.v_device_components AS
SELECT device_id,component_id,component_path,level
FROM jazzhands.v_device_components;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_components');
CREATE OR REPLACE VIEW jazzhands_legacy.v_device_slots AS
SELECT device_id,device_component_id,component_id,slot_id
FROM jazzhands.v_device_slots;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_slots');
CREATE OR REPLACE VIEW jazzhands_legacy.v_dns_changes_pending AS
SELECT dns_change_record_id,dns_domain_id,ip_universe_id,should_generate,last_generated,soa_name,ip_address
FROM jazzhands.v_dns_changes_pending;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dns_changes_pending');
CREATE OR REPLACE VIEW jazzhands_legacy.v_dns_domain_nouniverse AS
SELECT dns_domain_id,soa_name,soa_class,soa_ttl,soa_serial,soa_refresh,soa_retry,soa_expire,soa_minimum,soa_mname,soa_rname,parent_dns_domain_id,should_generate,last_generated,dns_domain_type,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.v_dns_domain_nouniverse;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dns_domain_nouniverse');
CREATE OR REPLACE VIEW jazzhands_legacy.v_dns_fwd AS
SELECT dns_record_id,network_range_id,dns_domain_id,dns_name,dns_ttl,dns_class,dns_type,dns_value,dns_priority,ip,netblock_id,ip_universe_id,ref_record_id,dns_srv_service,dns_srv_protocol,dns_srv_weight,dns_srv_port,is_enabled,should_generate_ptr,dns_value_record_id
FROM jazzhands.v_dns_fwd;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dns_fwd');
CREATE OR REPLACE VIEW jazzhands_legacy.v_dns_rvs AS
SELECT dns_record_id,network_range_id,dns_domain_id,dns_name,dns_ttl,dns_class,dns_type,dns_value,dns_priority,ip,netblock_id,ip_universe_id,rdns_record_id,dns_srv_service,dns_srv_protocol,dns_srv_weight,dns_srv_srv_port,is_enabled,should_generate_ptr,dns_value_record_id
FROM jazzhands.v_dns_rvs;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dns_rvs');
CREATE OR REPLACE VIEW jazzhands_legacy.v_hotpants_token AS
SELECT token_id,token_type,token_status,token_serial,token_key,zero_time,time_modulo,token_password,is_token_locked,token_unlock_time,bad_logins,token_sequence,last_updated,encryption_key_db_value,encryption_key_purpose,encryption_key_purpose_version,encryption_method
FROM jazzhands.v_hotpants_token;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_hotpants_token');
CREATE OR REPLACE VIEW jazzhands_legacy.v_l2_network_coll_expanded AS
SELECT level,layer2_network_collection_id,root_l2_network_coll_id,text_path,array_path,rvs_array_path
FROM jazzhands.v_l2_network_coll_expanded;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_l2_network_coll_expanded');
CREATE OR REPLACE VIEW jazzhands_legacy.v_l3_network_coll_expanded AS
SELECT level,layer3_network_collection_id,root_l3_network_coll_id,text_path,array_path,rvs_array_path
FROM jazzhands.v_l3_network_coll_expanded;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_l3_network_coll_expanded');
CREATE OR REPLACE VIEW jazzhands_legacy.v_layerx_network_expanded AS
SELECT layer3_network_id,layer3_network_description,netblock_id,ip_address,netblock_type,ip_universe_id,default_gateway_netblock_id,default_gateway_ip_address,default_gateway_netblock_type,default_gateway_ip_universe_id,layer2_network_id,encapsulation_name,encapsulation_domain,encapsulation_type,encapsulation_tag,layer2_network_description
FROM jazzhands.v_layerx_network_expanded;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_layerx_network_expanded');
CREATE OR REPLACE VIEW jazzhands_legacy.v_lv_hier AS
SELECT physicalish_volume_id,volume_group_id,logical_volume_id,child_pv_id,child_vg_id,child_lv_id,pv_path,vg_path,lv_path
FROM jazzhands.v_lv_hier;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_lv_hier');
CREATE OR REPLACE VIEW jazzhands_legacy.v_nblk_coll_netblock_expanded AS
SELECT netblock_collection_id,netblock_id
FROM jazzhands.v_nblk_coll_netblock_expanded;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_nblk_coll_netblock_expanded');
CREATE OR REPLACE VIEW jazzhands_legacy.v_netblock_coll_expanded AS
SELECT level,netblock_collection_id,root_netblock_collection_id,text_path,array_path,rvs_array_path
FROM jazzhands.v_netblock_coll_expanded;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_netblock_coll_expanded');
CREATE OR REPLACE VIEW jazzhands_legacy.v_network_interface_trans AS
SELECT network_interface_id,device_id,network_interface_name,description,parent_network_interface_id,parent_relation_type,netblock_id,physical_port_id,slot_id,logical_port_id,network_interface_type,is_interface_up,mac_addr,should_monitor,should_manage,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.v_network_interface_trans;

ALTER TABLE jazzhands_legacy.v_network_interface_trans
	ALTER is_interface_up SET DEFAULT 'Y'::text;

ALTER TABLE jazzhands_legacy.v_network_interface_trans
	ALTER should_manage SET DEFAULT 'Y'::text;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_network_interface_trans');
CREATE OR REPLACE VIEW jazzhands_legacy.v_network_range_expanded AS
SELECT network_range_id,network_range_type,description,parent_netblock_id,ip_address,netblock_type,ip_universe_id,start_netblock_id,start_ip_address,start_netblock_type,start_ip_universe_id,stop_netblock_id,stop_ip_address,stop_netblock_type,stop_ip_universe_id,dns_prefix,dns_domain_id,soa_name
FROM jazzhands.v_network_range_expanded;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_network_range_expanded');
CREATE OR REPLACE VIEW jazzhands_legacy.v_person AS
SELECT person_id,description,first_name,middle_name,last_name,name_suffix,gender,preferred_first_name,preferred_last_name,legal_first_name,legal_last_name,nickname,birth_date,diet,shirt_size,pant_size,hat_size,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.v_person;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_person');
CREATE OR REPLACE VIEW jazzhands_legacy.v_person_company AS
SELECT company_id,person_id,person_company_status,person_company_relation,is_exempt,is_management,is_full_time,description,employee_id,payroll_id,external_hr_id,position_title,badge_system_id,hire_date,termination_date,manager_person_id,supervisor_person_id,nickname,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.v_person_company;

ALTER TABLE jazzhands_legacy.v_person_company
	ALTER is_exempt SET DEFAULT 'Y'::text;

ALTER TABLE jazzhands_legacy.v_person_company
	ALTER is_management SET DEFAULT 'N'::text;

ALTER TABLE jazzhands_legacy.v_person_company
	ALTER is_full_time SET DEFAULT 'Y'::text;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_person_company');
CREATE OR REPLACE VIEW jazzhands_legacy.v_person_company_expanded AS
SELECT company_id,person_id
FROM jazzhands.v_person_company_expanded;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_person_company_expanded');
CREATE OR REPLACE VIEW jazzhands_legacy.v_person_company_hier AS
SELECT level,person_id,subordinate_person_id,intermediate_person_id,person_company_relation,array_path,rvs_array_path,cycle
FROM jazzhands.v_person_company_hier;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_person_company_hier');
CREATE OR REPLACE VIEW jazzhands_legacy.v_physical_connection AS
SELECT level,inter_component_connection_id,layer1_connection_id,physical_connection_id,inter_dev_conn_slot1_id,inter_dev_conn_slot2_id,layer1_physical_port1_id,layer1_physical_port2_id,slot1_id,slot2_id,physical_port1_id,physical_port2_id
FROM jazzhands.v_physical_connection;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_physical_connection');
CREATE OR REPLACE VIEW jazzhands_legacy.v_property AS
SELECT property_id,account_collection_id,account_id,account_realm_id,company_collection_id,company_id,device_collection_id,dns_domain_collection_id,layer2_network_collection_id,layer3_network_collection_id,netblock_collection_id,network_range_id,operating_system_id,operating_system_snapshot_id,person_id,property_collection_id,service_env_collection_id,site_code,x509_signed_certificate_id,property_name,property_type,property_value,property_value_timestamp,property_value_account_coll_id,property_value_device_coll_id,property_value_json,property_value_nblk_coll_id,property_value_password_type,property_value_person_id,property_value_sw_package_id,property_value_token_col_id,property_rank,start_date,finish_date,is_enabled,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.v_property;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_property');
CREATE OR REPLACE VIEW jazzhands_legacy.v_token AS
SELECT token_id,token_type,token_status,token_serial,token_sequence,account_id,token_password,zero_time,time_modulo,time_skew,is_token_locked,token_unlock_time,bad_logins,issued_date,token_last_updated,token_sequence_last_updated,lock_status_last_updated
FROM jazzhands.v_token;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_token');
CREATE OR REPLACE VIEW jazzhands_legacy.x509_certificate AS
SELECT x509_cert_id,friendly_name,is_active,is_certificate_authority,signing_cert_id,x509_ca_cert_serial_number,public_key,private_key,certificate_sign_req,subject,subject_key_identifier,valid_from,valid_to,x509_revocation_date,x509_revocation_reason,passphrase,encryption_key_id,ocsp_uri,crl_uri,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.x509_certificate;

ALTER TABLE jazzhands_legacy.x509_certificate
	ALTER is_active SET DEFAULT 'Y'::bpchar;

ALTER TABLE jazzhands_legacy.x509_certificate
	ALTER is_certificate_authority SET DEFAULT 'N'::bpchar;

SELECT schema_support.save_grants_for_replay('jazzhands', 'x509_certificate');
CREATE OR REPLACE VIEW jazzhands_legacy.device_power_connection AS
SELECT device_power_connection_id,inter_component_connection_id,rpc_device_id,rpc_power_interface_port,power_interface_port,device_id,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_power_connection;

SELECT schema_support.save_grants_for_replay('jazzhands', 'device_power_connection');
CREATE OR REPLACE VIEW jazzhands_legacy.device_power_interface AS
SELECT device_id,power_interface_port,power_plug_style,voltage,max_amperage,provides_power,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.device_power_interface;

SELECT schema_support.save_grants_for_replay('jazzhands', 'device_power_interface');
CREATE OR REPLACE VIEW jazzhands_legacy.physical_port AS
SELECT physical_port_id,device_id,port_name,port_type,description,port_plug_style,port_medium,port_protocol,port_speed,physical_label,port_purpose,logical_port_id,tcp_port,is_hardwired,data_ins_user,data_ins_date,data_upd_user,data_upd_date
FROM jazzhands.physical_port;

SELECT schema_support.save_grants_for_replay('jazzhands', 'physical_port');
CREATE OR REPLACE VIEW jazzhands_legacy.v_account_manager_map AS
SELECT login,account_id,person_id,company_id,account_realm_id,first_name,last_name,middle_name,manager_person_id,employee_id,human_readable,manager_account_id,manager_login,manager_human_readable,manager_last_name,manager_middle_name,manger_first_name,manager_employee_id,manager_company_id
FROM jazzhands.v_account_manager_map;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_account_manager_map');
CREATE OR REPLACE VIEW jazzhands_legacy.v_acct_coll_acct_expanded_detail AS
SELECT account_collection_id,root_account_collection_id,account_id,acct_coll_level,dept_level,assign_method,text_path,array_path
FROM jazzhands.v_acct_coll_acct_expanded_detail;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_acct_coll_acct_expanded_detail');
CREATE OR REPLACE VIEW jazzhands_legacy.v_application_role AS
SELECT role_level,role_id,parent_role_id,root_role_id,root_role_name,role_name,role_path,role_is_leaf,array_path,cycle
FROM jazzhands.v_application_role;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_application_role');
CREATE OR REPLACE VIEW jazzhands_legacy.v_device_coll_device_expanded AS
SELECT device_collection_id,device_id
FROM jazzhands.v_device_coll_device_expanded;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_coll_device_expanded');
CREATE OR REPLACE VIEW jazzhands_legacy.v_device_coll_hier_detail AS
SELECT device_collection_id,parent_device_collection_id,device_collection_level
FROM jazzhands.v_device_coll_hier_detail;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_coll_hier_detail');
CREATE OR REPLACE VIEW jazzhands_legacy.v_device_component_summary AS
SELECT device_id,cpu_model,cpu_count,core_count,memory_count,total_memory,disk_count,total_disk
FROM jazzhands.v_device_component_summary;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_component_summary');
CREATE OR REPLACE VIEW jazzhands_legacy.v_device_components_expanded AS
SELECT device_id,component_id,slot_id,vendor,model,serial_number,functions,slot_name,memory_size,memory_speed,disk_size,media_type
FROM jazzhands.v_device_components_expanded;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_components_expanded');
CREATE OR REPLACE VIEW jazzhands_legacy.v_device_components_json AS
SELECT device_id,components
FROM jazzhands.v_device_components_json;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_components_json');
CREATE OR REPLACE VIEW jazzhands_legacy.v_device_slot_connections AS
SELECT inter_component_connection_id,device_id,slot_id,slot_name,slot_index,mac_address,slot_type_id,slot_type,slot_function,remote_device_id,remote_slot_id,remote_slot_name,remote_slot_index,remote_mac_address,remote_slot_type_id,remote_slot_type,remote_slot_function
FROM jazzhands.v_device_slot_connections;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_slot_connections');
CREATE OR REPLACE VIEW jazzhands_legacy.v_hotpants_dc_attribute AS
SELECT property_id,device_collection_id,property_name,property_type,property_rank,property_value
FROM jazzhands.v_hotpants_dc_attribute;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_hotpants_dc_attribute');
CREATE OR REPLACE VIEW jazzhands_legacy.v_l1_all_physical_ports AS
SELECT layer1_connection_id,physical_port_id,device_id,port_name,port_type,port_purpose,other_physical_port_id,other_device_id,other_port_name,other_port_purpose,baud,data_bits,stop_bits,parity,flow_control
FROM jazzhands.v_l1_all_physical_ports;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_l1_all_physical_ports');
CREATE OR REPLACE VIEW jazzhands_legacy.v_netblock_hier AS
SELECT netblock_level,root_netblock_id,ip,netblock_id,ip_address,netblock_status,is_single_address,description,parent_netblock_id,site_code,text_path,array_path,array_ip_path
FROM jazzhands.v_netblock_hier;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_netblock_hier');
CREATE OR REPLACE VIEW jazzhands_legacy.v_site_netblock_expanded AS
SELECT site_code,netblock_id
FROM jazzhands.v_site_netblock_expanded;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_site_netblock_expanded');
CREATE OR REPLACE VIEW jazzhands_legacy.v_account_manager_hier AS
SELECT level,account_id,person_id,company_id,login,human_readable,account_realm_id,manager_account_id,manager_login,manager_person_id,manager_company_id,manager_human_readable,array_path
FROM jazzhands.v_account_manager_hier;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_account_manager_hier');
CREATE OR REPLACE VIEW jazzhands_legacy.v_acct_coll_acct_expanded AS
SELECT account_collection_id,account_id
FROM jazzhands.v_acct_coll_acct_expanded;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_acct_coll_acct_expanded');
CREATE OR REPLACE VIEW jazzhands_legacy.v_acct_coll_prop_expanded AS
SELECT account_collection_id,property_id,property_name,property_type,property_value,property_value_timestamp,property_value_account_coll_id,property_value_nblk_coll_id,property_value_password_type,property_value_person_id,property_value_token_col_id,property_rank,is_multivalue,assign_rank
FROM jazzhands.v_acct_coll_prop_expanded;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_acct_coll_prop_expanded');
CREATE OR REPLACE VIEW jazzhands_legacy.v_dev_col_device_root AS
SELECT device_id,root_id,root_name,root_type,leaf_id,leaf_name,leaf_type
FROM jazzhands.v_dev_col_device_root;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dev_col_device_root');
CREATE OR REPLACE VIEW jazzhands_legacy.v_dev_col_root AS
SELECT root_id,root_name,root_type,leaf_id,leaf_name,leaf_type
FROM jazzhands.v_dev_col_root;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dev_col_root');
CREATE OR REPLACE VIEW jazzhands_legacy.v_dns AS
SELECT dns_record_id,network_range_id,dns_domain_id,dns_name,dns_ttl,dns_class,dns_type,dns_value,dns_priority,ip,netblock_id,ip_universe_id,ref_record_id,dns_srv_service,dns_srv_protocol,dns_srv_weight,dns_srv_port,is_enabled,should_generate_ptr,dns_value_record_id
FROM jazzhands.v_dns;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dns');
CREATE OR REPLACE VIEW jazzhands_legacy.v_hotpants_device_collection AS
SELECT device_id,device_name,device_collection_id,device_collection_name,device_collection_type,ip_address
FROM jazzhands.v_hotpants_device_collection;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_hotpants_device_collection');
CREATE OR REPLACE VIEW jazzhands_legacy.v_dns_sorted AS
SELECT dns_record_id,network_range_id,dns_value_record_id,dns_name,dns_ttl,dns_class,dns_type,dns_value,dns_priority,ip,netblock_id,ref_record_id,dns_srv_service,dns_srv_protocol,dns_srv_weight,dns_srv_port,should_generate_ptr,is_enabled,dns_domain_id,anchor_record_id,anchor_rank
FROM jazzhands.v_dns_sorted;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dns_sorted');
CREATE OR REPLACE VIEW jazzhands_legacy.v_hotpants_client AS
SELECT device_id,device_name,ip_address,radius_secret
FROM jazzhands.v_hotpants_client;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_hotpants_client');
CREATE OR REPLACE VIEW jazzhands_legacy.v_unix_mclass_settings AS
SELECT device_collection_id,mclass_setting
FROM jazzhands.v_unix_mclass_settings;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_unix_mclass_settings');
CREATE OR REPLACE VIEW jazzhands_legacy.v_device_col_acct_col_unixgroup AS
SELECT device_collection_id,account_collection_id
FROM jazzhands.v_device_col_acct_col_unixgroup;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_col_acct_col_unixgroup');
CREATE OR REPLACE VIEW jazzhands_legacy.v_dev_col_user_prop_expanded AS
SELECT property_id,device_collection_id,account_id,login,account_status,account_realm_id,account_realm_name,is_enabled,property_type,property_name,property_rank,property_value,is_multivalue,is_boolean
FROM jazzhands.v_dev_col_user_prop_expanded;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_dev_col_user_prop_expanded');
CREATE OR REPLACE VIEW jazzhands_legacy.v_device_collection_account_ssh_key AS
SELECT device_collection_id,account_id,ssh_public_key
FROM jazzhands.v_device_collection_account_ssh_key;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_collection_account_ssh_key');
CREATE OR REPLACE VIEW jazzhands_legacy.v_device_col_acct_col_expanded AS
SELECT device_collection_id,account_collection_id,account_id
FROM jazzhands.v_device_col_acct_col_expanded;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_col_acct_col_expanded');
CREATE OR REPLACE VIEW jazzhands_legacy.v_device_col_acct_col_unixlogin AS
SELECT device_collection_id,account_collection_id,account_id
FROM jazzhands.v_device_col_acct_col_unixlogin;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_col_acct_col_unixlogin');
CREATE OR REPLACE VIEW jazzhands_legacy.v_hotpants_account_attribute AS
SELECT property_id,account_id,device_collection_id,login,property_name,property_type,property_value,property_rank,is_boolean
FROM jazzhands.v_hotpants_account_attribute;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_hotpants_account_attribute');
CREATE OR REPLACE VIEW jazzhands_legacy.v_unix_group_overrides AS
SELECT device_collection_id,account_collection_id,setting
FROM jazzhands.v_unix_group_overrides;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_unix_group_overrides');
CREATE OR REPLACE VIEW jazzhands_legacy.v_unix_account_overrides AS
SELECT device_collection_id,account_id,setting
FROM jazzhands.v_unix_account_overrides;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_unix_account_overrides');
CREATE OR REPLACE VIEW jazzhands_legacy.v_device_col_account_col_cart AS
SELECT device_collection_id,account_collection_id,setting
FROM jazzhands.v_device_col_account_col_cart;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_col_account_col_cart');
CREATE OR REPLACE VIEW jazzhands_legacy.v_device_col_account_cart AS
SELECT device_collection_id,account_id,setting
FROM jazzhands.v_device_col_account_cart;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_device_col_account_cart');
CREATE OR REPLACE VIEW jazzhands_legacy.v_unix_passwd_mappings AS
SELECT device_collection_id,account_id,login,crypt,unix_uid,unix_group_name,gecos,home,shell,ssh_public_key,setting,mclass_setting,extra_groups
FROM jazzhands.v_unix_passwd_mappings;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_unix_passwd_mappings');
CREATE OR REPLACE VIEW jazzhands_legacy.v_unix_group_mappings AS
SELECT device_collection_id,account_collection_id,group_name,unix_gid,group_password,setting,mclass_setting,members
FROM jazzhands.v_unix_group_mappings;

SELECT schema_support.save_grants_for_replay('jazzhands', 'v_unix_group_mappings');
UPDATE __regrants SET regrant = regexp_replace(regrant, ' jazzhands.', ' jazzhands_legacy.');
SELECT schema_support.replay_saved_grants();
