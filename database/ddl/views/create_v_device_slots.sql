CREATE OR REPLACE VIEW jazzhands.v_device_slots (
	device_id,
	device_component_id,
	component_id,
	slot_id) AS
WITH RECURSIVE device_slots (device_id, device_component_id, component_id, slot_id) AS (
	SELECT
		d.device_id,
		c.component_id, 
		c.component_id, 
		s.slot_id
	FROM
		device d JOIN
		component c USING (component_id) JOIN
		slot s USING (component_id)
	UNION
	SELECT
		p.device_id, 
		p.device_component_id,
		c.component_id,
		s.slot_id
	FROM
		device_slots p JOIN
		component c ON (p.slot_id = c.parent_slot_id) JOIN
		slot s ON (s.component_id = c.component_id)
	WHERE
		c.component_id NOT IN (
			SELECT component_id FROM device where component_id IS NOT NULL
		)
)
SELECT * FROM device_slots;
