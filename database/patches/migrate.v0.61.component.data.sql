\set ON_ERROR_STOP

/*
	Using this query to determine things that matter initially, map all of
	those device_types to a component_type.

	Because the (short- or long-term) goal is probably to make device_type_id
	a foreign key to component_type_id, we're going to change the component_id
	to match the device_type_id, which should make things easier later

SELECT
	device_type_id,
	company_name,
	model,
	tp.device_count as total_ports,
	up.device_count as connected_ports
FROM
	device_type dt JOIN
	(SELECT
		device_type_id,
		count(*) AS device_count
	 FROM
		device d JOIN
		physical_port pp USING (device_id)
	 GROUP BY
	 	device_type_id
	) tp USING (device_type_id) LEFT JOIN
	(SELECT
		device_type_id,
		count(*) AS device_count
	 FROM
		device d JOIN
		physical_port pp USING (device_id) JOIN
		layer1_connection l1c ON 
			(pp.physical_port_id = l1c.physical_port1_id OR
			 pp.physical_port_id = l1c.physical_port2_id)
	 GROUP BY
	 	device_type_id
	) up USING (device_type_id) LEFT JOIN
	company using (company_id);
	 	
*/
		
	
--
-- Update the current device types for the PowerEdge C6220 and C6220 II
-- to match a component type by assuming (for now) that they're 1U
--

\echo
\echo Fix up device_type models to match component_types for C6220 and
\echo Juniper EX stack
\echo
UPDATE
	device_type dt
SET
	model = model || ' 1U',
	description = dt.description || ' 1U'
FROM
	company c
WHERE
	dt.company_id = c.company_id AND
	company_name = 'Dell' AND
	model ~ 'PowerEdge C6220';

--
-- Fix the EX4200 device_type so it matches the correct component
--

UPDATE
	device_type dt
SET
	model = 'Juniper EX4xxx virtual chassis',
	description = 'Juniper EX4xxx virtual chassis'
FROM
	company c
WHERE
	dt.company_id = c.company_id AND
	company_name = 'Juniper' AND
	model = 'EX4200-48T';

\echo
\echo Creating placeholder component type for Dell Server
\echo

--
-- Create placeholder component types for 'Dell Server'
-- 

DO $$
#variable_conflict use_variable
DECLARE
	cid		integer;
	ctid	integer;
BEGIN
	SELECT company_id INTO cid FROM company WHERE company_name = 'Dell';
	IF NOT FOUND THEN
		INSERT INTO company (company_name) VALUEs ('Dell')
			RETURNING company_id INTO cid;
	END IF;

	INSERT INTO component_type (
		description,
		slot_type_id,
		model,
		company_id,
		asset_permitted,
		is_rack_mountable,
		size_units
	) VALUES (
		'Generic Dell Server (transition type)',
		NULL,
		'Server',
		cid,
		'Y',
		'N',
		1
	) RETURNING component_type_id INTO ctid;

	INSERT INTO component_type_component_func (
		component_type_id,
		component_function
	) VALUES (
		ctid,
		'device'
	);
END;
$$ LANGUAGE plpgsql;

\echo
\echo Changing component_type_id to match device_type_id for devices that
\echo there is a company/model match for to simplify things later
\echo

--
-- Update the component_type_ids for any component whose company_id and
-- model match a device_type to match the device_type_id.  This means
-- updating the types in component_type_slot_tmplt, val_component_property
-- component_property, and component_type_component_func
--

--
-- These constraints need to be deferrable for this to work
--
-- Apparently ALTER TABLE ALTER CONSTRAINT only works on 9.4+
--
-- ALTER TABLE component_type_component_func ALTER CONSTRAINT
-- 	fk_cmptypecf_comp_typ_id DEFERRABLE;
-- ALTER TABLE val_component_property ALTER CONSTRAINT
-- 	fk_comp_prop_rqd_cmptypid DEFERRABLE;
-- ALTER TABLE component_property ALTER CONSTRAINT
-- 	fk_comp_prop_comp_typ_id DEFERRABLE;
-- ALTER TABLE component_type_slot_tmplt ALTER CONSTRAINT
-- 	fk_comp_typ_slt_tmplt_cmptypid DEFERRABLE;

