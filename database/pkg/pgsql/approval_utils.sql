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

CREATE OR REPLACE FUNCTION approval_utils.calculate_due_date(
	response_period	interval,
	from_when	timestamp DEFAULT now()
) RETURNS timestamp AS $$
DECLARE
BEGIN
	RETURN date_trunc('day', (CASE 
		WHEN to_char(from_when + response_period::interval, 'D') = '1'
			THEN from_when + response_period::interval + '1 day'::interval
		WHEN to_char(from_when + response_period::interval, 'D') = '7'
			THEN from_when + response_period::interval + '2 days'::interval
		ELSE from_when + response_period::interval END)::timestamp) + 
			'1 day'::interval - '1 second'::interval
	;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = approval_utils,jazzhands;

CREATE OR REPLACE FUNCTION 
		approval_utils.get_or_create_correct_approval_instance_link(
	approval_instance_item_id
					approval_instance_item.approval_instance_item_id%TYPE,
	approval_instance_link_id	
					approval_instance_link.approval_instance_link_id%TYPE
) RETURNS approval_instance_link.approval_instance_link_id%TYPE AS $$
DECLARE
	_v			approval_utils.v_account_collection_approval_process%ROWTYPE;
	_l			approval_instance_link%ROWTYPE;
	_acaid		INTEGER;
	_pcid		INTEGER;
BEGIN
	EXECUTE 'SELECT * FROM approval_instance_link WHERE
		approval_instance_link_id = $1
	' INTO _l USING approval_instance_link_id;

	_v := approval_utils.refresh_approval_instance_item(approval_instance_item_id);

	IF _v.audit_table = 'account_collection_account' THEN
		IF _v.audit_seq_id IS NOT 
					DISTINCT FROM  _l.acct_collection_acct_seq_id THEN
			_acaid := _v.audit_seq_id;
			_pcid := NULL;
		END IF;
	ELSIF _v.audit_table = 'person_company' THEN
		_acaid := NULL;
		_pcid := _v.audit_seq_id;
		IF _v.audit_seq_id IS NOT DISTINCT FROM  _l.person_company_seq_id THEN
			_acaid := NULL;
			_pcid := _v.audit_seq_id;
		END IF;
	ELSE
		RAISE EXCEPTION 'Unable to handle audit table %', _v.audit_table;
	END IF;

	IF _acaid IS NOT NULL or _pcid IS NOT NULL THEN
		EXECUTE '
			INSERT INTO approval_instance_link (
				acct_collection_acct_seq_id, person_company_seq_id
			) VALUES ($1, $2) RETURNING *
		' INTO _l USING _acaid, _pcid;
		RETURN _l.approval_instance_link_id;
	ELSE
		RETURN approval_instance_link_id;
	END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = approval_utils,jazzhands;


CREATE OR REPLACE FUNCTION approval_utils.refresh_approval_instance_item(
	approval_instance_item_id
					approval_instance_item.approval_instance_item_id%TYPE
) RETURNS approval_utils.v_account_collection_approval_process AS $$
DECLARE
	_i	approval_instance_item.approval_instance_item_id%TYPE;
	_r	approval_utils.v_account_collection_approval_process%ROWTYPE;
