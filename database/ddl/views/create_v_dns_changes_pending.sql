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

--
-- XXX - This likely needs more work to get all the ip universe boundary
-- stuff better.
--
--
-- The WITH chg query takes all the cidr blocks in dns_change_record
-- and makes them into dns records.    NOTE:  They do not properly handle
-- things that are not on classful boundaries, which really needs to be fixed.
--
-- The first one does in-addr networks pulled from the changes.  Its probably
--	more agressive than it should be
-- The second one does zones without ip universes (does all)
-- The third does explicitly set ip universes and only those
-- The fourth acts like the third but expands ones visible to the one set
--
CREATE OR REPLACE VIEW v_dns_changes_pending AS
WITH chg AS (
	SELECT dns_change_record_id, dns_domain_id,
		case WHEN family(ip_address)  = 4 THEN set_masklen(ip_address, 24)
			ELSE set_masklen(ip_address, 64) END as ip_address,
		dns_utils.get_domain_from_cidr(ip_address) as cidrdns
	FROM dns_change_record
	WHERE ip_address is not null
) SELECT *
FROM (
	SELECT	chg.dns_change_record_id, n.dns_domain_id, du.ip_universe_id,
		du.should_generate, du.last_generated,
		n.soa_name, chg.ip_address
	FROM   chg
		INNER JOIN dns_domain n on chg.cidrdns = n.soa_name
		INNER JOIN dns_domain_ip_universe du ON
			du.dns_domain_id = n.dns_domain_id
UNION ALL
	SELECT  chg.dns_change_record_id, d.dns_domain_id, du.ip_universe_id,
		du.should_generate, du.last_generated,
		d.soa_name, NULL
	FROM	dns_change_record chg
		INNER JOIN dns_domain d USING (dns_domain_id)
		INNER JOIN dns_domain_ip_universe du USING (dns_domain_id)
	WHERE   dns_domain_id IS NOT NULL
	AND chg.ip_universe_id IS NULL
UNION ALL
	SELECT  chg.dns_change_record_id, d.dns_domain_id, ip_universe_id,
		du.should_generate, du.last_generated,
		d.soa_name, NULL
	FROM	dns_change_record chg
		INNER JOIN dns_domain d USING (dns_domain_id)
		INNER JOIN dns_domain_ip_universe du USING (dns_domain_id,ip_universe_id)
	WHERE   dns_domain_id IS NOT NULL
	AND chg.ip_universe_id IS NOT NULL
UNION ALL
	SELECT  chg.dns_change_record_id, d.dns_domain_id, 
		iv.visible_ip_universe_id,
		du.should_generate, du.last_generated,
		d.soa_name, NULL
	FROM	dns_change_record chg
		INNER JOIN ip_universe_visibility iv USING (ip_universe_id)
		INNER JOIN dns_domain d USING (dns_domain_id)
		INNER JOIN dns_domain_ip_universe du USING (dns_domain_id)
	WHERE   dns_domain_id IS NOT NULL
	AND chg.ip_universe_id IS NOT NULL
) x
;
