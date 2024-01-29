--
-- Copyright (c) 2023-2024 Todd M. Kover
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

\set ON_ERROR_STOP

/*
 * This is meant to recurse all the descendants of a node or all the ancestors
 * depending on how it is looked at.  "root" is the "oldest" ancestor,
 * leaf means "youngest".  Other views have historically used these
 * interchangably depending on how the newest works.
 *
 * NOTE:  path always set by order procssed, which is at the leaf "up" so
 * the leaf will always be first.
 *
 * NOTE:  I figured this all out on a plane.
 *
 * start at the _bottom_ and recurse _up_, then in the end swap how they
 * are presented because the "roto" is the "oldest" ancestor.
 */
CREATE OR REPLACE VIEW jazzhands_cache.v_device_collection_hier_recurse
AS
WITH RECURSIVE var_recurse (
	leaf_device_collection_id,
	device_collection_id,
	path,
	cycle
) as (
	SELECT
		b.device_collection_id					AS leaf_device_collection_id,
		b.device_collection_id					AS device_collection_id,
		ARRAY[b.device_collection_id]			AS path,
		false									AS cycle
	  FROM	device_collection b
UNION ALL
	SELECT
		x.leaf_device_collection_id				AS leaf_device_collection_id,
		h.device_collection_id					AS device_collection_id,
			x.path || h.device_collection_id	AS path,
		h.device_collection_id = ANY(x.path)	AS cycle
	  FROM	var_recurse x
		JOIN device_collection_hier h
			ON x.device_collection_id = h.child_device_collection_id
	WHERE	NOT x.cycle
) SELECT
			leaf_device_collection_id		AS device_collection_id,
			device_collection_id			AS root_device_collection_id,
			path,
			array_length(path, 1)			AS device_collection_level,
			cycle
  from			var_recurse
;

SELECT * FROM schema_support.create_cache_table(
	cache_table_schema := 'jazzhands_cache',
	cache_table := 'ct_device_collection_hier_recurse',
	defining_view_schema := 'jazzhands_cache',
	defining_view := 'v_device_collection_hier_recurse',
	create_options := '{
		"create_augment": {
			"device_collection_level": "GENERATED ALWAYS AS ( array_length(path, 1) ) STORED"
		}
	}',
	force := true
);


ALTER TABLE jazzhands_cache.ct_device_collection_hier_recurse
	ADD PRIMARY KEY (path);

CREATE INDEX ix_device_collection_hier_recurse_root_id  ON
	jazzhands_cache.ct_device_collection_hier_recurse
	(root_device_collection_id);

CREATE INDEX ix_device_collection_hier_recurse_leaf_Id  ON
	jazzhands_cache.ct_device_collection_hier_recurse
	(device_collection_id);

-- Thanks to slackoverflow :
-- https://stackoverflow.com/questions/4058731/can-postgresql-index-array-columns
--
-- note that @> needs to be used instead of ANY to take advangage of this
-- indexing.
--
CREATE INDEX ix_device_collection_hier_recurse_path
	ON jazzhands_cache.ct_device_collection_hier_recurse USING GIN
	(path array_ops);

CREATE OR REPLACE FUNCTION
	jazzhands_cache.ct_device_collection_hier_recurse_base_handler()
RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'DELETE' THEN
		DELETE FROM jazzhands_cache.ct_device_collection_hier_recurse
		WHERE root_device_collection_id = OLD.device_collection_id
		AND device_collection_id = OLD.device_collection_id;

		RETURN OLD;
	ELSIF TG_OP = 'UPDATE' THEN
		UPDATE jazzhands_cache.ct_device_collection_hier_recurse
		SET
			root_device_collection_id = NEW.device_collection_id,
			device_collection_id = NEW.device_collection_id
		WHERE root_device_collection_id = OLD.device_collection_id
		AND device_collection_id = OLD.device_collection_id;
	ELSIF TG_OP = 'INSERT' THEN
		INSERT INTO jazzhands_cache.ct_device_collection_hier_recurse (
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

DROP TRIGGER IF EXISTS aaa_ct_device_collection_hier_recurse_base_handler
ON jazzhands.device_collection;


CREATE TRIGGER aaa_ct_device_collection_hier_recurse_base_handler
AFTER INSERT OR DELETE OR UPDATE OF device_collection_id
ON jazzhands.device_collection
FOR EACH ROW
EXECUTE PROCEDURE
	jazzhands_cache.ct_device_collection_hier_recurse_base_handler();

-----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION jazzhands_cache.device_collection_hier_recurse_handler()
RETURNS TRIGGER AS $$
DECLARE
	_r		RECORD;
	_d		RECORD;
	_cnt	INTEGER;
BEGIN
	--
	-- Delete any rows that are invalidated due to a parent change.
	--
	IF
		(TG_OP = 'DELETE' OR TG_OP = 'UPDATE')
	THEN
		--
		-- This convoluted statement deletes anything where the path has the
		-- parent and child consective in the path array.  This is nasty.
		FOR _r IN
		DELETE FROM jazzhands_cache.ct_device_collection_hier_recurse
			WHERE path IN  (
				SELECT path FROM (
					SELECT * FROM (
						SELECT path, unnest(path) as first,
							unnest(pathplus) as second
							--, row_number() over () as rn
						FROM (
							SELECT path, path[2:array_length(path, 1)] AS pathplus
							FROM jazzhands_cache.ct_device_collection_hier_recurse
						) i
					) rmme WHERE second = OLD.device_collection_id
					AND first = OLD.child_device_collection_id
				) rmpath
			)
			RETURNING *
		LOOP
			RAISE DEBUG '-> dchd rm %', to_json(_r);
		END LOOP
		;
		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Deleting upstream references to accol %/% from cache == %',
			OLD.device_collection_id, OLD.child_device_collection_id, _cnt;
	END IF;

	--
	-- Insert any new rows to correspond with a new parent
	--
	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
		RAISE DEBUG 'dchd %%Insert: %', to_json(NEW);

		--- @> should use the GIN index.  ANY, not so much
		FOR _r IN
			SELECT DISTINCT
				p.path as parent_path, c.path as child_path,
				c.device_collection_id AS device_collection_id,
				p.root_device_collection_id AS root_device_collection_id,
				c.path || p.path as path,
				p.path @> ARRAY[NEW.child_device_collection_id]  OR
					c.path @> ARRAY[NEW.device_collection_id] AS cycle
			FROM	jazzhands_cache.ct_device_collection_hier_recurse p,
				jazzhands_cache.ct_device_collection_hier_recurse c
			WHERE p.device_collection_id = NEW.device_collection_id
			AND c.root_device_collection_id = NEW.child_device_collection_id
		LOOP
			RAISE DEBUG 'dchd: i/dsmash:%', to_json(_r);
			IF _r.cycle THEN
				RAISE EXCEPTION 'This creates an infite loop'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
			INSERT INTO jazzhands_cache.ct_device_collection_hier_recurse (
					root_device_collection_id,
					device_collection_id,
					path,
					cycle
				) VALUES (
					_r.root_device_collection_id,
					_r.device_collection_id,
					_r.path,
					_r.cycle
				) RETURNING * INTO _d ;
		END LOOP;
	END IF;

	RETURN NULL;
END
$$
LANGUAGE plpgsql
SET search_path=jazzhands
SECURITY DEFINER
;

DROP TRIGGER IF EXISTS aaa_device_collection_hier_recurse_handler
ON jazzhands.device_collection_hier;

CREATE TRIGGER aaa_device_collection_hier_recurse_handler
AFTER INSERT OR DELETE OR
	UPDATE OF device_collection_id, child_device_collection_id
ON jazzhands.device_collection_hier
FOR EACH ROW
EXECUTE PROCEDURE jazzhands_cache.device_collection_hier_recurse_handler();

CREATE OR REPLACE VIEW jazzhands.v_device_collection_hier_descendent  AS
SELECT device_collection_id, descendent_device_collection_id, device_collection_level
FROM (
	SELECT
		root_device_collection_id	AS  device_collection_id,
		device_collection_id		AS  descendent_device_collection_id,
		array_length(path, 1)		AS  device_collection_level,
		path						AS  device_collection_path,
		row_number() OVER (PARTITION BY
			root_device_collection_id, device_collection_id
			ORDER BY array_length(path,1)) AS rnk
	FROM jazzhands_cache.ct_device_collection_hier_recurse
) h
WHERE rnk = 1;

COMMENT ON VIEW jazzhands.v_device_collection_hier_descendent IS
	'All descendent device collections of a given device collection';

CREATE OR REPLACE VIEW jazzhands.v_device_collection_hier_ancestor  AS
SELECT device_collection_id,
	ancestor_device_collection_id,
	device_collection_level,
	device_collection_path
FROM (
	SELECT
		device_collection_id			AS  device_collection_id,
		root_device_collection_id		AS  ancestor_device_collection_id,
		array_length(path, 1)			AS  device_collection_level,
		path							AS	device_collection_path,
		row_number() OVER (PARTITION BY
			device_collection_id, root_device_collection_id
			ORDER BY array_length(path,1)) AS rnk
	FROM jazzhands_cache.ct_device_collection_hier_recurse
) h
WHERE rnk = 1;

COMMENT ON VIEW jazzhands.v_device_collection_hier_ancestor IS
	'All ancestors of a given device collection';

CREATE OR REPLACE VIEW jazzhands.v_device_collection_device_descendent AS
SELECT
	device_collection_id,
	device_id,
	device_collection_level,
	device_collection_path
FROM (
	SELECT
		root_device_collection_id	AS	device_collection_id,
		device_id,
		device_collection_level,
		path AS device_collection_path,
		row_number() OVER (PARTITION BY root_device_collection_id,  device_id
			ORDER BY device_collection_level) AS rnk
	FROM jazzhands_cache.ct_device_collection_hier_recurse
			JOIN jazzhands.device_collection_device cm
				USING (device_collection_id)
) i
WHERE rnk = 1;

COMMENT ON VIEW jazzhands.v_device_collection_device_descendent IS
	'All devices that are part of an device collection and (it''s descendent device collections, which is behind the scenes)';

CREATE OR REPLACE VIEW jazzhands.v_device_collection_device_ancestor AS
SELECT
	device_collection_id,
	device_id,
	device_collection_level,
	device_collection_path
FROM (
	SELECT
		r.device_collection_id	AS	device_collection_id,
		device_id, device_collection_level, path AS device_collection_path,
		row_number() OVER (PARTITION BY r.device_collection_id,  device_id
			ORDER BY device_collection_level) AS rnk
	FROM jazzhands_cache.ct_device_collection_hier_recurse r
			JOIN jazzhands.device_collection_device cm
				ON r.root_device_collection_id = cm.device_collection_id
) i
WHERE rnk = 1;

COMMENT ON VIEW jazzhands.v_device_collection_device_ancestor IS
	'All devices that are part of an device collection and (it''s ancestor device collections, which is behind the scenes)';
