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
PACKAGE global_util
 AUTHID CURRENT_USER
 IS

------------------------------------------------------------------------------------------------------------------
--DESCRIPTION:  This package is used to hold generic utility functions for JazzHands
--
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
GC_spec_id_tag	     CONSTANT global_types.id_tag_var_type:='$Id$';



-- Function Specs  -------------------------
--------------------------------------------

-- id_tag is a function to obtain the version information of the package
FUNCTION id_tag
	RETURN VARCHAR2;

-- This is required for functions, WNDS,RNDS, WNPS, RNPS tells that it doesnt read or write in plsql or db
-- Look this up for more information on Functions in Pkgs (p558)
-- RNDS This asserts that the function reads no database state (does not query database tables).
-- RNPS This asserts that the function reads no package state (does not reference the values of packaged variables)
-- TRUST This asserts that the function can be trusted not to violate one or more rules.
-- WNDS This asserts that the function writes no database state (does not modify database tables).
-- WNPS This asserts that the function writes no package state (does not change the values of packaged variables).

PRAGMA RESTRICT_REFERENCES (id_tag, WNDS, RNDS, WNPS, RNPS);



-- Procedure Specs  -------------------------
---------------------------------------------

-- This procedure asserts the validity of a contion.
-- e.g. tw_util.assert_condition( (p_var in ('A','B','C')), 'p_var not a valid value');
-- makes sure that p_var is either A, B, or C

PROCEDURE assert_condition      (p_pass_condition       IN      BOOLEAN,
				p_message_text		IN	VARCHAR2);

-- This procedure put a dbms_output.put_line of the passed message if the DEBUG gloabl is TRUE
PROCEDURE debug_msg      ( p_message_text               IN      VARCHAR2);



END;
/
