/*
 * Copyright (c) 2012-2014 Todd Kover
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

CREATE OR REPLACE FUNCTION device_power_connection_sanity() 
RETURNS TRIGGER AS $$
DECLARE
	_rpcpp	device_power_interface.provides_power%TYPE;
	_conpp	device_power_interface.provides_power%TYPE;
	_rpcpg	device_power_interface.power_plug_style%TYPE;
	_conpg	device_power_interface.power_plug_style%TYPE;
BEGIN
	SELECT	provides_power, power_plug_style
	 INTO	_rpcpp, _rpcpg
	 FROM	device_power_interface dpi
	WHERE	device_id = NEW.rpc_device_id
	  AND	power_interface_port = NEW.rpc_power_interface_port;

	SELECT	provides_power, power_plug_style
	 INTO	_conpp, _conpg
	 FROM	device_power_interface
	WHERE	device_id = NEW.device_id
	  AND	power_interface_port = NEW.power_interface_port;

	IF _rpcpg != _conpg THEN
		RAISE EXCEPTION 'Power Connection Plugs must match'
			USING ERRCODE = 'JH360';
	END IF;

	IF _rpcpp = 'N' THEN
		RAISE EXCEPTION 'RPCs must provide power'
			USING ERRCODE = 'JH362';
	END IF;

	IF _conpp = 'Y' THEN
		RAISE EXCEPTION 'Power Consumers must not provide power'
			USING ERRCODE = 'JH363';
	END IF;

	-- This will probably never happen because the previous two conditionals
	-- will catch all cases.  Its just here in case one of them goes away.
	IF _rpcpp = _conpp THEN
		RAISE EXCEPTION 'Power Connections must be between a power consumer and provider'
			USING ERRCODE = 'JH361';
	END IF;


	RETURN NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_device_power_connection_sanity 
	ON device_power_connection;
CREATE TRIGGER trigger_device_power_connection_sanity 
	BEFORE INSERT OR UPDATE 
	ON device_power_connection 
	FOR EACH ROW 
	EXECUTE PROCEDURE device_power_connection_sanity();

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION device_power_port_sanity() 
RETURNS TRIGGER AS $$
DECLARE
	_pp	integer;
BEGIN
	IF OLD.PROVIDES_POWER != NEW.PROVIDES_POWER THEN
		IF NEW.PROVIDES_POWER = 'N' THEN
			SELECT	count(*)
			 INTO	_pp
			 FROM	device_power_connection
			WHERE	rpc_device_id = NEW.device_id
			 AND	rpc_power_interface_port = NEW.power_interface_port;

			IF _pp > 0 THEN
				RAISE EXCEPTION 'Power Connections must be between a power consumer and provider'
					USING ERRCODE = 'JH361';
			END IF;
		ELSIF NEW.PROVIDES_POWER = 'Y' THEN
			SELECT	count(*)
			 INTO	_pp
			 FROM	device_power_connection
			WHERE	device_id = NEW.device_id
			 AND	power_interface_port = NEW.power_interface_port;
			IF _pp > 0 THEN
				RAISE EXCEPTION 'Power Connections must be between a power consumer and provider'
					USING ERRCODE = 'JH361';
			END IF;
		ELSE
			RAISE EXCEPTION 'This should never happen';
		END IF;
	END IF;

	IF OLD.POWER_PLUG_STYLE != NEW.POWER_PLUG_STYLE THEN
		SELECT	count(*)
		 INTO	_pp
		 FROM	device_power_connection
		WHERE	
				(device_id, power_interface_port) =
					(NEW.device_id, NEW.power_interface_port)
		  OR
				(rpc_device_id, rpc_power_interface_port) =
					(NEW.device_id, NEW.power_interface_port);
		IF _pp > 0 THEN
			RAISE EXCEPTION 'Power Connection Plugs must match'
				USING ERRCODE = 'JH360';
		END IF;
	END IF;
	RETURN NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_device_power_port_sanity 
	ON device_power_interface;
CREATE TRIGGER trigger_device_power_port_sanity 
	BEFORE UPDATE OF provides_power, power_plug_style
	ON device_power_interface 
	FOR EACH ROW 
	EXECUTE PROCEDURE device_power_port_sanity();

