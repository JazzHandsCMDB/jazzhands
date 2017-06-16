\set ON_ERROR_STOP

/*
 *

cleans up two problem nodes in moving the pk to lb_ip:

set constraints all deferred;
update lb_pool
set id = 901
where id = 826
and datacenter_id = 'LAX1';

update lb_node
set lb_pool_id = 901
where lb_pool_id = 826
and datacenter_id = 'LAX1';

set constraints all immediate;


 */

/*

the ones in intended have a solution, those not should probably be in a
cloud_jazz table:

-- datacenter_id
				-- id
-- customer_id
-- method
				-- request_string
				-- search_string
-- type
-- metadata
				-- created_on
-- ssl_certificate
-- ssl_key
-- ssl_chain
-- load_threshold_override
-- ignore_node_status
-- redirect_to

-- is_deleted
-- deleted_on
-- managed_by_api

port ranges need to be sorted out, its just a matter of looking for a service
and using it, otherwise creating a new one.

triggers will need to exist to handle changing ports gracefully.

*/


rollback;
begin;

DO $$
DECLARE
	_p		cloudapi.lb_pool%ROWTYPE;
	_name TEXT;
	_active char(1);
	_svc integer;
	id integer;
	svid integer;
	sei integer;
	sepi integer;
	pr integer;
BEGIN

	FOR _p IN SELECT * FROM cloudapi.lb_pool ORDER BY id
	LOOP
		_name := _p.datacenter_id || ':' || _p.id;
		INSERT INTO service (
			service_name, description
		) values (
			_name, 'imported from ' || _name
		) RETURNING service_id INTO id;

		INSERT INTO service_version (
			service_id, service_type, version_name
		) VALUES (
			id, 'lbpool', _name
		) RETURNING service_version_id INTO svid;

		-- insert a port range

		INSERT INTO service_endpoint ( port_range_id ) VALUES ( pr )
			RETURNING service_endpoint_id INTO sei;

		-- insert service_endpoint_provider
		--
		-- XX should migrate to shared_netblock_id
		INSERT INTO service_endpoint_provider (
			service_endpoint_provider_id,
			service_endpoint_provider_name, service_endpoint_provider_type,
			service_endpoint_id, netblock_id
		) VALUES (
			_p.id,
			_name, 'loadbalancer',
			sei, _p.lb_ip_id
		) RETURNING service_endpoint_provider_id INTO sepi;


	-- service_endpoint_provider
	-- service_endpoint_provider_member (node?)

	END LOOP;

	SELECT schema_support.reset_table_sequence(
		schema := 'jazzhands',
		table_name := 'service_endpoint_provider'
	);
END;
$$
;

rollback;
