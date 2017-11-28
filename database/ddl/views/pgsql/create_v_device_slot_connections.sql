CREATE OR REPLACE VIEW jazzhands.v_device_slot_connections (
	inter_component_connection_id,
	device_id,
	slot_id,
	slot_name,
	slot_index,
	mac_address,
	slot_type_id,
	slot_type,
	slot_function,
	remote_device_id,
	remote_slot_id,
	remote_slot_name,
	remote_slot_index,
	remote_mac_address,
	remote_slot_type_id,
	remote_slot_type,
	remote_slot_function
) AS
WITH ds AS (
	SELECT
		s.slot_id,
		ds.device_id,
		s.slot_name,
		s.slot_index,
		s.mac_address,
		st.slot_type_id,
		st.slot_type,
		st.slot_function
	FROM
		jazzhands.slot s JOIN
		jazzhands.slot_type st USING (slot_type_id) LEFT JOIN
		jazzhands.v_device_slots ds USING (slot_id)
	WHERE
		st.slot_type_id IN (
			SELECT
				slot_type_id
			FROM
				jazzhands.slot_type_prmt_rem_slot_type
			UNION
			SELECT
				remote_slot_type_id
			FROM
				jazzhands.slot_type_prmt_rem_slot_type
		)
)
SELECT
	icc.inter_component_connection_id,
	s1.device_id,
	s1.slot_id,
	s1.slot_name,
	s1.slot_index,
	s1.mac_address,
	s1.slot_type_id,
	s1.slot_type,
	s1.slot_function,
	s2.device_id,
	s2.slot_id,
	s2.slot_name,
	s2.slot_index,
	s2.mac_address,
	s2.slot_type_id,
	s2.slot_type,
	s2.slot_function
FROM
	ds s1 JOIN
	jazzhands.inter_component_connection icc ON (s1.slot_id = slot1_id) JOIN
	ds s2 ON (s2.slot_id = slot2_id)
UNION
SELECT
	icc.inter_component_connection_id,
	s2.device_id,
	s2.slot_id,
	s2.slot_name,
	s2.slot_index,
	s2.mac_address,
	s2.slot_type_id,
	s2.slot_type,
	s2.slot_function,
	s1.device_id,
	s1.slot_id,
	s1.slot_name,
	s1.slot_index,
	s1.mac_address,
	s1.slot_type_id,
	s1.slot_type,
	s1.slot_function
FROM
	ds s1 JOIN
	jazzhands.inter_component_connection icc ON (s1.slot_id = slot1_id) JOIN
	ds s2 ON (s2.slot_id = slot2_id)
UNION
SELECT
	NULL::integer,
	s1.device_id,
	s1.slot_id,
	s1.slot_name,
	s1.slot_index,
	s1.mac_address,
	s1.slot_type_id,
	s1.slot_type,
	s1.slot_function,
	NULL::integer,
	NULL::integer,
	NULL::text,
	NULL::integer,
	NULL::macaddr,
	NULL::integer,
	NULL::text,
	NULL::text
FROM
	ds s1
WHERE
	s1.slot_id NOT IN (
		SELECT slot1_id FROM jazzhands.inter_component_connection UNION
		SELECT slot2_id FROM jazzhands.inter_component_connection
	);
