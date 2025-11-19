
\set ON_ERROR_STOP

GRANT USAGE ON SCHEMA jazzhands_legacy TO app_zonegen;

GRANT SELECT ON jazzhands_legacy.device TO app_zonegen;
GRANT SELECT ON jazzhands_legacy.device_collection_device TO app_zonegen;
GRANT SELECT ON jazzhands_legacy.v_device_coll_hier_detail TO app_zonegen;
GRANT SELECT ON jazzhands_legacy.v_property TO app_zonegen;

GRANT SELECT ON jazzhands_legacy.dns_change_record TO app_zonegen;
GRANT SELECT ON jazzhands_legacy.dns_domain TO app_zonegen;
GRANT SELECT ON jazzhands_legacy.v_nblk_coll_netblock_expanded TO app_zonegen;
GRANT SELECT ON jazzhands_legacy.netblock TO app_zonegen;
GRANT SELECT ON jazzhands_legacy.site_netblock TO app_zonegen;
GRANT SELECT ON jazzhands_legacy.v_dns TO app_zonegen;
GRANT SELECT ON jazzhands_legacy.dns_domain_ip_universe TO app_zonegen;
GRANT SELECT ON jazzhands_legacy.ip_universe TO app_zonegen;
GRANT SELECT ON jazzhands_legacy.dns_domain_collection TO app_zonegen;
GRANT SELECT ON jazzhands_legacy.dns_domain_collection_dns_dom TO app_zonegen;
GRANT SELECT ON jazzhands_legacy.ip_universe_visibility TO app_zonegen;
GRANT SELECT ON jazzhands_legacy.netblock_collection TO app_zonegen;
GRANT SELECT ON jazzhands_legacy.netblock_collection_netblock TO app_zonegen;
GRANT SELECT ON jazzhands_legacy.dns_record TO app_zonegen;
GRANT SELECT ON jazzhands_legacy.v_dns_changes_pending TO app_zonegen;

GRANT EXECUTE ON FUNCTION script_hooks.zonegen_pre() TO app_zonegen;
GRANT EXECUTE ON FUNCTION script_hooks.zonegen_post() TO app_zonegen;

GRANT UPDATE ON jazzhands_legacy.dns_domain_ip_universe TO app_zonegen;
GRANT DELETE ON jazzhands_legacy.dns_change_record TO app_zonegen;


GRANT USAGE ON schema dns_utils TO app_zonegen;
GRANT EXECUTE ON function dns_utils.v6_inaddr(inet) TO app_zonegen;
GRANT USAGE ON schema script_hooks TO app_zonegen;

GRANT SELECT,UPDATE,DELETE ON jazzhands_legacy.dns_change_record TO app_zonegen;
GRANT EXECUTE ON FUNCTION dns_utils.get_domain_from_cidr(block inet) TO
        app_zonegen;
GRANT USAGE ON schema net_manip TO app_zonegen;

alter FUNCTION dns_utils.get_domain_from_cidr(block inet) security definer;
