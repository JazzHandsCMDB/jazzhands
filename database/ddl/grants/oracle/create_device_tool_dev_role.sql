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
-- $Id$
--


create role device_tool_dev_role;

grant create session to device_tool_dev_role;

grant execute 				on jazzhands.ip_manip to device_tool_dev_role;
grant select				on jazzhands.netblock to device_tool_dev_role;
grant select				on jazzhands.secondary_netblock to device_tool_dev_role;
grant select				on jazzhands.dns_record to device_tool_dev_role;
grant select				on jazzhands.dns_domain to device_tool_dev_role;
grant select				on jazzhands.partner to device_tool_dev_role;
grant select				on jazzhands.site to device_tool_dev_role;
grant select				on jazzhands.physical_port to device_tool_dev_role;
grant select				on jazzhands.network_interface to device_tool_dev_role;
grant select				on jazzhands.device to device_tool_dev_role;
grant select				on jazzhands.device_collection to device_tool_dev_role;
grant select				on jazzhands.device_collection_member to device_tool_dev_role;
grant select				on jazzhands.val_status to device_tool_dev_role;
grant select				on jazzhands.site_netblock to device_tool_dev_role;
grant select				on jazzhands.device_function to device_tool_dev_role;
grant select				on jazzhands.device_type to device_tool_dev_role;
grant select				on jazzhands.operating_system to device_tool_dev_role;
grant select				on jazzhands.val_ownership_status to device_tool_dev_role;
grant select				on jazzhands.val_production_state to device_tool_dev_role;
grant select				on jazzhands.val_device_function_type to device_tool_dev_role;
grant select				on jazzhands.val_network_interface_purpose to device_tool_dev_role;
grant select				on jazzhands.val_network_interface_type to device_tool_dev_role;
grant select				on jazzhands.val_dns_type to device_tool_dev_role;
grant select				on jazzhands.val_dns_class to device_tool_dev_role;
grant select				on jazzhands.snmp_commstr to device_tool_dev_role;
grant select				on jazzhands.val_device_auto_mgmt_protocol to device_tool_dev_role;
grant select				on jazzhands.val_processor_architecture to device_tool_dev_role;
grant select				on jazzhands.VAL_PORT_PURPOSE to device_tool_dev_role;
grant select				on jazzhands.VAL_PORT_TYPE to device_tool_dev_role;
grant select				on jazzhands.VAL_CABLE_TYPE to device_tool_dev_role;
grant select				on jazzhands.LAYER1_CONNECTION to device_tool_dev_role;
grant select				on jazzhands.PHYSICAL_CONNECTION to device_tool_dev_role;
grant select				on jazzhands.LOCATION to device_tool_dev_role;
grant select				on jazzhands.device_note to device_tool_dev_role;
grant select				on jazzhands.device_power_connection to device_tool_dev_role;
grant select				on jazzhands.device_power_interface to device_tool_dev_role;

