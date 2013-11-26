
\set ON_ERROR_STOP

set search_path=jazzhands;

drop view v_person_company_expanded;
drop view v_company_hier;

--------------------------------------------------------------------
-- DEALING WITH TABLE person_company [95413]

-- FOREIGN KEYS FROM
alter table account drop constraint fk_account_company_person;

-- FOREIGN KEYS TO
alter table person_company drop constraint fk_person_company_mgrprsn_id;
alter table person_company drop constraint fk_person_company_prsncmpy_sta;
alter table person_company drop constraint fk_person_company_sprprsn_id;
alter table person_company drop constraint fk_person_company_company_id;
alter table person_company drop constraint fk_person_company_prsnid;
alter table person_company drop constraint fk_person_company_prsncmpyrelt;
alter table person_company drop constraint ak_uq_prson_company_bdgid;
alter table person_company drop constraint IF EXISTS ak_uq_person_company_empid;
alter table person_company drop constraint pk_person_company;
-- INDEXES
DROP INDEX xifperson_company_person_id;
DROP INDEX xifperson_company_company_id;
DROP INDEX xif4person_company;
DROP INDEX xif5person_company;
DROP INDEX xif6person_company;
DROP INDEX xif3person_company;
-- CHECK CONSTRAINTS, etc
alter table person_company drop constraint check_yes_no_prsncmpy_mgmt;
alter table person_company drop constraint check_yes_no_691526916;
alter table person_company drop constraint check_yes_no_1391508687;
-- TRIGGERS, etc
drop trigger trig_automated_ac on person_company;
drop trigger trigger_audit_person_company on person_company;
drop trigger trigger_propagate_person_status_to_account on person_company;
drop trigger trig_userlog_person_company on person_company;


ALTER TABLE person_company RENAME TO person_company_v53;
ALTER TABLE audit.person_company RENAME TO person_company_v53;

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
	badge_system_id	varchar(255)  NULL,
	hire_date	timestamp with time zone  NULL,
	termination_date	timestamp with time zone  NULL,
	manager_person_id	integer  NULL,
	supervisor_person_id	integer  NULL,
	nickname	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'person_company', false);
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
	badge_system_id,		-- new column (badge_system_id)
	hire_date,
	termination_date,
	manager_person_id,
	supervisor_person_id,
	nickname,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
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
	NULL,		-- new column (badge_system_id)
	hire_date,
	termination_date,
	manager_person_id,
	supervisor_person_id,
	nickname,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM person_company_v53;

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
	badge_system_id,		-- new column (badge_system_id)
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
) SELECT
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
	NULL,		-- new column (badge_system_id)
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
FROM audit.person_company_v53;

ALTER TABLE person_company
        ALTER is_exempt
        SET DEFAULT 'Y'::bpchar;
ALTER TABLE person_company
	ALTER is_management
	SET DEFAULT 'N'::bpchar;
ALTER TABLE person_company
	ALTER is_full_time
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE jazzhands.person_company ADD CONSTRAINT ak_uq_person_company_empid UNIQUE (employee_id, company_id);
ALTER TABLE person_company ADD CONSTRAINT ak_uq_prson_company_bdgid UNIQUE (badge_system_id, company_id);
ALTER TABLE person_company ADD CONSTRAINT pk_person_company PRIMARY KEY (company_id, person_id);
-- INDEXES
CREATE INDEX xifperson_company_company_id ON person_company USING btree (company_id);
CREATE INDEX xifperson_company_person_id ON person_company USING btree (person_id);
CREATE INDEX xif4person_company ON person_company USING btree (supervisor_person_id);
CREATE INDEX xif5person_company ON person_company USING btree (person_company_status);
CREATE INDEX xif6person_company ON person_company USING btree (person_company_relation);
CREATE INDEX xif3person_company ON person_company USING btree (manager_person_id);

