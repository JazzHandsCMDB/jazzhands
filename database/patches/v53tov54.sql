\set ON_ERROR_STOP

drop view v_application_role_member;
drop view v_acct_coll_prop_expanded;
drop view v_dev_col_user_prop_expanded;
drop view v_l1_all_physical_ports;
drop view IF EXISTS v_device_col_acct_col_expanded;
drop view v_acct_coll_acct_expanded;
drop view v_account_collection_account;
drop view v_property;


/*

NOTES:
  - layer2_encapsulation_type is NULLable, should not be
  - rack.rack-type is NULLable.  should not be.
  - search for XXX and triggers

 */

/*
  The following tables are dealt with:
	val_property
	val_plug_style:val_power_plug_style
	device_type_power_port_templt
	encapsulation_netblock
	val_device_mgmt_ctrl_type
	val_ip_group_protocol
	val_layer2_encapsulation_type
	val_port_medium
	val_port_protocol
	val_port_speed
	val_rack_type
	device_type_phys_port_templt
	physical_port
	network_interface_purpose
	network_interface
	layer2_encapsulation
	ip_group
	ip_group_network_interface
	rack
	device_management_controller
	device
	service_environment_collection
	service_environment_coll_hier
	svc_environment_coll_svc_env
	property
 */
------------------------------------------------------------------------------
-- Delete data whose purpose is changing
------------------------------------------------------------------------------

delete from val_network_interface_type where network_interface_type in (
 'Ethernet',
 'FastEthernet',
 'GigabitEthernet',
 '10GigEthernet',
 'DS1',
 'DS3',
 'E1',
 'E3',
 'OC3',
 'OC12',
 'OC48',
 'OC192',
 'OC768',
 'serial'
);

delete from val_network_interface_purpose where network_interface_purpose in (
	'oobmgmt',
	'ibmgmt',
	'service'
);

------------------------------------------------------------------------------
-- BEGIN: TABLE MIGRATION
------------------------------------------------------------------------------

DROP TRIGGER IF EXISTS ta_manipulate_netblock_parentage on netblock;
DROP TRIGGER IF EXISTS aaa_ta_manipulate_netblock_parentage on netblock;

CREATE CONSTRAINT TRIGGER aaa_ta_manipulate_netblock_parentage 
AFTER INSERT OR DELETE ON netblock 
NOT DEFERRABLE INITIALLY IMMEDIATE 
FOR EACH ROW EXECUTE PROCEDURE manipulate_netblock_parentage_after();


--------------------------------------------------------------------
-- DEALING WITH TABLE val_property [438438]

-- FOREIGN KEYS FROM
alter table val_property_value drop constraint fk_valproval_namtyp;
alter table property drop constraint fk_property_nmtyp;

-- FOREIGN KEYS TO
alter table val_property drop constraint fk_valprop_pv_actyp_rst;
alter table val_property drop constraint fk_val_prop_nblk_coll_type;
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
alter table val_property drop constraint ckc_val_prop_pacct_id;
alter table val_property drop constraint check_prp_prmt_606225804;
alter table val_property drop constraint ckc_val_prop_osid;
alter table val_property drop constraint ckc_val_prop_pucls_id;
alter table val_property drop constraint ckc_val_prop_pdevcol_id;
alter table val_property drop constraint check_prp_prmt_2139007167;
alter table val_property drop constraint ckc_val_prop_pdnsdomid;
alter table val_property drop constraint ckc_val_prop_prodstate;
alter table val_property drop constraint ckc_val_prop_sitec;
-- TRIGGERS, etc
drop trigger trigger_audit_val_property on val_property;
drop trigger trig_userlog_val_property on val_property;


ALTER TABLE val_property RENAME TO val_property_v53;
ALTER TABLE audit.val_property RENAME TO val_property_v53;

