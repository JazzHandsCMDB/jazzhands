-- Copyright (c) 2020 Todd Kover
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

-- tests this:
\ir ../../ddl/views/approval/create_audit_views.sql
\ir ../../pkg/pgsql/approval_utils.sql
-- \ir ../../pkg/pgsql/property_utils.sql

DROP FUNCTION IF EXISTS
	approval_utils.approve(approval_instance_item_id integer, approved text, approving_account_id integer, new_value text);
DROP FUNCTION IF EXISTS
	approval_utils.approve(approval_instance_item_id integer, approved boolean, approving_account_id integer, new_value text);

SAVEPOINT test_approval_subsystem;

CREATE OR REPLACE FUNCTION test_approval_subsystem() RETURNS BOOLEAN AS $$
DECLARE
	_hire		DATE;
	_r			RECORD;
	_d			RECORD;
	_ph			RECORD;
	_bool		BOOLEAN;
	_tally		INTEGER;
	_ap			approval_process%ROWTYPE;
	_apc		approval_process_chain%ROWTYPE;
	_recheck	approval_process_chain%ROWTYPE;
	_jira		approval_process_chain%ROWTYPE;
	_startapc	approval_process_chain%ROWTYPE;
	_pnc		property_name_collection%ROWTYPE;
	_acct		account%ROWTYPE;
	_empa		account%ROWTYPE;
	_mgr1a		account%ROWTYPE;
	_mgr2a		account%ROWTYPE;
	_randoa		account%ROWTYPE;
	_companyid	company.company_id%TYPE;
	_arlmid		account_realm.account_realm_id%TYPE;
