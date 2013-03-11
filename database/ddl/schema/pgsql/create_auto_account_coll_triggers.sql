CREATE OR REPLACE FUNCTION automated_ac() RETURNS TRIGGER AS $_$
DECLARE
	acr	VARCHAR;
	c_name VARCHAR;
	sc VARCHAR;
	ac_ids INTEGER[];
	delete_aca BOOLEAN;
	_gender VARCHAR;
	_person_company RECORD;
	acr_c_name VARCHAR;
	gender_string VARCHAR;
	_status RECORD;
BEGIN
	IF TG_OP = 'INSERT' THEN
		IF NEW.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
		PERFORM 1 FROM val_person_status WHERE NEW.account_status = person_status AND is_disabled = 'N';
		IF NOT FOUND THEN
			RETURN NEW;
		END IF;
	-- The triggers need not deal with account realms companies or sites being renamed, although we may want to revisit this later.
	ELSIF NEW.account_id != OLD.account_id OR NEW.company_id != OLD.company_id OR NEW.account_realm_id != OLD.account_realm_id THEN
		RAISE NOTICE 'This trigger does not handle changing account_realm_id or company_id or account id';
		RETURN NEW;
	END IF;
	ac_ids = '{-1,-1,-1,-1,-1,-1,-1}';
	SELECT account_realm_name INTO acr FROM account_realm WHERE account_realm_id = NEW.account_realm_id;
	ac_ids[0] = acct_coll_manip.get_automated_account_collection_id(acr || '_' || NEW.account_type);
	SELECT company_short_name INTO c_name FROM company WHERE company_id = NEW.company_id AND company_short_name IS NOT NULL;
	IF NOT FOUND THEN
		RAISE NOTICE 'Company short name cannot be determined from company_id % in %', NEW.company_id, TG_NAME;
	ELSE
		acr_c_name = acr || '_' || c_name;
		ac_ids[1] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || NEW.account_type);
		SELECT
			pc.*
		INTO
			_person_company
		FROM
			person_company pc
		JOIN
			account a
		USING
			(person_id)
		WHERE
			a.person_id != 0 AND account_id = NEW.account_id;
		IF FOUND THEN
			IF _person_company.is_exempt IS NOT NULL THEN
				SELECT * INTO _status FROM acct_coll_manip.person_company_flags_to_automated_ac_name(_person_company.is_exempt, 'exempt');
				ac_ids[2] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || _status.old);
			END IF;
			IF _person_company.is_full_time IS NOT NULL THEN
				SELECT * INTO _status FROM acct_coll_manip.person_company_flags_to_automated_ac_name(_person_company.is_full_time, 'full_time');
				ac_ids[3] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || _status.old);
			END IF;
			IF _person_company.is_management IS NOT NULL THEN
				SELECT * INTO _status FROM acct_coll_manip.person_company_flags_to_automated_ac_name(_person_company.is_management, 'management');
				ac_ids[4] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || _status.old);
			END IF;
		END IF;
		SELECT
			gender
		INTO
			_gender
		FROM
			person
		JOIN
			account a
		USING
			(person_id)
		WHERE
			account_id = NEW.account_id AND a.person_id !=0 AND gender IS NOT NULL;
		IF FOUND THEN
			gender_string = acct_coll_manip.person_gender_flag_to_automated_ac_name(_gender);
			IF gender_string IS NOT NULL THEN
				ac_ids[5] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || gender_string);
			END IF;
		END IF;
	END IF;
	SELECT site_code INTO sc FROM person_location WHERE person_id = NEW.person_id AND site_code IS NOT NULL;
	IF FOUND THEN
		ac_ids[6] = acct_coll_manip.get_automated_account_collection_id(acr || '_' || sc);
	END IF;
	delete_aca = 't';
	IF TG_OP = 'INSERT' THEN
		delete_aca = 'f';
	ELSE
		IF NEW.account_role != 'primary' AND NEW.account_role != OLD.account_role THEN
			PERFORM acct_coll_manip.insert_or_delete_automated_ac('t', OLD.account_id, ac_ids);
			RETURN NEW;
		END IF;
		PERFORM 1 FROM val_person_status WHERE new.account_status = person_status AND is_disabled = 'N';
		IF NOT FOUND THEN
			PERFORM acct_coll_manip.insert_or_delete_automated_ac('t', OLD.account_id, ac_ids);
			RETURN NEW;
		END IF;
		IF NEW.account_role = 'primary' AND NEW.account_role != OLD.account_role OR
			NEW.account_status != OLD.account_status THEN
			delete_aca = 'f';
		END IF;
	END IF;
	IF NOT delete_aca THEN
		PERFORM acct_coll_manip.insert_or_delete_automated_ac('f', NEW.account_id, ac_ids);
	END IF;
	RETURN NEW;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER;
