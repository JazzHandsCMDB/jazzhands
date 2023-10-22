--
-- Copyright (c) 2015, 2016, 2018, 2019 Matthew Ragan
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
		REVOKE ALL ON SCHEMA component_utils FROM public;
		COMMENT ON SCHEMA component_utils IS 'part of jazzhands';
        END IF;
END;
$$;

--
-- fetch_disk_component will return a disk with the given model and
-- serial number, and will restrict it to vendor, if given.
--
-- Lookups are done to try to do matches on known vendor and model
-- probe strings, because lots of people suck
--
CREATE OR REPLACE FUNCTION component_utils.fetch_disk_component(
	model				text,
	serial_number		text,
	vendor_name			text DEFAULT NULL
) RETURNS jazzhands.component
AS $$
DECLARE
	m			ALIAS FOR model;
	sn			ALIAS FOR serial_number;
	ctid		integer;
	stid		integer;
	c			RECORD;
	cid			integer;
BEGIN
	cid := NULL;

	IF
		model IS NULL OR model ~ '^\s*$' OR
		serial_number IS NULL OR serial_number ~ '^\s*$'
	THEN
		RAISE EXCEPTION 'model and serial_number must be given to fetch_disk_component'
			USING ERRCODE = 'JH501';
	END IF;

	IF vendor_name IS NOT NULL THEN
		--
		-- Try to find a vendor that matches.  Look up various properties
		-- for a probe string match, and then see if it matches the
		-- company name.
		--
		SELECT
			comp.company_id INTO cid
		FROM
			company comp JOIN
			company_collection_company ccc USING (company_id) JOIN
			property p USING (company_collection_id)
		WHERE
			p.property_type = 'DeviceProvisioning' AND
			p.property_name = 'DiskVendorProbeString' AND
			p.property_value = vendor_name
		ORDER BY
			p.property_id
		LIMIT 1;

		IF cid IS NULL THEN
			SELECT
				comp.company_id INTO cid
			FROM
				company comp JOIN
				company_collection_company ccc USING (company_id) JOIN
				property p USING (company_collection_id)
			WHERE
				p.property_type = 'DeviceProvisioning' AND
				p.property_name = 'DeviceVendorProbeString' AND
				p.property_value = vendor_name
			ORDER BY
				p.property_id
			LIMIT 1;
		END IF;

		--
		-- This is being deprecated in favor of the company_collection
		-- above
		--
		IF cid IS NULL THEN
			SELECT
				company_id INTO cid
			FROM
				property p
			WHERE
				p.property_type = 'DeviceProvisioning' AND
				p.property_name = 'DeviceVendorProbeString' AND
				p.property_value = vendor_name;
		END IF;

		IF cid IS NULL THEN
			SELECT
				company_id INTO cid
			FROM
				company comp
			WHERE
				comp.company_name = vendor_name;
		END IF;

		IF cid IS NULL THEN
			RETURN NULL;
		END IF;
	END IF;

	--
	-- Try to determine the component_type
	--

	SELECT DISTINCT
		component_type_id INTO ctid
	FROM
		component_type ct JOIN
		component_property cp USING (component_type_id) JOIN
		component_type_component_function ctcf USING (component_type_id)
	WHERE
		ctcf.component_function = 'disk' AND
		cp.component_property_name = 'DiskModelProbeString' AND
		cp.component_property_type = 'disk' AND
		cp.property_value = m AND
		CASE WHEN cid IS NOT NULL THEN
			(company_id = cid)
		ELSE
			true
		END;

	IF ctid IS NULL THEN
		SELECT DISTINCT
			component_type_id INTO ctid
		FROM
			component_type ct JOIN
			component_type_component_function ctcf USING (component_type_id)
		WHERE
			component_function = 'disk' AND
			ct.model = m AND
			CASE WHEN cid IS NOT NULL THEN
				(company_id = cid)
			ELSE
				true
			END;
	END IF;

	--
	-- Find a component of this type with the given serial_number
	--
	 SELECT
		component.* INTO c
	FROM
		component JOIN
		asset a USING (component_id)
	WHERE
		component_type_id = ctid AND
		a.serial_number = sn;

	RETURN c;
END;
$$
SET search_path=jazzhands
SECURITY DEFINER
LANGUAGE plpgsql;

--
-- Remove functions that have been relocated to component_manip
--

DROP FUNCTION IF EXISTS component_utils.create_component_template_slots(
	jazzhands.component.component_id%TYPE
);

DROP FUNCTION IF EXISTS component_utils.replace_component(
	integer,
	integer
);

DROP FUNCTION IF EXISTS component_utils.migrate_component_template_slots(
	jazzhands.component.component_id%TYPE
);

DROP FUNCTION IF EXISTS component_utils.set_slot_names(
	integer[]
);

DROP FUNCTION IF EXISTS component_utils.remove_component_hier(
	jazzhands.component.component_id%TYPE,
	boolean 
);

DROP FUNCTION IF EXISTS component_utils.insert_pci_component(
	integer,
	integer,
	integer,
	integer,
	text,
	text,
	text,
	text,
	text[],
	text,
	text
);

DROP FUNCTION IF EXISTS component_utils.insert_disk_component(
	text,
	bigint,
	text,
	text,
	text,
	text
);

DROP FUNCTION IF EXISTS component_utils.insert_memory_component(
	text,
	bigint,
	bigint,
	text,
	text,
	text
);

DROP FUNCTION IF EXISTS component_utils.insert_cpu_component(
	text,
	bigint,
	bigint,
	text,
	text,
	text
);

DROP FUNCTION IF EXISTS component_utils.insert_component_into_parent_slot(
	integer,
	integer,
	text,
	text,
	text,
	integer,
	text
);

DROP FUNCTION IF EXISTS component_utils.fetch_component(
    jazzhands.component_type.component_type_id%TYPE,
    text,
    boolean,
    text,
    jazzhands.slot.slot_id%TYPE
);

REVOKE ALL ON SCHEMA component_utils FROM public;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA component_utils FROM public;

GRANT USAGE ON SCHEMA component_utils TO iud_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA component_utils TO iud_role;
