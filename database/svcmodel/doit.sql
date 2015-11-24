\set ON_ERROR_STOP

begin;

\i schema.sql
\i data.sql
\i jazzhands-db.sql
\i stab.sql

commit;
