/*
 * Copyright (c) 2023 Todd Kover
 * All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

--
-- These triggers enforce that things that are direct to host can't become
-- accidentaly not direct to host.  It's possible, even probable that these
-- should be folded into other triggers, but due to time constraints did not
-- want to do that now.
--

\set ON_ERROR_STOP

CREATE OR REPLACE FUNCTION block_storage_device_checks()
RETURNS TRIGGER AS $$
BEGIN

	PERFORM property_utils.validate_block_storage_device(NEW);
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_block_storage_device_checks
	ON block_storage_device;
CREATE CONSTRAINT TRIGGER trigger_block_storage_device_checks
	AFTER INSERT OR UPDATE
	ON block_storage_device
	DEFERRABLE FOR EACH ROW
	EXECUTE PROCEDURE block_storage_device_checks();

-----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION val_block_storage_device_type_checks()
RETURNS TRIGGER AS $$
BEGIN
	PERFORM property_utils.validate_val_block_storage_device_type(n)
		FROM block_storage_device n
		WHERE n.block_storage_device_type = NEW.block_storage_device_type;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_block_storage_device_type_checks
	ON val_block_storage_device_type;
CREATE CONSTRAINT TRIGGER trigger_val_block_storage_device_type_checks
	AFTER UPDATE 
	ON val_block_storage_device_type
	DEFERRABLE FOR EACH ROW
	EXECUTE PROCEDURE val_block_storage_device_type_checks();

-----------------------------------------------------------------------------
