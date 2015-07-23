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

		IF (ai.approval_process_id IS NULL OR
				ai.approval_process_id != _r.approval_process_id) THEN
			INSERT INTO approval_instance ( 
				approval_process_id 
			) VALUES ( 
				_r.approval_process_id 
			) RETURNING * INTO ai;
		END IF;

		IF ais.approver_account_id IS NULL OR
				ais.approver_account_id != _r.manager_account_id THEN

			INSERT INTO approval_instance_step (
				approval_process_chain_id, approver_account_id,
				approval_instance_id
			) VALUES (
				_r.approval_process_chain_id, _r.manager_account_id,
				ai.approval_process_id
			) RETURNING * INTO ais;
		END IF;
		
		INSERT INTO approval_instance_link ( acct_collection_acct_seq_id
			) VALUES ( _r.audit_seq_id ) RETURNING * INTO ail;

		--
		-- need to create or find the correct step to insert someone into;
		-- probably need a val table that says if every approver's stuff should
		-- be aggregated into one step or ifs a step per underling.
		--

		INSERT INTO approval_instance_item (
			approval_instance_link_id, approval_instance_step_id,
			approval_type, approved_label, approved_lhs, approved_rhs
		) VALUES ( 
			ail.approval_instance_link_id, ais.approval_instance_step_id,
			'account', _r.approval_label, _r.approval_lhs, _r.approval_rhs
		) RETURNING * INTO aii;

		UPDATE approval_instance_step 
		SET approval_instance_id = ai.approval_instance_id
		WHERE approval_instance_step_id = ais.approval_instance_step_id;
		tally := tally + 1;
	END LOOP;
	RETURN tally;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

CREATE OR REPLACE FUNCTION approval_utils.build_next_approval_item(
	approval_instance_item_id
					approval_instance_item.approval_instance_item_id%TYPE,
	approval_process_chain_id		
						approval_process_chain.approval_process_chain_id%TYPE,
	approved				char(1),
	approving_account_id	account.account_id%TYPE,
	new_value				text DEFAULT NULL
) RETURNS approval_instance_item.approval_instance_item_id%TYPE AS $$
DECLARE
	_r		RECORD;
	_apc	approval_process_chain%ROWTYPE;	
	_aii	approval_instance_item%ROWTYPE;	
	_new	approval_instance_item%ROWTYPE;	
	_acid	account.account_id%TYPE;
	apptype	text;
BEGIN
	EXECUTE '
		SELECT * 
		FROM approval_process_chain 
		WHERE approval_process_chain_id=$1
	' INTO _apc USING approval_process_chain_id;

	IF _apc.approval_process_chain_id is NULL THEN
		RAISE EXCEPTION 'Unable to follow this chain. It should be here';
	END IF;

	IF _apc.approving_entity = 'manager' THEN
		apptype := 'account';
	ELSIF _apc.approving_entity = 'jira-hr' THEN
		apptype := 'jira-hr';
	ELSE
		RAISE EXCEPTION 'Can not handle approving entity %',
			_apc.appriving_entity;
	END IF;

	EXECUTE '
		SELECT * 
		FROM approval_instance_item 
		WHERE approval_instance_item_id=$1
	' INTO _aii USING approval_instance_item_id;

	EXECUTE '
		INSERT INTO approval_instance_item
			(approval_instance_link_id, approval_type, approved_label,
				approved_lhs, approved_rhs
			) SELECT approval_instance_link_id, $2, approved_label,
				approved_lhs, $3
			FROM approval_instance_item
			WHERE approval_instance_item_id = $1
			RETURNING *
	' INTO _new USING approval_instance_item_id, apptype, new_value;

	RETURN _new.approval_instance_item_id;
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
	_r		RECORD;
	_aii	approval_instance_item%ROWTYPE;	
	_new	approval_instance_item.approval_instance_item_id%TYPE;	
	_chid	approval_process_chain.approval_process_chain_id%TYPE;
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
   	             INNER JOIN approval_instance_item aii
   	                 USING (approval_instance_step_id)
   	             INNER JOIN approval_instance_link ail
   	                 USING (approval_instance_link_id)
			INNER JOIN approval_process_chain aic
				USING (approval_process_chain_id)
		WHERE approval_instance_item_id = $1
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
			_chid := _r.reject_approval_process_chain_id;	
		END IF;
	ELSIF approved = 'Y' THEN
		IF _r.accept_approval_process_chain_id IS NOT NULL THEN
			_chid := _r.accept_approval_process_chain_id;
		END IF;
	ELSE
		RAISE EXCEPTION 'Approved must be Y or N';
	END IF;

	IF _chid IS NOT NULL THEN
		_new := approval_utils.build_next_approval_item(
			approval_instance_item_id, _chid, approved,
			approving_account_id, new_value);

		EXECUTE '
			UPDATE approval_instance_item
			SET next_approval_instance_item_id = $2
			WHERE approval_instance_item_id = $1
		' USING approval_instance_item_id, _new;
	END IF;

	RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

grant usage on schema approval_utils to iud_role;
revoke all on schema approval_utils from public;
revoke all on  all functions in schema approval_utils from public;
grant execute on all functions in schema approval_utils to iud_role;

