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
--
-- $Id$
--
CREATE OR REPLACE VIEW 
	V_Token
AS 
	SELECT 
		Token_ID,
		Token_Type,
		Token_Status,
		Token_Serial,
		Token_Sequence,
		System_User_ID,
		NVL2(Token_PIN, 'set', NULL) Token_PIN,
		Zero_Time,
		Time_Modulo,
		Time_Skew,
		Is_User_Token_Locked,
		Token_Unlock_Time,
		Bad_Logins,
		Issued_Date,
		T.Last_Updated AS Token_Last_Updated,
		TS.Last_Updated AS Token_Sequence_Last_Updated,
		SUT.Last_Updated AS Lock_Status_Last_Updated
	FROM
		Token T LEFT OUTER JOIN Token_Sequence TS USING (Token_ID)
		LEFT OUTER JOIN System_User_Token SUT USING (Token_ID)
;
