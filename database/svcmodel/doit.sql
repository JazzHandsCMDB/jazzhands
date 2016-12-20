\set ON_ERROR_STOP

rollback;
begin;

\i schema.sql
\i data.sql
\i jazzhands-db.sql
\i stab.sql
\i recursing-dns.sql
\i obs-frontend.sql
