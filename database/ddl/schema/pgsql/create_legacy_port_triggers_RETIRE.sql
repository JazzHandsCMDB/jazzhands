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
CREATE OR REPLACE FUNCTION do_layer1_connection_trigger()
RETURNS TRIGGER
AS $$
BEGIN
	IF TG_OP = 'INSERT' THEN
		INSERT INTO inter_component_connection (
			inter_component_connection_id,
			slot1_id,
			slot2_id,
			circuit_id
		) VALUES (
			NEW.layer1_connection_id,
			NEW.physical_port1_id,
			NEW.physical_port2_id,
			NEW.circuit_id
		);
		RETURN NEW;
	ELSIF TG_OP = 'UPDATE' THEN
		IF (NEW.layer1_connection_id IS DISTINCT FROM
				OLD.layer1_connection_id) OR
			(NEW.physical_port1_id IS DISTINCT FROM OLD.physical_port1_id) OR
			(NEW.physical_port2_id IS DISTINCT FROM OLD.physical_port2_id) OR
			(NEW.circuit_id IS DISTINCT FROM OLD.circuit_id)
		THEN
			UPDATE inter_component_connection
			SET
				inter_component_connection_id = NEW.layer1_connection_id,
				slot1_id = NEW.physical_port1_id,
				slot2_id = NEW.physical_port2_id,
				circuit_id = NEW.circuit_id
			WHERE
				inter_component_connection_id = OLD.layer1_connection_id;
		END IF;
		RETURN NEW;
	ELSIF TG_OP = 'DELETE' THEN
		DELETE FROM inter_component_connection WHERE
			inter_component_connection_id = OLD.layer1_connection_id;
		RETURN OLD;
	END IF;
END; $$
SET search_path=jazzhands
LANGUAGE plpgsql
SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_layer1_connection_insteadof ON layer1_connection;
CREATE TRIGGER trigger_layer1_connection_insteadof
	INSTEAD OF INSERT OR UPDATE OR DELETE
	ON layer1_connection
	FOR EACH ROW EXECUTE PROCEDURE
		jazzhands.do_layer1_connection_trigger();


CREATE OR REPLACE FUNCTION do_physical_port_trigger()
RETURNS TRIGGER
AS $$
BEGIN
	IF TG_OP = 'INSERT' THEN
		RAISE EXCEPTION 'Physical ports must be inserted as component slots';
	ELSIF TG_OP = 'UPDATE' THEN
		IF (NEW.physical_port_id IS DISTINCT FROM OLD.physical_port_id) OR
			(NEW.device_id IS DISTINCT FROM OLD.device_id) OR
			(NEW.port_type IS DISTINCT FROM OLD.port_type) OR
			(NEW.port_plug_style IS DISTINCT FROM OLD.port_plug_style) OR
			(NEW.port_medium IS DISTINCT FROM OLD.port_medium) OR
			(NEW.port_protocol IS DISTINCT FROM OLD.port_protocol) OR
			(NEW.port_speed IS DISTINCT FROM OLD.port_speed) OR
			(NEW.port_purpose IS DISTINCT FROM OLD.port_purpose) OR
			(NEW.logical_port_id IS DISTINCT FROM OLD.logical_port_id) OR
			(NEW.tcp_port IS DISTINCT FROM OLD.tcp_port) OR
			(NEW.is_hardwired IS DISTINCT FROM OLD.is_hardwired)
		THEN
			RAISE EXCEPTION 'Attempted to update a deprecated physical_port attribute that must be changed on the slot now';
		END IF;
		IF (NEW.port_name IS DISTINCT FROM OLD.port_name) OR
			(NEW.description IS DISTINCT FROM OLD.description) OR
			(NEW.physical_label IS DISTINCT FROM OLD.physical_label)
		THEN
			UPDATE slot
			SET
				slot_name = NEW.port_name,
				description = NEW.description,
				physical_label = NEW.physical_label
			WHERE
				slot_id = NEW.physical_port_id;
		END IF;
		RETURN NEW;
	ELSIF TG_OP = 'DELETE' THEN
		DELETE FROM slot WHERE
			slot_id = OLD.physical_port_id;
		RETURN OLD;
	END IF;
END; $$
SET search_path=jazzhands
LANGUAGE plpgsql
SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_physical_port_insteadof ON physical_port;
CREATE TRIGGER trigger_physical_port_insteadof 
	INSTEAD OF INSERT OR UPDATE OR DELETE
	ON physical_port
	FOR EACH ROW EXECUTE PROCEDURE
		jazzhands.do_physical_port_trigger();

