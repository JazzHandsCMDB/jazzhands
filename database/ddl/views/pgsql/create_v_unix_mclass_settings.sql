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
-- This view maps device collections to an array of non-user specific
-- properties for the device collection.
--
-- Its primary use if by other views to figure out how to generate files
-- for credentials management
--
CREATE OR REPLACE VIEW v_unix_mclass_settings
AS
SELECT device_collection_id, 
	array_agg(setting ORDER BY rn) AS mclass_setting
FROM (
	SELECT *, row_number() over () AS rn FROM (
		SELECT device_collection_id, 
				unnest(ARRAY[property_name, property_value]) AS setting
		FROM (
			SELECT  dcd.device_collection_id, 
					p.property_name, 
					coalesce(p.property_value, 
						p.property_value_password_type) as property_value,
					row_number() OVER (partition by 
							dcd.device_collection_id,
							p.property_name
							ORDER BY dcd.device_collection_level, property_id
					) AS ord
			FROM    v_device_coll_hier_detail dcd
				INNER JOIN v_property p on
						p.device_collection_id = dcd.parent_device_collection_id
			WHERE	p.property_type IN  ('MclassUnixProp')
			AND		p.account_collection_id is NULL
		) dc
		WHERE ord = 1
	) select_for_ordering
) property_list
GROUP BY device_collection_id
;
