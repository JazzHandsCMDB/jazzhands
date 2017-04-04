-- Copyright (c) 2017 Matthew Ragan
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

DO $$
DECLARE
        _tal INTEGER;
BEGIN
        select count(*)
        from pg_catalog.pg_namespace
        into _tal
        where nspname = 'layerx_network_manip';
        IF _tal = 0 THEN
                DROP SCHEMA IF EXISTS layerx_network_manip;
                CREATE SCHEMA layerx_network_manip AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA layerx_network_manip IS 'part of jazzhands';
        END IF;
END;
$$;

CREATE OR REPLACE FUNCTION layerx_network_manip.delete_layer2_network (
	layer2_network_id	jazzhands.layer2_network.layer2_network_id%TYPE
) RETURNS VOID AS $$
BEGIN
	PERFORM * FROM delete_layer2_network(
		layer2_network_id_list := ARRAY[ layer2_network_id ]
	);
END $$ LANGUAGE plpgsql;

--
-- delete_layer2_networks will remove all information for layer2_networks
-- given, including layer3_networks, dns_records, and netblocks, however
-- if any netblocks are still in use other than for dns_records, the delete
-- will fail
--
CREATE OR REPLACE FUNCTION layerx_network_manip.delete_layer2_networks (
	layer2_network_id_list	integer[]
) RETURNS VOID AS $$
BEGIN
	BEGIN
		PERFORM local_hooks.delete_layer2_networks_before_hooks(
			layer2_network_id_list := layer2_network_id_list
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

	WITH x AS (
		SELECT
			p.netblock_id AS netblock_id,
			l2.layer2_network_id AS layer2_network_id,
			l3.layer3_network_id AS layer3_network_id
		FROM
			jazzhands.layer2_network l2 JOIN
			jazzhands.layer3_network l3 USING (layer2_network_id) JOIN
			jazzhands.netblock p USING (netblock_id)
		WHERE
			l2.layer2_network_id = ANY(layer2_network_id_list)
	), l3_coll_del AS (
		DELETE FROM
			jazzhands.l3_network_coll_l3_network
		WHERE
			layer3_network_id IN (SELECT layer3_network_id FROM x)
	), l3_del AS (
		DELETE FROM
			jazzhands.layer3_network
		WHERE
			layer3_network_id in (SELECT layer3_network_id FROM x)
	), l2_coll_del AS (
		DELETE FROM
			jazzhands.l2_network_coll_l2_network
		WHERE
			layer2_network_id IN (SELECT layer2_network_id FROM x)
	), l2_del AS (
		DELETE FROM
			jazzhands.layer2_network
		WHERE
			layer2_network_id IN (SELECT layer2_network_id FROM x)
	), nb_sel AS (
		SELECT
			n.netblock_id
		FROM
			netblock n JOIN
			x ON (n.parent_netblock_id = x.netblock_id)
	), dns_del AS (
		DELETE FROM
			jazzhands.dns_record
		WHERE
			netblock_id IN (SELECT netblock_id FROM nb_sel)
	), nb_del as (
		DELETE FROM
			jazzhands.netblock
		WHERE
			netblock_id IN (SELECT netblock_id FROM nb_sel)
	)
	DELETE FROM
		jazzhands.netblock
	WHERE
		netblock_id IN (SELECT netblock_id FROM x);

	BEGIN
		PERFORM local_hooks.delete_layer2_networks_after_hooks(
			layer2_network_id_list := layer2_network_id_list
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

END $$ LANGUAGE plpgsql;
GRANT USAGE ON SCHEMA layerx_network_manip TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA layerx_network_manip TO iud_role;
