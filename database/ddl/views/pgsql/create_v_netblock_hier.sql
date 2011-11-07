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
--
--
--
-- $Id$
--

-- was originally in netblock/index.pl from stab.  It originally had
-- 	connect by prior nb.netblock_id = parent_netblock_id
-- 	start with nb.parent_netblock_id = ?
-- 	order siblings by ip_address, netmask_bits
-- and this makes the root selection by including root_netblock_id.
-- This may break down the "everything can be represented by a view" because
-- the recursive table takes too long to build.

-- the postgresql query would have the restriction in the non recursive part
-- of the with query


CREATE OR REPLACE VIEW v_netblock_hier AS
WITH RECURSIVE var_recurse (
	netblock_level,
	root_netblock_id,
	ip,
	netblock_id,
	ip_address,
	netmask_bits,
	netblock_status,
	IS_SINGLE_ADDRESS,
	IS_IPV4_ADDRESS,
	description,
	parent_netblock_id,
	site_code
) as  (
	select  0			as netblock_level,
		nb.netblock_id		as root_netblock_id,
		net_manip.inet_dbtop(nb.ip_address) as ip,
		nb.netblock_id,
		nb.ip_address,
		nb.netmask_bits,
		nb.netblock_status,
		nb.IS_SINGLE_ADDRESS,
		nb.IS_IPV4_ADDRESS,
		nb.description,
		nb.parent_netblock_id,
		snb.site_code
	  from  netblock nb
		left join site_netblock snb
			on snb.netblock_id = nb.netblock_id
	where   nb.IS_SINGLE_ADDRESS = 'N'
UNION ALL
	SELECT	x.netblock_level +1	as netblock_level,
		x.root_netblock_id	as root_netblock_id,
		net_manip.inet_dbtop(nb.ip_address) as ip,
		nb.netblock_id,
		nb.ip_address,
		nb.netmask_bits,
		nb.netblock_status,
		nb.IS_SINGLE_ADDRESS,
		nb.IS_IPV4_ADDRESS,
		nb.description,
		nb.parent_netblock_id,
		snb.site_code
	  from  var_recurse x
	  	inner join netblock nb
			on x.netblock_id = nb.parent_netblock_id
		left join site_netblock snb
			on snb.netblock_id = nb.netblock_id
	where   nb.IS_SINGLE_ADDRESS = 'N'
) SELECT * from var_recurse;
;
