-- Copyright (c) 2012-2017 Matthew Ragan
-- Copyright (c) 2014-2018 Todd M. Kover
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

-- Copyright (c) 2014 Todd Kover
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

CREATE OR REPLACE FUNCTION validate_netblock()
RETURNS TRIGGER AS $$
DECLARE
	nbtype				RECORD;
	v_netblock_id		netblock.netblock_id%TYPE;
	parent_netblock		RECORD;
	tmp_nb				RECORD;
	universes			integer[];
	netmask_bits		integer;
	tally				integer;
BEGIN
	IF NEW.ip_address IS NULL THEN
		RAISE EXCEPTION 'Column ip_address may not be null'
			USING ERRCODE = 'not_null_violation';
	END IF;

	/*
	 * These are trigger enforced later and are basically what anyone
	 * using this means.
	 */
	IF NEW.can_subnet = 'Y' and NEW.is_single_address iS NULL THEN
		NEW.is_single_address = 'N';
	ELSIF NEW.can_subnet IS NULL and NEW.is_single_address = 'Y' THEN
		NEW.can_subnet = 'N';
	END IF;

	/*
	 * If the universe is not set, we used to assume 0/default, but now
	 * its the same namespace.  In the interest of speed, we assume a
	 * default namespace of 0, which is kind of like before, and
	 * assume that if there's no match, 0 should be returned, which
	 * is also like before, which basically is just all the defaults.
	 * The assumption is that if multiple namespaces are used, then
	 * the caller is smart about figuring this out
	 */
	IF NEW.ip_universe_id IS NULL THEN
		NEW.ip_universe_id := netblock_utils.find_best_ip_universe(
				ip_address := NEW.ip_address
			);
	END IF;

	SELECT * INTO nbtype FROM val_netblock_type WHERE
		netblock_type = NEW.netblock_type;

	IF NEW.is_single_address = 'Y' THEN
		IF nbtype.db_forced_hierarchy = 'Y' THEN
			RAISE DEBUG 'Calculating netmask for new netblock';

			v_netblock_id := netblock_utils.find_best_parent_id(
				NEW.ip_address,
				NULL,
				NEW.netblock_type,
				NEW.ip_universe_id,
				NEW.is_single_address,
				NEW.netblock_id
				);

			IF v_netblock_id IS NULL THEN
				RAISE EXCEPTION 'A single address (%) must be the child of a parent netblock, which must have can_subnet=N', NEW.ip_address
					USING ERRCODE = 'JH105';
			END IF;

			SELECT masklen(ip_address) INTO netmask_bits FROM
				netblock WHERE netblock_id = v_netblock_id;

			NEW.ip_address := set_masklen(NEW.ip_address, netmask_bits);
		END IF;
	END IF;

	/* Done with handling of netmasks */

	IF NEW.can_subnet = 'Y' AND NEW.is_single_address = 'Y' THEN
		RAISE EXCEPTION 'Single addresses may not be subnettable'
			USING ERRCODE = 'JH106';
	END IF;

	IF NEW.is_single_address = 'N' AND (NEW.ip_address != cidr(NEW.ip_address))
			THEN
		RAISE EXCEPTION
			'Non-network bits must be zero if is_single_address is N for %',
			NEW.ip_address
			USING ERRCODE = 'JH103';
	END IF;

	/*
	 * This used to only happen for not-rfc1918 space, but that sort of
	 * uniqueness enforcement is done through ip universes now.
	 */
	SELECT * FROM netblock INTO tmp_nb
	WHERE
		ip_address = NEW.ip_address AND
		ip_universe_id = NEW.ip_universe_id AND
		netblock_type = NEW.netblock_type AND
		is_single_address = NEW.is_single_address
	LIMIT 1;

	IF (TG_OP = 'INSERT' AND FOUND) THEN
		RAISE EXCEPTION E'Unique Constraint Violated on IP Address: %\nFailing row is %\nConflicts with: %',
			NEW.ip_address, row_to_json(NEW), row_to_json(tmp_nb)
			USING ERRCODE= 'unique_violation';
	END IF;
	IF (TG_OP = 'UPDATE') THEN
		IF (NEW.ip_address != OLD.ip_address AND FOUND) THEN
			RAISE EXCEPTION E'Unique Constraint Violated on IP Address: %\nFailing row is %\nConflicts with: %',
				NEW.ip_address, row_to_json(NEW), row_to_json(tmp_nb)
				USING ERRCODE= 'unique_violation';
		END IF;
	END IF;

	/*
	 * for networks, check for uniqueness across ip universe and ip visibility
	 */
	IF NEW.is_single_address = 'N' THEN
		WITH x AS (
				SELECT	ip_universe_id
				FROM	ip_universe
				WHERE	ip_namespace IN (
							SELECT ip_namespace FROM ip_universe
							WHERE ip_universe_id = NEW.ip_universe_id
						)
				AND		ip_universe_id != NEW.ip_universe_id
			UNION
				SELECT	visible_ip_universe_id
				FROM	ip_universe_visibility
				WHERE	ip_universe_id = NEW.ip_universe_id
				AND		ip_universe_id != NEW.ip_universe_id
			UNION
				SELECT	ip_universe_id
				FROM	ip_universe_visibility
				WHERE	visible_ip_universe_id = NEW.ip_universe_id
				AND		visible_ip_universe_id != NEW.ip_universe_id
		) SELECT count(*) INTO tally
		FROM netblock
		WHERE ip_address = NEW.ip_address AND
			netblock_type = NEW.netblock_type AND
			ip_universe_id IN (select ip_universe_id FROM x) AND
			is_single_address = 'N' AND
			netblock_id != NEW.netblock_id
		;

		IF tally >  0 THEN
			RAISE EXCEPTION
				'IP Universe Constraint Violated on IP Address: % Universe: %',
				NEW.ip_address, NEW.ip_universe_id
				USING ERRCODE= 'unique_violation';
		END IF;

		IF NEW.can_subnet = 'N' THEN
			WITH x AS (
				SELECT	ip_universe_id
				FROM	ip_universe
				WHERE	ip_namespace IN (
							SELECT ip_namespace FROM ip_universe
							WHERE ip_universe_id = NEW.ip_universe_id
						)
				AND		ip_universe_id != NEW.ip_universe_id
			UNION
				SELECT	visible_ip_universe_id
				FROM	ip_universe_visibility
				WHERE	ip_universe_id = NEW.ip_universe_id
				AND		visible_ip_universe_id != NEW.ip_universe_id
			UNION
				SELECT	ip_universe_id
				FROM	ip_universe_visibility
				WHERE	visible_ip_universe_id = NEW.ip_universe_id
				AND		ip_universe_id != NEW.ip_universe_id
			) SELECT count(*) INTO tally
			FROM netblock
			WHERE
				ip_universe_id IN (select ip_universe_id FROM x) AND
				(
					ip_address <<= NEW.ip_address OR
					ip_address >>= NEW.ip_address
				) AND
				netblock_type = NEW.netblock_type AND
				is_single_address = 'N' AND
				can_subnet = 'N' AND
				netblock_id != NEW.netblock_id
			;

			IF tally >  0 THEN
				RAISE EXCEPTION
					'Can Subnet = N IP Universe Constraint Violated on IP Address: % Universe: %',
					NEW.ip_address, NEW.ip_universe_id
					USING ERRCODE= 'unique_violation';
			END IF;
		END IF;
	END IF;

	/*
	 * Parent validation is performed in the deferred after trigger
	 */

	 RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_netblock ON netblock;
