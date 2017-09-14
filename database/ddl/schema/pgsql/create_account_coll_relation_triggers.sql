/*
 * Copyright (c) 2016 Todd Kover
 * All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


--
-- $HeadURL$
-- $Id$
--

CREATE OR REPLACE FUNCTION acct_coll_preserve_direct()
RETURNS TRIGGER AS $$
BEGIN
	IF OLD.account_collection_relation = 'direct' THEN
		RAISE EXCEPTION 'Account Collection Relation % may not be removed',
			OLD.account_collection_relation
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_acct_coll_preserve_direct
	 ON val_account_collection_relatio;
CREATE CONSTRAINT TRIGGER trigger_acct_coll_preserve_direct
        AFTER DELETE OR UPDATE
        ON val_account_collection_relatio
		DEFERRABLE INITIALLY IMMEDIATE
        FOR EACH ROW
        EXECUTE PROCEDURE acct_coll_preserve_direct();

----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION acct_coll_insert_direct()
RETURNS TRIGGER AS $$
BEGIN
	INSERT INTO account_coll_type_relation (
		account_collection_relation, account_collection_type
	) VALUES (
		'direct', NEW.account_collection_type
	);
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_acct_coll_insert_direct
	 ON val_account_collection_type;
CREATE TRIGGER trigger_acct_coll_insert_direct
        AFTER INSERT
        ON val_account_collection_type
        FOR EACH ROW
        EXECUTE PROCEDURE acct_coll_insert_direct();

----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION acct_coll_remove_direct()
RETURNS TRIGGER AS $$
BEGIN
	DELETE FROM account_coll_type_relation 
		WHERE account_collection_type = OLD.account_collection_type
		AND account_collection_relation = 'direct'
	;
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_acct_coll_remove_direct
	 ON val_account_collection_type;
CREATE TRIGGER trigger_acct_coll_remove_direct
        BEFORE DELETE
        ON val_account_collection_type
        FOR EACH ROW
        EXECUTE PROCEDURE acct_coll_remove_direct();


----------------------------------------------------------------------------
----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION acct_coll_update_direct_before()
RETURNS TRIGGER AS $$
BEGIN
	SET CONSTRAINTS fk_acct_coll_rel_type_type DEFERRED;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_acct_coll_update_direct_before
	 ON val_account_collection_type;
CREATE TRIGGER trigger_acct_coll_update_direct_before
        BEFORE UPDATE OF account_collection_type
        ON val_account_collection_type
        FOR EACH ROW
        EXECUTE PROCEDURE acct_coll_update_direct_before();


----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION acct_coll_update_direct_before()
RETURNS TRIGGER AS $$
BEGIN
	UPDATE account_coll_type_relation
	SET account_collection_type = NEW.account_collection_type
	WHERE account_collection_type = OLD.account_collection_type;

	SET CONSTRAINTS fk_acct_coll_rel_type_type IMMEDIATE;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_acct_coll_update_direct_before
	 ON val_account_collection_type;
CREATE TRIGGER trigger_acct_coll_update_direct_before
        AFTER UPDATE OF account_collection_type
        ON val_account_collection_type
        FOR EACH ROW
        EXECUTE PROCEDURE acct_coll_update_direct_before();


----------------------------------------------------------------------------
----------------------------------------------------------------------------


CREATE OR REPLACE FUNCTION account_coll_member_relation_enforce()
RETURNS TRIGGER AS $$
DECLARE
	act	account_coll_type_relation%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	act
	FROM	account_coll_type_relation
	WHERE	account_collection_type =
		(select account_collection_type from account_collection
			where account_collection_id = NEW.account_collection_id)
	AND		account_collection_relation = NEW.account_collection_relation;

	IF act.MAX_NUM_MEMBERS IS NOT NULL THEN
		SELECT count(*)
		  INTO tally
		  FROM account_collection_account
		  		JOIN account_collection USING (account_collection_id)
		  WHERE account_collection_type = act.account_collection_type
		  AND account_collection_relation = NEW.account_collection_relation;

		IF tally > act.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF act.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		SELECT count(*)
		  INTO tally
		  FROM account_collection_account
		  		JOIN account_collection USING (account_collection_id)
		  WHERE account_collection_type = act.account_collection_type
		  AND account_collection_relation = NEW.account_collection_relation
		  AND account_id = NEW.account_id;

		IF tally > act.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'account % is in too many collections of type %/%',
				NEW.account_id,
				act.account_collection_type,
				act.account_collection_relation
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_account_coll_member_relation_enforce
	 ON account_collection_account;
CREATE CONSTRAINT TRIGGER trigger_account_coll_member_relation_enforce
        AFTER INSERT OR UPDATE
        ON account_collection_account
		DEFERRABLE INITIALLY IMMEDIATE
        FOR EACH ROW
        EXECUTE PROCEDURE account_coll_member_relation_enforce();

