/*
 * Copyright (c) 2019 Todd Kover
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

---------------------------------------------------------------------------
--
-- triggers for things added in the jazzhands_legacy schema that need to be
-- removed in any case.  This is kind of icky.
--
---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION del_jazzhands_legacy_support()
RETURNS TRIGGER AS $$
DECLARE
	_dcid	device_collection.device_collection_id%type;
BEGIN

	DELETE FROM device_collection_device
	WHERE device_id  = OLD.device_id
	AND device_collection_id IN (
		SELECT device_collection_id
		FROM property
		WHERE property_type = 'JazzHandsLegacySupport'
		AND property_name IN
			('IsMonitoredDevice','ShouldConfigFetch','IsLocallyManagedDevice',
			'AutoMgmtProtocol')
	);
	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_del_jazzhands_legacy_support ON device;
CREATE TRIGGER trigger_del_jazzhands_legacy_support
	BEFORE DELETE ON device
	FOR EACH ROW
	EXECUTE PROCEDURE del_jazzhands_legacy_support();


------------------------------------------------------------------------------
