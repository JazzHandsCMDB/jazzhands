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

/*
TODO:
 - consider unique record test when one record points to another.
    - value underway, need to do with reference

 - one day:
   - make sure dns_rec_prevent_dups still makes sense with other tests.
      Other tests seemed more complex than necessary.
   - deal with a zone switching to "not generated" so records do not hang out
      in dns_change_record in perpetuity.  This may just mean not adding
      records and letting the pgnotify go out.
*/

---------------------------------------------------------------------------
--
-- This shall replace all the aforementioned triggers
--

CREATE OR REPLACE FUNCTION dns_record_update_nontime()
RETURNS TRIGGER AS $$
DECLARE
	_dnsdomainid	DNS_DOMAIN.DNS_DOMAIN_ID%type;
	_ipaddr			NETBLOCK.IP_ADDRESS%type;
	_mkold			boolean;
	_mknew			boolean;
	_mkdom			boolean;
	_mkip			boolean;
BEGIN
	_mkold = false;
	_mkold = false;
	_mknew = true;

	IF TG_OP = 'DELETE' THEN
		_mknew := false;
		_mkold := true;
		_mkdom := true;
		if  OLD.netblock_id is not null  THEN
			_mkip := true;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		_mkold := false;
		_mkdom := true;
		if  NEW.netblock_id is not null  THEN
			_mkip := true;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF OLD.DNS_DOMAIN_ID != NEW.DNS_DOMAIN_ID THEN
			_mkold := true;
			_mkip := true;
		END IF;
		_mkdom := true;

		IF OLD.dns_name IS DISTINCT FROM NEW.dns_name THEN
			_mknew := true;
			IF NEW.DNS_TYPE = 'A' OR NEW.DNS_TYPE = 'AAAA' THEN
				IF NEW.SHOULD_GENERATE_PTR = true THEN
					_mkip := true;
				END IF;
			END IF;
		END IF;

		IF OLD.SHOULD_GENERATE_PTR != NEW.SHOULD_GENERATE_PTR THEN
			_mkold := true;
			_mkip := true;
		END IF;

		IF (OLD.netblock_id IS DISTINCT FROM NEW.netblock_id) THEN
			_mkold := true;
			_mknew := true;
			_mkip := true;
		END IF;
	END IF;

	if _mkold THEN
		IF _mkdom THEN
			_dnsdomainid := OLD.dns_domain_id;
		ELSE
			_dnsdomainid := NULL;
		END IF;
		if _mkip and OLD.netblock_id is not NULL THEN
			SELECT	ip_address
			  INTO	_ipaddr
			  FROM	netblock
			 WHERE	netblock_id  = OLD.netblock_id;
		ELSE
			_ipaddr := NULL;
		END IF;
		insert into DNS_CHANGE_RECORD
			(dns_domain_id, ip_address) VALUES (_dnsdomainid, _ipaddr);
	END IF;
	if _mknew THEN
		if _mkdom THEN
			_dnsdomainid := NEW.dns_domain_id;
		ELSE
			_dnsdomainid := NULL;
		END IF;
		if _mkip and NEW.netblock_id is not NULL THEN
			SELECT	ip_address
			  INTO	_ipaddr
			  FROM	netblock
			 WHERE	netblock_id  = NEW.netblock_id;
		ELSE
			_ipaddr := NULL;
		END IF;
		insert into DNS_CHANGE_RECORD
			(dns_domain_id, ip_address) VALUES (_dnsdomainid, _ipaddr);
	END IF;

	--
	-- deal with records pointing to this one.  only values are done because
	-- references are forced by ak to be in the same zone.
	IF TG_OP = 'INSERT' THEN
		INSERT INTO dns_change_record (dns_domain_id)
			SELECT DISTINCT dns_domain_id
			FROM dns_record
			WHERE dns_value_record_id = NEW.dns_record_id
			AND dns_domain_id != NEW.dns_domain_id;
	ELSIF TG_OP = 'UPDATE' THEN
		INSERT INTO dns_change_record (dns_domain_id)
			SELECT DISTINCT dns_domain_id
			FROM dns_record
			WHERE dns_value_record_id = NEW.dns_record_id
			AND dns_domain_id NOT IN (OLD.dns_domain_id, NEW.dns_domain_id);
	END IF;

	IF TG_OP = 'DELETE' THEN
		return OLD;
	END IF;
	return NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_record_update_nontime ON dns_record;
