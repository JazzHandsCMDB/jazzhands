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

---------------------------------------------------------------------------
-- DESCRIPTION: This package provides routines to manipulate IP addresses
-- and networks.  It's primarily an interface to java routines that do most
-- of the work
---------------------------------------------------------------------------
-- $Id$

--
-- here's what needs to be done to load this into an oracle environment
-- and make it accessible from PL/SQL
--
-- 0. process source and compile
-- 1. from a unix shell:
--	# loadjava -user <user>/<passwd>@<DB> -oci8 -resolve IPV4Addr.class
-- 2. execute the dll below

create or replace package ip_manip
as 
	GC_spec_id_tag       CONSTANT global_types.id_tag_var_type:='$Id$';

	FUNCTION id_tag RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;


	function java_v4_int_from_octet
	(
		p_ip_address			in varchar2,
		p_raise_exception_on_error	in number
	)
	return number DETERMINISTIC;

	function v4_int_from_octet
	(
		p_ip_address			in varchar2,
		p_raise_exception_on_error	in number default 0
	)
	return number DETERMINISTIC;

	function v4_octet_from_int
		(
		p_numeric_ip_address		  in		  number
		)
	return varchar2 DETERMINISTIC;

	function v4_netmask_from_bits
		(
		p_bits				in		  number
		)
	return number DETERMINISTIC;

	function v4_bits_from_netmask
		(
		p_netmask			in		  number
		)
	return number DETERMINISTIC;

	function v4_base_java
		(
		p_ip_address		in		number,
		p_bits			in		number
		)
	return number DETERMINISTIC;

	function v4_base
		(
		p_ip_address		in		number,
		p_bits			in		number
		)
	return number DETERMINISTIC;

	function v4_is_private_yn
		(
		p_ip_address		  in		  number
		)
	return varchar2 DETERMINISTIC;

	function v4_is_private
		(
		p_ip_address		  in		  number
		)
	return boolean DETERMINISTIC;

	function v4_is_in_block
		(
		p_network		in		number,
		p_bits			in		number,
		p_ipaddr		in		number
		)
	return varchar2 DETERMINISTIC;

	-- ipv6

	function java_v6_int_from_string
	(
		p_ip_address			in varchar2,
		p_raise_exception_on_error	in number
	)
	return number DETERMINISTIC;

	function v6_int_from_string
	(
		p_ip_address			in varchar2,
		p_raise_exception_on_error	in number default 0
	)
	return number DETERMINISTIC;

end;
/
show errors;
/