DROP TRIGGER IF EXISTS tb_a_validate_netblock ON netblock;

/* This should be lexicographically the first trigger to fire */

CREATE TRIGGER tb_a_validate_netblock BEFORE INSERT OR
	UPDATE OF netblock_id, ip_address, netblock_type, is_single_address,
		can_subnet, parent_netblock_id, ip_universe_id ON
	netblock FOR EACH ROW EXECUTE PROCEDURE
	validate_netblock();

CREATE OR REPLACE FUNCTION manipulate_netblock_parentage_before()
RETURNS TRIGGER AS $$

DECLARE
	nbtype				record;
	v_netblock_type		val_netblock_type.netblock_type%TYPE;
BEGIN
	/*
	 * Get the parameters for the given netblock type to see if we need
	 * to do anything
	 */

	RAISE DEBUG 'Performing % on netblock %', TG_OP, NEW.netblock_id;

	SELECT * INTO nbtype FROM val_netblock_type WHERE
		netblock_type = NEW.netblock_type;

	IF (NOT FOUND) OR nbtype.db_forced_hierarchy != 'Y' THEN
		RETURN NEW;
	END IF;

	/*
	 * Find the correct parent netblock
	 */

	RAISE DEBUG 'Setting forced hierarchical netblock %', NEW.netblock_id;
	NEW.parent_netblock_id := netblock_utils.find_best_parent_id(
		NEW.ip_address,
		NULL,
		NEW.netblock_type,
		NEW.ip_universe_id,
		NEW.is_single_address,
		NEW.netblock_id
		);

	RAISE DEBUG 'Setting parent for netblock % (%, type %, universe %, single-address %) to %',
		NEW.netblock_id, NEW.ip_address, NEW.netblock_type,
		NEW.ip_universe_id, NEW.is_single_address,
		NEW.parent_netblock_id;

	/*
	 * If we are an end-node, then we're done
	 */

	IF NEW.is_single_address = 'Y' THEN
		RETURN NEW;
	END IF;

	/*
	 * If we're updating and we're a container netblock, find
	 * all of the children of our new parent that should be ours and take
	 * them.  They will already be guaranteed to be of the correct
	 * netblock_type and ip_universe_id.  We can't do this for inserts
	 * because the row doesn't exist causing foreign key problems, so
	 * that needs to be done in an after trigger.
	 */
	IF TG_OP = 'UPDATE' THEN
		RAISE DEBUG 'Setting parent for all child netblocks of parent netblock % that belong to %',
			NEW.parent_netblock_id,
			NEW.netblock_id;
		UPDATE
			netblock
		SET
			parent_netblock_id = NEW.netblock_id
		WHERE
			parent_netblock_id = NEW.parent_netblock_id AND
			ip_address <<= NEW.ip_address AND
			netblock_id != NEW.netblock_id;

		RAISE DEBUG 'Setting parent for all child netblocks of netblock % that no longer belong to it to %',
			NEW.parent_netblock_id,
			NEW.netblock_id;
		RAISE DEBUG 'Setting parent % to %',
			OLD.netblock_id,
			OLD.parent_netblock_id;
		UPDATE
			netblock
		SET
			parent_netblock_id = OLD.parent_netblock_id
		WHERE
			parent_netblock_id = NEW.netblock_id AND
			(ip_universe_id != NEW.ip_universe_id OR
			 netblock_type != NEW.netblock_type OR
			 NOT(ip_address <<= NEW.ip_address));
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_manipulate_netblock_parentage ON netblock;
DROP TRIGGER IF EXISTS tb_manipulate_netblock_parentage ON netblock;

