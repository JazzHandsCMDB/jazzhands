/*
 * Copyright (c) 2014 Todd Kover
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

CREATE OR REPLACE FUNCTION ins_v_corp_family_account()
RETURNS TRIGGER AS $$
DECLARE
	acct_realm_id	account_realm.account_realm_id%TYPE;
BEGIN
	SELECT	account_realm_id
	INTO	acct_realm_id
	FROM	property
	WHERE	property_name = '_root_account_realm_id'
	AND	property_type = 'Defaults';

	IF acct_realm_id != NEW.account_realm_id THEN
		RAISE EXCEPTION 'Invalid account_realm_id'
		USING ERRCODE = 'foreign_key_violation';
	END IF;

	INSERT INTO account VALUES (NEW.*);

END;
$$ SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_ins_v_corp_family_account
        ON v_corp_family_account;
CREATE TRIGGER trigger_ins_v_corp_family_account
INSTEAD OF INSERT ON v_corp_family_account
FOR EACH ROW EXECUTE PROCEDURE ins_v_corp_family_account();

-- --------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION del_v_corp_family_account()
RETURNS TRIGGER AS $$
DECLARE
	acct_realm_id	account_realm.account_realm_id%TYPE;
BEGIN
	SELECT	account_realm_id
	INTO	acct_realm_id
	FROM	property
	WHERE	property_name = '_root_account_realm_id'
	AND	property_type = 'Defaults';

	IF acct_realm_id != OLD.account_realm_id THEN
		RAISE EXCEPTION 'Invalid account_realm_id'
		USING ERRCODE = 'foreign_key_violation';
	END IF;

	DELETE FROM account where account_id = OLD.account_id;
END;
$$ SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_del_v_corp_family_account
        ON v_corp_family_account;
CREATE TRIGGER trigger_del_v_corp_family_account
INSTEAD OF DELETE ON v_corp_family_account
FOR EACH ROW EXECUTE PROCEDURE del_v_corp_family_account();

-- --------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION upd_v_corp_family_account()
RETURNS TRIGGER AS $$
DECLARE
	acct_realm_id	account_realm.account_realm_id%TYPE;
	setstr		TEXT;
	_r		RECORD;
	val		TEXT;
BEGIN
	SELECT	account_realm_id
	INTO	acct_realm_id
	FROM	property
	WHERE	property_name = '_root_account_realm_id'
	AND	property_type = 'Defaults';

	IF acct_realm_id != OLD.account_realm_id OR
			acct_realm_id != NEW.account_realm_id THEN
		RAISE EXCEPTION 'Invalid account_realm_id'
		USING ERRCODE = 'foreign_key_violation';
	END IF;

	setstr = '';
	FOR _r IN SELECT * FROM json_each_text( row_to_json(NEW) )
	LOOP
		IF _r.key NOT SIMILAR TO 'data_(ins|upd)_(user|date)' THEN
			EXECUTE 'SELECT ' || _r.key ||' FROM account
				WHERE account_id = ' || OLD.account_id
				INTO val;
			IF ( _r.value IS NULL  AND val IS NOT NULL) OR
				( _r.value IS NOT NULL AND val IS NULL) OR
				(_r.value::text NOT SIMILAR TO val::text) THEN
				-- RAISE NOTICE 'Changing %: "%" to "%"', _r.key, val, _r.value;
				IF char_length(setstr) > 0 THEN
					setstr = setstr || ',
					';
				END IF;
				IF _r.value IS NOT  NULL THEN
					setstr = setstr || _r.key || ' = ' ||  
						quote_nullable(_r.value) || ' ' ;
				ELSE
					setstr = setstr || _r.key || ' = ' ||  
						' NULL ' ;
				END IF;
			END IF;
		END IF;
	END LOOP;


	IF char_length(setstr) > 0 THEN
		setstr = 'UPDATE account SET ' || setstr || '
			WHERE	account_id = ' || OLD.account_id;
		-- RAISE NOTICE 'executing %', setstr;
		EXECUTE setstr;
	END IF;
	RETURN NEW;

END;
$$ SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_upd_v_corp_family_account
        ON v_corp_family_account;
CREATE TRIGGER trigger_upd_v_corp_family_account
INSTEAD OF UPDATE ON v_corp_family_account
FOR EACH ROW EXECUTE PROCEDURE upd_v_corp_family_account();