CREATE TABLE val_property
(
	property_name	varchar(255) NOT NULL,
	property_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	is_multivalue	character(1) NOT NULL,
	prop_val_acct_coll_type_rstrct	varchar(50)  NULL,
	prop_val_nblk_coll_type_rstrct	varchar(50)  NULL,
	property_data_type	varchar(50) NOT NULL,
	permit_account_collection_id	character(10) NOT NULL,
	permit_company_id	character(10) NOT NULL,
	permit_device_collection_id	character(10) NOT NULL,
	permit_account_id	character(10) NOT NULL,
	permit_dns_domain_id	character(10) NOT NULL,
	permit_netblock_collection_id	character(10) NOT NULL,
	permit_operating_system_id	character(10) NOT NULL,
	permit_person_id	character(10) NOT NULL,
	permit_service_env_collection	character(10) NOT NULL,
	permit_site_code	character(10) NOT NULL,
	permit_property_rank	character(10) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_property', false);
INSERT INTO val_property (
	property_name,
	property_type,
	description,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_company_id,
	permit_device_collection_id,
	permit_account_id,
	permit_dns_domain_id,
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_person_id,
	permit_service_env_collection,		-- new column (permit_service_env_collection)
	permit_site_code,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	property_name,
	property_type,
	description,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_company_id,
	permit_device_collection_id,
	permit_account_id,
	permit_dns_domain_id,
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_person_id,
	permit_service_environment,		-- new column (permit_service_env_collection)
	permit_site_code,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_property_v53;

INSERT INTO audit.val_property (
	property_name,
	property_type,
	description,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_company_id,
	permit_device_collection_id,
	permit_account_id,
	permit_dns_domain_id,
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_person_id,
	permit_service_env_collection,		-- new column (permit_service_env_collection)
	permit_site_code,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	property_name,
	property_type,
	description,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_company_id,
	permit_device_collection_id,
	permit_account_id,
	permit_dns_domain_id,
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_person_id,
	permit_service_environment,		-- new column (permit_service_env_collection)
	permit_site_code,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_property_v53;

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
	ALTER permit_account_id
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
	ALTER permit_service_env_collection
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_site_code
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_property_rank
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
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_2139007167
	CHECK (permit_property_rank = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pdnsdomid
	CHECK (permit_dns_domain_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_sitec
	CHECK (permit_site_code = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_prodstate
	CHECK (permit_service_env_collection = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));

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
	FOREIGN KEY (prop_val_acct_coll_type_rstrct) REFERENCES val_account_collection_type(account_collection_type);
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_nblk_coll_type
	FOREIGN KEY (prop_val_nblk_coll_type_rstrct) REFERENCES val_netblock_collection_type(netblock_collection_type);
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_proptyp
	FOREIGN KEY (property_type) REFERENCES val_property_type(property_type);
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_propdttyp
	FOREIGN KEY (property_data_type) REFERENCES val_property_data_type(property_data_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_property');
DROP TABLE val_property_v53;
DROP TABLE audit.val_property_v53;
GRANT ALL ON val_property TO jazzhands;
GRANT SELECT ON val_property TO ro_role;
GRANT INSERT,UPDATE,DELETE ON val_property TO iud_role;
-- DONE DEALING WITH TABLE val_property [745586]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_plug_style [434465]

-- FOREIGN KEYS FROM
alter table device_type_power_port_templt drop constraint fk_dev_pport_v_plug_style;

-- FOREIGN KEYS TO
alter table val_plug_style drop constraint pk_val_plug_style;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
drop trigger trig_userlog_val_plug_style on val_plug_style;
drop trigger trigger_audit_val_plug_style on val_plug_style;

drop function perform_audit_val_plug_style();

ALTER TABLE val_plug_style RENAME TO val_plug_style_v53;
ALTER TABLE audit.val_plug_style RENAME TO val_plug_style_v53;

ALTER SEQUENCE audit.val_plug_style_seq RENAME to val_power_plug_style_seq;

CREATE TABLE val_power_plug_style
(
	power_plug_style	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_power_plug_style', false);
INSERT INTO val_power_plug_style (
	power_plug_style,		-- new column (power_plug_style)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	plug_style,		-- new column (power_plug_style)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_plug_style_v53;

INSERT INTO audit.val_power_plug_style (
	power_plug_style,		-- new column (power_plug_style)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	plug_style,		-- new column (power_plug_style)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_plug_style_v53;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_power_plug_style ADD CONSTRAINT pk_val_power_plug_style PRIMARY KEY (power_plug_style);
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- this is fixed later
--ALTER TABLE device_type_power_port_templt
--	ADD CONSTRAINT fk_dev_pport_v_pwr_plug_style
--	FOREIGN KEY (power_plug_style) REFERENCES val_power_plug_style(power_plug_style);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_power_plug_style');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_power_plug_style');
DROP TABLE val_plug_style_v53;
DROP TABLE audit.val_plug_style_v53;
GRANT ALL ON val_power_plug_style TO jazzhands;
GRANT SELECT ON val_power_plug_style TO ro_role;
GRANT INSERT,UPDATE,DELETE ON val_power_plug_style TO iud_role;
-- DONE DEALING WITH TABLE val_power_plug_style [745561]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE device_type_power_port_templt [433437]

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
alter table device_type_power_port_templt drop constraint fk_dev_type_dev_pwr_prt_tmpl;
-- not really here
-- alter table device_type_power_port_templt drop constraint fk_dev_pport_v_plug_style;
alter table device_type_power_port_templt drop constraint pk_device_type_power_port_temp;
-- INDEXES
-- CHECK CONSTRAINTS, etc
alter table device_type_power_port_templt drop constraint ckc_dtyp_pwrtmp_opt;
alter table device_type_power_port_templt drop constraint ckc_provides_power_device_t;
-- TRIGGERS, etc
drop trigger trig_userlog_device_type_power_port_templt on device_type_power_port_templt;
drop trigger trigger_audit_device_type_power_port_templt on device_type_power_port_templt;


ALTER TABLE device_type_power_port_templt RENAME TO device_type_power_port_templt_v53;
ALTER TABLE audit.device_type_power_port_templt RENAME TO device_type_power_port_templt_v53;

CREATE TABLE device_type_power_port_templt
(
	power_interface_port	varchar(20) NOT NULL,
	device_type_id	integer NOT NULL,
	power_plug_style	varchar(50) NOT NULL,
	voltage	integer NOT NULL,
	max_amperage	integer NOT NULL,
	provides_power	character(1) NOT NULL,
	is_optional	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'device_type_power_port_templt', false);
INSERT INTO device_type_power_port_templt (
	power_interface_port,
	device_type_id,
	power_plug_style,		-- new column (power_plug_style)
	voltage,
	max_amperage,
	provides_power,
	is_optional,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	power_interface_port,
	device_type_id,
	plug_style,		-- new column (power_plug_style)
	voltage,
	max_amperage,
	provides_power,
	is_optional,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM device_type_power_port_templt_v53;

INSERT INTO audit.device_type_power_port_templt (
	power_interface_port,
	device_type_id,
	power_plug_style,		-- new column (power_plug_style)
	voltage,
	max_amperage,
	provides_power,
	is_optional,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	power_interface_port,
	device_type_id,
	plug_style,		-- new column (power_plug_style)
	voltage,
	max_amperage,
	provides_power,
	is_optional,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.device_type_power_port_templt_v53;

ALTER TABLE device_type_power_port_templt
	ALTER is_optional
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device_type_power_port_templt ADD CONSTRAINT pk_device_type_power_port_temp PRIMARY KEY (power_interface_port, device_type_id);
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE device_type_power_port_templt ADD CONSTRAINT ckc_dtyp_pwrtmp_opt
	CHECK (is_optional = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE device_type_power_port_templt ADD CONSTRAINT ckc_provides_power_device_t
	CHECK ((provides_power = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((provides_power)::text = upper((provides_power)::text)));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE device_type_power_port_templt
	ADD CONSTRAINT fk_dev_type_dev_pwr_prt_tmpl
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);
ALTER TABLE device_type_power_port_templt
	ADD CONSTRAINT fk_dev_pport_v_pwr_plug_style
	FOREIGN KEY (power_plug_style) REFERENCES val_power_plug_style(power_plug_style);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device_type_power_port_templt');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device_type_power_port_templt');
DROP TABLE device_type_power_port_templt_v53;
DROP TABLE audit.device_type_power_port_templt_v53;
GRANT ALL ON device_type_power_port_templt TO jazzhands;
GRANT SELECT ON device_type_power_port_templt TO ro_role;
GRANT INSERT,UPDATE,DELETE ON device_type_power_port_templt TO iud_role;
-- DONE DEALING WITH TABLE device_type_power_port_templt [744390]
--------------------------------------------------------------------
CREATE TABLE encapsulation_netblock
(
	encapsulation_id	integer NOT NULL,
	netblock_id	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'encapsulation_netblock', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE encapsulation_netblock ADD CONSTRAINT pk_encapsulation_netblock PRIMARY KEY (encapsulation_id, netblock_id);
-- INDEXES
CREATE INDEX xif1encapsulation_netblock ON encapsulation_netblock USING btree (encapsulation_id);
CREATE INDEX xif2encapsulation_netblock ON encapsulation_netblock USING btree (netblock_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE encapsulation_netblock
	ADD CONSTRAINT fk_encap_netblock_nblk_id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
ALTER TABLE encapsulation_netblock
	ADD CONSTRAINT fk_encap_netblock_encap_id
	FOREIGN KEY (encapsulation_id) REFERENCES encapsulation(encapsulation_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'encapsulation_netblock');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'encapsulation_netblock');
-- DONE DEALING WITH TABLE encapsulation_netblock [744464]
--------------------------------------------------------------------
CREATE TABLE val_device_mgmt_ctrl_type
(
	device_mgmt_control_type	varchar(255) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_device_mgmt_ctrl_type', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_device_mgmt_ctrl_type ADD CONSTRAINT pk_val_device_mgmt_ctrl_type PRIMARY KEY (device_mgmt_control_type);
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- fixed later
-- ALTER TABLE device_management_controller
-- 	ADD CONSTRAINT fk_dev_mgmt_cntrl_val_ctrl_typ
-- 	FOREIGN KEY (device_mgmt_control_type) REFERENCES val_device_mgmt_ctrl_type(device_mgmt_control_type);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_device_mgmt_ctrl_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_device_mgmt_ctrl_type');
-- DONE DEALING WITH TABLE val_device_mgmt_ctrl_type [745272]
--------------------------------------------------------------------
CREATE TABLE val_ip_group_protocol
(
	ip_group_protocol	character(18) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_ip_group_protocol', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_ip_group_protocol ADD CONSTRAINT pk_val_ip_group_protocol PRIMARY KEY (ip_group_protocol);
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- fixed later
--ALTER TABLE ip_group
--	ADD CONSTRAINT fk_ip_grp_ip_grp_proto
--	FOREIGN KEY (ip_group_protocol) REFERENCES val_ip_group_protocol(ip_group_protocol);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_ip_group_protocol');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_ip_group_protocol');
-- DONE DEALING WITH TABLE val_ip_group_protocol [745365]
--------------------------------------------------------------------
CREATE TABLE val_layer2_encapsulation_type
(
	layer2_encapsulation_type	character(18) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_layer2_encapsulation_type', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_layer2_encapsulation_type ADD CONSTRAINT pk_val_layer2_encapsulation_ty PRIMARY KEY (layer2_encapsulation_type);
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- fixed later
--ALTER TABLE layer2_encapsulation
--	ADD CONSTRAINT fk_l2_encap_val_l2encap_type
--	FOREIGN KEY (layer2_encapsulation_type) REFERENCES val_layer2_encapsulation_type(layer2_encapsulation_type);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_layer2_encapsulation_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_layer2_encapsulation_type');
-- DONE DEALING WITH TABLE val_layer2_encapsulation_type [745375]
--------------------------------------------------------------------
CREATE TABLE val_port_medium
(
	port_medium	varchar(50) NOT NULL,
	port_plug_style	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_port_medium', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_port_medium ADD CONSTRAINT pk_val_port_medium PRIMARY KEY (port_medium, port_plug_style);
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- fixed later
-- ALTER TABLE physical_port
-- 	ADD CONSTRAINT fk_phys_port_port_medium
-- 	FOREIGN KEY (port_medium, port_plug_style) REFERENCES val_port_medium(port_medium, port_plug_style);
-- ALTER TABLE device_type_phys_port_templt
-- 	ADD CONSTRAINT fk_dt_phsport_tmpl_v_port_medm
--	FOREIGN KEY (port_medium, port_plug_style) REFERENCES val_port_medium(port_medium, port_plug_style);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_port_medium');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_port_medium');
-- DONE DEALING WITH TABLE val_port_medium [745519]
--------------------------------------------------------------------
CREATE TABLE val_port_protocol
(
	port_protocol	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_port_protocol', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_port_protocol ADD CONSTRAINT pk_val_port_protocol PRIMARY KEY (port_protocol);
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- fixed later
--ALTER TABLE physical_port
--	ADD CONSTRAINT fk_phys_port_val_protocol
--	FOREIGN KEY (port_protocol) REFERENCES val_port_protocol(port_protocol);
--ALTER TABLE device_type_phys_port_templt
--	ADD CONSTRAINT fk_dt_phsport_tmp_v_protocol
--	FOREIGN KEY (port_protocol) REFERENCES val_port_protocol(port_protocol);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_port_protocol');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_port_protocol');
-- DONE DEALING WITH TABLE val_port_protocol [745527]
--------------------------------------------------------------------
CREATE TABLE val_port_speed
(
	port_speed	varchar(50) NOT NULL,
	port_speed_bps	bigint NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_port_speed', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_port_speed ADD CONSTRAINT pk_val_port_speed PRIMARY KEY (port_speed);
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- fixed later
--ALTER TABLE physical_port
--	ADD CONSTRAINT fk_phys_port_val_port_speed
--	FOREIGN KEY (port_speed) REFERENCES val_port_speed(port_speed);
--ALTER TABLE device_type_phys_port_templt
--	ADD CONSTRAINT fk_dt_phsport_tmp_val_prt_spd
--	FOREIGN KEY (port_speed) REFERENCES val_port_speed(port_speed);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_port_speed');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_port_speed');
-- DONE DEALING WITH TABLE val_port_speed [745545]
--------------------------------------------------------------------
CREATE TABLE val_rack_type
(
	rack_type	varchar(255) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_rack_type', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_rack_type ADD CONSTRAINT pk_val_rack_type PRIMARY KEY (rack_type);
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- fixed later
--ALTER TABLE rack
--	ADD CONSTRAINT fk_rack_v_rack_type
--	FOREIGN KEY (rack_type) REFERENCES val_rack_type(rack_type);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_rack_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_rack_type');
-- DONE DEALING WITH TABLE val_rack_type [745642]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE device_type_phys_port_templt [856845]

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
alter table device_type_phys_port_templt drop constraint fk_devtype_ref_devtphysprttmpl;
alter table device_type_phys_port_templt drop constraint fk_devtphyprttmpl_ref_vprtpurp;
alter table device_type_phys_port_templt drop constraint pk_device_type_phys_port_templ;
-- INDEXES
DROP INDEX idx_dtphysport_portype;
-- CHECK CONSTRAINTS, etc
alter table device_type_phys_port_templt drop constraint ckc_dvtyp_physp_tmp_opt;
-- TRIGGERS, etc
drop trigger trigger_audit_device_type_phys_port_templt on device_type_phys_port_templt;
drop trigger trig_userlog_device_type_phys_port_templt on device_type_phys_port_templt;


ALTER TABLE device_type_phys_port_templt RENAME TO device_type_phys_port_templt_v53;
ALTER TABLE audit.device_type_phys_port_templt RENAME TO device_type_phys_port_templt_v53;

CREATE TABLE device_type_phys_port_templt
(
	port_name	varchar(50) NOT NULL,
	device_type_id	integer NOT NULL,
	port_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	port_plug_style	varchar(50)  NULL,
	port_medium	varchar(50)  NULL,
	port_protocol	varchar(50)  NULL,
	port_speed	varchar(50)  NULL,
	physical_label	varchar(50)  NULL,
	port_purpose	varchar(50)  NULL,
	tcp_port	integer  NULL,
	is_optional	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'device_type_phys_port_templt', false);
INSERT INTO device_type_phys_port_templt (
	port_name,
	device_type_id,
	port_type,
	description,
	port_medium,		-- new column (port_medium)
	port_plug_style,		-- new column (port_plug_style)
	port_protocol,		-- new column (port_protocol)
	port_speed,		-- new column (port_speed)
	physical_label,
	port_purpose,
	tcp_port,
	is_optional,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	port_name,
	device_type_id,
	port_type,
	description,
	NULL,		-- new column (port_medium)
	NULL,		-- new column (port_plug_style)
	NULL,		-- new column (port_protocol)
	NULL,		-- new column (port_speed)
	physical_label,
	port_purpose,
	tcp_port,
	is_optional,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM device_type_phys_port_templt_v53;

INSERT INTO audit.device_type_phys_port_templt (
	port_name,
	device_type_id,
	port_type,
	description,
	port_medium,		-- new column (port_medium)
	port_plug_style,		-- new column (port_plug_style)
	port_protocol,		-- new column (port_protocol)
	port_speed,		-- new column (port_speed)
	physical_label,
	port_purpose,
	tcp_port,
	is_optional,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	port_name,
	device_type_id,
	port_type,
	description,
	NULL,		-- new column (port_medium)
	NULL,		-- new column (port_plug_style)
	NULL,		-- new column (port_protocol)
	NULL,		-- new column (port_speed)
	physical_label,
	port_purpose,
	tcp_port,
	is_optional,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.device_type_phys_port_templt_v53;

ALTER TABLE device_type_phys_port_templt
	ALTER is_optional
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device_type_phys_port_templt ADD CONSTRAINT pk_device_type_phys_port_templ PRIMARY KEY (port_name, device_type_id);
-- INDEXES
CREATE INDEX xif5device_type_phys_port_temp ON device_type_phys_port_templt USING btree (port_medium, port_plug_style);
CREATE INDEX xif4device_type_phys_port_temp ON device_type_phys_port_templt USING btree (port_protocol);
CREATE INDEX xif6device_type_phys_port_temp ON device_type_phys_port_templt USING btree (port_speed);
CREATE INDEX xif3device_type_phys_port_temp ON device_type_phys_port_templt USING btree (port_type);

-- CHECK CONSTRAINTS
ALTER TABLE device_type_phys_port_templt ADD CONSTRAINT ckc_dvtyp_physp_tmp_opt
	CHECK (is_optional = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE device_type_phys_port_templt
	ADD CONSTRAINT fk_dt_phs_port_templt_port_typ
	FOREIGN KEY (port_type) REFERENCES val_port_type(port_type);
ALTER TABLE device_type_phys_port_templt
	ADD CONSTRAINT fk_devtype_ref_devtphysprttmpl
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);
ALTER TABLE device_type_phys_port_templt
	ADD CONSTRAINT fk_devtphyprttmpl_ref_vprtpurp
	FOREIGN KEY (port_purpose) REFERENCES val_port_purpose(port_purpose);
ALTER TABLE device_type_phys_port_templt
	ADD CONSTRAINT fk_dt_phsport_tmpl_v_port_medm
	FOREIGN KEY (port_medium, port_plug_style) REFERENCES val_port_medium(port_medium, port_plug_style);
ALTER TABLE device_type_phys_port_templt
	ADD CONSTRAINT fk_dt_phsport_tmp_val_prt_spd
	FOREIGN KEY (port_speed) REFERENCES val_port_speed(port_speed);
ALTER TABLE device_type_phys_port_templt
	ADD CONSTRAINT fk_dt_phsport_tmp_v_protocol
	FOREIGN KEY (port_protocol) REFERENCES val_port_protocol(port_protocol);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device_type_phys_port_templt');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device_type_phys_port_templt');
DROP TABLE device_type_phys_port_templt_v53;
DROP TABLE audit.device_type_phys_port_templt_v53;
-- DONE DEALING WITH TABLE device_type_phys_port_templt [862081]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE physical_port [433873]

-- FOREIGN KEYS FROM
alter table layer1_connection drop constraint fk_layer1_cnct_phys_port1;
alter table layer1_connection drop constraint fk_layer1_cnct_phys_port2;
alter table physical_connection drop constraint fk_patch_panel_port2;
alter table physical_connection drop constraint fk_patch_panel_port1;
alter table network_interface drop constraint IF EXISTS fk_network_int_phys_port;
alter table layer2_encapsulation drop constraint fk_l2encap_physport_id;

-- FOREIGN KEYS TO
alter table physical_port drop constraint fk_physport_dev_id;
alter table physical_port drop constraint fk_physical_fk_physic_val_port;
alter table physical_port drop constraint fk_phys_port_ref_vportpurp;
alter table physical_port drop constraint pk_physical_port;
alter table physical_port drop constraint ak_physical_port_devnamtype;
-- INDEXES
DROP INDEX idx_physport_device_id;
DROP INDEX idx_physport_porttype;
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
drop trigger trigger_audit_physical_port on physical_port;
drop trigger trig_userlog_physical_port on physical_port;


ALTER TABLE physical_port RENAME TO physical_port_v53;
ALTER TABLE audit.physical_port RENAME TO physical_port_v53;

CREATE TABLE physical_port
(
	physical_port_id	integer NOT NULL,
	device_id	integer NOT NULL,
	port_name	varchar(50) NOT NULL,
	port_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	port_plug_style	varchar(50)  NULL,
	port_medium	varchar(50)  NULL,
	port_protocol	varchar(50)  NULL,
	port_speed	varchar(50)  NULL,
	physical_label	varchar(50)  NULL,
	port_purpose	varchar(50)  NULL,
	tcp_port	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'physical_port', false);
INSERT INTO physical_port (
	physical_port_id,
	device_id,
	port_name,
	port_type,
	description,
	port_medium,		-- new column (port_medium)
	port_plug_style,	-- new column (port_plug_style)
	port_protocol,		-- new column (port_protocol)
	port_speed,		-- new column (port_speed)
	physical_label,
	port_purpose,
	tcp_port,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	physical_port_id,
	device_id,
	port_name,
	port_type,
	description,
	NULL,		-- new column (port_medium)
	NULL,		-- new column (port_plug_style)
	NULL,		-- new column (port_protocol)
	NULL,		-- new column (port_speed)
	physical_label,
	port_purpose,
	tcp_port,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM physical_port_v53;

INSERT INTO audit.physical_port (
	physical_port_id,
	device_id,
	port_name,
	port_type,
	description,
	port_medium,		-- new column (port_medium)
	port_plug_style,	-- new column (port_plug_style)
	port_protocol,		-- new column (port_protocol)
	port_speed,		-- new column (port_speed)
	physical_label,
	port_purpose,
	tcp_port,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	physical_port_id,
	device_id,
	port_name,
	port_type,
	description,
	NULL,		-- new column (port_medium)
	NULL,		-- new column (port_plug_style)
	NULL,		-- new column (port_protocol)
	NULL,		-- new column (port_speed)
	physical_label,
	port_purpose,
	tcp_port,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.physical_port_v53;

ALTER TABLE physical_port
	ALTER physical_port_id
	SET DEFAULT nextval('physical_port_physical_port_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE physical_port ADD CONSTRAINT pk_physical_port PRIMARY KEY (physical_port_id);
ALTER TABLE physical_port ADD CONSTRAINT ak_physical_port_devnamtype UNIQUE (device_id, port_name, port_type);
ALTER TABLE PHYSICAL_PORT
ADD CONSTRAINT  IAK_PPORT_DVID_PPORTID UNIQUE (PHYSICAL_PORT_ID,DEVICE_ID);

-- INDEXES
CREATE INDEX xif4physical_port ON physical_port USING btree (port_protocol);
CREATE INDEX idx_physport_device_id ON physical_port USING btree (device_id);
CREATE INDEX xif5physical_port ON physical_port USING btree (port_medium, port_plug_style);
CREATE INDEX xif6physical_port ON physical_port USING btree (port_speed);
CREATE INDEX idx_physport_porttype ON physical_port USING btree (port_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
ALTER TABLE layer1_connection
	ADD CONSTRAINT fk_layer1_cnct_phys_port1
	FOREIGN KEY (physical_port1_id) REFERENCES physical_port(physical_port_id);
ALTER TABLE layer1_connection
	ADD CONSTRAINT fk_layer1_cnct_phys_port2
	FOREIGN KEY (physical_port2_id) REFERENCES physical_port(physical_port_id);
ALTER TABLE physical_connection
	ADD CONSTRAINT fk_patch_panel_port2
	FOREIGN KEY (physical_port_id2) REFERENCES physical_port(physical_port_id);
ALTER TABLE physical_connection
	ADD CONSTRAINT fk_patch_panel_port1
	FOREIGN KEY (physical_port_id1) REFERENCES physical_port(physical_port_id);
ALTER TABLE network_interface
	ADD CONSTRAINT FK_NETWORK_INT_PHYS_PORT_DEVID
	FOREIGN KEY (physical_port_id, device_id) REFERENCES 
	physical_port(physical_port_id, device_id);
ALTER TABLE layer2_encapsulation
	ADD CONSTRAINT fk_l2encap_physport_id
	FOREIGN KEY (physical_port_id) REFERENCES physical_port(physical_port_id);

-- FOREIGN KEYS TO
ALTER TABLE physical_port
	ADD CONSTRAINT fk_phys_port_val_port_speed
	FOREIGN KEY (port_speed) REFERENCES val_port_speed(port_speed);
ALTER TABLE physical_port
	ADD CONSTRAINT fk_physical_fk_physic_val_port
	FOREIGN KEY (port_type) REFERENCES val_port_type(port_type);
ALTER TABLE physical_port
	ADD CONSTRAINT fk_phys_port_port_medium
	FOREIGN KEY (port_medium, port_plug_style) REFERENCES val_port_medium(port_medium, port_plug_style);
ALTER TABLE physical_port
	ADD CONSTRAINT fk_phys_port_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE physical_port
	ADD CONSTRAINT fk_phys_port_val_protocol
	FOREIGN KEY (port_protocol) REFERENCES val_port_protocol(port_protocol);
ALTER TABLE physical_port
	ADD CONSTRAINT fk_phys_port_ref_vportpurp
	FOREIGN KEY (port_purpose) REFERENCES val_port_purpose(port_purpose);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'physical_port');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'physical_port');
ALTER SEQUENCE physical_port_physical_port_id_seq
	 OWNED BY physical_port.physical_port_id;
DROP TABLE physical_port_v53;
DROP TABLE audit.physical_port_v53;
GRANT ALL ON physical_port TO jazzhands;
GRANT SELECT ON physical_port TO ro_role;
GRANT INSERT,UPDATE,DELETE ON physical_port TO iud_role;
-- DONE DEALING WITH TABLE physical_port [744862]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE val_network_interface_purpose [763243]
--------------------------------------------------------------------

-- a different fk is created later
alter table network_interface drop constraint fk_netint_netintprp_id;
alter table val_network_interface_purpose drop constraint pk_network_int_purpose;
ALTER TABLE val_network_interface_purpose 
	ADD CONSTRAINT pk_val_network_int_purpose 
	PRIMARY KEY (network_interface_purpose);

--------------------------------------------------------------------
-- DONE DEALING WITH TABLE val_network_interface_purpose [763243]
--------------------------------------------------------------------


CREATE TABLE network_interface_purpose
(
	device_id	integer NOT NULL,
	network_interface_purpose	varchar(50) NOT NULL,
	network_interface_id	integer  NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'network_interface_purpose', true);

-- PRIMARY AND ALTERNATE KEYS

ALTER TABLE network_interface_purpose ADD CONSTRAINT pk_network_int_purpose PRIMARY KEY (device_id, network_interface_purpose);
-- INDEXES
CREATE INDEX xif1network_interface_purpose ON network_interface_purpose USING btree (device_id);
CREATE INDEX xif2network_interface_purpose ON network_interface_purpose USING btree (network_interface_purpose);
CREATE INDEX xif3network_interface_purpose ON network_interface_purpose USING btree (network_interface_id, device_id);


-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- this is created later
--ALTER TABLE network_interface_purpose
--	ADD CONSTRAINT fk_netint_purpose_device_id
--	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- this is fixed later.
-- ALTER TABLE network_interface_purpose
-- 	ADD CONSTRAINT fk_netint_purp_dev_ni_id
-- 	FOREIGN KEY (network_interface_id, device_id) REFERENCES network_interface(network_interface_id, device_id);
ALTER TABLE network_interface_purpose
	ADD CONSTRAINT fk_netint_purpose_val_netint_p
	FOREIGN KEY (network_interface_purpose) 
	REFERENCES val_network_interface_purpose(network_interface_purpose);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'network_interface_purpose');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'network_interface_purpose');
-- DONE DEALING WITH TABLE network_interface_purpose [744656]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE network_interface [433648]

-- FOREIGN KEYS FROM
alter table static_route drop constraint fk_statrt_netintdst_id;
alter table static_route_template drop constraint fk_static_rt_net_interface;
alter table network_service drop constraint fk_netsvc_netint_id;
alter table dhcp_range drop constraint fk_dhcprng_netint_id;
alter table secondary_netblock drop constraint fk_secnblk_netint_id;

-- FOREIGN KEYS TO
alter table network_interface drop constraint fk_netint_netinttyp_id;
alter table network_interface drop constraint fk_netint_netblk_v6id;
alter table network_interface drop constraint fk_netint_netblk_v4id;
alter table network_interface drop constraint IF EXISTS fk_network_int_phys_port;
alter table network_interface drop constraint IF EXISTS fk_netint_netintprp_id;
alter table network_interface drop constraint fk_netint_device_id;
alter table network_interface drop constraint fk_netint_ref_parentnetint;
alter table network_interface drop constraint fk_netint_devid_name;
alter table network_interface drop constraint pk_network_interface_id;
-- INDEXES
DROP INDEX ix_netint_typeid;
DROP INDEX idx_netint_shouldmange;
DROP INDEX ix_netint_purpid;
DROP INDEX idx_netint_provides_dhcp;
DROP INDEX idx_netint_isprimary;
DROP INDEX ix_netint_prim_v4id;
DROP INDEX ix_netint_netdev_id;
DROP INDEX idx_netint_providesnat;
DROP INDEX idx_netint_parentnetint;
DROP INDEX ix_netint_prim_v6id;
DROP INDEX idx_netint_shouldmonitor;
DROP INDEX idx_netint_ismgmtinterface;
DROP INDEX idx_netint_isifaceup;
-- CHECK CONSTRAINTS, etc
alter table network_interface drop constraint ckc_should_manage_network_;
alter table network_interface drop constraint ckc_is_management_int_network_;
alter table network_interface drop constraint ckc_is_primary_network_;
alter table network_interface drop constraint ckc_provides_dhcp_network_;
alter table network_interface drop constraint ckc_provides_nat_network_;
alter table network_interface drop constraint ckc_is_interface_up_network_;
-- TRIGGERS, etc
drop trigger trigger_audit_network_interface on network_interface;
drop trigger trig_userlog_network_interface on network_interface;


ALTER TABLE network_interface RENAME TO network_interface_v53;
ALTER TABLE audit.network_interface RENAME TO network_interface_v53;

CREATE TABLE network_interface
(
	network_interface_id	integer NOT NULL,
	device_id	integer NOT NULL,
	network_interface_name	varchar(255)  NULL,
	description	varchar(255)  NULL,
	parent_network_interface_id	integer  NULL,
	parent_relation_type	varchar(255)  NULL,
	netblock_id	integer NOT NULL,
	physical_port_id	integer  NULL,
	network_interface_type	varchar(50) NOT NULL,
	is_interface_up	character(1) NOT NULL,
	mac_addr	macaddr  NULL,
	should_monitor	varchar(255) NOT NULL,
	provides_nat	character(1) NOT NULL,
	should_manage	character(1) NOT NULL,
	provides_dhcp	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'network_interface', false);
INSERT INTO network_interface (
	network_interface_id,
	device_id,
	network_interface_name,		-- new column (network_interface_name)
	description,
	parent_network_interface_id,
	parent_relation_type,		-- new column (parent_relation_type)
	netblock_id,		-- new column (netblock_id)
	physical_port_id,
	network_interface_type,
	is_interface_up,
	mac_addr,
	should_monitor,
	provides_nat,
	should_manage,
	provides_dhcp,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	network_interface_id,
	device_id,
	name,		-- new column (network_interface_name)
	description,
	parent_network_interface_id,
	NULL,		-- new column (parent_relation_type)
	v4_netblock_id,		-- new column (netblock_id)
	physical_port_id,
	network_interface_type,
	is_interface_up,
	mac_addr,
	should_monitor,
	provides_nat,
	should_manage,
	provides_dhcp,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM network_interface_v53 where v4_netblock_id is not NULL;

INSERT INTO audit.network_interface (
	network_interface_id,
	device_id,
	network_interface_name,		-- new column (network_interface_name)
	description,
	parent_network_interface_id,
	parent_relation_type,		-- new column (parent_relation_type)
	netblock_id,		-- new column (netblock_id)
	physical_port_id,
	network_interface_type,
	is_interface_up,
	mac_addr,
	should_monitor,
	provides_nat,
	should_manage,
	provides_dhcp,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	network_interface_id,
	device_id,
	name,		-- new column (network_interface_name)
	description,
	parent_network_interface_id,
	NULL,		-- new column (parent_relation_type)
	v4_netblock_id,		-- new column (netblock_id)
	physical_port_id,
	network_interface_type,
	is_interface_up,
	mac_addr,
	should_monitor,
	provides_nat,
	should_manage,
	provides_dhcp,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.network_interface_v53 where v4_netblock_id is not NULL;

INSERT INTO network_interface (
	network_interface_id,
	device_id,
	network_interface_name,		-- new column (network_interface_name)
	description,
	parent_network_interface_id,
	parent_relation_type,		-- new column (parent_relation_type)
	netblock_id,		-- new column (netblock_id)
	physical_port_id,
	network_interface_type,
	is_interface_up,
	mac_addr,
	should_monitor,
	provides_nat,
	should_manage,
	provides_dhcp,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	network_interface_id,
	device_id,
	name,		-- new column (network_interface_name)
	description,
	parent_network_interface_id,
	NULL,		-- new column (parent_relation_type)
	v6_netblock_id,		-- new column (netblock_id)
	physical_port_id,
	network_interface_type,
	is_interface_up,
	mac_addr,
	should_monitor,
	provides_nat,
	should_manage,
	provides_dhcp,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM network_interface_v53 where v6_netblock_id is not NULL;

INSERT INTO audit.network_interface (
	network_interface_id,
	device_id,
	network_interface_name,		-- new column (network_interface_name)
	description,
	parent_network_interface_id,
	parent_relation_type,		-- new column (parent_relation_type)
	netblock_id,		-- new column (netblock_id)
	physical_port_id,
	network_interface_type,
	is_interface_up,
	mac_addr,
	should_monitor,
	provides_nat,
	should_manage,
	provides_dhcp,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	network_interface_id,
	device_id,
	name,		-- new column (network_interface_name)
	description,
	parent_network_interface_id,
	NULL,		-- new column (parent_relation_type)
	v6_netblock_id,		-- new column (netblock_id)
	physical_port_id,
	network_interface_type,
	is_interface_up,
	mac_addr,
	should_monitor,
	provides_nat,
	should_manage,
	provides_dhcp,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.network_interface_v53 where v6_netblock_id is not NULL;

ALTER TABLE network_interface
	ALTER network_interface_id
	SET DEFAULT nextval('network_interface_network_interface_id_seq'::regclass);
ALTER TABLE network_interface
	ALTER is_interface_up
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE network_interface
	ALTER provides_nat
	SET DEFAULT 'N'::bpchar;
ALTER TABLE network_interface
	ALTER should_manage
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE network_interface
	ALTER provides_dhcp
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE network_interface ADD CONSTRAINT ak_net_int_devid_netintid UNIQUE (network_interface_id, device_id);
ALTER TABLE network_interface ADD CONSTRAINT fk_netint_devid_name UNIQUE (device_id, network_interface_name);
ALTER TABLE network_interface ADD CONSTRAINT pk_network_interface_id PRIMARY KEY (network_interface_id);
-- INDEXES
CREATE INDEX ix_netint_typeid ON network_interface USING btree (network_interface_type);
CREATE INDEX idx_netint_shouldmange ON network_interface USING btree (should_manage);
CREATE INDEX idx_netint_provides_dhcp ON network_interface USING btree (provides_dhcp);
CREATE INDEX ix_netint_prim_v4id ON network_interface USING btree (netblock_id);
CREATE INDEX ix_netint_netdev_id ON network_interface USING btree (device_id);
CREATE INDEX idx_netint_providesnat ON network_interface USING btree (provides_nat);
CREATE INDEX idx_netint_parentnetint ON network_interface USING btree (parent_network_interface_id);
CREATE INDEX idx_netint_shouldmonitor ON network_interface USING btree (should_monitor);
CREATE INDEX idx_netint_isifaceup ON network_interface USING btree (is_interface_up);
CREATE  INDEX XIF8NETWORK_INTERFACE ON NETWORK_INTERFACE USING btree
	(PHYSICAL_PORT_ID,DEVICE_ID);

-- CHECK CONSTRAINTS
ALTER TABLE network_interface ADD CONSTRAINT ckc_should_manage_network_
	CHECK ((should_manage = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((should_manage)::text = upper((should_manage)::text)));
ALTER TABLE network_interface ADD CONSTRAINT ckc_netint_parent_r_1604677531
	CHECK ((parent_relation_type)::text = ANY ((ARRAY['NONE'::character varying, 'SUBINTERFACE'::character varying, 'SECONDARY'::character varying])::text[]));
ALTER TABLE network_interface ADD CONSTRAINT ckc_provides_dhcp_network_
	CHECK ((provides_dhcp = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((provides_dhcp)::text = upper((provides_dhcp)::text)));
ALTER TABLE network_interface ADD CONSTRAINT ckc_provides_nat_network_
	CHECK ((provides_nat = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((provides_nat)::text = upper((provides_nat)::text)));
ALTER TABLE network_interface ADD CONSTRAINT ckc_is_interface_up_network_
	CHECK ((is_interface_up = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_interface_up)::text = upper((is_interface_up)::text)));

-- FOREIGN KEYS FROM
-- fixed later
--ALTER TABLE ip_group_network_interface
--	ADD CONSTRAINT fk_ipgrp_netint_netint_id
--	FOREIGN KEY (network_interface_id) REFERENCES network_interface(network_interface_id);
ALTER TABLE static_route
	ADD CONSTRAINT fk_statrt_netintdst_id
	FOREIGN KEY (network_interface_dst_id) REFERENCES network_interface(network_interface_id);
ALTER TABLE static_route_template
	ADD CONSTRAINT fk_static_rt_net_interface
	FOREIGN KEY (network_interface_dst_id) REFERENCES network_interface(network_interface_id);
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_netint_id
	FOREIGN KEY (network_interface_id) REFERENCES network_interface(network_interface_id);
ALTER TABLE network_interface_purpose
	ADD CONSTRAINT fk_netint_purp_dev_ni_id
	FOREIGN KEY (network_interface_id, device_id) REFERENCES network_interface(network_interface_id, device_id);
ALTER TABLE dhcp_range
	ADD CONSTRAINT fk_dhcprng_netint_id
	FOREIGN KEY (network_interface_id) REFERENCES network_interface(network_interface_id);
ALTER TABLE secondary_netblock
	ADD CONSTRAINT fk_secnblk_netint_id
	FOREIGN KEY (network_interface_id) REFERENCES network_interface(network_interface_id);

-- FOREIGN KEYS TO
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_netinttyp_id
	FOREIGN KEY (network_interface_type) REFERENCES val_network_interface_type(network_interface_type);
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_netblk_v4id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_ref_parentnetint
	FOREIGN KEY (parent_network_interface_id) REFERENCES network_interface(network_interface_id);
ALTER TABLE ONLY network_interface
	ADD CONSTRAINT fk_network_int_phys_port_devid 
	FOREIGN KEY (physical_port_id, device_id) 
	REFERENCES physical_port(physical_port_id, device_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'network_interface');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'network_interface');
ALTER SEQUENCE network_interface_network_interface_id_seq
	 OWNED BY network_interface.network_interface_id;
DROP TABLE network_interface_v53;
DROP TABLE audit.network_interface_v53;
GRANT ALL ON network_interface TO jazzhands;
GRANT SELECT ON network_interface TO ro_role;
GRANT INSERT,UPDATE,DELETE ON network_interface TO iud_role;
-- DONE DEALING WITH TABLE network_interface [744625]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE layer2_encapsulation [433574]

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
alter table layer2_encapsulation drop constraint fk_l2encap_encap_id;
alter table layer2_encapsulation drop constraint fk_l2encap_physport_id;
alter table layer2_encapsulation drop constraint ak_uq_layer2_encapsul_layer2_e;
alter table layer2_encapsulation drop constraint sys_c002636;
-- INDEXES
DROP INDEX idx_l2encaps_encapsid;
DROP INDEX idx_l2encaps_physport;
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
drop trigger trig_userlog_layer2_encapsulation on layer2_encapsulation;
drop trigger trigger_audit_layer2_encapsulation on layer2_encapsulation;


ALTER TABLE layer2_encapsulation RENAME TO layer2_encapsulation_v53;
ALTER TABLE audit.layer2_encapsulation RENAME TO layer2_encapsulation_v53;

CREATE TABLE layer2_encapsulation
(
	layer2_encapsulation_id	integer NOT NULL,
	layer2_encapsulation_type	character(18)  NULL,
	physical_port_id	integer NOT NULL,
	encapsulation_id	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'layer2_encapsulation', false);
INSERT INTO layer2_encapsulation (
	layer2_encapsulation_id,
	layer2_encapsulation_type,		-- new column (layer2_encapsulation_type)
	physical_port_id,
	encapsulation_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	layer2_encapsulation_id,
	NULL,		-- new column (layer2_encapsulation_type)
	physical_port_id,
	encapsulation_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM layer2_encapsulation_v53;

INSERT INTO audit.layer2_encapsulation (
	layer2_encapsulation_id,
	layer2_encapsulation_type,		-- new column (layer2_encapsulation_type)
	physical_port_id,
	encapsulation_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	layer2_encapsulation_id,
	NULL,		-- new column (layer2_encapsulation_type)
	physical_port_id,
	encapsulation_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.layer2_encapsulation_v53;

ALTER TABLE layer2_encapsulation
	ALTER layer2_encapsulation_id
	SET DEFAULT nextval('layer2_encapsulation_layer2_encapsulation_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE layer2_encapsulation ADD CONSTRAINT ak_uq_layer2_encapsul_layer2_e UNIQUE (physical_port_id, encapsulation_id);
ALTER TABLE layer2_encapsulation ADD CONSTRAINT pk_layer2_encapsulation PRIMARY KEY (layer2_encapsulation_id);
-- INDEXES
CREATE INDEX idx_l2encaps_encapsid ON layer2_encapsulation USING btree (encapsulation_id);
CREATE INDEX xif3layer2_encapsulation ON layer2_encapsulation USING btree (layer2_encapsulation_type);
CREATE INDEX idx_l2encaps_physport ON layer2_encapsulation USING btree (physical_port_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE layer2_encapsulation
	ADD CONSTRAINT fk_l2encap_encap_id
	FOREIGN KEY (encapsulation_id) REFERENCES encapsulation(encapsulation_id);
ALTER TABLE layer2_encapsulation
	ADD CONSTRAINT fk_l2_encap_val_l2encap_type
	FOREIGN KEY (layer2_encapsulation_type) REFERENCES val_layer2_encapsulation_type(layer2_encapsulation_type);
ALTER TABLE layer2_encapsulation
	ADD CONSTRAINT fk_l2encap_physport_id
	FOREIGN KEY (physical_port_id) REFERENCES physical_port(physical_port_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'layer2_encapsulation');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'layer2_encapsulation');
ALTER SEQUENCE layer2_encapsulation_layer2_encapsulation_id_seq
	 OWNED BY layer2_encapsulation.layer2_encapsulation_id;
DROP TABLE layer2_encapsulation_v53;
DROP TABLE audit.layer2_encapsulation_v53;
GRANT ALL ON layer2_encapsulation TO jazzhands;
GRANT SELECT ON layer2_encapsulation TO ro_role;
GRANT INSERT,UPDATE,DELETE ON layer2_encapsulation TO iud_role;
-- DONE DEALING WITH TABLE layer2_encapsulation [744548]
--------------------------------------------------------------------
CREATE TABLE ip_group
(
	ip_group_id	integer NOT NULL,
	ip_group_protocol	character(18) NOT NULL,
	netblock_collection_id	integer NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'ip_group', true);

CREATE SEQUENCE ip_group_ip_group_id_seq;
ALTER TABLE ip_group
        ALTER ip_group_id
        SET DEFAULT nextval('ip_group_ip_group_id_seq'::regclass);
ALTER SEQUENCE ip_group_ip_group_id_seq
	 OWNED BY ip_group.ip_group_id;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE ip_group ADD CONSTRAINT pk_ip_group PRIMARY KEY (ip_group_id);
-- INDEXES
CREATE INDEX xif2ip_group ON ip_group USING btree (netblock_collection_id);
CREATE INDEX xif1ip_group ON ip_group USING btree (ip_group_protocol);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- fixed later
--ALTER TABLE ip_group_network_interface
--	ADD CONSTRAINT fk_ip_grp_netint_ip_grp_id
--	FOREIGN KEY (ip_group_id) REFERENCES ip_group(ip_group_id);

-- FOREIGN KEYS TO
ALTER TABLE ip_group
	ADD CONSTRAINT fk_ip_grp_ip_grp_proto
	FOREIGN KEY (ip_group_protocol) REFERENCES val_ip_group_protocol(ip_group_protocol);
ALTER TABLE ip_group
	ADD CONSTRAINT fk_ip_proto_netblk_coll_id
	FOREIGN KEY (netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'ip_group');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'ip_group');
-- DONE DEALING WITH TABLE ip_group [744479]
--------------------------------------------------------------------
CREATE TABLE ip_group_network_interface
(
	ip_group_id	integer NOT NULL,
	network_interface_id	integer NOT NULL,
	priority	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'ip_group_network_interface', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE ip_group_network_interface ADD CONSTRAINT pk_ip_group_network_interface PRIMARY KEY (ip_group_id, network_interface_id);
-- INDEXES
CREATE INDEX xif2ip_group_network_interface ON ip_group_network_interface USING btree (network_interface_id);
CREATE INDEX xif1ip_group_network_interface ON ip_group_network_interface USING btree (ip_group_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE ip_group_network_interface
	ADD CONSTRAINT fk_ipgrp_netint_netint_id
	FOREIGN KEY (network_interface_id) REFERENCES network_interface(network_interface_id);
ALTER TABLE ip_group_network_interface
	ADD CONSTRAINT fk_ip_grp_netint_ip_grp_id
	FOREIGN KEY (ip_group_id) REFERENCES ip_group(ip_group_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'ip_group_network_interface');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'ip_group_network_interface');
-- DONE DEALING WITH TABLE ip_group_network_interface [744486]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE rack [433929]

-- FOREIGN KEYS FROM
alter table location drop constraint fk_location_ref_rack;

-- FOREIGN KEYS TO
alter table rack drop constraint fk_site_rack;
alter table rack drop constraint pk_rack_id;
alter table rack drop constraint ak_uq_site_room_sub_r_rack;
-- INDEXES
-- CHECK CONSTRAINTS, etc
alter table rack drop constraint ckc_display_from_bott_rack;
alter table rack drop constraint ckc_rack_type_rack;
-- TRIGGERS, etc
drop trigger trigger_audit_rack on rack;
drop trigger trig_userlog_rack on rack;


ALTER TABLE rack RENAME TO rack_v53;
ALTER TABLE audit.rack RENAME TO rack_v53;

CREATE TABLE rack
(
	rack_id	integer NOT NULL,
	site_code	varchar(50) NOT NULL,
	room	varchar(50)  NULL,
	sub_room	varchar(50)  NULL,
	rack_row	varchar(50)  NULL,
	rack_name	varchar(50)  NOT NULL,
	rack_style	varchar(50) NOT NULL,
	rack_type	varchar(255)  NULL,
	description	varchar(255)  NULL,
	rack_height_in_u	integer NOT NULL,
	display_from_bottom	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'rack', false);
INSERT INTO rack (
	rack_id,
	site_code,
	room,
	sub_room,
	rack_row,
	rack_name,
	rack_style,		-- new column (rack_style)
	rack_type,
	description,		-- new column (description)
	rack_height_in_u,
	display_from_bottom,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	rack_id,
	site_code,
	room,
	sub_room,
	rack_row,
	rack_name,
	rack_type,		-- new column (rack_style)
	NULL,
	NULL,		-- new column (description)
	rack_height_in_u,
	display_from_bottom,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM rack_v53;

INSERT INTO audit.rack (
	rack_id,
	site_code,
	room,
	sub_room,
	rack_row,
	rack_name,
	rack_style,		-- new column (rack_style)
	rack_type,
	description,		-- new column (description)
	rack_height_in_u,
	display_from_bottom,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	rack_id,
	site_code,
	room,
	sub_room,
	rack_row,
	rack_name,
	rack_type,		-- new column (rack_style)
	NULL,
	NULL,		-- new column (description)
	rack_height_in_u,
	display_from_bottom,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.rack_v53;

ALTER TABLE rack
	ALTER rack_id
	SET DEFAULT nextval('rack_rack_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE rack ADD CONSTRAINT pk_rack_id PRIMARY KEY (rack_id);
ALTER TABLE rack ADD CONSTRAINT ak_uq_site_room_sub_r_rack UNIQUE (site_code, room, sub_room, rack_row, rack_name);
-- INDEXES
CREATE INDEX xif2rack ON rack USING btree (rack_type);

-- CHECK CONSTRAINTS
ALTER TABLE rack ADD CONSTRAINT ckc_display_from_bott_rack
	CHECK ((display_from_bottom = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((display_from_bottom)::text = upper((display_from_bottom)::text)));
ALTER TABLE rack ADD CONSTRAINT ckc_rack_style_rack CHECK ((((rack_style)::text = ANY ((ARRAY['RELAY'::character varying, 'CABINET'::character varying])::text[])) AND ((rack_type)::text = upper((rack_style)::text))));



-- FOREIGN KEYS FROM
ALTER TABLE location
	ADD CONSTRAINT fk_location_ref_rack
	FOREIGN KEY (rack_id) REFERENCES rack(rack_id);

-- FOREIGN KEYS TO
ALTER TABLE rack
	ADD CONSTRAINT fk_site_rack
	FOREIGN KEY (site_code) REFERENCES site(site_code);
ALTER TABLE rack
	ADD CONSTRAINT fk_rack_v_rack_type
	FOREIGN KEY (rack_type) REFERENCES val_rack_type(rack_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'rack');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'rack');
ALTER SEQUENCE rack_rack_id_seq
	 OWNED BY rack.rack_id;
DROP TABLE rack_v53;
DROP TABLE audit.rack_v53;
GRANT ALL ON rack TO jazzhands;
GRANT SELECT ON rack TO ro_role;
GRANT INSERT,UPDATE,DELETE ON rack TO iud_role;
-- DONE DEALING WITH TABLE rack [744921]
--------------------------------------------------------------------
CREATE TABLE device_management_controller
(
	manager_device_id	integer NOT NULL,
	device_id	integer NOT NULL,
	device_mgmt_control_type	varchar(255) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'device_management_controller', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device_management_controller ADD CONSTRAINT pk_device_management_controlle PRIMARY KEY (manager_device_id, device_id);
-- INDEXES
CREATE INDEX xif2device_management_controll ON device_management_controller USING btree (device_id);
CREATE INDEX xif3device_management_controll ON device_management_controller USING btree (device_mgmt_control_type);
CREATE INDEX xif1device_management_controll ON device_management_controller USING btree (manager_device_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- added later
--ALTER TABLE device_management_controller
--	ADD CONSTRAINT fk_dev_mgmt_ctlr_dev_id
--	FOREIGN KEY (device_id) REFERENCES device(device_id);
--ALTER TABLE device_management_controller
--	ADD CONSTRAINT fk_dvc_mgmt_ctrl_mgr_dev_id
--	FOREIGN KEY (manager_device_id) REFERENCES device(device_id);
ALTER TABLE device_management_controller
	ADD CONSTRAINT fk_dev_mgmt_cntrl_val_ctrl_typ
	FOREIGN KEY (device_mgmt_control_type) REFERENCES val_device_mgmt_ctrl_type(device_mgmt_control_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device_management_controller');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device_management_controller');
-- DONE DEALING WITH TABLE device_management_controller [744312]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE device [433295]

-- FOREIGN KEYS FROM
alter table physical_port drop constraint fk_phys_port_dev_id;
alter table network_service drop constraint fk_netsvc_device_id;
alter table device_ssh_key drop constraint fk_dev_ssh_key_ssh_key_id;
alter table device_collection_device drop constraint fk_devcolldev_dev_id;
alter table device_power_interface drop constraint fk_device_device_power_supp;
alter table layer1_connection drop constraint fk_l1conn_ref_device;
alter table device_ticket drop constraint fk_dev_tkt_dev_id;
alter table snmp_commstr drop constraint fk_snmpstr_device_id;
alter table device_note drop constraint fk_device_note_device;
alter table network_interface drop constraint fk_netint_device_id;
alter table static_route drop constraint fk_statrt_devsrc_id;

-- FOREIGN KEYS TO
alter table device drop constraint fk_device_dnsrecord;
alter table device drop constraint fk_device_vownerstatus;
alter table device drop constraint fk_device_ref_parent_device;
alter table device drop constraint fk_device_ref_voesymbtrk;
alter table device drop constraint fk_device_reference_val_devi;
alter table device drop constraint fk_dev_devtp_id;
alter table device drop constraint fk_device_fk_dev_v_svcenv;
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
DROP INDEX idx_dev_svcenv;
DROP INDEX idx_dev_iddnsrec;
DROP INDEX idx_dev_dev_status;
DROP INDEX idx_dev_locationid;
DROP INDEX idx_dev_osid;
DROP INDEX xifdevice_sitecode;
-- CHECK CONSTRAINTS, etc
alter table device drop constraint ckc_is_locally_manage_device;
alter table device drop constraint sys_c0069052;
alter table device drop constraint ckc_is_monitored_device;
alter table device drop constraint sys_c0069060;
alter table device drop constraint sys_c0069056;
alter table device drop constraint sys_c0069054;
alter table device drop constraint sys_c0069057;
alter table device drop constraint sys_c0069055;
alter table device drop constraint ckc_is_baselined_device;
alter table device drop constraint ckc_should_fetch_conf_device;
alter table device drop constraint sys_c0069051;
alter table device drop constraint ckc_is_virtual_device_device;
alter table device drop constraint sys_c0069059;
alter table device drop constraint sys_c0069061;
-- TRIGGERS, etc
drop trigger trigger_verify_device_voe on device;
drop trigger trigger_audit_device on device;
drop trigger trig_userlog_device on device;


ALTER TABLE device RENAME TO device_v53;
ALTER TABLE audit.device RENAME TO device_v53;

CREATE TABLE device
(
	device_id	integer NOT NULL,
	device_type_id	integer NOT NULL,
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
	device_status	varchar(50) NOT NULL,
	service_environment	varchar(50) NOT NULL,
	operating_system_id	integer NOT NULL,
	voe_id	integer  NULL,
	ownership_status	varchar(50) NOT NULL,
	auto_mgmt_protocol	varchar(50)  NULL,
	voe_symbolic_track_id	integer  NULL,
	is_locally_managed	character(1) NOT NULL,
	is_monitored	character(1) NOT NULL,
	is_virtual_device	character(1) NOT NULL,
	should_fetch_config	character(1) NOT NULL,
	is_baselined	character(1) NOT NULL,
	lease_expiration_date	timestamp with time zone  NULL,
	date_in_service	timestamp with time zone  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'device', false);
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
	lease_expiration_date,		-- new column (lease_expiration_date)
	date_in_service,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
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
	NULL,		-- new column (lease_expiration_date)
	date_in_service,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM device_v53;

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
	lease_expiration_date,		-- new column (lease_expiration_date)
	date_in_service,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
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
	NULL,		-- new column (lease_expiration_date)
	date_in_service,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.device_v53;

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
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE network_interface_purpose
	ADD CONSTRAINT fk_netint_purpose_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE device_ssh_key
	ADD CONSTRAINT fk_dev_ssh_key_ssh_key_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE device_collection_device
	ADD CONSTRAINT fk_devcolldev_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE device_power_interface
	ADD CONSTRAINT fk_device_device_power_supp
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE layer1_connection
	ADD CONSTRAINT fk_l1conn_ref_device
	FOREIGN KEY (tcpsrv_device_id) REFERENCES device(device_id);
ALTER TABLE device_management_controller
	ADD CONSTRAINT fk_dev_mgmt_ctlr_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE device_ticket
	ADD CONSTRAINT fk_dev_tkt_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE device_management_controller
	ADD CONSTRAINT fk_dvc_mgmt_ctrl_mgr_dev_id
	FOREIGN KEY (manager_device_id) REFERENCES device(device_id);
ALTER TABLE snmp_commstr
	ADD CONSTRAINT fk_snmpstr_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
ALTER TABLE physical_port
	ADD CONSTRAINT fk_phys_port_dev_id
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
	FOREIGN KEY (site_code) REFERENCES site(site_code);
ALTER TABLE device
	ADD CONSTRAINT fk_device_fk_dev_val_stat
	FOREIGN KEY (device_status) REFERENCES val_device_status(device_status);
ALTER TABLE device
	ADD CONSTRAINT fk_dev_os_id
	FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id);
ALTER TABLE device
	ADD CONSTRAINT fk_dev_location_id
	FOREIGN KEY (location_id) REFERENCES location(location_id);
ALTER TABLE device
	ADD CONSTRAINT fk_device_fk_voe
	FOREIGN KEY (voe_id) REFERENCES voe(voe_id);

-- TRIGGERS
CREATE TRIGGER trigger_verify_device_voe 
	BEFORE INSERT OR UPDATE ON device 
	FOR EACH ROW EXECUTE PROCEDURE verify_device_voe();

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device');
ALTER SEQUENCE device_device_id_seq
	 OWNED BY device.device_id;
DROP TABLE device_v53;
DROP TABLE audit.device_v53;
GRANT ALL ON device TO jazzhands;
GRANT SELECT ON device TO ro_role;
GRANT INSERT,UPDATE,DELETE ON device TO iud_role;
-- DONE DEALING WITH TABLE device [744232]
--------------------------------------------------------------------

CREATE TABLE service_environment_collection
(
	service_env_collection_id	integer NOT NULL,
	service_env_collection_name	varchar(50) NOT NULL,
	service_env_collection_type	varchar(50)  NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'service_environment_collection', true);

CREATE SEQUENCE service_environment_collection_service_env_collection_id_seq;
ALTER TABLE service_environment_collection
        ALTER service_env_collection_id
        SET DEFAULT nextval('service_environment_collection_service_env_collection_id_seq'::regclass);

ALTER SEQUENCE service_environment_collection_service_env_collection_id_seq
	 OWNED BY service_environment_collection.service_env_collection_id;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE service_environment_collection ADD CONSTRAINT pk_service_environment_collect PRIMARY KEY (service_env_collection_id);
ALTER TABLE service_environment_collection ADD CONSTRAINT ak_val_svc_env_name_type UNIQUE (service_env_collection_name, service_env_collection_type);
-- INDEXES
CREATE INDEX xif1service_environment_collec ON service_environment_collection USING btree (service_env_collection_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- fixed later
--ALTER TABLE svc_environment_coll_svc_env
--	ADD CONSTRAINT fk_svc_env_coll_svc_coll_id
--	FOREIGN KEY (service_env_collection_id) REFERENCES service_environment_collection(service_env_collection_id);
--ALTER TABLE property
--	ADD CONSTRAINT FK_PROP_SVC_ENV_COLL_ID
--	FOREIGN KEY (service_env_collection_id) REFERENCES service_environment_collection(service_env_collection_id);
--ALTER TABLE service_environment_coll_hier
--	ADD CONSTRAINT fk_svcenv_coll_child_svccollid
--	FOREIGN KEY (child_service_env_coll_id) REFERENCES service_environment_collection(service_env_collection_id);
-- ALTER TABLE service_environment_coll_hier
--	ADD CONSTRAINT fk_svc_env_hier_svc_env_coll_i
--	FOREIGN KEY (service_env_collection_id) REFERENCES service_environment_collection(service_env_collection_id);

-- FOREIGN KEYS TO
-- ALTER TABLE service_environment_collection
-- 	ADD CONSTRAINT fk_svc_env_col_v_svc_env_type
-- 	FOREIGN KEY (service_env_collection_type) REFERENCES val_service_env_coll_type(service_env_collection_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'service_environment_collection');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'service_environment_collection');
-- DONE DEALING WITH TABLE service_environment_collection [744946]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE service_environment_coll_hier []
CREATE TABLE service_environment_coll_hier
(
	service_env_collection_id	integer NOT NULL,
	child_service_env_coll_id	integer NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'service_environment_coll_hier', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE service_environment_coll_hier ADD CONSTRAINT pk_service_environment_hier PRIMARY KEY (service_env_collection_id, child_service_env_coll_id);
-- INDEXES
CREATE INDEX xif2service_environment_coll_h ON service_environment_coll_hier USING btree (service_env_collection_id);
CREATE INDEX xif1service_environment_coll_h ON service_environment_coll_hier USING btree (child_service_env_coll_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE service_environment_coll_hier
	ADD CONSTRAINT fk_svcenv_coll_child_svccollid
	FOREIGN KEY (child_service_env_coll_id) REFERENCES service_environment_collection(service_env_collection_id);
ALTER TABLE service_environment_coll_hier
	ADD CONSTRAINT fk_svc_env_hier_svc_env_coll_i
	FOREIGN KEY (service_env_collection_id) REFERENCES service_environment_collection(service_env_collection_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'service_environment_coll_hier');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'service_environment_coll_hier');
-- DONE DEALING WITH TABLE service_environment_coll_hier [171000]
--------------------------------------------------------------------

--------------------------------------------------------------------
CREATE TABLE svc_environment_coll_svc_env
(
	service_environment	varchar(50) NOT NULL,
	service_env_collection_id	integer NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'svc_environment_coll_svc_env', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE svc_environment_coll_svc_env ADD CONSTRAINT pk_svc_environment_coll_svc_en PRIMARY KEY (service_environment, service_env_collection_id);
-- INDEXES
CREATE INDEX xif2svc_environment_coll_svc_e ON svc_environment_coll_svc_env USING btree (service_env_collection_id);
CREATE INDEX xif1svc_environment_coll_svc_e ON svc_environment_coll_svc_env USING btree (service_environment);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE svc_environment_coll_svc_env
	ADD CONSTRAINT fk_svc_env_coll_svc_coll_id
	FOREIGN KEY (service_env_collection_id) REFERENCES service_environment_collection(service_env_collection_id);
-- added for realz later
--ALTER TABLE svc_environment_coll_svc_env
--	ADD CONSTRAINT fk_svc_env_col_svc_env
--	FOREIGN KEY (service_environment) REFERENCES val_service_environment(service_environment);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'svc_environment_coll_svc_env');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'svc_environment_coll_svc_env');
-- DONE DEALING WITH TABLE svc_environment_coll_svc_env [745045]
--------------------------------------------------------------------

CREATE TABLE val_service_env_coll_type
(
	service_env_collection_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_service_env_coll_type', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_service_env_coll_type ADD CONSTRAINT pk_val_service_env_coll_type PRIMARY KEY (service_env_collection_type);
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
ALTER TABLE service_environment_collection
	ADD CONSTRAINT fk_svc_env_col_v_svc_env_type
	FOREIGN KEY (service_env_collection_type) REFERENCES val_service_env_coll_type(service_env_collection_type);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_service_env_coll_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_service_env_coll_type');
-- DONE DEALING WITH TABLE val_service_env_coll_type [745650]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE val_service_environment [135878]

-- FOREIGN KEYS FROM
alter table network_service drop constraint fk_netsvc_csvcenv;
alter table device drop constraint fk_device_fk_dev_v_svcenv;
alter table appaal_instance drop constraint fk_appaal_i_fk_applic_svcenv;
alter table voe drop constraint fk_voe_ref_v_svcenv;
alter table sw_package_release drop constraint fk_sw_pkg_rel_ref_vsvcenv;
alter table sw_package drop constraint fk_sw_pkg_ref_v_prod_state;
alter table property drop constraint fk_property_svcenv;

-- FOREIGN KEYS TO
alter table val_service_environment drop constraint fk_val_svcenv_prodstate;
alter table val_service_environment drop constraint pk_val_service_environment;
-- INDEXES
DROP INDEX xif1val_service_environment;
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
drop trigger trig_userlog_val_service_environment on val_service_environment;
drop trigger trigger_audit_val_service_environment on val_service_environment;

drop function perform_audit_val_service_environment();

ALTER TABLE val_service_environment RENAME TO val_service_environment_v53;
ALTER TABLE audit.val_service_environment RENAME TO val_service_environment_v53;

CREATE TABLE service_environment
(
	service_environment	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	production_state	varchar(50) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
ALTER SEQUENCE audit.val_service_environment_seq RENAME TO service_environment_seq;
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'service_environment', false);
INSERT INTO service_environment (
	service_environment,
	description,
	production_state,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	service_environment,
	description,
	production_state,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_service_environment_v53;

INSERT INTO audit.service_environment (
	service_environment,
	description,
	production_state,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	service_environment,
	description,
	production_state,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_service_environment_v53;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE service_environment ADD CONSTRAINT pk_service_environment PRIMARY KEY (service_environment);
-- INDEXES
CREATE INDEX xif1service_environment ON service_environment USING btree (production_state);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
ALTER TABLE svc_environment_coll_svc_env
	ADD CONSTRAINT fk_svc_env_col_svc_env
	FOREIGN KEY (service_environment) REFERENCES service_environment(service_environment);
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_csvcenv
	FOREIGN KEY (service_environment) REFERENCES service_environment(service_environment);
ALTER TABLE device
	ADD CONSTRAINT fk_device_fk_dev_v_svcenv
	FOREIGN KEY (service_environment) REFERENCES service_environment(service_environment);
ALTER TABLE appaal_instance
	ADD CONSTRAINT fk_appaal_i_fk_applic_svcenv
	FOREIGN KEY (service_environment) REFERENCES service_environment(service_environment);
ALTER TABLE voe
	ADD CONSTRAINT fk_voe_ref_v_svcenv
	FOREIGN KEY (service_environment) REFERENCES service_environment(service_environment);
ALTER TABLE sw_package_release
	ADD CONSTRAINT fk_sw_pkg_rel_ref_vsvcenv
	FOREIGN KEY (service_environment) REFERENCES service_environment(service_environment);
ALTER TABLE sw_package
	ADD CONSTRAINT fk_sw_pkg_ref_v_prod_state
	FOREIGN KEY (production_state_restriction) REFERENCES service_environment(service_environment);

-- FOREIGN KEYS TO
ALTER TABLE service_environment
	ADD CONSTRAINT fk_val_svcenv_prodstate
	FOREIGN KEY (production_state) REFERENCES val_production_state(production_state);

-- TRIGGERS
--- XXX trigger: trigger_delete_per_svc_env_svc_env_collection
--- XXX trigger: trigger_update_per_svc_env_svc_env_collection
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'service_environment');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'service_environment');
DROP TABLE val_service_environment_v53;
DROP TABLE audit.val_service_environment_v53;
-- DONE DEALING WITH TABLE service_environment [127108]
--------------------------------------------------------------------


-- NOW...  Create service environment collections that would have been
-- previously setup by triggers that will get added later on here.
-- NOTE:  The update of property uses these.

insert into val_service_env_coll_type
	( service_env_collection_type ) values ('per-environment');

insert into service_environment_collection
	(service_env_collection_name, service_env_collection_type)
SELECT	service_environment, 'per-environment' AS type
  FROM	service_environment;

insert into svc_environment_coll_svc_env
	(service_environment, service_env_collection_id)
SELECT	service_env_collection_name, service_env_collection_id
 from	service_environment_collection
WHERE	service_env_collection_type = 'per-environment';


--------------------------------------------------------------------
-- DEALING WITH TABLE property [438512]

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
alter table property drop constraint fk_property_val_prsnid;
alter table property drop constraint fk_property_person_id;
alter table property drop constraint fk_property_site_code;
alter table property drop constraint fk_property_pval_compid;
alter table property drop constraint fk_property_osid;
alter table property drop constraint IF EXISTS fk_property_svcenv;
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
DROP INDEX xifprop_devcolid;
DROP INDEX xifprop_svcenv;
DROP INDEX xifprop_pval_compid;
-- CHECK CONSTRAINTS, etc
alter table property drop constraint ckc_prop_isenbld;
-- TRIGGERS, etc
drop trigger trigger_validate_property on property;
drop trigger trigger_audit_property on property;
drop trigger trig_userlog_property on property;


ALTER TABLE property RENAME TO property_v53;
ALTER TABLE audit.property RENAME TO property_v53;

CREATE TABLE property
(
	property_id	integer NOT NULL,
	account_collection_id	integer  NULL,
	account_id	integer  NULL,
	company_id	integer  NULL,
	device_collection_id	integer  NULL,
	dns_domain_id	integer  NULL,
	netblock_collection_id	integer  NULL,
	operating_system_id	integer  NULL,
	person_id	integer  NULL,
	service_env_collection_id	integer  NULL,
	site_code	varchar(50)  NULL,
	property_name	varchar(255) NOT NULL,
	property_type	varchar(50) NOT NULL,
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
	property_rank	integer  NULL,
	start_date	timestamp without time zone  NULL,
	finish_date	timestamp without time zone  NULL,
	is_enabled	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'property', false);
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
	service_env_collection_id,		-- new column (service_env_collection_id)
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
	property_rank,
	start_date,
	finish_date,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	property_id,
	account_collection_id,
	account_id,
	company_id,
	device_collection_id,
	dns_domain_id,
	netblock_collection_id,
	operating_system_id,
	person_id,
	(select service_env_collection_id
	  from  service_environment_collection
	 where  service_env_collection_name = service_environment
	  and   service_env_collection_type = 'per-environment'
	), 			-- new column (service_env_collection_id)
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
	property_rank,
	start_date,
	finish_date,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM property_v53;

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
	service_env_collection_id,		-- new column (service_env_collection_id)
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
	property_rank,
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
) SELECT
	property_id,
	account_collection_id,
	account_id,
	company_id,
	device_collection_id,
	dns_domain_id,
	netblock_collection_id,
	operating_system_id,
	person_id,
	(select service_env_collection_id
	  from  service_environment_collection
	 where  service_env_collection_name = service_environment
	  and   service_env_collection_type = 'per-environment'
	), 			-- new column (service_env_collection_id)
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
	property_rank,
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
FROM audit.property_v53;

ALTER TABLE property
	ALTER property_id
	SET DEFAULT nextval('property_property_id_seq'::regclass);
ALTER TABLE property
	ALTER is_enabled
	SET DEFAULT 'Y'::bpchar;

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
CREATE INDEX xifprop_pval_swpkgid ON property USING btree (property_value_sw_package_id);
CREATE INDEX xif21property ON property USING btree (service_env_collection_id);
CREATE INDEX xifprop_pval_acct_colid ON property USING btree (property_value_account_coll_id);
CREATE INDEX xifprop_devcolid ON property USING btree (device_collection_id);
CREATE INDEX xifprop_pval_compid ON property USING btree (property_value_company_id);

-- CHECK CONSTRAINTS
ALTER TABLE property ADD CONSTRAINT ckc_prop_isenbld
	CHECK (is_enabled = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE property
	ADD CONSTRAINT fk_property_val_prsnid
	FOREIGN KEY (property_value_person_id) REFERENCES person(person_id);
ALTER TABLE property
	ADD CONSTRAINT fk_property_person_id
	FOREIGN KEY (person_id) REFERENCES person(person_id);
ALTER TABLE property
	ADD CONSTRAINT fk_property_site_code
	FOREIGN KEY (site_code) REFERENCES site(site_code);
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_compid
	FOREIGN KEY (property_value_company_id) REFERENCES company(company_id);
ALTER TABLE property
	ADD CONSTRAINT fk_property_osid
	FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id);
ALTER TABLE property
	ADD CONSTRAINT fk_property_nblk_coll_id
	FOREIGN KEY (netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id);
ALTER TABLE property
	ADD CONSTRAINT fk_property_acct_col
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);
ALTER TABLE property
	ADD CONSTRAINT FK_PROP_SVC_ENV_COLL_ID
	FOREIGN KEY (service_env_collection_id) REFERENCES service_environment_collection(service_env_collection_id);
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_tokcolid
	FOREIGN KEY (property_value_token_col_id) REFERENCES token_collection(token_collection_id);
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_dnsdomid
	FOREIGN KEY (property_value_dns_domain_id) REFERENCES dns_domain(dns_domain_id);
ALTER TABLE property
	ADD CONSTRAINT fk_property_pv_nblkcol_id
	FOREIGN KEY (property_value_nblk_coll_id) REFERENCES netblock_collection(netblock_collection_id);
ALTER TABLE property
	ADD CONSTRAINT fk_property_nmtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_pwdtyp
	FOREIGN KEY (property_value_password_type) REFERENCES val_password_type(password_type);
ALTER TABLE property
	ADD CONSTRAINT fk_property_acctid
	FOREIGN KEY (account_id) REFERENCES account(account_id);
ALTER TABLE property
	ADD CONSTRAINT fk_property_compid
	FOREIGN KEY (company_id) REFERENCES company(company_id);
ALTER TABLE property
	ADD CONSTRAINT fk_property_dnsdomid
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_swpkgid
	FOREIGN KEY (property_value_sw_package_id) REFERENCES sw_package(sw_package_id);
ALTER TABLE property
	ADD CONSTRAINT fk_property_devcolid
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_acct_colid
	FOREIGN KEY (property_value_account_coll_id) REFERENCES account_collection(account_collection_id);

-- TRIGGERS
CREATE TRIGGER trigger_validate_property 
	BEFORE INSERT OR UPDATE ON property 
	FOR EACH ROW EXECUTE PROCEDURE validate_property();

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'property');
ALTER SEQUENCE property_property_id_seq
	 OWNED BY property.property_id;
DROP TABLE property_v53;
DROP TABLE audit.property_v53;
GRANT ALL ON property TO jazzhands;
GRANT SELECT ON property TO ro_role;
GRANT INSERT,UPDATE,DELETE ON property TO iud_role;
-- DONE DEALING WITH TABLE property [744880]
--------------------------------------------------------------------

CREATE TABLE val_port_plug_style
(
	port_plug_style	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_port_plug_style', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_port_plug_style ADD CONSTRAINT pk_val_port_plug_style PRIMARY KEY (port_plug_style);
-- INDEXES
CREATE INDEX xif1val_port_medium ON val_port_medium USING btree (port_plug_style);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
ALTER TABLE val_port_medium
	ADD CONSTRAINT fk_val_prt_medm_prt_plug_typ
	FOREIGN KEY (port_plug_style) REFERENCES val_port_plug_style(port_plug_style);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_port_plug_style');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_port_plug_style');
-- DONE DEALING WITH TABLE val_port_plug_style [1098014]
--------------------------------------------------------------------

CREATE TABLE val_port_protocol_speed
(
	port_protocol	varchar(50) NOT NULL,
	port_speed	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_port_protocol_speed', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_port_protocol_speed ADD CONSTRAINT pk_val_port_protocol_speed PRIMARY KEY (port_protocol, port_speed);
-- INDEXES
CREATE INDEX xif2val_port_protocol_speed ON val_port_protocol_speed USING btree (port_protocol);
CREATE INDEX xif1val_port_protocol_speed ON val_port_protocol_speed USING btree (port_speed);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE val_port_protocol_speed
	ADD CONSTRAINT fk_v_prt_proto_speed_speed
	FOREIGN KEY (port_speed) REFERENCES val_port_speed(port_speed);
ALTER TABLE val_port_protocol_speed
	ADD CONSTRAINT fk_v_prt_proto_speed_proto
	FOREIGN KEY (port_protocol) REFERENCES val_port_protocol(port_protocol);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_port_protocol_speed');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_port_protocol_speed');
-- DONE DEALING WITH TABLE val_port_protocol_speed [1109706]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE x509_certificate [1286248]

-- FOREIGN KEYS FROM
alter table x509_key_usage_attribute drop constraint fk_x509_certificate;

-- FOREIGN KEYS TO
alter table x509_certificate drop constraint fk_x509_cert_cert;
alter table x509_certificate drop constraint fk_x509cert_enc_id_id;
alter table x509_certificate drop constraint pk_x509_certificate;
alter table x509_certificate drop constraint ak_x509_cert_cert_ca_ser;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
drop trigger trig_userlog_x509_certificate on x509_certificate;
drop trigger trigger_audit_x509_certificate on x509_certificate;


ALTER TABLE x509_certificate RENAME TO x509_certificate_v53;
ALTER TABLE audit.x509_certificate RENAME TO x509_certificate_v53;

CREATE TABLE x509_certificate
(
	x509_cert_id	integer NOT NULL,
	is_certificate_authority	character(1) NOT NULL,
	signing_cert_id	integer  NULL,
	x509_ca_cert_serial_number	integer  NULL,
	public_key	varchar(4000) NOT NULL,
	private_key	varchar(4000) NOT NULL,
	certificate_sign_req	varchar(4000)  NULL,
	subject	varchar(255) NOT NULL,
	valid_from	timestamp(6) without time zone NOT NULL,
	valid_to	timestamp(6) without time zone NOT NULL,
	is_cert_revoked	character(1) NOT NULL,
	passphrase	varchar(255)  NULL,
	encryption_key_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'x509_certificate', false);
INSERT INTO x509_certificate (
	x509_cert_id,
	is_certificate_authority,		-- new column (is_certificate_authority)
	signing_cert_id,
	x509_ca_cert_serial_number,
	public_key,
	private_key,
	certificate_sign_req,
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
) SELECT
	x509_cert_id,
	NULL,		-- new column (is_certificate_authority)
	signing_cert_id,
	x509_ca_cert_serial_number,
	public_key,
	private_key,
	certificate_sign_req,
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
FROM x509_certificate_v53;

INSERT INTO audit.x509_certificate (
	x509_cert_id,
	is_certificate_authority,		-- new column (is_certificate_authority)
	signing_cert_id,
	x509_ca_cert_serial_number,
	public_key,
	private_key,
	certificate_sign_req,
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
) SELECT
	x509_cert_id,
	NULL,		-- new column (is_certificate_authority)
	signing_cert_id,
	x509_ca_cert_serial_number,
	public_key,
	private_key,
	certificate_sign_req,
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
FROM audit.x509_certificate_v53;

ALTER TABLE x509_certificate
	ALTER x509_cert_id
	SET DEFAULT nextval('x509_certificate_x509_cert_id_seq'::regclass);
ALTER TABLE x509_certificate
	ALTER is_certificate_authority
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE x509_certificate ADD CONSTRAINT pk_x509_certificate PRIMARY KEY (x509_cert_id);
ALTER TABLE x509_certificate ADD CONSTRAINT ak_x509_cert_cert_ca_ser UNIQUE (signing_cert_id, x509_ca_cert_serial_number);
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE x509_certificate ADD CONSTRAINT check_yes_no_31190954
	CHECK (is_certificate_authority = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
ALTER TABLE x509_key_usage_attribute
	ADD CONSTRAINT fk_x509_certificate
	FOREIGN KEY (x509_cert_id) REFERENCES x509_certificate(x509_cert_id);

-- FOREIGN KEYS TO
ALTER TABLE x509_certificate
	ADD CONSTRAINT fk_x509_cert_cert
	FOREIGN KEY (signing_cert_id) REFERENCES x509_certificate(x509_cert_id);
ALTER TABLE x509_certificate
	ADD CONSTRAINT fk_x509cert_enc_id_id
	FOREIGN KEY (encryption_key_id) REFERENCES encryption_key(encryption_key_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'x509_certificate');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'x509_certificate');
ALTER SEQUENCE x509_certificate_x509_cert_id_seq
	 OWNED BY x509_certificate.x509_cert_id;
DROP TABLE x509_certificate_v53;
DROP TABLE audit.x509_certificate_v53;
-- DONE DEALING WITH TABLE x509_certificate [1280415]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE device_collection_assignd_cert [1299375]

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
alter table device_collection_assignd_cert drop constraint fk_key_usg_reason_for_assng_d;
alter table device_collection_assignd_cert drop constraint fk_devcolascrt_flownacctid;
alter table device_collection_assignd_cert drop constraint fk_x509_key_usg_attrbt_dvc;
alter table device_collection_assignd_cert drop constraint fk_x509_certificate_file_fmt;
alter table device_collection_assignd_cert drop constraint fk_devcolascrt_devcolid;
alter table device_collection_assignd_cert drop constraint fk_devcol_asscrt_acctcolid;
alter table device_collection_assignd_cert drop constraint pk_device_collection_assigned;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
drop trigger trigger_audit_device_collection_assignd_cert on device_collection_assignd_cert;
drop trigger trig_userlog_device_collection_assignd_cert on device_collection_assignd_cert;


ALTER TABLE device_collection_assignd_cert RENAME TO device_collection_assignd_cert_v53;
ALTER TABLE audit.device_collection_assignd_cert RENAME TO device_collection_assignd_cert_v53;

CREATE TABLE device_collection_assignd_cert
(
	device_collection_id	integer NOT NULL,
	x509_cert_id	integer NOT NULL,
	x509_key_usg	varchar(50) NOT NULL,
	x509_file_format	varchar(50) NOT NULL,
	file_location_path	varchar(255) NOT NULL,
	key_tool_label	varchar(255)  NULL,
	file_access_mode	integer NOT NULL,
	file_owner_account_id	integer NOT NULL,
	file_group_acct_collection_id	integer NOT NULL,
	file_passphrase_path	varchar(255)  NULL,
	key_usage_reason_for_assign	varchar(50)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'device_collection_assignd_cert', false);
INSERT INTO device_collection_assignd_cert (
	device_collection_id,
	x509_cert_id,
	x509_key_usg,
	x509_file_format,
	file_location_path,
	key_tool_label,
	file_access_mode,
	file_owner_account_id,
	file_group_acct_collection_id,
	file_passphrase_path,
	key_usage_reason_for_assign,
	data_ins_user,
	data_ins_date,
	data_upd_date,
	data_upd_user
) SELECT
	device_collection_id,
	x509_cert_id,
	x509_key_usg,
	x509_file_format,
	file_location_path,
	key_tool_label,
	file_access_mode,
	file_owner_account_id,
	file_group_acct_collection_id,
	file_passphrase_path,
	key_usage_reason_for_assign,
	data_ins_user,
	data_ins_date,
	data_upd_date::timestamp,
	data_upd_user
FROM device_collection_assignd_cert_v53;

INSERT INTO audit.device_collection_assignd_cert (
	device_collection_id,
	x509_cert_id,
	x509_key_usg,
	x509_file_format,
	file_location_path,
	key_tool_label,
	file_access_mode,
	file_owner_account_id,
	file_group_acct_collection_id,
	file_passphrase_path,
	key_usage_reason_for_assign,
	data_ins_user,
	data_ins_date,
	data_upd_date,
	data_upd_user,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	device_collection_id,
	x509_cert_id,
	x509_key_usg,
	x509_file_format,
	file_location_path,
	key_tool_label,
	file_access_mode,
	file_owner_account_id,
	file_group_acct_collection_id,
	file_passphrase_path,
	key_usage_reason_for_assign,
	data_ins_user,
	data_ins_date,
	data_upd_date::timestamp,
	data_upd_user,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.device_collection_assignd_cert_v53;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device_collection_assignd_cert ADD CONSTRAINT pk_device_collection_assigned PRIMARY KEY (device_collection_id, x509_cert_id, x509_key_usg);
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE device_collection_assignd_cert
	ADD CONSTRAINT fk_key_usg_reason_for_assng_d
	FOREIGN KEY (key_usage_reason_for_assign) REFERENCES val_key_usg_reason_for_assgn(key_usage_reason_for_assign);
ALTER TABLE device_collection_assignd_cert
	ADD CONSTRAINT fk_devcolascrt_flownacctid
	FOREIGN KEY (file_owner_account_id) REFERENCES account(account_id);
ALTER TABLE device_collection_assignd_cert
	ADD CONSTRAINT fk_x509_key_usg_attrbt_dvc
	FOREIGN KEY (x509_cert_id, x509_key_usg) REFERENCES x509_key_usage_attribute(x509_cert_id, x509_key_usg);
ALTER TABLE device_collection_assignd_cert
	ADD CONSTRAINT fk_x509_certificate_file_fmt
	FOREIGN KEY (x509_file_format) REFERENCES val_x509_certificate_file_fmt(x509_file_format);
ALTER TABLE device_collection_assignd_cert
	ADD CONSTRAINT fk_devcolascrt_devcolid
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);
ALTER TABLE device_collection_assignd_cert
	ADD CONSTRAINT fk_devcol_asscrt_acctcolid
	FOREIGN KEY (file_group_acct_collection_id) REFERENCES account_collection(account_collection_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device_collection_assignd_cert');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device_collection_assignd_cert');
DROP TABLE device_collection_assignd_cert_v53;
DROP TABLE audit.device_collection_assignd_cert_v53;
-- DONE DEALING WITH TABLE device_collection_assignd_cert [1293177]
--------------------------------------------------------------------

------------------------------------------------------------------------------
-- END: TABLE MIGRATION
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- increase size of data_ins/upd_user columns
------------------------------------------------------------------------------
DO $$
DECLARE
    col RECORD;
BEGIN
    FOR col IN
        SELECT c.table_schema, c.table_name, c.column_name
        FROM information_schema.columns c JOIN information_schema.tables t
        ON c.table_schema = t.table_schema AND c.table_name = t.table_name
        WHERE t.table_type = 'BASE TABLE'
        AND c.column_name IN ('data_ins_user', 'data_upd_user')
	AND c.character_maximum_length = 30
    LOOP
        EXECUTE 'ALTER TABLE ' || col.table_schema || '.' || col.table_name
        || ' ALTER COLUMN ' || col.column_name || ' TYPE varchar(255)';
    END LOOP;
END
$$;

------------------------------------------------------------------------------
-- BEGIN: RECREATE VIEWS
------------------------------------------------------------------------------
CREATE VIEW v_property AS
 SELECT property.property_id, property.account_collection_id, 
    property.account_id, property.company_id, property.device_collection_id, 
    property.dns_domain_id, property.netblock_collection_id, 
    property.operating_system_id, property.person_id, 
    property.service_env_collection_id, property.site_code, 
    property.property_name, property.property_type, property.property_value, 
    property.property_value_timestamp, property.property_value_company_id, 
    property.property_value_account_coll_id, 
    property.property_value_dns_domain_id, property.property_value_nblk_coll_id, 
    property.property_value_password_type, property.property_value_person_id, 
    property.property_value_sw_package_id, property.property_value_token_col_id, 
    property.property_rank, property.start_date, property.finish_date, 
    property.is_enabled, property.data_ins_user, property.data_ins_date, 
    property.data_upd_user, property.data_upd_date
   FROM property
  WHERE property.is_enabled = 'Y'::bpchar AND (property.start_date IS NULL AND property.finish_date IS NULL OR property.start_date IS NULL AND now() <= property.finish_date OR property.start_date <= now() AND property.finish_date IS NULL OR property.start_date <= now() AND now() <= property.finish_date);

GRANT ALL ON v_property TO jazzhands;
GRANT SELECT ON v_property TO ro_role;
GRANT INSERT,UPDATE,DELETE ON v_property TO iud_role;
-- DONE DEALING WITH TABLE v_property [947993]
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH TABLE v_account_collection_account [1168109]
CREATE VIEW v_account_collection_account AS
 SELECT account_collection_account.account_collection_id, 
    account_collection_account.account_id, 
    account_collection_account.account_id_rank, 
    account_collection_account.start_date, 
    account_collection_account.finish_date, 
    account_collection_account.data_ins_user, 
    account_collection_account.data_ins_date, 
    account_collection_account.data_upd_user, 
    account_collection_account.data_upd_date
   FROM account_collection_account
  WHERE account_collection_account.start_date IS NULL AND account_collection_account.finish_date IS NULL OR account_collection_account.start_date IS NULL AND now() <= account_collection_account.finish_date OR account_collection_account.start_date <= now() AND account_collection_account.finish_date IS NULL OR account_collection_account.start_date <= now() AND now() <= account_collection_account.finish_date;

GRANT ALL ON v_account_collection_account TO jazzhands;
GRANT SELECT ON v_account_collection_account TO ro_role;
GRANT INSERT,UPDATE,DELETE ON v_account_collection_account TO iud_role;
-- DONE DEALING WITH TABLE v_account_collection_account [1162371]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE v_acct_coll_acct_expanded [1168113]
CREATE VIEW v_acct_coll_acct_expanded AS
 SELECT DISTINCT ace.account_collection_id, aca.account_id
   FROM v_acct_coll_expanded ace
   JOIN v_account_collection_account aca ON aca.account_collection_id = ace.root_account_collection_id;

GRANT ALL ON v_acct_coll_acct_expanded TO jazzhands;
GRANT SELECT ON v_acct_coll_acct_expanded TO ro_role;
GRANT INSERT,UPDATE,DELETE ON v_acct_coll_acct_expanded TO iud_role;
-- DONE DEALING WITH TABLE v_acct_coll_acct_expanded [1162390]
--------------------------------------------------------------------

CREATE VIEW v_device_col_acct_col_expanded AS
 SELECT DISTINCT dchd.device_collection_id, dcu.account_collection_id, 
    vuue.account_id
   FROM v_device_coll_hier_detail dchd
   JOIN v_property dcu ON dcu.device_collection_id = dchd.parent_device_collection_id
   JOIN v_acct_coll_acct_expanded vuue ON vuue.account_collection_id = dcu.account_collection_id
  WHERE dcu.property_name::text = 'UnixLogin'::text AND dcu.property_type::text = 'MclassUnixProp'::text;

GRANT ALL ON v_device_col_acct_col_expanded TO jazzhands;
GRANT SELECT ON v_device_col_acct_col_expanded TO ro_role;
GRANT INSERT,UPDATE,DELETE ON v_device_col_acct_col_expanded TO iud_role;


-- DONE DEALING WITH TABLE v_device_col_acct_col_expanded [948090]
--------------------------------------------------------------------

CREATE VIEW v_l1_all_physical_ports AS
 SELECT subquery.layer1_connection_id, subquery.physical_port_id, 
    subquery.device_id, subquery.port_name, subquery.port_type, 
    subquery.port_purpose, subquery.other_physical_port_id, 
    subquery.other_device_id, subquery.other_port_name, 
    subquery.other_port_purpose, subquery.baud, subquery.data_bits, 
    subquery.stop_bits, subquery.parity, subquery.flow_control
   FROM (        (         SELECT l1.layer1_connection_id, p1.physical_port_id, 
                            p1.device_id, p1.port_name, p1.port_type, 
                            p1.port_purpose, 
                            p2.physical_port_id AS other_physical_port_id, 
                            p2.device_id AS other_device_id, 
                            p2.port_name AS other_port_name, 
                            p2.port_purpose AS other_port_purpose, l1.baud, 
                            l1.data_bits, l1.stop_bits, l1.parity, 
                            l1.flow_control
                           FROM physical_port p1
                      JOIN layer1_connection l1 ON l1.physical_port1_id = p1.physical_port_id
                 JOIN physical_port p2 ON l1.physical_port2_id = p2.physical_port_id
                WHERE p1.port_type::text = p2.port_type::text
                UNION 
                         SELECT l1.layer1_connection_id, p1.physical_port_id, 
                            p1.device_id, p1.port_name, p1.port_type, 
                            p1.port_purpose, 
                            p2.physical_port_id AS other_physical_port_id, 
                            p2.device_id AS other_device_id, 
                            p2.port_name AS other_port_name, 
                            p2.port_purpose AS other_port_purpose, l1.baud, 
                            l1.data_bits, l1.stop_bits, l1.parity, 
                            l1.flow_control
                           FROM physical_port p1
                      JOIN layer1_connection l1 ON l1.physical_port2_id = p1.physical_port_id
                 JOIN physical_port p2 ON l1.physical_port1_id = p2.physical_port_id
                WHERE p1.port_type::text = p2.port_type::text)
        UNION 
                 SELECT NULL::integer, p1.physical_port_id, p1.device_id, 
                    p1.port_name, p1.port_type, p1.port_purpose, NULL::integer, 
                    NULL::integer, NULL::character varying, 
                    NULL::character varying, NULL::integer, NULL::integer, 
                    NULL::integer, NULL::character varying, 
                    NULL::character varying
                   FROM physical_port p1
              LEFT JOIN layer1_connection l1 ON l1.physical_port1_id = p1.physical_port_id OR l1.physical_port2_id = p1.physical_port_id
             WHERE l1.layer1_connection_id IS NULL) subquery
  ORDER BY network_strings.numeric_interface(subquery.port_name);

GRANT ALL ON v_l1_all_physical_ports TO jazzhands;
GRANT SELECT ON v_l1_all_physical_ports TO ro_role;
GRANT INSERT,UPDATE,DELETE ON v_l1_all_physical_ports TO iud_role;
-- DONE DEALING WITH TABLE v_l1_all_physical_ports [948018]
--------------------------------------------------------------------
CREATE VIEW v_dev_col_user_prop_expanded AS
 SELECT dchd.device_collection_id, s.account_id, s.login, s.account_status, 
    upo.property_type, upo.property_name, upo.property_value, 
        CASE
            WHEN upn.is_multivalue = 'N'::bpchar THEN 0
            ELSE 1
        END AS is_multievalue, 
        CASE
            WHEN pdt.property_data_type::text = 'boolean'::text THEN 1
            ELSE 0
        END AS is_boolean
   FROM v_acct_coll_acct_expanded_detail uued
   JOIN account_collection u ON uued.account_collection_id = u.account_collection_id
   JOIN v_property upo ON upo.account_collection_id = u.account_collection_id AND (upo.property_type::text = ANY (ARRAY['CCAForceCreation'::character varying, 'CCARight'::character varying, 'ConsoleACL'::character varying, 'RADIUS'::character varying, 'TokenMgmt'::character varying, 'UnixPasswdFileValue'::character varying, 'UserMgmt'::character varying, 'cca'::character varying, 'feed-attributes'::character varying, 'proteus-tm'::character varying, 'wwwgroup'::character varying]::text[]))
   JOIN val_property upn ON upo.property_name::text = upn.property_name::text AND upo.property_type::text = upn.property_type::text
   JOIN val_property_data_type pdt ON upn.property_data_type::text = pdt.property_data_type::text
   LEFT JOIN v_device_coll_hier_detail dchd ON dchd.parent_device_collection_id = upo.device_collection_id
   JOIN account s ON uued.account_id = s.account_id
  ORDER BY dchd.device_collection_level, 
CASE
    WHEN u.account_collection_type::text = 'per-user'::text THEN 0
    WHEN u.account_collection_type::text = 'property'::text THEN 1
    WHEN u.account_collection_type::text = 'systems'::text THEN 2
    ELSE 3
END, 
CASE
    WHEN uued.assign_method = 'Account_CollectionAssignedToPerson'::text THEN 0
    WHEN uued.assign_method = 'Account_CollectionAssignedToDept'::text THEN 1
    WHEN uued.assign_method = 'ParentAccount_CollectionOfAccount_CollectionAssignedToPerson'::text THEN 2
    WHEN uued.assign_method = 'ParentAccount_CollectionOfAccount_CollectionAssignedToDept'::text THEN 2
    WHEN uued.assign_method = 'Account_CollectionAssignedToParentDept'::text THEN 3
    WHEN uued.assign_method = 'ParentAccount_CollectionOfAccount_CollectionAssignedToParentDep'::text THEN 3
    ELSE 6
END, uued.dept_level, uued.acct_coll_level, dchd.device_collection_id, u.account_collection_id;

GRANT ALL ON v_dev_col_user_prop_expanded TO jazzhands;
GRANT SELECT ON v_dev_col_user_prop_expanded TO ro_role;
GRANT INSERT,UPDATE,DELETE ON v_dev_col_user_prop_expanded TO iud_role;
-- DONE DEALING WITH TABLE v_dev_col_user_prop_expanded [948056]
--------------------------------------------------------------------
CREATE VIEW v_acct_coll_prop_expanded AS
 SELECT v_acct_coll_expanded_detail.root_account_collection_id AS account_collection_id, 
    v_property.property_id, v_property.property_name, v_property.property_type, 
    v_property.property_value, v_property.property_value_timestamp, 
    v_property.property_value_company_id, 
    v_property.property_value_account_coll_id, 
    v_property.property_value_dns_domain_id, 
    v_property.property_value_nblk_coll_id, 
    v_property.property_value_password_type, 
    v_property.property_value_person_id, 
    v_property.property_value_sw_package_id, 
    v_property.property_value_token_col_id, 
        CASE val_property.is_multivalue
            WHEN 'N'::bpchar THEN false
            WHEN 'Y'::bpchar THEN true
            ELSE NULL::boolean
        END AS is_multivalue
   FROM v_acct_coll_expanded_detail
   JOIN account_collection ac USING (account_collection_id)
   JOIN v_property USING (account_collection_id)
   JOIN val_property USING (property_name, property_type)
  ORDER BY 
CASE ac.account_collection_type
    WHEN 'per-user'::text THEN 0
    ELSE 99
END, 
CASE v_acct_coll_expanded_detail.assign_method
    WHEN 'DirectAccountCollectionAssignment'::text THEN 0
    WHEN 'DirectDepartmentAssignment'::text THEN 1
    WHEN 'DepartmentAssignedToAccountCollection'::text THEN 2
    WHEN 'AccountAssignedToChildDepartment'::text THEN 3
    WHEN 'AccountAssignedToChildAccountCollection'::text THEN 4
    WHEN 'DepartmentAssignedToChildAccountCollection'::text THEN 5
    WHEN 'ChildDepartmentAssignedToAccountCollection'::text THEN 6
    WHEN 'ChildDepartmentAssignedToChildAccountCollection'::text THEN 7
    ELSE 99
END, v_acct_coll_expanded_detail.dept_level, v_acct_coll_expanded_detail.acct_coll_level, v_acct_coll_expanded_detail.root_account_collection_id;

GRANT ALL ON v_acct_coll_prop_expanded TO jazzhands;
GRANT SELECT ON v_acct_coll_prop_expanded TO ro_role;
GRANT INSERT,UPDATE,DELETE ON v_acct_coll_prop_expanded TO iud_role;
-- DONE DEALING WITH TABLE v_acct_coll_prop_expanded [948061]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE v_application_role_member [1168123]
CREATE VIEW v_application_role_member AS
 SELECT device_collection_device.device_id, 
    device_collection_device.device_collection_id AS role_id, 
    device_collection_device.data_ins_user, 
    device_collection_device.data_ins_date, 
    device_collection_device.data_upd_user, 
    device_collection_device.data_upd_date
   FROM device_collection_device
  WHERE (device_collection_device.device_collection_id IN ( SELECT device_collection.device_collection_id
           FROM device_collection
          WHERE device_collection.device_collection_type::text = 'appgroup'::text));

GRANT ALL ON v_application_role_member TO jazzhands;
GRANT SELECT ON v_application_role_member TO ro_role;
GRANT INSERT,UPDATE,DELETE ON v_application_role_member TO iud_role;
-- DONE DEALING WITH TABLE v_application_role_member [1162419]
--------------------------------------------------------------------

------------------------------------------------------------------------------
-- END: RECREATE VIEWS
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- comments...
------------------------------------------------------------------------------
COMMENT ON TABLE property IS 'generic property instance that describes system wide properties, as well as properties for various values of columns used throughout the db for configuration, acls, defaults, etc; also used to relate some tables';
COMMENT ON COLUMN property.property_id IS 'primary key for table to uniquely identify rows.';
COMMENT ON COLUMN property.account_collection_id IS 'user collection that properties may be set on.';
COMMENT ON COLUMN property.account_id IS 'system user that properties may be set on.';
COMMENT ON COLUMN property.company_id IS 'company that properties may be set on.';
COMMENT ON COLUMN property.device_collection_id IS 'device collection that properties may be set on.';
COMMENT ON COLUMN property.dns_domain_id IS 'dns domain that properties may be set on.';
COMMENT ON COLUMN property.operating_system_id IS 'operating system that properties may be set on.';
COMMENT ON COLUMN property.site_code IS 'site_code that properties may be set on';
COMMENT ON COLUMN property.property_name IS 'textual name of a property';
COMMENT ON COLUMN property.property_type IS 'textual type of a department';
COMMENT ON COLUMN property.property_value IS 'general purpose column for value of property not defined by other types.  This may be enforced by fk (trigger) if val_property.property_data_type is list (fk is to val_property_value).';
COMMENT ON COLUMN property.property_value_timestamp IS 'property is defined as a timestamp';
COMMENT ON COLUMN property.start_date IS 'date/time that the assignment takes effect';
COMMENT ON COLUMN property.finish_date IS 'date/time that the assignment ceases taking effect';
COMMENT ON COLUMN property.is_enabled IS 'indiciates if the property is temporarily disabled or not.';
COMMENT ON COLUMN token.encryption_key_id IS 'encryption information for token_key, if used';
COMMENT ON TABLE token_collection IS 'Group tokens together in arbitrary ways.';
COMMENT ON TABLE token_collection_token IS 'Assign individual tokens to groups.';
COMMENT ON TABLE val_property IS 'valid values and attributes for (name,type) pairs in the property table';
COMMENT ON COLUMN val_property.property_name IS 'property name for validation purposes';
COMMENT ON COLUMN val_property.property_type IS 'property type for validation purposes';
COMMENT ON COLUMN val_property.is_multivalue IS 'If N, acts like an ak on property.(*_id,property_type)';
COMMENT ON COLUMN val_property.property_data_type IS 'which of the property_table_* columns should be used for this value';
COMMENT ON COLUMN val_property.permit_account_collection_id IS 'defines how company id should be used in the property for this (name,type)';
COMMENT ON COLUMN val_property.permit_company_id IS 'defines how company id should be used in the property for this (name,type)';
COMMENT ON COLUMN val_property.permit_device_collection_id IS 'defines how company id should be used in the property for this (name,type)';
COMMENT ON COLUMN val_property.permit_account_id IS 'defines how company id should be used in the property for this (name,type)';
COMMENT ON COLUMN val_property.permit_dns_domain_id IS 'defines how company id should be used in the property for this (name,type)';
COMMENT ON TABLE val_property_data_type IS 'valid data types for property (name,type) pairs';
COMMENT ON TABLE val_property_type IS 'validation table for property types';
COMMENT ON COLUMN val_property_value.property_name IS 'property name for validation purposes';
COMMENT ON COLUMN val_property_value.property_type IS 'property type for validation purposes';
COMMENT ON COLUMN val_property_value.valid_property_value IS 'if applicatable, servves as a fk for valid property_values.  This depends on val_property.property_data_type being set to list.';

------------------------------------------------------------------------------
-- BEGIN regenerate validate_property()
------------------------------------------------------------------------------
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
			((service_env_collection_id IS NULL AND NEW.service_env_collection_id IS NULL) OR
				(service_env_collection_id = NEW.service_env_collection_id)) AND
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
			((service_env_collection_id IS NULL AND NEW.service_env_collection_id IS NULL) OR
				(service_env_collection_id = NEW.service_env_collection_id)) AND
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
		IF v_prop.Property_Data_Type = 'netblock_collection_id' THEN
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

	IF v_prop.permit_service_env_collection = 'REQUIRED' THEN
			IF NEW.service_env_collection_id IS NULL THEN
				RAISE 'service_env_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_service_env_collection = 'PROHIBITED' THEN
			IF NEW.service_env_collection_id IS NOT NULL THEN
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

	IF v_prop.Permit_Property_Rank = 'REQUIRED' THEN
			IF NEW.property_rank IS NULL THEN
				RAISE 'property_rank is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Property_Rank = 'PROHIBITED' THEN
			IF NEW.property_rank IS NOT NULL THEN
				RAISE 'property_rank is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
------------------------------------------------------------------------------
-- END regenerate validate_property()
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- BEGIN regenerate schema_support.rebuild_audit_trigger to truncate
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_trigger
    ( aud_schema VARCHAR, tbl_schema VARCHAR, table_name VARCHAR )
RETURNS VOID AS $$
BEGIN
    EXECUTE 'CREATE OR REPLACE FUNCTION ' || quote_ident(tbl_schema)
        || '.' || quote_ident('perform_audit_' || table_name)
        || $ZZ$() RETURNS TRIGGER AS $TQ$
            DECLARE
                appuser VARCHAR;
            BEGIN
                BEGIN
                    appuser := session_user
                        || '/' || current_setting('jazzhands.appuser');
                EXCEPTION WHEN OTHERS THEN
                    appuser := session_user;
                END;

    		appuser = substr(appuser, 1, 255);

                IF TG_OP = 'DELETE' THEN
                    INSERT INTO $ZZ$ || quote_ident(aud_schema) 
                        || '.' || quote_ident(table_name) || $ZZ$
                    VALUES ( OLD.*, 'DEL', now(), appuser );
                    RETURN OLD;
                ELSIF TG_OP = 'UPDATE' THEN
                    INSERT INTO $ZZ$ || quote_ident(aud_schema)
                        || '.' || quote_ident(table_name) || $ZZ$
                    VALUES ( NEW.*, 'UPD', now(), appuser );
                    RETURN NEW;
                ELSIF TG_OP = 'INSERT' THEN
                    INSERT INTO $ZZ$ || quote_ident(aud_schema)
                        || '.' || quote_ident(table_name) || $ZZ$
                    VALUES ( NEW.*, 'INS', now(), appuser );
                    RETURN NEW;
                END IF;
                RETURN NULL;
            END;
        $TQ$ LANGUAGE plpgsql SECURITY DEFINER
    $ZZ$;

    EXECUTE 'DROP TRIGGER IF EXISTS ' || quote_ident('trigger_audit_'
        || table_name) || ' ON ' || quote_ident(tbl_schema) || '.'
        || quote_ident(table_name);

    EXECUTE 'CREATE TRIGGER ' || quote_ident('trigger_audit_' || table_name)
        || ' AFTER INSERT OR UPDATE OR DELETE ON ' || quote_ident(tbl_schema)
        || '.' || quote_ident(table_name) || ' FOR EACH ROW EXECUTE PROCEDURE ' 
        || quote_ident(tbl_schema) || '.' || quote_ident('perform_audit_'
        || table_name) || '()';
END;
$$ LANGUAGE plpgsql;
------------------------------------------------------------------------------
-- END regenerate schema_support.rebuild_audit_trigger to truncate
------------------------------------------------------------------------------

-- rebuild all audit triggers, to change above
SELECT schema_support.build_audit_tables('audit', 'jazzhands');


------------------------------------------------------------------------------
-- BEGIN regenerate schema_support.trigger_ins_upd_generic_func() to truncate
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION schema_support.trigger_ins_upd_generic_func()
RETURNS TRIGGER AS $$
DECLARE
    appuser VARCHAR;
BEGIN
    BEGIN
        appuser := session_user || '/' || current_setting('jazzhands.appuser');
    EXCEPTION
        WHEN OTHERS THEN appuser := session_user;
    END;

    appuser = substr(appuser, 1, 255);

    IF TG_OP = 'INSERT' THEN
        NEW.data_ins_user = appuser;
        NEW.data_ins_date = 'now';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        NEW.data_upd_user = appuser;
        NEW.data_upd_date = 'now';

        IF OLD.data_ins_user != NEW.data_ins_user THEN
            RAISE EXCEPTION
                'Non modifiable column "DATA_INS_USER" cannot be modified.';
        END IF;

        IF OLD.data_ins_date != NEW.data_ins_date THEN
            RAISE EXCEPTION
                'Non modifiable column "DATA_INS_DATE" cannot be modified.';
        END IF;
    END IF;

    RETURN NEW;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
------------------------------------------------------------------------------
-- END regenerate schema_support.trigger_ins_upd_generic_func() to truncate
------------------------------------------------------------------------------

-- note:  do not need to run schema_support.rebuild_stamp_triggers since 
-- they all call the above function

------------------------------------------------------------------------------
-- BEGIN update dns_record triggers
------------------------------------------------------------------------------
/*
 * Copyright (c) 2012 Todd Kover
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

CREATE OR REPLACE FUNCTION dns_rec_before() RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'DELETE' THEN
		PERFORM 1 FROM jazzhands.dns_domain WHERE dns_domain_id IN (
		    OLD.dns_domain_id, netblock_utils.find_rvs_zone_from_netblock_id(OLD.netblock_id)
		)
		FOR UPDATE;

		RETURN OLD;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.netblock_id IS NOT NULL THEN
			PERFORM 1 FROM jazzhands.dns_domain WHERE dns_domain_id IN (
		    	NEW.dns_domain_id, netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
			) FOR UPDATE;
		END IF;

		RETURN NEW;
	ELSE
		IF OLD.netblock_id IS DISTINCT FROM NEW.netblock_id THEN
			IF OLD.netblock_id IS NOT NULL THEN
				PERFORM 1 FROM jazzhands.dns_domain WHERE dns_domain_id IN (
			    	OLD.dns_domain_id, netblock_utils.find_rvs_zone_from_netblock_id(OLD.netblock_id))
				FOR UPDATE;
			END IF;
			IF NEW.netblock_id IS NOT NULL THEN
				PERFORM 1 FROM jazzhands.dns_domain WHERE dns_domain_id IN (
			    	NEW.dns_domain_id, netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
				)
				FOR UPDATE;
			END IF;
		ELSE
			IF NEW.netblock_id IS NOT NULL THEN
				PERFORM 1 FROM jazzhands.dns_domain WHERE dns_domain_id IN (
			    	NEW.dns_domain_id, netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
				) FOR UPDATE;
			END IF;
		END IF;

		RETURN NEW;
	END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_rec_before ON dns_record;
CREATE TRIGGER trigger_dns_rec_before 
	BEFORE INSERT OR DELETE OR UPDATE 
	ON dns_record 
	FOR EACH ROW
	EXECUTE PROCEDURE dns_rec_before();

CREATE OR REPLACE FUNCTION update_dns_zone() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
		UPDATE jazzhands.dns_domain SET zone_last_updated = clock_timestamp()
            WHERE dns_domain_id = NEW.dns_domain_id
			AND ( zone_last_updated < last_generated
			OR zone_last_updated is NULL);

		IF TG_OP = 'UPDATE' THEN
			IF OLD.dns_domain_id != NEW.dns_domain_id THEN
				UPDATE jazzhands.dns_domain SET zone_last_updated = clock_timestamp()
					 WHERE dns_domain_id = OLD.dns_domain_id
					 AND ( zone_last_updated < last_generated or zone_last_updated is NULL );
			END IF;
			IF NEW.netblock_id != OLD.netblock_id THEN
				UPDATE jazzhands.dns_domain SET zone_last_updated = clock_timestamp()
					 WHERE dns_domain_id in (
						 netblock_utils.find_rvs_zone_from_netblock_id(OLD.netblock_id),
						 netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
					)
				     AND ( zone_last_updated < last_generated or zone_last_updated is NULL );
			END IF;
		ELSIF TG_OP = 'INSERT' AND NEW.netblock_id is not NULL THEN
			UPDATE jazzhands.dns_domain SET zone_last_updated = clock_timestamp()
				WHERE dns_domain_id = 
					netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
				AND ( zone_last_updated < last_generated or zone_last_updated is NULL );

		END IF;
	END IF;

    IF TG_OP = 'DELETE' THEN
        UPDATE jazzhands.dns_domain SET zone_last_updated = clock_timestamp()
			WHERE dns_domain_id = OLD.dns_domain_id
			AND ( zone_last_updated < last_generated or zone_last_updated is NULL );

		IF OLD.dns_type = 'A' OR OLD.dns_type = 'AAAA' THEN
			UPDATE jazzhands.dns_domain SET zone_last_updated = clock_timestamp()
                 WHERE  dns_domain_id = netblock_utils.find_rvs_zone_from_netblock_id(OLD.netblock_id)
				 AND ( zone_last_updated < last_generated or zone_last_updated is NULL );
        END IF;
    END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_dns_zone ON dns_record;
CREATE CONSTRAINT TRIGGER trigger_update_dns_zone 
	AFTER INSERT OR DELETE OR UPDATE 
	ON dns_record 
	INITIALLY DEFERRED
	FOR EACH ROW 
	EXECUTE PROCEDURE update_dns_zone();

------------------------------------------------------------------------------
-- BEGIN update dns_record triggers
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- BEGIN add new device triggers
------------------------------------------------------------------------------
/*
 * Copyright (c) 2013 Todd Kover
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


-- Manage per-device device collections.
--
-- When a device is added, updated or removed, there is a per-device
-- device-collection that goes along with it

-- XXX Need automated test cases

-- before a device is deleted, remove the per-device device collections, 
-- if appropriate
CREATE OR REPLACE FUNCTION delete_per_device_device_collection() 
RETURNS TRIGGER AS $$
DECLARE
	dcid			device_collection.device_collection_id%TYPE;
BEGIN
	SELECT	device_collection_id
	  FROM  device_collection
	  INTO	dcid
	 WHERE	device_collection_type = 'per-device'
	   AND	device_collection_id in
		(select device_collection_id
		 from device_collection_device
		where device_id = OLD.device_id
		)
	ORDER BY device_collection_id
	LIMIT 1;

	IF dcid IS NOT NULL THEN
		DELETE FROM device_collection_device
		WHERE device_collection_id = dcid;

		DELETE from device_collection
		WHERE device_collection_id = dcid;
	END IF;

	RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_delete_per_device_device_collection ON Device;
CREATE TRIGGER trigger_delete_per_device_device_collection 
BEFORE DELETE
ON device
FOR EACH ROW EXECUTE PROCEDURE delete_per_device_device_collection();

------------------------------------------------------------------------------


-- On inserts and updates, ensure the per-device device collection is updated
-- correctly.
CREATE OR REPLACE FUNCTION update_per_device_device_collection()
RETURNS TRIGGER AS $$
DECLARE
	dcid		device_collection.device_collection_id%TYPE;
	newname		device_collection.device_collection_name%TYPE;
BEGIN
	IF NEW.device_name IS NOT NULL THEN
		newname = NEW.device_name || '_' || NEW.device_id;
	ELSE
		newname = 'per_d_dc_contrived_' || NEW.device_id;
	END IF;

	IF TG_OP = 'INSERT' THEN
		insert into device_collection 
			(device_collection_name, device_collection_type)
		values
			(newname, 'per-device')
		RETURNING device_collection_id INTO dcid;
		insert into device_collection_device 
			(device_collection_id, device_id)
		VALUES
			(dcid, NEW.device_id);
	ELSIF TG_OP = 'UPDATE'  THEN
		UPDATE	device_collection
		   SET	device_collection_name = newname
		 WHERE	device_collection_name != newname
		   AND	device_collection_type = 'per-device'
		   AND	device_collection_id in (
			SELECT	device_collection_id
			  FROM	device_collection_device
			 WHERE	device_id = NEW.device_id
			);
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_per_device_device_collection ON device;
CREATE TRIGGER trigger_update_per_device_device_collection 
AFTER INSERT OR UPDATE
ON device 
FOR EACH ROW EXECUTE PROCEDURE update_per_device_device_collection();
------------------------------------------------------------------------------
-- END add new device triggers
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- BEGIN add new service_environment triggers
------------------------------------------------------------------------------
/*
 * Copyright (c) 2013 Todd Kover
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


-- Manage per-service_environment collections.
--
-- When a service environment is added, updated or removed, there is a
-- per-environment
-- service environment collection that goes along with it

-- XXX Need automated test cases

-- before a serivce environment is deleted, remove the 
-- collection its a part of, -- if appropriate
CREATE OR REPLACE FUNCTION delete_per_svc_env_svc_env_collection() 
RETURNS TRIGGER AS $$
DECLARE
	secid	service_environment_collection.service_env_collection_id%TYPE;
BEGIN
	SELECT	service_env_collection_id
	  FROM  service_environment_collection
	  INTO	secid
	 WHERE	service_env_collection_type = 'per-environment'
	   AND	service_env_collection_id in
		(select service_env_collection_id
		 from svc_environment_coll_svc_env
		where service_environment = OLD.service_environment
		)
	ORDER BY service_env_collection_id
	LIMIT 1;

	IF secid IS NOT NULL THEN
		DELETE FROM svc_environment_coll_svc_env
		WHERE service_env_collection_id = secid;

		DELETE from service_environment_collection
		WHERE service_env_collection_id = secid;
	END IF;

	RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_delete_per_svc_env_svc_env_collection ON service_environment;
CREATE TRIGGER trigger_delete_per_svc_env_svc_env_collection 
BEFORE DELETE
ON service_environment
FOR EACH ROW EXECUTE PROCEDURE delete_per_svc_env_svc_env_collection();

------------------------------------------------------------------------------


-- On inserts and updates, ensure the per-environment service collection 
-- is updated correctly.
CREATE OR REPLACE FUNCTION update_per_svc_env_svc_env_collection()
RETURNS TRIGGER AS $$
DECLARE
	secid		service_environment_collection.service_env_collection_id%TYPE;
BEGIN
	IF TG_OP = 'INSERT' THEN
		insert into service_environment_collection 
			(service_env_collection_name, service_env_collection_type)
		values
			(NEW.service_environment, 'per-environment')
		RETURNING service_env_collection_id INTO secid;
		insert into svc_environment_coll_svc_env 
			(service_env_collection_id, service_environment)
		VALUES
			(secid, NEW.service_environment);
	ELSIF TG_OP = 'UPDATE'  AND OLD.service_environment != NEW.service_environment THEN
		UPDATE	service_environment_collection
		   SET	service_env_collection_name = NEW.service_environment
		 WHERE	service_env_collection_name != NEW.service_environment
		   AND	service_env_collection_type = 'per-environment'
		   AND	service_environment in (
			SELECT	service_environment
			  FROM	svc_environment_coll_svc_env
			 WHERE	service_environment = NEW.service_environment
			);
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_per_svc_env_svc_env_collection ON service_environment;
CREATE TRIGGER trigger_update_per_svc_env_svc_env_collection 
AFTER INSERT OR UPDATE
ON service_environment 
FOR EACH ROW EXECUTE PROCEDURE update_per_svc_env_svc_env_collection();
------------------------------------------------------------------------------
-- END add new service_environment triggers
------------------------------------------------------------------------------

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION dns_rec_type_validation() RETURNS TRIGGER AS $$
BEGIN
	IF NEW.dns_type in ('A', 'AAAA') AND NEW.netblock_id IS NULL THEN
		RAISE EXCEPTION 'Attempt to set % record without a Netblock',
			NEW.dns_type;
	END IF;

	IF NEW.netblock_Id is not NULL and 
			( NEW.dns_value IS NOT NULL OR NEW.dns_value_record_id IS NOT NULL ) THEN
		RAISE EXCEPTION 'Both dns_value and netblock_id may not be set';
	END IF;

	IF NEW.dns_value IS NOT NULL AND NEW.dns_value_record_id IS NOT NULL THEN
		RAISE EXCEPTION 'Both dns_value and dns_value_record_id may not be set';
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_rec_a_type_validation ON dns_record;
CREATE TRIGGER trigger_dns_rec_a_type_validation 
	BEFORE INSERT OR UPDATE 
	ON dns_record 
	FOR EACH ROW 
	EXECUTE PROCEDURE dns_rec_type_validation();
------------------------------------------------------------------------------
-- BEGIN COMMENTS!
COMMENT ON COLUMN device_collection_assignd_cert.file_access_mode IS 'Numeric representation of the File Access Mode.';
COMMENT ON COLUMN device_collection_assignd_cert.file_group_acct_collection_id IS 'Identifies user collection that corresponds to a unix group for the file to be owned by';
COMMENT ON COLUMN device_collection_assignd_cert.file_location_path IS 'Alphanumeric representation of the path leading to the file.';
COMMENT ON COLUMN device_collection_assignd_cert.file_owner_account_id IS 'Identifier of the file owner.';
COMMENT ON COLUMN device_collection_assignd_cert.key_tool_label IS 'Alphanumeric representation of the label attached to the certificate by Key Tool';
COMMENT ON COLUMN device_collection_assignd_cert.key_usage_reason_for_assign IS 'Uniquely identifies and indicates reason for assignment.';
COMMENT ON COLUMN device_collection_assignd_cert.x509_cert_id IS 'Uniquely identifies Certificate';
COMMENT ON COLUMN device_collection_assignd_cert.x509_file_format IS 'Format Name of the file containing Certificate information. Example; keytool, rsa';
COMMENT ON COLUMN device_collection_assignd_cert.x509_key_usg IS 'Name of the Certificate.';
COMMENT ON COLUMN x509_certificate.is_cert_revoked IS 'Indicates if certificate has been revoked. ''Y'' indicates that Certificate has been revoked.';
COMMENT ON COLUMN x509_certificate.private_key IS 'Textual representation of Certificate Private Key. Private Key is a component of X509 standard and is used for encryption.';
COMMENT ON COLUMN x509_certificate.public_key IS 'Textual representation of Certificate Public Key. Public Key is a component of X509 standard and is used for encryption.';
COMMENT ON COLUMN x509_certificate.signing_cert_id IS 'Identifier for the certificate that has signed this one.';
COMMENT ON COLUMN x509_certificate.subject IS 'Textual representation of a certificate subject. Certificate subject is a part of X509 certificate specifications.';
COMMENT ON COLUMN x509_certificate.valid_from IS 'Timestamp indicating when the certificate becomes valid and can be used.';
COMMENT ON COLUMN x509_certificate.valid_to IS 'Timestamp indicating when the certificate becomes invalid and can''t be used.';
COMMENT ON COLUMN x509_certificate.x509_ca_cert_serial_number IS 'Serial INTEGER assigned to the certificate within Certificate Authority. It uniquely identifies certificate within the realm of the CA.';
COMMENT ON COLUMN x509_certificate.x509_cert_id IS 'Uniquely identifies Certificate';
COMMENT ON TABLE device_collection_assignd_cert IS 'Actual  assignment of the usage category APPLICATION Certificates to Device Collections.';
COMMENT ON TABLE x509_certificate IS 'X509 specification Certificate.';
-- END COMMENTS!
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Add new definitions of data whose purpose is changing
------------------------------------------------------------------------------

INSERT INTO VAL_Network_Interface_Type (Network_Interface_Type)
        VALUES ('point-to-point');
INSERT INTO VAL_Network_Interface_Type (Network_Interface_Type)
        VALUES ('broadcast');

insert into val_network_interface_purpose
        (NETWORK_INTERFACE_PURPOSE,DESCRIPTION)
        values ('api', 'Interface used to manage device via API');
insert into val_network_interface_purpose
        (NETWORK_INTERFACE_PURPOSE,DESCRIPTION)
        values ('radius', 'Interface used for radius');
insert into val_network_interface_purpose
        (NETWORK_INTERFACE_PURPOSE)
        values ('login');

insert into val_layer2_encapsulation_type
        (layer2_encapsulation_type) values ('trunk');
insert into val_layer2_encapsulation_type
        (layer2_encapsulation_type) values ('access');
insert into val_layer2_encapsulation_type
        (layer2_encapsulation_type) values ('native');

insert into val_ip_group_protocol
        (ip_group_protocol) values ('vrrp');
insert into val_ip_group_protocol
        (ip_group_protocol) values ('hsrp');
insert into val_ip_group_protocol
        (ip_group_protocol) values ('bgp');

insert into val_port_protocol (port_protocol) values ( 'Ethernet' );
insert into val_port_protocol (port_protocol) values ( 'DS1' );
insert into val_port_protocol (port_protocol) values ( 'DS3' );
insert into val_port_protocol (port_protocol) values ( 'E1' );
insert into val_port_protocol (port_protocol) values ( 'E3' );
insert into val_port_protocol (port_protocol) values ( 'OC3' );
insert into val_port_protocol (port_protocol) values ( 'OC12' );
insert into val_port_protocol (port_protocol) values ( 'OC48' );
insert into val_port_protocol (port_protocol) values ( 'OC192' );
insert into val_port_protocol (port_protocol) values ( 'OC768' );
insert into val_port_protocol (port_protocol) values ( 'serial' );

insert into val_port_plug_style (port_plug_style) values ('db9');
insert into val_port_plug_style (port_plug_style) values ('rj45');
insert into val_port_plug_style (port_plug_style) values ('SFP');
insert into val_port_plug_style (port_plug_style) values ('SFP+');
insert into val_port_plug_style (port_plug_style) values ('QSFP+');
insert into val_port_plug_style (port_plug_style) values ('GBIC');
insert into val_port_plug_style (port_plug_style) values ('XENPAK');

-- need to do sr, lr, cat6, cat5, twinax, etc
insert into val_port_medium (port_medium,port_plug_style) values
        ('serial', 'db9');
insert into val_port_medium (port_medium,port_plug_style) values
        ('serial', 'rj45');
insert into val_port_medium (port_medium,port_plug_style) values
        ('TwinAx', 'SFP+');


insert into val_port_speed (port_speed, port_speed_bps) values
        ('10Mb', 10000);
insert into val_port_speed (port_speed, port_speed_bps) values
        ('100Mb', 1000000);
insert into val_port_speed (port_speed, port_speed_bps) values
        ('1G', 1000000000);
insert into val_port_speed (port_speed, port_speed_bps) values
        ('10G', 10000000000);
insert into val_port_speed (port_speed, port_speed_bps) values
        ('40G', 40000000000);
insert into val_port_speed (port_speed, port_speed_bps) values
        ('100G', 100000000000);

insert into val_port_protocol_speed (port_protocol, port_speed)
        values ('Ethernet', '10Mb');
insert into val_port_protocol_speed (port_protocol, port_speed)
        values ('Ethernet', '100Mb');
insert into val_port_protocol_speed (port_protocol, port_speed)
        values ('Ethernet', '1G');
insert into val_port_protocol_speed (port_protocol, port_speed)
        values ('Ethernet', '10G');
insert into val_port_protocol_speed (port_protocol, port_speed)
        values ('Ethernet', '40G');
insert into val_port_protocol_speed (port_protocol, port_speed)
        values ('Ethernet', '100G');

insert into val_device_collection_type
        (device_collection_type, can_have_account_collection)
values
        ('per-device', 'N');

RAISE EXCEPTION 'XXX consdier setting these up for existing devices';

RAISE EXCEPTION 'views for org accounts (_rootcompanyid)'
