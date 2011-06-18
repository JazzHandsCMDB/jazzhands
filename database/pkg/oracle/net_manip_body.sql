-- Copyright (c) 2011, Todd M. Kover
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--     * Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--     * Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
-- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
/*
 * $Id$
 */

/*

XXXXXXXXXXXXXXXXXXXXXXXXXXXX NOTE XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

ONLY inet_ptodb and inet_dbtop are implemented for v6.   The others operate
on ipv4 ONLY.  This needs to be fixed before any oracle release happens

XXXXXXXXXXXXXXXXXXXXXXXXXXXX NOTE XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

 */

create or replace package body net_manip
IS
	-------------------------------------------------------------------
	-- for config management
	-------------------------------------------------------------------
	FUNCTION id_tag 
	RETURN VARCHAR2
	IS
	BEGIN
     		RETURN('<-- $Id$ -->');
	END;
	--end of procedure id_tag
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- given a varchar dotted quad, returns the integer value of the IP
	-- address.  if p_raise_exception_on_error, Java will throw an
	-- exception, otherwise it returns -1
	-------------------------------------------------------------------
	function java_v4_int_from_octet
	(
		p_ip_address			in varchar2,
		p_raise_exception_on_error	in number
	)
	return number
	DETERMINISTIC
	AS LANGUAGE JAVA
	NAME 'IPv4Manip.v4_int_from_octet(java.lang.String, int)
		return long';
	-- end of procedure java_v4_int_from_octet
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- given a varchar human readable IPv6 address, returns theinteger
	-- value.  If p_raise_exception_on_error, Java will throw an
	-- exception, otherwise it returns -1
	-------------------------------------------------------------------
	function java_v6_int_from_octet
	(
		p_ip_address			in varchar2,
		p_raise_exception_on_error	in number
	)
	return number
	DETERMINISTIC
	AS LANGUAGE JAVA
	NAME 'IPv6Manip.v6_int_from_string(java.lang.String, int)
		return BigInteger';
	-- end of procedure java_v4_int_from_octet
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- Given a human printable address, returns a number. If
	-- p_raise_exception_on_error is printed, it lets Java throw an
	-- error, otherwise, not so much
	--
	-- NOTE: the second argument to ipv6 may not work
	-------------------------------------------------------------------
	function inet_ptodb
	(
		p_ip_address			in varchar2,
		p_raise_exception_on_error	in number 	default 0
	)
	return number 
	DETERMINISTIC
	as 
		v_rv number;
	begin
		IF (instr(p_ip_address, ':') > 0 ) THEN
			v_rv := java_v6_int_from_string(p_ip_address,
				p_raise_exception_on_error);
		ELSE
			v_rv := java_v4_int_from_octet(p_ip_address,
				p_raise_exception_on_error);
		END IF;
		if(v_rv = -1) then
			return(NULL);
		end if;
		return(v_rv);
	end;
	-- end of procedure inet_ptodb
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- given a number, returns a dotted quad
	-------------------------------------------------------------------
	function java_v4_string_from_int
		(
		p_numeric_ip_address in  number
		)
	return varchar2
	DETERMINISTIC
	AS LANGUAGE java
	NAME 'IPv4Manip.LongToString(long)
		return java.lang.String';
	-- end of procedure java_v4_octet_from_int
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- given a number, returns the human readable ipv6 version
	-------------------------------------------------------------------
	function java_v6_string_from_number
		(
		p_numeric_ip_address in  number
		)
	return varchar2
	DETERMINISTIC
	AS LANGUAGE JAVA
	NAME 'IPv6Manip.v6_string_from_int(BigInteger)
		return java.lang.String';
	-- end of procedure java_v6_string_from_octet
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- Given a number, return the human readable form.  Takes a second
	-- argument to force it to be a v6 or v4 number, otherwise tries to
	-- guess
	--
	-------------------------------------------------------------------
	function inet_dbtop
	(
		p_numeric_ip_address		in number,
		p_ipvnum			in number	DEFAULT NULL
	)
	return varchar2 
	DETERMINISTIC
	as
		v_ipvnum number;
	begin
		v_ipvnum := p_ipvnum;
		IF (v_ipvnum is null) THEN
			IF (p_numeric_ip_address = 1) THEN 
				v_ipvnum := 6;
			ELSE
				IF (p_numeric_ip_address > 4294967295) THEN 
					v_ipvnum := 6;
				ELSE
					v_ipvnum := 4;
				END IF;
			END IF;
		END IF;
		if(v_ipvnum = 4) THEN
			return java_v4_string_from_int(p_numeric_ip_address);
		END IF;
		if(v_ipvnum = 6) THEN
			return java_v6_string_from_number(p_numeric_ip_address);
		END IF;
		return(-1);
	end;
	-- end of procedure inet_dbtop
	-------------------------------------------------------------------

	

	-------------------------------------------------------------------
	-- given the number of significant bits returns a number that is the
	-- netmask
	-------------------------------------------------------------------
	function inet_bits_to_mask
		(
		p_bits				in		  number
		)
	return number
	DETERMINISTIC
	AS LANGUAGE JAVA
	NAME 'IPv4Manip.BitsToNetmask(int)
		return long';
	-- end of procedure inet_bits_to_mask
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- given a numeric netmask, returns the number of significant bits
	-------------------------------------------------------------------
	function inet_mask_to_bits
		(
		p_netmask				in		  number
		)
	return number
	DETERMINISTIC
	AS LANGUAGE JAVA
	NAME 'IPv4Manip.NetmaskStringToBits(long)
		return int';
	-- end of procedure inet_mask_to_bits
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- given an IP address and bits, returns the network address (the
	-- lowest address in that netblock)
	-------------------------------------------------------------------
	function v4_base_java
		(
		p_ip_address		in		number,
		p_bits			in		number
		)
	return number
	DETERMINISTIC
	AS LANGUAGE JAVA
	NAME 'IPv4Manip.NetworkOfIp(long, int)
		return long';
	-- end of procedure v4_base
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- calls v4_base_java, but is smart enough to return 0 if the
	-- addres is not ipv4 rather than throw an exception.
	-------------------------------------------------------------------
	function inet_base
		(
		p_ip_address		in		number,
		p_bits			in		number
		)
	return number
	DETERMINISTIC
	AS 
	begin
		if(p_ip_address > 4294967295) then
			return( 0 );
		end if;
		return(v4_base_java(p_ip_address, p_bits));
	end;
	-- end of procedure inet_base
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- returns 'Y' if an addres is in rfc1918/4193 space, 
	-- otherwise returns 'N'
	-------------------------------------------------------------------
	function inet_is_private_yn
		(
		p_ip_address		  in		  number
		)
	return varchar2
	DETERMINISTIC
	AS LANGUAGE JAVA
	NAME 'IPv4Manip.IsIp1918Space_yn(long)
		return java.lang.String';
	-- end of procedure inet_is_private_yn
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	function inet_is_private
		(
		p_ip_address		in		number
		)
	return boolean
	DETERMINISTIC
	as
	begin
		if(inet_is_private_yn(p_ip_address) = 'Y') then
			return(true);
		end if;
		return(false);
	end;
	-- end of procedure inet_is_private_yn
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	function inet_inblock
		(
		p_network		in		number,
		p_bits			in		number,
		p_ipaddr		in		number
		)
	return varchar2
	DETERMINISTIC
	AS LANGUAGE JAVA
	NAME 'IPv4Manip.IsIpInNet_yn(java.math.BigInteger, int, long)
		return java.lang.String';
	-- end of procedure inet_inblock
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-------------------------------------------------------------------
	function java_v6_int_from_string
	(
		p_ip_address			in varchar2,
		p_raise_exception_on_error	in number
	)
	return number
	DETERMINISTIC
	AS LANGUAGE JAVA
	NAME 'IPv6Manip.v6_int_from_string(java.lang.String, int)
		return java.math.BigInteger';
	-- end of procedure java_v4_int_from_string
	-------------------------------------------------------------------
end;
/
show errors;