grant select				on jazzhands.aud$netblock to device_tool_dev_role;
grant select				on jazzhands.aud$secondary_netblock to device_tool_dev_role;
grant select				on jazzhands.aud$dns_record to device_tool_dev_role;
grant select				on jazzhands.aud$dns_domain to device_tool_dev_role;
grant select				on jazzhands.aud$partner to device_tool_dev_role;
grant select				on jazzhands.aud$site to device_tool_dev_role;
grant select				on jazzhands.aud$physical_port to device_tool_dev_role;
grant select				on jazzhands.aud$network_interface to device_tool_dev_role;
grant select				on jazzhands.aud$device to device_tool_dev_role;
grant select				on jazzhands.aud$device_collection to device_tool_dev_role;
grant select				on jazzhands.aud$device_collection_member to device_tool_dev_role;
grant select				on jazzhands.aud$val_status to device_tool_dev_role;
grant select				on jazzhands.aud$site_netblock to device_tool_dev_role;
grant select				on jazzhands.aud$device_function to device_tool_dev_role;
grant select				on jazzhands.aud$device_type to device_tool_dev_role;
grant select				on jazzhands.aud$operating_system to device_tool_dev_role;
grant select				on jazzhands.aud$val_ownership_status to device_tool_dev_role;
grant select				on jazzhands.aud$val_production_state to device_tool_dev_role;
grant select				on jazzhands.aud$val_device_function_type to device_tool_dev_role;
grant select				on jazzhands.aud$VAL_NETWORK_INTERFACE_PURP to device_tool_dev_role;
grant select				on jazzhands.aud$val_network_interface_type to device_tool_dev_role;
grant select				on jazzhands.aud$val_dns_type to device_tool_dev_role;
grant select				on jazzhands.aud$val_dns_class to device_tool_dev_role;
grant select				on jazzhands.aud$snmp_commstr to device_tool_dev_role;
grant select				on jazzhands.aud$VAL_DEVICE_AUTO_MGMT_PROTO to device_tool_dev_role;
grant select				on jazzhands.aud$val_processor_architecture to device_tool_dev_role;
grant select				on jazzhands.aud$VAL_PORT_PURPOSE to device_tool_dev_role;
grant select				on jazzhands.aud$VAL_PORT_TYPE to device_tool_dev_role;
grant select				on jazzhands.aud$VAL_CABLE_TYPE to device_tool_dev_role;
grant select				on jazzhands.aud$LAYER1_CONNECTION to device_tool_dev_role;
grant select				on jazzhands.aud$PHYSICAL_CONNECTION to device_tool_dev_role;
grant select				on jazzhands.aud$LOCATION to device_tool_dev_role;
grant select				on jazzhands.aud$device_note to device_tool_dev_role;
grant select				on jazzhands.aud$device_power_connection to device_tool_dev_role;
grant select				on jazzhands.aud$device_power_interface to device_tool_dev_role;


prompt ' grants  and synonyms '
exit;

create user &&developer identified by &passwd
 DEFAULT TABLESPACE DATA
   TEMPORARY TABLESPACE TEMP
   PROFILE DEFAULT
   ACCOUNT UNLOCK;

 grant device_tool_dev_role to &&developer

 create synonym &&developer.ip_manip for jazzhands.ip_manip;
 create synonym &&developer.netblock for jazzhands.netblock;
 create synonym &&developer.secondary_netblock for jazzhands.secondary_netblock;
 create synonym &&developer.dns_record for jazzhands.dns_record;
 create synonym &&developer.dns_domain for jazzhands.dns_domain;
 create synonym &&developer.site for jazzhands.site;
 create synonym &&developer.partner for jazzhands.partner;

 create synonym &&developer.physical_port for jazzhands.physical_port;
 create synonym &&developer.network_interface for jazzhands.network_interface;
 create synonym &&developer.device for jazzhands.device;
 create synonym &&developer.device_collection for jazzhands.device_collection;
 create synonym &&developer.device_collection_member for jazzhands.device_collection_member;
 create synonym &&developer.device_function for jazzhands.device_function;
 create synonym &&developer.device_type for jazzhands.device_type;
 create synonym &&developer.val_status for jazzhands.val_status;
 create synonym &&developer.site_netblock for jazzhands.site_netblock;
 create synonym &&developer.operating_system for jazzhands.operating_system;
 create synonym &&developer.val_ownership_status for jazzhands.val_ownership_status;
 create synonym &&developer.val_production_state for jazzhands.val_production_state;
 create synonym &&developer.val_device_function_type for jazzhands.val_device_function_type;
 create synonym &&developer.val_network_interface_purpose for jazzhands.val_network_interface_purpose;
 create synonym &&developer.val_network_interface_type for jazzhands.val_network_interface_type;
 create synonym &&developer.snmp_commstr for jazzhands.snmp_commstr;
 create synonym &&developer.val_dns_type for jazzhands.val_dns_type;
 create synonym &&developer.val_dns_class for jazzhands.val_dns_class;
 create synonym &&developer.val_device_auto_mgmt_protocol for jazzhands.val_device_auto_mgmt_protocol;
 create synonym &&developer.val_processor_architecture for jazzhands.val_processor_architecture;

 create synonym &&developer.val_port_purpose for jazzhands.val_port_purpose;
 create synonym &&developer.val_port_type for jazzhands.val_port_type;
 create synonym &&developer.val_cable_type for jazzhands.val_cable_type;
 create synonym &&developer.layer1_connection for jazzhands.layer1_connection;
 create synonym &&developer.physical_connection for jazzhands.physical_connection;
 create synonym &&developer.location for jazzhands.location;


