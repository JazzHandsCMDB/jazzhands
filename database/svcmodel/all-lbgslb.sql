rollback;
begin;
\set ON_ERROR_STOP
\set ECHO queries

\ir lbpool.sql
\ir gslb.sql
