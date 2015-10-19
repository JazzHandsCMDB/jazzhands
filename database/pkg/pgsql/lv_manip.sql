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

DO $$
DECLARE
        _tal INTEGER;
BEGIN
        select count(*)
        from pg_catalog.pg_namespace
        into _tal
        where nspname = 'lv_manip';
        IF _tal = 0 THEN
                DROP SCHEMA IF EXISTS lv_manip;
                CREATE SCHEMA lv_manip AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA lv_manip IS 'part of jazzhands';
        END IF;
END;
$$;

CREATE OR REPLACE FUNCTION lv_manip.delete_lv_hier(
	physicalish_volume_id	integer DEFAULT NULL,
	volume_group_id			integer DEFAULT NULL,
	logical_volume_id		integer DEFAULT NULL,
	pv_list	OUT integer[],
	vg_list	OUT integer[],
	lv_list	OUT integer[]
) RETURNS RECORD AS $$
DECLARE
	pvid ALIAS FOR physicalish_volume_id;
	vgid ALIAS FOR volume_group_id;
	lvid ALIAS FOR logical_volume_id;
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_pv_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = pvid
			END OR
			CASE WHEN vgid  IS NULL
				THEN false
				ELSE lh.volume_group_id = vgid
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = lvid
			END)
			AND child_pv_id IS NOT NULL
	) INTO pv_list;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_vg_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = pvid
			END OR
			CASE WHEN vgid  IS NULL
				THEN false
				ELSE lh.volume_group_id = vgid
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = lvid
			END)
			AND child_vg_id IS NOT NULL
	) INTO vg_list;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_lv_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = pvid
			END OR
			CASE WHEN vgid  IS NULL
				THEN false
				ELSE lh.volume_group_id = vgid
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = lvid
			END)
			AND child_lv_id IS NOT NULL
	) INTO lv_list;

	DELETE FROM logical_volume_property WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM logical_volume_purpose WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM logical_volume WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM volume_group WHERE volume_group_id = ANY(vg_list);
	DELETE FROM physicalish_volume WHERE physicalish_volume_id = ANY(pv_list);
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lv_manip.delete_lv_hier(
	INOUT physicalish_volume_list	integer[] DEFAULT NULL,
	INOUT volume_group_list		integer[] DEFAULT NULL,
	INOUT logical_volume_list		integer[] DEFAULT NULL
) RETURNS RECORD AS $$
DECLARE
	pv_list	integer[];
	vg_list	integer[];
	lv_list	integer[];
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_pv_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = ANY (physical_volume_list)
			END OR
			CASE WHEN vgid  IS NULL
				THEN false
				ELSE lh.volume_group_id = ANY (volume_group_list)
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = ANY (logical_volume_list)
			END)
			AND child_pv_id IS NOT NULL
	) INTO pv_list;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_vg_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = ANY (physicalish_volume_list)
			END OR
			CASE WHEN vgid  IS NULL
				THEN false
				ELSE lh.volume_group_id = ANY (volume_group_list)
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = ANY (logical_volume_list)
			END)
			AND child_vg_id IS NOT NULL
	) INTO vg_list;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_lv_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = ANY (physicalish_volume_list)
			END OR
			CASE WHEN vgid  IS NULL
				THEN false
				ELSE lh.volume_group_id = ANY (volume_group_list)
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = ANY (logical_volume_list)
			END)
			AND child_lv_id IS NOT NULL
	) INTO lv_list;

	DELETE FROM logical_volume_property WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM logical_volume_purpose WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM logical_volume WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM volume_group WHERE volume_group_id = ANY(vg_list);
	DELETE FROM physicalish_volume WHERE physicalish_volume_id = ANY(pv_list);

	physicalish_volume_list := pv_list;
	volume_group_list := vg_list;
	logical_volume_list := lv_list;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql;

--
-- This needs to be done recursively because lower level volume groups may
-- contain physicalish volumes that are not from this hierarchy
--
CREATE OR REPLACE FUNCTION lv_manip.delete_pv(
	physicalish_volume_list	integer[],
	purge_orphans			boolean DEFAULT false
) RETURNS VOID AS $$
DECLARE
	pvid integer;
	vgid integer;
BEGIN
	PERFORM * FROM lv_manip.remove_pv_membership(
		physicalish_volume_list,
		purge_orphans
	);

	DELETE FROM physicalish_volume WHERE
		physicalish_volume_id = ANY(physicalish_volume_list);
