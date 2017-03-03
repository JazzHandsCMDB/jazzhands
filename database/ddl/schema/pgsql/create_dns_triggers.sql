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
				IF NEW.SHOULD_GENERATE_PTR = 'Y' THEN
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

		IF ( NEW.should_generate_ptr = 'Y' AND NEW.dns_value_record_id IS NOT NULL ) THEN
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

		IF _sing = 'N' AND NEW.dns_type IN ('A','AAAA') THEN
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

	IF NEW.is_single_address = 'N' THEN
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
	WITH newref AS (
		SELECT * FROM dns_record
			WHERE NEW.reference_dns_record_id IS NOT NULL
			AND NEW.reference_dns_record_id = dns_record_id
			ORDER BY dns_record_id LIMIT 1
	), dns AS ( SELECT
			db.dns_record_id,
			coalesce(ref.dns_name, db.dns_name) as dns_name,
			db.dns_domain_id, db.dns_ttl,
			db.dns_class, db.dns_type,
			coalesce(val.dns_value, db.dns_value) AS dns_value,
			db.dns_priority, db.dns_srv_service, db.dns_srv_protocol,
			db.dns_srv_weight, db.dns_srv_port,
			coalesce(val.netblock_id, db.netblock_id) AS netblock_id,
			db.reference_dns_record_id, db.dns_value_record_id,
			db.should_generate_ptr, db.is_enabled
		FROM dns_record db
			LEFT JOIN dns_record ref
				ON ( db.reference_dns_record_id = ref.dns_record_id)
			LEFT JOIN dns_record val
				ON ( db.dns_value_record_id = val.dns_record_id )
			LEFT JOIN newref
				ON newref.dns_record_id = NEW.reference_dns_record_id
		WHERE db.dns_record_id != NEW.dns_record_id
		AND (lower(coalesce(ref.dns_name, db.dns_name))
					IS NOT DISTINCT FROM
				lower(coalesce(newref.dns_name, NEW.dns_name)) )
		AND ( db.dns_domain_id = NEW.dns_domain_id )
		AND ( db.dns_class = NEW.dns_class )
		AND ( db.dns_type = NEW.dns_type )
    		AND db.dns_record_id != NEW.dns_record_id
		AND db.dns_srv_service IS NOT DISTINCT FROM NEW.dns_srv_service
		AND db.dns_srv_protocol IS NOT DISTINCT FROM NEW.dns_srv_protocol
		AND db.dns_srv_port IS NOT DISTINCT FROM NEW.dns_srv_port
		AND db.is_enabled = 'Y'
	) SELECT	count(*)
		INTO	_tally
		FROM dns
			LEFT JOIN dns_record val
				ON ( NEW.dns_value_record_id = val.dns_record_id )
		WHERE
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
		IF NEW.SHOULD_GENERATE_PTR = 'Y' THEN
			SELECT	count(*)
			 INTO	_tally
			 FROM	dns_record
			WHERE dns_class = 'IN'
			AND dns_type = 'A'
			AND should_generate_ptr = 'Y'
			AND is_enabled = 'Y'
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
CREATE TRIGGER trigger_dns_rec_prevent_dups
	BEFORE INSERT OR UPDATE
	ON dns_record
	FOR EACH ROW
	EXECUTE PROCEDURE dns_rec_prevent_dups();

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION dns_record_check_name()
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.DNS_NAME IS NOT NULL THEN
		-- rfc rfc952
		IF NEW.DNS_NAME !~ '[-a-zA-Z0-9\._]*' THEN
			RAISE EXCEPTION 'Invalid DNS NAME %',
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
	BEFORE INSERT OR UPDATE OF DNS_NAME
	ON dns_record
	FOR EACH ROW
	EXECUTE PROCEDURE dns_record_check_name();

---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_record_cname_checker()
RETURNS TRIGGER AS $$
DECLARE
	_tally	INTEGER;
	_dom	TEXT;
