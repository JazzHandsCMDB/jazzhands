-- Copyright (c) 2014 Todd M. Kover
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

-- $Id$

-- The following columns are being retired in favor of postgresql functions:
-- 	netmask_bits, is_ipv4_address
--
-- This trigger allows them to not be touched but keeps them set until they
-- go away...
CREATE OR REPLACE FUNCTION retire_netblock_columns()
RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'INSERT' THEN
		IF NEW.NETMASK_BITS IS NULL THEN
			NEW.NETMASK_BITS := masklen(NEW.ip_address);
		END IF;
		IF NEW.IS_IPV4_ADDRESS  IS NULL THEN
			IF family(NEW.ip_address) = 4 THEN
				NEW.IS_IPV4_ADDRESS := 'Y';
			ELSE
				NEW.IS_IPV4_ADDRESS := 'N';
			END IF;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.IP_ADDRESS != OLD.IP_ADDRESS THEN
			IF OLD.NETMASK_BITS = NEW.NETMASK_BITS THEN
				NEW.NETMASK_BITS := masklen(NEW.ip_address);
			END IF;
			IF OLD.IS_IPV4_ADDRESS = NEW.IS_IPV4_ADDRESS THEN
				IF family(NEW.ip_address) = 4 THEN
					NEW.IS_IPV4_ADDRESS := 'Y';
				ELSE
					NEW.IS_IPV4_ADDRESS := 'N';
				END IF;
			END IF;
		END IF;
	ELSE
		RAISE EXCEPTION 'This should never happen.';
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS zzzz_trigger_retire_netblock_columns ON netblock;
CREATE TRIGGER zzzz_trigger_retire_netblock_columns
	BEFORE INSERT OR UPDATE OF ip_address, netmask_bits, is_ipv4_address
	ON netblock 
	FOR EACH ROW EXECUTE PROCEDURE retire_netblock_columns();

--
-- If stuff in inet and netmask_bits/ipv4 mismatch, complain
--
CREATE OR REPLACE FUNCTION netblock_complain_on_mismatch()
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.IS_IPV4_ADDRESS IS NULL or NEW.NETMASK_BITS IS NULL THEN
		RAISE EXCEPTION 'IS_IPv4_ADDRESS or NETMASK_BITS may not be NULL'
			USING ERRCODE = 'not_null_violation';
	END IF;

	IF NEW.IS_IPV4_ADDRESS = 'Y' and family(NEW.ip_address) != 4 THEN
		RAISE EXCEPTION 'is_ipv4_address must match family(NEW.ip_address)'
			USING ERRCODE = 'JH0FF';
	END IF;

	IF NEW.IS_IPV4_ADDRESS != 'Y' and family(NEW.ip_address) = 4 THEN
		RAISE EXCEPTION 'is_ipv4_address must match family(NEW.ip_address)'
			USING ERRCODE = 'JH0FF';
	END IF;

	IF NEW.NETMASK_BITS != masklen(NEW.ip_address) THEN
		RAISE EXCEPTION 'netmask_bits must match masklen(NEW.ip_address)'
			USING ERRCODE = 'JH0FF';
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_netblock_complain_on_mismatch ON netblock;
CREATE TRIGGER trigger_netblock_complain_on_mismatch
	AFTER INSERT OR UPDATE OF ip_address, netmask_bits, is_ipv4_address
	ON netblock 
	FOR EACH ROW EXECUTE PROCEDURE netblock_complain_on_mismatch();
