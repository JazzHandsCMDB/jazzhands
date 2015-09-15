/*
Invoked:

	--suffix
	v63
	--scan
	val_attestation_frequency
	val_approval_notifty_type
	approval_instance
	approval_instance_item
	approval_process
	val_approval_process_type
	val_approval_expiration_action
	approval_instance_link
	val_approval_chain_resp_prd
	approval_instance_step
	approval_process_chain
	approval_instance_step_notify
	val_approval_type
	v_account_manager_map
	approval_utils.v_account_collection_account_audit_map
	approval_utils.v_person_company_audit_map
	approval_utils.v_approval_matrix
	approval_utils.v_account_collection_audit_results
	approval_utils.v_account_collection_approval_process
	account_automated_reporting_ac
	automated_ac_on_person_company
	create_component_slots_by_trigger
	create_device_component_by_trigger
	delete_peraccount_account_collection
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance();
-- Creating new sequences....
CREATE SEQUENCE approval_instance_approval_instance_id_seq;
CREATE SEQUENCE approval_instance_step_approval_instance_step_id_seq;
CREATE SEQUENCE approval_process_approval_process_id_seq;
CREATE SEQUENCE approval_process_chain_approval_process_chain_id_seq;
CREATE SEQUENCE approval_instance_link_approval_instance_link_id_seq;
CREATE SEQUENCE approval_instance_item_approval_instance_item_id_seq;

DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'approval_utils';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS approval_utils;
		CREATE SCHEMA approval_utils AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA approval_utils IS 'part of jazzhands';
	END IF;
END;
$$;


--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_attestation_frequency
CREATE TABLE val_attestation_frequency
(
	attestation_frequency	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_attestation_frequency', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_attestation_frequency ADD CONSTRAINT pk_val_attestation_frequency PRIMARY KEY (attestation_frequency);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_attestation_frequency and approval_process
-- Skipping this FK since table does not exist yet
--ALTER TABLE approval_process
--	ADD CONSTRAINT fk_appproc_attest_freq
--	FOREIGN KEY (attestation_frequency) REFERENCES val_attestation_frequency(attestation_frequency);


-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_attestation_frequency');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_attestation_frequency');
-- DONE DEALING WITH TABLE val_attestation_frequency [1276215]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_approval_notifty_type
CREATE TABLE val_approval_notifty_type
(
	approval_notify_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_approval_notifty_type', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_approval_notifty_type ADD CONSTRAINT pk_val_approval_notify_type PRIMARY KEY (approval_notify_type);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_approval_notifty_type and approval_instance_step_notify
-- Skipping this FK since table does not exist yet
--ALTER TABLE approval_instance_step_notify
--	ADD CONSTRAINT fk_appinststepntfy_ntfy_typ
--	FOREIGN KEY (approval_notify_type) REFERENCES val_approval_notifty_type(approval_notify_type);


-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_approval_notifty_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_approval_notifty_type');
-- DONE DEALING WITH TABLE val_approval_notifty_type [1276190]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE approval_instance
CREATE TABLE approval_instance
(
	approval_instance_id	integer NOT NULL,
	approval_process_id	integer  NULL,
	approval_instance_name	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	approval_start	timestamp with time zone NOT NULL,
	approval_end	timestamp with time zone  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'approval_instance', true);
ALTER TABLE approval_instance
	ALTER approval_instance_id
	SET DEFAULT nextval('approval_instance_approval_instance_id_seq'::regclass);
ALTER TABLE approval_instance
	ALTER approval_start
	SET DEFAULT now();

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE approval_instance ADD CONSTRAINT pk_approval_instance PRIMARY KEY (approval_instance_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif1approval_instance ON approval_instance USING btree (approval_process_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK approval_instance and approval_instance_step
-- Skipping this FK since table does not exist yet
--ALTER TABLE approval_instance_step
--	ADD CONSTRAINT fk_app_inst_step_apinstid
--	FOREIGN KEY (approval_instance_id) REFERENCES approval_instance(approval_instance_id);


-- FOREIGN KEYS TO
-- consider FK approval_instance and approval_process
-- Skipping this FK since table does not exist yet
--ALTER TABLE approval_instance
--	ADD CONSTRAINT r_724
--	FOREIGN KEY (approval_process_id) REFERENCES approval_process(approval_process_id);


-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'approval_instance');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'approval_instance');
ALTER SEQUENCE approval_instance_approval_instance_id_seq
	 OWNED BY approval_instance.approval_instance_id;
-- DONE DEALING WITH TABLE approval_instance [1390939]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE approval_instance_item
CREATE TABLE approval_instance_item
(
	approval_instance_item_id	integer NOT NULL,
	approval_instance_link_id	integer NOT NULL,
	approval_instance_step_id	integer NOT NULL,
	next_approval_instance_item_id	integer  NULL,
	approved_category	varchar(255) NOT NULL,
	approved_label	varchar(255)  NULL,
	approved_lhs	varchar(255)  NULL,
	approved_rhs	varchar(255)  NULL,
	is_approved	character(1)  NULL,
	approved_account_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'approval_instance_item', true);
ALTER TABLE approval_instance_item
	ALTER approval_instance_item_id
	SET DEFAULT nextval('approval_instance_item_approval_instance_item_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE approval_instance_item ADD CONSTRAINT pk_approval_instance_item PRIMARY KEY (approval_instance_item_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif3approval_instance_item ON approval_instance_item USING btree (next_approval_instance_item_id);
CREATE INDEX xif4approval_instance_item ON approval_instance_item USING btree (approved_account_id);
CREATE INDEX xif1approval_instance_item ON approval_instance_item USING btree (approval_instance_step_id);
CREATE INDEX xif2approval_instance_item ON approval_instance_item USING btree (approval_instance_link_id);

-- CHECK CONSTRAINTS
ALTER TABLE approval_instance_item ADD CONSTRAINT check_yes_no_1349410716
	CHECK (is_approved = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK approval_instance_item and approval_instance_item
ALTER TABLE approval_instance_item
	ADD CONSTRAINT fk_appinstitmid_nextapiiid
	FOREIGN KEY (next_approval_instance_item_id) REFERENCES approval_instance_item(approval_instance_item_id);
-- consider FK approval_instance_item and account
ALTER TABLE approval_instance_item
	ADD CONSTRAINT fk_appinstitm_app_acctid
	FOREIGN KEY (approved_account_id) REFERENCES account(account_id);
-- consider FK approval_instance_item and approval_instance_link
-- Skipping this FK since table does not exist yet
--ALTER TABLE approval_instance_item
--	ADD CONSTRAINT fk_app_inst_item_appinstlinkid
--	FOREIGN KEY (approval_instance_link_id) REFERENCES approval_instance_link(approval_instance_link_id);

-- consider FK approval_instance_item and approval_instance_step
-- Skipping this FK since table does not exist yet
--ALTER TABLE approval_instance_item
--	ADD CONSTRAINT fk_appinstitem_appinststep
--	FOREIGN KEY (approval_instance_step_id) REFERENCES approval_instance_step(approval_instance_step_id);


-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'approval_instance_item');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'approval_instance_item');
ALTER SEQUENCE approval_instance_item_approval_instance_item_id_seq
	 OWNED BY approval_instance_item.approval_instance_item_id;
-- DONE DEALING WITH TABLE approval_instance_item [1546493]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE approval_process
CREATE TABLE approval_process
(
	approval_process_id	integer NOT NULL,
	approval_process_name	varchar(50) NOT NULL,
	approval_process_type	varchar(50)  NULL,
	description	varchar(255)  NULL,
	first_apprvl_process_chain_id	integer NOT NULL,
	property_collection_id	integer NOT NULL,
	approval_expiration_action	varchar(50) NOT NULL,
	attestation_frequency	varchar(50)  NULL,
	attestation_offset	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'approval_process', true);
ALTER TABLE approval_process
	ALTER approval_process_id
	SET DEFAULT nextval('approval_process_approval_process_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE approval_process ADD CONSTRAINT pk_approval_process PRIMARY KEY (approval_process_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif3approval_process ON approval_process USING btree (approval_expiration_action);
CREATE INDEX xif5approval_process ON approval_process USING btree (first_apprvl_process_chain_id);
CREATE INDEX xif4approval_process ON approval_process USING btree (attestation_frequency);
CREATE INDEX xif1approval_process ON approval_process USING btree (property_collection_id);
CREATE INDEX xif2approval_process ON approval_process USING btree (approval_process_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

ALTER TABLE ONLY approval_instance
	ADD CONSTRAINT fk_approval_proc_inst_aproc_id FOREIGN KEY 
	(approval_process_id) REFERENCES approval_process(approval_process_id);


-- FOREIGN KEYS TO
-- consider FK approval_process and val_approval_expiration_action
-- Skipping this FK since table does not exist yet
--ALTER TABLE approval_process
--	ADD CONSTRAINT fk_app_proc_expire_action
--	FOREIGN KEY (approval_expiration_action) REFERENCES val_approval_expiration_action(approval_expiration_action);

-- consider FK approval_process and property_collection
ALTER TABLE approval_process
	ADD CONSTRAINT fk_app_prc_propcoll_id
	FOREIGN KEY (property_collection_id) REFERENCES property_collection(property_collection_id);
-- consider FK approval_process and val_attestation_frequency
ALTER TABLE approval_process
	ADD CONSTRAINT fk_appproc_attest_freq
	FOREIGN KEY (attestation_frequency) REFERENCES val_attestation_frequency(attestation_frequency);
-- consider FK approval_process and approval_process_chain
-- Skipping this FK since table does not exist yet
--ALTER TABLE approval_process
--	ADD CONSTRAINT fk_app_proc_1st_app_proc_chnid
--	FOREIGN KEY (first_apprvl_process_chain_id) REFERENCES approval_process_chain(approval_process_chain_id);

-- consider FK approval_process and val_approval_process_type
-- Skipping this FK since table does not exist yet
--ALTER TABLE approval_process
--	ADD CONSTRAINT fk_app_proc_app_proc_typ
--	FOREIGN KEY (approval_process_type) REFERENCES val_approval_process_type(approval_process_type);


-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'approval_process');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'approval_process');
ALTER SEQUENCE approval_process_approval_process_id_seq
	 OWNED BY approval_process.approval_process_id;
-- DONE DEALING WITH TABLE approval_process [1274433]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_approval_process_type
CREATE TABLE val_approval_process_type
(
	approval_process_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_approval_process_type', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_approval_process_type ADD CONSTRAINT pk_val_approval_process_type PRIMARY KEY (approval_process_type);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_approval_process_type and approval_process
ALTER TABLE approval_process
	ADD CONSTRAINT fk_app_proc_app_proc_typ
	FOREIGN KEY (approval_process_type) REFERENCES val_approval_process_type(approval_process_type);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_approval_process_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_approval_process_type');
-- DONE DEALING WITH TABLE val_approval_process_type [1276199]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_approval_expiration_action
CREATE TABLE val_approval_expiration_action
(
	approval_expiration_action	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_approval_expiration_action', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_approval_expiration_action ADD CONSTRAINT pk_val_approval_expiration_act PRIMARY KEY (approval_expiration_action);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_approval_expiration_action and approval_process
ALTER TABLE approval_process
	ADD CONSTRAINT fk_app_proc_expire_action
	FOREIGN KEY (approval_expiration_action) REFERENCES val_approval_expiration_action(approval_expiration_action);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_approval_expiration_action');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_approval_expiration_action');
-- DONE DEALING WITH TABLE val_approval_expiration_action [1276182]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE approval_instance_link
CREATE TABLE approval_instance_link
(
	approval_instance_link_id	integer NOT NULL,
	acct_collection_acct_seq_id	integer  NULL,
	person_company_seq_id	integer  NULL,
	property_seq_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'approval_instance_link', true);
ALTER TABLE approval_instance_link
	ALTER approval_instance_link_id
	SET DEFAULT nextval('approval_instance_link_approval_instance_link_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE approval_instance_link ADD CONSTRAINT pk_approval_instance_link PRIMARY KEY (approval_instance_link_id);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK approval_instance_link and approval_instance_item
ALTER TABLE approval_instance_item
	ADD CONSTRAINT fk_app_inst_item_appinstlinkid
	FOREIGN KEY (approval_instance_link_id) REFERENCES approval_instance_link(approval_instance_link_id);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'approval_instance_link');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'approval_instance_link');
ALTER SEQUENCE approval_instance_link_approval_instance_link_id_seq
	 OWNED BY approval_instance_link.approval_instance_link_id;
-- DONE DEALING WITH TABLE approval_instance_link [1546509]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_approval_chain_resp_prd
CREATE TABLE val_approval_chain_resp_prd
(
	approval_chain_response_period	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_approval_chain_resp_prd', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_approval_chain_resp_prd ADD CONSTRAINT pk_val_approval_chain_resp_prd PRIMARY KEY (approval_chain_response_period);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_approval_chain_resp_prd and approval_process_chain
-- Skipping this FK since table does not exist yet
--ALTER TABLE approval_process_chain
--	ADD CONSTRAINT fk_appproc_chn_resp_period
--	FOREIGN KEY (approval_chain_response_period) REFERENCES val_approval_chain_resp_prd(approval_chain_response_period);


-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_approval_chain_resp_prd');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_approval_chain_resp_prd');
-- DONE DEALING WITH TABLE val_approval_chain_resp_prd [1276174]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE approval_instance_step
CREATE TABLE approval_instance_step
(
	approval_instance_step_id	integer NOT NULL,
	approval_instance_id	integer NOT NULL,
	approval_process_chain_id	integer NOT NULL,
	approval_instance_step_name	varchar(50) NOT NULL,
	approval_instance_step_due	timestamp with time zone NOT NULL,
	approval_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	approval_instance_step_start	timestamp with time zone NOT NULL,
	approval_instance_step_end	timestamp with time zone  NULL,
	approver_account_id	integer NOT NULL,
	actual_approver_account_id	integer  NULL,
	external_reference_name	varchar(255)  NULL,
	is_completed	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'approval_instance_step', true);
ALTER TABLE approval_instance_step
	ALTER approval_instance_step_id
	SET DEFAULT nextval('approval_instance_step_approval_instance_step_id_seq'::regclass);
ALTER TABLE approval_instance_step
	ALTER approval_instance_step_start
	SET DEFAULT now();
ALTER TABLE approval_instance_step
	ALTER is_completed
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE approval_instance_step ADD CONSTRAINT pk_approval_instance_step PRIMARY KEY (approval_instance_step_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif5approval_instance_step ON approval_instance_step USING btree (approval_process_chain_id);
CREATE INDEX xif4approval_instance_step ON approval_instance_step USING btree (approval_type);
CREATE INDEX xif2approval_instance_step ON approval_instance_step USING btree (approver_account_id);
CREATE INDEX xif1approval_instance_step ON approval_instance_step USING btree (approval_instance_id);
CREATE INDEX xif3approval_instance_step ON approval_instance_step USING btree (actual_approver_account_id);

-- CHECK CONSTRAINTS
ALTER TABLE approval_instance_step ADD CONSTRAINT check_yes_no_1099280524
	CHECK (is_completed = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK approval_instance_step and approval_instance_item
ALTER TABLE approval_instance_item
	ADD CONSTRAINT fk_appinstitem_appinststep
	FOREIGN KEY (approval_instance_step_id) REFERENCES approval_instance_step(approval_instance_step_id);
-- consider FK approval_instance_step and approval_instance_step_notify
-- Skipping this FK since table does not exist yet
--ALTER TABLE approval_instance_step_notify
--	ADD CONSTRAINT fk_appinststep_appinstprocid
--	FOREIGN KEY (approval_instance_step_id) REFERENCES approval_instance_step(approval_instance_step_id);


-- FOREIGN KEYS TO
-- consider FK approval_instance_step and account
ALTER TABLE approval_instance_step
	ADD CONSTRAINT fk_apstep_actual_app_acctid
	FOREIGN KEY (actual_approver_account_id) REFERENCES account(account_id);
-- consider FK approval_instance_step and approval_process_chain
-- Skipping this FK since table does not exist yet
--ALTER TABLE approval_instance_step
--	ADD CONSTRAINT fk_appinststep_app_prcchnid
--	FOREIGN KEY (approval_process_chain_id) REFERENCES approval_process_chain(approval_process_chain_id);

-- consider FK approval_instance_step and account
ALTER TABLE approval_instance_step
	ADD CONSTRAINT fk_appinststep_app_acct_id
	FOREIGN KEY (approver_account_id) REFERENCES account(account_id);
-- consider FK approval_instance_step and val_approval_type
-- Skipping this FK since table does not exist yet
--ALTER TABLE approval_instance_step
--	ADD CONSTRAINT fk_appinststep_app_type
--	FOREIGN KEY (approval_type) REFERENCES val_approval_type(approval_type);

-- consider FK approval_instance_step and approval_instance
ALTER TABLE approval_instance_step
	ADD CONSTRAINT fk_app_inst_step_apinstid
	FOREIGN KEY (approval_instance_id) REFERENCES approval_instance(approval_instance_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'approval_instance_step');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'approval_instance_step');
ALTER SEQUENCE approval_instance_step_approval_instance_step_id_seq
	 OWNED BY approval_instance_step.approval_instance_step_id;
-- DONE DEALING WITH TABLE approval_instance_step [1546520]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE approval_process_chain
CREATE TABLE approval_process_chain
(
	approval_process_chain_id	integer NOT NULL,
	approval_process_chain_name	varchar(50) NOT NULL,
	approval_chain_response_period	varchar(50)  NULL,
	description	varchar(255)  NULL,
	message	varchar(4096)  NULL,
	email_message        varchar(4096) NULL ,
	email_subject_prefix varchar(50) NULL ,
	email_subject_suffix varchar(50) NULL ,
	approving_entity	varchar(50)  NULL,
	refresh_all_data	character(1) NOT NULL,
	accept_app_process_chain_id	integer  NULL,
	reject_app_process_chain_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'approval_process_chain', true);
ALTER TABLE approval_process_chain
	ALTER approval_process_chain_id
	SET DEFAULT nextval('approval_process_chain_approval_process_chain_id_seq'::regclass);
ALTER TABLE approval_process_chain
	ALTER approval_chain_response_period
	SET DEFAULT '1 week'::character varying;
ALTER TABLE approval_process_chain
	ALTER refresh_all_data
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE approval_process_chain ADD CONSTRAINT pk_approval_process_chain PRIMARY KEY (approval_process_chain_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif1approval_process_chain ON approval_process_chain USING btree (approval_chain_response_period);
CREATE INDEX xif2approval_process_chain ON approval_process_chain USING btree (accept_app_process_chain_id);

-- CHECK CONSTRAINTS
ALTER TABLE approval_process_chain ADD CONSTRAINT check_yes_no_2125461495
	CHECK (refresh_all_data = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK approval_process_chain and approval_process
ALTER TABLE approval_process
	ADD CONSTRAINT fk_app_proc_1st_app_proc_chnid
	FOREIGN KEY (first_apprvl_process_chain_id) REFERENCES approval_process_chain(approval_process_chain_id);
-- consider FK approval_process_chain and approval_instance_step
ALTER TABLE approval_instance_step
	ADD CONSTRAINT fk_appinststep_app_prcchnid
	FOREIGN KEY (approval_process_chain_id) REFERENCES approval_process_chain(approval_process_chain_id);

-- FOREIGN KEYS TO
-- consider FK approval_process_chain and approval_process_chain
ALTER TABLE approval_process_chain
	ADD CONSTRAINT fk_apprchn_app_proc_chn
	FOREIGN KEY (accept_app_process_chain_id) REFERENCES approval_process_chain(approval_process_chain_id);
-- consider FK approval_process_chain and val_approval_chain_resp_prd
ALTER TABLE approval_process_chain
	ADD CONSTRAINT fk_appproc_chn_resp_period
	FOREIGN KEY (approval_chain_response_period) REFERENCES val_approval_chain_resp_prd(approval_chain_response_period);
-- consider FK approval_process_chain and approval_process_chain
ALTER TABLE approval_process_chain
	ADD CONSTRAINT fk_apprchn_rej_proc_chn
	FOREIGN KEY (accept_app_process_chain_id) REFERENCES approval_process_chain(approval_process_chain_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'approval_process_chain');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'approval_process_chain');
ALTER SEQUENCE approval_process_chain_approval_process_chain_id_seq
	 OWNED BY approval_process_chain.approval_process_chain_id;
-- DONE DEALING WITH TABLE approval_process_chain [1274450]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE approval_instance_step_notify
CREATE TABLE approval_instance_step_notify
(
	approv_instance_step_notify_id	integer NOT NULL,
	approval_instance_step_id	integer NOT NULL,
	approval_notify_type	varchar(50) NOT NULL,
	approval_notify_whence	timestamp with time zone NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'approval_instance_step_notify', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE approval_instance_step_notify ADD CONSTRAINT pk_approval_instance_step_noti PRIMARY KEY (approv_instance_step_notify_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif2approval_instance_step_not ON approval_instance_step_notify USING btree (approval_instance_step_id);
CREATE INDEX xif1approval_instance_step_not ON approval_instance_step_notify USING btree (approval_notify_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK approval_instance_step_notify and approval_instance_step
ALTER TABLE approval_instance_step_notify
	ADD CONSTRAINT fk_appinststep_appinstprocid
	FOREIGN KEY (approval_instance_step_id) REFERENCES approval_instance_step(approval_instance_step_id);
-- consider FK approval_instance_step_notify and val_approval_notifty_type
ALTER TABLE approval_instance_step_notify
	ADD CONSTRAINT fk_appinststepntfy_ntfy_typ
	FOREIGN KEY (approval_notify_type) REFERENCES val_approval_notifty_type(approval_notify_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'approval_instance_step_notify');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'approval_instance_step_notify');
-- DONE DEALING WITH TABLE approval_instance_step_notify [1274421]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_account_manager_map
CREATE VIEW v_account_manager_map AS
 WITH dude_base AS (
         SELECT a_1.login,
            a_1.account_id,
            a_1.person_id,
            a_1.company_id,
            COALESCE(p.preferred_first_name, p.first_name) AS first_name,
            COALESCE(p.preferred_last_name, p.last_name) AS last_name,
            pc.manager_person_id
           FROM account a_1
             JOIN person_company pc USING (company_id, person_id)
             JOIN person p USING (person_id)
          WHERE a_1.is_enabled = 'Y'::bpchar AND pc.person_company_relation::text = 'employee'::text AND a_1.account_role::text = 'primary'::text AND a_1.account_type::text = 'person'::text
        ), dude AS (
         SELECT dude_base.login,
            dude_base.account_id,
            dude_base.person_id,
            dude_base.company_id,
            dude_base.first_name,
            dude_base.last_name,
            dude_base.manager_person_id,
            concat(dude_base.first_name, ' ', dude_base.last_name, ' (', dude_base.login, ')') AS human_readable
           FROM dude_base
        )
 SELECT a.login,
    a.account_id,
    a.person_id,
    a.company_id,
    a.first_name,
    a.last_name,
    a.manager_person_id,
    a.human_readable,
    mp.account_id AS manager_account_id,
    mp.login AS manager_login,
    concat(mp.first_name, ' ', mp.last_name, ' (', mp.login, ')') AS manager_human_readable
   FROM dude a
     JOIN dude mp ON mp.person_id = a.manager_person_id;

-- DONE DEALING WITH TABLE v_account_manager_map [1283126]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_approval_type
CREATE TABLE val_approval_type
(
	approval_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_approval_type', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_approval_type ADD CONSTRAINT pk_val_approval_type PRIMARY KEY (approval_type);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_approval_type and approval_instance_step
ALTER TABLE approval_instance_step
	ADD CONSTRAINT fk_appinststep_app_type
	FOREIGN KEY (approval_type) REFERENCES val_approval_type(approval_type);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_approval_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_approval_type');
-- DONE DEALING WITH TABLE val_approval_type [1276207]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE approval_utils.v_account_collection_account_audit_map
CREATE VIEW approval_utils.v_account_collection_account_audit_map AS
 WITH all_audrecs AS (
         SELECT acaa.account_collection_id,
            acaa.account_id,
            acaa.account_id_rank,
            acaa.start_date,
            acaa.finish_date,
            acaa.data_ins_user,
            acaa.data_ins_date,
            acaa.data_upd_user,
            acaa.data_upd_date,
            acaa."aud#action",
            acaa."aud#timestamp",
            acaa."aud#user",
            acaa."aud#seq",
            row_number() OVER (PARTITION BY aca.account_collection_id, aca.account_id ORDER BY acaa."aud#timestamp" DESC) AS rownum
           FROM account_collection_account aca
             JOIN audit.account_collection_account acaa USING (account_collection_id, account_id)
          WHERE acaa."aud#action" = ANY (ARRAY['UPD'::bpchar, 'INS'::bpchar])
        )
 SELECT all_audrecs."aud#seq" AS audit_seq_id,
    all_audrecs.account_collection_id,
    all_audrecs.account_id,
    all_audrecs.account_id_rank,
    all_audrecs.start_date,
    all_audrecs.finish_date,
    all_audrecs.data_ins_user,
    all_audrecs.data_ins_date,
    all_audrecs.data_upd_user,
    all_audrecs.data_upd_date,
    all_audrecs."aud#action",
    all_audrecs."aud#timestamp",
    all_audrecs."aud#user",
    all_audrecs."aud#seq",
    all_audrecs.rownum
   FROM all_audrecs
  WHERE all_audrecs.rownum = 1;

-- DONE DEALING WITH TABLE approval_utils.v_account_collection_account_audit_map [1283137]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE approval_utils.v_person_company_audit_map
CREATE VIEW approval_utils.v_person_company_audit_map AS
 WITH all_audrecs AS (
         SELECT pca.company_id,
            pca.person_id,
            pca.person_company_status,
            pca.person_company_relation,
            pca.is_exempt,
            pca.is_management,
            pca.is_full_time,
            pca.description,
            pca.employee_id,
            pca.payroll_id,
            pca.external_hr_id,
            pca.position_title,
            pca.badge_system_id,
            pca.hire_date,
            pca.termination_date,
            pca.manager_person_id,
            pca.supervisor_person_id,
            pca.nickname,
            pca.data_ins_user,
            pca.data_ins_date,
            pca.data_upd_user,
            pca.data_upd_date,
            pca."aud#action",
            pca."aud#timestamp",
            pca."aud#user",
            pca."aud#seq",
            row_number() OVER (PARTITION BY pc.person_id, pc.company_id ORDER BY pca."aud#timestamp" DESC) AS rownum
           FROM person_company pc
             JOIN audit.person_company pca USING (person_id, company_id)
          WHERE pca."aud#action" = ANY (ARRAY['UPD'::bpchar, 'INS'::bpchar])
        )
 SELECT all_audrecs."aud#seq" AS audit_seq_id,
    all_audrecs.company_id,
    all_audrecs.person_id,
    all_audrecs.person_company_status,
    all_audrecs.person_company_relation,
    all_audrecs.is_exempt,
    all_audrecs.is_management,
    all_audrecs.is_full_time,
    all_audrecs.description,
    all_audrecs.employee_id,
    all_audrecs.payroll_id,
    all_audrecs.external_hr_id,
    all_audrecs.position_title,
    all_audrecs.badge_system_id,
    all_audrecs.hire_date,
    all_audrecs.termination_date,
    all_audrecs.manager_person_id,
    all_audrecs.supervisor_person_id,
    all_audrecs.nickname,
    all_audrecs.data_ins_user,
    all_audrecs.data_ins_date,
    all_audrecs.data_upd_user,
    all_audrecs.data_upd_date,
    all_audrecs."aud#action",
    all_audrecs."aud#timestamp",
    all_audrecs."aud#user",
    all_audrecs."aud#seq",
    all_audrecs.rownum
   FROM all_audrecs
  WHERE all_audrecs.rownum = 1;

-- DONE DEALING WITH TABLE approval_utils.v_person_company_audit_map [1283142]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE approval_utils.v_approval_matrix
CREATE VIEW approval_utils.v_approval_matrix AS
 SELECT ap.approval_process_id,
    ap.first_apprvl_process_chain_id,
    ap.approval_process_name,
    c.approval_chain_response_period AS approval_response_period,
    ap.approval_expiration_action,
    ap.attestation_frequency,
    ap.attestation_offset,
        CASE
            WHEN ap.attestation_frequency::text = 'monthly'::text THEN to_char(now(), 'YYYY-MM'::text)
            WHEN ap.attestation_frequency::text = 'weekly'::text THEN concat('week ', to_char(now(), 'WW'::text), ' - ', to_char(now(), 'YYY-MM-DD'::text))
            WHEN ap.attestation_frequency::text = 'quarterly'::text THEN concat(to_char(now(), 'YYYY'::text), 'q', to_char(now(), 'Q'::text))
            ELSE 'unknown'::text
        END AS current_attestation_name,
    p.property_id,
    p.property_name,
    p.property_type,
    p.property_value,
    split_part(p.property_value::text, ':'::text, 1) AS property_val_lhs,
    split_part(p.property_value::text, ':'::text, 2) AS property_val_rhs,
    c.approval_process_chain_id,
    c.approving_entity,
    c.approval_process_chain_name,
    ap.description AS approval_process_description,
    c.description AS approval_chain_description
   FROM approval_process ap
     JOIN property_collection pc USING (property_collection_id)
     JOIN property_collection_property pcp USING (property_collection_id)
     JOIN property p USING (property_name, property_type)
     LEFT JOIN approval_process_chain c ON c.approval_process_chain_id = ap.first_apprvl_process_chain_id
  WHERE ap.approval_process_name::text = 'ReportingAttest'::text AND ap.approval_process_type::text = 'attestation'::text;

-- DONE DEALING WITH TABLE approval_utils.v_approval_matrix [1283132]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE approval_utils.v_account_collection_audit_results
CREATE VIEW approval_utils.v_account_collection_audit_results AS
 WITH membermap AS (
         SELECT aca.audit_seq_id,
            ac.account_collection_id,
            ac.account_collection_name,
            ac.account_collection_type,
            a.login,
            a.account_id,
            a.person_id,
            a.company_id,
            a.first_name,
            a.last_name,
            a.manager_person_id,
            a.human_readable,
            a.manager_account_id,
            a.manager_login,
            a.manager_human_readable
           FROM v_account_manager_map a
             JOIN approval_utils.v_account_collection_account_audit_map aca USING (account_id)
             JOIN account_collection ac USING (account_collection_id)
          WHERE a.account_id <> a.manager_account_id
          ORDER BY a.manager_login, a.last_name, a.first_name, a.account_id
        )
 SELECT membermap.audit_seq_id,
    membermap.account_collection_id,
    membermap.account_collection_name,
    membermap.account_collection_type,
    membermap.login,
    membermap.account_id,
    membermap.person_id,
    membermap.company_id,
    membermap.first_name,
    membermap.last_name,
    membermap.manager_person_id,
    membermap.human_readable,
    membermap.manager_account_id,
    membermap.manager_login,
    membermap.manager_human_readable
   FROM membermap;

-- DONE DEALING WITH TABLE approval_utils.v_account_collection_audit_results [1283148]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE approval_utils.v_account_collection_approval_process
CREATE VIEW approval_utils.v_account_collection_approval_process AS
 WITH combo AS (
         WITH foo AS (
                 SELECT mm.audit_seq_id,
                    mm.account_collection_id,
                    mm.account_collection_name,
                    mm.account_collection_type,
                    mm.login,
                    mm.account_id,
                    mm.person_id,
                    mm.company_id,
                    mm.first_name,
                    mm.last_name,
                    mm.manager_person_id,
                    mm.human_readable,
                    mm.manager_account_id,
                    mm.manager_login,
                    mm.manager_human_readable,
                    mx.approval_process_id,
                    mx.first_apprvl_process_chain_id,
                    mx.approval_process_name,
                    mx.approval_response_period,
                    mx.approval_expiration_action,
                    mx.attestation_frequency,
                    mx.attestation_offset,
                    mx.current_attestation_name,
                    mx.property_id,
                    mx.property_name,
                    mx.property_type,
                    mx.property_value,
                    mx.property_val_lhs,
                    mx.property_val_rhs,
                    mx.approval_process_chain_id,
                    mx.approving_entity,
                    mx.approval_process_chain_name,
                    mx.approval_process_description,
                    mx.approval_chain_description
                   FROM approval_utils.v_account_collection_audit_results mm
                     JOIN approval_utils.v_approval_matrix mx ON mx.property_val_lhs = mm.account_collection_type::text
                  ORDER BY mm.manager_account_id, mm.account_id
                )
         SELECT foo.login,
            foo.account_id,
            foo.person_id,
            foo.company_id,
            foo.manager_account_id,
            foo.manager_login,
            'account_collection_account'::text AS audit_table,
            foo.audit_seq_id,
            foo.approval_process_id,
            foo.approval_process_chain_id,
            foo.approving_entity,
            foo.approval_process_description,
            foo.approval_chain_description,
            foo.approval_response_period,
            foo.approval_expiration_action,
            foo.attestation_frequency,
            foo.current_attestation_name,
            foo.attestation_offset,
            foo.approval_process_chain_name,
            foo.account_collection_type AS approval_category,
            concat('Verify ', foo.account_collection_type) AS approval_label,
            foo.human_readable AS approval_lhs,
            foo.account_collection_name AS approval_rhs
           FROM foo
        UNION
         SELECT mm.login,
            mm.account_id,
            mm.person_id,
            mm.company_id,
            mm.manager_account_id,
            mm.manager_login,
            'account_collection_account'::text AS audit_table,
            mm.audit_seq_id,
            mx.approval_process_id,
            mx.approval_process_chain_id,
            mx.approving_entity,
            mx.approval_process_description,
            mx.approval_chain_description,
            mx.approval_response_period,
            mx.approval_expiration_action,
            mx.attestation_frequency,
            mx.current_attestation_name,
            mx.attestation_offset,
            mx.approval_process_chain_name,
            mx.approval_process_name AS approval_category,
            'Verify Manager'::text AS approval_label,
            mm.human_readable AS approval_lhs,
            concat('Reports to ', mm.manager_human_readable) AS approval_rhs
           FROM approval_utils.v_approval_matrix mx
             JOIN property p ON p.property_name::text = mx.property_val_rhs AND p.property_type::text = mx.property_val_lhs
             JOIN approval_utils.v_account_collection_audit_results mm ON mm.account_collection_id = p.property_value_account_coll_id
          WHERE p.account_id <> mm.account_id
        UNION
         SELECT mm.login,
            mm.account_id,
            mm.person_id,
            mm.company_id,
            mm.manager_account_id,
            mm.manager_login,
            'person_company'::text AS audit_table,
            pcm.audit_seq_id,
            am.approval_process_id,
            am.approval_process_chain_id,
            am.approving_entity,
            am.approval_process_description,
            am.approval_chain_description,
            am.approval_response_period,
            am.approval_expiration_action,
            am.attestation_frequency,
            am.current_attestation_name,
            am.attestation_offset,
            am.approval_process_chain_name,
            am.property_val_rhs AS approval_category,
                CASE
                    WHEN am.property_val_rhs = 'position_title'::text THEN 'Verify Position Title'::text
                    ELSE NULL::text
                END AS aproval_label,
            mm.human_readable AS approval_lhs,
                CASE
                    WHEN am.property_val_rhs = 'position_title'::text THEN pcm.position_title
                    ELSE NULL::character varying
                END AS approval_rhs
           FROM v_account_manager_map mm
             JOIN approval_utils.v_person_company_audit_map pcm USING (person_id, company_id)
             JOIN approval_utils.v_approval_matrix am ON am.property_val_lhs = 'person_company'::text AND am.property_val_rhs = 'position_title'::text
        )
 SELECT combo.login,
    combo.account_id,
    combo.person_id,
    combo.company_id,
    combo.manager_account_id,
    combo.manager_login,
    combo.audit_table,
    combo.audit_seq_id,
    combo.approval_process_id,
    combo.approval_process_chain_id,
    combo.approving_entity,
    combo.approval_process_description,
    combo.approval_chain_description,
    combo.approval_response_period,
    combo.approval_expiration_action,
    combo.attestation_frequency,
    combo.current_attestation_name,
    combo.attestation_offset,
    combo.approval_process_chain_name,
    combo.approval_category,
    combo.approval_label,
    combo.approval_lhs,
    combo.approval_rhs
   FROM combo
  WHERE combo.manager_account_id <> combo.account_id
  ORDER BY combo.manager_login, combo.account_id, combo.approval_label;

-- DONE DEALING WITH TABLE approval_utils.v_account_collection_approval_process [1283153]
--------------------------------------------------------------------
-- Dropping obsoleted sequences....


-- Dropping obsoleted audit sequences....


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
-- triggers
DROP TRIGGER IF EXISTS trigger_automated_ac_on_person ON person;

------------------------------------------------------------------------------
-- DEALING WITH automated_tools
------------------------------------------------------------------------------

-- Copyright (c) 2015, Todd M. Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--       http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

\set ON_ERROR_STOP

DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'approval_utils';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS approval_utils;
		CREATE SCHEMA approval_utils AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA approval_utils IS 'part of jazzhands';
	END IF;
END;
$$;

CREATE OR REPLACE FUNCTION approval_utils.calculate_due_date(
	response_period	interval,
	from_when	timestamp DEFAULT now()
) RETURNS timestamp AS $$
DECLARE
BEGIN
	RETURN date_trunc('day', (CASE 
		WHEN to_char(from_when + response_period::interval, 'D') = '1'
			THEN from_when + response_period::interval + '1 day'::interval
		WHEN to_char(from_when + response_period::interval, 'D') = '7'
			THEN from_when + response_period::interval + '2 days'::interval
		ELSE from_when + response_period::interval END)::timestamp) + 
			'1 day'::interval - '1 second'::interval
	;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = approval_utils,jazzhands;

CREATE OR REPLACE FUNCTION 
		approval_utils.get_or_create_correct_approval_instance_link(
	approval_instance_item_id
					approval_instance_item.approval_instance_item_id%TYPE,
	approval_instance_link_id	
					approval_instance_link.approval_instance_link_id%TYPE
) RETURNS approval_instance_link.approval_instance_link_id%TYPE AS $$
DECLARE
	_v			approval_utils.v_account_collection_approval_process%ROWTYPE;
	_l			approval_instance_link%ROWTYPE;
	_acaid		INTEGER;
	_pcid		INTEGER;
BEGIN
	EXECUTE 'SELECT * FROM approval_instance_link WHERE
		approval_instance_link_id = $1
	' INTO _l USING approval_instance_link_id;

	_v := approval_utils.refresh_approval_instance_item(approval_instance_item_id);

	IF _v.audit_table = 'account_collection_account' THEN
		IF _v.audit_seq_id IS NOT 
					DISTINCT FROM  _l.acct_collection_acct_seq_id THEN
			_acaid := _v.audit_seq_id;
			_pcid := NULL;
		END IF;
	ELSIF _v.audit_table = 'person_company' THEN
		_acaid := NULL;
		_pcid := _v.audit_seq_id;
		IF _v.audit_seq_id IS NOT DISTINCT FROM  _l.person_company_seq_id THEN
			_acaid := NULL;
			_pcid := _v.audit_seq_id;
		END IF;
	ELSE
		RAISE EXCEPTION 'Unable to handle audit table %', _v.audit_table;
	END IF;

	IF _acaid IS NOT NULL or _pcid IS NOT NULL THEN
		EXECUTE '
			INSERT INTO approval_instance_link (
				acct_collection_acct_seq_id, person_company_seq_id
			) VALUES ($1, $2) RETURNING *
		' INTO _l USING _acaid, _pcid;
		RETURN _l.approval_instance_link_id;
	ELSE
		RETURN approval_instance_link_id;
	END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = approval_utils,jazzhands;


CREATE OR REPLACE FUNCTION approval_utils.refresh_approval_instance_item(
	approval_instance_item_id
					approval_instance_item.approval_instance_item_id%TYPE
) RETURNS approval_utils.v_account_collection_approval_process AS $$
DECLARE
	_i	approval_instance_item.approval_instance_item_id%TYPE;
	_r	approval_utils.v_account_collection_approval_process%ROWTYPE;
BEGIN
	--
	-- XXX p comes out of one of the three clauses in 
	-- v_account_collection_approval_process .  It is likely that that view
	-- needs to be broken into 2 or 3 views joined together so there is no
	-- code redundancy.  This is almost certainly true because it is a pain
	-- to keep column lists in syn everywhere
	EXECUTE '
		WITH p AS (
		SELECT  login,
		        account_id,
		        person_id,
		        company_id,
		        manager_account_id,
		        manager_login,
		        ''person_company''::text as audit_table,
		        audit_seq_id,
		        approval_process_id,
		        approval_process_chain_id,
		        approving_entity,
				approval_process_description,
				approval_chain_description,
				approval_response_period,
				approval_expiration_action,
				attestation_frequency,
				current_attestation_name,
				attestation_offset,
				approval_process_chain_name,
				property_val_rhs AS approval_category,
				CASE
					WHEN property_val_rhs = ''position_title''
						THEN ''Verify Position Title''
					END as approval_label,
		        human_readable AS approval_lhs,
		        CASE
		            WHEN property_val_rhs = ''position_title'' THEN pcm.position_title
		        END as approval_rhs
		FROM    v_account_manager_map mm
		        INNER JOIN v_person_company_audit_map pcm
		            USING (person_id,company_id)
		        INNER JOIN v_approval_matrix am
		            ON property_val_lhs = ''person_company''
		            AND property_val_rhs = ''position_title''
		), x AS ( select i.approval_instance_item_id, p.*
		from	approval_instance_item i
			inner join approval_instance_step s
				using (approval_instance_step_id)
			inner join approval_instance_link l
				using (approval_instance_link_id)
			inner join audit.account_collection_account res
				on res."aud#seq" = l.acct_collection_acct_seq_id
			 inner join v_account_collection_approval_process p
				on i.approved_label = p.approval_label
				and res.account_id = p.account_id
		UNION
		select i.approval_instance_item_id, p.*
		from	approval_instance_item i
			inner join approval_instance_step s
				using (approval_instance_step_id)
			inner join approval_instance_link l
				using (approval_instance_link_id)
			inner join audit.person_company res
				on res."aud#seq" = l.person_company_seq_id
			 inner join p
				on i.approved_label = p.approval_label
				and res.person_id = p.person_id
				and res.company_id = p.company_id
		) SELECT 
			login,
			account_id,
			person_id,
			company_id,
			manager_account_id,
			manager_login,
			audit_table,
			audit_seq_id,
			approval_process_id,
			approval_process_chain_id,
			approving_entity,
			approval_process_description,
			approval_chain_description,
			approval_response_period,
			approval_expiration_action,
			attestation_frequency,
			current_attestation_name,
			attestation_offset,
			approval_process_chain_name,
			approval_category,
			approval_label,
			approval_lhs,
			approval_rhs
		FROM x where	approval_instance_item_id = $1
	' INTO _r USING approval_instance_item_id;
	RETURN _r;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = approval_utils,jazzhands;
	

CREATE OR REPLACE FUNCTION approval_utils.build_attest()
RETURNS integer AS $$
DECLARE
	_r			RECORD;
	ai			approval_instance%ROWTYPE;
	ail			approval_instance_link%ROWTYPE;
	ais			approval_instance_step%ROWTYPE;
	aii			approval_instance_item%ROWTYPE;
	tally		INTEGER;
	_acaid		INTEGER;
	_pcid		INTEGER;
BEGIN
	tally := 0;

	-- XXX need to add magic for entering after the right day of the period.
	FOR _r IN SELECT * 
				FROM v_account_collection_approval_process
				WHERE (approval_process_id, current_attestation_name) NOT IN
					(SELECT approval_process_id, approval_instance_name 
					 FROM approval_instance
					)
	LOOP
		IF _r.approving_entity != 'manager' THEN
			RAISE EXCEPTION 'Do not know how to process approving entity %',
				_r.approving_entity;
		END IF;

		IF (ai.approval_process_id IS NULL OR
				ai.approval_process_id != _r.approval_process_id) THEN

			INSERT INTO approval_instance ( 
				approval_process_id, description, approval_instance_name
			) VALUES ( 
				_r.approval_process_id, 
				_r.approval_process_description, _r.current_attestation_name
			) RETURNING * INTO ai;
		END IF;

		IF ais.approver_account_id IS NULL OR
				ais.approver_account_id != _r.manager_account_id THEN

			INSERT INTO approval_instance_step (
				approval_process_chain_id, approver_account_id, 
				approval_instance_id, approval_type,  
				approval_instance_step_name,
				approval_instance_step_due, 
				description
			) VALUES (
				_r.approval_process_chain_id, _r.manager_account_id,
				ai.approval_instance_id, 'account',
				_r.approval_process_chain_name,
				approval_utils.calculate_due_date(_r.approval_response_period::interval),
				concat(_r.approval_chain_description, ' - ', _r.manager_login)
			) RETURNING * INTO ais;
		END IF;

		IF _r.audit_table = 'account_collection_account' THEN
			_acaid := _r.audit_seq_id;
			_pcid := NULL;
		ELSIF _R.audit_table = 'person_company' THEN
			_acaid := NULL;
			_pcid := _r.audit_seq_id;
		END IF;

		INSERT INTO approval_instance_link ( 
			acct_collection_acct_seq_id, person_company_seq_id
		) VALUES ( 
			_acaid, _pcid
		) RETURNING * INTO ail;

		--
		-- need to create or find the correct step to insert someone into;
		-- probably need a val table that says if every approvers stuff should
		-- be aggregated into one step or ifs a step per underling.
		--

		INSERT INTO approval_instance_item (
			approval_instance_link_id, approval_instance_step_id,
			approved_category, approved_label, approved_lhs, approved_rhs
		) VALUES ( 
			ail.approval_instance_link_id, ais.approval_instance_step_id,
			_r.approval_category, _r.approval_label, _r.approval_lhs, _r.approval_rhs
		) RETURNING * INTO aii;

		UPDATE approval_instance_step 
		SET approval_instance_id = ai.approval_instance_id
		WHERE approval_instance_step_id = ais.approval_instance_step_id;
		tally := tally + 1;
	END LOOP;
	RETURN tally;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = approval_utils,jazzhands;

--
-- returns new approval_instance_item based on how an existing one is
-- approved.  returns NULL if there is no next step
--
-- XXX - I suspect build_attest needs to call this.  There is redundancy
-- between the two of them.
--
CREATE OR REPLACE FUNCTION approval_utils.build_next_approval_item(
	approval_instance_item_id
					approval_instance_item.approval_instance_item_id%TYPE,
	approval_process_chain_id		
						approval_process_chain.approval_process_chain_id%TYPE,
	approval_instance_id
				approval_instance.approval_instance_id%TYPE,
	approved				char(1),
	approving_account_id	account.account_id%TYPE,
	new_value				text DEFAULT NULL
) RETURNS approval_instance_item.approval_instance_item_id%TYPE AS $$
DECLARE
	_r		RECORD;
	_apc	approval_process_chain%ROWTYPE;	
	_new	approval_instance_item%ROWTYPE;	
	_acid	account.account_id%TYPE;
	_step	approval_instance_step.approval_instance_step_id%TYPE;
	_l		approval_instance_link.approval_instance_link_id%TYPE;
	apptype	text;
	_v			approval_utils.v_account_collection_approval_process%ROWTYPE;
BEGIN
	EXECUTE '
		SELECT apc.*
		FROM approval_process_chain apc
		WHERE approval_process_chain_id=$1
	' INTO _apc USING approval_process_chain_id;

	IF _apc.approval_process_chain_id is NULL THEN
		RAISE EXCEPTION 'Unable to follow this chain: %',
			approval_process_chain_id;
	END IF;

	EXECUTE '
		SELECT aii.*, ais.approver_account_id
		FROM approval_instance_item  aii
			INNER JOIN approval_instance_step ais
				USING (approval_instance_step_id)
		WHERE approval_instance_item_id=$1
	' INTO _r USING approval_instance_item_id;

	IF _apc.approving_entity = 'manager' THEN
		apptype := 'account';
		_acid := NULL;
		EXECUTE '
			SELECT manager_account_id
			FROM	v_account_manager_map
			WHERE	account_id = $1
		' INTO _acid USING approving_account_id;
		--
		-- return NULL because there is no manager for the person
		--
		IF _acid IS NULL THEN
			RETURN NULL;
		END IF;
	ELSIF _apc.approving_entity = 'jira-hr' THEN
		apptype := 'jira-hr';
		_acid :=  _r.approver_account_id;
	ELSIF _apc.approving_entity = 'recertify' THEN
		apptype := 'account';
		EXECUTE '
			SELECT approver_account_id
			FROM approval_instance_item  aii
				INNER JOIN approval_instance_step ais
					USING (approval_instance_step_id)
			WHERE approval_instance_item_id IN (
				SELECT	approval_instance_item_id
				FROM	approval_instance_item
				WHERE	next_approval_instance_item_id = $1
			)
		' INTO _acid USING approval_instance_item_id;
	ELSE
		RAISE EXCEPTION 'Can not handle approving entity %',
			_apc.approving_entity;
	END IF;

	IF _acid IS NULL THEN
		RAISE EXCEPTION 'This whould not happen:  Unable to discern approving account.';
	END IF;

	EXECUTE '
		SELECT	approval_instance_step_id
		FROM	approval_instance_step
		WHERE	approval_process_chain_id = $1
		AND		approval_instance_id = $2
		AND		approver_account_id = $3
	' INTO _step USING approval_process_chain_id,
		approval_instance_id, _acid;

	--
	-- _new gets built out for all the fields that should get inserted,
	-- and then at the end is stomped on by what actually gets inserted.
	--

	IF _step IS NULL THEN
		EXECUTE '
			INSERT INTO approval_instance_step (
				approval_instance_id, approval_process_chain_id,
				approval_instance_step_name,
				approver_account_id, approval_type, 
				approval_instance_step_due,
				description
			) VALUES (
				$1, $2, $3, $4, $5, approval_utils.calculate_due_date($6), $7
			) RETURNING approval_instance_step_id
		' INTO _step USING 
			approval_instance_id, approval_process_chain_id,
			_apc.approval_process_chain_name,
			_acid, apptype, 
			_apc.approval_chain_response_period::interval,
			concat(_apc.description, ' for ', _r.approver_account_id, ' by ',
			approving_account_id);
	END IF;

	IF _apc.refresh_all_data = 'Y' THEN
		-- this is called twice, should rethink how to not
		_v := approval_utils.refresh_approval_instance_item(approval_instance_item_id);
		_l := approval_utils.get_or_create_correct_approval_instance_link(
			approval_instance_item_id,
			_r.approval_instance_link_id
		);
		_new.approval_instance_link_id := _l;
		_new.approved_label := _v.approval_label;
		_new.approved_category := _v.approval_category;
		_new.approved_lhs := _v.approval_lhs;
		_new.approved_rhs := _v.approval_rhs;
	ELSE
		_new.approval_instance_link_id := _r.approval_instance_link_id;
		_new.approved_label := _r.approved_label;
		_new.approved_category := _r.approved_category;
		_new.approved_lhs := _r.approved_lhs;
		IF new_value IS NULL THEN
			_new.approved_rhs := _r.approved_rhs;
		ELSE
			_new.approved_rhs := new_value;
		END IF;
	END IF;

	-- RAISE NOTICE 'step is %', _step;
	-- RAISE NOTICE 'acid is %', _acid;

	EXECUTE '
		INSERT INTO approval_instance_item
			(approval_instance_link_id, approved_label, approved_category,
				approved_lhs, approved_rhs, approval_instance_step_id
			) SELECT $2, $3, $4,
				$5, $6, $7
			FROM approval_instance_item
			WHERE approval_instance_item_id = $1
			RETURNING *
	' INTO _new USING approval_instance_item_id, 
		_new.approval_instance_link_id, _new.approved_label, _new.approved_category,
		_new.approved_lhs, _new.approved_rhs,
		_step;

	-- RAISE NOTICE 'returning %', _new.approval_instance_item_id;
	RETURN _new.approval_instance_item_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = approval_utils,jazzhands;

CREATE OR REPLACE FUNCTION approval_utils.approve(
	approval_instance_item_id	
					approval_instance_item.approval_instance_item_id%TYPE,
	approved				char(1),
	approving_account_id	account.account_id%TYPE,
	new_value				text DEFAULT NULL
) RETURNS boolean AS $$
DECLARE
	_r		RECORD;
	_aii	approval_instance_item%ROWTYPE;	
	_new	approval_instance_item.approval_instance_item_id%TYPE;	
	_chid	approval_process_chain.approval_process_chain_id%TYPE;
	_tally	INTEGER;
BEGIN
	EXECUTE '
		SELECT 	aii.approval_instance_item_id,
			ais.approval_instance_step_id,
			ais.approval_instance_id,
			ais.approver_account_id,
			aii.is_approved,
			ais.is_completed,
			aic.accept_app_process_chain_id,
			aic.reject_app_process_chain_id
   	     FROM    approval_instance ai
   	             INNER JOIN approval_instance_step ais
   	                 USING (approval_instance_id)
   	             INNER JOIN approval_instance_item aii
   	                 USING (approval_instance_step_id)
   	             INNER JOIN approval_instance_link ail
   	                 USING (approval_instance_link_id)
			INNER JOIN approval_process_chain aic
				USING (approval_process_chain_id)
		WHERE approval_instance_item_id = $1
	' USING approval_instance_item_id INTO 	_r;


	--
	-- Ensure that only the person or their management chain can approve
	-- others
	IF _r.approver_account_id != approving_account_id THEN
		EXECUTE '
			WITH RECURSIVE rec (
				root_account_id,
				account_id,
				manager_account_id
			) as (
					SELECT  account_id as root_account_id,
							account_id, manager_account_id
					FROM	v_account_manager_map
				UNION ALL
					SELECT a.root_account_id, m.account_id, m.manager_account_id
					FROM rec a join v_account_manager_map m
						ON a.manager_account_id = m.account_id
			) SELECT count(*) from rec where root_account_id = $1
				and manager_account_id = $2
		' INTO _tally USING _r.approver_account_id, approving_account_id;

		IF _tally = 0 THEN
			EXECUTE '
				SELECT	count(*)
				FROM	property
						INNER JOIN v_acct_coll_acct_expanded e
						USING (account_collection_id)
				WHERE	property_type = ''Defaults''
				AND		property_name = ''_can_approve_all''
				AND		e.account_id = $1
			' INTO _tally USING approving_account_id;

			IF _tally = 0 THEN
				RAISE EXCEPTION 'Only a person and their management chain may approve others';
			END IF;
		END IF;

	END IF;

	IF _r.approval_instance_item_id IS NULL THEN
		RAISE EXCEPTION 'Unknown approval_instance_item_id %',
			approval_instance_item_id;
	END IF;

	IF _r.is_approved IS NOT NULL THEN
		RAISE EXCEPTION 'Approval is already completed.';
	END IF;

	EXECUTE '
		UPDATE approval_instance_item
		SET is_approved = $2,
		approved_account_id = $3
		WHERE approval_instance_item_id = $1
	' USING approval_instance_item_id, approved, approving_account_id;

	IF approved = 'N' THEN
		IF _r.reject_app_process_chain_id IS NOT NULL THEN
			_chid := _r.reject_app_process_chain_id;	
		END IF;
	ELSIF approved = 'Y' THEN
		IF _r.accept_app_process_chain_id IS NOT NULL THEN
			_chid := _r.accept_app_process_chain_id;
		END IF;
	ELSE
		RAISE EXCEPTION 'Approved must be Y or N';
	END IF;

	IF _chid IS NOT NULL THEN
		_new := approval_utils.build_next_approval_item(
			approval_instance_item_id, _chid,
			_r.approval_instance_id, approved,
			approving_account_id, new_value);

		EXECUTE '
			UPDATE approval_instance_item
			SET next_approval_instance_item_id = $2
			WHERE approval_instance_item_id = $1
		' USING approval_instance_item_id, _new;
	END IF;

	RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = approval_utils,jazzhands;

grant select on all tables in schema approval_utils to iud_role;
grant usage on schema approval_utils to iud_role;
revoke all on schema approval_utils from public;
revoke all on  all functions in schema approval_utils from public;
grant execute on all functions in schema approval_utils to iud_role;

------------------------------------------------------------------------------
-- DONE DEALING WITH automated_tools
------------------------------------------------------------------------------

/*
 * Copyright (c) 2015 Todd Kover
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

/*
 * These routines support the management of account collections for people that
 * report to and rollup to a given person.
 *
 * They were written with multiple account_realms in mind, although the triggers
 * only support all this for the default realm as defined by properties, so
 * a multiple realm context is untested.
 *
 * Many of the routines accept optional arguments for various fields.  This is
 * to speed up calling functions so the same queries do not need to be run
 * multiple times.  There is probably room for additional cleverness around
 * all this.  If those values are not specified, then they get looked up.
 *
 * This handles both contractors and employees.  It should probably be
 * tweaked to just handle employees.
 */

