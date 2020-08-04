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

DO $$
BEGIN
	PERFORM * FROM val_component_function WHERE component_function = 'PDU';

	IF NOT FOUND THEN
		INSERT INTO val_component_function (component_function, description)
		VALUES
			('PDU', 'Power Distribution Unit'),
			('power_supply', 'Power Supply');

		INSERT INTO val_component_property_type (
			component_property_type, description, is_multivalue
		) VALUES 
			('PDU', 'PDU properties', true),
			('power_supply', 'power supply properties', true);

		INSERT INTO val_component_property (
			component_property_name,
			component_property_type,
			description,
			is_multivalue,
			property_data_type,
			required_component_function,
			permit_slot_type_id
		) VALUES 
			('Voltage', 'PDU', 'Outlet Voltage', false, 'number',
				'PDU', 'REQUIRED'),
			('MaxAmperage', 'PDU', 'Max Outlet Amperage', false, 'number',
				'PDU', 'REQUIRED'),
			('Wattage', 'power_supply', 'Power Supply Wattage', false, 'number',
				'power_supply', 'REQUIRED'),
			('Provides', 'power_supply', 'Provides power', false, 'boolean',
				'power_supply', 'REQUIRED');

		INSERT INTO val_slot_function (slot_function, description) VALUES
			('power', 'Provides or uses power');

		--
		-- Power slots
		--

		INSERT INTO val_slot_physical_interface
			(slot_physical_interface_type, slot_function)
		SELECT
			unnest(ARRAY[
				'IEC-60320-C13',
				'IEC-60320-C14',
				'IEC-60320-C19',
				'IEC-60320-C20',
				'NEMA 5-15P',
				'NEMA 5-15R',
				'NEMA 5-20P',
				'NEMA 5-20R',
				'NEMA 5-30P',
				'NEMA 5-30R',
				'NEMA 6-15P',
				'NEMA 6-15R',
				'NEMA 6-20P',
				'NEMA 6-20R',
				'NEMA 6-30P',
				'NEMA 6-30R',
				'NEMA 6-50P',
				'NEMA 6-50R',
				'NEMA L14-30P',
				'NEMA L14-30R',
				'NEMA L15-30P',
				'NEMA L15-30R',
				'NEMA L21-30P',
				'NEMA L21-30R',
				'NEMA L5-15P',
				'NEMA L5-15R',
				'NEMA L5-20P',
				'NEMA L5-20R',
				'NEMA L5-30P',
				'NEMA L5-30R',
				'NEMA L6-15P',
				'NEMA L6-15R',
				'NEMA L6-20P',
				'NEMA L6-20R',
				'NEMA L6-30P',
				'NEMA L6-30R',
				'Hubbell CS8364C',
				'Hubbell CS8365C'
			]),
			'power'
		;


		--
		-- Power slot types will be inserted on the fly, I think, because of the
		-- sheer number of combinations that can exist
		--
	END IF;
END; $$ language plpgsql;