BEGIN
	--
	-- XXX p comes out of one of the three clauses in 
	-- v_account_collection_approval_process .  It is likely that that view
	-- needs to be broken into 2 or 3 views joined together so there is no
	-- code redundancy.  This is almost certainly true because it is a pain
	-- to keep column lists in syn everywhere
	EXECUTE '
		WITH p AS (
		SELECT  login,
		        account_id,
		        person_id,
		        company_id,
		        manager_account_id,
		        manager_login,
		        ''person_company''::text as audit_table,
		        audit_seq_id,
		        approval_process_id,
		        approval_process_chain_id,
		        approving_entity,
				approval_process_description,
				approval_chain_description,
				approval_response_period,
				approval_expiration_action,
				attestation_frequency,
				current_attestation_name,
				attestation_offset,
				approval_process_chain_name,
				property_val_rhs AS approval_category,
				CASE
					WHEN property_val_rhs = ''position_title''
						THEN ''Verify Position Title''
					END as approval_label,
		        human_readable AS approval_lhs,
		        CASE
		            WHEN property_val_rhs = ''position_title'' THEN pcm.position_title
		        END as approval_rhs
		FROM    v_account_manager_map mm
		        INNER JOIN v_person_company_audit_map pcm
		            USING (person_id,company_id)
		        INNER JOIN v_approval_matrix am
		            ON property_val_lhs = ''person_company''
		            AND property_val_rhs = ''position_title''
		), x AS ( select i.approval_instance_item_id, p.*
		from	approval_instance_item i
			inner join approval_instance_step s
				using (approval_instance_step_id)
			inner join approval_instance_link l
				using (approval_instance_link_id)
			inner join audit.account_collection_account res
				on res."aud#seq" = l.acct_collection_acct_seq_id
			 inner join v_account_collection_approval_process p
				on i.approved_label = p.approval_label
				and res.account_id = p.account_id
		UNION
		select i.approval_instance_item_id, p.*
		from	approval_instance_item i
			inner join approval_instance_step s
				using (approval_instance_step_id)
			inner join approval_instance_link l
				using (approval_instance_link_id)
			inner join audit.person_company res
				on res."aud#seq" = l.person_company_seq_id
			 inner join p
				on i.approved_label = p.approval_label
				and res.person_id = p.person_id
				and res.company_id = p.company_id
		) SELECT 
			login,
			account_id,
			person_id,
			company_id,
			manager_account_id,
			manager_login,
			audit_table,
			audit_seq_id,
			approval_process_id,
			approval_process_chain_id,
			approving_entity,
			approval_process_description,
			approval_chain_description,
			approval_response_period,
			approval_expiration_action,
			attestation_frequency,
			current_attestation_name,
			attestation_offset,
			approval_process_chain_name,
			approval_category,
			approval_label,
			approval_lhs,
			approval_rhs
		FROM x where	approval_instance_item_id = $1
	' INTO _r USING approval_instance_item_id;
	RETURN _r;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = approval_utils,jazzhands;
	

CREATE OR REPLACE FUNCTION approval_utils.build_attest()
RETURNS integer AS $$
DECLARE
	_r			RECORD;
	ai			approval_instance%ROWTYPE;
	ail			approval_instance_link%ROWTYPE;
	ais			approval_instance_step%ROWTYPE;
	aii			approval_instance_item%ROWTYPE;
	tally		INTEGER;
	_acaid		INTEGER;
	_pcid		INTEGER;
BEGIN
	tally := 0;

	-- XXX need to add magic for entering after the right day of the period.
	FOR _r IN SELECT * 
				FROM v_account_collection_approval_process
				WHERE (approval_process_id, current_attestation_name) NOT IN
					(SELECT approval_process_id, approval_instance_name 
					 FROM approval_instance
					)
	LOOP
		IF _r.approving_entity != 'manager' THEN
			RAISE EXCEPTION 'Do not know how to process approving entity %',
				_r.approving_entity;
		END IF;

		IF (ai.approval_process_id IS NULL OR
				ai.approval_process_id != _r.approval_process_id) THEN

			INSERT INTO approval_instance ( 
				approval_process_id, description, approval_instance_name
			) VALUES ( 
				_r.approval_process_id, 
				_r.approval_process_description, _r.current_attestation_name
			) RETURNING * INTO ai;
		END IF;

		IF ais.approver_account_id IS NULL OR
				ais.approver_account_id != _r.manager_account_id THEN

			INSERT INTO approval_instance_step (
				approval_process_chain_id, approver_account_id, 
				approval_instance_id, approval_type,  
				approval_instance_step_name,
				approval_instance_step_due, 
				description
			) VALUES (
				_r.approval_process_chain_id, _r.manager_account_id,
				ai.approval_process_id, 'account',
				_r.approval_process_chain_name,
				approval_utils.calculate_due_date(_r.approval_response_period::interval),
				concat(_r.approval_chain_description, ' - ', _r.manager_login)
			) RETURNING * INTO ais;
		END IF;

		IF _r.audit_table = 'account_collection_account' THEN
			_acaid := _r.audit_seq_id;
			_pcid := NULL;
		ELSIF _R.audit_table = 'person_company' THEN
			_acaid := NULL;
			_pcid := _r.audit_seq_id;
		END IF;

		INSERT INTO approval_instance_link ( 
			acct_collection_acct_seq_id, person_company_seq_id
		) VALUES ( 
			_acaid, _pcid
		) RETURNING * INTO ail;

		--
		-- need to create or find the correct step to insert someone into;
		-- probably need a val table that says if every approvers stuff should
		-- be aggregated into one step or ifs a step per underling.
		--

		INSERT INTO approval_instance_item (
			approval_instance_link_id, approval_instance_step_id,
			approved_category, approved_label, approved_lhs, approved_rhs
		) VALUES ( 
			ail.approval_instance_link_id, ais.approval_instance_step_id,
			_r.approval_category, _r.approval_label, _r.approval_lhs, _r.approval_rhs
		) RETURNING * INTO aii;

		UPDATE approval_instance_step 
		SET approval_instance_id = ai.approval_instance_id
		WHERE approval_instance_step_id = ais.approval_instance_step_id;
		tally := tally + 1;
	END LOOP;
	RETURN tally;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = approval_utils,jazzhands;

