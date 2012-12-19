--
-- $HeadURL$
-- $Id$
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
