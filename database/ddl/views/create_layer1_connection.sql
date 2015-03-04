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

create or replace view layer1_connection
AS
WITH conn_props AS (
	SELECT inter_component_connection_id,
			component_property_name, component_property_type,
			property_value
	FROM	component_property
	WHERE	component_property_type IN ('serial-connection')
), tcpsrv_device_id AS (
	SELECT inter_component_connection_id, device_id
	FROM	component_property
			INNER JOIN device USING (component_id)
	WHERE	component_property_type = 'tcpsrv-connections'
	AND		component_property_name = 'tcpsrv_device_id'
) , tcpsrv_enabled AS (
	SELECT inter_component_connection_id, property_value
	FROM	component_property
	WHERE	component_property_type = 'tcpsrv-connections'
	AND		component_property_name = 'tcpsrv_enabled'
) SELECT	
	icc.inter_component_connection_id  AS layer1_connection_id,
	icc.slot1_id			AS physical_port1_id,
	icc.slot2_id			AS physical_port2_id,
	icc.circuit_id,
	baud.property_value::integer			AS baud,
	dbits.property_value::integer		AS data_bits,
	sbits.property_value::integer		AS stop_bits,
	parity.property_value		AS parity,
	flow.property_value			AS flow_control,
	tcpsrv.device_id			AS tcpsrv_device_id,
	coalesce(tcpsrvon.property_value,'N')::char(1)	AS is_tcpsrv_enabled,
	icc.data_ins_user,
	icc.data_ins_date,
	icc.data_upd_user,
	icc.data_upd_date
FROM inter_component_connection icc
	INNER JOIN slot s1 ON icc.slot1_id = s1.slot_id
	INNER JOIN slot_type st1 ON st1.slot_type_id = s1.slot_type_id
	INNER JOIN slot s2 ON icc.slot2_id = s2.slot_id
	INNER JOIN slot_type st2 ON st2.slot_type_id = s2.slot_type_id
	LEFT JOIN tcpsrv_device_id tcpsrv USING (inter_component_connection_id)
	LEFT JOIN tcpsrv_enabled tcpsrvon USING (inter_component_connection_id)
	LEFT JOIN conn_props baud ON baud.inter_component_connection_id =
		icc.inter_component_connection_id AND
		baud.component_property_name = 'baud'
	LEFT JOIN conn_props dbits ON dbits.inter_component_connection_id =
		icc.inter_component_connection_id AND
		dbits.component_property_name = 'data-bits'
	LEFT JOIN conn_props sbits ON sbits.inter_component_connection_id =
		icc.inter_component_connection_id AND
		sbits.component_property_name = 'stop-bits'
	LEFT JOIN conn_props parity ON parity.inter_component_connection_id =
		icc.inter_component_connection_id AND
		parity.component_property_name = 'parity'
	LEFT JOIN conn_props flow ON flow.inter_component_connection_id =
		icc.inter_component_connection_id AND
		flow.component_property_name = 'flow-control'
 WHERE  st1.slot_function in ('network', 'serial', 'patchpanel')
	OR
 	st1.slot_function in ('network', 'serial', 'patchpanel')
;
