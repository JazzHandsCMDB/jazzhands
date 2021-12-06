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

-- $Id


\set ON_ERROR_STOP

\t on
SAVEPOINT service_relationship_regression;

\ir ../../ddl/schema/pgsql/create_schema_relationship_triggers.sql

SAVEPOINT pretest;

--
-- Trigger tests
--
CREATE OR REPLACE FUNCTION service_relationship_regression() RETURNS BOOLEAN AS
$$
DECLARE
	_t		TEXT;
	_r		RECORD;
	_d		RECORD;
	_s1		service%ROWTYPE;
	_s2		service%ROWTYPE;
	_s3		service%ROWTYPE;
	_sv1	service_version%ROWTYPE;
	_sv2	service_version%ROWTYPE;
	_sv2b	service_version%ROWTYPE;
	_sv3	service_version%ROWTYPE;
	_svx	service_version%ROWTYPE;
BEGIN
	RAISE NOTICE 'service_relationship_regression: Begin';

	INSERT INTO val_service_type (service_type) VALUES ('jhtest');

	INSERT INTO service (service_name, service_type)
		VALUES ('jhsrv1', 'jhtest') RETURNING * INTO _s1;
	INSERT INTO service_version (service_id, service_version_name)
		VALUES (_s1.service_id, '1.0.0') RETURNING * INTO _sv1;

	INSERT INTO service (service_name, service_type)
		VALUES ('jhsrv2', 'jhtest') RETURNING * INTO _s2;
	INSERT INTO service_version (service_id, service_version_name)
		VALUES (_s2.service_id, '2.0.0') RETURNING * INTO _sv2;
	INSERT INTO service_version (service_id, service_version_name)
		VALUES (_s2.service_id, '2.0.1') RETURNING * INTO _sv2b;

	INSERT INTO service (service_name, service_type)
		VALUES ('jhsrv3', 'jhtest') RETURNING * INTO _s3;
	INSERT INTO service_version (service_id, service_version_name)
		VALUES (_s3.service_id, '3.0.0') RETURNING * INTO _sv3;

	--	EXCEPTION WHEN unique_violation THEN
	--		RAISE EXCEPTION '%', SQLERRM USING ERRCODE = 'JH999';

	RAISE NOTICE 'Testing if just an unbounded service works...';
	BEGIN
		INSERT INTO service_relationship (
			service_version_id, service_relationship_type,
			service_version_restriction_service_id
		) VALUES (
			_sv1.service_version_id, 'depend',
			_s2.service_id
		) RETURNING * INTO _r;

		SELECT * INTO _d FROM service_relationship
			WHERE service_relationship_id = _r.service_relationship_id;
		IF _d != _r THEN
			RAISE EXCEPTION 'Weird insert % %', to_jsonb(_r), to_jsonb(_d);
		END IF;
		RAISE EXCEPTION 'It worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE 'Testing if just an unbounded service version works...';
	BEGIN
		INSERT INTO service_relationship (
			service_version_id, service_relationship_type,
			related_service_version_id
		) VALUES (
			_sv1.service_version_id, 'depend',
			_sv2.service_version_id
		) RETURNING * INTO _r;
		SELECT * INTO _d FROM service_relationship
			WHERE service_relationship_id = _r.service_relationship_id;
		IF _d != _r THEN
			RAISE EXCEPTION 'Weird insert % %', to_jsonb(_r), to_jsonb(_d);
		END IF;
		RAISE EXCEPTION 'It worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE 'Testing if just an bounded service works...';
	BEGIN
		INSERT INTO service_relationship (
			service_version_id, service_relationship_type,
			service_version_restriction_service_id,
			service_version_restriction
		) VALUES (
			_sv1.service_version_id, 'depend',
			_sv2.service_id,
			'>= 2.0') RETURNING * INTO _r;
		SELECT * INTO _d FROM service_relationship
			WHERE service_relationship_id = _r.service_relationship_id;
		IF _d != _r THEN
			RAISE EXCEPTION 'Weird insert % %', to_jsonb(_r), to_jsonb(_d);
		END IF;
		RAISE EXCEPTION 'It worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE 'Testing if unbounded service and service_version_id fails...';
	BEGIN
		BEGIN
			INSERT INTO service_relationship (
				service_version_id, service_relationship_type, service_version_restriction_service_id,
				related_service_version_id
			) VALUES (
				_sv1.service_version_id, 'depend', _sv2.service_id,
				_sv2.service_version_id) RETURNING * INTO _r;
		EXCEPTION WHEN not_null_violation THEN
			RAISE EXCEPTION '%', SQLERRM USING ERRCODE = 'JH999';
		END;
		RAISE EXCEPTION 'It worked (ugh!)';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE 'Checking if depending on another version of yourself fails';
	BEGIN
		BEGIN
			INSERT INTO service_relationship (
				service_version_id, service_relationship_type,
				related_service_version_id
			) VALUES (
				_sv2.service_version_id, 'depend',
				_sv2b.service_version_id) RETURNING * INTO _r;
		EXCEPTION WHEN invalid_parameter_value THEN
			RAISE EXCEPTION 'It did (%)', SQLERRM USING ERRCODE = 'JH999';
		END;
		RAISE EXCEPTION 'It worked (% % %)',
			jsonb_pretty(to_jsonb(_r)),
			jsonb_pretty(to_jsonb(_sv2)),
			jsonb_pretty(to_jsonb(_sv2b));
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE 'Checking if depending on yourself fails';
	BEGIN
		BEGIN
			INSERT INTO service_relationship (
				service_version_id, service_relationship_type,
				service_version_restriction_service_id
			) VALUES (
				_sv2.service_version_id, 'depend',
				_sv2.service_id) RETURNING * INTO _r;
		EXCEPTION WHEN invalid_parameter_value THEN
			RAISE EXCEPTION 'It did (%)', SQLERRM USING ERRCODE = 'JH999';
		END;
		RAISE EXCEPTION 'It worked (% % %)',
			jsonb_pretty(to_jsonb(_r)),
			jsonb_pretty(to_jsonb(_sv2)),
			jsonb_pretty(to_jsonb(_sv2b));
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE 'Checking if default regexp fail as expected...';
	FOR _r IN
		SELECT CAST(key AS text) as str,  CAST(value AS boolean) AS exp
		FROM (
			SELECT * FROM jsonb_each('{
				"hate":				false,
				"4.4":				false,
				"= 4.4":			true,
				"<= 4.4 > 5":		true,
				"<= 4.4> 5":		false,
				"<=  4.4   > 5 ":	false,
				"< 1.2.3-0":		true,
				"> 1.2.3-0 < 2":	false
		}') ) z
	LOOP
		BEGIN
			BEGIN
				INSERT INTO service_relationship (
					service_version_id, service_relationship_type,
					service_version_restriction_service_id,
					service_version_restriction
				) VALUES (
					_sv1.service_version_id, 'depend',
					_sv2.service_id,
					_r.str
				);

				IF _r.exp = true THEN
					RAISE EXCEPTION '% suceeded as expected', _r.str
				 		USING ERRCODE = 'JH999';
				ELSE
					RAISE EXCEPTION '% DID NOT FAIL', _r.str;
				END IF;
			EXCEPTION WHEN invalid_parameter_value THEN
				IF _r.exp = false THEN
					RAISE EXCEPTION '% failed as expected', _r.str
						USING  ERRCODE = 'JH999';
				ELSE
					RAISE EXCEPTION '% failed unexpectedly', _r.str;
				END IF;
			END;
		EXCEPTION WHEN SQLSTATE 'JH999' THEN
			RAISE NOTICE '... %', SQLERRM;
		END;
	END LOOP;

	---------------------------------------------------------------------

	RAISE NOTICE 'Checking if custom regexp succeeds as expected';
	BEGIN
		INSERT INTO val_service_type (
			service_type, service_version_restriction_regular_expression
		) VALUES (
			'jhtestre', '^[a-z]$'
		);
		WITH x AS (
			INSERT INTO service (service_name, service_type)
				VALUES ('jhtestres', 'jhtestre')
			RETURNING *
		) INSERT INTO service_version (
			service_id, service_version_name
		) SELECT x.service_id, '2.0' FROM x RETURNING * INTO _svx;

		BEGIN
			INSERT INTO service_relationship (
					service_version_id, service_relationship_type,
					service_version_restriction_service_id,
					service_version_restriction
				) VALUES (
					_svx.service_version_id, 'depend',
					_sv2.service_id,
					'a'
				) RETURNING * INTO _r;
			RAISE EXCEPTION 'ugh, it worked!' USING ERRCODE = 'JH999';
		EXCEPTION WHEN invalid_parameter_value THEN
			GET STACKED DIAGNOSTICS _t = PG_EXCEPTION_HINT ;
			RAISE EXCEPTION 'It failed  (% [%])', SQLERRM, _t;
		END;
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE 'Checking if custom regexp fails as expected';
	BEGIN
		INSERT INTO val_service_type (
			service_type, service_version_restriction_regular_expression
		) VALUES (
			'jhtestre', '^[a-z]$'
		);
		WITH x AS (
			INSERT INTO service (service_name, service_type)
				VALUES ('jhtestres', 'jhtestre')
			RETURNING *
		) INSERT INTO service_version (
			service_id, service_version_name
		) SELECT x.service_id, '2.0' FROM x RETURNING * INTO _svx;

		BEGIN
			INSERT INTO service_relationship (
					service_version_id, service_relationship_type,
					service_version_restriction_service_id,
					service_version_restriction
				) VALUES (
					_svx.service_version_id, 'depend',
					_sv2.service_id,
					'aa'
				) RETURNING * INTO _r;
			RAISE EXCEPTION 'ugh, it worked!';
		EXCEPTION WHEN invalid_parameter_value THEN
			GET STACKED DIAGNOSTICS _t = PG_EXCEPTION_HINT ;
			RAISE EXCEPTION 'It did (% [%])', SQLERRM, _t
				USING ERRCODE = 'JH999';
		END;
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	---------------------------------------------------------------------
	RAISE NOTICE 'Checking if changing regexp type to invalid works';
	BEGIN
		INSERT INTO val_service_type (
			service_type, service_version_restriction_regular_expression
		) VALUES (
			'jhtestre', '^[a-z]$'
		);
		WITH x AS (
			INSERT INTO service (service_name, service_type)
				VALUES ('jhtestres', 'jhtestre')
			RETURNING *
		) INSERT INTO service_version (
			service_id, service_version_name
		) SELECT x.service_id, '2.0' FROM x RETURNING * INTO _svx;

		INSERT INTO service_relationship (
			service_version_id, service_relationship_type,
			service_version_restriction_service_id,
			service_version_restriction
		) VALUES (
			_svx.service_version_id, 'depend',
			_sv2.service_id,
			'a'
		) RETURNING * INTO _r;
		BEGIN
			UPDATE val_service_type
			SET service_version_restriction_regular_expression = '^[0-9]$'
			WHERE service_type = 'jhtestre';

			RAISE EXCEPTION 'ugh, it worked!';
		EXCEPTION WHEN invalid_parameter_value THEN
			GET STACKED DIAGNOSTICS _t = PG_EXCEPTION_HINT ;
			RAISE EXCEPTION 'It failed  (% [%])', SQLERRM, _t
				USING ERRCODE = 'JH999';
		END;
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;
	RAISE NOTICE 'Checking if NULL to invalid works as expected';
	BEGIN
		INSERT INTO val_service_type (
			service_type
		) VALUES (
			'jhtestre'
		);
		WITH x AS (
			INSERT INTO service (service_name, service_type)
				VALUES ('jhtestres', 'jhtestre')
			RETURNING *
		) INSERT INTO service_version (
			service_id, service_version_name
		) SELECT x.service_id, '2.0' FROM x RETURNING * INTO _svx;

		INSERT INTO service_relationship (
			service_version_id, service_relationship_type,
			service_version_restriction_service_id,
			service_version_restriction
		) VALUES (
			_svx.service_version_id, 'depend',
			_sv2.service_id,
			'> 1.2'
		) RETURNING * INTO _r;
		BEGIN
			UPDATE val_service_type
			SET service_version_restriction_regular_expression = '^[0-9]$'
			WHERE service_type = 'jhtestre';

			RAISE EXCEPTION 'ugh, it worked!';
		EXCEPTION WHEN invalid_parameter_value THEN
			GET STACKED DIAGNOSTICS _t = PG_EXCEPTION_HINT ;
			RAISE EXCEPTION 'It failed  (% [%])', SQLERRM, _t
				USING ERRCODE = 'JH999';
		END;
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE 'Checking if changing regexp type to still valid works';
	BEGIN
		INSERT INTO val_service_type (
			service_type, service_version_restriction_regular_expression
		) VALUES (
			'jhtestre', '^[a-z]$'
		);
		WITH x AS (
			INSERT INTO service (service_name, service_type)
				VALUES ('jhtestres', 'jhtestre')
			RETURNING *
		) INSERT INTO service_version (
			service_id, service_version_name
		) SELECT x.service_id, '2.0' FROM x RETURNING * INTO _svx;

		INSERT INTO service_relationship (
			service_version_id, service_relationship_type,
			service_version_restriction_service_id,
			service_version_restriction
		) VALUES (
			_svx.service_version_id, 'depend',
			_sv2.service_id,
			'a'
		) RETURNING * INTO _r;
		BEGIN
			UPDATE val_service_type
			SET service_version_restriction_regular_expression = '^[a-z]+$'
			WHERE service_type = 'jhtestre';

			RAISE EXCEPTION 'it worked!' USING ERRCODE = 'JH999';
		EXCEPTION WHEN invalid_parameter_value THEN
			GET STACKED DIAGNOSTICS _t = PG_EXCEPTION_HINT ;
			RAISE EXCEPTION 'It failed  (% [%])', SQLERRM, _t;
		END;
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	RAISE NOTICE 'Checking if NULL to valid works as expected';
	BEGIN
		INSERT INTO val_service_type (
			service_type
		) VALUES (
			'jhtestre'
		);
		WITH x AS (
			INSERT INTO service (service_name, service_type)
				VALUES ('jhtestres', 'jhtestre')
			RETURNING *
		) INSERT INTO service_version (
			service_id, service_version_name
		) SELECT x.service_id, '2.0' FROM x RETURNING * INTO _svx;

		INSERT INTO service_relationship (
			service_version_id, service_relationship_type,
			service_version_restriction_service_id,
			service_version_restriction
		) VALUES (
			_svx.service_version_id, 'depend',
			_sv2.service_id,
			'> 1.2'
		) RETURNING * INTO _r;
		BEGIN
			UPDATE val_service_type
			SET service_version_restriction_regular_expression = '^.*$'
			WHERE service_type = 'jhtestre';

			RAISE EXCEPTION 'it worked!' USING ERRCODE = 'JH999';
		EXCEPTION WHEN invalid_parameter_value THEN
			GET STACKED DIAGNOSTICS _t = PG_EXCEPTION_HINT ;
			RAISE EXCEPTION 'It failed  (% [%])', SQLERRM, _t;
		END;
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... It did (%)', SQLERRM;
	END;

	---------------------------------------------------------------------

	RAISE NOTICE 'Cleaning up...';
	RAISE NOTICE 'END service_relationship_regression...';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT service_relationship_regression();
-- set search_path=jazzhands;
DROP FUNCTION service_relationship_regression();

ROLLBACK TO service_relationship_regression;

\t off
