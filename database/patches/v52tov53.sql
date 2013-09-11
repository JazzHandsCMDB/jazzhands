\set ON_ERROR_STOP

-- TODO:

-- just in case 
set search_path=jazzhands;

-- views that need to be dropped and recreated
drop view v_acct_coll_prop_expanded;
drop view v_dev_col_user_prop_expanded;
drop view IF EXISTS v_device_col_acct_col_expanded;
drop view v_property;
drop view v_nblk_coll_netblock_expanded;
drop view v_application_role_member;
drop view v_acct_coll_acct_expanded_detail;
drop view v_acct_coll_acct_expanded;
drop view v_account_collection_account;


--
-- $HeadURL$
-- $Id$
--

-- DROP SCHEMA IF EXISTS schema_support CASCADE;
-- CREATE SCHEMA schema_support AUTHORIZATION jazzhands;

DROP FUNCTION IF EXISTS schema_support.build_audit_table(varchar, boolean);
DROP FUNCTION IF EXISTS schema_support.build_audit_tables();
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_trigger(varchar);
DROP FUNCTION IF EXISTS schema_support.rebuild_audit_triggers();
DROP FUNCTION IF EXISTS schema_support.rebuild_stamp_trigger(varchar);
DROP FUNCTION IF EXISTS schema_support.rebuild_stamp_triggers();


DO $$
BEGIN
	IF NOT EXISTS(
		SELECT schema_name
		FROM information_schema.schemata
		WHERE schema_name = 'schema_support'
	) THEN
		EXECUTE 'CREATE SCHEMA schema_support AUTHORIZATION jazzhands';
	END IF;
END
$$;



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

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION schema_support.rebuild_audit_triggers
    ( aud_schema varchar, tbl_schema varchar )
RETURNS VOID AS $$
DECLARE
    table_list RECORD;
