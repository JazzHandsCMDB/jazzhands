
-- Copyright (c) 2016, Todd M. Kover
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
--
-- $Id$
--

-- when columns are dropped from network_interface this will replicate the
-- legacy behavior until other things can be cleaned up.
CREATE OR REPLACE VIEW v_network_interface_trans AS
SELECT ni.network_interface_id,
	ni.device_id,
	ni.network_interface_name,
	ni.description,
	ni.parent_network_interface_id,
	ni.parent_relation_type,
	nb.netblock_id,
	ni.physical_port_id,
	ni.slot_id,
	ni.logical_port_id,
	ni.network_interface_type,
	ni.is_interface_up,
	ni.mac_addr,
	ni.should_monitor,
	ni.provides_nat,
	ni.should_manage,
	ni.provides_dhcp,
	ni.data_ins_user,
	ni.data_ins_date,
	ni.data_upd_user,
	ni.data_upd_date
FROM network_interface ni
	LEFT JOIN (
		SELECT nin.network_interface_id, nin.netblock_id
		FROM network_interface_netblock nin
			JOIN (
					SELECT network_interface_id,
						min(network_interface_rank) as network_interface_rank
					FROM network_interface_netblock
					GROUP BY network_interface_id
			) mn
				USING (network_interface_id, network_interface_rank)
		) nb
	 USING (network_interface_id)

;

ALTER VIEW v_network_interface_trans
	alter column is_interface_up set default 'Y'::text;
ALTER VIEW v_network_interface_trans
	alter column provides_nat set default 'N'::text;
ALTER VIEW v_network_interface_trans
	alter column should_manage set default 'Y'::text;
ALTER VIEW v_network_interface_trans
	alter column provides_dhcp set default 'N'::text;
