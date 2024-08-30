-- Copyright (c) 2024 Matthew Ragan
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

DO $$
DECLARE
	_tal INTEGER;
BEGIN
	select count(*)
	from pg_catalog.pg_namespace
	into _tal
	where nspname = 'dhcp_manip';
	IF _tal = 0 THEN
	        DROP SCHEMA IF EXISTS dhcp_manip;
	        CREATE SCHEMA dhcp_manip AUTHORIZATION jazzhands;
	REVOKE USAGE ON SCHEMA dhcp_manip FROM public;
	COMMENT ON SCHEMA dhcp_manip IS 'part of jazzhands';
	END IF;
END;
$$;

CREATE OR REPLACE FUNCTION dhcp_manip.set_site_dns_servers(
	site_code			text,
	ip_addresses		inet[],
	ip_universe_id		jazzhands.ip_universe.ip_universe_id%TYPE DEFAULT 0,
	replace_addresses	boolean DEFAULT 'true'			
) RETURNS TABLE (
	netblock_collection_id		jazzhands.netblock_collection.netblock_collection_id%TYPE,
	netblock_collection_name	jazzhands.netblock_collection.netblock_collection_name%TYPE,
	netblock_collection_type	jazzhands.netblock_collection.netblock_collection_type%TYPE,
	netblock_id					jazzhands.netblock.netblock_id%TYPE,
	ip_address					inet
)  AS
$$
	DECLARE
		dns_nc		record;
		prop		record;
		sc			ALIAS FOR site_code;
		ncn			ALIAS FOR netblock_collection_name;
		nct			ALIAS FOR netblock_collection_type;
		ncid		ALIAS FOR netblock_collection_id;
		nid			ALIAS FOR netblock_id;
		iuid		ALIAS FOR ip_universe_id;
		ip			ALIAS FOR ip_address;
	BEGIN
		IF sc IS NULL THEN
			RAISE EXCEPTION 'site_code may not be null';
		END IF;

		--
		-- Fetch the netblock collection for DNS servers for this site
		-- if it exists
		--
		SELECT
			* INTO dns_nc
		FROM
			netblock_collection nc
		WHERE
			(nc.netblock_collection_name, nc.netblock_collection_type) =
				('DNSServers-' || sc, 'NetworkConfig');

		--
		-- ... otherwise insert one
		--
		IF NOT FOUND THEN
			INSERT INTO netblock_collection (
				netblock_collection_name,
				netblock_collection_type
			) VALUES (
				'DNSServers-' || sc,
				'NetworkConfig'
			) RETURNING * INTO dns_nc;
		END IF;

		RAISE NOTICE 'Fetched netblock_collection %',
			dns_nc.netblock_collection_id;

		IF dns_nc.netblock_collection_id IS NULL THEN
			RETURN;
		END IF;

		--
		-- If we want to just set them and clear out what's there,
		-- remove whatever is currently set
		--
		IF replace_addresses THEN
			DELETE FROM netblock_collection_netblock ncn WHERE
			ncn.netblock_collection_id = dns_nc.netblock_collection_id;
		END IF;
	
		--
		-- Insert the netblocks into the netblock_collection for the
		-- addresses passed.  Note that if they don't exist, they are
		-- not created
		--
		INSERT INTO netblock_collection_netblock (
			netblock_collection_id,
			netblock_id
		)
		SELECT
			dns_nc.netblock_collection_id,
			n.netblock_id
		FROM
			unnest(ip_addresses) ia(ip_address),
			netblock n
		WHERE
			n.netblock_type = 'default' AND
			n.ip_universe_id = iuid AND
			n.is_single_address = true AND
			host(n.ip_address) = host(ia.ip_address);


		--
		-- See if there is a property already created for this site for
		-- DomainNameServers...
		--
		SELECT
			p.property_id,
			p.property_name,
			p.property_type,
			p.layer2_network_collection_id,
			p.property_value_netblock_collection_id
		INTO prop
		FROM
			property p JOIN
			layer2_network_collection l2c USING (layer2_network_collection_id)
		WHERE
			p.property_name = 'DomainNameServers' AND
			p.property_type = 'DHCP' AND
			l2c.layer2_network_collection_name = sc AND
			l2c.layer2_network_collection_type = 'DHCP';

		--
		-- ... otherwise insert one
		--
		IF NOT FOUND THEN
			INSERT INTO property (
				property_name,
				property_type,
				layer2_network_collection_id,
				property_value_netblock_collection_id
			) SELECT
				'DomainNameServers',
				'DHCP',
				layer2_network_collection_id,
				dns_nc.netblock_collection_id
			FROM
				layer2_network_collection l2c
			WHERE
				l2c.layer2_network_collection_name = sc AND
				l2c.layer2_network_collection_type = 'DHCP'
			RETURNING 
				property_id,
				property_name,
				property_type,
				layer2_network_collection_id,
				property_value_netblock_collection_id
			INTO prop;
		END IF;

		RETURN QUERY
		SELECT
			nc.netblock_collection_id,
            nc.netblock_collection_name,
            nc.netblock_collection_type,
            n.netblock_id,
            n.ip_address
		FROM
			property p JOIN
			layer2_network_collection l2c USING (layer2_network_collection_id)
				JOIN
			netblock_collection nc ON (p.property_value_netblock_collection_id =
				nc.netblock_collection_id) JOIN
			netblock_collection_netblock ncn ON (nc.netblock_collection_id =
				ncn.netblock_collection_id) JOIN
			netblock n USING (netblock_id)
		WHERE
			p.property_id = prop.property_id;
			
		RETURN;
	END
