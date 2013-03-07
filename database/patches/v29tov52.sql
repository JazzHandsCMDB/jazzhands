\set ON_ERROR_STOP

set search_path = jazzhands;

-- views that get recreated later
drop view v_person_company_expanded;

-- rename device_collection_member to device_collection_device
alter table audit.device_collection_member rename to device_collection_device;
alter table device_collection_member rename to device_collection_device;

alter sequence audit.device_collection_member_seq rename to device_collection_device_seq;
alter sequence audit.token_collection_member_seq rename to token_collection_token_seq;

DROP INDEX ix_netdev_coll_mbr_netdev_coll;
CREATE INDEX ix_dev_col_dev_dev_colid ON device_collection_device USING btree (device_collection_id);

ALTER TABLE ONLY device_collection_device DROP CONSTRAINT fk_devcollmem_dev_id;
ALTER TABLE ONLY device_collection_device
    ADD CONSTRAINT fk_devcolldev_dev_id FOREIGN KEY (device_id) REFERENCES device(device_id);

ALTER TABLE ONLY device_collection_device DROP CONSTRAINT fk_devcollmem_devc_id;

ALTER TABLE ONLY device_collection_device
	ADD CONSTRAINT fk_devcolldev_dev_colid FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);

ALTER TABLE ONLY device_collection_device
 	DROP  CONSTRAINT sys_c002655;

ALTER TABLE ONLY device_collection_device
	ADD CONSTRAINT pk_device_collection_device PRIMARY KEY (device_id, device_collection_id);

DROP TRIGGER IF EXISTS trig_userlog_device_collection_member on device_collection_device;
CREATE TRIGGER trig_userlog_device_collection_device BEFORE INSERT OR UPDATE ON device_collection_device FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();

DROP TRIGGER trigger_audit_device_collection_member on device_collection_device;
DROP FUNCTION IF EXISTS perform_audit_device_collection_member();
SELECT schema_support.rebuild_audit_trigger('device_collection_device');


-- rename token_collection_member to token_collection_device

alter table audit.token_collection_member rename to token_collection_token;
alter table token_collection_member rename to token_collection_token;

ALTER TABLE ONLY token_collection_token DROP constraint pk_token_collection_member;
ALTER TABLE ONLY token_collection_token
    ADD CONSTRAINT pk_token_collection_token PRIMARY KEY (token_collection_id, token_id);

DROP INDEX idx_tok_col_member_tok_col_id ;
CREATE INDEX idx_tok_col_token_tok_col_id ON token_collection_token USING btree (token_collection_id);

DROP INDEX idx_tok_col_member_tok_id ;
CREATE INDEX idx_tok_col_token_tok_id ON token_collection_token USING btree (token_id);

 ALTER TABLE ONLY token_collection_token DROP CONSTRAINT fk_tok_col_mem_token_id;
 ALTER TABLE ONLY token_collection_token
    ADD CONSTRAINT fk_tok_col_tok_token_id FOREIGN KEY (token_id) REFERENCES token(token_id);

ALTER TABLE ONLY token_collection_token DROP CONSTRAINT fk_tok_col_mem_token_col_id;
ALTER TABLE ONLY token_collection_token
    ADD CONSTRAINT fk_tok_col_tok_token_col_id FOREIGN KEY (token_collection_id) REFERENCES token_collection(token_collection_id);

DROP TRIGGER IF EXISTS trig_userlog_token_collection_member on token_collection_token;

CREATE TRIGGER trig_userlog_token_collection_token BEFORE INSERT OR UPDATE ON token_collection_token FOR EACH ROW EXECUTE PROCEDURE schema_support.trigger_ins_upd_generic_func();

DROP TRIGGER IF EXISTS trigger_audit_token_collection_member ON token_collection_token;
DROP FUNCTION IF EXISTS perform_audit_token_collection_member();
SELECT schema_support.rebuild_audit_trigger('token_collection_token');

-- DEALING WITH TABLE dns_domain [655411]

-- FOREIGN KEYS FROM
alter table dns_record drop constraint fk_dnsid_dnsdom_id;
alter table property drop constraint fk_property_pval_dnsdomid;
alter table property drop constraint fk_property_dnsdomid;

-- FOREIGN KEYS TO
alter table dns_domain drop constraint fk_dns_dom_dns_dom_typ;
alter table dns_domain drop constraint fk_dnsdom_dnsdom_id;
alter table dns_domain drop constraint pk_dns_domain;
-- INDEXES
DROP INDEX xifdns_dom_dns_dom_type;
DROP INDEX idx_dnsdomain_parentdnsdomain;
-- CHECK CONSTRAINTS, etc
alter table dns_domain drop constraint ckc_should_generate_dns_doma;
-- TRIGGERS, etc
drop trigger trigger_audit_dns_domain on dns_domain;
drop trigger trig_userlog_dns_domain on dns_domain;


ALTER TABLE dns_domain RENAME TO dns_domain_v52;
ALTER TABLE audit.dns_domain RENAME TO dns_domain_v52;

