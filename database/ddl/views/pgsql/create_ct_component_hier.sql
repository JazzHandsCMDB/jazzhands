--
-- Copyright (c) 2015 Matthew Ragan
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
CREATE OR REPLACE VIEW jazzhands_cache.v_component_hier (
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

SELECT * FROM schema_support.create_cache_table(
	cache_table_schema := 'jazzhands_cache',
	cache_table := 'ct_component_hier',
	defining_view_schema := 'jazzhands_cache',
	defining_view := 'v_component_hier'
);

CREATE INDEX ix_component_hier_component_id ON 
	jazzhands_cache.ct_component_hier(component_id);

CREATE INDEX ix_component_hier_child_component_id ON 
	jazzhands_cache.ct_component_hier(child_component_id);

CREATE OR REPLACE FUNCTION jazzhands_cache.cache_component_parent_handler()
RETURNS TRIGGER AS $$
BEGIN
	RAISE DEBUG 'In jazzhands_cache.cache_component_parent_handler';
	RAISE DEBUG E'\nOLD is: %\nNEW is %\n',
		jsonb_pretty(to_jsonb(OLD)),
		jsonb_pretty(to_jsonb(NEW));
	--
	-- Delete any rows that are invalidated due to a parent change.
	--
	IF
		(TG_OP = 'DELETE' OR TG_OP = 'UPDATE') AND
		OLD.parent_slot_id IS NOT NULL
	THEN
		RAISE DEBUG 'Deleting upstream references to component % from cache',
			OLD.component_id;

		DELETE FROM
			jazzhands_cache.ct_component_hier
		WHERE
			OLD.component_id = ANY (component_path)
			AND component_id != OLD.component_id;
	END IF;

	--
	-- Insert any new rows to correspond with a new parent
	--

	IF
		(TG_OP = 'INSERT' OR TG_OP = 'UPDATE') AND
		NEW.parent_slot_id IS NOT NULL
	THEN
		RAISE DEBUG 'Inserting upstream references for component % into cache',
			OLD.component_id;

		INSERT INTO jazzhands_cache.ct_component_hier
		SELECT 
			ch.component_id,
			ch2.child_component_id,
			array_cat(ch2.component_path, ch.component_path),
			array_length(ch2.component_path, 1) + array_length(ch.component_path, 1)
		FROM
			jazzhands.slot s
			JOIN jazzhands_cache.ct_component_hier ch ON (
				s.component_id = ch.child_component_id
			),
			jazzhands_cache.ct_component_hier ch2
		WHERE
			s.slot_id = NEW.parent_slot_id
			AND ch2.component_id = NEW.component_id;
	END IF;
	RETURN NULL;
END
$$
LANGUAGE plpgsql
SECURITY DEFINER
;

--
-- Note: this trigger needs to fire before the one that updates
-- ct_device_components, since it needs to be accurate for that one to work
-- and not be really slow
--
DROP TRIGGER IF EXISTS aaa_tg_cache_component_parent_handler ON jazzhands.component;

CREATE TRIGGER aaa_tg_cache_component_parent_handler
AFTER INSERT OR DELETE OR UPDATE OF parent_slot_id ON jazzhands.component
FOR EACH ROW
EXECUTE PROCEDURE jazzhands_cache.cache_component_parent_handler();

CREATE OR REPLACE VIEW jazzhands.v_component_hier AS
SELECT * FROM jazzhands_cache.ct_component_hier;
