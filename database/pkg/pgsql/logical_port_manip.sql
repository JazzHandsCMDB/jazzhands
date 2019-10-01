-- Copyright (c) 2019, Matthew Ragan
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

\set ON_ERROR_STOP

DO $$
DECLARE
        _tal INTEGER;
BEGIN
        select count(*)
        from pg_catalog.pg_namespace
        into _tal
        where nspname = 'logical_port_manip';
        IF _tal = 0 THEN
                DROP SCHEMA IF EXISTS logical_port_manip;
                CREATE SCHEMA logical_port_manip AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA logical_port_manip IS 'part of jazzhands';
        END IF;
END;
$$;

CREATE OR REPLACE FUNCTION logical_port_manip.remove_mlag_peer(
	device_id			jazzhands.device.device_id%TYPE,
	mlag_peering_id		jazzhands.mlag_peering.mlag_peering_id%TYPE DEFAULT NULL
)
RETURNS boolean AS
$$
DECLARE
	mprec		jazzhands.mlag_peering%ROWTYPE;
	mpid		ALIAS FOR mlag_peering_id;
	devid		ALIAS FOR device_id;
BEGIN
	SELECT
		mp.mlag_peering_id INTO mprec
	FROM
		mlag_peering mp
	WHERE
		mp.device1_id = devid OR
		mp.device2_id = devid;

	IF NOT FOUND THEN
		RETURN false;
	END IF;

	IF mpid IS NOT NULL AND mpid != mprec.mlag_peering_id THEN
		RETURN false;
	END IF;

	mpid := mprec.mlag_peering_id;

	--
	-- Remove all logical ports from this device from any mlag_peering
	-- ports
	--
	UPDATE
		logical_port lp
	SET
		parent_logical_port_id = NULL
	WHERE
		lp.device_id = devid AND
		lp.parent_logical_port_id IN (
			SELECT
				logical_port_id
			FROM
				logical_port mlp
			WHERE
				mlp.mlag_peering_id = mprec.mlag_peering_id
		);

	--
	-- If both sides are gone, then delete the MLAG
	--
	
	IF mprec.device1_id IS NULL OR mprec.device2_id IS NULL THEN
		WITH x AS (
			SELECT
				layer2_connection_id
			FROM
				layer2_connection l2c
			WHERE
				l2c.logical_port1_id IN (
					SELECT
						logical_port_id
					FROM
						logical_port lp
					WHERE
						lp.mlag_peering_id = mpid
				) OR
				l2c.logical_port2_id IN (
					SELECT
						logical_port_id
					FROM
						logical_port lp
					WHERE
						lp.mlag_peering_id = mpid
				)
		), z AS (
			DELETE FROM layer2_connection_l2_network l2cl2n WHERE
				l2cl2n.layer2_connection_id IN (
					SELECT layer2_connection_id FROM x
				)
		)
		DELETE FROM layer2_connection l2c WHERE
			l2c.layer2_connection_id IN (
				SELECT layer2_connection_id FROM x
			);

		DELETE FROM logical_port lp WHERE
			lp.mlag_peering_id = mpid;
		DELETE FROM mlag_peering mp WHERE
			mp.mlag_peering_id = mpid;
	END IF;
	RETURN true;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

GRANT USAGE ON SCHEMA logical_port_manip TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA logical_port_manip TO iud_role;
