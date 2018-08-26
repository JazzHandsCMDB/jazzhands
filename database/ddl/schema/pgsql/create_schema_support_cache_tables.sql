-- Copyright (c) 2018, Matthew Ragan
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

----------------------------------------------------------------------------
-- BEGIN cache table support
----------------------------------------------------------------------------
--
-- 
-- These functions are used to better automate creating and manipulating
-- cache tables.  Cache tables are conceptually very similar to materialized
-- views, except the theory is that triggers on the base tables will keep
-- the views updated.  The functions here ensure that things stay
-- synchronized when those triggers fail to DTRT, and also to set up and
-- manage the cache tables from the underlying views
-- 
-- The schema_support.cache_table table contains a list of the cache
-- tables and underlying views, and an updates_enabled boolean which
-- controls whether or not calling the schema_support.refresh_cache_tables()
-- function without specifying a cache table will regenerate that entry
-- 
-- The schema_support.cache_table_update_log will contain rows where
-- schema_support.refresh_cache_tables() updated any rows, or if the forced
-- flag was passed.  A log entry is not generated if no actions are performed
-- unless the forced parameter is set to true.
-- 

CREATE OR REPLACE FUNCTION schema_support.create_cache_table (
	cache_table_schema		text,
	cache_table				text,
	defining_view_schema	text,
	defining_view			text,
	force					BOOLEAN DEFAULT false
) RETURNS void AS $$
DECLARE
	param_cache_table_schema	ALIAS FOR cache_table_schema;
	param_cache_table			ALIAS FOR cache_table;
	param_defining_view_schema	ALIAS FOR defining_view_schema;
	param_defining_view			ALIAS FOR defining_view;
	ct_rec						RECORD;
BEGIN
	--
	-- Ensure that the defining view exists
	--
	PERFORM *
	FROM
		information_schema.views
	WHERE
		table_schema = defining_view_schema AND
		table_name = defining_view;
	
	IF NOT FOUND THEN
		RAISE 'view %.% does not exist',
			defining_view_schema,
			defining_view
			USING ERRCODE = 'foreign_key_violation';
	END IF;

	--
	-- Verify that the cache table does not exist, or if it does that
	-- we have an entry for it in schema_support.cache_table and
	-- force is being passed.
	--

	PERFORM *
	FROM
		information_schema.tables
	WHERE
		table_schema = cache_table_schema AND
		table_name = cache_table;
	
	IF FOUND THEN
		IF NOT force THEN
			RAISE 'cache table %.% already exists',
				cache_table_schema,
				cache_table
				USING ERRCODE = 'unique_violation';
		END IF;

		PERFORM *
		FROM
			schema_support.cache_table ct
		WHERE
			ct.cache_table_schema = param_cache_table_schema AND
			ct.cache_table = param_cache_table;

		IF NOT FOUND THEN
			RAISE '%', concat(
				'cache table ', cache_table_schema, '.', cache_table,
				' already exists, but there is no tracking ',
				'information for it in schema_support.cache_table.  ',
				'This must be corrected manually.')
				USING ERRCODE = 'unique_violation';
		END IF;

		PERFORM schema_support.save_grants_for_replay(
			cache_table_schema, cache_table
		);

		EXECUTE 'DROP TABLE '
			|| quote_ident(cache_table_schema) || '.'
			|| quote_ident(cache_table);
	END IF;

	SELECT * INTO ct_rec
	FROM
		schema_support.cache_table ct
	WHERE
		ct.cache_table_schema = param_cache_table_schema AND
		ct.cache_table = param_cache_table;

	IF NOT FOUND THEN
		INSERT INTO schema_support.cache_table(
			cache_table_schema,
			cache_table,
			defining_view_schema,
			defining_view,
			updates_enabled
		) VALUES (
			param_cache_table_schema,
			param_cache_table,
			param_defining_view_schema,
			param_defining_view,
			'true'
		);
	END IF;

	EXECUTE format('CREATE TABLE %I.%I AS SELECT * FROM %I.%I',
		cache_table_schema,
		cache_table,
		defining_view_schema,
		defining_view
	);
