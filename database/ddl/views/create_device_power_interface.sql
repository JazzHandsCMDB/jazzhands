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

create or replace view device_power_interface
AS
WITH pdu AS (
	SELECT	slot_type_id, property_value::integer AS property_value
	FROM	component_property
	WHERE	component_property_type = 'PDU'
), provides AS (
	SELECT	slot_type_id, property_value
	FROM	component_property
	WHERE	component_property_type = 'power_supply'
	AND	component_property_name = 'Provides'
) SELECT	
	d.device_id,
	s.slot_name			AS power_interface_port,
	st.slot_physical_interface_type	AS power_plug_style,
	vlt.property_value		AS voltage,
	amp.property_value		AS max_amperage,
	p.property_value::text	AS provides_power,
	s.data_ins_user,
	s.data_ins_date,
	s.data_upd_user,
	s.data_upd_date
FROM	slot s
	INNER JOIN slot_type st USING (slot_type_id)
	INNER JOIN provides p USING (slot_type_id)
	INNER JOIN pdu vlt USING (slot_type_id)
	INNER JOIN pdu amp USING (slot_type_id)
	INNER JOIN v_device_slots d USING (slot_id)
WHERE slot_function = 'power'
;
