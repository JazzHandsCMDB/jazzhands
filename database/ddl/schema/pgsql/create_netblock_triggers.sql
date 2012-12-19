-- Copyright (c) 2012, Matthew Ragan
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

CREATE OR REPLACE FUNCTION validate_netblock() RETURNS TRIGGER AS $$
BEGIN
	/*
	 * Force netmask_bits to be authoritative
	 */

	IF NEW.netmask_bits IS NULL THEN
		RAISE EXCEPTION 'Column netmask_bits may not be null'
			USING ERRCODE = 'not_null_violation';
	ELSE
		NEW.ip_address = set_masklen(NEW.ip_address, NEW.netmask_bits);
	END IF;

	IF NEW.can_subnet = 'Y' AND NEW.is_single_address = 'Y' THEN
		RAISE EXCEPTION 'Single addresses may not be subnettable'
			USING ERRCODE = 22106;
	END IF;

	IF NEW.is_single_address = 'N' AND (NEW.ip_address != cidr(NEW.ip_address))
			THEN
		RAISE EXCEPTION
			'Non-network bits must be zero if is_single_address is N'
			USING ERRCODE = 22103;
	END IF;

	/*
	 * Commented out check for RFC1918 space.  This is probably handled
	 * well enough by the ip_universe/netblock_type additions, although
	 * it's possible that netblock_type may need to have an additional
	 * field added to allow people to be stupid (for example,
	 * allow_duplicates='Y','N','RFC1918')
	 */
/*
	IF NOT net_manip.inet_is_private(NEW.ip_address) THEN
*/
			PERFORM netblock_id 
			   FROM netblock 
			  WHERE ip_address = new.ip_address AND
					ip_universe_id = new.ip_universe_id AND
					netblock_type = new.netblock_type;
			IF (TG_OP = 'INSERT' AND FOUND) THEN 
				RAISE EXCEPTION 'Unique Constraint Violated on IP Address: %', 
					new.ip_address
					USING ERRCODE= 'unique_violation';
			END IF;
			IF (TG_OP = 'UPDATE') THEN
				IF (NEW.ip_address != OLD.ip_address AND FOUND) THEN
					RAISE EXCEPTION 
						'Unique Constraint Violated on IP Address: %', 
						new.ip_address
						USING ERRCODE = 'unique_violation';
				END IF;
			END IF;
/*
	END IF;
*/

	/*
	 * Parent validation is performed in the deferred after trigger
	 */

	 RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_netblock ON netblock;
CREATE TRIGGER trigger_validate_netblock BEFORE INSERT OR UPDATE ON netblock
	FOR EACH ROW EXECUTE PROCEDURE validate_netblock();

CREATE OR REPLACE FUNCTION manipulate_netblock_parentage_before() RETURNS TRIGGER AS $$

DECLARE
	nbtype				record;
	v_trigger			record;
	v_netblock_type		val_netblock_type.netblock_type%TYPE;
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
		RETURN v_trigger;
	END IF;

	/*
	 * Find the correct parent netblock if we're not deleting
	 */ 

	IF TG_OP != 'DELETE' THEN
		RAISE DEBUG 'Checking forced hierarchical netblock %', NEW.netblock_id;
		NEW.parent_netblock_id = netblock_utils.find_best_parent_id(
			NEW.ip_address,
			NEW.netmask_bits,
			NEW.netblock_type,
			NEW.ip_universe_id,
			NEW.is_single_address
			);

		RAISE DEBUG 'Setting parent for netblock % to %', NEW.netblock_id,
			NEW.parent_netblock_id;

		/*
		 * If we are an end-node, then we're done
		 */

		IF NEW.is_single_address = 'Y' THEN
			RETURN NEW;
		END IF;
	END IF;


	/*
	 * If we are deleting, attach all children to the parent and wipe
	 * hands on pants;
	 */
	IF TG_OP = 'DELETE' THEN
		RAISE DEBUG 'Setting parent for all child netblocks of deleted netblock % to %',
			OLD.netblock_id,
			OLD.parent_netblock_id;

		UPDATE 
			netblock 
		SET
			parent_netblock_id = OLD.parent_netblock_id
		WHERE
			parent_netblock_id = OLD.netblock_id;
		RETURN OLD;
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_manipulate_netblock_parentage ON netblock;
DROP TRIGGER IF EXISTS tb_manipulate_netblock_parentage ON netblock;

