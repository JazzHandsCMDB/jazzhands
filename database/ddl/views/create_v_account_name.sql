-- Copyright (c) 2019, Ryan D. Williams
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

CREATE OR REPLACE VIEW v_account_name AS
SELECT
    a.account_id,
    COALESCE(prp.first_name, p.first_name) AS first_name,
    COALESCE(prp.last_name, p.last_name) AS last_name,
    COALESCE(prp.display_name,
		COALESCE(prp.first_name, p.first_name) || ' ' ||
		COALESCE(prp.last_name, p.last_name)
	) AS display_name
FROM account a
INNER JOIN v_person p USING (person_id)
LEFT JOIN (
	SELECT aca.account_id,
		min(property_value) FILTER (WHERE property_name='first_name') as first_name,
		min(property_value) FILTER (WHERE property_name='last_name') as last_name,
		min(property_value) FILTER (WHERE property_name='display_name') as display_name
	FROM account_collection_account aca
	iNNER JOIN property USING (account_collection_id)
    WHERE property_type = 'account_name_override'
	GROUP BY 1
) prp USING (account_Id)
;
