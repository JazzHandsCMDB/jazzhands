/*==============================================================*/
/* triggers and such for JazzHands PostgreSQL 8.3               */
/*==============================================================*/


-- Since PostgreSQL does not have packages like Oracle does, we're using
-- schemas instead for namespace similarity.  Also, since PostgreSQL
-- does not have session variables, we have to use a temporary table
-- to hold our junk.  Yay.


-- --
-- -- IntegrityPackage
-- --
/* config variable version */


CREATE SCHEMA "IntegrityPackage";

-- Function to initialize the trigger nest level

CREATE OR REPLACE FUNCTION "IntegrityPackage"."InitNestLevel"() 
	RETURNS VOID AS $$
BEGIN
	SELECT set_config('jazzhands.nestlevel', 0, false);
END;
$$ LANGUAGE plpgsql;

-- Function to return the trigger nest level

CREATE OR REPLACE FUNCTION "IntegrityPackage"."GetNestLevel"()
	RETURNS INTEGER AS $$
DECLARE
    level INTEGER;
BEGIN
	BEGIN
		level := current_setting('jazzhands.nestlevel');
	EXCEPTION
		WHEN OTHERS THEN
			level := set_config('jazzhands.nestlevel', '0', false);
	END;
    RETURN (level);
END;
$$ LANGUAGE plpgsql;

-- Procedure to increase the trigger nest level

CREATE OR REPLACE FUNCTION "IntegrityPackage"."NextNestLevel"() 
	RETURNS INTEGER AS $$
DECLARE
    level INTEGER;
BEGIN
	BEGIN
		level := current_setting('jazzhands.nestlevel');
	EXCEPTION
		WHEN OTHERS THEN
			level := 0;
	END;
	IF level IS NULL THEN
		level := set_config('jazzhands.nestlevel', '1', false);
	ELSE
		level := set_config('jazzhands.nestlevel', (level + 1)::VARCHAR,
			false);
	END IF;
	RETURN(level);
END;
$$ LANGUAGE plpgsql;

-- Procedure to decrease the trigger nest level

CREATE OR REPLACE FUNCTION "IntegrityPackage"."PreviousNestLevel"()
	RETURNS INTEGER AS $$
DECLARE
    level INTEGER;
BEGIN
	BEGIN
		level := current_setting('jazzhands.nestlevel');
	EXCEPTION
		WHEN OTHERS THEN
			level := 0;
	END;
	IF (level IS NULL) OR (level <= 0) THEN
		level := set_config('jazzhands.nestlevel', '0', false);
	ELSE
		level := set_config('jazzhands.nestlevel', (level - 1)::VARCHAR,
			false);
	END IF;
	RETURN(level);
END;
$$ LANGUAGE plpgsql;

/* Temporary table version */
/*
CREATE SCHEMA "IntegrityPackage";

-- Function to initialize the trigger nest level

CREATE OR REPLACE FUNCTION "IntegrityPackage"."InitNestLevel"() 
	RETURNS INTEGER AS $$
BEGIN
	BEGIN
		CREATE TEMP TABLE "IntegrityPackageVariables" (
			myrow	INTEGER,
			nestlevel	INTEGER default 0,
			constraint "pk_IntegrityPackageVariables" primary key (myrow)
		);
		INSERT INTO "IntegrityPackageVariables" (myrow) VALUES (1);
	EXCEPTION
		WHEN OTHERS THEN
			NULL;
	END;
	RETURN(0);
END;
$$ LANGUAGE plpgsql;

-- Function to return the trigger nest level

CREATE OR REPLACE FUNCTION "IntegrityPackage"."GetNestLevel"() 
	RETURNS INTEGER AS $$
DECLARE
    level INTEGER;
BEGIN
	level := 0;
    BEGIN
        SELECT nestlevel INTO level FROM "IntegrityPackageVariables";
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END;
    RETURN (level);
END;
$$ LANGUAGE plpgsql;

-- Procedure to increase the trigger nest level

CREATE OR REPLACE FUNCTION "IntegrityPackage"."NextNestLevel"()
	RETURNS INTEGER AS $$
DECLARE
    level INTEGER;
BEGIN
	level := 0;
    BEGIN
        SELECT nestlevel INTO level FROM "IntegrityPackageVariables";
    EXCEPTION
        WHEN OTHERS THEN
			RETURN (level);
    END;
	level := level + 1;
	UPDATE "IntegrityPackageVariables" SET nestlevel = level;
	RETURN(level);
END;
$$ LANGUAGE plpgsql;

-- Procedure to decrease the trigger nest level

CREATE OR REPLACE FUNCTION "IntegrityPackage"."PreviousNestLevel"()
	RETURNS INTEGER AS $$
DECLARE
    level INTEGER;
BEGIN
	level := 0;
    BEGIN
        SELECT nestlevel INTO level FROM "IntegrityPackageVariables";
    EXCEPTION
        WHEN OTHERS THEN
			RETURN (level);
    END;
	IF level > 0 THEN
		level := level - 1;
		UPDATE "IntegrityPackageVariables" SET nestlevel = level;
	END IF;
	RETURN(level);
END;
$$ LANGUAGE plpgsql;
*/

