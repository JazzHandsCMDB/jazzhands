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

Prompt 'Enter new password for ap_stats: '

create user ap_stats identified by &1;

create role stats_role;

grant create session to stats_role;

grant execute 			on jazzhands.ip_manip to stats_role;
grant select 			on jazzhands.device to stats_role;
grant select 			on jazzhands.network_interface to stats_role;
grant select 			on jazzhands.netblock to stats_role;
grant select 			on jazzhands.snmp_commstr to stats_role;
grant select 			on jazzhands.device_function to stats_role;
grant select 			on jazzhands.site to stats_role;
grant select 			on jazzhands.partner to stats_role;
grant select 			on jazzhands.dns_record to stats_role;
grant select 			on jazzhands.dns_domain to stats_role;
grant select 			on jazzhands.secondary_netblock to stats_role;
grant select 			on jazzhands.device_type to stats_role;
grant select 			on jazzhands.location to stats_role;
grant select 			on jazzhands.physical_port to stats_role;
grant select 			on jazzhands.val_port_type to stats_role;

grant select 			on jazzhands.location to stats_role;
grant select 			on jazzhands.val_device_function_type to stats_role;

grant stats_role to ap_stats;

create synonym ap_stats.ip_manip for jazzhands.ip_manip;
create synonym ap_stats.device for jazzhands.device;
create synonym ap_stats.network_interface for jazzhands.network_interface;
create synonym ap_stats.netblock for jazzhands.netblock;
create synonym ap_stats.snmp_commstr for jazzhands.snmp_commstr;
create synonym ap_stats.device_function for jazzhands.device_function;
create synonym ap_stats.site for jazzhands.site;
create synonym ap_stats.partner for jazzhands.partner;
create synonym ap_stats.dns_record for jazzhands.dns_record;
create synonym ap_stats.dns_domain for jazzhands.dns_domain;
create synonym ap_stats.secondary_netblock for jazzhands.secondary_netblock;
create synonym ap_stats.device_type for jazzhands.device_type;
create synonym ap_stats.location for jazzhands.location;
create synonym ap_stats.physical_port for jazzhands.physical_port;
create synonym ap_stats.val_port_type for jazzhands.val_port_type;
create synonym ap_stats.val_device_function_type for jazzhands.val_device_function_type;

