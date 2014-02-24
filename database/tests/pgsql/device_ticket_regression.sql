-- Copyright (c) 2014 Todd Kover
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

-- $Id$


\set ON_ERROR_STOP

\t on

-- 
-- Simple tests that make sure everything works as expected
--
CREATE OR REPLACE FUNCTION device_ticket_regression() RETURNS BOOLEAN AS $$
DECLARE
	_tally			integer;
	_dev			device%ROWTYPE;
	_tix			device_ticket%ROWTYPE;
	_tixsys			ticketing_system%ROWTYPE;
	_dt			device_type%ROWTYPE;
BEGIN
	RAISE NOTICE 'Cleanup Records from Previous Tests';
	delete from device_Ticket where device_Ticket_notes like 'JHTEST%' ;
	delete from device where description like 'JHTEST%' or
		device_name like 'JHTEST%';
	delete from ticketing_system where description like 'JHTEST%' ;
	delete from device_type where model like 'JHTEST%';
	delete from rack where site_code = 'JHTEST01';
	delete from site where site_code = 'JHTEST01';

	RAISE NOTICE '++ Beginning tests of device_ticket...';

	INSERT INTO site (
		site_code, site_status
	) VALUES (
		'JHTEST01', 'ACTIVE'
	);

	INSERT INTO device_type (
		model, rack_units, has_802_3_interface,
		has_802_11_interface, snmp_capable, is_chassis
	) values (
		'JHTEST type', 2, 'N', 'N', 'N', 'Y'
	) RETURNING * INTO _dt;

	INSERT INTO ticketing_system (
		ticketing_system_name, ticketing_system_url,
		description
	) values (
		'tix', 'https:://tix.example.com?id=?',
		'JHTEST text tix'
	) RETURNING * into _tixsys;

	INSERT INTO device (
		device_type_id, device_name, device_status, site_code,
		service_environment, operating_system_id,
		ownership_status, is_monitored
	) values (
		_dt.device_type_id, 'JHTEST device', 'up', 'JHTEST01',
		'production', 0,
		'owned', 'Y'
	) RETURNING * into _dev;

	INSERT INTO device_ticket (
		device_id, ticketing_system_id, ticket_number,
		device_ticket_notes
	) values (
		_dev.device_id, _tixsys.ticketing_system_id, 'FOO-01',
		'JHTEST notes'
	);
	
	RAISE NOTICE '++ Done tests of device_ticket...';
	-- same as beginning..
	delete from device_Ticket where device_Ticket_notes like 'JHTEST%' ;
	delete from device where description like 'JHTEST%' or
		device_name like 'JHTEST%';
	delete from ticketing_system where description like 'JHTEST%' ;
	delete from device_type where model like 'JHTEST%';
	delete from rack where site_code = 'JHTEST01';
	delete from site where site_code = 'JHTEST01';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT device_ticket_regression();
-- set search_path=jazzhands;
DROP FUNCTION device_ticket_regression();

\t off
