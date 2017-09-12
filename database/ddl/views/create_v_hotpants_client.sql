-- Copyright (c) 2016, Todd M. Kover
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

-- This likely needs to die in favor of making hotpants less aware of device
-- collection

CREATE OR REPLACE VIEW v_hotpants_client AS
SELECT 
                device_id,
                device_name,
		ip_address,
		p.property_value as radius_secret
            FROM    v_property p
                    INNER JOIN v_device_coll_device_expanded dc
                        USING (device_collection_id)
                    INNER JOIN device d USING (device_id)
                    INNER JOIN network_interface_netblock ni USING (device_id)
                    INNER JOIN netblock USING (netblock_id)
            WHERE     property_name = 'RadiusSharedSecret'
            AND     property_type = 'HOTPants';

