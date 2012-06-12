/*
 * $HeadURL
 * $Id$
 */

CREATE OR REPLACE FUNCTION trigger_ins_upd_generic_func() RETURNS TRIGGER AS $$
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

CREATE OR REPLACE FUNCTION rebuild_stamp_triggers() RETURNS VOID AS $$
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

select rebuild_stamp_triggers();

