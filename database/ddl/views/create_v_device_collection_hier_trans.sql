-- Copyright (c) 2016-2019, Todd Kover
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

CREATE OR REPLACE VIEW v_device_collection_hier_trans AS
SELECT 
	device_collection_id AS parent_device_collection_id,
	child_device_collection_id AS device_collection_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM device_collection_hier;
