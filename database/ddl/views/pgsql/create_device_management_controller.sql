
-- Copyright (c) 2022, Todd M. Kover
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
--
-- $Id$
--

-- to be retired

CREATE OR REPLACE VIEW device_management_controller AS
SELECT
        manager_device_id,
        device_id,
        component_management_controller_type AS device_management_control_type,
        description,
        data_ins_user,
        data_ins_date,
        data_upd_user,
        data_upd_date
FROM jazzhands.component_management_controller c
        JOIN (SELECT device_id, component_id FROM jazzhands.device) d
                USING (component_id)
        JOIN (SELECT device_id AS manager_device_id,
                        component_id AS manager_component_id
                        FROM jazzhands.device) md
                USING (manager_component_id)
;