ALTER TABLE component_type_component_func
	DROP CONSTRAINT fk_cmptypecf_comp_typ_id;
ALTER TABLE component_type_component_func
	ADD CONSTRAINT fk_cmptypecf_comp_typ_id
	FOREIGN KEY (component_type_id) REFERENCES component_type(component_type_id) DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE val_component_property
	DROP CONSTRAINT fk_comp_prop_rqd_cmptypid;
ALTER TABLE val_component_property
	ADD CONSTRAINT fk_comp_prop_rqd_cmptypid
	FOREIGN KEY (required_component_type_id) REFERENCES component_type(component_type_id) DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE component_property
	DROP CONSTRAINT fk_comp_prop_comp_typ_id;
ALTER TABLE component_property
	ADD CONSTRAINT fk_comp_prop_comp_typ_id
	FOREIGN KEY (component_type_id) REFERENCES component_type(component_type_id) DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE component_type_slot_tmplt
	DROP CONSTRAINT fk_comp_typ_slt_tmplt_cmptypid;
ALTER TABLE component_type_slot_tmplt
	ADD CONSTRAINT fk_comp_typ_slt_tmplt_cmptypid
	FOREIGN KEY (component_type_id) REFERENCES component_type(component_type_id) DEFERRABLE INITIALLY IMMEDIATE;

SET CONSTRAINTS
		jazzhands.fk_cmptypecf_comp_typ_id,
		jazzhands.fk_comp_prop_comp_typ_id,
		jazzhands.fk_comp_prop_rqd_cmptypid,
		jazzhands.fk_comp_typ_slt_tmplt_cmptypid
	DEFERRED;

CREATE TEMPORARY TABLE component_type_id_to_device_type_id AS
	SELECT
		ct.component_type_id,
		device_type_id
	FROM
		component_type ct JOIN
		device_type dt ON (
			ct.company_id = dt.company_id AND
			ct.model = dt.model
		);

UPDATE component_type_component_func ct
	SET component_type_id = c2d.device_type_id
	FROM component_type_id_to_device_type_id c2d
	WHERE ct.component_type_id = c2d.component_type_id;

UPDATE val_component_property ct
	SET required_component_type_id = c2d.device_type_id
	FROM component_type_id_to_device_type_id c2d
	WHERE ct.required_component_type_id = c2d.component_type_id;

UPDATE component_property ct
	SET component_type_id = c2d.device_type_id
	FROM component_type_id_to_device_type_id c2d
	WHERE ct.component_type_id = c2d.component_type_id;

UPDATE component_type_slot_tmplt ct
	SET component_type_id = c2d.device_type_id
	FROM component_type_id_to_device_type_id c2d
	WHERE ct.component_type_id = c2d.component_type_id;

UPDATE component_type ct
	SET component_type_id = c2d.device_type_id
	FROM component_type_id_to_device_type_id c2d
	WHERE ct.component_type_id = c2d.component_type_id;

UPDATE device_type dt
	SET component_type_id = c2d.device_type_id
	FROM component_type_id_to_device_type_id c2d
	WHERE dt.device_type_id = c2d.device_type_id;

\echo
\echo Creating components for all devices with layer1_connection entries
\echo

--
-- Create components for all of the devices.
--

DO $$
DECLARE
	dev_rec	RECORD;
	cid		INTEGER;
	cnt		INTEGER;
BEGIN
	cnt := 0;
	FOR dev_rec IN
		SELECT DISTINCT
			d.device_id,
			d.device_type_id
		FROM
			device d JOIN
			physical_port pp USING (device_id) JOIN
			layer1_connection l1c ON 
				(pp.physical_port_id = l1c.physical_port1_id OR
				 pp.physical_port_id = l1c.physical_port2_id)
	LOOP
		INSERT INTO component (component_type_id) VALUES (dev_rec.device_type_id)
			RETURNING component_id INTO cid;
		UPDATE device SET component_id = cid WHERE device_id =
			dev_rec.device_id;
		cnt := cnt + 1;
		IF (cnt % 100 = 0) THEN
			RAISE INFO 'Inserted % components', cnt;
		END IF;
	END LOOP;
END;
$$ language plpgsql;

\echo
\echo Creating child components for the EX4200 virtual chassis
\echo

