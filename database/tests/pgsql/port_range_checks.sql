-- Copyright (c) 2021 Todd Kover
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

\t on
SAVEPOINT port_range_regression;

\ir ../../ddl/schema/pgsql/create_port_range_triggers.sql

SAVEPOINT pretest;

--
-- Trigger tests
--
CREATE OR REPLACE FUNCTION port_range_regression() RETURNS BOOLEAN AS $$
DECLARE
	_tally	INTEGER;
	_r	RECORD;
	_d	RECORD;
	_ok	val_port_range_type%ROWTYPE;
	_nok	val_port_range_type%ROWTYPE;
BEGIN
	RAISE NOTICE 'port_range_regression: Begin';

	RAISE NOTICE 'Inserting test data...';
	INSERT INTO protocol ( protocol ) VALUES ('testprotocol');

	INSERT INTO val_port_range_type (
		port_range_type, protocol, range_permitted
	) VALUES (
		'ok', 'testprotocol', true
	) RETURNING * INTO _ok;

	INSERT INTO val_port_range_type (
		port_range_type, protocol, range_permitted
	) VALUES (
		'nok', 'testprotocol', false
	) RETURNING * INTO _nok;

	RAISE NOTICE 'Running tests...';

	RAISE NOTICE 'Checking if is_singleton is set for me...';
	BEGIN
		INSERT INTO port_range (
			port_range_name, port_range_type, protocol, port_start, port_end
		) VALUES (
			'singleton', 'nok', 'testprotocol', 10, 10
		) RETURNING * INTO _r;

		SELECT * INTO _d
		FROM port_range
		WHERE port_range_name = 'singleton'
		AND port_range_type = 'nok'
		AND protocol = 'testprotocol';

		IF _d != _r THEN
			RAISE EXCEPTION 'Insert is inconsistent: % %',
				jsonb_pretty(to_jsonb(_r)),
				jsonb_pretty(to_jsonb(_d));
		END IF;

		IF NOT _r.is_singleton THEN
			RAISE EXCEPTION 'is_singleton is % instead of true',
				_r.is_singleton;
		END IF;
		RAISE EXCEPTION 'It worked!' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It is (%)', SQLERRM;
	END;

	RAISE NOTICE 'Checking if range_permitted fails appropriately for INSERTS...';
	BEGIN
		BEGIN
			INSERT INTO port_range (
				port_range_name, port_range_type, protocol, port_start, port_end
			) VALUES (
				'notsingleton', 'nok', 'testprotocol', 10, 15
			) RETURNING * INTO _r;
		EXCEPTION WHEN invalid_parameter_value THEN
			RAISE EXCEPTION '%', SQLERRM USING ERRCODE = 'JH999';
		END;
		RAISE EXCEPTION '... It did not(!)';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE 'Checking if mismatches singleton fails...';
	BEGIN
		BEGIN
			INSERT INTO port_range (
				port_range_name, port_range_type, protocol,
				port_start, port_end, is_singleton
			) VALUES (
				'singleton', 'nok', 'testprotocol',
				10, 15, true
			) RETURNING * INTO _r;
		EXCEPTION WHEN invalid_parameter_value THEN
			RAISE EXCEPTION '%', SQLERRM USING ERRCODE = 'JH999';
		END;
		RAISE EXCEPTION '... It did not(!)';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE 'Checking if changing range_permitted fails';
	BEGIN
		INSERT INTO port_range (
			port_range_name, port_range_type, protocol, port_start, port_end
		) VALUES (
			'notsingleton', 'ok', 'testprotocol', 10, 15
		) RETURNING * INTO _r;

		BEGIN
			UPDATE val_port_range_type
			SET range_permitted = false
			WHERE protocol = 'testprotocol'
			AND port_range_type = 'ok';
		EXCEPTION WHEN invalid_parameter_value THEN
			RAISE EXCEPTION '%', SQLERRM USING ERRCODE = 'JH999';
		END;
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;


	RAISE NOTICE 'Cleaning up...';
	RAISE NOTICE 'END port_range_regression...';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT port_range_regression();
-- set search_path=jazzhands;
DROP FUNCTION port_range_regression();

ROLLBACK TO port_range_regression;

\t off
