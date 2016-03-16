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
-- When putting an account into an account collection, check to see if
-- it is permissionsable based on realm restrictions
--
CREATE OR REPLACE FUNCTION account_collection_account_realm() 
RETURNS TRIGGER AS $_$
DECLARE
	_a	account%ROWTYPE;
	_at	val_account_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	_at
	FROM	val_account_collection_type
		JOIN account_collection USING (account_collection_type)
	WHERE
		account_collection_id = NEW.account_collection_id;

	-- no restrictions, so do not care
	IF _at.account_realm_id IS NULL THEN
		RETURN NEW;
	END IF;

	-- check to see if the account's account realm matches
	IF TG_OP = 'INSERT' OR OLD.account_id != NEW.account_id THEN
		SELECT	*
		INTO	_a
		FROM	account	
		WHERE	account_id = NEW.account_id;
		
		IF _a.account_realm_id != _at.account_realm_id THEN
			RAISE EXCEPTION 'account realm of % does not match account realm restriction on account_collection %',
				NEW.account_id, NEW.account_collection_id
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$_$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trig_account_collection_account_realm 
	ON account_collection_account;
CREATE TRIGGER trig_account_collection_account_realm 
	AFTER INSERT OR UPDATE
	ON account_collection_account 
	FOR EACH ROW 
	EXECUTE PROCEDURE account_collection_account_realm();

---------------------------------------------------------------------------------
--
-- When putting an account colletion into another, makes sure that it does not
-- violate account_realm restrictions

--
CREATE OR REPLACE FUNCTION account_collection_hier_realm() 
RETURNS TRIGGER AS $_$
DECLARE
	_pat	val_account_collection_type%ROWTYPE;
	_cat	val_account_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	_pat
	FROM	val_account_collection_type
		JOIN account_collection USING (account_collection_type)
	WHERE
		account_collection_id = NEW.account_collection_id;
	SELECT *
	INTO	_cat
	FROM	val_account_collection_type
		JOIN account_collection USING (account_collection_type)
	WHERE
		account_collection_id = NEW.child_account_collection_id;

	-- no restrictions, so do not care
	IF _pat.account_realm_id IS DISTINCT FROM _cat.account_realm_id THEN
		RAISE EXCEPTION 'account realm restrictions on parent %/child % do not match" ',
			NEW.account_collection_id, NEW.child_account_collection_id
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;
	RETURN NEW;
END;
$_$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trig_account_collection_hier_realm 
	ON account_collection_hier;
CREATE TRIGGER trig_account_collection_hier_realm 
	AFTER INSERT OR UPDATE
	ON account_collection_hier 
	FOR EACH ROW 
	EXECUTE PROCEDURE account_collection_hier_realm();

---------------------------------------------------------------------------------
--
-- When setting an account_realm restriction on an account collection, fail if
-- any accounts or parent or children collections violate it.
--
CREATE OR REPLACE FUNCTION account_collection_type_realm() 
RETURNS TRIGGER AS $_$
DECLARE
	_tally	integer;
BEGIN
	IF NEW.account_realm_id IS NULL THEN
		RETURN NEW;
	END IF;

	SELECT	count(*)
	INTO	_tally
	FROM	account_collection_account
			JOIN account_collection USING (account_collection_id)
			JOIN account a USING (account_id)
	WHERE	account_collection_type = NEW.account_collection_type
	AND		a.account_realm_id != NEW.account_realm_id;
	IF _tally > 0 THEN
		RAISE EXCEPTION 'Unable to set account_realm restriction because there are accounts assigned that do not match it'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	-- This is probably useless.
	SELECT	count(*)
	INTO	_tally
	FROM	account_collection_hier h
			JOIN account_collection pac USING (account_collection_id)
			JOIN val_account_collection_type pat USING (account_collection_type)
			JOIN account_collection cac ON
				h.child_account_collection_id = cac.account_collection_id
			JOIN val_account_collection_type cat ON
				cac.account_collection_type = cat.account_collection_type
	WHERE	(
				pac.account_collection_type = NEW.account_collection_type
			OR
				cac.account_collection_type = NEW.account_collection_type
			)
	AND		(
				pat.account_realm_id IS DISTINCT FROM NEW.account_realm_id
			OR
				cat.account_realm_id IS DISTINCT FROM NEW.account_realm_id
			)
	;
	IF _tally > 0 THEN
		RAISE EXCEPTION 'Unable to set account_realm restriction because there are account collections in the hierarchy that do not match'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;
	RETURN NEW;
