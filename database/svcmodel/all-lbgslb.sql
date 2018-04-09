rollback;
begin;
\set ON_ERROR_STOP
\set ECHO queries

--
-- This is because gslb_group needs to be done before lb pools
-- gslb_name as well although that adds some complexities.
--
DO $$
DECLARE
        myrole  TEXT;
        _t              INTEGER;
BEGIN
	SELECT current_role INTO myrole;
	SET role = dba;

	ALTER SEQUENCE jazzhands.service_endpoint_provider_col_service_endpoint_provider_col_seq
		RESTART WITH 5000;

	ALTER SEQUENCE jazzhands.service_endpoint_service_endpoint_id_seq
		RESTART WITH 5000;

	EXECUTE 'SET role ' || myrole;
END;
$$;

savepoint lb;

\ir lbpool.sql
\ir gslb.sql