--
-- Insert components for EX4200s
--
INSERT INTO component (
	component_type_id,
	parent_slot_id
)
SELECT
	swtype.component_type_id,
	slot_id
FROM
	component c JOIN
	component_type ct USING (component_type_id) JOIN
	slot s USING (component_id) JOIN
	slot_type st ON (s.slot_type_id = st.slot_type_id) JOIN
	component_type_slot_tmplt ctst USING (component_type_slot_tmplt_id),
	component_type swtype
WHERE
	ct.model = 'Juniper EX4xxx virtual chassis' AND
	st.slot_function = 'chassis_slot' AND
	st.slot_physical_interface_type = 'JuniperEXStack' AND
	ctst.slot_index IN (0,1) AND
	swtype.model = 'EX4200-48T';

\echo
\echo Creating temporary network slots on the server components for the
\echo server ports that have layer1_connections.  These will later get
\echo cleaned up after device probes determine their actual locations
\echo
--
-- Create temporary network slots directly on the server components (until we
-- probe later)
--
INSERT INTO slot (
	component_id,
	slot_name,
	slot_type_id,
	slot_side
) SELECT
	component_id,
	CASE
		WHEN port_name ~ '^eth' THEN port_name
		ELSE 'eth' ||
			(regexp_replace(port_name, '^.*(\d+)$', '\1'))::integer - 1
	END AS port_name,
	slot_type_id,
	'BACK'
FROM
	device d JOIN
	device_type dt USING (device_type_id) JOIN
	company c ON (dt.company_id = c.company_id) JOIN
	physical_port pp USING (device_id) JOIN
	layer1_connection l1c ON 
		(pp.physical_port_id = l1c.physical_port1_id OR
		 pp.physical_port_id = l1c.physical_port2_id),
	slot_type st
WHERE
	c.company_name = 'Dell' AND
	slot_type = '1000BaseTEthernet' AND
	slot_function = 'network';

\echo
\echo Mapping all layer2_connections into inter_component_connections
\echo

INSERT INTO inter_component_connection (slot1_id, slot2_id)
WITH x AS (
	SELECT
		device_id,
		physical_port_id,
		CASE WHEN port_name ~ '^(em|p\d+p)' THEN
			'eth' || 
			(regexp_replace(port_name, '^.*(\d+)$', '\1'))::integer - 1
		ELSE 
			port_name 
		END AS port_name
	FROM
		device d JOIN
		physical_port p USING (device_id)
), y AS (
	SELECT
		device_id,
		slot_id,
		slot_name
	FROM
		v_device_slots ds JOIN
		slot s USING (slot_id)
)
SELECT
	slot1.slot_id,
	slot2.slot_id
FROM
	layer1_connection l1c JOIN
	x port1 ON (l1c.physical_port1_id = port1.physical_port_id) JOIN
	x port2 ON (l1c.physical_port2_id = port2.physical_port_id) JOIN
	y slot1 ON (
		port1.device_id = slot1.device_id AND 
		port1.port_name = slot1.slot_name
	) JOIN
	y slot2 ON (
		port2.device_id = slot2.device_id AND 
		port2.port_name = slot2.slot_name
	) order by slot1.slot_id;


WITH x AS (
	SELECT
		device_id,
		physical_port_id,
		CASE WHEN port_name ~ '^(em|p\d+p)' THEN
			'eth' || 
			(regexp_replace(port_name, '^.*(\d+)$', '\1'))::integer - 1
		ELSE 
			port_name 
		END AS port_name
	FROM
		device d JOIN
		physical_port p USING (device_id)
), y AS (
	SELECT
		device_id,
		slot_id,
		slot_name
	FROM
		v_device_slots ds JOIN
		slot s USING (slot_id)
)
UPDATE
	network_interface ni
SET
	physical_port_id = slot1.slot_id
FROM
	x port1 JOIN
	y slot1 ON (
		port1.device_id = slot1.device_id AND 
		port1.port_name = slot1.slot_name
	)
WHERE
	ni.physical_port_id = port1.physical_port_id;

UPDATE
	network_interface ni
SET
	physical_port_id = NULL
WHERE
	ni.physical_port_id IS NOT NULL AND
	ni.physical_port_id NOT IN (SELECT slot_id FROM slot);
