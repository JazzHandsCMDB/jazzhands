-- Copyright (c) 2013-2015, Todd M. Kover
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
-- The inter_component_connection get the slot1/2 columns to make joining
-- a little easier.  I waffled.  -kovert
--
CREATE OR REPLACE VIEW v_physical_connection AS
with recursive var_recurse (
	level,
	inter_component_connection_id,
	PHYSICAL_CONNECTION_ID,
	inter_dev_conn_slot1_id,
	inter_dev_conn_slot2_id,
	slot1_id,
	slot2_id,
	array_path,
	cycle
) as (
	       select 	0,
			l1.inter_component_connection_id,
			pc.PHYSICAL_CONNECTION_ID,
	                l1.slot1_id	as inter_dev_conn_slot1_id,
	                l1.slot2_id	as inter_dev_conn_slot2_id,
	                pc.slot1_id,
	                pc.slot2_id,
			ARRAY[slot1_id] as array_path,
			false			 as cycle
	          from  inter_component_connection l1
	        	inner join physical_connection pc
				using (slot1_id)
UNION ALL
       select 	x.level + 1,
		x.inter_component_connection_id,
		pc.PHYSICAL_CONNECTION_ID,
                x.slot1_id 	as inter_dev_conn_slot1_id,
                x.slot2_id 	as inter_dev_conn_slot2_id,
                pc.slot1_id,
                pc.slot2_id,
		pc.slot2_id || x.array_path as array_path,
		pc.slot2_id = ANY(x.array_path) as cycle
	FROM    var_recurse x
	        inner join physical_connection pc
	                on x.slot2_id = pc.slot1_id
) select
	level,
	inter_component_connection_id,
	inter_component_connection_id as layer1_connection_id,
	PHYSICAL_CONNECTION_ID,
	inter_dev_conn_slot1_id,
	inter_dev_conn_slot2_id,
	inter_dev_conn_slot1_id as layer1_physical_port1_id,
	inter_dev_conn_slot2_id as layer1_physical_port2_id,
	slot1_id,
	slot2_id,
	slot1_id as physical_port1_id,
	slot2_id as physical_port2_id
from var_recurse;
