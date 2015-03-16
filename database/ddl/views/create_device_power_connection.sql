--
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
--
-- $Id$
--

create or replace view device_power_connection
AS
WITH slotdev AS (
	SELECT	slot_id, slot_name, device_id
	FROM	slot
		INNER JOIN v_device_slots USING (slot_id)
		INNER JOIN slot_type st USING (slot_type_id)
	WHERE	slot_function = 'power'
) SELECT	
	icc.inter_component_connection_id	AS device_power_connection_id,
	icc.inter_component_connection_id,
	s1.device_id				AS rpc_device_id,
	s1.slot_name				AS rpc_power_interface_port,
	s2.slot_name				AS power_interface_port,
	s2.device_id				AS device_id,
	icc.data_ins_user,
	icc.data_ins_date,
	icc.data_upd_user,
	icc.data_upd_date
FROM	inter_component_connection icc
	INNER JOIN slotdev s1 on icc.slot1_id = s1.slot_id
	INNER JOIN slotdev s2 on icc.slot2_id = s2.slot_id
;
