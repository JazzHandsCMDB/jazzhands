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

drop schema if exists netblock_utils cascade;
create schema netblock_utils authorization jazzhands;

-------------------------------------------------------------------
-- returns the Id tag for CM
-------------------------------------------------------------------
CREATE OR REPLACE FUNCTION netblock_utils.id_tag()
RETURNS VARCHAR AS $$
BEGIN
	RETURN('<-- $Id -->');
END;
$$ LANGUAGE plpgsql;
-- end of procedure id_tag
-------------------------------------------------------------------

CREATE OR REPLACE FUNCTION netblock_utils.find_best_parent_id(
	in_IpAddress netblock.ip_address%type,
	in_Netmask_Bits netblock.NETMASK_BITS%type
) RETURNS netblock.netblock_id%type AS $$
DECLARE
	par_nbid	netblock.netblock_id%type;
BEGIN
	in_IpAddress := set_masklen(in_IpAddress, in_Netmask_Bits);
	select  Netblock_Id
	  into	par_nbid
	  from  ( select Netblock_Id, Ip_Address, Netmask_Bits
		    from NetBlock
		   where
		   	in_IpAddress <<= ip_address
		    and is_single_address = 'N'
		    and is_organizational = 'N'
		    and netmask_bits > 0
		order by netmask_bits desc
	) subq LIMIT 1;

	return par_nbid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION netblock_utils.find_rvs_zone_from_netblock_id(
	in_netblock_id	netblock.netblock_id%type
) RETURNS dns_domain.dns_domain_id%type AS $$
DECLARE
	v_rv	dns_domain.dns_domain_id%type;
	v_domid	dns_domain.dns_domain_id%type;
	v_lhsip	netblock.ip_address%type;
	v_rhsip	netblock.ip_address%type;
	nb_match CURSOR ( in_nb_id netblock.netblock_id%type) FOR
		-- The query used to include this in the where clause, but
		-- oracle was uber slow 
		--	net_manip.inet_base(nb.ip_address, root.netmask_bits) =  
		--		net_manip.inet_base(root.ip_address, root.netmask_bits) 
		select  rootd.dns_domain_id,
				 net_manip.inet_base(nb.ip_address, root.netmask_bits),
				 net_manip.inet_base(root.ip_address, root.netmask_bits)
		  from  netblock nb,
			netblock root
				inner join dns_record rootd
					on rootd.netblock_id = root.netblock_id
					and rootd.dns_type = 'REVERSE_ZONE_BLOCK_PTR'
		 where
		  	nb.netblock_id = in_nb_id;
BEGIN
	v_rv := NULL;
	OPEN nb_match(in_netblock_id);
	LOOP
		FETCH  nb_match INTO v_domid, v_lhsip, v_rhsip;
		if NOT FOUND THEN
			EXIT;
		END IF;

		if v_lhsip = v_rhsip THEN
			v_rv := v_domid;
			EXIT;
		END IF;
	END LOOP;
	CLOSE nb_match;
	return v_rv;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