--
-- returns new approval_instance_item based on how an existing one is
-- approved.  returns NULL if there is no next step
--
-- XXX - I suspect build_attest needs to call this.  There is redundancy
-- between the two of them.
--
CREATE OR REPLACE FUNCTION approval_utils.build_next_approval_item(
	approval_instance_item_id
					approval_instance_item.approval_instance_item_id%TYPE,
	approval_process_chain_id		
						approval_process_chain.approval_process_chain_id%TYPE,
	approval_instance_id
				approval_instance.approval_instance_id%TYPE,
	approved				char(1),
	approving_account_id	account.account_id%TYPE,
	new_value				text DEFAULT NULL
) RETURNS approval_instance_item.approval_instance_item_id%TYPE AS $$
DECLARE
	_r		RECORD;
	_apc	approval_process_chain%ROWTYPE;	
	_new	approval_instance_item%ROWTYPE;	
	_acid	account.account_id%TYPE;
	_step	approval_instance_step.approval_instance_step_id%TYPE;
	_l		approval_instance_link.approval_instance_link_id%TYPE;
	apptype	text;
	_v			approval_utils.v_account_collection_approval_process%ROWTYPE;
BEGIN
	EXECUTE '
		SELECT apc.*
		FROM approval_process_chain apc
		WHERE approval_process_chain_id=$1
	' INTO _apc USING approval_process_chain_id;

	IF _apc.approval_process_chain_id is NULL THEN
		RAISE EXCEPTION 'Unable to follow this chain: %',
			approval_process_chain_id;
	END IF;

	EXECUTE '
		SELECT aii.*, ais.approver_account_id
		FROM approval_instance_item  aii
			INNER JOIN approval_instance_step ais
				USING (approval_instance_step_id)
		WHERE approval_instance_item_id=$1
	' INTO _r USING approval_instance_item_id;

	IF _apc.approving_entity = 'manager' THEN
		apptype := 'account';
		_acid := NULL;
		EXECUTE '
			SELECT manager_account_id
			FROM	v_account_manager_map
			WHERE	account_id = $1
		' INTO _acid USING approving_account_id;
		--
		-- return NULL because there is no manager for the person
		--
		IF _acid IS NULL THEN
			RETURN NULL;
		END IF;
	ELSIF _apc.approving_entity = 'jira-hr' THEN
		apptype := 'jira-hr';
		_acid :=  _r.approver_account_id;
	ELSIF _apc.approving_entity = 'recertify' THEN
		apptype := 'account';
		EXECUTE '
			SELECT approver_account_id
			FROM approval_instance_item  aii
				INNER JOIN approval_instance_step ais
					USING (approval_instance_step_id)
			WHERE approval_instance_item_id IN (
				SELECT	approval_instance_item_id
				FROM	approval_instance_item
				WHERE	next_approval_instance_item_id = $1
			)
		' INTO _acid USING approval_instance_item_id;
	ELSE
		RAISE EXCEPTION 'Can not handle approving entity %',
			_apc.approving_entity;
	END IF;

	IF _acid IS NULL THEN
		RAISE EXCEPTION 'This whould not happen:  Unable to discern approving account.';
	END IF;

	EXECUTE '
		SELECT	approval_instance_step_id
		FROM	approval_instance_step
		WHERE	approval_process_chain_id = $1
		AND		approval_instance_id = $2
		AND		approver_account_id = $3
	' INTO _step USING approval_process_chain_id,
		approval_instance_id, _acid;

	--
	-- _new gets built out for all the fields that should get inserted,
	-- and then at the end is stomped on by what actually gets inserted.
	--

	IF _step IS NULL THEN
		EXECUTE '
			INSERT INTO approval_instance_step (
				approval_instance_id, approval_process_chain_id,
				approval_instance_step_name,
				approver_account_id, approval_type, 
				approval_instance_step_due,
				description
			) VALUES (
				$1, $2, $3, $4, $5, approval_utils.calculate_due_date($6), $7
			) RETURNING approval_instance_step_id
		' INTO _step USING 
			approval_instance_id, approval_process_chain_id,
			_apc.approval_process_chain_name,
			_acid, apptype, 
			_apc.approval_chain_response_period::interval,
			concat(_apc.description, ' for ', _r.approver_account_id, ' by ',
			approving_account_id);
	END IF;

	IF _apc.refresh_all_data = 'Y' THEN
		-- this is called twice, should rethink how to not
		_v := approval_utils.refresh_approval_instance_item(approval_instance_item_id);
		_l := approval_utils.get_or_create_correct_approval_instance_link(
			approval_instance_item_id,
			_r.approval_instance_link_id
		);
		_new.approval_instance_link_id := _l;
		_new.approved_label := _v.approval_label;
		_new.approved_category := _v.approval_category;
		_new.approved_lhs := _v.approval_lhs;
		_new.approved_rhs := _v.approval_rhs;
	ELSE
		_new.approval_instance_link_id := _r.approval_instance_link_id;
		_new.approved_label := _r.approved_label;
		_new.approved_category := _r.approved_category;
		_new.approved_lhs := _r.approved_lhs;
		IF new_value IS NULL THEN
			_new.approved_rhs := _r.approved_rhs;
		ELSE
			_new.approved_rhs := new_value;
		END IF;
	END IF;

	-- RAISE NOTICE 'step is %', _step;
	-- RAISE NOTICE 'acid is %', _acid;

	EXECUTE '
		INSERT INTO approval_instance_item
			(approval_instance_link_id, approved_label, approved_category,
				approved_lhs, approved_rhs, approval_instance_step_id
			) SELECT $2, $3, $4,
				$5, $6, $7
			FROM approval_instance_item
			WHERE approval_instance_item_id = $1
			RETURNING *
	' INTO _new USING approval_instance_item_id, 
		_new.approval_instance_link_id, _new.approved_label, _new.approved_category,
		_new.approved_lhs, _new.approved_rhs,
		_step;

	-- RAISE NOTICE 'returning %', _new.approval_instance_item_id;
	RETURN _new.approval_instance_item_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = approval_utils,jazzhands;

