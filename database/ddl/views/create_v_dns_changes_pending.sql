--
-- Copyright (c) 2015, Todd M. Kover
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

--
-- This is used by the zonegen software
--

CREATE OR REPLACE VIEW v_dns_changes_pending AS
SELECT DISTINCT *
FROM (
SELECT  chg.dns_change_record_id, n.dns_domain_id,
	n.should_generate, n.last_generated,
	n.soa_name, chg.ip_address
	FROM   dns_change_record chg
	LEFT JOIN (
		SELECT * fROM
			dns_record dns
			INNER JOIN dns_domain dom USING (dns_domain_id)
			iNNER JOIN netblock n USING (netblock_id)
		WHERE dns.dns_type = 'REVERSE_ZONE_BLOCK_PTR'
	) n
   		ON	family(chg.ip_address) = family(n.ip_address) AND
			set_masklen(chg.ip_address, masklen(n.ip_address))
		 		<<= n.ip_address
	WHERE chg.ip_address IS NOT NULL
UNION
SELECT	chg.dns_change_record_id, d.dns_domain_id,
	d.should_generate, d.last_generated,
	d.soa_name, NULL
 FROM	dns_change_record chg
	INNER JOIN dns_domain d USING (dns_domain_id)
	WHERE	dns_domain_id IS NOT NULL
) x
