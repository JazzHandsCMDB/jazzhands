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
        where nspname = 'component_utils';
        IF _tal = 0 THEN
                DROP SCHEMA IF EXISTS component_utils;
                CREATE SCHEMA component_utils AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA component_utils IS 'part of jazzhands';
        END IF;
END;
$$;

CREATE OR REPLACE FUNCTION component_utils.create_component_template_slots(
	component_id	jazzhands.component.component_id%TYPE
) RETURNS SETOF jazzhands.slot
AS $$
DECLARE
	ctid	jazzhands.component_type.component_type_id%TYPE;
	s		jazzhands.slot%ROWTYPE;
	cid 	ALIAS FOR component_id;
BEGIN
	FOR s IN
		INSERT INTO jazzhands.slot (
			component_id,
			slot_name,
			slot_type_id,
			slot_index,
			component_type_slot_tmplt_id,
			physical_label,
			slot_x_offset,
			slot_y_offset,
			slot_z_offset,
			slot_side
		) SELECT
			cid,
			ctst.slot_name_template,
			ctst.slot_type_id,
			ctst.slot_index,
			ctst.component_type_slot_tmplt_id,
			ctst.physical_label,
			ctst.slot_x_offset,
			ctst.slot_y_offset,
			ctst.slot_z_offset,
			ctst.slot_side
		FROM
			component_type_slot_tmplt ctst JOIN
			component c USING (component_type_id)
		WHERE
			c.component_id = cid AND
			ctst.component_type_slot_tmplt_id NOT IN (
				SELECT component_type_slot_tmplt_id FROM slot WHERE
					slot.component_id = cid
				)
		ORDER BY ctst.component_type_slot_tmplt_id
		RETURNING *
	LOOP
		RAISE DEBUG 'Creating slot for component % from template %',
			cid, s.component_type_slot_tmplt_id;
		RETURN NEXT s;
	END LOOP;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION component_utils.set_slot_names(
	slot_id_list	integer[] DEFAULT NULL
) RETURNS VOID
AS $$
DECLARE
	slot_rec	RECORD;
	sn			text;
BEGIN
	-- Get a list of all slots that have replacement values

	FOR slot_rec IN
		SELECT 
			s.slot_id,
			st.slot_name_template,
			st.slot_index as slot_index,
			pst.slot_index as parent_slot_index
		FROM
			slot s JOIN
			component_type_slot_tmplt st ON (s.component_type_slot_tmplt_id =
				st.component_type_slot_tmplt_id) JOIN
			component c ON (s.component_id = c.component_id) LEFT JOIN
			slot ps ON (c.parent_slot_id = ps.slot_id) LEFT JOIN
			component_type_slot_tmplt pst ON (ps.component_type_slot_tmplt_id =
				pst.component_type_slot_tmplt_id)
		WHERE
			s.slot_id = ANY(slot_id_list) AND
			st.slot_name_template LIKE '%\%{%'
	LOOP
		sn := slot_rec.slot_name_template;
		IF (slot_rec.slot_index IS NOT NULL) THEN
			sn := regexp_replace(sn,
				'%\{slot_index\}', slot_rec.slot_index::text,
				'g');
		END IF;
		IF (slot_rec.parent_slot_index IS NOT NULL) THEN
			sn := regexp_replace(sn,
				'%\{parent_slot_index\}', slot_rec.parent_slot_index::text,
				'g');
		END IF;
		IF (slot_rec.parent_slot_index IS NOT NULL AND
			slot_rec.slot_index IS NOT NULL) THEN
			sn := regexp_replace(sn,
				'%\{relative_slot_index\}', 
				(slot_rec.parent_slot_index + slot_rec.slot_index)::text,
				'g');
		END IF;
		RAISE DEBUG 'Setting name of slot % to %',
			slot_rec.slot_id,
			sn;
		UPDATE slot SET slot_name = sn WHERE slot_id = slot_rec.slot_id;
	END LOOP;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql;

GRANT USAGE ON SCHEMA component_utils TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA component_utils TO ro_role;
