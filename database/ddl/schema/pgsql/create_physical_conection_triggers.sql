/*
 * Copyright (c) 2015 Matthew Ragan
 * Copyright (c) 2012-2015 Todd Kover
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

CREATE OR REPLACE FUNCTION verify_physical_connection() RETURNS TRIGGER AS $$
BEGIN
	PERFORM 1 FROM
		physical_connection l1
		JOIN physical_connection l2 ON
			l1.slot1_id = l2.slot2_id AND
			l1.slot2_id = l2.slot1_id;
	IF FOUND THEN
		RAISE EXCEPTION 'Connection already exists in opposite direction';
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_verify_physical_connection ON physical_connection;
CREATE TRIGGER trigger_verify_physical_connection AFTER INSERT OR UPDATE
	ON physical_connection EXECUTE PROCEDURE verify_physical_connection();

