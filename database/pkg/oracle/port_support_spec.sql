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
-- Provide Helpful functions for dealing with ports
---------------------------------------------------------------------------
-- $Id$

create or replace package port_support
as 
	GC_spec_id_tag       CONSTANT global_types.id_tag_var_type:='$Id$';

	-- TYPE layer1_conn_array is varray(50) of varchar2(4000);
	TYPE layer1_conn_array is table of varchar2(4000) index by pls_integer;


	FUNCTION id_tag RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;

	FUNCTION has_power_ports (
		in_Device_id device.device_id%type
	) RETURN BOOLEAN;

	FUNCTION has_serial_ports (
		in_Device_id device.device_id%type
	) RETURN BOOLEAN;

	FUNCTION has_physical_ports (
		in_Device_id device.device_id%type,
		in_port_type val_port_type.port_type%type DEFAULT NULL
	) RETURN BOOLEAN;

	procedure do_l1_connection_update(
		p_cnames in layer1_conn_array,
		p_values in layer1_conn_array,
		p_l1_id in layer1_connection.layer1_connection_id%type
	);
end;
/
show errors;
/
