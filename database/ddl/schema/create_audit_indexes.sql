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
-- $Id$
--
-- these probably need to be folded in better, and we need to come up with
-- a better way of doing constraints on the audit tables, but here we are...

CREATE INDEX IX_AUDSYSUSRTKN_TKID_SYSUSRID ON AUD$SYSTEM_USER_TOKEN
(TOKEN_ID, SYSTEM_USER_ID) TABLESPACE INDEX01 COMPUTE STATISTICS PARALLEL 8;

CREATE INDEX IX_AUDSYSUSRTKN_SYSUSRID_TOKID ON AUD$SYSTEM_USER_TOKEN
(SYSTEM_USER _ID, TOKEN_ID) TABLESPACE INDEX01 COMPUTE STATISTICS PARALLEL 8;

create index IX_AUDTOKEN_AUDTSTAMP ON AUD$TOKEN(TOKEN_ID, AUD#TIMESTAMP)
TABLESPACE INDEX01 COMPUTE STATISTICS PARALLEL 8;

