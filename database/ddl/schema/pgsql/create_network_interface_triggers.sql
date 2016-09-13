/*
 * Copyright (c) 2014 Todd Kover
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
		AND is_single_address = 'Y'
		AND netblock_type = 'default';

		IF _tally = 0 THEN
			RAISE EXCEPTION 'network interfaces must refer to single ip addresses of type default (%,%)', NEW.network_interface_id, NEW.netblock_id
				USING errcode = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_net_int_nb_single_address ON network_interface;
CREATE TRIGGER trigger_net_int_nb_single_address
	BEFORE INSERT OR UPDATE OF netblock_id
	ON network_interface
	FOR EACH ROW
	EXECUTE PROCEDURE net_int_nb_single_address();

---------------------------------------------------------------------------
-- Transition triggers
---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION net_int_netblock_to_nbn_compat_before()
RETURNS TRIGGER AS $$
DECLARE
	_tally	INTEGER;
BEGIN
	SET CONSTRAINTS FK_NETINT_NB_NETINT_ID DEFERRED;
	SET CONSTRAINTS FK_NETINT_NB_NBLK_ID DEFERRED;

	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_net_int_netblock_to_nbn_compat_before
ON network_interface;
CREATE TRIGGER trigger_net_int_netblock_to_nbn_compat_before
	BEFORE DELETE
	ON network_interface
	FOR EACH ROW
	EXECUTE PROCEDURE net_int_netblock_to_nbn_compat_before();

CREATE OR REPLACE FUNCTION net_int_netblock_to_nbn_compat_after()
RETURNS TRIGGER AS $$
DECLARE
	_tally	INTEGER;
BEGIN
	SELECT  count(*)
	  INTO  _tally
	  FROM  pg_catalog.pg_class
	 WHERE  relname = '__network_interface_netblocks'
	   AND  relpersistence = 't';

	IF _tally = 0 THEN
		CREATE TEMPORARY TABLE IF NOT EXISTS __network_interface_netblocks (
			network_interface_id INTEGER, netblock_id INTEGER
		);
	END IF;

	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
		SELECT count(*) INTO _tally FROM __network_interface_netblocks
		WHERE network_interface_id = NEW.network_interface_id
		AND netblock_id IS NOT DISTINCT FROM ( NEW.netblock_id );
		if _tally >  0 THEN
			RETURN NEW;
		END IF;
		INSERT INTO __network_interface_netblocks
			(network_interface_id, netblock_id)
		VALUES (NEW.network_interface_id,NEW.netblock_id);
	ELSIF TG_OP = 'DELETE' THEN
		SELECT count(*) INTO _tally FROM __network_interface_netblocks
		WHERE network_interface_id = OLD.network_interface_id
		AND netblock_id IS NOT DISTINCT FROM ( OLD.netblock_id );
		if _tally >  0 THEN
			RETURN OLD;
		END IF;
		INSERT INTO __network_interface_netblocks
			(network_interface_id, netblock_id)
		VALUES (OLD.network_interface_id,OLD.netblock_id);
	END IF;

	IF TG_OP = 'INSERT' THEN
		IF NEW.netblock_id IS NOT NULL THEN
			SELECT COUNT(*)
			INTO _tally
			FROM	network_interface_netblock
			WHERE	network_interface_id = NEW.network_interface_id
			AND		netblock_id = NEW.netblock_id;

			IF _tally = 0 THEN
				SELECT COUNT(*)
				INTO _tally
				FROM	network_interface_netblock
				WHERE	network_interface_id != NEW.network_interface_id
				AND		netblock_id = NEW.netblock_id;

				IF _tally != 0  THEN
					UPDATE network_interface_netblock
					SET network_interface_id = NEW.network_interface_id
					WHERE netblock_id = NEW.netblock_id;
				ELSE
					INSERT INTO network_interface_netblock
						(network_interface_id, netblock_id)
					VALUES
						(NEW.network_interface_id, NEW.netblock_id);
				END IF;
			END IF;
		END IF;
	ELSIF TG_OP = 'UPDATE'  THEN
		IF OLD.netblock_id is NULL and NEW.netblock_ID is NOT NULL THEN
			SELECT COUNT(*)
			INTO _tally
			FROM	network_interface_netblock
			WHERE	network_interface_id = NEW.network_interface_id
			AND		netblock_id = NEW.netblock_id;

			IF _tally = 0 THEN
				INSERT INTO network_interface_netblock
					(network_interface_id, netblock_id)
				VALUES
					(NEW.network_interface_id, NEW.netblock_id);
			END IF;
		ELSIF OLD.netblock_id IS NOT NULL and NEW.netblock_id is NOT NULL THEN
			IF OLD.netblock_id != NEW.netblock_id THEN
				UPDATE network_interface_netblock
					SET network_interface_id = NEW.network_interface_Id,
						netblock_id = NEW.netblock_id
						WHERE network_interface_id = OLD.network_interface_id
						AND netblock_id = OLD.netblock_id
						AND netblock_id != NEW.netblock_id
				;
			END IF;
		END IF;
	ELSIF TG_OP = 'DELETE' THEN
		IF OLD.netblock_id IS NOT NULL THEN
			DELETE from network_interface_netblock
				WHERE network_interface_id = OLD.network_interface_id
				AND netblock_id = OLD.netblock_id;
		END IF;
		RETURN OLD;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_net_int_netblock_to_nbn_compat_after
ON network_interface;

CREATE TRIGGER trigger_net_int_netblock_to_nbn_compat_after
	AFTER INSERT OR UPDATE OF network_interface_id, netblock_id
	ON network_interface
	FOR EACH ROW
	EXECUTE PROCEDURE net_int_netblock_to_nbn_compat_after();

DROP TRIGGER IF EXISTS trigger_net_int_netblock_to_nbn_compat_before_del
ON network_interface;
CREATE TRIGGER trigger_net_int_netblock_to_nbn_compat_before_del
	BEFORE DELETE
	ON network_interface
	FOR EACH ROW
	EXECUTE PROCEDURE net_int_netblock_to_nbn_compat_after();

---- network_interface_netblock -> network_interface
-- note that the triggers above could fired
CREATE OR REPLACE FUNCTION network_interface_netblock_to_ni()
RETURNS TRIGGER AS $$
DECLARE
	_r		network_interface_netblock%ROWTYPE;
	_rank	network_interface_netblock.network_interface_rank%TYPE;
	_tally	INTEGER;
BEGIN
	SELECT  count(*)
	  INTO  _tally
	  FROM  pg_catalog.pg_class
	 WHERE  relname = '__network_interface_netblocks'
	   AND  relpersistence = 't';

	IF _tally = 0 THEN
		CREATE TEMPORARY TABLE IF NOT EXISTS __network_interface_netblocks (
			network_interface_id INTEGER, netblock_id INTEGER
		);
	END IF;
	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
		SELECT count(*) INTO _tally FROM __network_interface_netblocks
		WHERE network_interface_id = NEW.network_interface_id
		AND netblock_id = NEW.netblock_id;
		if _tally >  0 THEN
			RETURN NEW;
		END IF;
		INSERT INTO __network_interface_netblocks
			(network_interface_id, netblock_id)
		VALUES (NEW.network_interface_id,NEW.netblock_id);
	ELSIF TG_OP = 'DELETE' THEN
		SELECT count(*) INTO _tally FROM __network_interface_netblocks
		WHERE network_interface_id = OLD.network_interface_id
		AND netblock_id = OLD.netblock_id;
		if _tally >  0 THEN
			RETURN OLD;
		END IF;
		INSERT INTO __network_interface_netblocks
			(network_interface_id, netblock_id)
		VALUES (OLD.network_interface_id,OLD.netblock_id);
	END IF;

	IF TG_OP = 'INSERT' THEN
		SELECT min(network_interface_rank), count(*)
		INTO _rank, _tally
		FROM network_interface_netblock
		WHERE network_interface_id = NEW.network_interface_id;

		IF _tally = 0 OR NEW.network_interface_rank <= _rank THEN
			UPDATE network_interface set netblock_id = NEW.netblock_id
			WHERE network_interface_id = NEW.network_interface_id
			AND netblock_id IS DISTINCT FROM (NEW.netblock_id)
			;
		END IF;
	ELSIF TG_OP = 'DELETE'  THEN
		-- if we started to disallow NULLs, just ignore this for now
		BEGIN
			UPDATE network_interface
				SET netblock_id = NULL
				WHERE network_interface_id = OLD.network_interface_id
				AND netblock_id = OLD.netblock_id;
		EXCEPTION WHEN null_value_not_allowed THEN
			RAISE DEBUG 'null_value_not_allowed';
		END;
		RETURN OLD;
	ELSIF TG_OP = 'UPDATE'  THEN
		SELECT min(network_interface_rank)
			INTO _rank
			FROM network_interface_netblock
			WHERE network_interface_id = NEW.network_interface_id;

		IF NEW.network_interface_rank <= _rank THEN
			UPDATE network_interface
				SET network_interface_id = NEW.network_interface_id,
					netblock_id = NEW.netblock_id
				WHERE network_interface_Id = OLD.network_interface_id
				AND netblock_id IS NOT DISTINCT FROM ( OLD.netblock_id );
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_network_interface_netblock_to_ni
ON network_interface_netblock;
CREATE TRIGGER trigger_network_interface_netblock_to_ni
	AFTER INSERT OR UPDATE OR DELETE
	ON network_interface_netblock
	FOR EACH ROW
	EXECUTE PROCEDURE network_interface_netblock_to_ni();

CREATE OR REPLACE FUNCTION network_interface_drop_tt()
RETURNS TRIGGER AS $$
DECLARE
	_tally INTEGER;
BEGIN
	SELECT  count(*)
	  INTO  _tally
	  FROM  pg_catalog.pg_class
	 WHERE  relname = '__network_interface_netblocks'
	   AND  relpersistence = 't';

	SET CONSTRAINTS FK_NETINT_NB_NETINT_ID IMMEDIATE;
	SET CONSTRAINTS FK_NETINT_NB_NBLK_ID IMMEDIATE;

	IF _tally > 0 THEN
		DROP TABLE IF EXISTS __network_interface_netblocks;
	END IF;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_network_interface_drop_tt_netint_nb
ON network_interface_netblock;
CREATE TRIGGER trigger_network_interface_drop_tt_netint_nb
	AFTER INSERT OR UPDATE OR DELETE
	ON network_interface_netblock
	EXECUTE PROCEDURE network_interface_drop_tt();

DROP TRIGGER IF EXISTS trigger_network_interface_drop_tt_netint_ni
ON network_interface;
CREATE TRIGGER trigger_network_interface_drop_tt_netint_ni
	AFTER INSERT OR UPDATE OR DELETE
	ON network_interface
	EXECUTE PROCEDURE network_interface_drop_tt();

---------------------------------------------------------------------------
-- End of transition triggers
---------------------------------------------------------------------------


