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

-- XXX not dealing with pending

DROP VIEW IF EXISTS v_account_collection_approval_process;
drop view if exists v_approval_matrix;
DROP VIEW IF EXISTS v_account_collection_audit_results;
drop VIEW if exists v_person_company_audit_map;
drop VIEW if exists v_account_collection_account_audit_map;
drop VIEW if exists v_account_manager_map;

-- This describes some sort of "how to approve".  This would be the
-- starting point for something and we would like to these in places to
-- do automatic approval.  It likely also needs attestation properties like
-- 'attest on the nTH day of the quarter or some such..  It points to a
-- property collection that makes up the differnet things that would figure
-- out what needs to be approved/attested.
--
-- 
drop table if exists approval_process cascade;
create table approval_process (
	approval_process_id		serial,
	approval_process_name		text not null,
	approval_process_type		text not null,
	description					text,
	first_approval_process_chain_id	integer,
	property_collection_id		integer,
	primary key (approval_process_id)
);


--
-- This is the approval chain.  Right now it is either manager or jira-hr.
-- manager menas the manager of the person or the mangaer of the last
-- approver.  jira-hr just says its handled by an external script that
-- deals with the interaction with Jira.  Things are then closed and
-- it returns to the process
--
-- Likely I'm missing a chain that says 'return to previous'
--
drop table if exists approval_process_chain cascade;
create table approval_process_chain (
	approval_process_chain_id	serial,
	description					text,
	approving_entity		text,
	refresh_all_data		char(1) DEFAULT 'N' NOT NULL,
	accept_approval_process_chain_id	integer,
	reject_approval_process_chain_id	integer,
	primary key (approval_process_chain_id)
);

alter table approval_process_chain
	add constraint fk_accept_approval_process_chain_id 
	foreign key (accept_approval_process_chain_id)
	references approval_process_chain(approval_process_chain_id);

alter table approval_process_chain
	add constraint fk_reject_approval_process_chain_id 
	foreign key (reject_approval_process_chain_id)
	references approval_process_chain(approval_process_chain_id);

-- XXX missing attestation properties?
--
-- This is an instance of a process.  For attestation, this means once
-- a quarter a bunch of these will come into existinace for a given
-- process.   (one per approving manager). 
--
-- This is built from v_account_collection_approval_process
--
drop table if exists approval_instance cascade;
create table approval_instance (
	approval_instance_id		serial not null,
	approval_process_id		integer not null,
	description				text,
	approval_start			timestamp  DEFAULT now() not null,
	approval_end			timestamp,
	primary key (approval_instance_id)
);

alter table approval_instance
	add constraint fk_approval_process_id 
	foreign key (approval_process_id)
	references approval_process(approval_process_id);

--
-- Its possible that this just needs to die and item and step get folded
-- together.  The distinction exists today to show all the different items
-- that need to be approved/attested to by a given account.
--
-- This is a group of things that are approved together in one instance.
-- (in attestation, there would be one row per manager).
--
-- When one cycle is done, if its handed off to someone else, anotehr step
-- would come into existance..
--
-- not clear that "next step" belongs here because each item can be approved
-- or rejected and go to a different path.  Without that, its possible that
-- all this gets folded into the above.
--
-- I need to reconcile "show me all the stuff outstanding for ME, though.
-- which is gleaned from here
--
drop table if exists approval_instance_step cascade;
create table approval_instance_step (
	approval_instance_step_id	serial not null,
	approval_instance_id		integer not null,
	approval_process_chain_id	integer not null,
	description				text,
	approval_type				text not null,
	approval_instance_step_start	timestamp DEFAULT now() not null,
	approval_instance_step_end	timestamp,
	approver_account_id		integer not null,
	actual_approver_account_id	integer,
	external_reference_name	text,
	is_completed			char(1) DEFAULT 'N' not null,
	primary key (approval_instance_step_id)
);

alter table approval_instance_step
	add constraint fk_approval_instance_id 
	foreign key (approval_instance_id)
	references approval_instance(approval_instance_id);

