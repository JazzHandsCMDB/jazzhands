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
CREATE OR REPLACE
PACKAGE unix_util
 IS

------------------------------------------------------------------------------------------------------------------
--DESCRIPTION:  This package is used to insert and manipulate system user data and related data (vehicles,etc.)
-------------------------------------------------------------------------------------------------------------------
--$Id$



-- TYPE Definitions -------------------------
---------------------------------------------


--  Array types
---------------------------------------------


-- Reference Cursor


-- Global Variables -------------------------
---------------------------------------------

-- This holds the ID tag of this header file.  Can be used for debug purposes
GC_spec_id_tag	     CONSTANT global_types.id_tag_var_type := '$Id$';



-- Function Specs  -------------------------
--------------------------------------------

-- id_tag is a function to obtain the version information of the package
FUNCTION id_tag 	RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;



-- Below reference replaced by DETERMINISTIC and PARALLEL_ENABLE
-- PRAGMA RESTRICT_REFERENCES (id_tag, WNDS, RNDS, WNPS, RNPS);


-- Procedure Specs  -------------------------
---------------------------------------------

PROCEDURE unix_add
(
	p_system_user_id	IN	System_User.SYSTEM_USER_ID % TYPE,
	p_shell			IN	USER_UNIX_INFO.SHELL % TYPE,
	p_home			IN	USER_UNIX_INFO.DEFAULT_HOME % TYPE,
	p_gpass			IN	UNIX_GROUP.GROUP_PASSWORD % TYPE,
	p_uid			OUT	USER_UNIX_INFO.UNIX_UID % TYPE,
	p_gid			OUT	UNIX_GROUP.UNIX_GID % TYPE
);

PROCEDURE group_add
(
	p_group_id		OUT	UNIX_GROUP.UNIX_GROUP_ID % TYPE,
	p_gid			IN	UNIX_GROUP.UNIX_GID % TYPE,
	p_passwd		IN	UNIX_GROUP.GROUP_PASSWORD % TYPE,
	p_name			IN	UNIX_GROUP.GROUP_NAME % TYPE
);

PROCEDURE member_add
(
	p_system_user_id	IN	System_User.SYSTEM_USER_ID % TYPE,
	p_group_id		IN	Unix_Group.UNIX_GROUP_ID % TYPE
);

PROCEDURE user_add
(
	p_system_user_id	IN	USER_UNIX_INFO.SYSTEM_USER_ID % TYPE,
	p_uid			IN	USER_UNIX_INFO.UNIX_UID % TYPE,
	p_group_id		IN	USER_UNIX_INFO.UNIX_GROUP_ID % TYPE,
	p_shell			IN	USER_UNIX_INFO.SHELL % TYPE,
	p_home			IN	USER_UNIX_INFO.DEFAULT_HOME % TYPE
);

END;
/
