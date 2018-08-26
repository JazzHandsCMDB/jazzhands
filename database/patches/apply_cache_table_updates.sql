CREATE SCHEMA jazzhands_cache;

CREATE TABLE schema_support.cache_table (
	cache_table_schema		text	NOT NULL,
	cache_table				text	NOT NULL,
	defining_view_schema	text	NOT NULL,
	defining_view			text	NOT NULL,
	updates_enabled			boolean	NOT NULL,
	PRIMARY KEY (cache_table_schema, cache_table)
);

CREATE TABLE schema_support.cache_table_update_log (
	cache_table_schema		text	NOT NULL,
	cache_table				text	NOT NULL,
	update_timestamp		timestamp with time zone NOT NULL,
	rows_inserted			integer	NOT NULL,
	rows_deleted			integer	NOT NULL,
	forced					boolean NOT NULL
);

\ir ../ddl/schema/pgsql/create_schema_support_cache_tables.sql
\ir ../ddl/views/pgsql/create_ct_component_hier.sql
\ir ../ddl/views/pgsql/create_ct_device_components.sql

GRANT USAGE ON SCHEMA jazzhands_cache TO iud_role;
GRANT SELECT ON ALL TABLES IN SCHEMA jazzhands_cache TO iud_role;
