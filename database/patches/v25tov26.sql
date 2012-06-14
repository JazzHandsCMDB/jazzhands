-- NOTE: This rearranged the schema to what's in 0.25 to what will be
-- 0.26.  Copyrights and whatnot may not duplicated here but are elsewhere
-- in the source tree, so check there if you are reusing code.
-- 

--- RENAME UNIX_USER_INFO to ACCOUNT_USER_INFO
-- schema changes
alter table audit.user_unix_info rename to account_unix_info;

alter sequence audit.user_unix_info_seq rename to account_unix_info_seq;

--- audit table
--- primary table
drop trigger trig_userlog_user_unix_info on user_unix_info;
drop trigger trigger_audit_user_unix_info on user_unix_info;
drop function perform_audit_user_unix_info();

ALTER TABLE USER_UNIX_INFO drop CONSTRAINT  PK_USER_UNIX_INFO ;
ALTER TABLE USER_UNIX_INFO drop CONSTRAINT  AK_USER_UNIX_INFO_UNIX_UID ;
drop  INDEX xif3user_unix_info ;
ALTER TABLE USER_UNIX_INFO drop CONSTRAINT FK_UXIFO_ACCT_ID ;
ALTER TABLE USER_UNIX_INFO drop CONSTRAINT FK_UXIFO_UNXGRP_ACCTCOLID ;

alter table user_unix_info rename to account_unix_info;

ALTER TABLE ACCOUNT_UNIX_INFO ADD CONSTRAINT  PK_ACCOUNT_UNIX_INFO PRIMARY KEY (ACCOUNT_ID)       ;
ALTER TABLE ACCOUNT_UNIX_INFO ADD CONSTRAINT  AK_ACCOUNT_UNIX_INFO_UNIX_UID UNIQUE (UNIX_UID)       ;
CREATE  INDEX XIF3ACCOUNT_UNIX_INFO ON ACCOUNT_UNIX_INFO (UNIX_GROUP_ACCT_COLLECTION_ID   ASC);

ALTER TABLE ACCOUNT_UNIX_INFO ADD CONSTRAINT FK_AUXIFO_ACCT_ID FOREIGN KEY (ACCOUNT_ID) REFERENCES ACCOUNT (ACCOUNT_ID)  ;
ALTER TABLE ACCOUNT_UNIX_INFO ADD CONSTRAINT FK_AUXIFO_UNXGRP_ACCTCOLID FOREIGN KEY (UNIX_GROUP_ACCT_COLLECTION_ID) REFERENCES ACCOUNT_COLLECTION (ACCOUNT_COLLECTION_ID) ON DELETE SET NULL;

-- drop things that depends on this table
ALTER TABLE ACCOUNT_COLLECTION
        DROP CONSTRAINT FK_ACCTCOL_USRCOLTYP ;
ALTER TABLE VAL_PROPERTY
        DROP CONSTRAINT FK_VALPROP_PV_ACTYP_RST ;
ALTER TABLE VAL_PROPERTY_TYPE
        DROP CONSTRAINT FK_PROP_TYP_PV_UCTYP_RST ;
ALTER TABLE ACCOUNT_ASSIGND_CERT
        DROP CONSTRAINT FK_KEY_USG_REASON_FOR_ASSGN_U ;

drop trigger trig_userlog_val_account_collection_type on 
	val_account_collection_type;
drop trigger trigger_audit_val_account_collection_type 
	on val_account_collection_type;

ALTER TABLE VAL_ACCOUNT_COLLECTION_TYPE
        drop CONSTRAINT  PK_VAL_ACCOUNT_COLLECTION_TYPE ;

alter table VAL_ACCOUNT_COLLECTION_TYPE rename to VAL_ACCOUNT_COLLECTION_TYPE_XX;

CREATE TABLE VAL_ACCOUNT_COLLECTION_TYPE
(
        ACCOUNT_COLLECTION_TYPE VARCHAR(50) NOT NULL ,
        DESCRIPTION          VARCHAR(4000) NULL ,
        IS_INFRASTRUCTURE_TYPE CHAR(1) NOT NULL ,
        DATA_INS_USER        VARCHAR(30) NULL ,
        DATA_INS_DATE        TIMESTAMP WITH TIME ZONE NULL ,
        DATA_UPD_USER        VARCHAR(30) NULL ,
        DATA_UPD_DATE        TIMESTAMP WITH TIME ZONE NULL
);

