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

Prompt 'Enter new password for ap_gen_cons_acls: '

create user ap_gen_cons_acls identified by &1;

create role gen_cons_acls_role;

grant create session to gen_cons_acls_role;

grant gen_cons_acls_role to ap_gen_cons_acls;

grant select on jazzhands.uclass to gen_cons_acls_role;
grant select on jazzhands.device_collection to gen_cons_acls_role;
grant select on jazzhands.v_uclass_user_expanded to gen_cons_acls_role;
grant select on jazzhands.device to gen_cons_acls_role;
grant select on jazzhands.uclass_property_override to gen_cons_acls_role;
grant select on jazzhands.mclass_property_override to gen_cons_acls_role;
grant select on jazzhands.system_user to gen_cons_acls_role;
grant select on jazzhands.device_collection_device to gen_cons_acls_role;
grant select on jazzhands.device_collection_hier to gen_cons_acls_role;
grant select on jazzhands.physical_port to gen_cons_acls_role;
grant select on jazzhands.layer1_connection to gen_cons_acls_role;
grant select on jazzhands.device_function to gen_cons_acls_role;
grant select on jazzhands.sudo_uclass_device_collection to gen_cons_acls_role;

create synonym ap_gen_cons_acls.uclass for jazzhands.uclass;
create synonym ap_gen_cons_acls.device_collection for jazzhands.device_collection;
create synonym ap_gen_cons_acls.v_uclass_user_expanded for jazzhands.v_uclass_user_expanded;
create synonym ap_gen_cons_acls.device for jazzhands.device;
create synonym ap_gen_cons_acls.uclass_property_override for jazzhands.uclass_property_override;
create synonym ap_gen_cons_acls.mclass_property_override for jazzhands.mclass_property_override;
create synonym ap_gen_cons_acls.system_user for jazzhands.system_user;
create synonym ap_gen_cons_acls.device_collection_device for jazzhands.device_collection_device;
create synonym ap_gen_cons_acls.device_collection_hier for jazzhands.device_collection_hier;
create synonym ap_gen_cons_acls.physical_port for jazzhands.physical_port;
create synonym ap_gen_cons_acls.layer1_connection for jazzhands.layer1_connection;
create synonym ap_gen_cons_acls.device_function for jazzhands.device_function;
create synonym ap_gen_cons_acls.sudo_uclass_device_collection for jazzhands.sudo_uclass_device_collection;
