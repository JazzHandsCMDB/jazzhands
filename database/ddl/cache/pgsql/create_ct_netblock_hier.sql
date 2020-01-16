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
        defining_view := 'v_netblock_hier',
	force := true
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


-- This is handy when debugging but if left here it will likely trigger
-- duplicate rows...
-- ALTER SEQUENCE netblock_netblock_id_seq restart WITH 100000;

CREATE OR REPLACE FUNCTION jazzhands_cache.cache_netblock_hier_handler()
RETURNS TRIGGER AS $$
DECLARE
	_cnt	INTEGER;
	_r		RECORD;
	_n		RECORD;
BEGIN
	IF TG_OP IN ('UPDATE','INSERT') AND NEW.is_single_address = 'Y' THEN
		RETURN NULL;
	END IF;

	IF TG_OP IN ('DELETE','UPDATE') THEN
		RAISE DEBUG 'ENTER cache_netblock_hier_handler OLD: % %',
			TG_OP, to_json(OLD);
	END IF;
	IF TG_OP IN ('INSERT','UPDATE') THEN
		RAISE DEBUG 'ENTER cache_netblock_hier_handler NEW: % %',
			TG_OP, to_json(NEW);
		IF NEW.parent_netblock_id IS NOT NULL AND NEW.netblock_id = NEW.parent_netblock_id THEN
			RAISE DEBUG 'aborting because this row is self referrential';
			RETURN NULL;
		END IF;
	END IF;

	--
	-- Delete any rows that are invalidated due to a parent change.
	-- Any parent change means recreating all the rows related to the node
	-- that changes; due to how the netblock triggers work, this may result
	-- in records being changed multiple times.
	--
	IF TG_OP = 'DELETE' OR
		(
			TG_OP = 'UPDATE' AND OLD.parent_netblock_id IS NOT NULL
		)
	THEN
		RAISE DEBUG '% cleanup for %, % [%]',
			TG_OP, OLD.netblock_id, OLD.parent_netblock_id, OLD.ip_address;
		FOR _r IN
		DELETE FROM jazzhands_cache.ct_netblock_hier
		WHERE	OLD.netblock_id = ANY(path)
		RETURNING *
		LOOP
			RAISE DEBUG '-> rm/DEL %', to_json(_r);
		END LOOP;
		get diagnostics _cnt = row_count;
		RAISE DEBUG 'nbcache: Deleting upstream references to netblock % from cache == %',
			OLD.netblock_id, _cnt;
	ELSIF TG_OP = 'INSERT' THEN
		FOR _r IN
		DELETE FROM jazzhands_cache.ct_netblock_hier
		-- WHERE	NEW.netblock_id = ANY(path)
		WHERE root_netblocK_id = NEW.netblock_id
		RETURNING *
		LOOP
			RAISE DEBUG '-> rm/INS?! %', to_json(_r);
		END LOOP;
	END IF;


	--
	-- XXX deal with parent becoming NULL!
	--

	IF TG_OP IN ('INSERT', 'UPDATE') THEN
		RAISE DEBUG 'nbcache: % reference for new netblock %, % [%]',
			TG_OP, NEW.netblock_id, NEW.parent_netblock_id, NEW.ip_address;

		--
		-- This runs even if parent_netblock_id is NULL in order to get the
		-- row that includes the netblock into itself.
		--
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

		FOR _r IN
			SELECT h.*, ip_address
			FROM jazzhands_cache.ct_netblock_hier h
				JOIN netblock n ON
					n.netblock_id = h.root_netblock_id
			AND n.parent_netblock_id = NEW.netblock_id
			-- AND array_length(path, 1) > 1
		LOOP
			RAISE DEBUG 'nb/ins from %', to_json(_r);
			_r.root_netblock_id := NEW.netblock_id;
			IF array_length(_r.path, 1) = 1 THEN
				_r.intermediate_netblock_id := NEW.netblock_id;
			ELSE
				_r.intermediate_netblock_id := _r.intermediate_netblock_id;
			END IF;
			_r.netblock_id := _r.netblock_id;
			_r.path := array_append(_r.path, NEW.netblock_id);

			RAISE DEBUG '... %', to_json(_r);
			INSERT INTO jazzhands_cache.ct_netblock_hier (
				root_netblock_id, intermediate_netblock_id,
				netblock_id, path
			) VALUES (
				_r.root_netblock_id, _r.intermediate_netblock_id,
				_r.netblock_id, _r.path
			);
		END LOOP;

		--
		-- now combine all the kids and all the parents with this row in
		-- the middle
		--
		IF TG_OP = 'INSERT' THEN
			FOR _r IN
				SELECT
					hpar.root_netblock_id,
					hkid.intermediate_netblock_id as intermediate_netblock_id,
					hkid.netblock_id,
					array_cat( hkid.path, hpar.path[2:]) as path,
					hkid.path as hkid_path,
					hpar.path as hpar_path
				FROM jazzhands_cache.ct_netblock_hier hkid
					JOIN jazzhands_cache.ct_netblock_hier hpar
						ON hkid.root_netblock_id = hpar.netblock_id
				WHERE hpar.netblock_id = NEW.netblock_id
				AND array_length(hpar.path, 1) > 1
				AND array_length(hkid.path, 1) > 2
			LOOP
				RAISE DEBUG 'XXX nb ins/comp: %', to_json(_r);
				INSERT INTO jazzhands_cache.ct_netblock_hier (
					root_netblock_id, intermediate_netblock_id,
					netblock_id, path
				) VALUES (
					_r.root_netblock_id, _r.intermediate_netblock_id,
					_r.netblock_id, _r.path
				);
				END LOOP;
		END IF;
	END IF;
	RAISE DEBUG 'EXIT jazzhands_cache.cache_netblock_hier_handler';
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

--
-- If I do not have ip_address here, it fails to fire if the parent id is
-- changed by tb_manipulate_netblock_parentage, which seems like a bug?
--
CREATE TRIGGER zaa_ta_cache_netblock_hier_handler
	AFTER INSERT OR DELETE OR UPDATE OF ip_address, parent_netblock_id
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
	ON jazzhands.netblock;

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