INSERT INTO VAL_ACCOUNT_COLLECTION_TYPE
(
	ACCOUNT_COLLECTION_TYPE,
	DESCRIPTION,
	IS_INFRASTRUCTURE_TYPE,
	DATA_INS_USER,
	DATA_INS_DATE,
	DATA_UPD_USER,
	DATA_UPD_DATE
) SELECT
	ACCOUNT_COLLECTION_TYPE,
	DESCRIPTION,
	case WHEN ACCOUNT_COLLECTION_TYPE = 'unix-group' THEN 'Y'
		WHEN ACCOUNT_COLLECTION_TYPE = 'per-user' THEN 'Y'
		ELSE 'N' END as IS_INFRASTRUCTURE_TYPE,
	DATA_INS_USER,
	DATA_INS_DATE,
	DATA_UPD_USER,
	DATA_UPD_DATE
FROM VAL_ACCOUNT_COLLECTION_TYPE_XX;

ALTER TABLE VAL_ACCOUNT_COLLECTION_TYPE
        ADD CONSTRAINT  PK_VAL_ACCOUNT_COLLECTION_TYPE 
	PRIMARY KEY (ACCOUNT_COLLECTION_TYPE)       ;

ALTER TABLE VAL_ACCOUNT_COLLECTION_TYPE
        ADD CONSTRAINT  CHECK_YES_NO_1816418084 
	CHECK (IS_INFRASTRUCTURE_TYPE IN ('Y', 'N'));

ALTER TABLE VAL_ACCOUNT_COLLECTION_TYPE
        ALTER IS_INFRASTRUCTURE_TYPE SET DEFAULT 'N';

-- add back in other foreign keys
ALTER TABLE ACCOUNT_COLLECTION
        ADD CONSTRAINT FK_ACCTCOL_USRCOLTYP 
	FOREIGN KEY (ACCOUNT_COLLECTION_TYPE) 
	REFERENCES VAL_ACCOUNT_COLLECTION_TYPE (ACCOUNT_COLLECTION_TYPE)  ;
ALTER TABLE VAL_PROPERTY
        ADD CONSTRAINT FK_VALPROP_PV_ACTYP_RST 
	FOREIGN KEY (PROP_VAL_ACCT_COLL_TYPE_RSTRCT) 
	REFERENCES VAL_ACCOUNT_COLLECTION_TYPE (ACCOUNT_COLLECTION_TYPE) 
	ON DELETE SET NULL;
ALTER TABLE VAL_PROPERTY_TYPE
        ADD CONSTRAINT FK_PROP_TYP_PV_UCTYP_RST 
	FOREIGN KEY (PROP_VAL_ACCT_COLL_TYPE_RSTRCT) 
	REFERENCES VAL_ACCOUNT_COLLECTION_TYPE (ACCOUNT_COLLECTION_TYPE) 
	ON DELETE SET NULL;
ALTER TABLE ACCOUNT_ASSIGND_CERT
        ADD CONSTRAINT FK_KEY_USG_REASON_FOR_ASSGN_U 
	FOREIGN KEY (KEY_USAGE_REASON_FOR_ASSIGN) 
	REFERENCES VAL_KEY_USG_REASON_FOR_ASSGN (KEY_USAGE_REASON_FOR_ASSIGN)  ;

------------- REDO AUDIT TABLES ----------------------------

alter table audit.val_account_collection_type 
	rename to val_account_collection_type_XX;

alter table audit.val_account_collection_type_XX 
	alter column "aud#seq" drop default;

CREATE OR REPLACE FUNCTION build_audit_tables_new() RETURNS VOID AS $FUNC$
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
				AND TABLE_NAME IN
					('val_account_collection_type')
		ORDER BY
			table_name
	LOOP
		name := table_list.table_name;
		RAISE NOTICE 'Creating audit table %', name;
		-- EXECUTE 'CREATE SEQUENCE audit.' || quote_ident(name || '_seq');
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

	END LOOP;
END;
$FUNC$ LANGUAGE plpgsql;

SELECT build_audit_tables_new();

drop function build_audit_tables_new();

