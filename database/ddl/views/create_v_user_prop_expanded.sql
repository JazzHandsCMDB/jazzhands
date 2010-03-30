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

CREATE OR REPLACE VIEW V_User_Prop_Expanded AS
		SELECT
			System_User_Id,
			Property_Type,
			Property_Name,
			Property_Value,
			Property_Value_Timestamp,
			Property_Value_Company_Id,
			Property_Value_DNS_Domain_ID,
			Property_Value_Netblock_ID,
			Property_Value_Password_Type,
			Property_Value_Token_Col_Id,
			Property_Value_Uclass_Id,
			DECODE(Is_Multivalue, 'N', 0, 'Y', 1) Is_Multivalue
		FROM 
			MV_Uclass_User_Expanded_Detail UUED JOIN 
			UClass USING (Uclass_ID) JOIN
			Property USING (Uclass_ID) JOIN
			VAL_Property USING
				(Property_Name, Property_Type) JOIN
			System_User SU ON (SU.System_User_Id = UUED.System_User_ID)
		ORDER BY
			 DECODE(UClass_Type,
				'per-user', 0,
				'property', 1,
				'systems', 2,
				3),
			 DECODE(Assign_Method,
				'UclassAssignedToPerson', 0,
				'UclassAssignedToDept', 1,
				'ParentUclassOfUclassAssignedToPerson', 2,
				'ParentUclassOfUclassAssignedToDept', 2,
				'UclassAssignedToParentDept', 3,
				'ParentUclassOfUclassAssignedToParentDep', 3,
				6),
			 Dept_Level, UClass_Level, UClass_ID;

