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

create or replace package body netblock_verify
IS
	GC_pkg_name CONSTANT USER_OBJECTS.OBJECT_NAME % TYPE :=
		'netblock_verify';
	G_err_num NUMBER;
	G_err_msg VARCHAR2(200);

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
	-- returns the number of instances for a given IP address
	-------------------------------------------------------------------
	FUNCTION count_matching_rows(
		in_ip_address	netblock.ip_address%type,
		in_bits		netblock.netmask_bits%type
	) RETURN number
	AS
		pragma	  	autonomous_transaction;
		v_return	boolean := false;
		v_count	 	number(10);
	begin     
		select count(*)
		  into v_count
		  from netblock
		 where ip_address = in_ip_address
		   and netmask_bits = in_bits;

		 return(v_count); 
	exception when NO_DATA_FOUND then
		return 0;
	end;    
	--end of procedure count_matching_rows
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- given a netblock id, fills in parent address and bits
	-------------------------------------------------------------------
	PROCEDURE get_netblock_ip_and_bits (
		in_netblock_id		in     netblock.netblock_id%type,
		in_parent_ipaddress	out     netblock.ip_address%type,
		in_parent_bits		out     netblock.netmask_bits%type
	) AS
		pragma	  autonomous_transaction;
	begin
		select	ip_address, netmask_bits
		  into	in_parent_ipaddress, in_parent_bits
		  from	NETBLOCK
		 where	netblock_id = in_netblock_id;
	end;
	--end of procedure get_netblock_ip_and_bits
	-------------------------------------------------------------------

	-------------------------------------------------------------------
	-- check to see if stored up list loses its parent if a netblock
	-- goes away
	-------------------------------------------------------------------
	PROCEDURE check_parent_child
	AS
		v_blk_ip	netblock.ip_address%type;
		v_blk_bits	netblock.netmask_bits%type;
		v_id		netblock.netblock_id%type;
		cursor		kid_iterate(parent_id number)   IS
					select netblock_id, ip_address
					  from netblock
					where parent_netblock_id = parent_id;
	v_std_object_name   VARCHAR2(60) := GC_pkg_name || '.check_parent_child';
	begin
		for idx in 1 .. netblock_verify.G_changed_netblock_ids.count loop
			v_id := netblock_verify.G_changed_netblock_ids(idx);
			select ip_address, netmask_bits
			  into v_blk_ip, v_blk_bits
			  from netblock
			 where netblock_id = v_id;
			for item in kid_iterate(v_id) loop
				if(ip_manip.v4_is_in_block(v_blk_ip, v_blk_bits,item.ip_address) = 'N') then
					G_err_num := global_errors.ERRNUM_NETBLOCK_BADPARENT;
					G_err_msg := global_errors.ERRMSG_NETBLOCK_BADPARENT;
					global_errors.log_error(G_err_num, v_std_object_name,
						G_err_msg);
					raise_application_error(G_err_num, G_err_msg || ' ( ' || item.netblock_id || '; parent: ' || v_id || ')');
				end if;
			end loop;
		end loop;   
	end;
	--end of procedure check_parent_child
	-------------------------------------------------------------------

end;
/
show errors
/
