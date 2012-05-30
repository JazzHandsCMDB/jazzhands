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


create role voe_dev_role;

grant create session to voe_dev_role;

grant execute 			on jazzhands.ip_manip to voe_dev_role;
grant select			on jazzhands.netblock to voe_dev_role;
grant select			on jazzhands.SW_PACKAGE to voe_dev_role;
grant select			on jazzhands.SW_PACKAGE to voe_dev_role;
grant select			on jazzhands.SW_PACKAGE_RELATION to voe_dev_role;
grant select			on jazzhands.SW_PACKAGE_RELATION to voe_dev_role;
grant select			on jazzhands.SW_PACKAGE_RELEASE to voe_dev_role;
grant select			on jazzhands.SW_PACKAGE_RELEASE to voe_dev_role;
grant select			on jazzhands.SW_PACKAGE_REPOSITORY to voe_dev_role;
grant select			on jazzhands.SW_PACKAGE_REPOSITORY to voe_dev_role;
grant select			on jazzhands.VAL_PACKAGE_RELATION_TYPE to voe_dev_role;
grant select			on jazzhands.VAL_SW_PACKAGE_FORMAT to voe_dev_role;
grant select			on jazzhands.VAL_SW_PACKAGE_FORMAT to voe_dev_role;
grant select			on jazzhands.VAL_SW_PACKAGE_TYPE to voe_dev_role;
grant select			on jazzhands.VAL_SW_PACKAGE_TYPE to voe_dev_role;
grant select			on jazzhands.VAL_VOE_STATE to voe_dev_role;
grant select			on jazzhands.VOE_RELATION to voe_dev_role;
grant select			on jazzhands.VOE_SW_PACKAGE to voe_dev_role;
grant select			on jazzhands.VOE_SW_PACKAGE to voe_dev_role;
grant select			on jazzhands.VOE_SYMBOLIC_TRACK to voe_dev_role;
grant select			on jazzhands.VOE to voe_dev_role;
grant select			on jazzhands.DEVICE to voe_dev_role;

grant select			on jazzhands.aud$netblock to voe_dev_role;
grant select			on jazzhands.aud$SW_PACKAGE to voe_dev_role;
grant select			on jazzhands.aud$SW_PACKAGE to voe_dev_role;
grant select			on jazzhands.aud$SW_PACKAGE_RELATION to voe_dev_role;
grant select			on jazzhands.aud$SW_PACKAGE_RELATION to voe_dev_role;
grant select			on jazzhands.aud$SW_PACKAGE_RELEASE to voe_dev_role;
grant select			on jazzhands.aud$SW_PACKAGE_RELEASE to voe_dev_role;
grant select			on jazzhands.aud$SW_PACKAGE_REPOSITORY to voe_dev_role;
grant select			on jazzhands.aud$SW_PACKAGE_REPOSITORY to voe_dev_role;
grant select			on jazzhands.aud$VAL_PACKAGE_RELATION_TYPE to voe_dev_role;
grant select			on jazzhands.aud$VAL_SW_PACKAGE_FORMAT to voe_dev_role;
grant select			on jazzhands.aud$VAL_SW_PACKAGE_FORMAT to voe_dev_role;
grant select			on jazzhands.aud$VAL_SW_PACKAGE_TYPE to voe_dev_role;
grant select			on jazzhands.aud$VAL_SW_PACKAGE_TYPE to voe_dev_role;
grant select			on jazzhands.aud$VAL_VOE_STATE to voe_dev_role;
grant select			on jazzhands.aud$VOE_RELATION to voe_dev_role;
grant select			on jazzhands.aud$VOE_SW_PACKAGE to voe_dev_role;
grant select			on jazzhands.aud$VOE_SW_PACKAGE to voe_dev_role;
grant select			on jazzhands.aud$VOE_SYMBOLIC_TRACK to voe_dev_role;
grant select			on jazzhands.aud$VOE to voe_dev_role;
grant select			on jazzhands.aud$DEVICE to voe_dev_role;

-- grant execute			on jazzhands.TIME_UTIL to voe_dev_role;
-- grant execute			on jazzhands.VOE_MANIP_UTIL to voe_dev_role;
-- grant execute			on jazzhands.VOE_TRACK_MANIP to voe_dev_role;

prompt ' grants  and synonyms '
exit;

create user &&developer identified by &passwd
 DEFAULT TABLESPACE DATA
   TEMPORARY TABLESPACE TEMP
   PROFILE DEFAULT
   ACCOUNT UNLOCK;

 grant voe_dev_role to &&developer;

 create synonym &&developer.ip_manip for jazzhands.ip_manip;

create synonym &&developer.DEVICE for jazzhands.DEVICE;
create synonym &&developer.SW_PACKAGE for jazzhands.SW_PACKAGE;
create synonym &&developer.SW_PACKAGE_RELATION for jazzhands.SW_PACKAGE_RELATION;
create synonym &&developer.SW_PACKAGE_RELEASE for jazzhands.SW_PACKAGE_RELEASE;
create synonym &&developer.SW_PACKAGE_REPOSITORY for jazzhands.SW_PACKAGE_REPOSITORY;
create synonym &&developer.VAL_PACKAGE_RELATION_TYPE for jazzhands.VAL_PACKAGE_RELATION_TYPE;
create synonym &&developer.VAL_SW_PACKAGE_FORMAT for jazzhands.VAL_SW_PACKAGE_FORMAT;
create synonym &&developer.VAL_SW_PACKAGE_TYPE for jazzhands.VAL_SW_PACKAGE_TYPE;
create synonym &&developer.VAL_VOE_STATE for jazzhands.VAL_VOE_STATE;
create synonym &&developer.VOE_RELATION for jazzhands.VOE_RELATION;
create synonym &&developer.VOE_SW_PACKAGE for jazzhands.VOE_SW_PACKAGE;
create synonym &&developer.VOE_SYMBOLIC_TRACK for jazzhands.VOE_SYMBOLIC_TRACK;
create synonym &&developer.VOE for jazzhands.VOE;