CREATE OR REPLACE FUNCTION trigger_ins_upd_generic_func() RETURNS TRIGGER AS $$
DECLARE
	appuser	VARCHAR;
BEGIN
	BEGIN
		appuser := current_user || '/' || current_setting('jazzhands.appuser');
	EXCEPTION
		WHEN OTHERS THEN
			appuser := current_user;
	END;
	IF TG_OP = 'INSERT' THEN
		NEW.data_ins_user = appuser;
		NEW.data_ins_date = 'now';
	END IF;

	if TG_OP = 'UPDATE' THEN
		NEW.data_upd_user = appuser;
		NEW.data_upd_date = 'now';
		IF OLD.data_ins_user != NEW.data_ins_user then
			RAISE EXCEPTION
				'Non modifiable column "DATA_INS_USER" cannot be modified.';
		END IF;
		IF OLD.data_ins_date != NEW.data_ins_date then
			RAISE EXCEPTION
				'Non modifiable column "DATA_INS_DATE" cannot be modified.';
		END IF;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rebuild_stamp_triggers() RETURNS VOID AS $$
BEGIN
	DECLARE
		tab	RECORD;
	BEGIN
		FOR tab IN 
			SELECT 
				table_name
			FROM
				information_schema.tables
			WHERE
				table_schema = 'public' AND
				table_type = 'BASE TABLE' AND
				table_name NOT LIKE 'aud$%'
		LOOP
			EXECUTE 'DROP TRIGGER IF EXISTS ' ||
				quote_ident('trig_userlog_' || tab.table_name) ||
				' ON ' || quote_ident(tab.table_name);
			EXECUTE 'CREATE TRIGGER ' ||
				quote_ident('trig_userlog_' || tab.table_name) ||
				' BEFORE INSERT OR UPDATE ON ' ||
				quote_ident(tab.table_name) ||
				' FOR EACH ROW EXECUTE PROCEDURE trigger_ins_upd_generic_func()';
		END LOOP;
	END;
END;
$$ LANGUAGE plpgsql;

select rebuild_stamp_triggers();

--
-- Make sure there is only one department of type 'direct' for a given user
--

/* XXX REVISIT

CREATE OR REPLACE FUNCTION verify_direct_dept_member() RETURNS TRIGGER AS $$
BEGIN
	PERFORM count(*) FROM dept_member WHERE reporting_type = 'DIRECT'
		GROUP BY person_id HAVING count(*) > 1;
	IF FOUND THEN
		RAISE EXCEPTION 'Users may not directly report to multiple departments';
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

--
--
--

DROP TRIGGER IF EXISTS trigger_verify_direct_dept_member ON dept_member;
CREATE TRIGGER trigger_verify_direct_dept_member AFTER INSERT OR UPDATE 
	ON dept_member EXECUTE PROCEDURE verify_direct_dept_member();

*/

CREATE OR REPLACE FUNCTION verify_layer1_connection() RETURNS TRIGGER AS $$
BEGIN
	PERFORM 1 FROM 
		layer1_connection l1 JOIN layer1_connection l2 ON 
			l1.physical_port1_id = l2.physical_port2_id AND
			l1.physical_port2_id = l2.physical_port1_id;
	IF FOUND THEN
		RAISE EXCEPTION 'Connection already exists in opposite direction';
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_verify_layer1_connection ON layer1_connection;
CREATE TRIGGER trigger_verify_layer1_connection AFTER INSERT OR UPDATE 
	ON layer1_connection EXECUTE PROCEDURE verify_layer1_connection();