BEGIN
	RAISE NOTICE '++ Beginning tests of approval subsystem...';

	INSERT INTO val_property_name_collection_type (
		property_name_collection_type
	) VALUES (
		'JHTEST'
	);

	--
	-- This comes form init/initialize_jazzhands.sql
	--
	select * INTO _pnc FROM property_name_collection
	WHERE property_name_collection_name = 'ReportingAttestation'
	AND property_name_collection_type = 'attestation';

	--
	-- build approval chain
	--
	RAISE NOTICE '++ Build approval process chains...';

	INSERT INTO approval_process_chain (
		approval_process_chain_name, approval_chain_response_period,
		refresh_all_data, message, email_message,
		approving_entity,
		accept_approval_process_chain_id,
		reject_approval_process_chain_id,
		permit_immediate_resolution
	) VALUES (
		'Jira Process', '1 week',
		true, 'message', 'email_message',
		'jira-hr',
		_recheck.approval_process_chain_id,
		_recheck.approval_process_chain_id,
		false
	) RETURNING * INTO _jira;

	INSERT INTO approval_process_chain (
		approval_process_chain_name, approval_chain_response_period,
		refresh_all_data, message, email_message,
		approving_entity,
		accept_approval_process_chain_id,
		reject_approval_process_chain_id,
		permit_immediate_resolution
	) VALUES (
		'Start Process', '1 week',
		true, 'message', 'email_message',
		'manager',
		NULL,
		_jira.approval_process_chain_id,
		false
	) RETURNING * INTO _startapc;

	INSERT INTO approval_process_chain (
		approval_process_chain_name, approval_chain_response_period,
		refresh_all_data, message, email_message,
		approving_entity,
		accept_approval_process_chain_id,
		reject_approval_process_chain_id,
		permit_immediate_resolution
	) VALUES (
		'Recheck Data', '1 week',
		true, 'message', 'email_message',
		'recertify',
		NULL,
		_jira.approval_process_chain_id,
		false
	) RETURNING * INTO _recheck;

	-- build a process

	INSERT INTO approval_process (
		approval_process_name,
		approval_process_type,
		description,
		first_approval_process_chain_id,
		property_name_collection_id,
		approval_expiration_action,
		attestation_frequency,
		attestation_offset
	) VALUES (
		'ReportingAttest',
		'attestation',
		'unit test case',
		_startapc.approval_process_chain_id,
		_pnc.property_name_collection_id,
		'pester',
		'quarterly',
		0
	) RETURNING * INTO _ap;

	RAISE NOTICE '++ Setting up teams...';
	INSERT INTO account_collection (
		account_collection_name, account_collection_type
	) VALUES (
		'Team Evil', 'department'
	);

	RAISE NOTICE '++ Adding some employees...';
	INSERT INTO account_realm ( account_realm_name ) VALUES ('Evil')
		RETURNING account_realm_id INTO _arlmid;

	SELECT company_manip.add_company(
		company_name		:= 'Evil, Example Corp',
		company_types		:= ARRAY['corporate family'],
		account_realm_id	:= _arlmid
	) INTO _companyid;

	_hire := cast(now()::date - '1 year'::interval AS date);

	WITH aui AS (
		SELECT 	*
		FROM person_manip.add_user(
			company_Id 				:=	_companyid,
			person_company_relation	:= 'employee',
			first_name				:= 'Edward',
			last_name				:= 'Alderson',
			position_title			:= 'CEO',
			hire_date				:= _hire,
			department_name			:= 'FSociety'
		) aui
	) SELECT account_id INTO _acct.account_id FROM aui;
	SELECT * INTO _acct FROM account WHERE account_id = _acct.account_id;

	IF _acct.person_id IS NULL THEN
		RAISE EXCEPTION 'Issue getting the data for TOP manager';
	END IF;

	WITH aui AS (
		SELECT 	*
		FROM person_manip.add_user(
			company_Id 				:=	_companyid,
			person_company_relation	:= 'employee',
			first_name				:= 'Elliott',
			middle_name				:= 'Robot',
			last_name				:= 'Alderson',
			position_title			:= 'Troubled Hacker',
			hire_date				:= _hire,
			department_name			:= 'FSociety',
			manager_person_id		:= _acct.person_id
		) aui
	) SELECT account_id INTO _mgr1a.account_id FROM aui;
	SELECT * INTO _mgr1a FROM account WHERE account_id = _mgr1a.account_id;

	PERFORM a.*
	FROM person_manip.add_user(
		company_Id 				:=	_companyid,
		person_company_relation	:= 'employee',
		first_name				:= 'Darline',
		last_name				:= 'Alderson',
		position_title			:= 'Minion',
		department_name			:= 'FSociety',
		hire_date				:= _hire,
		manager_person_id		:= _acct.person_id
	) au JOIN account a USING (account_id);

	WITH aui AS (
		SELECT 	*
		FROM person_manip.add_user(
			company_Id 				:=	_companyid,
			person_company_relation	:= 'employee',
			first_name				:= 'Tyrell',
			last_name				:= 'Wellnick',
			position_title			:= 'CEO',
			hire_date				:= _hire,
			department_name			:= 'Team Evil'
		) aui
	) SELECT account_id INTO _mgr2a.account_id FROM aui;
	SELECT * INTO _mgr2a FROM account WHERE account_id = _mgr2a.account_id;

	WITH aui AS (
		SELECT a.*
		FROM person_manip.add_user(
			company_Id 				:=	_companyid,
			person_company_relation	:= 'employee',
			first_name				:= 'Angela',
			last_name				:= 'Moss',
			position_title			:= 'Business Sales',
			department_name			:= 'Team Evil',
			hire_date				:= _hire,
			manager_person_id		:= _mgr1a.person_id
		) aui JOIN account a USING (account_id)
	) SELECT account_id INTO _empa.account_id FROM aui;
	SELECT * INTO _empa FROM account WHERE account_id = _empa.account_id;

	WITH aui AS (
		SELECT 	*
		FROM person_manip.add_user(
			company_Id 				:=	_companyid,
			person_company_relation	:= 'employee',
			first_name				:= 'Random',
			last_name				:= 'Ando',
			position_title			:= 'Marketing',
			hire_date				:= _hire,
			department_name			:= 'Marketing',
			manager_person_id		:= _acct.person_id
		) aui
	) SELECT account_id INTO _randoa.account_id FROM aui;
	SELECT * INTO _randoa FROM account WHERE account_id = _randoa.account_id;

	PERFORM a.*
	FROM person_manip.add_user(
		company_Id 				:=	_companyid,
		person_company_relation	:= 'employee',
		first_name				:= 'Hacker II',
		last_name				:= 'Sharon',
		position_title			:= 'Knowles',
		department_name			:= 'Team Evil',
		hire_date				:= _hire,
		manager_person_id		:= _mgr2a.person_id
	) au JOIN account a USING (account_id);

	--
	-- helpful when developing, but normally noise.
	--
	IF 0 = 1 THEN
		FOR _r IN SELECT account_id, login FROM account
		LOOP
			RAISE NOTICE '%', to_json(_r);
		END LOOP;

		FOR _r IN SELECT account_id, manager_account_id FROM v_account_manager_hier
		LOOP
			RAISE NOTICE '%', to_json(_r);
		END LOOP;
		_r := NULL;
	END IF;

	RAISE NOTICE '++ Building an attestation...';
	SELECT approval_utils.build_attest() INTO _tally;
	RAISE NOTICE ' ... %', _tally;

	IF _tally = 0 THEN
		RAISE EXCEPTION 'Attestation did not get setup.  Bad.';
	END IF;

	RAISE NOTICE 'Checking to see if approving everything works and closes';
	BEGIN
		BEGIN
			FOR _r IN SELECT approval_utils.approve(
					approval_instance_item_id := ai.approval_instance_item_id,
					approved := true,
					approving_account_id := a.account_id
				)  AS bool, account_id, approval_instance_id
				FROM approval_instance_item ai
				JOIN approval_instance_step ais
					USING (approval_instance_step_id)
				JOIN account a ON a.account_id = ais.approver_account_id
			LOOP
				IF NOT _r.bool THEN
					RAISE EXCEPTION 'approve did not succeed on %', to_json(_r);
				END IF;
			END LOOP;

			SELECT count(*)
				INTO _tally
				FROM approval_instance
				WHERE approval_end IS NULL
				AND approval_instance_id = _r.approval_instance_id;

			IF _tally != 0 THEN
				RAISE EXCEPTION 'approval did not complete - %', _tally;
			END IF;

			RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
		END;
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	RAISE NOTICE 'Checking to if rejecting something triggers a reject step';
	BEGIN
		SELECT approval_utils.approve(
			approval_instance_item_id := ai.approval_instance_item_id,
			approved := false,
			approving_account_id := a.account_id
		)  AS bool, approver_account_id, approval_instance_item_id
		INTO _r
		FROM approval_instance_item ai
		JOIN approval_instance_step ais
			USING (approval_instance_step_id)
		JOIN account a ON a.account_id = ais.approver_account_id
		LIMIT 1;

		_d := NULL;
		SELECT ai.*, approval_type INTO _d
		FROM approval_instance_item ai
			JOIN approval_instance_step USING (approval_instance_step_id)
		WHERE  approval_instance_item_id IS NOT NULL
		AND approval_instance_item_id IN (
			SELECT next_approval_instance_item_id
			FROM approval_instance_item
			WHERE approval_instance_item_id = _r.approval_instance_item_id
		);

		IF _d.approval_instance_item_id IS NULL OR
			_d.approval_type != 'jira-hr'
		THEN
			RAISE EXCEPTION '... failed %', jsonb_pretty(to_jsonb(_d));
		END IF;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	RAISE NOTICE 'Checking to if rejecting something with early termination works';
	BEGIN
		SELECT approval_utils.approve(
			approval_instance_item_id := ai.approval_instance_item_id,
			approved := false,
			approving_account_id := a.account_id,
			terminate_chain := true
		)  AS bool, approver_account_id, approval_instance_item_id
		INTO _r
		FROM approval_instance_item ai
		JOIN approval_instance_step ais
			USING (approval_instance_step_id)
		JOIN account a ON a.account_id = ais.approver_account_id
		LIMIT 1;

		_d := NULL;
		SELECT ai.*, approval_type INTO _d
		FROM approval_instance_item ai
			JOIN approval_instance_step USING (approval_instance_step_id)
		WHERE  approval_instance_item_id IS NOT NULL
		AND approval_instance_item_id IN (
			SELECT next_approval_instance_item_id
			FROM approval_instance_item
			WHERE approval_instance_item_id = _r.approval_instance_item_id
		);

		IF _d.approval_instance_item_id IS NULL OR
			_d.approval_type = 'jira-hr'
		THEN
			RAISE EXCEPTION '... failed %', jsonb_pretty(to_jsonb(_d));
		END IF;

		RAISE EXCEPTION '.... it worked!  (ABD!)';
	EXCEPTION WHEN error_in_assignment THEN
		RAISE NOTICE '.... it did!';
	END;

	RAISE NOTICE 'Checking to if rejecting something triggers early term';
	BEGIN
		SELECT approval_utils.approve(
			approval_instance_item_id := ai.approval_instance_item_id,
			approved := false,
			approving_account_id := a.account_id
		)  AS bool, approver_account_id, approval_instance_item_id
		INTO _r
		FROM approval_instance_item ai
		JOIN approval_instance_step ais
			USING (approval_instance_step_id)
		JOIN account a ON a.account_id = ais.approver_account_id
		LIMIT 1;

		_d := NULL;
		SELECT ai.*, approval_type, approver_account_id
		INTO _d
		FROM approval_instance_item ai
			JOIN approval_instance_step USING (approval_instance_step_id)
		WHERE  approval_instance_item_id IS NOT NULL
		AND approval_instance_item_id IN (
			SELECT next_approval_instance_item_id
			FROM approval_instance_item
			WHERE approval_instance_item_id = _r.approval_instance_item_id
		);

		IF _d.approval_instance_item_id IS NULL OR
			_d.approval_type != 'jira-hr'
		THEN
			RAISE EXCEPTION '... failed %', jsonb_pretty(to_jsonb(_d));
		END IF;

		SELECT approval_utils.approve(
			approval_instance_item_id := _d.approval_instance_item_id,
			approved := false,
			approving_account_id := _d.approver_account_id
		)  AS bool, approver_account_id, approval_instance_item_id
		INTO _r
		FROM approval_instance_item ai
		JOIN approval_instance_step ais
			USING (approval_instance_step_id)
		JOIN account a ON a.account_id = ais.approver_account_id
		WHERE approval_instance_item_id = _d.approval_instance_item_id;

		_d := NULL;
		SELECT *
			INTO _d
			FROM approval_instance_item
			WHERE approval_instance_item_id = _r.approval_instance_item_id;

		IF _d.next_approval_instance_item_id IS NOT NULL THEN
			RAISE EXCEPTION '... It did not!'
				USING ERRCODE = 'error_in_assignment';
		END IF;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did!';
	END;

	RAISE NOTICE 'Checking to see if bad approver fails ';
	BEGIN
		SELECT approval_utils.approve(
			approval_instance_item_id := ai.approval_instance_item_id,
			approved := false,
			approving_account_id := _mgr2a.account_id
		)  AS bool, approver_account_id, approval_instance_item_id
		INTO _r
		FROM approval_instance_item ai
		JOIN approval_instance_step ais
			USING (approval_instance_step_id)
		JOIN account a ON a.account_id = ais.approver_account_id
		WHERE account_id = _mgr1a.account_id
		LIMIT 1;

		IF _r.bool THEN
			RAISE EXCEPTION 'It worked! (bad)';
		END IF;

		RAISE EXCEPTION 'it didn not! (BAD)';
	EXCEPTION WHEN error_in_assignment THEN
		RAISE NOTICE '.... it did! (GOOD)';
	END;

	RAISE NOTICE 'Checking to see if reporting chain can approve things.';
	BEGIN
		SELECT ai.*, approver_account_id
		INTO _r
		FROM approval_instance_item ai
		JOIN approval_instance_step ais
			USING (approval_instance_step_id)
		JOIN account a ON a.account_id = ais.approver_account_id
		WHERE account_id = _mgr1a.account_id
		LIMIT 1;

		RAISE NOTICE '-> %, %', _acct.account_id, to_json(_r);

		SELECT approval_utils.approve(
			approval_instance_item_id := _r.approval_instance_item_id,
			approved := true,
			approving_account_id := _acct.account_id
		)  AS bool
		INTO _bool;

		IF NOT _bool THEN
			RAISE EXCEPTION 'It worked! (bad) %',  jsonb_pretty(to_jsonb(_d));
		END IF;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (GOOD)';
	END;

	RAISE NOTICE 'Checking to see if rejecting a terminated employee burns everything to the ground...';
	BEGIN
		SELECT ai.*,
			account_id, person_id, company_id,
			approver_account_id
		INTO _r
		FROM approval_instance_item ai
		JOIN approval_instance_step ais
			USING (approval_instance_step_id)
		JOIN approval_instance_link al
			USING (approval_instance_link_id)
		JOIN jazzhands_audit.account_collection_account aca ON
			aca."aud#seq" = al.acct_collection_acct_seq_id
		JOIN account a USING (account_id)
		LIMIT 1;

		UPDATE person_company SET person_company_status = 'terminated'
			WHERE person_id = _r.person_id AND company_id = _r.company_id;
		-- this is probably unnecessary.
		UPDATE account SET account_status = 'terminated'
			WHERE account_id = _r.account_id
			AND account_status != 'terminated';


		SELECT approval_utils.approve(
			approval_instance_item_id := _r.approval_instance_item_id,
			approved := false,
			approving_account_id := _r.approver_account_id
		)  AS bool
		INTO _bool;

		-- IF NOT _bool THEN
		--	RAISE EXCEPTION 'It failed! (bad) %',  jsonb_pretty(to_jsonb(_r));
		-- END IF;

		RAISE EXCEPTION 'worked' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (GOOD)';
	END;

	RAISE NOTICE 'Checking to see if rando can not approve';
	BEGIN
		SELECT ai.*, approver_account_id
		INTO _r
		FROM approval_instance_item ai
		JOIN approval_instance_step ais
			USING (approval_instance_step_id)
		JOIN account a ON a.account_id = ais.approver_account_id
		WHERE account_id = _mgr1a.account_id
		LIMIT 1;

		SELECT approval_utils.approve(
			approval_instance_item_id := _r.approval_instance_item_id,
			approved := true,
			approving_account_id := _randoa.account_id
		)  AS bool
		INTO _bool;

		IF NOT _bool THEN
			RAISE EXCEPTION 'It worked! (bad) %',  jsonb_pretty(to_jsonb(_d));
		END IF;
	EXCEPTION WHEN error_in_assignment THEN
		RAISE NOTICE '.... it failed corretly! (GOOD)';
	END;

	RAISE NOTICE 'Checking to see if rando can be permitted to approve via chain';
	BEGIN
		SELECT ai.*, approver_account_id
		INTO _r
		FROM approval_instance_item ai
		JOIN approval_instance_step ais
			USING (approval_instance_step_id)
		JOIN account a ON a.account_id = ais.approver_account_id
		WHERE account_id = _mgr1a.account_id
		LIMIT 1;

		INSERT INTO property (
			property_type, property_name,
			account_collection_id,
			property_value_account_collection_id
		) SELECT 'attestation', 'AlternateApprovers',
			a.account_collection_id,
			v.account_collection_id
		FROM ( SELECT account_collection_id, account_id
			FROM account_collection
			JOIN account_collection_account USING (account_collection_id)
			WHERE account_collection_type = 'per-account'
		) a, ( SELECT account_collection_id, account_id
			FROM account_collection
			JOIN account_collection_account USING (account_collection_id)
			WHERE account_collection_type = 'per-account'
		) v
		WHERE a.account_id = _acct.account_id
		AND v.account_id = _randoa.account_id
		RETURNING * INTO _d;

		SELECT approval_utils.approve(
			approval_instance_item_id := _r.approval_instance_item_id,
			approved := true,
			approving_account_id := _randoa.account_id
		)  AS bool
		INTO _bool;

		IF _bool THEN
			RAISE EXCEPTION 'It worked!' USING ERRCODE = 'JH999';
		END IF;
		RAISE EXCEPTION 'It failed! (BAD) %',  jsonb_pretty(to_jsonb(_d));
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it worked! (GOOD)';
	END;

	RAISE NOTICE 'Checking to see if rando can be permitted to approve via alternte';
	BEGIN
		SELECT ai.*, approver_account_id
		INTO _r
		FROM approval_instance_item ai
		JOIN approval_instance_step ais
			USING (approval_instance_step_id)
		JOIN account a ON a.account_id = ais.approver_account_id
		WHERE account_id = _mgr1a.account_id
		LIMIT 1;

		INSERT INTO property (
			property_type, property_name,
			account_collection_id,
			property_value_account_collection_id
		) SELECT 'attestation', 'AlternateApprovers',
			a.account_collection_id,
			v.account_collection_id
		FROM ( SELECT account_collection_id, account_id
			FROM account_collection
			JOIN account_collection_account USING (account_collection_id)
			WHERE account_collection_type = 'per-account'
		) a, ( SELECT account_collection_id, account_id
			FROM account_collection
			JOIN account_collection_account USING (account_collection_id)
			WHERE account_collection_type = 'per-account'
		) v
		WHERE a.account_id = _mgr1a.account_id
		AND v.account_id = _randoa.account_id
		RETURNING * INTO _d;

		SELECT approval_utils.approve(
			approval_instance_item_id := _r.approval_instance_item_id,
			approved := true,
			approving_account_id := _randoa.account_id
		)  AS bool
		INTO _bool;

		IF _bool THEN
			RAISE EXCEPTION 'It worked!' USING ERRCODE = 'JH999';
		END IF;
		RAISE EXCEPTION 'It failed! (BAD) %',  jsonb_pretty(to_jsonb(_d));
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it worked! (GOOD)';
	END;

	RAISE NOTICE 'Checking to see if rando can be permitted to approve via delegate';
	BEGIN
		SELECT ai.*, approver_account_id
		INTO _r
		FROM approval_instance_item ai
		JOIN approval_instance_step ais
			USING (approval_instance_step_id)
		JOIN account a ON a.account_id = ais.approver_account_id
		WHERE account_id = _mgr1a.account_id
		LIMIT 1;

		INSERT INTO property (
			property_type, property_name,
			account_collection_id,
			property_value_account_collection_id
		) SELECT 'attestation', 'Delegate',
			a.account_collection_id,
			v.account_collection_id
		FROM ( SELECT account_collection_id, account_id
			FROM account_collection
			JOIN account_collection_account USING (account_collection_id)
			WHERE account_collection_type = 'per-account'
		) a, ( SELECT account_collection_id, account_id
			FROM account_collection
			JOIN account_collection_account USING (account_collection_id)
			WHERE account_collection_type = 'per-account'
		) v
		WHERE a.account_id = _mgr1a.account_id
		AND v.account_id = _randoa.account_id
		RETURNING * INTO _d;

		SELECT approval_utils.approve(
			approval_instance_item_id := _r.approval_instance_item_id,
			approved := true,
			approving_account_id := _randoa.account_id
		)  AS bool
		INTO _bool;

		IF _bool THEN
			RAISE EXCEPTION 'It worked!' USING ERRCODE = 'JH999';
		END IF;
		RAISE EXCEPTION 'It failed! (BAD) %',  jsonb_pretty(to_jsonb(_d));
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it worked! (GOOD)';
	END;



	RAISE NOTICE 'Cleaning Up.... (not really, because... rollback)';
	RAISE NOTICE '++ End Attestation tests...';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;

SELECT test_approval_subsystem();

-- set search_path=jazzhands;
DROP FUNCTION test_approval_subsystem();

ROLLBACK TO test_approval_subsystem;

\t off
