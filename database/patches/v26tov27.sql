-- drop views that get recreated at the bottom
drop view IF EXISTS v_application_role_member;
drop view IF EXISTS v_application_role;
drop view IF EXISTS v_acct_coll_prop_expanded;
drop view IF EXISTS v_property;

drop view IF EXISTS v_acct_coll_account_expanded;

drop function build_audit_tables();
drop function rebuild_audit_triggers();
drop function rebuild_stamp_triggers();

drop table IF EXISTS val_account_collection_type_xx;
drop sequence IF EXISTS val_account_collection_type_xx_seq;
drop table IF EXISTS audit.val_account_collection_type_xx;
drop sequence IF EXISTS audit.val_account_collection_type_xx_seq;


--
-- $HeadURL: https://jazzhands.svn.sourceforge.net/svnroot/jazzhands/trunk/database/ddl/schema/pgsql/create_schema_support.sql $
-- $Id: create_schema_support.sql 184 2012-08-13 23:16:29Z kovert $
--
drop schema IF EXISTS schema_support;
create schema schema_support authorization jazzhands;

-------------------------------------------------------------------
-- returns the Id tag for CM
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION schema_support.id_tag()
RETURNS VARCHAR AS $$
BEGIN
        RETURN('<-- $Id -->');
END;
$$ LANGUAGE plpgsql;
-- end of procedure id_tag
-------------------------------------------------------------------

CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_trigger(name varchar)
RETURNS VOID AS $$
DECLARE
	create_text	VARCHAR;
BEGIN
	EXECUTE 'CREATE OR REPLACE FUNCTION ' || quote_ident('perform_audit_' || 
			name) || $ZZ$() RETURNS TRIGGER AS $TQ$
		DECLARE
			appuser VARCHAR;
		BEGIN
			BEGIN
				appuser := session_user || '/' || current_setting('jazzhands.appuser');
			EXCEPTION
				WHEN OTHERS THEN
					appuser := session_user;
			END;

			IF TG_OP = 'DELETE' THEN
				INSERT INTO audit.$ZZ$ || quote_ident(name) || $ZZ$ VALUES (
					OLD.*, 'DEL', now(), appuser);
				RETURN OLD;
			ELSIF TG_OP = 'UPDATE' THEN
				INSERT INTO audit.$ZZ$ || quote_ident(name) || $ZZ$ VALUES (
					NEW.*, 'UPD', now(), appuser);
				RETURN NEW;
			ELSIF TG_OP = 'INSERT' THEN
				INSERT INTO audit.$ZZ$ || quote_ident(name) || $ZZ$ VALUES (
					NEW.*, 'INS', now(), appuser);
				RETURN NEW;
			END IF;
			RETURN NULL;
		END;
		$TQ$ LANGUAGE plpgsql SECURITY DEFINER
	$ZZ$;
	EXECUTE 'DROP TRIGGER IF EXISTS ' ||
		quote_ident('trigger_audit_' || name) || ' ON ' || quote_ident(name);
	EXECUTE 'CREATE TRIGGER ' ||
		quote_ident('trigger_audit_' || name) || 
			' AFTER INSERT OR UPDATE OR DELETE ON ' ||
			quote_ident(name) || ' FOR EACH ROW EXECUTE PROCEDURE ' ||
			quote_ident('perform_audit_' || name) || '()';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_triggers()
RETURNS VOID AS $$
DECLARE
	table_list	RECORD;
	name		VARCHAR;
BEGIN
	--
	-- select tables with audit tables
	--
	FOR table_list IN SELECT table_name FROM information_schema.tables
		WHERE
			table_type = 'BASE TABLE' AND
			table_schema = 'public' AND
			table_name IN (
				SELECT
					table_name 
				FROM
					information_schema.tables
				WHERE
					table_schema = 'audit' AND
					table_type = 'BASE TABLE'
				)
		ORDER BY
			table_name
	LOOP
		name := table_list.table_name;
		PERFORM schema_support.rebuild_audit_trigger(name);
	END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION schema_support.build_audit_table(
	name varchar,
	first_time boolean DEFAULT true
) RETURNS VOID AS $FUNC$
DECLARE
	create_text	VARCHAR;