CREATE OR REPLACE FUNCTION verify_physical_connection() RETURNS TRIGGER AS $$
BEGIN
	PERFORM 1 FROM 
		physical_connection l1 JOIN physical_connection l2 ON 
			l1.physical_port_id1 = l2.physical_port_id2 AND
			l1.physical_port_id2 = l2.physical_port_id1;
	IF FOUND THEN
		RAISE EXCEPTION 'Connection already exists in opposite direction';
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_verify_physical_connection ON physical_connection;
CREATE TRIGGER trigger_verify_physical_connection AFTER INSERT OR UPDATE 
	ON physical_connection EXECUTE PROCEDURE verify_physical_connection();

CREATE OR REPLACE FUNCTION verify_device_voe() RETURNS TRIGGER AS $$
DECLARE
	voe_sw_pkg_repos		sw_package_repository.sw_package_repository_id%TYPE;
	os_sw_pkg_repos		operating_system.sw_package_repository_id%TYPE;
	voe_sym_trx_sw_pkg_repo_id	voe_symbolic_track.sw_package_repository_id%TYPE;
BEGIN

	IF (NEW.operating_system_id IS NOT NULL)
	THEN
		SELECT sw_package_repository_id INTO os_sw_pkg_repos
			FROM
				operating_system
			WHERE
				operating_system_id = NEW.operating_system_id;
	END IF;

	IF (NEW.voe_id IS NOT NULL) THEN
		SELECT sw_package_repository_id INTO voe_sw_pkg_repos
			FROM
				voe
			WHERE
				voe_id=NEW.voe_id;
		IF (voe_sw_pkg_repos != os_sw_pkg_repos) THEN
			RAISE EXCEPTION 
				'Device OS and VOE have different SW Pkg Repositories';
		END IF;
	END IF;

	IF (NEW.voe_symbolic_track_id IS NOT NULL) THEN
		SELECT sw_package_repository_id INTO voe_sym_trx_sw_pkg_repo_id	
			FROM
				voe_symbolic_track
			WHERE
				voe_symbolic_track_id=NEW.voe_symbolic_track_id;
		IF (voe_sym_trx_sw_pkg_repo_id != os_sw_pkg_repos) THEN
			RAISE EXCEPTION 
				'Device OS and VOE track have different SW Pkg Repositories';
		END IF;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_verify_device_voe ON device;
CREATE TRIGGER trigger_verify_device_voe BEFORE INSERT OR UPDATE
	ON device FOR EACH ROW EXECUTE PROCEDURE verify_device_voe();

CREATE OR REPLACE FUNCTION update_dns_zone() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
		UPDATE dns_domain SET zone_last_updated = now()
            WHERE dns_domain_id = NEW.dns_domain_id;

		IF NEW.dns_type = 'A' THEN
			UPDATE  dns_domain SET zone_last_updated = now()
				WHERE dns_domain_id = netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id);
		END IF;

		IF TG_OP = 'UPDATE' THEN
			IF OLD.dns_domain_id != NEW.dns_domain_id THEN
				UPDATE dns_domain SET zone_last_updated = now()
					 WHERE dns_domain_id = OLD.dns_domain_id;
			END IF;
			IF NEW.dns_type = 'A' THEN
				IF OLD.netblock_id != NEW.netblock_id THEN
					UPDATE  dns_domain SET zone_last_updated = now()
						 WHERE dns_domain_id = netblock_utils.find_rvs_zone_from_netblock_id(OLD.netblock_id);
				END IF;
			END IF;
		END IF;
	END IF;

    IF TG_OP = 'DELETE' THEN
        UPDATE  dns_domain SET zone_last_updated = now()
			WHERE dns_domain_id = OLD.dns_domain_id;

        IF OLD.dns_type = 'A' THEN
			UPDATE dns_domain SET zone_last_updated = now()
                 WHERE  dns_domain_id = netblock_utils.find_rvs_zone_from_netblock_id(OLD.netblock_id);
        END IF;
    END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_dns_zone ON dns_record;
CREATE TRIGGER trigger_update_dns_zone AFTER INSERT OR DELETE OR UPDATE 
	ON dns_record FOR EACH ROW EXECUTE PROCEDURE update_dns_zone();

