DROP SCHEMA IF EXISTS acct_coll_manip CASCADE;
CREATE SCHEMA acct_coll_manip AUTHORIZATION jazzhands;
CREATE OR REPLACE FUNCTION acct_coll_manip.get_automated_account_collection_id(ac_name VARCHAR) RETURNS INTEGER AS $_$
DECLARE
	ac_id INTEGER;
BEGIN
	SELECT account_collection_id INTO ac_id FROM account_collection WHERE account_collection_name = ac_name AND account_collection_type ='automated';
	IF NOT FOUND THEN
		INSERT INTO account_collection (account_collection_name, account_collection_type) VALUES (ac_name, 'automated')
			RETURNING account_collection_id INTO ac_id;
	END IF;
	RETURN ac_id;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION acct_coll_manip.insert_or_delete_automated_ac(do_delete BOOLEAN,acct_id INTEGER,ac_ids INTEGER[]) RETURNS VOID AS $_$
DECLARE
	coll_id INTEGER;
BEGIN
	FOREACH coll_id IN ARRAY ac_ids
	LOOP
		IF coll_id = -1 THEN
			CONTINUE;
		END IF;
		IF do_delete THEN
			DELETE FROM account_collection_account WHERE account_collection_id = coll_id and account_id = acct_id;
			CONTINUE;
		END IF;
		PERFORM 1 FROM account_collection_account WHERE account_collection_id = coll_id AND account_id = acct_id;
		IF NOT FOUND THEN
			INSERT INTO account_collection_account (account_collection_id, account_id) VALUES (coll_id, acct_id);
		END IF;
	END LOOP;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION acct_coll_manip.person_company_flags_to_automated_ac_name(old_flag VARCHAR(1), base_name VARCHAR, OUT old VARCHAR, OUT new VARCHAR) AS $_$
BEGIN
	old = base_name;
	IF old_flag = 'N' THEN
		old  = 'non_' || base_name;
		new = base_name;
	ELSE
		new = 'non_' || base_name;
	END IF;
END;
$_$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION acct_coll_manip.person_gender_flag_to_automated_ac_name(flag VARCHAR(1)) RETURNS VARCHAR AS $_$
BEGIN
	IF flag IS NULL THEN
		RETURN NULL;
	END IF;
	IF flag = 'M' THEN
		RETURN 'male';
	ELSIF flag = 'F' THEN
		RETURN 'female';
	ELSIF flag = 'U' THEN
		RETURN 'unspecified_gender';
	END IF;
	RAISE NOTICE 'Gender account collection name cannot be determined for flag %', flag;
	RETURN NULL;
END;
$_$ LANGUAGE plpgsql;
