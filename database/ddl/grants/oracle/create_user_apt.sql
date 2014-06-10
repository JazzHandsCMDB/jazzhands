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

Prompt 'Enter new password for ap_apt: '

create user ap_apt identified by &1;

create role apt_role;

grant create session to apt_role;

grant apt_role to ap_apt;

create synonym ap_apt.netblock for jazzhands.netblock;
create synonym ap_apt.network_interface for jazzhands.network_interface;
create synonym ap_apt.operating_system for jazzhands.operating_system;
create synonym ap_apt.sw_package for jazzhands.sw_package;
create synonym ap_apt.sw_package_relation for jazzhands.sw_package_relation;
create synonym ap_apt.sw_package_release for jazzhands.sw_package_release;
create synonym ap_apt.sw_package_repository for jazzhands.sw_package_repository;
create synonym ap_apt.voe_sw_package for jazzhands.voe_sw_package;
create synonym ap_apt.voe_symbolic_track for jazzhands.voe_symbolic_track;
create synonym ap_apt.voe for jazzhands.voe;
create synonym ap_apt.device for jazzhands.device;


create synonym ap_apt.ip_manip for jazzhands.ip_manip;
create synonym ap_apt.time_util for jazzhands.time_util;


grant select on jazzhands.netblock to apt_role;
grant select on jazzhands.network_interface to apt_role;
grant select on jazzhands.operating_system to apt_role;
grant select on jazzhands.sw_package to apt_role;
grant select on jazzhands.sw_package_relation to apt_role;
grant select on jazzhands.sw_package_release to apt_role;
grant select on jazzhands.sw_package_repository to apt_role;
grant select on jazzhands.voe_sw_package to apt_role;
grant select on jazzhands.voe_symbolic_track to apt_role;
grant select on jazzhands.voe to apt_role;
grant select on jazzhands.device to apt_role;
grant execute on jazzhands.time_util to apt_role;
grant execute on jazzhands.ip_manip to apt_role;