/* XXX REVISIT

CREATE OR REPLACE FUNCTION populate_default_vendor_term() RETURNS TRIGGER AS $$
BEGIN
	-- set default termination date as the end of the following quarter
	IF (NEW.person_type = 'vendor' AND NEW.termination_date IS NULL) THEN
		NEW.termination_date := date_trunc('quarter', now()) + interval '6 months';
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;


DROP TRIGGER IF EXISTS trigger_populate_vendor_default_term ON person;
CREATE TRIGGER trigger_populate_vendor_default_term BEFORE INSERT OR UPDATE
	ON person FOR EACH ROW EXECUTE PROCEDURE populate_default_vendor_term();

*/

CREATE OR REPLACE FUNCTION validate_property() RETURNS TRIGGER AS $$
DECLARE
	tally			integer;
	v_prop			VAL_Property%ROWTYPE;
	v_proptype		VAL_Property_Type%ROWTYPE;
	v_account_collection	account_collection%ROWTYPE;
	v_num			integer;
	v_listvalue		Property.Property_Value%TYPE;
BEGIN

	-- Pull in the data from the property and property_type so we can
	-- figure out what is and is not valid

	BEGIN
		SELECT * INTO STRICT v_prop FROM VAL_Property WHERE
			Property_Name = NEW.Property_Name AND
			Property_Type = NEW.Property_Type;

		SELECT * INTO STRICT v_proptype FROM VAL_Property_Type WHERE
			Property_Type = NEW.Property_Type;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			RAISE EXCEPTION 
				'Property name or type does not exist'
				USING ERRCODE = 'foreign_key_violation';
			RETURN NULL;
	END;

	-- Check to see if the property itself is multivalue.  That is, if only
	-- one value can be set for this property for a specific property LHS

	IF (v_prop.is_multivalue = 'N') THEN
		PERFORM 1 FROM Property WHERE
			Property_Id != NEW.Property_Id AND
			Property_Name = NEW.Property_Name AND
			Property_Type = NEW.Property_Type AND
			((Company_Id IS NULL AND NEW.Company_Id IS NULL) OR
				(Company_Id = NEW.Company_Id)) AND
			((Device_Collection_Id IS NULL AND NEW.Device_Collection_Id IS NULL) OR
				(Device_Collection_Id = NEW.Device_Collection_Id)) AND
			((DNS_Domain_Id IS NULL AND NEW.DNS_Domain_Id IS NULL) OR
				(DNS_Domain_Id = NEW.DNS_Domain_Id)) AND
			((Operating_System_Id IS NULL AND NEW.Operating_System_Id IS NULL) OR
				(Operating_System_Id = NEW.Operating_System_Id)) AND
			((Production_State IS NULL AND NEW.Production_State IS NULL) OR
				(Production_State = NEW.Production_State)) AND
			((Site_Code IS NULL AND NEW.Site_Code IS NULL) OR
				(Site_Code = NEW.Site_Code)) AND
			((Account_Id IS NULL AND NEW.Account_Id IS NULL) OR
				(Account_Id = NEW.Account_Id)) AND
			((account_collection_Id IS NULL AND NEW.account_collection_Id IS NULL) OR
				(account_collection_Id = NEW.account_collection_Id)) AND
			((person_id IS NULL AND NEW.Person_id IS NULL) OR
				(Account_Id = NEW.person_id))
			;
			
		IF FOUND THEN
			RAISE EXCEPTION 
				'Property of type % already exists for given LHS and property is not multivalue',
				NEW.Property_Type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;
	END IF;

	-- Check to see if the property type is multivalue.  That is, if only
	-- one property and value can be set for any properties with this type
	-- for a specific property LHS

	IF (v_proptype.is_multivalue = 'N') THEN
		PERFORM 1 FROM Property WHERE
			Property_Id != NEW.Property_Id AND
			Property_Type = NEW.Property_Type AND
			((Company_Id IS NULL AND NEW.Company_Id IS NULL) OR
				(Company_Id = NEW.Company_Id)) AND
			((Device_Collection_Id IS NULL AND NEW.Device_Collection_Id IS NULL) OR
				(Device_Collection_Id = NEW.Device_Collection_Id)) AND
			((DNS_Domain_Id IS NULL AND NEW.DNS_Domain_Id IS NULL) OR
				(DNS_Domain_Id = NEW.DNS_Domain_Id)) AND
			((Operating_System_Id IS NULL AND NEW.Operating_System_Id IS NULL) OR
				(Operating_System_Id = NEW.Operating_System_Id)) AND
			((Production_State IS NULL AND NEW.Production_State IS NULL) OR
				(Production_State = NEW.Production_State)) AND
			((Site_Code IS NULL AND NEW.Site_Code IS NULL) OR
				(Site_Code = NEW.Site_Code)) AND
			((Person_id IS NULL AND NEW.Person_id IS NULL) OR
				(Person_Id = NEW.Person_Id)) AND
			((Account_Id IS NULL AND NEW.Account_Id IS NULL) OR
				(Account_Id = NEW.Account_Id)) AND
			((account_collection_Id IS NULL AND NEW.account_collection_Id IS NULL) OR
				(account_collection_Id = NEW.account_collection_Id));

		IF FOUND THEN
			RAISE EXCEPTION 
				'Property % of type % already exists for given LHS and property type is not multivalue',
				NEW.Property_Name, NEW.Property_Type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;
	END IF;

	-- now validate the property_value columns.
	tally := 0;

	--
	-- first determine if the property_value is set properly.
	--

	-- iterate over each of fk PROPERTY_VALUE columns and if a valid
	-- value is set, increment tally, otherwise raise an exception.
	IF NEW.Property_Value_Company_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'company_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Company_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Password_Type IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'password_type' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Password_Type' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Token_Col_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'token_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Token_Collection_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_SW_Package_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'sw_package_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be SW_Package_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Account_Coll_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'account_collection_i' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be account_collection_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Timestamp IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'timestamp' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Timestamp' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_DNS_Domain_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'dns_domain_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be DNS_Domain_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Netblock_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'netblock_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Netblock_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Person_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'Person_Id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Person_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	-- at this point, tally will be set to 1 if one of the other property
	-- values is set to something valid.  Now, check the various options for
	-- PROPERTY_VALUE itself.  If a new type is added to the val table, this
	-- trigger needs to be updated or it will be considered invalid.  If a
	-- new PROPERTY_VALUE_* column is added, then it will pass through without
	-- trigger modification.  This should be considered bad.

	IF NEW.Property_Value IS NOT NULL THEN
		tally := tally + 1;
		IF v_prop.Property_Data_Type = 'boolean' THEN
			IF NEW.Property_Value != 'Y' AND NEW.Property_Value != 'N' THEN
				RAISE 'Boolean Property_Value must be Y or N' USING
					ERRCODE = 'invalid_parameter_value';
			END IF;
		ELSIF v_prop.Property_Data_Type = 'number' THEN
			BEGIN
				v_num := to_number(NEW.property_value, '9');
			EXCEPTION
				WHEN OTHERS THEN
					RAISE 'Property_Value must be numeric' USING
						ERRCODE = 'invalid_parameter_value';
			END;
		ELSIF v_prop.Property_Data_Type = 'list' THEN
			BEGIN
				SELECT Valid_Property_Value INTO STRICT v_listvalue FROM 
					VAL_Property_Value WHERE
						Property_Name = NEW.Property_Name AND
						Property_Type = NEW.Property_Type AND
						Valid_Property_Value = NEW.Property_Value;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					RAISE 'Property_Value must be a valid value' USING
						ERRCODE = 'invalid_parameter_value';
			END;
		ELSIF v_prop.Property_Data_Type != 'string' THEN
			RAISE 'Property_Data_Type is not a known type' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_prop.Property_Data_Type != 'none' AND tally = 0 THEN
		RAISE 'One of the PROPERTY_VALUE fields must be set.' USING
			ERRCODE = 'invalid_parameter_value';
	END IF;

	IF tally > 1 THEN
		RAISE 'Only one of the PROPERTY_VALUE fields may be set.' USING
			ERRCODE = 'invalid_parameter_value';
	END IF;

	-- If the RHS contains a account_collection_ID, check to see if it must be a
	-- specific type (e.g. per-user), and verify that if so
	
	IF NEW.Property_Value_Account_Coll_Id IS NOT NULL THEN
		IF v_prop.Prop_Val_account_collection_Type_Rstrct IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_account_collection FROM account_collection WHERE
					account_collection_Id = NEW.Property_Value_Account_Coll_Id;
				IF v_account_collection.account_collection_Type != v_prop.Prop_Val_account_collection_Type_Rstrct
				THEN
					RAISE 'Property_Value_Account_Coll_Id must be of type %',
					v_prop.Prop_Val_account_collection_Type_Rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- At this point, the RHS has been checked, so now we verify data
	-- set on the LHS

	-- There needs to be a stanza here for every "lhs".  If a new column is
	-- added to the property table, a new stanza needs to be added here,
	-- otherwise it will not be validated.  This should be considered bad.

	IF v_prop.Permit_Company_Id = 'REQUIRED' THEN
			IF NEW.Company_Id IS NULL THEN
				RAISE 'Company_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Company_Id = 'PROHIBITED' THEN
			IF NEW.Company_Id IS NOT NULL THEN
				RAISE 'Company_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Device_Collection_Id = 'REQUIRED' THEN
			IF NEW.Device_Collection_Id IS NULL THEN
				RAISE 'Device_Collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;

	ELSIF v_prop.Permit_Device_Collection_Id = 'PROHIBITED' THEN
			IF NEW.Device_Collection_Id IS NOT NULL THEN
				RAISE 'Device_Collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_DNS_Domain_Id = 'REQUIRED' THEN
			IF NEW.DNS_Domain_Id IS NULL THEN
				RAISE 'DNS_Domain_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_DNS_Domain_Id = 'PROHIBITED' THEN
			IF NEW.DNS_Domain_Id IS NOT NULL THEN
				RAISE 'DNS_Domain_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Production_State = 'REQUIRED' THEN
			IF NEW.Production_State IS NULL THEN
				RAISE 'Production_State is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Production_State = 'PROHIBITED' THEN
			IF NEW.Production_State IS NOT NULL THEN
				RAISE 'Production_State is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Operating_System_Id = 'REQUIRED' THEN
			IF NEW.Operating_System_Id IS NULL THEN
				RAISE 'Operating_System_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Operating_System_Id = 'PROHIBITED' THEN
			IF NEW.Operating_System_Id IS NOT NULL THEN
				RAISE 'Operating_System_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Site_Code = 'REQUIRED' THEN
			IF NEW.Site_Code IS NULL THEN
				RAISE 'Site_Code is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Site_Code = 'PROHIBITED' THEN
			IF NEW.Site_Code IS NOT NULL THEN
				RAISE 'Site_Code is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Account_Id = 'REQUIRED' THEN
			IF NEW.Account_Id IS NULL THEN
				RAISE 'Account_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Account_Id = 'PROHIBITED' THEN
			IF NEW.Account_Id IS NOT NULL THEN
				RAISE 'Account_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_account_collection_Id = 'REQUIRED' THEN
			IF NEW.account_collection_Id IS NULL THEN
				RAISE 'account_collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_account_collection_Id = 'PROHIBITED' THEN
			IF NEW.account_collection_Id IS NOT NULL THEN
				RAISE 'account_collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Person_Id = 'REQUIRED' THEN
			IF NEW.Person_Id IS NULL THEN
				RAISE 'Person_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Person_Id = 'PROHIBITED' THEN
			IF NEW.Person_Id IS NOT NULL THEN
				RAISE 'Person_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_validate_property ON Property;
