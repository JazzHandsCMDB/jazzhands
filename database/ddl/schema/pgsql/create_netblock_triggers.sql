
CREATE OR REPLACE FUNCTION validate_netblock() RETURNS TRIGGER AS $$
BEGIN
	/*
	 * Force netmask_bits to be authoritative
	 */

	IF NEW.netmask_bits IS NULL THEN
		RAISE EXCEPTION 'Column netmask_bits may not be null'
			USING ERRCODE = 23502;
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
			'Non-network bits must be zero if is_single_address is set'
			USING ERRCODE = 22103;
	END IF;

	/*
	 * only allow multiple addresses to exist if it is a 1918-space 
	 * address.   (This may need to be revised for sites that do really
	 *  really really stupid things.  Perhaps a marker in the netblock 
	 * that indicates that its one of these blocks or  some such?  Or a
	 * separate table that says which blocks are ok.  (make the 
	 * mutating table stuff better?) 
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
					USING ERRCODE= 23505;
			END IF;
			IF (TG_OP = 'UPDATE') THEN
				IF (NEW.ip_address != OLD.ip_address AND FOUND) THEN
					RAISE EXCEPTION 
						'Unique Constraint Violated on IP Address: %', 
						new.ip_address
						USING ERRCODE = 23505;
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

CREATE OR REPLACE FUNCTION validate_netblock_parentage() RETURNS TRIGGER AS $$
DECLARE
	nbrec			record;
	realnew			record;
	nbtype			record;
	nbid			netblock.netblock_id%type;
	ipaddr			inet;
	single_count	integer;
	nonsingle_count	integer;
	pip	    		netblock.ip_address%type;
BEGIN
	/*
	 * It's possible that due to delayed triggers that what is stored in
	 * NEW is not current, so fetch the current values
	 */
	
	SELECT * INTO nbtype FROM val_netblock_type WHERE 
		netblock_type = NEW.netblock_type;

/*
	-- This needs to get f1x0r3d
	IF nbtype.db_forced_hierarchy = 'Y' THEN
		PERFORM netblock_utils.recalculate_parentage(NEW.netblock_id);
	END IF;
*/

	SELECT * INTO realnew FROM netblock WHERE netblock_id = NEW.netblock_id;
	/*
	 * If the parent changed above (or somewhere else between update and
	 * now), just bail, because another trigger will have been fired that
	 * we can do the full check with.
	 */
	IF NEW.parent_netblock_id != realnew.parent_netblock_id THEN
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

		/*
		 * Validate that if a netblock has a parent, unless
		 * it is the root of a hierarchy
		 */
		nbid := netblock_utils.find_best_parent_id(
			realnew.ip_address, 
			masklen(realnew.ip_address),
			realnew.netblock_type,
			realnew.ip_universe_id
		);

		IF nbid IS NOT NULL THEN
			RAISE EXCEPTION 'Non-organizational netblock % must have correct parent(%)',
				realnew.netblock_id, nbid USING ERRCODE = 22102;
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
			nbid := netblock_utils.find_best_parent_id(
				realnew.ip_address, 
				masklen(realnew.ip_address),
				realnew.netblock_type,
				realnew.ip_universe_id
				);
			if (nbid IS NULL OR realnew.parent_netblock_id != nbid) THEN
				RAISE EXCEPTION 
					'Parent netblock % for netblock % is not the correct parent (%)',
					realnew.parent_netblock_id, realnew.netblock_id, nbid
					USING ERRCODE = 22102;
			END IF;
			IF realnew.is_single_address = 'Y' AND 
					((family(realnew.ip_address) = 4 AND 
						masklen(realnew.ip_address) < 32) OR
					(family(realnew.ip_address) = 6 AND 
						masklen(realnew.ip_address) < 128))
					THEN 
				SELECT ip_address INTO ipaddr FROM netblock
					WHERE netblock_id = nbid;
				IF (masklen(realnew.ip_address) != masklen(ipaddr)) THEN
				RAISE EXCEPTION 'Parent netblock does not have same netmask for single address'
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

DROP TRIGGER IF EXISTS trigger_validate_netblock_parentage ON netblock;
CREATE CONSTRAINT TRIGGER trigger_validate_netblock_parentage 
	AFTER INSERT OR UPDATE ON netblock DEFERRABLE INITIALLY DEFERRED
	FOR EACH ROW EXECUTE PROCEDURE validate_netblock_parentage();