CREATE TRIGGER trigger_dns_record_update_nontime
	AFTER INSERT OR UPDATE OR DELETE
	ON dns_record
	FOR EACH ROW
	EXECUTE PROCEDURE dns_record_update_nontime();

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION dns_a_rec_validation() RETURNS TRIGGER AS $$
DECLARE
	_ip		netblock.ip_address%type;
	_sing	netblock.is_single_address%type;
BEGIN

	--
	-- arguably, this belongs elsewhere in a non-"validation" trigger,
	-- but that only matters if this wants to be a constraint trigger.
	--
	IF NEW.ip_universe_id IS NULL THEN
		IF NEW.netblock_id IS NOT NULL THEN
			SELECT ip_universe_id INTO NEW.ip_universe_id
			FROM netblock
			WHERE netblock_id = NEW.netblock_id;
		ELSIF NEW.dns_value_record_id IS NOT NULL THEN
			SELECT ip_universe_id INTO NEW.ip_universe_id
			FROM dns_record
			WHERE dns_record_id = NEW.dns_value_record_id;
		ELSE
			-- old default.
			NEW.ip_universe_id = 0;
		END IF;
	END IF;

/*
	IF NEW.dns_type NOT IN ('A', 'AAAA', 'REVERSE_ZONE_BLOCK_PTR') THEN
		IF NEW.netblock_id IS NOT NULL THEN
			RAISE EXCEPTION 'Attempt to set % record with netblock',
				NEW.dns_type
				USING ERRCODE = 'not_null_violation';
		END IF;
		IF TG_OP = 'INSERT' THEN
			RETURN NEW;
		ELSIF TG_OP = 'UPDATE' AND
			OLD.dns_type IS NOT DISTINCT FROM NEW.dns_type
		THEN
			RETURN NEW;
		END IF;
	END IF;
 */

	IF NEW.dns_type in ('A', 'AAAA') THEN
		IF ( NEW.netblock_id IS NULL AND NEW.dns_value_record_id IS NULL ) THEN
			RAISE EXCEPTION 'Attempt to set % record without netblocks',
				NEW.dns_type
				USING ERRCODE = 'not_null_violation';
		ELSIF NEW.dns_value_record_id IS NOT NULL THEN
			PERFORM *
			FROM dns_record d
			WHERE d.dns_record_id = NEW.dns_value_record_id
			AND d.dns_type = NEW.dns_type
			AND d.dns_class = NEW.dns_class;

			IF NOT FOUND THEN
				RAISE EXCEPTION 'Attempt to set % value record without the correct netblock',
					NEW.dns_type
					USING ERRCODE = 'not_null_violation';
			END IF;
		END IF;

		IF ( NEW.should_generate_ptr = true AND NEW.dns_value_record_id IS NOT NULL ) THEN
			RAISE EXCEPTION 'It is not permitted to set should_generate_ptr and use a dns_value_record_id'
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;

	IF NEW.netblock_Id is not NULL and
			( NEW.dns_value IS NOT NULL OR NEW.dns_value_record_id IS NOT NULL ) THEN
		RAISE EXCEPTION 'Both dns_value and netblock_id may not be set'
			USING ERRCODE = 'JH001';
	END IF;

	IF NEW.dns_value IS NOT NULL AND NEW.dns_value_record_id IS NOT NULL THEN
		RAISE EXCEPTION 'Both dns_value and dns_value_record_id may not be set'
			USING ERRCODE = 'JH001';
	END IF;

	-- XXX need to deal with changing a netblock type and breaking dns_record..
	IF NEW.netblock_id IS NOT NULL THEN
		SELECT ip_address, is_single_address
		  INTO _ip, _sing
		  FROM netblock
		 WHERE netblock_id = NEW.netblock_id;

		IF NEW.dns_type = 'A' AND family(_ip) != '4' THEN
			RAISE EXCEPTION 'A records must be assigned to non-IPv4 records'
				USING ERRCODE = 'JH200';
		END IF;

		IF NEW.dns_type = 'AAAA' AND family(_ip) != '6' THEN
			RAISE EXCEPTION 'AAAA records must be assigned to non-IPv6 records'
				USING ERRCODE = 'JH200';
		END IF;

		IF _sing = false AND NEW.dns_type IN ('A','AAAA') THEN
			RAISE EXCEPTION 'Non-single addresses may not have % records', NEW.dns_type
				USING ERRCODE = 'foreign_key_violation';
		END IF;

	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_a_rec_validation ON dns_record;
