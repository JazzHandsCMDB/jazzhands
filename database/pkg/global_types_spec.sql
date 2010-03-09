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
PACKAGE global_types
 AUTHID CURRENT_USER
 IS

------------------------------------------------------------------------------------------------------------------
--DESCRIPTION:  This package is used to hold all typing that is used in JazzHands
--
-------------------------------------------------------------------------------------------------------------------
--$Id$



-- TYPE Definitions -------------------------
---------------------------------------------

SUBTYPE id_tag_var_type			IS		VARCHAR2(100);
SUBTYPE jazzhands_boolean_type		IS		CHAR(1);
SUBTYPE include_exclude_type	IS		VARCHAR2(10);
SUBTYPE gender_type				IS		SYSTEM_USER.GENDER%TYPE;

TYPE property_rec_type IS RECORD
(
	property_id		property.property_id%TYPE,
	property_name		property.property_name%TYPE,
	property_type		property.property_type%TYPE
);


--  Array types
---------------------------------------------

TYPE netblock_id_array is table of NETBLOCK.NETBLOCK_ID%TYPE index by binary_integer;
TYPE system_user_id_array is table of SYSTEM_USER.SYSTEM_USER_ID%TYPE index by binary_integer;
TYPE property_rec_array is table of property_rec_type index by binary_integer;

-- Reference Cursor
TYPE jazzhands_ref_cur IS REF CURSOR;


-- Global Variables -------------------------
---------------------------------------------
-- Calling values 
GC_boolean_true	   	CONSTANT jazzhands_boolean_type:='Y';
GC_boolean_false	   	CONSTANT jazzhands_boolean_type:='N';

GC_include			CONSTANT include_exclude_type:='INCLUDE';
GC_exclude			CONSTANT include_exclude_type:='EXCLUDE';

GC_male				CONSTANT gender_type:='M';
GC_female			CONSTANT gender_type:='F';
GC_unknown			CONSTANT gender_type:='U';


-- This is not set as a constant so it can be changed dynamically
-- See bb_test_script for an example
--G_DEBUG			BOOLEAN:=TRUE;
G_DEBUG			BOOLEAN:=FALSE;

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


END;  
/
