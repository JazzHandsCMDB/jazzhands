--
-- Copyright (c) 2015 Matthew Ragan
-- All rights reserved.
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--      http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--

--
-- Insert some companies that we know we're going to need later
--
-- INSERT INTO company (
-- 	company_name
-- ) SELECT company_name FROM
-- 	unnest(ARRAY[ 
-- 		'Intel Corporation',
-- 		'Samsung',
-- 		'Inventec Corp'
-- 	]) x(company_name)
-- EXCEPT
-- 	SELECT company_name FROM company;

INSERT INTO val_component_function (component_function, description) VALUES
	('storage', 'Storage'),
	('chassis', 'Chassis'),
	('device', 'Standalone Device'),
	('virtual', 'Virtual Component');

--
-- Slot functions are also somewhat arbitrary, and exist for associating
-- valid component_properties, for displaying UI components, and for
-- validating inter_component_connection links
--
INSERT INTO val_slot_function (slot_function, description) VALUES
	('storage', 'storage connection'),
	('fan', 'fan'),
	('component_bus', 'bus connection'),
	('chassis_slot', 'chassis slot for card, node, or VC component'),
	('parallel', 'Parallel port'),
	('USB', 'USB port'),
	('IEEE1394', 'IEEE 1394/Firewire port'),
	('Thunderbolt', 'Thunderbolt port'),
	('inter_component_link', 'Proprietary inter-component connection');

--
-- Slot types are not arbitrary.  In order for a component to attach to a
-- slot, a specific linkage must exist in either
-- slot_type_permitted_component_type for internal connections (i.e. the
-- component becomes a logical sub-component of the parent) or in
-- slot_type_prmt_rem_slot_type for an external connection (i.e.
-- a connection to a separate component entirely, such as a network or
-- power connection)
--

--
-- Chassis slot types
--
INSERT INTO val_slot_physical_interface
	(slot_physical_interface_type, slot_function)
SELECT
	unnest(ARRAY[
		'sled',
		'card'
	]),
	'chassis_slot'
;

