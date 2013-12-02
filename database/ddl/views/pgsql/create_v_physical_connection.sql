-- Copyright (c) 2013, Todd M. Kover
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

--
-- The layer1_connection get the physical_port1/2 columns to make joining
-- a little easier.  I waffled.  -kovert
--
CREATE OR REPLACE VIEW v_physical_connection AS
with recursive var_recurse (
	level,
	layer1_connection_id,
	PHYSICAL_CONNECTION_ID,
	layer1_physical_port1_id,
	layer1_physical_port2_id,
	physical_port1_id,
	physical_port2_id
) as (
	       select 	0,
			l1.layer1_connection_id,
			pc.PHYSICAL_CONNECTION_ID,
	                l1.physical_port1_id	as layer1_physical_port1_id,
	                l1.physical_port2_id	as layer1_physical_port2_id,
	                pc.physical_port1_id,
	                pc.physical_port2_id
	          from  layer1_connection l1
	        	inner join physical_connection pc
				using (physical_port1_id)
UNION ALL
       select 	x.level + 1,
		x.layer1_connection_id,
		pc.PHYSICAL_CONNECTION_ID,
                x.physical_port1_id 	as layer1_physical_port1_id,
                x.physical_port2_id 	as layer1_physical_port2_id,
                pc.physical_port1_id,
                pc.physical_port2_id
	FROM    var_recurse x
	        inner join physical_connection pc
	                on x.physical_port2_id = pc.physical_port1_id
) select
	level,
	layer1_connection_id,
	PHYSICAL_CONNECTION_ID,
	layer1_physical_port1_id,
	layer1_physical_port2_id,
	physical_port1_id,
	physical_port2_id
from var_recurse;
