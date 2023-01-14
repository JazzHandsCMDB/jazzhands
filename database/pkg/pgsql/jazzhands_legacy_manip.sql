/*
 * Copyright (c) 2022 Todd Kover
 * All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *	  http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * $Id$
 */

-- Create schema if it does not exist, do nothing otherwise.
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'jazzhands_legacy_manip';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS jazzhands_legacy_manip;
		CREATE SCHEMA jazzhands_legacy_manip AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA jazzhands_legacy_manip IS 'part of jazzhands';
		REVOKE ALL ON SCHEMA jazzhands_legacy_manip FROM public;
	END IF;
END;
$$;

CREATE OR REPLACE FUNCTION jazzhands_legacy_manip.relation_mapping ()
RETURNS JSONB AS $$
BEGIN
	RETURN '{
		"account_assignd_cert": "account_assigned_certificate",
		"account_auth_log": null,
		"account_coll_type_relation": "account_collection_type_relation",
		"account_realm_acct_coll_type": "account_realm_account_collection_type",
		"appaal_instance_device_coll": "appaal_instance_device_collection",
		"component_type_component_func": "component_type_component_function",
		"component_type_slot_tmplt": "component_type_slot_template",
		"device_collection_assignd_cert": "device_collection_assigned_certificate",
		"device_power_connection": null,
		"device_power_interface": null,
		"dns_domain_collection_dns_dom": "dns_domain_collection_dns_domain",
		"l2_network_coll_l2_network": "layer2_network_collection_layer2_network",
		"l3_network_coll_l3_network": "layer3_network_collection_layer3_network",
		"layer1_connection": null,
		"layer2_connection_l2_network": "layer2_connection_layer2_network",
		"network_interface": "layer3_interface",
		"network_interface_netblock": "layer3_interface_netblock",
		"network_interface_purpose": "layer3_interface_purpose",
		"person_auth_question": "person_authentication_question",
		"person_company_attr": "person_company_attribute",
		"physical_port": null,
		"property_collection": "property_name_collection",
		"property_collection_hier": "property_name_collection_hier",
		"property_collection_property": "property_name_collection_property_name",
		"service_environment_coll_hier": "service_environment_collection_hier",
		"shared_netblock_network_int": "shared_netblock_layer3_interface",
		"slot_type_prmt_comp_slot_type": "slot_type_permitted_component_slot_type",
		"slot_type_prmt_rem_slot_type": "slot_type_permitted_remote_slot_type",
		"snmp_commstr": null,
		"sudo_acct_col_device_collectio": "sudo_account_collection_device_collection",
		"svc_environment_coll_svc_env": "service_environment_collection_service_environment",
		"sw_package": null,
		"v_acct_coll_acct_expanded": null,
		"v_acct_coll_acct_expanded_detail": null,
		"v_acct_coll_expanded": null,
		"v_acct_coll_expanded_detail": null,
		"v_acct_coll_prop_expanded": null,
		"v_application_role": null,
		"v_application_role_member": null,
		"v_company_hier": null,
		"v_corp_family_account": null,
		"v_department_company_expanded": null,
		"v_dev_col_device_root": null,
		"v_dev_col_root": "v_device_collection_root",
		"v_dev_col_user_prop_expanded": null,
		"v_device_col_account_cart": null,
		"v_device_col_account_col_cart": null,
		"v_device_col_acct_col_expanded": null,
		"v_device_col_acct_col_unixgroup": null,
		"v_device_col_acct_col_unixlogin": null,
		"v_device_coll_device_expanded": null,
		"v_device_coll_hier_detail": null,
		"v_device_collection_account_ssh_key": null,
		"v_device_collection_hier_trans": null,
		"v_device_collection_root": null,
		"v_dns_changes_pending": null,
		"v_dns_domain_nouniverse": null,
		"v_dns": null,
		"v_dns_fwd": null,
		"v_dns_rvs": null,
		"v_dns_sorted": null,
		"v_hotpants_client": null,
		"v_hotpants_dc_attribute": null,
		"v_hotpants_device_collection": null,
		"v_hotpants_dc_attribute": null,
		"v_hotpants_token": null,
		"v_l1_all_physical_ports": null,
		"v_l2_network_coll_expanded": "v_layer2_network_collection_expanded",
		"v_l3_network_coll_expanded": "v_layer3_network_collection_expanded",
		"v_lv_hier": null,
		"v_nblk_coll_netblock_expanded": null,
		"v_netblock_coll_expanded": "v_netblock_collection_expanded",
		"v_network_interface_trans": null,
		"v_person_company": null,
		"v_unix_account_overrides": null,
		"v_unix_passwd_mappings": null,
		"v_token": null,
		"val_account_collection_relatio": "val_account_collection_relation",
		"val_app_key": "val_application_key",
		"val_app_key_values": "val_application_key_values",
		"val_approval_chain_resp_prd": "val_approval_chain_response_period",
		"val_auth_question": "val_authentication_question",
		"val_auth_resource": "val_authentication_resource",
		"val_device_auto_mgmt_protocol": null,
		"val_device_mgmt_ctrl_type": "val_device_management_controller_type",
		"val_key_usg_reason_for_assgn": "val_key_usage_reason_for_assignment",
		"val_layer2_network_coll_type": "val_layer2_network_collection_type",
		"val_layer3_network_coll_type": "val_layer3_network_collection_type",
		"val_network_interface_purpose": null,
		"val_network_interface_type": null,
		"val_os_snapshot_type": "val_operating_system_snapshot_type",
		"val_person_company_attr_dtype": "val_person_company_attribute_data_type",
		"val_person_company_attr_name": "val_person_company_attribute_name",
		"val_person_company_attr_value": "val_person_company_attribute_value",
		"val_person_contact_loc_type": "val_person_contact_location_type",
		"val_property_collection": "val_property_name_collection",
		"val_property_collection_type": "val_property_name_collection_type",
		"val_pvt_key_encryption_type": "val_private_key_encryption_type",
		"val_service_env_coll_type": "val_service_environment_collection_type",
		"val_snmp_commstr_type": null,
		"val_sw_package_type": null,
		"val_x509_certificate_file_fmt": "val_x509_certificate_file_format",
		"volume_group_physicalish_vol": "volume_group_physicalish_volume",
		"x509_certificate": null
	}'::jsonb;