BEGIN
	_tally := 0;
	IF TG_OP = 'INSERT' OR NEW.DNS_TYPE != OLD.DNS_TYPE THEN
		IF NEW.DNS_TYPE = 'CNAME' THEN
			IF TG_OP = 'UPDATE' THEN
			SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE
						NEW.dns_domain_id = x.dns_domain_id
				 AND	OLD.dns_record_id != x.dns_record_id
				 AND	(
							NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			ELSE
				-- only difference between above and this is the use of OLD
				SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE
						NEW.dns_domain_id = x.dns_domain_id
				 AND	(
							NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			END IF;
		-- this clause is basically the same as above except = 'CANME'
		ELSIF NEW.DNS_TYPE != 'CNAME' THEN
			IF TG_OP = 'UPDATE' THEN
				SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE	x.dns_type = 'CNAME'
				 AND	NEW.dns_domain_id = x.dns_domain_id
				 AND	OLD.dns_record_id != x.dns_record_id
				 AND	(
							NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			ELSE
				-- only difference between above and this is the use of OLD
				SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE	x.dns_type = 'CNAME'
				 AND	NEW.dns_domain_id = x.dns_domain_id
				 AND	(
							NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			END IF;
		END IF;
	END IF;

	IF _tally > 0 THEN
		SELECT soa_name INTO _dom FROM dns_domain
		WHERE dns_domain_id = NEW.dns_domain_id ;

		if NEW.dns_name IS NULL THEN
			RAISE EXCEPTION '% may not have CNAME and other records (%)',
				_dom, _tally
				USING ERRCODE = 'unique_violation';
		ELSE
			RAISE EXCEPTION '%.% may not have CNAME and other records (%)',
				NEW.dns_name, _dom, _tally
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_record_cname_checker ON dns_record;
CREATE TRIGGER trigger_dns_record_cname_checker
	BEFORE INSERT OR UPDATE OF dns_type
	ON dns_record
	FOR EACH ROW
	EXECUTE PROCEDURE dns_record_cname_checker();

---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_record_enabled_check()
RETURNS TRIGGER AS $$
BEGIN
	IF new.IS_ENABLED = 'N' THEN
		PERFORM *
		FROM dns_record
		WHERE dns_value_record_id = NEW.dns_record_id
		OR reference_dns_record_id = NEW.dns_record_id;

		IF FOUND THEN
			RAISE EXCEPTION 'Can not disabled records referred to by other enabled records.'
				USING ERRCODE = 'JH001';
		END IF;
	END IF;

	IF new.IS_ENABLED = 'Y' THEN
		PERFORM *
		FROM dns_record
		WHERE ( NEW.dns_value_record_id = dns_record_id
				OR NEW.reference_dns_record_id = dns_record_id
		) AND is_enabled = 'N';

		IF FOUND THEN
			RAISE EXCEPTION 'Can not enable records referencing disabled records.'
				USING ERRCODE = 'JH001';
		END IF;
	END IF;


	RETURN NEW;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER;

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
	IF new.SHOULD_GENERATE = 'Y' THEN
		insert into DNS_CHANGE_RECORD
			(dns_domain_id) VALUES (NEW.dns_domain_id);
	END IF;
	RETURN NEW;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_domain_trigger_change ON dns_domain;
CREATE TRIGGER trigger_dns_domain_trigger_change
	AFTER INSERT OR UPDATE OF soa_name, soa_class, soa_ttl,
		soa_refresh, soa_retry, soa_expire, soa_minimum, soa_mname,
		soa_rname, should_generate
	ON dns_domain
	FOR EACH ROW
	EXECUTE PROCEDURE dns_domain_trigger_change();

---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dns_change_record_pgnotify()
RETURNS TRIGGER AS $$
BEGIN
	NOTIFY dns_zone_gen;
	RETURN NEW;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_change_record_pgnotify ON dns_change_record;
CREATE TRIGGER trigger_dns_change_record_pgnotify
	AFTER INSERT OR UPDATE
	ON dns_change_record
	EXECUTE PROCEDURE dns_change_record_pgnotify();
