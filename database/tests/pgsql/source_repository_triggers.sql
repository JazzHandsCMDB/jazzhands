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

\ir ../../ddl/schema/pgsql/create_service_base_triggers.sql
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
	_srp	source_repository_provider%ROWTYPE;
	_srprj	source_repository_project%ROWTYPE;
	_se		service_endpoint%ROWTYPE;
	_sr1	source_repository%ROWTYPE;
	_sr2	source_repository%ROWTYPE;
BEGIN
	RAISE NOTICE 'source_repository_regression: Begin';

	RAISE NOTICE 'Inserting test data...';

	INSERT INTO val_service_type (service_type) VALUES ('jhtest');

	INSERT INTO service (service_name, service_type) VALUES ('jhtest', 'jhtest') RETURNING * INTO _s;

	INSERT INTO service_endpoint ( service_id )
		VALUES (_s.service_id )
		RETURNING * INTO _se;

	INSERT INTO val_service_source_control_purpose
		( service_source_control_purpose ) VALUES ('jhtest-checkout');

	INSERT INTO val_source_repository_uri_purpose
		( source_repository_uri_purpose ) VALUES ('build-jhtest');

	INSERT INTO val_source_repository_method
		( source_repository_method ) VALUES ('git-jhtest');

	INSERT INTO source_repository_provider
		( source_repository_provider_name, source_repository_method )
		VALUES
		( 'jhtest', 'git-jhtest') RETURNING * INTO _srp;

	INSERT INTO source_repository_project (
		source_repository_project_name, source_repository_provider_id
	) VALUES (
		'JHPROJ', _srp.source_repository_provider_id
	) RETURNING * INTO _srprj;

	INSERT INTO  source_repository (
		source_repository_provider_id, source_repository_project_id,
		source_repository_name
	) VALUES (
		_srp.source_repository_provider_id, _srprj.source_repository_project_id,
		'barz'
	) RETURNING * INTO _sr1;

	INSERT INTO  source_repository (
		source_repository_provider_id, source_repository_project_id,
		source_repository_name
	) VALUES (
		_srp.source_repository_provider_id, _srprj.source_repository_project_id,
		'ack'
	) RETURNING * INTO _sr2;

	INSERT INTO val_source_repository_protocol (
		source_repository_protocol
	) VALUES (
		'jhtest-ssh'
	);

	RAISE NOTICE 'Checking if not setting endpoint or uri fails... ';
	BEGIN
		BEGIN
			INSERT INTO source_repository_provider_uri_template (
				source_repository_provider_id, source_repository_uri_purpose,
				source_repository_protocol, source_repository_template_path_fragment
			) VALUES (
				_srp.source_repository_provider_id, 'build-jhtest',
				'jhtest-ssh', 'ssh://git.thing.com/%{uc_project}/%{repository/'
			);
		EXCEPTION WHEN null_value_not_allowed THEN
			RAISE EXCEPTION '%', SQLERRM USING ERRCODE = 'JH999';
		END;
		RAISE EXCEPTION 'Ugh, It worked!';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE 'Checking if setting both endpoint and uri fails... ';
	BEGIN
		BEGIN
			INSERT INTO source_repository_provider_uri_template(
				source_repository_provider_id, source_repository_uri_purpose,
				source_repository_template_path_fragment,
				source_repository_protocol, source_repository_uri, service_endpoint_id
			) VALUES (
				_srp.source_repository_provider_id, 'build-jhtest',
				'ssh://git.thing.com/%{uc_project}/%{repository/',
				'jhtest-ssh', 'https://example.com/', _se.service_endpoint_id
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
			service_id, source_repository_id, service_source_control_purpose, is_primary
		) VALUES (
			_s.service_id, _sr1.source_repository_id, 'jhtest-checkout', true
		);
		BEGIN
			INSERT INTO service_source_repository (
				service_id, source_repository_id, service_source_control_purpose, is_primary
			) VALUES (
				_s.service_id, _sr2.source_repository_id, 'jhtest-checkout', true
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
			service_id, source_repository_id, service_source_control_purpose, is_primary
		) VALUES (
			_s.service_id, _sr1.source_repository_id, 'jhtest-checkout', true
		);
		INSERT INTO service_source_repository (
			service_id, source_repository_id, service_source_control_purpose, is_primary
		) VALUES (
			_s.service_id, _sr2.source_repository_id, 'jhtest-checkout', false
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