-- CHECK CONSTRAINTS
ALTER TABLE person_company ADD CONSTRAINT check_yes_no_prsncmpy_mgmt
	CHECK (is_management = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE person_company ADD CONSTRAINT check_yes_no_691526916
	CHECK (is_full_time = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE person_company ADD CONSTRAINT check_yes_no_1391508687
	CHECK (is_exempt = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
ALTER TABLE account
	ADD CONSTRAINT fk_account_company_person
	FOREIGN KEY (company_id, person_id) REFERENCES person_company(company_id, person_id);

-- FOREIGN KEYS TO
ALTER TABLE person_company
	ADD CONSTRAINT fk_person_company_mgrprsn_id
	FOREIGN KEY (manager_person_id) REFERENCES person(person_id);
ALTER TABLE person_company
	ADD CONSTRAINT fk_person_company_prsncmpy_sta
	FOREIGN KEY (person_company_status) REFERENCES val_person_status(person_status);
ALTER TABLE person_company
	ADD CONSTRAINT fk_person_company_sprprsn_id
	FOREIGN KEY (supervisor_person_id) REFERENCES person(person_id);
ALTER TABLE person_company
	ADD CONSTRAINT fk_person_company_prsncmpyrelt
	FOREIGN KEY (person_company_relation) REFERENCES val_person_company_relation(person_company_relation);
ALTER TABLE person_company
	ADD CONSTRAINT fk_person_company_prsnid
	FOREIGN KEY (person_id) REFERENCES person(person_id);
ALTER TABLE person_company
	ADD CONSTRAINT fk_person_company_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id);

-- TRIGGERS
--- XXX trigger: trig_automated_ac

DROP TRIGGER IF EXISTS trigger_propagate_person_status_to_account
        ON person_company;
CREATE TRIGGER trigger_propagate_person_status_to_account
AFTER UPDATE ON person_company
        FOR EACH ROW EXECUTE PROCEDURE propagate_person_status_to_account();

DROP TRIGGER IF EXISTS trig_automated_ac ON person_company;
CREATE TRIGGER trig_automated_ac AFTER UPDATE ON person_company 
FOR EACH ROW EXECUTE PROCEDURE automated_ac_on_person_company();



SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'person_company');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'person_company');
DROP TABLE person_company_v53;
DROP TABLE audit.person_company_v53;

COMMENT ON COLUMN person_company.nickname IS 'Nickname in the context of a given company.  This is less likely to be used, the value in person is preferrred.';


