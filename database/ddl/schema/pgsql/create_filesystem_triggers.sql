/* * Copyright (c) 2023 Todd Kover
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

\set ON_ERROR_STOP

CREATE OR REPLACE FUNCTION validate_filesystem()
RETURNS TRIGGER AS $$
BEGIN
	PERFORM property_utils.validate_filesystem(NEW);
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_filesystem ON filesystem;
CREATE CONSTRAINT TRIGGER trigger_validate_filesystem
AFTER INSERT OR UPDATE OF
	 filesystem_type, mountpoint, filesystem_label, filesystem_serial
ON filesystem
FOR EACH ROW EXECUTE PROCEDURE validate_filesystem();

----

CREATE OR REPLACE FUNCTION validate_filesystem_type()
RETURNS TRIGGER AS $$
BEGIN
	PERFORM	property_utils.validate_filesystem(f)
	FROM filesystem f
	WHERE f.filesystem_type = NEW.filesystem_type;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_filesystem_type ON val_filesystem_type;
CREATE CONSTRAINT TRIGGER trigger_validate_filesystem_type
AFTER INSERT OR UPDATE OF
	 filesystem_type, permit_mountpoint, permit_filesystem_label,
	permit_filesystem_serial
ON val_filesystem_type
FOR EACH ROW EXECUTE PROCEDURE validate_filesystem_type();
