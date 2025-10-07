-- Copyright (c) 2018-2019 Todd Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--       http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-- $Id$


\set ON_ERROR_STOP

-- set client_min_messages to 'debug';

-- \t on
SAVEPOINT ct_site_netblock_tests;

-- \ir ../../ddl/cache/pgsql/create_ct_netblock_hier.sql

--
-- basically legacy v_site_netblock_expanded view except excluding single
-- addresses
--
CREATE OR REPLACE VIEW slow AS
 WITH RECURSIVE parent_netblock AS (
         SELECT n.netblock_id,
            n.parent_netblock_id,
            n.ip_address,
            sn.site_code
           FROM netblock n
             LEFT JOIN site_netblock sn ON n.netblock_id = sn.netblock_id
          WHERE n.parent_netblock_id IS NULL
        UNION
         SELECT n.netblock_id,
            n.parent_netblock_id,
            n.ip_address,
            COALESCE(sn.site_code, p.site_code) AS "coalesce"
           FROM netblock n
             JOIN parent_netblock p ON n.parent_netblock_id = p.netblock_id
             LEFT JOIN site_netblock sn ON n.netblock_id = sn.netblock_id
        )
 SELECT parent_netblock.site_code,
    parent_netblock.netblock_id
   FROM parent_netblock
	JOIN netblock USING (netblock_id)
WHERE is_single_address = false
;

--
-- like above, but using cache tables
--
CREATE OR REPLACE VIEW fast AS
SELECT site_code, netblock_id
FROM netblock
LEFT JOIN (
	SELECT site_code, netblock_id
	FROM (
	SELECT p.site_code,
	n.netblock_id,
	rank() OVER (PARTITION BY n.netblock_id
		ORDER BY array_length(hc.path, 1) ,
			array_length(n.path, 1)
			) as tier
	FROM property p
	JOIN netblock_collection nc USING (netblock_collection_id)
	JOIN jazzhands_cache.ct_netblock_collection_hier_recurse hc
		USING (netblock_collection_id)
	JOIN netblock_collection_netblock ncn
		USING (netblock_collection_id)
	JOIN jazzhands_cache.ct_netblock_hier n
		ON ncn.netblock_id = n.root_netblock_id
	WHERE property_name = 'per-site-netblock_collection'
	AND p.property_type = 'automated'
	) miniq WHERE tier = 1
) bizness USING (netblock_id)
WHERE is_single_address = false
;

SELECT schema_support.relation_diff(
	schema := 'jazzhands',
	old_rel := 'slow',
	new_rel := 'fast',
	prikeys := ARRAY['netblock_id']
);

--
-- version of fast that also includes single addresses
--
CREATE VIEW fastish AS
SELECT * FROM fast
UNION ALL
SELECT site_code, n.netblock_id from fast f
	JOIN netblock n ON f.netblock_id = n.parent_netblock_id
	WHERE n.parent_netblock_id IS NOT NULL
	AND is_single_address = true
UNION ALL
SELECT NULL, netblock_id
	FROM netblock
	WHERE is_single_address = true and parent_netblock_id IS NULL
;


savepoint foo;

SELECT schema_support.relation_diff(
	schema := 'jazzhands',
	old_rel := 'v_site_netblock_expanded',
	new_rel := 'fastish',
	prikeys := ARRAY['netblock_id']
);

--
-- Trigger tests
--
CREATE OR REPLACE FUNCTION site_netblock_cache_tests() RETURNS BOOLEAN AS $$
DECLARE
	_nb1	netblock%ROWTYPE;
	_nb2	netblock%ROWTYPE;
	_nb3	netblock%ROWTYPE;
	_nb4	netblock%ROWTYPE;
	_nb5	netblock%ROWTYPE;
	_t	RECORD;
	_r	RECORD;
