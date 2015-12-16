/*
 * Copyright (c) 2011-2013 Matthew Ragan
 * Copyright (c) 2012-2015 Todd Kover
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

/*

update_account_type_account_collection updates ac's of type usertype.
based on account_type.   It does not properly deal with account realms
and should just die.  I want to make sure the case is handled by automated_ac

update_company_account_collection likely needs to just die 
(its commented out) but its need should be double checked, particularly
looking at what automated_ac does.
	

 */

--- start of per-account manipulations
-- manage per-account account collection types.  Arguably we want to extend
-- account collections to be per account_realm, but I was not ready to do this at
-- implementaion time.
-- XXX need automated test case

-- before an account is deleted, remove the per-account account collections, 
-- if appropriate.
--
-- NOTE: this runs on DELETE only
CREATE OR REPLACE FUNCTION delete_peraccount_account_collection() 
RETURNS TRIGGER AS $$
DECLARE
	acid			account_collection.account_collection_id%TYPE;
BEGIN
	IF TG_OP = 'DELETE' THEN
		SELECT	account_collection_id
		  INTO	acid
		  FROM	account_collection ac
				INNER JOIN account_collection_account aca
					USING (account_collection_id)
		 WHERE	aca.account_id = OLD.account_Id
		   AND	ac.account_collection_type = 'per-account';

		IF acid is NOT NULL THEN
			DELETE from account_collection_account
			where account_collection_id = acid;

			DELETE from account_collection
			where account_collection_id = acid;
		END IF;
	END IF;
	RETURN OLD;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_delete_peraccount_account_collection ON Account;
CREATE TRIGGER trigger_delete_peraccount_account_collection BEFORE DELETE
	ON account 
	FOR EACH ROW 
	EXECUTE PROCEDURE delete_peraccount_account_collection();

----------------------------------------------------------------------------
-- on inserts/updates ensure the per-account account is updated properly
CREATE OR REPLACE FUNCTION update_peraccount_account_collection() 
RETURNS TRIGGER AS $$
DECLARE
	def_acct_rlm	account_realm.account_realm_id%TYPE;
	acid			account_collection.account_collection_id%TYPE;
DECLARE
	newname	TEXT;
BEGIN
	newname = concat(NEW.login, '_', NEW.account_id);
	if TG_OP = 'INSERT' THEN
		insert into account_collection 
			(account_collection_name, account_collection_type)
		values
			(newname, 'per-account')
		RETURNING account_collection_id INTO acid;
		insert into account_collection_account 
			(account_collection_id, account_id)
		VALUES
			(acid, NEW.account_id);
	END IF;

	IF TG_OP = 'UPDATE' AND OLD.login != NEW.login THEN
		UPDATE	account_collection
		    set	account_collection_name = newname
		  where	account_collection_type = 'per-account'
		    and	account_collection_id = (
				SELECT	account_collection_id
		  		FROM	account_collection ac
						INNER JOIN account_collection_account aca
							USING (account_collection_id)
		 		WHERE	aca.account_id = OLD.account_Id
		   		AND	ac.account_collection_type = 'per-account'
			);
	END IF;
	return NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_peraccount_account_collection 
	ON account;
CREATE TRIGGER trigger_update_peraccount_account_collection
	AFTER INSERT OR UPDATE
	ON Account FOR 
	EACH ROW EXECUTE 
	PROCEDURE update_peraccount_account_collection();

--- end of per-account manipulations
-------------------------------------------------------------------------------

/*
 * Deal with propagating person status down to accounts, if appropriate
 *
 * XXX - this needs to be reimplemented in oracle
 */
CREATE OR REPLACE FUNCTION propagate_person_status_to_account()
	RETURNS TRIGGER AS $$
DECLARE
	should_propagate	val_person_status.propagate_from_person%type;
BEGIN

	IF OLD.person_company_status != NEW.person_company_status THEN
		select propagate_from_person
		  into should_propagate
		 from	val_person_status
		 where	person_status = NEW.person_company_status;
		IF should_propagate = 'Y' THEN
			update account
			  set	account_status = NEW.person_company_status
			 where	person_id = NEW.person_id
			  AND	company_id = NEW.company_id;
		END IF;
	END IF;
	RETURN NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_propagate_person_status_to_account 
	ON person_company;
CREATE TRIGGER trigger_propagate_person_status_to_account 
AFTER UPDATE ON person_company
	FOR EACH ROW EXECUTE PROCEDURE propagate_person_status_to_account();

-------------------------------------------------------------------------------

/*
 * Deal with propagating person status down to accounts, if appropriate
 *
 * XXX - this needs to be reimplemented in oracle
 */
CREATE OR REPLACE FUNCTION pull_password_account_realm_from_account()
	RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'INSERT' THEN
		IF NEW.account_realm_id IS NULL THEN
			SELECT account_realm_id
			INTO	NEW.account_realm_id
			FROM	account
			WHERE	account_id = NEW.account_id;
		END IF;
	ELSIF NEW.account_realm_id = OLD.account_realm_id THEN
		IF NEW.account_realm_id IS NULL THEN
			SELECT account_realm_id
			INTO	NEW.account_realm_id
			FROM	account
			WHERE	account_id = NEW.account_id;
		END IF;
	END IF;
	RETURN NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_pull_password_account_realm_from_account 
	ON account_password;
