-- Copyright (c) 2015 Todd M. Kover
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

CREATE OR REPLACE VIEW v_approval_instance_step_expanded AS 
WITH RECURSIVE rai AS (
	SELECT 	
		approval_instance_item_id as root_item_id,
		approval_instance_step_id as root_step_id,
		0 as level,
		approval_instance_step_id,
		approval_instance_item_id,
		next_approval_instance_item_id,
		is_approved
	FROM	approval_instance_item
	WHERE	approval_instance_item_id NOT IN (
		SELECT next_approval_instance_item_id
		FROM approval_instance_item
		WHERE next_approval_instance_item_id IS NOT NULL
	)
	UNION
	SELECT 	rai.root_item_id, rai.root_step_id,
		rai.level + 1,
		i.approval_instance_step_id,
		i.approval_instance_item_id,
		i.next_approval_instance_item_id,
		i.is_approved
	FROM	approval_instance_item i
		INNER JOIN rai ON
		rai.next_approval_instance_item_id = i.approval_instance_item_id
		
), q AS (
	SELECT	root_item_id AS first_approval_instance_item_id,
		root_step_id AS root_step_id,
		approval_instance_item_id AS approval_instance_item_id,
		approval_instance_step_id AS approval_instance_step_id,
		rank() OVER (PARTITION BY root_item_id 
				ORDER BY root_item_id,level DESC) as tier,
		level,
		is_approved
	FROM	rai
) SELECT * from q
;
