CREATE OR REPLACE FUNCTION person_manip.merge_accounts(
	merge_from_account_id	account.account_Id%TYPE,
	merge_to_account_id	account.account_Id%TYPE
) RETURNS INTEGER AS $$
DECLARE
	fpc		person_company%ROWTYPE;
	tpc		person_company%ROWTYPE;
	_account_realm_id INTEGER;
BEGIN
	select	*
	  into	fpc
	  from	person_company
	 where	(person_id, company_id) in
		(select person_id, company_id 
		   from account where account_id = merge_from_account_id);

	select	*
	  into	tpc
	  from	person_company
	 where	(person_id, company_id) in
		(select person_id, company_id 
		   from account where account_id = merge_to_account_id);

	IF (fpc.company_id != tpc.company_id) THEN
		RAISE EXCEPTION 'Accounts are in different companies';
	END IF;

	IF (fpc.person_company_relation != tpc.person_company_relation) THEN
		RAISE EXCEPTION 'People have different relationships';
	END IF;

	IF(tpc.external_hr_id is NOT NULL AND fpc.external_hr_id IS NULL) THEN
		RAISE EXCEPTION 'Destination account has an external HR ID and origin account has none';
	END IF;

	-- move any account collections over that are
	-- not infrastructure ones, and the new person is
	-- not in
	UPDATE	account_collection_account
	   SET	ACCOUNT_ID = merge_to_account_id
	 WHERE	ACCOUNT_ID = merge_from_account_id
	  AND	ACCOUNT_COLLECTION_ID IN (
			SELECT ACCOUNT_COLLECTION_ID
			  FROM	ACCOUNT_COLLECTION
				INNER JOIN VAL_ACCOUNT_COLLECTION_TYPE
					USING (ACCOUNT_COLLECTION_TYPE)
			 WHERE	IS_INFRASTRUCTURE_TYPE = 'N'
		)
	  AND	account_collection_id not in (
			SELECT	account_collection_id
			  FROM	account_collection_account
			 WHERE	account_id = merge_to_account_id
	);


	-- Now begin removing the old account
	PERFORM person_manip.purge_account( merge_from_account_id );

	-- Switch person_ids
	DELETE FROM person_account_realm_company WHERE person_id = fpc.person_id AND company_id = tpc.company_id;
	SELECT account_realm_id INTO _account_realm_id FROM account_realm_company WHERE company_id = tpc.company_id;
	INSERT INTO person_account_realm_company (person_id, company_id, account_realm_id) VALUES ( fpc.person_id , tpc.company_id, _account_realm_id);
	UPDATE account SET account_realm_id = _account_realm_id, person_id = fpc.person_id WHERE person_id = tpc.person_id AND company_id = fpc.company_id;
	DELETE FROM person_company WHERE person_id = tpc.person_id AND company_id = tpc.company_id;
	DELETE FROM person_account_realm_company WHERE person_id = tpc.person_id AND company_id = tpc.company_id;
	UPDATE person_image SET person_id = fpc.person_id WHERE person_id = tpc.person_id;
	-- if there are other relations that may exist, do not delete the person.
	BEGIN
		delete from person where person_id = tpc.person_id;
	EXCEPTION WHEN foreign_key_violation THEN
		NULL;
	END;

	return merge_to_account_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