-- DONE DEALING WITH TABLE person_company [101684]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE person_company_badge []
CREATE TABLE person_company_badge
(
	company_id	integer NOT NULL,
	person_id	integer NOT NULL,
	badge_id	varchar(255) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'person_company_badge', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE person_company_badge ADD CONSTRAINT pk_person_company_badge PRIMARY KEY (company_id, person_id, badge_id);
-- INDEXES
CREATE INDEX xif1person_company_badge ON person_company_badge USING btree (company_id, person_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE person_company_badge
	ADD CONSTRAINT fk_person_company_badge_pc
	FOREIGN KEY (company_id, person_id) REFERENCES person_company(company_id, person_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'person_company_badge');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'person_company_badge');

COMMENT ON TABLE person_company_badge IS 
'badges associated with a person''s relationship to a company';
COMMENT ON COLUMN person_company_badge.badge_id IS 
'Identification usually defined externally in a badge system.';


-- DONE DEALING WITH TABLE person_company_badge [101707]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE physical_connection [261333]
--
-- RENAME physical_port columns to match layer1_connection columns.

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
alter table physical_connection drop constraint fk_physical_conn_v_cable_type;
alter table physical_connection drop constraint fk_patch_panel_port1;
alter table physical_connection drop constraint fk_patch_panel_port2;
alter table physical_connection drop constraint pk_physical_connection;
alter table physical_connection drop constraint ak_uq_physical_port_id2;
alter table physical_connection drop constraint ak_uq_physical_port_id1;
-- INDEXES
DROP INDEX idx_physconn_cabletype;
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
drop trigger trig_userlog_physical_connection on physical_connection;
drop trigger trigger_verify_physical_connection on physical_connection;
drop trigger trigger_audit_physical_connection on physical_connection;


ALTER TABLE physical_connection RENAME TO physical_connection_v53;
ALTER TABLE audit.physical_connection RENAME TO physical_connection_v53;

CREATE TABLE physical_connection
(
	physical_connection_id	integer NOT NULL,
	physical_port1_id	integer NOT NULL,
	physical_port2_id	integer NOT NULL,
	cable_type	varchar(50) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'physical_connection', false);
INSERT INTO physical_connection (
	physical_connection_id,
	physical_port1_id,		-- new column (physical_port1_id)
	physical_port2_id,		-- new column (physical_port2_id)
	cable_type,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	physical_connection_id,
	physical_port_id1,		-- new column (physical_port1_id)
	physical_port_id2,		-- new column (physical_port2_id)
	cable_type,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM physical_connection_v53;

INSERT INTO audit.physical_connection (
	physical_connection_id,
	physical_port1_id,		-- new column (physical_port1_id)
	physical_port2_id,		-- new column (physical_port2_id)
	cable_type,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	physical_connection_id,
	physical_port_id1,		-- new column (physical_port1_id)
	physical_port_id2,		-- new column (physical_port2_id)
	cable_type,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.physical_connection_v53;

ALTER TABLE physical_connection
	ALTER physical_connection_id
	SET DEFAULT nextval('physical_connection_physical_connection_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE physical_connection ADD CONSTRAINT ak_uq_physical_port_id1 UNIQUE (physical_port1_id);
ALTER TABLE physical_connection ADD CONSTRAINT pk_physical_connection PRIMARY KEY (physical_connection_id);
ALTER TABLE physical_connection ADD CONSTRAINT ak_uq_physical_port_id2 UNIQUE (physical_port2_id);
-- INDEXES
CREATE INDEX idx_physconn_cabletype ON physical_connection USING btree (cable_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE physical_connection
	ADD CONSTRAINT fk_physical_conn_v_cable_type
	FOREIGN KEY (cable_type) REFERENCES val_cable_type(cable_type);
ALTER TABLE physical_connection
	ADD CONSTRAINT fk_patch_panel_port2
	FOREIGN KEY (physical_port2_id) REFERENCES physical_port(physical_port_id);
ALTER TABLE physical_connection
	ADD CONSTRAINT fk_patch_panel_port1
	FOREIGN KEY (physical_port1_id) REFERENCES physical_port(physical_port_id);

-- TRIGGERS
CREATE TRIGGER trigger_verify_physical_connection AFTER INSERT OR UPDATE
        ON physical_connection EXECUTE PROCEDURE verify_physical_connection();

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'physical_connection');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'physical_connection');
ALTER SEQUENCE physical_connection_physical_connection_id_seq
	 OWNED BY physical_connection.physical_connection_id;
DROP TABLE physical_connection_v53;
DROP TABLE audit.physical_connection_v53;
-- DONE DEALING WITH TABLE physical_connection [267614]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- BEGIN FULLY QUALIFYING DEVICE related TRIGGERS 

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
	  FROM  jazzhands.device_collection
	  INTO	dcid
	 WHERE	device_collection_type = 'per-device'
	   AND	device_collection_id in
		(select device_collection_id
		 from jazzhands.device_collection_device
		where device_id = OLD.device_id
		)
	ORDER BY device_collection_id
	LIMIT 1;

	IF dcid IS NOT NULL THEN
		DELETE FROM jazzhands.device_collection_device
		WHERE device_collection_id = dcid;

		DELETE from jazzhands.device_collection
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
		insert into jazzhands.device_collection 
			(device_collection_name, device_collection_type)
		values
			(newname, 'per-device')
		RETURNING device_collection_id INTO dcid;
		insert into jazzhands.device_collection_device 
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
			  FROM	jazzhands.device_collection_device
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

--- Other triggers on device

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
				jazzhands.operating_system
			WHERE
				operating_system_id = NEW.operating_system_id;
	END IF;

	IF (NEW.voe_id IS NOT NULL) THEN
		SELECT sw_package_repository_id INTO voe_sw_pkg_repos
			FROM
				jazzhands.voe
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
				jazzhands.voe_symbolic_track
			WHERE
				voe_symbolic_track_id=NEW.voe_symbolic_track_id;
		IF (voe_sym_trx_sw_pkg_repo_id != os_sw_pkg_repos) THEN
			RAISE EXCEPTION 
				'Device OS and VOE track have different SW Pkg Repositories';
		END IF;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_verify_device_voe ON device;
CREATE TRIGGER trigger_verify_device_voe BEFORE INSERT OR UPDATE
	ON device FOR EACH ROW EXECUTE PROCEDURE verify_device_voe();



CREATE OR REPLACE FUNCTION verify_physical_connection() RETURNS TRIGGER AS $$
BEGIN
	PERFORM 1 FROM 
		jazzhands.physical_connection l1 
		JOIN jazzhands.physical_connection l2 ON 
			l1.physical_port_id1 = l2.physical_port_id2 AND
			l1.physical_port_id2 = l2.physical_port_id1;
	IF FOUND THEN
		RAISE EXCEPTION 'Connection already exists in opposite direction';
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_verify_physical_connection ON physical_connection;
CREATE TRIGGER trigger_verify_physical_connection AFTER INSERT OR UPDATE 
	ON physical_connection EXECUTE PROCEDURE verify_physical_connection();


-- END FULLY QUALIFYING DEVICE TRIGGERS 
--------------------------------------------------------------------

-- recreate views

--------------------------------------------------------------------
-- DEALING WITH TABLE v_person_company_expanded []
CREATE VIEW v_person_company_expanded AS
 WITH RECURSIVE var_recurse(level, root_company_id, company_id, person_id) AS (
                 SELECT 0 AS level, 
                    c.company_id AS root_company_id, 
                    c.company_id, 
                    pc.person_id
                   FROM company c
              JOIN person_company pc ON c.company_id = pc.company_id
        UNION ALL 
                 SELECT x.level + 1 AS level, 
                    x.company_id AS root_company_id, 
                    c.company_id, 
                    pc.person_id
                   FROM var_recurse x
              JOIN company c ON c.parent_company_id = x.company_id
         JOIN person_company pc ON c.company_id = pc.company_id
        )
 SELECT DISTINCT var_recurse.root_company_id AS company_id, 
    var_recurse.person_id
   FROM var_recurse;

-- DONE DEALING WITH TABLE v_person_company_expanded [125796]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_company_hier []
CREATE VIEW v_company_hier AS
 WITH RECURSIVE var_recurse(level, root_company_id, company_id, person_id) AS (
                 SELECT 0 AS level, 
                    c.company_id AS root_company_id, 
                    c.company_id, 
                    pc.person_id
                   FROM company c
              JOIN person_company pc ON c.company_id = pc.company_id
        UNION ALL 
                 SELECT x.level + 1 AS level, 
                    x.company_id AS root_company_id, 
                    c.company_id, 
                    pc.person_id
                   FROM var_recurse x
              JOIN company c ON c.parent_company_id = x.company_id
         JOIN person_company pc ON c.company_id = pc.company_id
        )
 SELECT DISTINCT var_recurse.root_company_id, 
    var_recurse.company_id
   FROM var_recurse;

-- DONE DEALING WITH TABLE v_company_hier [125873]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING with port_utils.setup_device_physical_ports and columns
-- added in last migration

-------------------------------------------------------------------
-- sets up physical ports for a device if they are not there.  This
-- will eitehr use in_port_type or in the case where its not set,
-- will iterate over each type of physical port and run it for that.
-- This is to facilitate new types that show up over time.
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION port_utils.setup_device_physical_ports (
	in_Device_id device.device_id%type,
	in_port_type val_port_type.port_type%type DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
	v_dt_id	device.device_type_id%type;
	v_pt	val_port_type.port_type%type;
	ptypes	RECORD;
BEGIN
	select  device_type_id
	  into	v_dt_id
	  from  device
	 where	device_id = in_device_id;


	FOR ptypes IN select port_type from val_port_type 
	LOOP
		v_pt := ptypes.port_type;
		if(in_port_type is NULL or v_pt = in_port_type) THEN
			if( NOT port_support.has_physical_ports(in_device_id,v_pt) ) then
				insert into physical_port
					(device_id, port_name, port_type, description,
					 port_plug_style,
					 port_medium, port_protocol, port_speed,
					 physical_label, port_purpose, tcp_port
					)
					select	in_device_id, port_name, port_type, description,
					 		port_plug_style,
					 		port_medium, port_protocol, port_speed,
					 		physical_label, port_purpose, tcp_port
					  from	device_type_phys_port_templt
					 where  device_type_id = v_dt_id
					  and	port_type = v_pt
					  and	is_optional = 'N'
				;
			end if;
		end if;
	END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- DONE DEALING with port_utils.setup_device_physical_ports 
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEAL WITH DEVICE_NOTE SEQUENCE
create sequence note_id_seq;

alter table device_note alter column note_id set default nextval('note_id_seq');
alter table person_note alter column note_id set default nextval('note_id_seq');

-- DONE: DEAL WITH DEVICE_NOTE SEQUENCE
--------------------------------------------------------------------

GRANT select on all tables in schema jazzhands to ro_role;
GRANT insert,update,delete on all tables in schema jazzhands to iud_role;
GRANT select on all sequences in schema jazzhands to ro_role;
GRANT usage on all sequences in schema jazzhands to iud_role;
grant execute on all functions in schema port_support to iud_role;
grant execute on all functions in schema port_utils to iud_role;