CREATE TRIGGER trigger_validate_property BEFORE INSERT OR UPDATE 
	ON Property FOR EACH ROW EXECUTE PROCEDURE validate_property();

CREATE OR REPLACE FUNCTION update_account_type_account_collection() RETURNS TRIGGER AS $$
DECLARE
	uc_name		account_collection.account_collection_Name%TYPE;
	ucid		account_collection.account_collection_Id%TYPE;
BEGIN
	IF TG_OP = 'UPDATE' THEN
		IF OLD.Account_Type = NEW.Account_Type THEN 
			RETURN NEW;
		END IF;

	uc_name := OLD.Account_Type;

	DELETE FROM account_collection_Account WHERE Account_Id = OLD.Account_Id AND
		account_collection_ID = (
			SELECT account_collection_ID 
			FROM account_collection 
			WHERE account_collection_Name = uc_name 
			AND account_collection_Type = 'usertype');

	END IF;
	uc_name := NEW.Account_Type;
	BEGIN
		SELECT account_collection_ID INTO STRICT ucid 
		  FROM account_collection 
		 WHERE account_collection_Name = uc_name 
		AND account_collection_Type = 'usertype';
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			INSERT INTO account_collection (
				account_collection_Name, account_collection_Type
			) VALUES (
				uc_name, 'usertype'
			) RETURNING account_collection_Id INTO ucid;
	END;
	IF ucid IS NOT NULL THEN
		INSERT INTO account_collection_Account (
			account_collection_ID,
			Account_Id
		) VALUES (
			ucid,
			NEW.Account_Id
		);
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_account_type_account_collection
	ON Account;