/* XXX if parent_netblock_id is in the list, then it causes the tests to fail.
 * this should probably be understood.
 */
CREATE TRIGGER tb_manipulate_netblock_parentage
	BEFORE INSERT OR UPDATE
	OF
		ip_address, netblock_type, ip_universe_id,
		netblock_id, can_subnet, is_single_address
	ON netblock
	FOR EACH ROW EXECUTE PROCEDURE manipulate_netblock_parentage_before();


CREATE OR REPLACE FUNCTION manipulate_netblock_parentage_after()
RETURNS TRIGGER AS $$

DECLARE
	nbtype				record;
	v_netblock_type		val_netblock_type.netblock_type%TYPE;
	v_row_count			integer;
	v_trigger			record;
BEGIN
	/*
	 * Get the parameters for the given netblock type to see if we need
	 * to do anything
	 */

	IF TG_OP = 'DELETE' THEN
		v_trigger := OLD;
	ELSE
		v_trigger := NEW;
	END IF;

	SELECT * INTO nbtype FROM val_netblock_type WHERE
		netblock_type = v_trigger.netblock_type;

	IF (NOT FOUND) OR nbtype.db_forced_hierarchy != 'Y' THEN
		RETURN NULL;
	END IF;

	/*
	 * If we are deleting, attach all children to the parent and wipe
	 * hands on pants;
	 */
	IF TG_OP = 'DELETE' THEN
		UPDATE
			netblock
		SET
			parent_netblock_id = OLD.parent_netblock_id
		WHERE
			parent_netblock_id = OLD.netblock_id;

		GET DIAGNOSTICS v_row_count = ROW_COUNT;
	--	IF (v_row_count > 0) THEN
			RAISE DEBUG 'Set parent for all child netblocks of deleted netblock % (address %, is_single_address %) to % (% rows updated)',
				OLD.netblock_id,
				OLD.ip_address,
				OLD.is_single_address,
				OLD.parent_netblock_id,
				v_row_count;
	--	END IF;

		RETURN NULL;
	END IF;

	IF NEW.is_single_address = 'Y' THEN
		RETURN NULL;
	END IF;

	RAISE DEBUG 'Setting parent for all child netblocks of parent netblock % that belong to %',
		NEW.parent_netblock_id,
		NEW.netblock_id;

	IF NEW.parent_netblock_id IS NULL THEN
		UPDATE
			netblock
		SET
			parent_netblock_id = NEW.netblock_id
		WHERE
			parent_netblock_id IS NULL AND
			ip_address <<= NEW.ip_address AND
			netblock_id != NEW.netblock_id AND
			netblock_type = NEW.netblock_type AND
			ip_universe_id = NEW.ip_universe_id;
		RETURN NULL;
	ELSE
		-- We don't need to specify the netblock_type or ip_universe_id here
		-- because the parent would have had to match
		UPDATE
			netblock
		SET
			parent_netblock_id = NEW.netblock_id
		WHERE
			parent_netblock_id = NEW.parent_netblock_id AND
			ip_address <<= NEW.ip_address AND
			netblock_id != NEW.netblock_id;
		RETURN NULL;
	END IF;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS ta_manipulate_netblock_parentage ON netblock;