CREATE TRIGGER tb_manipulate_netblock_parentage
	BEFORE INSERT OR DELETE OR UPDATE OF
		ip_address, netmask_bits, netblock_type, ip_universe_id
	ON netblock
	FOR EACH ROW EXECUTE PROCEDURE manipulate_netblock_parentage_before();


CREATE OR REPLACE FUNCTION manipulate_netblock_parentage_after() RETURNS TRIGGER AS $$

DECLARE
	nbtype				record;
	v_netblock_type		val_netblock_type.netblock_type%TYPE;
BEGIN
	/*
	 * Get the parameters for the given netblock type to see if we need
	 * to do anything
	 */

	SELECT * INTO nbtype FROM val_netblock_type WHERE 
		netblock_type = NEW.netblock_type;

	IF (NOT FOUND) OR nbtype.db_forced_hierarchy != 'Y' THEN
		RETURN NULL;
	END IF;

	IF NEW.is_single_address = 'Y' THEN
		RETURN NULL;
	END IF;

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

	RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS ta_manipulate_netblock_parentage ON netblock;

CREATE CONSTRAINT TRIGGER ta_manipulate_netblock_parentage
	AFTER INSERT ON netblock NOT DEFERRABLE
	FOR EACH ROW EXECUTE PROCEDURE manipulate_netblock_parentage_after();

CREATE OR REPLACE FUNCTION validate_netblock_parentage() RETURNS TRIGGER AS $$
DECLARE
	nbrec			record;
	realnew			record;
	nbtype			record;
	v_trigger		record;
	parent_nbid		netblock.netblock_id%type;
	ipaddr			inet;
	parent_ipaddr	inet;
	single_count	integer;
	nonsingle_count	integer;
	pip	    		netblock.ip_address%type;
