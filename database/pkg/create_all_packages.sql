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
--
-- This will create all packages in the proper order
--
-- $Id$
--

@@system_user_util_spec.sql
show errors
@@unix_util_spec.sql
show errors
@@dept_member_verify_spec.sql
show errors
@@mclass_prop_override_verify_spec.sql
show errors
@@netblock_verify_spec.sql
show errors
@@netblock_utils_spec.sql
show errors
--@@fqdn_util_spec.sql
@@token_util_spec.sql
show errors
@@time_util_spec.sql
show errors
@@dns_gen_utils_spec.sql
show errors
-- @@voe_manip_util_spec.sql
-- show errors
-- @@voe_track_manip_spec.sql
-- show errors
@@port_support_spec.sql
show errors
@@port_util_spec.sql
show errors
@@device_utils_spec.sql
show errors
@@netblock_utils_spec.sql
show errors
@@key_crypto_spec.sql
show errors
@@dbms_job_util_spec.sql
show errors
@@appgroup_util_spec.sql
show errors
@@property_verify_spec.sql
show errors


@@global_errors_body.sql
show errors
@@global_types_body.sql
show errors
@@global_util_body.sql
show errors

@@system_user_util_body.sql
show errors
@@unix_util_body.sql
show errors
@@dept_member_verify_body.sql
show errors
@@mclass_prop_override_verify_body.sql
show errors
@@netblock_verify_body.sql
show errors;
@@netblock_utils_body.sql
show errors
--@@fqdn_util_body.sql
@@token_util_body.sql
show errors
@@time_util_body.sql
show errors
@@dns_gen_utils_body.sql
show errors
-- @@voe_manip_util_body.sql
-- show errors
-- @@voe_track_manip_body.sql
-- show errors
@@port_support_body.sql
show errors
@@port_util_body.sql
show errors
@@device_utils_body.sql
show errors
@@netblock_utils_body.sql
show errors
@@key_crypto_body.sql
show errors
@@dbms_job_util_body.sql
show errors
@@appgroup_util_body.sql
show errors
@@property_verify_body.sql
show errors

