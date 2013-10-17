
CREATE OR REPLACE VIEW v_netblock_hier AS
WITH RECURSIVE var_recurse (
	netblock_level,
	root_netblock_id,
	ip,
	netblock_id,
	ip_address,
	netmask_bits,
	netblock_status,
	IS_SINGLE_ADDRESS,
	IS_IPV4_ADDRESS,
	description,
	parent_netblock_id,
	site_code,
	array_path,
	array_ip_path,
	cycle
) as  (
	select  0			as netblock_level,
		nb.netblock_id		as root_netblock_id,
		net_manip.inet_dbtop(nb.ip_address) as ip,
		nb.netblock_id,
		nb.ip_address,
		nb.netmask_bits,
		nb.netblock_status,
		nb.IS_SINGLE_ADDRESS,
		nb.IS_IPV4_ADDRESS,
		nb.description,
		nb.parent_netblock_id,
		snb.site_code,
		ARRAY[nb.netblock_id] as "array",
		ARRAY[nb.ip_address] as "array",
		false as bool
	  from  netblock nb
		left join site_netblock snb
			on snb.netblock_id = nb.netblock_id
	where   nb.IS_SINGLE_ADDRESS = 'N'
UNION ALL
	SELECT	x.netblock_level +1	as netblock_level,
		x.root_netblock_id	as root_netblock_id,
		net_manip.inet_dbtop(nb.ip_address) as ip,
		nb.netblock_id,
		nb.ip_address,
		nb.netmask_bits,
		nb.netblock_status,
		nb.IS_SINGLE_ADDRESS,
		nb.IS_IPV4_ADDRESS,
		nb.description,
		nb.parent_netblock_id,
		snb.site_code,
		x.array_path || nb.netblock_id AS array_path,
		x.array_ip_path || nb.ip_address AS array_ip_path,
		nb.netblock_id = ANY (x.array_path)
	  from  var_recurse x
	  	inner join netblock nb
			on x.netblock_id = nb.parent_netblock_id
		left join site_netblock snb
			on snb.netblock_id = nb.netblock_id
	where   nb.IS_SINGLE_ADDRESS = 'N'
	and	NOT cycle
) SELECT 
	netblock_level,
	root_netblock_id,
	ip,
	netblock_id,
	ip_address,
	netmask_bits,
	netblock_status,
	IS_SINGLE_ADDRESS,
	IS_IPV4_ADDRESS,
	description,
	parent_netblock_id,
	site_code,
	array_to_string(var_recurse.array_path, '/'::text) AS text_path,
	array_path,
	array_ip_path
from var_recurse;
;
