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
PACKAGE GLOBAL_ERRORS
  IS

------------------------------------------------------------------------------------------------------------------
--DESCRIPTION:  This package is used to verify netblock information
--
-------------------------------------------------------------------------------------------------------------------
--$Id$



-- TYPE Definitions -------------------------
---------------------------------------------

SUBTYPE err_msg_type	IS	VARCHAR2(255);


--  Array types
---------------------------------------------
TYPE ty_metadata is RECORD (  ErrorID NUMBER,
                            ServiceID varchar2(50),
                            Error_Level varchar2(50),
                            Timestamp varchar2(30),
                            Text_For_Alert varchar2(200),
                            ServiceSpecificErrorLink Varchar2(200));


TYPE err_msg_t       IS TABLE OF VARCHAR2(512)   INDEX BY BINARY_INTEGER;
TYPE err_msg_table is TABLE OF TY_METADATA;


-- Reference Cursor


-- Global Variables -------------------------
---------------------------------------------

-- This holds the ID tag of this header file.  Can be used for debug purposes
GC_spec_id_tag	     CONSTANT global_types.id_tag_var_type:='$Id$';


err_msg_rs			 err_msg_table:= ERR_MSG_TABLE(null,NULL,NULL,NULL,NULL,NULL);
err_tab_i			 INTEGER := 1;
g_error				 varchar2(100);
--g_return_code can have 'S', 'W' or 'E' values;
g_return_code		 char(1);

-- Global error number list and Messages
ERRNUM_UNKNOWN		CONSTANT	   NUMBER:=-20000;
ERRMSG_UNKNOWN		CONSTANT	   err_msg_type:='Unknown Error';
ERRNUM_INTERNAL		CONSTANT	   NUMBER:=-20001;
ERRMSG_INTERNAL		CONSTANT	   err_msg_type:='Internal Programming Error';
ERRNUM_NON_IPV4		CONSTANT	   NUMBER:=-20100;
ERRMSG_NON_IPV4		CONSTANT	   err_msg_type:='Non-IPv4 IP address are unsupported at present';
ERRNUM_NETBLK_P_CHILD	CONSTANT   NUMBER:=-20101;
ERRMSG_NETBLK_P_CHILD	CONSTANT   err_msg_type:='Parent-Child Netblock conflict';
ERRNUM_NETINT_PRIMARY	CONSTANT   NUMBER:=-20200;
ERRMSG_NETINT_PRIMARY	CONSTANT   err_msg_type:='A device must have one and only one primary interface';
ERRNUM_SNMP_COMMSTR		CONSTANT   NUMBER:=-20300;
ERRMSG_SNMP_COMMSTR		CONSTANT   err_msg_type:='A device may only have one community string of a given type. ';
ERRNUM_DIRECT_DEPT		CONSTANT   NUMBER:=-20400;
ERRMSG_DIRECT_DEPT		CONSTANT   err_msg_type:='A System User can only directly report to one deptarment.';
ERRNUM_MULTIVALUE_OVERRIDE	CONSTANT   NUMBER:=-20500;
ERRMSG_MULTIVALUE_OVERRIDE	CONSTANT   err_msg_type:='This property does not allow multiple values.';

ERRNUM_PKGCONFLICT		CONSTANT	NUMBER:= -20600;
ERRMSG_PKGCONFLICT		CONSTANT	err_msg_type := 'There is a conflicting package.';
ERRNUM_PKGREPNOTOPEN		CONSTANT	NUMBER:= -20601;
ERRMSG_PKGREPNOTOPEN		CONSTANT	err_msg_type := 'Package is not open';
ERRNUM_DEV_SWPKGREPOS_MISMATCH	CONSTANT	NUMBER:= -20602;
ERRMSG_DEV_SWPKGREPOS_MISMATCH	CONSTANT	err_msg_type := 'Devices OS and VOE have different SW Pkg Repositories';
ERRNUM_DEV_VTRKOSREP_MISMATCH	CONSTANT	NUMBER:= -20603;
ERRMSG_DEV_VTRKOSREP_MISMATCH	CONSTANT	err_msg_type := 'Devices OS and VOE TRACK have different SW Pkg Repositories';

ERRNUM_NETBLOCK_IPV4ONLY	CONSTANT	NUMBER:= -20700;
ERRMSG_NETBLOCK_IPV4ONLY	CONSTANT	err_msg_type := 'IPv4 Addresses must be <= 32 bits';
ERRNUM_NETBLOCK_NODUPS		CONSTANT	NUMBER:= -20701;
ERRMSG_NETBLOCK_NODUPS		CONSTANT	err_msg_type := 'Unique Constraint Violated on IP Address';
ERRNUM_NETBLOCK_SMALLPARENT	CONSTANT	NUMBER:= -20702;
ERRMSG_NETBLOCK_SMALLPARENT	CONSTANT	err_msg_type := 'Change would result in parent being smaller';
ERRNUM_NETBLOCK_RANGEERROR	CONSTANT	NUMBER:= -20703;
ERRMSG_NETBLOCK_RANGEERROR	CONSTANT	err_msg_type := 'Change would not be within bounds of parent IP';
ERRNUM_NETBLOCK_BADPARENT	CONSTANT	NUMBER:= -20704;
ERRMSG_NETBLOCK_BADPARENT	CONSTANT	err_msg_type := 'Change invalidates parent-child relationship';
ERRNUM_NETBLOCK_OOR		CONSTANT	NUMBER:= -20705;
ERRMSG_NETBLOCK_OOR		CONSTANT	err_msg_type := 'IP Address is out of valid range for this type of v4/v6 address';

ERRNUM_APPGROUP_BADTYPE		CONSTANT	NUMBER:= -20800;
ERRMSG_APPGROUP_BADTYPE		CONSTANT	err_msg_type := 'Invalid to remove approle from non-app device collection';

-- -20900 downward are raised in K_TIUBR_PROPERTY.  I justwas too lazy to
-- do it here.
-- -20900 - property.property_value is wrongly set
-- -20901 - property.property_value is set when it shouldn not be
-- -20902 - property.property_value too many are set
-- -20902 - property.* (lhs) is not set when it should be
-- -20903 - property.* (lhs) is set when it should not be
-- -20904 - property.uclass_id is of the wrong type.



-- Function Specs  -------------------------
--------------------------------------------

-- id_tag is a function to obtain the version information of the package
FUNCTION id_tag
	RETURN VARCHAR2;

-- Look this up for more information on Functions in Pkgs (p558)
PRAGMA RESTRICT_REFERENCES (id_tag, WNDS, RNDS, WNPS, RNPS);



-- Procedure Specs  ---------------------


-- This procedure is the total waters wrapper around the global error package
-- This will usually be the way to log errros from the application
PROCEDURE log_error		(p_err_num		IN		NUMBER,
				p_proc_name		IN		VARCHAR2,
				p_err_msg		IN		VARCHAR2);




PROCEDURE push( msg IN varchar2);

PROCEDURE push(Errorid IN number default 0,
                serviceID IN varchar2 ,
                error_level IN varchar2,
                timestamp IN varchar2,
                msg      IN VARCHAR2,
                ServiceSpecificErrorLink IN varchar2 DEFAULT null);

FUNCTION  pop(msg OUT VARCHAR2)    RETURN BOOLEAN;

FUNCTION pop(Errorid OUT number,
                serviceID OUT varchar2 ,
                error_level OUT varchar2,
                timestamp OUT varchar2,
                msg      OUT varchar2,
                ServiceSpecificErrorLink OUT varchar2) RETURN BOOLEAN;

FUNCTION GetErrors  return LONG  ;

END; -- Package spec
/
