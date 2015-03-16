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
	PERFORM * FROM val_slot_function WHERE slot_function = 'serial';

	IF NOT FOUND THEN
		INSERT INTO val_slot_function (slot_function, description) VALUES
			('serial', 'Serial port');

		--
		-- Serial slot types
		--
		INSERT INTO val_slot_physical_interface
			(slot_physical_interface_type, slot_function)
		SELECT
			unnest(ARRAY[
				'RJ45',
				'DB9-M',
				'DB9-F',
				'DB25-M',
				'DB25-F',
				'virtual'
			]),
			'serial';

		INSERT INTO slot_type 
			(slot_type, slot_physical_interface_type, slot_function,
			 description, remote_slot_permitted)
		VALUES
			('RJ45 serial', 'RJ45', 'serial', 'RJ45 serial port', 'Y'),
			('DB9-F serial', 'DB9-F', 'serial', 'DB9 serial port', 'Y'),
			('DB9-M serial', 'DB9-M', 'serial', 'DB9 serial port', 'Y'),
			('DB25-F serial', 'DB25-F', 'serial', 'RJ45 serial port', 'Y'),
			('DB25-M serial', 'DB25-M', 'serial', 'RJ45 serial port', 'Y'),
			('virtual serial', 'virtual', 'serial', 'virtual serial port', 'Y');
	END IF;
END $$ language plpgsql
