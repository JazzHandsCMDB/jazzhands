-- Copyright (c) 2015, Todd M. Kover
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

\set ON_ERROR_STOP

DROP schema IF EXISTS approval_utils CASCADE;

DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'approval_utils';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS approval_utils;
		CREATE SCHEMA approval_utils AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA approval_utils IS 'part of jazzhands';
	END IF;
END;
$$;

CREATE OR REPLACE FUNCTION approval_utils.build_attest()
RETURNS integer AS $$
DECLARE
	_r			RECORD;
	ai			approval_instance%ROWTYPE;
	ail			approval_instance_link%ROWTYPE;
	ais			approval_instance_step%ROWTYPE;
	aii			approval_instance_item%ROWTYPE;
	tally		INTEGER;
BEGIN
	tally := 0;
	FOR _r IN SELECT * FROM v_account_collection_approval_process
	LOOP
		IF _r.approving_entity != 'manager' THEN
			RAISE NOTICE 'Do not know how to process approving entity %',
				_r.approving_entity;
		END IF;
		IF ais.approver_account_id IS NULL OR
				ais.approver_account_id != _r.manager_account_id THEN

			INSERT INTO approval_instance_step (
				approval_process_chain_id, approver_account_id
			) VALUES (
				_r.approval_process_chain_id, _r.manager_account_id
			) RETURNING * INTO ais;

			INSERT INTO approval_instance (
				approval_process_id, first_approval_instance_step_id)
			VALUES (
				_r.approval_process_id, ais.approval_instance_step_id
			) RETURNING * INTO ai;
		END IF;
		
		INSERT INTO approval_instance_link ( acct_collection_acct_seq_id
			) VALUES ( _r.audit_seq_id ) RETURNING * INTO ail;

		INSERT INTO approval_instance_item (
			approval_instance_link_id,
			approved_label, approved_lhs, approved_rhs
		) VALUES ( 
			ail.approval_instance_link_id,
			_r.approval_label, _r.approval_lhs, _r.approval_rhs
		) RETURNING * INTO aii;

		INSERT INTO approval_instance_step_item (
			approval_instance_step_id, approval_instance_item_id
		) VALUES (
			ais.approval_instance_step_id, aii.approval_instance_item_id
		);

		UPDATE approval_instance_step 
		SET approval_instance_id = ai.approval_instance_id
		WHERE approval_instance_step_id = ais.approval_instance_step_id;
		tally := tally + 1;
	END LOOP;
	RETURN tally;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

CREATE OR REPLACE FUNCTION approval_utils.do_approve(
	approval_instance_item_id	
					approval_instance_item.approval_instance_item_id%TYPE,
	approved				char(1),
	approving_account_id	account.account_id%TYPE,
	new_value				text DEFAULT NULL
) RETURNS boolean AS $$
DECLARE
	_r		RECORD:
	_aii	approval_instance_item%ROWTYPE;	
	_new	approval_instance_item%ROWTYPE;	
BEGIN
	-- XXX - need to check to see if this account is permitted to approve
	-- or not

	EXECUTE '
	SELECT 	aii.approval_instance_item_id,
		ais.approval_instance_step_id,
		aii.is_approved,
		aii.is_completed,
		aic.accept_approval_process_chain_id,
		aic.reject_approval_process_chain_id
        FROM    approval_instance ai
                INNER JOIN approval_instance_step ais
                    USING (approval_instance_id)
                INNER JOIN approval_instance_step_item aisi
                    USING (approval_instance_step_id)
                INNER JOIN approval_instance_item aii
                    USING (approval_instance_item_id)
                INNER JOIN approval_instance_link ail
                    USING (approval_instance_link_id)
		INNER JOIN approval_process_chain aic
			USING (approval_process_chain_id)
	WHERE approver_account_id = 6817
	' USING approval_instance_item_id INTO 	_r;

	IF _r.is_completed = 'Y' THEN
		RAISE EXCEPTION 'Approval is already completed.';
	END IF;

	-- XXX is_completed set here?  Is that used to notify the requestor
	-- that it was not aprpoved or does that roll up to an instance?
	EXECUTE '
		UPDATE approval_instance_item
		SET is_approved = $2,
			is_completed = $3,
		approved_account_id = $4
		WHERE approval_instance_item_id = $1
	' USING approval_instance_item_id, approved, 'Y', approving_account_id;

	IF approved = 'N' THEN
		IF _r.reject_approval_process_chain_id IS NOT NULL THEN
		END IF;
	ELSIF approved = 'Y' THEN
		IF _r.accept_approval_process_chain_id IS NOT NULL THEN
		END IF;
	END IF;

	RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

grant usage on schema approval_utils to iud_role;
revoke all on schema approval_utils from public;
revoke all on  all functions in schema approval_utils from public;
grant execute on all functions in schema approval_utils to iud_role;