BEGIN
	/*
	 * It's possible that due to delayed triggers that what is stored in
	 * NEW is not current, so fetch the current values
	 */
	
	IF TG_OP = 'DELETE' THEN
		v_trigger := OLD;
	ELSE
		v_trigger := NEW;
	END IF;
	
	RAISE DEBUG 'Validating  % of netblock %', TG_OP, v_trigger.netblock_id;

	SELECT * INTO nbtype FROM val_netblock_type WHERE 
		netblock_type = v_trigger.netblock_type;

	IF (NOT FOUND) OR nbtype.db_forced_hierarchy != 'Y' THEN
		RETURN NULL;
	END IF;

	SELECT * INTO realnew FROM netblock WHERE netblock_id =
		v_trigger.netblock_id;
	
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
	 * Validate that all children are of the same netblock_type and
	 * in the same ip_universe.  We care about this even if the
	 * netblock type is not a validated type.
	 */
	
	PERFORM netblock_id FROM netblock WHERE
		parent_netblock_id = realnew.netblock_id AND
		netblock_type != realnew.netblock_type AND
		ip_universe_id != realnew.ip_universe_id;

	IF FOUND THEN
		RAISE EXCEPTION 'Netblock children must all be of the same type and universe as the parent'
			USING ERRCODE = 22109;
	END IF;

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
			RAISE 'A single address must be the child of a parent netblock'
				USING ERRCODE = 22105;
		END IF;		

		/*
		 * Validate that a netblock has a parent, unless
		 * it is the root of a hierarchy
		 */
		parent_nbid := netblock_utils.find_best_parent_id(
			realnew.ip_address, 
			masklen(realnew.ip_address),
			realnew.netblock_type,
			realnew.ip_universe_id,
			realnew.is_single_address
		);

		IF parent_nbid IS NOT NULL THEN
			RAISE EXCEPTION 'Netblock % has NULL parent; should be %',
				realnew.netblock_id, parent_nbid USING ERRCODE = 22102;
		END IF;
	ELSE
	 	/*
		 * Reject a block that is self-referential
		 */
	 	IF realnew.parent_netblock_id = realnew.netblock_id THEN
			RAISE EXCEPTION 'Netblock may not have itself as a parent'
				USING ERRCODE = 22101;
		END IF;
		
		SELECT * INTO nbrec FROM netblock WHERE netblock_id = 
			realnew.parent_netblock_id;

		/*
		 * This shouldn't happen, but may because of deferred constraints
		 */
		IF NOT FOUND THEN
			RAISE EXCEPTION 'Parent netblock % does not exist',
			realnew.parent_netblock_id
			USING ERRCODE = 23503;
		END IF;

		IF nbrec.is_single_address = 'Y' THEN
			RAISE EXCEPTION 'Parent netblock may not be a single address'
			USING ERRCODE = 23504;
		END IF;

		IF nbrec.ip_universe_id != realnew.ip_universe_id OR
				nbrec.netblock_type != realnew.netblock_type THEN
			RAISE EXCEPTION 'Parent netblock must be the same type and ip_universe'
			USING ERRCODE = 22110;
		END IF;

		IF nbtype.is_validated_hierarchy='N' THEN
			/*
			 * validated hierarchy addresses may not have the best parent as
			 * a parent, but if they have a parent, it should be a superblock
			 */

			IF NOT (realnew.ip_address << nbrec.ip_address OR
					cidr(realnew.ip_address) != nbrec.ip_address) THEN
				RAISE EXCEPTION 'Parent netblock is not a valid parent'
					USING ERRCODE = 22102;
			END IF;
		ELSE
			parent_nbid := netblock_utils.find_best_parent_id(
				realnew.ip_address, 
				masklen(realnew.ip_address),
				realnew.netblock_type,
				realnew.ip_universe_id,
				realnew.is_single_address
				);

			IF (parent_nbid IS NULL OR realnew.parent_netblock_id != parent_nbid) THEN
				SELECT ip_address INTO parent_ipaddr FROM netblock WHERE
					netblock_id = parent_nbid;
				SELECT ip_address INTO ipaddr FROM netblock WHERE
					netblock_id = realnew.parent_netblock_id;

				RAISE EXCEPTION 
					'Parent netblock % (%) for netblock % (%) is not the correct parent (should be % (%))',
					realnew.parent_netblock_id, ipaddr,
					realnew.netblock_id, realnew.ip_address,
					parent_nbid, parent_ipaddr
					USING ERRCODE = 22102;
			END IF;
			IF realnew.is_single_address = 'Y' THEN 
				SELECT ip_address INTO ipaddr FROM netblock
					WHERE netblock_id = parent_nbid;
				IF (masklen(realnew.ip_address) != masklen(ipaddr)) THEN
					RAISE 'Parent netblock % does not have same netmask as single address child % (% vs %)',
						parent_nbid, realnew.netblock_id, masklen(ipaddr),
						masklen(realnew.ip_address)
						USING ERRCODE = 22105;
				END IF;
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
				RAISE EXCEPTION 'Netblock may not have direct children for both single and multiple addresses simultaneously'
					USING ERRCODE = 22107;
			END IF;
			/*
			 * Validate that none of the children of the parent netblock are
			 * children of this netblock (e.g. if inserting into the middle
			 * of the hierarchy)
			 */
			 PERFORM netblock_id FROM netblock WHERE 
				parent_netblock_id = realnew.parent_netblock_id AND
				netblock_id != realnew.netblock_id AND
				ip_address <<= realnew.ip_address;
			IF FOUND THEN
				RAISE EXCEPTION 'Other netblocks have children that should belong to this parent'
					USING ERRCODE = 22108;
			END IF;
		END IF;
	END IF;

	RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
 * NOTE: care needs to be taken to make this trigger name come
 * lexicographically last, since it needs to check what happened in the
 * other triggers
 */

DROP TRIGGER IF EXISTS trigger_validate_netblock_parentage ON netblock;
CREATE CONSTRAINT TRIGGER trigger_validate_netblock_parentage 
	AFTER INSERT OR UPDATE OR DELETE ON netblock DEFERRABLE INITIALLY DEFERRED
	FOR EACH ROW EXECUTE PROCEDURE validate_netblock_parentage();

