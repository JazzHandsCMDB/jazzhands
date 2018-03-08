--
-- Copyright (c) 2018, Todd M. Kover
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
-- This is a backwards compatibility view that came into existiance in 0.82
-- that will probably live in perpetuity.
--

CREATE OR REPLACE VIEW site_netblock AS
SELECT site_code, netblock_id,
	ncn.data_ins_user, ncn.data_ins_date,
	ncn.data_upd_user, ncn.data_upd_date
FROM property p
	JOIN netblock_collection nc USING (netblock_collection_id)
	JOIN netblock_collection_netblock ncn USING (netblock_collection_id)
WHERE property_name = 'per-site-netblock_collection'
AND property_type = 'automated'