alter table approval_instance_step
	add constraint fk_approval_process_chain_id 
	foreign key (approval_process_chain_id)
	references approval_process_chain(approval_process_chain_id);

create index on approval_instance_step(approval_type);

alter table approval_instance_step
	add constraint fk_approver_account_id 
	foreign key (approver_account_id)
	references account(account_id);

alter table approval_instance_step
	add constraint fk_actual_approver_account_id 
	foreign key (actual_approver_account_id)
	references account(account_id);

-- These items may want to be folded into approval_instance_item
--
-- These are just fk's to all the audit table rows that are related to a
-- given item"
--
drop table if exists approval_instance_link cascade;
create table approval_instance_link (
	approval_instance_link_id	serial not null,
	acct_collection_acct_seq_id	integer,
	person_company_seq_id	integer,
	property_seq_id			integer,
	primary key (approval_instance_link_id)
);

--
-- This is where each approved item actually lives and is what is actually
-- presented to users to check off.  what to do next comes from the the
-- process chain
--
drop table if exists approval_instance_item cascade;
create table approval_instance_item (
	approval_instance_item_id	serial not null,
	approval_instance_link_id	integer not null,
	approval_instance_step_id	integer not null,
	next_approval_instance_item_id	integer,
	approved_label			text,
	approved_lhs			text,
	approved_rhs			text,
	is_approved				char(1),
	approved_account_id		integer,
	approved_device_id		integer,	-- where the approval came from
	primary key (approval_instance_item_id)
);

alter table approval_instance_item
	add constraint fk_approval_instance_link_id 
	foreign key (approval_instance_link_id)
	references approval_instance_link(approval_instance_link_id);

alter table approval_instance_item
	add constraint fk_approval_instance_step_id 
	foreign key (approval_instance_step_id)
	references approval_instance_step(approval_instance_step_id);

alter table approval_instance_item
	add constraint fk_approved_account_id 
	foreign key (approved_account_id)
	references account(account_id);

--------------------------------- views -----------------------------------

create view v_approval_matrix AS
SELECT	ap.approval_process_id, ap.first_approval_process_chain_id,
		ap.approval_process_name,
		p.property_id, p.property_name, 
		p.property_type, p.property_value,
		split_part(p.property_value, ':', 1) as property_val_lhs,
		split_part(p.property_value, ':', 2) as property_val_rhs,
		c.approval_process_chain_id, c.approving_entity,
		ap.description as approval_process_description,
		c.description as approval_chain_description
from	approval_process ap
		INNER JOIN property_collection pc USING (property_collection_id)
		INNER JOIN property_collection_property pcp USING (property_collection_id)
		INNER JOIN property p USING (property_name, property_type)
		LEFT JOIN approval_process_chain c
			ON c.approval_process_chain_id = ap.first_approval_process_chain_id
where	ap.approval_process_name = 'ReportingAttest'
and		ap.approval_process_type = 'attestation'
;

CREATE VIEW v_account_manager_map AS
WITH dude_base AS (
	SELECT a.login, a.account_id, person_id, a.company_id,
	    coalesce(p.preferred_first_name, p.first_name) as first_name,
	    coalesce(p.preferred_last_name, p.last_name) as last_name,
	    pc.manager_person_id
	FROM    account a
		INNER JOIN person_company pc USING (company_id,person_id)
		INNER JOIN person p USING (person_id)
	WHERE   a.is_enabled = 'Y'
	AND		pc.person_company_relation = 'employee'
	AND     a.account_role = 'primary' and a.account_type = 'person'
), dude AS (
	SELECT *,
		concat(first_name, ' ', last_name, ' (', login, ')') as human_readable
	FROM dude_base
) SELECT a.*, mp.account_id as manager_account_id, mp.login as manager_login
FROM dude a
	INNER JOIN dude mp ON mp.person_id = a.manager_person_id
;

---------------------------- audit table maps 

