-- Copyright (c) 2017-2020 Todd Kover
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

begin;

\t on

SAVEPOINT v_dns_domain_nouniverse_test;

CREATE OR REPLACE FUNCTION validate_v_dns_domain_nouniverse_tests() RETURNS BOOLEAN AS $$
DECLARE
	_testrec	jazzhands_legacy.v_dns_domain_nouniverse%ROWTYPE;
	_d1		jazzhands_legacy.v_dns_domain_nouniverse%ROWTYPE;
	_r		RECORD;
	_f		RECORD;
BEGIN
	RAISE NOTICE '++ Beginning tests of v_dns_domain_nouniverse support...';

	INSERT INTO v_dns_domain_nouniverse (
		soa_name, dns_domain_type,
		soa_ttl, soa_serial, soa_refresh, soa_retry,
		soa_expire, soa_minimum, soa_mname, soa_rname,
		should_generate
	) VALUES (
		'example.com', 'service',
		600, 12345, 5, 7,
		6, 8, 'mname', 'rname',
		'Y'
	) RETURNING * INTO _testrec;

	SELECT * INTO _r FROM v_dns_domain_nouniverse
		WHERE dns_domain_id = _testrec.dns_domain_id;
	IF _testrec != _r THEN
		RAISE EXCEPTION 'INSERT did not match: % %',
			jsonb_pretty(to_jsonb(_testrec)),
			jsonb_pretty(to_jsonb(_r));
	END IF;

	RAISE NOTICE 'Checking to see if changing should_generate works...';
	BEGIN
		UPDATE v_dns_domain_nouniverse
		SET should_generate = 'N'
		WHERE dns_domain_id = _testrec.dns_domain_id
		RETURNING * INTO _testrec;

		SELECT * INTO _r FROM v_dns_domain_nouniverse
			WHERE dns_domain_id = _testrec.dns_domain_id;
		IF _testrec != _r THEN
			RAISE EXCEPTION 'UPDATE did not match: % %',
				jsonb_pretty(to_jsonb(_testrec)),
				jsonb_pretty(to_jsonb(_r));
		END IF;

		IF _testrec.should_generate != 'N' THEN
			RAISE EXCEPTION 'should_generate did not turn off: % %',
				jsonb_pretty(to_jsonb(_testrec)),
				jsonb_pretty(to_jsonb(_r));
		END IF;
		RAISE EXCEPTION '%', 'a-ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
			RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;

	RAISE NOTICE 'Checking to see if soa serial bump works...';
	BEGIN
		UPDATE v_dns_domain_nouniverse
		SET soa_serial = 909
		WHERE dns_domain_id = _testrec.dns_domain_id
		RETURNING * INTO _testrec;

		SELECT * INTO _r FROM v_dns_domain_nouniverse
			WHERE dns_domain_id = _testrec.dns_domain_id;
		IF _testrec != _r THEN
			RAISE EXCEPTION 'UPDATE did not match: % %',
				jsonb_pretty(to_jsonb(_testrec)),
				jsonb_pretty(to_jsonb(_r));
		END IF;
		IF _testrec.soa_serial != 909 THEN
			RAISE EXCEPTION 'should_generate did not turn off: % %',
				jsonb_pretty(to_jsonb(_testrec)),
				jsonb_pretty(to_jsonb(_r));
		END IF;
		RAISE EXCEPTION '%', 'a-ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
			RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;


	DELETE FROM v_dns_domain_nouniverse
	WHERE dns_domain_id = _testrec.dns_domain_id;

	RAISE NOTICE '++ End DNS tests...';

	RETURN true;
END;
$$ LANGUAGE plpgsql
SET search_path=jazzhands_legacy;

SELECT validate_v_dns_domain_nouniverse_tests();
DROP FUNCTION validate_v_dns_domain_nouniverse_tests();

ROLLBACK TO v_dns_domain_nouniverse_test;

\t off
