
--------------------------------------------------------------------
-- DEALING WITH x509 certificates
create sequence x509_ca_cert_serial_number_seq;

alter table x509_certificate alter column x509_ca_cert_serial_number type numeric;
alter table audit.x509_certificate alter column x509_ca_cert_serial_number type numeric;

-- DONE DEALING WITH x509 certificates
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE network_interface

alter table network_interface alter column netblock_id drop not null;

-- DONE DEALING WITH TABLE dhcp_range [363284]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE dhcp_range [380836]

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
alter table dhcp_range drop constraint fk_dhcprng_netint_id;
alter table dhcp_range drop constraint fk_dhcprangestop_netblock;
alter table dhcp_range drop constraint fk_dhcprangestart_netblock;
alter table dhcp_range drop constraint pk_dhcprange;
-- INDEXES
DROP INDEX idx_dhcprng_startnetblk;
DROP INDEX idx_dhcprng_stopnetblk;
DROP INDEX idx_dhcprng_netint;
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
drop trigger trigger_audit_dhcp_range on dhcp_range;
drop trigger trig_userlog_dhcp_range on dhcp_range;

ALTER TABLE dhcp_range RENAME TO dhcp_range_v53;
ALTER TABLE audit.dhcp_range RENAME TO dhcp_range_v53;

CREATE TABLE network_range
(
	network_range_id	integer NOT NULL,
	description	varchar(4000)  NULL,
	start_netblock_id	integer NOT NULL,
	stop_netblock_id	integer NOT NULL,
	dns_prefix	varchar(255)  NULL,
	dns_domain_id	integer NOT NULL,
	lease_time	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);

ALTER SEQUENCE audit.dhcp_range_seq RENAME TO network_range_seq;
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'network_range', false);
INSERT INTO network_range (
	network_range_id,		-- new column (network_range_id)
	description,		-- new column (description)
	start_netblock_id,
	stop_netblock_id,
	dns_prefix,		-- new column (dns_prefix)
	dns_domain_id,
	lease_time,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	dhcp.dhcp_range_id,	-- new column (network_range_id)
	NULL,		-- new column (description)
	dhcp.start_netblock_id,
	dhcp.stop_netblock_id,
	NULL,		-- new column (dns_prefix)
	dns.dns_domain_id,
	dhcp.lease_time,
	dhcp.data_ins_user,
	dhcp.data_ins_date,
	dhcp.data_upd_user,
	dhcp.data_upd_date
FROM dhcp_range_v53 dhcp
	LEFT JOIN NETWORK_INTERFACE USING (network_interface_id)
	LEFT JOIN DNS_RECORD dns USING (NETBLOCK_ID)
WHERE
	dns.should_Generate_ptr = 'Y'
;
	

INSERT INTO audit.network_range (
	network_range_id,		-- new column (network_range_id)
	description,		-- new column (description)
	start_netblock_id,
	stop_netblock_id,
	dns_prefix,		-- new column (dns_prefix)
	dns_domain_id,
	lease_time,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	dhcp.dhcp_range_id,		-- new column (network_range_id)
	NULL,		-- new column (description)
	dhcp.start_netblock_id,
	dhcp.stop_netblock_id,
	NULL,		-- new column (dns_prefix)
	dns.dns_domain_id,
	dhcp.lease_time,
	dhcp.data_ins_user,
	dhcp.data_ins_date,
	dhcp.data_upd_user,
	dhcp.data_upd_date,
	dhcp."aud#action",
	dhcp."aud#timestamp",
	dhcp."aud#user",
	dhcp."aud#seq"
FROM audit.dhcp_range_v53 dhcp
	LEFT JOIN NETWORK_INTERFACE USING (network_interface_id)
	LEFT JOIN DNS_RECORD dns USING (NETBLOCK_ID)
WHERE
	dns.should_Generate_ptr = 'Y'
;

ALTER SEQUENCE dhcp_range_dhcp_range_id_seq
        RENAME TO network_range_network_range_id_seq;

ALTER TABLE network_range
        ALTER network_range_id
        SET DEFAULT nextval('network_range_network_range_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE network_range ADD CONSTRAINT pk_network_range PRIMARY KEY (network_range_id);
-- INDEXES
CREATE INDEX idx_netrng_stopnetblk ON network_range USING btree (stop_netblock_id);
CREATE INDEX idx_netrng_dnsdomainid ON network_range USING btree (dns_domain_id);
CREATE INDEX idx_netrng_startnetblk ON network_range USING btree (start_netblock_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE network_range
	ADD CONSTRAINT fk_net_range_stop_netblock
	FOREIGN KEY (stop_netblock_id) REFERENCES netblock(netblock_id);
ALTER TABLE network_range
	ADD CONSTRAINT fk_net_range_dns_domain_id
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);
ALTER TABLE network_range
	ADD CONSTRAINT fk_net_range_start_netblock
	FOREIGN KEY (start_netblock_id) REFERENCES netblock(netblock_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'network_range');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'network_range');
ALTER SEQUENCE network_range_network_range_id_seq
         OWNED BY network_range.network_range_id;
DROP TABLE dhcp_range_v53;
DROP TABLE audit.dhcp_range_v53;
GRANT ALL ON network_range TO jazzhands;
GRANT SELECT ON network_range TO ro_role;
GRANT INSERT,UPDATE,DELETE ON network_range TO iud_role;

drop function IF EXISTS perform_audit_dhcp_range();

-- DONE DEALING WITH TABLE network_range [385227]
--------------------------------------------------------------------


GRANT select on all tables in schema jazzhands to ro_role;
GRANT insert,update,delete on all tables in schema jazzhands to iud_role;
GRANT select on all sequences in schema jazzhands to ro_role;
GRANT usage on all sequences in schema jazzhands to iud_role;

