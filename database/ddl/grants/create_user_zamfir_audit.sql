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

Prompt 'Enter new password for ap_zamfir_audit: '

create user ap_zamfir_audit identified by &1;

create role zamfir_audit_role;

grant create session to zamfir_audit_role;

grant select, update on jazzhands.device to zamfir_audit_role;
grant execute		on jazzhands.ip_manip to zamfir_audit_role;
grant select		on jazzhands.device_type to zamfir_audit_role;
grant select,insert,update	on jazzhands.device_function to zamfir_audit_role;
grant select		on jazzhands.operating_system to zamfir_audit_role;
grant select		on jazzhands.composite_os_version to zamfir_audit_role;
grant select		on jazzhands.network_interface to zamfir_audit_role;
grant select		on jazzhands.netblock to zamfir_audit_role;
grant select		on jazzhands.site to zamfir_audit_role;
grant select		on jazzhands.location to zamfir_audit_role;
grant select		on jazzhands.val_production_state to zamfir_audit_role;
grant select		on jazzhands.val_device_function_type to zamfir_audit_role;
grant select		on jazzhands.val_status to zamfir_audit_role;
grant select		on jazzhands.site_netblock to zamfir_audit_role;
grant select		on jazzhands.dns_record to zamfir_audit_role;
grant select		on jazzhands.partner to zamfir_audit_role;
grant select		on jazzhands.dns_record to zamfir_audit_role;
grant select		on jazzhands.dns_domain to zamfir_audit_role;
grant select		on jazzhands.physical_port to zamfir_audit_role;
grant select		on jazzhands.layer1_connection to zamfir_audit_role;

grant zamfir_audit_role to ap_zamfir_audit;

create synonym ap_zamfir_audit.ip_manip for jazzhands.ip_manip;
create synonym ap_zamfir_audit.device for jazzhands.device;
create synonym ap_zamfir_audit.device_type for jazzhands.device_type;
create synonym ap_zamfir_audit.device_function for jazzhands.device_function;
create synonym ap_zamfir_audit.operating_system for jazzhands.operating_system;
create synonym ap_zamfir_audit.composite_os_version for jazzhands.composite_os_version;
create synonym ap_zamfir_audit.network_interface for jazzhands.network_interface;
create synonym ap_zamfir_audit.netblock for jazzhands.netblock;
create synonym ap_zamfir_audit.site for jazzhands.site;
create synonym ap_zamfir_audit.location for jazzhands.location;
create synonym ap_zamfir_audit.val_production_state for jazzhands.val_production_state;
create synonym ap_zamfir_audit.val_device_function_type for jazzhands.val_function_type;
create synonym ap_zamfir_audit.val_status for jazzhands.val_status;
create synonym ap_zamfir_audit.site_netblock for jazzhands.site_netblock;
create synonym ap_zamfir_audit.dns_record for jazzhands.dns_record;
create synonym ap_zamfir_audit.dns_domain for jazzhands.dns_domain;
create synonym ap_zamfir_audit.partner for jazzhands.partner;
create synonym ap_zamfir_audit.physical_port for jazzhands.physical_port;
create synonym ap_zamfir_audit.layer1_connection for jazzhands.layer1_connection;
