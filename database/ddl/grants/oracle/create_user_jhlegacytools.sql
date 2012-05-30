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

Prompt 'Enter password for jhlegacytools:'

CREATE USER jhlegacytools 
	IDENTIFIED BY "&1"
	PROFILE DEFAULT
	ACCOUNT UNLOCK;

ALTER USER jhlegacytools DEFAULT ROLE ALL;




CREATE ROLE jhlegacytools_role;

GRANT CREATE SESSION TO jhlegacytools_role;


grant select, insert, update, delete	on jazzhands.sudo_alias to jhlegacytools_role;
grant select, insert, update, delete	on jazzhands.sudo_uclass_device_collection to jhlegacytools_role;
grant select, insert, update, delete	on jazzhands.sudo_default to jhlegacytools_role;
grant select on jazzhands.v_uclass_user_expanded to jhlegacytools_role;

GRANT jhlegacytools_role TO jhlegacytools;

create SYNONYM jhlegacytools.sudo_alias for jazzhands.sudo_alias;
create SYNONYM jhlegacytools.sudo_uclass_device_collection for jazzhands.sudo_uclass_device_collection;
create SYNONYM jhlegacytools.sudo_default for jazzhands.sudo_default;
create SYNONYM jhlegacytools.v_uclass_user_expanded for jazzhands.v_uclass_user_expanded;
