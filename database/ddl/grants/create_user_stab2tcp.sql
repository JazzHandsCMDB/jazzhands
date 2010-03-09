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

Prompt 'Enter new password for ap_stab2tcp: '

create user ap_stab2tcp identified by &1;

create role stab2tcp_role;

grant create session to stab2tcp_role;

grant stab2tcp_role to ap_stab2tcp;

grant select on jazzhands.layer1_connection to stab2tcp_role;
grant select on jazzhands.physical_port to stab2tcp_role;
grant select on jazzhands.device_function to stab2tcp_role;
grant select on jazzhands.device to stab2tcp_role;
grant select on jazzhands.dns_domain to stab2tcp_role;
grant select on jazzhands.dns_record to stab2tcp_role;
grant select on jazzhands.network_interface to stab2tcp_role;
grant select on jazzhands.netblock to stab2tcp_role;
grant execute on jazzhands.port_utils to stab2tcp_role;

create synonym ap_stab2tcp.layer1_connection for jazzhands.layer1_connection;
create synonym ap_stab2tcp.physical_port for jazzhands.physical_port;
create synonym ap_stab2tcp.device_function for jazzhands.device_function;
create synonym ap_stab2tcp.device for jazzhands.device;
create synonym ap_stab2tcp.dns_domain for jazzhands.dns_domain;
create synonym ap_stab2tcp.dns_record for jazzhands.dns_record;
create synonym ap_stab2tcp.network_interface for jazzhands.network_interface;
create synonym ap_stab2tcp.netblock for jazzhands.netblock;

create synonym ap_stab2tcp.port_utils for jazzhands.port_utils;