$$
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = 'jazzhands';

CREATE OR REPLACE FUNCTION dhcp_manip.set_site_dhcp_server(
	site_code			text,
	device_id			jazzhands.device.device_id%TYPE,
	set_failover		boolean DEFAULT 'false'			
) RETURNS boolean AS
$$
	DECLARE
		dcid		jazzhands.device_collection.device_collection_id%TYPE;
		prop		record;
		sc			ALIAS FOR site_code;
		devid		ALIAS FOR device_id;
	BEGIN
		IF sc IS NULL THEN
			RAISE EXCEPTION 'site_code may not be null';
		END IF;

		--
		-- Get the per-device device collection for this device
		--
		SELECT
			device_collection_id INTO dcid
		FROM
			device_collection_dc JOIN
			device_collection_device dcd USING (device_collection_id)
		WHERE
			dc.device_collection_type = 'per-device' AND
			dcd.device_id = dcid;

		IF NOT FOUND THEN
			RAISE EXCEPTION
				'Unable to find per-device device_collection for device %',
				devid;
			RETURN false;
		END IF;

		--
		-- See if there is a property already created for this site for
		-- DomainNameServers...
		--
		SELECT
			p.property_id,
			p.property_name,
			p.property_type,
			p.layer2_network_collection_id,
			p.property_value_netblock_collection_id
		INTO prop
		FROM
			property p JOIN
			layer2_network_collection l2c USING (layer2_network_collection_id)
		WHERE
			p.property_name = 
				CASE
					WHEN set_failover THEN 'FailoverDHCPServer'
					ELSE 'PrimaryDHCPServer'
				END AND
			p.property_type = 'DHCP' AND
			l2c.layer2_network_collection_name = sc AND
			l2c.layer2_network_collection_type = 'DHCP';

		--
		-- Update it or insert a new one
		--
		IF FOUND THEN
			UPDATE property p SET property_value_device_collection_id = dcid
			WHERE p.property_id = prop
			RETURNING
			    property_id,
                property_name,
                property_type,
                layer2_network_collection_id,
                property_value_device_collection_id
            INTO prop;
		ELSE
			INSERT INTO property (
				property_name,
				property_type,
				layer2_network_collection_id,
				property_value_netblock_collection_id
			) SELECT
				CASE
					WHEN set_failover THEN 'FailoverDHCPServer'
					ELSE 'PrimaryDHCPServer'
				END,
				'DHCP',
				layer2_network_collection_id,
				dns_nc.netblock_collection_id
			FROM
				layer2_network_collection l2c
			WHERE
				l2c.layer2_network_collection_name = sc AND
				l2c.layer2_network_collection_type = 'DHCP'
			RETURNING 
				property_id,
				property_name,
				property_type,
				layer2_network_collection_id,
                property_value_device_collection_id
			INTO prop;
		END IF;

		RETURN true;
	END
