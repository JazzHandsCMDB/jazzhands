-- Copyright (c) 2017 Todd Kover
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

-- tests this:
-- \ir ../../ddl/schema/pgsql/create_dns_triggers-RETIRE.sql


SAVEPOINT dns_trigger_test;

CREATE OR REPLACE FUNCTION validate_dns_domain_name_triggers() RETURNS BOOLEAN AS $$
DECLARE
	_testrec	dns_domain%ROWTYPE;
	_d1		dns_domain%ROWTYPE;
BEGIN
	RAISE NOTICE '++ Beginning tests of dns_domain_name/soa_name retire triggers...';

	INSERT INTO dns_domain (
		dns_domain_name, dns_domain_type
	) VALUES (
		'example.com', 'service'
	) RETURNING * INTO _testrec;

	RAISE NOTICE 'Checking to see if updates of soa_name propagates...';
	BEGIN
		UPDATE dns_domain
		SET soa_name = 'example.org'
		WHERE dns_domain_id = _testrec.dns_domain_id;

		SELECT * INTO _d1
		FROM dns_domain
		WHERE dns_domain_id = _testrec.dns_domain_id;

		IF _d1.dns_domain_name != 'example.org' THEN
			RAISE EXCEPTION ' IT DOES NOT!';
		END IF;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	RAISE NOTICE 'Checking to see if updates of dns_domain_name propagates...';
	BEGIN
		UPDATE dns_domain
		SET dns_domain_name = 'example.net'
		WHERE dns_domain_id = _testrec.dns_domain_id;

		SELECT * INTO _d1
		FROM dns_domain
		WHERE dns_domain_id = _testrec.dns_domain_id;

		IF _d1.soa_name != 'example.net' THEN
			RAISE EXCEPTION ' IT DOES NOT!';
		END IF;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	RAISE NOTICE 'Checking to see if dns_domain and soa_name error when both updated...';
	BEGIN
		UPDATE dns_domain
		SET dns_domain_name = 'example.net', soa_name = 'example.net'
		WHERE dns_domain_id = _testrec.dns_domain_id;

		RAISE EXCEPTION 'IT DID NOT!';
	EXCEPTION WHEN invalid_parameter_value THEN
		RAISE NOTICE '.... it did!';
	END;

	RAISE NOTICE 'Checking to see if dns_domain and soa_name error when both updated to different things...';
	BEGIN
		UPDATE dns_domain
		SET dns_domain_name = 'example.net', soa_name = 'example.org'
		WHERE dns_domain_id = _testrec.dns_domain_id;

		RAISE EXCEPTION 'IT DID NOT!';
	EXCEPTION WHEN invalid_parameter_value THEN
		RAISE NOTICE '.... it did!';
	END;

	DELETE FROM dns_domain
	WHERE dns_domain_id = _testrec.dns_domain_id;

	RAISE NOTICE '++ End DNS tests...';

	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT validate_dns_domain_name_triggers();
DROP FUNCTION validate_dns_domain_name_triggers();

ROLLBACK TO dns_trigger_test;

\t off