DROP TRIGGER IF EXISTS trig_automated_ac ON account;
CREATE TRIGGER trig_automated_ac AFTER INSERT OR UPDATE ON account FOR EACH ROW EXECUTE PROCEDURE automated_ac();

CREATE OR REPLACE FUNCTION automated_ac_on_person_company() RETURNS TRIGGER AS $_$
DECLARE
	ac_id INTEGER[];
	c_name VARCHAR;
	old_c_name VARCHAR;
	old_acr_c_name VARCHAR;
	acr_c_name VARCHAR;
	exempt_status VARCHAR;
	full_time_status VARCHAR;
	manager_status VARCHAR;
	old_r RECORD;
	r RECORD;
	_status RECORD;
BEGIN
	-- at this time person_company.is_exempt column can be null.
	-- take into account of is_exempt going from null to not null
	IF NEW.is_exempt IS NOT NULL AND OLD.is_exempt IS NOT NULL AND NEW.is_exempt = OLD.is_exempt AND NEW.is_management = OLD.is_management AND NEW.is_full_time = OLD.is_full_time OR NEW.person_id = 0 AND OLD.person_id = 0 THEN
		RETURN NEW;
	END IF;
	IF NEW.person_id != OLD.person_id OR NEW.company_id != OLD.company_id THEN
		RAISE NOTICE 'This trigger % does not support changing person_id or company_id', TG_NAME;
		RETURN NEW;
	END IF;
	SELECT company_short_name INTO old_c_name FROM company WHERE company_id = OLD.company_id AND company_short_name IS NOT NULL;
	IF NOT FOUND THEN
		RAISE NOTICE 'Company short name cannot be determined from company_id % in trigger %', OLD.company_id, TG_NAME;
	END IF;
	c_name = old_c_name;
	FOR old_r
		IN SELECT
			account_realm_name, account_id
		FROM
			account_realm ar
		JOIN
			account a
		USING
			(account_realm_id)
		JOIN
			val_person_status vps
		ON
			account_status = vps.person_status AND vps.is_disabled='N'
		WHERE
			a.person_id = OLD.person_id AND a.company_id = OLD.company_id 
	LOOP
		old_acr_c_name = old_r.account_realm_name || '_' || old_c_name;
		FOR r
			IN SELECT
				account_realm_name, account_id
			FROM
				account_realm ar
			JOIN
				account a
			USING
				(account_realm_id)
			JOIN
				val_person_status vps
			ON
				account_status = vps.person_status AND vps.is_disabled='N'
			WHERE
				a.person_id = NEW.person_id AND a.company_id = NEW.company_id
		LOOP
			acr_c_name = r.account_realm_name || '_' || c_name;
			IF coalesce(NEW.is_exempt,'') != coalesce(OLD.is_exempt,'') THEN
				SELECT * INTO _status FROM acct_coll_manip.person_company_flags_to_automated_ac_name(OLD.is_exempt, 'exempt');
				IF old_acr_c_name IS NOT NULL THEN
					DELETE FROM account_collection_account WHERE account_id = old_r.account_id
						AND account_collection_id = acct_coll_manip.get_automated_account_collection_id(old_acr_c_name || '_' || _status.old); 
				END IF;
				IF acr_c_name IS NOT NULL THEN
					ac_id[0] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || _status.new);
					PERFORM acct_coll_manip.insert_or_delete_automated_ac('f', r.account_id, ac_id);
				END IF;
			END IF;
			IF NEW.is_full_time != OLD.is_full_time THEN
				SELECT * INTO _status FROM acct_coll_manip.person_company_flags_to_automated_ac_name(OLD.is_full_time, 'full_time');
				IF old_acr_c_name IS NOT NULL THEN
					DELETE FROM account_collection_account WHERE account_id = old_r.account_id
						AND account_collection_id = acct_coll_manip.get_automated_account_collection_id(old_acr_c_name || '_' || _status.old);
				END IF;
				IF acr_c_name IS NOT NULL THEN
					ac_id[0] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || _status.new);
					PERFORM acct_coll_manip.insert_or_delete_automated_ac('f', r.account_id, ac_id);
				END IF;
			END IF;
			IF NEW.is_management != OLD.is_management THEN
				SELECT * INTO _status FROM acct_coll_manip.person_company_flags_to_automated_ac_name(OLD.is_management, 'management');
				IF old_acr_c_name IS NOT NULL THEN
					DELETE FROM account_collection_account WHERE account_id = old_r.account_id
						AND account_collection_id = acct_coll_manip.get_automated_account_collection_id(old_acr_c_name || '_' || _status.old);
				END IF;
				IF acr_c_name IS NOT NULL THEN
					ac_id[0] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || _status.new);
					PERFORM acct_coll_manip.insert_or_delete_automated_ac('f', r.account_id, ac_id);
				END IF;
			END IF;
		END LOOP;
	END LOOP;
	RETURN NEW;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER;
