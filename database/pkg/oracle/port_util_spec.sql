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

create or replace package port_utils
as 
	GC_spec_id_tag       CONSTANT global_types.id_tag_var_type:='$Id$';

	GC_conscfg_zone CONSTANT varchar2(1024) := 'conscfg.example.com';

	FUNCTION id_tag RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;

	PROCEDURE setup_device_power (
		in_Device_id device.device_id%type
	);

	PROCEDURE setup_device_serial (
		in_Device_id device.device_id%type
	);

	PROCEDURE setup_device_physical_ports (
		in_Device_id device.device_id%type,
		in_port_type val_port_type.port_type%type DEFAULT NULL
	);

	FUNCTION configure_layer1_connect (
		physportid1 	physical_port.physical_port_id%type,
		physportid2 	physical_port.physical_port_id%type,
		baud		layer1_connection.baud%type	DEFAULT -99,
		data_bits   	layer1_connection.data_bits%type	DEFAULT -99,
		stop_bits   	layer1_connection.stop_bits%type	DEFAULT -99,
		parity	  	layer1_connection.parity%type	DEFAULT '__unknown__',
		flw_cntrl   	layer1_connection.flow_control%type 
			DEFAULT '__unknown__',
		circuit_id   	layer1_connection.circuit_id%type DEFAULT -99
	) return number;

	FUNCTION configure_power_connect (
		in_dev1_id	device_power_connection.device_id%type,
		in_port1_id	device_power_connection.power_interface_port%type,
		in_dev2_id	device_power_connection.rpc_device_id%type,
		in_port2_id	device_power_connection.rpc_power_interface_port%type
	) return number;

	PROCEDURE setup_conscfg_record (
		in_physportid	physical_port.physical_port_id%type,
		in_name		device.device_name%type,
		in_dstsvr	device.device_name%type
	);

	PROCEDURE delete_conscfg_record (
		in_name		device.device_name%type
	);
end;
/
show errors;
/
