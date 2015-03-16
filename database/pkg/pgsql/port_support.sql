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
 *
 * backend support for dealing with ports.  This is not part of the public
 * interface so generally should not be granted.
 */

drop schema if exists port_support cascade;
create schema port_support authorization jazzhands;
COMMENT ON SCHEMA port_support IS 'part of jazzhands';

-------------------------------------------------------------------
-- returns the Id tag for CM
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION port_support.id_tag() RETURNS VARCHAR AS $$
BEGIN
		RETURN('<-- $Id$ -->');
END;
$$ LANGUAGE plpgsql;
--end of procedure id_tag
-------------------------------------------------------------------

-------------------------------------------------------------------
-- returns if a device has any power ports or not
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION port_support.has_power_ports (
	in_Device_id device.device_id%type
) RETURNS VARCHAR AS $$
DECLARE
	tally	integer;
BEGIN
	select	count(*)
	  into	tally
	  from	device_power_interface
	 where	device_id = in_device_id;

	if tally = 0  then
		return FALSE;
	end if;

	return TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
--end of procedure has_power_ports
-------------------------------------------------------------------

-------------------------------------------------------------------
-- returns if a device has any serial ports or not
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION port_support.has_serial_ports (
	in_Device_id device.device_id%type
) RETURNS BOOLEAN AS $$
BEGIN
	return has_physical_ports(in_Device_id, 'serial');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
--end of procedure has_serial_ports
-------------------------------------------------------------------

-------------------------------------------------------------------
-- returns if a device has any physical ports or not
-- if in_port_type is set, will limit the check to that type,
-- otherwise will limit the search to that type
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION port_support.has_physical_ports (
	in_Device_id device.device_id%type,
	in_port_type slot_type.slot_function%type DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
	tally integer;
BEGIN
	if in_port_type is NULL then
		select	count(*)
		  into	tally
		  from	physical_port
		 where	device_id = in_device_id;
	else
		select	count(*)
		  into	tally
		  from	physical_port
		 where	device_id = in_device_id
		  and	port_type = in_port_type;
	end if;

	if tally = 0 then
		return FALSE;
	end if;

	return TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
--end of procedure has_physical_ports
-------------------------------------------------------------------


-------------------------------------------------------------------
-- update a table dynamically
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION port_support.do_l1_connection_update(
	p_cnames in varchar(100) [],
	p_values in varchar(100) [],
	p_l1_id in layer1_connection.layer1_connection_id%type
) RETURNS VOID AS $$
DECLARE
	l_stmt  varchar(4096);
	l_rc    integer;
	i       integer;
BEGIN
	l_stmt := 'update layer1_connection set ';
	for i in array_lower(p_cnames, 1) .. array_upper(p_cnames, 1)
	LOOP
		if (i > array_lower(p_cnames, 1) ) then
			l_stmt := l_stmt || ',';
		end if;
		l_stmt := l_stmt || p_cnames[i] || '=' || p_values[i];
	END LOOP;
	l_stmt := l_stmt || ' where layer1_connection_id = ' || p_l1_id;
	RAISE DEBUG '%', l_stmt;
	-- note: bind variables, sadly, are not used here, but the only
	-- thing that is supposed to call it, 
	-- port_utils.configure_layer1_connect is expected to use
	-- quote_literal to make sure things are properly quoted to avoid
	-- sql injection type attacks.  I would rather use bind variables,
	-- but this does not appear to work for dynamically built queries
	-- in pl/pgsql.  alas.
	EXECUTE l_stmt;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
--end of procedure do_l1_connection_update
-------------------------------------------------------------------
