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

drop schema if exists net_manip cascade;
create schema net_manip authorization jazzhands;

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
	p_ip_address			in inet,
	p_raise_exception_on_error	in integer 	default 0
)
returns inet AS $$
BEGIN
	return(p_ip_address);
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
returns inet AS $$
BEGIN
	return( p_ip_address );	 --  may want this to be host(inet)
END;
$$ LANGUAGE plpgsql;
-- end of net_manip.inet_dbtop
-------------------------------------------------------------------

CREATE OR REPLACE FUNCTION net_manip.inet_bits_to_mask
	(
	p_bits				in integer
	)
returns inet AS $$
BEGIN
	return( netmask(cast('0.0.0.0/' || p_bits as INET)) );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE function net_manip.inet_mask_to_bits
	(
	p_netmask			in inet
	)
returns integer AS $$
BEGIN
	return (32-log(2, 4294967296 - net_manip.inet_dbton(p_netmask)))::integer;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE function net_manip.inet_base
	(
	p_ip_address		in		inet,
	p_bits			in		integer
	)
returns inet AS $$
DECLARE
	host inet;
BEGIN
	host = host(p_ip_address) || '/' || p_bits;
	return network(host);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE function net_manip.inet_is_private_yn
	(
	p_ip_address		  in		  inet
	)
returns char AS $$
BEGIN
	if( net_manip.inet_is_private(p_ip_address)) THEN
		return 'Y';
	else
		return 'N';
	end if;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE function net_manip.inet_is_private
	(
	p_ip_address		in		inet
	)
returns boolean AS $$
BEGIN
	if( family(p_ip_address) = 4) THEN
		if('192.168/16' >> p_ip_address) THEN
			return(true);
		END IF;
		if('10/8' >> p_ip_address) THEN
			return(true);
		END IF;
		if('172.16/12' >> p_ip_address) THEN
			return(true);
		END IF;
		if('172.16/12' >> p_ip_address) THEN
			return(true);
		END IF;
	else
		if('FC00::/7' >> p_ip_address) THEN
			return(true);
		end if;
	END IF;

	return(false);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE function net_manip.inet_inblock
	(
	p_network		in		inet,
	p_bits			in		integer,
	p_ipaddr		in		inet
	)
returns char AS $$
BEGIN
	return(
		cast(host(p_network) || '/' || p_bits as inet) >>
			host(p_ipaddr)
	);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE function net_manip.inet_dbton
	(
	p_ipaddr		in		inet
	)
returns bigint AS $$
BEGIN
	IF( family(p_ip_address) = 4) THEN
		return(
			((split_part(host(p_ipaddr), '.', 1))::BIGINT << 24) +
			((split_part(host(p_ipaddr), '.', 2))::BIGINT << 16) +
			((split_part(host(p_ipaddr), '.', 3))::BIGINT << 8) +
			((split_part(host(p_ipaddr), '.', 4))::BIGINT) 
		);
	ELSE
		RAISE EXCEPTION 'Netmasks unsupported for IPv6';
	END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE function net_manip.inet_ntodb
	(
	p_ipaddr		in		bigint
	)
returns inet AS $$
BEGIN
	IF( family(p_ip_address) != 4) THEN
		RAISE EXCEPTION 'Netmasks unsupported for IPv6.';
	ELSE
		RAISE EXCEPTION 'Not implemented Yet. - XXX';
	END IF;
END;
$$ LANGUAGE plpgsql;
