CREATE OR REPLACE FUNCTION person_manip.pick_login(
	in_account_realm_id	account_realm.account_realm_id%TYPE,
	in_first_name VARCHAR DEFAULT NULL,
	in_middle_name VARCHAR DEFAULT NULL,
	in_last_name VARCHAR DEFAULT NULL
) RETURNS varchar AS
$$
DECLARE
	_acctrealmid	integer;
	_login			varchar;
	_trylogin		varchar;
    id				account.account_id%TYPE;
	fn		text;
	ln		text;
BEGIN
	-- remove special characters
	fn = regexp_replace(lower(in_first_name), '[^a-z]', '', 'g');
	ln = regexp_replace(lower(in_last_name), '[^a-z]', '', 'g');
	_acctrealmid := in_account_realm_id;
	-- Try first initial, last name
	_login = lpad(lower(fn), 1) || lower(ln);
	SELECT account_id into id FROM account where account_realm_id = _acctrealmid
		AND login = _login;

	IF id IS NULL THEN
		RETURN _login;
	END IF;

	-- Try first initial, middle initial, last name
	if in_middle_name IS NOT NULL THEN
		_login = lpad(lower(fn), 1) || lpad(lower(in_middle_name), 1) || lower(ln);
		SELECT account_id into id FROM account where account_realm_id = _acctrealmid
			AND login = _login;
		IF id IS NULL THEN
			RETURN _login;
		END IF;
	END IF;

	-- if length of first+last is <= 10 then try that.
	_login = lower(fn) || lower(ln);
	IF char_length(_login) < 10 THEN
		SELECT account_id into id FROM account where account_realm_id = _acctrealmid
			AND login = _login;
		IF id IS NULL THEN
			RETURN _login;
		END IF;
	END IF;

	-- ok, keep trying to add a number to first initial, last
	_login = lpad(lower(fn), 1) || lower(ln);
	FOR i in 1..500 LOOP
		_trylogin := _login || i;
		SELECT account_id into id FROM account where account_realm_id = _acctrealmid
			AND login = _trylogin;
		IF id IS NULL THEN
			RETURN _trylogin;
		END IF;
	END LOOP;

	-- wtf. this should never happen
	RETURN NULL;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