CREATE TRIGGER trigger_update_account_type_account_collection AFTER INSERT OR UPDATE 
	ON Account FOR EACH ROW EXECUTE PROCEDURE 
	update_account_type_account_collection();

/* XXX REVISIT

CREATE OR REPLACE FUNCTION update_company_account_collection() RETURNS TRIGGER AS $$
DECLARE
	compname	Company.Company_Name%TYPE;
	uc_name		account_collection.Name%TYPE;
	ucid		account_collection.account_collection_Id%TYPE;
BEGIN
	IF TG_OP = 'UPDATE' THEN
		IF OLD.Company_Id = NEW.Company_Id THEN 
			RETURN NEW;
		END IF;

		SELECT Company_Name INTO compname FROM Company WHERE
			Company_Id = OLD.Company_ID;

		IF compname IS NOT NULL THEN
			--
			-- The following awesome nested regex does the following to the
			-- company name:
			--   - eliminate anything after the first comma or parens
			--   - eliminate all non-alphanumerics (except spaces)
			--   - remove any trailing 'corporation', 'inc', 'llc' or 'inc'
			--   - convert spaces to underscores
			--   - lowercase
			--
			uc_name := regexp_replace(
						regexp_replace(
							regexp_replace(
								regexp_replace(
									regexp_replace(lower(compname),
									' ?[,(].*$', ''),
								'&', 'and'),
							'[^A-Za-z0-9 ]', ''),
						' (corporation|inc|llc|ltd|co|corp|llp)$', ''),
					' ', '_');

			DELETE FROM account_collection_Account WHERE Account_id = OLD.Person_ID 
				AND account_collection_ID = (
					SELECT account_collection_ID FROM account_collection WHERE Name = uc_name 
					AND account_collection_Type = 'company');
		END IF;
	END IF;

	SELECT Company_Name INTO compname FROM Company WHERE
		Company_Id = NEW.Company_ID;

	IF compname IS NOT NULL THEN
		--
		-- The following awesome nested regex does the following to the
		-- company name:
		--   - eliminate anything after the first comma or parens
		--   - eliminate all non-alphanumerics (except spaces)
		--   - remove any trailing 'corporation', 'inc', 'llc' or 'inc'
		--   - convert spaces to underscores
		--   - lowercase
		--
		uc_name := regexp_replace(
					regexp_replace(
						regexp_replace(
							regexp_replace(
								regexp_replace(lower(compname),
								' ?[,(].*$', ''),
							'&', 'and'),
						'[^A-Za-z0-9 ]', ''),
					' (corporation|inc|llc|ltd|co|corp|llp)$', ''),
				' ', '_');

		BEGIN
			SELECT account_collection_ID INTO STRICT ucid FROM account_collection WHERE
				Name = uc_name AND account_collection_Type = 'company';
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				INSERT INTO account_collection (
					Name, account_collection_Type
				) VALUES (
					uc_name, 'company'
				) RETURNING account_collection_Id INTO ucid;
		END;
		IF ucid IS NOT NULL THEN
			INSERT INTO account_collection_Account (
				account_collection_ID,
				Person_ID
			) VALUES (
				ucid,
				NEW.Person_Id
			);
		END IF;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_company_account_collection 
	ON Person;
CREATE TRIGGER trigger_update_company_account_collection AFTER INSERT OR UPDATE 
	ON Person FOR EACH ROW EXECUTE PROCEDURE update_company_account_collection();

*/

