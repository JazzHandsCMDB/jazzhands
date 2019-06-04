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

CREATE OR REPLACE VIEW jazzhands_cache.v_netblock_hier AS
WITH RECURSIVE var_recurse (
	root_netblock_id,
	intermediate_netblock_id,
	netblock_id,
	path
) AS (
	SELECT netblock_id as root_netblock_id,
		netblock_id as intermediate_netblock_id,
		netblock_id,
		ARRAY[netblock_id] as path
	FROM	netblock
		WHERE is_single_address = 'N'
UNION
	SELECT p.root_netblock_id,
		n.parent_netblock_id,
		n.netblock_id,
		array_prepend(n.netblock_id, path)
	FROM var_recurse p
		JOIN netblock n
			ON p.netblock_id = n.parent_netblock_id
	WHERE n.is_single_address = 'N'
) SELECT * FROM var_recurse;

SELECT * FROM schema_support.create_cache_table(
        cache_table_schema := 'jazzhands_cache',
        cache_table := 'ct_netblock_hier',
        defining_view_schema := 'jazzhands_cache',
        defining_view := 'v_netblock_hier'
);


CREATE INDEX ix_netblock_hier_netblock_root_id ON
	jazzhands_cache.ct_netblock_hier(root_netblock_id);

CREATE INDEX ix_netblock_hier_netblock_intermediate_id ON
	jazzhands_cache.ct_netblock_hier(intermediate_netblock_id);

CREATE INDEX ix_netblock_hier_netblock_netblock_id ON
	jazzhands_cache.ct_netblock_hier(netblock_id);

CREATE INDEX ix_netblock_hier_netblock_path ON
	jazzhands_cache.ct_netblock_hier(path);

ALTER TABLE jazzhands_cache.ct_netblock_hier
ADD
PRIMARY KEY (path);


CREATE OR REPLACE FUNCTION jazzhands_cache.cache_netblock_hier_handler()
RETURNS TRIGGER AS $$
DECLARE
	_cnt	INTEGER;
	_r		RECORD;