CREATE TABLE dns_domain
(
	dns_domain_id	integer NOT NULL,
	soa_name	varchar(255)  NULL,
	soa_class	varchar(50)  NULL,
	soa_ttl	integer  NULL,
	soa_serial	bigint  NULL,
	soa_refresh	integer  NULL,
	soa_retry	integer  NULL,
	soa_expire	integer  NULL,
	soa_minimum	integer  NULL,
	soa_mname	varchar(255)  NULL,
	soa_rname	varchar(255) NOT NULL,
	parent_dns_domain_id	integer  NULL,
	should_generate	character(1) NOT NULL,
	last_generated	timestamp with time zone  NULL,
	zone_last_updated	timestamp with time zone  NULL,
	dns_domain_type	varchar(50) NOT NULL,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('dns_domain', false);
INSERT INTO dns_domain (
	dns_domain_id,
	soa_name,
	soa_class,
	soa_ttl,
	soa_serial,
	soa_refresh,
	soa_retry,
	soa_expire,
	soa_minimum,
	soa_mname,
	soa_rname,
	parent_dns_domain_id,
	should_generate,
	last_generated,
	zone_last_updated,
	dns_domain_type,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT		dns_domain_id,
	soa_name,
	soa_class,
	soa_ttl,
	soa_serial,
	soa_refresh,
	soa_retry,
	soa_expire,
	soa_minimum,
	soa_mname,
	soa_rname,
	parent_dns_domain_id,
	should_generate,
	last_generated,
	zone_last_updated,
	dns_domain_type,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM dns_domain_v52;

INSERT INTO audit.dns_domain (
	dns_domain_id,
	soa_name,
	soa_class,
	soa_ttl,
	soa_serial,
	soa_refresh,
	soa_retry,
	soa_expire,
	soa_minimum,
	soa_mname,
	soa_rname,
	parent_dns_domain_id,
	should_generate,
	last_generated,
	zone_last_updated,
	dns_domain_type,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT		dns_domain_id,
	soa_name,
	soa_class,
	soa_ttl,
	soa_serial,
	soa_refresh,
	soa_retry,
	soa_expire,
	soa_minimum,
	soa_mname,
	soa_rname,
	parent_dns_domain_id,
	should_generate,
	last_generated,
	zone_last_updated,
	dns_domain_type,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.dns_domain_v52;

ALTER TABLE dns_domain
	ALTER dns_domain_id
	SET DEFAULT nextval('dns_domain_dns_domain_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE dns_domain ADD CONSTRAINT pk_dns_domain PRIMARY KEY (dns_domain_id);
-- INDEXES
CREATE INDEX xifdns_dom_dns_dom_type ON dns_domain USING btree (dns_domain_type);
CREATE INDEX idx_dnsdomain_parentdnsdomain ON dns_domain USING btree (parent_dns_domain_id);

-- CHECK CONSTRAINTS
ALTER TABLE dns_domain ADD CONSTRAINT ckc_should_generate_dns_doma
	CHECK ((should_generate = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((should_generate)::text = upper((should_generate)::text)));

-- FOREIGN KEYS FROM
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsid_dnsdom_id
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_dnsdomid
	FOREIGN KEY (property_value_dns_domain_id) REFERENCES dns_domain(dns_domain_id) ON DELETE SET NULL;
ALTER TABLE property
	ADD CONSTRAINT fk_property_dnsdomid
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id) ON DELETE SET NULL;

-- FOREIGN KEYS TO
ALTER TABLE dns_domain
	ADD CONSTRAINT fk_dns_dom_dns_dom_typ
	FOREIGN KEY (dns_domain_type) REFERENCES val_dns_domain_type(dns_domain_type) ON DELETE SET NULL;
ALTER TABLE dns_domain
	ADD CONSTRAINT fk_dnsdom_dnsdom_id
	FOREIGN KEY (parent_dns_domain_id) REFERENCES dns_domain(dns_domain_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('dns_domain');
SELECT schema_support.rebuild_audit_trigger('dns_domain');
ALTER SEQUENCE dns_domain_dns_domain_id_seq
	 OWNED BY dns_domain.dns_domain_id;
DROP TABLE dns_domain_v52;
DROP TABLE audit.dns_domain_v52;
-- DEALING WITH TABLE x509_certificate [656668]

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


ALTER TABLE x509_certificate RENAME TO x509_certificate_v52;
ALTER TABLE audit.x509_certificate RENAME TO x509_certificate_v52;

CREATE TABLE x509_certificate
(
	x509_cert_id	integer NOT NULL,
	signing_cert_id	integer  NULL,
	x509_ca_cert_serial_number	integer  NULL,
	public_key	varchar(4000) NOT NULL,
	private_key	varchar(4000) NOT NULL,
	certificate_sign_req	varchar(4000) NULL,
	subject	varchar(255) NOT NULL,
	valid_from	timestamp(6) without time zone NOT NULL,
	valid_to	timestamp(6) without time zone NOT NULL,
	is_cert_revoked	character(1) NOT NULL,
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
FROM x509_certificate_v52;

COMMENT ON TABLE x509_certificate IS 'X509 specification Certificate.';
COMMENT ON COLUMN x509_certificate.x509_cert_id IS 'Uniquely identifies Certificate';
COMMENT ON COLUMN x509_certificate.signing_cert_id IS 'Identifier for the certificate that has signed this one.';
COMMENT ON COLUMN x509_certificate.x509_ca_cert_serial_number IS 'Serial INTEGER assigned to the certificate within Certificate Authority. It uniquely identifies certificate within the realm of the CA.';
COMMENT ON TABLE x509_certificate_v52 IS 'X509 specification Certificate.';
COMMENT ON COLUMN x509_certificate.public_key IS 'Textual representation of Certificate Public Key. Public Key is a component of X509 standard and is used for encryption.';
COMMENT ON COLUMN x509_certificate_v52.x509_cert_id IS 'Uniquely identifies Certificate';
COMMENT ON COLUMN x509_certificate.private_key IS 'Textual representation of Certificate Private Key. Private Key is a component of X509 standard and is used for encryption.';
COMMENT ON COLUMN x509_certificate_v52.signing_cert_id IS 'Identifier for the certificate that has signed this one.';
COMMENT ON COLUMN x509_certificate.subject IS 'Textual representation of a certificate subject. Certificate subject is a part of X509 certificate specifications.';
COMMENT ON COLUMN x509_certificate_v52.x509_ca_cert_serial_number IS 'Serial INTEGER assigned to the certificate within Certificate Authority. It uniquely identifies certificate within the realm of the CA.';
COMMENT ON COLUMN x509_certificate.valid_from IS 'Timestamp indicating when the certificate becomes valid and can be used.';
COMMENT ON COLUMN x509_certificate_v52.public_key IS 'Textual representation of Certificate Public Key. Public Key is a component of X509 standard and is used for encryption.';
COMMENT ON COLUMN x509_certificate.valid_to IS 'Timestamp indicating when the certificate becomes invalid and can''t be used.';
COMMENT ON COLUMN x509_certificate_v52.private_key IS 'Textual representation of Certificate Private Key. Private Key is a component of X509 standard and is used for encryption.';
COMMENT ON COLUMN x509_certificate.is_cert_revoked IS 'Indicates if certificate has been revoked. ''Y'' indicates that Certificate has been revoked.';
COMMENT ON COLUMN x509_certificate_v52.subject IS 'Textual representation of a certificate subject. Certificate subject is a part of X509 certificate specifications.';
COMMENT ON COLUMN x509_certificate_v52.valid_from IS 'Timestamp indicating when the certificate becomes valid and can be used.';
COMMENT ON COLUMN x509_certificate_v52.valid_to IS 'Timestamp indicating when the certificate becomes invalid and can''t be used.';
COMMENT ON COLUMN x509_certificate_v52.is_cert_revoked IS 'Indicates if certificate has been revoked. ''Y'' indicates that Certificate has been revoked.';

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
FROM audit.x509_certificate_v52;

ALTER TABLE x509_certificate
	ALTER x509_cert_id
	SET DEFAULT nextval('x509_certificate_x509_cert_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE x509_certificate ADD CONSTRAINT pk_x509_certificate PRIMARY KEY (x509_cert_id);
ALTER TABLE x509_certificate ADD CONSTRAINT ak_x509_cert_cert_ca_ser UNIQUE (signing_cert_id, x509_ca_cert_serial_number);
-- INDEXES

-- CHECK CONSTRAINTS

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
SELECT schema_support.rebuild_stamp_trigger('x509_certificate');
SELECT schema_support.rebuild_audit_trigger('x509_certificate');
ALTER SEQUENCE x509_certificate_x509_cert_id_seq
	 OWNED BY x509_certificate.x509_cert_id;
DROP TABLE x509_certificate_v52;
DROP TABLE audit.x509_certificate_v52;

-- DEALING WITH TABLE dns_record [707740]

CREATE SEQUENCE dns_record_dns_record_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- FOREIGN KEYS FROM
alter table device drop constraint fk_device_dnsrecord;
alter table network_service drop constraint fk_netsvc_dnsid_id;
alter table dns_record_relation drop constraint fk_dnsrec_ref_dnsrecrltn_rl_id;
alter table dns_record_relation drop constraint fk_dns_rec_ref_dns_rec_rltn;

-- FOREIGN KEYS TO
alter table dns_record drop constraint fk_dnsid_dnsdom_id;
alter table dns_record drop constraint fk_dnsrecord_dnsrecord;
alter table dns_record drop constraint fk_dnsrec_ref_dns_ref_id;
alter table dns_record drop constraint fk_dnsrecord_vdnstype;
alter table dns_record drop constraint fk_dns_record_vdnsclass;
alter table dns_record drop constraint fk_dnsid_nblk_id;
alter table dns_record drop constraint fk_dnsrec_vdnssrvsrvc;
alter table dns_record drop constraint pk_dns_record;
-- INDEXES
DROP INDEX idx_dnsrec_dnssrvservice;
DROP INDEX ix_dnsid_domid;
DROP INDEX ix_dnsid_netblock_id;
DROP INDEX idx_dnsrec_refdnsrec;
DROP INDEX idx_dnsrec_dnstype;
DROP INDEX idx_dnsrec_dnsclass;
-- CHECK CONSTRAINTS, etc
alter table dns_record drop constraint ckc_dns_srv_protocol_dns_reco;
alter table dns_record drop constraint ckc_is_enabled_dns_reco;
alter table dns_record drop constraint ckc_should_generate_p_dns_reco;
-- TRIGGERS, etc
drop trigger trig_userlog_dns_record on dns_record;
drop trigger trigger_audit_dns_record on dns_record;
drop trigger trigger_update_dns_zone on dns_record;


ALTER TABLE dns_record RENAME TO dns_record_v52;
ALTER TABLE audit.dns_record RENAME TO dns_record_v52;

CREATE TABLE dns_record
(
	dns_record_id	integer NOT NULL,
	dns_name	varchar(255)  NULL,
	dns_domain_id	integer NOT NULL,
	dns_ttl	integer  NULL,
	dns_class	varchar(50) NOT NULL,
	dns_type	varchar(50) NOT NULL,
	dns_value	varchar(512)  NULL,
	dns_priority	integer  NULL,
	dns_srv_service	varchar(50)  NULL,
	dns_srv_protocol	varchar(4)  NULL,
	dns_srv_weight	integer  NULL,
	dns_srv_port	integer  NULL,
	netblock_id	integer  NULL,
	reference_dns_record_id	integer  NULL,
	dns_value_record_id	integer  NULL,
	should_generate_ptr	character(1) NOT NULL,
	is_enabled	character(1) NOT NULL,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('dns_record', false);
INSERT INTO dns_record (
	dns_record_id,
	dns_name,
	dns_domain_id,
	dns_ttl,
	dns_class,
	dns_type,
	dns_value,
	dns_priority,
	dns_srv_service,
	dns_srv_protocol,
	dns_srv_weight,
	dns_srv_port,
	netblock_id,
	reference_dns_record_id,
	dns_value_record_id,
	should_generate_ptr,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT		dns_record_id,
	dns_name,
	dns_domain_id,
	dns_ttl,
	dns_class,
	dns_type,
	dns_value,
	dns_priority,
	dns_srv_service,
	dns_srv_protocol,
	dns_srv_weight,
	dns_srv_port,
	netblock_id,
	reference_dns_record_id,
	dns_value_record_id,
	should_generate_ptr,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM dns_record_v52;

INSERT INTO audit.dns_record (
	dns_record_id,
	dns_name,
	dns_domain_id,
	dns_ttl,
	dns_class,
	dns_type,
	dns_value,
	dns_priority,
	dns_srv_service,
	dns_srv_protocol,
	dns_srv_weight,
	dns_srv_port,
	netblock_id,
	reference_dns_record_id,
	dns_value_record_id,
	should_generate_ptr,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT		dns_record_id,
	dns_name,
	dns_domain_id,
	dns_ttl,
	dns_class,
	dns_type,
	dns_value,
	dns_priority,
	dns_srv_service,
	dns_srv_protocol,
	dns_srv_weight,
	dns_srv_port,
	netblock_id,
	reference_dns_record_id,
	dns_value_record_id,
	should_generate_ptr,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.dns_record_v52;

ALTER TABLE dns_record
	ALTER dns_record_id
	SET DEFAULT nextval('dns_record_dns_record_id_seq'::regclass);
ALTER TABLE dns_record
	ALTER should_generate_ptr
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE dns_record
	ALTER is_enabled
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE dns_record ADD CONSTRAINT pk_dns_record PRIMARY KEY (dns_record_id);
-- INDEXES
CREATE INDEX idx_dnsrec_dnssrvservice ON dns_record USING btree (dns_srv_service);
CREATE INDEX ix_dnsid_domid ON dns_record USING btree (dns_domain_id);
CREATE INDEX ix_dnsid_netblock_id ON dns_record USING btree (netblock_id);
CREATE INDEX idx_dnsrec_refdnsrec ON dns_record USING btree (reference_dns_record_id);
CREATE INDEX idx_dnsrec_dnstype ON dns_record USING btree (dns_type);
CREATE INDEX idx_dnsrec_dnsclass ON dns_record USING btree (dns_class);

-- CHECK CONSTRAINTS
ALTER TABLE DNS_RECORD
        ADD CONSTRAINT  CKC_DNS_SRV_PROTOCOL_DNS_RECO CHECK (DNS_SRV_PROTOCOL is null or (DNS_SRV_PROTOCOL in ('tcp','udp') and DNS_SRV_PROTOCOL = lower(DNS_SRV_PROTOCOL)))  ;
ALTER TABLE dns_record ADD CONSTRAINT ckc_is_enabled_dns_reco
	CHECK ((is_enabled = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_enabled)::text = upper((is_enabled)::text)));
ALTER TABLE dns_record ADD CONSTRAINT ckc_should_generate_p_dns_reco
	CHECK ((should_generate_ptr = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((should_generate_ptr)::text = upper((should_generate_ptr)::text)));

-- FOREIGN KEYS FROM
ALTER TABLE device
	ADD CONSTRAINT fk_device_dnsrecord
	FOREIGN KEY (identifying_dns_record_id) REFERENCES dns_record(dns_record_id);
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_dnsid_id
	FOREIGN KEY (dns_record_id) REFERENCES dns_record(dns_record_id);
ALTER TABLE dns_record_relation
	ADD CONSTRAINT fk_dnsrec_ref_dnsrecrltn_rl_id
	FOREIGN KEY (related_dns_record_id) REFERENCES dns_record(dns_record_id);
ALTER TABLE dns_record_relation
	ADD CONSTRAINT fk_dns_rec_ref_dns_rec_rltn
	FOREIGN KEY (dns_record_id) REFERENCES dns_record(dns_record_id);

-- FOREIGN KEYS TO
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsid_dnsdom_id
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsrecord_dnsrecord
	FOREIGN KEY (reference_dns_record_id) REFERENCES dns_record(dns_record_id);
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsrec_ref_dns_ref_id
	FOREIGN KEY (dns_value_record_id) REFERENCES dns_record(dns_record_id);
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsrecord_vdnstype
	FOREIGN KEY (dns_type) REFERENCES val_dns_type(dns_type);
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dns_record_vdnsclass
	FOREIGN KEY (dns_class) REFERENCES val_dns_class(dns_class);
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsid_nblk_id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsrec_vdnssrvsrvc
	FOREIGN KEY (dns_srv_service) REFERENCES val_dns_srv_service(dns_srv_service);

-- TRIGGERS
CREATE TRIGGER trigger_update_dns_zone AFTER INSERT OR DELETE OR UPDATE ON dns_record FOR EACH ROW EXECUTE PROCEDURE update_dns_zone();

SELECT schema_support.rebuild_stamp_trigger('dns_record');
SELECT schema_support.rebuild_audit_trigger('dns_record');
ALTER SEQUENCE dns_record_dns_record_id_seq
	 OWNED BY dns_record.dns_record_id;
DROP TABLE dns_record_v52;
DROP TABLE audit.dns_record_v52;

-- DEALING WITH TABLE person_company [766344]

-- FOREIGN KEYS FROM
alter table account drop constraint fk_account_company_person;

-- FOREIGN KEYS TO
alter table person_company drop constraint fk_person_company_prsncmpyrelt;
alter table person_company drop constraint fk_person_company_prsncmpy_sta;
alter table person_company drop constraint fk_person_company_mgrprsn_id;
alter table person_company drop constraint fk_person_company_sprprsn_id;
alter table person_company drop constraint fk_person_company_company_id;
alter table person_company drop constraint fk_person_company_prsnid;
alter table person_company drop constraint ak_uq_person_company_empid;
alter table person_company drop constraint ak_uq_prson_company_bdgid;
alter table person_company drop constraint pk_person_company;
-- INDEXES
DROP INDEX xifperson_company_person_id;
DROP INDEX xifperson_company_company_id;
DROP INDEX xif6person_company;
DROP INDEX xif4person_company;
DROP INDEX xif5person_company;
DROP INDEX xif3person_company;
-- CHECK CONSTRAINTS, etc
alter table person_company drop constraint check_yes_no_1391508687;
-- TRIGGERS, etc
drop trigger trigger_audit_person_company on person_company;
drop trigger trigger_propagate_person_status_to_account on person_company;
drop trigger trig_userlog_person_company on person_company;


ALTER TABLE person_company RENAME TO person_company_v52;
ALTER TABLE audit.person_company RENAME TO person_company_v52;

CREATE TABLE person_company
(
	company_id	integer NOT NULL,
	person_id	integer NOT NULL,
	person_company_status	varchar(50) NOT NULL,
	person_company_relation	varchar(50) NOT NULL,
	is_exempt	character(1) NOT NULL,
	is_management	character(1) NOT NULL,
	is_full_time	character(1) NOT NULL,
	description	varchar(255)  NULL,
	employee_id	integer  NULL,
	payroll_id	varchar(255)  NULL,
	external_hr_id	varchar(255)  NULL,
	position_title	varchar(50)  NULL,
	badge_id	varchar(12)  NULL,
	hire_date	timestamp with time zone  NULL,
	termination_date	timestamp with time zone  NULL,
	manager_person_id	integer  NULL,
	supervisor_person_id	integer  NULL,
	nickname	varchar(255)  NULL,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('person_company', false);
INSERT INTO person_company (
	company_id,
	person_id,
	person_company_status,
	person_company_relation,
	is_exempt,
	is_management,
	is_full_time,
	description,
	employee_id,
	payroll_id,
	external_hr_id,
	position_title,
	badge_id,
	hire_date,
	termination_date,
	manager_person_id,
	supervisor_person_id,
	nickname,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT		company_id,
	person_id,
	person_company_status,
	person_company_relation,
	is_exempt,
	'N',
	is_exempt,
	description,
	employee_id,
	payroll_id,
	external_hr_id,
	position_title,
	badge_id,
	hire_date,
	termination_date,
	manager_person_id,
	supervisor_person_id,
	nickname,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM person_company_v52;

INSERT INTO audit.person_company (
	company_id,
	person_id,
	person_company_status,
	person_company_relation,
	is_exempt,
	is_management,
	is_full_time,
	description,
	employee_id,
	payroll_id,
	external_hr_id,
	position_title,
	badge_id,
	hire_date,
	termination_date,
	manager_person_id,
	supervisor_person_id,
	nickname,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT		company_id,
	person_id,
	person_company_status,
	person_company_relation,
	is_exempt,
	'N',
	is_exempt,
	description,
	employee_id,
	payroll_id,
	external_hr_id,
	position_title,
	badge_id,
	hire_date,
	termination_date,
	manager_person_id,
	supervisor_person_id,
	nickname,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.person_company_v52;

ALTER TABLE person_company
	ALTER is_management
	SET DEFAULT 'N'::bpchar;
ALTER TABLE person_company
	ALTER is_full_time
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE person_company ADD CONSTRAINT ak_uq_person_company_empid UNIQUE (employee_id, company_id);
ALTER TABLE person_company ADD CONSTRAINT ak_uq_prson_company_bdgid UNIQUE (badge_id, company_id);
ALTER TABLE person_company ADD CONSTRAINT pk_person_company PRIMARY KEY (company_id, person_id);
-- INDEXES
CREATE INDEX xifperson_company_person_id ON person_company USING btree (person_id);
CREATE INDEX xifperson_company_company_id ON person_company USING btree (company_id);
CREATE INDEX xif6person_company ON person_company USING btree (person_company_relation);
CREATE INDEX xif4person_company ON person_company USING btree (supervisor_person_id);
CREATE INDEX xif5person_company ON person_company USING btree (person_company_status);
CREATE INDEX xif3person_company ON person_company USING btree (manager_person_id);

-- CHECK CONSTRAINTS
ALTER TABLE person_company ADD CONSTRAINT check_yes_no_691526916
	CHECK (is_full_time = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE person_company ADD CONSTRAINT check_yes_no_1391508687
	CHECK (is_exempt = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE person_company ADD CONSTRAINT check_yes_no_prsncmpy_mgmt
	CHECK (is_management = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
ALTER TABLE account
	ADD CONSTRAINT fk_account_company_person
	FOREIGN KEY (company_id, person_id) REFERENCES person_company(company_id, person_id) ON DELETE SET NULL;

-- FOREIGN KEYS TO
ALTER TABLE person_company
	ADD CONSTRAINT fk_person_company_prsncmpyrelt
	FOREIGN KEY (person_company_relation) REFERENCES val_person_company_relation(person_company_relation) ON DELETE SET NULL;
ALTER TABLE person_company
	ADD CONSTRAINT fk_person_company_prsncmpy_sta
	FOREIGN KEY (person_company_status) REFERENCES val_person_status(person_status) ON DELETE SET NULL;
ALTER TABLE person_company
	ADD CONSTRAINT fk_person_company_mgrprsn_id
	FOREIGN KEY (manager_person_id) REFERENCES person(person_id) ON DELETE SET NULL;
ALTER TABLE person_company
	ADD CONSTRAINT fk_person_company_sprprsn_id
	FOREIGN KEY (supervisor_person_id) REFERENCES person(person_id) ON DELETE SET NULL;
ALTER TABLE person_company
	ADD CONSTRAINT fk_person_company_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id);
ALTER TABLE person_company
	ADD CONSTRAINT fk_person_company_prsnid
	FOREIGN KEY (person_id) REFERENCES person(person_id);

COMMENT ON COLUMN person_company.nickname IS 'Nickname in the context of a given company.  This is less likely to be used, the value in person is preferrred.';
-- TRIGGERS
--- XXX trigger: trigger_propagate_person_status_to_account
SELECT schema_support.rebuild_stamp_trigger('person_company');
SELECT schema_support.rebuild_audit_trigger('person_company');
DROP TABLE person_company_v52;
DROP TABLE audit.person_company_v52;

---  redo v_application_role
-- Copyright (c) 2011, Todd M. Kover
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
--
-- $Id$
--

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

-- XXX v_application_role_member this should probably be pulled out to common
-- XXX need to decide how to deal with oracle's WITH READ ONLY

CREATE OR REPLACE VIEW v_application_role_member AS
	select	device_id,
		device_collection_id as role_id,
		DATA_INS_USER,
		DATA_INS_DATE,
		DATA_UPD_USER,
		DATA_UPD_DATE
	from	device_collection_device
	where	device_collection_id in
		(select device_collection_id from device_collection
			where device_collection_type = 'appgroup'
		)
;


-- v_company_hier
-- Copyright (c) 2012, Todd M. Kover
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
--
-- $Id$
--

CREATE OR REPLACE VIEW v_company_hier AS
WITH RECURSIVE var_recurse (
	level,
	root_company_id,
	company_id,
	person_id
) as (
	SELECT	
		0				as level,
		c.company_id			as root_company_id,
		c.company_id			as company_id,
		pc.person_id			as person_id
	  FROM	company c
		inner join person_company pc
			on c.company_id = pc.company_id
UNION ALL
	SELECT	
		x.level + 1			as level,
		x.company_id			as root_company_id,
		c.company_id			as company_id,
		pc.person_id			as person_id
	  FROM	var_recurse x
		inner join company c
			on c.parent_company_id = x.company_id
		inner join person_company pc
			on c.company_id = pc.company_id
) SELECT	distinct root_company_id as root_company_id, company_id
  from 		var_recurse;

-- netblock_manip

-- Copyright (c) 2012 Matthew Ragan
-- Copyright (c) 2005-2010, Vonage Holdings Corp.
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--     * Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--     * Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
-- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
/*
 * $Id$
 */

-------------------------------------------------------------------
-- returns the Id tag for CM
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION netblock_utils.id_tag()
RETURNS VARCHAR AS $$
BEGIN
	RETURN('<-- $Id -->');
END;
$$ LANGUAGE plpgsql;
-- end of procedure id_tag
-------------------------------------------------------------------

CREATE OR REPLACE FUNCTION netblock_utils.find_best_parent_id(
	in_IpAddress jazzhands.netblock.ip_address%type,
	in_Netmask_Bits jazzhands.netblock.netmask_bits%type,
	in_netblock_type jazzhands.netblock.netblock_type%type,
	in_ip_universe_id jazzhands.ip_universe.ip_universe_id%type,
	in_is_single_address jazzhands.netblock.is_single_address%type
) RETURNS jazzhands.netblock.netblock_id%type AS $$
DECLARE
	par_nbid	jazzhands.netblock.netblock_id%type;
BEGIN
	IF (in_netmask_bits IS NOT NULL) THEN
		in_IpAddress := set_masklen(in_IpAddress, in_Netmask_Bits);
	END IF;
	select  Netblock_Id
	  into	par_nbid
	  from  ( select Netblock_Id, Ip_Address, Netmask_Bits
		    from jazzhands.netblock
		   where
		   	in_IpAddress <<= ip_address
		    and is_single_address = 'N'
			and netblock_type = in_netblock_type
			and ip_universe_id = in_ip_universe_id
		    and (
				(in_is_single_address = 'N' AND netmask_bits < in_Netmask_Bits)
				OR
				(in_is_single_address = 'Y' AND 
					(in_Netmask_Bits IS NULL OR netmask_bits = in_Netmask_Bits))
			)
		order by netmask_bits desc
	) subq LIMIT 1;

	return par_nbid;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION netblock_utils.find_best_parent_id(
	in_netblock_id jazzhands.netblock.netblock_id%type
) RETURNS jazzhands.netblock.netblock_id%type AS $$
DECLARE
	nbrec		RECORD;
BEGIN
	SELECT * INTO nbrec FROM jazzhands.netblock WHERE 
		netblock_id = in_netblock_id;

	RETURN netblock_utils.find_best_parent_id(
		nbrec.ip_address,
		nbrec.netmask_bits,
		nbrec.netblock_type,
		nbrec.ip_universe_id,
		nbrec.is_single_address
	);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION netblock_utils.delete_netblock(
	in_netblock_id	jazzhands.netblock.netblock_id%type
) RETURNS VOID AS $$
DECLARE
	par_nbid	jazzhands.netblock.netblock_id%type;
BEGIN
	/*
	 * Update netblocks that use this as a parent to point to my parent
	 */
	SELECT
		netblock_id INTO par_nbid
	FROM
		jazzhands.netblock
	WHERE 
		netblock_id = in_netblock_id;
	
	UPDATE
		jazzhands.netblock
	SET
		parent_netblock_id = par_nbid
	WHERE
		parent_netblock_id = in_netblock_id;
	
	/*
	 * Now delete the record
	 */
	DELETE FROM jazzhands.netblock WHERE netblock_id = in_netblock_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION netblock_utils.recalculate_parentage(
	in_netblock_id	jazzhands.netblock.netblock_id%type
) RETURNS INTEGER AS $$
DECLARE
	nbrec		RECORD;
	childrec	RECORD;
	nbid		jazzhands.netblock.netblock_id%type;
	ipaddr		inet;

BEGIN
	SELECT * INTO nbrec FROM jazzhands.netblock WHERE 
		netblock_id = in_netblock_id;

	nbid := netblock_utils.find_best_parent_id(in_netblock_id);

	UPDATE jazzhands.netblock SET parent_netblock_id = nbid
		WHERE netblock_id = in_netblock_id;
	
	FOR childrec IN SELECT * FROM jazzhands.netblock WHERE 
		parent_netblock_id = nbid
		AND netblock_id != in_netblock_id
	LOOP
		IF (childrec.ip_address <<= nbrec.ip_address) THEN
			UPDATE jazzhands.netblock SET parent_netblock_id = in_netblock_id
				WHERE netblock_id = childrec.netblock_id;
		END IF;
	END LOOP;
	RETURN nbid;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION netblock_utils.find_rvs_zone_from_netblock_id(
	in_netblock_id	jazzhands.netblock.netblock_id%type
) RETURNS jazzhands.dns_domain.dns_domain_id%type AS $$
DECLARE
	v_rv	jazzhands.dns_domain.dns_domain_id%type;
	v_domid	jazzhands.dns_domain.dns_domain_id%type;
	v_lhsip	jazzhands.netblock.ip_address%type;
	v_rhsip	jazzhands.netblock.ip_address%type;
	nb_match CURSOR ( in_nb_id jazzhands.netblock.netblock_id%type) FOR
		-- The query used to include this in the where clause, but
		-- oracle was uber slow 
		--	net_manip.inet_base(nb.ip_address, root.netmask_bits) =  
		--		net_manip.inet_base(root.ip_address, root.netmask_bits) 
		select  rootd.dns_domain_id,
				 net_manip.inet_base(nb.ip_address, root.netmask_bits),
				 net_manip.inet_base(root.ip_address, root.netmask_bits)
		  from  jazzhands.netblock nb,
			jazzhands.netblock root
				inner join jazzhands.dns_record rootd
					on rootd.netblock_id = root.netblock_id
					and rootd.dns_type = 'REVERSE_ZONE_BLOCK_PTR'
		 where
		  	nb.netblock_id = in_nb_id;
BEGIN
	v_rv := NULL;
	OPEN nb_match(in_netblock_id);
	LOOP
		FETCH  nb_match INTO v_domid, v_lhsip, v_rhsip;
		if NOT FOUND THEN
			EXIT;
		END IF;

		if v_lhsip = v_rhsip THEN
			v_rv := v_domid;
			EXIT;
		END IF;
	END LOOP;
	CLOSE nb_match;
	return v_rv;
END;
$$ LANGUAGE plpgsql;

GRANT USAGE ON SCHEMA netblock_utils TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA netblock_utils TO PUBLIC;


--- START netblock triggers
-- Copyright (c) 2012, Matthew Ragan
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

CREATE OR REPLACE FUNCTION jazzhands.validate_netblock() RETURNS TRIGGER AS $$
DECLARE
	nbtype				RECORD;
	v_netblock_id		jazzhands.netblock.netblock_id%TYPE;
	parent_netblock		RECORD;
BEGIN
	/*
	 * Force netmask_bits to be authoritative.  If netblock_bits is NULL
	 * and this is a validated hierarchy, then set things to match the best
	 * parent
	 */

	IF NEW.netmask_bits IS NULL THEN
		SELECT * INTO nbtype FROM jazzhands.val_netblock_type WHERE 
			netblock_type = NEW.netblock_type;

		IF (NOT FOUND) OR nbtype.db_forced_hierarchy != 'Y' THEN
			RAISE EXCEPTION 'Column netmask_bits may not be null'
				USING ERRCODE = 'not_null_violation';
		END IF;
	
		RAISE DEBUG 'Calculating netmask for new netblock';

		v_netblock_id := netblock_utils.find_best_parent_id(
			NEW.ip_address,
			NULL,
			NEW.netblock_type,
			NEW.ip_universe_id,
			NEW.is_single_address
			);
	
		SELECT masklen(ip_address) INTO NEW.netmask_bits FROM jazzhands.netblock
			WHERE netblock_id = v_netblock_id;

		IF NEW.netmask_bits IS NULL THEN
			RAISE EXCEPTION 'Column netmask_bits may not be null'
				USING ERRCODE = 'not_null_violation';
		END IF;
	END IF;

	NEW.ip_address = set_masklen(NEW.ip_address, NEW.netmask_bits);

	IF NEW.can_subnet = 'Y' AND NEW.is_single_address = 'Y' THEN
		RAISE EXCEPTION 'Single addresses may not be subnettable'
			USING ERRCODE = 22106;
	END IF;

	IF NEW.is_single_address = 'N' AND (NEW.ip_address != cidr(NEW.ip_address))
			THEN
		RAISE EXCEPTION
			'Non-network bits must be zero if is_single_address is N for %',
			NEW.ip_address
			USING ERRCODE = 22103;
	END IF;

	/*
	 * Commented out check for RFC1918 space.  This is probably handled
	 * well enough by the ip_universe/netblock_type additions, although
	 * it's possible that netblock_type may need to have an additional
	 * field added to allow people to be stupid (for example,
	 * allow_duplicates='Y','N','RFC1918')
	 */

/*
	IF NOT net_manip.inet_is_private(NEW.ip_address) THEN
*/
			PERFORM netblock_id 
			   FROM jazzhands.netblock 
			  WHERE ip_address = NEW.ip_address AND
					ip_universe_id = NEW.ip_universe_id AND
					netblock_type = NEW.netblock_type AND
					is_single_address = NEW.is_single_address;
			IF (TG_OP = 'INSERT' AND FOUND) THEN 
				RAISE EXCEPTION 'Unique Constraint Violated on IP Address: %', 
					NEW.ip_address
					USING ERRCODE= 'unique_violation';
			END IF;
			IF (TG_OP = 'UPDATE') THEN
				IF (NEW.ip_address != OLD.ip_address AND FOUND) THEN
					RAISE EXCEPTION 
						'Unique Constraint Violated on IP Address: %', 
						NEW.ip_address
						USING ERRCODE = 'unique_violation';
				END IF;
			END IF;
/*
	END IF;
*/

	/*
	 * Parent validation is performed in the deferred after trigger
	 */

	 RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_netblock ON jazzhands.netblock;
DROP TRIGGER IF EXISTS tb_a_validate_netblock ON jazzhands.netblock;

/* This should be lexicographically the first trigger to fire */

CREATE TRIGGER tb_a_validate_netblock BEFORE INSERT OR UPDATE ON 
	jazzhands.netblock FOR EACH ROW EXECUTE PROCEDURE 
	jazzhands.validate_netblock();

CREATE OR REPLACE FUNCTION jazzhands.manipulate_netblock_parentage_before() RETURNS TRIGGER AS $$

DECLARE
	nbtype				record;
	v_netblock_type		jazzhands.val_netblock_type.netblock_type%TYPE;
BEGIN
	/*
	 * Get the parameters for the given netblock type to see if we need
	 * to do anything
	 */

	RAISE DEBUG 'Performing % on netblock %', TG_OP, NEW.netblock_id;
		
	SELECT * INTO nbtype FROM jazzhands.val_netblock_type WHERE 
		netblock_type = NEW.netblock_type;

	IF (NOT FOUND) OR nbtype.db_forced_hierarchy != 'Y' THEN
		RETURN NEW;
	END IF;

	/*
	 * Find the correct parent netblock
	 */ 

	RAISE DEBUG 'Setting forced hierarchical netblock %', NEW.netblock_id;
	NEW.parent_netblock_id := netblock_utils.find_best_parent_id(
		NEW.ip_address,
		NEW.netmask_bits,
		NEW.netblock_type,
		NEW.ip_universe_id,
		NEW.is_single_address
		);

	RAISE DEBUG 'Setting parent for netblock % (%, type %, universe %, single-address %) to %', 
		NEW.netblock_id, NEW.ip_address, NEW.netblock_type,
		NEW.ip_universe_id, NEW.is_single_address,
		NEW.parent_netblock_id;

	/*
	 * If we are an end-node, then we're done
	 */

	IF NEW.is_single_address = 'Y' THEN
		RETURN NEW;
	END IF;

	/*
	 * If we're updating and we're a container netblock, find
	 * all of the children of our new parent that should be ours and take 
	 * them.  They will already be guaranteed to be of the correct
	 * netblock_type and ip_universe_id.  We can't do this for inserts
	 * because the row doesn't exist causing foreign key problems, so
	 * that needs to be done in an after trigger.
	 */
	IF TG_OP = 'UPDATE' THEN
		RAISE DEBUG 'Setting parent for all child netblocks of parent netblock % that belong to %',
			NEW.parent_netblock_id,
			NEW.netblock_id;
		UPDATE
			jazzhands.netblock
		SET
			parent_netblock_id = NEW.netblock_id
		WHERE
			parent_netblock_id = NEW.parent_netblock_id AND
			ip_address <<= NEW.ip_address AND
			netblock_id != NEW.netblock_id;

		RAISE DEBUG 'Setting parent for all child netblocks of netblock % that no longer belong to it to %',
			NEW.parent_netblock_id,
			NEW.netblock_id;
		RAISE DEBUG 'Setting parent % to %',
			OLD.netblock_id,
			OLD.parent_netblock_id;
		UPDATE
			jazzhands.netblock
		SET
			parent_netblock_id = OLD.parent_netblock_id
		WHERE
			parent_netblock_id = NEW.netblock_id AND
			(ip_universe_id != NEW.ip_universe_id OR
			 netblock_type != NEW.netblock_type OR
			 NOT(ip_address <<= NEW.ip_address));
	END IF;

	RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_manipulate_netblock_parentage ON jazzhands.netblock;
DROP TRIGGER IF EXISTS tb_manipulate_netblock_parentage ON jazzhands.netblock;

CREATE TRIGGER tb_manipulate_netblock_parentage
	BEFORE INSERT OR UPDATE OF
		ip_address, netmask_bits, netblock_type, ip_universe_id
	ON jazzhands.netblock
	FOR EACH ROW EXECUTE PROCEDURE jazzhands.manipulate_netblock_parentage_before();


CREATE OR REPLACE FUNCTION jazzhands.manipulate_netblock_parentage_after() RETURNS TRIGGER AS $$

DECLARE
	nbtype				record;
	v_netblock_type		jazzhands.val_netblock_type.netblock_type%TYPE;
	v_row_count			integer;
	v_trigger			record;
BEGIN
	/*
	 * Get the parameters for the given netblock type to see if we need
	 * to do anything
	 */

	IF TG_OP = 'DELETE' THEN
		v_trigger := OLD;
	ELSE
		v_trigger := NEW;
	END IF;

	SELECT * INTO nbtype FROM jazzhands.val_netblock_type WHERE 
		netblock_type = v_trigger.netblock_type;

	IF (NOT FOUND) OR nbtype.db_forced_hierarchy != 'Y' THEN
		RETURN NULL;
	END IF;

	/*
	 * If we are deleting, attach all children to the parent and wipe
	 * hands on pants;
	 */
	IF TG_OP = 'DELETE' THEN
		UPDATE 
			jazzhands.netblock 
		SET
			parent_netblock_id = OLD.parent_netblock_id
		WHERE
			parent_netblock_id = OLD.netblock_id;
		
		GET DIAGNOSTICS v_row_count = ROW_COUNT;
	--	IF (v_row_count > 0) THEN
			RAISE DEBUG 'Set parent for all child netblocks of deleted netblock % (address %, is_single_address %) to % (% rows updated)',
				OLD.netblock_id,
				OLD.ip_address,
				OLD.is_single_address,
				OLD.parent_netblock_id,
				v_row_count;
	--	END IF;

		RETURN NULL;
	END IF;

	IF NEW.is_single_address = 'Y' THEN
		RETURN NULL;
	END IF;

	RAISE DEBUG 'Setting parent for all child netblocks of parent netblock % that belong to %',
		NEW.parent_netblock_id,
		NEW.netblock_id;

	IF NEW.parent_netblock_id IS NULL THEN
		UPDATE
			jazzhands.netblock
		SET
			parent_netblock_id = NEW.netblock_id
		WHERE
			parent_netblock_id IS NULL AND
			ip_address <<= NEW.ip_address AND
			netblock_id != NEW.netblock_id;
		RETURN NULL;
	ELSE
		UPDATE
			jazzhands.netblock
		SET
			parent_netblock_id = NEW.netblock_id
		WHERE
			parent_netblock_id = NEW.parent_netblock_id AND
			ip_address <<= NEW.ip_address AND
			netblock_id != NEW.netblock_id;

		RETURN NULL;
	END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS ta_manipulate_netblock_parentage ON jazzhands.netblock;

CREATE CONSTRAINT TRIGGER ta_manipulate_netblock_parentage
	AFTER INSERT OR DELETE ON jazzhands.netblock NOT DEFERRABLE
	FOR EACH ROW EXECUTE PROCEDURE jazzhands.manipulate_netblock_parentage_after();

CREATE OR REPLACE FUNCTION jazzhands.validate_netblock_parentage() RETURNS TRIGGER AS $$
DECLARE
	nbrec			record;
	realnew			record;
	nbtype			record;
	parent_nbid		jazzhands.netblock.netblock_id%type;
	ipaddr			inet;
	parent_ipaddr	inet;
	single_count	integer;
	nonsingle_count	integer;
	pip	    		jazzhands.netblock.ip_address%type;
BEGIN

	RAISE DEBUG 'Validating % of netblock %', TG_OP, NEW.netblock_id;

	SELECT * INTO nbtype FROM jazzhands.val_netblock_type WHERE 
		netblock_type = NEW.netblock_type;

	IF (NOT FOUND) THEN
		RETURN NULL;
	END IF;

	/*
	 * It's possible that due to delayed triggers that what is stored in
	 * NEW is not current, so fetch the current values
	 */
	
	SELECT * INTO realnew FROM jazzhands.netblock WHERE netblock_id =
		NEW.netblock_id;
	IF NOT FOUND THEN
		/* 
		 * If the netblock isn't there, it was subsequently deleted, so 
		 * our parentage doesn't need to be checked
		 */
		RETURN NULL;
	END IF;
	
	
	/*
	 * If the parent changed above (or somewhere else between update and
	 * now), just bail, because another trigger will have been fired that
	 * we can do the full check with.
	 */
	IF NEW.parent_netblock_id != realnew.parent_netblock_id AND
		realnew.parent_netblock_id IS NOT NULL
	THEN
		RAISE DEBUG '... skipping for now';
		RETURN NULL;
	END IF;

	/*
	 * Validate that parent and all children are of the same netblock_type and
	 * in the same ip_universe.  We care about this even if the
	 * netblock type is not a validated type.
	 */
	
	RAISE DEBUG 'Verifying child ip_universe and type match';
	PERFORM netblock_id FROM jazzhands.netblock WHERE
		parent_netblock_id = realnew.netblock_id AND
		netblock_type != realnew.netblock_type AND
		ip_universe_id != realnew.ip_universe_id;

	IF FOUND THEN
		RAISE EXCEPTION 'Netblock children must all be of the same type and universe as the parent'
			USING ERRCODE = 22109;
	END IF;

	RAISE DEBUG '... OK';

	/*
	 * validate that this netblock is attached to its correct parent
	 */
	IF realnew.parent_netblock_id IS NULL THEN
		IF nbtype.is_validated_hierarchy='N' THEN
			RETURN NULL;
		END IF;
		RAISE DEBUG 'Checking hierarchical netblock_id % with NULL parent',
			NEW.netblock_id;

		IF realnew.is_single_address = 'Y' THEN
			RAISE 'A single address (%) must be the child of a parent netblock',
				realnew.ip_address
				USING ERRCODE = 22105;
		END IF;		

		/*
		 * Validate that a netblock has a parent, unless
		 * it is the root of a hierarchy
		 */
		parent_nbid := netblock_utils.find_best_parent_id(
			realnew.ip_address, 
			masklen(realnew.ip_address),
			realnew.netblock_type,
			realnew.ip_universe_id,
			realnew.is_single_address
		);

		IF parent_nbid IS NOT NULL THEN
			SELECT * INTO nbrec FROM jazzhands.netblock WHERE netblock_id =
				parent_nbid;

			RAISE EXCEPTION 'Netblock % (%) has NULL parent; should be % (%)',
				realnew.netblock_id, realnew.ip_address, 
				parent_nbid, nbrec.ip_address USING ERRCODE = 22102;
		END IF;

		/*
		 * Validate that none of the other top-level netblocks should
		 * belong to this netblock
		 */
		PERFORM netblock_id FROM jazzhands.netblock WHERE 
			parent_netblock_id IS NULL AND
			netblock_id != NEW.netblock_id AND
			ip_address <<= NEW.ip_address;
		IF FOUND THEN
			RAISE EXCEPTION 'Other top-level netblocks should belong to this parent'
				USING ERRCODE = 22108;
		END IF;
	ELSE
	 	/*
		 * Reject a block that is self-referential
		 */
	 	IF realnew.parent_netblock_id = realnew.netblock_id THEN
			RAISE EXCEPTION 'Netblock may not have itself as a parent'
				USING ERRCODE = 22101;
		END IF;
		
		SELECT * INTO nbrec FROM jazzhands.netblock WHERE netblock_id = 
			realnew.parent_netblock_id;

		/*
		 * This shouldn't happen, but may because of deferred constraints
		 */
		IF NOT FOUND THEN
			RAISE EXCEPTION 'Parent netblock % does not exist',
			realnew.parent_netblock_id
			USING ERRCODE = 23503;
		END IF;

		IF nbrec.is_single_address = 'Y' THEN
			RAISE EXCEPTION 'Parent netblock % of single address % may not also be a single address',
			nbrec.netblock_id, realnew.ip_address
			USING ERRCODE = 22110;
		END IF;

		IF nbrec.ip_universe_id != realnew.ip_universe_id OR
				nbrec.netblock_type != realnew.netblock_type THEN
			RAISE EXCEPTION 'Netblock children must all be of the same type and universe as the parent'
			USING ERRCODE = 22109;
		END IF;

		IF nbtype.is_validated_hierarchy='N' THEN
			/*
			 * validated hierarchy addresses may not have the best parent as
			 * a parent, but if they have a parent, it should be a superblock
			 */

			IF NOT (realnew.ip_address << nbrec.ip_address OR
					cidr(realnew.ip_address) != nbrec.ip_address) THEN
				RAISE EXCEPTION 'Parent netblock % (%)  is not a valid parent for %',
					nbrec.ip_address, nbrec.netblock_id, realnew.ip_address
					USING ERRCODE = 22102;
			END IF;
		ELSE
			parent_nbid := netblock_utils.find_best_parent_id(
				realnew.ip_address, 
				masklen(realnew.ip_address),
				realnew.netblock_type,
				realnew.ip_universe_id,
				realnew.is_single_address
				);

			IF realnew.can_subnet = 'N' THEN
				PERFORM netblock_id FROM jazzhands.netblock WHERE
					parent_netblock_id = realnew.netblock_id AND
					is_single_address = 'N';
				IF FOUND THEN
					RAISE EXCEPTION 'A non-subnettable netblock (%) may not have child network netblocks',
					realnew.netblock_id
					USING ERRCODE = 22111;
				END IF;
			END IF;
			IF realnew.is_single_address = 'Y' THEN 
				SELECT ip_address INTO ipaddr FROM jazzhands.netblock
					WHERE netblock_id = realnew.parent_netblock_id;
				IF (masklen(realnew.ip_address) != masklen(ipaddr)) THEN
					RAISE 'Parent netblock % does not have same netmask as single address child % (% vs %)',
						parent_nbid, realnew.netblock_id, masklen(ipaddr),
						masklen(realnew.ip_address)
						USING ERRCODE = 22105;
				END IF;
			END IF;
			IF (parent_nbid IS NULL OR realnew.parent_netblock_id != parent_nbid) THEN
				SELECT ip_address INTO parent_ipaddr FROM jazzhands.netblock
				WHERE
					netblock_id = parent_nbid;
				SELECT ip_address INTO ipaddr FROM jazzhands.netblock WHERE
					netblock_id = realnew.parent_netblock_id;

				RAISE EXCEPTION 
					'Parent netblock % (%) for netblock % (%) is not the correct parent (should be % (%))',
					realnew.parent_netblock_id, ipaddr,
					realnew.netblock_id, realnew.ip_address,
					parent_nbid, parent_ipaddr
					USING ERRCODE = 22102;
			END IF;
			/*
			 * Validate that all children are is_single_address='Y' or
			 * all children are is_single_address='N'
			 */
			SELECT count(*) INTO single_count FROM jazzhands.netblock WHERE
				is_single_address='Y' and parent_netblock_id = 
				realnew.parent_netblock_id;
			SELECT count(*) INTO nonsingle_count FROM jazzhands.netblock WHERE
				is_single_address='N' and parent_netblock_id =
				realnew.parent_netblock_id;

			IF (single_count > 0 and nonsingle_count > 0) THEN
				SELECT * INTO nbrec FROM jazzhands.netblock WHERE netblock_id =
					realnew.parent_netblock_id;
				RAISE EXCEPTION 'Netblock % (%) may not have direct children for both single and multiple addresses simultaneously',
					nbrec.netblock_id, nbrec.ip_address
					USING ERRCODE = 22107;
			END IF;
			/*
			 *  If we're updating and we changed our ip_address (including
			 *  netmask bits), then check that our children still belong to
			 *  us
			 */
			 IF (TG_OP = 'UPDATE' AND NEW.ip_address != OLD.ip_address) THEN
				PERFORM netblock_id FROM jazzhands.netblock WHERE 
					parent_netblock_id = realnew.netblock_id AND
					((is_single_address = 'Y' AND NEW.ip_address != 
						ip_address::cidr) OR
					(is_single_address = 'N' AND realnew.netblock_id !=
						netblock_utils.find_best_parent_id(netblock_id)));
				IF FOUND THEN
					RAISE EXCEPTION 'Update for netblock % (%) causes parent to have children that do not belong to it',
						realnew.netblock_id, realnew.ip_address
						USING ERRCODE = 22112;
				END IF;
			END IF;

			/*
			 * Validate that none of the children of the parent netblock are
			 * children of this netblock (e.g. if inserting into the middle
			 * of the hierarchy)
			 */
			IF (realnew.is_single_address = 'N') THEN
				PERFORM netblock_id FROM jazzhands.netblock WHERE 
					parent_netblock_id = realnew.parent_netblock_id AND
					netblock_id != realnew.netblock_id AND
					ip_address <<= realnew.ip_address;
				IF FOUND THEN
					RAISE EXCEPTION 'Other netblocks have children that should belong to parent % (%)',
						realnew.parent_netblock_id, realnew.ip_address
						USING ERRCODE = 22108;
				END IF;
			END IF;
		END IF;
	END IF;

	RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
 * NOTE: care needs to be taken to make this trigger name come
 * lexicographically last, since it needs to check what happened in the
 * other triggers
 */

DROP TRIGGER IF EXISTS trigger_validate_netblock_parentage ON jazzhands.netblock;
CREATE CONSTRAINT TRIGGER trigger_validate_netblock_parentage 
	AFTER INSERT OR UPDATE ON jazzhands.netblock DEFERRABLE INITIALLY DEFERRED
	FOR EACH ROW EXECUTE PROCEDURE jazzhands.validate_netblock_parentage();

--- END netblock triggers

--- START netblock triggers

--- views

-- Copyright (c) 2011, Todd M. Kover
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
--
-- $Id: create_v_acct_coll_account_expanded.sql 60 2011-10-03 09:11:29Z kovert $
--

CREATE OR REPLACE VIEW v_person_company_expanded AS
WITH RECURSIVE var_recurse (
	level,
	root_company_id,
	company_id,
	person_id
) as (
	SELECT	
		0				as level,
		c.company_id			as root_company_id,
		c.company_id			as company_id,
		pc.person_id			as person_id
	  FROM	company c
		inner join person_company pc
			on c.company_id = pc.company_id
UNION ALL
	SELECT	
		x.level + 1			as level,
		x.company_id			as root_company_id,
		c.company_id			as company_id,
		pc.person_id			as person_id
	  FROM	var_recurse x
		inner join company c
			on c.parent_company_id = x.company_id
		inner join person_company pc
			on c.company_id = pc.company_id
) SELECT	distinct root_company_id as company_id, person_id
  from 		var_recurse;



-- START ../ddl/views/pgsql/create_v_site_netblock_expanded.sql

-- Copyright (c) 2005-2010, Vonage Holdings Corp.
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--     * Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--     * Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
-- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
-- $Id$
--

-- This view shows the site code for each entry in the netblock table
-- even when it's one of the ancestor netblocks that has the
-- site_netblock assignments

CREATE OR REPLACE VIEW v_site_netblock_expanded AS
WITH RECURSIVE parent_netblock AS (
  SELECT n.netblock_id, n.parent_netblock_id, n.ip_address, sn.site_code
  FROM netblock n LEFT JOIN site_netblock sn on n.netblock_id = sn.netblock_id
  WHERE n.parent_netblock_id IS NULL
  UNION
  SELECT n.netblock_id, n.parent_netblock_id, n.ip_address,
    coalesce(sn.site_code, p.site_code)
  FROM netblock n JOIN parent_netblock p ON n.parent_netblock_id = p.netblock_id
  LEFT JOIN site_netblock sn ON n.netblock_id = sn.netblock_id
)
SELECT site_code, netblock_id FROM parent_netblock;
-- END ../ddl/views/pgsql/create_v_site_netblock_expanded.sql



--- random fixes

DROP TRIGGER trigger_fix_person_image_oid_ownership on person_image;
CREATE TRIGGER trigger_fix_person_image_oid_ownership BEFORE INSERT ON person_image FOR EACH ROW EXECUTE PROCEDURE fix_person_image_oid_ownership();

DROP TRIGGER IF EXISTS trigger_propagate_person_status_to_account
        ON person_company;
CREATE TRIGGER trigger_propagate_person_status_to_account
AFTER UPDATE ON person_company
        FOR EACH ROW EXECUTE PROCEDURE propagate_person_status_to_account();


-- from ../pkg/pgsql/person_manip.sql
CREATE OR REPLACE FUNCTION person_manip.update_department( department varchar, _account_id integer, old_account_collection_id integer) 
	RETURNS INTEGER AS $$
DECLARE
	_account_collection_id INTEGER;
BEGIN
	_account_collection_id = person_manip.get_account_collection_id( department, 'department' ); 
	IF old_account_collection_id IS NULL THEN
		INSERT INTO account_collection_account (account_id, account_collection_id) VALUES (_account_id, _account_collection_id);
	ELSE
		--RAISE NOTICE 'updating account_collection_account with id % for account %', _account_collection_id, _account_id;
		UPDATE account_collection_account SET account_collection_id = _account_collection_id WHERE account_id = _account_id AND account_collection_id=old_account_collection_id;
	END IF;
	RETURN _account_collection_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


grant insert,update,delete on all tables in schema jazzhands to iud_role;
grant select,update on all sequences in schema public to iud_role;

grant select on all tables in schema audit to ro_role;
grant select on all tables in schema jazzhands to ro_role;
grant execute on all functions in schema net_manip to ro_role;
grant execute on all functions in schema netblock_utils to ro_role;