END;
$$
SET search_path = jazzhands
LANGUAGE plpgsql;

--
-- This needs to be done recursively because lower level volume groups may
-- contain physicalish volumes that are not from this hierarchy
--
CREATE OR REPLACE FUNCTION lv_manip.remove_pv_membership(
	physicalish_volume_list	integer[],
	purge_orphans			boolean DEFAULT false
) RETURNS VOID AS $$
DECLARE
	pvid integer;
	vgid integer;
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	FOREACH pvid IN ARRAY physicalish_volume_list LOOP
		DELETE FROM 
			volume_group_physicalish_vol vgpv
		WHERE
			vgpv.physicalish_volume_id = pvid
		RETURNING
			volume_group_id INTO vgid;
		
		IF FOUND AND purge_orphans THEN
			PERFORM * FROM
				volume_group_physicalish_vol vgpv
			WHERE
				volume_group_id = vgid;

			IF NOT FOUND THEN
				PERFORM lv_manip.delete_vg(
					volume_group_id := vgid,
					purge_orphans := purge_orphans
				);
			END IF;
		END IF;

	END LOOP;
END;
$$
SET search_path = jazzhands
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lv_manip.delete_vg(
	volume_group_id	integer,
	purge_orphans boolean DEFAULT false
) RETURNS VOID AS $$
DECLARE
	lvids	integer[];
BEGIN
	PERFORM lv_manip.delete_vg(
		volume_group_list := ARRAY [ volume_group_id ],
		purge_orphans := purge_orphans
	);
END;
$$
SET search_path = jazzhands
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lv_manip.delete_vg(
	volume_group_list	integer[],
	purge_orphans boolean DEFAULT false
) RETURNS VOID AS $$
DECLARE
	lvids	integer[];
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	SELECT ARRAY(
		SELECT
			logical_volume_id
		FROM
			logical_volume lv
		WHERE
			lv.volume_group_id = ANY(volume_group_list)
	) INTO lvids;

	PERFORM lv_manip.delete_pv(
		physicalish_volume_list := (
			SELECT ARRAY (SELECT
				physicalish_volume_id
			FROM
				physicalish_volume
			WHERE
				logical_volume_id = ANY(lvids)
		)),
		purge_orphans := purge_orphans
	);

	DELETE FROM
		volume_group_physicalish_vol vgpv
	WHERE
		vgpv.volume_group_id = ANY(volume_group_list);
	
	DELETE FROM
		volume_group_purpose vgp
	WHERE
		vgp.volume_group_id = ANY(volume_group_list);

	DELETE FROM
		logical_volume_property
	WHERE
		logical_volume_id = ANY(lvids);

	DELETE FROM
		logical_volume_purpose
	WHERE
		logical_volume_id = ANY(lvids);
	
	DELETE FROM
		logical_volume
	WHERE
		logical_volume_id = ANY(lvids);
	
	DELETE FROM
		volume_group vg
	WHERE
		vg.volume_group_id = ANY(volume_group_list);
END;
$$
SET search_path = jazzhands
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lv_manip.delete_lv(
	logical_volume_id	integer,
	purge_orphans boolean DEFAULT false
) RETURNS VOID AS $$
BEGIN
	PERFORM lv_manip.delete_lv(
		logical_volume_list := ARRAY [ logical_volume_id ],
		purge_orphans := purge_orphans
	);
END;
$$
SET search_path = jazzhands
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION lv_manip.delete_lv(
	logical_volume_list	integer[],
	purge_orphans boolean DEFAULT false
) RETURNS VOID AS $$
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	PERFORM lv_manip.delete_pv(
		physicalish_volume_list := (
			SELECT ARRAY (SELECT
				physicalish_volume_id
			FROM
				physicalish_volume pv
			WHERE
				pv.logical_volume_id = ANY(logical_volume_list)
		)),
		purge_orphans := purge_orphans
	);

	DELETE FROM
		logical_volume_property lvp
	WHERE
		lvp.logical_volume_id = ANY(logical_volume_list);
	
	DELETE FROM
		logical_volume_purpose lvp
	WHERE
		lvp.logical_volume_id = ANY(logical_volume_list);
	
	DELETE FROM
		logical_volume lv
	WHERE
		lv.logical_volume_id = ANY(logical_volume_list);
END;
$$
SET search_path = jazzhands
LANGUAGE plpgsql;

GRANT USAGE ON SCHEMA lv_manip TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA lv_manip TO ro_role;
