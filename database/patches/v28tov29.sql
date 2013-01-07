-- NOTE:  Running these first instructions may require grants on the jazzhands
-- database or changing the owner to jazzhands
--
-- migrate schema from public to jazzhands;

ALTER SCHEMA public RENAME TO jazzhands;
CREATE SCHEMA public;
ALTER USER jazzhands SET search_path = jazzhands;
set search_path = jazzhands;
-- 
comment on schema jazzhands is null;


-- reload this to get new public schemas
-- BEGIN ../ddl/schema/pgsql/create_schema_support.sql

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
			table_schema = 'jazzhands' AND
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
			table_schema = 'jazzhands' AND
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
				table_schema = 'jazzhands' AND
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
-- END ../ddl/schema/pgsql/create_schema_support.sql


-- need to autogenerate, done by hand now
create sequence ip_universe_ip_universe_id_seq;

drop view v_netblock_hier;
drop view v_person_company_expanded;
drop view v_department_company_expanded;
drop view v_dev_col_user_prop_expanded;
drop view v_acct_coll_acct_expanded_detail;

CREATE TABLE ip_universe
(
	ip_universe_id	integer NOT NULL,
	ip_universe_name	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('ip_universe', true);
ALTER TABLE ip_universe
	ALTER ip_universe_id
	SET DEFAULT nextval('ip_universe_ip_universe_id_seq'::regclass);
ALTER SEQUENCE ip_universe_ip_universe_id_seq
	 OWNED BY ip_universe.ip_universe_id;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE ip_universe ADD CONSTRAINT pk_ip_universe PRIMARY KEY (ip_universe_id);
ALTER TABLE ONLY ip_universe
	ADD CONSTRAINT ak_ip_universe_name UNIQUE (ip_universe_name);
-- INDEXES


-- CHECK CONSTRAINTS

-- Not there yet...
-- FOREIGN KEYS FROM
-- ALTER TABLE netblock
--	ADD CONSTRAINT fk_nblk_ip_universe_id
--	FOREIGN KEY (ip_universe_id) REFERENCES ip_universe(ip_universe_id) ON DELETE SET NULL;

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('ip_universe');
SELECT schema_support.rebuild_audit_trigger('ip_universe');
CREATE TABLE val_netblock_type
(
	netblock_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	db_forced_hierarchy	character(1) NOT NULL,
	is_validated_hierarchy	character(1) NOT NULL,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('val_netblock_type', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_netblock_type ADD CONSTRAINT pk_val_netblock_type PRIMARY KEY (netblock_type);
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE val_netblock_type ADD CONSTRAINT check_yes_no_1459364629
	CHECK (is_validated_hierarchy = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE val_netblock_type ADD CONSTRAINT check_yes_no_1634617190
	CHECK (db_forced_hierarchy = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- not there yet...
-- FOREIGN KEYS FROM
-- ALTER TABLE netblock
--	ADD CONSTRAINT fk_netblock_nblk_typ
--	FOREIGN KEY (netblock_type) REFERENCES val_netblock_type(netblock_type) ON DELETE SET NULL;

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('val_netblock_type');
SELECT schema_support.rebuild_audit_trigger('val_netblock_type');

-- insert default values that are now in initialize_jazzhands.sql
INSERT INTO ip_universe (
        ip_universe_id, ip_universe_name, description
) VALUES (
        0, 'default', 'default IP universe'
);

INSERT INTO val_netblock_type(
        netblock_type, description, db_forced_hierarchy, is_validated_hierarchy
) VALUES (
        'default', 'standard hierarchical netblock type', 'Y', 'Y'
);

INSERT INTO val_netblock_type(
        netblock_type, description, db_forced_hierarchy, is_validated_hierarchy
) VALUES (
	'adhoc', 'standard non-hierarchical netblock type', 'Y', 'Y'
);

INSERT INTO val_netblock_type(
	netblock_type, description, db_forced_hierarchy, is_validated_hierarchy
) VALUES (
	'dns', 'organizational groupings used for assigning DNS in-addr records', 'N', 'Y'
);



-- DEALING WITH TABLE netblock [185498]

-- FOREIGN KEYS FROM
alter table site_netblock drop constraint fk_site_netblock_ref_netblock;
alter table secondary_netblock drop constraint fk_secnblk_nblk_id;
alter table network_interface drop constraint fk_netint_netblk_v6id;
alter table network_interface drop constraint fk_netint_netblk_v4id;
alter table static_route_template drop constraint fk_netblock_st_rt_dst_net;
alter table netblock_collection_netblock drop constraint fk_nblk_col_nblk_nblkid;
alter table static_route drop constraint fk_statrt_nblk_id;
alter table dhcp_range drop constraint fk_dhcprangestart_netblock;
alter table dhcp_range drop constraint fk_dhcprangestop_netblock;
alter table dns_record drop constraint fk_dnsid_nblk_id;
alter table static_route_template drop constraint fk_netblock_st_rt_src_net;

-- FOREIGN KEYS TO
alter table netblock drop constraint fk_netblock_company;
alter table netblock drop constraint fk_netblock_v_netblock_stat;
alter table netblock drop constraint fk_netblk_netblk_parid;
alter table netblock drop constraint pk_netblock;
-- INDEXES
DROP INDEX ix_netblk_ip_address;
DROP INDEX xif5netblock;
DROP INDEX ix_netblk_ip_address_parent;
DROP INDEX idx_netblk_netblkstatus;
-- CHECK CONSTRAINTS, etc
alter table netblock drop constraint ckc_is_single_address_netblock;
alter table netblock drop constraint check_yes_no_172122967;
alter table netblock drop constraint ckc_is_organizational_netblock;
alter table netblock drop constraint ckc_is_ipv4_address_netblock;
-- TRIGGERS, etc
drop trigger trigger_validate_netblock on netblock;
drop trigger trig_userlog_netblock on netblock;
drop trigger trigger_validate_netblock_parentage on netblock;
drop trigger trigger_audit_netblock on netblock;


ALTER TABLE netblock RENAME TO netblock_v28;
ALTER TABLE audit.netblock RENAME TO netblock_v28;

CREATE TABLE netblock
(
	netblock_id	integer NOT NULL,
	ip_address	inet NOT NULL,
	netmask_bits	integer NOT NULL,
	netblock_type	varchar(50)  NOT NULL,
	is_ipv4_address	character(1) NOT NULL,
	is_single_address	character(1) NOT NULL,
	can_subnet	character(1) NOT NULL,
	parent_netblock_id	integer  NULL,
	netblock_status	varchar(50) NOT NULL,
	nic_id	varchar(255)  NULL,
	nic_company_id	integer  NULL,
	ip_universe_id	integer  NOT NULL,
	description	varchar(255)  NULL,
	reservation_ticket_number	varchar(255)  NULL,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('netblock', false);
INSERT INTO netblock (
	netblock_id,
	ip_address,
	netmask_bits,
	netblock_type,
	is_ipv4_address,
	is_single_address,
	can_subnet,
	parent_netblock_id,
	netblock_status,
	nic_id,
	nic_company_id,
	ip_universe_id,
	description,
	reservation_ticket_number,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT		netblock_id,
	ip_address,
	netmask_bits,
	case WHEN is_organizational = 'Y' 
		THEN 'default-adhoc' 
		ELSE 'default' END,
	is_ipv4_address,
	is_single_address,
	can_subnet,
	parent_netblock_id,
	netblock_status,
	nic_id,
	nic_company_id,
	0,
	description,
	reservation_ticket_number,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM netblock_v28;

INSERT INTO audit.netblock (
	netblock_id,
	ip_address,
	netmask_bits,
	netblock_type,
	is_ipv4_address,
	is_single_address,
	can_subnet,
	parent_netblock_id,
	netblock_status,
	nic_id,
	nic_company_id,
	ip_universe_id,
	description,
	reservation_ticket_number,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT		netblock_id,
	ip_address,
	netmask_bits,
	case WHEN is_organizational = 'Y' 
		THEN 'default-adhoc' 
		ELSE 'default' END,
	is_ipv4_address,
	is_single_address,
	can_subnet,
	parent_netblock_id,
	netblock_status,
	nic_id,
	nic_company_id,
	0,
	description,
	reservation_ticket_number,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.netblock_v28;

ALTER TABLE netblock
	ALTER netblock_id
	SET DEFAULT nextval('netblock_netblock_id_seq'::regclass);

ALTER TABLE netblock
	ALTER ip_universe_id
	SET DEFAULT 0;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE netblock ADD CONSTRAINT pk_netblock PRIMARY KEY (netblock_id);
-- INDEXES
CREATE INDEX ix_netblk_ip_address ON netblock USING btree (ip_address);
CREATE INDEX xif7netblock ON netblock USING btree (netblock_type);
CREATE INDEX xif5netblock ON netblock USING btree (nic_company_id);
CREATE INDEX ix_netblk_ip_address_parent ON netblock USING btree (parent_netblock_id);
CREATE INDEX xif6netblock ON netblock USING btree (ip_universe_id);
CREATE INDEX idx_netblk_netblkstatus ON netblock USING btree (netblock_status);

-- CHECK CONSTRAINTS
ALTER TABLE netblock ADD CONSTRAINT ckc_is_single_address_netblock
	CHECK ((is_single_address IS NULL) OR ((is_single_address = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_single_address)::text = upper((is_single_address)::text))));
ALTER TABLE netblock ADD CONSTRAINT check_yes_no_172122967
	CHECK (can_subnet = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE netblock ADD CONSTRAINT ckc_is_ipv4_address_netblock
	CHECK ((is_ipv4_address IS NULL) OR ((is_ipv4_address = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_ipv4_address)::text = upper((is_ipv4_address)::text))));

-- FOREIGN KEYS FROM
ALTER TABLE site_netblock
	ADD CONSTRAINT fk_site_netblock_ref_netblock
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
ALTER TABLE secondary_netblock
	ADD CONSTRAINT fk_secnblk_nblk_id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_netblk_v6id
	FOREIGN KEY (v6_netblock_id) REFERENCES netblock(netblock_id);
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_netblk_v4id
	FOREIGN KEY (v4_netblock_id) REFERENCES netblock(netblock_id);
ALTER TABLE static_route_template
	ADD CONSTRAINT fk_netblock_st_rt_dst_net
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
ALTER TABLE netblock_collection_netblock
	ADD CONSTRAINT fk_nblk_col_nblk_nblkid
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
ALTER TABLE static_route
	ADD CONSTRAINT fk_statrt_nblk_id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
ALTER TABLE dhcp_range
	ADD CONSTRAINT fk_dhcprangestart_netblock
	FOREIGN KEY (start_netblock_id) REFERENCES netblock(netblock_id);
ALTER TABLE dhcp_range
	ADD CONSTRAINT fk_dhcprangestop_netblock
	FOREIGN KEY (stop_netblock_id) REFERENCES netblock(netblock_id);
ALTER TABLE dns_record
	ADD CONSTRAINT fk_dnsid_nblk_id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
ALTER TABLE static_route_template
	ADD CONSTRAINT fk_netblock_st_rt_src_net
	FOREIGN KEY (netblock_src_id) REFERENCES netblock(netblock_id);

-- FOREIGN KEYS TO
ALTER TABLE netblock
	ADD CONSTRAINT fk_netblock_nblk_typ
	FOREIGN KEY (netblock_type) REFERENCES val_netblock_type(netblock_type) ON DELETE SET NULL;
ALTER TABLE netblock
	ADD CONSTRAINT fk_netblock_company
	FOREIGN KEY (nic_company_id) REFERENCES company(company_id) ON DELETE SET NULL;
ALTER TABLE netblock
	ADD CONSTRAINT fk_netblock_v_netblock_stat
	FOREIGN KEY (netblock_status) REFERENCES val_netblock_status(netblock_status);
ALTER TABLE netblock
	ADD CONSTRAINT fk_nblk_ip_universe_id
	FOREIGN KEY (ip_universe_id) REFERENCES ip_universe(ip_universe_id) ON DELETE SET NULL;
ALTER TABLE netblock
	ADD CONSTRAINT fk_netblk_netblk_parid
	FOREIGN KEY (parent_netblock_id) REFERENCES netblock(netblock_id);

-- TRIGGERS
-- this just inserted straight from 
-- ../ddl/schema/pgsql/create_netblock_triggers.sql
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

CREATE OR REPLACE FUNCTION validate_netblock() RETURNS TRIGGER AS $$
BEGIN
	/*
	 * Force netmask_bits to be authoritative
	 */

	IF NEW.netmask_bits IS NULL THEN
		RAISE EXCEPTION 'Column netmask_bits may not be null'
			USING ERRCODE = 'not_null_violation';
	ELSE
		NEW.ip_address = set_masklen(NEW.ip_address, NEW.netmask_bits);
	END IF;

	IF NEW.can_subnet = 'Y' AND NEW.is_single_address = 'Y' THEN
		RAISE EXCEPTION 'Single addresses may not be subnettable'
			USING ERRCODE = 22106;
	END IF;

	IF NEW.is_single_address = 'N' AND (NEW.ip_address != cidr(NEW.ip_address))
			THEN
		RAISE EXCEPTION
			'Non-network bits must be zero if is_single_address is N'
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
			   FROM netblock 
			  WHERE ip_address = new.ip_address AND
					ip_universe_id = new.ip_universe_id AND
					netblock_type = new.netblock_type;
			IF (TG_OP = 'INSERT' AND FOUND) THEN 
				RAISE EXCEPTION 'Unique Constraint Violated on IP Address: %', 
					new.ip_address
					USING ERRCODE= 'unique_violation';
			END IF;
			IF (TG_OP = 'UPDATE') THEN
				IF (NEW.ip_address != OLD.ip_address AND FOUND) THEN
					RAISE EXCEPTION 
						'Unique Constraint Violated on IP Address: %', 
						new.ip_address
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

DROP TRIGGER IF EXISTS trigger_validate_netblock ON netblock;
CREATE TRIGGER trigger_validate_netblock BEFORE INSERT OR UPDATE ON netblock
	FOR EACH ROW EXECUTE PROCEDURE validate_netblock();

CREATE OR REPLACE FUNCTION manipulate_netblock_parentage_before() RETURNS TRIGGER AS $$

DECLARE
	nbtype				record;
	v_trigger			record;
	v_netblock_type		val_netblock_type.netblock_type%TYPE;
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
		
	SELECT * INTO nbtype FROM val_netblock_type WHERE 
		netblock_type = v_trigger.netblock_type;

	IF (NOT FOUND) OR nbtype.db_forced_hierarchy != 'Y' THEN
		RETURN v_trigger;
	END IF;

	/*
	 * Find the correct parent netblock if we're not deleting
	 */ 

	IF TG_OP != 'DELETE' THEN
		RAISE DEBUG 'Checking forced hierarchical netblock %', NEW.netblock_id;
		NEW.parent_netblock_id = netblock_utils.find_best_parent_id(
			NEW.ip_address,
			NEW.netmask_bits,
			NEW.netblock_type,
			NEW.ip_universe_id,
			NEW.is_single_address
			);

		RAISE DEBUG 'Setting parent for netblock % to %', NEW.netblock_id,
			NEW.parent_netblock_id;

		/*
		 * If we are an end-node, then we're done
		 */

		IF NEW.is_single_address = 'Y' THEN
			RETURN NEW;
		END IF;
	END IF;


	/*
	 * If we are deleting, attach all children to the parent and wipe
	 * hands on pants;
	 */
	IF TG_OP = 'DELETE' THEN
		RAISE DEBUG 'Setting parent for all child netblocks of deleted netblock % to %',
			OLD.netblock_id,
			OLD.parent_netblock_id;

		UPDATE 
			netblock 
		SET
			parent_netblock_id = OLD.parent_netblock_id
		WHERE
			parent_netblock_id = OLD.netblock_id;
		RETURN OLD;
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
			netblock
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
			netblock
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

DROP TRIGGER IF EXISTS trigger_manipulate_netblock_parentage ON netblock;
DROP TRIGGER IF EXISTS tb_manipulate_netblock_parentage ON netblock;

CREATE TRIGGER tb_manipulate_netblock_parentage
	BEFORE INSERT OR DELETE OR UPDATE OF
		ip_address, netmask_bits, netblock_type, ip_universe_id
	ON netblock
	FOR EACH ROW EXECUTE PROCEDURE manipulate_netblock_parentage_before();


CREATE OR REPLACE FUNCTION manipulate_netblock_parentage_after() RETURNS TRIGGER AS $$

DECLARE
	nbtype				record;
	v_netblock_type		val_netblock_type.netblock_type%TYPE;
BEGIN
	/*
	 * Get the parameters for the given netblock type to see if we need
	 * to do anything
	 */

	SELECT * INTO nbtype FROM val_netblock_type WHERE 
		netblock_type = NEW.netblock_type;

	IF (NOT FOUND) OR nbtype.db_forced_hierarchy != 'Y' THEN
		RETURN NULL;
	END IF;

	IF NEW.is_single_address = 'Y' THEN
		RETURN NULL;
	END IF;

	RAISE DEBUG 'Setting parent for all child netblocks of parent netblock % that belong to %',
		NEW.parent_netblock_id,
		NEW.netblock_id;
	UPDATE
		netblock
	SET
		parent_netblock_id = NEW.netblock_id
	WHERE
		parent_netblock_id = NEW.parent_netblock_id AND
		ip_address <<= NEW.ip_address AND
		netblock_id != NEW.netblock_id;

	RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS ta_manipulate_netblock_parentage ON netblock;

CREATE CONSTRAINT TRIGGER ta_manipulate_netblock_parentage
	AFTER INSERT ON netblock NOT DEFERRABLE
	FOR EACH ROW EXECUTE PROCEDURE manipulate_netblock_parentage_after();

CREATE OR REPLACE FUNCTION validate_netblock_parentage() RETURNS TRIGGER AS $$
DECLARE
	nbrec			record;
	realnew			record;
	nbtype			record;
	v_trigger		record;
	parent_nbid		netblock.netblock_id%type;
	ipaddr			inet;
	parent_ipaddr	inet;
	single_count	integer;
	nonsingle_count	integer;
	pip	    		netblock.ip_address%type;
BEGIN
	/*
	 * It's possible that due to delayed triggers that what is stored in
	 * NEW is not current, so fetch the current values
	 */
	
	IF TG_OP = 'DELETE' THEN
		v_trigger := OLD;
	ELSE
		v_trigger := NEW;
	END IF;
	
	RAISE DEBUG 'Validating  % of netblock %', TG_OP, v_trigger.netblock_id;

	SELECT * INTO nbtype FROM val_netblock_type WHERE 
		netblock_type = v_trigger.netblock_type;

	IF (NOT FOUND) THEN
		RETURN NULL;
	END IF;

	SELECT * INTO realnew FROM netblock WHERE netblock_id =
		v_trigger.netblock_id;
	
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
	PERFORM netblock_id FROM netblock WHERE
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
			RAISE 'A single address must be the child of a parent netblock'
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
			SELECT * INTO nbrec FROM netblock WHERE netblock_id =
				parent_nbid;

			RAISE EXCEPTION 'Netblock % (%) has NULL parent; should be % (%)',
				realnew.netblock_id, realnew.ip_address, 
				parent_nbid, nbrec.ip_address USING ERRCODE = 22102;
		END IF;
	ELSE
	 	/*
		 * Reject a block that is self-referential
		 */
	 	IF realnew.parent_netblock_id = realnew.netblock_id THEN
			RAISE EXCEPTION 'Netblock may not have itself as a parent'
				USING ERRCODE = 22101;
		END IF;
		
		SELECT * INTO nbrec FROM netblock WHERE netblock_id = 
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
			RAISE EXCEPTION 'Parent netblock may not be a single address'
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
				RAISE EXCEPTION 'Parent netblock is not a valid parent'
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
				PERFORM netblock_id FROM netblock WHERE
					parent_netblock_id = realnew.netblock_id AND
					is_single_address = 'N';
				IF FOUND THEN
					RAISE EXCEPTION 'A non-subnettable netblock may not have child network netblocks'
					USING ERRCODE = 22111;
				END IF;
			END IF;
			IF realnew.is_single_address = 'Y' THEN 
				SELECT ip_address INTO ipaddr FROM netblock
					WHERE netblock_id = realnew.parent_netblock_id;
				IF (masklen(realnew.ip_address) != masklen(ipaddr)) THEN
					RAISE 'Parent netblock % does not have same netmask as single address child % (% vs %)',
						parent_nbid, realnew.netblock_id, masklen(ipaddr),
						masklen(realnew.ip_address)
						USING ERRCODE = 22105;
				END IF;
			END IF;
			IF (parent_nbid IS NULL OR realnew.parent_netblock_id != parent_nbid) THEN
				SELECT ip_address INTO parent_ipaddr FROM netblock WHERE
					netblock_id = parent_nbid;
				SELECT ip_address INTO ipaddr FROM netblock WHERE
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
			SELECT count(*) INTO single_count FROM netblock WHERE
				is_single_address='Y' and parent_netblock_id = 
				realnew.parent_netblock_id;
			SELECT count(*) INTO nonsingle_count FROM netblock WHERE
				is_single_address='N' and parent_netblock_id =
				realnew.parent_netblock_id;

			IF (single_count > 0 and nonsingle_count > 0) THEN
				RAISE EXCEPTION 'Netblock may not have direct children for both single and multiple addresses simultaneously'
					USING ERRCODE = 22107;
			END IF;
			/*
			 *  If we're updating and we changed our ip_address (including
			 *  netmask bits), then check that our children still belong to
			 *  us
			 */
			 IF (TG_OP = 'UPDATE' AND NEW.ip_address != OLD.ip_address) THEN
				PERFORM netblock_id FROM netblock WHERE 
					parent_netblock_id = realnew.netblock_id AND
					((is_single_address = 'Y' AND NEW.ip_address != 
						ip_address::cidr) OR
					(is_single_address = 'N' AND realnew.netblock_id !=
						netblock_utils.find_best_parent_id(netblock_id)));
				IF FOUND THEN
					RAISE EXCEPTION 'Update causes parent to have children that do not belong to it'
						USING ERRCODE = 22112;
				END IF;
			END IF;


			/*
			 * Validate that none of the children of the parent netblock are
			 * children of this netblock (e.g. if inserting into the middle
			 * of the hierarchy)
			 */
			 PERFORM netblock_id FROM netblock WHERE 
				parent_netblock_id = realnew.parent_netblock_id AND
				netblock_id != realnew.netblock_id AND
				ip_address <<= realnew.ip_address;
			IF FOUND THEN
				RAISE EXCEPTION 'Other netblocks have children that should belong to this parent'
					USING ERRCODE = 22108;
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

DROP TRIGGER IF EXISTS trigger_validate_netblock_parentage ON netblock;
CREATE CONSTRAINT TRIGGER trigger_validate_netblock_parentage 
	AFTER INSERT OR UPDATE OR DELETE ON netblock DEFERRABLE INITIALLY DEFERRED
	FOR EACH ROW EXECUTE PROCEDURE validate_netblock_parentage();

-- END ../ddl/schema/pgsql/create_netblock_triggers.sql

SELECT schema_support.rebuild_stamp_trigger('netblock');
SELECT schema_support.rebuild_audit_trigger('netblock');
ALTER SEQUENCE netblock_netblock_id_seq
	 OWNED BY netblock.netblock_id;
DROP TABLE netblock_v28;
DROP TABLE audit.netblock_v28;
-- DEALING WITH TABLE company [284781]

-- FOREIGN KEYS FROM
alter table person_contact drop constraint fk_prsn_contect_cr_cmpyid;
alter table circuit drop constraint fk_circuit_aloc_companyid;
alter table account_realm_company drop constraint fk_acct_rlm_cmpy_cmpy_id;
alter table property drop constraint fk_property_pval_compid;
alter table site drop constraint fk_site_colo_company_id;
alter table company_type drop constraint fk_company_type_company_id;
alter table netblock drop constraint fk_netblock_company;
alter table property drop constraint fk_property_compid;
alter table circuit drop constraint fk_circuit_zloc_company_id;
alter table device_type drop constraint fk_devtyp_company;
alter table operating_system drop constraint fk_os_company;
alter table department drop constraint fk_dept_company;
alter table physical_address drop constraint fk_physaddr_company_id;
alter table circuit drop constraint fk_circuit_vend_companyid;
alter table person_company drop constraint fk_person_company_company_id;

-- FOREIGN KEYS TO
alter table company drop constraint fk_company_parent_company_id;
alter table company drop constraint pk_company;
-- INDEXES
DROP INDEX idx_company_iscorpfamily;
DROP INDEX idx_company_companycode;
DROP INDEX xif1company;
-- CHECK CONSTRAINTS, etc
alter table company drop constraint ckc_is_corporate_fami_company;
-- TRIGGERS, etc
drop trigger trigger_audit_company on company;
drop trigger trig_userlog_company on company;


ALTER TABLE company RENAME TO company_v28;
ALTER TABLE audit.company RENAME TO company_v28;

CREATE TABLE company
(
	company_id	integer NOT NULL,
	company_name	varchar(255) NOT NULL,
	company_short_name	varchar(50)  NULL,
	is_corporate_family	character(1) NOT NULL,
	parent_company_id	integer  NULL,
	description	varchar(4000)  NULL,
	company_code	varchar(10)  NULL,
	account_prefix	varchar(8)  NULL,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('company', false);
INSERT INTO company (
	company_id,
	company_name,
	company_short_name,
	is_corporate_family,
	parent_company_id,
	description,
	company_code,
	account_prefix,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT		company_id,
	company_name,
	NULL,
	is_corporate_family,
	parent_company_id,
	description,
	company_code,
	account_prefix,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM company_v28;

INSERT INTO audit.company (
	company_id,
	company_name,
	company_short_name,
	is_corporate_family,
	parent_company_id,
	description,
	company_code,
	account_prefix,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT		company_id,
	company_name,
	NULL,
	is_corporate_family,
	parent_company_id,
	description,
	company_code,
	account_prefix,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.company_v28;

ALTER TABLE company
	ALTER company_id
	SET DEFAULT nextval('company_company_id_seq'::regclass);
ALTER TABLE company
	ALTER is_corporate_family
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE company ADD CONSTRAINT pk_company PRIMARY KEY (company_id);
-- INDEXES
CREATE INDEX idx_company_iscorpfamily ON company USING btree (is_corporate_family);
CREATE INDEX idx_company_companycode ON company USING btree (company_code);
CREATE INDEX xif1company ON company USING btree (parent_company_id);

-- CHECK CONSTRAINTS
ALTER TABLE company ADD CONSTRAINT ckc_cmpy_shrt_name_195335815
	CHECK (((company_short_name)::text = lower((company_short_name)::text)) AND ((company_short_name)::text !~~ '% %'::text));
ALTER TABLE company ADD CONSTRAINT ckc_is_corporate_fami_company
	CHECK ((is_corporate_family = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_corporate_family)::text = upper((is_corporate_family)::text)));

-- FOREIGN KEYS FROM
ALTER TABLE person_contact
	ADD CONSTRAINT fk_prsn_contect_cr_cmpyid
	FOREIGN KEY (person_contact_cr_company_id) REFERENCES company(company_id) ON DELETE SET NULL;
ALTER TABLE circuit
	ADD CONSTRAINT fk_circuit_aloc_companyid
	FOREIGN KEY (aloc_lec_company_id) REFERENCES company(company_id) ON DELETE SET NULL;
ALTER TABLE account_realm_company
	ADD CONSTRAINT fk_acct_rlm_cmpy_cmpy_id
	FOREIGN KEY (company_id) REFERENCES company(company_id);
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_compid
	FOREIGN KEY (property_value_company_id) REFERENCES company(company_id) ON DELETE SET NULL;
ALTER TABLE site
	ADD CONSTRAINT fk_site_colo_company_id
	FOREIGN KEY (colo_company_id) REFERENCES company(company_id) ON DELETE SET NULL;
ALTER TABLE company_type
	ADD CONSTRAINT fk_company_type_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id);
ALTER TABLE netblock
	ADD CONSTRAINT fk_netblock_company
	FOREIGN KEY (nic_company_id) REFERENCES company(company_id) ON DELETE SET NULL;
ALTER TABLE property
	ADD CONSTRAINT fk_property_compid
	FOREIGN KEY (company_id) REFERENCES company(company_id);
ALTER TABLE circuit
	ADD CONSTRAINT fk_circuit_zloc_company_id
	FOREIGN KEY (zloc_lec_company_id) REFERENCES company(company_id) ON DELETE SET NULL;
ALTER TABLE device_type
	ADD CONSTRAINT fk_devtyp_company
	FOREIGN KEY (company_id) REFERENCES company(company_id) ON DELETE SET NULL;
ALTER TABLE operating_system
	ADD CONSTRAINT fk_os_company
	FOREIGN KEY (company_id) REFERENCES company(company_id) ON DELETE SET NULL;
ALTER TABLE department
	ADD CONSTRAINT fk_dept_company
	FOREIGN KEY (company_id) REFERENCES company(company_id);
ALTER TABLE physical_address
	ADD CONSTRAINT fk_physaddr_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id) ON DELETE SET NULL;
ALTER TABLE circuit
	ADD CONSTRAINT fk_circuit_vend_companyid
	FOREIGN KEY (vendor_company_id) REFERENCES company(company_id) ON DELETE SET NULL;
ALTER TABLE person_company
	ADD CONSTRAINT fk_person_company_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id);

-- FOREIGN KEYS TO
ALTER TABLE company
	ADD CONSTRAINT fk_company_parent_company_id
	FOREIGN KEY (parent_company_id) REFERENCES company(company_id) ON DELETE SET NULL;

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('company');
SELECT schema_support.rebuild_audit_trigger('company');
ALTER SEQUENCE company_company_id_seq
	 OWNED BY company.company_id;
DROP TABLE company_v28;
DROP TABLE audit.company_v28;

---------------------------
-- put back views that needed to be recreated
--


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
--
--
-- $Id$
--

-- was originally in netblock/index.pl from stab.  It originally had
-- 	connect by prior nb.netblock_id = parent_netblock_id
-- 	start with nb.parent_netblock_id = ?
-- 	order siblings by ip_address, netmask_bits
-- and this makes the root selection by including root_netblock_id.
-- This may break down the "everything can be represented by a view" because
-- the recursive table takes too long to build.

-- the postgresql query would have the restriction in the non recursive part
-- of the with query


CREATE OR REPLACE VIEW v_netblock_hier AS
WITH RECURSIVE var_recurse (
	netblock_level,
	root_netblock_id,
	ip,
	netblock_id,
	ip_address,
	netmask_bits,
	netblock_status,
	IS_SINGLE_ADDRESS,
	IS_IPV4_ADDRESS,
	description,
	parent_netblock_id,
	site_code
) as  (
	select  0			as netblock_level,
		nb.netblock_id		as root_netblock_id,
		net_manip.inet_dbtop(nb.ip_address) as ip,
		nb.netblock_id,
		nb.ip_address,
		nb.netmask_bits,
		nb.netblock_status,
		nb.IS_SINGLE_ADDRESS,
		nb.IS_IPV4_ADDRESS,
		nb.description,
		nb.parent_netblock_id,
		snb.site_code
	  from  netblock nb
		left join site_netblock snb
			on snb.netblock_id = nb.netblock_id
	where   nb.IS_SINGLE_ADDRESS = 'N'
UNION ALL
	SELECT	x.netblock_level +1	as netblock_level,
		x.root_netblock_id	as root_netblock_id,
		net_manip.inet_dbtop(nb.ip_address) as ip,
		nb.netblock_id,
		nb.ip_address,
		nb.netmask_bits,
		nb.netblock_status,
		nb.IS_SINGLE_ADDRESS,
		nb.IS_IPV4_ADDRESS,
		nb.description,
		nb.parent_netblock_id,
		snb.site_code
	  from  var_recurse x
	  	inner join netblock nb
			on x.netblock_id = nb.parent_netblock_id
		left join site_netblock snb
			on snb.netblock_id = nb.netblock_id
	where   nb.IS_SINGLE_ADDRESS = 'N'
) SELECT * from var_recurse;
;


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

CREATE OR REPLACE VIEW v_department_company_expanded AS
WITH RECURSIVE var_recurse (
	level,
	root_company_id,
	company_id,
	account_collection_id
) as (
	SELECT	
		0				as level,
		c.company_id			as root_company_id,
		c.company_id			as company_id,
		d.account_collection_id		as account_collection_id
	  FROM	company c
		inner join department d
			on c.company_id = d.company_id
UNION ALL
	SELECT	
		x.level + 1			as level,
		x.company_id			as root_company_id,
		c.company_id			as company_id,
		d.account_collection_id		as account_collection_id
	  FROM	var_recurse x
		inner join company c
			on c.parent_company_id = x.company_id
		inner join department d
			on c.company_id = d.company_id
) SELECT	distinct root_company_id as company_id, account_collection_id
  from 		var_recurse;


-- include ../pkg/pgsql/netblock_utils.sql
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

-- this just adds unnecessary complicates, m'kay...
-- drop schema if exists netblock_utils cascade;
-- create schema netblock_utils authorization jazzhands;

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

DROP FUNCTION IF EXISTS netblock_utils.find_best_parent_id(inet,integer);
CREATE OR REPLACE FUNCTION netblock_utils.find_best_parent_id(
	in_IpAddress netblock.ip_address%type,
	in_Netmask_Bits netblock.NETMASK_BITS%type,
	in_netblock_type netblock.netblock_type%type,
	in_ip_universe_id ip_universe.ip_universe_id%type,
	in_is_single_address netblock.is_single_address%type
) RETURNS netblock.netblock_id%type AS $$
DECLARE
	par_nbid	netblock.netblock_id%type;
BEGIN
	in_IpAddress := set_masklen(in_IpAddress, in_Netmask_Bits);
	select  Netblock_Id
	  into	par_nbid
	  from  ( select Netblock_Id, Ip_Address, Netmask_Bits
		    from netblock
		   where
		   	in_IpAddress <<= ip_address
		    and is_single_address = 'N'
			and netblock_type = in_netblock_type
			and ip_universe_id = in_ip_universe_id
		    and (
				(in_is_single_address = 'N' AND netmask_bits < in_Netmask_Bits)
				OR
				(in_is_single_address = 'Y' AND netmask_bits = in_Netmask_Bits)
			)
		order by netmask_bits desc
	) subq LIMIT 1;

	return par_nbid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION netblock_utils.find_best_parent_id(
	in_netblock_id netblock.netblock_id%type
) RETURNS netblock.netblock_id%type AS $$
DECLARE
	nbrec		RECORD;
BEGIN
	SELECT * INTO nbrec FROM netblock WHERE netblock_id = in_netblock_id;

	RETURN netblock_utils.find_best_parent_id(
		nbrec.ip_address,
		nbrec.netmask_bits,
		nbrec.netblock_type,
		nbrec.ip_universe_id,
		nbrec.is_single_address
	);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION netblock_utils.delete_netblock(
	in_netblock_id	netblock.netblock_id%type
) RETURNS VOID AS $$
DECLARE
	par_nbid	netblock.netblock_id%type;
BEGIN
	/*
	 * Update netblocks that use this as a parent to point to my parent
	 */
	SELECT
		netblock_id INTO par_nbid
	FROM
		netblock
	WHERE 
		netblock_id = in_netblock_id;
	
	UPDATE
		netblock
	SET
		parent_netblock_id = par_nbid
	WHERE
		parent_netblock_id = in_netblock_id;
	
	/*
	 * Now delete the record
	 */
	DELETE FROM netblock WHERE netblock_id = in_netblock_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS netblock_utils.recalculate_parentage(integer);
CREATE OR REPLACE FUNCTION netblock_utils.recalculate_parentage(
	in_netblock_id	netblock.netblock_id%type
) RETURNS INTEGER AS $$
DECLARE
	nbrec		RECORD;
	childrec	RECORD;
	nbid		netblock.netblock_id%type;
	ipaddr		inet;

BEGIN
	SELECT * INTO nbrec FROM netblock WHERE netblock_id = in_netblock_id;

	nbid := netblock_utils.find_best_parent_id(in_netblock_id);

	UPDATE netblock SET parent_netblock_id = nbid
		WHERE netblock_id = in_netblock_id;
	
	FOR childrec IN SELECT * FROM netblock WHERE parent_netblock_id = nbid
		AND netblock_id != in_netblock_id
	LOOP
		IF (childrec.ip_address <<= nbrec.ip_address) THEN
			UPDATE netblock SET parent_netblock_id = in_netblock_id
				WHERE netblock_id = childrec.netblock_id;
		END IF;
	END LOOP;
	RETURN nbid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION netblock_utils.find_rvs_zone_from_netblock_id(
	in_netblock_id	netblock.netblock_id%type
) RETURNS dns_domain.dns_domain_id%type AS $$
DECLARE
	v_rv	dns_domain.dns_domain_id%type;
	v_domid	dns_domain.dns_domain_id%type;
	v_lhsip	netblock.ip_address%type;
	v_rhsip	netblock.ip_address%type;
	nb_match CURSOR ( in_nb_id netblock.netblock_id%type) FOR
		-- The query used to include this in the where clause, but
		-- oracle was uber slow 
		--	net_manip.inet_base(nb.ip_address, root.netmask_bits) =  
		--		net_manip.inet_base(root.ip_address, root.netmask_bits) 
		select  rootd.dns_domain_id,
				 net_manip.inet_base(nb.ip_address, root.netmask_bits),
				 net_manip.inet_base(root.ip_address, root.netmask_bits)
		  from  netblock nb,
			netblock root
				inner join dns_record rootd
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
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- END ../pkg/pgsql/netblock_utils.sql

-- views that are no longer the same in prod for some reason, probably
-- because of postgres upgrades.  Reloading these to force consistency

-- BEGIN ../ddl/views/pgsql/create_v_acct_coll_acct_expanded_detail.sql
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

-- END ../ddl/views/pgsql/create_v_acct_coll_acct_expanded_detail.sql

-- BEGIN ../ddl/views/create_v_dev_col_user_prop_expanded.sql
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

-- This view maps users to device collections and lists properties
-- assigned to the users in order of their priorities.

CREATE OR REPLACE VIEW v_dev_col_user_prop_expanded AS
SELECT dchd.device_collection_id,
  s.account_id, s.login, s.account_status,
  upo.property_type property_type,
  upo.property_name property_name, 
  upo.property_value,
   CASE WHEN upn.is_multivalue = 'N' THEN 0
	ELSE 1 END is_multievalue,
  CASE WHEN pdt.property_data_type = 'boolean' THEN 1 ELSE 0 END is_boolean
FROM v_acct_coll_acct_expanded_detail uued
JOIN Account_Collection u ON uued.Account_Collection_id = u.Account_Collection_id
JOIN v_property upo ON upo.Account_Collection_id = u.Account_Collection_id
 AND upo.property_type in (
  'CCAForceCreation', 'CCARight', 'ConsoleACL', 'RADIUS', 'TokenMgmt',
  'UnixPasswdFileValue', 'UserMgmt', 'cca', 'feed-attributes',
  'proteus-tm', 'wwwgroup')
JOIN val_property upn
  ON upo.property_name = upn.property_name
 AND upo.property_type = upn.property_type
JOIN val_property_data_type pdt
  ON upn.property_data_type = pdt.property_data_type
LEFT JOIN v_device_coll_hier_detail dchd
  ON (dchd.parent_device_collection_id = upo.device_collection_id)
JOIN account s ON uued.account_id = s.account_id
ORDER BY device_collection_level,
   CASE WHEN u.Account_Collection_type = 'per-user' THEN 0
   	WHEN u.Account_Collection_type = 'property' THEN 1
   	WHEN u.Account_Collection_type = 'systems' THEN 2
	ELSE 3 END,
  CASE WHEN uued.assign_method = 'Account_CollectionAssignedToPerson' THEN 0
  	WHEN uued.assign_method = 'Account_CollectionAssignedToDept' THEN 1
  	WHEN uued.assign_method = 
	'ParentAccount_CollectionOfAccount_CollectionAssignedToPerson' THEN 2
  	WHEN uued.assign_method = 
	'ParentAccount_CollectionOfAccount_CollectionAssignedToDept' THEN 2
  	WHEN uued.assign_method = 
	'Account_CollectionAssignedToParentDept' THEN 3
  	WHEN uued.assign_method = 
	'ParentAccount_CollectionOfAccount_CollectionAssignedToParentDep' 
			THEN 3
        ELSE 6 END,
  uued.dept_level, uued.acct_coll_level, dchd.device_collection_id, 
  u.Account_Collection_id;
-- END ../ddl/views/create_v_dev_col_user_prop_expanded.sql

-- BEGIN ../ddl/views/create_v_l1_all_physical_ports.sql
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

-- This view is used to show all physical ports on a device and the ports
-- they are linked to, since this can go either way.

create or replace view v_l1_all_physical_ports as
select * from
(
select   
		l1.layer1_connection_Id,
		p1.physical_port_id 	as physical_port_id,
		p1.device_id		as device_id,
		p1.port_name		as port_name,
		p1.port_type		as port_type,
		p1.port_purpose		as port_purpose,
		p2.physical_port_id 	as other_physical_port_id,
		p2.device_id		as other_device_id,
		p2.port_name		as other_port_name,
		p2.port_purpose		as other_port_purpose,
		l1.baud,
		l1.data_bits,
		l1.stop_bits,
		l1.parity,
		l1.flow_control
	  from  physical_port p1
	    inner join layer1_connection l1
			on l1.physical_port1_id = p1.physical_port_id
	    inner join physical_port p2
			on l1.physical_port2_id = p2.physical_port_id
	 where  p1.port_type = p2.port_type
UNION
	 select
		l1.layer1_connection_Id,
		p1.physical_port_id 	as physical_port_id,
		p1.device_id		as device_id,
		p1.port_name		as port_name,
		p1.port_type		as port_type,
		p1.port_purpose		as port_purpose,
		p2.physical_port_id 	as other_physical_port_id,
		p2.device_id		as other_device_id,
		p2.port_name		as other_port_name,
		p2.port_purpose		as other_port_purpose,
		l1.baud,
		l1.data_bits,
		l1.stop_bits,
		l1.parity,
		l1.flow_control
	  from  physical_port p1
	    inner join layer1_connection l1
			on l1.physical_port2_id = p1.physical_port_id
	    inner join physical_port p2
			on l1.physical_port1_id = p2.physical_port_id
	 where  p1.port_type = p2.port_type
UNION
	 select
		NULL,
		p1.physical_port_id 	as physical_port_id,
		p1.device_id		as device_id,
		p1.port_name		as port_name,
		p1.port_type		as port_type,
		p1.port_purpose		as port_purpose,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL
	  from  physical_port p1
	left join layer1_connection l1
		on l1.physical_port1_id = P1.physical_port_id
		or l1.physical_port2_id = P1.physical_port_id
	     where  l1.layer1_connection_id is NULL
) subquery order by NETWORK_STRINGS.NUMERIC_INTERFACE(port_name);
-- END ../ddl/views/create_v_l1_all_physical_ports.sql

-- person_manip.add_person appears to have been redone in prod, so reloading
-- just for completeness
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
	OUT _person_id INTEGER,
	OUT _account_collection_id INTEGER,
	OUT _account_id INTEGER)
 AS $$
DECLARE
	_account_realm_id INTEGER;
BEGIN
	INSERT INTO person (first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
		VALUES (first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
		RETURNING person_id into _person_id;
	INSERT INTO person_company
		(person_id,company_id,external_hr_id,person_company_status,is_exempt,employee_id,hire_date,termination_date,person_company_relation, position_title)
		VALUES
		(_person_id, _company_id, external_hr_id, person_company_status, is_exempt, employee_id, hire_date, termination_date, person_company_relation, job_title);
	SELECT account_realm_id INTO _account_realm_id FROM account_realm_company WHERE company_id = _company_id;
	INSERT INTO person_account_realm_company ( person_id, company_id, account_realm_id) VALUES ( _person_id, _company_id, _account_realm_id);
	INSERT INTO account ( login, person_id, company_id, account_realm_id, account_status, account_role, account_type) 
		VALUES ( login, _person_id, _company_id, _account_realm_id, person_company_status, 'primary', 'person')
		RETURNING account_id INTO _account_id;
	IF department IS NULL THEN
		RETURN;
	END IF;
	_account_collection_id = person_manip.get_account_collection_id(department, 'department');
	INSERT INTO account_collection_account (account_collection_id, account_id) VALUES ( _account_collection_id, _account_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- prod patch, being folded in
drop function IF EXISTS person_manip.merge_accounts(integer, integer);
drop function IF EXISTS person_manip.merge_accounts(boolean, integer, integer);
CREATE OR REPLACE FUNCTION person_manip.merge_accounts(
	allow_external_hr_id_in_dest_account BOOLEAN,
	merge_from_account_id	account.account_Id%TYPE,
	merge_to_account_id	account.account_Id%TYPE
) RETURNS INTEGER AS $$
DECLARE
	fpc		person_company%ROWTYPE;
	tpc		person_company%ROWTYPE;
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

	IF(tpc.external_hr_id is NOT NULL AND NOT allow_external_hr_id_in_dest_account) THEN
		RAISE EXCEPTION 'Destination account has an external HR ID';
	END IF;

	-- Switch the HR ID
	UPDATE PERSON_COMPANY
	  SET  EXTERNAL_HR_ID = NULL
	WHERE	PERSON_ID = fpc.person_id
	  AND	COMPANY_ID = fpc.company_id;

	UPDATE PERSON_COMPANY
	  SET  EXTERNAL_HR_ID = fpc.external_hr_id
	WHERE	PERSON_ID = tpc.person_id
	  AND	COMPANY_ID = tpc.company_id;

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

	update person_contact set person_id = tpc.person_id where person_id = fpc.person_id;
	update person_image set person_id = tpc.person_id where person_id = fpc.person_id;
	update person_vehicle set person_id = tpc.person_id where person_id = fpc.person_id;
	update property set person_id = tpc.person_id where person_id = fpc.person_id;
	delete from person_account_realm_company where person_id = fpc.person_id AND company_id = fpc.company_id;
	delete from person_company where person_id = fpc.person_id AND company_id = fpc.company_id;
	-- if there are other relations that may exist, do not delete the person.
	BEGIN
		delete from person where person_id = fpc.person_id;
	EXCEPTION WHEN foreign_key_violation THEN
		NULL;
	END;
	return merge_to_account_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- BEGIN: ../pkg/pgsql/net_manip.sql
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
/*
 * $Id$
 */

-- DROP SCHEMA IF EXISTS net_manip CASCADE;
-- CREATE SCHEMA net_manip AUTHORIZATION jazzhands;

-------------------------------------------------------------------
-- returns the Id tag for CM
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION net_manip.id_tag()
RETURNS VARCHAR AS $$
BEGIN
	RETURN('<-- $Id -->');
END;
$$ LANGUAGE plpgsql;
-- end of procedure id_tag
-------------------------------------------------------------------

-------------------------------------------------------------------
-- returns its first argument (noop under postgresql)
-------------------------------------------------------------------

CREATE OR REPLACE FUNCTION net_manip.inet_ptodb
(
	p_ip_address			in inet
)
RETURNS inet AS $$
BEGIN
	return(p_ip_address);
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION net_manip.inet_ptodb(inet, integer);
CREATE OR REPLACE FUNCTION net_manip.inet_ptodb
(
	p_ip_address			in inet,
	p_netmask_bits			in integer
)
RETURNS inet AS $$
BEGIN
	return(set_masklen(p_ip_address, p_netmask_bits));
END;
$$ LANGUAGE plpgsql;

-- end of net_manip.inet_ptodb
-------------------------------------------------------------------

-------------------------------------------------------------------
-- returns its first argument (noop under postgresql)
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION net_manip.inet_dbtop
(
	p_ip_address			in inet
)
RETURNS inet AS $$
BEGIN
	return( host(p_ip_address) );
END;
$$ LANGUAGE plpgsql;
-- end of net_manip.inet_dbtop
-------------------------------------------------------------------

CREATE OR REPLACE FUNCTION net_manip.inet_bits_to_mask
	(
	p_bits				in integer
	)
RETURNS inet AS $$
BEGIN
	IF p_bits > 32 OR p_bits < 0 THEN
		RAISE EXCEPTION 'Value for p_bits must be between 0 and 32';
	END IF;
		
	RETURN( netmask(cast('0.0.0.0/' || p_bits AS inet)) );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION net_manip.inet_mask_to_bits
	(
	p_netmask			in inet
	)
RETURNS integer AS $$
BEGIN
	IF family(p_netmask) = 6 THEN
		RAISE EXCEPTION 'Netmask is not supported for IPv6 addresses';
	END IF;
	RETURN (32-log(2, 4294967296 - net_manip.inet_dbton(p_netmask)))::integer;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION net_manip.inet_base
	(
	p_ip_address		in		inet,
	p_bits			in		integer
	)
RETURNS inet AS $$
DECLARE
	host inet;
BEGIN
	host = set_masklen(p_ip_address, p_bits);
	return network(host);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION net_manip.inet_is_private_yn
	(
	p_ip_address		  in		  inet
	)
RETURNS char AS $$
BEGIN
	IF (net_manip.inet_is_private(p_ip_address)) THEN
		RETURN 'Y';
	ELSE
		RETURN 'N';
	END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION net_manip.inet_is_private
	(
	p_ip_address		in		inet
	)
RETURNS boolean AS $$
BEGIN
	IF( family(p_ip_address) = 4) THEN
		IF ('192.168/16' >> p_ip_address) THEN
			RETURN(true);
		END IF;
		IF ('10/8' >> p_ip_address) THEN
			RETURN(true);
		END IF;
		IF ('172.16/12' >> p_ip_address) THEN
			RETURN(true);
		END IF;
	else
		IF ('FC00::/7' >> p_ip_address) THEN
			RETURN(true);
		END IF;
	END IF;

	RETURN(false);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE function net_manip.inet_inblock
	(
	p_network		in		inet,
	p_bits			in		integer,
	p_ipaddr		in		inet
	)
RETURNS char AS $$
BEGIN
	RETURN(
		CAST(host(p_network) || '/' || p_bits AS inet) >> p_ipaddr
	);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE function net_manip.inet_dbton
	(
	p_ipaddr		in		inet
	)
RETURNS bigint AS $$
BEGIN
	IF (family(p_ipaddr) = 4) THEN
		RETURN p_ipaddr - '0.0.0.0';
	ELSE
		RETURN p_ipaddr - '::0';
	END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE function net_manip.inet_ntodb
	(
	p_ipaddr		in		bigint
	)
RETURNS inet AS $$
BEGIN
	IF p_ipaddr > 4294967296 OR p_ipaddr < 16777216 THEN
		RETURN inet('::0') + p_ipaddr;
	ELSE
		RETURN inet('0.0.0.0') + p_ipaddr;
	END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE function net_manip.inet_ntodb
	(
	p_ipaddr		in		bigint,
	p_netmask_bits	in		integer
	)
RETURNS inet AS $$
BEGIN
	RETURN(set_masklen(net_manip.inet_ntodb(p_ipaddr), p_netmask_bits));
END;

$$ LANGUAGE plpgsql;

-- END: ../pkg/pgsql/net_manip.sql

-- regular grants
grant insert,update,delete on all tables in schema jazzhands to iud_role;
grant select,update on all sequences in schema jazzhands to iud_role;
grant select on all tables in schema audit to ro_role;
grant select on all tables in schema jazzhands to ro_role;

--- XXX - deal with grants on v_netblock_hier AND netblock
--- XXX - grants on v_acct_coll_acct_expanded_detail
--- XXX - deal with grants on company views and company