/*
 * $Id$
 */

-- Create schema if it does not exist, do nothing otherwise.
DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'auto_ac_manip';
	IF _tal = 0 THEN
		DROP SCHEMA IF EXISTS auto_ac_manip;
		CREATE SCHEMA auto_ac_manip AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA auto_ac_manip IS 'part of jazzhands';
	END IF;
END;
$$;

\set ON_ERROR_STOP


--------------------------------------------------------------------------------
-- returns the Id tag for CM
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.id_tag()
RETURNS VARCHAR AS $$
BEGIN
	RETURN('<-- $Id$ -->');
END;
$$ LANGUAGE plpgsql;
-- end of procedure id_tag

--------------------------------------------------------------------------------
--
-- renames a person's magic account collection when login name changes
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.rename_automated_report_acs(
	account_id			account.account_id%TYPE,
	old_login			account.login%TYPE,
	new_login			account.login%TYPE,
	account_realm_id	account.account_realm_id%TYPE
) RETURNS VOID AS $_$
BEGIN
	EXECUTE '
		UPDATE account_collection
		  SET	account_collection_name =
		  			replace(account_collection_name, $6, $7)
		WHERE	account_collection_id IN (
				SELECT property_value_account_coll_id
				FROM	property
				WHERE	property_name IN ($3, $4)
				AND		property_type = $5
				AND		account_id = $1
				AND		account_realm_id = $2
		)' USING	account_id, account_realm_id,
				'AutomatedDirectsAC','AutomatedRollupsAC','auto_acct_coll',
				old_login, new_login;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