BEGIN
    --
    -- select tables with audit tables
    --
    FOR table_list IN
        SELECT table_name FROM information_schema.tables
        WHERE table_type = 'BASE TABLE' AND table_schema = tbl_schema
        AND table_name IN (
            SELECT table_name FROM information_schema.tables
            WHERE table_schema = aud_schema AND table_type = 'BASE TABLE'
        ) ORDER BY table_name
    LOOP
        PERFORM schema_support.rebuild_audit_trigger
            (aud_schema, tbl_schema, table_list.table_name);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION schema_support.build_audit_table(
    aud_schema VARCHAR, tbl_schema VARCHAR, table_name VARCHAR,
    first_time boolean DEFAULT true
)
RETURNS VOID AS $FUNC$
BEGIN
    IF first_time THEN
        EXECUTE 'CREATE SEQUENCE ' || quote_ident(aud_schema) || '.'
            || quote_ident(table_name || '_seq');
    END IF;

    EXECUTE 'CREATE TABLE ' || quote_ident(aud_schema) || '.'
        || quote_ident(table_name) || ' AS '
        || 'SELECT *, NULL::char(3) as "aud#action", now() as "aud#timestamp", '
        || 'NULL::varchar(255) AS "aud#user", NULL::integer AS "aud#seq" '
        || 'FROM ' || quote_ident(tbl_schema) || '.' || quote_ident(table_name) 
        || ' LIMIT 0';

    EXECUTE 'ALTER TABLE ' || quote_ident(aud_schema) || '.'
        || quote_ident(table_name)
        || $$ ALTER COLUMN "aud#seq" SET NOT NULL, $$
        || $$ ALTER COLUMN "aud#seq" SET DEFAULT nextval('$$
        || quote_ident(aud_schema) || '.' || quote_ident(table_name || '_seq')
        || $$')$$;

    IF first_time THEN
        PERFORM schema_support.rebuild_audit_trigger
            ( aud_schema, tbl_schema, table_name );
    END IF;
END;
$FUNC$ LANGUAGE plpgsql;

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION schema_support.build_audit_tables
    ( aud_schema varchar, tbl_schema varchar )
RETURNS VOID AS $FUNC$
DECLARE
     table_list RECORD;
BEGIN
    FOR table_list IN
        SELECT table_name FROM information_schema.tables
        WHERE table_type = 'BASE TABLE' AND table_schema = tbl_schema
        AND NOT ( 
            table_name IN (
                SELECT table_name FROM information_schema.tables
                WHERE table_schema = aud_schema
            )
        )
        ORDER BY table_name
    LOOP
        PERFORM schema_support.build_audit_table
            ( aud_schema, tbl_schema, table_list.table_name );
    END LOOP;

    PERFORM schema_support.rebuild_audit_triggers(aud_schema, tbl_schema);
END;
$FUNC$ LANGUAGE plpgsql;

-------------------------------------------------------------------------------

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

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION schema_support.rebuild_stamp_trigger
    (tbl_schema VARCHAR, table_name VARCHAR)
RETURNS VOID AS $$
BEGIN
    EXECUTE 'DROP TRIGGER IF EXISTS '
        || quote_ident('trig_userlog_' || table_name)
        || ' ON ' || quote_ident(tbl_schema) || '.' || quote_ident(table_name);

    EXECUTE 'CREATE TRIGGER '
        || quote_ident('trig_userlog_' || table_name)
        || ' BEFORE INSERT OR UPDATE ON '
        || quote_ident(tbl_schema) || '.' || quote_ident(table_name)
        || ' FOR EACH ROW EXECUTE PROCEDURE'
        || ' schema_support.trigger_ins_upd_generic_func()';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION schema_support.rebuild_stamp_triggers
    (tbl_schema VARCHAR)
RETURNS VOID AS $$
BEGIN
    DECLARE
        tab RECORD;
    BEGIN
        FOR tab IN 
            SELECT table_name FROM information_schema.tables
            WHERE table_schema = tbl_schema AND table_type = 'BASE TABLE'
            AND table_name NOT LIKE 'aud$%'
        LOOP
            PERFORM schema_support.rebuild_stamp_trigger
	        (tbl_schema, tab.table_name);
        END LOOP;
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- select schema_support.rebuild_stamp_triggers();
-- SELECT schema_support.build_audit_tables();


-- DEALING WITH TABLE account_collection_account [118654]

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
alter table account_collection_account drop constraint fk_acctcol_usr_ucol_id;
alter table account_collection_account drop constraint fk_acol_account_id;
alter table account_collection_account drop constraint pk_account_collection_user;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
drop trigger trig_userlog_account_collection_account on account_collection_account;
drop trigger trigger_audit_account_collection_account on account_collection_account;


ALTER TABLE account_collection_account RENAME TO account_collection_account_v52;
ALTER TABLE audit.account_collection_account RENAME TO account_collection_account_v52;

CREATE TABLE account_collection_account
(
	account_collection_id	integer NOT NULL,
	account_id	integer NOT NULL,
	account_id_rank	integer  NULL,
	start_date	timestamp without time zone  NULL,
	finish_date	timestamp without time zone  NULL,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'account_collection_account', false);
INSERT INTO account_collection_account (
	account_collection_id,
	account_id,
	start_date,
	finish_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT		account_collection_id,
	account_id,
	start_date,
	finish_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM account_collection_account_v52;

INSERT INTO audit.account_collection_account (
	account_collection_id,
	account_id,
	start_date,
	finish_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT		account_collection_id,
	account_id,
	start_date,
	finish_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.account_collection_account_v52;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE account_collection_account ADD CONSTRAINT pk_account_collection_user PRIMARY KEY (account_collection_id, account_id);
ALTER TABLE account_collection_account ADD CONSTRAINT ak_acctcol_acct_rank UNIQUE (account_collection_id, account_id_rank);
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
ALTER TABLE account_unix_info
	ADD CONSTRAINT fk_acct_unx_info_ac_acct
	FOREIGN KEY (unix_group_acct_collection_id, account_id) REFERENCES account_collection_account(account_collection_id, account_id);

-- FOREIGN KEYS TO
ALTER TABLE account_collection_account
	ADD CONSTRAINT fk_acctcol_usr_ucol_id
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);
ALTER TABLE account_collection_account
	ADD CONSTRAINT fk_acol_account_id
	FOREIGN KEY (account_id) REFERENCES account(account_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'account_collection_account');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'account_collection_account');
DROP TABLE account_collection_account_v52;
DROP TABLE audit.account_collection_account_v52;
-- DEALING WITH TABLE device_collection_device [118893]

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
alter table device_collection_device drop constraint fk_devcolldev_dev_colid;
alter table device_collection_device drop constraint fk_devcolldev_dev_id;
alter table device_collection_device drop constraint pk_device_collection_device;
-- INDEXES
DROP INDEX ix_dev_col_dev_dev_colid;
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
drop trigger trigger_audit_device_collection_device on device_collection_device;
drop trigger trig_userlog_device_collection_device on device_collection_device;


ALTER TABLE device_collection_device RENAME TO device_collection_device_v52;
ALTER TABLE audit.device_collection_device RENAME TO device_collection_device_v52;

CREATE TABLE device_collection_device
(
	device_id	integer NOT NULL,
	device_collection_id	integer NOT NULL,
	device_id_rank	integer  NULL,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'device_collection_device', false);
INSERT INTO device_collection_device (
	device_id,
	device_collection_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT		device_id,
	device_collection_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM device_collection_device_v52;

INSERT INTO audit.device_collection_device (
	device_id,
	device_collection_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT		device_id,
	device_collection_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.device_collection_device_v52;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device_collection_device ADD CONSTRAINT pk_device_collection_device PRIMARY KEY (device_id, device_collection_id);
ALTER TABLE device_collection_device ADD CONSTRAINT ak_dev_coll_dev_rank UNIQUE (device_collection_id, device_id_rank);
-- INDEXES
CREATE INDEX ix_dev_col_dev_dev_colid ON device_collection_device USING btree (device_collection_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE device_collection_device
	ADD CONSTRAINT fk_devcolldev_dev_colid
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);
ALTER TABLE device_collection_device
	ADD CONSTRAINT fk_devcolldev_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device_collection_device');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device_collection_device');
DROP TABLE device_collection_device_v52;
DROP TABLE audit.device_collection_device_v52;
-- DEALING WITH TABLE netblock_collection_netblock [119170]

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
alter table netblock_collection_netblock drop constraint fk_nblk_col_nblk_nblkid;
alter table netblock_collection_netblock drop constraint fk_nblk_col_nblk_nbcolid;
alter table netblock_collection_netblock drop constraint pk_account_collection_account;
-- INDEXES
DROP INDEX xifk_nb_col_nb_nbcolid;
DROP INDEX ifk_nb_col_nb_nblkid;
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
drop trigger trig_userlog_netblock_collection_netblock on netblock_collection_netblock;
drop trigger trigger_audit_netblock_collection_netblock on netblock_collection_netblock;


ALTER TABLE netblock_collection_netblock RENAME TO netblock_collection_netblock_v52;
ALTER TABLE audit.netblock_collection_netblock RENAME TO netblock_collection_netblock_v52;

CREATE TABLE netblock_collection_netblock
(
	netblock_collection_id	integer NOT NULL,
	netblock_id	integer NOT NULL,
	netblock_id_rank	integer  NULL,
	start_date	timestamp without time zone  NULL,
	finish_date	timestamp without time zone  NULL,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'netblock_collection_netblock', false);
INSERT INTO netblock_collection_netblock (
	netblock_collection_id,
	netblock_id,
	start_date,
	finish_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT		netblock_collection_id,
	netblock_id,
	start_date,
	finish_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM netblock_collection_netblock_v52;

INSERT INTO audit.netblock_collection_netblock (
	netblock_collection_id,
	netblock_id,
	start_date,
	finish_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT		netblock_collection_id,
	netblock_id,
	start_date,
	finish_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.netblock_collection_netblock_v52;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE netblock_collection_netblock ADD CONSTRAINT ak_netblk_coll_nblk_id UNIQUE (netblock_collection_id, netblock_id_rank);
ALTER TABLE netblock_collection_netblock ADD CONSTRAINT pk_account_collection_account PRIMARY KEY (netblock_collection_id, netblock_id);
-- INDEXES
CREATE INDEX xifk_nb_col_nb_nbcolid ON netblock_collection_netblock USING btree (netblock_collection_id);
CREATE INDEX ifk_nb_col_nb_nblkid ON netblock_collection_netblock USING btree (netblock_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE netblock_collection_netblock
	ADD CONSTRAINT fk_nblk_col_nblk_nblkid
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);
ALTER TABLE netblock_collection_netblock
	ADD CONSTRAINT fk_nblk_col_nblk_nbcolid
	FOREIGN KEY (netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'netblock_collection_netblock');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'netblock_collection_netblock');
DROP TABLE netblock_collection_netblock_v52;
DROP TABLE audit.netblock_collection_netblock_v52;
-- DEALING WITH TABLE ssh_key [119508]

-- FOREIGN KEYS FROM
alter table device_ssh_key drop constraint fk_dev_ssh_key_device_id;
alter table account_ssh_key drop constraint fk_account_ssh_key_account_id;

-- FOREIGN KEYS TO
alter table ssh_key drop constraint fk_ssh_key_enc_key_id;
alter table ssh_key drop constraint fk_ssh_key_ssh_key_type;
alter table ssh_key drop constraint pk_ssh_key;
-- INDEXES
DROP INDEX xif2ssh_key;
DROP INDEX xif1ssh_key;
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
drop trigger trigger_audit_ssh_key on ssh_key;
drop trigger trig_userlog_ssh_key on ssh_key;


ALTER TABLE ssh_key RENAME TO ssh_key_v52;
ALTER TABLE audit.ssh_key RENAME TO ssh_key_v52;

CREATE TABLE ssh_key
(
	ssh_key_id	integer NOT NULL,
	ssh_key_type	character(18)  NULL,
	ssh_public_key	varchar(4096) NOT NULL,
	ssh_private_key	varchar(4096)  NULL,
	encryption_key_id	integer  NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'ssh_key', false);
INSERT INTO ssh_key (
	ssh_key_id,
	ssh_key_type,
	ssh_public_key,
	ssh_private_key,
	encryption_key_id,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT		ssh_key_id,
	ssh_key_type,
	ssh_public_key,
	ssh_private_key,
	_,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM ssh_key_v52;

INSERT INTO audit.ssh_key (
	ssh_key_id,
	ssh_key_type,
	ssh_public_key,
	ssh_private_key,
	encryption_key_id,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT		ssh_key_id,
	ssh_key_type,
	ssh_public_key,
	ssh_private_key,
	_,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.ssh_key_v52;

ALTER TABLE ssh_key
	ALTER ssh_key_id
	SET DEFAULT nextval('ssh_key_ssh_key_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE ssh_key ADD CONSTRAINT pk_ssh_key PRIMARY KEY (ssh_key_id);
ALTER TABLE ssh_key ADD CONSTRAINT ak_ssh_key_private_key UNIQUE (ssh_private_key);
ALTER TABLE ssh_key ADD CONSTRAINT ak_ssh_key_public_key UNIQUE (ssh_public_key);
-- INDEXES
CREATE INDEX xif2ssh_key ON ssh_key USING btree (ssh_key_type);
CREATE INDEX xif1ssh_key ON ssh_key USING btree (encryption_key_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
ALTER TABLE device_ssh_key
	ADD CONSTRAINT fk_dev_ssh_key_device_id
	FOREIGN KEY (ssh_key_id) REFERENCES ssh_key(ssh_key_id);
ALTER TABLE account_ssh_key
	ADD CONSTRAINT fk_account_ssh_key_account_id
	FOREIGN KEY (ssh_key_id) REFERENCES ssh_key(ssh_key_id);

-- FOREIGN KEYS TO
ALTER TABLE ssh_key
	ADD CONSTRAINT fk_ssh_key_enc_key_id
	FOREIGN KEY (encryption_key_id) REFERENCES encryption_key(encryption_key_id);
ALTER TABLE ssh_key
	ADD CONSTRAINT fk_ssh_key_ssh_key_type
	FOREIGN KEY (ssh_key_type) REFERENCES val_ssh_key_type(ssh_key_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'ssh_key');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'ssh_key');
ALTER SEQUENCE ssh_key_ssh_key_id_seq
	 OWNED BY ssh_key.ssh_key_id;
DROP TABLE ssh_key_v52;
DROP TABLE audit.ssh_key_v52;
-- DEALING WITH TABLE token_collection_token [119630]

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
alter table token_collection_token drop constraint fk_tok_col_tok_token_id;
alter table token_collection_token drop constraint fk_tok_col_tok_token_col_id;
alter table token_collection_token drop constraint pk_token_collection_token;
-- INDEXES
DROP INDEX idx_tok_col_token_tok_id;
DROP INDEX idx_tok_col_token_tok_col_id;
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
drop trigger trig_userlog_token_collection_token on token_collection_token;
drop trigger trigger_audit_token_collection_token on token_collection_token;


ALTER TABLE token_collection_token RENAME TO token_collection_token_v52;
ALTER TABLE audit.token_collection_token RENAME TO token_collection_token_v52;

CREATE TABLE token_collection_token
(
	token_collection_id	integer NOT NULL,
	token_id	integer NOT NULL,
	token_id_rank	integer  NULL,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'token_collection_token', false);
INSERT INTO token_collection_token (
	token_collection_id,
	token_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT		token_collection_id,
	token_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM token_collection_token_v52;

INSERT INTO audit.token_collection_token (
	token_collection_id,
	token_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT		token_collection_id,
	token_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.token_collection_token_v52;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE token_collection_token ADD CONSTRAINT ak_tokcoll_tok_tok_id UNIQUE (token_collection_id, token_id_rank);
ALTER TABLE token_collection_token ADD CONSTRAINT pk_token_collection_token PRIMARY KEY (token_collection_id, token_id);
-- INDEXES
CREATE INDEX idx_tok_col_token_tok_id ON token_collection_token USING btree (token_id);
CREATE INDEX idx_tok_col_token_tok_col_id ON token_collection_token USING btree (token_collection_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE token_collection_token
	ADD CONSTRAINT fk_tok_col_tok_token_id
	FOREIGN KEY (token_id) REFERENCES token(token_id);
ALTER TABLE token_collection_token
	ADD CONSTRAINT fk_tok_col_tok_token_col_id
	FOREIGN KEY (token_collection_id) REFERENCES token_collection(token_collection_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'token_collection_token');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'token_collection_token');
DROP TABLE token_collection_token_v52;
DROP TABLE audit.token_collection_token_v52;

-- DEALING WITH TABLE val_property [403986]

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
alter table val_property drop constraint ckc_val_prop_cmp_id;
alter table val_property drop constraint ckc_val_prop_ismulti;
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


ALTER TABLE val_property RENAME TO val_property_v52;
ALTER TABLE audit.val_property RENAME TO val_property_v52;

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
	permit_service_environment	character(10) NOT NULL,
	permit_site_code	character(10) NOT NULL,
	permit_property_rank	character(10) NOT NULL,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
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
	permit_service_environment,
	permit_site_code,
	permit_property_rank,
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
	permit_account_collection_id,
	permit_company_id,
	permit_device_collection_id,
	permit_account_id,
	permit_dns_domain_id,
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_person_id,
	permit_service_environment,
	permit_site_code,
	'PROHIBITED',
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_property_v52;

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
	permit_service_environment,
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
) SELECT		property_name,
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
	permit_service_environment,
	permit_site_code,
	'PROHIBITED',
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_property_v52;

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
	ALTER permit_service_environment
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
DROP TABLE val_property_v52;
DROP TABLE audit.val_property_v52;

-- DEALING WITH TABLE property [403366]

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
alter table property drop constraint fk_property_val_prsnid;
alter table property drop constraint fk_property_person_id;
alter table property drop constraint fk_property_site_code;
alter table property drop constraint fk_property_pval_compid;
alter table property drop constraint fk_property_osid;
alter table property drop constraint fk_property_svcenv;
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


ALTER TABLE property RENAME TO property_v52;
ALTER TABLE audit.property RENAME TO property_v52;

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
	service_environment	varchar(50)  NULL,
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
	property_rank	integer NULL,
	start_date	timestamp without time zone  NULL,
	finish_date	timestamp without time zone  NULL,
	is_enabled	character(1) NOT NULL,
	data_ins_user	varchar(30)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(30)  NULL,
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
FROM property_v52;

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
FROM audit.property_v52;

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
	ADD CONSTRAINT fk_property_svcenv
	FOREIGN KEY (service_environment) REFERENCES val_service_environment(service_environment);
ALTER TABLE property
	ADD CONSTRAINT fk_property_nblk_coll_id
	FOREIGN KEY (netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id);
ALTER TABLE property
	ADD CONSTRAINT fk_property_acct_col
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);
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
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'property');
ALTER SEQUENCE property_property_id_seq
	 OWNED BY property.property_id;
DROP TABLE property_v52;
DROP TABLE audit.property_v52;

-----------------------------------------------------------------------------
-- additional items

CREATE  INDEX XIF4ACCOUNT_UNIX_INFO ON ACCOUNT_UNIX_INFO
(UNIX_GROUP_ACCT_COLLECTION_ID   ASC,ACCOUNT_ID   ASC);


-- add missing views back in

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

CREATE OR REPLACE VIEW v_acct_coll_acct_expanded AS
	SELECT DISTINCT 
		ace.account_collection_id,
		aca.account_id
	FROM 
		v_acct_coll_expanded ace JOIN
		v_account_collection_account aca ON
			aca.account_collection_id = ace.root_account_collection_id;



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

CREATE OR REPLACE VIEW v_nblk_coll_netblock_expanded AS
WITH RECURSIVE var_recurse (
	level,
	root_collection_id,
	netblock_collection_id,
	child_netblock_collection_id,
	netblock_id
) as (
	SELECT	
		0				as level,
		u.netblock_collection_id		as root_collection_id, 
		u.netblock_collection_id		as netblock_collection_id, 
		u.netblock_collection_id		as child_netblock_collection_id,
		ua.netblock_Id			as netblock_id
	  FROM	netblock_collection u
		inner join netblock_collection_netblock ua
			on u.netblock_collection_id =
				ua.netblock_collection_id
UNION ALL
	SELECT	
		x.level + 1			as level,
		x.netblock_collection_id		as root_netblock_collection_id, 
		uch.netblock_collection_id		as netblock_collection_id, 
		uch.child_netblock_collection_id	as child_netblock_collection_id,
		ua.netblock_Id			as netblock_id
	  FROM	var_recurse x
		inner join netblock_collection_hier uch
			on x.child_netblock_collection_id =
				uch.netblock_collection_id
		inner join netblock_collection_netblock ua
			on uch.child_netblock_collection_id =
				ua.netblock_collection_id
) SELECT	distinct root_collection_id as netblock_collection_id,
		netblock_id as netblock_id
  from 		var_recurse;



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

-- new acct_coll_manip

DO $$
BEGIN
	IF NOT EXISTS(
		SELECT schema_name
		FROM information_schema.schemata
		WHERE schema_name = 'acct_coll_manip'
	) THEN
		EXECUTE 'CREATE SCHEMA acct_coll_manip AUTHORIZATION jazzhands';
	END IF;
END
$$;

CREATE OR REPLACE FUNCTION acct_coll_manip.get_automated_account_collection_id(ac_name VARCHAR) RETURNS INTEGER AS $_$
DECLARE
	ac_id INTEGER;
BEGIN
	SELECT account_collection_id INTO ac_id FROM account_collection WHERE account_collection_name = ac_name AND account_collection_type ='automated';
	IF NOT FOUND THEN
		INSERT INTO account_collection (account_collection_name, account_collection_type) VALUES (ac_name, 'automated')
			RETURNING account_collection_id INTO ac_id;
	END IF;
	RETURN ac_id;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION acct_coll_manip.insert_or_delete_automated_ac(do_delete BOOLEAN,acct_id INTEGER,ac_ids INTEGER[]) RETURNS VOID AS $_$
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

CREATE OR REPLACE FUNCTION acct_coll_manip.person_company_flags_to_automated_ac_name(flag VARCHAR(1), base_name VARCHAR, OUT name VARCHAR, OUT non_name VARCHAR) AS $_$
BEGIN
	name = base_name;
	IF flag = 'N' THEN
		name  = 'non_' || base_name;
		non_name = base_name;
	ELSE
		non_name = 'non_' || base_name;
	END IF;
END;
$_$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION acct_coll_manip.person_gender_char_to_automated_ac_name(gender VARCHAR(1)) RETURNS VARCHAR AS $_$
BEGIN
	IF gender IS NULL THEN
		RETURN NULL;
	END IF;
	IF gender = 'M' THEN
		RETURN 'male';
	ELSIF gender = 'F' THEN
		RETURN 'female';
	ELSIF gender = 'U' THEN
		RETURN 'unspecified_gender';
	END IF;
	RAISE NOTICE 'Gender account collection name cannot be determined from gender symbol ''%''', gender;
	RETURN NULL;
END;
$_$ LANGUAGE plpgsql;

-------------------------------------------------------------------
-- BEGIN redo ../ddl/schema/pgsql/create_dns_triggers.sql

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
		PERFORM 1 FROM jazzhands.dns_domain WHERE dns_domain_id IN (
		    NEW.dns_domain_id, netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
		)
		FOR UPDATE;

		RETURN NEW;
	ELSE
		IF OLD.netblock_id IS DISTINCT FROM NEW.netblock_id THEN
			PERFORM 1 FROM jazzhands.dns_domain WHERE dns_domain_id IN (
			    OLD.dns_domain_id, netblock_utils.find_rvs_zone_from_netblock_id(OLD.netblock_id),
			    NEW.dns_domain_id, netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
			)
			FOR UPDATE;
		ELSE
			PERFORM 1 FROM jazzhands.dns_domain WHERE dns_domain_id IN (
			    NEW.dns_domain_id, netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
			)
			FOR UPDATE;
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

		IF NEW.dns_type = 'A' THEN
			UPDATE jazzhands.dns_domain SET zone_last_updated = clock_timestamp()
				WHERE dns_domain_id = netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
				AND ( zone_last_updated < last_generated or zone_last_updated is NULL );
		END IF;

		IF TG_OP = 'UPDATE' THEN
			IF OLD.dns_domain_id != NEW.dns_domain_id THEN
				UPDATE jazzhands.dns_domain SET zone_last_updated = clock_timestamp()
					 WHERE dns_domain_id = OLD.dns_domain_id
					 AND ( zone_last_updated < last_generated or zone_last_updated is NULL );
			END IF;
			IF NEW.dns_type = 'A' THEN
				IF OLD.netblock_id != NEW.netblock_id THEN
					UPDATE jazzhands.dns_domain SET zone_last_updated = clock_timestamp()
						 WHERE dns_domain_id = netblock_utils.find_rvs_zone_from_netblock_id(OLD.netblock_id)
					     AND ( zone_last_updated < last_generated or zone_last_updated is NULL );
				END IF;
			END IF;
		END IF;
	END IF;

    IF TG_OP = 'DELETE' THEN
        UPDATE jazzhands.dns_domain SET zone_last_updated = clock_timestamp()
			WHERE dns_domain_id = OLD.dns_domain_id
			AND ( zone_last_updated < last_generated or zone_last_updated is NULL );

        IF OLD.dns_type = 'A' THEN
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


-- END redo ../ddl/schema/pgsql/create_dns_triggers.sql
-------------------------------------------------------------------

-- BEGIN redo ../ddl/schema/pgsql/create_netblock_triggers.sql
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
			netblock_id != NEW.netblock_id AND
			netblock_type = NEW.netblock_type AND
			ip_universe_id = NEW.ip_universe_id;
		RETURN NULL;
	ELSE
		-- We don't need to specify the netblock_type or ip_universe_id here
		-- because the parent would have had to match
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
			netblock_type = NEW.netblock_type AND
			ip_universe_id = NEW.ip_universe_id AND
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


-- END redo ../ddl/schema/pgsql/create_netblock_triggers.sql

-- BEGIN redo ../pkg/pgsql/person_manip.sql
-- Copyright (c) 2012, AppNexus, Inc.
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
		INSERT INTO account_collection (account_collection_type, account_collection_name)
			VALUES (type, department)
		RETURNING account_collection_id into _account_collection_id;
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
	IF old_account_collection_id IS NULL THEN
		INSERT INTO account_collection_account (account_id, account_collection_id) VALUES (_account_id, _account_collection_id);
	ELSE
		--RAISE NOTICE 'updating account_collection_account with id % for account %', _account_collection_id, _account_id;
		UPDATE account_collection_account SET account_collection_id = _account_collection_id WHERE account_id = _account_id AND account_collection_id=old_account_collection_id;
	END IF;
	RETURN _account_collection_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION person_manip.add_person(
	__person_id INTEGER,
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
	is_manager VARCHAR(1),
	is_exempt VARCHAR(1),
	is_full_time VARCHAR(1),
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
	IF __person_id IS NULL THEN
		INSERT INTO person (first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
			VALUES (first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
			RETURNING person_id into _person_id;
	ELSE
		INSERT INTO person (person_id, first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
			VALUES (__person_id, first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date);
		_person_id = __person_id;
	END IF;
	INSERT INTO person_company
		(person_id,company_id,external_hr_id,person_company_status,is_management, is_exempt, is_full_time, employee_id,hire_date,termination_date,person_company_relation, position_title)
		VALUES
		(_person_id, _company_id, external_hr_id, person_company_status, is_manager, is_exempt, is_full_time, employee_id, hire_date, termination_date, person_company_relation, job_title);
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
	INSERT INTO account ( login, person_id, company_id, account_realm_id, account_status, description, account_role, account_type) 
		VALUES (_login, _person_id, _company_id, _account_realm_id, _account_status, _description, 'primary', 'pseudouser')
	RETURNING account_id into _account_id;
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

$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Purge account from system.  This is called rarely and does not hit
-- a number of tables where account_id may appear.  The caller needs
-- to deal with those manually because they are not properties of the
-- account
CREATE OR REPLACE FUNCTION person_manip.purge_account(
		in_account_id	account.account_id%TYPE
) RETURNS void AS $$
BEGIN
	DELETE FROM account_assignd_cert where ACCOUNT_ID = in_account_id;
	DELETE FROM account_token where ACCOUNT_ID = in_account_id;
	DELETE FROM account_unix_info where ACCOUNT_ID = in_account_id;
	DELETE FROM klogin where ACCOUNT_ID = in_account_id;
	DELETE FROM property where ACCOUNT_ID = in_account_id;
	DELETE FROM account_password where ACCOUNT_ID = in_account_id;
	DELETE FROM unix_group where account_collection_id in 
		(select account_collection_id from account_collection where account_collection_name in
			(select login from account where account_id = in_account_id)
			and account_collection_type in ('unix-group')
		);
	DELETE FROM account_collection_account where ACCOUNT_ID = in_account_id;

	DELETE FROM account_collection where account_collection_name in 
		(select login from account where account_id = in_account_id)
		and account_collection_type in ('per-user', 'unix-group');

	DELETE FROM account where ACCOUNT_ID = in_account_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION person_manip.merge_accounts(
	merge_from_account_id	account.account_Id%TYPE,
	merge_to_account_id	account.account_Id%TYPE
) RETURNS INTEGER AS $$
DECLARE
	fpc		person_company%ROWTYPE;
	tpc		person_company%ROWTYPE;
	_account_realm_id INTEGER;
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

	IF(tpc.external_hr_id is NOT NULL AND fpc.external_hr_id IS NULL) THEN
		RAISE EXCEPTION 'Destination account has an external HR ID and origin account has none';
	END IF;

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

	-- Switch person_ids
	DELETE FROM person_account_realm_company WHERE person_id = fpc.person_id AND company_id = tpc.company_id;
	SELECT account_realm_id INTO _account_realm_id FROM account_realm_company WHERE company_id = tpc.company_id;
	INSERT INTO person_account_realm_company (person_id, company_id, account_realm_id) VALUES ( fpc.person_id , tpc.company_id, _account_realm_id);
	UPDATE account SET account_realm_id = _account_realm_id, person_id = fpc.person_id WHERE person_id = tpc.person_id AND company_id = fpc.company_id;
	DELETE FROM person_company WHERE person_id = tpc.person_id AND company_id = tpc.company_id;
	DELETE FROM person_account_realm_company WHERE person_id = tpc.person_id AND company_id = tpc.company_id;
	UPDATE person_image SET person_id = fpc.person_id WHERE person_id = tpc.person_id;
	-- if there are other relations that may exist, do not delete the person.
	BEGIN
		delete from person where person_id = tpc.person_id;
	EXCEPTION WHEN foreign_key_violation THEN
		NULL;
	END;

	return merge_to_account_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION person_manip.change_company(final_company_id integer, _person_id integer, initial_company_id integer)  RETURNS VOID AS $_$
DECLARE
	initial_person_company  person_company%ROWTYPE;
BEGIN
	INSERT INTO person_account_realm_company (company_id, person_id, account_realm_id) VALUES (final_company_id, _person_id,
		(SELECT account_realm_id FROM account_realm_company WHERE company_id = initial_company_id));
	SELECT * INTO initial_person_company FROM person_company WHERE person_id = _person_id AND company_id = initial_company_id;
	initial_person_company.company_id = final_company_id;
	INSERT INTO person_company VALUES (initial_person_company.*);
	UPDATE account SET company_id = final_company_id WHERE company_id = initial_company_id AND person_id = _person_id;
	DELETE FROM person_company WHERE person_id = _person_id AND company_id = initial_company_id;
	DELETE FROM person_account_realm_company WHERE person_id = _person_id AND company_id = initial_company_id;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = jazzhands, pg_temp;

-- END redo ../pkg/pgsql/person_manip.sql


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

-- This view shows which users are mapped to which device collections,
-- which is particularly important for generating passwd files. Please
-- note that the same account_id can be mapped to the same
-- device_collection multiple times via different account_collections. The
-- user_collection_id column is important mostly to join the results of the
-- view back to the account_collection table, and select only certain account_collection
-- types (such as 'system' and 'per-user') to be expanded.

CREATE OR REPLACE VIEW v_device_col_acct_col_expanded AS
SELECT DISTINCT dchd.device_collection_id, dcu.account_collection_id, 
	vuue.account_id
FROM v_device_coll_hier_detail dchd
JOIN v_property dcu ON dcu.device_collection_id = 
	dchd.parent_device_collection_id
JOIN v_acct_coll_acct_expanded vuue 
	on vuue.account_collection_id = dcu.account_collection_id
WHERE dcu.property_name = 'UnixLogin' and dcu.property_type = 'MclassUnixProp';

------------------------------------------------------------------------------
-- BEGIN port_utils

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

drop schema if exists port_utils cascade;
create schema port_utils authorization jazzhands;

-------------------------------------------------------------------
-- returns the Id tag for CM
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION port_utils.id_tag() RETURNS VARCHAR AS $$
BEGIN
		RETURN('<-- $Id$ -->');
END;
$$ LANGUAGE plpgsql;
--end of procedure id_tag
-------------------------------------------------------------------

-------------------------------------------------------------------
-- sets up power ports for a device if they are not there.
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION port_utils.setup_device_power (
	in_Device_id device.device_id%type
) RETURNS VOID AS $$
DECLARE
	dt_id	device.device_type_id%type;
BEGIN
	if( port_support.has_power_ports(in_device_id) ) then
		return;
	end if;

	select  device_type_id
	  into	dt_id
	  from  device
	 where	device_id = in_device_id;

	 insert into device_power_interface
		(device_id, power_interface_port)
		select in_device_id, power_interface_port
		  from device_type_power_port_templt
		 where device_type_id = dt_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-------------------------------------------------------------------
-- sets up serial ports for a device if they are not there.
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION port_utils.setup_device_serial (
	in_Device_id device.device_id%type
) RETURNS INTEGER AS $$
DECLARE
	dt_id	device.device_type_id%type;
BEGIN
	return setup_device_physical_ports(in_device_id, 'serial');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
					(device_id, port_name, port_type)
					select	in_device_id, port_name, port_type
					  from	device_type_phys_port_templt
					 where  device_type_id = v_dt_id
					  and	port_type = v_pt
				;
			end if;
		end if;
	END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-------------------------------------------------------------------
-- connect to layer1 devices
-------------------------------------------------------------------
--
--
CREATE OR REPLACE FUNCTION port_utils.configure_layer1_connect (
	physportid1	physical_port.physical_port_id%type,
	physportid2	physical_port.physical_port_id%type,
	baud		layer1_connection.baud%type			DEFAULT -99,
	data_bits	layer1_connection.data_bits%type	DEFAULT -99,
	stop_bits	layer1_connection.stop_bits%type	DEFAULT -99,
	parity     	layer1_connection.parity%type		DEFAULT '__unknown__',
	flw_cntrl	layer1_connection.flow_control%type DEFAULT '__unknown__',
	circuit_id   	layer1_connection.circuit_id%type DEFAULT -99
) RETURNS INTEGER AS $$
DECLARE
	tally		integer;
	l1_con_id	layer1_connection.layer1_connection_id%TYPE;
	l1con		layer1_connection%ROWTYPE;
	p1_l1_con	layer1_connection%ROWTYPE;
	p2_l1_con	layer1_connection%ROWTYPE;
	p1_port		physical_port%ROWTYPE;
	p2_port		physical_port%ROWTYPE;
	col_nams	varchar(100) [];
	col_vals	varchar(100) [];
	updateitr	integer;
	i_baud		layer1_connection.baud%type;
	i_data_bits	layer1_connection.data_bits%type;
	i_stop_bits	layer1_connection.stop_bits%type;
	i_parity     	layer1_connection.parity%type;
	i_flw_cntrl	layer1_connection.flow_control%type;
	i_circuit_id layer1_connection.circuit_id%type;
BEGIN
	RAISE DEBUG 'looking up % and %', physportid1, physportid2;

	RAISE DEBUG 'min args %:%:% <--', physportid1, physportid2, circuit_id;

	-- First make sure the physical ports exist
	BEGIN
		select	*
		  into	p1_port
		  from	physical_port
		 where	physical_port_id = physportid1;

		select	*
		  into	p2_port
		  from	physical_port
		 where	physical_port_id = physportid2;
	EXCEPTION WHEN no_data_found THEN
		RAISE EXCEPTION 'Two physical ports must be specified'
			USING ERRCODE = -20100;
	END;

	if p1_port.port_type <> p2_port.port_type then
		RAISE EXCEPTION 'Port Types Must match' USING ERRCODE = -20101;
	end if;

	-- see if existing layer1_connection exists
	-- [XXX] probably want to pull out into a cursor
	BEGIN
		select	*
		  into	p1_l1_con
		  from	layer1_connection
		 where	physical_port1_id = physportid1
		    or  physical_port2_id = physportid1;
	EXCEPTION WHEN no_data_found THEN
		NULL;
	END;
	BEGIN
		select	*
		  into	p2_l1_con
		  from	layer1_connection
		 where	physical_port1_id = physportid2
		    or  physical_port2_id = physportid2;
	
	EXCEPTION WHEN no_data_found THEN
		NULL;
	END;

	updateitr := 0;

	--		need to figure out which ports to reset in some cases
	--		need to check as many combinations as possible.
	--		need to deal with new ids.

	--
	-- If a connection already exists, figure out the right one
	-- If there are two, then remove one.  Favor ones where the left
	-- is this port.
	--
	-- Also falling out of this will be the port needs to be updated,
	-- assuming a port needs to be updated
	--
	RAISE DEBUG 'one is %, the other is %', p1_l1_con.layer1_connection_id,
		p2_l1_con.layer1_connection_id;
	if (p1_l1_con.layer1_connection_id is not NULL) then
		if (p2_l1_con.layer1_connection_id is not NULL) then
			if (p1_l1_con.physical_port1_id = physportid1) then
				--
				-- if this is not true, then the connection already
				-- exists between these two, and layer1_params need to
				-- be set later.  If they are already connected,
				-- this gets discovered here
				--
				if(p1_l1_con.physical_port2_id != physportid2) then
					--
					-- physport1 is connected to something, just not this
					--
					RAISE DEBUG 'physport1 is connected to something, just not this';
					l1_con_id := p1_l1_con.layer1_connection_id;
					--
					-- physport2 is connected to something, which needs to go away, so make it go away
					--
					if(p2_l1_con.layer1_connection_id is not NULL) then
						RAISE DEBUG 'physport2 is connected to something, just not this';
						RAISE DEBUG '>>>> removing %', 
							p2_l1_con.layer1_connection_id;
						delete from layer1_connection
							where layer1_connection_id =
								p2_l1_con.layer1_connection_id;
					end if;
				else
					l1_con_id := p1_l1_con.layer1_connection_id;
					RAISE DEBUG 'they''re already connected';
				end if;
			elsif (p1_l1_con.physical_port2_id = physportid1) then
				RAISE DEBUG '>>> connection is backwards!';
				if (p1_l1_con.physical_port1_id != physportid2) then
					if (p2_l1_con.physical_port1_id = physportid1) then
						l1_con_id := p2_l1_con.layer1_connection_id;
						RAISE DEBUG '>>>>+ removing %', p1_l1_con.layer1_connection_id;
						delete from layer1_connection
							where layer1_connection_id =
								p1_l1_con.layer1_connection_id;
					else
						if (p1_l1_con.physical_port1_id = physportid1) then
							l1_con_id := p1_l1_con.layer1_connection_id;
						else
							-- p1_l1_con.physical_port2_id must be physportid1
							l1_con_id := p1_l1_con.layer1_connection_id;
						end if;
						RAISE DEBUG '>>>>- removing %', p2_l1_con.layer1_connection_id;
						delete from layer1_connection
							where layer1_connection_id =
								p2_l1_con.layer1_connection_id;
					end if;
				else
					RAISE DEBUG 'they''re already connected, but backwards';
					l1_con_id := p1_l1_con.layer1_connection_id;
				end if;
			end if;
		else
			RAISE DEBUG 'p1 is connected, bt p2 is not';
			l1_con_id := p1_l1_con.layer1_connection_id;
		end if;
	elsif(p2_l1_con.layer1_connection_id is NULL) then
		-- both are null in this case
			
		IF (circuit_id = -99) THEN
			i_circuit_id := NULL;
		ELSE
			i_circuit_id := circuit_id;
		END IF;
		IF (baud = -99) THEN
			i_baud := NULL;
		ELSE
			i_baud := baud;
		END IF;
		IF data_bits = -99 THEN
			i_data_bits := NULL;
		ELSE
			i_data_bits := data_bits;
		END IF;
		IF stop_bits = -99 THEN
			i_stop_bits := NULL;
		ELSE
			i_stop_bits := stop_bits;
		END IF;
		IF parity = '__unknown__' THEN
			i_parity := NULL;
		ELSE
			i_parity := parity;
		END IF;
		IF flw_cntrl = '__unknown__' THEN
			i_flw_cntrl := NULL;
		ELSE
			i_flw_cntrl := flw_cntrl;
		END IF;
		IF p1_port.port_type = 'serial' THEN
		        insert into layer1_connection (
			        PHYSICAL_PORT1_ID, PHYSICAL_PORT2_ID,
			        BAUD, DATA_BITS, STOP_BITS, PARITY, FLOW_CONTROL, 
			        CIRCUIT_ID, IS_TCPSRV_ENABLED
		        ) values (
			        physportid1, physportid2,
			        i_baud, i_data_bits, i_stop_bits, i_parity, i_flw_cntrl,
			        i_circuit_id, 'Y'
		        ) RETURNING layer1_connection_id into l1_con_id;
		ELSE
		        insert into layer1_connection (
			        PHYSICAL_PORT1_ID, PHYSICAL_PORT2_ID,
			        BAUD, DATA_BITS, STOP_BITS, PARITY, FLOW_CONTROL, 
			        CIRCUIT_ID
		        ) values (
			        physportid1, physportid2,
			        i_baud, i_data_bits, i_stop_bits, i_parity, i_flw_cntrl,
			        i_circuit_id
		        ) RETURNING layer1_connection_id into l1_con_id;
		END IF;
		RAISE DEBUG 'added, l1_con_id is %', l1_con_id;
		return 1;
	else
		RAISE DEBUG 'p2 is connected but p1 is not';
		l1_con_id := p2_l1_con.layer1_connection_id;
	end if;

	RAISE DEBUG 'l1_con_id is %', l1_con_id;

	-- check to see if both ends are the same type
	-- see if they're already connected.  If not, zap the connection
	--	that doesn't match this port1/port2 config (favor first port)
	-- update various variables
	select	*
	  into	l1con
	  from	layer1_connection
	 where	layer1_connection_id = l1_con_id;

	if (l1con.PHYSICAL_PORT1_ID != physportid1 OR
			l1con.PHYSICAL_PORT2_ID != physportid2) AND
			(l1con.PHYSICAL_PORT1_ID != physportid2 OR
			l1con.PHYSICAL_PORT2_ID != physportid1)  THEN
		-- this means that one end is wrong, now we need to figure out
		-- which end.
		if(l1con.PHYSICAL_PORT1_ID = physportid1) THEN
			RAISE DEBUG 'update port2 to second port';
			updateitr := updateitr + 1;
			col_nams[updateitr] := 'PHYSICAL_PORT2_ID';
			col_vals[updateitr] := physportid2;
		elsif(l1con.PHYSICAL_PORT2_ID = physportid1) THEN
			RAISE DEBUG 'update port1 to second port';
			updateitr := updateitr + 1;
			col_nams[updateitr] := 'PHYSICAL_PORT1_ID';
			col_vals[updateitr] := physportid2;
		elsif(l1con.PHYSICAL_PORT1_ID = physportid2) THEN
			RAISE DEBUG 'update port2 to first port';
			updateitr := updateitr + 1;
			col_nams[updateitr] := 'PHYSICAL_PORT2_ID';
			col_vals[updateitr] := physportid1;
		elsif(l1con.PHYSICAL_PORT2_ID = physportid2) THEN
			RAISE DEBUG 'update port1 to first port';
			updateitr := updateitr + 1;
			col_nams[updateitr] := 'PHYSICAL_PORT1_ID';
			col_vals[updateitr] := physportid1;
		end if;
	end if;

	RAISE DEBUG 'circuit_id -- % v %', circuit_id, l1con.circuit_id;
	if(circuit_id <> -99 and (l1con.circuit_id is NULL or l1con.circuit_id <> circuit_id)) THEN
		RAISE DEBUG 'updating circuit_id';
		updateitr := updateitr + 1;
		col_nams[updateitr] := 'CIRCUIT_ID';
		col_vals[updateitr] := circuit_id;
	end if;

	RAISE DEBUG  'baud: % v %', baud, l1con.baud;
	if(baud <> -99 and (l1con.baud is NULL or l1con.baud <> baud)) THEN
		RAISE DEBUG 'updating baud';
		updateitr := updateitr + 1;
		col_nams[updateitr] := 'BAUD';
		col_vals[updateitr] := baud;
	end if;

	if(data_bits <> -99 and (l1con.data_bits is NULL or l1con.data_bits <> data_bits)) THEN
		RAISE DEBUG 'updating data_bits';
		updateitr := updateitr + 1;
		col_nams[updateitr] := 'DATA_BITS';
		col_vals[updateitr] := data_bits;
	end if;

	if(stop_bits <> -99 and (l1con.stop_bits is NULL or l1con.stop_bits <> stop_bits)) THEN
		RAISE DEBUG 'updating stop bits';
		updateitr := updateitr + 1;
		col_nams[updateitr] := 'STOP_BITS';
		col_vals[updateitr] := stop_bits;
	end if;

	if(parity <> '__unknown__' and (l1con.parity is NULL or l1con.parity <> parity)) THEN
		RAISE DEBUG 'updating parity';
		updateitr := updateitr + 1;
		col_nams[updateitr] := 'PARITY';
		col_vals[updateitr] := quote_literal(parity);
	end if;

	if(flw_cntrl <> '__unknown__' and (l1con.parity is NULL or l1con.parity <> flw_cntrl)) THEN
		RAISE DEBUG 'updating flow control';
		updateitr := updateitr + 1;
		col_nams[updateitr] := 'FLOW_CONTROL';
		col_vals[updateitr] := quote_literal(flw_cntrl);
	end if;

	if(updateitr > 0) then
		RAISE DEBUG 'running do_l1_connection_update';
		PERFORM port_support.do_l1_connection_update(col_nams, col_vals, l1_con_id);
	end if;

	RAISE DEBUG 'returning %', updateitr;
	return updateitr;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-------------------------------------------------------------------
-- connect two power devices
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION port_utils.configure_power_connect (
	in_dev1_id	device_power_connection.device_id%type,
	in_port1_id	device_power_connection.power_interface_port%type,
	in_dev2_id	device_power_connection.rpc_device_id%type,
	in_port2_id	device_power_connection.rpc_power_interface_port%type
) RETURNS void AS $$
DECLARE
	v_p1_pc		device_power_connection%ROWTYPE;
	v_p2_pc		device_power_connection%ROWTYPE;
	v_pc		device_power_connection%ROWTYPE;
	v_pc_id		device_power_connection.device_power_connection_id%type;
BEGIN
	RAISE DEBUG 'consider %:% %:%',
		in_dev1_id, in_port1_id, in_dev2_id, in_port2_id;
	-- check to see if ports are already connected
	BEGIN
		select	*
		  into	v_p1_pc
		  from	device_power_connection
		 where	(device_Id = in_dev1_id 
					and power_interface_port = in_port1_id) OR
				(rpc_device_id = in_dev1_id
					and rpc_power_interface_port = in_port1_id);
	EXCEPTION WHEN no_data_found THEN
		v_p1_pc.device_power_connection_id := NULL;
	END;

	BEGIN
		select	*
		  into	v_p2_pc
		  from	device_power_connection
		 where	(device_Id = in_dev2_id 
					and power_interface_port = in_port2_id) OR
				(rpc_device_id = in_dev2_id
					and rpc_power_interface_port = in_port2_id);
	EXCEPTION WHEN no_data_found THEN
		v_p2_pc.device_power_connection_id := NULL;
	END;

	--
	-- If a connection already exists, figure out the right one
	-- If there are two, then remove one.  Favor ones where the left
	-- is this port.
	--
	-- Also falling out of this will be the port needs to be updated,
	-- assuming a port needs to be updated
	--
	RAISE DEBUG 'one is %, the other is %', 
		v_p1_pc.device_power_connection_id, v_p2_pc.device_power_connection_id;
	IF (v_p1_pc.device_power_connection_id is not NULL) then
		IF (v_p2_pc.device_power_connection_id is not NULL) then
			IF (v_p1_pc.device_id = in_dev1_id AND v_p1_pc.power_interface_port = in_port1_id) then
				--
				-- if this is not true, then the connection already
				-- exists between these two.
				-- If they are already connected, this gets 
				-- discovered here
				--
				RAISE DEBUG '>> one side matches: %:% %:%',
						v_p1_pc.rpc_device_id, in_dev2_id,
						v_p1_pc.rpc_power_interface_port, in_port2_id;
				IF(v_p1_pc.rpc_device_id != in_dev2_id OR v_p1_pc.rpc_power_interface_port != in_port2_id) then
					--
					-- port is connected to something, just not this
					--
					RAISE DEBUG 'port1 is connected to something, just not this';
					v_pc_id := v_p1_pc.device_power_connection_id;
					--
					-- port2 is connected to something, which needs to go away, so make it go away
					--
					IF(v_p2_pc.device_power_connection_id is not NULL) then
						RAISE DEBUG 'port2 is connectedt to something, deleting it';
						RAISE DEBUG '>>>> removing(0) %',v_p2_pc.device_power_connection_id;
						delete from device_power_connection
							where device_power_connection_id =
								v_p2_pc.device_power_connection_id;
					END IF;
				ELSE
					v_pc_id := v_p1_pc.device_power_connection_id;
					RAISE DEBUG 'they are alredy connected to each other';
					-- XXX NOTE THAT THIS SHOULD NOT RETURN FOR MORE PROPERTIES TO TWEAK
					return;
				END IF;
			ELSIF (v_p1_pc.rpc_device_id = in_dev1_id AND v_p1_pc.rpc_power_interface_port = in_port1_id) then
				RAISE DEBUG '>>> connection is backwards!';
				IF(v_p1_pc.device_id != in_dev2_id OR v_p1_pc.power_interface_port != in_port2_id) then
					IF (v_p2_pc.rpc_device_id = in_dev1_id AND v_p2_pc.rpc_power_interface_port = in_port1_id) then
						v_pc_id := v_p2_pc.device_power_connection_id;
						RAISE DEBUG '>>>> removing(1) %',
							v_p1_pc.device_power_connection_id;
						delete from device_power_connection
							where device_power_connection_id =
								v_p1_pc.device_power_connection_id;
					ELSE
						IF (v_p1_pc.device_id = in_dev1_id AND v_p1_pc.power_interface_port = in_port1_id) then
							v_pc_id := v_p1_pc.device_power_connection_id;
						ELSE
							-- v_p1_pc.device_id must be port1
							v_pc_id := v_p1_pc.device_power_connection_id;
						END IF;
						RAISE DEBUG '>>>> removing(2) %', 
							v_p2_pc.device_power_connection_id;
						delete from device_power_connection
							where device_power_connection_id =
								v_p2_pc.device_power_connection_id;
					END IF;
				ELSE
					RAISE DEBUG 'already connected, but backwards.';
					v_pc_id := v_p1_pc.device_power_connection_id;
					-- XXX NOTE THAT THIS SHOULD NOT RETURN FOR MORE PROPERTIES TO TWEAK
					return;
				END IF;
			ELSE
				RAISE DEBUG 'else condition that should not have happened happened';
				return;
			END IF;
		ELSE
			RAISE DEBUG 'p1 is connected but p2 is not';
			v_pc_id := v_p1_pc.device_power_connection_id;
		END IF;
	ELSIF(v_p2_pc.device_power_connection_id is NULL) then
		-- both are null in this case, so connect 'em.
		RAISE DEBUG 'insert brand new record!';
		RAISE DEBUG 'consider %:% %:%',
			in_dev1_id, in_port1_id, in_dev2_id, in_port2_id;
		insert into device_power_connection (
			rpc_device_id,
			rpc_power_interface_port,
			power_interface_port,
			device_id
		) values (
			in_dev2_id,
			in_port2_id,
			in_port1_id,
			in_dev1_id 
		);
		RAISE DEBUG 'record is totally inserted';
		return;
	ELSE
		RAISE DEBUG 'p2 is connected, bt p1 is not (else)';
		v_pc_id := v_p2_pc.device_power_connection_id;
	END IF;

	RAISE DEBUG 'salvaging power connection %', v_pc_id;
	-- this is here instead of above so that its possible to add properties
	-- to the argument list that would also get updated the same way serial
	-- port parameters do.  Otherwise, it would make more sense to do the
	-- updates in the morass above.
	--
	select	*
	  into	v_pc
	  from	device_power_connection
	 where	device_power_connection_id = v_pc_id;

	-- XXX - need to actually figure out which part to update and upate it.
	IF v_pc.device_id = in_dev1_id AND v_pc.power_interface_port = in_port1_id THEN
		update	device_power_connection
		   set	rpc_device_id = in_dev2_id,
				rpc_power_interface_port = in_port2_id
		  where	device_power_connection_id = v_pc_id;
	ELSIF v_pc.device_id = in_dev2_id AND v_pc.power_interface_port = in_port2_id THEN
		update	device_power_connection
		   set	rpc_device_id = in_dev1_id,
				rpc_power_interface_port = in_port1_id
		  where	device_power_connection_id = v_pc_id;
	ELSIF v_pc.rpc_device_id = in_dev1_id AND v_pc.rpc_power_interface_port = in_port1_id THEN
		update	device_power_connection
		   set	device_id = in_dev2_id,
				power_interface_port = in_port2_id
		  where	device_power_connection_id = v_pc_id;
	ELSIF v_pc.rpc_device_id = in_dev2_id AND v_pc.rpc_power_interface_port = in_port2_id THEN
		update	device_power_connection
		   set	device_id = in_dev1_id,
				power_interface_port = in_port1_id
		  where	device_power_connection_id = v_pc_id;
	END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-------------------------------------------------------------------
-- setup console information (dns and whatnot)
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION port_utils.setup_conscfg_record (
	in_physportid   physical_port.physical_port_id%type,
	in_name	 	device.device_name%type,
	in_dstsvr       device.device_name%type
) RETURNS void AS $$
DECLARE
	v_zoneid	dns_domain.dns_domain_id%type;
	v_recid		dns_record.dns_record_id%type;
	v_val		dns_record.dns_value%type;
	v_isthere	boolean;
	v_dstsvr	varchar(1024);
BEGIN
	return;

	-- if we end up adopting the conscfg zone, then GC_conscfg_zone
	-- is set to a constant that should probably be grabbed from the
	-- property table.

	select	dns_domain_id
	  into	v_zoneid
	  from	dns_domain
	 where	soa_name = 'conscfg.example.com'; -- GC_conscfg_zone;

	-- to ensure cname is properly terminated
	v_val := substr(in_dstsvr, -1, 1);
	IF ( v_val != '.' )  THEN
		v_dstsvr := in_dstsvr || '.';
	ELSE
		v_dstsvr := in_dstsvr;
	END IF;

	v_isthere := true;
	BEGIN
		select	dns_record_id, dns_value
		  into	v_recid, v_val
		  from	dns_record
		 where	dns_domain_id = v_zoneid
		  and	dns_name = in_name;
	EXCEPTION WHEN no_data_found THEN
		v_isthere := false;
	END;

	if (v_isthere = true) THEN
		if( v_val != v_dstsvr) THEN
			update 	dns_record
			  set	dns_value = v_dstsvr
			 where	dns_record_id = v_recid;
		END IF;
	ELSE
		insert into dns_record (
			dns_name, dns_domain_id, dns_class, dns_type,
			dns_value
		) values (
			in_name, v_zoneid, 'IN', 'CNAME',
			v_dstsvr
		);
	END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-------------------------------------------------------------------
-- cleanup a console connection
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION port_utils.delete_conscfg_record (
	in_name	 	device.device_name%type
) RETURNS VOID AS $$
DECLARE
	v_zoneid	dns_domain.dns_domain_id%type;
BEGIN
	select	dns_domain_id
	  into	v_zoneid
	  from	dns_domain
	 where	soa_name = GC_conscfg_zone;

	delete from dns_record
	 where	dns_name = in_name
	   and	dns_domain_id = v_zoneid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- END port_utils

------------------------------------------------------------------------------
-- BEGIN create_auto_account_coll_triggers.sql
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION automated_ac() RETURNS TRIGGER AS $_$
DECLARE
	acr	VARCHAR;
	c_name VARCHAR;
	sc VARCHAR;
	ac_ids INTEGER[];
	delete_aca BOOLEAN;
	_gender VARCHAR;
	_person_company RECORD;
	acr_c_name VARCHAR;
	gender_string VARCHAR;
	_status RECORD;
BEGIN
	IF TG_OP = 'INSERT' THEN
		IF NEW.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
		PERFORM 1 FROM val_person_status WHERE NEW.account_status = person_status AND is_disabled = 'N';
		IF NOT FOUND THEN
			RETURN NEW;
		END IF;
	-- The triggers need not deal with account realms companies or sites being renamed, although we may want to revisit this later.
	ELSIF NEW.account_id != OLD.account_id THEN
		RAISE NOTICE 'This trigger does not handle changing account id';
		RETURN NEW;
	ELSIF NEW.account_realm_id != OLD.account_realm_id THEN
		RAISE NOTICE 'This trigger does not handle changing account_realm_id';
		RETURN NEW;
	ELSIF NEW.company_id != OLD.company_id THEN
		RAISE NOTICE 'This trigger does not handle changing company_id';
		RETURN NEW;
	END IF;
	ac_ids = '{-1,-1,-1,-1,-1,-1,-1}';
	SELECT account_realm_name INTO acr FROM account_realm WHERE account_realm_id = NEW.account_realm_id;
	ac_ids[0] = acct_coll_manip.get_automated_account_collection_id(acr || '_' || NEW.account_type);
	SELECT company_short_name INTO c_name FROM company WHERE company_id = NEW.company_id AND company_short_name IS NOT NULL;
	IF NOT FOUND THEN
		RAISE NOTICE 'Company short name cannot be determined from company_id % in %', NEW.company_id, TG_NAME;
	ELSE
		acr_c_name = acr || '_' || c_name;
		ac_ids[1] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || NEW.account_type);
		SELECT
			pc.*
		INTO
			_person_company
		FROM
			person_company pc
		JOIN
			account a
		USING
			(person_id)
		WHERE
			a.person_id != 0 AND account_id = NEW.account_id;
		IF FOUND THEN
			IF _person_company.is_exempt IS NOT NULL THEN
				SELECT * INTO _status FROM acct_coll_manip.person_company_flags_to_automated_ac_name(_person_company.is_exempt, 'exempt');
				-- will remove account from old account collection
				ac_ids[2] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || _status.name);
			END IF;
			SELECT * INTO _status FROM acct_coll_manip.person_company_flags_to_automated_ac_name(_person_company.is_full_time, 'full_time');
			ac_ids[3] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || _status.name);
			SELECT * INTO _status FROM acct_coll_manip.person_company_flags_to_automated_ac_name(_person_company.is_management, 'management');
			ac_ids[4] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || _status.name);
		END IF;
		SELECT
			gender
		INTO
			_gender
		FROM
			person
		JOIN
			account a
		USING
			(person_id)
		WHERE
			account_id = NEW.account_id AND a.person_id !=0 AND gender IS NOT NULL;
		IF FOUND THEN
			gender_string = acct_coll_manip.person_gender_char_to_automated_ac_name(_gender);
			IF gender_string IS NOT NULL THEN
				ac_ids[5] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || gender_string);
			END IF;
		END IF;
	END IF;
	SELECT site_code INTO sc FROM person_location WHERE person_id = NEW.person_id AND site_code IS NOT NULL;
	IF FOUND THEN
		ac_ids[6] = acct_coll_manip.get_automated_account_collection_id(acr || '_' || sc);
	END IF;
	delete_aca = 't';
	IF TG_OP = 'INSERT' THEN
		delete_aca = 'f';
	ELSE
		IF NEW.account_role != 'primary' AND NEW.account_role != OLD.account_role THEN
			-- reaching here means account must be removed from all automated account collections
			PERFORM acct_coll_manip.insert_or_delete_automated_ac('t', OLD.account_id, ac_ids);
			RETURN NEW;
		END IF;
		PERFORM 1 FROM val_person_status WHERE NEW.account_status = person_status AND is_disabled = 'N';
		IF NOT FOUND THEN
			-- reaching here means account must be removed from all automated account collections
			PERFORM acct_coll_manip.insert_or_delete_automated_ac('t', OLD.account_id, ac_ids);
			RETURN NEW;
		END IF;
		IF NEW.account_role = 'primary' AND NEW.account_role != OLD.account_role OR
			NEW.account_status != OLD.account_status THEN
			-- reaching here means there were no automated account collection for this account
			-- and this is the first time this account goes into the automated collections even though this is not SQL insert
			-- notice that NEW.account_status here is 'enabled' or similar type
			delete_aca = 'f';
		END IF;
	END IF;
	IF NOT delete_aca THEN
		-- do all inserts
		PERFORM acct_coll_manip.insert_or_delete_automated_ac('f', NEW.account_id, ac_ids);
	END IF;
	RETURN NEW;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER;
DROP TRIGGER IF EXISTS trig_automated_ac ON account;
CREATE TRIGGER trig_automated_ac AFTER INSERT OR UPDATE ON account FOR EACH ROW EXECUTE PROCEDURE automated_ac();

CREATE OR REPLACE FUNCTION automated_ac_on_person_company() RETURNS TRIGGER AS $_$
DECLARE
	ac_id INTEGER[];
	c_name VARCHAR;
	old_acr_c_name VARCHAR;
	acr_c_name VARCHAR;
	exempt_status RECORD;
	new_exempt_status RECORD;
	full_time_status RECORD;
	manager_status RECORD;
	old_r RECORD;
	r RECORD;
BEGIN
	-- at this time person_company.is_exempt column can be null.
	-- take into account of is_exempt going from null to not null
	IF (NEW.is_exempt IS NOT NULL AND OLD.is_exempt IS NOT NULL AND NEW.is_exempt = OLD.is_exempt OR NEW.is_exempt IS NULL AND OLD.is_exempt IS NULL)
		AND NEW.is_management = OLD.is_management AND NEW.is_full_time = OLD.is_full_time
		OR (NEW.person_id = 0 AND OLD.person_id = 0) THEN
		RETURN NEW;
	END IF;
	IF NEW.person_id != OLD.person_id THEN
		RAISE NOTICE 'This trigger % does not support changing person_id', TG_NAME;
		RETURN NEW;
	ELSIF NEW.company_id != OLD.company_id THEN
		RAISE NOTICE 'This trigger % does not support changing company_id', TG_NAME;
		RETURN NEW;
	END IF;
	SELECT company_short_name INTO c_name FROM company WHERE company_id = OLD.company_id AND company_short_name IS NOT NULL;
	IF NOT FOUND THEN
		RAISE NOTICE 'Company short name cannot be determined from company_id % in trigger %', OLD.company_id, TG_NAME;
		RETURN NEW;
	END IF;
	FOR old_r
		IN SELECT
			account_realm_name, account_id
		FROM
			account_realm ar
		JOIN
			account a
		USING
			(account_realm_id)
		JOIN
			val_person_status vps
		ON
			account_status = vps.person_status AND vps.is_disabled='N'
		WHERE
			a.person_id = OLD.person_id AND a.company_id = OLD.company_id
	LOOP
		old_acr_c_name = old_r.account_realm_name || '_' || c_name;
		IF coalesce(NEW.is_exempt, '') != coalesce(OLD.is_exempt, '') THEN
			IF OLD.is_exempt IS NOT NULL THEN
				SELECT * INTO exempt_status FROM acct_coll_manip.person_company_flags_to_automated_ac_name(OLD.is_exempt, 'exempt');
				DELETE FROM account_collection_account WHERE account_id = old_r.account_id
					AND account_collection_id = acct_coll_manip.get_automated_account_collection_id(old_acr_c_name || '_' || exempt_status.name);
			END IF;
		END IF;
		IF NEW.is_full_time != OLD.is_full_time THEN
			SELECT * INTO full_time_status FROM acct_coll_manip.person_company_flags_to_automated_ac_name(OLD.is_full_time, 'full_time');
			DELETE FROM account_collection_account WHERE account_id = old_r.account_id
				AND account_collection_id = acct_coll_manip.get_automated_account_collection_id(old_acr_c_name || '_' || full_time_status.name);
		END IF;
		IF NEW.is_management != OLD.is_management THEN
			SELECT * INTO manager_status FROM acct_coll_manip.person_company_flags_to_automated_ac_name(OLD.is_management, 'management');
			DELETE FROM account_collection_account WHERE account_id = old_r.account_id
				AND account_collection_id = acct_coll_manip.get_automated_account_collection_id(old_acr_c_name || '_' || manager_status.name);
		END IF;
		-- looping over the same set of data.  TODO: optimize for speed
		FOR r
			IN SELECT
				account_realm_name, account_id
			FROM
				account_realm ar
			JOIN
				account a
			USING
				(account_realm_id)
			JOIN
				val_person_status vps
			ON
				account_status = vps.person_status AND vps.is_disabled='N'
			WHERE
				a.person_id = NEW.person_id AND a.company_id = NEW.company_id
		LOOP
			acr_c_name = r.account_realm_name || '_' || c_name;
			IF coalesce(NEW.is_exempt, '') != coalesce(OLD.is_exempt, '') THEN
				IF NEW.is_exempt IS NOT NULL THEN
					SELECT * INTO new_exempt_status FROM acct_coll_manip.person_company_flags_to_automated_ac_name(NEW.is_exempt, 'exempt');
					ac_id[0] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || new_exempt_status.name);
					PERFORM acct_coll_manip.insert_or_delete_automated_ac('f', r.account_id, ac_id);
				END IF;
			END IF;
			IF NEW.is_full_time != OLD.is_full_time THEN
				ac_id[0] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || full_time_status.non_name);
				PERFORM acct_coll_manip.insert_or_delete_automated_ac('f', r.account_id, ac_id);
			END IF;
			IF NEW.is_management != OLD.is_management THEN
				ac_id[0] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || manager_status.non_name);
				PERFORM acct_coll_manip.insert_or_delete_automated_ac('f', r.account_id, ac_id);
			END IF;
		END LOOP;
	END LOOP;
	RETURN NEW;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER;
DROP TRIGGER IF EXISTS trig_automated_ac ON person_company;
CREATE TRIGGER trig_automated_ac AFTER UPDATE ON person_company FOR EACH ROW EXECUTE PROCEDURE automated_ac_on_person_company();

CREATE OR REPLACE FUNCTION automated_ac_on_person() RETURNS TRIGGER AS $_$
DECLARE
	ac_id INTEGER[];
	c_name VARCHAR;
	old_c_name VARCHAR;
	old_acr_c_name VARCHAR;
	acr_c_name VARCHAR;
	gender_string VARCHAR;
	r RECORD;
	old_r RECORD;
BEGIN
	IF NEW.gender = OLD.gender OR NEW.person_id = 0 AND OLD.person_id = 0 THEN
		RETURN NEW;
	END IF;
	IF OLD.person_id != NEW.person_id THEN
		RAISE NOTICE 'This trigger % does not support changing person_id.  old person_id % new person_id %', TG_NAME, OLD.person_id, NEW.person_id;
		RETURN NEW;
	END IF;
	FOR old_r
		IN SELECT
			account_realm_name, account_id, company_id
		FROM
			account_realm ar
		JOIN
			account a
		USING
			(account_realm_id)
		JOIN
			val_person_status vps
		ON
			account_status = vps.person_status AND vps.is_disabled='N'
		WHERE
			a.person_id = OLD.person_id
	LOOP
		SELECT company_short_name INTO old_c_name FROM company WHERE company_id = old_r.company_id AND company_short_name IS NOT NULL;
		IF FOUND THEN
			old_acr_c_name = old_r.account_realm_name || '_' || old_c_name;
			gender_string = acct_coll_manip.person_gender_char_to_automated_ac_name(OLD.gender);
			IF gender_string IS NOT NULL THEN
				DELETE FROM account_collection_account WHERE account_id = old_r.account_id
					AND account_collection_id = acct_coll_manip.get_automated_account_collection_id(old_acr_c_name || '_' ||  gender_string);
			END IF;
		ELSE
			RAISE NOTICE 'Company short name cannot be determined from company_id % in %', old_r.company_id, TG_NAME;
		END IF;
		-- looping over the same set of data.  TODO: optimize for speed
		FOR r
			IN SELECT
				account_realm_name, account_id, company_id
			FROM
				account_realm ar
			JOIN
				account a
			USING
				(account_realm_id)
			JOIN
				val_person_status vps
			ON
				account_status = vps.person_status AND vps.is_disabled='N'
			WHERE
				a.person_id = NEW.person_id
		LOOP
			IF old_r.company_id = r.company_id THEN
				IF old_c_name IS NULL THEN
					RAISE NOTICE 'The new company short name is null like the old company short name. Going to the next record if there is any';
					CONTINUE;
				END IF;
				c_name = old_c_name;
			ELSE
				SELECT company_short_name INTO c_name FROM company WHERE company_id = r.company_id AND company_short_name IS NOT NULL;
				IF NOT FOUND THEN
					RAISE NOTICE 'New company short name cannot be determined from company_id % in %', r.company_id, TG_NAME;
					CONTINUE;
				END IF;
			END IF;
			acr_c_name = r.account_realm_name || '_' || c_name;
			gender_string = acct_coll_manip.person_gender_char_to_automated_ac_name(NEW.gender);
			IF gender_string IS NULL THEN
				CONTINUE;
			END IF;
			ac_id[0] = acct_coll_manip.get_automated_account_collection_id(acr_c_name || '_' || gender_string);
			PERFORM acct_coll_manip.insert_or_delete_automated_ac('f', r.account_id, ac_id);
		END LOOP;
	END LOOP;
	RETURN NEW;
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER;
DROP TRIGGER IF EXISTS trig_automated_ac ON person;
CREATE TRIGGER trig_automated_ac AFTER UPDATE ON person FOR EACH ROW EXECUTE PROCEDURE automated_ac_on_person();

CREATE OR REPLACE FUNCTION automated_realm_site_ac_pl() RETURNS TRIGGER AS $_$
DECLARE
	sc VARCHAR;
	r RECORD;
	ac_id INTEGER;
	ac_name VARCHAR;
	p_id INTEGER;
BEGIN
	IF TG_OP = 'UPDATE' THEN
		IF NEW.person_location_id != OLD.person_location_id THEN
			RAISE NOTICE 'This trigger % does not support changing person_location_id', TG_NAME;
			RETURN NEW;
		END IF;
		IF NEW.person_id IS NOT NULL AND OLD.person_id IS NOT NULL AND NEW.person_id != OLD.person_id THEN
			RAISE NOTICE 'This trigger % does not support changing person_id', TG_NAME;
			RETURN NEW;
		END IF;
		IF NEW.person_id IS NULL OR OLD.person_id IS NULL THEN
			-- setting person_id to NULL is done by 'usermgr merge'
			-- RAISE NOTICE 'This trigger % does not support null person_id', TG_NAME;
			RETURN NEW;
		END IF;
		IF NEW.site_code IS NOT NULL AND OLD.site_code IS NOT NULL AND NEW.site_code = OLD.site_code
			OR NEW.person_location_type != 'office' AND OLD.person_location_type != 'office' THEN
			RETURN NEW;
		END IF;
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

	FOR r IN SELECT account_realm_name, account_id
		FROM
			account_realm ar
		JOIN
			account a
		ON
			ar.account_realm_id=a.account_realm_id AND a.account_role = 'primary' AND a.person_id = p_id 
		JOIN
			val_person_status vps
		ON
			vps.person_status = a.account_status AND vps.is_disabled='N'
		JOIN
			site s
		ON
			s.site_code = sc AND a.company_id = s.colo_company_id
	LOOP
		IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
			ac_name = r.account_realm_name || '_' || sc;
			ac_id = acct_coll_manip.get_automated_account_collection_id( r.account_realm_name || '_' || sc );
			IF TG_OP != 'UPDATE' OR NEW.person_location_type = 'office' THEN
				PERFORM 1 FROM account_collection_account WHERE account_collection_id = ac_id AND account_id = r.account_id;
				IF NOT FOUND THEN
					INSERT INTO account_collection_account (account_collection_id, account_id) VALUES (ac_id, r.account_id);
				END IF;
			END IF;
		END IF;
		IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
			IF OLD.site_code IS NULL THEN
				CONTINUE;
			END IF;
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
END;
$_$ LANGUAGE plpgsql SECURITY DEFINER;
DROP TRIGGER IF EXISTS trig_automated_realm_site_ac_pl ON person_location;
CREATE TRIGGER trig_automated_realm_site_ac_pl AFTER DELETE OR INSERT OR UPDATE ON person_location FOR EACH ROW EXECUTE PROCEDURE automated_realm_site_ac_pl();

------------------------------------------------------------------------------
-- END create_auto_account_coll_triggers.sql
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- BEGIN 

ALTER TABLE account DROP CONSTRAINT fk_account_acct_rlm_id;
ALTER TABLE account DROP CONSTRAINT fk_account_acctrole;
ALTER TABLE account DROP CONSTRAINT fk_account_company_person;
ALTER TABLE account DROP CONSTRAINT fk_account_prsn_cmpy_acct;
ALTER TABLE account_unix_info DROP CONSTRAINT fk_acct_unx_info_ac_acct;
ALTER TABLE appaal_instance DROP CONSTRAINT fk_appaal_inst_filgrpacctcolid;
ALTER TABLE account_unix_info DROP CONSTRAINT fk_auxifo_unxgrp_acctcolid;
ALTER TABLE circuit DROP CONSTRAINT fk_circuit_aloc_companyid;
ALTER TABLE circuit DROP CONSTRAINT fk_circuit_vend_companyid;
ALTER TABLE circuit DROP CONSTRAINT fk_circuit_zloc_company_id;
ALTER TABLE company DROP CONSTRAINT fk_company_parent_company_id;
ALTER TABLE department DROP CONSTRAINT fk_dept_mgr_acct_id;
ALTER TABLE device DROP CONSTRAINT fk_dev_location_id;
ALTER TABLE device DROP CONSTRAINT fk_device_site_code;
ALTER TABLE device_type DROP CONSTRAINT fk_devtyp_company;
ALTER TABLE person DROP CONSTRAINT fk_diet_val_diet;
ALTER TABLE dns_domain DROP CONSTRAINT fk_dns_dom_dns_dom_typ;
ALTER TABLE netblock_collection DROP CONSTRAINT fk_nblk_coll_v_nblk_c_typ;
ALTER TABLE netblock DROP CONSTRAINT fk_nblk_ip_universe_id;
ALTER TABLE netblock DROP CONSTRAINT fk_netblock_company;
ALTER TABLE netblock DROP CONSTRAINT fk_netblock_nblk_typ;
ALTER TABLE operating_system DROP CONSTRAINT fk_os_company;
ALTER TABLE person_location DROP CONSTRAINT fk_persloc_persid;
ALTER TABLE person_location DROP CONSTRAINT fk_persloc_persloctyp;
ALTER TABLE person_location DROP CONSTRAINT fk_persloc_physaddrid;
ALTER TABLE person_location DROP CONSTRAINT fk_persloc_site_code;
ALTER TABLE person_company DROP CONSTRAINT fk_person_company_mgrprsn_id;
ALTER TABLE person_company DROP CONSTRAINT fk_person_company_prsncmpy_sta;
ALTER TABLE person_company DROP CONSTRAINT fk_person_company_prsncmpyrelt;
ALTER TABLE person_company DROP CONSTRAINT fk_person_company_sprprsn_id;
ALTER TABLE person_contact DROP CONSTRAINT fk_person_contact_person_id;
ALTER TABLE person_contact DROP CONSTRAINT fk_person_contact_typ_tec;
ALTER TABLE person_image DROP CONSTRAINT fk_person_image_personid;
ALTER TABLE person_note DROP CONSTRAINT fk_person_note_person_id;
ALTER TABLE physical_address DROP CONSTRAINT fk_physaddr_company_id;
ALTER TABLE physical_address DROP CONSTRAINT fk_physaddr_iso_cc;
ALTER TABLE val_property_type DROP CONSTRAINT fk_prop_typ_pv_uctyp_rst;
ALTER TABLE property DROP CONSTRAINT fk_property_acct_col;
ALTER TABLE property DROP CONSTRAINT fk_property_acctid;
ALTER TABLE property DROP CONSTRAINT fk_property_devcolid;
ALTER TABLE property DROP CONSTRAINT fk_property_dnsdomid;
ALTER TABLE property DROP CONSTRAINT fk_property_nblk_coll_id;
ALTER TABLE property DROP CONSTRAINT fk_property_osid;
ALTER TABLE property DROP CONSTRAINT fk_property_person_id;
ALTER TABLE property DROP CONSTRAINT fk_property_pv_nblkcol_id;
ALTER TABLE property DROP CONSTRAINT fk_property_pval_acct_colid;
ALTER TABLE property DROP CONSTRAINT fk_property_pval_compid;
ALTER TABLE property DROP CONSTRAINT fk_property_pval_dnsdomid;
ALTER TABLE property DROP CONSTRAINT fk_property_pval_pwdtyp;
ALTER TABLE property DROP CONSTRAINT fk_property_pval_swpkgid;
ALTER TABLE property DROP CONSTRAINT fk_property_pval_tokcolid;
ALTER TABLE property DROP CONSTRAINT fk_property_site_code;
ALTER TABLE property DROP CONSTRAINT fk_property_svcenv;
ALTER TABLE property DROP CONSTRAINT fk_property_val_prsnid;
ALTER TABLE person_contact DROP CONSTRAINT fk_prsn_cntct_prscn_loc;
ALTER TABLE person_contact DROP CONSTRAINT fk_prsn_contect_cr_cmpyid;
ALTER TABLE site DROP CONSTRAINT fk_site_colo_company_id;
ALTER TABLE site DROP CONSTRAINT fk_site_physaddr_id;
ALTER TABLE ssh_key DROP CONSTRAINT fk_ssh_key_enc_key_id;
ALTER TABLE ssh_key DROP CONSTRAINT fk_ssh_key_ssh_key_type;
ALTER TABLE val_property DROP CONSTRAINT fk_valprop_pv_actyp_rst;

ALTER TABLE ONLY account ADD CONSTRAINT fk_account_acct_rlm_id FOREIGN KEY (account_realm_id) REFERENCES account_realm(account_realm_id);
ALTER TABLE ONLY account ADD CONSTRAINT fk_account_acctrole FOREIGN KEY (account_role) REFERENCES val_account_role(account_role);
ALTER TABLE ONLY account ADD CONSTRAINT fk_account_company_person FOREIGN KEY (company_id, person_id) REFERENCES person_company(company_id, person_id);
ALTER TABLE ONLY account ADD CONSTRAINT fk_account_prsn_cmpy_acct FOREIGN KEY (person_id, company_id, account_realm_id) REFERENCES person_account_realm_company(person_id, company_id, account_realm_id);
ALTER TABLE ONLY account_unix_info ADD CONSTRAINT fk_acct_unx_info_ac_acct FOREIGN KEY (unix_group_acct_collection_id, account_id) REFERENCES account_collection_account(account_collection_id, account_id);
ALTER TABLE ONLY appaal_instance ADD CONSTRAINT fk_appaal_inst_filgrpacctcolid FOREIGN KEY (file_group_acct_collection_id) REFERENCES account_collection(account_collection_id);
ALTER TABLE ONLY account_unix_info ADD CONSTRAINT fk_auxifo_unxgrp_acctcolid FOREIGN KEY (unix_group_acct_collection_id) REFERENCES account_collection(account_collection_id);
ALTER TABLE ONLY circuit ADD CONSTRAINT fk_circuit_aloc_companyid FOREIGN KEY (aloc_lec_company_id) REFERENCES company(company_id);
ALTER TABLE ONLY circuit ADD CONSTRAINT fk_circuit_vend_companyid FOREIGN KEY (vendor_company_id) REFERENCES company(company_id);
ALTER TABLE ONLY circuit ADD CONSTRAINT fk_circuit_zloc_company_id FOREIGN KEY (zloc_lec_company_id) REFERENCES company(company_id);
ALTER TABLE ONLY company ADD CONSTRAINT fk_company_parent_company_id FOREIGN KEY (parent_company_id) REFERENCES company(company_id);
ALTER TABLE ONLY department ADD CONSTRAINT fk_dept_mgr_acct_id FOREIGN KEY (manager_account_id) REFERENCES account(account_id);
ALTER TABLE ONLY device ADD CONSTRAINT fk_dev_location_id FOREIGN KEY (location_id) REFERENCES location(location_id);
ALTER TABLE ONLY device ADD CONSTRAINT fk_device_site_code FOREIGN KEY (site_code) REFERENCES site(site_code);
ALTER TABLE ONLY device_type ADD CONSTRAINT fk_devtyp_company FOREIGN KEY (company_id) REFERENCES company(company_id);
ALTER TABLE ONLY person ADD CONSTRAINT fk_diet_val_diet FOREIGN KEY (diet) REFERENCES val_diet(diet);
ALTER TABLE ONLY dns_domain ADD CONSTRAINT fk_dns_dom_dns_dom_typ FOREIGN KEY (dns_domain_type) REFERENCES val_dns_domain_type(dns_domain_type);
ALTER TABLE ONLY netblock_collection ADD CONSTRAINT fk_nblk_coll_v_nblk_c_typ FOREIGN KEY (netblock_collection_type) REFERENCES val_netblock_collection_type(netblock_collection_type);
ALTER TABLE ONLY netblock ADD CONSTRAINT fk_nblk_ip_universe_id FOREIGN KEY (ip_universe_id) REFERENCES ip_universe(ip_universe_id);
ALTER TABLE ONLY netblock ADD CONSTRAINT fk_netblock_company FOREIGN KEY (nic_company_id) REFERENCES company(company_id);
ALTER TABLE ONLY netblock ADD CONSTRAINT fk_netblock_nblk_typ FOREIGN KEY (netblock_type) REFERENCES val_netblock_type(netblock_type);
ALTER TABLE ONLY operating_system ADD CONSTRAINT fk_os_company FOREIGN KEY (company_id) REFERENCES company(company_id);
ALTER TABLE ONLY person_location ADD CONSTRAINT fk_persloc_persid FOREIGN KEY (person_id) REFERENCES person(person_id);
ALTER TABLE ONLY person_location ADD CONSTRAINT fk_persloc_persloctyp FOREIGN KEY (person_location_type) REFERENCES val_person_location_type(person_location_type);
ALTER TABLE ONLY person_location ADD CONSTRAINT fk_persloc_physaddrid FOREIGN KEY (physical_address_id) REFERENCES physical_address(physical_address_id);
ALTER TABLE ONLY person_location ADD CONSTRAINT fk_persloc_site_code FOREIGN KEY (site_code) REFERENCES site(site_code);
ALTER TABLE ONLY person_company ADD CONSTRAINT fk_person_company_mgrprsn_id FOREIGN KEY (manager_person_id) REFERENCES person(person_id);
ALTER TABLE ONLY person_company ADD CONSTRAINT fk_person_company_prsncmpy_sta FOREIGN KEY (person_company_status) REFERENCES val_person_status(person_status);
ALTER TABLE ONLY person_company ADD CONSTRAINT fk_person_company_prsncmpyrelt FOREIGN KEY (person_company_relation) REFERENCES val_person_company_relation(person_company_relation);
ALTER TABLE ONLY person_company ADD CONSTRAINT fk_person_company_sprprsn_id FOREIGN KEY (supervisor_person_id) REFERENCES person(person_id);
ALTER TABLE ONLY person_contact ADD CONSTRAINT fk_person_contact_person_id FOREIGN KEY (person_id) REFERENCES person(person_id);
ALTER TABLE ONLY person_contact ADD CONSTRAINT fk_person_contact_typ_tec FOREIGN KEY (person_contact_technology, person_contact_type) REFERENCES val_person_contact_technology(person_contact_technology, person_contact_type);
ALTER TABLE ONLY person_image ADD CONSTRAINT fk_person_image_personid FOREIGN KEY (person_id) REFERENCES person(person_id);
ALTER TABLE ONLY person_note ADD CONSTRAINT fk_person_note_person_id FOREIGN KEY (person_id) REFERENCES person(person_id);
ALTER TABLE ONLY physical_address ADD CONSTRAINT fk_physaddr_company_id FOREIGN KEY (company_id) REFERENCES company(company_id);
ALTER TABLE ONLY physical_address ADD CONSTRAINT fk_physaddr_iso_cc FOREIGN KEY (iso_country_code) REFERENCES val_country_code(iso_country_code);
ALTER TABLE ONLY val_property_type ADD CONSTRAINT fk_prop_typ_pv_uctyp_rst FOREIGN KEY (prop_val_acct_coll_type_rstrct) REFERENCES val_account_collection_type(account_collection_type);
ALTER TABLE ONLY property ADD CONSTRAINT fk_property_acct_col FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);
ALTER TABLE ONLY property ADD CONSTRAINT fk_property_acctid FOREIGN KEY (account_id) REFERENCES account(account_id);
ALTER TABLE ONLY property ADD CONSTRAINT fk_property_devcolid FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);
ALTER TABLE ONLY property ADD CONSTRAINT fk_property_dnsdomid FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);
ALTER TABLE ONLY property ADD CONSTRAINT fk_property_nblk_coll_id FOREIGN KEY (netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id);
ALTER TABLE ONLY property ADD CONSTRAINT fk_property_osid FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id);
ALTER TABLE ONLY property ADD CONSTRAINT fk_property_person_id FOREIGN KEY (person_id) REFERENCES person(person_id);
ALTER TABLE ONLY property ADD CONSTRAINT fk_property_pv_nblkcol_id FOREIGN KEY (property_value_nblk_coll_id) REFERENCES netblock_collection(netblock_collection_id);
ALTER TABLE ONLY property ADD CONSTRAINT fk_property_pval_acct_colid FOREIGN KEY (property_value_account_coll_id) REFERENCES account_collection(account_collection_id);
ALTER TABLE ONLY property ADD CONSTRAINT fk_property_pval_compid FOREIGN KEY (property_value_company_id) REFERENCES company(company_id);
ALTER TABLE ONLY property ADD CONSTRAINT fk_property_pval_dnsdomid FOREIGN KEY (property_value_dns_domain_id) REFERENCES dns_domain(dns_domain_id);
ALTER TABLE ONLY property ADD CONSTRAINT fk_property_pval_pwdtyp FOREIGN KEY (property_value_password_type) REFERENCES val_password_type(password_type);
ALTER TABLE ONLY property ADD CONSTRAINT fk_property_pval_swpkgid FOREIGN KEY (property_value_sw_package_id) REFERENCES sw_package(sw_package_id);
ALTER TABLE ONLY property ADD CONSTRAINT fk_property_pval_tokcolid FOREIGN KEY (property_value_token_col_id) REFERENCES token_collection(token_collection_id);
ALTER TABLE ONLY property ADD CONSTRAINT fk_property_site_code FOREIGN KEY (site_code) REFERENCES site(site_code);
ALTER TABLE ONLY property ADD CONSTRAINT fk_property_svcenv FOREIGN KEY (service_environment) REFERENCES val_service_environment(service_environment);
ALTER TABLE ONLY property ADD CONSTRAINT fk_property_val_prsnid FOREIGN KEY (property_value_person_id) REFERENCES person(person_id);
ALTER TABLE ONLY person_contact ADD CONSTRAINT fk_prsn_cntct_prscn_loc FOREIGN KEY (person_contact_location_type) REFERENCES val_person_contact_loc_type(person_contact_location_type);
ALTER TABLE ONLY person_contact ADD CONSTRAINT fk_prsn_contect_cr_cmpyid FOREIGN KEY (person_contact_cr_company_id) REFERENCES company(company_id);
ALTER TABLE ONLY site ADD CONSTRAINT fk_site_colo_company_id FOREIGN KEY (colo_company_id) REFERENCES company(company_id);
ALTER TABLE ONLY site ADD CONSTRAINT fk_site_physaddr_id FOREIGN KEY (physical_address_id) REFERENCES physical_address(physical_address_id);
ALTER TABLE ONLY ssh_key ADD CONSTRAINT fk_ssh_key_enc_key_id FOREIGN KEY (encryption_key_id) REFERENCES encryption_key(encryption_key_id);
ALTER TABLE ONLY ssh_key ADD CONSTRAINT fk_ssh_key_ssh_key_type FOREIGN KEY (ssh_key_type) REFERENCES val_ssh_key_type(ssh_key_type);
ALTER TABLE ONLY val_property ADD CONSTRAINT fk_valprop_pv_actyp_rst FOREIGN KEY (prop_val_acct_coll_type_rstrct) REFERENCES val_account_collection_type(account_collection_type);

