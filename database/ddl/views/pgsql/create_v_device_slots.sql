CREATE OR REPLACE VIEW jazzhands.v_device_slots (
	device_id,
	device_component_id,
	component_id,
	slot_id) AS
SELECT
	d.device_id,
	d.component_id,
	dc.component_id,
	s.slot_id
FROM
	jazzhands.device d
	JOIN jazzhands_cache.ct_device_components dc USING (device_id)
	JOIN slot s ON (dc.component_id = s.component_id);