END;
$_$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trig_account_collection_type_realm ON val_account_collection_type;
CREATE TRIGGER trig_account_collection_type_realm 
	AFTER UPDATE OF account_realm_id
	ON val_account_collection_type 
	FOR EACH ROW 
	EXECUTE PROCEDURE account_collection_type_realm();

---------------------------------------------------------------------------------
--
-- When changing an account's account_realm_id (sounds like a bad idea), make
-- sure that it does not violate any account colletion
--
CREATE OR REPLACE FUNCTION account_change_realm_aca_realm() 
RETURNS TRIGGER AS $_$
DECLARE
	_tally	integer;
BEGIN
	SELECT	count(*)
	INTO	_tally
	FROM	account_collection_account
			JOIN account_collection USING (account_collection_id)
			JOIN val_account_collection_type vt USING (account_collection_type)
	WHERE	vt.account_realm_id IS NOT NULL
	AND		vt.account_realm_id != NEW.account_realm_id;
	
	IF _tally > 0 THEN
		RAISE EXCEPTION 'New account realm is part of % account collections with a type restriction',
			_tally
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;
	RETURN NEW;
END;
$_$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trig_account_change_realm_aca_realm ON account;
CREATE TRIGGER trig_account_change_realm_aca_realm 
	BEFORE UPDATE OF account_realm_id
	ON account 
	FOR EACH ROW 
	EXECUTE PROCEDURE account_change_realm_aca_realm();


---------------------------------------------------------------------------------
--
-- when changing types, check to see if the new type has restrictions
-- any accounts or parent or children collections violate it.
--
CREATE OR REPLACE FUNCTION account_collection_realm() 
RETURNS TRIGGER AS $_$
DECLARE
	_at		val_account_collection_type%ROWTYPE;
	_tally	integer;
BEGIN
	SELECT * INTO _at FROM val_account_collection_type
	WHERE account_collection_type = NEW.account_collection_type;

	IF _at.account_realm_id IS NULL THEN
		RETURN NEW;
	END IF;

	SELECT	count(*)
	INTO	_tally
	FROM	account_collection_account
			JOIN account a USING (account_id)
	WHERE	account_collection_id = NEW.account_collection_id
	AND		a.account_realm_id != _at.account_realm_id;
	IF _tally > 0 THEN
		RAISE EXCEPTION 'Unable to set account_realm restriction because there are accounts assigned that do not match it'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	SELECT	count(*)
	INTO	_tally
	FROM	account_collection_hier h
			JOIN account_collection pac USING (account_collection_id)
			JOIN val_account_collection_type pat USING (account_collection_type)
			JOIN account_collection cac ON
				h.child_account_collection_id = cac.account_collection_id
			JOIN val_account_collection_type cat ON
				cac.account_collection_type = cat.account_collection_type
	WHERE	(
				pac.account_collection_id = NEW.account_collection_id
			OR		cac.account_collection_id = NEW.account_collection_id
			)
	AND		pat.account_realm_id IS DISTINCT FROM cat.account_realm_id
	;
	IF _tally > 0 THEN
		RAISE EXCEPTION 'Unable to set account_realm restriction because there are account collections in the hierarchy that do not match'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;
	RETURN NEW;
END;
$_$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trig_account_collection_realm ON account_collection;
CREATE TRIGGER trig_account_collection_realm 
	AFTER UPDATE OF account_collection_type
	ON account_collection 
	FOR EACH ROW 
	EXECUTE PROCEDURE account_collection_realm();

