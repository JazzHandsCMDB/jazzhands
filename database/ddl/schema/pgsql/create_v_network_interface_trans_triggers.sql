/*
 * Copyright (c) 2017 Todd Kover
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
CREATE OR REPLACE FUNCTION v_network_interface_trans_ins()
RETURNS TRIGGER AS $$
DECLARE
	_ni	network_interface%ROWTYPE;
BEGIN
	INSERT INTO network_interface (
                device_id, 
		network_interface_name, description, 
		parent_network_interface_id,
                parent_relation_type, physical_port_id, 
		slot_id, logical_port_id, 
		network_interface_type, is_interface_up, 
		mac_addr, should_monitor, provides_nat,
                should_manage, provides_dhcp
	) VALUES (
                NEW.device_id,
                NEW.network_interface_name, NEW.description,
                NEW.parent_network_interface_id,
                NEW.parent_relation_type, NEW.physical_port_id,
                NEW.slot_id, NEW.logical_port_id,
                NEW.network_interface_type, NEW.is_interface_up,
                NEW.mac_addr, NEW.should_monitor, NEW.provides_nat,
                NEW.should_manage, NEW.provides_dhcp
	) RETURNING * INTO _ni;

	IF NEW.netblock_id IS NOT NULL THEN
		INSERT INTO network_interface_netblock (
			network_interface_id, netblock_id
		) VALUES (
			_ni.network_interface_id, NEW.netblock_id
		);
	END IF;

	NEW.network_interface_id := _ni.network_interface_id;
	NEW.device_id := _ni.device_id;
	NEW.network_interface_name := _ni.network_interface_name;
	NEW.description := _ni.description;
	NEW.parent_network_interface_id := _ni.parent_network_interface_id;
	NEW.parent_relation_type := _ni.parent_relation_type;
	NEW.physical_port_id := _ni.physical_port_id;
	NEW.slot_id := _ni.slot_id;
	NEW.logical_port_id := _ni.logical_port_id;
	NEW.network_interface_type := _ni.network_interface_type;
	NEW.is_interface_up := _ni.is_interface_up;
	NEW.mac_addr := _ni.mac_addr;
	NEW.should_monitor := _ni.should_monitor;
	NEW.provides_nat := _ni.provides_nat;
	NEW.should_manage := _ni.should_manage;
	NEW.provides_dhcp :=_ni.provides_dhcp;
	NEW.data_ins_user :=_ni.data_ins_user;
	NEW.data_ins_date := _ni.data_ins_date;
	NEW.data_upd_user := _ni.data_upd_user;
	NEW.data_upd_date := _ni.data_upd_date;


	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_v_network_interface_trans_ins ON
	v_network_interface_trans;

CREATE TRIGGER trigger_v_network_interface_trans_ins
        INSTEAD OF INSERT ON v_network_interface_trans
        FOR EACH ROW
        EXECUTE PROCEDURE v_network_interface_trans_ins();

---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION v_network_interface_trans_del()
RETURNS TRIGGER AS $$
DECLARE
	_ni		network_interface%ROWTYPE;
BEGIN
	IF OLD.netblock_id IS NOT NULL THEN
		DELETE FROM network_interface_netblock
		WHERE network_interface_id = OLD.network_interface_id
		AND netblock_id = OLD.netblock_id;
	END IF;

	DELETE FROM network_interface
	WHERE network_interface_id = OLD.network_interface_id;

	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_v_network_interface_trans_del ON
	v_network_interface_trans;

CREATE TRIGGER trigger_v_network_interface_trans_del
        INSTEAD OF DELETE ON v_network_interface_trans
        FOR EACH ROW
        EXECUTE PROCEDURE v_network_interface_trans_del();

---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION v_network_interface_trans_upd()
RETURNS TRIGGER AS $$
DECLARE
	upd_query		TEXT[];
	_ni				network_interface%ROWTYPE;
BEGIN
	IF OLD.network_interface_id IS DISTINCT FROM NEW.network_interface_id THEN
		RAISE EXCEPTION 'May not update network_interface_id'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF OLD.netblock_id IS DISTINCT FROM NEW.netblock_id THEN
		IF OLD.netblock_id IS NULL THEN
			INSERT INTO network_interface_netblock (
				network_interface_id, netblock_id
			) VALUES (
				_ni.network_interface_id, NEW.netblock_id
			);
		ELSIF NEW.netblock_id IS NULL THEN
			DELETE FROM network_interface_netblock
			WHERE network_interface_id = OLD.network_interface_id
			AND netblock_id = OLD.netblock_id;

			WITH x AS (
				SELECT *,
				rank() OVER (PARTITION BY 
					ni.network_interface_id ORDER BY 
					nin.network_interface_rank) AS rnk
				FROM network_interface_netblock
				WHERE network_interface_id = NEW.network_interface_id
			) SELECT netblock_id
			INTO NEW.netblock_id
				FROM x
				WHERE x.rnk = 1;
		ELSE
			UPDATE network_interface_netblock
			SET netblock_id = NEW.netblock_id
			WHERE netblock_id = OLD.netblock_id
			AND network_interface_id = NEW.network_interface_id;
		END IF;
	END IF;

	DELETE FROM network_interface
	WHERE network_interface_id = OLD.network_interface_id;

	upd_query := NULL;
		IF NEW.device_id IS DISTINCT FROM OLD.device_id THEN
			upd_query := array_append(upd_query,
				'device_id = ' || quote_nullable(NEW.device_id));
		END IF;
		IF NEW.network_interface_name IS DISTINCT FROM OLD.network_interface_name THEN
			upd_query := array_append(upd_query,
				'network_interface_name = ' || quote_nullable(NEW.network_interface_name));
		END IF;
		IF NEW.description IS DISTINCT FROM OLD.description THEN
			upd_query := array_append(upd_query,
				'description = ' || quote_nullable(NEW.description));
		END IF;
		IF NEW.parent_network_interface_id IS DISTINCT FROM OLD.parent_network_interface_id THEN
			upd_query := array_append(upd_query,
				'parent_network_interface_id = ' || quote_nullable(NEW.parent_network_interface_id));
		END IF;
		IF NEW.parent_relation_type IS DISTINCT FROM OLD.parent_relation_type THEN
			upd_query := array_append(upd_query,
				'parent_relation_type = ' || quote_nullable(NEW.parent_relation_type));
		END IF;
		IF NEW.physical_port_id IS DISTINCT FROM OLD.physical_port_id THEN
			upd_query := array_append(upd_query,
				'physical_port_id = ' || quote_nullable(NEW.physical_port_id));
		END IF;
		IF NEW.slot_id IS DISTINCT FROM OLD.slot_id THEN
			upd_query := array_append(upd_query,
				'slot_id = ' || quote_nullable(NEW.slot_id));
		END IF;
		IF NEW.logical_port_id IS DISTINCT FROM OLD.logical_port_id THEN
			upd_query := array_append(upd_query,
				'logical_port_id = ' || quote_nullable(NEW.logical_port_id));
		END IF;
		IF NEW.network_interface_type IS DISTINCT FROM OLD.network_interface_type THEN
			upd_query := array_append(upd_query,
				'network_interface_type = ' || quote_nullable(NEW.network_interface_type));
		END IF;
		IF NEW.is_interface_up IS DISTINCT FROM OLD.is_interface_up THEN
			upd_query := array_append(upd_query,
				'is_interface_up = ' || quote_nullable(NEW.is_interface_Up));
		END IF;
		IF NEW.mac_addr IS DISTINCT FROM OLD.mac_addr THEN
			upd_query := array_append(upd_query,
				'mac_addr = ' || quote_nullable(NEW.mac_addr));
		END IF;
		IF NEW.should_monitor IS DISTINCT FROM OLD.should_monitor THEN
			upd_query := array_append(upd_query,
				'should_monitor = ' || quote_nullable(NEW.should_monitor));
		END IF;
		IF NEW.provides_nat IS DISTINCT FROM OLD.provides_nat THEN
			upd_query := array_append(upd_query,
				'provides_nat = ' || quote_nullable(NEW.provides_nat));
		END IF;
		IF NEW.should_manage IS DISTINCT FROM OLD.should_manage THEN
			upd_query := array_append(upd_query,
				'should_manage = ' || quote_nullable(NEW.should_manage));
		END IF;
		IF NEW.provides_dhcp IS DISTINCT FROM OLD.provides_dhcp THEN
			upd_query := array_append(upd_query,
				'provides_dhcp = ' || quote_nullable(NEW.provides_dhcp));
		END IF;

		IF upd_query IS NOT NULL THEN
			EXECUTE 'UPDATE network_interface SET ' ||
				array_to_string(upd_query, ', ') ||
				' WHERE network_interface_id = $1 RETURNING *'
			USING OLD.network_interface_id
			INTO _ni;

			NEW.device_id := _ni.device_id;
			NEW.network_interface_name := _ni.network_interface_name;
			NEW.description := _ni.description;
			NEW.parent_network_interface_id := _ni.parent_network_interface_id;
			NEW.parent_relation_type := _ni.parent_relation_type;
			NEW.physical_port_id := _ni.physical_port_id;
			NEW.slot_id := _ni.slot_id;
			NEW.logical_port_id := _ni.logical_port_id;
			NEW.network_interface_type := _ni.network_interface_type;
			NEW.is_interface_up := _ni.is_interface_up;
			NEW.mac_addr := _ni.mac_addr;
			NEW.should_monitor := _ni.should_monitor;
			NEW.provides_nat := _ni.provides_nat;
			NEW.should_manage := _ni.should_manage;
			NEW.provides_dhcp := _ni.provides_dhcp;
			NEW.data_ins_user := _ni.data_ins_user;
			NEW.data_ins_date := _ni.data_ins_date;
			NEW.data_upd_user := _ni.data_upd_user;
			NEW.data_upd_date := _ni.data_upd_date;
		END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_v_network_interface_trans_upd ON
	v_network_interface_trans;

CREATE TRIGGER trigger_v_network_interface_trans_upd
        INSTEAD OF UPDATE ON v_network_interface_trans
        FOR EACH ROW
        EXECUTE PROCEDURE v_network_interface_trans_upd();

---------------------------------------------------------------------------