$$
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = 'jazzhands';

CREATE OR REPLACE FUNCTION dhcp_manip.set_site_pxe_servers(
	site_code			text,
	ip_address			inet,
	ip_universe_id		jazzhands.ip_universe.ip_universe_id%TYPE
) RETURNS boolean AS
$$
	DECLARE
		pxe_nc		record;
		prop		record;
		sc			ALIAS FOR site_code;
		ip			ALIAS FOR ip_address;
		iuid		ALIAS FOR ip_universe_id;
	BEGIN
		IF sc IS NULL THEN
			RAISE EXCEPTION 'site_code may not be null';
		END IF;

		--
		-- Fetch the netblock collection for the PXE server for this site
		-- if it exists
		--
		SELECT
			* INTO pxe_nc
		FROM
			netblock_collection nc
		WHERE
			(nc.netblock_collection_name, nc.netblock_collection_type) =
				('PXEHost-' || sc, 'NetworkConfigSingleAddresses');

		--
		-- ... otherwise insert one
		--
		IF NOT FOUND THEN
			INSERT INTO netblock_collection (
				netblock_collection_name,
				netblock_collection_type
			) VALUES (
				'PXEHost-' || sc,
				'NetworkConfigSingleAddresses'
			) RETURNING * INTO pxe_nc;
		END IF;

		RAISE NOTICE 'Fetched netblock_collection %',
			pxe_nc.netblock_collection_id;

		IF pxe_nc.netblock_collection_id IS NULL THEN
			RETURN NULL;
		END IF;

		--
		-- clean it out, just in case
		--
		DELETE FROM netblock_collection_netblock ncn WHERE
			ncn.netblock_collection_id = pxe_nc.netblock_collection_id;
	
		--
		-- Insert the netblocks into the netblock_collection for the
		-- addresses passed.  Note that if they don't exist, they are
		-- not created
		--
		INSERT INTO netblock_collection_netblock (
			netblock_collection_id,
			netblock_id
		)
		SELECT
			pxe_nc.netblock_collection_id,
			n.netblock_id
		FROM
			netblock n
		WHERE
			n.netblock_type = 'default' AND
			n.ip_universe_id = iuid AND
			n.is_single_address = true AND
			host(n.ip_address) = host(ip);


		--
		-- See if there is a property already created for this site for
		-- NextServer
		--
		SELECT
			p.property_id,
			p.property_name,
			p.property_type,
			p.layer2_network_collection_id,
			p.property_value_netblock_collection_id
		INTO prop
		FROM
			property p JOIN
			layer2_network_collection l2c USING (layer2_network_collection_id)
		WHERE
			p.property_name = 'NextServer' AND
			p.property_type = 'DHCP' AND
			l2c.layer2_network_collection_name = sc AND
			l2c.layer2_network_collection_type = 'DHCP';

		--
		-- ... otherwise insert one
		--
		IF NOT FOUND THEN
			INSERT INTO property (
				property_name,
				property_type,
				layer2_network_collection_id,
				property_value_netblock_collection_id
			) SELECT
				'NextServer',
				'DHCP',
				layer2_network_collection_id,
				pxe_nc.netblock_collection_id
			FROM
				layer2_network_collection l2c
			WHERE
				l2c.layer2_network_collection_name = sc AND
				l2c.layer2_network_collection_type = 'DHCP'
			RETURNING 
				property_id,
				property_name,
				property_type,
				layer2_network_collection_id,
				property_value_netblock_collection_id
			INTO prop;
		END IF;

		RETURN true;
	END
$$
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = 'jazzhands';

SELECT schema_support.replay_saved_grants();

REVOKE USAGE ON SCHEMA dhcp_manip FROM public;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA dhcp_manip FROM public;

GRANT USAGE ON SCHEMA dhcp_manip TO iud_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA dhcp_manip TO iud_role;
