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

Prompt 'Enter new password for ap_zonegen: '

create user ap_zonegen identified by &1;

create role zonegen_role;

grant create session to zonegen_role;

grant execute 			on jazzhands.ip_manip to zonegen_role;
grant select 			on jazzhands.dns_record to zonegen_role;
grant select,update		on jazzhands.dns_domain to zonegen_role;
grant select 			on jazzhands.dhcp_range to zonegen_role;
grant select 			on jazzhands.netblock to zonegen_role;
grant select 			on jazzhands.network_interface to zonegen_role;

grant zonegen_role to ap_zonegen;

create synonym ap_zonegen.ip_manip for jazzhands.ip_manip;
create synonym ap_zonegen.dns_record for jazzhands.dns_record;
create synonym ap_zonegen.dns_domain for jazzhands.dns_domain;
create synonym ap_zonegen.dhcp_range for jazzhands.dhcp_range;
create synonym ap_zonegen.netblock for jazzhands.netblock;
create synonym ap_zonegen.network_interface for jazzhands.network_interface;

create synonym ap_zonegen.device for jazzhands.device;
create synonym ap_zonegen.device_function for jazzhands.device_function;
create synonym ap_zonegen.site_netblock for jazzhands.site_netblock;
