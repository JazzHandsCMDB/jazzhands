\set ON_ERROR_STOP
rollback;
begin;
\i schema.sql
\i data.sql
COMMIT;