CREATE TRIGGER trigger_dns_a_rec_validation
	BEFORE INSERT OR UPDATE
	ON dns_record
	FOR EACH ROW
	EXECUTE PROCEDURE dns_a_rec_validation();
---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION nb_dns_a_rec_validation() RETURNS TRIGGER AS $$
DECLARE
	_tal	integer;
BEGIN
	IF family(OLD.ip_address) != family(NEW.ip_address) THEN
		--
		-- The dns_value_record_id check is not strictly needed since
		-- the "dns_value_record_id" points to something of the same type
		-- and the trigger would catch that, but its here in case some
		-- assumption later changes and its good to test for..
		IF family(NEW.ip_address) = 6 THEN
			SELECT count(*)
			INTO	_tal
			FROM	dns_record
			WHERE	(
						netblock_id = NEW.netblock_id
						AND		dns_type = 'A'
					)
			OR		(
						dns_value_record_id IN (
							SELECT dns_record_id
							FROM	dns_record
							WHERE	netblock_id = NEW.netblock_id
							AND		dns_type = 'A'
						)
					);

			IF _tal > 0 THEN
				RAISE EXCEPTION 'A records must be assigned to IPv4 records'
					USING ERRCODE = 'JH200';
			END IF;
		END IF;

		IF family(NEW.ip_address) = 4 THEN
			SELECT count(*)
			INTO	_tal
			FROM	dns_record
			WHERE	(
						netblock_id = NEW.netblock_id
						AND		dns_type = 'AAAA'
					)
			OR		(
						dns_value_record_id IN (
							SELECT dns_record_id
							FROM	dns_record
							WHERE	netblock_id = NEW.netblock_id
							AND		dns_type = 'AAAA'
						)
					);

			IF _tal > 0 THEN
				RAISE EXCEPTION 'AAAA records must be assigned to IPv6 records'
					USING ERRCODE = 'JH200';
			END IF;
		END IF;
	END IF;

	IF NEW.is_single_address = false THEN
			SELECT count(*)
			INTO	_tal
			FROM	dns_record
			WHERE	netblock_id = NEW.netblock_id
			AND		dns_type IN ('A', 'AAAA');

		IF _tal > 0 THEN
			RAISE EXCEPTION 'Non-single addresses may not have % records', NEW.dns_type
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_nb_dns_a_rec_validation ON netblock;
CREATE TRIGGER trigger_nb_dns_a_rec_validation
	BEFORE UPDATE OF ip_address, is_single_address
	ON netblock
	FOR EACH ROW
	EXECUTE PROCEDURE nb_dns_a_rec_validation();


---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_non_a_rec_validation() RETURNS TRIGGER AS $$
DECLARE
	_ip		netblock.ip_address%type;
BEGIN
	IF NEW.dns_type NOT in ('A', 'AAAA', 'REVERSE_ZONE_BLOCK_PTR') AND
			( NEW.dns_value IS NULL AND NEW.dns_value_record_id IS NULL ) THEN
		RAISE EXCEPTION 'Attempt to set % record without a value',
			NEW.dns_type
			USING ERRCODE = 'not_null_violation';
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_non_a_rec_validation ON dns_record;
CREATE TRIGGER trigger_dns_non_a_rec_validation
	BEFORE INSERT OR UPDATE
	ON dns_record
	FOR EACH ROW
	EXECUTE PROCEDURE dns_non_a_rec_validation();

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION dns_rec_prevent_dups()
RETURNS TRIGGER AS $$
DECLARE
	_tally	INTEGER;
