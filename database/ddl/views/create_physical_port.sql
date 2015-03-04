-- Copyright (c) 2015, Todd M. Kover, Matthew D. Ragan
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
-- XXX NOTE: need to migrate network_interface.physical_port_id
--

create or replace view physical_port
AS
SELECT	
	sl.slot_id			AS physical_port_id,
	d.device_id,
	sl.slot_name			AS port_name,
	st.slot_function		AS port_type,
	sl.description,
	st.slot_physical_interface_type	AS port_plug_style,
	NULL::text			AS port_medium,
	NULL::text			AS port_protocol,
	NULL::text			AS port_speed,
	sl.physical_label,
	NULL::text			AS port_purpose,
	NULL::integer			AS logical_port_id,
	NULL::integer			AS tcp_port,
	CASE WHEN ct.is_removable = 'Y' THEN 'N' ELSE 'Y' END AS is_hardwired,
	sl.data_ins_user,
	sl.data_ins_date,
	sl.data_upd_user,
	sl.data_upd_date
  FROM	slot sl 
	INNER JOIN slot_type st USING (slot_type_id)
	INNER JOIN v_device_slots d USING (slot_id)
	INNER JOIN component c ON (sl.component_id = c.component_id)
	INNER JOIN component_type ct USING (component_type_id)
 WHERE	st.slot_function in ('network', 'serial', 'patchpanel')
;