/*
 * XXX - this needs ot be compared to the oracle trigger.
 * I'm not clear that it captures all the cases it should and doesn't
 * use netmask_bits like it probably should
 */
CREATE OR REPLACE FUNCTION validate_netblock() RETURNS TRIGGER AS $$
DECLARE
	pip	    netblock.ip_address%type;
	dumb	boolean;
BEGIN
	/* note, the autonomous transaction stuff may make some of the stuff  
	 * we're trying to do
	 * here weird.
	 */
	 
	/* XXX ORACLE/PGSQL */
	/* 
	 * Only IPv4 Now...
	 */
	IF( masklen(NEW.ip_address) > 32) THEN
			return NEW;
	END IF;

	/*
	 * only allow multiple addresses to exist if it is a 1918-space 
	 * address.   (This may need to be revised for sites that do really
	 *  really really stupid things.  Perhaps a marker in the netblock 
	 * that indicates that its one of these blocks or  some such?  Or a
	 * separate table that says which blocks are ok.  (make the 
	 * mutating table stuff better?) 
	 */
	IF net_manip.inet_is_private(NEW.ip_address) = FALSE THEN
			PERFORM netblock_id 
			   FROM netblock 
			  WHERE ip_address = new.ip_address;
			IF (TG_OP = 'INSERT' AND FOUND) THEN 
				RAISE EXCEPTION 'Unique Constraint Violated on IP Address: %', 
					new.ip_address
					USING ERRCODE= -20701;
			END IF;
			IF (TG_OP = 'UPDATE') THEN
				IF (NEW.ip_address != OLD.ip_address AND FOUND) THEN
					RAISE EXCEPTION 
						'Unique Constraint Violated on IP Address: %', 
						new.ip_address
						USING ERRCODE = -20701;
				END IF;
			END IF;
	END IF;

	/* verify that parentage still matters.  */
	IF NEW.parent_netblock_id IS NOT NULL THEN 
		dumb := FALSE;
		IF TG_OP = 'INSERT' THEN
			dumb := TRUE;
		ELSIF TG_OP = 'UPDATE' THEN
			IF (NEW.ip_address != OLD.ip_address) OR 
					(NEW.parent_netblock_id != old.parent_netblock_id) THEN
				dumb := TRUE;
			END IF;
		END IF;
		IF dumb = TRUE THEN
			SELECT cast(host(ip_address) || '/' || netmask_bits as inet)  
		      INTO pip 
			  FROM netblock 
		     WHERE netblock_id = new.parent_netblock_id;
			IF NOT FOUND THEN
				RAISE EXCEPTION 
					'Parent netblock id not found!  This should not happen.';
			END IF;
			IF NOT(NEW.ip_address << pip) THEN
				RAISE EXCEPTION 'Netblock is not contained in parent'
					USING ERRCODE = 20703;
			END IF;
		END IF;
	END IF;

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_validate_netblock ON netblock;
CREATE TRIGGER trigger_validate_netblock BEFORE INSERT OR UPDATE ON netblock
	FOR EACH ROW EXECUTE PROCEDURE validate_netblock();