DROP TRIGGER IF EXISTS aaa_ta_manipulate_netblock_parentage ON netblock;

CREATE CONSTRAINT TRIGGER aaa_ta_manipulate_netblock_parentage
	AFTER INSERT OR DELETE ON netblock NOT DEFERRABLE
	FOR EACH ROW EXECUTE PROCEDURE manipulate_netblock_parentage_after();

CREATE OR REPLACE FUNCTION validate_netblock_parentage()
RETURNS TRIGGER AS $$
DECLARE
	nbrec			record;
	realnew			record;
	nbtype			record;
	parent_nbid		netblock.netblock_id%type;
	parent_rec		record;
	ipaddr			inet;
	parent_ipaddr	inet;
	single_count	integer;
	nonsingle_count	integer;
	pip	    		netblock.ip_address%type;
BEGIN

	RAISE DEBUG 'Validating % of netblock %', TG_OP, NEW.netblock_id;

	SELECT * INTO nbtype FROM val_netblock_type WHERE
		netblock_type = NEW.netblock_type;

	/*
	 * It's possible that due to delayed triggers that what is stored in
	 * NEW is not current, so fetch the current values
	 */

	SELECT * INTO realnew FROM netblock WHERE netblock_id =
		NEW.netblock_id;
	IF NOT FOUND THEN
		/*
		 * If the netblock isn't there, it was subsequently deleted, so
		 * our parentage doesn't need to be checked
		 */
		RETURN NULL;
	END IF;


	/*
	 * If the parent changed above (or somewhere else between update and
	 * now), just bail, because another trigger will have been fired that
	 * we can do the full check with.
	 */
	IF NEW.parent_netblock_id != realnew.parent_netblock_id AND
		realnew.parent_netblock_id IS NOT NULL
	THEN
		RAISE DEBUG '... skipping for now';
		RETURN NULL;
	END IF;

	/*
	 * Validate that parent and all children are of the same netblock_type and
	 * in the same ip_universe.  We care about this even if the
	 * netblock type is not a validated type.
	 */

	RAISE DEBUG 'Verifying child ip_universe and type match';
	PERFORM netblock_id FROM netblock WHERE
		parent_netblock_id = realnew.netblock_id AND
		netblock_type != realnew.netblock_type AND
		ip_universe_id != realnew.ip_universe_id;

	IF FOUND THEN
		RAISE EXCEPTION 'Netblock children must all be of the same type and universe as the parent'
			USING ERRCODE = 'JH109';
	END IF;

	RAISE DEBUG '... OK';

	/*
	 * validate that this netblock is attached to its correct parent
	 */
	IF realnew.parent_netblock_id IS NULL THEN
		IF nbtype.is_validated_hierarchy='N' THEN
			RETURN NULL;
		END IF;
		RAISE DEBUG 'Checking hierarchical netblock_id % with NULL parent',
			NEW.netblock_id;

		IF realnew.is_single_address = 'Y' THEN
			RAISE 'A single address (%) must be the child of a parent netblock, which must have can_subnet=N',
				realnew.ip_address
				USING ERRCODE = 'JH105';
		END IF;

		/*
		 * Validate that a netblock has a parent, unless
		 * it is the root of a hierarchy
		 */
		parent_nbid := netblock_utils.find_best_parent_id(
			realnew.ip_address,
			NULL,
			realnew.netblock_type,
			realnew.ip_universe_id,
			realnew.is_single_address,
			realnew.netblock_id
		);

		IF parent_nbid IS NOT NULL THEN
			SELECT * INTO nbrec FROM netblock WHERE netblock_id =
				parent_nbid;

			RAISE EXCEPTION 'Netblock % (%) has NULL parent; should be % (%)',
				realnew.netblock_id, realnew.ip_address,
				parent_nbid, nbrec.ip_address USING ERRCODE = 'JH102';
		END IF;

		/*
		 * Validate that none of the other top-level netblocks should
		 * belong to this netblock
		 */
		PERFORM netblock_id FROM netblock WHERE
			parent_netblock_id IS NULL AND
			netblock_id != NEW.netblock_id AND
			netblock_type = NEW.netblock_type AND
			ip_universe_id = NEW.ip_universe_id AND
			ip_address <<= NEW.ip_address;
		IF FOUND THEN
			RAISE EXCEPTION 'Other top-level netblocks should belong to this parent'
				USING ERRCODE = 'JH108';
		END IF;
	ELSE
	 	/*
		 * Reject a block that is self-referential
		 */
	 	IF realnew.parent_netblock_id = realnew.netblock_id THEN
			RAISE EXCEPTION 'Netblock may not have itself as a parent'
				USING ERRCODE = 'JH101';
		END IF;

		SELECT * INTO nbrec FROM netblock WHERE netblock_id =
			realnew.parent_netblock_id;

		/*
		 * This shouldn't happen, but may because of deferred constraints
		 */
		IF NOT FOUND THEN
			RAISE EXCEPTION 'Parent netblock % does not exist',
			realnew.parent_netblock_id
			USING ERRCODE = 'foreign_key_violation';
		END IF;

		IF nbrec.is_single_address = 'Y' THEN
			RAISE EXCEPTION 'A parent netblock (% for %) may not be a single address',
			nbrec.netblock_id, realnew.ip_address
			USING ERRCODE = 'JH10A';
		END IF;

		IF nbrec.ip_universe_id != realnew.ip_universe_id OR
				nbrec.netblock_type != realnew.netblock_type THEN
			RAISE EXCEPTION 'Netblock children must all be of the same type and universe as the parent'
			USING ERRCODE = 'JH109';
		END IF;

		IF nbtype.is_validated_hierarchy='N' THEN
			RETURN NULL;
		ELSE
			parent_nbid := netblock_utils.find_best_parent_id(
				realnew.ip_address,
				NULL,
				realnew.netblock_type,
				realnew.ip_universe_id,
				realnew.is_single_address,
				realnew.netblock_id
				);

			SELECT * FROM netblock INTO parent_rec WHERE netblock_id =
				parent_nbid;

			IF realnew.can_subnet = 'N' THEN
				PERFORM netblock_id FROM netblock WHERE
					parent_netblock_id = realnew.netblock_id AND
					is_single_address = 'N';
				IF FOUND THEN
					RAISE EXCEPTION E'A non-subnettable netblock may not have child network netblocks\nParent: %\nChild: %\n',
						row_to_json(parent_rec, true),
						row_to_json(realnew, true)
					USING ERRCODE = 'JH10B';
				END IF;
			END IF;
			IF realnew.is_single_address = 'Y' THEN
				SELECT * INTO nbrec FROM netblock
					WHERE netblock_id = realnew.parent_netblock_id;
				IF (nbrec.can_subnet = 'Y') THEN
					RAISE 'Parent netblock % for single-address % must have can_subnet=N',
						nbrec.netblock_id,
						realnew.ip_address
						USING ERRCODE = 'JH10D';
				END IF;
				IF (masklen(realnew.ip_address) !=
						masklen(nbrec.ip_address)) THEN
					RAISE 'Parent netblock % does not have the same netmask as single-address child % (% vs %)',
						parent_nbid, realnew.netblock_id,
						masklen(nbrec.ip_address),
						masklen(realnew.ip_address)
						USING ERRCODE = 'JH105';
				END IF;
			END IF;
			IF (parent_nbid IS NULL OR realnew.parent_netblock_id != parent_nbid) THEN
				SELECT ip_address INTO parent_ipaddr FROM netblock
				WHERE
					netblock_id = parent_nbid;
				SELECT ip_address INTO ipaddr FROM netblock WHERE
					netblock_id = realnew.parent_netblock_id;

				RAISE EXCEPTION
					'Parent netblock % (%) for netblock % (%) is not the correct parent (should be % (%))',
					realnew.parent_netblock_id, ipaddr,
					realnew.netblock_id, realnew.ip_address,
					parent_nbid, parent_ipaddr
					USING ERRCODE = 'JH102';
			END IF;
			/*
			 * Validate that all children are is_single_address='Y' or
			 * all children are is_single_address='N'
			 */
			SELECT count(*) INTO single_count FROM netblock WHERE
				is_single_address='Y' and parent_netblock_id =
				realnew.parent_netblock_id;
			SELECT count(*) INTO nonsingle_count FROM netblock WHERE
				is_single_address='N' and parent_netblock_id =
				realnew.parent_netblock_id;

			IF (single_count > 0 and nonsingle_count > 0) THEN
				SELECT * INTO nbrec FROM netblock WHERE netblock_id =
					realnew.parent_netblock_id;
				RAISE EXCEPTION 'Netblock % (%) may not have direct children for both single and multiple addresses simultaneously',
					nbrec.netblock_id, nbrec.ip_address
					USING ERRCODE = 'JH107';
			END IF;
			/*
			 *  If we're updating and we changed our ip_address (including
			 *  netmask bits), then check that our children still belong to
			 *  us
			 */
			 IF (TG_OP = 'UPDATE' AND NEW.ip_address != OLD.ip_address) THEN
				PERFORM netblock_id FROM netblock WHERE
					parent_netblock_id = realnew.netblock_id AND
					((is_single_address = 'Y' AND NEW.ip_address !=
						ip_address::cidr) OR
					(is_single_address = 'N' AND realnew.netblock_id !=
						netblock_utils.find_best_parent_id(netblock_id)));
				IF FOUND THEN
					RAISE EXCEPTION 'Update for netblock % (%) causes parent to have children that do not belong to it',
						realnew.netblock_id, realnew.ip_address
						USING ERRCODE = 'JH10E';
				END IF;
			END IF;

			/*
			 * Validate that none of the children of the parent netblock are
			 * children of this netblock (e.g. if inserting into the middle
			 * of the hierarchy)
			 */
			IF (realnew.is_single_address = 'N') THEN
				PERFORM netblock_id FROM netblock WHERE
					parent_netblock_id = realnew.parent_netblock_id AND
					netblock_id != realnew.netblock_id AND
					ip_address <<= realnew.ip_address;
				IF FOUND THEN
					RAISE EXCEPTION 'Other netblocks have children that should belong to parent % (%)',
						realnew.parent_netblock_id, realnew.ip_address
						USING ERRCODE = 'JH108';
				END IF;
			END IF;
		END IF;
	END IF;

	RETURN NULL;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