END
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path=schema_support;

CREATE OR REPLACE FUNCTION schema_support.synchronize_cache_tables (
	cache_table_schema		text DEFAULT NULL,
	cache_table				text DEFAULT NULL
) RETURNS void AS $$
DECLARE
	ct_rec			RECORD;
	query			text;
	inserted_rows	integer;
	deleted_rows	integer;
BEGIN
	IF cache_table_schema IS NULL THEN
		IF cache_table IS NOT NULL THEN
			RAISE 'Must specify cache_table_schema if cache_table is passed'
				USING ERRCODE = 'null_value_not_allowed';
		END IF;
		query := '
			SELECT
				*
			FROM
				schema_support.cache_table
			WHERE
				updates_enabled = true
			';
	ELSE
		IF cache_table IS NOT NULL THEN
			query := format($query$
				SELECT
					*
				FROM
					schema_support.cache_table
				WHERE
					quote_ident(cache_table_schema) = '%I' AND
					quote_ident(cache_table) = '%I'
				$query$,
				cache_table_schema,
				cache_table
			);
		ELSE
			query := format($query$
				SELECT
					*
				FROM
					schema_support.cache_table
				WHERE
					quote_ident(cache_table_schema) = '%I' AND
					updates_enabled = true
				$query$,
				cache_table_schema
			);
		END IF;
	END IF;
	FOR ct_rec IN EXECUTE query LOOP
		RAISE DEBUG 'Processing %.%',
			quote_ident(ct_rec.cache_table_schema),
			quote_ident(ct_rec.cache_table);
			
		--
		-- Insert rows that exist in the view that do not exist in the cache
		-- table
		--
		query := format($query$
			INSERT INTO %I.%I
			SELECT * FROM %I.%I z
			WHERE
				(z) IN 
				(
					SELECT (x) FROM 
					(
						SELECT * FROM %I.%I EXCEPT
						SELECT * FROM %I.%I
					) x
				)
			$query$,
			ct_rec.cache_table_schema,
			ct_rec.cache_table,
			ct_rec.defining_view_schema,
			ct_rec.defining_view,
			ct_rec.defining_view_schema,
			ct_rec.defining_view,
			ct_rec.cache_table_schema,
			ct_rec.cache_table
		);
		RAISE DEBUG E'Executing:\n%\n', query;
		EXECUTE query;
		GET DIAGNOSTICS inserted_rows := ROW_COUNT;

		--
		-- Delete rows that exist in the cache table that do not exist in the
		-- defining view
		--
		query := format($query$
			DELETE FROM %I.%I z
			WHERE
				(z) IN 
				(
					SELECT (x) FROM 
					(
						SELECT * FROM %I.%I EXCEPT
						SELECT * FROM %I.%I
					) x
				)
			$query$,
			ct_rec.cache_table_schema,
			ct_rec.cache_table,
			ct_rec.cache_table_schema,
			ct_rec.cache_table,
			ct_rec.defining_view_schema,
			ct_rec.defining_view
		);
		RAISE DEBUG E'Executing:\n%\n', query;
		EXECUTE query;
		GET DIAGNOSTICS deleted_rows := ROW_COUNT;

		IF (inserted_rows > 0 OR deleted_rows > 0) THEN
			INSERT INTO schema_support.cache_table_update_log (
				cache_table_schema,
				cache_table,
				update_timestamp,
				rows_inserted,
				rows_deleted,
				forced
			) VALUES (
				ct_rec.cache_table_schema,
				ct_rec.cache_table,
				current_timestamp,
				inserted_rows,
				deleted_rows,
				false
			);
		END IF;
	END LOOP;
END
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path=schema_support;

----------------------------------------------------------------------------
-- END cache table support
----------------------------------------------------------------------------