/*
 * Deal with propagating person status down to accounts, if appropriate
 *
 * XXX - this needs to be reimplemented in oracle
 */
CREATE OR REPLACE FUNCTION propagate_person_status_to_account()
	RETURNS TRIGGER AS $$
DECLARE
	should_propagate 	val_person_status.propagate_from_person%type;
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
			  AND	company_id = NEW.company_id
			  AND	account_status in (
				  	SELECT	person_status
					  FROM	val_person_status
					 WHERE	propagate_from_person = 'Y'
			  	);
		END IF;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_propagate_person_status_to_account 
	ON person_company;
CREATE TRIGGER trigger_propagate_person_status_to_account 
AFTER UPDATE ON person_company
	FOR EACH ROW EXECUTE PROCEDURE propagate_person_status_to_account();
 
/*
 * Do not let hierarchy point to itself.  This shoudl probabyl be extended
 * to check up/down the hierarchy to prevent loops.  Needs to be ported to
 * oracle XXX
 */
CREATE OR REPLACE FUNCTION check_account_colllection_hier_loop()
	RETURNS TRIGGER AS $$
BEGIN
	IF NEW.account_collection_id = NEW.child_account_collection_id THEN
		RAISE EXCEPTION 'Account Collection Loops Not Pernitted '
			USING ERRCODE = 20704;	/* XXX */
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_check_account_collection_hier_loop 
	ON account_collection_hier;
CREATE TRIGGER trigger_check_account_collection_hier_loop 
AFTER INSERT OR UPDATE ON account_collection_hier
	FOR EACH ROW EXECUTE PROCEDURE check_account_colllection_hier_loop();
 

