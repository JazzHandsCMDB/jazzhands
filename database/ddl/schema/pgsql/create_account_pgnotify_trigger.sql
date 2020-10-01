/*
 * Copyright (c) 2016 Todd Kover
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

----------------------------------------------------------------------------
/*

When certain tables are insert/updated, this triggers something listening on
pgnotify to get a notification that the thing with that id changed and it can
do whatever it wants.

 */

CREATE OR REPLACE FUNCTION pgnotify_token_change()
RETURNS TRIGGER AS $$
BEGIN
	PERFORM pg_notify ('token_change', 'token_id=' || NEW.token_id);
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_pgnotify_token_change ON token;
CREATE TRIGGER trigger_pgnotify_token_change
	AFTER INSERT OR UPDATE
	ON token
	FOR EACH ROW
	EXECUTE PROCEDURE pgnotify_token_change();

----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION pgnotify_account_token_change()
RETURNS TRIGGER AS $$
BEGIN
	PERFORM pg_notify ('account_id', 'account_id=' || NEW.account_id);
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_pgnotify_account_token_change ON account_token;
CREATE TRIGGER trigger_pgnotify_account_token_change
	AFTER INSERT OR UPDATE
	ON account_token
	FOR EACH ROW
	EXECUTE PROCEDURE pgnotify_account_token_change();

----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION pgnotify_account_password_changes()
RETURNS TRIGGER AS $$
BEGIN
	PERFORM pg_notify ('account_password_change', 'account_id=' || NEW.account_id);
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_pgnotify_account_password_changes
	ON account_password;
CREATE TRIGGER trigger_pgnotify_account_password_changes
	AFTER INSERT OR UPDATE
	ON account_password
	FOR EACH ROW
	EXECUTE PROCEDURE pgnotify_account_password_changes();

----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION pgnotify_account_collection_account_token_changes()
RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
		PERFORM	*
		FROM	property_name_collection
				JOIN property_name_collection_property_name pcp
					USING (property_name_collection_id)
				JOIN property p
					USING (property_name, property_type)
		WHERE	p.account_collection_id = OLD.account_collection_id
		AND		property_name_collection_type = 'jazzhands-internal'
		AND		property_name_collection_name = 'notify-account_collection_account'
		;

		IF FOUND THEN
			PERFORM pg_notify('account_change', concat('account_id=', OLD.account_id));
		END IF;
	END IF;
	IF TG_OP = 'UPDATE' OR TG_OP = 'INSERT' THEN
		PERFORM	*
		FROM	property_name_collection
				JOIN property_name_collection_property_name pcp
					USING (property_name_collection_id)
				JOIN property p
					USING (property_name, property_type)
		WHERE	p.account_collection_id = NEW.account_collection_id
		AND		property_name_collection_type = 'jazzhands-internal'
		AND		property_name_collection_name = 'notify-account_collection_account'
		;

		IF FOUND THEN
			PERFORM pg_notify('account_change', concat('account_id=', NEW.account_id));
		END IF;
	END IF;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_pgnotify_account_collection_account_token_changes
	ON account_collection_account;
CREATE TRIGGER trigger_pgnotify_account_collection_account_token_changes
	AFTER INSERT OR UPDATE OR DELETE
	ON account_collection_account
	FOR EACH ROW
	EXECUTE PROCEDURE pgnotify_account_collection_account_token_changes();

----------------------------------------------------------------------------
