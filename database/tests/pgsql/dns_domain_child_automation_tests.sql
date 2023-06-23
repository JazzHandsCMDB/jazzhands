-- Copyright (c) 2023 Todd Kover
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
--

\set ON_ERROR_STOP

\ir ../../ddl/schema/pgsql/create_dns_domain_collection_auto_member_triggers.sql

\t on

savepoint pretest;
DROP FUNCTION IF EXISTS dns_domain_child_automation_test();
CREATE FUNCTION dns_domain_child_automation_test() RETURNS BOOLEAN AS $$
DECLARE
	_ddc		dns_domain_collection;
	_domp		INTEGER;
	_domc		INTEGER;
	tallyb		INTEGER;
	tallya		INTEGER;
	_r			RECORD;
BEGIN
	INSERT INTO property (
		property_type, property_name, property_value
	) VALUES (
		'Defaults', '_dnsmname', 'ns.example.com'
	) ON CONFLICT DO NOTHING;

	INSERT INTO property (
		property_type, property_name, property_value
	) VALUES (
		'Defaults', '_dnsrname', 'hostmaster.example.com'
	) ON CONFLICT DO NOTHING;

	INSERT INTO val_dns_domain_collection_type (
		dns_domain_collection_type, manage_child_domains_automatically
	) VALUES (
		'jhtest', true
	);

	INSERT INTO dns_domain_collection (
		dns_domain_collection_name, dns_domain_collection_type
	) VALUES (
		'testcoll', 'jhtest'
	) RETURNING * INTO _ddc;

	_domp := dns_manip.add_dns_domain('example.org', 'service');

	SELECT count(*) INTO tallya FROM dns_domain_collection_dns_domain
		WHERE dns_domain_collection_id = _ddc.dns_domain_collection_id;

	IF tallya != 0 THEN
		RAISE EXCEPTION 'domain oddly already exists in collection';
	END IF;

	RAISE NOTICE 'Checking if adding a child DTRT... ';
	BEGIN
		INSERT INTO dns_domain_collection_dns_domain (
			dns_domain_collection_id, dns_domain_id
		) VALUES (
			_ddc.dns_domain_collection_id, _domp
		);

		SELECT count(*) INTO tallya FROM dns_domain_collection_dns_domain
			WHERE dns_domain_collection_id = _ddc.dns_domain_collection_id;
		IF tallya != 1 THEN
			RAISE EXCEPTION 'domain oddly already exists in collection';
		END IF;

		_domc := dns_manip.add_dns_domain('child1.example.org', 'service');

		SELECT count(*) INTO tallyb FROM dns_domain_collection_dns_domain
			WHERE dns_domain_collection_id = _ddc.dns_domain_collection_id;
		IF tallyb != 2 THEN
			RAISE EXCEPTION
				'child domain did not insert by tally - (%,%)',
				tallya, tallyb;
		END IF;

		delete from dns_change_record where dns_domain_id = _domc;
		DELETE FROM dns_domain_ip_universe WHERE dns_domain_id = _domc;
		DELETE FROM dns_domain WHERE dns_domain_id = _domc;

		SELECT count(*) INTO tallyb FROM dns_domain_collection_dns_domain
			WHERE dns_domain_collection_id = _ddc.dns_domain_collection_id;
		IF tallyb != 1 THEN
			RAISE EXCEPTION
				'child domain did not delete by tally - (%,%)',
				tallya, tallyb;
		END IF;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... ok: (%: %)', SQLSTATE, SQLERRM;
	END;

	RAISE NOTICE 'Checking if adding a child wo/automanagment DTRT... ';
	BEGIN
		UPDATE val_dns_domain_collection_type
			SET manage_child_domains_automatically = false
			WHERE dns_domain_collection_type = 'jhtest';

		INSERT INTO dns_domain_collection_dns_domain (
			dns_domain_collection_id, dns_domain_id
		) VALUES (
			_ddc.dns_domain_collection_id, _domp
		);

		SELECT count(*) INTO tallya FROM dns_domain_collection_dns_domain
			WHERE dns_domain_collection_id = _ddc.dns_domain_collection_id;
		IF tallya != 1 THEN
			RAISE EXCEPTION 'domain oddly already exists in collection';
		END IF;

		_domc := dns_manip.add_dns_domain('child1.example.org', 'service');

		SELECT count(*) INTO tallyb FROM dns_domain_collection_dns_domain
			WHERE dns_domain_collection_id = _ddc.dns_domain_collection_id;
		IF tallyb != 1 THEN
			RAISE EXCEPTION
				'child domain did not insert by tally - (%,%)',
				tallya, tallyb;
		END IF;

		delete from dns_change_record where dns_domain_id = _domc;
		DELETE FROM dns_domain_ip_universe WHERE dns_domain_id = _domc;
		DELETE FROM dns_domain WHERE dns_domain_id = _domc;

		SELECT count(*) INTO tallyb FROM dns_domain_collection_dns_domain
			WHERE dns_domain_collection_id = _ddc.dns_domain_collection_id;
		IF tallyb != 1 THEN
			RAISE EXCEPTION
				'child domain did not delete by tally - (%,%)',
				tallya, tallyb;
		END IF;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '... ok: (%: %)', SQLSTATE, SQLERRM;
	END;


	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT dns_domain_child_automation_test();
DROP FUNCTION dns_domain_child_automation_test();

ROLLBACK TO pretest;
\t off