CREATE TRIGGER trigger_pull_password_account_realm_from_account 
BEFORE INSERT OR UPDATE of ACCOUNT_ID
	ON account_password
	FOR EACH ROW EXECUTE PROCEDURE pull_password_account_realm_from_account();


-------------------------------------------------------------------------------

/*
 * Enforce that is_enabled should match whatever val_person_status has for it.
 *
 * XXX - this needs to be reimplemented in oracle
 */
CREATE OR REPLACE FUNCTION account_enforce_is_enabled()
	RETURNS TRIGGER AS $$
DECLARE
	correctval	char(1);
BEGIN
	SELECT is_enabled INTO correctval
	FROM val_person_status 
	WHERE person_status = NEW.account_status;

	IF TG_OP = 'INSERT' THEN
		IF NEW.is_enabled is NULL THEN
			NEW.is_enabled = correctval;
		ELSIF NEW.account_status != correctval THEN
			RAISE EXCEPTION 'May not set IS_ENABLED to an invalid value for given account_status: %', NEW.account_status
				USING errcode = 'integrity_constraint_violation';
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.account_status != OLD.account_status THEN
			IF NEW.is_enabled != correctval THEN
				NEW.is_enabled := correctval;
			END IF;
		ELSIF NEW.is_enabled != correctval THEN
			RAISE EXCEPTION 'May not update IS_ENABLED to an invalid value for given account_status: %', NEW.account_status
				USING errcode = 'integrity_constraint_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_account_enforce_is_enabled 
	ON account;
CREATE TRIGGER trigger_account_enforce_is_enabled 
BEFORE INSERT OR UPDATE of account_status,is_enabled
	ON account
	FOR EACH ROW EXECUTE PROCEDURE account_enforce_is_enabled();

-------------------------------------------------------------------------------

/*
 * ensure that a login is only made up of legal characters
 *
 * XXX - this needs to be reimplemented in oracle
 */
CREATE OR REPLACE FUNCTION account_validate_login()
	RETURNS TRIGGER AS $$
DECLARE
	correctval	char(1);
BEGIN

	IF NEW.login  ~ '[^-/@a-z0-9_]+' THEN
		RAISE EXCEPTION 'May not update IS_ENABLED to an invalid value for given account_status: %', NEW.account_status
			USING errcode = 'integrity_constraint_violation';
	END IF;

	RETURN NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_account_validate_login 
	ON account;
CREATE TRIGGER trigger_account_validate_login 
BEFORE INSERT OR UPDATE of login
	ON account
	FOR EACH ROW EXECUTE PROCEDURE account_validate_login();


-------------------------------------------------------------------------------

/*
 * migrate val_person_status.is_disabled to is_enabled
 *
 * This should go away when is_disabled does.
 */
CREATE OR REPLACE FUNCTION val_person_status_enabled_migration_enforce()
	RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'INSERT' THEN
		IF ( NEW.is_disabled IS NOT NULL AND NEW.is_enabled IS NOT NULL ) THEN
			RAISE EXCEPTION 'May not set both IS_ENABLED and IS_DISABLED.  Set IS_ENABLED only.'
				USING errcode = 'integrity_constraint_violation';
		END IF;

		IF NEW.is_enabled IS NOT NULL THEN
			IF NEW.is_enabled = 'Y' THEN
				NEW.is_disabled := 'N';
			ELSE
				NEW.is_disabled := 'Y';
			END IF;
		ELSIF NEW.is_disabled IS NOT NULL THEN
			IF NEW.is_disabled = 'Y' THEN
				NEW.is_enabled := 'N';
			ELSE
				NEW.is_enabled := 'Y';
			END IF;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF ( OLD.is_disabled != NEW.is_disabled AND
				OLD.is_enabled != NEW.is_enabled ) THEN
			RAISE EXCEPTION 'May not update both IS_ENABLED and IS_DISABLED.  Update IS_ENABLED only.'
				USING errcode = 'integrity_constraint_violation';
		END IF;

		IF OLD.is_enabled != NEW.is_enabled THEN
			IF NEW.is_enabled = 'Y' THEN
				NEW.is_disabled := 'N';
			ELSE
				NEW.is_disabled := 'Y';
			END IF;
		ELSIF OLD.is_disabled != NEW.is_disabled THEN
			IF NEW.is_disabled = 'Y' THEN
				NEW.is_enabled := 'N';
			ELSE
				NEW.is_enabled := 'Y';
			END IF;
		END IF;
	END IF;

	IF NEW.is_enabled = NEW.is_disabled THEN
		RAISE NOTICE 'is_enabled=is_disabled.  This should never happen' 
			USING  errcode = 'integrity_constraint_violation';
	END IF;

	RETURN NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_person_status_enabled_migration_enforce 
	ON account;
CREATE TRIGGER trigger_val_person_status_enabled_migration_enforce 
BEFORE INSERT OR UPDATE of is_disabled, is_enabled
	ON val_person_status
	FOR EACH ROW EXECUTE 
	PROCEDURE val_person_status_enabled_migration_enforce();


-------------------------------------------------------------------------------
