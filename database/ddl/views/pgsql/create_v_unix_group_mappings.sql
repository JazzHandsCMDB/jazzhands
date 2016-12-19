-- Copyright (c) 2014, Todd M. Kover
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
--
-- $Id$
--

--
-- This query returns what can become a group entry for a given mclass,
-- applying all the various ways for mclass properties to tweak behavior
--
-- This relies on v_device_col_account_col_cart which limits the responses to
-- just mclasses/accounts mapped through the UnixGroup property.  That feature
-- may be able to be undone...
-- 
--
create or replace view v_unix_group_mappings AS
SELECT	dc.device_collection_id,
		ac.account_collection_id,
		ac.account_collection_name as group_name,
		coalesce(setting[(select i + 1
			from generate_subscripts(setting, 1) as i
			where setting[i] = 'ForceGroupGID')]::integer, unix_gid
			) as unix_gid,
		group_password,
		o.setting,
		mcs.mclass_setting,
		array_agg(DISTINCT a.login ORDER BY a.login) as members
FROM	device_collection dc
		JOIN ( 
			SELECT dch.device_collection_id, vace.account_collection_id
				FROM v_property  p
					JOIN v_device_coll_hier_detail dch ON
						p.device_collection_id = dch.parent_device_collection_id
					join v_account_collection_expanded vace 
						ON vace.root_account_collection_id =
							p.account_collection_id
				WHERE property_name = 'UnixGroup'
				AND property_type = 'MclassUnixProp'
			UNION
			select dch.device_collection_id, uag.account_collection_id
			from   v_property p
					JOIN v_device_coll_hier_detail dch ON
							p.device_collection_id = 
								dch.parent_device_collection_id
					join v_acct_coll_acct_expanded vace 
						using (account_collection_id)
					join (
						SELECT a.* 
						FROM account a
							INNER JOIN account_unix_info using (account_id)
							WHERE a.is_enabled = 'Y'
						) a on vace.account_id = a.account_id
					join account_unix_info aui on a.account_id = aui.account_id
					join unix_group ug
						on ug.account_collection_id = aui.unix_group_acct_collection_id
					join account_collection uag
				on ug.account_collection_id = uag.account_collection_id
			WHERE property_name = 'UnixLogin'
			AND property_type = 'MclassUnixProp'
			) ugmap USING (device_collection_id)
		JOIN account_collection ac USING (account_collection_id)
		JOIN unix_group USING (account_collection_id)
		LEFT JOIN v_device_col_account_col_cart o
			USING (device_collection_id,account_collection_id)
		LEFT JOIN (
			SELECT	g.* 
			FROM	(
				SELECT * FROM (
					SELECT device_collection_id, account_collection_id,account_id
		 			FROM	device_collection dc, v_acct_coll_acct_expanded ae
								INNER JOIN unix_group USING (account_collection_id)
		 						INNER JOIN account_collection inac using
									(account_collection_id)
		 			WHERE	dc.device_collection_type = 'mclass'
		 			UNION
		 			SELECT * from (
							SELECT  dch.device_collection_id, 
									p.account_collection_id, aca.account_id
							FROM    v_property p
									INNER JOIN unix_group ug USING (account_collection_id)
									JOIN v_device_coll_hier_detail dch ON
										p.device_collection_id = dch.parent_device_collection_id
									INNER JOIN v_acct_coll_acct_expanded  aca
										ON p.property_value_account_coll_id = aca.account_collection_id
							WHERE   p.property_name = 'UnixGroupMemberOverride'
							AND     p.property_type = 'MclassUnixProp'
						) dcugm
					) actoa
						JOIN account_unix_info ui USING (account_id)
						JOIN (
                			SELECT a.*
                			FROM account a
                        			INNER JOIN account_unix_info using (account_id)
                        			WHERE a.is_enabled = 'Y'

						) a USING (account_id)
					) g
					JOIN (
                				SELECT a.*
                				FROM account a
                        				INNER JOIN account_unix_info using (account_id)
                        				WHERE a.is_enabled = 'Y'
				
						) accts USING (account_id)
					JOIN v_unix_passwd_mappings
						USING (device_collection_id, account_id)
			) a USING (device_collection_id,account_collection_id)
		LEFT JOIN v_unix_mclass_settings mcs
				ON mcs.device_collection_id = dc.device_collection_id
GROUP BY	dc.device_collection_id,
		ac.account_collection_id,
		ac.account_collection_name,
		unix_gid,
		group_password,
		o.setting,
		mcs.mclass_setting
order by device_collection_id, account_collection_id
;
