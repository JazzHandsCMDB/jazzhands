-- Copyright (c) 2019, Matthew Ragan
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--       http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.


CREATE OR REPLACE FUNCTION layer3_network_validate_netblock()
RETURNS TRIGGER AS $$
DECLARE
	nb	jazzhands.netblock%ROWTYPE;
BEGIN
	IF
		NEW.netblock_id IS NOT NULL AND (
			TG_OP = 'INSERT' OR
			(NEW.netblock_id IS DISTINCT FROM OLD.netblock_id)
		)
	THEN
		SELECT
			* INTO nb
		FROM
			netblock n
		WHERE
			n.netblock_id = NEW.netblock_id;

		IF FOUND THEN
			IF
				nb.can_subnet = true OR
				nb.is_single_address = true
			THEN
				RAISE 'Netblock % (%) assigned to layer3_network % must not be subnettable or a single address',
					nb.netblock_id,
					nb.ip_address,
					NEW.layer3_network_id
				USING ERRCODE = 'JH111';
			END IF;
		END IF;
	END IF;
	RETURN NEW;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=jazzhands;

DROP TRIGGER IF EXISTS trigger_layer3_network_validate_netblock
	 ON layer3_network;
CREATE CONSTRAINT TRIGGER trigger_layer3_network_validate_netblock
	AFTER INSERT OR UPDATE OF netblock_id
	ON layer3_network
	FOR EACH ROW
	EXECUTE PROCEDURE layer3_network_validate_netblock();


CREATE OR REPLACE FUNCTION netblock_validate_layer3_network_netblock()
RETURNS TRIGGER AS $$
DECLARE
	l3	jazzhands.layer3_network%ROWTYPE;
BEGIN
	IF NEW.can_subnet = true OR NEW.is_single_address = 'Y' THEN
		SELECT
			* INTO l3
		FROM
			layer3_network l3n
		WHERE
			l3n.netblock_id = NEW.netblock_id;
	
		IF FOUND THEN
			RAISE 'Netblock % (%) assigned to layer3_network % must not be subnettable or a single address',
				NEW.netblock_id,
				NEW.ip_address,
				l3.layer3_network_id
			USING ERRCODE = 'JH111';
		END IF;
	END IF;
	RETURN NEW;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=jazzhands;

DROP TRIGGER IF EXISTS trigger_netblock_validate_layer3_network_netblock
	 ON netblock;
CREATE CONSTRAINT TRIGGER trigger_netblock_validate_layer3_network_netblock
	AFTER UPDATE OF can_subnet,is_single_address
	ON netblock
	FOR EACH ROW
	EXECUTE PROCEDURE netblock_validate_layer3_network_netblock();