--------------------------------------------------------------------------------
--
-- returns the number of direct reports to a person
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.get_num_direct_reports(
	account_id 	account.account_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE
) RETURNS INTEGER AS $_$
DECLARE
	_numrpt	INTEGER;
BEGIN
	-- get number of direct reports
	EXECUTE '
		WITH peeps AS (
			SELECT	account_realm_id, account_id, login, person_id, 
					manager_person_id
			FROM	account a
				INNER JOIN person_company USING (person_id, company_id)
				INNER JOIN val_person_status vps ON
					vps.person_status = a.account_status
			WHERE	account_role = $3
			AND		account_type = ''person''
			AND		person_company_relation = ''employee''
			AND		vps.is_disabled = ''N''
		) SELECT count(*)
		FROM peeps reports
			INNER JOIN peeps managers on  
				managers.person_id = reports.manager_person_id
			AND	managers.account_realm_id = reports.account_realm_id
		WHERE	managers.account_id = $1
		AND		managers.account_realm_id = $2
	' INTO _numrpt USING account_id, account_realm_id, 'primary';

	RETURN _numrpt;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

--------------------------------------------------------------------------------
--
-- returns the number of direct reports that have reports
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.get_num_reports_with_reports(
	account_id 	account.account_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE
) RETURNS INTEGER AS $_$
DECLARE
	_numrlup	INTEGER;