BEGIN
	if first_time = true THEN
		EXECUTE 'CREATE SEQUENCE audit.' || quote_ident(name || '_seq');
	end if;
	EXECUTE 'CREATE TABLE audit.' || quote_ident(name) || ' AS
		SELECT *,
			NULL::char(3) as "aud#action",
			now() as "aud#timestamp",
			NULL::varchar(30) AS "aud#user",
			NULL::integer AS "aud#seq"
		FROM ' || quote_ident(name) || ' LIMIT 0';
	EXECUTE 'ALTER TABLE audit.' || quote_ident(name ) ||
		$$ ALTER COLUMN "aud#seq" SET NOT NULL,
		ALTER COLUMN "aud#seq" SET DEFAULT nextval('audit.$$ ||
			name || '_seq' || $$')$$;
	IF first_time = true THEN
		PERFORM schema_support.rebuild_audit_trigger(name);
	END IF;
END;
$FUNC$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION schema_support.build_audit_tables()
RETURNS VOID AS $FUNC$
DECLARE
	table_list	RECORD;
	create_text	VARCHAR;
	name		VARCHAR;
BEGIN
	FOR table_list IN SELECT table_name FROM information_schema.tables
		WHERE
			table_type = 'BASE TABLE' AND
			table_schema = 'public' AND
			NOT( table_name IN (
				SELECT
					table_name 
				FROM
					information_schema.tables
				WHERE
					table_schema = 'audit'
				)
			)
		ORDER BY
			table_name
	LOOP
		name := table_list.table_name;
		PERFORM schema_support.build_audit_table(name);
	END LOOP;
	PERFORM schema_support.rebuild_audit_triggers();
END;
$FUNC$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION schema_support.trigger_ins_upd_generic_func()
RETURNS TRIGGER AS $$
DECLARE
	appuser	VARCHAR;
BEGIN
	BEGIN
		appuser := session_user || '/' || current_setting('jazzhands.appuser');
	EXCEPTION
		WHEN OTHERS THEN
			appuser := session_user;
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION schema_support.rebuild_stamp_trigger(name varchar)
RETURNS VOID AS $$
BEGIN
	BEGIN
		EXECUTE 'DROP TRIGGER IF EXISTS ' ||
			quote_ident('trig_userlog_' || name) ||
			' ON ' || quote_ident(name);
		EXECUTE 'CREATE TRIGGER ' ||
			quote_ident('trig_userlog_' || name) ||
			' BEFORE INSERT OR UPDATE ON ' ||
			quote_ident(name) ||
			' FOR EACH ROW EXECUTE PROCEDURE 
			schema_support.trigger_ins_upd_generic_func()';
	END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION schema_support.rebuild_stamp_triggers()
RETURNS VOID AS $$
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
			PERFORM schema_support.rebuild_stamp_trigger(tab.table_name);
		END LOOP;
	END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- select schema_support.rebuild_stamp_triggers();
-- SELECT schema_support.build_audit_tables();

---------------------- data changes ----------------------------------------

CREATE TABLE val_service_environment
(
	service_environment	varchar(50)  NOT NULL,
	description	varchar(4000)  NULL,
	production_state	varchar(50)  NOT NULL,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
	data_upd_date	timestamp with time zone  NULL
);

SELECT schema_support.build_audit_table('val_service_environment', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_service_environment ADD CONSTRAINT pk_val_service_environment PRIMARY KEY (service_environment);
-- INDEXES
CREATE INDEX xif1val_service_environment ON val_service_environment USING btree (production_state);

-- CHECK CONSTRAINTS

-- these will be created later when the column is adjusted in all these tables
-- FOREIGN KEYS FROM
--ALTER TABLE network_service
--	ADD CONSTRAINT fk_netsvc_csvcenv
--	FOREIGN KEY (service_environment) REFERENCES val_service_environment(service_environment);
--ALTER TABLE device
--	ADD CONSTRAINT fk_device_fk_dev_v_svcenv
--	FOREIGN KEY (service_environment) REFERENCES val_service_environment(service_environment);
--ALTER TABLE appaal_instance
--	ADD CONSTRAINT fk_appaal_i_fk_applic_svcenv
--	FOREIGN KEY (service_environment) REFERENCES val_service_environment(service_environment);
--ALTER TABLE voe
--	ADD CONSTRAINT fk_voe_ref_v_svcenv
--	FOREIGN KEY (service_environment) REFERENCES val_service_environment(service_environment);
--ALTER TABLE sw_package_release
--	ADD CONSTRAINT fk_sw_pkg_rel_ref_vsvcenv
--	FOREIGN KEY (service_environment) REFERENCES val_service_environment(service_environment);
ALTER TABLE sw_package
	DROP CONSTRAINT fk_sw_pkg_ref_v_prod_state;
ALTER TABLE sw_package
	ADD CONSTRAINT fk_sw_pkg_ref_v_prod_state
	FOREIGN KEY (production_state_restriction) REFERENCES val_service_environment(service_environment);
--ALTER TABLE property
--	ADD CONSTRAINT fk_property_svcenv
--	FOREIGN KEY (service_environment) REFERENCES val_service_environment(service_environment) ON DELETE SET NULL;

-- FOREIGN KEYS TO
ALTER TABLE val_service_environment
	ADD CONSTRAINT r_429
	FOREIGN KEY (production_state) REFERENCES val_production_state(production_state) ON DELETE SET NULL;

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('val_service_environment');
SELECT schema_support.rebuild_audit_trigger('val_service_environment');

INSERT INTO VAL_service_environment (service_environment, production_state)
        VALUES ('unspecified', 'unspecified');
INSERT INTO VAL_service_environment (service_environment, production_state)
        VALUES ('unallocated', 'unallocated');
INSERT INTO VAL_service_environment (service_environment, production_state)
        VALUES ('production', 'production');
INSERT INTO VAL_service_environment (service_environment, production_state)
        VALUES ('development', 'development');
INSERT INTO VAL_service_environment (service_environment, production_state)
        VALUES ('qa', 'test');
INSERT INTO VAL_service_environment (service_environment, production_state)
        VALUES ('staging', 'test');
INSERT INTO VAL_service_environment (service_environment, production_state)
        VALUES ('test', 'test');

delete from val_production_state where production_state not in (
	'unspecified',
	'unallocated',
	'production',
	'development',
	'qa',
	'staging',
	'test'
);

-- DEALING WITH TABLE appaal_instance [183075]

-- FOREIGN KEYS FROM
alter table appaal_instance_property drop constraint fk_appaalins_ref_appaalinsprop;
alter table appaal_instance_device_coll drop constraint fk_appaalins_ref_appaalinsdcol;

-- FOREIGN KEYS TO
alter table appaal_instance drop constraint fk_appaal_i_reference_fo_accti;
alter table appaal_instance drop constraint fk_appaal_inst_filgrpacctcolid;
alter table appaal_instance drop constraint fk_appaal_i_fk_applic_val_prod;
alter table appaal_instance drop constraint fk_appaal_ref_appaal_inst;
alter table appaal_instance drop constraint pk_appaal_instance;
-- INDEXES
DROP INDEX xifappaal_inst_filgrpacctcolid;
-- CHECK CONSTRAINTS, etc
alter table appaal_instance drop constraint ckc_file_mode_appaal_i;
-- TRIGGERS, etc
drop trigger trig_userlog_appaal_instance on appaal_instance;
drop trigger trigger_audit_appaal_instance on appaal_instance;


ALTER TABLE appaal_instance RENAME TO appaal_instance_v26;
ALTER TABLE audit.appaal_instance RENAME TO appaal_instance_v26;

CREATE TABLE appaal_instance
(
	appaal_instance_id	integer  NOT NULL,
	appaal_id	integer  NULL,
	service_environment	varchar(50)  NOT NULL,
	file_mode	integer  NOT NULL,
	file_owner_account_id	integer  NOT NULL,
	file_group_acct_collection_id	integer,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('appaal_instance', false);
INSERT INTO appaal_instance (
	appaal_instance_id,
	appaal_id,
	service_environment,
	file_mode,
	file_owner_account_id,
	file_group_acct_collection_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT		appaal_instance_id,
	appaal_id,
	production_state,
	file_mode,
	file_owner_account_id,
	file_group_acct_collection_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM appaal_instance_v26;

INSERT INTO audit.appaal_instance (
	appaal_instance_id,
	appaal_id,
	service_environment,
	file_mode,
	file_owner_account_id,
	file_group_acct_collection_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT		appaal_instance_id,
	appaal_id,
	production_state,
	file_mode,
	file_owner_account_id,
	file_group_acct_collection_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.appaal_instance_v26;

ALTER TABLE appaal_instance
	ALTER appaal_instance_id
	SET DEFAULT nextval('appaal_instance_appaal_instance_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE appaal_instance ADD CONSTRAINT pk_appaal_instance PRIMARY KEY (appaal_instance_id);
-- INDEXES
CREATE INDEX xifappaal_inst_filgrpacctcolid ON appaal_instance USING btree (file_group_acct_collection_id);

-- CHECK CONSTRAINTS
ALTER TABLE appaal_instance ADD CONSTRAINT ckc_file_mode_appaal_i
	CHECK ((file_mode >= 0) AND (file_mode <= 4095));

-- FOREIGN KEYS FROM
ALTER TABLE appaal_instance_property
	ADD CONSTRAINT fk_appaalins_ref_appaalinsprop
	FOREIGN KEY (appaal_instance_id) REFERENCES appaal_instance(appaal_instance_id);
ALTER TABLE appaal_instance_device_coll
	ADD CONSTRAINT fk_appaalins_ref_appaalinsdcol
	FOREIGN KEY (appaal_instance_id) REFERENCES appaal_instance(appaal_instance_id);

-- FOREIGN KEYS TO
ALTER TABLE appaal_instance
	ADD CONSTRAINT fk_appaal_i_reference_fo_accti
	FOREIGN KEY (file_owner_account_id) REFERENCES account(account_id);
ALTER TABLE appaal_instance
	ADD CONSTRAINT fk_appaal_inst_filgrpacctcolid
	FOREIGN KEY (file_group_acct_collection_id) REFERENCES account_collection(account_collection_id) ON DELETE SET NULL;
ALTER TABLE appaal_instance
	ADD CONSTRAINT fk_appaal_i_fk_applic_svcenv
	FOREIGN KEY (service_environment) REFERENCES val_service_environment(service_environment);
ALTER TABLE appaal_instance
	ADD CONSTRAINT fk_appaal_ref_appaal_inst
	FOREIGN KEY (appaal_id) REFERENCES appaal(appaal_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('appaal_instance');
SELECT schema_support.rebuild_audit_trigger('appaal_instance');
alter sequence appaal_instance_appaal_instance_id_seq owned by
	appaal_instance.appaal_instance_id;
DROP TABLE appaal_instance_v26;
DROP TABLE audit.appaal_instance_v26;
-- end nutty reaction
GRANT ALL ON appaal_instance TO jazzhands;
GRANT SELECT ON appaal_instance TO ro_role;
GRANT INSERT,UPDATE,DELETE ON appaal_instance TO iud_role;
-- DEALING WITH TABLE device [183133]

-- FOREIGN KEYS FROM
alter table physical_port drop constraint fk_physport_dev_id;
alter table network_service drop constraint fk_netsvc_device_id;
alter table device drop constraint fk_device_ref_parent_device;
alter table device_power_interface drop constraint fk_device_device_power_supp;
alter table layer1_connection drop constraint fk_l1conn_ref_device;
alter table device_ticket drop constraint fk_dev_tkt_dev_id;
alter table device_collection_member drop constraint fk_devcollmem_dev_id;
alter table snmp_commstr drop constraint fk_snmpstr_device_id;
alter table device_note drop constraint fk_device_note_device;
alter table network_interface drop constraint fk_netint_device_id;
alter table static_route drop constraint fk_statrt_devsrc_id;

-- FOREIGN KEYS TO
alter table device drop constraint fk_device_dnsrecord;
alter table device drop constraint fk_device_vownerstatus;
alter table device drop constraint fk_device_fk_dev_val_prod;
alter table device drop constraint fk_device_ref_voesymbtrk;
alter table device drop constraint fk_device_reference_val_devi;
alter table device drop constraint fk_dev_devtp_id;
alter table device drop constraint fk_device_site_code;
alter table device drop constraint fk_device_fk_dev_val_stat;
alter table device drop constraint fk_dev_os_id;
alter table device drop constraint fk_dev_location_id;
alter table device drop constraint fk_device_fk_voe;
alter table device drop constraint pk_networkdevice;
-- INDEXES
DROP INDEX idx_dev_voeid;
DROP INDEX idx_dev_ismonitored;
DROP INDEX idx_dev_ownershipstatus;
DROP INDEX idx_dev_islclymgd;
DROP INDEX ix_netdev_devtype_id;
DROP INDEX idx_dev_iddnsrec;
DROP INDEX idx_dev_dev_status;
DROP INDEX idx_dev_locationid;
DROP INDEX idx_dev_osid;
DROP INDEX idx_dev_prodstate;
DROP INDEX xifdevice_sitecode;
-- CHECK CONSTRAINTS, etc
alter table device drop constraint sys_c0069052;
alter table device drop constraint ckc_is_locally_manage_device;
alter table device drop constraint ckc_is_monitored_device;
alter table device drop constraint sys_c0069060;
alter table device drop constraint sys_c0069056;
alter table device drop constraint sys_c0069054;
alter table device drop constraint sys_c0069057;
alter table device drop constraint sys_c0069055;
alter table device drop constraint ckc_should_fetch_conf_device;
alter table device drop constraint ckc_is_baselined_device;
alter table device drop constraint ckc_is_virtual_device_device;
alter table device drop constraint sys_c0069051;
alter table device drop constraint sys_c0069059;
alter table device drop constraint sys_c0069061;
-- TRIGGERS, etc
drop trigger trigger_verify_device_voe on device;
drop trigger trigger_audit_device on device;
drop trigger trig_userlog_device on device;


ALTER TABLE device RENAME TO device_v26;
ALTER TABLE audit.device RENAME TO device_v26;

CREATE TABLE device
(
	device_id	integer  NULL,
	device_type_id	integer  NOT NULL,
	device_name	varchar(255)  NULL,
	site_code	varchar(50)  NULL,
	identifying_dns_record_id	integer  NULL,
	serial_number	varchar(255)  NULL,
	part_number	varchar(255)  NULL,
	host_id	varchar(255)  NULL,
	physical_label	varchar(255)  NULL,
	asset_tag	varchar(255)  NULL,
	location_id	integer  NULL,
	parent_device_id	integer  NULL,
	description	varchar(255)  NULL,
	device_status	varchar(50)  NOT NULL,
	service_environment	varchar(50)  NOT NULL,
	operating_system_id	integer  NOT NULL,
	voe_id	integer  NULL,
	ownership_status	varchar(50)  NOT NULL,
	auto_mgmt_protocol	varchar(50)  NULL,
	voe_symbolic_track_id	integer  NULL,
	is_locally_managed	character(1)  NOT NULL,
	is_monitored	character(1)  NOT NULL,
	is_virtual_device	character(1)  NOT NULL,
	should_fetch_config	character(1)  NOT NULL,
	is_baselined	character(1)  NOT NULL,
	date_in_service	timestamp with time zone  NULL,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('device', false);
INSERT INTO device (
	device_id,
	device_type_id,
	device_name,
	site_code,
	identifying_dns_record_id,
	serial_number,
	part_number,
	host_id,
	physical_label,
	asset_tag,
	location_id,
	parent_device_id,
	description,
	device_status,
	service_environment,
	operating_system_id,
	voe_id,
	ownership_status,
	auto_mgmt_protocol,
	voe_symbolic_track_id,
	is_locally_managed,
	is_monitored,
	is_virtual_device,
	should_fetch_config,
	is_baselined,
	date_in_service,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT		device_id,
	device_type_id,
	device_name,
	site_code,
	identifying_dns_record_id,
	serial_number,
	part_number,
	host_id,
	physical_label,
	asset_tag,
	location_id,
	parent_device_id,
	description,
	device_status,
	production_state,
	operating_system_id,
	voe_id,
	ownership_status,
	auto_mgmt_protocol,
	voe_symbolic_track_id,
	is_locally_managed,
	is_monitored,
	is_virtual_device,
	should_fetch_config,
	is_baselined,
	date_in_service,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM device_v26;

INSERT INTO audit.device (
	device_id,
	device_type_id,
	device_name,
	site_code,
	identifying_dns_record_id,
	serial_number,
	part_number,
	host_id,
	physical_label,
	asset_tag,
	location_id,
	parent_device_id,
	description,
	device_status,
	service_environment,
	operating_system_id,
	voe_id,
	ownership_status,
	auto_mgmt_protocol,
	voe_symbolic_track_id,
	is_locally_managed,
	is_monitored,
	is_virtual_device,
	should_fetch_config,
	is_baselined,
	date_in_service,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT		device_id,
	device_type_id,
	device_name,
	site_code,
	identifying_dns_record_id,
	serial_number,
	part_number,
	host_id,
	physical_label,
	asset_tag,
	location_id,
	parent_device_id,
	description,
	device_status,
	production_state,
	operating_system_id,
	voe_id,
	ownership_status,
	auto_mgmt_protocol,
	voe_symbolic_track_id,
	is_locally_managed,
	is_monitored,
	is_virtual_device,
	should_fetch_config,
	is_baselined,
	date_in_service,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.device_v26;

ALTER TABLE device
	ALTER device_id
	SET DEFAULT nextval('device_device_id_seq'::regclass);
ALTER TABLE device
	ALTER is_locally_managed
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE device
	ALTER is_virtual_device
	SET DEFAULT 'N'::bpchar;
ALTER TABLE device
	ALTER should_fetch_config
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE device
	ALTER is_baselined
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device ADD CONSTRAINT pk_networkdevice PRIMARY KEY (device_id);
-- INDEXES
CREATE INDEX idx_dev_voeid ON device USING btree (voe_id);
CREATE INDEX idx_dev_ismonitored ON device USING btree (is_monitored);
CREATE INDEX idx_dev_ownershipstatus ON device USING btree (ownership_status);
CREATE INDEX idx_dev_islclymgd ON device USING btree (is_locally_managed);
CREATE INDEX ix_netdev_devtype_id ON device USING btree (device_type_id);
CREATE INDEX idx_dev_svcenv ON device USING btree (service_environment);
CREATE INDEX idx_dev_iddnsrec ON device USING btree (identifying_dns_record_id);
CREATE INDEX idx_dev_dev_status ON device USING btree (device_status);
CREATE INDEX idx_dev_locationid ON device USING btree (location_id);
CREATE INDEX idx_dev_osid ON device USING btree (operating_system_id);
CREATE INDEX xifdevice_sitecode ON device USING btree (site_code);

-- CHECK CONSTRAINTS
ALTER TABLE device ADD CONSTRAINT ckc_is_locally_manage_device
	CHECK ((is_locally_managed = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_locally_managed)::text = upper((is_locally_managed)::text)));
ALTER TABLE device ADD CONSTRAINT sys_c0069052
	CHECK (device_type_id IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT ckc_is_monitored_device
	CHECK ((is_monitored = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_monitored)::text = upper((is_monitored)::text)));
ALTER TABLE device ADD CONSTRAINT sys_c0069060
	CHECK (should_fetch_config IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069056
	CHECK (ownership_status IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069054
	CHECK (service_environment IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069057
	CHECK (is_monitored IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069055
	CHECK (operating_system_id IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT ckc_is_baselined_device
	CHECK ((is_baselined = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_baselined)::text = upper((is_baselined)::text)));
ALTER TABLE device ADD CONSTRAINT ckc_should_fetch_conf_device
	CHECK ((should_fetch_config = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((should_fetch_config)::text = upper((should_fetch_config)::text)));
ALTER TABLE device ADD CONSTRAINT sys_c0069051
	CHECK (device_id IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT ckc_is_virtual_device_device
	CHECK ((is_virtual_device = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_virtual_device)::text = upper((is_virtual_device)::text)));
ALTER TABLE device ADD CONSTRAINT sys_c0069059
	CHECK (is_virtual_device IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069061
	CHECK (is_baselined IS NOT NULL);

-- FOREIGN KEYS FROM
ALTER TABLE physical_port
	ADD CONSTRAINT fk_physport_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE device_power_interface
	ADD CONSTRAINT fk_device_device_power_supp
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE layer1_connection
	ADD CONSTRAINT fk_l1conn_ref_device
	FOREIGN KEY (tcpsrv_device_id) REFERENCES device(device_id);
ALTER TABLE device_ticket
	ADD CONSTRAINT fk_dev_tkt_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE device_collection_member
	ADD CONSTRAINT fk_devcollmem_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE snmp_commstr
	ADD CONSTRAINT fk_snmpstr_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE device_note
	ADD CONSTRAINT fk_device_note_device
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE static_route
	ADD CONSTRAINT fk_statrt_devsrc_id
	FOREIGN KEY (device_src_id) REFERENCES device(device_id);

-- FOREIGN KEYS TO
ALTER TABLE device
	ADD CONSTRAINT fk_device_dnsrecord
	FOREIGN KEY (identifying_dns_record_id) REFERENCES dns_record(dns_record_id);
ALTER TABLE device
	ADD CONSTRAINT fk_device_vownerstatus
	FOREIGN KEY (ownership_status) REFERENCES val_ownership_status(ownership_status);
ALTER TABLE device
	ADD CONSTRAINT fk_device_ref_parent_device
	FOREIGN KEY (parent_device_id) REFERENCES device(device_id);
ALTER TABLE device
	ADD CONSTRAINT fk_device_ref_voesymbtrk
	FOREIGN KEY (voe_symbolic_track_id) REFERENCES voe_symbolic_track(voe_symbolic_track_id);
ALTER TABLE device
	ADD CONSTRAINT fk_device_reference_val_devi
	FOREIGN KEY (auto_mgmt_protocol) REFERENCES val_device_auto_mgmt_protocol(auto_mgmt_protocol);
ALTER TABLE device
	ADD CONSTRAINT fk_dev_devtp_id
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);
ALTER TABLE device
	ADD CONSTRAINT fk_device_fk_dev_v_svcenv
	FOREIGN KEY (service_environment) REFERENCES val_service_environment(service_environment);
ALTER TABLE device
	ADD CONSTRAINT fk_device_site_code
	FOREIGN KEY (site_code) REFERENCES site(site_code) ON DELETE SET NULL;
ALTER TABLE device
	ADD CONSTRAINT fk_device_fk_dev_val_stat
	FOREIGN KEY (device_status) REFERENCES val_device_status(device_status);
ALTER TABLE device
	ADD CONSTRAINT fk_dev_os_id
	FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id);
ALTER TABLE device
	ADD CONSTRAINT fk_dev_location_id
	FOREIGN KEY (location_id) REFERENCES location(location_id) ON DELETE SET NULL;
ALTER TABLE device
	ADD CONSTRAINT fk_device_fk_voe
	FOREIGN KEY (voe_id) REFERENCES voe(voe_id);

-- TRIGGERS
DROP TRIGGER IF EXISTS trigger_verify_device_voe ON device;
CREATE TRIGGER trigger_verify_device_voe BEFORE INSERT OR UPDATE
        ON device FOR EACH ROW EXECUTE PROCEDURE verify_device_voe();
SELECT schema_support.rebuild_stamp_trigger('device');
SELECT schema_support.rebuild_audit_trigger('device');
alter sequence device_device_id_seq owned by device.device_id;
DROP TABLE device_v26;
DROP TABLE audit.device_v26;
GRANT INSERT,SELECT,UPDATE,DELETE ON device TO stab_role;
GRANT ALL ON device TO jazzhands;
GRANT SELECT ON device TO ro_role;
GRANT INSERT,UPDATE,DELETE ON device TO iud_role;
CREATE TABLE device_coll_account_coll
(
	device_collection_id	integer  NOT NULL,
	account_collection_id	integer  NOT NULL,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('device_coll_account_coll', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device_coll_account_coll ADD CONSTRAINT pk_device_coll_account_coll PRIMARY KEY (device_collection_id, account_collection_id);
-- INDEXES
CREATE INDEX xifk_devcolacct_col_devcolid ON device_coll_account_coll USING btree (device_collection_id);
CREATE INDEX xifk_devcolacct_col_acctcolid ON device_coll_account_coll USING btree (account_collection_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- This will get added later and mucks with rebuilding device_collection
-- ALTER TABLE device_coll_account_coll
-- 	 CONSTRAINT fk_devcolacct_col_devcolid
-- 	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);
ALTER TABLE device_coll_account_coll
	ADD CONSTRAINT fk_dev_coll_acct_coll_acctcoli
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('device_coll_account_coll');
SELECT schema_support.rebuild_audit_trigger('device_coll_account_coll');
-- DEALING WITH TABLE device_collection [183157]

-- FOREIGN KEYS FROM
alter table device_collection_hier drop constraint fk_devcollhier_pdevcol_id;
alter table klogin_mclass drop constraint fk_klgnmcl_devcoll_id;
alter table appaal_instance_device_coll drop constraint fk_devcoll_ref_appaalinstdcoll;
alter table sudo_acct_col_device_collectio drop constraint fk_sudo_ucl_fk_dev_co_device_c;
alter table device_collection_hier drop constraint fk_devcollhier_devcol_id;
alter table property drop constraint fk_property_devcolid;
alter table device_collection_member drop constraint fk_devcollmem_devc_id;
alter table device_collection_assignd_cert drop constraint fk_devcolascrt_devcolid;

-- FOREIGN KEYS TO
alter table device_collection drop constraint fk_devc_devctyp_id;
alter table device_collection drop constraint fk_dev_coll_ref_sudo_def;
alter table device_collection drop constraint ak_uq_devicecoll_name_type;
alter table device_collection drop constraint pk_networkdevicecoll;
-- INDEXES
DROP INDEX idx_devcoll_devcolltype;
-- CHECK CONSTRAINTS, etc
alter table device_collection drop constraint ckc_should_generate_s_device_c;
-- TRIGGERS, etc
drop trigger trigger_audit_device_collection on device_collection;
drop trigger trig_userlog_device_collection on device_collection;


ALTER TABLE device_collection RENAME TO device_collection_v26;
ALTER TABLE audit.device_collection RENAME TO device_collection_v26;

CREATE TABLE device_collection
(
	device_collection_id	integer  NOT NULL,
	device_collection_name	varchar(255)  NOT NULL,
	device_collection_type	varchar(50)  NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('device_collection', false);
INSERT INTO device_collection (
	device_collection_id,
	device_collection_name,
	device_collection_type,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT		device_collection_id,
	device_collection_name,
	device_collection_type,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM device_collection_v26;

INSERT INTO audit.device_collection (
	device_collection_id,
	device_collection_name,
	device_collection_type,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT		device_collection_id,
	device_collection_name,
	device_collection_type,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.device_collection_v26;

ALTER TABLE device_collection
	ALTER device_collection_id
	SET DEFAULT nextval('device_collection_device_collection_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device_collection ADD CONSTRAINT ak_uq_devicecoll_name_type UNIQUE (device_collection_name, device_collection_type);
ALTER TABLE device_collection ADD CONSTRAINT pk_networkdevicecoll PRIMARY KEY (device_collection_id);
-- INDEXES
CREATE INDEX idx_devcoll_devcolltype ON device_collection USING btree (device_collection_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
ALTER TABLE device_collection_hier
	ADD CONSTRAINT fk_devcollhier_pdevcol_id
	FOREIGN KEY (parent_device_collection_id) REFERENCES device_collection(device_collection_id);
ALTER TABLE device_coll_account_coll
	ADD CONSTRAINT fk_devcolacct_col_devcolid
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);
ALTER TABLE klogin_mclass
	ADD CONSTRAINT fk_klgnmcl_devcoll_id
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);
ALTER TABLE sudo_acct_col_device_collectio
	ADD CONSTRAINT fk_sudo_ucl_fk_dev_co_device_c
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);
ALTER TABLE appaal_instance_device_coll
	ADD CONSTRAINT fk_devcoll_ref_appaalinstdcoll
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);
ALTER TABLE device_collection_hier
	ADD CONSTRAINT fk_devcollhier_devcol_id
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);
ALTER TABLE property
	ADD CONSTRAINT fk_property_devcolid
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id) ON DELETE SET NULL;
ALTER TABLE device_collection_member
	ADD CONSTRAINT fk_devcollmem_devc_id
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);
ALTER TABLE device_collection_assignd_cert
	ADD CONSTRAINT fk_devcolascrt_devcolid
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);

-- FOREIGN KEYS TO
ALTER TABLE device_collection
	ADD CONSTRAINT fk_devc_devctyp_id
	FOREIGN KEY (device_collection_type) REFERENCES val_device_collection_type(device_collection_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('device_collection');
SELECT schema_support.rebuild_audit_trigger('device_collection');
alter table device_collection_v26 alter column device_collection_id
	drop default;
ALTER SEQUENCE device_collection_device_collection_id_seq
	OWNED BY device_collection.device_collection_id;
DROP TABLE device_collection_v26;
DROP TABLE audit.device_collection_v26;
GRANT SELECT ON device_collection TO stab_role;
GRANT ALL ON device_collection TO jazzhands;
GRANT SELECT ON device_collection TO ro_role;
GRANT INSERT,UPDATE,DELETE ON device_collection TO iud_role;
-- DEALING WITH TABLE network_service [183343]

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
alter table network_service drop constraint fk_netsvc_device_id;
alter table network_service drop constraint fk_netsvc_netsvctyp_id;
alter table network_service drop constraint fk_netsvc_netint_id;
alter table network_service drop constraint fk_netsvc_dnsid_id;
alter table network_service drop constraint fk_netsvc_nsvcstat_id;
alter table network_service drop constraint pk_service;
-- INDEXES
DROP INDEX idx_netsvc_prodstate;
DROP INDEX ix_netsvc_netintid;
DROP INDEX idx_netsvc_netsvctype;
DROP INDEX idx_netsvc_ismonitored;
DROP INDEX ix_netsvc_dnsidrecid;
DROP INDEX ix_netsvc_netdevid;
-- CHECK CONSTRAINTS, etc
alter table network_service drop constraint ckc_is_monitored_network_;
-- TRIGGERS, etc
drop trigger trig_userlog_network_service on network_service;
drop trigger trigger_audit_network_service on network_service;


ALTER TABLE network_service RENAME TO network_service_v26;
ALTER TABLE audit.network_service RENAME TO network_service_v26;

CREATE TABLE network_service
(
	network_service_id	integer  NOT NULL,
	name	varchar(255)  NULL,
	description	varchar(255)  NULL,
	network_service_type	varchar(50)  NOT NULL,
	is_monitored	character(1)  NULL,
	device_id	integer  NULL,
	network_interface_id	integer  NULL,
	dns_record_id	integer  NULL,
	service_environment	varchar(50)  NOT NULL,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('network_service', false);
INSERT INTO network_service (
	network_service_id,
	name,
	description,
	network_service_type,
	is_monitored,
	device_id,
	network_interface_id,
	dns_record_id,
	service_environment,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT		network_service_id,
	name,
	description,
	network_service_type,
	is_monitored,
	device_id,
	network_interface_id,
	dns_record_id,
	production_state,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM network_service_v26;

INSERT INTO audit.network_service (
	network_service_id,
	name,
	description,
	network_service_type,
	is_monitored,
	device_id,
	network_interface_id,
	dns_record_id,
	service_environment,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT		network_service_id,
	name,
	description,
	network_service_type,
	is_monitored,
	device_id,
	network_interface_id,
	dns_record_id,
	production_state,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.network_service_v26;

ALTER TABLE network_service
	ALTER network_service_id
	SET DEFAULT nextval('network_service_network_service_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE network_service ADD CONSTRAINT pk_service PRIMARY KEY (network_service_id);
-- INDEXES
CREATE INDEX idx_netsvc_svcenv ON network_service USING btree (service_environment);
CREATE INDEX ix_netsvc_netintid ON network_service USING btree (network_interface_id);
CREATE INDEX idx_netsvc_netsvctype ON network_service USING btree (network_service_type);
CREATE INDEX idx_netsvc_ismonitored ON network_service USING btree (is_monitored);
CREATE INDEX ix_netsvc_dnsidrecid ON network_service USING btree (dns_record_id);
CREATE INDEX ix_netsvc_netdevid ON network_service USING btree (device_id);

-- CHECK CONSTRAINTS
ALTER TABLE network_service ADD CONSTRAINT ckc_is_monitored_network_
	CHECK ((is_monitored IS NULL) OR ((is_monitored = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_monitored)::text = upper((is_monitored)::text))));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_netsvctyp_id
	FOREIGN KEY (network_service_type) REFERENCES val_network_service_type(network_service_type);
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_netint_id
	FOREIGN KEY (network_interface_id) REFERENCES network_interface(network_interface_id);
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_dnsid_id
	FOREIGN KEY (dns_record_id) REFERENCES dns_record(dns_record_id);
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_csvcenv
	FOREIGN KEY (service_environment) REFERENCES val_service_environment(service_environment);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('network_service');
SELECT schema_support.rebuild_audit_trigger('network_service');
alter table network_service_v26 alter column network_service_id
	drop default;
alter sequence network_service_network_service_id_seq
	owned by network_service.network_service_id;
DROP TABLE network_service_v26;
DROP TABLE audit.network_service_v26;
GRANT ALL ON network_service TO jazzhands;
GRANT SELECT ON network_service TO ro_role;
GRANT INSERT,UPDATE,DELETE ON network_service TO iud_role;
-- DEALING WITH TABLE property [183435]

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
alter table property drop constraint fk_property_val_prsnid;
alter table property drop constraint fk_property_person_id;
alter table property drop constraint fk_property_site_code;
alter table property drop constraint fk_property_pval_compid;
alter table property drop constraint fk_property_osid;
alter table property drop constraint fk_property_nblk_coll_id;
alter table property drop constraint fk_property_acct_col;
alter table property drop constraint fk_property_pval_tokcolid;
alter table property drop constraint fk_property_pval_dnsdomid;
alter table property drop constraint fk_property_pv_nblkcol_id;
alter table property drop constraint fk_property_nmtyp;
alter table property drop constraint fk_property_pval_pwdtyp;
alter table property drop constraint fk_property_acctid;
alter table property drop constraint fk_property_compid;
alter table property drop constraint fk_property_dnsdomid;
alter table property drop constraint fk_property_pval_swpkgid;
alter table property drop constraint fk_property_devcolid;
alter table property drop constraint fk_property_prodstate;
alter table property drop constraint fk_property_pval_acct_colid;
alter table property drop constraint pk_property;
-- INDEXES
DROP INDEX xifprop_acctcol_id;
DROP INDEX xifprop_account_id;
DROP INDEX xifprop_dnsdomid;
DROP INDEX xifprop_pval_pwdtyp;
DROP INDEX xifprop_pval_tokcolid;
DROP INDEX xifprop_nmtyp;
DROP INDEX xif17property;
DROP INDEX xifprop_site_code;
DROP INDEX xifprop_pval_dnsdomid;
DROP INDEX xif18property;
DROP INDEX xifprop_compid;
DROP INDEX xif19property;
DROP INDEX xif20property;
DROP INDEX xifprop_osid;
DROP INDEX xifprop_pval_acct_colid;
DROP INDEX xifprop_pval_swpkgid;
DROP INDEX xifprop_prodstate;
DROP INDEX xifprop_devcolid;
DROP INDEX xifprop_pval_compid;
-- CHECK CONSTRAINTS, etc
alter table property drop constraint ckc_prop_isenbld;
-- TRIGGERS, etc
drop trigger trigger_validate_property on property;
drop trigger trigger_audit_property on property;
drop trigger trig_userlog_property on property;


ALTER TABLE property RENAME TO property_v26;
ALTER TABLE audit.property RENAME TO property_v26;

CREATE TABLE property
(
	property_id	integer  NOT NULL,
	account_collection_id	integer  NULL,
	account_id	integer  NULL,
	company_id	integer  NULL,
	device_collection_id	integer  NULL,
	dns_domain_id	integer  NULL,
	netblock_collection_id	integer  NULL,
	operating_system_id	integer  NULL,
	person_id	integer  NULL,
	service_environment	varchar(50)  NULL,
	site_code	varchar(50)  NULL,
	property_name	varchar(255)  NOT NULL,
	property_type	varchar(50)  NOT NULL,
	property_value	varchar(1024)  NULL,
	property_value_timestamp	timestamp without time zone  NULL,
	property_value_company_id	integer  NULL,
	property_value_account_coll_id	integer  NULL,
	property_value_dns_domain_id	integer  NULL,
	property_value_nblk_coll_id	integer  NULL,
	property_value_password_type	varchar(50)  NULL,
	property_value_person_id	integer  NULL,
	property_value_sw_package_id	integer  NULL,
	property_value_token_col_id	integer  NULL,
	start_date	timestamp without time zone  NULL,
	finish_date	timestamp without time zone  NULL,
	is_enabled	character(1)  NOT NULL,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('property', false);
INSERT INTO property (
	property_id,
	account_collection_id,
	account_id,
	company_id,
	device_collection_id,
	dns_domain_id,
	netblock_collection_id,
	operating_system_id,
	person_id,
	service_environment,
	site_code,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_dns_domain_id,
	property_value_nblk_coll_id,
	property_value_password_type,
	property_value_person_id,
	property_value_sw_package_id,
	property_value_token_col_id,
	start_date,
	finish_date,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT		property_id,
	account_collection_id,
	account_id,
	company_id,
	device_collection_id,
	dns_domain_id,
	netblock_collection_id,
	operating_system_id,
	person_id,
	production_state,
	site_code,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_dns_domain_id,
	property_value_nblk_coll_id,
	property_value_password_type,
	property_value_person_id,
	property_value_sw_package_id,
	property_value_token_col_id,
	start_date,
	finish_date,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM property_v26;

INSERT INTO audit.property (
	property_id,
	account_collection_id,
	account_id,
	company_id,
	device_collection_id,
	dns_domain_id,
	netblock_collection_id,
	operating_system_id,
	person_id,
	service_environment,
	site_code,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_dns_domain_id,
	property_value_nblk_coll_id,
	property_value_password_type,
	property_value_person_id,
	property_value_sw_package_id,
	property_value_token_col_id,
	start_date,
	finish_date,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT		property_id,
	account_collection_id,
	account_id,
	company_id,
	device_collection_id,
	dns_domain_id,
	netblock_collection_id,
	operating_system_id,
	person_id,
	production_state,
	site_code,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_dns_domain_id,
	property_value_nblk_coll_id,
	property_value_password_type,
	property_value_person_id,
	property_value_sw_package_id,
	property_value_token_col_id,
	start_date,
	finish_date,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.property_v26;

ALTER TABLE property
	ALTER property_id
	SET DEFAULT nextval('property_property_id_seq'::regclass);
ALTER TABLE property
	ALTER is_enabled
	SET DEFAULT 'Y'::bpchar;

COMMENT ON TABLE PROPERTY IS 'generic property instance that describes system wide properties, as well as properties for various values of columns used throughout the db for configuration, acls, defaults, etc; also used to relate some tables';

COMMENT ON COLUMN PROPERTY.PROPERTY_ID IS 'primary key for table to uniquely identify rows.';

COMMENT ON COLUMN PROPERTY.COMPANY_ID IS 'company that properties may be set on.';

COMMENT ON COLUMN PROPERTY.DEVICE_COLLECTION_ID IS 'device collection that properties may be set on.';

COMMENT ON COLUMN PROPERTY.DNS_DOMAIN_ID IS 'dns domain that properties may be set on.';

COMMENT ON COLUMN PROPERTY.ACCOUNT_ID IS 'system user that properties may be set on.';

COMMENT ON COLUMN PROPERTY.ACCOUNT_COLLECTION_ID IS 'user collection 
that properties may be set on.';

COMMENT ON COLUMN PROPERTY.SITE_CODE IS 'site_code that properties may be set on';

COMMENT ON COLUMN PROPERTY.PROPERTY_NAME IS 'textual name of a property';

COMMENT ON COLUMN PROPERTY.PROPERTY_TYPE IS 'textual type of a department';

COMMENT ON COLUMN PROPERTY.PROPERTY_VALUE IS 'general purpose column for value of property not defined by other types.  This may be enforced by fk (trigger) if val_property.property_data_type is list (fk is to val_property_value).';

COMMENT ON COLUMN PROPERTY.PROPERTY_VALUE_TIMESTAMP IS 'property is defined as a timestamp';

COMMENT ON COLUMN PROPERTY.START_DATE IS 'date/time that the assignment takes effect';

COMMENT ON COLUMN PROPERTY.FINISH_DATE IS 'date/time that the assignment ceases taking effect';

COMMENT ON COLUMN PROPERTY.IS_ENABLED IS 'indiciates if the property is temporarily disabled or not.';

COMMENT ON COLUMN PROPERTY.OPERATING_SYSTEM_ID IS 'operating system that properties may be set on.';


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE property ADD CONSTRAINT pk_property PRIMARY KEY (property_id);
-- INDEXES
CREATE INDEX xifprop_acctcol_id ON property USING btree (account_collection_id);
CREATE INDEX xifprop_account_id ON property USING btree (account_id);
CREATE INDEX xifprop_dnsdomid ON property USING btree (dns_domain_id);
CREATE INDEX xifprop_pval_pwdtyp ON property USING btree (property_value_password_type);
CREATE INDEX xifprop_pval_tokcolid ON property USING btree (property_value_token_col_id);
CREATE INDEX xifprop_nmtyp ON property USING btree (property_name, property_type);
CREATE INDEX xif17property ON property USING btree (property_value_person_id);
CREATE INDEX xifprop_site_code ON property USING btree (site_code);
CREATE INDEX xifprop_pval_dnsdomid ON property USING btree (property_value_dns_domain_id);
CREATE INDEX xif18property ON property USING btree (person_id);
CREATE INDEX xifprop_compid ON property USING btree (company_id);
CREATE INDEX xif19property ON property USING btree (property_value_nblk_coll_id);
CREATE INDEX xif20property ON property USING btree (netblock_collection_id);
CREATE INDEX xifprop_osid ON property USING btree (operating_system_id);
CREATE INDEX xifprop_pval_acct_colid ON property USING btree (property_value_account_coll_id);
CREATE INDEX xifprop_pval_swpkgid ON property USING btree (property_value_sw_package_id);
CREATE INDEX xifprop_devcolid ON property USING btree (device_collection_id);
CREATE INDEX xifprop_svcenv ON property USING btree (service_environment);
CREATE INDEX xifprop_pval_compid ON property USING btree (property_value_company_id);

-- CHECK CONSTRAINTS
ALTER TABLE property ADD CONSTRAINT ckc_prop_isenbld
	CHECK (is_enabled = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE property
	ADD CONSTRAINT fk_property_val_prsnid
	FOREIGN KEY (property_value_person_id) REFERENCES person(person_id) ON DELETE SET NULL;
ALTER TABLE property
	ADD CONSTRAINT fk_property_person_id
	FOREIGN KEY (person_id) REFERENCES person(person_id) ON DELETE SET NULL;
ALTER TABLE property
	ADD CONSTRAINT fk_property_site_code
	FOREIGN KEY (site_code) REFERENCES site(site_code) ON DELETE SET NULL;
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_compid
	FOREIGN KEY (property_value_company_id) REFERENCES company(company_id) ON DELETE SET NULL;
ALTER TABLE property
	ADD CONSTRAINT fk_property_osid
	FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id) ON DELETE SET NULL;
ALTER TABLE property
	ADD CONSTRAINT fk_property_svcenv
	FOREIGN KEY (service_environment) REFERENCES val_service_environment(service_environment) ON DELETE SET NULL;
ALTER TABLE property
	ADD CONSTRAINT fk_property_nblk_coll_id
	FOREIGN KEY (netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id) ON DELETE SET NULL;
ALTER TABLE property
	ADD CONSTRAINT fk_property_acct_col
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id) ON DELETE SET NULL;
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_tokcolid
	FOREIGN KEY (property_value_token_col_id) REFERENCES token_collection(token_collection_id) ON DELETE SET NULL;
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_dnsdomid
	FOREIGN KEY (property_value_dns_domain_id) REFERENCES dns_domain(dns_domain_id) ON DELETE SET NULL;
ALTER TABLE property
	ADD CONSTRAINT fk_property_pv_nblkcol_id
	FOREIGN KEY (property_value_nblk_coll_id) REFERENCES netblock_collection(netblock_collection_id) ON DELETE SET NULL;
ALTER TABLE property
	ADD CONSTRAINT fk_property_nmtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_pwdtyp
	FOREIGN KEY (property_value_password_type) REFERENCES val_password_type(password_type) ON DELETE SET NULL;
ALTER TABLE property
	ADD CONSTRAINT fk_property_acctid
	FOREIGN KEY (account_id) REFERENCES account(account_id) ON DELETE SET NULL;
ALTER TABLE property
	ADD CONSTRAINT fk_property_compid
	FOREIGN KEY (company_id) REFERENCES company(company_id);
ALTER TABLE property
	ADD CONSTRAINT fk_property_dnsdomid
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id) ON DELETE SET NULL;
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_swpkgid
	FOREIGN KEY (property_value_sw_package_id) REFERENCES sw_package(sw_package_id) ON DELETE SET NULL;
ALTER TABLE property
	ADD CONSTRAINT fk_property_devcolid
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id) ON DELETE SET NULL;
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_acct_colid
	FOREIGN KEY (property_value_account_coll_id) REFERENCES account_collection(account_collection_id) ON DELETE SET NULL;

-- TRIGGERS
DROP TRIGGER IF EXISTS trigger_validate_property ON Property;

CREATE OR REPLACE FUNCTION validate_property() RETURNS TRIGGER AS $$
DECLARE
	tally			integer;
	v_prop			VAL_Property%ROWTYPE;
	v_proptype		VAL_Property_Type%ROWTYPE;
	v_account_collection	account_collection%ROWTYPE;
	v_netblock_collection	netblock_collection%ROWTYPE;
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
			((service_environment IS NULL AND NEW.service_environment IS NULL) OR
				(service_environment = NEW.service_environment)) AND
			((Site_Code IS NULL AND NEW.Site_Code IS NULL) OR
				(Site_Code = NEW.Site_Code)) AND
			((Account_Id IS NULL AND NEW.Account_Id IS NULL) OR
				(Account_Id = NEW.Account_Id)) AND
			((account_collection_Id IS NULL AND NEW.account_collection_Id IS NULL) OR
				(account_collection_Id = NEW.account_collection_Id)) AND
			((netblock_collection_Id IS NULL AND NEW.netblock_collection_Id IS NULL) OR
				(netblock_collection_Id = NEW.netblock_collection_Id)) AND
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
			((service_environment IS NULL AND NEW.service_environment IS NULL) OR
				(service_environment = NEW.service_environment)) AND
			((Site_Code IS NULL AND NEW.Site_Code IS NULL) OR
				(Site_Code = NEW.Site_Code)) AND
			((Person_id IS NULL AND NEW.Person_id IS NULL) OR
				(Person_Id = NEW.Person_Id)) AND
			((Account_Id IS NULL AND NEW.Account_Id IS NULL) OR
				(Account_Id = NEW.Account_Id)) AND
			((account_collection_Id IS NULL AND NEW.account_collection_Id IS NULL) OR
				(account_collection_Id = NEW.account_collection_Id)) AND
			((netblock_collection_Id IS NULL AND NEW.netblock_collection_Id IS NULL) OR
				(netblock_collection_Id = NEW.netblock_collection_Id));

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
		IF v_prop.Property_Data_Type = 'account_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be account_collection_id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_nblk_Coll_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'nblk_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be nblk_collection_id' USING
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
		IF v_prop.prop_val_acct_coll_type_rstrct IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_account_collection FROM account_collection WHERE
					account_collection_Id = NEW.Property_Value_Account_Coll_Id;
				IF v_account_collection.account_collection_Type != v_prop.prop_val_acct_coll_type_rstrct
				THEN
					RAISE 'Property_Value_Account_Coll_Id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the RHS contains a netblock_collection_ID, check to see if it must be a
	-- specific type and verify that if so
	IF NEW.Property_Value_nblk_Coll_Id IS NOT NULL THEN
		IF v_prop.prop_val_acct_coll_type_rstrct IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_netblock_collection FROM netblock_collection WHERE
					netblock_collection_Id = NEW.Property_Value_nblk_Coll_Id;
				IF v_netblock_collection.netblock_collection_Type != v_prop.prop_val_acct_coll_type_rstrct
				THEN
					RAISE 'Property_Value_nblk_Coll_Id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
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

	IF v_prop.Permit_service_environment = 'REQUIRED' THEN
			IF NEW.service_environment IS NULL THEN
				RAISE 'service_environment is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_service_environment = 'PROHIBITED' THEN
			IF NEW.service_environment IS NOT NULL THEN
				RAISE 'service_environment is prohibited.'
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

	IF v_prop.Permit_netblock_collection_Id = 'REQUIRED' THEN
			IF NEW.netblock_collection_Id IS NULL THEN
				RAISE 'netblock_collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_netblock_collection_Id = 'PROHIBITED' THEN
			IF NEW.netblock_collection_Id IS NOT NULL THEN
				RAISE 'netblock_collection_Id is prohibited.'
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_property ON Property;
CREATE TRIGGER trigger_validate_property BEFORE INSERT OR UPDATE 
	ON Property FOR EACH ROW EXECUTE PROCEDURE validate_property();


SELECT schema_support.rebuild_stamp_trigger('property');
SELECT schema_support.rebuild_audit_trigger('property');
alter table property_v26 alter column property_id drop default;
alter SEQUENCE property_property_id_seq
	OWNED BY property.property_id;
DROP TABLE property_v26;
DROP TABLE audit.property_v26;
GRANT ALL ON property TO jazzhands;
GRANT SELECT ON property TO ap_directory;
GRANT SELECT ON property TO ro_role;
GRANT INSERT,UPDATE,DELETE ON property TO iud_role;
GRANT SELECT ON property TO ap_hrfeed;
-- DEALING WITH TABLE sudo_default [183499]

-- FOREIGN KEYS FROM
-- already gone by now.
-- alter table device_collection drop constraint fk_dev_coll_ref_sudo_def;

-- FOREIGN KEYS TO
alter table sudo_default drop constraint pk_sudo_default;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
drop trigger trigger_audit_sudo_default on sudo_default;
drop trigger trig_userlog_sudo_default on sudo_default;


ALTER TABLE sudo_default RENAME TO sudo_default_v26;
ALTER TABLE audit.sudo_default RENAME TO sudo_default_v26;

DROP FUNCTION perform_audit_sudo_default();

-- table is gone
DROP TABLE sudo_default_v26;
DROP TABLE audit.sudo_default_v26;

DROP SEQUENCE IF EXISTS sudo_default_seq;
DROP SEQUENCE IF EXISTS audit.sudo_default_seq;

-- DEALING WITH TABLE sw_package_release [183516]

-- FOREIGN KEYS FROM
alter table voe_sw_package drop constraint fk_voe_swpkg_ref_swpkg_rel;
alter table sw_package_relation drop constraint fk_swpkgrltn_ref_swpkgrel;

-- FOREIGN KEYS TO
alter table sw_package_release drop constraint fk_sw_package_type;
alter table sw_package_release drop constraint fk_sw_pkg_rel_ref_vswpkgfmt;
alter table sw_package_release drop constraint fk_sw_pkg_rel_ref_vdevarch;
alter table sw_package_release drop constraint fk_sw_pkg_rel_ref_vprodstate;
alter table sw_package_release drop constraint fk_sw_pkg_rel_ref_sw_pkg_rep;
alter table sw_package_release drop constraint fk_sw_pkg_rel_ref_sys_user;
alter table sw_package_release drop constraint fk_sw_pkg_ref_sw_pkg_rel;
alter table sw_package_release drop constraint pk_sw_package_release;
alter table sw_package_release drop constraint ak_uq_sw_pkg_rel_comb_sw_packa;
-- INDEXES
DROP INDEX idx_sw_pkg_rel_sw_pkg_id;
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
drop trigger trigger_audit_sw_package_release on sw_package_release;
drop trigger trig_userlog_sw_package_release on sw_package_release;


ALTER TABLE sw_package_release RENAME TO sw_package_release_v26;
ALTER TABLE audit.sw_package_release RENAME TO sw_package_release_v26;

CREATE TABLE sw_package_release
(
	sw_package_release_id	integer  NOT NULL,
	sw_package_id	integer  NOT NULL,
	sw_package_version	varchar(50)  NOT NULL,
	sw_package_format	varchar(50)  NOT NULL,
	sw_package_type	varchar(50)  NULL,
	creation_account_id	integer  NOT NULL,
	processor_architecture	varchar(50)  NOT NULL,
	service_environment	varchar(50)  NOT NULL,
	sw_package_repository_id	integer  NOT NULL,
	uploading_principal	varchar(255)  NULL,
	package_size	integer  NULL,
	installed_package_size_kb	integer  NULL,
	pathname	varchar(1024)  NULL,
	md5sum	varchar(255)  NULL,
	description	varchar(255)  NULL,
	instantiation_date	timestamp with time zone  NULL,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('sw_package_release', false);
INSERT INTO sw_package_release (
	sw_package_release_id,
	sw_package_id,
	sw_package_version,
	sw_package_format,
	sw_package_type,
	creation_account_id,
	processor_architecture,
	service_environment,
	sw_package_repository_id,
	uploading_principal,
	package_size,
	installed_package_size_kb,
	pathname,
	md5sum,
	description,
	instantiation_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT		sw_package_release_id,
	sw_package_id,
	sw_package_version,
	sw_package_format,
	sw_package_type,
	creation_account_id,
	processor_architecture,
	production_state,
	sw_package_repository_id,
	uploading_principal,
	package_size,
	installed_package_size_kb,
	pathname,
	md5sum,
	description,
	instantiation_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM sw_package_release_v26;

INSERT INTO audit.sw_package_release (
	sw_package_release_id,
	sw_package_id,
	sw_package_version,
	sw_package_format,
	sw_package_type,
	creation_account_id,
	processor_architecture,
	service_environment,
	sw_package_repository_id,
	uploading_principal,
	package_size,
	installed_package_size_kb,
	pathname,
	md5sum,
	description,
	instantiation_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT		sw_package_release_id,
	sw_package_id,
	sw_package_version,
	sw_package_format,
	sw_package_type,
	creation_account_id,
	processor_architecture,
	production_state,
	sw_package_repository_id,
	uploading_principal,
	package_size,
	installed_package_size_kb,
	pathname,
	md5sum,
	description,
	instantiation_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.sw_package_release_v26;

ALTER TABLE sw_package_release
	ALTER sw_package_release_id
	SET DEFAULT nextval('sw_package_release_sw_package_release_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE sw_package_release ADD CONSTRAINT pk_sw_package_release PRIMARY KEY (sw_package_release_id);
ALTER TABLE sw_package_release ADD CONSTRAINT ak_uq_sw_pkg_rel_comb_sw_packa UNIQUE (sw_package_id, sw_package_version, processor_architecture, sw_package_repository_id);
-- INDEXES
CREATE INDEX idx_sw_pkg_rel_sw_pkg_id ON sw_package_release USING btree (sw_package_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
ALTER TABLE voe_sw_package
	ADD CONSTRAINT fk_voe_swpkg_ref_swpkg_rel
	FOREIGN KEY (sw_package_release_id) REFERENCES sw_package_release(sw_package_release_id);
ALTER TABLE sw_package_relation
	ADD CONSTRAINT fk_swpkgrltn_ref_swpkgrel
	FOREIGN KEY (sw_package_release_id) REFERENCES sw_package_release(sw_package_release_id);

-- FOREIGN KEYS TO
ALTER TABLE sw_package_release
	ADD CONSTRAINT fk_sw_package_type
	FOREIGN KEY (sw_package_type) REFERENCES val_sw_package_type(sw_package_type);
ALTER TABLE sw_package_release
	ADD CONSTRAINT fk_sw_pkg_rel_ref_vswpkgfmt
	FOREIGN KEY (sw_package_format) REFERENCES val_sw_package_format(sw_package_format);
ALTER TABLE sw_package_release
	ADD CONSTRAINT fk_sw_pkg_rel_ref_vdevarch
	FOREIGN KEY (processor_architecture) REFERENCES val_processor_architecture(processor_architecture);
ALTER TABLE sw_package_release
	ADD CONSTRAINT fk_sw_pkg_rel_ref_sw_pkg_rep
	FOREIGN KEY (sw_package_repository_id) REFERENCES sw_package_repository(sw_package_repository_id);
ALTER TABLE sw_package_release
	ADD CONSTRAINT fk_sw_pkg_rel_ref_vsvcenv
	FOREIGN KEY (service_environment) REFERENCES val_service_environment(service_environment);
ALTER TABLE sw_package_release
	ADD CONSTRAINT fk_sw_pkg_rel_ref_sys_user
	FOREIGN KEY (creation_account_id) REFERENCES account(account_id);
ALTER TABLE sw_package_release
	ADD CONSTRAINT fk_sw_pkg_ref_sw_pkg_rel
	FOREIGN KEY (sw_package_id) REFERENCES sw_package(sw_package_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('sw_package_release');
SELECT schema_support.rebuild_audit_trigger('sw_package_release');
alter table sw_package_release_v26 alter column sw_package_release_id
	drop default;
ALTER SEQUENCE sw_package_release_sw_package_release_id_seq
	OWNED BY sw_package_release.sw_package_release_id;
DROP TABLE sw_package_release_v26;
DROP TABLE audit.sw_package_release_v26;
GRANT SELECT ON sw_package_release TO stab_role;
GRANT ALL ON sw_package_release TO jazzhands;
GRANT SELECT ON sw_package_release TO ro_role;
GRANT INSERT,UPDATE,DELETE ON sw_package_release TO iud_role;
-- DEALING WITH TABLE unix_group [183555]

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
alter table unix_group drop constraint fk_unxgrp_uclsid;
alter table unix_group drop constraint ak_unix_group_unix_group_name;
alter table unix_group drop constraint ak_unix_group_unix_gid;
alter table unix_group drop constraint pk_unix_group;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
drop trigger trigger_audit_unix_group on unix_group;
drop trigger trig_userlog_unix_group on unix_group;


ALTER TABLE unix_group RENAME TO unix_group_v26;
ALTER TABLE audit.unix_group RENAME TO unix_group_v26;

CREATE TABLE unix_group
(
	account_collection_id	integer  NOT NULL,
	unix_gid	integer  NOT NULL,
	group_password	varchar(20)  NULL,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('unix_group', false);
INSERT INTO unix_group (
	account_collection_id,
	unix_gid,
	group_password,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT		account_collection_id,
	unix_gid,
	group_password,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM unix_group_v26;

INSERT INTO audit.unix_group (
	account_collection_id,
	unix_gid,
	group_password,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT		account_collection_id,
	unix_gid,
	group_password,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.unix_group_v26;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE unix_group ADD CONSTRAINT ak_unix_group_unix_gid UNIQUE (unix_gid);
ALTER TABLE unix_group ADD CONSTRAINT pk_unix_group PRIMARY KEY (account_collection_id);
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE unix_group
	ADD CONSTRAINT fk_unxgrp_uclsid
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('unix_group');
SELECT schema_support.rebuild_audit_trigger('unix_group');
DROP TABLE unix_group_v26;
DROP TABLE audit.unix_group_v26;
GRANT ALL ON unix_group TO jazzhands;
GRANT SELECT ON unix_group TO ro_role;
GRANT INSERT,UPDATE,DELETE ON unix_group TO iud_role;
-- DEALING WITH TABLE val_property [183895]

-- FOREIGN KEYS FROM
alter table val_property_value drop constraint fk_valproval_namtyp;
alter table property drop constraint fk_property_nmtyp;

-- FOREIGN KEYS TO
alter table val_property drop constraint fk_valprop_pv_actyp_rst;
alter table val_property drop constraint r_425;
alter table val_property drop constraint fk_valprop_proptyp;
alter table val_property drop constraint fk_valprop_propdttyp;
alter table val_property drop constraint pk_val_property;
-- INDEXES
DROP INDEX xif3val_property;
DROP INDEX xif2val_property;
DROP INDEX xif1val_property;
DROP INDEX xif4val_property;
-- CHECK CONSTRAINTS, etc
alter table val_property drop constraint ckc_val_prop_ismulti;
alter table val_property drop constraint ckc_val_prop_cmp_id;
alter table val_property drop constraint check_prp_prmt_354296970;
alter table val_property drop constraint check_prp_prmt_606225804;
alter table val_property drop constraint ckc_val_prop_pacct_id;
alter table val_property drop constraint ckc_val_prop_osid;
alter table val_property drop constraint ckc_val_prop_pucls_id;
alter table val_property drop constraint ckc_val_prop_pdevcol_id;
alter table val_property drop constraint ckc_val_prop_pdnsdomid;
alter table val_property drop constraint ckc_val_prop_sitec;
alter table val_property drop constraint ckc_val_prop_prodstate;
-- TRIGGERS, etc
drop trigger trigger_audit_val_property on val_property;
drop trigger trig_userlog_val_property on val_property;


ALTER TABLE val_property RENAME TO val_property_v26;
ALTER TABLE audit.val_property RENAME TO val_property_v26;

CREATE TABLE val_property
(
	property_name	varchar(255)  NOT NULL,
	property_type	varchar(50)  NOT NULL,
	description	varchar(255)  NULL,
	is_multivalue	character(1)  NOT NULL,
	prop_val_acct_coll_type_rstrct	varchar(50)  NULL,
	prop_val_nblk_coll_type_rstrct	varchar(50)  NULL,
	property_data_type	varchar(50)  NOT NULL,
	permit_account_id	character(10)  NOT NULL,
	permit_account_collection_id	character(10)  NOT NULL,
	permit_company_id	character(10)  NOT NULL,
	permit_device_collection_id	character(10)  NOT NULL,
	permit_dns_domain_id	character(10)  NOT NULL,
	permit_netblock_collection_id	character(10)  NOT NULL,
	permit_operating_system_id	character(10)  NOT NULL,
	permit_person_id	character(10)  NOT NULL,
	permit_service_environment	character(10)  NOT NULL,
	permit_site_code	character(10)  NOT NULL,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('val_property', false);
INSERT INTO val_property (
	property_name,
	property_type,
	description,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_id,
	permit_account_collection_id,
	permit_company_id,
	permit_device_collection_id,
	permit_dns_domain_id,
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_person_id,
	permit_service_environment,
	permit_site_code,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT		property_name,
	property_type,
	description,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_id,
	permit_account_collection_id,
	permit_company_id,
	permit_device_collection_id,
	permit_dns_domain_id,
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_person_id,
	permit_production_state,
	permit_site_code,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_property_v26;

INSERT INTO audit.val_property (
	property_name,
	property_type,
	description,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_id,
	permit_account_collection_id,
	permit_company_id,
	permit_device_collection_id,
	permit_dns_domain_id,
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_person_id,
	permit_service_environment,
	permit_site_code,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT		property_name,
	property_type,
	description,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_id,
	permit_account_collection_id,
	permit_company_id,
	permit_device_collection_id,
	permit_dns_domain_id,
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_person_id,
	permit_production_state,
	permit_site_code,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_property_v26;

COMMENT ON TABLE VAL_PROPERTY IS 'valid values and attributes for (name,type) pairs in the property table';

COMMENT ON COLUMN VAL_PROPERTY.PROPERTY_NAME IS 'property name for validation purposes';

COMMENT ON COLUMN VAL_PROPERTY.PROPERTY_TYPE IS 'property type for validation purposes';

COMMENT ON COLUMN VAL_PROPERTY.IS_MULTIVALUE IS 'If N, acts like an ak on property.(*_id,property_type)';

COMMENT ON COLUMN VAL_PROPERTY.PROPERTY_DATA_TYPE IS 'which of the property_table_* columns should be used for this value';

COMMENT ON COLUMN VAL_PROPERTY.PERMIT_COMPANY_ID IS 'defines how company id should be used in the property for this (name,type)';

COMMENT ON COLUMN VAL_PROPERTY.PERMIT_DEVICE_COLLECTION_ID IS 'defines how company id should be used in the property for this (name,type)';

COMMENT ON COLUMN VAL_PROPERTY.PERMIT_DNS_DOMAIN_ID IS 'defines how company id should be used in the property for this (name,type)';

COMMENT ON COLUMN VAL_PROPERTY.PERMIT_ACCOUNT_ID IS 'defines how company id should be used in the property for this (name,type)';

COMMENT ON COLUMN VAL_PROPERTY.PERMIT_ACCOUNT_COLLECTION_ID IS 'defines how company id should be used in the property for this (name,type)';


ALTER TABLE val_property
	ALTER permit_account_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_account_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_company_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_device_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_dns_domain_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_netblock_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_operating_system_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_person_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_service_environment
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_site_code
	SET DEFAULT 'PROHIBITED'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_property ADD CONSTRAINT pk_val_property PRIMARY KEY (property_name, property_type);
-- INDEXES
CREATE INDEX xif3val_property ON val_property USING btree (prop_val_acct_coll_type_rstrct);
CREATE INDEX xif2val_property ON val_property USING btree (property_type);
CREATE INDEX xif1val_property ON val_property USING btree (property_data_type);
CREATE INDEX xif4val_property ON val_property USING btree (prop_val_nblk_coll_type_rstrct);

-- CHECK CONSTRAINTS
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_cmp_id
	CHECK (permit_company_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_ismulti
	CHECK (is_multivalue = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_354296970
	CHECK (permit_netblock_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_606225804
	CHECK (permit_person_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pacct_id
	CHECK (permit_account_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_osid
	CHECK (permit_operating_system_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pucls_id
	CHECK (permit_account_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pdevcol_id
	CHECK (permit_device_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pdnsdomid
	CHECK (permit_dns_domain_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_sitec
	CHECK (permit_site_code = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_prodstate
	CHECK (permit_service_environment = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));

-- FOREIGN KEYS FROM
ALTER TABLE val_property_value
	ADD CONSTRAINT fk_valproval_namtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);
ALTER TABLE property
	ADD CONSTRAINT fk_property_nmtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);

-- FOREIGN KEYS TO
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_pv_actyp_rst
	FOREIGN KEY (prop_val_acct_coll_type_rstrct) REFERENCES val_account_collection_type(account_collection_type) ON DELETE SET NULL;
ALTER TABLE val_property
	ADD CONSTRAINT r_425
	FOREIGN KEY (prop_val_nblk_coll_type_rstrct) REFERENCES val_netblock_collection_type(netblock_collection_type) ON DELETE SET NULL;
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_proptyp
	FOREIGN KEY (property_type) REFERENCES val_property_type(property_type);
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_propdttyp
	FOREIGN KEY (property_data_type) REFERENCES val_property_data_type(property_data_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('val_property');
SELECT schema_support.rebuild_audit_trigger('val_property');
DROP TABLE val_property_v26;
DROP TABLE audit.val_property_v26;
GRANT ALL ON val_property TO jazzhands;
GRANT SELECT ON val_property TO ro_role;
GRANT INSERT,UPDATE,DELETE ON val_property TO iud_role;
GRANT SELECT ON val_property TO ap_hrfeed;
-- DEALING WITH TABLE voe [184006]

-- FOREIGN KEYS FROM
alter table voe_relation drop constraint fk_voe_ref_voe_rel_voe;
alter table voe_relation drop constraint fk_voe_ref_voe_rel_rltdvoe;
alter table voe_symbolic_track drop constraint fk_voe_symbtrk_ref_pendvoe;
alter table voe_symbolic_track drop constraint fk_voe_symbtrk_ref_actvvoe;
alter table voe_sw_package drop constraint fk_voe_swpkg_ref_voe;
alter table device drop constraint fk_device_fk_voe;

-- FOREIGN KEYS TO
alter table voe drop constraint fk_voe_ref_vvoestate;
alter table voe drop constraint fk_voe_ref_v_prod_state;
alter table voe drop constraint pk_vonage_operating_env;
alter table voe drop constraint ak_uq_voe_voe_name_sw_vonage_o;
-- INDEXES
-- CHECK CONSTRAINTS, etc
alter table voe drop constraint sys_c0033904;
alter table voe drop constraint sys_c0033905;
alter table voe drop constraint sys_c0033906;
-- TRIGGERS, etc
drop trigger trigger_audit_voe on voe;
drop trigger trig_userlog_voe on voe;


ALTER TABLE voe RENAME TO voe_v26;
ALTER TABLE audit.voe RENAME TO voe_v26;

CREATE TABLE voe
(
	voe_id	integer  NOT NULL,
	voe_name	varchar(50)  NOT NULL,
	voe_state	varchar(50)  NOT NULL,
	sw_package_repository_id	integer  NOT NULL,
	service_environment	varchar(50)  NOT NULL,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('voe', false);
INSERT INTO voe (
	voe_id,
	voe_name,
	voe_state,
	sw_package_repository_id,
	service_environment,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT		voe_id,
	voe_name,
	voe_state,
	sw_package_repository_id,
	production_state,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM voe_v26;

INSERT INTO audit.voe (
	voe_id,
	voe_name,
	voe_state,
	sw_package_repository_id,
	service_environment,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT		voe_id,
	voe_name,
	voe_state,
	sw_package_repository_id,
	production_state,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.voe_v26;

ALTER TABLE voe
	ALTER voe_id
	SET DEFAULT nextval('voe_voe_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE voe ADD CONSTRAINT pk_vonage_operating_env PRIMARY KEY (voe_id);
ALTER TABLE voe ADD CONSTRAINT ak_uq_voe_voe_name_sw_vonage_o UNIQUE (voe_name, sw_package_repository_id);
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE voe ADD CONSTRAINT sys_c0033904
	CHECK (voe_id IS NOT NULL);
ALTER TABLE voe ADD CONSTRAINT sys_c0033905
	CHECK (voe_name IS NOT NULL);
ALTER TABLE voe ADD CONSTRAINT sys_c0033906
	CHECK (voe_state IS NOT NULL);

-- FOREIGN KEYS FROM
ALTER TABLE voe_relation
	ADD CONSTRAINT fk_voe_ref_voe_rel_voe
	FOREIGN KEY (voe_id) REFERENCES voe(voe_id);
ALTER TABLE voe_relation
	ADD CONSTRAINT fk_voe_ref_voe_rel_rltdvoe
	FOREIGN KEY (related_voe_id) REFERENCES voe(voe_id);
ALTER TABLE voe_symbolic_track
	ADD CONSTRAINT fk_voe_symbtrk_ref_pendvoe
	FOREIGN KEY (pending_voe_id) REFERENCES voe(voe_id);
ALTER TABLE voe_symbolic_track
	ADD CONSTRAINT fk_voe_symbtrk_ref_actvvoe
	FOREIGN KEY (active_voe_id) REFERENCES voe(voe_id);
ALTER TABLE voe_sw_package
	ADD CONSTRAINT fk_voe_swpkg_ref_voe
	FOREIGN KEY (voe_id) REFERENCES voe(voe_id);
ALTER TABLE device
	ADD CONSTRAINT fk_device_fk_voe
	FOREIGN KEY (voe_id) REFERENCES voe(voe_id);

-- FOREIGN KEYS TO
ALTER TABLE voe
	ADD CONSTRAINT fk_voe_ref_vvoestate
	FOREIGN KEY (voe_state) REFERENCES val_voe_state(voe_state);
ALTER TABLE voe
	ADD CONSTRAINT fk_voe_ref_v_svcenv
	FOREIGN KEY (service_environment) REFERENCES val_service_environment(service_environment);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('voe');
SELECT schema_support.rebuild_audit_trigger('voe');
alter table voe_v26 alter column voe_id drop default;
alter sequence voe_voe_id_seq OWNED BY voe.voe_id;
DROP TABLE voe_v26;
DROP TABLE audit.voe_v26;
GRANT INSERT,SELECT,UPDATE ON voe TO stab_role;
GRANT ALL ON voe TO jazzhands;
GRANT SELECT ON voe TO ro_role;
GRANT INSERT,UPDATE,DELETE ON voe TO iud_role;
-- DEALING WITH TABLE x509_certificate [184029]

-- FOREIGN KEYS FROM
alter table x509_certificate drop constraint fk_x509_cert_cert;
alter table x509_key_usage_attribute drop constraint fk_x509_certificate;

-- FOREIGN KEYS TO
-- alter table x509_certificate drop constraint fk_x509_cert_cert;
alter table x509_certificate drop constraint fk_x509cert_enc_id_id;
alter table x509_certificate drop constraint pk_x509_certificate;
alter table x509_certificate drop constraint ak_x509_cert_cert_ca_ser;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
drop trigger trig_userlog_x509_certificate on x509_certificate;
drop trigger trigger_audit_x509_certificate on x509_certificate;


ALTER TABLE x509_certificate RENAME TO x509_certificate_v26;
ALTER TABLE audit.x509_certificate RENAME TO x509_certificate_v26;

CREATE TABLE x509_certificate
(
	x509_cert_id	integer  NOT NULL,
	signing_cert_id	integer  NULL,
	x509_ca_cert_serial_number	integer  NULL,
	public_key	varchar(4000)  NOT NULL,
	private_key	varchar(4000)  NOT NULL,
	subject	varchar(255)  NOT NULL,
	valid_from	timestamp(6) without time zone  NOT NULL,
	valid_to	timestamp(6) without time zone  NOT NULL,
	is_cert_revoked	character(1)  NOT NULL,
	passphrase	varchar(255)  NULL,
	encryption_key_id	integer  NULL,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('x509_certificate', false);
INSERT INTO x509_certificate (
	x509_cert_id,
	signing_cert_id,
	x509_ca_cert_serial_number,
	public_key,
	private_key,
	subject,
	valid_from,
	valid_to,
	is_cert_revoked,
	passphrase,
	encryption_key_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT		x509_cert_id,
	signing_cert_id,
	x509_ca_cert_serial_number,
	public_key,
	private_key,
	subject,
	valid_from,
	valid_to,
	is_cert_revoked,
	passphrase,
	encryption_key_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM x509_certificate_v26;

INSERT INTO audit.x509_certificate (
	x509_cert_id,
	signing_cert_id,
	x509_ca_cert_serial_number,
	public_key,
	private_key,
	subject,
	valid_from,
	valid_to,
	is_cert_revoked,
	passphrase,
	encryption_key_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT		x509_cert_id,
	signing_cert_id,
	x509_ca_cert_serial_number,
	public_key,
	private_key,
	subject,
	valid_from,
	valid_to,
	is_cert_revoked,
	passphrase,
	encryption_key_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.x509_certificate_v26;

ALTER TABLE x509_certificate
	ALTER x509_cert_id
	SET DEFAULT nextval('x509_certificate_x509_cert_id_seq'::regclass);


COMMENT ON TABLE X509_CERTIFICATE IS 'X509 specification Certificate.';

COMMENT ON COLUMN X509_CERTIFICATE.X509_CERT_ID IS 'Uniquely identifies Certificate';

COMMENT ON COLUMN X509_CERTIFICATE.SIGNING_CERT_ID IS 'Identifier for the certificate that has signed this one.';

COMMENT ON COLUMN X509_CERTIFICATE.X509_CA_CERT_SERIAL_NUMBER IS 'Serial INTEGER assigned to the certificate within Certificate Authority. It uniquely identifies certificate within the realm of the CA.';

COMMENT ON COLUMN X509_CERTIFICATE.PUBLIC_KEY IS 'Textual representation of Certificate Public Key. Public Key is a component of X509 standard and is used for encryption.';

COMMENT ON COLUMN X509_CERTIFICATE.PRIVATE_KEY IS 'Textual representation of Certificate Private Key. Private Key is a component of X509 standard and is used for encryption.';

COMMENT ON COLUMN X509_CERTIFICATE.SUBJECT IS 'Textual representation of a certificate subject. Certificate subject is a part of X509 certificate specifications.';

COMMENT ON COLUMN X509_CERTIFICATE.VALID_FROM IS 'Timestamp indicating when the certificate becomes valid and can be used.';

COMMENT ON COLUMN X509_CERTIFICATE.VALID_TO IS 'Timestamp indicating when the certificate becomes invalid and can''t be used.';

COMMENT ON COLUMN X509_CERTIFICATE.IS_CERT_REVOKED IS 'Indicates if certificate has been revoked. ''Y'' indicates that Certificate has been revoked.';


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE x509_certificate ADD CONSTRAINT pk_x509_certificate PRIMARY KEY (x509_cert_id);
ALTER TABLE x509_certificate ADD CONSTRAINT ak_x509_cert_cert_ca_ser UNIQUE (signing_cert_id, x509_ca_cert_serial_number);
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
ALTER TABLE x509_certificate
	ADD CONSTRAINT fk_x509_cert_cert
	FOREIGN KEY (signing_cert_id) REFERENCES x509_certificate(x509_cert_id);
ALTER TABLE x509_key_usage_attribute
	ADD CONSTRAINT fk_x509_certificate
	FOREIGN KEY (x509_cert_id) REFERENCES x509_certificate(x509_cert_id);

-- FOREIGN KEYS TO
--ALTER TABLE x509_certificate
--	ADD CONSTRAINT fk_x509_cert_cert
--	FOREIGN KEY (signing_cert_id) REFERENCES x509_certificate(x509_cert_id);
ALTER TABLE x509_certificate
	ADD CONSTRAINT fk_x509cert_enc_id_id
	FOREIGN KEY (encryption_key_id) REFERENCES encryption_key(encryption_key_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('x509_certificate');
SELECT schema_support.rebuild_audit_trigger('x509_certificate');
alter table x509_certificate_v26 alter column x509_cert_id 
	drop default;
ALTER SEQUENCE x509_certificate_x509_cert_id_seq OWNED BY
	x509_certificate.x509_cert_id;
DROP TABLE x509_certificate_v26;
DROP TABLE audit.x509_certificate_v26;
GRANT ALL ON x509_certificate TO jazzhands;
GRANT SELECT ON x509_certificate TO ro_role;
GRANT INSERT,UPDATE,DELETE ON x509_certificate TO iud_role;

-- views/pgsql/create_v_application_role.sql
CREATE OR REPLACE VIEW v_application_role AS
WITH RECURSIVE var_recurse(
	role_level,
	role_id,
	parent_role_id,
	root_role_id,
	root_role_name,
	role_name,
	role_path,
	role_is_leaf
) as (
	SELECT	
		0					as role_level,
		device_collection_id			as role_id,
		cast(NULL AS integer)			as parent_role_id,
		device_collection_id			as root_role_id,
		device_collection_name			as root_role_name,
		device_collection_name			as role_name,
		'/'||device_collection_name		as role_path,
		'N'					as role_is_leaf
	FROM
		device_collection
	WHERE
		device_collection_type = 'appgroup'
	AND	device_collection_id not in
		(select device_collection_id from device_collection_hier)
UNION ALL
	SELECT	x.role_level + 1				as role_level,
		dch.device_collection_id 			as role_id,
		dch.parent_device_collection_id 		as parent_role_id,
		x.root_role_id 					as root_role_id,
		x.root_role_name 				as root_role_name,
		dc.device_collection_name			as role_name,
		cast(x.role_path || '/' || dc.device_collection_name 
					as varchar(255))	as role_path,
		case WHEN lchk.parent_device_collection_id IS NULL
			THEN 'Y'
			ELSE 'N'
			END 					as role_is_leaf
	FROM	var_recurse x
		inner join device_collection_hier dch
			on x.role_id = dch.parent_device_collection_id
		inner join device_collection dc
			on dch.device_collection_id = dc.device_collection_id
		left join device_collection_hier lchk
			on dch.device_collection_id 
				= lchk.parent_device_collection_id
) SELECT distinct * FROM var_recurse;

-- consider adding order by root_role_id, role_level, length(role_path)
-- or leave that to things calling it (probably smarter)

CREATE OR REPLACE VIEW v_application_role_member AS
	select	device_id,
		device_collection_id as role_id,
		DATA_INS_USER,
		DATA_INS_DATE,
		DATA_UPD_USER,
		DATA_UPD_DATE
	from	device_collection_member
	where	device_collection_id in
		(select device_collection_id from device_collection
			where device_collection_type = 'appgroup'
		)
;


create or replace view v_property
as
select *
from property
where	is_enabled = 'Y'
and	(
		(start_date is null and finish_date is null)
	OR
		(start_date is null and now() <= finish_date )
	OR
		(start_date <= now() and finish_date is NULL )
	OR
		(start_date <= now() and now() <= finish_date )
	)
;

grant select on v_application_role_member to ro_role;
grant select,insert,update,delete on v_application_role_member to ro_role;

grant select on v_application_role to ro_role;
grant select,insert,update,delete on v_application_role to ro_role;

grant select on v_property to ro_role;
grant select,insert,update,delete on v_property to ro_role;
grant select on v_property to ap_hrfeed;
grant select on v_property to ap_ldapfeed;
grant select on v_property to ap_passwd;


CREATE OR REPLACE VIEW v_acct_coll_expanded AS
WITH RECURSIVE acct_coll_recurse (
	level,
	root_account_collection_id,
	account_collection_id,
	array_path,
	cycle
) AS (
		SELECT
			0 as level,
			ac.account_collection_id as root_account_collection_id,
			ac.account_collection_id as account_collection_id,
			ARRAY[ac.account_collection_id] as array_path,
			false
		FROM
			account_collection ac
	UNION ALL
		SELECT 
			x.level + 1 as level,
			x.root_account_collection_id as root_account_collection_id,
			ach.account_collection_id as account_collection_id,
			x.array_path || ach.account_collection_id as array_path,
			ach.account_collection_id = ANY(array_path) as cycle
		FROM
			acct_coll_recurse x JOIN account_collection_hier ach ON
				x.account_collection_id = ach.child_account_collection_id
		WHERE
			NOT cycle
) SELECT
		level,
		account_collection_id,
		root_account_collection_id,
		array_to_string(array_path, '/') as text_path,
		array_path
	FROM
		acct_coll_recurse;



CREATE OR REPLACE VIEW v_acct_coll_acct_expanded AS
	SELECT DISTINCT 
		ace.account_collection_id,
		aca.account_id
	FROM 
		v_acct_coll_expanded ace JOIN
		v_account_collection_account aca ON
			aca.account_collection_id = ace.root_account_collection_id;


CREATE OR REPLACE VIEW v_acct_coll_expanded_detail AS
WITH RECURSIVE var_recurse (
	root_account_collection_id,
	account_collection_id,
	acct_coll_level,
	dept_level,
	assign_method,
	array_path,
	cycle
	) AS (
		SELECT
			ac.account_collection_id as account_collection_id,
			ac.account_collection_id as root_account_collection_id,
			CASE ac.account_collection_type
				WHEN 'department' THEN 0 
				ELSE 1
			END as acct_coll_level,
			CASE ac.account_collection_type
				WHEN 'department' THEN 1
				ELSE 0
			END as dept_level,
			CASE ac.account_collection_type
				WHEN 'department' THEN 'DirectDepartmentAssignment'
				ELSE 'DirectAccountCollectionAssignment'
			END as assign_method,
			ARRAY[ac.account_collection_id] as array_path,
			false
		FROM
			account_collection ac
	UNION ALL
		SELECT
			x.root_account_collection_id as root_account_collection_id,
			ach.account_collection_id as account_collection_id,
			CASE ac.account_collection_type
				WHEN 'department' THEN x.dept_level
				ELSE x.acct_coll_level + 1
			END as acct_coll_level,
			CASE ac.account_collection_type
				WHEN 'department' THEN x.dept_level + 1
				ELSE x.dept_level
			END as dept_level,
			CASE
				WHEN ac.account_collection_type = 'department' 
					THEN 'AccountAssignedToChildDepartment'
				WHEN x.dept_level > 1 AND x.acct_coll_level > 0
					THEN 'ChildDepartmentAssignedToChildAccountCollection'
				WHEN x.dept_level > 1
					THEN 'ChildDepartmentAssignedToAccountCollection'
				WHEN x.dept_level = 1 and x.acct_coll_level > 0
					THEN 'DepartmentAssignedToChildAccountCollection'
				WHEN x.dept_level = 1
					THEN 'DepartmentAssignedToAccountCollection'
				ELSE 'AccountAssignedToChildAccountCollection'
				END as assign_method,
			x.array_path || ach.account_collection_id as array_path,
			ach.account_collection_id = ANY(array_path)
		FROM
			var_recurse x JOIN account_collection_hier ach ON
				x.account_collection_id = ach.child_account_collection_id JOIN
			account_collection ac ON 
				ach.account_collection_id = ac.account_collection_id
		WHERE
			NOT cycle
) SELECT
		account_collection_id,
		root_account_collection_id,
		acct_coll_level as acct_coll_level,
		dept_level dept_level,
		assign_method,
		array_to_string(array_path, '/') as text_path,
		array_path
	FROM var_recurse;

CREATE OR REPLACE VIEW v_acct_coll_prop_expanded AS
	SELECT
		root_account_collection_id as account_collection_id,
		property_id,
		property_name,
		property_type,
		property_value,
		property_value_timestamp,
		property_value_company_id,
		property_value_account_coll_id,
		property_value_dns_domain_id,
		property_value_nblk_coll_id,
		property_value_password_type,
		property_value_person_id,
		property_value_sw_package_id,
		property_value_token_col_id,
		CASE is_multivalue WHEN 'N' THEN false WHEN 'Y' THEN true END 
			is_multivalue
	FROM
		v_acct_coll_expanded_detail JOIN
		account_collection ac USING (account_collection_id) JOIN
		v_property USING (account_collection_id) JOIN
		val_property USING (property_name, property_type)
	ORDER BY
		CASE account_collection_type
			WHEN 'per-user' THEN 0
			ELSE 99
			END,
		CASE assign_method
			WHEN 'DirectAccountCollectionAssignment' THEN 0
			WHEN 'DirectDepartmentAssignment' THEN 1
			WHEN 'DepartmentAssignedToAccountCollection' THEN 2
			WHEN 'AccountAssignedToChildDepartment' THEN 3
			WHEN 'AccountAssignedToChildAccountCollection' THEN 4
			WHEN 'DepartmentAssignedToChildAccountCollection' THEN 5
			WHEN 'ChildDepartmentAssignedToAccountCollection' THEN 6
			WHEN 'ChildDepartmentAssignedToChildAccountCollection' THEN 7
			ELSE 99
			END,
		dept_level,
		acct_coll_level,
		account_collection_id;


CREATE OR REPLACE VIEW v_acct_coll_acct_expanded_detail AS
WITH RECURSIVE var_recurse(
	account_collection_id,
	root_account_collection_id,
	account_id,
	acct_coll_level,
	dept_level,
	assign_method,
	array_path,
	cycle
) AS (
	SELECT 
		aca.account_collection_id,
		aca.account_collection_id,
		aca.account_id, 
		CASE ac.account_collection_type
			WHEN 'department'::text THEN 0
			ELSE 1
		END,
		CASE ac.account_collection_type
			WHEN 'department'::text THEN 1
			ELSE 0
		END,
		CASE ac.account_collection_type
			WHEN 'department'::text THEN 'DirectDepartmentAssignment'::text
			ELSE 'DirectAccountCollectionAssignment'::text
		END,
		ARRAY[aca.account_collection_id],
		false
	FROM
		account_collection ac JOIN
		account_collection_account aca USING (account_collection_id)
	UNION ALL 
	SELECT
		ach.account_collection_id,
		x.root_account_collection_id,
		x.account_id, 
		CASE ac.account_collection_type
			WHEN 'department'::text THEN x.dept_level
			ELSE x.acct_coll_level + 1
		END,
		CASE ac.account_collection_type
			WHEN 'department'::text THEN x.dept_level + 1
			ELSE x.dept_level
		END,
		CASE
			WHEN ac.account_collection_type::text = 'department'::text THEN 'AccountAssignedToChildDepartment'::text
			WHEN x.dept_level > 1 AND x.acct_coll_level > 0 THEN 'ParentDepartmentAssignedToParentAccountCollection'::text
			WHEN x.dept_level > 1 THEN 'ParentDepartmentAssignedToAccountCollection'::text
			WHEN x.dept_level = 1 AND x.acct_coll_level > 0 THEN 'DepartmentAssignedToParentAccountCollection'::text
			WHEN x.dept_level = 1 THEN 'DepartmentAssignedToAccountCollection'::text
			ELSE 'AccountAssignedToParentAccountCollection'::text
		END AS assign_method, x.array_path || ach.account_collection_id AS array_path, ach.account_collection_id = ANY (x.array_path)
	FROM
		var_recurse x JOIN
		account_collection_hier ach ON x.account_collection_id = ach.child_account_collection_id JOIN
		account_collection ac ON ach.account_collection_id = ac.account_collection_id
	WHERE
		NOT x.cycle
) SELECT 
	account_collection_id,
	root_account_collection_id,
	account_id,
	acct_coll_level,
	dept_level,
	assign_method,
	array_to_string(var_recurse.array_path, '/'::text) AS text_path,
	array_path
FROM
	var_recurse;

-------------------------------------------------------------------
-- returns the Id tag for CM
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION person_manip.id_tag()
RETURNS VARCHAR AS $$
BEGIN
	RETURN('<-- $Id -->');
END;
$$ LANGUAGE plpgsql;
-- end of procedure id_tag
-------------------------------------------------------------------

CREATE OR REPLACE FUNCTION person_manip.get_account_collection_id( department varchar, type varchar )
	RETURNS INTEGER AS $$
DECLARE
	_account_collection_id INTEGER;
BEGIN
	SELECT account_collection_id INTO _account_collection_id FROM account_collection WHERE account_collection_type= type
		AND account_collection_name= department;
	IF NOT FOUND THEN
		_account_collection_id = nextval('account_collection_account_collection_id_seq');
		INSERT INTO account_collection (account_collection_id, account_collection_type, account_collection_name)
			VALUES (_account_collection_id, type, department);
		--RAISE NOTICE 'Created new department % with account_collection_id %', department, _account_collection_id;
	END IF;
	RETURN _account_collection_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION person_manip.update_department( department varchar, _account_id integer, old_account_collection_id integer) 
	RETURNS INTEGER AS $$
DECLARE
	_account_collection_id INTEGER;
BEGIN
	_account_collection_id = person_manip.get_account_collection_id( department, 'department' ); 
	--RAISE NOTICE 'updating account_collection_account with id % for account %', _account_collection_id, _account_id; 
	UPDATE account_collection_account SET account_collection_id = _account_collection_id WHERE account_id = _account_id AND account_collection_id=old_account_collection_id;
	RETURN _account_collection_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS person_manip.add_person(
	VARCHAR, 
	VARCHAR, 
	VARCHAR,
	VARCHAR, 
	VARCHAR, 
	VARCHAR,
	DATE,
	INTEGER, 
	VARCHAR, 
	VARCHAR, 
	VARCHAR,
	INTEGER,
	DATE,
	DATE,
	VARCHAR,
	VARCHAR,
	VARCHAR, login VARCHAR,
	OUT INTEGER,
	OUT INTEGER,
	OUT INTEGER);


CREATE OR REPLACE FUNCTION person_manip.add_person(
	first_name VARCHAR, 
	middle_name VARCHAR, 
	last_name VARCHAR,
	name_suffix VARCHAR, 
	gender VARCHAR(1), 
	preferred_last_name VARCHAR,
	preferred_first_name VARCHAR,
	birth_date DATE,
	_company_id INTEGER, 
	external_hr_id VARCHAR, 
	person_company_status VARCHAR, 
	is_exempt VARCHAR(1),
	employee_id INTEGER,
	hire_date DATE,
	termination_date DATE,
	person_company_relation VARCHAR,
	job_title VARCHAR,
	department VARCHAR, login VARCHAR,
	OUT person_id INTEGER,
	OUT _account_collection_id INTEGER,
	OUT account_id INTEGER)
 AS $$
DECLARE
	_account_realm_id INTEGER;
BEGIN
	person_id = nextval('person_person_id_seq');
	INSERT INTO person (person_id, first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
		VALUES (person_id, first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date);
	INSERT INTO person_company
		(person_id,company_id,external_hr_id,person_company_status,is_exempt,employee_id,hire_date,termination_date,person_company_relation, position_title)
		VALUES
		(person_id, _company_id, external_hr_id, person_company_status, is_exempt, employee_id, hire_date, termination_date, person_company_relation, job_title);
	SELECT account_realm_id INTO _account_realm_id FROM account_realm_company WHERE company_id = _company_id;
	INSERT INTO person_account_realm_company ( person_id, company_id, account_realm_id) VALUES ( person_id, _company_id, _account_realm_id);
	account_id = nextval('account_account_id_seq');
	INSERT INTO account ( account_id, login, person_id, company_id, account_realm_id, account_status, account_role, account_type) 
		VALUES (account_id, login, person_id, _company_id, _account_realm_id, person_company_status, 'primary', 'person');
	IF department IS NULL THEN
		RETURN;
	END IF;
	_account_collection_id = person_manip.get_account_collection_id(department, 'department');
	INSERT INTO account_collection_account (account_collection_id, account_id) VALUES ( _account_collection_id, account_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE OR REPLACE FUNCTION person_manip.add_account_non_person(_company_id integer, _account_status character varying, _login character varying, _description character varying) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
	_account_realm_id INTEGER;
	_person_id INTEGER;
	_account_id INTEGER;
BEGIN
	_person_id := 0;
	SELECT account_realm_id INTO _account_realm_id FROM account_realm_company WHERE company_id = _company_id;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Cannot find account_realm_id with company id %',_company_id;
	END IF;
	_account_id = nextval('public.account_account_id_seq');
	INSERT INTO account ( account_id, login, person_id, company_id, account_realm_id, account_status, description, account_role, account_type) 
		VALUES (_account_id, _login, _person_id, _company_id, _account_realm_id, _account_status, _description, 'primary', 'pseudouser');
	RETURN _account_id;
END;
$$;


CREATE OR REPLACE FUNCTION person_manip.get_unix_uid(account_type CHARACTER VARYING) RETURNS INTEGER AS $$
DECLARE new_id INTEGER;
BEGIN
        IF account_type = 'people' THEN
                SELECT 
                        coalesce(max(unix_uid),10199) INTO new_id 
                FROM
                        account_unix_info aui
                JOIN
                        account a 
                USING
                        (account_id)
                JOIN
                        person p 
                USING
                        (person_id)
                WHERE
                        p.person_id != 0;
		new_id = new_id + 1;
        ELSE
                SELECT
                        coalesce(min(unix_uid),10000) INTO new_id
                FROM
                        account_unix_info aui
                JOIN
                        account a
                USING
                        (account_id)
                JOIN
                        person p
                USING
                        (person_id)
                WHERE
                        p.person_id = 0 AND unix_uid >0;
		new_id = new_id - 1;
        END IF;
        RETURN new_id;
END;

$$
        LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION fix_person_image_oid_ownership()
RETURNS TRIGGER AS $$
DECLARE
   b	integer;
BEGIN
	b := NEW.image_blob; 
	BEGIN
		EXECUTE 'GRANT SELECT on LARGE OBJECT b to picture_image_ro';
		EXECUTE 'GRANT UPGRADE on LARGE OBJECT b to picture_image_rw';
		EXECUTE 'ALTER large object b owner to jazzhands';
	EXCEPTION WHEN OTHERS THEN
		RAISE NOTICE 'Unable to adjust ownership of %', b;
	END;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

--- XXX - not quite clear where this belongs.  I think its on person_image
DROP TRIGGER IF EXISTS fix_person_image_oid_ownership ON person_image;
DROP TRIGGER IF EXISTS fix_person_image_oid_ownership ON person_image_usage;
DROP TRIGGER IF EXISTS trigger_fix_person_image_oid_ownership ON person_image_usage;
CREATE TRIGGER trigger_fix_person_image_oid_ownership BEFORE INSERT OR UPDATE OR DELETE
    ON person_image
    FOR EACH ROW 
    EXECUTE PROCEDURE fix_person_image_oid_ownership();

--- start of per-user manipulations
-- manage per-user account collection types.  Arguably we want to extend
-- account collections to be per account_realm, but I was not ready to do this at
-- implementaion time.
-- XXX need automated test case

-- before an account is deleted, remove the per-user account collections, if appropriate
-- this runs on DELETE only
CREATE OR REPLACE FUNCTION delete_peruser_account_collection() RETURNS TRIGGER AS $$
DECLARE
	def_acct_rlm	account_realm.account_realm_id%TYPE;
	acid			account_collection.account_collection_id%TYPE;
BEGIN
	IF TG_OP = 'DELETE' THEN
		SELECT	account_realm_id
		  INTO	def_acct_rlm
		  FROM	account_realm_company
		 WHERE	company_id IN
		 		(select property_value_company_id
				   from property
				  where	property_name = '_rootcompanyid'
				    and	property_type = 'Defaults'
				);
		IF def_acct_rlm is not NULL AND OLD.account_realm_id = def_acct_rlm THEN
				SELECT	account_collection_id FROM account_collection
				  INTO	acid
				 WHERE	account_collection_name = OLD.login
				   AND	account_collection_type = 'per-user';
	
				 DELETE from account_collection_account
				  where account_collection_id = acid;
	
				 DELETE from account_collection
				  where account_collection_id = acid;
		END IF;
	END IF;
	RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_delete_peruser_account_collection ON Account;
CREATE TRIGGER trigger_delete_peruser_account_collection BEFORE DELETE
	ON Account FOR EACH ROW EXECUTE PROCEDURE delete_peruser_account_collection();

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
			  AND	company_id = NEW.company_id;
		END IF;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION person_manip.add_person(
	first_name VARCHAR, 
	middle_name VARCHAR, 
	last_name VARCHAR,
	name_suffix VARCHAR, 
	gender VARCHAR(1), 
	preferred_last_name VARCHAR,
	preferred_first_name VARCHAR,
	birth_date DATE,
	_company_id INTEGER, 
	external_hr_id VARCHAR, 
	person_company_status VARCHAR, 
	is_exempt VARCHAR(1),
	employee_id INTEGER,
	hire_date DATE,
	termination_date DATE,
	person_company_relation VARCHAR,
	job_title VARCHAR,
	department VARCHAR, login VARCHAR,
	OUT person_id INTEGER,
	OUT _account_collection_id INTEGER,
	OUT account_id INTEGER)
 AS $$
DECLARE
	_account_realm_id INTEGER;
BEGIN
	person_id = nextval('person_person_id_seq');
	INSERT INTO person (person_id, first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
		VALUES (person_id, first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date);
	INSERT INTO person_company
		(person_id,company_id,external_hr_id,person_company_status,is_exempt,employee_id,hire_date,termination_date,person_company_relation, position_title)
		VALUES
		(person_id, _company_id, external_hr_id, person_company_status, is_exempt, employee_id, hire_date, termination_date, person_company_relation, job_title);
	SELECT account_realm_id INTO _account_realm_id FROM account_realm_company WHERE company_id = _company_id;
	INSERT INTO person_account_realm_company ( person_id, company_id, account_realm_id) VALUES ( person_id, _company_id, _account_realm_id);
	account_id = nextval('account_account_id_seq');
	INSERT INTO account ( account_id, login, person_id, company_id, account_realm_id, account_status, account_role, account_type) 
		VALUES (account_id, login, person_id, _company_id, _account_realm_id, person_company_status, 'primary', 'person');
	IF department IS NULL THEN
		RETURN;
	END IF;
	_account_collection_id = person_manip.get_account_collection_id(department, 'department');
	INSERT INTO account_collection_account (account_collection_id, account_id) VALUES ( _account_collection_id, account_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE OR REPLACE FUNCTION person_manip.add_account_non_person(_company_id integer, _account_status character varying, _login character varying, _description character varying) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
	_account_realm_id INTEGER;
	_person_id INTEGER;
	_account_id INTEGER;
BEGIN
	_person_id := 0;
	SELECT account_realm_id INTO _account_realm_id FROM account_realm_company WHERE company_id = _company_id;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Cannot find account_realm_id with company id %',_company_id;
	END IF;
	_account_id = nextval('public.account_account_id_seq');
	INSERT INTO account ( account_id, login, person_id, company_id, account_realm_id, account_status, description, account_role, account_type) 
		VALUES (_account_id, _login, _person_id, _company_id, _account_realm_id, _account_status, _description, 'primary', 'pseudouser');
	RETURN _account_id;
END;
$$;


-- rebuild all triggers to deal with function moving into schema_support
SELECT schema_support.rebuild_stamp_triggers();
SELECT schema_support.build_audit_tables();

drop function trigger_ins_upd_generic_func();


--- XXX --- KEEP AT END
grant insert,update,delete on all tables in schema public to iud_role;
grant select,update on all sequences in schema public to iud_role;
grant execute on all functions in schema person_manip to iud_role;
grant execute on all functions in schema port_support to iud_role;
grant execute on all functions in schema port_utils to iud_role;
--- END
