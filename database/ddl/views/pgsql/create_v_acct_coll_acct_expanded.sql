-- Copyright (c) 2013-2014, Todd M. Kover
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

CREATE OR REPLACE VIEW v_acct_coll_acct_expanded AS
	SELECT DISTINCT 
		ace.account_collection_id,
		aca.account_id
	FROM 
		v_acct_coll_expanded ace JOIN
		v_account_collection_account aca ON
			aca.account_collection_id = ace.root_account_collection_id;
