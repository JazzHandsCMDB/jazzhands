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

--
-- AD system
--
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'ame_invalid_approver');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'anonymous');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'appsmgr');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'asgadm');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'asguest');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'autoinstall');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'concurrent manager');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'concurrentmanager');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'feeder system');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'feedersystem');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'guest');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'ibe_admin');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'ibe_guest');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'ibeguest');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'iexadmin');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'initial setup');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'irc_emp_guest');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'irc_ext_guest');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'mobileadm');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'op_cust_care_admin');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'op_sysadmin');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'portal30');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'portal30_sso');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'sysadmin');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'wizard');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('AD', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'xml_user');

--
-- wrong, or combination of other entries
--
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Generic', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'adm');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Generic', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'appl');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Generic', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'application');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Generic', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'applications');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Generic', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'approver');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Generic', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'concurrent');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Generic', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'feeder');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Generic', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'initial');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Generic', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'invalid');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Generic', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'manager');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Generic', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'mobile');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Generic', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'portal');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Generic', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'public');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Generic', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'setup');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Generic', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'system');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Generic', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'user');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Generic', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'valid');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Generic', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'xml');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Generic', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'windows');

--
-- curses, strictly speaking not necessary b/c people type in names
-- and people can always be more imaginative than i can be in  terms
-- of cursing
--
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'anus');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'ass');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'asshole');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'assholia');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'bastard');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'bastards');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'bitch');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'bitches');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'blowjob');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'breast');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'breasts');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'bugger');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'bung');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'bunghole');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'bungholio');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'cock');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'cockgobbler');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'cocksmoker');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'crotch');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'cunt');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'daemon');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'demon');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'devil');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'dogdick');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'f*ckin');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'fecal');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'fishface');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'frack');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'freak');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'freck');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'frek');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'fuck');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'fucken');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'fucker');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'fucking');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'fxxk');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'giz');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'gloryhole');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'god');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'hell');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'hole');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'hump');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'jackhole');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'jerk');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'jerkwad');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'jizz');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'kinky');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'kunt');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'motherfuck');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'motherfucka');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'motherfucker');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'nerd');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'nutsack');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'p0rn');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'penis');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'penus');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'pindick');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'piss');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'pr0n');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'prick');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'pube');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'pubic');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'pus');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'pusbucket');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'pussy');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'satan');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'screw');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'scrotum');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'sex');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'sh!t');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'shit');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'shitty');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'shxt');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'tit');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'titty');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'turd');
insert into system_user (first_name, last_name, system_user_type, system_user_status, company_id, login) values ('Curses', 'Blacklist Entry', 'blacklist', 'disabled', 0, 'vagina');
