-- Copyright (c) 2005-2010, Vonage Holdings Corp.
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

create or replace package body ip_manip
IS
	-------------------------------------------------------------------
	-- returns the Id tag for CM
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
	-- given a varchar dotted quad, returns the integer value of the IP
	-- address.  if p_raise_exception_on_error, lets Java will throw an
	-- exception, otherwise it returns NULL1
	-------------------------------------------------------------------
	function v4_int_from_octet
	(
		p_ip_address			in varchar2,
		p_raise_exception_on_error	in number 	default 0
	)
	return number 
	DETERMINISTIC
	as 
		v_rv number;
	begin
		v_rv := java_v4_int_from_octet(p_ip_address,
			p_raise_exception_on_error);
		if(v_rv = -1) then
			return(NULL);
		end if;
		return(v_rv);
	end;
	-- end of procedure v4_int_from_octet
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- given a number, returns the varchar representation of that as a
	-- dotted quad 
	-------------------------------------------------------------------
	function v4_octet_from_int
		(
		p_numeric_ip_address		  in		  number
		)
	return varchar2
	DETERMINISTIC
	AS LANGUAGE java
	NAME 'IPv4Manip.LongToString(long)
		return java.lang.String';
	-- end of procedure v4_octet_from_int
	-------------------------------------------------------------------


	-------------------------------------------------------------------
	-- given the number of significant bits returns a number that is the
	-- netmask
	-------------------------------------------------------------------
	function v4_netmask_from_bits
		(
		p_bits				in		  number
		)
	return number
	DETERMINISTIC
	AS LANGUAGE JAVA
	NAME 'IPv4Manip.BitsToNetmask(int)
		return long';
	-- end of procedure v4_netmask_from_bits
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- given a numeric netmask, returns the number of significant bits
	-------------------------------------------------------------------
	function v4_bits_from_netmask
		(
		p_netmask				in		  number
		)
	return number
	DETERMINISTIC
	AS LANGUAGE JAVA
	NAME 'IPv4Manip.NetmaskStringToBits(long)
		return int';
	-- end of procedure v4_bits_from_netmask
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
	function v4_base
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
	-- end of procedure v4_base
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- returns 'Y' if an addres is in 1918 space, otherwise returns 'N'
	-------------------------------------------------------------------
	function v4_is_private_yn
		(
		p_ip_address		  in		  number
		)
	return varchar2
	DETERMINISTIC
	AS LANGUAGE JAVA
	NAME 'IPv4Manip.IsIp1918Space_yn(long)
		return java.lang.String';
	-- end of procedure v4_is_private_yn
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	function v4_is_private
		(
		p_ip_address		in		number
		)
	return boolean
	DETERMINISTIC
	as
	begin
		if(v4_is_private_yn(p_ip_address) = 'Y') then
			return(true);
		end if;
		return(false);
	end;
	-- end of procedure v4_is_private
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	function v4_is_in_block
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
	-- end of procedure v4_is_in_block
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
	-- end of procedure java_v4_int_from_octet
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- given a textual string, return an integer.
	-- if p_raise_exception_on_error, lets Java will throw an
	-- exception, otherwise it returns NULL1
	-------------------------------------------------------------------
	function v6_int_from_string
	(
		p_ip_address			in varchar2,
		p_raise_exception_on_error	in number 	default 0
	)
	return number 
	DETERMINISTIC
	as 
		v_rv number;
	begin
		v_rv := java_v6_int_from_string(p_ip_address,
			p_raise_exception_on_error);
		if(v_rv = -1) then
			return(NULL);
		end if;
		return(v_rv);
	end;
	-- end of procedure v4_int_from_octet
	-------------------------------------------------------------------
end;
/
show errors;