END;
$$
SET search_path=_jazzhands_legacy_manip
LANGUAGE plpgsql SECURITY INVOKER;

CREATE OR REPLACE FUNCTION jazzhands_legacy_manip.change_legacy_grants_for_users (
        username       		 TEXT,
        direction      		 TEXT,
		name_map_exception	 BOOLEAN default true
) RETURNS text[] AS $$
DECLARE
	issuper	BOOLEAN;
	rv	TEXT[];
BEGIN
	--
	-- no need to map tables for revocation
	--
	IF direction = 'revoke' THEN
		SELECT  schema_support.migrate_grants(
			username := username,
			direction := direction,
			old_schema := 'jazzhands_legacy',
			new_schema := 'jazzhands'
		) INTO rv;
	ELSE
		SELECT  schema_support.migrate_grants(
			username := username,
			direction := direction,
			old_schema := 'jazzhands_legacy',
			new_schema := 'jazzhands',
			name_map := jazzhands_legacy_manip.relation_mapping(),
			name_map_exception := name_map_exception
		) INTO rv;
	END IF;
	RETURN rv;
END;
$$
SET search_path=schema_support
LANGUAGE plpgsql
SECURITY INVOKER;

REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA jazzhands_legacy_manip FROM public;
GRANT USAGE ON SCHEMA jazzhands_legacy_manip TO iud_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA jazzhands_legacy_manip TO iud_role;