BEGIN
	IF NEW.is_single_address = 'Y' THEN
		RETURN NULL;
	END IF;
	--
	-- Delete any rows that are invalidated due to a parent change.
	--
	IF TG_OP = 'DELETE' THEN
		FOR _r IN
		DELETE FROM jazzhands_cache.ct_netblock_hier
		WHERE	OLD.netblock_id = ANY(path)
		RETURNING *
		LOOP
			RAISE DEBUG '-> rm/DEL %', to_json(_r);
		END LOOP;
		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Deleting upstream references to netblock % from cache == %',
			OLD.netblock_id, _cnt;
	ELSIF TG_OP = 'UPDATE' AND OLD.parent_netblock_id IS NOT NULL THEN
		FOR _r IN
		DELETE FROM jazzhands_cache.ct_netblock_hier
		WHERE	OLD.parent_netblock_id IS NOT NULL
					AND		OLD.parent_netblock_id = ANY (path)
					AND		OLD.netblock_id = ANY (path)
					AND		netblock_id = OLD.netblock_id
		RETURNING *
		LOOP
			RAISE DEBUG '-> rm/upd %', to_json(_r);
		END LOOP;
		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Deleting upstream references to netblock %/% from cache == %',
			OLD.netblock_id, OLD.parent_netblock_id, _cnt;
	END IF;

	--
	-- Insert any new rows to correspond with a new parent
	--


	IF TG_OP IN ('INSERT') THEN
		RAISE DEBUG 'Inserting reference for new netblock % into cache [%]',
			NEW.netblock_id, NEW.parent_netblock_id;

		FOR _r IN
		WITH RECURSIVE tier (
			root_netblock_id,
			intermediate_netblock_id,
			netblock_id,
			path
		)AS (
			SELECT parent_netblock_id,
				parent_netblock_id,
				netblock_id,
				ARRAY[netblock_id, parent_netblock_id]
			FROM netblock WHERE netblock_id = NEW.netblock_id
			AND parent_netblock_id IS NOT NULL
		UNION ALL
			SELECT n.parent_netblock_id,
				tier.intermediate_netblock_id,
				tier.netblock_id,
				array_append(tier.path, n.parent_netblock_id)
			FROM tier
				JOIN netblock n ON n.netblock_id = tier.root_netblock_id
			WHERE n.parent_netblock_id IS NOT NULL
		), combo AS (
			 SELECT * FROM tier
			UNION ALL
			SELECT netblock_id, netblock_id, netblock_id, ARRAY[netblock_id]
			FROM netblock WHERE netblock_id = NEW.netblock_id
		) SELECT * FROM combo
		LOOP
			RAISE DEBUG 'nb/ins up %', to_json(_r);
			INSERT INTO jazzhands_cache.ct_netblock_hier (
				root_netblock_id, intermediate_netblock_id, 
				netblock_id, path
			) VALUES (
				_r.root_netblock_id, _r.intermediate_netblock_id, 
				_r.netblock_id, _r.path
			);
		END LOOP;

	ELSIF (TG_OP = 'UPDATE' AND NEW.parent_netblock_id IS NOT NULL) THEN

		FOR _r IN
		WITH base AS (
			SELECT *
			FROM jazzhands_cache.ct_netblock_hier
			WHERE NEW.netblock_id = ANY (path)
			AND array_length(path, 1) > 2

		), inew AS (
			INSERT INTO jazzhands_cache.ct_netblock_hier (
				root_netblock_id,
				intermediate_netblock_id,
				netblock_id,
				path
			)  SELECT
				base.root_netblock_id,
				NEW.parent_netblock_id,
				netblock_id,
				array_cat(
					array_cat(
						path[: (array_position(path, NEW.netblock_id)-1)],
						ARRAY[NEW.netblock_id, NEW.parent_netblock_id]
					),
					path[(array_position(path, NEW.netblock_id)+1) :]
				)
				FROM base
				RETURNING *
		), uold AS (
			UPDATE jazzhands_cache.ct_netblock_hier n
			SET root_netblock_id = base.root_netblock_id,
				intermediate_netblock_id = NEW.parent_netblock_id,
			path = array_replace(base.path, base.root_netblock_id, NEW.parent_netblock_id)
			FROM base
			WHERE n.path = base.path
				RETURNING n.*
		) SELECT 'ins' as "what", * FROM inew
			UNION
			SELECT 'upd' as "what", * FROM uold

		LOOP
			RAISE DEBUG 'down:%', to_json(_r);
		END LOOP;

		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Inserting upstream references down for updated netblock %/% into cache == %',
			NEW.netblock_id, NEW.parent_netblock_id, _cnt;

		-- walk up and install rows for all the things above due to change
		FOR _r IN
		WITH RECURSIVE tier (
			root_netblock_id,
			intermediate_netblock_id,
			netblock_id,
			path,
			cycle
		)AS (
			SELECT parent_netblock_id,
                parent_netblock_id,
                netblock_id,
                ARRAY[netblock_id, parent_netblock_id],
                false
            FROM netblock WHERE netblock_id = NEW.netblock_id
        UNION ALL
            SELECT n.parent_netblock_id,
                n.netblock_Id,
                tier.netblock_id,
                array_append(tier.path, n.parent_netblock_id),
                n.parent_netblock_id = ANY(path)
            FROM tier
                JOIN netblock n ON n.netblock_id = tier.root_netblock_id
            WHERE n.parent_netblock_id IS NOT NULL
			AND NOT cycle
        ) SELECT * FROM tier
		LOOP
			IF _r.cycle THEN
				RAISE EXCEPTION 'Insert Created a netblock loop.'
					USING ERRCODE = 'JH101';
			END IF;
			INSERT INTO jazzhands_cache.ct_netblock_hier (
				root_netblock_id, intermediate_netblock_id, netblock_id, path
			) VALUES (
				_r.root_netblock_id, _r.intermediate_netblock_id, _r.netblock_id, _r.path
			);

			RAISE DEBUG 'nb/upd up %', to_json(_r);
		END LOOP;
		get diagnostics _cnt = row_count;
		RAISE DEBUG 'Inserting upstream references up for updated netblock %/% into cache == %',
			NEW.netblock_id, NEW.parent_netblock_id, _cnt;
	END IF;
	RETURN NULL;
END
$$
LANGUAGE plpgsql
SET search_path=jazzhands
SECURITY DEFINER
;

--
-- must fire after the other netblock triggers rejigger things
--
DROP TRIGGER IF EXISTS zaa_ta_cache_netblock_hier_handler
	ON jazzhands.netblock;

CREATE TRIGGER zaa_ta_cache_netblock_hier_handler
	AFTER INSERT OR DELETE OR UPDATE OF parent_netblock_id
	ON jazzhands.netblock
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_cache.cache_netblock_hier_handler();

------------------------------------------------------------------------------
--
-- This is to support tests
--
CREATE OR REPLACE FUNCTION jazzhands_cache.cache_netblock_hier_truncate_handler()
RETURNS TRIGGER AS $$
BEGIN
	TRUNCATE TABLE jazzhands_cache.ct_netblock_hier;
	RETURN NULL;
END
$$
LANGUAGE plpgsql
SET search_path=jazzhands
SECURITY DEFINER
;

DROP TRIGGER IF EXISTS trigger_cache_netblock_hier_truncate
	ON jazzhands.netbock;

CREATE TRIGGER  trigger_cache_netblock_hier_truncate
	AFTER TRUNCATE
	ON jazzhands.netblock
	EXECUTE PROCEDURE jazzhands_cache.cache_netblock_hier_truncate_handler();
------------------------------------------------------------------------------

--
-- This is becoming the real one on in 0.86 but need to adjust
-- appropriately in 0.85.
--
-- CREATE VIEW jazzhandse.v_netblock_hier AS
-- SELECT * FROM jazzhands_cache.v_netblock_hier;
