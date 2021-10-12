
-- Copyright (c) 2021, Todd M. Kover
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
-- port_range_name is not the protocol
--
CREATE OR REPLACE VIEW v_service_endpoint_expanded AS
SELECT	DISTINCT
	service_endpoint_id,
	service_id,
	dns_record_id,
	port_range_id,
	CASE WHEN dns_record_id IS NULL THEN service_endpoint_uri_fragment
		ELSE concat(service_name, '://', fqdn, CASE WHEN port_uri_start IS NULL THEN NULL ELSE port_uri END, '/', service_endpoint_uri_fragment)
		END as service_endpoint_uri,
	description,
	is_synthesized
FROM service_endpoint
	LEFT JOIN (
		SELECT dns_record_id, concat_ws('.',dns_name, dns_domain_name) AS fqdn
		FROM dns_record JOIN dns_domain USING (dns_domain_id)
	) dns USING (dns_record_id)
	LEFT JOIN (SELECT
		pr.port_range_id, pr.port_range_name,
		CASE WHEN pr.port_start = pr.port_end AND pr.service_override_port_range_id IS NULL THEN NULL
		ELSE concat(':', pr.port_start) END AS port_uri_start,
		concat(':', generate_series(pr.port_start, pr.port_end)) AS port_uri,
		coalesce(ppr.port_range_name, pr.port_range_name) AS service_name
		FROM port_range pr
		LEFT JOIN port_range ppr ON pr.service_override_port_range_id = ppr.port_range_id
	) pr USING (port_range_id)
