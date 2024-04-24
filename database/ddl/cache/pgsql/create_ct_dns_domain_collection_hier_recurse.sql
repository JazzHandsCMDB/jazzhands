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
CREATE OR REPLACE VIEW jazzhands_cache.v_dns_domain_collection_hier_recurse
AS
WITH RECURSIVE var_recurse (
	leaf_dns_domain_collection_id,
	dns_domain_collection_id,
	path,
	cycle
) as (
	SELECT
		b.dns_domain_collection_id				AS leaf_dns_domain_collection_id,
		b.dns_domain_collection_id				AS dns_domain_collection_id,
		ARRAY[b.dns_domain_collection_id]		AS path,
		false									AS cycle
	  FROM	dns_domain_collection b
UNION ALL
	SELECT
		x.leaf_dns_domain_collection_id				AS leaf_dns_domain_collection_id,
		h.dns_domain_collection_id					AS dns_domain_collection_id,
		x.path || h.dns_domain_collection_id		AS path,
		h.dns_domain_collection_id = ANY(x.path)	AS cycle
	  FROM	var_recurse x
		JOIN dns_domain_collection_hier h
			ON x.dns_domain_collection_id = h.child_dns_domain_collection_id
	WHERE	NOT x.cycle
) SELECT
			leaf_dns_domain_collection_id	AS dns_domain_collection_id,
			dns_domain_collection_id		AS root_dns_domain_collection_id,
			path,
			array_length(path, 1)			AS dns_domain_collection_level,
			cycle
  from		var_recurse
;

SELECT * FROM schema_support.create_cache_table(
	cache_table_schema := 'jazzhands_cache',
	cache_table := 'ct_dns_domain_collection_hier_recurse',
	defining_view_schema := 'jazzhands_cache',
	defining_view := 'v_dns_domain_collection_hier_recurse',
	create_options := '{
		"create_augment": {
			"dns_domain_collection_level": "GENERATED ALWAYS AS ( array_length(path, 1) ) STORED"
		}
	}',
	force := true
);


ALTER TABLE jazzhands_cache.ct_dns_domain_collection_hier_recurse
	ADD PRIMARY KEY (path);

CREATE INDEX ix_dns_domain_collection_hier_recurse_root_id  ON
	jazzhands_cache.ct_dns_domain_collection_hier_recurse
	(root_dns_domain_collection_id);

CREATE INDEX ix_dns_domain_collection_hier_recurse_leaf_Id  ON
	jazzhands_cache.ct_dns_domain_collection_hier_recurse
	(dns_domain_collection_id);

-- Thanks to slackoverflow :
-- https://stackoverflow.com/questions/4058731/can-postgresql-index-array-columns
--
-- note that @> needs to be used instead of ANY to take advangage of this
-- indexing.
--
CREATE INDEX ix_dns_domain_collection_hier_recurse_path
	ON jazzhands_cache.ct_dns_domain_collection_hier_recurse USING GIN
	(path array_ops);

CREATE OR REPLACE FUNCTION
	jazzhands_cache.ct_dns_domain_collection_hier_recurse_base_handler()
RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'DELETE' THEN
		DELETE FROM jazzhands_cache.ct_dns_domain_collection_hier_recurse
		WHERE root_dns_domain_collection_id = OLD.dns_domain_collection_id
		AND dns_domain_collection_id = OLD.dns_domain_collection_id;

		RETURN OLD;
	ELSIF TG_OP = 'UPDATE' THEN
		UPDATE jazzhands_cache.ct_dns_domain_collection_hier_recurse
		SET
			root_dns_domain_collection_id = NEW.dns_domain_collection_id,
			dns_domain_collection_id = NEW.dns_domain_collection_id
		WHERE root_dns_domain_collection_id = OLD.dns_domain_collection_id
		AND dns_domain_collection_id = OLD.dns_domain_collection_id;
	ELSIF TG_OP = 'INSERT' THEN
		INSERT INTO jazzhands_cache.ct_dns_domain_collection_hier_recurse (
			root_dns_domain_collection_id,
			dns_domain_collection_id,
			path,
			cycle
		) VALUES (
			NEW.dns_domain_collection_id,
			NEW.dns_domain_collection_id,
			ARRAY[NEW.dns_domain_collection_id],
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

DROP TRIGGER IF EXISTS aaa_ct_dns_domain_collection_hier_recurse_base_handler
ON jazzhands.dns_domain_collection;


CREATE TRIGGER aaa_ct_dns_domain_collection_hier_recurse_base_handler
AFTER INSERT OR DELETE OR UPDATE OF dns_domain_collection_id
ON jazzhands.dns_domain_collection
FOR EACH ROW
EXECUTE PROCEDURE
	jazzhands_cache.ct_dns_domain_collection_hier_recurse_base_handler();

-----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION jazzhands_cache.dns_domain_collection_hier_recurse_handler()
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
		DELETE FROM jazzhands_cache.ct_dns_domain_collection_hier_recurse
			WHERE path IN  (
				SELECT path FROM (
					SELECT * FROM (
						SELECT path, unnest(path) as first,
							unnest(pathplus) as second
							--, row_number() over () as rn
						FROM (
							SELECT path, path[2:array_length(path, 1)] AS pathplus
							FROM jazzhands_cache.ct_dns_domain_collection_hier_recurse
						) i
					) rmme WHERE second = OLD.dns_domain_collection_id
					AND first = OLD.child_dns_domain_collection_id
				) rmpath
			)
			RETURNING *
		LOOP
			RAISE DEBUG '-> ddchd rm %', to_json(_r);
		END LOOP
		;
		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Deleting upstream references to accol %/% from cache == %',
			OLD.dns_domain_collection_id, OLD.child_dns_domain_collection_id, _cnt;
	END IF;

	--
	-- Insert any new rows to correspond with a new parent
	--
	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
		RAISE DEBUG 'ddchd %%Insert: %', to_json(NEW);

		--- @> should use the GIN index.  ANY, not so much
		FOR _r IN
			SELECT DISTINCT
				p.path as parent_path, c.path as child_path,
				c.dns_domain_collection_id AS dns_domain_collection_id,
				p.root_dns_domain_collection_id AS root_dns_domain_collection_id,
				c.path || p.path as path,
				p.path @> ARRAY[NEW.child_dns_domain_collection_id]  OR
					c.path @> ARRAY[NEW.dns_domain_collection_id] AS cycle
			FROM	jazzhands_cache.ct_dns_domain_collection_hier_recurse p,
				jazzhands_cache.ct_dns_domain_collection_hier_recurse c
			WHERE p.dns_domain_collection_id = NEW.dns_domain_collection_id
			AND c.root_dns_domain_collection_id = NEW.child_dns_domain_collection_id
		LOOP
			RAISE DEBUG 'ddchd: i/dsmash:%', to_json(_r);
			IF _r.cycle THEN
				RAISE EXCEPTION 'This creates an infite loop'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
			INSERT INTO jazzhands_cache.ct_dns_domain_collection_hier_recurse (
					root_dns_domain_collection_id,
					dns_domain_collection_id,
					path,
					cycle
				) VALUES (
					_r.root_dns_domain_collection_id,
					_r.dns_domain_collection_id,
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

DROP TRIGGER IF EXISTS aaa_dns_domain_collection_hier_recurse_handler
ON jazzhands.dns_domain_collection_hier;

CREATE TRIGGER aaa_dns_domain_collection_hier_recurse_handler
AFTER INSERT OR DELETE OR
	UPDATE OF dns_domain_collection_id, child_dns_domain_collection_id
ON jazzhands.dns_domain_collection_hier
FOR EACH ROW
EXECUTE PROCEDURE jazzhands_cache.dns_domain_collection_hier_recurse_handler();

CREATE OR REPLACE VIEW jazzhands.v_dns_domain_collection_hier_descendent  AS
SELECT dns_domain_collection_id, descendent_dns_domain_collection_id, dns_domain_collection_level
FROM (
	SELECT
		root_dns_domain_collection_id	AS  dns_domain_collection_id,
		dns_domain_collection_id		AS  descendent_dns_domain_collection_id,
		array_length(path, 1)			AS  dns_domain_collection_level,
		path							AS  dns_domain_collection_path,
		row_number() OVER (PARTITION BY
			root_dns_domain_collection_id, dns_domain_collection_id
			ORDER BY array_length(path,1)) AS rnk
	FROM jazzhands_cache.ct_dns_domain_collection_hier_recurse
) h
WHERE rnk = 1;

COMMENT ON VIEW jazzhands.v_dns_domain_collection_hier_descendent IS
	'All descendent dns_domain collections of a given dns_domain collection';

CREATE OR REPLACE VIEW jazzhands.v_dns_domain_collection_hier_ancestor  AS
SELECT dns_domain_collection_id,
	ancestor_dns_domain_collection_id,
	dns_domain_collection_level,
	dns_domain_collection_path
FROM (
	SELECT
		dns_domain_collection_id			AS  dns_domain_collection_id,
		root_dns_domain_collection_id		AS  ancestor_dns_domain_collection_id,
		array_length(path, 1)				AS  dns_domain_collection_level,
		path								AS	dns_domain_collection_path,
		row_number() OVER (PARTITION BY
			dns_domain_collection_id, root_dns_domain_collection_id
			ORDER BY array_length(path,1)) AS rnk
	FROM jazzhands_cache.ct_dns_domain_collection_hier_recurse
) h
WHERE rnk = 1;

COMMENT ON VIEW jazzhands.v_dns_domain_collection_hier_ancestor IS
	'All ancestors of a given dns_domain collection';

CREATE OR REPLACE VIEW jazzhands.v_dns_domain_collection_dns_domain_descendent AS
SELECT
	dns_domain_collection_id,
	dns_domain_id,
	dns_domain_collection_level,
	dns_domain_collection_path
FROM (
	SELECT
		root_dns_domain_collection_id	AS	dns_domain_collection_id,
		dns_domain_id,
		dns_domain_collection_level,
		path AS dns_domain_collection_path,
		row_number() OVER (PARTITION BY root_dns_domain_collection_id,  dns_domain_id
			ORDER BY dns_domain_collection_level) AS rnk
	FROM jazzhands_cache.ct_dns_domain_collection_hier_recurse
			JOIN jazzhands.dns_domain_collection_dns_domain cm
				USING (dns_domain_collection_id)
) i
WHERE rnk = 1;

COMMENT ON VIEW jazzhands.v_dns_domain_collection_dns_domain_descendent IS
	'All dns_domains that are part of an dns_domain collection and (it''s descendent dns_domain collections, which is behind the scenes)';

CREATE OR REPLACE VIEW jazzhands.v_dns_domain_collection_dns_domain_ancestor AS
SELECT
	dns_domain_collection_id,
	dns_domain_id,
	dns_domain_collection_level,
	dns_domain_collection_path
FROM (
	SELECT
		r.dns_domain_collection_id	AS	dns_domain_collection_id,
		dns_domain_id, dns_domain_collection_level, path AS dns_domain_collection_path,
		row_number() OVER (PARTITION BY r.dns_domain_collection_id,  dns_domain_id
			ORDER BY dns_domain_collection_level) AS rnk
	FROM jazzhands_cache.ct_dns_domain_collection_hier_recurse r
			JOIN jazzhands.dns_domain_collection_dns_domain cm
				ON r.root_dns_domain_collection_id = cm.dns_domain_collection_id
) i
WHERE rnk = 1;

COMMENT ON VIEW jazzhands.v_dns_domain_collection_dns_domain_ancestor IS
	'All dns_domains that are part of an dns_domain collection and (it''s ancestor dns_domain collections, which is behind the scenes)';
