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

-- NEED TO PORT all of these
-- The ones starting with --++ may not need to be ported since they're also
-- commented out in the oracle part of things..

-- \i global_errors.sql
-- \i global_types.sql
-- \i global_util.sql

-- \i system_user_util.sql
\i person_manip.sql
\i auto_ac_manip.sql
\i company_manip.sql
-- \i unix_util.sql
-- \i dept_member_verify.sql
-- \i netblock_verify.sql
--++ \i fqdn_util.sql
-- \i token_util.sql
-- \i time_util.sql
-- \i dns_gen_utils.sql
--++  \i voe_manip_util.sql
--++ \i voe_track_manip.sql
\i port_support.sql
\i port_util.sql
\i device_utils.sql
\i netblock_utils.sql
\i netblock_manip.sql
-- \i key_crypto.sql
-- \i dbms_job_util.sql
-- \i appgroup_util.sql
-- \i property_verify.sql
\i physical_address_utils.sql
\i component_utils.sql
\i snapshot_manip.sql
\i lv_manip.sql
