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
-- This query maps device collections to accounts and limits it accounts
-- that are associated with a mclass/device collection.
--
-- NOTE:  This primary exists to build credentials files on a host.
-- Ideally it would be generic and NOT have the limits against
-- v_device_col_acct_col_expanded but that is necesary (for now) because
-- of dependent views 
--
-- Alternately a materized view could work, but that was still pretty
-- sluggish.  A materilized view of the restricted v_device_col_account_cart
-- here speeds things up but not enough to be worth the overhead
--
create or replace view v_device_col_account_cart AS
SELECT device_collection_id, account_id, setting
FROM (
	SELECT x.*,
		row_number() OVER (partition by device_collection_id,
			account_id ORDER BY setting) as rn
	FROM (

		SELECT	device_collection_id, account_id, NULL as setting
		FROM	v_device_col_acct_col_unixlogin 
				INNER JOIN account USING (account_id)
				INNER JOIN account_unix_info USING (account_id)
		UNION select device_collection_id, account_id, setting
 			from v_unix_account_overrides
				INNER JOIN account USING (account_id)
				INNER JOIN account_unix_info USING (account_id)
				INNER JOIN v_device_col_acct_col_unixlogin USING 
					(device_collection_id, account_id)
	) x
) xx
WHERE rn = 1;
