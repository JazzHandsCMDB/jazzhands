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

Prompt 'Enter new password for ap_pkgmanip: '

create user ap_pkgmanip identified by &1;

create role pkgmanip_role;

grant create session to pkgmanip_role;

grant pkgmanip_role to ap_pkgmanip;

create synonym ap_pkgmanip.val_production_state 
	for jazzhands.val_production_state;
create synonym ap_pkgmanip.system_user for jazzhands.system_user;
create synonym ap_pkgmanip.sw_package for jazzhands.sw_package;
create synonym ap_pkgmanip.sw_package_release for jazzhands.sw_package_release;
create synonym ap_pkgmanip.voe_sw_package for jazzhands.voe_sw_package;
create synonym ap_pkgmanip.voe for jazzhands.voe;
create synonym ap_pkgmanip.voe_symbolic_track for jazzhands.voe_symbolic_track;
create synonym ap_pkgmanip.sw_package_repository for jazzhands.sw_package_repository;
create synonym ap_pkgmanip.sw_package_relation for jazzhands.sw_package_association;
create synonym ap_pkgmanip.time_util for jazzhands.time_util;
create synonym ap_pkgmanip.voe_manip_util for jazzhands.voe_manip_util;
create synonym ap_pkgmanip.voe_track_manip for jazzhands.voe_track_manip;
create synonym ap_pkgmanip.val_processor_architecture for jazzhands.val_processor_architecture;


grant select on jazzhands.val_production_state to pkgmanip_role;
grant select on jazzhands.system_user to pkgmanip_role;
grant select on jazzhands.sw_package to pkgmanip_role;
grant select on jazzhands.sw_package_release to pkgmanip_role;
grant select on jazzhands.voe_sw_package to pkgmanip_role;
grant select on jazzhands.voe to pkgmanip_role;
grant select on jazzhands.voe_symbolic_track to pkgmanip_role;
grant select on jazzhands.sw_package_repository to pkgmanip_role;
grant select on jazzhands.sw_package_relation to pkgmanip_role;
grant select on jazzhands.val_processor_architecture to pkgmanip_role;
grant execute on jazzhands.time_util to pkgmanip_role;
grant execute on jazzhands.voe_manip_util to pkgmanip_role;
grant execute on jazzhands.voe_track_manip to pkgmanip_role;
