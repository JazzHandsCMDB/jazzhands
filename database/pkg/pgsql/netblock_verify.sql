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

drop schema netblock_verify cascade;
create schema netblock_verify authorization jazzhands;


/* XXX
GC_pkg_name CONSTANT USER_OBJECTS.OBJECT_NAME % TYPE :=
	'netblock_verify';
G_err_num NUMBER;
G_err_msg VARCHAR2(200);
 */

-------------------------------------------------------------------
-- returns the Id tag for CM
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION id_tag()
RETURNS VARCHAR AS $$
BEGIN
	RETURN('<-- $Id-->');
END;
$$ LANGUAGE plpgsql;
--end of procedure id_tag
-------------------------------------------------------------------

-------------------------------------------------------------------
-- returns the number of instances for a given IP address
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION count_matching_rows(
	in_ip_address	netblock.ip_address%type,
) RETURNS integer AS $$
DECLARE
	v_return	boolean := false;
	v_count	 	integer;
begin     
	select count(*)
	  into v_count
	  from netblock
	 where ip_address = in_ip_address

	 return(v_count); 
exception when NO_DATA_FOUND then
	return 0;
end;    
$$ LANGUAGE plpgsql SECURITY DEFINER;
--end of procedure count_matching_rows
-------------------------------------------------------------------

-------------------------------------------------------------------
-- given a netblock id, fills in parent address and bits
--
-- This is only used by oracle and should be retired
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_netblock_ip_and_bits (
	in_netblock_id		in     netblock.netblock_id%type,
	in_parent_ipaddress	out     netblock.ip_address%type,
	in_parent_bits		out     netblock.netmask_bits%type
) RETURNS void AS $$
begin
	select	ip_address, family(ip_address) as netmask_bits
	  into	in_parent_ipaddress, in_parent_bits
	  from	NETBLOCK
	 where	netblock_id = in_netblock_id;
end;
$$ LANGUAGE plpgsql SECURITY DEFINER;
--end of procedure get_netblock_ip_and_bits
-------------------------------------------------------------------

-- check_parent_child is not necessary due to the lack of the mutating
-- tables problem under postgresql.  So checks are directly in the triggers
-- instead of using packages.