BEGIN
	-- should not be able to insert the same record(s) twice
	SELECT	count(*)
		INTO	_tally
		FROM (
			SELECT
					db.dns_record_id,
					coalesce(ref.dns_name, db.dns_name) as dns_name,
					db.dns_domain_id, db.dns_ttl,
					db.dns_class, db.dns_type,
					coalesce(val.dns_value, db.dns_value) AS dns_value,
					db.dns_priority, db.dns_srv_service, db.dns_srv_protocol,
					db.dns_srv_weight, db.dns_srv_port, db.ip_universe_id,
					coalesce(val.netblock_id, db.netblock_id) AS netblock_id,
					db.reference_dns_record_id, db.dns_value_record_id,
					db.should_generate_ptr, db.is_enabled
				FROM dns_record db
					LEFT JOIN (
							SELECT dns_record_id AS reference_dns_record_id,
									dns_name
							FROM dns_record
							WHERE dns_domain_id = NEW.dns_domain_id
						) ref USING (reference_dns_record_id)
					LEFT JOIN (
							SELECT dns_record_id AS dns_value_record_id,
									dns_value, netblock_id
							FROM dns_record
						) val USING (dns_value_record_id)
				WHERE db.dns_record_id != NEW.dns_record_id
				AND (lower(coalesce(ref.dns_name, db.dns_name))
							IS NOT DISTINCT FROM lower(NEW.dns_name))
				AND ( db.dns_domain_id = NEW.dns_domain_id )
				AND ( db.dns_class = NEW.dns_class )
				AND ( db.dns_type = NEW.dns_type )
				AND db.dns_record_id != NEW.dns_record_id
				AND db.dns_srv_service IS NOT DISTINCT FROM NEW.dns_srv_service
				AND db.dns_srv_protocol IS NOT DISTINCT FROM NEW.dns_srv_protocol
				AND db.dns_srv_port IS NOT DISTINCT FROM NEW.dns_srv_port
				AND db.ip_universe_id IS NOT DISTINCT FROM NEW.ip_universe_id
				AND db.is_enabled = true
			) dns
			LEFT JOIN dns_record val
				ON ( NEW.dns_value_record_id = val.dns_record_id )
		WHERE
			dns.dns_domain_id = NEW.dns_domain_id
		AND
			dns.dns_value IS NOT DISTINCT FROM
				coalesce(val.dns_value, NEW.dns_value)
		AND
			dns.netblock_id IS NOT DISTINCT FROM
				coalesce(val.netblock_id, NEW.netblock_id)
	;

	IF _tally != 0 THEN
		RAISE EXCEPTION 'Attempt to insert the same dns record - % %', _tally,
			NEW USING ERRCODE = 'unique_violation';
	END IF;

	IF NEW.DNS_TYPE = 'A' OR NEW.DNS_TYPE = 'AAAA' THEN
		IF NEW.SHOULD_GENERATE_PTR = true THEN
			SELECT	count(*)
			 INTO	_tally
			 FROM	dns_record
			WHERE dns_class = 'IN'
			AND dns_type = 'A'
			AND should_generate_ptr = true
			AND is_enabled = true
			AND netblock_id = NEW.NETBLOCK_ID
			AND dns_record_id != NEW.DNS_RECORD_ID;

			IF _tally != 0 THEN
				RAISE EXCEPTION 'May not have more than one SHOULD_GENERATE_PTR record on the same IP on netblock_id %', NEW.netblock_id
					USING ERRCODE = 'JH201';
			END IF;
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_rec_prevent_dups ON dns_record;
CREATE CONSTRAINT TRIGGER trigger_dns_rec_prevent_dups
	AFTEr INSERT OR UPDATE
	ON dns_record
	FOR EACH ROW
	EXECUTE PROCEDURE dns_rec_prevent_dups();

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION dns_record_check_name()
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.DNS_NAME IS NOT NULL THEN
		-- rfc rfc952
		IF NEW.DNS_NAME ~ '[^-a-zA-Z0-9\._\*]+' THEN
			RAISE EXCEPTION 'Invalid DNS NAME %',
				NEW.DNS_NAME
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

		-- PTRs on wildcard records break thing and make no sense.
		IF NEW.DNS_NAME ~ '\*' AND NEW.SHOULD_GENERATE_PTR = true THEN
			RAISE EXCEPTION 'Wildcard DNS Record % can not have auto-set PTR',
				NEW.DNS_NAME
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_record_check_name ON dns_record;
CREATE TRIGGER trigger_dns_record_check_name
	BEFORE INSERT OR UPDATE OF DNS_NAME, SHOULD_GENERATE_PTR
	ON dns_record
	FOR EACH ROW
	EXECUTE PROCEDURE dns_record_check_name();

---------------------------------------------------------------------------
--
--
-- Checks for CNAMEs and other records
--
---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_record_cname_checker()
RETURNS TRIGGER AS $$
DECLARE
	_r		RECORD;
	_d		RECORD;
	_dom	TEXT;
