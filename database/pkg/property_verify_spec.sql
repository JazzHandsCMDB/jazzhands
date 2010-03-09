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
PACKAGE property_verify
-- AUTHID CURRENT_USER
 IS

--------------------------------------------------------------------------
--
-- DESCRIPTION:  This package is used to verify that is_multivalue is not
-- being violated in the property table, and deal with the more complex
-- validation that is required for this table
--
--------------------------------------------------------------------------
--$Id$

---------------------------------------------
-- TYPE Definitions -------------------------
---------------------------------------------
---------------------------------------------
--  Array types
---------------------------------------------
---------------------------------------------
-- Reference Cursor
---------------------------------------------
---------------------------------------------
-- Global Variables -------------------------
---------------------------------------------
-- This holds the ID tag of this header file.  Can be used for debug purposes
GC_spec_id_tag	     CONSTANT global_types.id_tag_var_type:='$Id$';

G_property_recs_type	global_types.property_rec_array;
G_property_recs_name	global_types.property_rec_array;

---------------------------------------------
-- Function Specs  -------------------------
--------------------------------------------

-- id_tag is a function to obtain the version information of the package
FUNCTION id_tag
	RETURN VARCHAR2;

-- Look this up for more information on Functions in Pkgs (p558)
PRAGMA RESTRICT_REFERENCES (id_tag, WNDS, RNDS, WNPS, RNPS);

---------------------------------------------
-- Procedure Specs  -------------------------
---------------------------------------------

END;
/
