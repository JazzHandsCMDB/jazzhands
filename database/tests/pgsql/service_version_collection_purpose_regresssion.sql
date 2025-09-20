-- Copyright (c) 2023-2024 Todd Kover
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
SAVEPOINT service_version_collection_purpose_regression;

\ir ../../ddl/schema/pgsql/create_service_automated_collection_triggers.sql
\ir ../../ddl/schema/pgsql/create_service_version_automated_membership_triggers.sql

SAVEPOINT pretest;

--
-- Trigger tests
--
CREATE OR REPLACE FUNCTION service_version_collection_purpose_regression() RETURNS BOOLEAN AS $$
DECLARE
	_r		RECORD;
	_s1		service;
	_s2		service;
	_sv1	service_version;
	_sv2	service_version;
BEGIN
	RAISE NOTICE 'service_version_collection_purpose_regression: Begin';

	INSERT INTO val_service_version_collection_purpose (
		service_version_collection_purpose
	) VALUES (
		'jhtestpurpose'
	);

	INSERT INTO val_service_type ( service_type, service_namespace ) VALUES
		('jhtype1', 'default');

	INSERT INTO service (service_name, service_type) VALUES
		('jhsvc1', 'jhtype1') RETURNING * INTO _s1;
	INSERT INTO service (service_name, service_type) VALUES
		('jhsvc2', 'jhtype1') RETURNING * INTO _s2;

	INSERT INTO service_version ( service_id, service_version_name )
		VALUES (_s1.service_Id, '1.2.3.4') RETURNING * INTO _sv1;
	INSERT INTO service_version ( service_id, service_version_name )
		VALUES (_s2.service_Id, '5.6.7.8') RETURNING * INTO _sv2;

	RAISE NOTICE 'Checking if adding wrong service_version to purpose collection fails for all fails';
	BEGIN
		INSERT INTO service_version_collection_service_version (
			service_version_collection_id, service_version_id
		) SELECT service_version_collection_id, _sv2.service_version_id
		FROM service_version_collection_purpose
		WHERE service_version_collection_purpose = 'all'
		AND service_id = _s1.service_Id;

		RAISE EXCEPTION 'Ugh, It worked!';
	EXCEPTION WHEN foreign_key_violation THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE 'Checking if adding wrong service_version to purpose collection fails for current fails';
	BEGIN
		INSERT INTO service_version_collection_service_version (
			service_version_collection_id, service_version_id
		) SELECT service_version_collection_id, _sv2.service_version_id
		FROM service_version_collection_purpose
		WHERE service_version_collection_purpose = 'current'
		AND service_id = _s1.service_Id;

		RAISE EXCEPTION 'Ugh, It worked!';
	EXCEPTION WHEN foreign_key_violation THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE 'Checking if changing a service_id on a service version works...';
	BEGIN
		UPDATE service_version SET service_id = _s2.service_id
		WHERE service_version_id = _sv1.service_version_id;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... it did : (%: %)', SQLSTATE, SQLERRM;
	END;

	RAISE NOTICE 'Checking if setting up a new service_version_collection_purpose works...';
	BEGIN
		INSERT INTO service_version_collection_purpose (
			service_version_collection_id,
			service_version_collection_purpose,
			service_id
		) SELECT service_version_collection_id, 'jhtestpurpose',
			_s1.service_id
		FROM service_version_collection_purpose
		WHERE service_version_collection_purpose = 'all'

		AND service_id = _s1.service_Id;
			RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... it did : (%: %)', SQLSTATE, SQLERRM;
	END;

	RAISE NOTICE 'Checking if setting up a new bogus service_version_collection_purpose fails...';
	BEGIN
		INSERT INTO service_version_collection_purpose (
			service_version_collection_id,
			service_version_collection_purpose,
			service_id
		) SELECT service_version_collection_id, 'jhtestpurpose',
			_s2.service_id
		FROM service_version_collection_purpose
		WHERE service_version_collection_purpose = 'all'
		AND service_id = _s1.service_Id;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN foreign_key_violation THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE 'Cleaning up...';

	RAISE NOTICE 'END service_version_collection_purpose_regression...';
	RETURN true;

END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT service_version_collection_purpose_regression();
-- set search_path=jazzhands;
DROP FUNCTION service_version_collection_purpose_regression();

ROLLBACK TO service_version_collection_purpose_regression;

\t off
