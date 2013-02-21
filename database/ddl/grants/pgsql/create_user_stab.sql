-- Copyright (c) 2005-2010, Vonage Holdings Corp.
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--     * Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--     * Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
-- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
-- $Id: create_user_stab.sql -1   $
--
\c jazzhands

CREATE USER ap_stab LOGIN;
CREATE ROLE stab_role;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA net_manip TO ro_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA netblock_utils TO ro_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA network_strings TO ro_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA port_utils TO stab_role;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA device_utils TO stab_role;

GRANT SELECT,UPDATE,INSERT,DELETE	ON netblock TO stab_role;
GRANT SELECT,UPDATE					ON netblock_netblock_id_seq TO stab_role;
GRANT SELECT,UPDATE,INSERT,DELETE	ON secondary_netblock TO stab_role;
GRANT SELECT,UPDATE,INSERT,DELETE	ON dns_record TO stab_role;
GRANT SELECT,UPDATE					ON dns_record_dns_domain_id_seq TO stab_role;
GRANT SELECT,UPDATE,INSERT			ON dns_domain TO stab_role;
GRANT SELECT,UPDATE					ON dns_domain_dns_domain_id_seq TO stab_role;
GRANT SELECT				ON company TO stab_role;
GRANT SELECT				ON site TO stab_role;

GRANT SELECT,UPDATE,INSERT,DELETE	ON physical_port TO stab_role;
GRANT SELECT,UPDATE					ON physical_port_physical_port_id_seq TO stab_role;
GRANT SELECT,UPDATE,INSERT,DELETE	ON network_interface TO stab_role;
GRANT SELECT,UPDATE					ON network_interface_network_interface_id_seq TO stab_role;
GRANT SELECT,UPDATE,INSERT,DELETE	ON device TO stab_role;
GRANT SELECT,UPDATE					ON device_device_id_seq TO stab_role;
GRANT SELECT,UPDATE,INSERT		ON val_device_status TO stab_role;
GRANT SELECT,UPDATE,INSERT		ON site_netblock TO stab_role;
-- GRANT SELECT,UPDATE,INSERT		ON device_function TO stab_role;
GRANT SELECT				ON device_type TO stab_role;
GRANT SELECT				ON operating_system TO stab_role;
GRANT SELECT				ON val_ownership_status TO stab_role;
GRANT SELECT				ON val_production_state TO stab_role;
-- GRANT SELECT				ON val_device_function_type TO stab_role;
GRANT SELECT				ON val_network_interface_purpose TO stab_role;
GRANT SELECT				ON val_network_interface_type TO stab_role;
GRANT SELECT				ON val_dns_type TO stab_role;
GRANT SELECT				ON val_dns_class TO stab_role;
GRANT SELECT,INSERT			ON snmp_commstr TO stab_role;
GRANT SELECT				ON val_device_auto_mgmt_protocol TO stab_role;
GRANT SELECT				ON val_processor_architecture TO stab_role;

GRANT SELECT,UPDATE,DELETE	   	ON layer1_connection TO stab_role;
GRANT SELECT,UPDATE					ON layer1_connection_layer1_connection_id_seq TO stab_role;
GRANT SELECT,UPDATE,INSERT	    	ON device_type TO stab_role;
GRANT SELECT,UPDATE					ON device_type_device_type_id_seq TO stab_role;
GRANT SELECT,UPDATE,INSERT	    	ON operating_system TO stab_role;
GRANT SELECT,UPDATE					ON operating_system_operating_system_id_seq TO stab_role;
GRANT SELECT,INSERT,UPDATE	    	ON snmp_commstr TO stab_role;
GRANT SELECT			  	ON val_snmp_commstr_type TO stab_role;
GRANT SELECT,INSERT,UPDATE,DELETE    	ON device_type_power_port_templt TO stab_role;
GRANT SELECT,INSERT,UPDATE,DELETE    	ON device_type_phys_port_templt TO stab_role;
GRANT SELECT			  	ON val_plug_style TO stab_role;
GRANT SELECT,INSERT		  	ON device_note TO stab_role;
GRANT SELECT,INSERT,UPDATE,DELETE  	ON location TO stab_role;
GRANT SELECT,UPDATE					ON location_location_id_seq TO stab_role;
GRANT SELECT,INSERT,UPDATE,DELETE  	ON device_power_interface TO stab_role;
GRANT SELECT,INSERT,UPDATE,DELETE  	ON device_power_connection TO stab_role;
GRANT SELECT,INSERT,UPDATE,DELETE  	ON physical_connection TO stab_role;
GRANT SELECT,UPDATE					ON physical_connection_physical_connection_id_seq TO stab_role;


GRANT SELECT,UPDATE,INSERT		ON voe TO stab_role;
GRANT SELECT,UPDATE				ON voe_voe_id_seq TO stab_role;
GRANT SELECT				ON val_processor_architecture TO stab_role;
GRANT SELECT				ON sw_package_repository TO stab_role;

GRANT SELECT				ON SW_PACKAGE TO stab_role;
GRANT SELECT				ON SW_PACKAGE_RELATION TO stab_role;
GRANT SELECT				ON SW_PACKAGE_RELEASE TO stab_role;
GRANT SELECT				ON SW_PACKAGE_REPOSITORY TO stab_role;
GRANT SELECT				ON VAL_PACKAGE_RELATION_TYPE TO stab_role;
GRANT SELECT				ON VAL_SW_PACKAGE_FORMAT TO stab_role;
GRANT SELECT				ON VAL_VOE_STATE TO stab_role;
GRANT SELECT				ON VOE_RELATION TO stab_role;
GRANT SELECT				ON VOE_SW_PACKAGE TO stab_role;
GRANT SELECT				ON VOE_SW_PACKAGE TO stab_role;
GRANT SELECT				ON VOE_SYMBOLIC_TRACK TO stab_role;
GRANT SELECT				ON VAL_UPGRADE_SEVERITY TO stab_role;

GRANT SELECT				ON val_stop_bits TO stab_role;
GRANT SELECT				ON val_data_bits TO stab_role;
GRANT SELECT				ON val_baud TO stab_role;
GRANT SELECT				ON val_flow_control TO stab_role;
GRANT SELECT				ON val_parity TO stab_role;
GRANT SELECT				ON val_cable_type TO stab_role;
GRANT SELECT				ON val_account_type TO stab_role;
GRANT SELECT,INSERT,UPDATE,DELETE  	ON dhcp_range TO stab_role;
GRANT SELECT,UPDATE				ON dhcp_range_dhcp_range_id_seq TO stab_role;
GRANT SELECT				ON device_collection TO stab_role;
GRANT SELECT				ON device_collection_hier TO stab_role;
GRANT SELECT				ON device_collection_device TO stab_role;

GRANT stab_role TO ap_stab;