BEGIN
	--- XXX - need to seriously think about ip_universes here.
	-- These should also move to the v_dns view once it's cached.  They were
	-- there before, but it was too slow here.

	SELECT dns_name, dns_domain_id, dns_class,
		COUNT(*) FILTER (WHERE dns_type = 'CNAME') AS num_cnames,
		COUNT(*) FILTER (WHERE dns_type != 'CNAME') AS num_not_cnames
	INTO _r
	FROM	(
		SELECT dns_name, dns_domain_id, dns_type, dns_class, ip_universe_id
			FROM dns_record
			WHERE reference_dns_record_id IS NULL
			AND is_enabled = 'Y'
		UNION ALL
		SELECT ref.dns_name, d.dns_domain_id, d.dns_type, d.dns_class,
				d.ip_universe_id
			FROM dns_record d
			JOIN dns_record ref
				ON ref.dns_record_id = d.reference_dns_record_id
			WHERE d.is_enabled = 'Y'
	) smash
	WHERE lower(dns_name) IS NOT DISTINCT FROM lower(NEW.dns_name)
	AND dns_domain_id = NEW.dns_domain_id
	-- AND ip_universe_id = NEW.ip_universe_id
	-- AND dns_class = NEW.dns_class
	GROUP BY 1, 2, 3;

	IF ( _r.num_cnames > 0 AND _r.num_not_cnames > 0 ) OR _r.num_cnames > 1 THEN
		SELECT dns_domain_name INTO _dom FROM dns_domain
		WHERE dns_domain_id = NEW.dns_domain_id ;

		if NEW.dns_name IS NULL THEN
			RAISE EXCEPTION '% may not have CNAME and other records (%/%)',
				_dom, _r.num_cnames, _r.num_not_cnames
				USING ERRCODE = 'unique_violation';
		ELSE
			RAISE EXCEPTION '%.% may not have CNAME and other records (%/%)',
				NEW.dns_name, _dom, _r.num_cnames, _r.num_not_cnames
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_record_cname_checker ON dns_record;
CREATE CONSTRAINT TRIGGER trigger_dns_record_cname_checker
	AFTER INSERT OR
		UPDATE OF dns_class, dns_type, dns_name, dns_domain_id, is_enabled
	ON dns_record
	FOR EACH ROW
	EXECUTE PROCEDURE dns_record_cname_checker();

---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_record_enabled_check()
RETURNS TRIGGER AS $$
BEGIN
	IF new.IS_ENABLED = false THEN
		PERFORM *
		FROM dns_record
		WHERE dns_value_record_id = NEW.dns_record_id
		OR reference_dns_record_id = NEW.dns_record_id;

		IF FOUND THEN
			RAISE EXCEPTION 'Can not disabled records referred to by other enabled records.'
				USING ERRCODE = 'JH001';
		END IF;
	END IF;

	IF new.IS_ENABLED = true THEN
		PERFORM *
		FROM dns_record
		WHERE ( NEW.dns_value_record_id = dns_record_id
				OR NEW.reference_dns_record_id = dns_record_id
		) AND is_enabled = false;

		IF FOUND THEN
			RAISE EXCEPTION 'Can not enable records referencing disabled records.'
				USING ERRCODE = 'JH001';
		END IF;
	END IF;


	RETURN NEW;
END;
$$
LANGUAGE plpgsql
SET search_path=jazzhands
SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_record_enabled_check ON dns_record;
CREATE TRIGGER trigger_dns_record_enabled_check
	BEFORE INSERT OR UPDATE of is_enabled
	ON dns_record
	FOR EACH ROW
	EXECUTE PROCEDURE dns_record_enabled_check();


---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_domain_trigger_change()
RETURNS TRIGGER AS $$
BEGIN
	PERFORM *
	FROM dns_domain_ip_universe
	WHERE dns_domain_id = NEW.dns_domain_id
	AND SHOULD_GENERATE = true;
	IF FOUND THEN
		INSERT INTO dns_change_record
			(dns_domain_id) VALUES (NEW.dns_domain_id);
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_domain_trigger_change ON dns_domain;
CREATE TRIGGER trigger_dns_domain_trigger_change
	AFTER INSERT OR UPDATE OF dns_domain_name
	ON dns_domain
	FOR EACH ROW
	EXECUTE PROCEDURE dns_domain_trigger_change();

---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_domain_ip_universe_can_generate()
RETURNS TRIGGER AS $$
DECLARE
	_c	boolean;
