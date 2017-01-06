-- Copyright (c) 2014-2017, Todd M. Kover
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
-- This is similar to v_unix_account_overrides but just shows unix groups
--
-- It shows one row per device_collection,account_collection mapping
--
-- NOTE: Unlike v_unix_account_overrides, it DOES pay attention to
-- device collection, account_collection mappings in property.  This may need
-- to be reconsidered
--
CREATE OR REPLACE VIEW v_device_col_account_col_cart AS
SELECT device_collection_Id, account_collection_id, setting
FROM (SELECT x.*,
	row_number() OVER (partition by device_collection_id,
		account_collection_id ORDER BY setting) AS rn
	FROM (
		SELECT	device_collection_id, account_collection_id, NULL as setting
		FROM	v_device_col_acct_col_unixgroup
			INNER JOIN account_collection USING (account_collection_id)
			INNER JOIN unix_group USING (account_collection_id)
		UNION
		SELECT device_collection_id, account_collection_id, setting
 			from v_unix_group_overrides
		) x
	) xx
WHERE rn = 1;
