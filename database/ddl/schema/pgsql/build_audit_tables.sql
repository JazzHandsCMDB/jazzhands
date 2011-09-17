--
-- $Id$
--

CREATE SCHEMA audit;

CREATE OR REPLACE FUNCTION build_audit_tables() RETURNS VOID AS $FUNC$
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
		ORDER BY
			table_name
	LOOP
		name := table_list.table_name;
		EXECUTE 'CREATE SEQUENCE audit.' || quote_ident(name || '_seq');
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
	PERFORM rebuild_audit_triggers();
END;
$FUNC$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rebuild_audit_triggers() RETURNS VOID AS $$
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
					appuser := current_user || '/' || current_setting('jazzhands.appuser');
				EXCEPTION
					WHEN OTHERS THEN
						appuser := current_user;
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
			$TQ$ LANGUAGE plpgsql
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

SELECT build_audit_tables();
