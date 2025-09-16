-- Copyright (c) 2014-2025 Matthew Ragan
-- Copyright (c) 2019-2023 Todd M. Kover
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

DO $$
BEGIN
    PERFORM * FROM schema_support.create_schema(schema :=
        'netblock_manip'
    );
END;
$$;

\ir allocate_netblock.sql
\ir allocate_netblock_from_pool.sql
\ir create_network_range.sql
\ir delete_netblock.sql
\ir recalculate_parentage.sql
\ir remove_network_range.sql
\ir set_layer3_interface_addresses.sql
\ir update_network_range.sql
\ir validate_network_range.sql

SELECT schema_support.replay_saved_grants();

REVOKE USAGE ON SCHEMA netblock_manip FROM public;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA netblock_manip FROM public;

GRANT USAGE ON SCHEMA netblock_manip TO iud_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA netblock_manip TO iud_role;
