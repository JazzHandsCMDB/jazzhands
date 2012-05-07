-- Copyright (c) 2012, AppNexus, Inc.
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
\c jazzhands;

CREATE USER ap_hrfeed;
GRANT SELECT,INSERT,UPDATE ON person TO ap_hrfeed;
GRANT UPDATE ON person_person_id_seq TO ap_hrfeed;

GRANT SELECT,INSERT,UPDATE ON person_company TO ap_hrfeed;

GRANT SELECT,INSERT ON account TO ap_hrfeed;
GRANT UPDATE ON account_account_id_seq to ap_hrfeed;

GRANT SELECT ON account_realm_company TO ap_hrfeed;

GRANT INSERT ON person_account_realm_company TO ap_hrfeed;

GRANT INSERT,SELECT,UPDATE ON account_collection_account TO ap_hrfeed;

GRANT INSERT, SELECT ON account_collection TO ap_hrfeed;
GRANT UPDATE ON account_collection_account_collection_id_seq TO ap_hrfeed;

GRANT SELECT ON property TO ap_hrfeed;
GRANT SELECT ON val_person_status TO ap_hrfeed;

\c feedlogs;

GRANT INSERT ON hr_scripts TO ap_hrfeed;
GRANT UPDATE ON hr_scripts_id_seq to ap_hrfeed;
