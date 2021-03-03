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
		REVOKE USAGE ON SCHEMA layerx_network_manip FROM PUBLIC;
        END IF;
END;
$$;

CREATE OR REPLACE FUNCTION layerx_network_manip.delete_layer2_network (
	layer2_network_id	jazzhands.layer2_network.layer2_network_id%TYPE,
	purge_network_interfaces	boolean DEFAULT false
) RETURNS VOID AS $$
BEGIN
	PERFORM * FROM layerx_network_manip.delete_layer2_networks(
		layer2_network_id_list := ARRAY[ layer2_network_id ],
		purge_network_interfaces := purge_network_interfaces
	);
END $$ LANGUAGE plpgsql;

--
-- delete_layer2_networks will remove all information for layer2_networks
-- given, including layer3_networks, dns_records, and netblocks, however
-- if any netblocks are still in use other than for dns_records, the delete
-- will fail
--
CREATE OR REPLACE FUNCTION layerx_network_manip.delete_layer2_networks (
	layer2_network_id_list	integer[],
	purge_network_interfaces	boolean DEFAULT false
) RETURNS SETOF jazzhands.layer2_network AS $$
DECLARE
	netblock_id_list	integer[];
BEGIN
	IF array_length(layer2_network_id_list, 1) IS NULL THEN
		RETURN;
	END IF;

	BEGIN
		PERFORM local_hooks.delete_layer2_networks_before_hooks(
			layer2_network_id_list := layer2_network_id_list
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

	PERFORM layerx_network_manip.delete_layer3_networks(
		layer3_network_id_list := ARRAY(
				SELECT layer3_network_id
				FROM layer3_network l3n
				WHERE layer2_network_id = ANY(layer2_network_id_list)
			),
		purge_network_interfaces :=
			delete_layer2_networks.purge_network_interfaces
	);

	DELETE FROM
		layer2_network_collection_layer2_network l2nc
	WHERE
		l2nc.layer2_network_id = ANY(layer2_network_id_list);

	RETURN QUERY DELETE FROM
		layer2_network l2n
	WHERE
		l2n.layer2_network_id = ANY(layer2_network_id_list)
	RETURNING *;

	BEGIN
		PERFORM local_hooks.delete_layer2_networks_after_hooks(
			layer2_network_id_list := layer2_network_id_list
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

END $$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION layerx_network_manip.delete_layer3_network (
	layer3_network_id	jazzhands.layer3_network.layer3_network_id%TYPE,
	purge_network_interfaces	boolean DEFAULT false
) RETURNS VOID AS $$
BEGIN
	PERFORM * FROM layerx_network_manip.delete_layer3_networks(
		layer3_network_id_list := ARRAY[ layer3_network_id ],
		purge_network_interfaces := purge_network_interfaces
	);
END $$ LANGUAGE plpgsql;

--
-- delete_layer3_networks will remove all information for layer3_networks
-- given, including dns_records and netblocks, however if any netblocks
-- are still in use other than for dns_records, the delete
-- will fail unless purge_network_interfaces is passed
--

CREATE OR REPLACE FUNCTION layerx_network_manip.delete_layer3_networks (
	layer3_network_id_list	integer[],
	purge_network_interfaces	boolean DEFAULT false
) RETURNS SETOF jazzhands.layer3_network AS $$
DECLARE
	netblock_id_list			integer[];
	network_interface_id_list	integer[];
BEGIN
	IF array_length(layer3_network_id_list, 1) IS NULL THEN
		RETURN;
	END IF;

	BEGIN
		PERFORM local_hooks.delete_layer3_networks_before_hooks(
			layer3_network_id_list := layer3_network_id_list
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;

	IF (purge_network_interfaces) THEN
		SELECT ARRAY(
			SELECT
				n.netblock_id AS netblock_id
			FROM
				layer3_network l3 JOIN
				netblock p USING (netblock_id) JOIN
				netblock n ON (p.netblock_id = n.parent_netblock_id)
			WHERE
				l3.layer3_network_id = ANY(layer3_network_id_list)
		) INTO netblock_id_list;

		WITH nin_del AS (
			DELETE FROM
				layer3_interface_netblock
			WHERE
				netblock_id = ANY(netblock_id_list)
			RETURNING layer3_interface_id
		), snni_del AS (
			DELETE FROM
				shared_netblock_layer3_interface
			WHERE
				shared_netblock_id IN (
					SELECT shared_netblock_id FROM shared_netblock
					WHERE netblock_id = ANY(netblock_id_list)
				)
			RETURNING layer3_interface_id
		)
		SELECT ARRAY(
			SELECT layer3_interface_id FROM nin_del
			UNION
			SELECT layer3_interface_id FROM snni_del
		) INTO network_interface_id_list;

		DELETE FROM
			layer3_interface_purpose nip
		WHERE
			nip.layer3_interface_id IN (
				SELECT
					layer3_interface_id
				FROM
					layer3_interface ni
				WHERE
					ni.layer3_interface_id = ANY(network_interface_id_list)
						AND
					ni.layer3_interface_id NOT IN (
						SELECT
							layer3_interface_id
						FROM
							layer3_interface_netblock
						UNION
						SELECT
							layer3_interface_id
						FROM
							shared_netblock_layer3_interface
					)
			);

		DELETE FROM
			layer3_interface ni
		WHERE
			ni.layer3_interface_id = ANY(network_interface_id_list) AND
			ni.layer3_interface_id NOT IN (
				SELECT layer3_interface_id FROM layer3_interface_netblock
				UNION
				SELECT layer3_interface_id FROM shared_netblock_layer3_interface
			);
	END IF;

	RETURN QUERY WITH x AS (
		SELECT
			p.netblock_id AS netblock_id,
			l3.layer3_network_id AS layer3_network_id
		FROM
			layer3_network l3 JOIN
			netblock p USING (netblock_id)
		WHERE
			l3.layer3_network_id = ANY(layer3_network_id_list)
	), l3_coll_del AS (
		DELETE FROM
			layer3_network_collection_layer3_network
		WHERE
			layer3_network_id IN (SELECT layer3_network_id FROM x)
	), l3_del AS (
		DELETE FROM
			layer3_network
		WHERE
			layer3_network_id in (SELECT layer3_network_id FROM x)
		RETURNING *
	), nb_sel AS (
		SELECT
			n.netblock_id
		FROM
			netblock n JOIN
			x ON (n.parent_netblock_id = x.netblock_id)
	), dns_del AS (
		DELETE FROM
			dns_record
		WHERE
			netblock_id IN (SELECT netblock_id FROM nb_sel)
	), nbc_del as (
		DELETE FROM
			netblock_collection_netblock
		WHERE
			netblock_id IN (SELECT netblock_id FROM x
				UNION SELECT netblock_id FROM nb_sel)
	), nb_del as (
		DELETE FROM
			netblock
		WHERE
			netblock_id IN (SELECT netblock_id FROM nb_sel)
	), sn_del as (
		DELETE FROM
			shared_netblock
		WHERE
			netblock_id IN (SELECT netblock_id FROM nb_sel)
	), nrp_del as (
		DELETE FROM
			property
		WHERE
			network_range_id IN (
				SELECT
					network_range_id
				FROM
					network_range nr JOIN
					x ON (nr.parent_netblock_id = x.netblock_id)
			)
	), nr_del as (
		DELETE FROM
			network_range
		WHERE
			parent_netblock_id IN (SELECT netblock_id FROM x)
		RETURNING
			start_netblock_id, stop_netblock_id
	), nrnb_del AS (
		DELETE FROM
			netblock
		WHERE
			netblock_id IN (
				SELECT start_netblock_id FROM nr_del
				UNION
				SELECT stop_netblock_id FROM nr_del
		)
	), nbd AS (
		DELETE FROM
			netblock
		WHERE
			netblock_id IN (SELECT netblock_id FROM x)
	)
	SELECT * FROM l3_del;

	BEGIN
		PERFORM local_hooks.delete_layer3_networks_after_hooks(
			layer3_network_id_list := layer3_network_id_list
		);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		NULL;
	END;
	RETURN;
END $$ LANGUAGE plpgsql SET search_path=jazzhands SECURITY DEFINER;

REVOKE ALL ON SCHEMA layerx_network_manip FROM public;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA layerx_network_manip FROM public;

GRANT ALL ON SCHEMA layerx_network_manip TO iud_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA layerx_network_manip TO iud_role;
