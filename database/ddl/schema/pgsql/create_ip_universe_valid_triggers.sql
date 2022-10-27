-- Copyright (c) 2017 Todd Kover
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

/*
 * When updating a netblock's ip universe id, make sure that there's not a
 * dns record for that netblock in that universe.  Its *possible* thi is
 * undesired, although [future?] universe visibility mappings may also render
 * that case unneessary.  If that's the case, then these constraints could
 * be dropped, but erring on the side of data integrity for now.
 *
 */
CREATE OR REPLACE FUNCTION check_ip_universe_netblock()
RETURNS TRIGGER AS $$
BEGIN
	PERFORM *
	FROM dns_record
	WHERE netblock_id IN (NEW.netblock_id, OLD.netblock_id)
	AND ip_universe_id != NEW.ip_universe_id;

	IF FOUND THEN
		RAISE EXCEPTION
			'IP Universes for netblocks must match dns records and netblocks'
			USING ERRCODE = 'foreign_key_violation';
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_check_ip_universe_netblock ON netblock;
CREATE CONSTRAINT TRIGGER trigger_check_ip_universe_netblock
	AFTER UPDATE OF netblock_id, ip_universe_id
	ON netblock
	DEFERRABLE
	FOR EACH ROW
	EXECUTE PROCEDURE check_ip_universe_netblock();

------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION check_ip_universe_dns_record()
RETURNS TRIGGER AS $$
DECLARE
	nb	integer[];
BEGIN
	IF TG_OP = 'UPDATE' THEN
		IF NEW.netblock_id != OLD.netblock_id THEN
			nb = ARRAY[OLD.netblock_id, NEW.netblock_id];
		ELSE
			nb = ARRAY[NEW.netblock_id];
		END IF;
	ELSE
		nb = ARRAY[NEW.netblock_id];
	END IF;

	PERFORM *
	FROM netblock
	WHERE netblock_id = ANY(nb)
	AND ip_universe_id != NEW.ip_universe_id;

	IF FOUND THEN
		RAISE EXCEPTION
			'IP Universes for dns_records must match dns records and netblocks '
			USING ERRCODE = 'foreign_key_violation',
			HINT = format('%s: %s', NEW.ip_universe_id, nb);
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_check_ip_universe_dns_record ON dns_record;
CREATE CONSTRAINT TRIGGER trigger_check_ip_universe_dns_record
	AFTER INSERT OR UPDATE OF dns_record_id, ip_universe_id
	ON dns_record
	DEFERRABLE
	FOR EACH ROW
	EXECUTE PROCEDURE check_ip_universe_dns_record();

------------------------------------------------------------------------------
