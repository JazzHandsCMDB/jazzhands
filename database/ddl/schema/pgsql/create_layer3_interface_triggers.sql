/*
 * Copyright (c) 2014-2019 Todd Kover
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
CREATE OR REPLACE FUNCTION net_int_nb_single_address()
RETURNS TRIGGER AS $$
DECLARE
	_tally	INTEGER;
BEGIN
	IF NEW.netblock_id IS NOT NULL THEN
		select count(*)
		INTO _tally
		FROM netblock
		WHERE netblock_id = NEW.netblock_id
		AND is_single_address = true
		AND netblock_type = 'default';

		IF _tally = 0 THEN
			RAISE EXCEPTION 'network interfaces must refer to single ip addresses of type default (%,%)', NEW.layer3_interface_id, NEW.netblock_id
				USING errcode = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_net_int_nb_single_address ON
	layer3_interface_netblock;
CREATE TRIGGER trigger_net_int_nb_single_address
	BEFORE INSERT OR UPDATE OF netblock_id
	ON layer3_interface_netblock
	FOR EACH ROW
	EXECUTE PROCEDURE net_int_nb_single_address();

---------------------------------------------------------------------------
-- sync device_id on layer3_interface on layer3_interface_netblock changes
---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION net_int_nb_device_id_ins()
RETURNS TRIGGER AS $$
BEGIN
	SET CONSTRAINTS fk_netint_nb_nblk_id DEFERRED;
	IF NEW.device_id IS NULL OR TG_OP = 'UPDATE' THEN
		SELECT device_id
		INTO	NEW.device_id
		FROM	layer3_interface
		WHERE	layer3_interface_id = NEW.layer3_interface_id;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_net_int_nb_device_id_ins ON
	layer3_interface_netblock;
CREATE TRIGGER trigger_net_int_nb_device_id_ins
	BEFORE INSERT OR UPDATE OF layer3_interface_id
	ON layer3_interface_netblock
	FOR EACH ROW
	EXECUTE PROCEDURE net_int_nb_device_id_ins();


CREATE OR REPLACE FUNCTION net_int_nb_device_id_ins_after()
RETURNS TRIGGER AS $$
BEGIN
	SET CONSTRAINTS fk_netint_nb_nblk_id IMMEDIATE;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_net_int_nb_device_id_ins_after ON
	layer3_interface_netblock;
CREATE TRIGGER trigger_net_int_nb_device_id_ins_after
	AFTER INSERT OR UPDATE OF layer3_interface_id
	ON layer3_interface_netblock
	FOR EACH ROW
	EXECUTE PROCEDURE net_int_nb_device_id_ins_after();

------------------------------------------------------------------------------
-- sync device_id on layer3_interface_netblock on layer3_interface changes
--
-- XXX - This needs to properly handle deferring triggers if appropriate XXX
------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION net_int_nb_device_id_ins_before()
RETURNS TRIGGER AS $$
BEGIN
	SET CONSTRAINTS fk_netint_nb_nblk_id DEFERRED;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_net_int_nb_device_id_ins_before ON
	layer3_interface;
CREATE TRIGGER trigger_net_int_nb_device_id_ins_before
	BEFORE UPDATE OF device_id
	ON layer3_interface
	FOR EACH ROW
	EXECUTE PROCEDURE net_int_nb_device_id_ins_before();

CREATE OR REPLACE FUNCTION net_int_device_id_upd()
RETURNS TRIGGER AS $$
BEGIN
	UPDATE layer3_interface_netblock
	SET device_id = NEW.device_id
	WHERE	layer3_interface_id = NEW.layer3_interface_id;
	SET CONSTRAINTS fk_netint_nb_nblk_id IMMEDIATE;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_net_int_device_id_upd ON
	layer3_interface;
CREATE TRIGGER trigger_net_int_device_id_upd
	AFTER UPDATE OF device_id
	ON layer3_interface
	FOR EACH ROW
	EXECUTE PROCEDURE net_int_device_id_upd();

