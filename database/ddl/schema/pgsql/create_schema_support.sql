--
-- $HeadURL$
-- $Id$
--

DROP SCHEMA IF EXISTS schema_support;
CREATE SCHEMA schema_support AUTHORIZATION jazzhands;

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
