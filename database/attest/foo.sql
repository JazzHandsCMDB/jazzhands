-- Copyright (c) 2015, Todd M. Kover
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

-- queries in development...

SELECT approver_account_id, aisi.*, aii.*, approval_instance_link_id
FROM	approval_instance ai
		INNER JOIN approval_instance_step ais
			USING (approval_instance_id)
		INNER JOIN approval_instance_step_item aisi
			USING (approval_instance_step_id)
		INNER JOIN approval_instance_item aii USING (approval_instance_item_id)
		INNER JOIN approval_instance_link ail USING (approval_instance_link_id)
WHERE	approver_account_id = 25;