DROP TRIGGER IF EXISTS trig_automated_ac ON person_company;
CREATE TRIGGER trig_automated_ac AFTER UPDATE ON person_company FOR EACH ROW EXECUTE PROCEDURE automated_ac_on_person_company();

CREATE OR REPLACE FUNCTION automated_ac_on_person() RETURNS TRIGGER AS $_$
DECLARE
	ac_id INTEGER[];
	c_name VARCHAR;
	old_c_name VARCHAR;
	old_acr_c_name VARCHAR;
	acr_c_name VARCHAR;
	gender_string VARCHAR;
	r RECORD;
	old_r RECORD;
BEGIN
	IF NEW.gender = OLD.gender OR NEW.person_id = 0 AND OLD.person_id = 0 THEN
		RETURN NEW;
	END IF;
	IF OLD.person_id ! = NEW.person_id THEN
		RAISE NOTICE 'This trigger % does not support changing person_id', TG_NAME;
		RETURN NEW;
	END IF;
	FOR old_r
		IN SELECT
			account_realm_name, account_id, company_id
		FROM
			account_realm ar
		JOIN
			account a
		USING
			(account_realm_id)
		JOIN
			val_person_status vps
		ON
			account_status = vps.person_status AND vps.is_disabled='N'
		WHERE
			a.person_id = OLD.person_id
	LOOP
		SELECT company_short_name INTO old_c_name FROM company WHERE company_id = old_r.company_id AND company_short_name IS NOT NULL;
		IF FOUND THEN
			old_acr_c_name = old_r.account_realm_name || '_' || old_c_name;
			gender_string = acct_coll_manip.person_gender_flag_to_automated_ac_name(OLD.gender);
			IF gender_string IS NOT NULL THEN
				DELETE FROM account_collection_account WHERE account_id = old_r.account_id
					AND account_collection_id = acct_coll_manip.get_automated_account_collection_id(old_acr_c_name || '_' ||  gender_string);
			END IF;
		ELSE
			RAISE NOTICE 'Company short name cannot be determined from company_id % in %', old_r.company_id, TG_NAME;
		END IF;
		FOR r
			IN SELECT
				account_realm_name, account_id, company_id
			FROM
				account_realm ar
			JOIN
				account a
			USING
				(account_realm_id)
			JOIN
				val_person_status vps
			ON
				account_status = vps.person_status AND vps.is_disabled='N'
			WHERE
				a.person_id = NEW.person_id
		LOOP
			-- do not support changing company per specification in the email
			c_name = old_c_name;
			IF c_name IS NULL THEN
				RAISE NOTICE 'Company short name cannot be determined from company_id % in %', NEW.company_id, TG_NAME;
				CONTINUE;
			END IF;
			acr_c_name = r.account_realm_name || '_' || c_name;
			gender_string = acct_coll_manip.person_gender_flag_to_automated_ac_name(NEW.gender);
			IF gender_string IS NULL THEN
				CONTINUE;
			END IF;
			ac_id[0] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || gender_string);
			PERFORM acct_coll_manip.insert_or_delete_automated_ac('f', r.account_id, ac_id);
		END LOOP;
	END LOOP;
	RETURN NEW;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER;