BEGIN
	EXECUTE '
		WITH peeps AS (
			SELECT	account_realm_id, account_id, login, person_id, 
					manager_person_id
			FROM	account a
				INNER JOIN person_company USING (person_id, company_id)
				INNER JOIN val_person_status vps ON
					vps.person_status = a.account_status
			WHERE	account_role = $3
			AND		account_type = ''person''
			AND		person_company_relation = ''employee''
			AND		account_realm_id = $2
			AND		vps.is_disabled = ''N''
		), agg AS ( SELECT reports.*, managers.account_id as manager_account_id,
				managers.login as manager_login, p.property_name,
				p.property_value_account_coll_id as account_collection_id
			FROM peeps reports
			INNER JOIN peeps managers
				ON managers.person_id = reports.manager_person_id
				AND	managers.account_realm_id = reports.account_realm_id
			INNER JOIN property p 
				ON p.account_id = reports.account_id
				AND p.account_realm_id = reports.account_realm_id
				AND p.property_name IN ($4,$5)
				AND p.property_type = $6
		), rank AS (
			SELECT *,
				rank() OVER (partition by account_id ORDER BY property_name desc)
					as rank
			FROM agg
		) SELECT count(*) from rank
		WHERE	manager_account_id =  $1
		AND 	account_realm_id = $2
		AND	rank = 1;
	' INTO _numrlup USING account_id, account_realm_id, 'primary',
				'AutomatedDirectsAC','AutomatedRollupsAC','auto_acct_coll';

	RETURN _numrlup;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;


--------------------------------------------------------------------------------
--
-- returns the automated ac for a given account for a given purpose, creates
-- if necessary.
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.find_or_create_automated_ac(
	account_id 	account.account_id%TYPE,
	ac_type		property.property_name%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE DEFAULT NULL,
	login				account.login%TYPE DEFAULT NULL
)  RETURNS account_collection.account_collection_id%TYPE AS $_$
DECLARE
	_acname		text;
	_acid		account_collection.account_collection_id%TYPE;
BEGIN
	IF login is NULL THEN
		EXECUTE 'SELECT account_realm_id,login 
			FROM account where account_id = $1' 
			INTO account_realm_id,login USING account_id;
	END IF;

	IF ac_type = 'AutomatedDirectsAC' THEN
		_acname := concat(login, '-employee-directs');
	ELSIF ac_type = 'AutomatedRollupsAC' THEN
		_acname := concat(login, '-employee-rollup');
	ELSE
		RAISE EXCEPTION 'Do not know how to name Automated AC type %', ac_type;
	END IF;

	--
	-- Check to see if a -direct account collection exists already.  If not,
	-- create it.  There is a bit of a problem here if the name is not unique
	-- or otherwise messed up.  This will just raise errors.
	--
	EXECUTE 'SELECT ac.account_collection_id
			FROM account_collection ac
				INNER JOIN property p
					ON p.property_value_account_coll_id = ac.account_collection_id
		   WHERE ac.account_collection_name = $1
		    AND	ac.account_collection_type = $2
			AND	p.property_name = $3
			AND p.property_type = $4
			AND p.account_id = $5
			AND p.account_realm_id = $6
		' INTO _acid USING _acname, 'automated',
				ac_type, 'auto_acct_coll', account_id,
				account_realm_id;

	-- Assume the person is always in their own account collection, or if tehy
	-- are not someone took them out for a good reason.  (Thus, they are only
	-- added on creation).
	IF _acid IS NULL THEN
		EXECUTE 'INSERT INTO account_collection (
					account_collection_name, account_collection_type
				) VALUES ( $1, $2) RETURNING *
			' INTO _acid USING _acname, 'automated';

		IF ac_type = 'AutomatedDirectsAC' THEN
			EXECUTE 'INSERT INTO account_collection_account (
						account_collection_id, account_id
					) VALUES (  $1, $2 )
				' USING _acid, account_id;
		END IF;

		EXECUTE '
			INSERT INTO property ( 
				account_id,
				account_realm_id,
				property_name,
				property_type,
				property_value_account_coll_id
			)  VALUES ( $1, $2, $3, $4, $5)'
			USING account_id, account_realm_id,
				ac_type, 'auto_acct_coll', _acid;
	END IF;

	RETURN _acid;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

--------------------------------------------------------------------------------
--
-- Creates the account collection and associated property if it exists,
-- makes sure the membership is what it should be (excluding the account,
-- itself, which may be a mistake -- the assumption is it was removed for a
-- good reason.
--
-- Returns the account_collection_id
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.populate_direct_report_ac(
	account_id 	account.account_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE DEFAULT NULL,
	login				account.login%TYPE DEFAULT NULL
)  RETURNS account_collection.account_collection_id%TYPE AS $_$
DECLARE
	_directac	account_collection.account_collection_id%TYPE;
BEGIN
	_directac := auto_ac_manip.find_or_create_automated_ac(
		account_id := account_id,
		account_realm_id := account_realm_id,
		ac_type := 'AutomatedDirectsAC'
	);

	--
	-- Make membership right
	--
	EXECUTE '
		WITH peeps AS (
			SELECT	account_realm_id, account_id, login, person_id, 
					manager_person_id
			FROM	account a
				INNER JOIN person_company USING (person_id, company_id)
				INNER JOIN val_person_status vps ON
					vps.person_status = a.account_status
			WHERE	account_role = $2
			AND		account_type = ''person''
			AND		person_company_relation = ''employee''
			AND		vps.is_disabled = ''N''
		), arethere AS (
			SELECT account_collection_id, account_id FROM
				account_collection_account
				WHERE account_collection_id = $3
		), shouldbethere AS (
			SELECT $3 as account_collection_id, reports.account_id
			FROM peeps reports
				INNER JOIN peeps managers on  
					managers.person_id = reports.manager_person_id
				AND	managers.account_realm_id = reports.account_realm_id
			WHERE	managers.account_id =  $1
			UNION SELECT $3, $1
		), ins AS (
			INSERT INTO account_collection_account 
				(account_collection_id, account_id)
			SELECT account_collection_id, account_id 
			FROM shouldbethere
			WHERE (account_collection_id, account_id)
				NOT IN (select account_collection_id, account_id FROM arethere)
			RETURNING *
		), del AS (
			DELETE FROM account_collection_account
			WHERE (account_collection_id, account_id)
			IN (
				SELECT account_collection_id, account_id 
				FROM arethere
			) AND (account_collection_id, account_id) NOT IN (
				SELECT account_collection_id, account_id 
				FROM shouldbethere
			) RETURNING *
		) SELECT * from ins UNION SELECT * from del
		'USING account_id, 'primary', _directac;

	RETURN _directac;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

--------------------------------------------------------------------------------
--
-- Creates the account collection and associated property if it exists,
-- makes sure the membership is what it should be .  This does NOT manipulate
-- the -direct account collection at all
--
-- Returns the account_collection_id
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.populate_rollup_report_ac(
	account_id 	account.account_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE DEFAULT NULL,
	login				account.login%TYPE DEFAULT NULL
)  RETURNS account_collection.account_collection_id%TYPE AS $_$
DECLARE
	_rollupac	account_collection.account_collection_id%TYPE;
BEGIN
	_rollupac := auto_ac_manip.find_or_create_automated_ac(
		account_id := account_id,
		account_realm_id := account_realm_id,
		ac_type := 'AutomatedRollupsAC'
	);

	EXECUTE '
		WITH peeps AS (
			SELECT	account_realm_id, account_id, login, person_id, 
					manager_person_id
			FROM	account a
				INNER JOIN person_company USING (person_id, company_id)
				INNER JOIN val_person_status vps
					ON vps.person_status=a.account_status
			WHERE	account_role = $2
			AND		account_type = ''person''
			AND		person_company_relation = ''employee''
			AND		vps.is_disabled = ''N''
		), agg AS ( SELECT reports.*, managers.account_id as manager_account_id,
				managers.login as manager_login, p.property_name,
				p.property_value_account_coll_id as account_collection_id
			FROM peeps reports
			INNER JOIN peeps managers
				ON managers.person_id = reports.manager_person_id
				AND	managers.account_realm_id = reports.account_realm_id
			INNER JOIN property p 
				ON p.account_id = reports.account_id
				AND p.account_realm_id = reports.account_realm_id
				AND p.property_name IN ($3,$4)
				AND p.property_type = $5
		), rank AS (
			SELECT *,
				rank() OVER (partition by account_id ORDER BY property_name desc)
					as rank
			FROM agg
		), shouldbethere AS (
			SELECT $6 as account_collection_id,
					account_collection_id as child_account_collection_id
			FROM rank
	 		WHERE	manager_account_id =  $1
			AND	rank = 1
		), arethere AS (
			SELECT account_collection_id, child_account_collection_id FROM
				account_collection_hier
			WHERE account_collection_id = $6
		), ins AS (
			INSERT INTO account_collection_hier 
				(account_collection_id, child_account_collection_id)
			SELECT account_collection_id, child_account_collection_id
			FROM shouldbethere
			WHERE (account_collection_id, child_account_collection_id)
				NOT IN (SELECT * from arethere)
			RETURNING *
		), del AS (
			DELETE FROM account_collection_hier
			WHERE (account_collection_id, child_account_collection_id)
				IN (SELECT * from arethere)
			AND (account_collection_id, child_account_collection_id)
				NOT IN (SELECT * FROM shouldbethere)
			RETURNING *
		) select * from ins UNION select * from del;

	' USING account_id, 'primary',
				'AutomatedDirectsAC','AutomatedRollupsAC','auto_acct_coll',
				_rollupac;

	RETURN _rollupac;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;


--------------------------------------------------------------------------------
--
-- makes sure that the -direct and -rollup account collections exist for
-- someone that should.  Does not destroy
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.create_report_account_collections(
	account_id 	account.account_id%TYPE,
	account_realm_id	account.account_realm_id%TYPE DEFAULT NULL,
	login				account.login%TYPE DEFAULT NULL,
	numrpt				integer DEFAULT NULL,
	numrlup				integer DEFAULT NULL
)  RETURNS VOID AS $_$
DECLARE
	_account	account%ROWTYPE;
	_directac	account_collection.account_collection_id%TYPE;
	_rollupac	account_collection.account_collection_id%TYPE;
BEGIN
	IF ( login is NULL or account_realm_id IS NULL ) THEN
		EXECUTE '
		SELECT account_realm_id, login
		FROM	account
		WHERE	account_id = $1
		' INTO account_realm_id, login USING account_id;
	END IF;
	IF numrpt IS NULL THEN
		numrpt := auto_ac_manip.get_num_direct_reports(account_id, account_realm_id);
	END IF;

	IF numrpt = 0 THEN
		RETURN;
	END IF;

	_directac := auto_ac_manip.populate_direct_report_ac(account_id, account_realm_id, login);

	IF numrlup IS NULL THEN
		numrlup := auto_ac_manip.get_num_reports_with_reports(account_id, account_realm_id);
	END IF;

	IF numrlup = 0 THEN
		RETURN;
	END IF;

	_rollupac := auto_ac_manip.populate_rollup_report_ac(account_id, account_realm_id, login);

	-- add directs to rollup
	EXECUTE 'INSERT INTO account_collection_hier (
			account_collection_id, child_account_collection_id
		) VALUES (
			$1, $2
		)' USING _rollupac, _directac;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

CREATE OR REPLACE FUNCTION auto_ac_manip.purge_report_account_collection(
	account_id 	account.account_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE,
	ac_type		property.property_name%TYPE
) RETURNS VOID AS $_$
BEGIN
	EXECUTE '
		DELETE FROM account_collection_account
		WHERE account_collection_ID IN (
			SELECT	property_value_account_coll_id
			FROM	property
			WHERE	property_name = $3
			AND		property_type = $4
			AND		account_id = $1
			AND		account_realm_id = $2
		)' USING account_id, account_realm_id, ac_type, 'auto_acct_coll';

	EXECUTE '
		WITH p AS (
			SELECT	property_value_account_coll_id AS account_collection_id
			FROM	property
			WHERE	property_name = $3
			AND		property_type = $4
			AND		account_id = $1
			AND		account_realm_id = $2
		)
		DELETE FROM account_collection_hier
		WHERE account_collection_id IN ( select account_collection_id from p)
		OR child_account_collection_id IN 
			( select account_collection_id from p)
		' USING account_id, account_realm_id, ac_type, 'auto_acct_coll';

	EXECUTE '
		WITH list AS (
			SELECT	property_value_account_coll_id as account_collection_id,
					property_id
			FROM	property
			WHERE	property_name = $3
			AND		property_type = $4
			AND		account_id = $1
			AND		account_realm_id = $2
		), props AS (
			DELETE FROM property WHERE property_id IN
				(select property_id FROM list ) RETURNING *
		) DELETE FROM account_collection WHERE account_collection_id IN
				(select property_value_account_coll_id FROM props )
		' USING account_id, account_realm_id, ac_type, 'auto_acct_coll';

END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

--------------------------------------------------------------------------------
--
-- makes sure that the -direct and -rollup account collections do exist for
-- someone if they should not.  Removes if necessary, and also removes them
-- from other account collections.  Arguably should also remove other
-- properties associated but I opted out of that for now. 
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.destroy_report_account_collections(
	account_id 	account.account_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE DEFAULT NULL,
	numrpt				integer DEFAULT NULL,
	numrlup				integer DEFAULT NULL
)  RETURNS VOID AS $_$
DECLARE
	_account	account%ROWTYPE;
	_directac	account_collection.account_collection_id%TYPE;
	_rollupac	account_collection.account_collection_id%TYPE;
BEGIN
	IF account_realm_id IS NULL THEN
		EXECUTE '
			SELECT account_realm_id
			FROM	account
			WHERE	account_id = $1
		' INTO account_realm_id USING account_id;
	END IF;

	IF numrpt IS NULL THEN
		numrpt := auto_ac_manip.get_num_direct_reports(account_id, account_realm_id);
	END IF;
	IF numrpt = 0 THEN
		PERFORM auto_ac_manip.purge_report_account_collection(
			account_id := account_id, 
			account_realm_id := account_realm_id,
			ac_type := 'AutomatedDirectsAC');
		RETURN;
	END IF;

	IF numrlup IS NULL THEN
		numrlup := auto_ac_manip.get_num_reports_with_reports(account_id, account_realm_id);
	END IF;
	IF numrlup = 0 THEN 
		PERFORM auto_ac_manip.purge_report_account_collection(
			account_id := account_id, 
			account_realm_id := account_realm_id,
			ac_type := 'AutomatedDirectsAC');
		RETURN;
	END IF;

END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

--------------------------------------------------------------------------------
--
-- one routine that just goes and fixes all the -direct and -rollup auto
-- account collections to be right.  Note that this just calls other routines
-- and relies on them to decide if things should be purged or not.
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.make_auto_report_acs_right(
	account_id 			account.account_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE DEFAULT NULL,
	login				account.login%TYPE DEFAULT NULL
)  RETURNS VOID AS $_$
DECLARE
	_numrpt	INTEGER;
	_numrlup INTEGER;
BEGIN
	IF account_realm_id IS NULL OR login IS NULL THEN
		EXECUTE '
			SELECT account_realm_id, login
			FROM	account
			WHERE	account_id = $1
		' INTO account_realm_id, login USING account_id;
	END IF;
	_numrpt := auto_ac_manip.get_num_direct_reports(account_id, account_realm_id);
	_numrlup := auto_ac_manip.get_num_reports_with_reports(account_id, account_realm_id);
	PERFORM auto_ac_manip.destroy_report_account_collections(account_id, account_realm_id, _numrpt, _numrlup);
	PERFORM auto_ac_manip.create_report_account_collections(account_id, account_realm_id, login, _numrpt, _numrlup);
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;



--------------------------------------------------------------------------------
--
-- fix all the fields that come from person_company.  This would be
-- called from a trigger.
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.make_personal_acs_right(
	account_id	account.account_id%TYPE
) RETURNS integer AS $_$
DECLARE
	_tally	INTEGER;
