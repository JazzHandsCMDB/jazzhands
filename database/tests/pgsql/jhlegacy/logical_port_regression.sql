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

\t on

SAVEPOINT lp_regression;

DO $$
DECLARE
	comptype	component_type%ROWTYPE;
	devtype		device_type%ROWTYPE;
	slottype	slot_type%ROWTYPE;
	device1		device%ROWTYPE;
	device2		device%ROWTYPE;
	device3		device%ROWTYPE;
	comp1		component%ROWTYPE;
	comp2		component%ROWTYPE;
	comp3		component%ROWTYPE;
	comp1slot1	slot%ROWTYPE;
	comp1slot2	slot%ROWTYPE;
	comp2slot1	slot%ROWTYPE;
	comp2slot2	slot%ROWTYPE;
	comp3slot1	slot%ROWTYPE;
	comp3slot2	slot%ROWTYPE;
	mlag		mlag_peering%ROWTYPE;
	mlag_lp		logical_port%ROWTYPE;
	dev1_lp		logical_port%ROWTYPE;
	dev2_lp		logical_port%ROWTYPE;
	dev3_lp		logical_port%ROWTYPE;
	errmsg		text;
BEGIN
	RAISE NOTICE '++ Beginning logical_port tests...';
	RAISE NOTICE '++ Populating data for logical_port tests...';

	INSERT INTO component_type (
		description
	) values (
		'logical_port test component_type'
	) RETURNING * INTO comptype;

	INSERT INTO device_type (
		model,
		component_type_id
	) values (
		'logical_port test device_type',
		comptype.component_type_id
	) RETURNING * INTO devtype;

	--
	-- Device 1
	--

	INSERT INTO component (
		component_type_id, component_name
	) values (
		comptype.component_type_id, 'test component 1'
	) RETURNING * INTO comp1;

	INSERT INTO device (
		component_id,
		device_name,
		device_type_id,
		device_status,
		service_environment_id,
		is_monitored
	) values (
		comp1.component_id,
		'logical_port test device 1',
		devtype.device_type_id,
		'up',
		1,
		'N'
	) RETURNING * INTO device1;

	INSERT INTO slot (
		slot_type_id,
		component_id,
		slot_name
	)
	SELECT
		st.slot_type_id,
		comp1.component_id,
		'comp1 slot1'
	FROM
		slot_type st
	WHERE
		slot_function = 'network'
	LIMIT 1
	RETURNING * INTO comp1slot1;
		
	INSERT INTO slot (
		slot_type_id,
		component_id,
		slot_name
	)
	SELECT
		st.slot_type_id,
		comp1.component_id,
		'comp1 slot2'
	FROM
		slot_type st
	WHERE
		slot_function != 'network'
	LIMIT 1
	RETURNING * INTO comp1slot2;

	RAISE NOTICE 'Device 1 is device_id %, component_id %, slot_id % and %',
		device1.device_id,
		comp1.component_id,
		comp1slot1.slot_id,
		comp1slot2.slot_id;

	--
	-- Device 2
	--

	INSERT INTO component (
		component_type_id, component_name
	) values (
		comptype.component_type_id, 'test component 1'
	) RETURNING * INTO comp2;

	INSERT INTO device (
		component_id,
		device_name,
		device_type_id,
		device_status,
		service_environment_id,
		is_monitored
	) values (
		comp2.component_id,
		'logical_port test device 2',
		devtype.device_type_id,
		'up',
		1,
		'N'
	) RETURNING * INTO device2;

	INSERT INTO slot (
		slot_type_id,
		component_id,
		slot_name
	)
	SELECT
		st.slot_type_id,
		comp2.component_id,
		'comp2 slot1'
	FROM
		slot_type st
	WHERE
		slot_function = 'network'
	LIMIT 1
	RETURNING * INTO comp2slot1;
		
	INSERT INTO slot (
		slot_type_id,
		component_id,
		slot_name
	)
	SELECT
		st.slot_type_id,
		comp2.component_id,
		'comp2 slot2'
	FROM
		slot_type st
	WHERE
		slot_function != 'network'
	LIMIT 1
	RETURNING * INTO comp2slot2;

	RAISE NOTICE 'Device 2 is device_id %, component_id %, slot_id % and %',
		device2.device_id,
		comp2.component_id,
		comp2slot1.slot_id,
		comp2slot2.slot_id;

	--
	-- Device 3
	--

	INSERT INTO component (
		component_type_id, component_name
	) values (
		comptype.component_type_id, 'test component 1'
	) RETURNING * INTO comp3;

	INSERT INTO device (
		component_id,
		device_name,
		device_type_id,
		device_status,
		service_environment_id,
		is_monitored
	) values (
		comp3.component_id,
		'logical_port test device 3',
		devtype.device_type_id,
		'up',
		1,
		'N'
	) RETURNING * INTO device1;

	INSERT INTO slot (
		slot_type_id,
		component_id,
		slot_name
	)
	SELECT
		st.slot_type_id,
		comp3.component_id,
		'comp3 slot1'
	FROM
		slot_type st
	WHERE
		slot_function = 'network'
	LIMIT 1
	RETURNING * INTO comp3slot1;
		
	INSERT INTO slot (
		slot_type_id,
		component_id,
		slot_name
	)
	SELECT
		st.slot_type_id,
		comp3.component_id,
		'comp3 slot1'
	FROM
		slot_type st
	WHERE
		slot_function != 'network'
	LIMIT 1
	RETURNING * INTO comp3slot2;

	RAISE NOTICE 'Device 2 is device_id %, component_id %, slot_id % and %',
		device3.device_id,
		comp3.component_id,
		comp3slot1.slot_id,
		comp3slot2.slot_id;

	--
	-- MLAG peer creation
	--

	RAISE NOTICE 'Create mlag_peering with no devices';
	BEGIN
		INSERT INTO mlag_peering(
			device1_id,
			device2_id
		) VALUES (
			NULL,
			NULL
		) RETURNING * INTO mlag;
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION
		WHEN SQLSTATE 'JH999' THEN
			RAISE NOTICE '   ...inserted mlag_peering % correctly',
				mlag.mlag_peering_id;
		WHEN OTHERS THEN
			GET STACKED DIAGNOSTICS errmsg = MESSAGE_TEXT;
			RAISE EXCEPTION '   ...failed incorrectly: %', errmsg;
	END;

	RAISE NOTICE 'Create mlag_peering with one device';
	BEGIN
		INSERT INTO mlag_peering(
			device1_id,
			device2_id
		) VALUES (
			device1.device_id,
			NULL
		) RETURNING * INTO mlag;
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION
		WHEN SQLSTATE 'JH999' THEN
			RAISE NOTICE '   ...inserted mlag_peering % correctly',
				mlag.mlag_peering_id;
		WHEN OTHERS THEN
			GET STACKED DIAGNOSTICS errmsg = MESSAGE_TEXT;
			RAISE EXCEPTION '   ...failed incorrectly: %', errmsg;
	END;

	RAISE NOTICE 'Create mlag_peering with two identical devices (should fail)';
	BEGIN
		INSERT INTO mlag_peering(
			device1_id,
			device2_id
		) VALUES (
			device1.device_id,
			device1.device_id
		) RETURNING * INTO mlag;
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION
		WHEN SQLSTATE 'JH999' THEN
			RAISE EXCEPTION '   ...inserted mlag_peering % incorrectly',
				mlag.mlag_peering_id;
		WHEN OTHERS THEN
			RAISE NOTICE '   ...failed correctly';
	END;

	RAISE NOTICE 'Create mlag_peering with two different devices';
	BEGIN
		INSERT INTO mlag_peering(
			device1_id,
			device2_id
		) VALUES (
			device1.device_id,
			device2.device_id
		) RETURNING * INTO mlag;
		RAISE NOTICE '   ...inserted mlag_peering % correctly',
			mlag.mlag_peering_id;
	EXCEPTION
		WHEN OTHERS THEN
			GET STACKED DIAGNOSTICS errmsg = MESSAGE_TEXT;
			RAISE EXCEPTION '   ...failed incorrectly: %', errmsg;
	END;

	--
	-- logical_port creation and modification
	--

	RAISE NOTICE 'Create logical_port of type MLAG with neither device_id nor mlag_peering_id set (should fail)';
	BEGIN
		INSERT INTO logical_port(
			logical_port_name,
			logical_port_type
		) VALUES (
			'lp test',
			'MLAG'
		) RETURNING * INTO mlag_lp;
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION
		WHEN SQLSTATE 'JH999' THEN
			RAISE EXCEPTION '   ...inserted logical_port % incorrectly',
				mlag_lp.logical_port_id;
		WHEN OTHERS THEN
			RAISE NOTICE '   ...failed correctly';
	END;

	RAISE NOTICE 'Create logical_port of type MLAG with both device_id and mlag_peering_id set (should fail)';
	BEGIN
		INSERT INTO logical_port(
			logical_port_name,
			logical_port_type,
			device_id,
			mlag_peering_id
		) VALUES (
			'lp test',
			'MLAG',
			device1.device_id,
			mlag.mlag_peering_id
		) RETURNING * INTO mlag_lp;
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION
		WHEN SQLSTATE 'JH999' THEN
			RAISE EXCEPTION '   ...inserted logical_port % incorrectly',
				mlag_lp.logical_port_id;
		WHEN OTHERS THEN
			RAISE NOTICE '   ...failed correctly';
	END;

	RAISE NOTICE 'Create logical_port of type MLAG with only device_id set (should fail)';
	BEGIN
		INSERT INTO logical_port(
			logical_port_name,
			logical_port_type,
			device_id
		) VALUES (
			'lp test',
			'MLAG',
			device1.device_id
		) RETURNING * INTO mlag_lp;
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION
		WHEN SQLSTATE 'JH999' THEN
			RAISE EXCEPTION '   ...inserted logical_port % incorrectly',
				mlag_lp.logical_port_id;
		WHEN OTHERS THEN
			RAISE NOTICE '   ...failed correctly';
	END;

	RAISE NOTICE 'Create logical_port of type MLAG with only mlag_peering_id set';
	BEGIN
		INSERT INTO logical_port(
			logical_port_name,
			logical_port_type,
			mlag_peering_id
		) VALUES (
			'MLAG test',
			'MLAG',
			mlag.mlag_peering_id
		) RETURNING * INTO mlag_lp;
		RAISE NOTICE '   ...inserted logical_port %', mlag_lp.logical_port_id;
	EXCEPTION
		WHEN OTHERS THEN
			GET STACKED DIAGNOSTICS errmsg = MESSAGE_TEXT;
			RAISE EXCEPTION '   ...failed incorrectly: %', errmsg;
	END;

	RAISE NOTICE 'Create logical_port of type LACP with only mlag_peering_id set (should fail)';
	BEGIN
		INSERT INTO logical_port(
			logical_port_name,
			logical_port_type,
			mlag_peering_id
		) VALUES (
			'LACP test',
			'LACP',
			mlag.mlag_peering_id
		) RETURNING * INTO dev1_lp;
		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION
		WHEN SQLSTATE 'JH999' THEN
			RAISE EXCEPTION '   ...inserted logical_port % incorrectly',
				dev1_lp.logical_port_id;
		WHEN OTHERS THEN
			RAISE NOTICE '   ...failed correctly';
	END;

	RAISE NOTICE 'Create logical_port of type LACP with only device_id set';
	BEGIN
		INSERT INTO logical_port(
			logical_port_name,
			logical_port_type,
			device_id
		) VALUES (
			'LACP test',
			'LACP',
			device1.device_id
		) RETURNING * INTO dev1_lp;
		RAISE NOTICE '   ...inserted logical_port % correctly',
			dev1_lp.logical_port_id;
	EXCEPTION
		WHEN OTHERS THEN
			RAISE EXCEPTION '   ...failed incorrectly';
	END;

	RAISE NOTICE 'Attempt to change logical_port.logical_port_id (should fail)';
	BEGIN
		UPDATE logical_port SET
			logical_port_id = 0
		WHERE 
			logical_port_id = mlag_lp.logical_port_id;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION
		WHEN SQLSTATE 'JH999' THEN
			RAISE EXCEPTION '   ...updated logical_port % incorrectly (logical_port_id -> 0)',
				mlag_lp.logical_port_id;
		WHEN OTHERS THEN
			RAISE NOTICE '   ...failed correctly';
	END;

	RAISE NOTICE 'Attempt to change logical_port.logical_port_type (should fail)';
	BEGIN
		UPDATE logical_port SET
			logical_port_type = 'LACP'
		WHERE 
			logical_port_id = mlag_lp.logical_port_id;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION
		WHEN SQLSTATE 'JH999' THEN
			RAISE EXCEPTION '   ...updated logical_port % incorrectly',
				mlag_lp.logical_port_id;
		WHEN OTHERS THEN
			RAISE NOTICE '   ...failed correctly';
	END;

	RAISE NOTICE 'Attempt to change logical_port.device_id (should fail)';
	BEGIN
		UPDATE logical_port SET
			device_id = device2.device_id
		WHERE 
			logical_port_id = mlag_lp.logical_port_id;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION
		WHEN SQLSTATE 'JH999' THEN
			RAISE EXCEPTION '   ...updated logical_port % incorrectly',
				mlag_lp.logical_port_id;
		WHEN OTHERS THEN
			RAISE NOTICE '   ...failed correctly';
	END;

	--
	-- logical_port_slot tests
	--


	RAISE NOTICE 'Attempt to add comp1slot1 (device1) to logical_port for device1...';
	BEGIN
		INSERT INTO logical_port_slot(
			logical_port_id,
			slot_id
		) VALUES (
			dev1_lp.logical_port_id,
			comp1slot1.slot_id
		);
		RAISE NOTICE '   ...inserted slot % into logical_port %',
			comp1slot1.slot_id,
			dev1_lp.logical_port_id;
	EXCEPTION
		WHEN OTHERS THEN
			GET STACKED DIAGNOSTICS errmsg = MESSAGE_TEXT;
			RAISE EXCEPTION '   ...failed incorrectly: %', errmsg;
	END;


	RAISE NOTICE '++ End of logical_port tests...';
END;
$$ LANGUAGE plpgsql;

ROLLBACK TO lp_regression;

\t off
