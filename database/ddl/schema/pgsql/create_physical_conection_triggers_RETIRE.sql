/*
 * Copyright (c) 2015 Todd Kover
 * Copyright (c) 2015 Matthew Ragan
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

---------------------------------------------------------------------------
-- deal with physical_port_id -> slot_id
---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION phys_conn_physical_id_to_slot_id_enforce()
RETURNS TRIGGER AS $$
DECLARE
	_tally	INTEGER;
BEGIN
	IF TG_OP = 'UPDATE' AND
		((NEW.slot1_id IS DISTINCT FROM OLD.slot1_ID AND
			NEW.physical_port1_id IS DISTINCT FROM OLD.physical_port1_id) OR
		(NEW.slot2_id IS DISTINCT FROM OLD.slot2_ID AND
			NEW.physical_port2_id IS DISTINCT FROM OLD.physical_port2_id))
	THEN
		RAISE EXCEPTION 'Only slot1_id OR slot2_id should be updated.'
			USING ERRCODE = 'integrity_constraint_violation';
	ELSIF TG_OP = 'INSERT' THEN
		IF (NEW.physical_port1_id IS NOT NULL AND NEW.slot1_id IS NOT NULL) OR
			(NEW.physical_port2_id IS NOT NULL AND NEW.slot2_id IS NOT NULL)
		THEN
			RAISE EXCEPTION 'Only slot1_id OR slot2_id should be set.'
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

	END IF;

	IF TG_OP = 'UPDATE' THEN
		IF OLD.slot1_id IS DISTINCT FROM NEW.slot1_id THEN
			NEW.physical_port1_id = NEW.slot1_id;
		ELSIF OLD.physical_port1_id IS DISTINCT FROM NEW.physical_port1_id THEN
			NEW.slot1_id = NEW.physical_port1_id;
		END IF;
		IF OLD.slot2_id IS DISTINCT FROM NEW.slot2_id THEN
			NEW.physical_port2_id = NEW.slot2_id;
		ELSIF OLD.physical_port2_id IS DISTINCT FROM NEW.physical_port2_id THEN
			NEW.slot2_id = NEW.physical_port2_id;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.slot1_id IS NOT NULL THEN
			NEW.physical_port1_id = NEW.slot_id;
		ELSIF NEW.physical_port1_id IS NOT NULL THEN
			NEW.slot1_id = NEW.physical_port1_id;
		END IF;
		IF NEW.slot2_id IS NOT NULL THEN
			NEW.physical_port2_id = NEW.slot_id;
		ELSIF NEW.physical_port2_id IS NOT NULL THEN
			NEW.slot2_id = NEW.physical_port2_id;
		END IF;
	ELSE
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_phys_conn_physical_id_to_slot_id_enforce
	ON physical_connection;
CREATE TRIGGER trigger_phys_conn_physical_id_to_slot_id_enforce
	BEFORE INSERT OR UPDATE OF physical_port1_id, slot1_id, physical_port2_id,
		slot2_id
	ON physical_connection
	FOR EACH ROW
	EXECUTE PROCEDURE phys_conn_physical_id_to_slot_id_enforce();
