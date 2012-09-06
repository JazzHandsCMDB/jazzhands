
CREATE OR REPLACE FUNCTION validate_netblock() RETURNS TRIGGER AS $$
BEGIN
	/* note, the autonomous transaction stuff may make some of the stuff  
	 * we're trying to do here weird.
	 */
	 
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
			  WHERE ip_address = new.ip_address;
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
	nbid			netblock.netblock_id%type;
	ipaddr			inet;
	single_count		integer;
	nonsingle_count	integer;
	pip	    		netblock.ip_address%type;
BEGIN
	/*
	 * validate that this netblock is attached to its correct parent
	 */
	IF NEW.parent_netblock_id IS NULL THEN
		/*
		 * Validate that if a non-organizational netblock has a parent, unless
		 * it is the root of a hierarchy
		 */
		IF NEW.is_organizational='N' THEN
			nbid := netblock_utils.find_best_parent_id(NEW.ip_address, 
				masklen(NEW.ip_address));
			IF nbid IS NOT NULL THEN
				RAISE EXCEPTION 'Non-organizational netblock must have correct parent(%)',
					nbid USING ERRCODE = 22102;
			END IF;
		END IF;
	ELSE
	 	/*
		 * Reject a block that is self-referential
		 */
	 	IF NEW.parent_netblock_id = NEW.netblock_id THEN
			RAISE EXCEPTION 'Netblock may not have itself as a parent'
				USING ERRCODE = 22101;
		END IF;
		
		SELECT * INTO nbrec FROM netblock WHERE netblock_id = 
			NEW.parent_netblock_id;

		/*
		 * This shouldn't happen, but may because of deferred constraints
		 */
		IF NOT FOUND THEN
			RAISE EXCEPTION 'Parent netblock % does not exist',
			NEW.parent_netblock_id
			USING ERRCODE = 23503;
		END IF;

		IF nbrec.is_single_address = 'Y' THEN
			RAISE EXCEPTION 'Parent netblock may not be a single address'
			USING ERRCODE = 23504;
		END IF;

		IF NEW.is_organizational='Y' THEN
			/*
			 * organizational addresses may not have the best parent as
			 * a parent, but if they have a parent, it should validate
			 */

			IF NOT (NEW.ip_address << nbrec.ip_address OR
					cidr(NEW.ip_address) != nbrec.ip_address) THEN
				RAISE EXCEPTION 'Parent netblock is a valid parent'
					USING ERRCODE = 22102;
			END IF;
		ELSE
			nbid := netblock_utils.find_best_parent_id(NEW.ip_address, 
				masklen(NEW.ip_address));
			if (nbid IS NULL OR NEW.parent_netblock_id != nbid) THEN
				RAISE EXCEPTION 'Parent netblock is not the correct parent'
					USING ERRCODE = 22102;
			END IF;
		END IF;
		IF NEW.is_single_address = 'Y' AND 
				((family(NEW.ip_address) = 4 AND 
					masklen(NEW.ip_address) < 32) OR
				(family(NEW.ip_address) = 6 AND 
					masklen(NEW.ip_address) < 128))
				THEN 
			SELECT ip_address INTO ipaddr FROM netblock
				WHERE netblock_id = nbid;
			IF (masklen(NEW.ip_address) != masklen(ipaddr)) THEN
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
			NEW.parent_netblock_id;
		SELECT count(*) INTO nonsingle_count FROM netblock WHERE
			is_single_address='N' and parent_netblock_id =
			NEW.parent_netblock_id;

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
		 	parent_netblock_id = NEW.parent_netblock_id AND
			netblock_id != NEW.netblock_id AND
		 	ip_address <<= NEW.ip_address;
		IF FOUND THEN
			RAISE EXCEPTION 'Other netblocks have children that should belong to this parent'
				USING ERRCODE = 22108;
		END IF;
	END IF;

	RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_netblock_parentage ON netblock;
CREATE CONSTRAINT TRIGGER trigger_validate_netblock_parentage 
	AFTER INSERT OR UPDATE ON netblock DEFERRABLE FOR EACH ROW 
	EXECUTE PROCEDURE validate_netblock_parentage();