INSERT INTO AUDIT.VAL_ACCOUNT_COLLECTION_TYPE
(
	ACCOUNT_COLLECTION_TYPE,
	DESCRIPTION,
	IS_INFRASTRUCTURE_TYPE,
	DATA_INS_USER,
	DATA_INS_DATE,
	DATA_UPD_USER,
	DATA_UPD_DATE,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	ACCOUNT_COLLECTION_TYPE,
	DESCRIPTION,
	case WHEN ACCOUNT_COLLECTION_TYPE = 'unix-group' THEN 'Y'
		WHEN ACCOUNT_COLLECTION_TYPE = 'per-user' THEN 'Y'
		ELSE 'N' END as IS_INFRASTRUCTURE_TYPE,
	DATA_INS_USER,
	DATA_INS_DATE,
	DATA_UPD_USER,
	DATA_UPD_DATE,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM AUDIT.VAL_ACCOUNT_COLLECTION_TYPE_XX;

------------- END AUDIT TABLES ----------------------------

------------- finally, audit and ins/delete table triggers ---------


/*
 * $HeadURL
 * $Id: build_ins_upd_triggers.sql 141 2012-06-12 21:15:47Z kovert $
 */

CREATE OR REPLACE FUNCTION rebuild_stamp_triggers_new() RETURNS VOID AS $$
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
			table_name in ('account_unix_info','val_account_collection_type') AND
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

select rebuild_stamp_triggers_new();

drop function rebuild_stamp_triggers_new();

CREATE OR REPLACE FUNCTION rebuild_audit_triggers_new() RETURNS VOID AS $$
DECLARE
	table_list	RECORD;
	create_text	VARCHAR;
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
				AND	table_name in
			('account_unix_info','val_account_collection_type')
				)
		ORDER BY
			table_name
	LOOP
		name := table_list.table_name;
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
		-- EXECUTE 'DROP TRIGGER IF EXISTS ' ||
		-- 	quote_ident('trigger_audit_' || name) || ' ON ' || quote_ident(name);
		EXECUTE 'CREATE TRIGGER ' ||
			quote_ident('trigger_audit_' || name) || ' AFTER INSERT OR UPDATE OR DELETE ON ' ||
				quote_ident(name) || ' FOR EACH ROW EXECUTE PROCEDURE ' ||
				quote_ident('perform_audit_' || name) || '()';
	END LOOP;
END;
$$ LANGUAGE plpgsql;

SELECT rebuild_audit_triggers_new();

drop function rebuild_audit_triggers_new();

------ redo person_manip.sql

drop schema if exists person_manip cascade;
create schema person_manip authorization jazzhands;

-------------------------------------------------------------------
-- returns the Id tag for CM
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION person_manip.id_tag()
RETURNS VARCHAR AS $$
BEGIN
	RETURN('<-- $Id$ -->');
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

CREATE OR REPLACE FUNCTION person_manip.add_person(
	first_name VARCHAR, 
	middle_name VARCHAR, 
	last_name VARCHAR,
	name_suffix VARCHAR, 
	gender VARCHAR(1), 
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
	INSERT INTO person (person_id, first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, birth_date)
		VALUES (person_id, first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, birth_date);
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

---- views, etc

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
-- $Id: create_v_account_collection_expanded.sql 138 2012-06-07 22:21:54Z kovert $
--

DROP VIEW IF EXISTS v_account_collection_expanded;
CREATE OR REPLACE VIEW v_account_collection_expanded AS
WITH RECURSIVE var_recurse (
	level,
	root_account_collection_id,
	account_collection_id
) as (
	SELECT	
		0				as level,
		a.account_collection_id		as root_account_collection_id, 
		a.account_collection_id		as account_collection_id
	  FROM	account_collection a
UNION ALL
	SELECT	
		x.level + 1			as level,
		x.root_account_collection_id	as root_account_collection_id, 
		ach.child_account_collection_id	as account_collection_id
	  FROM	var_recurse x
		inner join account_collection_hier ach
			on x.account_collection_id =
				ach.account_collection_id
) SELECT	level,
		root_account_collection_id,
		account_collection_id
  from 		var_recurse;


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
-- $Id: create_v_account_collection_account.sql 138 2012-06-07 22:21:54Z kovert $
--


create or replace view v_account_collection_account
as
select *
from account_collection_account
where	
	(
		(start_date is null and finish_date is null)
	OR
		(start_date is null and now() <= finish_date )
	OR
		(start_date <= now() and finish_date is NULL )
	OR
		(start_date <= now() and now() <= finish_date )
	)
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
-- $Id: create_v_acct_coll_account_expanded.sql 138 2012-06-07 22:21:54Z kovert $
--

DROP VIEW IF EXISTS v_acct_coll_account_expanded;
CREATE OR REPLACE VIEW v_acct_coll_account_expanded AS
SELECT	ace.level,
	ace.root_account_collection_id as account_collection_id,
	ace.account_collection_id as reference_account_collection_id,
	aca.account_id,
	CASE WHEN ace.root_account_collection_id = ace.account_collection_id THEN 'N' ELSE 'Y' END as is_recursive
  FROM	v_account_collection_expanded ace
	INNER JOIN v_account_collection_account aca
		using (account_collection_id)
;
