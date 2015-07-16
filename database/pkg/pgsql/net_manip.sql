-- Copyright (c) 2011, Todd M. Kover
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
 * $Id$
 */

DO $$
DECLARE
        _tal INTEGER;
BEGIN
        select count(*)
        from pg_catalog.pg_namespace
        into _tal
        where nspname = 'net_manip';
        IF _tal = 0 THEN
                DROP SCHEMA IF EXISTS net_manip;
                CREATE SCHEMA net_manip AUTHORIZATION jazzhands;
		COMMENT ON SCHEMA net_manip IS 'part of jazzhands';
        END IF;
END;
$$;

-------------------------------------------------------------------
-- returns the Id tag for CM
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION net_manip.id_tag()
RETURNS VARCHAR AS $$
BEGIN
	RETURN('<-- $Id -->');
END;
$$ LANGUAGE plpgsql;
-- end of procedure id_tag
-------------------------------------------------------------------

-------------------------------------------------------------------
-- returns its first argument (noop under postgresql)
-------------------------------------------------------------------

CREATE OR REPLACE FUNCTION net_manip.inet_ptodb
(
	p_ip_address			in inet
)
RETURNS inet AS $$
BEGIN
	return(p_ip_address);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION net_manip.inet_ptodb
(
	p_ip_address			in inet,
	p_netmask_bits			in integer
)
RETURNS inet AS $$
BEGIN
	return(set_masklen(p_ip_address, p_netmask_bits));
END;
$$ LANGUAGE plpgsql;

-- end of net_manip.inet_ptodb
-------------------------------------------------------------------

-------------------------------------------------------------------
-- returns its first argument (noop under postgresql)
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION net_manip.inet_dbtop
(
	p_ip_address			in inet
)
RETURNS inet AS $$
BEGIN
	return( host(p_ip_address) );
END;
$$ LANGUAGE plpgsql;
-- end of net_manip.inet_dbtop
-------------------------------------------------------------------

CREATE OR REPLACE FUNCTION net_manip.inet_bits_to_mask
	(
	p_bits				in integer
	)
RETURNS inet AS $$
BEGIN
	IF p_bits > 32 OR p_bits < 0 THEN
		RAISE EXCEPTION 'Value for p_bits must be between 0 and 32';
	END IF;
		
	RETURN( netmask(cast('0.0.0.0/' || p_bits AS inet)) );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION net_manip.inet_mask_to_bits
	(
	p_netmask			in inet
	)
RETURNS integer AS $$
BEGIN
	IF family(p_netmask) = 6 THEN
		RAISE EXCEPTION 'Netmask is not supported for IPv6 addresses';
	END IF;
	RETURN (32-log(2, 4294967296 - net_manip.inet_dbton(p_netmask)))::integer;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION net_manip.inet_base
	(
	p_ip_address		in		inet,
	p_bits			in		integer
	)
RETURNS inet AS $$
DECLARE
	host inet;
BEGIN
	host = set_masklen(p_ip_address, p_bits);
	return network(host);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION net_manip.inet_is_private_yn
	(
	p_ip_address		  in		  inet
	)
RETURNS char AS $$
BEGIN
	IF (net_manip.inet_is_private(p_ip_address)) THEN
		RETURN 'Y';
	ELSE
		RETURN 'N';
	END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION net_manip.inet_is_private
	(
	p_ip_address		in		inet
	)
RETURNS boolean AS $$
BEGIN
	IF( family(p_ip_address) = 4) THEN
		IF ('192.168/16' >> p_ip_address) THEN
			RETURN(true);
		END IF;
		IF ('10/8' >> p_ip_address) THEN
			RETURN(true);
		END IF;
		IF ('172.16/12' >> p_ip_address) THEN
			RETURN(true);
		END IF;
	else
		IF ('FC00::/7' >> p_ip_address) THEN
			RETURN(true);
		END IF;
	END IF;

	RETURN(false);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE function net_manip.inet_inblock
	(
	p_network		in		inet,
	p_bits			in		integer,
	p_ipaddr		in		inet
	)
RETURNS char AS $$
BEGIN
	RETURN(
		CAST(host(p_network) || '/' || p_bits AS inet) >> p_ipaddr
	);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE function net_manip.inet_dbton
	(
	p_ipaddr		in		inet
	)
RETURNS bigint AS $$
BEGIN
	IF (family(p_ipaddr) = 4) THEN
		RETURN p_ipaddr - '0.0.0.0';
	ELSE
		RETURN p_ipaddr - '::0';
	END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE function net_manip.inet_ntodb
	(
	p_ipaddr		in		bigint
	)
RETURNS inet AS $$
BEGIN
	IF p_ipaddr > 4294967296 OR p_ipaddr < 16777216 THEN
		RETURN inet('::0') + p_ipaddr;
	ELSE
		RETURN inet('0.0.0.0') + p_ipaddr;
	END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE function net_manip.inet_ntodb
	(
	p_ipaddr		in		bigint,
	p_netmask_bits	in		integer
	)
RETURNS inet AS $$
BEGIN
	RETURN(set_masklen(net_manip.inet_ntodb(p_ipaddr), p_netmask_bits));
END;
$$ LANGUAGE plpgsql;

------------------------------------------------------------------------------
--
-- Expand an IPv6 address completely (returns text) into eight segmenets,
-- with for elements each, zero filled
--
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION net_manip.expand_ipv6_address (
	ip		inet
) RETURNS text AS
$$
DECLARE
	parts	text[];
	proc	text[];
	elem	text;
	zero	text;
	tally	integer;
	rv		text;
BEGIN
	IF family(ip) != 6 THEN
		RAISE EXCEPTION 'net_manip.expand_ipv6_address only works on IPv6 addresses'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;
	-- end up with an array for each element, with an empty block being a
	-- spot that should be zero filled.  Due to regexp matching, a :: at the
	-- end will leave extra empty blocks at the end.
	-- This basically makes it so the empty array element needs to be zero
	-- expanded.
	parts := regexp_split_to_array(
		regexp_replace(
			regexp_replace(ip::text, '::/\d+$', ':'),
				'^:?([a-f0-9:]*):?(/\d+)?$', E'\\1', 'i'), ':'
		);

	--
	-- go through elements and zero fill them.
	tally := 0;
	FOREACH elem in ARRAY parts
	LOOP
		IF char_length(elem) > 0 THEN
			proc = proc || lpad(elem, 4, '0');
			tally := tally + 1;
		ELSE
			proc = proc || elem;
		END IF;
	END LOOP;

	-- figure out how big the zero expansion needs to be for later placement
	zero := '';
	tally := 8 - tally;
	WHILE tally > 0
	LOOP
		zero := zero || ':' || lpad('', 4, '0');
		tally := tally - 1;
	END LOOP;
	zero := regexp_replace(zero, '^:', '');

	--
	-- to through all the elements and find the empty one that should be
	-- zero filled
	parts := ARRAY[]::text[];
	FOREACH elem in ARRAY proc
	LOOP
		IF char_length(elem) > 0 THEN
			parts := parts || elem;
		ELSE
			parts := parts || zero;
		END IF;
	END LOOP;
	rv := array_to_string(parts, ':');
	RETURN rv;
END;
$$
LANGUAGE plpgsql;
