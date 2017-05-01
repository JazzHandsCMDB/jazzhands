
-- Copyright (c) 2017, Todd M. Kover
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

--
-- show only ip universe zero.  Note that domains not in universe zero will
-- not show up here at all.
--
CREATE OR REPLACE VIEW v_dns_domain_nouniverse AS
SELECT
	d.dns_domain_id,
	d.soa_name,
	du.soa_class,
	du.soa_ttl,
	du.soa_serial,
	du.soa_refresh,
	du.soa_retry,
	du.soa_expire,
	du.soa_minimum,
	du.soa_mname,
	du.soa_rname,
	d.parent_dns_domain_id,
	du.should_generate,
	du.last_generated,
	d.dns_domain_type,
	coalesce(d.data_ins_user, du.data_ins_user) as data_ins_user,
	coalesce(d.data_ins_date, du.data_ins_date) as data_ins_date,
	coalesce(du.data_upd_user, d.data_upd_user) as data_upd_user,
	coalesce(du.data_upd_date, d.data_upd_date) as data_upd_date
FROM dns_domain d
	JOIN dns_domain_ip_universe du USING (dns_domain_id)
WHERE ip_universe_id = 0
;