CREATE OR REPLACE FUNCTION approval_utils.approve(
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
	_tally	INTEGER;
BEGIN
	EXECUTE '
		SELECT 	aii.approval_instance_item_id,
			ais.approval_instance_step_id,
			ais.approval_instance_id,
			ais.approver_account_id,
			aii.is_approved,
			ais.is_completed,
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


	--
	-- Ensure that only the person or their management chain can approve
	-- others
	IF _r.approver_account_id != approving_account_id THEN
		EXECUTE '
			WITH RECURSIVE rec (
				root_account_id,
				account_id,
				manager_account_id
			) as (
					SELECT  account_id as root_account_id,
							account_id, manager_account_id
					FROM	v_account_manager_map
				UNION ALL
					SELECT a.root_account_id, m.account_id, m.manager_account_id
					FROM rec a join v_account_manager_map m
						ON a.manager_account_id = m.account_id
			) SELECT count(*) from rec where root_account_id = $1
				and manager_account_id = $2
		' INTO _tally USING _r.approver_account_id, approving_account_id;

		IF _tally = 0 THEN
			EXECUTE '
				SELECT	count(*)
				FROM	property
						INNER JOIN v_acct_coll_acct_expanded e
						USING (account_collection_id)
				WHERE	property_type = ''Defaults''
				AND		property_name = ''_can_approve_all''
				AND		e.account_id = $1
			' INTO _tally USING approving_account_id;

			IF _tally = 0 THEN
				RAISE EXCEPTION 'Only a person and their management chain may approve others';
			END IF;
		END IF;

	END IF;

	IF _r.approval_instance_item_id IS NULL THEN
		RAISE EXCEPTION 'Unknown approval_instance_item_id %',
			approval_instance_item_id;
	END IF;

	IF _r.is_approved IS NOT NULL THEN
		RAISE EXCEPTION 'Approval is already completed.';
	END IF;

	EXECUTE '
		UPDATE approval_instance_item
		SET is_approved = $2,
		approved_account_id = $3
		WHERE approval_instance_item_id = $1
	' USING approval_instance_item_id, approved, approving_account_id;

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
			approval_instance_item_id, _chid,
			_r.approval_instance_id, approved,
			approving_account_id, new_value);

		EXECUTE '
			UPDATE approval_instance_item
			SET next_approval_instance_item_id = $2
			WHERE approval_instance_item_id = $1
		' USING approval_instance_item_id, _new;
	END IF;

	RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = approval_utils,jazzhands;

grant usage on schema approval_utils to iud_role;
revoke all on schema approval_utils from public;
revoke all on  all functions in schema approval_utils from public;
grant execute on all functions in schema approval_utils to iud_role;

grant usage on schema approval_utils to stab_role;
grant execute on all functions in schema approval_utils to stab_role;
