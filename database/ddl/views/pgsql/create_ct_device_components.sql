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

CREATE OR REPLACE VIEW jazzhands_cache.v_device_components (
	device_id,
	component_id,
	component_path,
	level
) AS
SELECT
	device_id,
	component_id,
	component_path,
	level
FROM (
		SELECT
			device_id,
			child_component_id as component_id,
			component_path,
			level,
			MIN(level) OVER (PARTITION BY child_component_id) AS min_level
		FROM
			jazzhands_cache.ct_component_hier JOIN
			jazzhands.device d USING (component_id)
	) ch
WHERE
	level = min_level;

SELECT * FROM schema_support.create_cache_table(
	cache_table_schema := 'jazzhands_cache',
	cache_table := 'ct_device_components',
	defining_view_schema := 'jazzhands_cache',
	defining_view := 'v_device_components'
);

CREATE INDEX ix_device_components_component_id ON 
	jazzhands_cache.ct_device_components(component_id);

CREATE INDEX ix_device_components_device_id ON 
	jazzhands_cache.ct_device_components(device_id);

CREATE OR REPLACE FUNCTION jazzhands_cache.cache_device_component_device_handler()
RETURNS TRIGGER AS $$
BEGIN
	--
	-- Delete any rows that are invalidated due to a device un/reassignment
	--
	IF
		(TG_OP = 'DELETE' OR TG_OP = 'UPDATE') AND
		OLD.component_id IS NOT NULL
	THEN
		RAISE DEBUG 'Deleting device assignment for component % from cache',
			OLD.component_id;

		DELETE FROM
			jazzhands_cache.ct_device_components dc
		WHERE
			dc.device_id = OLD.device_id;
	END IF;

	--
	-- Insert any new rows to correspond with a new parent
	--

	IF
		(TG_OP = 'INSERT' OR TG_OP = 'UPDATE') AND
		NEW.component_id IS NOT NULL
	THEN
		RAISE DEBUG 'Inserting upstream references for component % into cache',
			NEW.component_id;

		INSERT INTO jazzhands_cache.ct_device_components (
			device_id,
			component_id,
			component_path,
			level
		) SELECT 
			NEW.device_id,
			ch.child_component_id,
			ch.component_path,
			ch.level
		FROM
			jazzhands_cache.ct_component_hier ch
		WHERE
			ch.component_id = NEW.component_id
			AND NOT (ch.child_component_id IN (
				SELECT
					component_id
				FROM
					jazzhands.device d
				WHERE
					d.component_id IS NOT NULL AND
					d.device_id != NEW.device_id
			));
	END IF;
	RETURN NULL;
END
$$
LANGUAGE plpgsql
SECURITY DEFINER
;

DROP TRIGGER IF EXISTS tg_cache_device_component_device_handler ON
	jazzhands.device;

CREATE TRIGGER tg_cache_device_component_device_handler
AFTER INSERT OR DELETE OR UPDATE OF component_id ON jazzhands.device
FOR EACH ROW
EXECUTE PROCEDURE jazzhands_cache.cache_device_component_device_handler();


CREATE OR REPLACE FUNCTION jazzhands_cache.cache_device_component_component_handler()
RETURNS TRIGGER AS $$
DECLARE
	dev_rec	RECORD;
	dc_rec	RECORD;
BEGIN
	--
	-- Delete any rows that are invalidated due to a parent slot un/reassignment
	--
	IF
		(TG_OP = 'DELETE' OR TG_OP = 'UPDATE') AND
		OLD.parent_slot_id IS NOT NULL
	THEN
		RAISE DEBUG 'Deleting device assignment for component % from cache',
			OLD.component_id;

		--
		-- If we're the top level of a device, nothing below it is going to
		-- change, so just return
		--
		PERFORM * FROM device d WHERE d.component_id = OLD.component_id;

		IF FOUND THEN
			RETURN NULL;
		END IF;
		--
		-- Only delete things belonging to this immediate device
		--
		SELECT * INTO dc_rec FROM jazzhands_cache.ct_device_components dc
		WHERE
			dc.component_id = OLD.component_id;

		IF dc_rec IS NOT NULL THEN
			DELETE FROM
				jazzhands_cache.ct_device_components dc
			WHERE
				OLD.component_id = ANY (component_path)
				AND dc.device_id = dc_rec.device_id;
		END IF;
	END IF;

	--
	-- Insert any new rows to correspond with a new parent
	--

	IF
		(TG_OP = 'INSERT' OR TG_OP = 'UPDATE') AND
		NEW.parent_slot_id IS NOT NULL
	THEN
		RAISE DEBUG 'Inserting upstream device references for component % into cache',
			NEW.component_id;

		
		SELECT d.* INTO dev_rec
		FROM
			jazzhands.slot s JOIN
			jazzhands_cache.v_device_components dc USING (component_id) JOIN
			device d USING (device_id)
		WHERE
			s.slot_id = NEW.parent_slot_id;

		IF FOUND THEN
			INSERT INTO jazzhands_cache.ct_device_components (
				device_id,
				component_id,
				component_path,
				level
			) SELECT 
				dev_rec.device_id,
				ch.child_component_id,
				ch.component_path,
				ch.level
			FROM
				jazzhands_cache.ct_component_hier ch
			WHERE
				ch.component_id = dev_rec.component_id
				AND NEW.component_id = ANY(component_path)
				AND NOT (ch.child_component_id IN (
					SELECT
						component_id
					FROM
						jazzhands.device d
					WHERE
						d.component_id IS NOT NULL AND
						d.device_id != dev_rec.device_id
				));
		END IF;
	END IF;
	RETURN NULL;
END
$$
LANGUAGE plpgsql
SECURITY DEFINER
;

DROP TRIGGER IF EXISTS aab_tg_cache_device_component_component_handler ON
	jazzhands.component;

CREATE TRIGGER aab_tg_cache_device_component_component_handler
AFTER INSERT OR DELETE OR UPDATE OF parent_slot_id ON jazzhands.component
FOR EACH ROW
EXECUTE PROCEDURE jazzhands_cache.cache_device_component_component_handler();

CREATE OR REPLACE VIEW jazzhands.v_device_components AS
SELECT * FROM jazzhands_cache.ct_device_components;