BEGIN
	EXECUTE '
	WITH ac AS (
		SELECT DISTINCT ac.*
		FROM	account_collection ac
				INNER JOIN property p USING (account_collection_id)
		WHERE	property_type = ''auto_acct_coll''
		AND		property_name in (''non_exempt'', ''exempt'',
					''management'', ''non_management'', ''full_time'',
					''non_full_time'', ''male'', ''female'', ''unspecified_gender'',
					''account_type'', ''person_company_relation'')
	), acct AS (
		    SELECT  a.account_id, a.account_type, a.account_role, parc.*,
			    pc.is_management, pc.is_full_time, pc.is_exempt,
			    p.gender, pc.person_company_relation
		     FROM   account a
			    INNER JOIN person_account_realm_company parc
				    USING (person_id, company_id, account_realm_id)
			    INNER JOIN person_company pc USING (person_id,company_id)
			    INNER JOIN person p USING (person_id)
			WHERE a.is_enabled = ''Y''
			AND a.account_role = ''primary''
		),
	list AS (
		SELECT  p.account_collection_id, a.account_id, a.account_type,
			a.account_role,
			a.person_id, a.company_id,
			ac.account_collection_name, ac.account_collection_type,
			p.property_name, p.property_type, p.property_value, p.property_id
		FROM    property p
			INNER JOIN ac USING (account_collection_id)
		    INNER JOIN acct a
				ON a.account_realm_id = p.account_realm_id
		WHERE   (p.company_id is NULL or a.company_id = p.company_id)
		    AND     property_type = ''auto_acct_coll''
			AND	( a.account_type = ''person'' 
				AND a.person_company_relation = ''employee''
				AND (
		    	(
			    	property_name =
					CASE WHEN a.is_exempt = ''N''
				    	THEN ''non_exempt''
				    	ELSE ''exempt'' END
				OR
			    	property_name =
					CASE WHEN a.is_management = ''N''
				    	THEN ''non_management''
				    	ELSE ''management'' END
				OR
			    	property_name =
					CASE WHEN a.is_full_time = ''N''
				    	THEN ''non_full_time''
				    	ELSE ''full_time'' END
				OR
			    	property_name =
					CASE WHEN a.gender = ''M'' THEN ''male''
				    	WHEN a.gender = ''F'' THEN ''female''
				    	ELSE ''unspecified_gender'' END
			) )
			OR (
			    property_name = ''account_type''
			    AND property_value = a.account_type
			    )
			OR (
			    property_name = ''person_company_relation''
			    AND property_value = a.person_company_relation
			    )
			)
	), ins AS (
			INSERT INTO account_collection_account
				(account_collection_id, account_id)
			SELECT 	account_collection_id, account_id
			FROM	 list
			WHERE	 (account_collection_id, account_id) NOT IN
				 	(SELECT account_collection_id, account_id FROM
						account_collection_account 
					JOIN ac USING (account_collection_id) )
			AND account_id = $1
		RETURNING *
	), del AS (
		DELETE
		FROM	 account_collection_account
		WHERE	 (account_collection_id, account_id) NOT IN
				 (SELECT account_collection_id, account_id FROM
					list JOIN ac USING (account_collection_id))
		AND	 	(account_collection_id, account_id) IN
				(SELECT account_collection_id,account_id from ac)
		AND account_id = $1 RETURNING *
	), combo AS (
		SELECT * from ins UNION select * FROM del
	) SELECT count(*) 
		FROM combo 
		JOIN account_collection USING (account_collection_id);
	' INTO _tally USING account_id;
	RETURN _tally;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;

--------------------------------------------------------------------------------
--
-- fix the person's site code based on their location.  This is largely meant
-- to be called by the person_location trigger.
-- called from a trigger.
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.make_site_acs_right(
	account_id	account.account_id%TYPE
) RETURNS integer AS $_$
DECLARE
	_tally	INTEGER;
BEGIN
	EXECUTE '
	WITH ac AS (
		SELECT DISTINCT ac.*
		FROM	account_collection ac
				INNER JOIN property p USING (account_collection_id)
		WHERE	property_type = ''auto_acct_coll''
		AND		property_name in (''site'')
	), acct AS (
		    SELECT  a.account_id, a.account_type, a.account_role, parc.*,
			    pc.is_management, pc.is_full_time, pc.is_exempt,
			    p.gender, pc.person_company_relation
		     FROM   account a
			    INNER JOIN person_account_realm_company parc
				    USING (person_id, company_id, account_realm_id)
			    INNER JOIN person_company pc USING (person_id,company_id)
			    INNER JOIN person p USING (person_id)
			WHERE a.is_enabled = ''Y''
			AND a.account_role = ''primary''
	), list AS (
		SELECT  p.account_collection_id, a.account_id, a.account_type,
			a.account_role,
			a.person_id, a.company_id,
			ac.account_collection_name, ac.account_collection_type,
			p.property_name, p.property_type, p.property_value, p.property_id
		FROM    property p
			INNER JOIN ac USING (account_collection_id)
		    INNER JOIN acct a
				ON a.account_realm_id = p.account_realm_id
			INNER JOIN person_location pl on a.person_id = pl.person_id
		WHERE   (p.company_id is NULL or a.company_id = p.company_id)
		AND		a.person_company_relation = ''employee''
		AND		property_type = ''auto_acct_coll''
		AND		p.site_code = pl.site_code
		AND		property_name = ''site''
	), ins AS (
			INSERT INTO account_collection_account
				(account_collection_id, account_id)
			SELECT 	account_collection_id, account_id
			FROM	 list
			WHERE	 (account_collection_id, account_id) NOT IN
				 	(SELECT account_collection_id, account_id FROM
						account_collection_account 
					JOIN ac USING (account_collection_id) )
			AND account_id = $1
		RETURNING *
	), del AS (
		DELETE
		FROM	 account_collection_account
		WHERE	 (account_collection_id, account_id) NOT IN
				 (SELECT account_collection_id, account_id FROM
					list JOIN ac USING (account_collection_id))
		AND	 	(account_collection_id, account_id) IN
				(SELECT account_collection_id,account_id from ac)
		AND account_id = $1 RETURNING *
	), combo AS (
		SELECT * from ins UNION select * FROM del
	) SELECT count(*) 
		FROM combo 
		JOIN account_collection USING (account_collection_id);
	' INTO _tally USING account_id;
	RETURN _tally;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;


--------------------------------------------------------------------------------
--
-- one routine that just fixes all auto acs
--
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_ac_manip.make_all_auto_acs_right(
	account_id 			account.account_id%TYPE,
	account_realm_id	account_realm.account_realm_id%TYPE DEFAULT NULL,
	login				account.login%TYPE DEFAULT NULL
)  RETURNS VOID AS $_$
BEGIN
	PERFORM auto_ac_manip.make_auto_report_acs_right(account_id, account_realm_id, login);
	PERFORM auto_ac_manip.make_site_acs_right(account_id);
	PERFORM auto_ac_manip.make_personal_acs_right(account_id);
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands;


/*
 * Copyright (c) 2015 Todd Kover
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

/*************************************************************************

This is how they used to work; this logic needs to be folded into 
"add a comany" logic

Here is how these work:

automated_ac()
	on account, used for RealmName_Type, most practically RealmName_person
	that is, omniscientcompany_person

automated_ac_on_person_company()
	on person_company, used for RealmName_ShortName_thing, that is:

		OmniscientRealm_omniscientcompany_full_time
		OmniscientRealm_omniscientcompany_management
		OmniscientRealm_omniscientcompany_exempt

		Y means they're in, N means they're not

automated_ac_on_person()
	on person, manipulates gender related class of the form
		RealmName_ShortName_thing that is

		OmniscientRealm_omniscientcompany_male
		OmniscientRealm_omniscientcompany_female

		also need to incorporate unknown

automated_realm_site_ac_pl()
	on person_location.  RealmName_SITE, i.e.  Omniscient_IAD1

	associates  a person's primary account in the realm with s site code

*************************************************************************/

--
-- Changes to account trigger addition/removal from various things.  This is
-- actually redundant with the second two triggers on person_company and
-- person, which deal with updates.  This covers the case of accounts coming
-- into existance after the rows in person/person_company
--
-- This currently does not move an account out of a "site" class when someone 
-- moves around, which should probably be revisited.
--
CREATE OR REPLACE FUNCTION automated_ac_on_account() 
RETURNS TRIGGER AS $_$
DECLARE
	_tally	INTEGER;
	_r		RECORD;
BEGIN
	IF TG_OP = 'DELETE' THEN
		IF OLD.account_role != 'primary' THEN
			RETURN OLD;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.account_role != 'primary' AND OLD.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
	END IF;


	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE'  THEN
		PERFORM auto_ac_manip.make_site_acs_right(NEW.account_id);
		PERFORM auto_ac_manip.make_personal_acs_right(NEW.account_id);
	END IF;

	IF TG_OP = 'UPDATE'  THEN
		PERFORM auto_ac_manip.make_site_acs_right(OLD.account_id);
		PERFORM auto_ac_manip.make_personal_acs_right(OLD.account_id);
	END IF;

	-- when deleting, do nothing rather than calling the above, same as
	-- update; pointless because account is getting deleted anyway.

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$_$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trig_add_automated_ac_on_account ON account;
CREATE TRIGGER trig_add_automated_ac_on_account 
	AFTER INSERT 
	OR UPDATE OF account_type, account_role, account_status
	ON account 
	FOR EACH ROW 
	EXECUTE PROCEDURE automated_ac_on_account();

DROP TRIGGER IF EXISTS trig_rm_automated_ac_on_account ON account;
CREATE TRIGGER trig_rm_automated_ac_on_account 
	BEFORE DELETE 
	ON account 
	FOR EACH ROW 
	EXECUTE PROCEDURE automated_ac_on_account();

--------------------------------------------------------------------------

--
-- Using a temporary table, add/remove users based on account collections
-- as defined in properties.
--
CREATE OR REPLACE FUNCTION automated_ac_on_person_company() 
RETURNS TRIGGER AS $_$
DECLARE
	_tally	INTEGER;
	_r		RECORD;
BEGIN
	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
		PERFORM	auto_ac_manip.make_personal_acs_right(account_id)
		FROM	v_corp_family_account
				INNER JOIN person_location USING (person_id)
		WHERE	account_role = 'primary'
		AND		person_id = NEW.person_id
		AND		company_id = NEW.company_id;
	END IF;

	IF TG_OP = 'DELETE' OR TG_OP = 'UPDATE' THEN
		PERFORM	auto_ac_manip.make_personal_acs_right(account_id)
		FROM	v_corp_family_account
				INNER JOIN person_location USING (person_id)
		WHERE	account_role = 'primary'
		AND		person_id = OLD.person_id
		AND		company_id = OLD.company_id;
	END IF;
	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$_$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_automated_ac_on_person_company ON person_company;
CREATE TRIGGER trigger_automated_ac_on_person_company 
	AFTER UPDATE OF is_management, is_exempt, is_full_time, person_id,company_id
	ON person_company 
	FOR EACH ROW EXECUTE PROCEDURE 
	automated_ac_on_person_company();

--------------------------------------------------------------------------

--
-- fires on changes to person that are relevant.  This does not fire on
-- insert or delete because accounts do not exist in either of those cases.
--
CREATE OR REPLACE FUNCTION automated_ac_on_person() 
RETURNS TRIGGER AS $_$
DECLARE
	_tally	INTEGER;
BEGIN
	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
		PERFORM	auto_ac_manip.make_personal_acs_right(account_id)
		FROM	v_corp_family_account
				INNER JOIN person_location USING (person_id)
		WHERE	account_role = 'primary'
		AND		person_id = NEW.person_id;
	END IF;

	IF TG_OP = 'DELETE' OR TG_OP = 'UPDATE' THEN
		PERFORM	auto_ac_manip.make_personal_acs_right(account_id)
		FROM	v_corp_family_account
				INNER JOIN person_location USING (person_id)
		WHERE	account_role = 'primary'
		AND		person_id = OLD.person_id;
	END IF;
	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;

END;
$_$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

--------------------------------------------------------------------------
--
-- If someone moves location, update the site if something appropriate exists
--
--
CREATE OR REPLACE FUNCTION automated_realm_site_ac_pl() 
RETURNS TRIGGER AS $_$
DECLARE
	_tally	INTEGER;
BEGIN
	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
		PERFORM	auto_ac_manip.make_site_acs_right(account_id)
		FROM	v_corp_family_account
				INNER JOIN person_location USING (person_id)
		WHERE	account_role = 'primary'
		AND		person_id = NEW.person_id;
	END IF;

	IF TG_OP = 'DELETE' OR TG_OP = 'UPDATE' THEN
		PERFORM	auto_ac_manip.make_site_acs_right(account_id)
		FROM	v_corp_family_account
				INNER JOIN person_location USING (person_id)
		WHERE	account_role = 'primary'
		AND		person_id = OLD.person_id;
	END IF;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$_$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trig_automated_realm_site_ac_pl ON person_location;
CREATE TRIGGER trig_automated_realm_site_ac_pl 
	AFTER DELETE OR INSERT OR UPDATE OF site_code, person_id
	ON person_location 
	FOR EACH ROW 
	EXECUTE PROCEDURE automated_realm_site_ac_pl();


grant usage on schema auto_ac_manip to iud_role;
revoke all on schema auto_ac_manip from public;
revoke all on  all functions in schema auto_ac_manip from public;
grant execute on all functions in schema auto_ac_manip to iud_role;


--
-- Copyright (c) 2015 Matthew Ragan
-- All rights reserved.
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--      http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--

DO $$
DECLARE
        _tal INTEGER;
BEGIN
        select count(*)
        from pg_catalog.pg_namespace
        into _tal
        where nspname = 'component_utils';
        IF _tal = 0 THEN
                DROP SCHEMA IF EXISTS component_utils;
                CREATE SCHEMA component_utils AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA component_utils IS 'part of jazzhands';
        END IF;
END;
$$;

CREATE OR REPLACE FUNCTION component_utils.create_component_template_slots(
	component_id	jazzhands.component.component_id%TYPE
) RETURNS SETOF jazzhands.slot
AS $$
DECLARE
	ctid	jazzhands.component_type.component_type_id%TYPE;
	s		jazzhands.slot%ROWTYPE;
	cid 	ALIAS FOR component_id;
BEGIN
	FOR s IN
		INSERT INTO jazzhands.slot (
			component_id,
			slot_name,
			slot_type_id,
			slot_index,
			component_type_slot_tmplt_id,
			physical_label,
			slot_x_offset,
			slot_y_offset,
			slot_z_offset,
			slot_side
		) SELECT
			cid,
			ctst.slot_name_template,
			ctst.slot_type_id,
			ctst.slot_index,
			ctst.component_type_slot_tmplt_id,
			ctst.physical_label,
			ctst.slot_x_offset,
			ctst.slot_y_offset,
			ctst.slot_z_offset,
			ctst.slot_side
		FROM
			component_type_slot_tmplt ctst JOIN
			component c USING (component_type_id) LEFT JOIN
			slot ON (slot.component_id = cid AND
				slot.component_type_slot_tmplt_id =
				ctst.component_type_slot_tmplt_id
			)
		WHERE
			c.component_id = cid AND
			slot.component_type_slot_tmplt_id IS NULL
		ORDER BY ctst.component_type_slot_tmplt_id
		RETURNING *
	LOOP
		RAISE DEBUG 'Creating slot for component % from template %',
			cid, s.component_type_slot_tmplt_id;
		RETURN NEXT s;
	END LOOP;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION component_utils.migrate_component_template_slots(
	component_id			jazzhands.component.component_id%TYPE
) RETURNS SETOF jazzhands.slot
AS $$
DECLARE
	cid 	ALIAS FOR component_id;
BEGIN
	-- Ensure all of the new slots have appropriate names

	PERFORM component_utils.set_slot_names(
		slot_id_list := ARRAY(
				SELECT s.slot_id FROM slot s WHERE s.component_id = cid
			)
	);

	-- Move everything from the old slot to the new slot if the slot name
	-- and component functions match up, then delete the old slot

	RETURN QUERY
	WITH old_slot AS (
		SELECT
			s.slot_id,
			s.slot_name,
			s.slot_type_id,
			st.slot_function,
			ctst.component_type_slot_tmplt_id
		FROM
			slot s JOIN 
			slot_type st USING (slot_type_id) JOIN
			component c USING (component_id) LEFT JOIN
			component_type_slot_tmplt ctst USING (component_type_slot_tmplt_id)
		WHERE
			s.component_id = cid AND
			ctst.component_type_id IS DISTINCT FROM c.component_type_id
	), new_slot AS (
		SELECT
			s.slot_id,
			s.slot_name,
			s.slot_type_id,
			st.slot_function
		FROM
			slot s JOIN 
			slot_type st USING (slot_type_id) JOIN
			component c USING (component_id) LEFT JOIN
			component_type_slot_tmplt ctst USING (component_type_slot_tmplt_id)
		WHERE
			s.component_id = cid AND
			ctst.component_type_id IS NOT DISTINCT FROM c.component_type_id
	), slot_map AS (
		SELECT
			o.slot_id AS old_slot_id,
			n.slot_id AS new_slot_id
		FROM
			old_slot o JOIN
			new_slot n ON (
				o.slot_name = n.slot_name AND o.slot_function = n.slot_function)
	), slot_1_upd AS (
		UPDATE
			inter_component_connection ic
		SET
			slot1_id = slot_map.new_slot_id
		FROM
			slot_map
		WHERE
			slot1_id = slot_map.old_slot_id
		RETURNING *
	), slot_2_upd AS (
		UPDATE
			inter_component_connection ic
		SET
			slot2_id = slot_map.new_slot_id
		FROM
			slot_map
		WHERE
			slot2_id = slot_map.old_slot_id
		RETURNING *
	), prop_upd AS (
		UPDATE
			component_property cp
		SET
			slot_id = slot_map.new_slot_id
		FROM
			slot_map
		WHERE
			slot_id = slot_map.old_slot_id
		RETURNING *
	), comp_upd AS (
		UPDATE
			component c
		SET
			parent_slot_id = slot_map.new_slot_id
		FROM
			slot_map
		WHERE
			parent_slot_id = slot_map.old_slot_id
		RETURNING *
	), ni_upd AS (
		UPDATE
			network_interface ni
		SET
			slot_id = slot_map.new_slot_id
		FROM
			slot_map
		WHERE
			physical_port_id = slot_map.old_slot_id OR
			slot_id = slot_map.new_slot_id
		RETURNING *
	), delete_migraged_slots AS (
		DELETE FROM
			slot
		WHERE
			slot_id IN (SELECT old_slot_id FROM slot_map)
		RETURNING *
	), delete_empty_slots AS (
		DELETE FROM
			slot s
		WHERE
			slot_id IN (
				SELECT os.slot_id FROM
					old_slot os LEFT JOIN
					component_property cp ON (os.slot_id = cp.slot_id) LEFT JOIN
					network_interface ni ON (
						ni.slot_id = os.slot_id OR
						ni.physical_port_id = os.slot_id) LEFT JOIN
					inter_component_connection ic ON (
						slot1_id = os.slot_id OR
						slot2_id = os.slot_id) LEFT JOIN
					component c ON (c.parent_slot_id = os.slot_id)
				WHERE
					ic.inter_component_connection_id IS NULL AND
					c.component_id IS NULL AND
					ni.network_interface_id IS NULL AND
					cp.component_property_id IS NULL AND
					os.component_type_slot_tmplt_id IS NOT NULL
			)
	) SELECT s.* FROM slot s JOIN slot_map sm ON s.slot_id = sm.new_slot_id;

	RETURN;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION component_utils.set_slot_names(
	slot_id_list	integer[] DEFAULT NULL
) RETURNS VOID
AS $$
DECLARE
	slot_rec	RECORD;
	sn			text;
