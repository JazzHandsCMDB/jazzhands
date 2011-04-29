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
CREATE OR REPLACE PACKAGE
	Token_Util
AS

PROCEDURE set_sequence
(
	p_token_id			IN	Token_Sequence.Token_ID % TYPE,
	p_token_sequence	IN	Token_Sequence.Token_Sequence % TYPE,
	p_reset_time		IN	VARCHAR2
);


PROCEDURE set_pin
(
	p_token_id		IN	Token.Token_ID % TYPE,
	p_token_pin		IN	Token.Token_PIN % TYPE
);

PROCEDURE copy_pin
(
	p_source_token_id	IN	Token.Token_ID % TYPE,
	p_dest_token_id		IN	Token.Token_ID % TYPE
);

PROCEDURE replace_token
(
	p_source_token_id	IN	Token.Token_ID % TYPE,
	p_dest_token_id		IN	Token.Token_ID % TYPE
);

PROCEDURE assign_token
(
	p_token_id		IN	Token.Token_ID % TYPE,
	p_user_id		IN	System_User.System_User_ID % TYPE
);

PROCEDURE unassign_token
(
	p_token_id		IN	Token.Token_ID % TYPE,
	p_user_id		IN	System_User.System_User_ID % TYPE
);

PROCEDURE set_status
(
	p_token_id		IN	Token.Token_ID % TYPE,
	p_token_status	IN	Token.Token_Status % TYPE
);

PROCEDURE set_lock_status
(
	p_token_id      IN  System_User_Token.Token_ID % TYPE,
	p_lock_status   IN  System_User_Token.Is_User_Token_Locked % TYPE,
	p_unlock_time   IN  System_User_Token.Token_Unlock_Time % TYPE,
	p_bad_logins    IN  System_User_Token.Bad_Logins % TYPE,
	p_last_updated  IN  System_User_Token.Last_Updated % TYPE
);

PROCEDURE set_time_skew
(
	p_token_id		IN	Token.Token_ID % TYPE,
	p_time_skew		IN	Token.Time_Skew % TYPE
);

END Token_Util;
/