BEGIN
	IF NEW.should_generate = true THEN
		SELECT CAN_GENERATE
		INTO _c
		FROM val_dns_domain_type
		JOIN dns_domain USING (dns_domain_type)
		WHERE dns_domain_id = NEW.dns_domain_id;

		IF _c != true THEN
			RAISE EXCEPTION 'This dns_domain_type may not be autogenerated.'
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_domain_ip_universe_can_generate ON dns_domain_ip_universe;
CREATE TRIGGER trigger_dns_domain_ip_universe_can_generate
	AFTER INSERT OR UPDATE OF should_generate
	ON dns_domain_ip_universe
	FOR EACH ROW
	EXECUTE PROCEDURE dns_domain_ip_universe_can_generate();

---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_domain_type_should_generate()
RETURNS TRIGGER AS $$
DECLARE
	_c	INTEGER;
BEGIN
	IF NEW.can_generate = false THEN
		SELECT count(*)
		INTO _c
		FROM dns_domain
		WHERE dns_domain_type = NEW.dns_domain_type
		AND should_generate = true;

		IF _c != true THEN
			RAISE EXCEPTION 'May not change can_generate with existing autogenerated zones.'
				USING ERRCODE = 'integrity_constraint_violation';
		END IF;

	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_domain_type_should_generate ON val_dns_domain_type;
CREATE TRIGGER trigger_dns_domain_type_should_generate
	AFTER UPDATE OF can_generate
	ON val_dns_domain_type
	FOR EACH ROW
	EXECUTE PROCEDURE dns_domain_type_should_generate();

---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_domain_ip_universe_trigger_change()
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.should_generate = true THEN
		--
		-- kind of a weird case, but if last_generated matches
		-- the last change date of the zone, then its part of actually
		-- regenerating and should not get a change record otherwise
		-- that would constantly create change records.
		--
		IF TG_OP = 'INSERT' OR NEW.last_generated < NEW.data_upd_date THEN
			INSERT INTO dns_change_record
			(dns_domain_id) VALUES (NEW.dns_domain_id);
		END IF;
    ELSE
		DELETE FROM DNS_CHANGE_RECORD
		WHERE dns_domain_id = NEW.dns_domain_id
		AND ip_universe_id = NEW.ip_universe_id;
	END IF;

	--
	-- When its not a change as part of zone generation, mark it as
	-- something that needs to be addressed by zonegen
	--
	RETURN NEW;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_domain_ip_universe_trigger_change
	ON dns_domain_ip_universe;
CREATE TRIGGER trigger_dns_domain_ip_universe_trigger_change
	AFTER INSERT OR UPDATE OF soa_class, soa_ttl, soa_serial,
		soa_refresh, soa_retry, soa_expire, soa_minimum, soa_mname,
		soa_rname, should_generate
	ON dns_domain_ip_universe
	FOR EACH ROW
	EXECUTE PROCEDURE dns_domain_ip_universe_trigger_change();

---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_domain_ip_universe_trigger_del()
RETURNS TRIGGER AS $$
DECLARE  _r RECORD;
BEGIN
	-- this all needs to be rethunk in light of when this can be NULL
	IF OLD.should_generate THEN
		DELETE FROM dns_change_record
		WHERE dns_domain_id = OLD.dns_domain_id
		AND (
			ip_universe_id = OLD.ip_universe_id
			OR ip_universe_id IS NULL
		);
	END IF;

	FOR _r IN SELECT * FROM dns_change_record
	LOOP
	END LOOP;

	RETURN OLD;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=jazzhands;

DROP TRIGGER IF EXISTS trigger_dns_domain_ip_universe_trigger_del
	ON dns_domain_ip_universe;
CREATE TRIGGER trigger_dns_domain_ip_universe_trigger_del
	BEFORE DELETE
	ON dns_domain_ip_universe
	FOR EACH ROW
	EXECUTE PROCEDURE dns_domain_ip_universe_trigger_del();


---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_change_record_pgnotify()
RETURNS TRIGGER AS $$
BEGIN
	NOTIFY dns_zone_gen;
	RETURN NEW;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=jazzhands;

DROP TRIGGER IF EXISTS trigger_dns_change_record_pgnotify ON dns_change_record;
CREATE TRIGGER trigger_dns_change_record_pgnotify
	AFTER INSERT OR UPDATE
	ON dns_change_record
	EXECUTE PROCEDURE dns_change_record_pgnotify();
