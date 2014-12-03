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
-- This maps device collections to users.
--
-- NOTE:  There are two kinds of ssh keys.  "global" which are found in
-- account_ssh_key and end up with a device collection of null and
-- device_collection_ssh_key which maps ssh keys to account collections (and
-- thus accounts) for only given mclasses.
--
-- This means a user may have two rows in this view.  Some thought should go
-- into how to make that go away.  It means a cartesian join against
-- account_ssh_key and device_collection in the second query
-- in the union, I think.
--

CREATE OR REPLACE VIEW v_device_collection_account_ssh_key
AS
SELECT device_collection_id, account_id,
		array_agg(ssh_public_key) as ssh_public_key
FROM ( 
	SELECT * FROM (
		SELECT  dchd.device_collection_id,
			account_id,
			ssh_public_key
		FROM    device_collection_ssh_key dcssh
			INNER JOIN ssh_key USING (ssh_key_id)
			INNER JOIN v_acct_coll_acct_expanded ac
		    		USING (account_collection_id)
			INNER JOIN account a USING (account_id)
			INNER JOIN v_device_coll_hier_detail dchd ON
		    		dchd.parent_device_collection_id =
		    			dcssh.device_collection_id
    	UNION
	   SELECT  NULL as device_collection_id,
	    		account_id,
	    		ssh_public_key
	    FROM    account_ssh_key ask
	    INNER JOIN ssh_key skey using (ssh_key_id)
    ) keylist
	ORDER BY account_id, 
		coalesce(device_collection_id, 0), ssh_public_key 
) allkeys
    GROUP BY device_collection_id, account_id
;
