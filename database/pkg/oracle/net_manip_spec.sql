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

/*

XXXXXXXXXXXXXXXXXXXXXXXXXXXX NOTE XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

ONLY inet_ptodb and inet_dbtop are implemented for v6.   The others operate
on ipv4 ONLY.  This needs to be fixed before any oracle release happens

XXXXXXXXXXXXXXXXXXXXXXXXXXXX NOTE XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

 */

create or replace package net_manip
IS
	GC_spec_id_tag	CONSTANT global_types.id_tag_var_type := '$Id$';

	FUNCTION id_tag RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;

	function java_v4_int_from_octet
	(
		p_ip_address			in varchar2,
		p_raise_exception_on_error	in number
	)
	return number DETERMINISTIC;

	function java_v6_int_from_octet
	(
		p_ip_address			in varchar2,
		p_raise_exception_on_error	in number
	)
	return number DETERMINISTIC;
	function inet_ptodb
	(
		p_ip_address			in varchar2,
		p_raise_exception_on_error	in number 	default 0
	)
	return number DETERMINISTIC;

	function java_v4_string_from_int
		(
		p_numeric_ip_address in  number
		)
	return varchar2 DETERMINISTIC;

	function java_v6_string_from_number
		(
		p_numeric_ip_address in  number
		)
	return varchar2 DETERMINISTIC;

	function inet_dbtop
		(
		p_numeric_ip_address 	in  number,
		p_ipvnum	     	in  number		DEFAULT NULL
		)
	return varchar2 DETERMINISTIC;

	function inet_bits_to_mask
		(
		p_bits				in		  number
		)
	return number DETERMINISTIC;

	function inet_mask_to_bits
		(
		p_netmask				in		  number
		)
	return number DETERMINISTIC;

	function v4_base_java
		(
		p_ip_address		in		number,
		p_bits			in		number
		)
	return number DETERMINISTIC;

	function inet_base
		(
		p_ip_address		in		number,
		p_bits			in		number
		)
	return number DETERMINISTIC;

	function inet_is_private_yn
		(
		p_ip_address		  in		  number
		)
	return varchar2 DETERMINISTIC;

	function inet_is_private
		(
		p_ip_address		in		number
		)
	return boolean DETERMINISTIC;

	function inet_inblock
		(
		p_network		in		number,
		p_bits			in		number,
		p_ipaddr		in		number
		)
	return varchar2 DETERMINISTIC;

	function java_v6_int_from_string
	(
		p_ip_address			in varchar2,
		p_raise_exception_on_error	in number
	)
	return number DETERMINISTIC;

	function dbton
	(
		p_ip_address			in number
	)
	return number DETERMINISTIC;

	function ntodb
	(
		p_ip_address			in number
	)
	return number DETERMINISTIC;

end;
/
show errors;
