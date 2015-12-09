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

-- \ir global_errors.sql
-- \ir global_types.sql
-- \ir global_util.sql

-- \ir system_user_util.sql
\ir person_manip.sql
\ir auto_ac_manip.sql
\ir company_manip.sql
-- \ir unix_util.sql
-- \ir dept_member_verify.sql
-- \ir netblock_verify.sql
--++ \ir fqdn_util.sql
-- \ir token_util.sql
-- \ir time_util.sql
-- \ir dns_gen_utils.sql
--++  \ir voe_manip_util.sql
--++ \ir voe_track_manip.sql
\ir port_support.sql
\ir port_util.sql
\ir device_utils.sql
\ir netblock_utils.sql
\ir netblock_manip.sql
-- \ir key_crypto.sql
-- \ir dbms_job_util.sql
-- \ir appgroup_util.sql
-- \ir property_verify.sql
\ir physical_address_utils.sql
\ir component_utils.sql
\ir snapshot_manip.sql
\ir lv_manip.sql
\ir approval_utils.sql
