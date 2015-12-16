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

CREATE OR REPLACE FUNCTION approval_instance_step_auto_complete()
RETURNS TRIGGER AS $$
DECLARE
	_tally	INTEGER;
BEGIN
	--
	-- on insert, if the parent was already marked as completed, fail.
	-- arguably, this should happen on updates as well
	--	possibly should move this to a before trigger
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

	IF NEW.is_approved IS NOT NULL THEN
		SELECT	count(*)
		INTO	_tally
		FROM	approval_instance_item
		WHERE	approval_instance_step_id = NEW.approval_instance_step_id
		AND		approval_instance_item_id != NEW.approval_instance_item_id
		AND		is_approved IS NOT NULL;

		IF _tally = 0 THEN
			UPDATE	approval_instance_step
			SET		is_completed = 'Y',
					approval_instance_step_end = now()
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

CREATE OR REPLACE FUNCTION approval_instance_step_resolve_instance()
RETURNS TRIGGER AS $$
DECLARE
	_tally INTEGER;
BEGIN
	SELECT	count(*)
	INTO	_tally
	FROM	approval_instance_step
	WHERE	is_completed = 'N'
	AND		approval_instance_id = NEW.approval_instance_id;

	IF _tally = 0 THEN
		UPDATE approval_instance
		SET	approval_end = now()
		WHERE	approval_instance_id = NEW.approval_instance_id;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_approval_instance_step_resolve_instance ON
	approval_instance_step;
CREATE TRIGGER trigger_approval_instance_step_resolve_instance 
	AFTER UPDATE OF is_completed 
        ON approval_instance_step
        FOR EACH ROW
        EXECUTE PROCEDURE approval_instance_step_resolve_instance();


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
--
-- This is just meant to work until such time as the approval bits are modified
-- to deal with account being there.

CREATE OR REPLACE FUNCTION legacy_approval_instance_step_notify_account()
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.account_id IS NULL THEN
		SELECT	approver_account_id
		INTO	NEW.account_id
		FROM	approval_instance_step
		WHERE	approval_instance_step_id =
				NEW.approval_instance_step_id;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_legacy_approval_instance_step_notify_account ON
	approval_instance_step_notify;
CREATE TRIGGER trigger_legacy_approval_instance_step_notify_account 
	BEFORE INSERT OR  UPDATE OF account_id
        ON approval_instance_step_notify
	FOR EACH ROW
        EXECUTE PROCEDURE legacy_approval_instance_step_notify_account();


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------


