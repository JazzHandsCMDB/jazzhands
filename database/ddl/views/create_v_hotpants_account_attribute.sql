-- Copyright (c) 2016, Todd M. Kover
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

-- This likely needs to die in favor of making hotpants less aware of device
-- collection

CREATE OR REPLACE VIEW v_hotpants_account_attribute AS
SELECT	property_id,
	account_id,
	device_collection_id,
	login,
	property_name,
	property_type,
	property_value,
	property_rank,
	is_boolean
FROM	v_device_collection_account_property_expanded 
	INNER JOIN Device_Collection USING (Device_Collection_ID)
WHERE	is_enabled = 'Y'
AND	(
		Device_Collection_Type IN ('HOTPants-app', 'HOTPants')
	OR
		Property_Type IN ('RADIUS', 'HOTPants') 
	)
;
