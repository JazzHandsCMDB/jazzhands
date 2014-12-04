--
-- Copyright (c) 2014 Matthew Ragan
-- All rights reserved.
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--      http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
drop schema if exists physical_address_utils cascade;
create schema physical_address_utils authorization jazzhands;

CREATE OR REPLACE FUNCTION physical_address_utils.localized_physical_address(
	physical_address_id integer,
	line_separator text DEFAULT ', ',
	include_country boolean DEFAULT true
) RETURNS text AS $$
DECLARE
	address	text;
BEGIN
	SELECT concat_ws(line_separator,
			CASE WHEN iso_country_code IN 
					('SG', 'US', 'CA', 'UK', 'GB', 'FR', 'AU') THEN 
				concat_ws(' ', address_housename, address_street)
			WHEN iso_country_code IN ('IL') THEN
				concat_ws(', ', address_housename, address_street)
			WHEN iso_country_code IN ('ES') THEN
				concat_ws(', ', address_street, address_housename)
			ELSE
				concat_ws(' ', address_street, address_housename)
			END,
			address_pobox,
			address_neighborhood,
			address_building,
			CASE WHEN iso_country_code IN ('US', 'CA', 'UK') THEN 
				concat_ws(', ', address_city, 
					concat_ws(' ', address_region, postal_code))
			WHEN iso_country_code IN ('SG', 'AU') THEN
				concat_ws(' ', address_city, address_region, postal_code)
			ELSE
				concat_ws(' ', postal_code, address_city, address_region)
			END,
			iso_country_code
		)
	INTO address
	FROM
		physical_address pa
	WHERE
		pa.physical_address_id = 
			localized_physical_address.physical_address_id;
	RETURN address;
END; $$
SET search_path=jazzhands
LANGUAGE plpgsql;

GRANT USAGE ON SCHEMA physical_address_utils TO public;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA physical_address_utils TO ro_role;
