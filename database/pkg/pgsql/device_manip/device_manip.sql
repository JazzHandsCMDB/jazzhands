-- Copyright (c) 2019-2025, Matthew Ragan
-- Copyright (c) 2013-2020, Todd Kover
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

-- Create schema if it does not exist, do nothing otherwise.

DO $$
BEGIN
	PERFORM * FROM schema_support.create_schema(schema := 
		'device_manip'
	);
END;
$$;

\ir monitoring_off_in_rack.sql
\ir remove_layer3_interface.sql
\ir remove_layer3_interfaces.sql
\ir retire_device.sql
\ir retire_devices.sql
\ir retire_racks.sql
\ir set_operating_system.sql
\ir swap_device_ip_addresses.sql

REVOKE ALL ON SCHEMA device_manip FROM public;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA device_manip FROM public;

GRANT ALL ON SCHEMA device_manip TO iud_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA device_manip TO iud_role;
