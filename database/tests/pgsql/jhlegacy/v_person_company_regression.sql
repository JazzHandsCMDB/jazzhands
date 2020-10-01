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

\t on

SAVEPOINT v_person_company_validation_regression;

SET jazzhands.permit_company_insert = 'permit';

-- \ir ../../ddl/schema/pgsql/create_v_person_company_triggers.sql

--
-- Trigger tests
--
CREATE OR REPLACE FUNCTION v_person_company_valid_regression() RETURNS BOOLEAN AS $$
DECLARE
	m		person.person_id%TYPE;
	p		person.person_id%TYPE;
	c		company.company_id%TYPE;
	_vpco	v_person_company%ROWTYPE;
	_vpcn	v_person_company%ROWTYPE;
	_vpcl	v_person_company%ROWTYPE;
BEGIN
	RAISE NOTICE 'v_person_company regression: BEGIN';

	INSERT INTO person  (first_name, last_name) values ('Jethro','Manager')
		RETURNING person_id INTO m;

	INSERT INTO person  (first_name, last_name) values ('Hans','Jazz')
		RETURNING person_id INTO p;
	INSERT INTO company (company_name) values ('Jazzy, inc')
		RETURNING company_id INTO c;

	INSERT INTO val_person_status 
		(person_status, is_enabled, propagate_from_person)
	VALUES
		('active', 'Y', 'N'), 
		('inactive', 'N', 'N');

	INSERT INTO v_person_company (
		person_id, company_id, person_company_status, person_company_relation,
		is_exempt, is_management, is_full_time, description, position_title,
		hire_date, manager_person_id
	) VALUES (
		p, c, 'active', 'employee',
		'Y', 'Y', 'Y', 'dude', 'Chief Wrangler',
		now(), m
	) RETURNING * INTO _vpco;

	SELECT * INTO _vpcn FROM v_person_company
	WHERE person_id = p and company_id = c;

	IF _vpco IS DISTINCT FROM _vpcn THEN
		RAISE EXCEPTION 'Insert Failed % %', _vpco, _vpcn;
	END IF;

	UPDATE v_person_company
	SET termination_date = now(),
		person_company_status = 'inactive',
		description = 'foo'
	WHERE person_id = p and company_id = c
	RETURNING * INTO _vpcl;

	_vpcl.termination_date = now();
	_vpcl.person_company_status = 'inactive';

	SELECT * INTO _vpcn FROM v_person_company
	WHERE person_id = p and company_id = c;

	IF _vpco IS NOT DISTINCT FROM _vpcl THEN
		RAISE EXCEPTION 'Updated changed nothing.';
	END IF;

	IF _vpcl IS DISTINCT FROM _vpcn THEN
		RAISE EXCEPTION 'Update Failed % %', _vpco, _vpcn;
	END IF;

	RAISE NOTICE 'v_person_company regression: DONE';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

SELECT v_person_company_valid_regression();
DROP FUNCTION v_person_company_valid_regression();

SET jazzhands.permit_company_insert TO default;

ROLLBACK TO v_person_company_validation_regression;

\t off