-- alter table val_property drop constraint r_425;
alter table val_service_environment drop constraint r_429;
--ALTER TABLE ONLY val_property
--    ADD CONSTRAINT FK_VAL_PROP_NBLK_COLL_TYPE FOREIGN KEY (prop_val_nblk_coll_type_rstrct) REFERENCES val_netblock_collection_type(netblock_collection_type);
ALTER TABLE ONLY val_service_environment
    ADD CONSTRAINT FK_VAL_SVCENV_PRODSTATE FOREIGN KEY (production_state) REFERENCES val_production_state(production_state);

------------------------------------------------------------------------------
-- BEGIN: validate_property to handle property_rank

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

DROP TRIGGER IF EXISTS trigger_validate_property ON Property;
CREATE TRIGGER trigger_validate_property BEFORE INSERT OR UPDATE 
	ON Property FOR EACH ROW EXECUTE PROCEDURE validate_property();


-- END: validate_property to handle property_rank
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- BEGIN: adjust the size of all audit tables to 255 characters
DO $$
DECLARE
	table_list RECORD;
BEGIN
	FOR table_list IN
		SELECT table_name
		FROM information_schema.tables
		WHERE table_schema = 'audit'
	LOOP
		EXECUTE 'alter table audit.' || table_list.table_name || ' alter column "aud#user" type varchar(255);';
	END LOOP;
END
$$;
-- END: adjust the size of all audit tables to 255 characters
------------------------------------------------------------------------------

-- put in comments that we missed

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

-- not sure what happened to this
DROP TRIGGER IF EXISTS trigger_validate_property ON Property;
CREATE TRIGGER trigger_validate_property BEFORE INSERT OR UPDATE
        ON Property FOR EACH ROW EXECUTE PROCEDURE validate_property();

----------------------------------------------------------------------------
-- BEGIN: ../ddl/views/create_v_l1_all_physical_ports.sql

-- updated at some point, this is to make the diff change so forcing an
-- update for clarity

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
-- END: ../ddl/views/create_v_l1_all_physical_ports.sql
----------------------------------------------------------------------------

-- regenerate data_ins triggers since function for generating them changed
SELECT schema_support.rebuild_audit_triggers('audit', 'jazzhands');

-- regenerate audit triggers since function for generating them changed
SELECT schema_support.rebuild_stamp_triggers('jazzhands');

GRANT select on all tables in schema jazzhands to ro_role;
GRANT insert,update,delete on all tables in schema jazzhands to iud_role;

GRANT select on all sequences in schema jazzhands to ro_role;
GRANT usage on all sequences in schema jazzhands to iud_role;

