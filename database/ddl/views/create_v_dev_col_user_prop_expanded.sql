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

-- Copyright (c) 2015, Todd M. Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--       http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.


-- This view maps users to device collections and lists properties
-- assigned to the users in order of their priorities.

DROP VIEW v_dev_col_user_prop_expanded;
CREATE OR REPLACE VIEW v_dev_col_user_prop_expanded AS
SELECT	dchd.device_collection_id,
	a.account_id, a.login, a.account_status,
	ar.account_realm_id, ar.account_realm_name,
	a.is_enabled,
	upo.property_type property_type,
	upo.property_name property_name, 
	coalesce(Property_Value_Password_Type, Property_Value) AS property_value,
	CASE WHEN upn.is_multivalue = 'N' THEN 0
		ELSE 1 END is_multivalue,
	CASE WHEN pdt.property_data_type = 'boolean' THEN 1 ELSE 0 END is_boolean
FROM	v_acct_coll_acct_expanded_detail uued
	INNER JOIN Account_Collection u 
		USING (account_collection_id)
	INNER JOIN v_property upo ON 
		upo.Account_Collection_id = u.Account_Collection_id
		AND upo.property_type in (
			'CCAForceCreation', 'CCARight', 'ConsoleACL', 'RADIUS', 
			'TokenMgmt', 'UnixPasswdFileValue', 'UserMgmt', 'cca', 
			'feed-attributes', 'wwwgroup')
	INNER JOIN val_property upn
		ON upo.property_name = upn.property_name
		AND upo.property_type = upn.property_type
	INNER JOIN val_property_data_type pdt
		ON upn.property_data_type = pdt.property_data_type
	INNER JOIN account a ON uued.account_id = a.account_id
	INNER JOIN account_realm ar ON a.account_realm_id = ar.account_realm_id
	LEFT JOIN v_device_coll_hier_detail dchd
  		ON (dchd.parent_device_collection_id = upo.device_collection_id)
ORDER BY device_collection_level,
   CASE WHEN u.Account_Collection_type = 'per-account' THEN 0
	WHEN u.Account_Collection_type = 'property' THEN 1
	WHEN u.Account_Collection_type = 'systems' THEN 2
	ELSE 3 END,
  CASE WHEN uued.assign_method = 'Account_CollectionAssignedToPerson' THEN 0
	WHEN uued.assign_method = 'Account_CollectionAssignedToDept' THEN 1
	WHEN uued.assign_method = 
	'ParentAccount_CollectionOfAccount_CollectionAssignedToPerson' THEN 2
	WHEN uued.assign_method = 
	'ParentAccount_CollectionOfAccount_CollectionAssignedToDept' THEN 2
	WHEN uued.assign_method = 
	'Account_CollectionAssignedToParentDept' THEN 3
	WHEN uued.assign_method = 
	'ParentAccount_CollectionOfAccount_CollectionAssignedToParentDep' 
			THEN 3
        ELSE 6 END,
  uued.dept_level, uued.acct_coll_level, dchd.device_collection_id, 
  u.Account_Collection_id;
