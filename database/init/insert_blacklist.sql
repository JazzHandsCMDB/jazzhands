-- Copyright (c) 2005-201Vonage Holdings Corp.
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
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'ame_invalid_approver');
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'anonymous');
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'appsmgr');
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'asgadm');
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'asguest');
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'autoinstall');
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'concurrent manager');
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'concurrentmanager');
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'feeder system');
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'feedersystem');
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'guest');
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'ibe_admin');
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'ibe_guest');
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'ibeguest');
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'iexadmin');
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'initial setup');
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'irc_emp_guest');
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'irc_ext_guest');
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'mobileadm');
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'op_cust_care_admin');
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'op_sysadmin');
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'portal30');
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'portal30_sso');
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'sysadmin');
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'wizard');
insert into account (description, account_type, account_status, login) values ('AD Blacklist Entry', 'blacklist', 'disabled', 'xml_user');

--
-- wrong, or combination of other entries
--
insert into account (description, account_type, account_status, login) values ('Generic Blacklist Entry', 'blacklist', 'disabled', 'adm');
insert into account (description, account_type, account_status, login) values ('Generic Blacklist Entry', 'blacklist', 'disabled', 'appl');
insert into account (description, account_type, account_status, login) values ('Generic Blacklist Entry', 'blacklist', 'disabled', 'application');
insert into account (description, account_type, account_status, login) values ('Generic Blacklist Entry', 'blacklist', 'disabled', 'applications');
insert into account (description, account_type, account_status, login) values ('Generic Blacklist Entry', 'blacklist', 'disabled', 'approver');
insert into account (description, account_type, account_status, login) values ('Generic Blacklist Entry', 'blacklist', 'disabled', 'concurrent');
insert into account (description, account_type, account_status, login) values ('Generic Blacklist Entry', 'blacklist', 'disabled', 'feeder');
insert into account (description, account_type, account_status, login) values ('Generic Blacklist Entry', 'blacklist', 'disabled', 'initial');
insert into account (description, account_type, account_status, login) values ('Generic Blacklist Entry', 'blacklist', 'disabled', 'invalid');
insert into account (description, account_type, account_status, login) values ('Generic Blacklist Entry', 'blacklist', 'disabled', 'manager');
insert into account (description, account_type, account_status, login) values ('Generic Blacklist Entry', 'blacklist', 'disabled', 'mobile');
insert into account (description, account_type, account_status, login) values ('Generic Blacklist Entry', 'blacklist', 'disabled', 'portal');
insert into account (description, account_type, account_status, login) values ('Generic Blacklist Entry', 'blacklist', 'disabled', 'public');
insert into account (description, account_type, account_status, login) values ('Generic Blacklist Entry', 'blacklist', 'disabled', 'setup');
insert into account (description, account_type, account_status, login) values ('Generic Blacklist Entry', 'blacklist', 'disabled', 'system');
insert into account (description, account_type, account_status, login) values ('Generic Blacklist Entry', 'blacklist', 'disabled', 'user');
insert into account (description, account_type, account_status, login) values ('Generic Blacklist Entry', 'blacklist', 'disabled', 'valid');
insert into account (description, account_type, account_status, login) values ('Generic Blacklist Entry', 'blacklist', 'disabled', 'xml');
insert into account (description, account_type, account_status, login) values ('Generic Blacklist Entry', 'blacklist', 'disabled', 'windows');

--
-- curses, strictly speaking not necessary b/c people type in names
-- and people can always be more imaginative than i can be in  terms
-- of cursing
--
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'anus');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'ass');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'asshole');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'assholia');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'bastard');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'bastards');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'bitch');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'bitches');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'blowjob');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'breast');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'breasts');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'bugger');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'bung');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'bunghole');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'bungholio');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'cock');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'cockgobbler');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'cocksmoker');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'crotch');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'cunt');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'daemon');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'demon');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'devil');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'dogdick');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'f*ckin');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'fecal');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'fishface');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'frack');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'freak');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'freck');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'frek');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'fuck');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'fucken');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'fucker');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'fucking');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'fxxk');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'giz');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'gloryhole');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'god');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'hell');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'hole');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'hump');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'jackhole');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'jerk');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'jerkwad');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'jizz');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'kinky');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'kunt');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'motherfuck');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'motherfucka');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'motherfucker');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'nerd');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'nutsack');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'p0rn');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'penis');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'penus');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'pindick');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'piss');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'pr0n');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'prick');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'pube');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'pubic');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'pus');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'pusbucket');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'pussy');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'satan');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'screw');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'scrotum');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'sex');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'sh!t');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'shit');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'shitty');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'shxt');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'tit');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'titty');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'turd');
insert into account (description, account_type, account_status, login) values ('Curses Blacklist Entry', 'blacklist', 'disabled', 'vagina');