DROP TRIGGER IF EXISTS trig_automated_ac ON person;
CREATE TRIGGER trig_automated_ac AFTER UPDATE ON person FOR EACH ROW EXECUTE PROCEDURE automated_ac_on_person();

CREATE OR REPLACE FUNCTION automated_realm_site_ac_pl() RETURNS TRIGGER AS $_$
DECLARE
	sc VARCHAR;
	r RECORD;
	ac_id INTEGER;
	ac_name VARCHAR;
	p_id INTEGER;
BEGIN
	IF TG_OP = 'UPDATE' AND (NEW.site_code = OLD.site_code OR NEW.person_location_type != 'office' AND OLD.person_location_type != 'office') THEN
		RETURN NEW;
	END IF;

	IF TG_OP = 'INSERT' AND NEW.person_location_type != 'office' THEN
		RETURN NEW;
	END IF;

	IF TG_OP = 'DELETE' THEN
		IF OLD.person_location_type != 'office' THEN
			RETURN OLD;
		END IF;
		p_id = OLD.person_id;
		sc = OLD.site_code;
	ELSE
		p_id = NEW.person_id;
		sc = NEW.site_code;
	END IF;

	FOR r IN SELECT account_realm_name, account_id
		FROM
			account_realm ar
		JOIN
			account a
		ON
			ar.account_realm_id=a.account_realm_id AND a.account_role = 'primary' AND a.person_id = p_id 
		JOIN
			val_person_status vps
		ON
			vps.person_status = a.account_status AND vps.is_disabled='N'
		JOIN
			site s
		ON
			s.site_code = sc AND a.company_id = s.colo_company_id
	LOOP
		IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
			ac_name = r.account_realm_name || '_' || sc;
			ac_id = acct_coll_manip.get_automated_account_collection_id( r.account_realm_name || '_' || sc );
			IF TG_OP = 'UPDATE' AND NEW.person_location_type != 'office' THEN
				CONTINUE;
			END IF;
			PERFORM 1 FROM account_collection_account WHERE account_collection_id = ac_id AND account_id = r.account_id;
			IF NOT FOUND THEN
				INSERT INTO account_collection_account (account_collection_id, account_id) VALUES (ac_id, r.account_id);
			END IF;
		END IF;
		IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
			ac_name = r.account_realm_name || '_' || OLD.site_code;
			SELECT account_collection_id INTO ac_id FROM account_collection WHERE account_collection_name = ac_name AND account_collection_type ='automated';
			IF NOT FOUND THEN
				RAISE NOTICE 'Account collection name % of type "automated" not found in %', ac_name, TG_NAME;
				CONTINUE;
			END IF;
			DELETE FROM account_collection_account WHERE account_collection_id = ac_id AND account_id = r.account_id;
		END IF;
	END LOOP;
	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	END IF;
	RETURN NEW;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER;
DROP TRIGGER IF EXISTS trig_automated_realm_site_ac_pl ON person_location;
CREATE TRIGGER trig_automated_realm_site_ac_pl AFTER DELETE OR INSERT OR UPDATE ON person_location FOR EACH ROW EXECUTE PROCEDURE automated_realm_site_ac_pl();