CREATE VIEW v_account_collection_account_audit_map AS
WITH all_audrecs AS (
    select acaa.*,
	row_number() OVER
	    (partition BY account_collection_id,account_id ORDER BY
	    "aud#timestamp" desc) as rownum
    from    account_collection_account aca
	join audit.account_collection_account acaa
	    using (account_collection_id, account_id)
    where "aud#action" in ('UPD', 'INS')
) SELECT "aud#seq" as audit_seq_id, * from all_audrecs WHERE rownum = 1;

CREATE VIEW v_person_company_audit_map AS
WITH all_audrecs AS (
    select pca.*,
	row_number() OVER
	    (partition BY person_id,company_id ORDER BY
	    "aud#timestamp" desc) as rownum
    from    person_company pc
	join audit.person_company pca
	    using (person_id, company_id)
    where "aud#action" in ('UPD', 'INS')
) SELECT "aud#seq" as audit_seq_id, * from all_audrecs WHERE rownum = 1;

---------------------------- things that use the maps

CREATE VIEW v_account_collection_audit_results AS
WITH membermap AS (
    SELECT  aca.audit_seq_id,
	ac.account_collection_id,
	ac.account_collection_name, ac.account_collection_type,
	a.*
    FROM    v_account_manager_map a
	INNER JOIN v_account_collection_account_audit_map aca 
		USING (account_id)
	INNER JOIN account_collection ac USING (account_collection_id)
	WHERE a.account_id != a.manager_account_id
    ORDER BY manager_login, a.last_name, a.first_name, a.account_id
) select * from membermap ;


-- Now need to figure out how to present this correctly.
-- 
-- The union of these three queries is basically everything to attest, but
-- the presentation will be somewhat clumsy.

-- The p.account_id != mm.account_id gets around some weird hoop jumping
-- because a manager is in his own directs account collection.  Generally
-- means someone does not validate themselves being there, which is fine.
-- (manifests itself as dups)

CREATE VIEW v_account_collection_approval_process AS
WITH combo AS (
WITH foo AS (
	SELECT mm.*, mx.*
            FROM v_account_collection_audit_results mm
                INNER JOIN v_approval_matrix mx ON
                    mx.property_val_lhs = mm.account_collection_type
        ORDER BY manager_account_id, account_id
) SELECT  login,
		account_id,
		person_id,
		company_id,
		manager_account_id,
		manager_login,
		'account_collection_account'::text as audit_table,
		audit_seq_id,
		approval_process_id,
		approval_process_chain_id,
		approving_entity,
		approval_process_description,
		approval_chain_description,
		account_collection_type as approval_label,
		human_readable AS approval_lhs,
		account_collection_name as approval_rhs
FROM foo
UNION
SELECT  mm.login,
		mm.account_id,
		mm.person_id,
		mm.company_id,
		mm.manager_account_id,
		mm.manager_login,
		'account_collection_account'::text as audit_table,
		mm.audit_seq_id,
		approval_process_id,
		approval_process_chain_id,
		approving_entity,
		approval_process_description,
		approval_chain_description,
		approval_process_name as approval_label,
		mm.human_readable AS approval_lhs,
		concat ('Reports to ',mm.manager_login) AS approval_rhs	
FROM v_approval_matrix mx
	INNER JOIN property p ON
		p.property_name = mx.property_val_rhs AND
		p.property_type = mx.property_val_lhs
	INNER JOIN v_account_collection_audit_results mm ON
		mm.account_collection_id=p.property_value_account_coll_id
	WHERE p.account_id != mm.account_id
UNION
SELECT  login,
		account_id,
		person_id,
		company_id,
		manager_account_id,
		manager_login,
		'person_company'::text as audit_table,
		audit_seq_id,
		approval_process_id,
		approval_process_chain_id,
		approving_entity,
		approval_process_description,
		approval_chain_description,
		property_val_rhs as approval_label,
		human_readable AS approval_lhs,
		CASE 
			WHEN property_val_rhs = 'position_title' THEN pcm.position_title
		END as approval_rhs
FROM	v_account_manager_map mm
		INNER JOIN v_person_company_audit_map pcm
			USING (person_id,company_id)
		INNER JOIN v_approval_matrix am
			ON property_val_lhs = 'person_company'
			AND property_val_rhs = 'position_title'
) select * from combo 
where manager_account_id != account_id
order by manager_login, account_id, approval_label
;

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION approval_instance_step_auto_complete()
RETURNS TRIGGER AS $$
DECLARE
	_tally	INTEGER;
