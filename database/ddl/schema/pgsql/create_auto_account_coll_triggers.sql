CREATE OR REPLACE FUNCTION get_automated_account_collection_id(ac_name VARCHAR) RETURNS INTEGER AS $_$
DECLARE
	ac_id INTEGER;
BEGIN
	SELECT account_collection_id INTO ac_id FROM account_collection WHERE account_collection_name = ac_name AND account_collection_type ='automated';
	IF NOT FOUND THEN
		RAISE NOTICE 'Account collection name % of type "automated" not found. Creating', ac_name;
		INSERT INTO account_collection (account_collection_name, account_collection_type) VALUES (ac_name, 'automated')
			RETURNING account_collection_id INTO ac_id;
	END IF;
	RETURN ac_id;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION insert_or_delete_automated_ac(do_delete BOOLEAN,acct_id INTEGER,ac_ids INTEGER[]) RETURNS VOID AS $_$
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

CREATE OR REPLACE FUNCTION automated_ac() RETURNS TRIGGER AS $_$
DECLARE
	acr	VARCHAR;
	c_name VARCHAR;
	sc VARCHAR;
	ac_ids INTEGER[];
	delete_aca BOOLEAN;
BEGIN
	IF TG_OP = 'INSERT' THEN
		IF NEW.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
		PERFORM 1 FROM val_person_status WHERE NEW.account_status = person_status AND is_disabled = 'N';
		IF NOT FOUND THEN
			RETURN NEW;
		END IF;
	END IF;
	ac_ids = '{-1,-1,-1}';
	SELECT account_realm_name INTO acr FROM account_realm WHERE account_realm_id = NEW.account_realm_id;
	ac_ids[0] = get_automated_account_collection_id(acr || '_' || NEW.account_type);	
	SELECT company_short_name INTO c_name FROM company WHERE company_id = NEW.company_id;
	IF NOT FOUND OR c_name IS NULL THEN
		RAISE NOTICE 'Company short name cannot be determined from company_id % in %', NEW.company_id, TG_NAME;
	ELSE
		ac_ids[1] = get_automated_account_collection_id(acr || '_' || c_name || '_' || NEW.account_type);
	END IF;
	SELECT site_code INTO sc FROM person_location WHERE person_id = NEW.person_id;
	IF FOUND AND sc IS NOT NULL THEN
		ac_ids[2] = get_automated_account_collection_id(acr || '_' || sc);
	END IF;
	delete_aca = 't';
	IF TG_OP = 'INSERT' THEN
		delete_aca = 'f';
	ELSE
		IF NEW.account_role != 'primary' AND NEW.account_role != OLD.account_role THEN
			PERFORM insert_or_delete_automated_ac('t', OLD.account_id, ac_ids);
			RETURN NEW;
		END IF;
		PERFORM 1 FROM val_person_status WHERE new.account_status = person_status AND is_disabled = 'N';
		IF NOT FOUND THEN
			PERFORM insert_or_delete_automated_ac('t', OLD.account_id, ac_ids);
			RETURN NEW;
		END IF;
		IF NEW.account_role = 'primary' AND NEW.account_role != OLD.account_role OR
			NEW.account_status != OLD.account_status THEN
			delete_aca = 'f';
		END IF;
	END IF;
	IF NOT delete_aca THEN
		PERFORM insert_or_delete_automated_ac('f', NEW.account_id, ac_ids);
	END IF;
	RETURN NEW;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER;
DROP TRIGGER IF EXISTS trig_automated_ac ON account;
CREATE TRIGGER trig_automated_ac AFTER INSERT OR UPDATE ON account FOR EACH ROW EXECUTE PROCEDURE automated_ac();

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

	FOR r IN SELECT account_realm_name, account_id FROM account_realm ar
		JOIN account a ON ar.account_realm_id=a.account_realm_id AND a.account_role = 'primary' AND a.person_id = p_id 
		JOIN val_person_status vps ON vps.person_status = a.account_status AND vps.is_disabled='N'
		JOIN site s ON s.site_code = sc AND a.company_id = s.colo_company_id
	LOOP
		IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
			ac_name = r.account_realm_name || '_' || sc;
			ac_id = get_automated_account_collection_id( r.account_realm_name || '_' || sc );
			IF TG_OP = 'UPDATE' AND NEW.person_location_type != 'office' THEN
				CONTINUE;
			END IF;
			PERFORM	insert_if_not_there_account_collection_account(ac_id, r.account_id);
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
END	
$_$ LANGUAGE plpgsql SECURITY DEFINER;
DROP TRIGGER IF EXISTS trig_automated_realm_site_ac_pl ON person_location;
CREATE TRIGGER trig_automated_realm_site_ac_pl AFTER DELETE OR INSERT OR UPDATE ON person_location FOR EACH ROW EXECUTE PROCEDURE automated_realm_site_ac_pl();
