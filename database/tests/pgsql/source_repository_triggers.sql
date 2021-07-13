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
SAVEPOINT source_repository_regression;

\ir ../../ddl/schema/pgsql/create_base_service_triggers.sql
\ir ../../ddl/schema/pgsql/create_service_source_repository_triggers.sql

SAVEPOINT pretest;

--
-- Trigger tests
--
CREATE OR REPLACE FUNCTION source_repository_regression() RETURNS BOOLEAN AS $$
DECLARE
	_tally	INTEGER;
	_r		RECORD;
	_d		RECORD;
	_s		service%ROWTYPE;
	_sr		source_repository%ROWTYPE;
	_se		service_endpoint%ROWTYPE;
	_srl1	source_repository_location%ROWTYPE;
	_srl2	source_repository_location%ROWTYPE;
BEGIN
	RAISE NOTICE 'source_repository_regression: Begin';

	RAISE NOTICE 'Inserting test data...';

	INSERT INTO val_service_type (service_type) VALUES ('jhtest');

	INSERT INTO service (service_name, service_type) VALUES ('jhtest', 'jhtest') RETURNING * INTO _s;

	INSERT INTO service_endpoint ( service_id, service_endpoint_uri )
		VALUES (_s.service_id, 'https://example.org/api/v1/')
		RETURNING * INTO _se;

	INSERT INTO val_service_source_control_purpose
		( service_source_control_purpose ) VALUES ('jhtest');

	INSERT INTO val_source_repository_url_purpose
		( source_repository_url_purpose ) VALUES ('jhtest');

	INSERT INTO val_source_repository_method
		( source_repository_method ) VALUES ('jhtest');

	INSERT INTO source_repository
		( source_repository_name, source_repository_method )
		VALUES
		( 'jhtest', 'jhtest') RETURNING * INTO _sr;

	INSERT INTO  source_repository_location (
		source_repository_id, service_source_control_purpose,
		service_source_repository_path
	) VALUES (
		_sr.source_repository_id, 'jhtest',
		'foo/bar/barz.git'
	) RETURNING * INTO _srl1;

	INSERT INTO  source_repository_location (
		source_repository_id, service_source_control_purpose,
		service_source_repository_path
	) VALUES (
		_sr.source_repository_id, 'jhtest',
		'foo/bar/ack.git'
	) RETURNING * INTO _srl2;

	RAISE NOTICE 'Checking if not setting endpoint or url fails... ';
	BEGIN
		BEGIN
			INSERT INTO source_repository_url(
				source_repository_id, source_repository_url_purpose
			) VALUES (
				_sr.source_repository_id, 'jhtest'
			);
		EXCEPTION WHEN null_value_not_allowed THEN
			RAISE EXCEPTION '%', SQLERRM USING ERRCODE = 'JH999';
		END;
		RAISE EXCEPTION 'Ugh, It worked!';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE 'Checking if not setting endpoint and url fails... ';
	BEGIN
		BEGIN
			INSERT INTO source_repository_url(
				source_repository_id, source_repository_url_purpose,
				source_repository_url, service_endpoint_id
			) VALUES (
				_sr.source_repository_id, 'jhtest',
				'https://example.com/', _se.service_endpoint_id
			);
		EXCEPTION WHEN invalid_parameter_value THEN
			RAISE EXCEPTION '%', SQLERRM USING ERRCODE = 'JH999';
		END;
		RAISE EXCEPTION 'Ugh, It worked!';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE 'Checking if not setting endpoint and url fails... ';
	BEGIN
		BEGIN
			INSERT INTO source_repository_url(
				source_repository_id, source_repository_url_purpose,
				source_repository_url, service_endpoint_id
			) VALUES (
				_sr.source_repository_id, 'jhtest',
				'https://example.com/', _se.service_endpoint_id
			);
		EXCEPTION WHEN invalid_parameter_value THEN
			RAISE EXCEPTION '%', SQLERRM USING ERRCODE = 'JH999';
		END;
		RAISE EXCEPTION 'Ugh, It worked!';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE 'Checking if multiple primaries fail on INSERT... ';
	BEGIN
		INSERT INTO service_source_repository (
			service_id, source_repository_location_id, is_primary
		) VALUES (
			_s.service_id, _srl1.source_repository_location_id, true
		);
		BEGIN
			INSERT INTO service_source_repository (
				service_id, source_repository_location_id, is_primary
			) VALUES (
				_s.service_id, _srl2.source_repository_location_id, true
			);
		EXCEPTION WHEN unique_violation THEN
			RAISE EXCEPTION '%', SQLERRM USING ERRCODE = 'JH999';
		END;
		RAISE EXCEPTION 'Ugh, It worked!';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE 'Checking if multiple primaries fail on UPDATE... ';
	BEGIN
		INSERT INTO service_source_repository (
			service_id, source_repository_location_id, is_primary
		) VALUES (
			_s.service_id, _srl1.source_repository_location_id, true
		);
		INSERT INTO service_source_repository (
			service_id, source_repository_location_id, is_primary
		) VALUES (
			_s.service_id, _srl2.source_repository_location_id, false
		) RETURNING * INTO _r;
		BEGIN
			UPDATE service_source_repository
			SET is_primary = true
			WHERE service_source_repository_id =
				_r.service_source_repository_id;
		EXCEPTION WHEN unique_violation THEN
			RAISE EXCEPTION '%', SQLERRM USING ERRCODE = 'JH999';
		END;
		RAISE EXCEPTION 'Ugh, It worked!';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;


	RAISE NOTICE 'Cleaning up...';
	RAISE NOTICE 'END source_repository_regression...';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT source_repository_regression();
-- set search_path=jazzhands;
DROP FUNCTION source_repository_regression();

ROLLBACK TO source_repository_regression;

\t off
