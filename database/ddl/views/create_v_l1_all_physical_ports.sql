--
-- Copyright (c) 2015 Matthew Ragan, Todd M. Kover
-- All rights reserved.
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--      http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- This view is used to show all physical ports on a device and the ports
-- they are linked to, since this can go either way.

create or replace view v_l1_all_physical_ports as
WITH pp AS (
	SELECT
		sl.slot_id,
		ds.device_id,
		sl.slot_name,
		st.slot_function
	FROM
		slot sl JOIN
		slot_type st USING (slot_type_id) LEFT JOIN
		v_device_slots ds using (slot_id)
)
SELECT
	icc.inter_component_connection_id as layer1_connection_id,
	s1.slot_id as physical_port_id,
	s1.device_id as device_id,
	s1.slot_name as port_name,
	s1.slot_function as port_type,
	NULL as port_purpose,
	s2.slot_id as other_physical_port_id,
	s2.device_id as other_device_id,
	s2.slot_name as other_port_name,
	NULL as other_port_purpose,
	NULL::integer as baud,
	NULL::integer as data_bits,
	NULL::integer as stop_bits,
	NULL::varchar as parity,
	NULL::varchar as flow_control
FROM
	pp s1 JOIN
	inter_component_connection icc ON (s1.slot_id = icc.slot1_id) JOIN
	pp s2 ON (s2.slot_id = icc.slot2_id)
UNION	
SELECT
	icc.inter_component_connection_id as layer1_connection_id,
	s2.slot_id as physical_port_id,
	s2.device_id as device_id,
	s2.slot_name as port_name,
	s2.slot_function as port_type,
	NULL as port_purpose,
	s1.slot_id as other_physical_port_id,
	s1.device_id as other_device_id,
	s1.slot_name as other_port_name,
	NULL as other_port_purpose,
	NULL::integer as baud,
	NULL::integer as data_bits,
	NULL::integer as stop_bits,
	NULL::varchar as parity,
	NULL::varchar as flow_control
FROM
	pp s1 JOIN
	inter_component_connection icc ON (s1.slot_id = icc.slot1_id) JOIN
	pp s2 ON (s2.slot_id = icc.slot2_id)
UNION
SELECT
	NULL as layer1_connection_id,
	s1.slot_id as physical_port_id,
	s1.device_id as device_id,
	s1.slot_name as port_name,
	s1.slot_function as port_type,
	NULL as port_purpose,
	NULL as other_physical_port_id,
	NULL as other_device_id,
	NULL as other_port_name,
	NULL as other_port_purpose,
	NULL::integer as baud,
	NULL::integer as data_bits,
	NULL::integer as stop_bits,
	NULL::varchar as parity,
	NULL::varchar as flow_control
FROM
	pp s1 LEFT JOIN
	inter_component_connection icc ON (s1.slot_id = icc.slot1_id)
WHERE
	inter_component_connection_id IS NULL;