BEGIN
	RAISE NOTICE 'site_netblock_cache_tests: Cleanup Records from Previous Tests';

	RAISE NOTICE '++ Inserting testing data';
	INSERT INTO site (site_code, site_status) VALUES ('JHT0', 'PLANNED');
	INSERT INTO site (site_code, site_status) VALUES ('JHT1', 'PLANNED');
	INSERT INTO site (site_code, site_status) VALUES ('JHT2', 'PLANNED');

	INSERT INTO netblock (
		ip_address, netblock_status, can_subnet, is_single_address
	) VALUES (
		'172.30.0.0/16', 'Allocated', true, false
	) RETURNING * INTO _nb1;

	INSERT INTO netblock (
		ip_address, netblock_status, can_subnet, is_single_address
	) VALUES (
		'172.30.0.0/20', 'Allocated', true, false
	) RETURNING * INTO _nb2;

	INSERT INTO netblock (
		ip_address, netblock_status, can_subnet, is_single_address
	) VALUES (
		'172.30.40.0/22', 'Allocated', true, false
	) RETURNING * INTO _nb3;

	INSERT INTO netblock (
		ip_address, netblock_status, can_subnet, is_single_address
	) VALUES (
		'172.30.42.0/24', 'Allocated', false, false
	) RETURNING * INTO _nb4;

	INSERT INTO netblock (
		ip_address, netblock_status, can_subnet, is_single_address
	) VALUES (
		'172.30.42.5/24', 'Allocated', false,  true
	) RETURNING * INTO _nb5;

	RAISE NOTICE 'rows: % % % % %',
		_nb1.netblock_Id, _nb2.netblock_Id, _nb3.netblock_Id,
		_nb4.netblock_Id, _nb5.netblock_id;

	INSERT INTO site_netblock (site_code, netblock_id)
		VALUES ('JHT0', _nb1.netblock_id);
	INSERT INTO site_netblock (site_code, netblock_id)
		VALUES ('JHT1', _nb3.netblock_id);

	RAISE NOTICE '++ Now, Tests..';

	RAISE NOTICE 'Checking if top level netblock is right... [ % ]',
		_nb1.netblock_id;
	BEGIN
		SELECT *
		INTO _r
		FROM fast
		WHERE netblock_id = _nb1.netblock_id;

		IF _r.site_code IS NULL OR _r.site_code != 'JHT0' THEN
			RAISE EXCEPTION '.. It did not % ', to_json(_r);
		END IF;
		RAISE EXCEPTION '%', 'ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	PERFORM schema_support.relation_diff(
		schema := 'jazzhands',
		old_rel := 'slow',
		new_rel := 'fast',
		prikeys := ARRAY['netblock_id']
	);

	RAISE NOTICE 'Checking if middle level netblock is right... [ % ]',
		_nb2.netblock_id;
	BEGIN

		SELECT *
		INTO _r
		FROM fast
		WHERE netblock_id = _nb2.netblock_id;

		IF _r.site_code IS NULL OR _r.site_code != 'JHT0' THEN
			RAISE EXCEPTION '.. It did not % ', to_json(_r);
		END IF;
		RAISE EXCEPTION '%', 'ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;
	PERFORM schema_support.relation_diff(
		schema := 'jazzhands',
		old_rel := 'slow',
		new_rel := 'fast',
		prikeys := ARRAY['netblock_id']
	);


	RAISE NOTICE 'Checking if third level netblock is right...';
	BEGIN
		SELECT *
		INTO _r
		FROM fast
		WHERE netblock_id = _nb3.netblock_id;

		IF _r.site_code IS NULL OR _r.site_code != 'JHT1' THEN
			RAISE EXCEPTION '.. It did not % ', to_json(_r);
		END IF;
		RAISE EXCEPTION '%', 'ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;
	PERFORM schema_support.relation_diff(
		schema := 'jazzhands',
		old_rel := 'slow',
		new_rel := 'fast',
		prikeys := ARRAY['netblock_id']
	);

/*
 * not checking, since single addresses aren't in there.
	RAISE NOTICE 'Checking if fourth level netblock is right...';
	BEGIN
		SELECT *
		INTO _r
		FROM fast
		WHERE netblock_id = _nb5.netblock_id;

		IF _r.site_code IS NULL OR _r.site_code != 'JHT1' THEN
			RAISE EXCEPTION '.. It did not % ', to_json(_r);
		END IF;
		RAISE EXCEPTION '%', 'ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;
	PERFORM schema_support.relation_diff(
		schema := 'jazzhands',
		old_rel := 'slow',
		new_rel := 'fast',
		prikeys := ARRAY['netblock_id']
	);
*/

	RAISE NOTICE 'Checking if adding middle works...';
	BEGIN
		INSERT INTO site_netblock (netblock_id, site_code)
			VALUES (_nb2.netblock_id, 'JHT1');

		SELECT *
		INTO _r
		FROM fast
		WHERE netblock_id = _nb2.netblock_id;

		IF _r.site_code IS NULL OR _r.site_code != 'JHT1' THEN
			RAISE EXCEPTION '.. It did not % ', to_json(_r);
		END IF;
		RAISE EXCEPTION '%', 'ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;
	PERFORM schema_support.relation_diff(
		schema := 'jazzhands',
		old_rel := 'slow',
		new_rel := 'fast',
		prikeys := ARRAY['netblock_id']
	);

	RAISE NOTICE 'Checking if adjusting middle works to end...';
	BEGIN
		UPDATE site_netblock SET site_code = 'JHT2'
		WHERE netblock_id = _nb3.netblock_id;

		SELECT *
		INTO _r
		FROM fast
		WHERE netblock_id = _nb4.netblock_id;

		IF _r.site_code IS NULL OR _r.site_code != 'JHT2' THEN
			RAISE EXCEPTION '.. It did not % ', to_json(_r);
		END IF;
		RAISE EXCEPTION '%', 'ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;
	PERFORM schema_support.relation_diff(
		schema := 'jazzhands',
		old_rel := 'slow',
		new_rel := 'fast',
		prikeys := ARRAY['netblock_id']
	);

	RAISE NOTICE 'Cleaning up...';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT site_netblock_cache_tests();
-- set search_path=jazzhands;
DROP FUNCTION site_netblock_cache_tests();

ROLLBACK TO ct_site_netblock_tests;

\t off
