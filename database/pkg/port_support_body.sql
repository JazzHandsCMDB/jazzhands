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
create or replace package body port_support
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
	-- returns if a device has any power ports or not
	-------------------------------------------------------------------
	FUNCTION has_power_ports (
		in_Device_id device.device_id%type
	) RETURN BOOLEAN
	IS
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
	--end of procedure has_power_ports
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- returns if a device has any serial ports or not
	-------------------------------------------------------------------
	FUNCTION has_serial_ports (
		in_Device_id device.device_id%type
	) RETURN BOOLEAN
	IS
		tally	integer;
	BEGIN
		return has_physical_ports(in_Device_id, 'serial');
	END;
	--end of procedure has_serial_ports
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- returns if a device has any physical ports or not
	-- if in_port_type is set, will limit the check to that type,
	-- otherwise will limit the search to that type
	-------------------------------------------------------------------
	FUNCTION has_physical_ports (
		in_Device_id device.device_id%type,
		in_port_type val_port_type.port_type%type DEFAULT NULL
	) RETURN BOOLEAN
	IS
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
	--end of procedure has_physical_ports
	-------------------------------------------------------------------


	-------------------------------------------------------------------
	-- update a table dynamically
	-------------------------------------------------------------------
	procedure do_l1_connection_update(
		p_cnames in layer1_conn_array,
		p_values in layer1_conn_array,
		p_l1_id in layer1_connection.layer1_connection_id%type
	) is
		l_stmt  long;
		l_rc    number;
		i       number;
		g_cursor number;
	begin
		g_cursor := dbms_sql.open_cursor;

		l_stmt := 'update layer1_connection set ' || p_cnames(1) || '= :bv1';
		dbms_output.put_line('P_names is ' || p_cnames.count);
		for i in 2 .. p_cnames.count loop
				l_stmt := l_stmt || ',' || p_cnames(i) || ' = :bv' || i;
		end loop;

		l_stmt := l_stmt || ' where layer1_connection_id = :lcid';

		--
		-- make the query happen and stuff.
		--
		dbms_output.put_line( l_stmt );
		dbms_sql.parse( g_cursor, l_stmt, dbms_sql.native );

		for i in 1 .. p_values.count
		loop
			dbms_sql.bind_variable( g_cursor, ':bv' || i, p_values(i) );
		end loop;

		dbms_sql.bind_variable( g_cursor, ':lcid', p_l1_id );
		l_rc := dbms_sql.execute( g_cursor );
		end;
	--end of procedure do_l1_connection_update
	-------------------------------------------------------------------

end;
/
show errors;