BEGIN
	--
	-- on insert, if the parent was already marked as completed, fail.
	-- arguably, this should happen on updates as well
	--	possibnly should move this to a before trigger
	--
	IF TG_OP = 'INSERT' THEN
		SELECT	count(*)
		INTO	_tally
		FROM	approval_instance_step
		WHERE	approval_instance_step_id = NEW.approval_instance_step_id
		AND		is_completed = 'Y';

		IF _tally > 0 THEN
			RAISE EXCEPTION 'Completed attestation cycles may not have items added';
		END IF;
	END IF;

	-- XXX temporarily off!
	RETURN NEW;
	IF NEW.is_approved IS NOT NULL THEN
		SELECT	count(*)
		INTO	_tally
		FROM	approval_instance_item
		WHERE	approval_instance_step_id = NEW.approval_instance_step_id
		AND		approval_instance_item_id != NEW.approval_instance_item_id;

		IF _tally = 0 THEN
			UPDATE	approval_instance_step
			SET		is_completed = 'Y'
			WHERE	approval_instance_step_id = NEW.approval_instance_step_id;
		END IF;
		
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_approval_instance_step_auto_complete ON
	approval_instance_item;
CREATE TRIGGER trigger_approval_instance_step_auto_complete 
	AFTER INSERT OR UPDATE OF is_approved
        ON approval_instance_item
        FOR EACH ROW
        EXECUTE PROCEDURE approval_instance_step_auto_complete();

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION approval_instance_step_completed_immutable()
RETURNS TRIGGER AS $$
BEGIN
	IF ( OLD.is_completed ='Y' AND NEW.is_completed = 'N' ) THEN
		RAISE EXCEPTION 'Approval completion may not be reverted';
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_approval_instance_step_completed_immutable ON
	approval_instance_step;
CREATE TRIGGER trigger_approval_instance_step_completed_immutable 
	BEFORE UPDATE OF is_completed 
        ON approval_instance_step
        FOR EACH ROW
        EXECUTE PROCEDURE approval_instance_step_completed_immutable();

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION approval_instance_item_approved_immutable()
RETURNS TRIGGER AS $$
BEGIN
	IF OLD.is_approved != NEW.is_approved THEN
		RAISE EXCEPTION 'Approval may not be changed';
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_approval_instance_item_approved_immutable ON
	approval_instance_item;
CREATE TRIGGER trigger_approval_instance_item_approved_immutable 
	BEFORE UPDATE OF is_approved 
        ON approval_instance_item
        FOR EACH ROW
        EXECUTE PROCEDURE approval_instance_item_approved_immutable();

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION approval_instance_item_approval_notify()
RETURNS TRIGGER AS $$
BEGIN
	NOTIFY approval_instance_item_approval_change;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_approval_instance_item_approval_notify ON
	approval_instance_item;
CREATE TRIGGER trigger_approval_instance_item_approval_notify 
	AFTER INSERT OR  UPDATE OF is_approved 
        ON approval_instance_item
        EXECUTE PROCEDURE approval_instance_item_approval_notify();


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------


-- XXX trigger that says when the last item is closed, complete the step
-- XXX trigger that does not allow you to add items if the step is complete
-- XXX triggers should also consider locking other tables

grant select on all tables in schema jazzhands to ro_role;
grant insert,update,delete on all tables in schema jazzhands to iud_role;
