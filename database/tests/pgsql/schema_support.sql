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
SAVEPOINT schema_support_regression;

\ir ../../ddl/schema/pgsql/create_schema_support.sql

SAVEPOINT pretest;

--
-- Trigger tests
--
CREATE OR REPLACE FUNCTION schema_support_regression() RETURNS BOOLEAN AS $$
DECLARE
	_v		boolean;
	test	TEXT[];
	want	TEXT;
	curv	TEXT;
	succ	boolean;
BEGIN
	RAISE NOTICE 'Starting schema_aupport version tests...';

	FOREACH test SLICE 1 IN ARRAY '{
		{0.55, 0.55, true},
		{0.90, 0.89.5, true},
		{0.90, 0.90.1, false},
		{1.0, 0.90, true},
		{0.90, 1.0, false},
		{1:1.90, 2:2.0, false},
		{1.90-6, 0.89-2, true},
		{1.90-6, 0.89.7-2, true},
		{0.90, 0.55, true}
	}'::text[][]
	LOOP
		curv := test[1];
		want := test[2];
		succ := test[3];

		RAISE NOTICE 'Checking explicit schema of current have % v want % returns %',
			curv, want, succ;
		BEGIN
			PERFORM schema_support.set_schema_version(curv, 'jazzhands');
			_v := schema_support.check_schema_version(want, 'jazzhands');
			IF _v = succ THEN
				RAISE EXCEPTION 'yay!' USING ERRCODE = 'JH999';
			ELSE
				RAISE EXCEPTION 'it did not! doh! -- %', _v;
			END IF;
		EXCEPTION WHEN SQLSTATE 'JH999' THEN
			RAISE NOTICE '... It did (%)', SQLERRM;
		END;
	END LOOP;

	FOREACH test SLICE 1 IN ARRAY '{
		{0.55, 0.55, true},
		{0.90, 0.89.5, true},
		{0.90, 0.90.1, false},
		{1.0, 0.90, true},
		{0.90, 1.0, false},
		{1:1.90, 2:2.0, false},
		{1.90-6, 0.89-2, true},
		{1.90-6, 0.89.7-2, true},
		{0.90, 0.55, true}
	}'::text[][]
	LOOP
		curv := test[1];
		want := test[2];
		succ := test[3];

		RAISE NOTICE 'Checking guessed schema of current have % v want % returns %',
			curv, want, succ;
		BEGIN
			SET search_path=jazzhands, somethingelse;
			PERFORM schema_support.set_schema_version(curv, 'jazzhands');
			_v := schema_support.check_schema_version(want);
			IF _v = succ THEN
				RAISE EXCEPTION 'yay!' USING ERRCODE = 'JH999';
			ELSE
				RAISE EXCEPTION 'it did not! doh! -- %', _v;
			END IF;
		EXCEPTION WHEN SQLSTATE 'JH999' THEN
			RAISE NOTICE '... It did (%)', SQLERRM;
		END;
	END LOOP;


	RAISE NOTICE 'Ending schema_aupport version tests...';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT schema_support_regression();
-- set search_path=jazzhands;
DROP FUNCTION schema_support_regression();

ROLLBACK TO schema_support_regression;

\t off