BEGIN
	-- Get a list of all slots that have replacement values

	FOR slot_rec IN
		SELECT 
			s.slot_id,
			st.slot_name_template,
			st.slot_index as slot_index,
			pst.slot_index as parent_slot_index
		FROM
			slot s JOIN
			component_type_slot_tmplt st ON (s.component_type_slot_tmplt_id =
				st.component_type_slot_tmplt_id) JOIN
			component c ON (s.component_id = c.component_id) LEFT JOIN
			slot ps ON (c.parent_slot_id = ps.slot_id) LEFT JOIN
			component_type_slot_tmplt pst ON (ps.component_type_slot_tmplt_id =
				pst.component_type_slot_tmplt_id)
		WHERE
			s.slot_id = ANY(slot_id_list) AND
			st.slot_name_template LIKE '%\%{%'
	LOOP
		sn := slot_rec.slot_name_template;
		IF (slot_rec.slot_index IS NOT NULL) THEN
			sn := regexp_replace(sn,
				'%\{slot_index\}', slot_rec.slot_index::text,
				'g');
		END IF;
		IF (slot_rec.parent_slot_index IS NOT NULL) THEN
			sn := regexp_replace(sn,
				'%\{parent_slot_index\}', slot_rec.parent_slot_index::text,
				'g');
		END IF;
		IF (slot_rec.parent_slot_index IS NOT NULL AND
			slot_rec.slot_index IS NOT NULL) THEN
			sn := regexp_replace(sn,
				'%\{relative_slot_index\}', 
				(slot_rec.parent_slot_index + slot_rec.slot_index)::text,
				'g');
		END IF;
		RAISE DEBUG 'Setting name of slot % to %',
			slot_rec.slot_id,
			sn;
		UPDATE slot SET slot_name = sn WHERE slot_id = slot_rec.slot_id;
	END LOOP;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION component_utils.remove_component_hier(
	component_id	jazzhands.component.component_id%TYPE,
	really_delete	boolean DEFAULT FALSE
) RETURNS BOOLEAN
AS $$
DECLARE
	slot_list		integer[];
	shelf_list		integer[];
	delete_list		integer[];
	cid				integer;
BEGIN
	cid := component_id;

	SELECT ARRAY(
		SELECT
			slot_id
		FROM
			v_component_hier h JOIN
			slot s ON (h.child_component_id = s.component_id)
		WHERE
			h.component_id = cid)
	INTO slot_list;

	IF really_delete THEN
		SELECT ARRAY(
			SELECT
				child_component_id
			FROM
				v_component_hier h
			WHERE
				h.component_id = cid)
		INTO delete_list;
	ELSE

		SELECT ARRAY(
			SELECT
				child_component_id
			FROM
				v_component_hier h LEFT JOIN
				asset a on (a.component_id = h.child_component_id)
			WHERE
				h.component_id = cid AND
				serial_number IS NOT NULL
		)
		INTO shelf_list;

		SELECT ARRAY(
			SELECT
				child_component_id
			FROM
				v_component_hier h LEFT JOIN
				asset a on (a.component_id = h.child_component_id)
			WHERE
				h.component_id = cid AND
				serial_number IS NULL
		)
		INTO delete_list;

	END IF;

	DELETE FROM
		inter_component_connection
	WHERE
		slot1_id = ANY (slot_list) OR
		slot2_id = ANY (slot_list);

	UPDATE
		component c
	SET
		parent_slot_id = NULL
	WHERE
		c.component_id = ANY (array_cat(delete_list, shelf_list)) AND
		parent_slot_id IS NOT NULL;

	DELETE FROM component_property cp WHERE
		cp.component_id = ANY (delete_list) OR
		slot_id = ANY (slot_list);
		
	DELETE FROM
		slot s
	WHERE
		slot_id = ANY (slot_list) AND
		s.component_id = ANY(delete_list);
		
	DELETE FROM
		component c
	WHERE
		c.component_id = ANY (delete_list);

	RETURN true;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql;

--
-- These need to all call a generic component/component_type insertion
-- function, rather than all of the specific types, but that's thinking
--

CREATE OR REPLACE FUNCTION component_utils.insert_pci_component(
	pci_vendor_id	integer,
	pci_device_id	integer,
	pci_sub_vendor_id	integer DEFAULT NULL,
	pci_subsystem_id	integer DEFAULT NULL,
	pci_vendor_name		text DEFAULT NULL,
	pci_device_name		text DEFAULT NULL,
	pci_sub_vendor_name		text DEFAULT NULL,
	pci_sub_device_name		text DEFAULT NULL,
	component_function_list	text[] DEFAULT NULL,
	slot_type			text DEFAULT 'unknown',
	serial_number		text DEFAULT NULL
) RETURNS jazzhands.component
AS $$
DECLARE
	sn			ALIAS FOR serial_number;
	ctid		integer;
	comp_id		integer;
	sub_comp_id	integer;
	stid		integer;
	vendor_name	text;
	sub_vendor_name	text;
	model_name	text;
	c			RECORD;
BEGIN
	IF (pci_sub_vendor_id IS NULL AND pci_subsystem_id IS NOT NULL) OR
			(pci_sub_vendor_id IS NOT NULL AND pci_subsystem_id IS NULL) THEN
		RAISE EXCEPTION
			'pci_sub_vendor_id and pci_subsystem_id must be set together';
	END IF;

	--
	-- See if we have this component type in the database already
	--
	SELECT
		vid.component_type_id INTO ctid
	FROM
		component_property vid JOIN
		component_property did ON (
			vid.component_property_name = 'PCIVendorID' AND
			vid.component_property_type = 'PCI' AND
			did.component_property_name = 'PCIDeviceID' AND
			did.component_property_type = 'PCI' AND
			vid.component_type_id = did.component_type_id ) LEFT JOIN
		component_property svid ON (
			svid.component_property_name = 'PCISubsystemVendorID' AND
			svid.component_property_type = 'PCI' AND
			svid.component_type_id = did.component_type_id ) LEFT JOIN
		component_property sid ON (
			sid.component_property_name = 'PCISubsystemID' AND
			sid.component_property_type = 'PCI' AND
			sid.component_type_id = did.component_type_id )
	WHERE
		vid.property_value = pci_vendor_id::varchar AND
		did.property_value = pci_device_id::varchar AND
		svid.property_value IS NOT DISTINCT FROM pci_sub_vendor_id::varchar AND
		sid.property_value IS NOT DISTINCT FROM pci_subsystem_id::varchar;

	--
	-- The device type doesn't exist, so attempt to insert it
	--

	IF NOT FOUND THEN	
		IF pci_device_name IS NULL OR component_function_list IS NULL THEN
			RAISE EXCEPTION 'component_id not found and pci_device_name or component_function_list was not passed' USING ERRCODE = 'JH501';
		END IF;

		--
		-- Ensure that there's a company linkage for the PCI (subsystem)vendor
		--
		SELECT
			company_id, company_name INTO comp_id, vendor_name
		FROM
			property p JOIN
			company c USING (company_id)
		WHERE
			property_type = 'DeviceProvisioning' AND
			property_name = 'PCIVendorID' AND
			company_id = pci_vendor_id;
		
		IF NOT FOUND THEN
			IF pci_vendor_name IS NULL THEN
				RAISE EXCEPTION 'PCI vendor id mapping not found and pci_vendor_name was not passed' USING ERRCODE = 'JH501';
			END IF;
			SELECT company_id INTO comp_id FROM company
			WHERE company_name = pci_vendor_name;
		
			IF NOT FOUND THEN
				INSERT INTO company (company_name, description)
				VALUES (pci_vendor_name, 'PCI vendor auto-insert')
				RETURNING company_id INTO comp_id;
			END IF;

			INSERT INTO property (
				property_name,
				property_type,
				property_value,
				company_id
			) VALUES (
				'PCIVendorID',
				'DeviceProvisioning',
				pci_vendor_id,
				comp_id
			);
			vendor_name := pci_vendor_name;
		END IF;

		SELECT
			company_id, company_name INTO sub_comp_id, sub_vendor_name
		FROM
			property JOIN
			company c USING (company_id)
		WHERE
			property_type = 'DeviceProvisioning' AND
			property_name = 'PCIVendorID' AND
			company_id = pci_sub_vendor_id;
		
		IF NOT FOUND THEN
			IF pci_sub_vendor_name IS NULL THEN
				RAISE EXCEPTION 'PCI subsystem vendor id mapping not found and pci_sub_vendor_name was not passed' USING ERRCODE = 'JH501';
			END IF;
			SELECT company_id INTO sub_comp_id FROM company
			WHERE company_name = pci_sub_vendor_name;
		
			IF NOT FOUND THEN
				INSERT INTO company (company_name, description)
				VALUES (pci_sub_vendor_name, 'PCI vendor auto-insert')
				RETURNING company_id INTO sub_comp_id;
			END IF;

			INSERT INTO property (
				property_name,
				property_type,
				property_value,
				company_id
			) VALUES (
				'PCIVendorID',
				'DeviceProvisioning',
				pci_sub_vendor_id,
				sub_comp_id
			);
			sub_vendor_name := pci_sub_vendor_name;
		END IF;

		--
		-- Fetch the slot type
		--

		SELECT 
			slot_type_id INTO stid
		FROM
			slot_type st
		WHERE
			st.slot_type = insert_pci_component.slot_type AND
			slot_function = 'PCI';

		IF NOT FOUND THEN
			RAISE EXCEPTION 'slot type % with function PCI not found adding component_type',
				insert_pci_component.slot_type
				USING ERRCODE = 'JH501';
		END IF;

		--
		-- Figure out the best name/description to insert this component with
		--
		IF pci_sub_device_name IS NOT NULL AND pci_sub_device_name != 'Device' THEN
			model_name = concat_ws(' ', 
				sub_vendor_name, pci_sub_device_name,
				'(' || vendor_name, pci_device_name || ')');
		ELSIF pci_sub_device_name = 'Device' THEN
			model_name = concat_ws(' ', 
				vendor_name, '(' || sub_vendor_name || ')', pci_device_name);
		ELSE
			model_name = concat_ws(' ', vendor_name, pci_device_name);
		END IF;
		INSERT INTO component_type (
			company_id,
			model,
			slot_type_id,
			asset_permitted,
			description
		) VALUES (
			CASE WHEN 
				sub_comp_id IS NULL OR
				pci_sub_device_name IS NULL OR
				pci_sub_device_name = 'Device'
			THEN
				comp_id
			ELSE
				sub_comp_id
			END,
			CASE WHEN
				pci_sub_device_name IS NULL OR
				pci_sub_device_name = 'Device'
			THEN
				pci_device_name
			ELSE
				pci_sub_device_name
			END,
			stid,
			'Y',
			model_name
		) RETURNING component_type_id INTO ctid;
		--
		-- Insert properties for the PCI vendor/device IDs
		--
		INSERT INTO component_property (
			component_property_name,
			component_property_type,
			component_type_id,
			property_value
		) VALUES 
			('PCIVendorID', 'PCI', ctid, pci_vendor_id),
			('PCIDeviceID', 'PCI', ctid, pci_device_id);
		
		IF (pci_subsystem_id IS NOT NULL) THEN
			INSERT INTO component_property (
				component_property_name,
				component_property_type,
				component_type_id,
				property_value
			) VALUES 
				('PCISubsystemVendorID', 'PCI', ctid, pci_sub_vendor_id),
				('PCISubsystemID', 'PCI', ctid, pci_subsystem_id);
		END IF;
		--
		-- Insert the component functions
		--

		INSERT INTO component_type_component_func (
			component_type_id,
			component_function
		) SELECT DISTINCT
			ctid,
			cf
		FROM
			unnest(array_append(component_function_list, 'PCI')) x(cf);
	END IF;


	--
	-- We have a component_type_id now, so look to see if this component
	-- serial number already exists
	--
	IF serial_number IS NOT NULL THEN
		SELECT 
			component.* INTO c
		FROM
			component JOIN
			asset a USING (component_id)
		WHERE
			component_type_id = ctid AND
			a.serial_number = sn;

		IF FOUND THEN
			RETURN c;
		END IF;
	END IF;

	INSERT INTO jazzhands.component (
		component_type_id
	) VALUES (
		ctid
	) RETURNING * INTO c;

	IF serial_number IS NOT NULL THEN
		INSERT INTO asset (
			component_id,
			serial_number,
			ownership_status
		) VALUES (
			c.component_id,
			serial_number,
			'unknown'
		);
	END IF;

	RETURN c;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION component_utils.insert_disk_component(
	model				text,
	bytes				bigint,
	vendor_name			text DEFAULT NULL,
	protocol			text DEFAULT 'SATA',
	media_type			text DEFAULT 'Rotational',
	serial_number		text DEFAULT NULL
) RETURNS jazzhands.component
AS $$
DECLARE
	m			ALIAS FOR model;
	sn			ALIAS FOR serial_number;
	ctid		integer;
	stid		integer;
	c			RECORD;
	cid			integer;
BEGIN
	cid := NULL;

	IF vendor_name IS NOT NULL THEN	
		SELECT 
			company_id INTO cid
		FROM
			company c LEFT JOIN
			property p USING (company_id)
		WHERE
			property_type = 'DeviceProvisioning' AND
			property_name = 'VendorDiskProbeString' AND
			property_value = vendor_name;
	END IF;

	--
	-- See if we have this component type in the database already.
	--
	SELECT DISTINCT
		component_type_id INTO ctid
	FROM
		component_type ct JOIN
		component_type_component_func ctcf USING (component_type_id)
	WHERE
		component_function = 'disk' AND
		ct.model = m AND
		CASE WHEN cid IS NOT NULL THEN
			(company_id = cid)
		ELSE
			true
		END;

	--
	-- If the type isn't found, then we need to insert it
	--
	IF NOT FOUND THEN
		--
		-- Fetch the slot type
		--
		SELECT 
			slot_type_id INTO stid
		FROM
			slot_type st
		WHERE
			st.slot_type = protocol AND
			slot_function = 'disk';

		IF NOT FOUND THEN
			RAISE EXCEPTION 'slot type % with function disk not found adding component_type',
				protocol
				USING ERRCODE = 'JH501';
		END IF;

		IF cid IS NULL THEN
			SELECT
				company_id INTO cid
			FROM
				company
			WHERE
				company_name = 'unknown';

			IF NOT FOUND THEN
				IF NOT FOUND THEN
					RAISE EXCEPTION 'company_id for unknown company not found adding component_type'
						USING ERRCODE = 'JH501';
				END IF;
			END IF;
		END IF;

		INSERT INTO component_type (
			company_id,
			model,
			slot_type_id,
			asset_permitted,
			description
		) VALUES (
			cid,
			model,
			stid,
			'Y',
			concat_ws(' ', vendor_name, model, media_type, 'disk')
		) RETURNING component_type_id INTO ctid;

		--
		-- Insert component properties for the disk
		--
		INSERT INTO component_property (
			component_property_name,
			component_property_type,
			component_type_id,
			property_value
		) VALUES 
			('DiskSize', 'disk', ctid, bytes),
			('DiskProtocol', 'disk', ctid, protocol),
			('MediaType', 'disk', ctid, media_type);
		
		--
		-- Insert the component functions
		--

		INSERT INTO component_type_component_func (
			component_type_id,
			component_function
		) SELECT DISTINCT
			ctid,
			cf
		FROM
			unnest(ARRAY['storage', 'disk']) x(cf);
	END IF;

	--
	-- We have a component_type_id now, so look to see if this component
	-- serial number already exists
	--
	IF serial_number IS NOT NULL THEN
		SELECT 
			component.* INTO c
		FROM
			component JOIN
			asset a USING (component_id)
		WHERE
			component_type_id = ctid AND
			a.serial_number = sn;

		IF FOUND THEN
			RETURN c;
		END IF;
	END IF;

	INSERT INTO jazzhands.component (
		component_type_id
	) VALUES (
		ctid
	) RETURNING * INTO c;

	IF serial_number IS NOT NULL THEN
		INSERT INTO asset (
			component_id,
			serial_number,
			ownership_status
		) VALUES (
			c.component_id,
			serial_number,
			'unknown'
		);
	END IF;

	RETURN c;

END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION component_utils.insert_memory_component(
	model				text,
	memory_size			bigint,
	memory_speed		bigint,
	memory_type			text DEFAULT 'DDR3',
	vendor_name			text DEFAULT NULL,
	serial_number		text DEFAULT NULL
) RETURNS jazzhands.component
AS $$
DECLARE
	m			ALIAS FOR model;
	sn			ALIAS FOR serial_number;
	ctid		integer;
	stid		integer;
	c			RECORD;
	cid			integer;
