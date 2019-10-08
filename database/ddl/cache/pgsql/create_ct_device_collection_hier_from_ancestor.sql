--
-- Copyright (c) 2018-2019 Todd M. Kover
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

CREATE OR REPLACE VIEW jazzhands_cache.v_device_collection_hier_from_ancestor
AS
WITH RECURSIVE var_recurse (
	root_device_collection_id,
	device_collection_id,
	path,
	cycle
) as (
	SELECT
		u.device_collection_id		as root_device_collection_id,
		u.device_collection_id		as device_collection_id,
		ARRAY[u.device_collection_id]	as path,
		false							as cycle
	  FROM	device_collection u
UNION ALL
	SELECT
		x.root_device_collection_id		as root_device_collection_id,
		uch.child_device_collection_id	as device_collection_id,
		array_prepend(uch.child_device_collection_id, x.path) as path,
		uch.child_device_collection_id = ANY(x.path)			as cycle
	  FROM	var_recurse x
		inner join device_collection_hier uch
			on x.device_collection_id = uch.device_collection_id
	WHERE	NOT x.cycle
) SELECT	*
  from 		var_recurse
;


SELECT * FROM schema_support.create_cache_table(
	cache_table_schema := 'jazzhands_cache',
	cache_table := 'ct_device_collection_hier_from_ancestor',
	defining_view_schema := 'jazzhands_cache',
	defining_view := 'v_device_collection_hier_from_ancestor',
	force := true
);

ALTER TABLE jazzhands_cache.ct_device_collection_hier_from_ancestor
ADD
PRIMARY KEY (path);

CREATE INDEX ix_device_collection_hier_from_ancestor_id  ON
	jazzhands_cache.ct_device_collection_hier_from_ancestor(root_device_collection_id);

CREATE INDEX iix_device_collection_hier_from_ancestor_id ON
	jazzhands_cache.ct_device_collection_hier_from_ancestor(device_collection_id);

CREATE OR REPLACE FUNCTION jazzhands_cache.device_collection_base_handler()
RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'DELETE' THEN
		DELETE FROM jazzhands_cache.ct_device_collection_hier_from_ancestor
		WHERE root_device_collection_id = OLD.device_collection_id
		AND device_collection_id = OLD.device_collection_id;

		RETURN OLD;
	ELSIF TG_OP = 'UPDATE' THEN
		UPDATE jazzhands_cache.ct_device_collection_hier_from_ancestor
		SET
			root_device_collection_id = NEW.device_collection_id,
			device_collection_id = NEW.device_collection_id
		WHERE root_device_collection_id = OLD.device_collection_id
		AND device_collection_id = OLD.device_collection_id;
	ELSIF TG_OP = 'INSERT' THEN
		INSERT INTO jazzhands_cache.ct_device_collection_hier_from_ancestor (
			root_device_collection_id,
			device_collection_id,
			path,
			cycle
		) VALUES (
			NEW.device_collection_id,
			NEW.device_collection_id,
			ARRAY[NEW.device_collection_id],
			false
		);
	END IF;

	RETURN NEW;
END
$$
LANGUAGE plpgsql
SET search_path=jazzhands
SECURITY DEFINER
;

DROP TRIGGER IF EXISTS aaa_device_collection_base_handler
ON jazzhands.device_collection;

CREATE TRIGGER aaa_device_collection_base_handler
AFTER INSERT OR DELETE OR UPDATE OF device_collection_id
ON jazzhands.device_collection
FOR EACH ROW
EXECUTE PROCEDURE jazzhands_cache.device_collection_base_handler();



-----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION jazzhands_cache.device_collection_root_handler()
RETURNS TRIGGER AS $$
DECLARE
	_r		RECORD;
	_cnt	INTEGER;
BEGIN
	--
	-- Delete any rows that are invalidated due to a parent change.
	--
	IF
		(TG_OP = 'DELETE' OR TG_OP = 'UPDATE')
	THEN
		FOR _r IN
		DELETE FROM jazzhands_cache.ct_device_collection_hier_from_ancestor
		WHERE	OLD.device_collection_id = ANY (path)
		AND		OLD.child_device_collection_id = ANY (path)
		RETURNING *
		LOOP
			RAISE DEBUG '-> rm %', to_json(_r);
		END LOOP
		;
		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Deleting upstream references to netcoll %/% from cache == %',
			OLD.device_collection_id, OLD.child_device_collection_id, _cnt;
	END IF;


	--
	-- Insert any new rows to correspond with a new parent
	--
	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
		RAISE DEBUG '%%Insert: %', to_json(NEW);
		-- for the new collection/child, glue together all the ones that
		-- have device_collection_id = parent
		-- with those that have root_device_collection_id = child

		FOR _r IN
			SELECT
				p.path as parent_path, c.path as child_path,
				p.root_device_collection_id,
				c.device_collection_id,
				c.path || p.path as path,
				false AS cycle
			FROM	jazzhands_cache.ct_device_collection_hier_from_ancestor p,
				jazzhands_cache.ct_device_collection_hier_from_ancestor c
			WHERE p.device_collection_id = NEW.device_collection_id
			AND c.root_device_collection_id = NEW.child_device_collection_id
		LOOP
			RAISE DEBUG 'i/smash:%', to_json(_r);
			IF _r.cycle THEN
				RAISE EXCEPTION 'danger!  cycle!';
			END IF;
			INSERT INTO jazzhands_cache.ct_device_collection_hier_from_ancestor (
					root_device_collection_id,
					device_collection_id,
					path,
					cycle
				) VALUES (
					_r.root_device_collection_id,
					_r.device_collection_id,
					_r.path,
					_r.cycle
				);
		END LOOP;
	END IF;

	RETURN NULL;
END
$$
LANGUAGE plpgsql
SET search_path=jazzhands
SECURITY DEFINER
;

DROP TRIGGER IF EXISTS aaa_device_collection_root_handler
ON jazzhands.device_collection_hier;

CREATE TRIGGER aaa_device_collection_root_handler
AFTER INSERT OR DELETE OR
	UPDATE OF device_collection_id, child_device_collection_id
ON jazzhands.device_collection_hier
FOR EACH ROW
EXECUTE PROCEDURE jazzhands_cache.device_collection_root_handler();

CREATE OR REPLACE VIEW jazzhands.v_device_collection_hier_from_ancestor AS
SELECT * FROM jazzhands_cache.ct_device_collection_hier_from_ancestor;
