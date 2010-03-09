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

Prompt 'Enter new password for ap_stab: '

create user ap_stab identified by &1;

create role stab_role;

grant create session to stab_role;

grant execute 				on jazzhands.ip_manip to stab_role;
grant select,update,insert,delete	on jazzhands.netblock to stab_role;
grant select 				on jazzhands.dns_record to stab_role;
grant select				on jazzhands.dns_domain to stab_role;
grant select				on jazzhands.partner to stab_role;
grant select				on jazzhands.site to stab_role;

grant stab_role to ap_stab;

create synonym ap_stab.ip_manip for jazzhands.ip_manip;
create synonym ap_stab.netblock for jazzhands.netblock;
create synonym ap_stab.dns_record for jazzhands.dns_record;
create synonym ap_stab.dns_domain for jazzhands.dns_domain;
create synonym ap_stab.site for jazzhands.site;
create synonym ap_stab.partner for jazzhands.partner;
