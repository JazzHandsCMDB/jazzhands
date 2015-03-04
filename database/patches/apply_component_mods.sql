\set ON_ERROR_STOP

\echo 
\echo Installing component_utils functions
\echo
\ir ../pkg/pgsql/component_utils.sql

\echo 
\echo Applying updated component triggers
\echo
\ir ../ddl/schema/pgsql/create_component_triggers.sql

\echo 
\echo Initializing component data (component_types, slots, templates, etc)
\echo
\ir ../init/initialize_component.sql

\echo
\echo Creating component views
\echo
\ir ../ddl/views/create_v_device_slots.sql

\echo
\echo Migrating device data to components
\echo
\ir ../patches/migrate.v0.61.component.data.sql
