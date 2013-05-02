CREATE OR REPLACE FUNCTION person_manip.change_company(final_company_id integer, _person_id integer, initial_company_id integer)  RETURNS VOID AS $_$
DECLARE
	initial_person_company  person_company%ROWTYPE;
BEGIN
	INSERT INTO person_account_realm_company (company_id, person_id, account_realm_id) VALUES (final_company_id, _person_id,
		(SELECT account_realm_id FROM account_realm_company WHERE company_id = initial_company_id));
	SELECT * INTO initial_person_company FROM person_company WHERE person_id = _person_id AND company_id = initial_company_id;
	initial_person_company.company_id = final_company_id;
	INSERT INTO person_company VALUES (initial_person_company.*);
	UPDATE account SET company_id = final_company_id WHERE company_id = initial_company_id AND person_id = _person_id;
	DELETE FROM person_company WHERE person_id = _person_id AND company_id = initial_company_id;
	DELETE FROM person_account_realm_company WHERE person_id = _person_id AND company_id = initial_company_id;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands, pg_temp;
