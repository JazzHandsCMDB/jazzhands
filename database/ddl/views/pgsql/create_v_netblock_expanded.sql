-- Copyright (c) 2013, Todd M. Kover
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
--
-- $Id$
--


-- This view shows the site code for each entry in the netblock table
-- even when it's one of the ancestor netblocks that has the
-- site_netblock assignments

CREATE OR REPLACE VIEW v_netblock_expanded AS
WITH RECURSIVE parent_netblock AS (
  SELECT n.*, sn.site_code, 'EXPLICIT' as site_assignment
  FROM netblock n LEFT JOIN site_netblock sn on n.netblock_id = sn.netblock_id
  WHERE n.parent_netblock_id IS NULL
  UNION
  SELECT n.*, coalesce(sn.site_code, p.site_code) as site_code,
	case	WHEN sn.site_code is NULL THEN 'INHERITED'
		WHEN p.site_code is NULL THEN NULL
		ELSE 'ASSIGNED' END as site_assignment
  FROM netblock n 
	JOIN parent_netblock p 
		ON n.parent_netblock_id = p.netblock_id
  LEFT JOIN site_netblock sn 
	ON n.netblock_id = sn.netblock_id
)
SELECT 
	netblock_id,
	host(ip_address) as IP,
	ip_address,
	netmask_bits,
	netblock_type,
	is_ipv4_address,
	is_single_address,
	can_subnet,
	parent_netblock_id,
	netblock_status,
	nic_id,
	nic_company_id,
	ip_universe_id,
	description,
	reservation_ticket_number,
	site_code,
	site_assignment,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM parent_netblock;
