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

-- This view maps users to device collections and lists properties
-- assigned to the users in order of their priorities.

CREATE OR REPLACE VIEW v_dev_col_user_prop_expanded AS
SELECT dchd.device_collection_id,
  s.system_user_id, s.login, s.system_user_status,
  upo.property_type uclass_property_type,
  upo.property_name uclass_property_name, upo.property_value,
  decode(upn.is_multivalue, 'N', 0, 'Y', 1) is_multivalue,
  CASE WHEN pdt.property_data_type = 'boolean' THEN 1 ELSE 0 END is_boolean
FROM v_uclass_user_expanded_detail uued
JOIN uclass u ON uued.uclass_id = u.uclass_id
JOIN v_property upo ON upo.uclass_id = u.uclass_id
 AND upo.property_type in (
  'CCAForceCreation', 'CCARight', 'ConsoleACL', 'RADIUS', 'TokenMgmt',
  'UnixPasswdFileValue', 'UserMgmt', 'cca', 'feed-attributes',
  'proteus-tm', 'wwwgroup')
JOIN val_property upn
  ON upo.property_name = upn.property_name
 AND upo.property_type = upn.property_type
JOIN val_property_data_type pdt
  ON upn.property_data_type = pdt.property_data_type
LEFT JOIN v_device_coll_hier_detail dchd
  ON (dchd.parent_device_collection_id = upo.device_collection_id)
JOIN system_user s ON uued.system_user_id = s.system_user_id
ORDER BY device_collection_level,
  decode(u.uclass_type, 
    'per-user', 0,
    'property', 1,
    'systems',  2, 3),
  decode(uued.assign_method,
    'UclassAssignedToPerson',                  0,
    'UclassAssignedToDept',                    1,
    'ParentUclassOfUclassAssignedToPerson',    2,
    'ParentUclassOfUclassAssignedToDept',      2,
    'UclassAssignedToParentDept',              3,
    'ParentUclassOfUclassAssignedToParentDep', 3, 6),
  uued.dept_level, uued.uclass_level, dchd.device_collection_id, u.uclass_id;