/*
 * NOTE: care needs to be taken to make this trigger name come
 * lexicographically last, since it needs to check what happened in the
 * other triggers
 */


DROP TRIGGER IF EXISTS trigger_validate_netblock_parentage ON netblock;
CREATE CONSTRAINT TRIGGER trigger_validate_netblock_parentage
	AFTER INSERT OR UPDATE OF
	netblock_id, ip_address, netblock_type, is_single_address,
	can_subnet, parent_netblock_id, ip_universe_id
	ON netblock
	DEFERRABLE INITIALLY DEFERRED
	FOR EACH ROW EXECUTE PROCEDURE validate_netblock_parentage();


-----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION netblock_single_address_ni()
RETURNS TRIGGER AS $$
DECLARE
	_tally	INTEGER;
BEGIN
	IF (NEW.is_single_address = 'N' AND OLD.is_single_address = 'Y') OR
		(NEW.netblock_type != 'default' AND OLD.netblock_type = 'default')
			THEN
		select count(*)
		INTO _tally
		FROM network_interface_netblock
		WHERE netblock_id = NEW.netblock_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'network interfaces must refer to single ip addresses of type default address (%,%)', NEW.ip_address, NEW.netblock_id
				USING errcode = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_netblock_single_address_ni ON netblock;
CREATE TRIGGER trigger_netblock_single_address_ni
	BEFORE UPDATE OF is_single_address, netblock_type
	ON netblock
	FOR EACH ROW
	EXECUTE PROCEDURE netblock_single_address_ni();

------------------------------------------------------------------------
-- NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE
-- NOTE
-- NOTE -- There are other files that have netblock related triggers
-- NOTE -- such as network_range
-- NOTE
-- NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE
------------------------------------------------------------------------