BEGIN
	cid := NULL;

	IF vendor_name IS NOT NULL THEN	
		SELECT 
			company_id INTO cid
		FROM
			company c LEFT JOIN
			property p USING (company_id)
		WHERE
			property_type = 'DeviceProvisioning' AND
			property_name = 'VendorMemoryProbeString' AND
			property_value = vendor_name;
	END IF;

	--
	-- See if we have this component type in the database already.
	--
	SELECT DISTINCT
		component_type_id INTO ctid
	FROM
		component_type ct JOIN
		component_type_component_func ctcf USING (component_type_id)
	WHERE
		component_function = 'memory' AND
		ct.model = m AND
		CASE WHEN cid IS NOT NULL THEN
			(company_id = cid)
		ELSE
			true
		END;

	--
	-- If the type isn't found, then we need to insert it
	--
	IF NOT FOUND THEN
		--
		-- Fetch the slot type
		--
		SELECT 
			slot_type_id INTO stid
		FROM
			slot_type st
		WHERE
			st.slot_type = memory_type AND
			slot_function = 'memory';

		IF NOT FOUND THEN
			RAISE EXCEPTION 'slot type % with function memory not found adding component_type',
				memory_type
				USING ERRCODE = 'JH501';
		END IF;

		IF cid IS NULL THEN
			SELECT
				company_id INTO cid
			FROM
				company
			WHERE
				company_name = 'unknown';

			IF NOT FOUND THEN
				IF NOT FOUND THEN
					RAISE EXCEPTION 'company_id for unknown company not found adding component_type'
						USING ERRCODE = 'JH501';
				END IF;
			END IF;
		END IF;

		INSERT INTO component_type (
			company_id,
			model,
			slot_type_id,
			asset_permitted,
			description
		) VALUES (
			cid,
			model,
			stid,
			'Y',
			concat_ws(' ', vendor_name, model, (memory_size || 'MB'), 'memory')
		) RETURNING component_type_id INTO ctid;

		--
		-- Insert component properties for the memory
		--
		INSERT INTO component_property (
			component_property_name,
			component_property_type,
			component_type_id,
			property_value
		) VALUES 
			('MemorySize', 'memory', ctid, memory_size),
			('MemorySpeed', 'memory', ctid, memory_speed);
		
		--
		-- Insert the component functions
		--

		INSERT INTO component_type_component_func (
			component_type_id,
			component_function
		) SELECT DISTINCT
			ctid,
			cf
		FROM
			unnest(ARRAY['memory']) x(cf);
	END IF;

	--
	-- We have a component_type_id now, so look to see if this component
	-- serial number already exists
	--
	IF serial_number IS NOT NULL THEN
		SELECT 
			component.* INTO c
		FROM
			component JOIN
			asset a USING (component_id)
		WHERE
			component_type_id = ctid AND
			a.serial_number = sn;

		IF FOUND THEN
			RETURN c;
		END IF;
	END IF;

	INSERT INTO jazzhands.component (
		component_type_id
	) VALUES (
		ctid
	) RETURNING * INTO c;

	IF serial_number IS NOT NULL THEN
		INSERT INTO asset (
			component_id,
			serial_number,
			ownership_status
		) VALUES (
			c.component_id,
			serial_number,
			'unknown'
		);
	END IF;

	RETURN c;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION component_utils.insert_cpu_component(
	model				text,
	processor_speed		bigint,
	processor_cores		bigint,
	socket_type			text,
	vendor_name			text DEFAULT NULL,
	serial_number		text DEFAULT NULL
) RETURNS jazzhands.component
AS $$
DECLARE
	m			ALIAS FOR model;
	sn			ALIAS FOR serial_number;
	ctid		integer;
	stid		integer;
	c			RECORD;
	cid			integer;
BEGIN
	cid := NULL;

	IF vendor_name IS NOT NULL THEN	
		SELECT 
			company_id INTO cid
		FROM
			company c LEFT JOIN
			property p USING (company_id)
		WHERE
			property_type = 'DeviceProvisioning' AND
			property_name = 'VendorCPUProbeString' AND
			property_value = vendor_name;
	END IF;

	--
	-- See if we have this component type in the database already.
	--
	SELECT DISTINCT
		component_type_id INTO ctid
	FROM
		component_type ct JOIN
		component_type_component_func ctcf USING (component_type_id)
	WHERE
		component_function = 'CPU' AND
		ct.model = m AND
		CASE WHEN cid IS NOT NULL THEN
			(company_id = cid)
		ELSE
			true
		END;

	--
	-- If the type isn't found, then we need to insert it
	--
	IF NOT FOUND THEN
		--
		-- Fetch the slot type
		--
		SELECT 
			slot_type_id INTO stid
		FROM
			slot_type st
		WHERE
			st.slot_type = socket_type AND
			slot_function = 'CPU';

		IF NOT FOUND THEN
			RAISE EXCEPTION 'slot type %, function % not found adding component_type',
				socket_type,
				'CPU'
				USING ERRCODE = 'JH501';
		END IF;

		IF cid IS NULL THEN
			SELECT
				company_id INTO cid
			FROM
				company
			WHERE
				company_name = 'unknown';

			IF NOT FOUND THEN
				IF NOT FOUND THEN
					RAISE EXCEPTION 'company_id for unknown company not found adding component_type'
						USING ERRCODE = 'JH501';
				END IF;
			END IF;
		END IF;

		INSERT INTO component_type (
			company_id,
			model,
			slot_type_id,
			asset_permitted,
			description
		) VALUES (
			cid,
			model,
			stid,
			'Y',
			model
		) RETURNING component_type_id INTO ctid;

		--
		-- Insert component properties for the CPU
		--
		INSERT INTO component_property (
			component_property_name,
			component_property_type,
			component_type_id,
			property_value
		) VALUES 
			('ProcessorCores', 'CPU', ctid, processor_cores),
			('ProcessorSpeed', 'CPU', ctid, processor_speed);
		
		--
		-- Insert the component functions
		--

		INSERT INTO component_type_component_func (
			component_type_id,
			component_function
		) SELECT DISTINCT
			ctid,
			cf
		FROM
			unnest(ARRAY['CPU']) x(cf);
	END IF;

	--
	-- We have a component_type_id now, so look to see if this component
	-- serial number already exists
	--
	IF serial_number IS NOT NULL THEN
		SELECT 
			component.* INTO c
		FROM
			component JOIN
			asset a USING (component_id)
		WHERE
			component_type_id = ctid AND
			a.serial_number = sn;

		IF FOUND THEN
			RETURN c;
		END IF;
	END IF;

	INSERT INTO jazzhands.component (
		component_type_id
	) VALUES (
		ctid
	) RETURNING * INTO c;

	IF serial_number IS NOT NULL THEN
		INSERT INTO asset (
			component_id,
			serial_number,
			ownership_status
		) VALUES (
			c.component_id,
			serial_number,
			'unknown'
		);
	END IF;

	RETURN c;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION component_utils.insert_component_into_parent_slot(
	parent_component_id	integer,
	component_id	integer,
	slot_name		text,
	slot_function	text,
	slot_type		text DEFAULT 'unknown',
	slot_index		integer DEFAULT NULL,
	physical_label	text DEFAULT NULL
) RETURNS jazzhands.slot
AS $$
DECLARE
	pcid 	ALIAS FOR parent_component_id;
	cid		ALIAS FOR component_id;
	sf		ALIAS FOR slot_function;
	sn		ALIAS FOR slot_name;
	st		ALIAS FOR slot_type;
	s		RECORD;
	stid	integer;
BEGIN
	--
	-- Look for this slot assigned to the component
	--
	SELECT
		slot.* INTO s
	FROM
		slot JOIN
		slot_type USING (slot_type_id)
	WHERE
		slot.component_id = pcid AND
		slot_type.slot_type = st AND
		slot_type.slot_function = sf AND
		slot.slot_name = sn;

	IF NOT FOUND THEN
		RAISE DEBUG 'Auto-creating slot for component assignment';
		SELECT
			slot_type_id INTO stid
		FROM
			slot_type
		WHERE
			slot_type.slot_type = st AND
			slot_type.slot_function = sf;

		IF NOT FOUND THEN
			RAISE EXCEPTION 'slot type %, function % not found adding component_type',
				st,
				sf
				USING ERRCODE = 'JH501';
		END IF;

		INSERT INTO slot (
			component_id,
			slot_name,
			slot_index,
			slot_type_id,
			physical_label,
			description
		) VALUES (
			pcid,
			sn,
			slot_index,
			stid,
			physical_label,
			'autocreated component slot'
		) RETURNING * INTO s;
	END IF;

	RAISE DEBUG 'Assigning component with component_id % to slot %',
		cid, s.slot_id;

	UPDATE 
		component c
	SET
		parent_slot_id = s.slot_id
	WHERE
		c.component_id = cid;

	RETURN s;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql;

--
-- Replace a given simple component with another one.  This isn't very smart,
-- in that it doesn't touch component_property in any way, although perhaps
-- there should be a flag on val_component_property indicating which
-- properties are asset-related, and which are function-related to flag
-- which should be copied
--
-- Note: this does not move any sub-components that are attached to slots,
-- either
--
CREATE OR REPLACE FUNCTION component_utils.replace_component(
	old_component_id	integer,
	new_component_id	integer
) RETURNS VOID
AS $$
DECLARE
	oc	RECORD;
BEGIN
	SELECT
		* INTO oc
	FROM
		component
	WHERE
		component_id = old_component_id;

	UPDATE
		component
	SET
		parent_slot_id = NULL
	WHERE
		component_id = old_component_id;

	UPDATE 
		component
	SET
		parent_slot_id = oc.parent_slot_id
	WHERE
		component_id = new_component_id;

	UPDATE
		device
	SET
		component_id = new_component_id
	WHERE
		component_id = old_component_id;
	
	UPDATE
		physicalish_volume
	SET
		component_id = new_component_id
	WHERE
		component_id = old_component_id;

	RETURN;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql;

GRANT USAGE ON SCHEMA component_utils TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA component_utils TO ro_role;

--
-- Copyright (c) 2015 Matthew Ragan
-- All rights reserved.
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--      http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--

DO $$
DECLARE
        _tal INTEGER;
BEGIN
        select count(*)
        from pg_catalog.pg_namespace
        into _tal
        where nspname = 'lv_manip';
        IF _tal = 0 THEN
                DROP SCHEMA IF EXISTS lv_manip;
                CREATE SCHEMA lv_manip AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA lv_manip IS 'part of jazzhands';
        END IF;
END;
$$;

CREATE OR REPLACE FUNCTION lv_manip.delete_lv_hier(
	physicalish_volume_id	integer DEFAULT NULL,
	volume_group_id			integer DEFAULT NULL,
	logical_volume_id		integer DEFAULT NULL,
	pv_list	OUT integer[],
	vg_list	OUT integer[],
	lv_list	OUT integer[]
) RETURNS RECORD AS $$
DECLARE
	pvid ALIAS FOR physicalish_volume_id;
	vgid ALIAS FOR volume_group_id;
	lvid ALIAS FOR logical_volume_id;
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_pv_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = pvid
			END OR
			CASE WHEN vgid  IS NULL
				THEN false
				ELSE lh.volume_group_id = vgid
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = lvid
			END)
			AND child_pv_id IS NOT NULL
	) INTO pv_list;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_vg_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = pvid
			END OR
			CASE WHEN vgid  IS NULL
				THEN false
				ELSE lh.volume_group_id = vgid
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = lvid
			END)
			AND child_vg_id IS NOT NULL
	) INTO vg_list;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_lv_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = pvid
			END OR
			CASE WHEN vgid  IS NULL
				THEN false
				ELSE lh.volume_group_id = vgid
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = lvid
			END)
			AND child_lv_id IS NOT NULL
	) INTO lv_list;

	DELETE FROM logical_volume_property WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM logical_volume_purpose WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM logical_volume WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM volume_group WHERE volume_group_id = ANY(vg_list);
	DELETE FROM physicalish_volume WHERE physicalish_volume_id = ANY(pv_list);
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lv_manip.delete_lv_hier(
	INOUT physicalish_volume_list	integer[] DEFAULT NULL,
	INOUT volume_group_list		integer[] DEFAULT NULL,
	INOUT logical_volume_list		integer[] DEFAULT NULL
) RETURNS RECORD AS $$
DECLARE
	pv_list	integer[];
	vg_list	integer[];
	lv_list	integer[];
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_pv_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = ANY (physical_volume_list)
			END OR
			CASE WHEN vgid  IS NULL
				THEN false
				ELSE lh.volume_group_id = ANY (volume_group_list)
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = ANY (logical_volume_list)
			END)
			AND child_pv_id IS NOT NULL
	) INTO pv_list;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_vg_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = ANY (physicalish_volume_list)
			END OR
			CASE WHEN vgid  IS NULL
				THEN false
				ELSE lh.volume_group_id = ANY (volume_group_list)
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = ANY (logical_volume_list)
			END)
			AND child_vg_id IS NOT NULL
	) INTO vg_list;

	SELECT ARRAY(
		SELECT 
			DISTINCT child_lv_id
		FROM
			v_lv_hier lh
		WHERE
			(CASE WHEN pvid IS NULL
				THEN false
				ELSE lh.physicalish_volume_id = ANY (physicalish_volume_list)
			END OR
			CASE WHEN vgid  IS NULL
				THEN false
				ELSE lh.volume_group_id = ANY (volume_group_list)
			END OR
			CASE WHEN lvid IS NULL
				THEN false
				ELSE lh.logical_volume_id = ANY (logical_volume_list)
			END)
			AND child_lv_id IS NOT NULL
	) INTO lv_list;

	DELETE FROM logical_volume_property WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM logical_volume_purpose WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM logical_volume WHERE logical_volume_id = ANY(lv_list);
	DELETE FROM volume_group WHERE volume_group_id = ANY(vg_list);
	DELETE FROM physicalish_volume WHERE physicalish_volume_id = ANY(pv_list);

	physicalish_volume_list := pv_list;
	volume_group_list := vg_list;
	logical_volume_list := lv_list;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql;

--
-- This needs to be done recursively because lower level volume groups may
-- contain physicalish volumes that are not from this hierarchy
--
CREATE OR REPLACE FUNCTION lv_manip.delete_pv(
	physicalish_volume_list	integer[],
	purge_orphans			boolean DEFAULT false
) RETURNS VOID AS $$
DECLARE
	pvid integer;
	vgid integer;
BEGIN
	PERFORM * FROM lv_manip.remove_pv_membership(
		physicalish_volume_list,
		purge_orphans
	);

	DELETE FROM physicalish_volume WHERE
		physicalish_volume_id = ANY(physicalish_volume_list);
END;
$$
SET search_path = jazzhands
LANGUAGE plpgsql;

--
-- This needs to be done recursively because lower level volume groups may
-- contain physicalish volumes that are not from this hierarchy
--
CREATE OR REPLACE FUNCTION lv_manip.remove_pv_membership(
	physicalish_volume_list	integer[],
	purge_orphans			boolean DEFAULT false
) RETURNS VOID AS $$
DECLARE
	pvid integer;
	vgid integer;
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	FOREACH pvid IN ARRAY physicalish_volume_list LOOP
		DELETE FROM 
			volume_group_physicalish_vol vgpv
		WHERE
			vgpv.physicalish_volume_id = pvid
		RETURNING
			volume_group_id INTO vgid;
		
		IF FOUND AND purge_orphans THEN
			PERFORM * FROM
				volume_group_physicalish_vol vgpv
			WHERE
				volume_group_id = vgid;

			IF NOT FOUND THEN
				PERFORM lv_manip.delete_vg(
					volume_group_id := vgid,
					purge_orphans := purge_orphans
				);
			END IF;
		END IF;

	END LOOP;
END;
$$
SET search_path = jazzhands
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lv_manip.delete_vg(
	volume_group_id	integer,
	purge_orphans boolean DEFAULT false
) RETURNS VOID AS $$
DECLARE
	lvids	integer[];
BEGIN
	PERFORM lv_manip.delete_vg(
		volume_group_list := ARRAY [ volume_group_id ],
		purge_orphans := purge_orphans
	);
END;
$$
SET search_path = jazzhands
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lv_manip.delete_vg(
	volume_group_list	integer[],
	purge_orphans boolean DEFAULT false
) RETURNS VOID AS $$
DECLARE
	lvids	integer[];
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	SELECT ARRAY(
		SELECT
			logical_volume_id
		FROM
			logical_volume lv
		WHERE
			lv.volume_group_id = ANY(volume_group_list)
	) INTO lvids;

	PERFORM lv_manip.delete_pv(
		physicalish_volume_list := (
			SELECT ARRAY (SELECT
				physicalish_volume_id
			FROM
				physicalish_volume
			WHERE
				logical_volume_id = ANY(lvids)
		)),
		purge_orphans := purge_orphans
	);

	DELETE FROM
		volume_group_physicalish_vol vgpv
	WHERE
		vgpv.volume_group_id = ANY(volume_group_list);
	
	DELETE FROM
		volume_group_purpose vgp
	WHERE
		vgp.volume_group_id = ANY(volume_group_list);

	DELETE FROM
		logical_volume_property
	WHERE
		logical_volume_id = ANY(lvids);

	DELETE FROM
		logical_volume_purpose
	WHERE
		logical_volume_id = ANY(lvids);
	
	DELETE FROM
		logical_volume
	WHERE
		logical_volume_id = ANY(lvids);
	
	DELETE FROM
		volume_group vg
	WHERE
		vg.volume_group_id = ANY(volume_group_list);
END;
$$
SET search_path = jazzhands
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lv_manip.delete_lv(
	logical_volume_id	integer,
	purge_orphans boolean DEFAULT false
) RETURNS VOID AS $$
BEGIN
	PERFORM lv_manip.delete_lv(
		logical_volume_list := ARRAY [ logical_volume_id ],
		purge_orphans := purge_orphans
	);
END;
$$
SET search_path = jazzhands
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION lv_manip.delete_lv(
	logical_volume_list	integer[],
	purge_orphans boolean DEFAULT false
) RETURNS VOID AS $$
BEGIN
	SET CONSTRAINTS ALL DEFERRED;

	PERFORM lv_manip.delete_pv(
		physicalish_volume_list := (
			SELECT ARRAY (SELECT
				physicalish_volume_id
			FROM
				physicalish_volume pv
			WHERE
				pv.logical_volume_id = ANY(logical_volume_list)
		)),
		purge_orphans := purge_orphans
	);

	DELETE FROM
		logical_volume_property lvp
	WHERE
		lvp.logical_volume_id = ANY(logical_volume_list);
	
	DELETE FROM
		logical_volume_purpose lvp
	WHERE
		lvp.logical_volume_id = ANY(logical_volume_list);
	
	DELETE FROM
		logical_volume lv
	WHERE
		lv.logical_volume_id = ANY(logical_volume_list);
END;
$$
SET search_path = jazzhands
LANGUAGE plpgsql;

GRANT USAGE ON SCHEMA lv_manip TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA lv_manip TO ro_role;


------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trigger_automated_ac_on_person_company ON person_company;
CREATE TRIGGER trigger_automated_ac_on_person_company AFTER UPDATE OF manager_person_id, person_company_status, person_company_relation ON person_company FOR EACH ROW EXECUTE PROCEDURE automated_ac_on_person_company();

DROP TRIGGER IF EXISTS trig_add_account_automated_reporting_ac ON account;
CREATE TRIGGER trig_add_account_automated_reporting_ac AFTER INSERT OR UPDATE OF login, account_status ON account FOR EACH ROW EXECUTE PROCEDURE account_automated_reporting_ac();

alter function netblock_utils.recalculate_parentage (integer) set search_path = jazzhands;
alter function netblock_utils.find_rvs_zone_from_netblock_id(integer) set search_path=jazzhands;
alter function netblock_utils.find_free_netblocks(parent_netblock_id integer, netmask_bits integer, single_address boolean, allocation_method text, max_addresses integer, desired_ip_address inet, rnd_masklen_threshold integer, rnd_max_count integer) set search_path=jazzhands;
alter function netblock_utils.find_free_netblock(parent_netblock_id integer, netmask_bits integer, single_address boolean, allocation_method text, desired_ip_address inet, rnd_masklen_threshold integer, rnd_max_count integer) set search_path=jazzhands;
alter function netblock_utils.find_best_parent_id(in_netblock_id integer) set search_path=jazzhands;
alter function netblock_utils.find_best_parent_id(in_ipaddress inet, in_netmask_bits integer, in_netblock_type character varying, in_ip_universe_id integer, in_is_single_address character, in_netblock_id integer, in_fuzzy_can_subnet boolean, can_fix_can_subnet boolean) set search_path=jazzhands;
alter function netblock_utils.delete_netblock(integer) set search_path=jazzhands;
alter function netblock_utils.calculate_intermediate_netblocks(ip_block_1 inet, ip_block_2 inet, netblock_type text, ip_universe_id integer) set search_path=jazzhands;

