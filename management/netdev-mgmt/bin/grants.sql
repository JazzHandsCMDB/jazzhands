ALTER USER app_network_manip SET search_path = 'jazzhands';

GRANT SELECT ON
	jazzhands.v_layerx_network_expanded,
	jazzhands.device,
	jazzhands.device_type,
	jazzhands.network_interface,
	jazzhands.network_interface_netblock,
	jazzhands.netblock,
	jazzhands.device_encapsulation_domain
TO app_network_manip;

GRANT USAGE ON SCHEMA jazzhands TO app_network_manip;
GRANT USAGE ON SCHEMA layerx_network_manip TO app_network_manip;
GRANT EXECUTE ON FUNCTION
	layerx_network_manip.delete_layer2_network ( integer, boolean)
TO app_network_manip;
