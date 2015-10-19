-- Copyright (c) 2015, Todd M. Kover
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

-- this is also in the approval_utils "pkg"

DO $$
DECLARE
        _tal INTEGER;
BEGIN
        select count(*)
        from pg_catalog.pg_namespace
        into _tal
        where nspname = 'approval_utils';
        IF _tal = 0 THEN
                DROP SCHEMA IF EXISTS approval_utils;
                CREATE SCHEMA approval_utils AUTHORIZATION jazzhands;
                COMMENT ON SCHEMA approval_utils IS 'part of jazzhands';
        END IF;
END;
$$;

\ir create_v_approval_matrix.sql;
\ir create_audit_views.sql;
\ir create_v_account_collection_audit_results.sql;
\ir create_v_account_collection_approval_process.sql;