alter function netblock_manip.allocate_netblock(parent_netblock_id integer, netmask_bits integer, address_type text, can_subnet boolean, allocation_method text, rnd_masklen_threshold integer, rnd_max_count integer, ip_address inet, description character varying, netblock_status character varying) set search_path=jazzhands;
alter function netblock_manip.allocate_netblock(parent_netblock_list integer[], netmask_bits integer, address_type text, can_subnet boolean, allocation_method text, rnd_masklen_threshold integer, rnd_max_count integer, ip_address inet, description character varying, netblock_status character varying) set search_path=jazzhands;
alter function netblock_manip.delete_netblock(integer) set search_path=jazzhands;
alter function netblock_manip.recalculate_parentage(integer) set search_path=jazzhands;


--------------------------------------------------------------------
-- DEALING WITH proc account_automated_reporting_ac -> account_automated_reporting_ac 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_automated_reporting_ac', 'account_automated_reporting_ac');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
DROP TRIGGER IF EXISTS trig_rm_account_automated_reporting_ac ON jazzhands.account;
DROP TRIGGER IF EXISTS trig_add_account_automated_reporting_ac ON jazzhands.account;
-- consider old oid 1354640
DROP FUNCTION IF EXISTS account_automated_reporting_ac();

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 1335770
CREATE OR REPLACE FUNCTION jazzhands.account_automated_reporting_ac()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
	_numrpt	INTEGER;
	_r		RECORD;
BEGIN
	IF TG_OP = 'DELETE' THEN
		IF OLD.account_role != 'primary' THEN
			RETURN OLD;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.account_role != 'primary' AND OLD.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
	END IF;

	-- XXX check account realm to see if we should be inserting for this
	-- XXX account realm

	IF TG_OP = 'INSERT' THEN
		PERFORM auto_ac_manip.create_report_account_collections(
			account_id := NEW.account_id, 
			account_realm_id := NEW.account_realm_id,
			login := NEW.login
		);
	ELSIF TG_OP = 'UPDATE' THEN
		PERFORM auto_ac_manip.rename_automated_report_acs(
			NEW.account_id, OLD.login, NEW.login, NEW.account_realm_id);
	ELSIF TG_OP = 'DELETE' THEN
		DELETE FROM account_collection_account WHERE account_id
			= OLD.account_id
		AND account_collection_id IN ( select account_collection_id
			FROM account_collection where account_collection_type
			= 'automated'
		);
		-- PERFORM auto_ac_manip.destroy_report_account_collections(
		-- 	account_id := OLD.account_id,
		-- 	account_realm_id := OLD.account_realm_id
		-- );
	END IF;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$function$
;
-- triggers on this function (if applicable)
CREATE TRIGGER trig_rm_account_automated_reporting_ac BEFORE DELETE ON account FOR EACH ROW EXECUTE PROCEDURE account_automated_reporting_ac();
CREATE TRIGGER trig_add_account_automated_reporting_ac AFTER INSERT OR UPDATE OF login, account_status ON account FOR EACH ROW EXECUTE PROCEDURE account_automated_reporting_ac();

-- DONE WITH proc account_automated_reporting_ac -> account_automated_reporting_ac 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc automated_ac_on_person_company -> automated_ac_on_person_company 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'automated_ac_on_person_company', 'automated_ac_on_person_company');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
DROP TRIGGER IF EXISTS trigger_automated_ac_on_person_company ON jazzhands.person_company;
-- consider old oid 1354634
DROP FUNCTION IF EXISTS automated_ac_on_person_company();

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 1335765
CREATE OR REPLACE FUNCTION jazzhands.automated_ac_on_person_company()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_acc	account%ROWTYPE;
BEGIN
	SELECT * INTO _acc 
	FROM account
	WHERE person_id = NEW.person_id
	AND account_role = 'primary'
	AND account_realm_id IN (
		SELECT account_realm_id FROM property 
		WHERE property_name = '_root_account_realm_id'
		AND property_type = 'Defaults'
	);

	IF NOT FOUND THEN
		RETURN NEW;
	END IF;

	SELECT * INTO _acc 
	FROM account
	WHERE person_id = OLD.manager_person_id
	AND account_role = 'primary'
	AND account_realm_id IN (
		SELECT account_realm_id FROM property 
		WHERE property_name = '_root_account_realm_id'
		AND property_type = 'Defaults'
	);
	IF FOUND THEN
		PERFORM auto_ac_manip.make_auto_report_acs_right(_acc.account_id, _acc.account_realm_id, _acc.login);
	END IF;

	SELECT * INTO _acc 
	FROM account
	WHERE person_id = NEW.manager_person_id
	AND account_role = 'primary'
	AND account_realm_id IN (
		SELECT account_realm_id FROM property 
		WHERE property_name = '_root_account_realm_id'
		AND property_type = 'Defaults'
	);
	IF FOUND THEN
		PERFORM auto_ac_manip.make_auto_report_acs_right(_acc.account_id, _acc.account_realm_id, _acc.login);
	END IF;


	RETURN NEW;
END;
$function$
;
-- triggers on this function (if applicable)
CREATE TRIGGER trigger_automated_ac_on_person_company AFTER UPDATE OF manager_person_id, person_company_status, person_company_relation ON person_company FOR EACH ROW EXECUTE PROCEDURE automated_ac_on_person_company();

-- DONE WITH proc automated_ac_on_person_company -> automated_ac_on_person_company 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc create_component_slots_by_trigger -> create_component_slots_by_trigger 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'create_component_slots_by_trigger', 'create_component_slots_by_trigger');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
DROP TRIGGER IF EXISTS trigger_create_component_template_slots ON jazzhands.component;
-- consider old oid 1354705
DROP FUNCTION IF EXISTS create_component_slots_by_trigger();

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 1335835
CREATE OR REPLACE FUNCTION jazzhands.create_component_slots_by_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	-- For inserts, just do a simple slot creation, for updates, things
	-- get more complicated, so try to migrate slots

	IF (TG_OP = 'INSERT' OR OLD.component_type_id != NEW.component_type_id)
	THEN
		PERFORM component_utils.create_component_template_slots(
			component_id := NEW.component_id);
	END IF;
	IF (TG_OP = 'UPDATE' AND OLD.component_type_id != NEW.component_type_id)
	THEN
		PERFORM component_utils.migrate_component_template_slots(
			component_id := NEW.component_id
		);
	END IF;
	RETURN NEW;
END;
$function$
;
-- triggers on this function (if applicable)
CREATE TRIGGER trigger_create_component_template_slots AFTER INSERT OR UPDATE OF component_type_id ON component FOR EACH ROW EXECUTE PROCEDURE create_component_slots_by_trigger();

-- DONE WITH proc create_component_slots_by_trigger -> create_component_slots_by_trigger 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc create_device_component_by_trigger -> create_device_component_by_trigger 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'create_device_component_by_trigger', 'create_device_component_by_trigger');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
DROP TRIGGER IF EXISTS trigger_create_device_component ON jazzhands.device;
-- consider old oid 1354709
DROP FUNCTION IF EXISTS create_device_component_by_trigger();

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 1335839
CREATE OR REPLACE FUNCTION jazzhands.create_device_component_by_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	devtype		RECORD;
	ctid		integer;
	cid			integer;
	scarr       integer[];
	dcarr       integer[];
	server_ver	integer;
BEGIN

	SELECT
		dt.device_type_id,
		dt.component_type_id,
		dt.template_device_id,
		d.component_id
	INTO
		devtype
	FROM
		device_type dt LEFT JOIN
		device d ON (dt.template_device_id = d.device_id)
	WHERE
		dt.device_type_id = NEW.device_type_id;

	IF NEW.component_id IS NOT NULL THEN
		IF devtype.component_type_id IS NOT NULL THEN
			SELECT
				component_type_id INTO ctid
			FROM
				component c
			WHERE
				c.component_id = NEW.component_id;

			IF ctid != devtype.component_type_id THEN
				UPDATE
					component
				SET
					component_type_id = devtype.component_type_id
				WHERE
					component_id = NEW.component_id;
			END IF;
		END IF;
			
		RETURN NEW;
	END IF;

	--
	-- If template_device_id doesn't exist, then create an instance of
	-- the component_id if it exists 
	--
	IF devtype.component_id IS NULL THEN
		--
		-- If the component_id doesn't exist, then we're done
		--
		IF devtype.component_type_id IS NULL THEN
			RETURN NEW;
		END IF;
		--
		-- Insert a component of the given type and tie it to the device
		--
		INSERT INTO component (component_type_id)
			VALUES (devtype.component_type_id)
			RETURNING component_id INTO cid;

		NEW.component_id := cid;
		RETURN NEW;
	ELSE
		SELECT setting INTO server_ver FROM pg_catalog.pg_settings
			WHERE name = 'server_version_num';

		IF (server_ver < 90400) THEN
			--
			-- This is pretty nasty; welcome to SQL
			--
			--
			-- This returns data into a temporary table (ugh) that's used as a
			-- key/value store to map each template component to the 
			-- newly-created one
			--
			CREATE TEMPORARY TABLE trig_comp_ins AS
			WITH comp_ins AS (
				INSERT INTO component (
					component_type_id
				) SELECT
					c.component_type_id
				FROM
					device_type dt JOIN 
					v_device_components dc ON
						(dc.device_id = dt.template_device_id) JOIN
					component c USING (component_id)
				WHERE
					device_type_id = NEW.device_type_id
				ORDER BY
					level, c.component_type_id
				RETURNING component_id
			)
			SELECT 
				src_comp.component_id as src_component_id,
				dst_comp.component_id as dst_component_id,
				src_comp.level as level
			FROM
				(SELECT
					c.component_id,
					level,
					row_number() OVER (ORDER BY level, c.component_type_id)
						AS rownum
				 FROM
					device_type dt JOIN 
					v_device_components dc ON
						(dc.device_id = dt.template_device_id) JOIN
					component c USING (component_id)
				 WHERE
					device_type_id = NEW.device_type_id
				) src_comp,
				(SELECT
					component_id,
					row_number() OVER () AS rownum
				 FROM
					comp_ins
				) dst_comp
			WHERE
				src_comp.rownum = dst_comp.rownum;

			/* 
				 Now take the mapping of components that were inserted above,
				 and tie the new components to the appropriate slot on the
				 parent.
				 The logic below is:
					- Take the template component, and locate its parent slot
					- Find the correct slot on the corresponding new parent 
					  component by locating one with the same slot_name and
					  slot_type_id on the mapped parent component_id
					- Update the parent_slot_id of the component with the
					  mapped component_id to this slot_id 
				 
				 This works even if the top-level component is attached to some
				 other device, since there will not be a mapping for those in
				 the table to locate.
			*/
					  
			UPDATE
				component dc
			SET
				parent_slot_id = ds.slot_id
			FROM
				trig_comp_ins tt,
				trig_comp_ins ptt,
				component sc,
				slot ss,
				slot ds
			WHERE
				tt.src_component_id = sc.component_id AND
				tt.dst_component_id = dc.component_id AND
				ss.slot_id = sc.parent_slot_id AND
				ss.component_id = ptt.src_component_id AND
				ds.component_id = ptt.dst_component_id AND
				ss.slot_type_id = ds.slot_type_id AND
				ss.slot_name = ds.slot_name;

			SELECT dst_component_id INTO cid FROM trig_comp_ins WHERE
				level = 1;

			NEW.component_id := cid;

			DROP TABLE trig_comp_ins;

			RETURN NEW;
		ELSE
			WITH dev_comps AS (
				SELECT
					c.component_id,
					c.component_type_id,
					level,
					row_number() OVER (ORDER BY level, c.component_type_id) AS
						rownum
				FROM
					device_type dt JOIN 
					v_device_components dc ON
						(dc.device_id = dt.template_device_id) JOIN
					component c USING (component_id)
				WHERE
					device_type_id = NEW.device_type_id
			),
			comp_ins AS (
				INSERT INTO component (
					component_type_id
				) SELECT
					component_type_id
				FROM
					dev_comps
				ORDER BY
					rownum
				RETURNING component_id, component_type_id
			),
			comp_ins_arr AS (
				SELECT
					array_agg(component_id) AS dst_arr
				FROM
					comp_ins
			),
			dev_comps_arr AS (
				SELECT
					array_agg(component_id) as src_arr
				FROM
					dev_comps
			)
			SELECT src_arr, dst_arr INTO scarr, dcarr FROM
				dev_comps_arr, comp_ins_arr;

			UPDATE
				component dc
			SET
				parent_slot_id = ds.slot_id
			FROM
				unnest(scarr, dcarr) AS 
					tt(src_component_id, dst_component_id),
				unnest(scarr, dcarr) AS 
					ptt(src_component_id, dst_component_id),
				component sc,
				slot ss,
				slot ds
			WHERE
				tt.src_component_id = sc.component_id AND
				tt.dst_component_id = dc.component_id AND
				ss.slot_id = sc.parent_slot_id AND
				ss.component_id = ptt.src_component_id AND
				ds.component_id = ptt.dst_component_id AND
				ss.slot_type_id = ds.slot_type_id AND
				ss.slot_name = ds.slot_name;

			SELECT 
				component_id INTO NEW.component_id
			FROM 
				component c
			WHERE
				component_id = ANY(dcarr) AND
				parent_slot_id IS NULL;

			RETURN NEW;
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;
-- triggers on this function (if applicable)
CREATE TRIGGER trigger_create_device_component BEFORE INSERT OR UPDATE OF device_type_id ON device FOR EACH ROW EXECUTE PROCEDURE create_device_component_by_trigger();

-- DONE WITH proc create_device_component_by_trigger -> create_device_component_by_trigger 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc delete_peraccount_account_collection -> delete_peraccount_account_collection 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'delete_peraccount_account_collection', 'delete_peraccount_account_collection');

-- DROP OLD FUNCTION
-- triggers on this function (if applicable)
DROP TRIGGER IF EXISTS trigger_delete_peraccount_account_collection ON jazzhands.account;
-- consider old oid 1354556
DROP FUNCTION IF EXISTS delete_peraccount_account_collection();

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 1335687
CREATE OR REPLACE FUNCTION jazzhands.delete_peraccount_account_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	acid			account_collection.account_collection_id%TYPE;
BEGIN
	IF TG_OP = 'DELETE' THEN
		SELECT	account_collection_id
		  INTO	acid
		  FROM	account_collection ac
				INNER JOIN account_collection_account aca
					USING (account_collection_id)
		 WHERE	aca.account_id = OLD.account_Id
		   AND	ac.account_collection_type = 'per-account';

		IF acid is NOT NULL THEN
			DELETE from account_collection_account
			where account_collection_id = acid;

			DELETE from account_collection
			where account_collection_id = acid;
		END IF;
	END IF;
	RETURN OLD;
END;
$function$
;
-- triggers on this function (if applicable)
CREATE TRIGGER trigger_delete_peraccount_account_collection BEFORE DELETE ON account FOR EACH ROW EXECUTE PROCEDURE delete_peraccount_account_collection();

-- DONE WITH proc delete_peraccount_account_collection -> delete_peraccount_account_collection 
--------------------------------------------------------------------

--------------------------------------------------------------------
--- new data from initialization
--------------------------------------------------------------------

DO $$
DECLARE
	_tally INTEGER;
BEGIN
	SELECT count(*)  INTO _tally
	FROM val_property
	WHERE property_name != 'PermitStabSection'
	AND property_type != 'StabRole';

	IF _tally = 0 THEN
		insert into val_property (
        	PROPERTY_NAME, PROPERTY_TYPE, IS_MULTIVALUE, PROPERTY_DATA_TYPE,
        	permit_account_collection_id
		)  values ('PermitStabSection', 'StabRole', 'Y', 'list', 'REQUIRED');
	END IF;
END;
$$;

DO $$
DECLARE
	_tally INTEGER;
	_x TEXT;
BEGIN
	FOREACH _x IN ARRAY ARRAY['Device','DNS','Netblock','Sites','StabAccess',
			'Attest','Approval','FullAdmin']
	LOOP
		SELECT count(*)  INTO _tally
		FROM val_property_value
		WHERE property_name != 'PermitStabSection'
		AND property_type != 'StabRole'
		AND valid_property_value != _x;

		IF _tally = 0 THEN
			insert into val_property_value (
        			property_name, property_type, valid_property_value
			) values
        			('PermitStabSection', 'StabRole', _x)
			;
		END IF;
	END LOOP;
END;
$$;

DO $$
DECLARE
	_tally INTEGER;
BEGIN
	SELECT count(*)  INTO _tally
	FROM val_property
	WHERE property_name != '_stab_root'
	AND property_type != 'Defaults';

	IF _tally = 0 THEN
		insert into val_property (
        		property_name, property_type, is_multivalue, property_data_type,
        		description
		) values (
        		'_stab_root', 'Defaults', 'N', 'string',
        		'root of url for stab, if apps need to direct people'
		);
	END IF;
END;
$$;

DO $$
DECLARE
	_tally INTEGER;
BEGIN
	SELECT count(*)  INTO _tally
	FROM val_property
	WHERE property_name != '_approval_email_signer'
	AND property_type != 'Defaults';

	IF _tally = 0 THEN
		insert into val_property (
        		property_name, property_type, is_multivalue, property_data_type,
        		description
		) values (
        		'_approval_email_signer', 'Defaults', 'N', 'string',
        		'Email address to sign aproval emails from (in body)'
		);
	END IF;
END;
$$;

DO $$
DECLARE
	_tally INTEGER;
BEGIN
	SELECT count(*)  INTO _tally
	FROM val_property
	WHERE property_name != '_can_approve_all'
	AND property_type != 'Defaults';

	IF _tally = 0 THEN
		insert into val_property (
        		property_name, property_type, is_multivalue, property_data_type,
        		description, permit_account_collection_id
		) values (
        		'_can_approve_all', 'Defaults', 'Y', 'string',
        		'Stored Procedures will allow these people to execute any approval.  Assign sparingly, if at all.',
        		'REQUIRED'
		);
	END IF;
END;
$$;


--------------------------------------------------------------------
--- done new data from initialization
--------------------------------------------------------------------

-- Clean Up
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_saved_grants();
GRANT select on all tables in schema jazzhands to ro_role;
GRANT insert,update,delete on all tables in schema jazzhands to iud_role;
GRANT select on all sequences in schema jazzhands to ro_role;
GRANT usage on all sequences in schema jazzhands to iud_role;
GRANT select on all tables in schema audit to ro_role;
GRANT select on all sequences in schema audit to ro_role;
-- SELECT schema_support.end_maintenance();
