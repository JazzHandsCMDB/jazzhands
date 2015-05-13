CREATE OR REPLACE VIEW jazzhands.v_component_hier (
	component_id,
	child_component_id,
	component_path,
	level
	) AS
WITH RECURSIVE component_hier (
		component_id,
		child_component_id,
		slot_id,
		component_path
) AS (
	SELECT
		c.component_id, 
		c.component_id, 
		s.slot_id,
		ARRAY[c.component_id]::integer[]
	FROM
		component c LEFT JOIN
		slot s USING (component_id)
	UNION
	SELECT
		p.component_id,
		c.component_id,
		s.slot_id,
		array_prepend(c.component_id, p.component_path)
	FROM
		component_hier p JOIN
		component c ON (p.slot_id = c.parent_slot_id) LEFT JOIN
		slot s ON (s.component_id = c.component_id)
)
SELECT DISTINCT component_id, child_component_id, component_path, array_length(component_path, 1) FROM component_hier;

