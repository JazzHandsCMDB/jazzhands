/*
Invoked:

	--suffix=v64
	--col-default=appaal_group_name:'database'
	--col-default=logical_volume_type:'legacy'
	--col-default=physical_address-type='location'
	--scan-tables
	--first=layer2_network
	--first=layer3_network
	v_property
	approval_utils.v_approval_matrix
	--first=company_collection
	--first=company
*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance();
select timeofday(), now();
--
-- Process middle (non-trigger) schema jazzhands
--
--
-- Process middle (non-trigger) schema net_manip
--
--
-- Process middle (non-trigger) schema network_strings
--
--
-- Process middle (non-trigger) schema time_util
--
--
-- Process middle (non-trigger) schema dns_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('dns_utils', 'add_dns_domain');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS dns_utils.add_dns_domain ( soa_name character varying, dns_domain_type character varying, add_nameservers boolean );
CREATE OR REPLACE FUNCTION dns_utils.add_dns_domain(soa_name character varying, dns_domain_type character varying DEFAULT NULL::character varying, add_nameservers boolean DEFAULT true)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	elements		text[];
	parent_zone		text;
	parent_id		dns_domain.dns_domain_id%type;
	domain_id		dns_domain.dns_domain_id%type;
	elem			text;
	sofar			text;
	rvs_nblk_id		netblock.netblock_id%type;
BEGIN
	IF soa_name IS NULL THEN
		RETURN NULL;
	END IF;
	elements := regexp_split_to_array(soa_name, '\.');
	sofar := '';
	FOREACH elem in ARRAY elements
	LOOP
		IF octet_length(sofar) > 0 THEN
			sofar := sofar || '.';
		END IF;
		sofar := sofar || elem;
		parent_zone := regexp_replace(soa_name, '^'||sofar||'.', '');
		EXECUTE 'SELECT dns_domain_id FROM dns_domain 
			WHERE soa_name = $1' INTO parent_id USING soa_name;
		IF parent_id IS NOT NULL THEN
			EXIT;
		END IF;
	END LOOP;

	IF dns_domain_type IS NULL THEN
		IF soa_name ~ '^.*(in-addr|ip6)\.arpa$' THEN
			dns_domain_type := 'reverse';
		END IF;
	END IF;

	IF dns_domain_type IS NULL THEN
		RAISE EXCEPTION 'Unable to guess dns_domain_type for %',
			soa_name USING ERRCODE = 'not_null_violation'; 
	END IF;

	EXECUTE '
		INSERT INTO dns_domain (
			soa_name,
			soa_class,
			soa_mname,
			soa_rname,
			parent_dns_domain_id,
			should_generate,
			dns_domain_type
		) VALUES (
			$1,
			$2,
			$3,
			$4,
			$5,
			$6,
			$7
		) RETURNING dns_domain_id' INTO domain_id 
		USING soa_name, 
			'IN',
			(select property_value from property where property_type = 'Defaults'
				and property_name = '_dnsmname'),
			(select property_value from property where property_type = 'Defaults'
				and property_name = '_dnsrname'),
			parent_id,
			'Y',
			dns_domain_type
	;

	IF dns_domain_type = 'reverse' THEN
		rvs_nblk_id := dns_utils.get_or_create_rvs_netblock_link(
			soa_name, domain_id);
	END IF;

	IF add_nameservers THEN
		PERFORM dns_utils.add_ns_records(domain_id);
	END IF;

	RETURN domain_id;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('dns_utils', 'add_domains_from_netblock');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS dns_utils.add_domains_from_netblock ( netblock_id integer );
CREATE OR REPLACE FUNCTION dns_utils.add_domains_from_netblock(netblock_id integer)
 RETURNS TABLE(dns_domain_id integer, soa_name text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	block		inet;
	domain		text;
	domain_id	dns_domain.dns_domain_id%TYPE;
	nid			ALIAS FOR netblock_id;
BEGIN
	SELECT ip_address INTO block FROM netblock n WHERE n.netblock_id = nid; 

	RAISE DEBUG 'Createing inverse DNS zones for %s', block;

	RETURN QUERY SELECT
		dns_utils.add_dns_domain(
			soa_name := x.soa_name,
			dns_domain_type := 'reverse'
			),
		x.soa_name::text
	FROM
		dns_utils.get_all_domain_rows_for_cidr(block) x LEFT JOIN
		dns_domain d USING (soa_name)
	WHERE
		d.dns_domain_id IS NULL;

END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('dns_utils', 'get_all_domains_for_cidr');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS dns_utils.get_all_domains_for_cidr ( block inet );
CREATE OR REPLACE FUNCTION dns_utils.get_all_domains_for_cidr(block inet)
 RETURNS text[]
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	cur			inet;
	rv			text[];
BEGIN
	IF family(block) = 4 THEN
		IF (masklen(block) >= 24) THEN
			rv = rv || dns_utils.get_domain_from_cidr(set_masklen(block, 24));
		ELSE
			FOR cur IN SELECT set_masklen((block + o), 24) 
						FROM generate_series(0, (256 * (2 ^ (24 - 
							masklen(block))) - 1)::integer, 256) as x(o)
			LOOP
				rv = rv || dns_utils.get_domain_from_cidr(cur);
			END LOOP;
		END IF;
	ELSIF family(block) = 6 THEN
			-- note sure if we should do this or not, but we are..
			cur := set_masklen(block, 64);
			rv = rv || dns_utils.get_domain_from_cidr(cur);
	ELSE
		RAISE EXCEPTION 'Not IPv% aware.', family(block);
	END IF;
    return rv;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION dns_utils.get_all_domain_rows_for_cidr(block inet)
 RETURNS TABLE(soa_name text)
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	cur			inet;
BEGIN
	IF family(block) = 4 THEN
		IF (masklen(block) >= 24) THEN
			soa_name := dns_utils.get_domain_from_cidr(set_masklen(block, 24));
			RETURN NEXT;
		ELSE
			FOR cur IN 
				SELECT 
					set_masklen((block + o), 24) 
				FROM
					generate_series(
						0, 
						(256 * (2 ^ (24 - masklen(block))) - 1)::integer,
						256)
					AS x(o)
			LOOP
				soa_name := dns_utils.get_domain_from_cidr(cur);
				RETURN NEXT;
			END LOOP;
		END IF;
	ELSIF family(block) = 6 THEN
			-- note sure if we should do this or not, but we are..
			cur := set_masklen(block, 64);
			soa_name := dns_utils.get_domain_from_cidr(cur);
			RETURN NEXT;
	ELSE
		RAISE EXCEPTION 'Not IPv% aware.', family(block);
	END IF;
    return;
END;
$function$
;

--
-- Process middle (non-trigger) schema person_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('person_manip', 'pick_login');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS person_manip.pick_login ( in_account_realm_id integer, in_first_name character varying, in_middle_name character varying, in_last_name character varying );
CREATE OR REPLACE FUNCTION person_manip.pick_login(in_account_realm_id integer, in_first_name character varying DEFAULT NULL::character varying, in_middle_name character varying DEFAULT NULL::character varying, in_last_name character varying DEFAULT NULL::character varying)
 RETURNS character varying
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_acctrealmid	integer;
	_login			varchar;
	_trylogin		varchar;
	_trunclen		integer;
    id				account.account_id%TYPE;
	fn		text;
	ln		text;
BEGIN
	SELECT	property_value::int
	INTO	_trunclen
	FROM	property
	WHERE	property_type = 'Defaults'
	AND	 	property_name = '_max_default_login_length';

	IF NOT FOUND THEN
		_trunclen := 15;
	END IF;

	-- remove special characters
	fn = regexp_replace(lower(in_first_name), '[^a-z]', '', 'g');
	ln = regexp_replace(lower(in_last_name), '[^a-z]', '', 'g');
	_acctrealmid := in_account_realm_id;
	-- Try first initial, last name
	_login = lpad(lower(fn), 1) || lower(ln);

	IF _trunclen IS NOT NULL AND _trunclen > 0 THEN
		_login := left(_login, _trunclen);
	END IF;

	SELECT account_id into id FROM account where account_realm_id = _acctrealmid
		AND login = _login;

	IF id IS NULL THEN
		RETURN _login;
	END IF;

	-- Try first initial, middle initial, last name
	if in_middle_name IS NOT NULL THEN
		_login = lpad(lower(fn), 1) || lpad(lower(in_middle_name), 1) || lower(ln);

		IF _trunclen IS NOT NULL AND _trunclen > 0 THEN
			_login := left(_login, _trunclen);
		END IF;
		SELECT account_id into id FROM account where account_realm_id = _acctrealmid
			AND login = _login;
		IF id IS NULL THEN
			RETURN _login;
		END IF;
	END IF;

	-- if length of first+last is <= 10 then try that.
	_login = lower(fn) || lower(ln);
	IF _trunclen IS NOT NULL AND _trunclen > 0 THEN
		_login := left(_login, _trunclen);
	END IF;
	IF char_length(_login) < 10 THEN
		SELECT account_id into id FROM account where account_realm_id = _acctrealmid
			AND login = _login;
		IF id IS NULL THEN
			RETURN _login;
		END IF;
	END IF;

	-- ok, keep trying to add a number to first initial, last
	_login = lpad(lower(fn), 1) || lower(ln);
	FOR i in 1..500 LOOP
		IF _trunclen IS NOT NULL AND _trunclen > 0 THEN
			_login := left(_login, _trunclen - 2);
		END IF;
		_trylogin := _login || i;
		SELECT account_id into id FROM account where account_realm_id = _acctrealmid
			AND login = _trylogin;
		IF id IS NULL THEN
			RETURN _trylogin;
		END IF;
	END LOOP;

	-- wtf. this should never happen
	RETURN NULL;
END;
$function$
;

--
-- Process middle (non-trigger) schema auto_ac_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('auto_ac_manip', 'destroy_report_account_collections');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS auto_ac_manip.destroy_report_account_collections ( account_id integer, account_realm_id integer, numrpt integer, numrlup integer );
CREATE OR REPLACE FUNCTION auto_ac_manip.destroy_report_account_collections(account_id integer, account_realm_id integer DEFAULT NULL::integer, numrpt integer DEFAULT NULL::integer, numrlup integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_account	account%ROWTYPE;
	_directac	account_collection.account_collection_id%TYPE;
	_rollupac	account_collection.account_collection_id%TYPE;
BEGIN
	IF account_realm_id IS NULL THEN
		EXECUTE '
			SELECT account_realm_id
			FROM	account
			WHERE	account_id = $1
		' INTO account_realm_id USING account_id;
	END IF;

	IF numrpt IS NULL THEN
		numrpt := auto_ac_manip.get_num_direct_reports(account_id, account_realm_id);
	END IF;
	IF numrpt = 0 THEN
		PERFORM auto_ac_manip.purge_report_account_collection(
			account_id := account_id, 
			account_realm_id := account_realm_id,
			ac_type := 'AutomatedDirectsAC');
		RETURN;
	END IF;

	IF numrlup IS NULL THEN
		numrlup := auto_ac_manip.get_num_reports_with_reports(account_id, account_realm_id);
	END IF;
	IF numrlup = 0 THEN 
		PERFORM auto_ac_manip.purge_report_account_collection(
			account_id := account_id, 
			account_realm_id := account_realm_id,
			ac_type := 'AutomatedRollupsAC');
		RETURN;
	END IF;

END;
$function$
;

--
-- Process middle (non-trigger) schema company_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('company_manip', 'add_company');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS company_manip.add_company ( _company_name text, _company_types text[], _parent_company_id integer, _account_realm_id integer, _company_short_name text, _description text );
CREATE OR REPLACE FUNCTION company_manip.add_company(_company_name text, _company_types text[] DEFAULT NULL::text[], _parent_company_id integer DEFAULT NULL::integer, _account_realm_id integer DEFAULT NULL::integer, _company_short_name text DEFAULT NULL::text, _description text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_cmpid	company.company_id%type;
	_short	text;
	_isfam	char(1);
BEGIN
	IF _company_types @> ARRAY['corporate family'] THEN
		_isfam := 'Y';
	ELSE
		_isfam := 'N';
	END IF;
	IF _company_short_name IS NULL and _isfam = 'Y' THEN
		_short := lower(regexp_replace(
				regexp_replace(
					regexp_replace(_company_name, 
						E'\\s+(ltd|sarl|limited|pt[ye]|GmbH|ag|ab|inc)', 
						'', 'gi'),
					E'[,\\.\\$#@]', '', 'mg'),
				E'\\s+', '_', 'gi'));
	END IF;

	INSERT INTO company (
		company_name, company_short_name,
		parent_company_id, description
	) VALUES (
		_company_name, _short,
		_parent_company_id, _description
	) RETURNING company_id INTO _cmpid;

	IF _account_realm_id IS NOT NULL THEN
		INSERT INTO account_realm_company (
			account_realm_id, company_id
		) VALUES (
			_account_realm_id, _cmpid
		);
	END IF;

	IF _company_types IS NOT NULL THEN
		PERFORM company_manip.add_company_types(_cmpid, _account_realm_id, _company_types);
	END IF;

	RETURN _cmpid;
END;
$function$
;

--
-- Process middle (non-trigger) schema port_support
--
--
-- Process middle (non-trigger) schema port_utils
--
--
-- Process middle (non-trigger) schema device_utils
--
--
-- Process middle (non-trigger) schema netblock_utils
--
--
-- Process middle (non-trigger) schema netblock_manip
--
-- Changed function
SELECT schema_support.save_grants_for_replay('netblock_manip', 'allocate_netblock');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS netblock_manip.allocate_netblock ( parent_netblock_list integer[], netmask_bits integer, address_type text, can_subnet boolean, allocation_method text, rnd_masklen_threshold integer, rnd_max_count integer, ip_address inet, description character varying, netblock_status character varying );
CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock(parent_netblock_list integer[], netmask_bits integer DEFAULT NULL::integer, address_type text DEFAULT 'netblock'::text, can_subnet boolean DEFAULT true, allocation_method text DEFAULT NULL::text, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024, ip_address inet DEFAULT NULL::inet, description character varying DEFAULT NULL::character varying, netblock_status character varying DEFAULT 'Allocated'::character varying)
 RETURNS netblock
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	parent_rec		RECORD;
	netblock_rec	RECORD;
	inet_rec		RECORD;
	loopback_bits	integer;
	inet_family		integer;
	ip_addr			ALIAS FOR ip_address;
BEGIN
	IF parent_netblock_list IS NULL THEN
		RAISE 'parent_netblock_list must be specified'
		USING ERRCODE = 'null_value_not_allowed';
	END IF;

	IF address_type NOT IN ('netblock', 'single', 'loopback') THEN
		RAISE 'address_type must be one of netblock, single, or loopback'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF netmask_bits IS NULL AND address_type = 'netblock' THEN
		RAISE EXCEPTION
			'You must specify a netmask when address_type is netblock'
			USING ERRCODE = 'invalid_parameter_value';
	END IF;

	IF ip_address IS NOT NULL THEN
		SELECT 
			array_agg(netblock_id)
		INTO
			parent_netblock_list
		FROM
			netblock n
		WHERE
			ip_addr <<= n.ip_address AND
			netblock_id = ANY(parent_netblock_list);

		IF parent_netblock_list IS NULL THEN
			RETURN NULL;
		END IF;
	END IF;

	-- Lock the parent row, which should keep parallel processes from
	-- trying to obtain the same address

	FOR parent_rec IN SELECT * FROM jazzhands.netblock WHERE netblock_id = 
			ANY(allocate_netblock.parent_netblock_list) ORDER BY netblock_id
			FOR UPDATE LOOP

		IF parent_rec.is_single_address = 'Y' THEN
			RAISE EXCEPTION 'parent_netblock_id refers to a single_address netblock'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;

		IF inet_family IS NULL THEN
			inet_family := family(parent_rec.ip_address);
		ELSIF inet_family != family(parent_rec.ip_address) 
				AND ip_address IS NULL THEN
			RAISE EXCEPTION 'Allocation may not mix IPv4 and IPv6 addresses'
			USING ERRCODE = 'JH10F';
		END IF;

		IF address_type = 'loopback' THEN
			loopback_bits := 
				CASE WHEN 
					family(parent_rec.ip_address) = 4 THEN 32 ELSE 128 END;

			IF parent_rec.can_subnet = 'N' THEN
				RAISE EXCEPTION 'parent subnet must have can_subnet set to Y'
					USING ERRCODE = 'JH10B';
			END IF;
		ELSIF address_type = 'single' THEN
			IF parent_rec.can_subnet = 'Y' THEN
				RAISE EXCEPTION
					'parent subnet for single address must have can_subnet set to N'
					USING ERRCODE = 'JH10B';
			END IF;
		ELSIF address_type = 'netblock' THEN
			IF parent_rec.can_subnet = 'N' THEN
				RAISE EXCEPTION 'parent subnet must have can_subnet set to Y'
					USING ERRCODE = 'JH10B';
			END IF;
		END IF;
	END LOOP;

 	IF NOT FOUND THEN
 		RETURN NULL;
 	END IF;

	IF address_type = 'loopback' THEN
		-- If we're allocating a loopback address, then we need to create
		-- a new parent to hold the single loopback address

		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			netmask_bits := loopback_bits,
			single_address := false,
			allocation_method := allocation_method,
			desired_ip_address := ip_address,
			max_addresses := 1
			);

		IF NOT FOUND THEN
			RETURN NULL;
		END IF;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			inet_rec.netblock_type,
			'N',
			'N',
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO parent_rec;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			parent_rec.netblock_type,
			'Y',
			'N',
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

		PERFORM dns_utils.add_domains_from_netblock(
			netblock_id := netblock_rec.netblock_id);

		RETURN netblock_rec;
	END IF;

	IF address_type = 'single' THEN
		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			single_address := true,
			allocation_method := allocation_method,
			desired_ip_address := ip_address,
			rnd_masklen_threshold := rnd_masklen_threshold,
			rnd_max_count := rnd_max_count,
			max_addresses := 1
			);

		IF NOT FOUND THEN
			RETURN NULL;
		END IF;

		RAISE DEBUG 'ip_address is %', inet_rec.ip_address;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			inet_rec.netblock_type,
			'Y',
			'N',
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

		RETURN netblock_rec;
	END IF;
	IF address_type = 'netblock' THEN
		SELECT * INTO inet_rec FROM netblock_utils.find_free_netblocks(
			parent_netblock_list := parent_netblock_list,
			netmask_bits := netmask_bits,
			single_address := false,
			allocation_method := allocation_method,
			desired_ip_address := ip_address,
			max_addresses := 1);

		IF NOT FOUND THEN
			RETURN NULL;
		END IF;

		INSERT INTO jazzhands.netblock (
			ip_address,
			netblock_type,
			is_single_address,
			can_subnet,
			ip_universe_id,
			description,
			netblock_status
		) VALUES (
			inet_rec.ip_address,
			inet_rec.netblock_type,
			'N',
			CASE WHEN can_subnet THEN 'Y' ELSE 'N' END,
			inet_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;
		
		RAISE DEBUG 'Allocated netblock_id % for %',
			netblock_rec.netblock_id,
			netblock_re.ip_address;

		PERFORM dns_utils.add_domains_from_netblock(
			netblock_id := netblock_rec.netblock_id);

		RETURN netblock_rec;
	END IF;
END;
$function$
;

--
-- Process middle (non-trigger) schema physical_address_utils
--
--
-- Process middle (non-trigger) schema component_utils
--
--
-- Process middle (non-trigger) schema snapshot_manip
--
--
-- Process middle (non-trigger) schema lv_manip
--
--
-- Process middle (non-trigger) schema schema_support
--
--
-- Process middle (non-trigger) schema approval_utils
--
-- Changed function
SELECT schema_support.save_grants_for_replay('approval_utils', 'approve');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS approval_utils.approve ( approval_instance_item_id integer, approved character, approving_account_id integer, new_value text );
CREATE OR REPLACE FUNCTION approval_utils.approve(approval_instance_item_id integer, approved character, approving_account_id integer, new_value text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO approval_utils, jazzhands
AS $function$
DECLARE
	_r		RECORD;
	_aii	approval_instance_item%ROWTYPE;	
	_new	approval_instance_item.approval_instance_item_id%TYPE;	
	_chid	approval_process_chain.approval_process_chain_id%TYPE;
	_tally	INTEGER;
BEGIN
	EXECUTE '
		SELECT 	aii.approval_instance_item_id,
			ais.approval_instance_step_id,
			ais.approval_instance_id,
			ais.approver_account_id,
			ais.approval_type,
			aii.is_approved,
			ais.is_completed,
			aic.accept_app_process_chain_id,
			aic.reject_app_process_chain_id
   	     FROM    approval_instance ai
   		     INNER JOIN approval_instance_step ais
   			 USING (approval_instance_id)
   		     INNER JOIN approval_instance_item aii
   			 USING (approval_instance_step_id)
   		     INNER JOIN approval_instance_link ail
   			 USING (approval_instance_link_id)
			INNER JOIN approval_process_chain aic
				USING (approval_process_chain_id)
		WHERE approval_instance_item_id = $1
	' USING approval_instance_item_id INTO 	_r;

	--
	-- Ensure that only the person or their management chain can approve
	-- others; this may want to be a property on val_approval_type rather
	-- than hard coded on account...
	IF (_r.approval_type = 'account' AND _r.approver_account_id != approving_account_id ) THEN
		EXECUTE '
			WITH RECURSIVE rec (
					root_account_id,
					account_id,
					manager_account_id,
					apath, cycle
	    			) as (
		    			SELECT  account_id as root_account_id,
			    			account_id, manager_account_id,
			    			ARRAY[account_id] as apath, false as cycle
		    			FROM    v_account_manager_map
					UNION ALL
		    			SELECT a.root_account_id, m.account_id, m.manager_account_id,
						a.apath || m.account_id, m.account_id=ANY(a.apath)
		    			FROM rec a join v_account_manager_map m
						ON a.manager_account_id = m.account_id
		    			WHERE not a.cycle
			) SELECT count(*) from rec where root_account_id = $1
				and manager_account_id = $2
		' INTO _tally USING _r.approver_account_id, approving_account_id;

		IF _tally = 0 THEN
			EXECUTE '
				SELECT	count(*)
				FROM	property
						INNER JOIN v_acct_coll_acct_expanded e
						USING (account_collection_id)
				WHERE	property_type = ''Defaults''
				AND		property_name = ''_can_approve_all''
				AND		e.account_id = $1
			' INTO _tally USING approving_account_id;

			IF _tally = 0 THEN
				RAISE EXCEPTION 'Only a person and their management chain may approve others';
			END IF;
		END IF;

	END IF;

	IF _r.approval_instance_item_id IS NULL THEN
		RAISE EXCEPTION 'Unknown approval_instance_item_id %',
			approval_instance_item_id;
	END IF;

	IF _r.is_approved IS NOT NULL THEN
		RAISE EXCEPTION 'Approval is already completed.';
	END IF;

	EXECUTE '
		UPDATE approval_instance_item
		SET is_approved = $2,
		approved_account_id = $3
		WHERE approval_instance_item_id = $1
	' USING approval_instance_item_id, approved, approving_account_id;

	IF approved = 'N' THEN
		IF _r.reject_app_process_chain_id IS NOT NULL THEN
			_chid := _r.reject_app_process_chain_id;	
		END IF;
	ELSIF approved = 'Y' THEN
		IF _r.accept_app_process_chain_id IS NOT NULL THEN
			_chid := _r.accept_app_process_chain_id;
		END IF;
	ELSE
		RAISE EXCEPTION 'Approved must be Y or N';
	END IF;

	IF _chid IS NOT NULL THEN
		_new := approval_utils.build_next_approval_item(
			approval_instance_item_id, _chid,
			_r.approval_instance_id, approved,
			approving_account_id, new_value);

		EXECUTE '
			UPDATE approval_instance_item
			SET next_approval_instance_item_id = $2
			WHERE approval_instance_item_id = $1
		' USING approval_instance_item_id, _new;
	END IF;

	RETURN true;
END;
$function$
;

DROP FUNCTION IF EXISTS approval_utils.build_attest (  );
-- Changed function
SELECT schema_support.save_grants_for_replay('approval_utils', 'build_next_approval_item');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS approval_utils.build_next_approval_item ( approval_instance_item_id integer, approval_process_chain_id integer, approval_instance_id integer, approved character, approving_account_id integer, new_value text );
CREATE OR REPLACE FUNCTION approval_utils.build_next_approval_item(approval_instance_item_id integer, approval_process_chain_id integer, approval_instance_id integer, approved character, approving_account_id integer, new_value text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO approval_utils, jazzhands
AS $function$
DECLARE
	_r		RECORD;
	_apc	approval_process_chain%ROWTYPE;	
	_new	approval_instance_item%ROWTYPE;	
	_acid	account.account_id%TYPE;
	_step	approval_instance_step.approval_instance_step_id%TYPE;
	_l		approval_instance_link.approval_instance_link_id%TYPE;
	apptype	text;
	_v			approval_utils.v_account_collection_approval_process%ROWTYPE;
BEGIN
	EXECUTE '
		SELECT apc.*
		FROM approval_process_chain apc
		WHERE approval_process_chain_id=$1
	' INTO _apc USING approval_process_chain_id;

	IF _apc.approval_process_chain_id is NULL THEN
		RAISE EXCEPTION 'Unable to follow this chain: %',
			approval_process_chain_id;
	END IF;

	EXECUTE '
		SELECT aii.*, ais.approver_account_id
		FROM approval_instance_item  aii
			INNER JOIN approval_instance_step ais
				USING (approval_instance_step_id)
		WHERE approval_instance_item_id=$1
	' INTO _r USING approval_instance_item_id;

	IF _apc.approving_entity = 'manager' THEN
		apptype := 'account';
		_acid := NULL;
		EXECUTE '
			SELECT manager_account_id
			FROM	v_account_manager_map
			WHERE	account_id = $1
		' INTO _acid USING approving_account_id;
		--
		-- return NULL because there is no manager for the person
		--
		IF _acid IS NULL THEN
			RETURN NULL;
		END IF;
	ELSIF _apc.approving_entity = 'jira-hr' THEN
		apptype := 'jira-hr';
		_acid :=  _r.approver_account_id;
	ELSIF _apc.approving_entity = 'rt-hr' THEN
		apptype := 'rt-hr';
		_acid :=  _r.approver_account_id;
	ELSIF _apc.approving_entity = 'recertify' THEN
		apptype := 'account';
		EXECUTE '
			SELECT approver_account_id
			FROM approval_instance_item  aii
				INNER JOIN approval_instance_step ais
					USING (approval_instance_step_id)
			WHERE approval_instance_item_id IN (
				SELECT	approval_instance_item_id
				FROM	approval_instance_item
				WHERE	next_approval_instance_item_id = $1
			)
		' INTO _acid USING approval_instance_item_id;
	ELSE
		RAISE EXCEPTION 'Can not handle approving entity %',
			_apc.approving_entity;
	END IF;

	IF _acid IS NULL THEN
		RAISE EXCEPTION 'This whould not happen:  Unable to discern approving account.';
	END IF;

	EXECUTE '
		SELECT	approval_instance_step_id
		FROM	approval_instance_step
		WHERE	approval_process_chain_id = $1
		AND		approval_instance_id = $2
		AND		approver_account_id = $3
		AND		is_completed = ''N''
	' INTO _step USING approval_process_chain_id,
		approval_instance_id, _acid;

	--
	-- _new gets built out for all the fields that should get inserted,
	-- and then at the end is stomped on by what actually gets inserted.
	--

	IF _step IS NULL THEN
		EXECUTE '
			INSERT INTO approval_instance_step (
				approval_instance_id, approval_process_chain_id,
				approval_instance_step_name,
				approver_account_id, approval_type, 
				approval_instance_step_due,
				description
			) VALUES (
				$1, $2, $3, $4, $5, approval_utils.calculate_due_date($6), $7
			) RETURNING approval_instance_step_id
		' INTO _step USING 
			approval_instance_id, approval_process_chain_id,
			_apc.approval_process_chain_name,
			_acid, apptype, 
			_apc.approval_chain_response_period::interval,
			concat(_apc.description, ' for ', _r.approver_account_id, ' by ',
			approving_account_id);
	END IF;

	IF _apc.refresh_all_data = 'Y' THEN
		-- this is called twice, should rethink how to not
		_v := approval_utils.refresh_approval_instance_item(approval_instance_item_id);
		_l := approval_utils.get_or_create_correct_approval_instance_link(
			approval_instance_item_id,
			_r.approval_instance_link_id
		);
		_new.approval_instance_link_id := _l;
		_new.approved_label := _v.approval_label;
		_new.approved_category := _v.approval_category;
		_new.approved_lhs := _v.approval_lhs;
		_new.approved_rhs := _v.approval_rhs;
	ELSE
		_new.approval_instance_link_id := _r.approval_instance_link_id;
		_new.approved_label := _r.approved_label;
		_new.approved_category := _r.approved_category;
		_new.approved_lhs := _r.approved_lhs;
		IF new_value IS NULL THEN
			_new.approved_rhs := _r.approved_rhs;
		ELSE
			_new.approved_rhs := new_value;
		END IF;
	END IF;

	-- RAISE NOTICE 'step is %', _step;
	-- RAISE NOTICE 'acid is %', _acid;

	EXECUTE '
		INSERT INTO approval_instance_item
			(approval_instance_link_id, approved_label, approved_category,
				approved_lhs, approved_rhs, approval_instance_step_id
			) SELECT $2, $3, $4,
				$5, $6, $7
			FROM approval_instance_item
			WHERE approval_instance_item_id = $1
			RETURNING *
	' INTO _new USING approval_instance_item_id, 
		_new.approval_instance_link_id, _new.approved_label, _new.approved_category,
		_new.approved_lhs, _new.approved_rhs,
		_step;

	-- RAISE NOTICE 'returning %', _new.approval_instance_item_id;
	RETURN _new.approval_instance_item_id;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('approval_utils', 'refresh_approval_instance_item');
-- Dropped in case type changes.
DROP FUNCTION IF EXISTS approval_utils.refresh_approval_instance_item ( approval_instance_item_id integer );
CREATE OR REPLACE FUNCTION approval_utils.refresh_approval_instance_item(approval_instance_item_id integer)
 RETURNS approval_utils.v_account_collection_approval_process
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO approval_utils, jazzhands
AS $function$
DECLARE
	_i	approval_instance_item.approval_instance_item_id%TYPE;
	_r	approval_utils.v_account_collection_approval_process%ROWTYPE;
BEGIN
	--
	-- XXX p comes out of one of the three clauses in 
	-- v_account_collection_approval_process .  It is likely that that view
	-- needs to be broken into 2 or 3 views joined together so there is no
	-- code redundancy.  This is almost certainly true because it is a pain
	-- to keep column lists in syn everywhere
	EXECUTE '
		WITH p AS (
		SELECT  login,
			account_id,
			person_id,
			mm.company_id,
			manager_account_id,
			manager_login,
			''person_company''::text as audit_table,
			audit_seq_id,
			approval_process_id,
			approval_process_chain_id,
			approving_entity,
				approval_process_description,
				approval_chain_description,
				approval_response_period,
				approval_expiration_action,
				attestation_frequency,
				current_attestation_name,
				current_attestation_begins,
				attestation_offset,
				approval_process_chain_name,
				property_val_rhs AS approval_category,
				CASE
					WHEN property_val_rhs = ''position_title''
						THEN ''Verify Position Title''
					END as approval_label,
			human_readable AS approval_lhs,
			CASE
			    WHEN property_val_rhs = ''position_title'' THEN pcm.position_title
			END as approval_rhs
		FROM    v_account_manager_map mm
			INNER JOIN v_person_company_audit_map pcm
			    USING (person_id)
			INNER JOIN v_approval_matrix am
			    ON property_val_lhs = ''person_company''
			    AND property_val_rhs = ''position_title''
		), x AS ( select i.approval_instance_item_id, p.*
		from	approval_instance_item i
			inner join approval_instance_step s
				using (approval_instance_step_id)
			inner join approval_instance_link l
				using (approval_instance_link_id)
			inner join audit.account_collection_account res
				on res."aud#seq" = l.acct_collection_acct_seq_id
			 inner join v_account_collection_approval_process p
				on i.approved_label = p.approval_label
				and res.account_id = p.account_id
		UNION
		select i.approval_instance_item_id, p.*
		from	approval_instance_item i
			inner join approval_instance_step s
				using (approval_instance_step_id)
			inner join approval_instance_link l
				using (approval_instance_link_id)
			inner join audit.person_company res
				on res."aud#seq" = l.person_company_seq_id
			 inner join p
				on i.approved_label = p.approval_label
				and res.person_id = p.person_id
		) SELECT 
			login,
			account_id,
			person_id,
					company_id,
					manager_account_id,
					manager_login,
					audit_table,
					audit_seq_id,
					approval_process_id,
					approval_process_chain_id,
					approving_entity,
					approval_process_description,
					approval_chain_description,
					approval_response_period,
					approval_expiration_action,
					attestation_frequency,
					current_attestation_name,
					current_attestation_begins,
					attestation_offset,
					approval_process_chain_name,
					approval_category,
					approval_label,
					approval_lhs,
					approval_rhs
				FROM x where	approval_instance_item_id = $1
			' INTO _r USING approval_instance_item_id;
			RETURN _r;
		END;
		$function$
;

-- New function
CREATE OR REPLACE FUNCTION approval_utils.build_attest(nowish timestamp without time zone DEFAULT now())
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO approval_utils, jazzhands
AS $function$
DECLARE
	_r			RECORD;
	ai			approval_instance%ROWTYPE;
	ail			approval_instance_link%ROWTYPE;
	ais			approval_instance_step%ROWTYPE;
	aii			approval_instance_item%ROWTYPE;
	tally		INTEGER;
	_acaid		INTEGER;
	_pcid		INTEGER;
BEGIN
	tally := 0;

	-- XXX need to add magic for entering after the right day of the period.
	FOR _r IN SELECT * 
				FROM v_account_collection_approval_process
				WHERE (approval_process_id, current_attestation_name) NOT IN
					(SELECT approval_process_id, approval_instance_name 
					 FROM approval_instance
					)
				AND current_attestation_begins < nowish
	LOOP
		IF _r.approving_entity != 'manager' THEN
			RAISE EXCEPTION 'Do not know how to process approving entity %',
				_r.approving_entity;
		END IF;

		IF (ai.approval_process_id IS NULL OR
				ai.approval_process_id != _r.approval_process_id) THEN

			INSERT INTO approval_instance ( 
				approval_process_id, description, approval_instance_name
			) VALUES ( 
				_r.approval_process_id, 
				_r.approval_process_description, _r.current_attestation_name
			) RETURNING * INTO ai;
		END IF;

		IF ais.approver_account_id IS NULL OR
				ais.approver_account_id != _r.manager_account_id THEN

			INSERT INTO approval_instance_step (
				approval_process_chain_id, approver_account_id, 
				approval_instance_id, approval_type,  
				approval_instance_step_name,
				approval_instance_step_due, 
				description
			) VALUES (
				_r.approval_process_chain_id, _r.manager_account_id,
				ai.approval_instance_id, 'account',
				_r.approval_process_chain_name,
				approval_utils.calculate_due_date(_r.approval_response_period::interval),
				concat(_r.approval_chain_description, ' - ', _r.manager_login)
			) RETURNING * INTO ais;
		END IF;

		IF _r.audit_table = 'account_collection_account' THEN
			_acaid := _r.audit_seq_id;
			_pcid := NULL;
		ELSIF _R.audit_table = 'person_company' THEN
			_acaid := NULL;
			_pcid := _r.audit_seq_id;
		END IF;

		INSERT INTO approval_instance_link ( 
			acct_collection_acct_seq_id, person_company_seq_id
		) VALUES ( 
			_acaid, _pcid
		) RETURNING * INTO ail;

		--
		-- need to create or find the correct step to insert someone into;
		-- probably need a val table that says if every approvers stuff should
		-- be aggregated into one step or ifs a step per underling.
		--

		INSERT INTO approval_instance_item (
			approval_instance_link_id, approval_instance_step_id,
			approved_category, approved_label, approved_lhs, approved_rhs
		) VALUES ( 
			ail.approval_instance_link_id, ais.approval_instance_step_id,
			_r.approval_category, _r.approval_label, _r.approval_lhs, _r.approval_rhs
		) RETURNING * INTO aii;

		UPDATE approval_instance_step 
		SET approval_instance_id = ai.approval_instance_id
		WHERE approval_instance_step_id = ais.approval_instance_step_id;
		tally := tally + 1;
	END LOOP;
	RETURN tally;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION approval_utils.message_replace(message text, start_time timestamp without time zone DEFAULT NULL::timestamp without time zone, due_time timestamp without time zone DEFAULT NULL::timestamp without time zone)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO approval_utils, jazzhands
AS $function$
DECLARE
	rv	text;
	stabroot	text;
	faqurl	text;
BEGIN
	SELECT property_value
	INTO stabroot
	FROM property
	WHERE property_name = '_stab_root'
	AND property_type = 'Defaults'
	ORDER BY property_id
	LIMIT 1;

	SELECT property_value
	INTO faqurl
	FROM property
	WHERE property_name = '_approval_faq_site'
	AND property_type = 'Defaults'
	ORDER BY property_id
	LIMIT 1;

	rv := message;
	rv := regexp_replace(rv, '%\{effective_date\}', start_time::date::text, 'g');
	rv := regexp_replace(rv, '%\{due_date\}', due_time::date::text, 'g');
	rv := regexp_replace(rv, '%\{stab_url\}', stabroot, 'g');
	rv := regexp_replace(rv, '%\{faq_url\}', faqurl, 'g');

	-- There is also due_threat, which is processed in approval-email.pl

	return rv;
END;
$function$
;

-- Creating new sequences....
CREATE SEQUENCE company_collection_company_collection_id_seq;
CREATE SEQUENCE dns_domain_collection_dns_domain_collection_id_seq;
CREATE SEQUENCE layer2_network_collection_layer2_network_collection_id_seq;
CREATE SEQUENCE layer3_network_collection_layer3_network_collection_id_seq;


--------------------------------------------------------------------
-- DEALING WITH TABLE layer2_network [3720821]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'layer2_network', 'layer2_network');

-- FOREIGN KEYS FROM
ALTER TABLE device_layer2_network DROP CONSTRAINT IF EXISTS fk_device_l2_net_l2netid;
ALTER TABLE layer2_connection_l2_network DROP CONSTRAINT IF EXISTS fk_l2c_l2n_l2netid;
ALTER TABLE layer2_connection_l2_network DROP CONSTRAINT IF EXISTS fk_l2cl2n_l2net_id_encap_typ;
ALTER TABLE layer3_network DROP CONSTRAINT IF EXISTS fk_l3net_l2net;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_prop_l2netid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.layer2_network DROP CONSTRAINT IF EXISTS fk_l2_net_encap_domain;
ALTER TABLE jazzhands.layer2_network DROP CONSTRAINT IF EXISTS fk_l2_net_encap_range_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'layer2_network');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.layer2_network DROP CONSTRAINT IF EXISTS ak_l2_net_l2net_encap_typ;
ALTER TABLE jazzhands.layer2_network DROP CONSTRAINT IF EXISTS ak_l2net_encap_name;
ALTER TABLE jazzhands.layer2_network DROP CONSTRAINT IF EXISTS ak_l2net_encap_tag;
ALTER TABLE jazzhands.layer2_network DROP CONSTRAINT IF EXISTS pk_layer2_network;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_l2_net_encap_domain";
DROP INDEX IF EXISTS "jazzhands"."xif_l2_net_encap_range_id";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_layer2_network ON jazzhands.layer2_network;
DROP TRIGGER IF EXISTS trigger_audit_layer2_network ON jazzhands.layer2_network;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'layer2_network');
---- BEGIN audit.layer2_network TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'layer2_network', 'layer2_network');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'layer2_network');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."layer2_network_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'layer2_network');
---- DONE audit.layer2_network TEARDOWN


ALTER TABLE layer2_network RENAME TO layer2_network_v64;
ALTER TABLE audit.layer2_network RENAME TO layer2_network_v64;

CREATE TABLE layer2_network
(
	layer2_network_id	integer NOT NULL,
	encapsulation_name	varchar(32)  NULL,
	encapsulation_domain	varchar(50)  NULL,
	encapsulation_type	varchar(50)  NULL,
	encapsulation_tag	integer  NULL,
	description	varchar(255)  NULL,
	encapsulation_range_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'layer2_network', false);
ALTER TABLE layer2_network
	ALTER layer2_network_id
	SET DEFAULT nextval('layer2_network_layer2_network_id_seq'::regclass);
INSERT INTO layer2_network (
	layer2_network_id,
	encapsulation_name,
	encapsulation_domain,
	encapsulation_type,
	encapsulation_tag,
	description,
	encapsulation_range_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	layer2_network_id,
	encapsulation_name,
	encapsulation_domain,
	encapsulation_type,
	encapsulation_tag,
	description,
	encapsulation_range_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM layer2_network_v64;

INSERT INTO audit.layer2_network (
	layer2_network_id,
	encapsulation_name,
	encapsulation_domain,
	encapsulation_type,
	encapsulation_tag,
	description,
	encapsulation_range_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	layer2_network_id,
	encapsulation_name,
	encapsulation_domain,
	encapsulation_type,
	encapsulation_tag,
	description,
	encapsulation_range_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.layer2_network_v64;

ALTER TABLE layer2_network
	ALTER layer2_network_id
	SET DEFAULT nextval('layer2_network_layer2_network_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE layer2_network ADD CONSTRAINT ak_l2_net_l2net_encap_typ UNIQUE (layer2_network_id, encapsulation_type);
ALTER TABLE layer2_network ADD CONSTRAINT ak_l2net_encap_name UNIQUE (encapsulation_domain, encapsulation_type, encapsulation_name);
ALTER TABLE layer2_network ADD CONSTRAINT ak_l2net_encap_tag UNIQUE (encapsulation_type, encapsulation_domain, encapsulation_tag);
ALTER TABLE layer2_network ADD CONSTRAINT pk_layer2_network PRIMARY KEY (layer2_network_id);

-- Table/Column Comments
COMMENT ON COLUMN layer2_network.encapsulation_range_id IS 'Administrative information about which range this is a part of';
-- INDEXES
CREATE INDEX xif_l2_net_encap_domain ON layer2_network USING btree (encapsulation_domain, encapsulation_type);
CREATE INDEX xif_l2_net_encap_range_id ON layer2_network USING btree (encapsulation_range_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK layer2_network and device_layer2_network
ALTER TABLE device_layer2_network
	ADD CONSTRAINT fk_device_l2_net_l2netid
	FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id);
-- consider FK layer2_network and layer2_connection_l2_network
ALTER TABLE layer2_connection_l2_network
	ADD CONSTRAINT fk_l2c_l2n_l2netid
	FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id);
-- consider FK layer2_network and layer2_connection_l2_network
ALTER TABLE layer2_connection_l2_network
	ADD CONSTRAINT fk_l2cl2n_l2net_id_encap_typ
	FOREIGN KEY (layer2_network_id, encapsulation_type) REFERENCES layer2_network(layer2_network_id, encapsulation_type);
-- consider FK layer2_network and l2_network_coll_l2_network
-- Skipping this FK since table does not exist yet
--ALTER TABLE l2_network_coll_l2_network
--	ADD CONSTRAINT fk_l2netcl2net_l2netid
--	FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id);

-- consider FK layer2_network and layer3_network
ALTER TABLE layer3_network
	ADD CONSTRAINT fk_l3net_l2net
	FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id);

-- FOREIGN KEYS TO
-- consider FK layer2_network and encapsulation_domain
ALTER TABLE layer2_network
	ADD CONSTRAINT fk_l2_net_encap_domain
	FOREIGN KEY (encapsulation_domain, encapsulation_type) REFERENCES encapsulation_domain(encapsulation_domain, encapsulation_type);
-- consider FK layer2_network and encapsulation_range
ALTER TABLE layer2_network
	ADD CONSTRAINT fk_l2_net_encap_range_id
	FOREIGN KEY (encapsulation_range_id) REFERENCES encapsulation_range(encapsulation_range_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'layer2_network');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'layer2_network');
ALTER SEQUENCE layer2_network_layer2_network_id_seq
	 OWNED BY layer2_network.layer2_network_id;
DROP TABLE IF EXISTS layer2_network_v64;
DROP TABLE IF EXISTS audit.layer2_network_v64;
-- DONE DEALING WITH TABLE layer2_network [3729840]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE layer3_network [3720840]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'layer3_network', 'layer3_network');

-- FOREIGN KEYS FROM
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_prop_l3netid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.layer3_network DROP CONSTRAINT IF EXISTS fk_l3_net_def_gate_nbid;
ALTER TABLE jazzhands.layer3_network DROP CONSTRAINT IF EXISTS fk_l3net_l2net;
ALTER TABLE jazzhands.layer3_network DROP CONSTRAINT IF EXISTS fk_l3net_rndv_pt_nblk_id;
ALTER TABLE jazzhands.layer3_network DROP CONSTRAINT IF EXISTS fk_layer3_network_netblock_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'layer3_network');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.layer3_network DROP CONSTRAINT IF EXISTS ak_layer3_network_netblock_id;
ALTER TABLE jazzhands.layer3_network DROP CONSTRAINT IF EXISTS pk_layer3_network;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_l3_net_def_gate_nbid";
DROP INDEX IF EXISTS "jazzhands"."xif_l3net_l2net";
DROP INDEX IF EXISTS "jazzhands"."xif_l3net_rndv_pt_nblk_id";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_layer3_network ON jazzhands.layer3_network;
DROP TRIGGER IF EXISTS trigger_audit_layer3_network ON jazzhands.layer3_network;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'layer3_network');
---- BEGIN audit.layer3_network TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'layer3_network', 'layer3_network');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'layer3_network');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."layer3_network_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'layer3_network');
---- DONE audit.layer3_network TEARDOWN


ALTER TABLE layer3_network RENAME TO layer3_network_v64;
ALTER TABLE audit.layer3_network RENAME TO layer3_network_v64;

CREATE TABLE layer3_network
(
	layer3_network_id	integer NOT NULL,
	netblock_id	integer  NULL,
	layer2_network_id	integer  NULL,
	default_gateway_netblock_id	integer  NULL,
	rendezvous_netblock_id	integer  NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'layer3_network', false);
ALTER TABLE layer3_network
	ALTER layer3_network_id
	SET DEFAULT nextval('layer3_network_layer3_network_id_seq'::regclass);
INSERT INTO layer3_network (
	layer3_network_id,
	netblock_id,
	layer2_network_id,
	default_gateway_netblock_id,
	rendezvous_netblock_id,		-- new column (rendezvous_netblock_id)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	layer3_network_id,
	netblock_id,
	layer2_network_id,
	default_gateway_netblock_id,
	NULL,		-- new column (rendezvous_netblock_id)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM layer3_network_v64;

INSERT INTO audit.layer3_network (
	layer3_network_id,
	netblock_id,
	layer2_network_id,
	default_gateway_netblock_id,
	rendezvous_netblock_id,		-- new column (rendezvous_netblock_id)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	layer3_network_id,
	netblock_id,
	layer2_network_id,
	default_gateway_netblock_id,
	NULL,		-- new column (rendezvous_netblock_id)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.layer3_network_v64;

ALTER TABLE layer3_network
	ALTER layer3_network_id
	SET DEFAULT nextval('layer3_network_layer3_network_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE layer3_network ADD CONSTRAINT ak_layer3_network_netblock_id UNIQUE (netblock_id);
ALTER TABLE layer3_network ADD CONSTRAINT pk_layer3_network PRIMARY KEY (layer3_network_id);

-- Table/Column Comments
COMMENT ON COLUMN layer3_network.rendezvous_netblock_id IS 'Multicast Rendevous Point Address';
-- INDEXES
CREATE INDEX xif_l3_net_def_gate_nbid ON layer3_network USING btree (default_gateway_netblock_id);
CREATE INDEX xif_l3net_l2net ON layer3_network USING btree (layer2_network_id);
CREATE INDEX xif_l3net_rndv_pt_nblk_id ON layer3_network USING btree (rendezvous_netblock_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK layer3_network and l3_network_coll_l3_network
-- Skipping this FK since table does not exist yet
--ALTER TABLE l3_network_coll_l3_network
--	ADD CONSTRAINT fk_l3netcol_l3_net_l3netid
--	FOREIGN KEY (layer3_network_id) REFERENCES layer3_network(layer3_network_id);


-- FOREIGN KEYS TO
-- consider FK layer3_network and netblock
ALTER TABLE layer3_network
	ADD CONSTRAINT fk_l3_net_def_gate_nbid
	FOREIGN KEY (default_gateway_netblock_id) REFERENCES netblock(netblock_id);
-- consider FK layer3_network and layer2_network
ALTER TABLE layer3_network
	ADD CONSTRAINT fk_l3net_l2net
	FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id);
-- consider FK layer3_network and netblock
ALTER TABLE layer3_network
	ADD CONSTRAINT fk_l3net_rndv_pt_nblk_id
	FOREIGN KEY (rendezvous_netblock_id) REFERENCES netblock(netblock_id);
-- consider FK layer3_network and netblock
ALTER TABLE layer3_network
	ADD CONSTRAINT fk_layer3_network_netblock_id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'layer3_network');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'layer3_network');
ALTER SEQUENCE layer3_network_layer3_network_id_seq
	 OWNED BY layer3_network.layer3_network_id;
DROP TABLE IF EXISTS layer3_network_v64;
DROP TABLE IF EXISTS audit.layer3_network_v64;
-- DONE DEALING WITH TABLE layer3_network [3729883]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE company_collection
CREATE TABLE company_collection
(
	company_collection_id	integer NOT NULL,
	company_collection_name	varchar(255) NOT NULL,
	company_collection_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'company_collection', true);
ALTER TABLE company_collection
	ALTER company_collection_id
	SET DEFAULT nextval('company_collection_company_collection_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE company_collection ADD CONSTRAINT ak_company_collection_namtyp UNIQUE (company_collection_name, company_collection_type);
ALTER TABLE company_collection ADD CONSTRAINT pk_company_collection PRIMARY KEY (company_collection_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xifcomp_coll_com_coll_type ON company_collection USING btree (company_collection_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK company_collection and company_collection_hier
-- Skipping this FK since table does not exist yet
--ALTER TABLE company_collection_hier
--	ADD CONSTRAINT fk_comp_coll_comp_coll_id
--	FOREIGN KEY (company_collection_id) REFERENCES company_collection(company_collection_id);

-- consider FK company_collection and company_collection_hier
-- Skipping this FK since table does not exist yet
--ALTER TABLE company_collection_hier
--	ADD CONSTRAINT fk_comp_coll_comp_coll_kid_id
--	FOREIGN KEY (child_company_collection_id) REFERENCES company_collection(company_collection_id);

-- consider FK company_collection and company_collection_company
-- Skipping this FK since table does not exist yet
--ALTER TABLE company_collection_company
--	ADD CONSTRAINT fk_company_coll_company_coll_i
--	FOREIGN KEY (company_collection_id) REFERENCES company_collection(company_collection_id);

-- consider FK company_collection and property
-- Skipping this FK since column does not exist yet
--ALTER TABLE property
--	ADD CONSTRAINT fk_prop_compcoll_id
--	FOREIGN KEY (company_collection_id) REFERENCES company_collection(company_collection_id);


-- FOREIGN KEYS TO
-- consider FK company_collection and val_company_collection_type
-- Skipping this FK since table does not exist yet
--ALTER TABLE company_collection
--	ADD CONSTRAINT fk_comp_coll_com_coll_type
--	FOREIGN KEY (company_collection_type) REFERENCES val_company_collection_type(company_collection_type);


-- TRIGGERS
-- consider NEW oid 3738441
CREATE OR REPLACE FUNCTION jazzhands.validate_company_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.company_collection_type != NEW.company_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.company_collection_type = OLD.company_collection_type
		AND	p.company_collection_id = NEW.company_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'company_collection % of type % is used by % restricted properties.',
				NEW.company_collection_id, NEW.company_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	
END;
$function$
;
CREATE TRIGGER trigger_validate_company_collection_type_change BEFORE UPDATE OF company_collection_type ON company_collection FOR EACH ROW EXECUTE PROCEDURE validate_company_collection_type_change();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'company_collection');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'company_collection');
ALTER SEQUENCE company_collection_company_collection_id_seq
	 OWNED BY company_collection.company_collection_id;
-- DONE DEALING WITH TABLE company_collection [3729227]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE company [3720285]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'company', 'company');

-- FOREIGN KEYS FROM
ALTER TABLE account_realm_company DROP CONSTRAINT IF EXISTS fk_acct_rlm_cmpy_cmpy_id;
ALTER TABLE circuit DROP CONSTRAINT IF EXISTS fk_circuit_aloc_companyid;
ALTER TABLE circuit DROP CONSTRAINT IF EXISTS fk_circuit_vend_companyid;
ALTER TABLE circuit DROP CONSTRAINT IF EXISTS fk_circuit_zloc_company_id;
ALTER TABLE company_type DROP CONSTRAINT IF EXISTS fk_company_type_company_id;
ALTER TABLE component_type DROP CONSTRAINT IF EXISTS fk_component_type_company_id;
ALTER TABLE contract DROP CONSTRAINT IF EXISTS fk_contract_company_id;
ALTER TABLE department DROP CONSTRAINT IF EXISTS fk_dept_company;
ALTER TABLE device_type DROP CONSTRAINT IF EXISTS fk_devtyp_company;
ALTER TABLE netblock DROP CONSTRAINT IF EXISTS fk_netblock_company;
ALTER TABLE operating_system DROP CONSTRAINT IF EXISTS fk_os_company;
ALTER TABLE person_company DROP CONSTRAINT IF EXISTS fk_person_company_company_id;
ALTER TABLE physical_address DROP CONSTRAINT IF EXISTS fk_physaddr_company_id;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_compid;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_pval_compid;
ALTER TABLE person_contact DROP CONSTRAINT IF EXISTS fk_prsn_contect_cr_cmpyid;
ALTER TABLE site DROP CONSTRAINT IF EXISTS fk_site_colo_company_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.company DROP CONSTRAINT IF EXISTS fk_company_parent_company_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'company');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.company DROP CONSTRAINT IF EXISTS pk_company;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_company_iscorpfamily";
DROP INDEX IF EXISTS "jazzhands"."xif1company";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.company DROP CONSTRAINT IF EXISTS ckc_cmpy_shrt_name_195335815;
ALTER TABLE jazzhands.company DROP CONSTRAINT IF EXISTS ckc_is_corporate_fami_company;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_company ON jazzhands.company;
DROP TRIGGER IF EXISTS trigger_audit_company ON jazzhands.company;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'company');
---- BEGIN audit.company TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'company', 'company');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'company');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."company_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'company');
---- DONE audit.company TEARDOWN


ALTER TABLE company RENAME TO company_v64;
ALTER TABLE audit.company RENAME TO company_v64;

CREATE TABLE company
(
	company_id	integer NOT NULL,
	company_name	varchar(255) NOT NULL,
	company_short_name	varchar(50)  NULL,
	parent_company_id	integer  NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'company', false);
ALTER TABLE company
	ALTER company_id
	SET DEFAULT nextval('company_company_id_seq'::regclass);
INSERT INTO company (
	company_id,
	company_name,
	company_short_name,
	parent_company_id,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	company_id,
	company_name,
	company_short_name,
	parent_company_id,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM company_v64;

INSERT INTO audit.company (
	company_id,
	company_name,
	company_short_name,
	parent_company_id,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	company_id,
	company_name,
	company_short_name,
	parent_company_id,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.company_v64;

ALTER TABLE company
	ALTER company_id
	SET DEFAULT nextval('company_company_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE company ADD CONSTRAINT pk_company PRIMARY KEY (company_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif1company ON company USING btree (parent_company_id);

-- CHECK CONSTRAINTS
ALTER TABLE company ADD CONSTRAINT ckc_cmpy_shrt_name_195335815
	CHECK (((company_short_name)::text = lower((company_short_name)::text)) AND ((company_short_name)::text !~~ '% %'::text));

-- FOREIGN KEYS FROM
-- consider FK company and account_realm_company
ALTER TABLE account_realm_company
	ADD CONSTRAINT fk_acct_rlm_cmpy_cmpy_id
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and circuit
ALTER TABLE circuit
	ADD CONSTRAINT fk_circuit_aloc_companyid
	FOREIGN KEY (aloc_lec_company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and circuit
ALTER TABLE circuit
	ADD CONSTRAINT fk_circuit_vend_companyid
	FOREIGN KEY (vendor_company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and circuit
ALTER TABLE circuit
	ADD CONSTRAINT fk_circuit_zloc_company_id
	FOREIGN KEY (zloc_lec_company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and company_collection_company
-- Skipping this FK since table does not exist yet
--ALTER TABLE company_collection_company
--	ADD CONSTRAINT fk_company_coll_company_id
--	FOREIGN KEY (company_id) REFERENCES company(company_id);

-- consider FK company and company_type
ALTER TABLE company_type
	ADD CONSTRAINT fk_company_type_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and component_type
ALTER TABLE component_type
	ADD CONSTRAINT fk_component_type_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id);
-- consider FK company and contract
ALTER TABLE contract
	ADD CONSTRAINT fk_contract_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and department
ALTER TABLE department
	ADD CONSTRAINT fk_dept_company
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and device_type
ALTER TABLE device_type
	ADD CONSTRAINT fk_devtyp_company
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and netblock
ALTER TABLE netblock
	ADD CONSTRAINT fk_netblock_company
	FOREIGN KEY (nic_company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and operating_system
ALTER TABLE operating_system
	ADD CONSTRAINT fk_os_company
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and person_company
ALTER TABLE person_company
	ADD CONSTRAINT fk_person_company_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and physical_address
ALTER TABLE physical_address
	ADD CONSTRAINT fk_physaddr_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_compid
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_compid
	FOREIGN KEY (property_value_company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and person_contact
ALTER TABLE person_contact
	ADD CONSTRAINT fk_prsn_contect_cr_cmpyid
	FOREIGN KEY (person_contact_cr_company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK company and site
ALTER TABLE site
	ADD CONSTRAINT fk_site_colo_company_id
	FOREIGN KEY (colo_company_id) REFERENCES company(company_id) DEFERRABLE;

-- FOREIGN KEYS TO
-- consider FK company and company
ALTER TABLE company
	ADD CONSTRAINT fk_company_parent_company_id
	FOREIGN KEY (parent_company_id) REFERENCES company(company_id) DEFERRABLE;

-- TRIGGERS
-- consider NEW oid 3738463
CREATE OR REPLACE FUNCTION jazzhands.delete_per_company_company_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	dcid			company_collection.company_collection_id%TYPE;
BEGIN
	SELECT	company_collection_id
	  FROM  company_collection
	  INTO	dcid
	 WHERE	company_collection_type = 'per-company'
	   AND	company_collection_id in
		(select company_collection_id
		 from company_collection_company
		where company_id = OLD.company_id
		)
	ORDER BY company_collection_id
	LIMIT 1;

	IF dcid IS NOT NULL THEN
		DELETE FROM company_collection_company
		WHERE company_collection_id = dcid;

		DELETE from company_collection
		WHERE company_collection_id = dcid;
	END IF;

	RETURN OLD;
END;
$function$
;
CREATE TRIGGER trigger_delete_per_company_company_collection BEFORE DELETE ON company FOR EACH ROW EXECUTE PROCEDURE delete_per_company_company_collection();

-- XXX - may need to include trigger function
-- consider NEW oid 3738465
CREATE OR REPLACE FUNCTION jazzhands.update_per_company_company_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	dcid		company_collection.company_collection_id%TYPE;
	newname		company_collection.company_collection_name%TYPE;
BEGIN
	IF NEW.company_name IS NOT NULL THEN
		newname = NEW.company_name || '_' || NEW.company_id;
	ELSE
		newname = 'per_d_dc_contrived_' || NEW.company_id;
	END IF;

	IF TG_OP = 'INSERT' THEN
		insert into company_collection
			(company_collection_name, company_collection_type)
		values
			(newname, 'per-company')
		RETURNING company_collection_id INTO dcid;
		insert into company_collection_company
			(company_collection_id, company_id)
		VALUES
			(dcid, NEW.company_id);
	ELSIF TG_OP = 'UPDATE'  THEN
		UPDATE	company_collection
		   SET	company_collection_name = newname
		 WHERE	company_collection_name != newname
		   AND	company_collection_type = 'per-company'
		   AND	company_collection_id in (
			SELECT	company_collection_id
			  FROM	company_collection_company
			 WHERE	company_id = NEW.company_id
			);
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_update_per_company_company_collection AFTER INSERT OR UPDATE ON company FOR EACH ROW EXECUTE PROCEDURE update_per_company_company_collection();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'company');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'company');
ALTER SEQUENCE company_company_id_seq
	 OWNED BY company.company_id;
DROP TABLE IF EXISTS company_v64;
DROP TABLE IF EXISTS audit.company_v64;
-- DONE DEALING WITH TABLE company [3729214]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_app_key [3721805]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_app_key', 'val_app_key');

-- FOREIGN KEYS FROM
ALTER TABLE appaal_instance_property DROP CONSTRAINT IF EXISTS fk_appaalinstprop_ref_vappkey;
ALTER TABLE val_app_key_values DROP CONSTRAINT IF EXISTS fk_vappkeyval_ref_vappkey;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_app_key');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_app_key DROP CONSTRAINT IF EXISTS pk_val_app_key;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_app_key ON jazzhands.val_app_key;
DROP TRIGGER IF EXISTS trigger_audit_val_app_key ON jazzhands.val_app_key;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'val_app_key');
---- BEGIN audit.val_app_key TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_app_key', 'val_app_key');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_app_key');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_app_key_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'val_app_key');
---- DONE audit.val_app_key TEARDOWN


ALTER TABLE val_app_key RENAME TO val_app_key_v64;
ALTER TABLE audit.val_app_key RENAME TO val_app_key_v64;

CREATE TABLE val_app_key
(
	appaal_group_name	varchar(50) NOT NULL,
	app_key	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_app_key', false);
INSERT INTO val_app_key (
	appaal_group_name,		-- new column (appaal_group_name)
	app_key,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	'database',		-- new column (appaal_group_name)
	app_key,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_app_key_v64;

INSERT INTO audit.val_app_key (
	appaal_group_name,		-- new column (appaal_group_name)
	app_key,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	'database',		-- new column (appaal_group_name)
	app_key,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_app_key_v64;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_app_key ADD CONSTRAINT pk_val_app_key PRIMARY KEY (appaal_group_name, app_key);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif1val_app_key ON val_app_key USING btree (appaal_group_name);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_app_key and appaal_instance_property
-- Skipping this FK since column does not exist yet
--ALTER TABLE appaal_instance_property
--	ADD CONSTRAINT fk_appaalinstprop_ref_vappkey
--	FOREIGN KEY (appaal_group_name, app_key) REFERENCES val_app_key(appaal_group_name, app_key);

-- consider FK val_app_key and val_app_key_values
-- Skipping this FK since column does not exist yet
--ALTER TABLE val_app_key_values
--	ADD CONSTRAINT fk_vappkeyval_ref_vappkey
--	FOREIGN KEY (appaal_group_name, app_key) REFERENCES val_app_key(appaal_group_name, app_key);


-- FOREIGN KEYS TO
-- consider FK val_app_key and val_appaal_group_name
-- Skipping this FK since table does not exist yet
--ALTER TABLE val_app_key
--	ADD CONSTRAINT fk_val_app_key_group_name
--	FOREIGN KEY (appaal_group_name) REFERENCES val_appaal_group_name(appaal_group_name);


-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_app_key');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_app_key');
DROP TABLE IF EXISTS val_app_key_v64;
DROP TABLE IF EXISTS audit.val_app_key_v64;
-- DONE DEALING WITH TABLE val_app_key [3730894]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_app_key_values [3721813]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_app_key_values', 'val_app_key_values');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.val_app_key_values DROP CONSTRAINT IF EXISTS fk_vappkeyval_ref_vappkey;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_app_key_values');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_app_key_values DROP CONSTRAINT IF EXISTS pk_val_app_key_values;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_app_key_values ON jazzhands.val_app_key_values;
DROP TRIGGER IF EXISTS trigger_audit_val_app_key_values ON jazzhands.val_app_key_values;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'val_app_key_values');
---- BEGIN audit.val_app_key_values TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_app_key_values', 'val_app_key_values');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_app_key_values');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_app_key_values_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'val_app_key_values');
---- DONE audit.val_app_key_values TEARDOWN


ALTER TABLE val_app_key_values RENAME TO val_app_key_values_v64;
ALTER TABLE audit.val_app_key_values RENAME TO val_app_key_values_v64;

CREATE TABLE val_app_key_values
(
	appaal_group_name	varchar(50) NOT NULL,
	app_key	varchar(50) NOT NULL,
	app_value	varchar(4000) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_app_key_values', false);
INSERT INTO val_app_key_values (
	appaal_group_name,		-- new column (appaal_group_name)
	app_key,
	app_value,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	'database',		-- new column (appaal_group_name)
	app_key,
	app_value,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_app_key_values_v64;

INSERT INTO audit.val_app_key_values (
	appaal_group_name,		-- new column (appaal_group_name)
	app_key,
	app_value,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	'database',		-- new column (appaal_group_name)
	app_key,
	app_value,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_app_key_values_v64;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_app_key_values ADD CONSTRAINT pk_val_app_key_values PRIMARY KEY (appaal_group_name, app_key, app_value);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK val_app_key_values and val_app_key
ALTER TABLE val_app_key_values
	ADD CONSTRAINT fk_vappkeyval_ref_vappkey
	FOREIGN KEY (appaal_group_name, app_key) REFERENCES val_app_key(appaal_group_name, app_key);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_app_key_values');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_app_key_values');
DROP TABLE IF EXISTS val_app_key_values_v64;
DROP TABLE IF EXISTS audit.val_app_key_values_v64;
-- DONE DEALING WITH TABLE val_app_key_values [3730903]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_appaal_group_name
CREATE TABLE val_appaal_group_name
(
	appaal_group_name	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_appaal_group_name', true);
--
-- Copying initialization data
--
INSERT INTO val_appaal_group_name
	( appaal_group_name,description
) VALUES (
	 'database','keys related to database connections' );

INSERT INTO val_appaal_group_name
	( appaal_group_name,description
) VALUES (
	 'ldap','keys related to ldap connections' );

INSERT INTO val_appaal_group_name
	( appaal_group_name,description
) VALUES (
	 'web','keys related to http(s) connections' );


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_appaal_group_name ADD CONSTRAINT pk_val_appaal_group_name PRIMARY KEY (appaal_group_name);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_appaal_group_name and appaal_instance_property
-- Skipping this FK since column does not exist yet
--ALTER TABLE appaal_instance_property
--	ADD CONSTRAINT fk_allgrpprop_val_name
--	FOREIGN KEY (appaal_group_name) REFERENCES val_appaal_group_name(appaal_group_name);

-- consider FK val_appaal_group_name and val_app_key
ALTER TABLE val_app_key
	ADD CONSTRAINT fk_val_app_key_group_name
	FOREIGN KEY (appaal_group_name) REFERENCES val_appaal_group_name(appaal_group_name);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_appaal_group_name');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_appaal_group_name');
-- DONE DEALING WITH TABLE val_appaal_group_name [3730911]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_company_collection_type
CREATE TABLE val_company_collection_type
(
	company_collection_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	is_infrastructure_type	character(1) NOT NULL,
	max_num_members	integer  NULL,
	max_num_collections	integer  NULL,
	can_have_hierarchy	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_company_collection_type', true);
--
-- Copying initialization data
--
INSERT INTO val_company_collection_type
	( company_collection_type,description,is_infrastructure_type,max_num_members,max_num_collections,can_have_hierarchy
) VALUES (
	 'per-company',NULL,'N','1',NULL,'N' );

ALTER TABLE val_company_collection_type
	ALTER is_infrastructure_type
	SET DEFAULT 'N'::bpchar;
ALTER TABLE val_company_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_company_collection_type ADD CONSTRAINT pk_company_collection_type PRIMARY KEY (company_collection_type);

-- Table/Column Comments
COMMENT ON COLUMN val_company_collection_type.max_num_members IS 'Maximum INTEGER of members in a given collection of this type
';
COMMENT ON COLUMN val_company_collection_type.max_num_collections IS 'Maximum INTEGER of collections a given member can be a part of of this type.
';
COMMENT ON COLUMN val_company_collection_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE val_company_collection_type ADD CONSTRAINT check_yes_no_1614108214
	CHECK (is_infrastructure_type = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE val_company_collection_type ADD CONSTRAINT check_yes_no_845966153
	CHECK (can_have_hierarchy = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK val_company_collection_type and company_collection
ALTER TABLE company_collection
	ADD CONSTRAINT fk_comp_coll_com_coll_type
	FOREIGN KEY (company_collection_type) REFERENCES val_company_collection_type(company_collection_type);
-- consider FK val_company_collection_type and val_property
-- Skipping this FK since column does not exist yet
--ALTER TABLE val_property
--	ADD CONSTRAINT fk_val_prop_comp_coll_type
--	FOREIGN KEY (company_collection_type) REFERENCES val_company_collection_type(company_collection_type);


-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_company_collection_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_company_collection_type');
-- DONE DEALING WITH TABLE val_company_collection_type [3730999]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_company_type [3721901]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_company_type', 'val_company_type');

-- FOREIGN KEYS FROM
ALTER TABLE company_type DROP CONSTRAINT IF EXISTS fk_company_type_val;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_company_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_company_type DROP CONSTRAINT IF EXISTS pk_val_company_type;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_company_type ON jazzhands.val_company_type;
DROP TRIGGER IF EXISTS trigger_audit_val_company_type ON jazzhands.val_company_type;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'val_company_type');
---- BEGIN audit.val_company_type TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_company_type', 'val_company_type');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_company_type');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_company_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'val_company_type');
---- DONE audit.val_company_type TEARDOWN


ALTER TABLE val_company_type RENAME TO val_company_type_v64;
ALTER TABLE audit.val_company_type RENAME TO val_company_type_v64;

CREATE TABLE val_company_type
(
	company_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	company_type_purpose	varchar(50) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_company_type', false);
ALTER TABLE val_company_type
	ALTER company_type_purpose
	SET DEFAULT 'default'::character varying;
INSERT INTO val_company_type (
	company_type,
	description,
	company_type_purpose,		-- new column (company_type_purpose)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	company_type,
	description,
	'default'::character varying,		-- new column (company_type_purpose)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_company_type_v64;

INSERT INTO audit.val_company_type (
	company_type,
	description,
	company_type_purpose,		-- new column (company_type_purpose)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	company_type,
	description,
	NULL,		-- new column (company_type_purpose)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_company_type_v64;

ALTER TABLE val_company_type
	ALTER company_type_purpose
	SET DEFAULT 'default'::character varying;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_company_type ADD CONSTRAINT pk_val_company_type PRIMARY KEY (company_type);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_v_comptyp_comptyppurp ON val_company_type USING btree (company_type_purpose);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_company_type and company_type
ALTER TABLE company_type
	ADD CONSTRAINT fk_company_type_val
	FOREIGN KEY (company_type) REFERENCES val_company_type(company_type);

-- FOREIGN KEYS TO
-- consider FK val_company_type and val_company_type_purpose
-- Skipping this FK since table does not exist yet
--ALTER TABLE val_company_type
--	ADD CONSTRAINT fk_v_comptyp_comptyppurp
--	FOREIGN KEY (company_type_purpose) REFERENCES val_company_type_purpose(company_type_purpose);


-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_company_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_company_type');
DROP TABLE IF EXISTS val_company_type_v64;
DROP TABLE IF EXISTS audit.val_company_type_v64;
-- DONE DEALING WITH TABLE val_company_type [3731011]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_company_type_purpose
CREATE TABLE val_company_type_purpose
(
	company_type_purpose	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_company_type_purpose', true);
--
-- Copying initialization data
--
INSERT INTO val_company_type_purpose
	( company_type_purpose,description
) VALUES (
	 'default',NULL );


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_company_type_purpose ADD CONSTRAINT pk_val_company_type_purpose PRIMARY KEY (company_type_purpose);

-- Table/Column Comments
COMMENT ON TABLE val_company_type_purpose IS 'Mechanism to group company types together, mostly for display or more complicated rules';
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_company_type_purpose and val_company_type
ALTER TABLE val_company_type
	ADD CONSTRAINT fk_v_comptyp_comptyppurp
	FOREIGN KEY (company_type_purpose) REFERENCES val_company_type_purpose(company_type_purpose);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_company_type_purpose');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_company_type_purpose');
-- DONE DEALING WITH TABLE val_company_type_purpose [3731021]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_dns_domain_collection_type
CREATE TABLE val_dns_domain_collection_type
(
	dns_domain_collection_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	max_num_members	integer  NULL,
	max_num_collections	integer  NULL,
	can_have_hierarchy	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_dns_domain_collection_type', true);
--
-- Copying initialization data
--
ALTER TABLE val_dns_domain_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_dns_domain_collection_type ADD CONSTRAINT pk_val_dns_domain_collection_t PRIMARY KEY (dns_domain_collection_type);

-- Table/Column Comments
COMMENT ON COLUMN val_dns_domain_collection_type.max_num_members IS 'Maximum INTEGER of members in a given collection of this type';
COMMENT ON COLUMN val_dns_domain_collection_type.max_num_collections IS 'Maximum INTEGER of collections a given member can be a part of of this type.';
COMMENT ON COLUMN val_dns_domain_collection_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE val_dns_domain_collection_type ADD CONSTRAINT check_yes_no_dnsdom_coll_canhi
	CHECK (can_have_hierarchy = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK val_dns_domain_collection_type and dns_domain_collection
-- Skipping this FK since table does not exist yet
--ALTER TABLE dns_domain_collection
--	ADD CONSTRAINT fk_dns_dom_coll_typ_val
--	FOREIGN KEY (dns_domain_collection_type) REFERENCES val_dns_domain_collection_type(dns_domain_collection_type);

-- consider FK val_dns_domain_collection_type and val_property
-- Skipping this FK since column does not exist yet
--ALTER TABLE val_property
--	ADD CONSTRAINT fk_val_property_dnsdomcolltype
--	FOREIGN KEY (dns_domain_collection_type) REFERENCES val_dns_domain_collection_type(dns_domain_collection_type);


-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_dns_domain_collection_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_dns_domain_collection_type');
-- DONE DEALING WITH TABLE val_dns_domain_collection_type [3731150]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_layer2_network_coll_type
CREATE TABLE val_layer2_network_coll_type
(
	layer2_network_collection_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	max_num_members	integer  NULL,
	max_num_collections	integer  NULL,
	can_have_hierarchy	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_layer2_network_coll_type', true);
--
-- Copying initialization data
--
ALTER TABLE val_layer2_network_coll_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_layer2_network_coll_type ADD CONSTRAINT pk_val_layer2_network_coll_typ PRIMARY KEY (layer2_network_collection_type);

-- Table/Column Comments
COMMENT ON COLUMN val_layer2_network_coll_type.max_num_members IS 'Maximum INTEGER of members in a given collection of this type
';
COMMENT ON COLUMN val_layer2_network_coll_type.max_num_collections IS 'Maximum INTEGER of collections a given member can be a part of of this type.
';
COMMENT ON COLUMN val_layer2_network_coll_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE val_layer2_network_coll_type ADD CONSTRAINT check_yes_no_2053022263
	CHECK (can_have_hierarchy = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK val_layer2_network_coll_type and layer2_network_collection
-- Skipping this FK since table does not exist yet
--ALTER TABLE layer2_network_collection
--	ADD CONSTRAINT fk_l2netcoll_type
--	FOREIGN KEY (layer2_network_collection_type) REFERENCES val_layer2_network_coll_type(layer2_network_collection_type);

-- consider FK val_layer2_network_coll_type and val_property
-- Skipping this FK since column does not exist yet
--ALTER TABLE val_property
--	ADD CONSTRAINT fk_val_prop_l2netype
--	FOREIGN KEY (layer2_network_collection_type) REFERENCES val_layer2_network_coll_type(layer2_network_collection_type);


-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_layer2_network_coll_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_layer2_network_coll_type');
-- DONE DEALING WITH TABLE val_layer2_network_coll_type [3731258]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_layer3_network_coll_type
CREATE TABLE val_layer3_network_coll_type
(
	layer3_network_collection_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	max_num_members	integer  NULL,
	max_num_collections	integer  NULL,
	can_have_hierarchy	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_layer3_network_coll_type', true);
--
-- Copying initialization data
--
ALTER TABLE val_layer3_network_coll_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_layer3_network_coll_type ADD CONSTRAINT pk_val_layer3_network_coll_typ PRIMARY KEY (layer3_network_collection_type);

-- Table/Column Comments
COMMENT ON COLUMN val_layer3_network_coll_type.max_num_members IS 'Maximum INTEGER of members in a given collection of this type
';
COMMENT ON COLUMN val_layer3_network_coll_type.max_num_collections IS 'Maximum INTEGER of collections a given member can be a part of of this type.
';
COMMENT ON COLUMN val_layer3_network_coll_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE val_layer3_network_coll_type ADD CONSTRAINT check_yes_no_l3nc_chh
	CHECK (can_have_hierarchy = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK val_layer3_network_coll_type and layer3_network_collection
-- Skipping this FK since table does not exist yet
--ALTER TABLE layer3_network_collection
--	ADD CONSTRAINT fk_l3_netcol_netcol_type
--	FOREIGN KEY (layer3_network_collection_type) REFERENCES val_layer3_network_coll_type(layer3_network_collection_type);

-- consider FK val_layer3_network_coll_type and val_property
-- Skipping this FK since column does not exist yet
--ALTER TABLE val_property
--	ADD CONSTRAINT fk_val_prop_l3netwok_type
--	FOREIGN KEY (layer3_network_collection_type) REFERENCES val_layer3_network_coll_type(layer3_network_collection_type);


-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_layer3_network_coll_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_layer3_network_coll_type');
-- DONE DEALING WITH TABLE val_layer3_network_coll_type [3731268]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_logical_volume_type
CREATE TABLE val_logical_volume_type
(
	logical_volume_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_logical_volume_type', true);
--
-- Copying initialization data
--
INSERT INTO val_logical_volume_type
	( logical_volume_type,description
) VALUES (
	 'legacy','data that predates existance of this table' );


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_logical_volume_type ADD CONSTRAINT pk_logical_volume_type PRIMARY KEY (logical_volume_type);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_logical_volume_type and logical_volume
-- Skipping this FK since column does not exist yet
--ALTER TABLE logical_volume
--	ADD CONSTRAINT fk_log_volume_log_vol_type
--	FOREIGN KEY (logical_volume_type) REFERENCES val_logical_volume_type(logical_volume_type);

-- consider FK val_logical_volume_type and logical_volume_property
-- Skipping this FK since column does not exist yet
--ALTER TABLE logical_volume_property
--	ADD CONSTRAINT fk_lvprop_type
--	FOREIGN KEY (logical_volume_type) REFERENCES val_logical_volume_type(logical_volume_type);


-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_logical_volume_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_logical_volume_type');
-- DONE DEALING WITH TABLE val_logical_volume_type [3731303]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_netblock_collection_type [3722153]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_netblock_collection_type', 'val_netblock_collection_type');

-- FOREIGN KEYS FROM
ALTER TABLE netblock_collection DROP CONSTRAINT IF EXISTS fk_nblk_coll_v_nblk_c_typ;
ALTER TABLE val_property DROP CONSTRAINT IF EXISTS fk_val_prop_nblk_coll_type;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_netblock_collection_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_netblock_collection_type DROP CONSTRAINT IF EXISTS pk_val_netblock_collection_typ;
-- INDEXES
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_netblock_collection_type DROP CONSTRAINT IF EXISTS check_yes_no_nct_chh;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_netblock_collection_type ON jazzhands.val_netblock_collection_type;
DROP TRIGGER IF EXISTS trigger_audit_val_netblock_collection_type ON jazzhands.val_netblock_collection_type;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'val_netblock_collection_type');
---- BEGIN audit.val_netblock_collection_type TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_netblock_collection_type', 'val_netblock_collection_type');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_netblock_collection_type');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_netblock_collection_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'val_netblock_collection_type');
---- DONE audit.val_netblock_collection_type TEARDOWN


ALTER TABLE val_netblock_collection_type RENAME TO val_netblock_collection_type_v64;
ALTER TABLE audit.val_netblock_collection_type RENAME TO val_netblock_collection_type_v64;

CREATE TABLE val_netblock_collection_type
(
	netblock_collection_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	max_num_members	integer  NULL,
	max_num_collections	integer  NULL,
	can_have_hierarchy	character(1) NOT NULL,
	netblock_single_addr_restrict	varchar(3) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_netblock_collection_type', false);
ALTER TABLE val_netblock_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE val_netblock_collection_type
	ALTER netblock_single_addr_restrict
	SET DEFAULT 'ANY'::character varying;
INSERT INTO val_netblock_collection_type (
	netblock_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	netblock_single_addr_restrict,		-- new column (netblock_single_addr_restrict)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	netblock_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	'ANY'::character varying,		-- new column (netblock_single_addr_restrict)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_netblock_collection_type_v64;

INSERT INTO audit.val_netblock_collection_type (
	netblock_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	netblock_single_addr_restrict,		-- new column (netblock_single_addr_restrict)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	netblock_collection_type,
	description,
	max_num_members,
	max_num_collections,
	can_have_hierarchy,
	NULL,		-- new column (netblock_single_addr_restrict)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_netblock_collection_type_v64;

ALTER TABLE val_netblock_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE val_netblock_collection_type
	ALTER netblock_single_addr_restrict
	SET DEFAULT 'ANY'::character varying;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_netblock_collection_type ADD CONSTRAINT pk_val_netblock_collection_typ PRIMARY KEY (netblock_collection_type);

-- Table/Column Comments
COMMENT ON COLUMN val_netblock_collection_type.max_num_members IS 'Maximum INTEGER of members in a given collection of this type
';
COMMENT ON COLUMN val_netblock_collection_type.max_num_collections IS 'Maximum INTEGER of collections a given member can be a part of of this type.
';
COMMENT ON COLUMN val_netblock_collection_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE val_netblock_collection_type ADD CONSTRAINT check_any_yes_no_nc_singaddr_r
	CHECK ((netblock_single_addr_restrict)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying, 'ANY'::character varying])::text[]));
ALTER TABLE val_netblock_collection_type ADD CONSTRAINT check_yes_no_nct_chh
	CHECK (can_have_hierarchy = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK val_netblock_collection_type and netblock_collection
ALTER TABLE netblock_collection
	ADD CONSTRAINT fk_nblk_coll_v_nblk_c_typ
	FOREIGN KEY (netblock_collection_type) REFERENCES val_netblock_collection_type(netblock_collection_type);
-- consider FK val_netblock_collection_type and val_property
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_nblk_coll_type
	FOREIGN KEY (prop_val_nblk_coll_type_rstrct) REFERENCES val_netblock_collection_type(netblock_collection_type);
-- consider FK val_netblock_collection_type and val_property
-- Skipping this FK since column does not exist yet
--ALTER TABLE val_property
--	ADD CONSTRAINT fk_val_property_netblkcolltype
--	FOREIGN KEY (netblock_collection_type) REFERENCES val_netblock_collection_type(netblock_collection_type);


-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_netblock_collection_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_netblock_collection_type');
DROP TABLE IF EXISTS val_netblock_collection_type_v64;
DROP TABLE IF EXISTS audit.val_netblock_collection_type_v64;
-- DONE DEALING WITH TABLE val_netblock_collection_type [3731311]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_network_range_type [3722197]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_network_range_type', 'val_network_range_type');

-- FOREIGN KEYS FROM
ALTER TABLE network_range DROP CONSTRAINT IF EXISTS fk_netrng_netrng_typ;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_network_range_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_network_range_type DROP CONSTRAINT IF EXISTS pk_val_network_range_type;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_network_range_type ON jazzhands.val_network_range_type;
DROP TRIGGER IF EXISTS trigger_audit_val_network_range_type ON jazzhands.val_network_range_type;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'val_network_range_type');
---- BEGIN audit.val_network_range_type TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_network_range_type', 'val_network_range_type');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_network_range_type');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_network_range_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'val_network_range_type');
---- DONE audit.val_network_range_type TEARDOWN


ALTER TABLE val_network_range_type RENAME TO val_network_range_type_v64;
ALTER TABLE audit.val_network_range_type RENAME TO val_network_range_type_v64;

CREATE TABLE val_network_range_type
(
	network_range_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	dns_domain_required	character(10) NOT NULL,
	default_dns_prefix	varchar(50)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_network_range_type', false);
ALTER TABLE val_network_range_type
	ALTER dns_domain_required
	SET DEFAULT 'REQUIRED'::bpchar;
INSERT INTO val_network_range_type (
	network_range_type,
	description,
	dns_domain_required,		-- new column (dns_domain_required)
	default_dns_prefix,		-- new column (default_dns_prefix)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	network_range_type,
	description,
	'REQUIRED'::bpchar,		-- new column (dns_domain_required)
	NULL,		-- new column (default_dns_prefix)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_network_range_type_v64;

INSERT INTO audit.val_network_range_type (
	network_range_type,
	description,
	dns_domain_required,		-- new column (dns_domain_required)
	default_dns_prefix,		-- new column (default_dns_prefix)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	network_range_type,
	description,
	NULL,		-- new column (dns_domain_required)
	NULL,		-- new column (default_dns_prefix)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_network_range_type_v64;

ALTER TABLE val_network_range_type
	ALTER dns_domain_required
	SET DEFAULT 'REQUIRED'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_network_range_type ADD CONSTRAINT pk_val_network_range_type PRIMARY KEY (network_range_type);

-- Table/Column Comments
COMMENT ON COLUMN val_network_range_type.dns_domain_required IS 'indicates how dns_domain_id is required on network_range (thus a NOT NULL constraint)';
COMMENT ON COLUMN val_network_range_type.default_dns_prefix IS 'default dns prefix for ranges of this type, can be overridden in network_range.   Required if dns_domain_required is set.';
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE val_network_range_type ADD CONSTRAINT check_prp_prmt_nrngty_ddom
	CHECK (dns_domain_required = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK val_network_range_type and network_range
ALTER TABLE network_range
	ADD CONSTRAINT fk_netrng_netrng_typ
	FOREIGN KEY (network_range_type) REFERENCES val_network_range_type(network_range_type);

-- FOREIGN KEYS TO

-- TRIGGERS
-- consider NEW oid 3738593
CREATE OR REPLACE FUNCTION jazzhands.validate_val_network_range_type()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF NEW.dns_domain_required = 'REQUIRED' THEN
		PERFORM
		FROM	network_range
		WHERE	network_range_type = NEW.network_range_type
		AND		dns_domain_id IS NULL;

		IF FOUND THEN
			RAISE EXCEPTION 'dns_domain_id is not set on some ranges'
				USING ERRCODE = 'not_null_violation';
		END IF;
	ELSIF NEW.dns_domain_required = 'PROHIBITED' THEN
		PERFORM
		FROM	network_range
		WHERE	network_range_type = NEW.network_range_type
		AND		dns_domain_id IS NOT NULL;

		IF FOUND THEN
			RAISE EXCEPTION 'dns_domain_id is set on some ranges'
				USING ERRCODE = 'not_null_violation';
		END IF;
	END IF;

END; $function$
;
CREATE TRIGGER trigger_validate_val_network_range_type BEFORE UPDATE OF dns_domain_required ON val_network_range_type FOR EACH ROW EXECUTE PROCEDURE validate_val_network_range_type();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_network_range_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_network_range_type');
DROP TABLE IF EXISTS val_network_range_type_v64;
DROP TABLE IF EXISTS audit.val_network_range_type_v64;
-- DONE DEALING WITH TABLE val_network_range_type [3731357]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_person_company_attr_dtype
CREATE TABLE val_person_company_attr_dtype
(
	person_company_attr_data_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_person_company_attr_dtype', true);
--
-- Copying initialization data
--
INSERT INTO val_person_company_attr_dtype
	( person_company_attr_data_type,description
) VALUES (
	 'boolean',NULL );

INSERT INTO val_person_company_attr_dtype
	( person_company_attr_data_type,description
) VALUES (
	 'number',NULL );

INSERT INTO val_person_company_attr_dtype
	( person_company_attr_data_type,description
) VALUES (
	 'string',NULL );

INSERT INTO val_person_company_attr_dtype
	( person_company_attr_data_type,description
) VALUES (
	 'list',NULL );

INSERT INTO val_person_company_attr_dtype
	( person_company_attr_data_type,description
) VALUES (
	 'timestamp',NULL );

INSERT INTO val_person_company_attr_dtype
	( person_company_attr_data_type,description
) VALUES (
	 'person_id',NULL );


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_person_company_attr_dtype ADD CONSTRAINT pk_val_pers_comp_attr_dataty PRIMARY KEY (person_company_attr_data_type);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_person_company_attr_dtype and val_person_company_attr_name
-- Skipping this FK since table does not exist yet
--ALTER TABLE val_person_company_attr_name
--	ADD CONSTRAINT fk_prescompattr_name_datatyp
--	FOREIGN KEY (person_company_attr_data_type) REFERENCES val_person_company_attr_dtype(person_company_attr_data_type);


-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_person_company_attr_dtype');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_person_company_attr_dtype');
-- DONE DEALING WITH TABLE val_person_company_attr_dtype [3731415]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_person_company_attr_name
CREATE TABLE val_person_company_attr_name
(
	person_company_attr_name	integer NOT NULL,
	person_company_attr_data_type	varchar(50)  NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_person_company_attr_name', true);
--
-- Copying initialization data
--

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_person_company_attr_name ADD CONSTRAINT pk_val_person_company_attr_nam PRIMARY KEY (person_company_attr_name);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xifprescompattr_name_datatyp ON val_person_company_attr_name USING btree (person_company_attr_data_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_person_company_attr_name and val_person_company_attr_value
-- Skipping this FK since table does not exist yet
--ALTER TABLE val_person_company_attr_value
--	ADD CONSTRAINT fk_pers_comp_attr_val_name
--	FOREIGN KEY (person_company_attr_name) REFERENCES val_person_company_attr_name(person_company_attr_name);

-- consider FK val_person_company_attr_name and person_company_attr
-- Skipping this FK since table does not exist yet
--ALTER TABLE person_company_attr
--	ADD CONSTRAINT fk_person_comp_attr_val_name
--	FOREIGN KEY (person_company_attr_name) REFERENCES val_person_company_attr_name(person_company_attr_name);


-- FOREIGN KEYS TO
-- consider FK val_person_company_attr_name and val_person_company_attr_dtype
ALTER TABLE val_person_company_attr_name
	ADD CONSTRAINT fk_prescompattr_name_datatyp
	FOREIGN KEY (person_company_attr_data_type) REFERENCES val_person_company_attr_dtype(person_company_attr_data_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_person_company_attr_name');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_person_company_attr_name');
-- DONE DEALING WITH TABLE val_person_company_attr_name [3731423]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_person_company_attr_value
CREATE TABLE val_person_company_attr_value
(
	person_company_attr_name	integer NOT NULL,
	person_company_attr_value	integer NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_person_company_attr_value', true);
--
-- Copying initialization data
--

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_person_company_attr_value ADD CONSTRAINT pk_val_pers_company_attr_value PRIMARY KEY (person_company_attr_name, person_company_attr_value);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xifpers_comp_attr_val_name ON val_person_company_attr_value USING btree (person_company_attr_name);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK val_person_company_attr_value and val_person_company_attr_name
ALTER TABLE val_person_company_attr_value
	ADD CONSTRAINT fk_pers_comp_attr_val_name
	FOREIGN KEY (person_company_attr_name) REFERENCES val_person_company_attr_name(person_company_attr_name);

-- TRIGGERS
-- consider NEW oid 3738642
CREATE OR REPLACE FUNCTION jazzhands.validate_pers_comp_attr_value()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally			integer;
BEGIN
	PERFORM 1
	FROM	val_person_company_attr_value
	WHERE	(person_company_attr_name,person_company_attr_value)
			IN
			(OLD.person_company_attr_name,OLD.person_company_attr_value)
	;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'attribute_value must be valid'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;

END;
$function$
;
CREATE TRIGGER trigger_validate_pers_comp_attr_value BEFORE DELETE OR UPDATE OF person_company_attr_name, person_company_attr_value ON val_person_company_attr_value FOR EACH ROW EXECUTE PROCEDURE validate_pers_comp_attr_value();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_person_company_attr_value');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_person_company_attr_value');
-- DONE DEALING WITH TABLE val_person_company_attr_value [3731432]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_physical_address_type
CREATE TABLE val_physical_address_type
(
	physical_address_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_physical_address_type', true);
--
-- Copying initialization data
--
INSERT INTO val_physical_address_type
	( physical_address_type,description
) VALUES (
	 'location','physical location' );

INSERT INTO val_physical_address_type
	( physical_address_type,description
) VALUES (
	 'mailing','physical location' );

INSERT INTO val_physical_address_type
	( physical_address_type,description
) VALUES (
	 'legal','physical location' );


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_physical_address_type ADD CONSTRAINT pk_val_physical_address_type PRIMARY KEY (physical_address_type);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_physical_address_type and physical_address
-- Skipping this FK since column does not exist yet
--ALTER TABLE physical_address
--	ADD CONSTRAINT fk_physaddr_type_val
--	FOREIGN KEY (physical_address_type) REFERENCES val_physical_address_type(physical_address_type);


-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_physical_address_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_physical_address_type');
-- DONE DEALING WITH TABLE val_physical_address_type [3731502]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_property [3722339]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_property', 'val_property');

-- FOREIGN KEYS FROM
ALTER TABLE property_collection_property DROP CONSTRAINT IF EXISTS fk_prop_col_propnamtyp;
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_nmtyp;
ALTER TABLE val_property_value DROP CONSTRAINT IF EXISTS fk_valproval_namtyp;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_prop_val_devcol_typ_rstr_dc;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_prop_nblk_coll_type;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_propdttyp;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_proptyp;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_pv_actyp_rst;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_property');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS pk_val_property;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1val_property";
DROP INDEX IF EXISTS "jazzhands"."xif2val_property";
DROP INDEX IF EXISTS "jazzhands"."xif3val_property";
DROP INDEX IF EXISTS "jazzhands"."xif4val_property";
DROP INDEX IF EXISTS "jazzhands"."xif5val_property";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1279736247;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1279736503;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1804972034;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_2016888554;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_2139007167;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_271462566;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_354296970;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_606225804;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_cmp_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_ismulti;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_osid;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pacct_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pdevcol_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pdnsdomid;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_prodstate;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pucls_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_sitec;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_property ON jazzhands.val_property;
DROP TRIGGER IF EXISTS trigger_audit_val_property ON jazzhands.val_property;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'val_property');
---- BEGIN audit.val_property TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_property', 'val_property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_property');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_property_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'val_property');
---- DONE audit.val_property TEARDOWN


ALTER TABLE val_property RENAME TO val_property_v64;
ALTER TABLE audit.val_property RENAME TO val_property_v64;

CREATE TABLE val_property
(
	property_name	varchar(255) NOT NULL,
	property_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	account_collection_type	varchar(50)  NULL,
	company_collection_type	varchar(50)  NULL,
	device_collection_type	varchar(50)  NULL,
	dns_domain_collection_type	varchar(50)  NULL,
	layer2_network_collection_type	varchar(50)  NULL,
	layer3_network_collection_type	varchar(50)  NULL,
	netblock_collection_type	varchar(50)  NULL,
	property_collection_type	varchar(50)  NULL,
	service_env_collection_type	varchar(50)  NULL,
	is_multivalue	character(1) NOT NULL,
	prop_val_acct_coll_type_rstrct	varchar(50)  NULL,
	prop_val_dev_coll_type_rstrct	varchar(50)  NULL,
	prop_val_nblk_coll_type_rstrct	varchar(50)  NULL,
	property_data_type	varchar(50) NOT NULL,
	permit_account_collection_id	character(10) NOT NULL,
	permit_account_id	character(10) NOT NULL,
	permit_account_realm_id	character(10) NOT NULL,
	permit_company_id	character(10) NOT NULL,
	permit_company_collection_id	character(10) NOT NULL,
	permit_device_collection_id	character(10) NOT NULL,
	permit_dns_domain_id	character(10) NOT NULL,
	permit_dns_domain_coll_id	character(10) NOT NULL,
	permit_layer2_network_coll_id	character(10) NOT NULL,
	permit_layer3_network_coll_id	character(10) NOT NULL,
	permit_netblock_collection_id	character(10) NOT NULL,
	permit_operating_system_id	character(10) NOT NULL,
	permit_os_snapshot_id	character(10) NOT NULL,
	permit_person_id	character(10) NOT NULL,
	permit_property_collection_id	character(10) NOT NULL,
	permit_service_env_collection	character(10) NOT NULL,
	permit_site_code	character(10) NOT NULL,
	permit_property_rank	character(10) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_property', false);
ALTER TABLE val_property
	ALTER is_multivalue
	SET DEFAULT 'N'::bpchar;
ALTER TABLE val_property
	ALTER permit_account_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_account_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_account_realm_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_company_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_company_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_device_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_dns_domain_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_dns_domain_coll_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer2_network_coll_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer3_network_coll_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_netblock_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_operating_system_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_os_snapshot_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_person_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_property_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_service_env_collection
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_site_code
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_property_rank
	SET DEFAULT 'PROHIBITED'::bpchar;
INSERT INTO val_property (
	property_name,
	property_type,
	description,
	account_collection_type,		-- new column (account_collection_type)
	company_collection_type,		-- new column (company_collection_type)
	device_collection_type,		-- new column (device_collection_type)
	dns_domain_collection_type,		-- new column (dns_domain_collection_type)
	layer2_network_collection_type,		-- new column (layer2_network_collection_type)
	layer3_network_collection_type,		-- new column (layer3_network_collection_type)
	netblock_collection_type,		-- new column (netblock_collection_type)
	property_collection_type,		-- new column (property_collection_type)
	service_env_collection_type,		-- new column (service_env_collection_type)
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_dev_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_company_collection_id,		-- new column (permit_company_collection_id)
	permit_device_collection_id,
	permit_dns_domain_id,
	permit_dns_domain_coll_id,		-- new column (permit_dns_domain_coll_id)
	permit_layer2_network_coll_id,		-- new column (permit_layer2_network_coll_id)
	permit_layer3_network_coll_id,		-- new column (permit_layer3_network_coll_id)
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_os_snapshot_id,
	permit_person_id,
	permit_property_collection_id,
	permit_service_env_collection,
	permit_site_code,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	property_name,
	property_type,
	description,
	NULL,		-- new column (account_collection_type)
	NULL,		-- new column (company_collection_type)
	NULL,		-- new column (device_collection_type)
	NULL,		-- new column (dns_domain_collection_type)
	NULL,		-- new column (layer2_network_collection_type)
	NULL,		-- new column (layer3_network_collection_type)
	NULL,		-- new column (netblock_collection_type)
	NULL,		-- new column (property_collection_type)
	NULL,		-- new column (service_env_collection_type)
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_dev_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	'PROHIBITED'::bpchar,		-- new column (permit_company_collection_id)
	permit_device_collection_id,
	permit_dns_domain_id,
	'PROHIBITED'::bpchar,		-- new column (permit_dns_domain_coll_id)
	'PROHIBITED'::bpchar,		-- new column (permit_layer2_network_coll_id)
	'PROHIBITED'::bpchar,		-- new column (permit_layer3_network_coll_id)
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_os_snapshot_id,
	permit_person_id,
	permit_property_collection_id,
	permit_service_env_collection,
	permit_site_code,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_property_v64;

INSERT INTO audit.val_property (
	property_name,
	property_type,
	description,
	account_collection_type,		-- new column (account_collection_type)
	company_collection_type,		-- new column (company_collection_type)
	device_collection_type,		-- new column (device_collection_type)
	dns_domain_collection_type,		-- new column (dns_domain_collection_type)
	layer2_network_collection_type,		-- new column (layer2_network_collection_type)
	layer3_network_collection_type,		-- new column (layer3_network_collection_type)
	netblock_collection_type,		-- new column (netblock_collection_type)
	property_collection_type,		-- new column (property_collection_type)
	service_env_collection_type,		-- new column (service_env_collection_type)
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_dev_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_company_collection_id,		-- new column (permit_company_collection_id)
	permit_device_collection_id,
	permit_dns_domain_id,
	permit_dns_domain_coll_id,		-- new column (permit_dns_domain_coll_id)
	permit_layer2_network_coll_id,		-- new column (permit_layer2_network_coll_id)
	permit_layer3_network_coll_id,		-- new column (permit_layer3_network_coll_id)
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_os_snapshot_id,
	permit_person_id,
	permit_property_collection_id,
	permit_service_env_collection,
	permit_site_code,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	property_name,
	property_type,
	description,
	NULL,		-- new column (account_collection_type)
	NULL,		-- new column (company_collection_type)
	NULL,		-- new column (device_collection_type)
	NULL,		-- new column (dns_domain_collection_type)
	NULL,		-- new column (layer2_network_collection_type)
	NULL,		-- new column (layer3_network_collection_type)
	NULL,		-- new column (netblock_collection_type)
	NULL,		-- new column (property_collection_type)
	NULL,		-- new column (service_env_collection_type)
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_dev_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	NULL,		-- new column (permit_company_collection_id)
	permit_device_collection_id,
	permit_dns_domain_id,
	NULL,		-- new column (permit_dns_domain_coll_id)
	NULL,		-- new column (permit_layer2_network_coll_id)
	NULL,		-- new column (permit_layer3_network_coll_id)
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_os_snapshot_id,
	permit_person_id,
	permit_property_collection_id,
	permit_service_env_collection,
	permit_site_code,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_property_v64;

ALTER TABLE val_property
	ALTER is_multivalue
	SET DEFAULT 'N'::bpchar;
ALTER TABLE val_property
	ALTER permit_account_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_account_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_account_realm_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_company_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_company_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_device_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_dns_domain_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_dns_domain_coll_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer2_network_coll_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer3_network_coll_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_netblock_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_operating_system_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_os_snapshot_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_person_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_property_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_service_env_collection
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_site_code
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_property_rank
	SET DEFAULT 'PROHIBITED'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_property ADD CONSTRAINT pk_val_property PRIMARY KEY (property_name, property_type);

-- Table/Column Comments
COMMENT ON TABLE val_property IS 'valid values and attributes for (name,type) pairs in the property table.  This defines how triggers enforce aspects of the property table';
COMMENT ON COLUMN val_property.property_name IS 'property name for validation purposes';
COMMENT ON COLUMN val_property.property_type IS 'property type for validation purposes';
COMMENT ON COLUMN val_property.account_collection_type IS 'type restriction of the account_collection_id on LHS';
COMMENT ON COLUMN val_property.company_collection_type IS 'type restriction of company_collection_id on LHS';
COMMENT ON COLUMN val_property.device_collection_type IS 'type restriction of device_collection_id on LHS';
COMMENT ON COLUMN val_property.dns_domain_collection_type IS 'type restriction of dns_domain_collection_id restriction on LHS';
COMMENT ON COLUMN val_property.netblock_collection_type IS 'type restriction of netblock_collection_id on LHS';
COMMENT ON COLUMN val_property.property_collection_type IS 'type restriction of property_collection_id on LHS';
COMMENT ON COLUMN val_property.service_env_collection_type IS 'type restriction of service_enviornment_collection_id on LHS';
COMMENT ON COLUMN val_property.is_multivalue IS 'If N, acts like an alternate key on property.(lhs,property_name,property_type)';
COMMENT ON COLUMN val_property.prop_val_acct_coll_type_rstrct IS 'if property_value is account_collection_Id, this limits the account_collection_types that can be used in that column.';
COMMENT ON COLUMN val_property.prop_val_dev_coll_type_rstrct IS 'if property_value is devicet_collection_Id, this limits the devicet_collection_types that can be used in that column.';
COMMENT ON COLUMN val_property.prop_val_nblk_coll_type_rstrct IS 'if property_value isnetblockt_collection_Id, this limits the netblockt_collection_types that can be used in that column.';
COMMENT ON COLUMN val_property.property_data_type IS 'which, if any, of the property_table_* columns should be used for this value.   May turn more complex enforcement via trigger';
COMMENT ON COLUMN val_property.permit_account_collection_id IS 'defines permissibility/requirement of account_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_account_id IS 'defines permissibility/requirement of account_idon LHS of property';
COMMENT ON COLUMN val_property.permit_account_realm_id IS 'defines permissibility/requirement of account_realm_id on LHS of property';
COMMENT ON COLUMN val_property.permit_company_id IS 'defines permissibility/requirement of company_id on LHS of property.  *NOTE*  THIS COLUMN WILL BE REMOVED IN >0.65';
COMMENT ON COLUMN val_property.permit_company_collection_id IS 'defines permissibility/requirement of company_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_device_collection_id IS 'defines permissibility/requirement of device_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_dns_domain_id IS 'defines permissibility/requirement of dns_domain_id on LHS of property. *NOTE*  THIS COLUMN WILL BE REMOVED IN >0.65';
COMMENT ON COLUMN val_property.permit_dns_domain_coll_id IS 'defines permissibility/requirement of dns_domain_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_layer2_network_coll_id IS 'defines permissibility/requirement of layer2_network_id on LHS of property';
COMMENT ON COLUMN val_property.permit_layer3_network_coll_id IS 'defines permissibility/requirement of layer3_network_id on LHS of property';
COMMENT ON COLUMN val_property.permit_netblock_collection_id IS 'defines permissibility/requirement of netblock_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_operating_system_id IS 'defines permissibility/requirement of operating_system_id on LHS of property';
COMMENT ON COLUMN val_property.permit_os_snapshot_id IS 'defines permissibility/requirement of operating_system_snapshot_id on LHS of property';
COMMENT ON COLUMN val_property.permit_person_id IS 'defines permissibility/requirement of person_id on LHS of property';
COMMENT ON COLUMN val_property.permit_property_collection_id IS 'defines permissibility/requirement of property_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_service_env_collection IS 'defines permissibility/requirement of service_env_collection_id on LHS of property';
COMMENT ON COLUMN val_property.permit_site_code IS 'defines permissibility/requirement of site_code on LHS of property';
COMMENT ON COLUMN val_property.permit_property_rank IS 'defines permissibility of property_rank, and if it should be part of the "lhs" of the given property';
-- INDEXES
CREATE INDEX xif10val_property ON val_property USING btree (netblock_collection_type);
CREATE INDEX xif11val_property ON val_property USING btree (property_collection_type);
CREATE INDEX xif12val_property ON val_property USING btree (service_env_collection_type);
CREATE INDEX xif13val_property ON val_property USING btree (layer3_network_collection_type);
CREATE INDEX xif14val_property ON val_property USING btree (layer2_network_collection_type);
CREATE INDEX xif1val_property ON val_property USING btree (property_data_type);
CREATE INDEX xif2val_property ON val_property USING btree (property_type);
CREATE INDEX xif3val_property ON val_property USING btree (prop_val_acct_coll_type_rstrct);
CREATE INDEX xif4val_property ON val_property USING btree (prop_val_nblk_coll_type_rstrct);
CREATE INDEX xif5val_property ON val_property USING btree (prop_val_dev_coll_type_rstrct);
CREATE INDEX xif6val_property ON val_property USING btree (account_collection_type);
CREATE INDEX xif7val_property ON val_property USING btree (company_collection_type);
CREATE INDEX xif8val_property ON val_property USING btree (device_collection_type);
CREATE INDEX xif9val_property ON val_property USING btree (dns_domain_collection_type);

-- CHECK CONSTRAINTS
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_1494616001
	CHECK (permit_dns_domain_coll_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_1804972034
	CHECK (permit_os_snapshot_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_185689986
	CHECK (permit_layer2_network_coll_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_185755522
	CHECK (permit_layer3_network_coll_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_2016888554
	CHECK (permit_account_realm_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_2139007167
	CHECK (permit_property_rank = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_271462566
	CHECK (permit_property_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_354296970
	CHECK (permit_netblock_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_366948481
	CHECK (permit_company_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_606225804
	CHECK (permit_person_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_cmp_id
	CHECK (permit_company_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_ismulti
	CHECK (is_multivalue = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_osid
	CHECK (permit_operating_system_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pacct_id
	CHECK (permit_account_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pdevcol_id
	CHECK (permit_device_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pdnsdomid
	CHECK (permit_dns_domain_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_prodstate
	CHECK (permit_service_env_collection = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pucls_id
	CHECK (permit_account_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_sitec
	CHECK (permit_site_code = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK val_property and property_collection_property
ALTER TABLE property_collection_property
	ADD CONSTRAINT fk_prop_col_propnamtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);
-- consider FK val_property and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_nmtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);
-- consider FK val_property and val_property_value
ALTER TABLE val_property_value
	ADD CONSTRAINT fk_valproval_namtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);

-- FOREIGN KEYS TO
-- consider FK val_property and val_service_env_coll_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_prop_svcemvcoll_type
	FOREIGN KEY (service_env_collection_type) REFERENCES val_service_env_coll_type(service_env_collection_type);
-- consider FK val_property and val_device_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_prop_val_devcol_typ_rstr_dc
	FOREIGN KEY (prop_val_dev_coll_type_rstrct) REFERENCES val_device_collection_type(device_collection_type);
-- consider FK val_property and val_device_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_prop_val_devcoll_id
	FOREIGN KEY (device_collection_type) REFERENCES val_device_collection_type(device_collection_type);
-- consider FK val_property and val_account_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_acct_coll_type
	FOREIGN KEY (account_collection_type) REFERENCES val_account_collection_type(account_collection_type);
-- consider FK val_property and val_company_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_comp_coll_type
	FOREIGN KEY (company_collection_type) REFERENCES val_company_collection_type(company_collection_type);
-- consider FK val_property and val_layer2_network_coll_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_l2netype
	FOREIGN KEY (layer2_network_collection_type) REFERENCES val_layer2_network_coll_type(layer2_network_collection_type);
-- consider FK val_property and val_layer3_network_coll_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_l3netwok_type
	FOREIGN KEY (layer3_network_collection_type) REFERENCES val_layer3_network_coll_type(layer3_network_collection_type);
-- consider FK val_property and val_netblock_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_nblk_coll_type
	FOREIGN KEY (prop_val_nblk_coll_type_rstrct) REFERENCES val_netblock_collection_type(netblock_collection_type);
-- consider FK val_property and val_dns_domain_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_property_dnsdomcolltype
	FOREIGN KEY (dns_domain_collection_type) REFERENCES val_dns_domain_collection_type(dns_domain_collection_type);
-- consider FK val_property and val_netblock_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_property_netblkcolltype
	FOREIGN KEY (netblock_collection_type) REFERENCES val_netblock_collection_type(netblock_collection_type);
-- consider FK val_property and val_property_data_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_propdttyp
	FOREIGN KEY (property_data_type) REFERENCES val_property_data_type(property_data_type);
-- consider FK val_property and val_property_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_proptyp
	FOREIGN KEY (property_type) REFERENCES val_property_type(property_type);
-- consider FK val_property and val_account_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_pv_actyp_rst
	FOREIGN KEY (prop_val_acct_coll_type_rstrct) REFERENCES val_account_collection_type(account_collection_type);
-- consider FK val_property and val_property_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_vla_property_val_propcollty
	FOREIGN KEY (property_collection_type) REFERENCES val_property_collection_type(property_collection_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_property');
DROP TABLE IF EXISTS val_property_v64;
DROP TABLE IF EXISTS audit.val_property_v64;
-- DONE DEALING WITH TABLE val_property [3731535]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_raid_type [3722432]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_raid_type', 'val_raid_type');

-- FOREIGN KEYS FROM
ALTER TABLE volume_group DROP CONSTRAINT IF EXISTS fk_volgrp_rd_type;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_raid_type');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_raid_type DROP CONSTRAINT IF EXISTS pk_raid_type;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_raid_type ON jazzhands.val_raid_type;
DROP TRIGGER IF EXISTS trigger_audit_val_raid_type ON jazzhands.val_raid_type;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'val_raid_type');
---- BEGIN audit.val_raid_type TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_raid_type', 'val_raid_type');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_raid_type');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_raid_type_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'val_raid_type');
---- DONE audit.val_raid_type TEARDOWN


ALTER TABLE val_raid_type RENAME TO val_raid_type_v64;
ALTER TABLE audit.val_raid_type RENAME TO val_raid_type_v64;

CREATE TABLE val_raid_type
(
	raid_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	primary_raid_level	integer  NULL,
	secondary_raid_level	integer  NULL,
	raid_level_qualifier	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_raid_type', false);
INSERT INTO val_raid_type (
	raid_type,
	description,
	primary_raid_level,		-- new column (primary_raid_level)
	secondary_raid_level,		-- new column (secondary_raid_level)
	raid_level_qualifier,		-- new column (raid_level_qualifier)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	raid_type,
	description,
	NULL,		-- new column (primary_raid_level)
	NULL,		-- new column (secondary_raid_level)
	NULL,		-- new column (raid_level_qualifier)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_raid_type_v64;

INSERT INTO audit.val_raid_type (
	raid_type,
	description,
	primary_raid_level,		-- new column (primary_raid_level)
	secondary_raid_level,		-- new column (secondary_raid_level)
	raid_level_qualifier,		-- new column (raid_level_qualifier)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	raid_type,
	description,
	NULL,		-- new column (primary_raid_level)
	NULL,		-- new column (secondary_raid_level)
	NULL,		-- new column (raid_level_qualifier)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_raid_type_v64;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_raid_type ADD CONSTRAINT pk_raid_type PRIMARY KEY (raid_type);

-- Table/Column Comments
COMMENT ON COLUMN val_raid_type.primary_raid_level IS 'Common RAID Disk Data Format Specification primary raid level.';
COMMENT ON COLUMN val_raid_type.secondary_raid_level IS 'Common RAID Disk Data Format Specification secondary raid level.';
COMMENT ON COLUMN val_raid_type.raid_level_qualifier IS 'Common RAID Disk Data Format Specification''s integer INTEGER that describes the raid.  Arguably, this should be split out to distinct fields and constructed, and maybe one day it will be and this field will go away.';
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK val_raid_type and volume_group
ALTER TABLE volume_group
	ADD CONSTRAINT fk_volgrp_rd_type
	FOREIGN KEY (raid_type) REFERENCES val_raid_type(raid_type) DEFERRABLE;

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_raid_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_raid_type');
DROP TABLE IF EXISTS val_raid_type_v64;
DROP TABLE IF EXISTS audit.val_raid_type_v64;
-- DONE DEALING WITH TABLE val_raid_type [3731641]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_slot_function [3722450]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_slot_function', 'val_slot_function');

-- FOREIGN KEYS FROM
ALTER TABLE component_property DROP CONSTRAINT IF EXISTS fk_comp_prop_sltfuncid;
ALTER TABLE val_slot_physical_interface DROP CONSTRAINT IF EXISTS fk_slot_phys_int_slot_func;
ALTER TABLE slot_type DROP CONSTRAINT IF EXISTS fk_slot_type_slt_func;
ALTER TABLE val_component_property DROP CONSTRAINT IF EXISTS fk_vcomp_prop_rqd_slt_func;

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'val_slot_function');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.val_slot_function DROP CONSTRAINT IF EXISTS pk_val_slot_function;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_slot_function ON jazzhands.val_slot_function;
DROP TRIGGER IF EXISTS trigger_audit_val_slot_function ON jazzhands.val_slot_function;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'val_slot_function');
---- BEGIN audit.val_slot_function TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'val_slot_function', 'val_slot_function');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'val_slot_function');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_slot_function_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'val_slot_function');
---- DONE audit.val_slot_function TEARDOWN


ALTER TABLE val_slot_function RENAME TO val_slot_function_v64;
ALTER TABLE audit.val_slot_function RENAME TO val_slot_function_v64;

CREATE TABLE val_slot_function
(
	slot_function	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	can_have_mac_address	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_slot_function', false);
ALTER TABLE val_slot_function
	ALTER can_have_mac_address
	SET DEFAULT 'N'::bpchar;
INSERT INTO val_slot_function (
	slot_function,
	description,
	can_have_mac_address,		-- new column (can_have_mac_address)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	slot_function,
	description,
	'N'::bpchar,		-- new column (can_have_mac_address)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_slot_function_v64;

INSERT INTO audit.val_slot_function (
	slot_function,
	description,
	can_have_mac_address,		-- new column (can_have_mac_address)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	slot_function,
	description,
	NULL,		-- new column (can_have_mac_address)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.val_slot_function_v64;

ALTER TABLE val_slot_function
	ALTER can_have_mac_address
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_slot_function ADD CONSTRAINT pk_val_slot_function PRIMARY KEY (slot_function);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE val_slot_function ADD CONSTRAINT check_yes_no_slotfunc_macaddr
	CHECK (can_have_mac_address = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK val_slot_function and component_property
ALTER TABLE component_property
	ADD CONSTRAINT fk_comp_prop_sltfuncid
	FOREIGN KEY (slot_function) REFERENCES val_slot_function(slot_function);
-- consider FK val_slot_function and val_slot_physical_interface
ALTER TABLE val_slot_physical_interface
	ADD CONSTRAINT fk_slot_phys_int_slot_func
	FOREIGN KEY (slot_function) REFERENCES val_slot_function(slot_function);
-- consider FK val_slot_function and slot_type
ALTER TABLE slot_type
	ADD CONSTRAINT fk_slot_type_slt_func
	FOREIGN KEY (slot_function) REFERENCES val_slot_function(slot_function);
-- consider FK val_slot_function and val_component_property
ALTER TABLE val_component_property
	ADD CONSTRAINT fk_vcomp_prop_rqd_slt_func
	FOREIGN KEY (required_slot_function) REFERENCES val_slot_function(slot_function);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_slot_function');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_slot_function');
DROP TABLE IF EXISTS val_slot_function_v64;
DROP TABLE IF EXISTS audit.val_slot_function_v64;
-- DONE DEALING WITH TABLE val_slot_function [3731659]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE account_token [3720040]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_token', 'account_token');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.account_token DROP CONSTRAINT IF EXISTS fk_acct_ref_acct_token;
ALTER TABLE jazzhands.account_token DROP CONSTRAINT IF EXISTS fk_acct_token_ref_token;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'account_token');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.account_token DROP CONSTRAINT IF EXISTS ak_account_token_tken_acct;
ALTER TABLE jazzhands.account_token DROP CONSTRAINT IF EXISTS pk_account_token;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_accttoken_usrtokenlocked";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.account_token DROP CONSTRAINT IF EXISTS ckc_is_user_token_loc_system_u;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_account_token ON jazzhands.account_token;
DROP TRIGGER IF EXISTS trigger_audit_account_token ON jazzhands.account_token;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'account_token');
---- BEGIN audit.account_token TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'account_token', 'account_token');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'account_token');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."account_token_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'account_token');
---- DONE audit.account_token TEARDOWN


ALTER TABLE account_token RENAME TO account_token_v64;
ALTER TABLE audit.account_token RENAME TO account_token_v64;

CREATE TABLE account_token
(
	account_token_id	integer NOT NULL,
	account_id	integer NOT NULL,
	token_id	integer NOT NULL,
	issued_date	timestamp with time zone NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'account_token', false);
ALTER TABLE account_token
	ALTER account_token_id
	SET DEFAULT nextval('account_token_account_token_id_seq'::regclass);
INSERT INTO account_token (
	account_token_id,
	account_id,
	token_id,
	issued_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	account_token_id,
	account_id,
	token_id,
	issued_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM account_token_v64;

INSERT INTO audit.account_token (
	account_token_id,
	account_id,
	token_id,
	issued_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	account_token_id,
	account_id,
	token_id,
	issued_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.account_token_v64;

ALTER TABLE account_token
	ALTER account_token_id
	SET DEFAULT nextval('account_token_account_token_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE account_token ADD CONSTRAINT ak_account_token_tken_acct UNIQUE (account_id, token_id);
ALTER TABLE account_token ADD CONSTRAINT pk_account_token PRIMARY KEY (account_token_id);

-- Table/Column Comments
COMMENT ON COLUMN account_token.account_token_id IS 'This is its own PK in order to better handle auditing.';
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK account_token and account
ALTER TABLE account_token
	ADD CONSTRAINT fk_acct_ref_acct_token
	FOREIGN KEY (account_id) REFERENCES account(account_id);
-- consider FK account_token and token
ALTER TABLE account_token
	ADD CONSTRAINT fk_acct_token_ref_token
	FOREIGN KEY (token_id) REFERENCES token(token_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'account_token');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'account_token');
ALTER SEQUENCE account_token_account_token_id_seq
	 OWNED BY account_token.account_token_id;
DROP TABLE IF EXISTS account_token_v64;
DROP TABLE IF EXISTS audit.account_token_v64;
-- DONE DEALING WITH TABLE account_token [3728969]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE appaal_instance_property [3720098]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'appaal_instance_property', 'appaal_instance_property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.appaal_instance_property DROP CONSTRAINT IF EXISTS fk_apalinstprp_enc_id_id;
ALTER TABLE jazzhands.appaal_instance_property DROP CONSTRAINT IF EXISTS fk_appaalins_ref_appaalinsprop;
ALTER TABLE jazzhands.appaal_instance_property DROP CONSTRAINT IF EXISTS fk_appaalinstprop_ref_vappkey;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'appaal_instance_property');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.appaal_instance_property DROP CONSTRAINT IF EXISTS pk_appaal_instance_property;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."ind_aaiprop_key_value";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_appaal_instance_property ON jazzhands.appaal_instance_property;
DROP TRIGGER IF EXISTS trigger_audit_appaal_instance_property ON jazzhands.appaal_instance_property;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'appaal_instance_property');
---- BEGIN audit.appaal_instance_property TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'appaal_instance_property', 'appaal_instance_property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'appaal_instance_property');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."appaal_instance_property_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'appaal_instance_property');
---- DONE audit.appaal_instance_property TEARDOWN


ALTER TABLE appaal_instance_property RENAME TO appaal_instance_property_v64;
ALTER TABLE audit.appaal_instance_property RENAME TO appaal_instance_property_v64;

CREATE TABLE appaal_instance_property
(
	appaal_instance_id	integer NOT NULL,
	app_key	varchar(50) NOT NULL,
	appaal_group_name	varchar(50) NOT NULL,
	appaal_group_rank	character(18) NOT NULL,
	app_value	varchar(4000) NOT NULL,
	encryption_key_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'appaal_instance_property', false);
INSERT INTO appaal_instance_property (
	appaal_instance_id,
	app_key,
	appaal_group_name,		-- new column (appaal_group_name)
	appaal_group_rank,		-- new column (appaal_group_rank)
	app_value,
	encryption_key_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	appaal_instance_id,
	app_key,
	'database',		-- new column (appaal_group_name)
	NULL,		-- new column (appaal_group_rank)
	app_value,
	encryption_key_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM appaal_instance_property_v64;

INSERT INTO audit.appaal_instance_property (
	appaal_instance_id,
	app_key,
	appaal_group_name,		-- new column (appaal_group_name)
	appaal_group_rank,		-- new column (appaal_group_rank)
	app_value,
	encryption_key_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	appaal_instance_id,
	app_key,
	'database',		-- new column (appaal_group_name)
	NULL,		-- new column (appaal_group_rank)
	app_value,
	encryption_key_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.appaal_instance_property_v64;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE appaal_instance_property ADD CONSTRAINT ak_appaal_instance_idkeyrank UNIQUE (appaal_instance_id, app_key, appaal_group_rank);
ALTER TABLE appaal_instance_property ADD CONSTRAINT pk_appaal_instance_property PRIMARY KEY (appaal_instance_id, app_key, appaal_group_name, appaal_group_rank);

-- Table/Column Comments
COMMENT ON COLUMN appaal_instance_property.encryption_key_id IS 'encryption information for app_value, if used';
-- INDEXES
CREATE INDEX ind_aaiprop_key_value ON appaal_instance_property USING btree (app_key, app_value);
CREATE INDEX xif4appaal_instance_property ON appaal_instance_property USING btree (appaal_group_name);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK appaal_instance_property and val_appaal_group_name
ALTER TABLE appaal_instance_property
	ADD CONSTRAINT fk_allgrpprop_val_name
	FOREIGN KEY (appaal_group_name) REFERENCES val_appaal_group_name(appaal_group_name);
-- consider FK appaal_instance_property and encryption_key
ALTER TABLE appaal_instance_property
	ADD CONSTRAINT fk_apalinstprp_enc_id_id
	FOREIGN KEY (encryption_key_id) REFERENCES encryption_key(encryption_key_id);
-- consider FK appaal_instance_property and appaal_instance
ALTER TABLE appaal_instance_property
	ADD CONSTRAINT fk_appaalins_ref_appaalinsprop
	FOREIGN KEY (appaal_instance_id) REFERENCES appaal_instance(appaal_instance_id);
-- consider FK appaal_instance_property and val_app_key
ALTER TABLE appaal_instance_property
	ADD CONSTRAINT fk_appaalinstprop_ref_vappkey
	FOREIGN KEY (appaal_group_name, app_key) REFERENCES val_app_key(appaal_group_name, app_key);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'appaal_instance_property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'appaal_instance_property');
DROP TABLE IF EXISTS appaal_instance_property_v64;
DROP TABLE IF EXISTS audit.appaal_instance_property_v64;
-- DONE DEALING WITH TABLE appaal_instance_property [3729024]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE approval_instance_item [3720122]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'approval_instance_item', 'approval_instance_item');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.approval_instance_item DROP CONSTRAINT IF EXISTS fk_app_inst_item_appinstlinkid;
ALTER TABLE jazzhands.approval_instance_item DROP CONSTRAINT IF EXISTS fk_appinstitem_appinststep;
ALTER TABLE jazzhands.approval_instance_item DROP CONSTRAINT IF EXISTS fk_appinstitm_app_acctid;
ALTER TABLE jazzhands.approval_instance_item DROP CONSTRAINT IF EXISTS fk_appinstitmid_nextapiiid;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'approval_instance_item');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.approval_instance_item DROP CONSTRAINT IF EXISTS pk_approval_instance_item;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1approval_instance_item";
DROP INDEX IF EXISTS "jazzhands"."xif2approval_instance_item";
DROP INDEX IF EXISTS "jazzhands"."xif3approval_instance_item";
DROP INDEX IF EXISTS "jazzhands"."xif4approval_instance_item";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.approval_instance_item DROP CONSTRAINT IF EXISTS check_yes_no_1349410716;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_approval_instance_item ON jazzhands.approval_instance_item;
DROP TRIGGER IF EXISTS trigger_audit_approval_instance_item ON jazzhands.approval_instance_item;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'approval_instance_item');
---- BEGIN audit.approval_instance_item TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'approval_instance_item', 'approval_instance_item');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'approval_instance_item');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."approval_instance_item_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'approval_instance_item');
---- DONE audit.approval_instance_item TEARDOWN


ALTER TABLE approval_instance_item RENAME TO approval_instance_item_v64;
ALTER TABLE audit.approval_instance_item RENAME TO approval_instance_item_v64;

CREATE TABLE approval_instance_item
(
	approval_instance_item_id	integer NOT NULL,
	approval_instance_link_id	integer NOT NULL,
	approval_instance_step_id	integer NOT NULL,
	next_approval_instance_item_id	integer  NULL,
	approved_category	varchar(255) NOT NULL,
	approved_label	varchar(255)  NULL,
	approved_lhs	varchar(255)  NULL,
	approved_rhs	varchar(255)  NULL,
	is_approved	character(1)  NULL,
	approved_account_id	integer  NULL,
	approval_note	text  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'approval_instance_item', false);
ALTER TABLE approval_instance_item
	ALTER approval_instance_item_id
	SET DEFAULT nextval('approval_instance_item_approval_instance_item_id_seq'::regclass);
INSERT INTO approval_instance_item (
	approval_instance_item_id,
	approval_instance_link_id,
	approval_instance_step_id,
	next_approval_instance_item_id,
	approved_category,
	approved_label,
	approved_lhs,
	approved_rhs,
	is_approved,
	approved_account_id,
	approval_note,		-- new column (approval_note)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	approval_instance_item_id,
	approval_instance_link_id,
	approval_instance_step_id,
	next_approval_instance_item_id,
	approved_category,
	approved_label,
	approved_lhs,
	approved_rhs,
	is_approved,
	approved_account_id,
	NULL,		-- new column (approval_note)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM approval_instance_item_v64;

INSERT INTO audit.approval_instance_item (
	approval_instance_item_id,
	approval_instance_link_id,
	approval_instance_step_id,
	next_approval_instance_item_id,
	approved_category,
	approved_label,
	approved_lhs,
	approved_rhs,
	is_approved,
	approved_account_id,
	approval_note,		-- new column (approval_note)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	approval_instance_item_id,
	approval_instance_link_id,
	approval_instance_step_id,
	next_approval_instance_item_id,
	approved_category,
	approved_label,
	approved_lhs,
	approved_rhs,
	is_approved,
	approved_account_id,
	NULL,		-- new column (approval_note)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.approval_instance_item_v64;

ALTER TABLE approval_instance_item
	ALTER approval_instance_item_id
	SET DEFAULT nextval('approval_instance_item_approval_instance_item_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE approval_instance_item ADD CONSTRAINT pk_approval_instance_item PRIMARY KEY (approval_instance_item_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif1approval_instance_item ON approval_instance_item USING btree (approval_instance_step_id);
CREATE INDEX xif2approval_instance_item ON approval_instance_item USING btree (approval_instance_link_id);
CREATE INDEX xif3approval_instance_item ON approval_instance_item USING btree (next_approval_instance_item_id);
CREATE INDEX xif4approval_instance_item ON approval_instance_item USING btree (approved_account_id);

-- CHECK CONSTRAINTS
ALTER TABLE approval_instance_item ADD CONSTRAINT check_yes_no_1349410716
	CHECK (is_approved = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK approval_instance_item and approval_instance_link
ALTER TABLE approval_instance_item
	ADD CONSTRAINT fk_app_inst_item_appinstlinkid
	FOREIGN KEY (approval_instance_link_id) REFERENCES approval_instance_link(approval_instance_link_id);
-- consider FK approval_instance_item and approval_instance_step
ALTER TABLE approval_instance_item
	ADD CONSTRAINT fk_appinstitem_appinststep
	FOREIGN KEY (approval_instance_step_id) REFERENCES approval_instance_step(approval_instance_step_id);
-- consider FK approval_instance_item and account
ALTER TABLE approval_instance_item
	ADD CONSTRAINT fk_appinstitm_app_acctid
	FOREIGN KEY (approved_account_id) REFERENCES account(account_id);
-- consider FK approval_instance_item and approval_instance_item
ALTER TABLE approval_instance_item
	ADD CONSTRAINT fk_appinstitmid_nextapiiid
	FOREIGN KEY (next_approval_instance_item_id) REFERENCES approval_instance_item(approval_instance_item_id);

-- TRIGGERS
-- consider NEW oid 3738418
CREATE OR REPLACE FUNCTION jazzhands.approval_instance_item_approval_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	NOTIFY approval_instance_item_approval_change;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_approval_instance_item_approval_notify AFTER INSERT OR UPDATE OF is_approved ON approval_instance_item FOR EACH STATEMENT EXECUTE PROCEDURE approval_instance_item_approval_notify();

-- XXX - may need to include trigger function
-- consider NEW oid 3738414
CREATE OR REPLACE FUNCTION jazzhands.approval_instance_item_approved_immutable()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF OLD.is_approved != NEW.is_approved THEN
		RAISE EXCEPTION 'Approval may not be changed';
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_approval_instance_item_approved_immutable BEFORE UPDATE OF is_approved ON approval_instance_item FOR EACH ROW EXECUTE PROCEDURE approval_instance_item_approved_immutable();

-- XXX - may need to include trigger function
-- consider NEW oid 3738410
CREATE OR REPLACE FUNCTION jazzhands.approval_instance_step_auto_complete()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	--
	-- on insert, if the parent was already marked as completed, fail.
	-- arguably, this should happen on updates as well
	--	possibly should move this to a before trigger
	--
	IF TG_OP = 'INSERT' THEN
		SELECT	count(*)
		INTO	_tally
		FROM	approval_instance_step
		WHERE	approval_instance_step_id = NEW.approval_instance_step_id
		AND		is_completed = 'Y';

		IF _tally > 0 THEN
			RAISE EXCEPTION 'Completed attestation cycles may not have items added';
		END IF;
	END IF;

	IF NEW.is_approved IS NOT NULL THEN
		SELECT	count(*)
		INTO	_tally
		FROM	approval_instance_item
		WHERE	approval_instance_step_id = NEW.approval_instance_step_id
		AND		approval_instance_item_id != NEW.approval_instance_item_id
		AND		is_approved IS NOT NULL;

		IF _tally = 0 THEN
			UPDATE	approval_instance_step
			SET		is_completed = 'Y',
					approval_instance_step_end = now()
			WHERE	approval_instance_step_id = NEW.approval_instance_step_id;
		END IF;
		
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_approval_instance_step_auto_complete AFTER INSERT OR UPDATE OF is_approved ON approval_instance_item FOR EACH ROW EXECUTE PROCEDURE approval_instance_step_auto_complete();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'approval_instance_item');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'approval_instance_item');
ALTER SEQUENCE approval_instance_item_approval_instance_item_id_seq
	 OWNED BY approval_instance_item.approval_instance_item_id;
DROP TABLE IF EXISTS approval_instance_item_v64;
DROP TABLE IF EXISTS audit.approval_instance_item_v64;
-- DONE DEALING WITH TABLE approval_instance_item [3729051]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE approval_instance_step [3720149]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'approval_instance_step', 'approval_instance_step');

-- FOREIGN KEYS FROM
ALTER TABLE approval_instance_item DROP CONSTRAINT IF EXISTS fk_appinstitem_appinststep;
ALTER TABLE approval_instance_step_notify DROP CONSTRAINT IF EXISTS fk_appinststep_appinstprocid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.approval_instance_step DROP CONSTRAINT IF EXISTS fk_app_inst_step_apinstid;
ALTER TABLE jazzhands.approval_instance_step DROP CONSTRAINT IF EXISTS fk_appinststep_app_acct_id;
ALTER TABLE jazzhands.approval_instance_step DROP CONSTRAINT IF EXISTS fk_appinststep_app_prcchnid;
ALTER TABLE jazzhands.approval_instance_step DROP CONSTRAINT IF EXISTS fk_appinststep_app_type;
ALTER TABLE jazzhands.approval_instance_step DROP CONSTRAINT IF EXISTS fk_apstep_actual_app_acctid;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'approval_instance_step');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.approval_instance_step DROP CONSTRAINT IF EXISTS pk_approval_instance_step;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1approval_instance_step";
DROP INDEX IF EXISTS "jazzhands"."xif2approval_instance_step";
DROP INDEX IF EXISTS "jazzhands"."xif3approval_instance_step";
DROP INDEX IF EXISTS "jazzhands"."xif4approval_instance_step";
DROP INDEX IF EXISTS "jazzhands"."xif5approval_instance_step";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.approval_instance_step DROP CONSTRAINT IF EXISTS check_yes_no_1099280524;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_approval_instance_step ON jazzhands.approval_instance_step;
DROP TRIGGER IF EXISTS trigger_audit_approval_instance_step ON jazzhands.approval_instance_step;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'approval_instance_step');
---- BEGIN audit.approval_instance_step TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'approval_instance_step', 'approval_instance_step');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'approval_instance_step');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."approval_instance_step_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'approval_instance_step');
---- DONE audit.approval_instance_step TEARDOWN


ALTER TABLE approval_instance_step RENAME TO approval_instance_step_v64;
ALTER TABLE audit.approval_instance_step RENAME TO approval_instance_step_v64;

CREATE TABLE approval_instance_step
(
	approval_instance_step_id	integer NOT NULL,
	approval_instance_id	integer NOT NULL,
	approval_process_chain_id	integer NOT NULL,
	approval_instance_step_name	varchar(50) NOT NULL,
	approval_instance_step_due	timestamp with time zone NOT NULL,
	approval_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	approval_instance_step_start	timestamp with time zone NOT NULL,
	approval_instance_step_end	timestamp with time zone  NULL,
	approver_account_id	integer NOT NULL,
	external_reference_name	varchar(255)  NULL,
	is_completed	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'approval_instance_step', false);
ALTER TABLE approval_instance_step
	ALTER approval_instance_step_id
	SET DEFAULT nextval('approval_instance_step_approval_instance_step_id_seq'::regclass);
ALTER TABLE approval_instance_step
	ALTER approval_instance_step_start
	SET DEFAULT now();
ALTER TABLE approval_instance_step
	ALTER is_completed
	SET DEFAULT 'N'::bpchar;
INSERT INTO approval_instance_step (
	approval_instance_step_id,
	approval_instance_id,
	approval_process_chain_id,
	approval_instance_step_name,
	approval_instance_step_due,
	approval_type,
	description,
	approval_instance_step_start,
	approval_instance_step_end,
	approver_account_id,
	external_reference_name,
	is_completed,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	approval_instance_step_id,
	approval_instance_id,
	approval_process_chain_id,
	approval_instance_step_name,
	approval_instance_step_due,
	approval_type,
	description,
	approval_instance_step_start,
	approval_instance_step_end,
	approver_account_id,
	external_reference_name,
	is_completed,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM approval_instance_step_v64;

INSERT INTO audit.approval_instance_step (
	approval_instance_step_id,
	approval_instance_id,
	approval_process_chain_id,
	approval_instance_step_name,
	approval_instance_step_due,
	approval_type,
	description,
	approval_instance_step_start,
	approval_instance_step_end,
	approver_account_id,
	external_reference_name,
	is_completed,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	approval_instance_step_id,
	approval_instance_id,
	approval_process_chain_id,
	approval_instance_step_name,
	approval_instance_step_due,
	approval_type,
	description,
	approval_instance_step_start,
	approval_instance_step_end,
	approver_account_id,
	external_reference_name,
	is_completed,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.approval_instance_step_v64;

ALTER TABLE approval_instance_step
	ALTER approval_instance_step_id
	SET DEFAULT nextval('approval_instance_step_approval_instance_step_id_seq'::regclass);
ALTER TABLE approval_instance_step
	ALTER approval_instance_step_start
	SET DEFAULT now();
ALTER TABLE approval_instance_step
	ALTER is_completed
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE approval_instance_step ADD CONSTRAINT pk_approval_instance_step PRIMARY KEY (approval_instance_step_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif1approval_instance_step ON approval_instance_step USING btree (approval_instance_id);
CREATE INDEX xif2approval_instance_step ON approval_instance_step USING btree (approver_account_id);
CREATE INDEX xif4approval_instance_step ON approval_instance_step USING btree (approval_type);
CREATE INDEX xif5approval_instance_step ON approval_instance_step USING btree (approval_process_chain_id);

-- CHECK CONSTRAINTS
ALTER TABLE approval_instance_step ADD CONSTRAINT check_yes_no_1099280524
	CHECK (is_completed = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK approval_instance_step and approval_instance_item
ALTER TABLE approval_instance_item
	ADD CONSTRAINT fk_appinstitem_appinststep
	FOREIGN KEY (approval_instance_step_id) REFERENCES approval_instance_step(approval_instance_step_id);
-- consider FK approval_instance_step and approval_instance_step_notify
ALTER TABLE approval_instance_step_notify
	ADD CONSTRAINT fk_appinststep_appinstprocid
	FOREIGN KEY (approval_instance_step_id) REFERENCES approval_instance_step(approval_instance_step_id);

-- FOREIGN KEYS TO
-- consider FK approval_instance_step and approval_instance
ALTER TABLE approval_instance_step
	ADD CONSTRAINT fk_app_inst_step_apinstid
	FOREIGN KEY (approval_instance_id) REFERENCES approval_instance(approval_instance_id);
-- consider FK approval_instance_step and account
ALTER TABLE approval_instance_step
	ADD CONSTRAINT fk_appinststep_app_acct_id
	FOREIGN KEY (approver_account_id) REFERENCES account(account_id);
-- consider FK approval_instance_step and approval_process_chain
ALTER TABLE approval_instance_step
	ADD CONSTRAINT fk_appinststep_app_prcchnid
	FOREIGN KEY (approval_process_chain_id) REFERENCES approval_process_chain(approval_process_chain_id);
-- consider FK approval_instance_step and val_approval_type
ALTER TABLE approval_instance_step
	ADD CONSTRAINT fk_appinststep_app_type
	FOREIGN KEY (approval_type) REFERENCES val_approval_type(approval_type);

-- TRIGGERS
-- consider NEW oid 3738412
CREATE OR REPLACE FUNCTION jazzhands.approval_instance_step_completed_immutable()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF ( OLD.is_completed ='Y' AND NEW.is_completed = 'N' ) THEN
		RAISE EXCEPTION 'Approval completion may not be reverted';
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_approval_instance_step_completed_immutable BEFORE UPDATE OF is_completed ON approval_instance_step FOR EACH ROW EXECUTE PROCEDURE approval_instance_step_completed_immutable();

-- XXX - may need to include trigger function
-- consider NEW oid 3738416
CREATE OR REPLACE FUNCTION jazzhands.approval_instance_step_resolve_instance()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally INTEGER;
BEGIN
	SELECT	count(*)
	INTO	_tally
	FROM	approval_instance_step
	WHERE	is_completed = 'N'
	AND		approval_instance_id = NEW.approval_instance_id;

	IF _tally = 0 THEN
		UPDATE approval_instance
		SET	approval_end = now()
		WHERE	approval_instance_id = NEW.approval_instance_id;
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_approval_instance_step_resolve_instance AFTER UPDATE OF is_completed ON approval_instance_step FOR EACH ROW EXECUTE PROCEDURE approval_instance_step_resolve_instance();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'approval_instance_step');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'approval_instance_step');
ALTER SEQUENCE approval_instance_step_approval_instance_step_id_seq
	 OWNED BY approval_instance_step.approval_instance_step_id;
DROP TABLE IF EXISTS approval_instance_step_v64;
DROP TABLE IF EXISTS audit.approval_instance_step_v64;
-- DONE DEALING WITH TABLE approval_instance_step [3729078]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE approval_instance_step_notify [3720166]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'approval_instance_step_notify', 'approval_instance_step_notify');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.approval_instance_step_notify DROP CONSTRAINT IF EXISTS fk_appinststep_appinstprocid;
ALTER TABLE jazzhands.approval_instance_step_notify DROP CONSTRAINT IF EXISTS fk_appinststepntfy_ntfy_typ;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'approval_instance_step_notify');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.approval_instance_step_notify DROP CONSTRAINT IF EXISTS pk_approval_instance_step_noti;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1approval_instance_step_not";
DROP INDEX IF EXISTS "jazzhands"."xif2approval_instance_step_not";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_approval_instance_step_notify ON jazzhands.approval_instance_step_notify;
DROP TRIGGER IF EXISTS trigger_audit_approval_instance_step_notify ON jazzhands.approval_instance_step_notify;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'approval_instance_step_notify');
---- BEGIN audit.approval_instance_step_notify TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'approval_instance_step_notify', 'approval_instance_step_notify');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'approval_instance_step_notify');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."approval_instance_step_notify_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'approval_instance_step_notify');
---- DONE audit.approval_instance_step_notify TEARDOWN


ALTER TABLE approval_instance_step_notify RENAME TO approval_instance_step_notify_v64;
ALTER TABLE audit.approval_instance_step_notify RENAME TO approval_instance_step_notify_v64;

CREATE TABLE approval_instance_step_notify
(
	approv_instance_step_notify_id	integer NOT NULL,
	approval_instance_step_id	integer NOT NULL,
	approval_notify_type	varchar(50) NOT NULL,
	account_id	integer NOT NULL,
	approval_notify_whence	timestamp with time zone NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'approval_instance_step_notify', false);
INSERT INTO approval_instance_step_notify (
	approv_instance_step_notify_id,
	approval_instance_step_id,
	approval_notify_type,
	account_id,		-- new column (account_id)
	approval_notify_whence,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	o.approv_instance_step_notify_id,
	o.approval_instance_step_id,
	o.approval_notify_type,
	approver_account_id,	    -- new column (account_id)
	o.approval_notify_whence,
	o.data_ins_user,
	o.data_ins_date,
	o.data_upd_user,
	o.data_upd_date
FROM approval_instance_step_notify_v64 o
	INNER JOIN approval_instance_step USING (approval_instance_step_id);



INSERT INTO audit.approval_instance_step_notify (
	approv_instance_step_notify_id,
	approval_instance_step_id,
	approval_notify_type,
	account_id,		-- new column (account_id)
	approval_notify_whence,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	o.approv_instance_step_notify_id,
	o.approval_instance_step_id,
	o.approval_notify_type,
	approver_account_id,	    -- new column (account_id)
	o.approval_notify_whence,
	o.data_ins_user,
	o.data_ins_date,
	o.data_upd_user,
	o.data_upd_date,
	o."aud#action",
	o."aud#timestamp",
	o."aud#user",
	o."aud#seq"
FROM audit.approval_instance_step_notify_v64 o
	INNER JOIN approval_instance_step USING (approval_instance_step_id);



-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE approval_instance_step_notify ADD CONSTRAINT pk_approval_instance_step_noti PRIMARY KEY (approv_instance_step_notify_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif1approval_instance_step_not ON approval_instance_step_notify USING btree (approval_notify_type);
CREATE INDEX xif2approval_instance_step_not ON approval_instance_step_notify USING btree (approval_instance_step_id);
CREATE INDEX xif3approval_instance_step_not ON approval_instance_step_notify USING btree (account_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK approval_instance_step_notify and approval_instance_step
ALTER TABLE approval_instance_step_notify
	ADD CONSTRAINT fk_appinststep_appinstprocid
	FOREIGN KEY (approval_instance_step_id) REFERENCES approval_instance_step(approval_instance_step_id);
-- consider FK approval_instance_step_notify and val_approval_notifty_type
ALTER TABLE approval_instance_step_notify
	ADD CONSTRAINT fk_appinststepntfy_ntfy_typ
	FOREIGN KEY (approval_notify_type) REFERENCES val_approval_notifty_type(approval_notify_type);
-- consider FK approval_instance_step_notify and account
ALTER TABLE approval_instance_step_notify
	ADD CONSTRAINT fk_appr_inst_step_notif_acct
	FOREIGN KEY (account_id) REFERENCES account(account_id);

-- TRIGGERS
-- consider NEW oid 3738420
CREATE OR REPLACE FUNCTION jazzhands.legacy_approval_instance_step_notify_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF NEW.account_id IS NULL THEN
		SELECT	approver_account_id
		INTO	NEW.account_id
		FROM	legacy_approval_instance_step
		WHERE	legacy_approval_instance_step_id = NEW.legacy_approval_instance_step_id;
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_legacy_approval_instance_step_notify_account BEFORE INSERT OR UPDATE OF account_id ON approval_instance_step_notify FOR EACH STATEMENT EXECUTE PROCEDURE legacy_approval_instance_step_notify_account();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'approval_instance_step_notify');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'approval_instance_step_notify');
DROP TABLE IF EXISTS approval_instance_step_notify_v64;
DROP TABLE IF EXISTS audit.approval_instance_step_notify_v64;
-- DONE DEALING WITH TABLE approval_instance_step_notify [3729094]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE approval_process [3720178]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'approval_process', 'approval_process');

-- FOREIGN KEYS FROM
ALTER TABLE approval_instance DROP CONSTRAINT IF EXISTS fk_approval_proc_inst_aproc_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.approval_process DROP CONSTRAINT IF EXISTS fk_app_prc_propcoll_id;
ALTER TABLE jazzhands.approval_process DROP CONSTRAINT IF EXISTS fk_app_proc_1st_app_proc_chnid;
ALTER TABLE jazzhands.approval_process DROP CONSTRAINT IF EXISTS fk_app_proc_app_proc_typ;
ALTER TABLE jazzhands.approval_process DROP CONSTRAINT IF EXISTS fk_app_proc_expire_action;
ALTER TABLE jazzhands.approval_process DROP CONSTRAINT IF EXISTS fk_appproc_attest_freq;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'approval_process');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.approval_process DROP CONSTRAINT IF EXISTS pk_approval_process;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1approval_process";
DROP INDEX IF EXISTS "jazzhands"."xif2approval_process";
DROP INDEX IF EXISTS "jazzhands"."xif3approval_process";
DROP INDEX IF EXISTS "jazzhands"."xif4approval_process";
DROP INDEX IF EXISTS "jazzhands"."xif5approval_process";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_approval_process ON jazzhands.approval_process;
DROP TRIGGER IF EXISTS trigger_audit_approval_process ON jazzhands.approval_process;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'approval_process');
---- BEGIN audit.approval_process TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'approval_process', 'approval_process');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'approval_process');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."approval_process_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'approval_process');
---- DONE audit.approval_process TEARDOWN


ALTER TABLE approval_process RENAME TO approval_process_v64;
ALTER TABLE audit.approval_process RENAME TO approval_process_v64;

CREATE TABLE approval_process
(
	approval_process_id	integer NOT NULL,
	approval_process_name	varchar(50) NOT NULL,
	approval_process_type	varchar(50)  NULL,
	description	varchar(255)  NULL,
	first_apprvl_process_chain_id	integer NOT NULL,
	property_collection_id	integer NOT NULL,
	approval_expiration_action	varchar(50) NOT NULL,
	attestation_frequency	varchar(50)  NULL,
	attestation_offset	integer  NULL,
	max_escalation_level	integer  NULL,
	escalation_delay	character(18)  NULL,
	escalation_reminder_gap	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'approval_process', false);
ALTER TABLE approval_process
	ALTER approval_process_id
	SET DEFAULT nextval('approval_process_approval_process_id_seq'::regclass);
INSERT INTO approval_process (
	approval_process_id,
	approval_process_name,
	approval_process_type,
	description,
	first_apprvl_process_chain_id,
	property_collection_id,
	approval_expiration_action,
	attestation_frequency,
	attestation_offset,
	max_escalation_level,		-- new column (max_escalation_level)
	escalation_delay,		-- new column (escalation_delay)
	escalation_reminder_gap,		-- new column (escalation_reminder_gap)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	approval_process_id,
	approval_process_name,
	approval_process_type,
	description,
	first_apprvl_process_chain_id,
	property_collection_id,
	approval_expiration_action,
	attestation_frequency,
	attestation_offset,
	NULL,		-- new column (max_escalation_level)
	NULL,		-- new column (escalation_delay)
	NULL,		-- new column (escalation_reminder_gap)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM approval_process_v64;

INSERT INTO audit.approval_process (
	approval_process_id,
	approval_process_name,
	approval_process_type,
	description,
	first_apprvl_process_chain_id,
	property_collection_id,
	approval_expiration_action,
	attestation_frequency,
	attestation_offset,
	max_escalation_level,		-- new column (max_escalation_level)
	escalation_delay,		-- new column (escalation_delay)
	escalation_reminder_gap,		-- new column (escalation_reminder_gap)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	approval_process_id,
	approval_process_name,
	approval_process_type,
	description,
	first_apprvl_process_chain_id,
	property_collection_id,
	approval_expiration_action,
	attestation_frequency,
	attestation_offset,
	NULL,		-- new column (max_escalation_level)
	NULL,		-- new column (escalation_delay)
	NULL,		-- new column (escalation_reminder_gap)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.approval_process_v64;

ALTER TABLE approval_process
	ALTER approval_process_id
	SET DEFAULT nextval('approval_process_approval_process_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE approval_process ADD CONSTRAINT pk_approval_process PRIMARY KEY (approval_process_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif1approval_process ON approval_process USING btree (property_collection_id);
CREATE INDEX xif2approval_process ON approval_process USING btree (approval_process_type);
CREATE INDEX xif3approval_process ON approval_process USING btree (approval_expiration_action);
CREATE INDEX xif4approval_process ON approval_process USING btree (attestation_frequency);
CREATE INDEX xif5approval_process ON approval_process USING btree (first_apprvl_process_chain_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK approval_process and approval_instance
ALTER TABLE approval_instance
	ADD CONSTRAINT fk_approval_proc_inst_aproc_id
	FOREIGN KEY (approval_process_id) REFERENCES approval_process(approval_process_id);

-- FOREIGN KEYS TO
-- consider FK approval_process and property_collection
ALTER TABLE approval_process
	ADD CONSTRAINT fk_app_prc_propcoll_id
	FOREIGN KEY (property_collection_id) REFERENCES property_collection(property_collection_id);
-- consider FK approval_process and approval_process_chain
ALTER TABLE approval_process
	ADD CONSTRAINT fk_app_proc_1st_app_proc_chnid
	FOREIGN KEY (first_apprvl_process_chain_id) REFERENCES approval_process_chain(approval_process_chain_id);
-- consider FK approval_process and val_approval_process_type
ALTER TABLE approval_process
	ADD CONSTRAINT fk_app_proc_app_proc_typ
	FOREIGN KEY (approval_process_type) REFERENCES val_approval_process_type(approval_process_type);
-- consider FK approval_process and val_approval_expiration_action
ALTER TABLE approval_process
	ADD CONSTRAINT fk_app_proc_expire_action
	FOREIGN KEY (approval_expiration_action) REFERENCES val_approval_expiration_action(approval_expiration_action);
-- consider FK approval_process and val_attestation_frequency
ALTER TABLE approval_process
	ADD CONSTRAINT fk_appproc_attest_freq
	FOREIGN KEY (attestation_frequency) REFERENCES val_attestation_frequency(attestation_frequency);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'approval_process');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'approval_process');
ALTER SEQUENCE approval_process_approval_process_id_seq
	 OWNED BY approval_process.approval_process_id;
DROP TABLE IF EXISTS approval_process_v64;
DROP TABLE IF EXISTS audit.approval_process_v64;
-- DONE DEALING WITH TABLE approval_process [3729107]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE approval_process_chain [3720194]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'approval_process_chain', 'approval_process_chain');

-- FOREIGN KEYS FROM
ALTER TABLE approval_process DROP CONSTRAINT IF EXISTS fk_app_proc_1st_app_proc_chnid;
ALTER TABLE approval_instance_step DROP CONSTRAINT IF EXISTS fk_appinststep_app_prcchnid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.approval_process_chain DROP CONSTRAINT IF EXISTS fk_appproc_chn_resp_period;
ALTER TABLE jazzhands.approval_process_chain DROP CONSTRAINT IF EXISTS fk_apprchn_app_proc_chn;
ALTER TABLE jazzhands.approval_process_chain DROP CONSTRAINT IF EXISTS fk_apprchn_rej_proc_chn;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'approval_process_chain');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.approval_process_chain DROP CONSTRAINT IF EXISTS pk_approval_process_chain;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1approval_process_chain";
DROP INDEX IF EXISTS "jazzhands"."xif2approval_process_chain";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.approval_process_chain DROP CONSTRAINT IF EXISTS check_yes_no_2125461495;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_approval_process_chain ON jazzhands.approval_process_chain;
DROP TRIGGER IF EXISTS trigger_audit_approval_process_chain ON jazzhands.approval_process_chain;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'approval_process_chain');
---- BEGIN audit.approval_process_chain TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'approval_process_chain', 'approval_process_chain');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'approval_process_chain');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."approval_process_chain_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'approval_process_chain');
---- DONE audit.approval_process_chain TEARDOWN


ALTER TABLE approval_process_chain RENAME TO approval_process_chain_v64;
ALTER TABLE audit.approval_process_chain RENAME TO approval_process_chain_v64;

CREATE TABLE approval_process_chain
(
	approval_process_chain_id	integer NOT NULL,
	approval_process_chain_name	varchar(50) NOT NULL,
	approval_chain_response_period	varchar(50)  NULL,
	description	varchar(255)  NULL,
	message	varchar(4096)  NULL,
	email_message	varchar(4096)  NULL,
	email_subject_prefix	varchar(50)  NULL,
	email_subject_suffix	varchar(50)  NULL,
	max_escalation_level	integer  NULL,
	escalation_delay	integer  NULL,
	escalation_reminder_gap	integer  NULL,
	approving_entity	varchar(50)  NULL,
	refresh_all_data	character(1) NOT NULL,
	accept_app_process_chain_id	integer  NULL,
	reject_app_process_chain_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'approval_process_chain', false);
ALTER TABLE approval_process_chain
	ALTER approval_process_chain_id
	SET DEFAULT nextval('approval_process_chain_approval_process_chain_id_seq'::regclass);
ALTER TABLE approval_process_chain
	ALTER approval_chain_response_period
	SET DEFAULT '1 week'::character varying;
ALTER TABLE approval_process_chain
	ALTER refresh_all_data
	SET DEFAULT 'N'::bpchar;
INSERT INTO approval_process_chain (
	approval_process_chain_id,
	approval_process_chain_name,
	approval_chain_response_period,
	description,
	message,
	email_message,
	email_subject_prefix,
	email_subject_suffix,
	max_escalation_level,		-- new column (max_escalation_level)
	escalation_delay,		-- new column (escalation_delay)
	escalation_reminder_gap,		-- new column (escalation_reminder_gap)
	approving_entity,
	refresh_all_data,
	accept_app_process_chain_id,
	reject_app_process_chain_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	approval_process_chain_id,
	approval_process_chain_name,
	approval_chain_response_period,
	description,
	message,
	email_message,
	email_subject_prefix,
	email_subject_suffix,
	NULL,		-- new column (max_escalation_level)
	NULL,		-- new column (escalation_delay)
	NULL,		-- new column (escalation_reminder_gap)
	approving_entity,
	refresh_all_data,
	accept_app_process_chain_id,
	reject_app_process_chain_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM approval_process_chain_v64;

INSERT INTO audit.approval_process_chain (
	approval_process_chain_id,
	approval_process_chain_name,
	approval_chain_response_period,
	description,
	message,
	email_message,
	email_subject_prefix,
	email_subject_suffix,
	max_escalation_level,		-- new column (max_escalation_level)
	escalation_delay,		-- new column (escalation_delay)
	escalation_reminder_gap,		-- new column (escalation_reminder_gap)
	approving_entity,
	refresh_all_data,
	accept_app_process_chain_id,
	reject_app_process_chain_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	approval_process_chain_id,
	approval_process_chain_name,
	approval_chain_response_period,
	description,
	message,
	email_message,
	email_subject_prefix,
	email_subject_suffix,
	NULL,		-- new column (max_escalation_level)
	NULL,		-- new column (escalation_delay)
	NULL,		-- new column (escalation_reminder_gap)
	approving_entity,
	refresh_all_data,
	accept_app_process_chain_id,
	reject_app_process_chain_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.approval_process_chain_v64;

ALTER TABLE approval_process_chain
	ALTER approval_process_chain_id
	SET DEFAULT nextval('approval_process_chain_approval_process_chain_id_seq'::regclass);
ALTER TABLE approval_process_chain
	ALTER approval_chain_response_period
	SET DEFAULT '1 week'::character varying;
ALTER TABLE approval_process_chain
	ALTER refresh_all_data
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE approval_process_chain ADD CONSTRAINT pk_approval_process_chain PRIMARY KEY (approval_process_chain_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif1approval_process_chain ON approval_process_chain USING btree (approval_chain_response_period);
CREATE INDEX xif2approval_process_chain ON approval_process_chain USING btree (accept_app_process_chain_id);

-- CHECK CONSTRAINTS
ALTER TABLE approval_process_chain ADD CONSTRAINT check_yes_no_2125461495
	CHECK (refresh_all_data = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK approval_process_chain and approval_process
ALTER TABLE approval_process
	ADD CONSTRAINT fk_app_proc_1st_app_proc_chnid
	FOREIGN KEY (first_apprvl_process_chain_id) REFERENCES approval_process_chain(approval_process_chain_id);
-- consider FK approval_process_chain and approval_instance_step
ALTER TABLE approval_instance_step
	ADD CONSTRAINT fk_appinststep_app_prcchnid
	FOREIGN KEY (approval_process_chain_id) REFERENCES approval_process_chain(approval_process_chain_id);

-- FOREIGN KEYS TO
-- consider FK approval_process_chain and val_approval_chain_resp_prd
ALTER TABLE approval_process_chain
	ADD CONSTRAINT fk_appproc_chn_resp_period
	FOREIGN KEY (approval_chain_response_period) REFERENCES val_approval_chain_resp_prd(approval_chain_response_period);
-- consider FK approval_process_chain and approval_process_chain
ALTER TABLE approval_process_chain
	ADD CONSTRAINT fk_apprchn_app_proc_chn
	FOREIGN KEY (accept_app_process_chain_id) REFERENCES approval_process_chain(approval_process_chain_id);
-- consider FK approval_process_chain and approval_process_chain
ALTER TABLE approval_process_chain
	ADD CONSTRAINT fk_apprchn_rej_proc_chn
	FOREIGN KEY (accept_app_process_chain_id) REFERENCES approval_process_chain(approval_process_chain_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'approval_process_chain');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'approval_process_chain');
ALTER SEQUENCE approval_process_chain_approval_process_chain_id_seq
	 OWNED BY approval_process_chain.approval_process_chain_id;
DROP TABLE IF EXISTS approval_process_chain_v64;
DROP TABLE IF EXISTS audit.approval_process_chain_v64;
-- DONE DEALING WITH TABLE approval_process_chain [3729123]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE company_collection_company
CREATE TABLE company_collection_company
(
	company_collection_id	integer NOT NULL,
	company_id	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'company_collection_company', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE company_collection_company ADD CONSTRAINT pk_company_collection_company PRIMARY KEY (company_collection_id, company_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xifcompany_coll_company_coll_i ON company_collection_company USING btree (company_collection_id);
CREATE INDEX xifcompany_coll_company_id ON company_collection_company USING btree (company_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK company_collection_company and company_collection
ALTER TABLE company_collection_company
	ADD CONSTRAINT fk_company_coll_company_coll_i
	FOREIGN KEY (company_collection_id) REFERENCES company_collection(company_collection_id);
-- consider FK company_collection_company and company
ALTER TABLE company_collection_company
	ADD CONSTRAINT fk_company_coll_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id);

-- TRIGGERS
-- consider NEW oid 3738460
CREATE OR REPLACE FUNCTION jazzhands.company_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	dct	val_company_collection_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	dct
	FROM	val_company_collection_type
	WHERE	company_collection_type =
		(select company_collection_type from company_collection
			where company_collection_id = NEW.company_collection_id);

	IF dct.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from company_collection_company
		  where company_collection_id = NEW.company_collection_id;
		IF tally > dct.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF dct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from company_collection_company
		  		inner join company_collection using (company_collection_id)
		  where company_id = NEW.company_id
		  and	company_collection_type = dct.company_collection_type;
		IF tally > dct.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Company may not be a member of more than % collections of type %',
				dct.MAX_NUM_COLLECTIONS, dct.company_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;
CREATE CONSTRAINT TRIGGER trigger_company_collection_member_enforce AFTER INSERT OR UPDATE ON company_collection_company DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE company_collection_member_enforce();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'company_collection_company');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'company_collection_company');
-- DONE DEALING WITH TABLE company_collection_company [3729239]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE company_collection_hier
CREATE TABLE company_collection_hier
(
	company_collection_id	integer NOT NULL,
	child_company_collection_id	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'company_collection_hier', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE company_collection_hier ADD CONSTRAINT pk_company_collection_hier PRIMARY KEY (company_collection_id, child_company_collection_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xifcomp_coll_comp_coll_id ON company_collection_hier USING btree (company_collection_id);
CREATE INDEX xifcomp_coll_comp_coll_kid_id ON company_collection_hier USING btree (child_company_collection_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK company_collection_hier and company_collection
ALTER TABLE company_collection_hier
	ADD CONSTRAINT fk_comp_coll_comp_coll_id
	FOREIGN KEY (company_collection_id) REFERENCES company_collection(company_collection_id);
-- consider FK company_collection_hier and company_collection
ALTER TABLE company_collection_hier
	ADD CONSTRAINT fk_comp_coll_comp_coll_kid_id
	FOREIGN KEY (child_company_collection_id) REFERENCES company_collection(company_collection_id);

-- TRIGGERS
-- consider NEW oid 3738457
CREATE OR REPLACE FUNCTION jazzhands.company_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	dct	val_company_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	dct
	FROM	val_company_collection_type
	WHERE	company_collection_type =
		(select company_collection_type from company_collection
			where company_collection_id = NEW.company_collection_id);

	IF dct.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Company Collections of type % may not be hierarcical',
			dct.company_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE CONSTRAINT TRIGGER trigger_company_collection_hier_enforce AFTER INSERT OR UPDATE ON company_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE company_collection_hier_enforce();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'company_collection_hier');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'company_collection_hier');
-- DONE DEALING WITH TABLE company_collection_hier [3729249]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE department [3720410]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'department', 'department');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.department DROP CONSTRAINT IF EXISTS fk_dept_badge_type;
ALTER TABLE jazzhands.department DROP CONSTRAINT IF EXISTS fk_dept_company;
ALTER TABLE jazzhands.department DROP CONSTRAINT IF EXISTS fk_dept_mgr_acct_id;
ALTER TABLE jazzhands.department DROP CONSTRAINT IF EXISTS fk_dept_usr_col_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'department');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.department DROP CONSTRAINT IF EXISTS pk_deptid;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_dept_deptcode_companyid";
DROP INDEX IF EXISTS "jazzhands"."xif6department";
DROP INDEX IF EXISTS "jazzhands"."xifdept_badge_type";
DROP INDEX IF EXISTS "jazzhands"."xifdept_company";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.department DROP CONSTRAINT IF EXISTS ckc_is_active_dept;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_department ON jazzhands.department;
DROP TRIGGER IF EXISTS trigger_audit_department ON jazzhands.department;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'department');
---- BEGIN audit.department TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'department', 'department');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'department');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."department_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'department');
---- DONE audit.department TEARDOWN


ALTER TABLE department RENAME TO department_v64;
ALTER TABLE audit.department RENAME TO department_v64;

CREATE TABLE department
(
	account_collection_id	integer NOT NULL,
	company_id	integer NOT NULL,
	manager_account_id	integer  NULL,
	is_active	character(1) NOT NULL,
	dept_code	varchar(30)  NULL,
	cost_center	varchar(10)  NULL,
	cost_center_name	varchar(50)  NULL,
	cost_center_number	integer  NULL,
	default_badge_type_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'department', false);
ALTER TABLE department
	ALTER is_active
	SET DEFAULT 'Y'::bpchar;
INSERT INTO department (
	account_collection_id,
	company_id,
	manager_account_id,
	is_active,
	dept_code,
	cost_center,
	cost_center_name,		-- new column (cost_center_name)
	cost_center_number,		-- new column (cost_center_number)
	default_badge_type_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	account_collection_id,
	company_id,
	manager_account_id,
	is_active,
	dept_code,
	cost_center,
	NULL,		-- new column (cost_center_name)
	NULL,		-- new column (cost_center_number)
	default_badge_type_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM department_v64;

INSERT INTO audit.department (
	account_collection_id,
	company_id,
	manager_account_id,
	is_active,
	dept_code,
	cost_center,
	cost_center_name,		-- new column (cost_center_name)
	cost_center_number,		-- new column (cost_center_number)
	default_badge_type_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	account_collection_id,
	company_id,
	manager_account_id,
	is_active,
	dept_code,
	cost_center,
	NULL,		-- new column (cost_center_name)
	NULL,		-- new column (cost_center_number)
	default_badge_type_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.department_v64;

ALTER TABLE department
	ALTER is_active
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE department ADD CONSTRAINT pk_deptid PRIMARY KEY (account_collection_id);

-- Table/Column Comments
COMMENT ON COLUMN department.cost_center IS 'THIS COLUMN IS DEPRECATED.  It will be removed >= 0.66.  Please use _name and _number.';
-- INDEXES
CREATE INDEX idx_dept_deptcode_companyid ON department USING btree (dept_code, company_id);
CREATE INDEX xif6department ON department USING btree (manager_account_id);
CREATE INDEX xifdept_badge_type ON department USING btree (default_badge_type_id);
CREATE INDEX xifdept_company ON department USING btree (company_id);

-- CHECK CONSTRAINTS
ALTER TABLE department ADD CONSTRAINT ckc_is_active_dept
	CHECK ((is_active = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_active)::text = upper((is_active)::text)));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK department and badge_type
ALTER TABLE department
	ADD CONSTRAINT fk_dept_badge_type
	FOREIGN KEY (default_badge_type_id) REFERENCES badge_type(badge_type_id);
-- consider FK department and company
ALTER TABLE department
	ADD CONSTRAINT fk_dept_company
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK department and account
ALTER TABLE department
	ADD CONSTRAINT fk_dept_mgr_acct_id
	FOREIGN KEY (manager_account_id) REFERENCES account(account_id);
-- consider FK department and account_collection
ALTER TABLE department
	ADD CONSTRAINT fk_dept_usr_col_id
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'department');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'department');
DROP TABLE IF EXISTS department_v64;
DROP TABLE IF EXISTS audit.department_v64;
-- DONE DEALING WITH TABLE department [3729370]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE dns_domain_collection
CREATE TABLE dns_domain_collection
(
	dns_domain_collection_id	integer NOT NULL,
	dns_domain_collection_name	varchar(50) NOT NULL,
	dns_domain_collection_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'dns_domain_collection', true);
ALTER TABLE dns_domain_collection
	ALTER dns_domain_collection_id
	SET DEFAULT nextval('dns_domain_collection_dns_domain_collection_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE dns_domain_collection ADD CONSTRAINT ak_dns_domain_collection_namty UNIQUE (dns_domain_collection_name, dns_domain_collection_type);
ALTER TABLE dns_domain_collection ADD CONSTRAINT pk_dns_domain_collection PRIMARY KEY (dns_domain_collection_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif1dns_domain_collection ON dns_domain_collection USING btree (dns_domain_collection_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK dns_domain_collection and dns_domain_collection_dns_dom
-- Skipping this FK since table does not exist yet
--ALTER TABLE dns_domain_collection_dns_dom
--	ADD CONSTRAINT fk_dns_dom_coll_dns_dom_dns_do
--	FOREIGN KEY (dns_domain_collection_id) REFERENCES dns_domain_collection(dns_domain_collection_id);

-- consider FK dns_domain_collection and dns_domain_collection_hier
-- Skipping this FK since table does not exist yet
--ALTER TABLE dns_domain_collection_hier
--	ADD CONSTRAINT fk_dns_domain_coll_id
--	FOREIGN KEY (dns_domain_collection_id) REFERENCES dns_domain_collection(dns_domain_collection_id);

-- consider FK dns_domain_collection and dns_domain_collection_hier
-- Skipping this FK since table does not exist yet
--ALTER TABLE dns_domain_collection_hier
--	ADD CONSTRAINT fk_dns_domain_coll_id_child
--	FOREIGN KEY (child_dns_domain_collection_id) REFERENCES dns_domain_collection(dns_domain_collection_id);

-- consider FK dns_domain_collection and property
-- Skipping this FK since column does not exist yet
--ALTER TABLE property
--	ADD CONSTRAINT fk_property_dns_dom_collect
--	FOREIGN KEY (dns_domain_collection_id) REFERENCES dns_domain_collection(dns_domain_collection_id);


-- FOREIGN KEYS TO
-- consider FK dns_domain_collection and val_dns_domain_collection_type
ALTER TABLE dns_domain_collection
	ADD CONSTRAINT fk_dns_dom_coll_typ_val
	FOREIGN KEY (dns_domain_collection_type) REFERENCES val_dns_domain_collection_type(dns_domain_collection_type);

-- TRIGGERS
-- consider NEW oid 3738445
CREATE OR REPLACE FUNCTION jazzhands.validate_dns_domain_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.dns_domain_collection_type != NEW.dns_domain_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.dns_domain_collection_type = OLD.dns_domain_collection_type
		AND	p.dns_domain_collection_id = NEW.dns_domain_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'dns_domain_collection % of type % is used by % restricted properties.',
				NEW.dns_domain_collection_id, NEW.dns_domain_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	
END;
$function$
;
CREATE TRIGGER trigger_validate_dns_domain_collection_type_change BEFORE UPDATE OF dns_domain_collection_type ON dns_domain_collection FOR EACH ROW EXECUTE PROCEDURE validate_dns_domain_collection_type_change();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'dns_domain_collection');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'dns_domain_collection');
ALTER SEQUENCE dns_domain_collection_dns_domain_collection_id_seq
	 OWNED BY dns_domain_collection.dns_domain_collection_id;
-- DONE DEALING WITH TABLE dns_domain_collection [3729611]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE dns_domain_collection_dns_dom
CREATE TABLE dns_domain_collection_dns_dom
(
	dns_domain_collection_id	integer NOT NULL,
	dns_domain_id	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'dns_domain_collection_dns_dom', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE dns_domain_collection_dns_dom ADD CONSTRAINT pk_dns_domain_collection_dns_d PRIMARY KEY (dns_domain_collection_id, dns_domain_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif1dns_domain_collection_dns_ ON dns_domain_collection_dns_dom USING btree (dns_domain_id);
CREATE INDEX xif2dns_domain_collection_dns_ ON dns_domain_collection_dns_dom USING btree (dns_domain_collection_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK dns_domain_collection_dns_dom and dns_domain_collection
ALTER TABLE dns_domain_collection_dns_dom
	ADD CONSTRAINT fk_dns_dom_coll_dns_dom_dns_do
	FOREIGN KEY (dns_domain_collection_id) REFERENCES dns_domain_collection(dns_domain_collection_id);
-- consider FK dns_domain_collection_dns_dom and dns_domain
ALTER TABLE dns_domain_collection_dns_dom
	ADD CONSTRAINT fk_dns_dom_coll_dns_domid
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);

-- TRIGGERS
-- consider NEW oid 3738523
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	dct	val_dns_domain_collection_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	dct
	FROM	val_dns_domain_collection_type
	WHERE	dns_domain_collection_type =
		(select dns_domain_collection_type from dns_domain_collection
			where dns_domain_collection_id = NEW.dns_domain_collection_id);

	IF dct.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from dns_domain_collection_dns_dom
		  where dns_domain_collection_id = NEW.dns_domain_collection_id;
		IF tally > dct.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF dct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from dns_domain_collection_dns_dom
		  		inner join dns_domain_collection using (dns_domain_collection_id)
		  where dns_domain_id = NEW.dns_domain_id
		  and	dns_domain_collection_type = dct.dns_domain_collection_type;
		IF tally > dct.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'DNS Domain may not be a member of more than % collections of type %',
				dct.MAX_NUM_COLLECTIONS, dct.dns_domain_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;
CREATE CONSTRAINT TRIGGER trigger_dns_domain_collection_member_enforce AFTER INSERT OR UPDATE ON dns_domain_collection_dns_dom DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE dns_domain_collection_member_enforce();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'dns_domain_collection_dns_dom');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'dns_domain_collection_dns_dom');
-- DONE DEALING WITH TABLE dns_domain_collection_dns_dom [3729623]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE dns_domain_collection_hier
CREATE TABLE dns_domain_collection_hier
(
	dns_domain_collection_id	integer NOT NULL,
	child_dns_domain_collection_id	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'dns_domain_collection_hier', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE dns_domain_collection_hier ADD CONSTRAINT pk_dns_domain_collection_hier PRIMARY KEY (dns_domain_collection_id, child_dns_domain_collection_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif1dns_domain_collection_hier ON dns_domain_collection_hier USING btree (child_dns_domain_collection_id);
CREATE INDEX xif2dns_domain_collection_hier ON dns_domain_collection_hier USING btree (dns_domain_collection_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK dns_domain_collection_hier and dns_domain_collection
ALTER TABLE dns_domain_collection_hier
	ADD CONSTRAINT fk_dns_domain_coll_id
	FOREIGN KEY (dns_domain_collection_id) REFERENCES dns_domain_collection(dns_domain_collection_id);
-- consider FK dns_domain_collection_hier and dns_domain_collection
ALTER TABLE dns_domain_collection_hier
	ADD CONSTRAINT fk_dns_domain_coll_id_child
	FOREIGN KEY (child_dns_domain_collection_id) REFERENCES dns_domain_collection(dns_domain_collection_id);

-- TRIGGERS
-- consider NEW oid 3738520
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	dct	val_dns_domain_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	dct
	FROM	val_dns_domain_collection_type
	WHERE	dns_domain_collection_type =
		(select dns_domain_collection_type from dns_domain_collection
			where dns_domain_collection_id = NEW.dns_domain_collection_id);

	IF dct.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'DNS Domain Collections of type % may not be hierarcical',
			dct.dns_domain_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE CONSTRAINT TRIGGER trigger_dns_domain_collection_hier_enforce AFTER INSERT OR UPDATE ON dns_domain_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE dns_domain_collection_hier_enforce();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'dns_domain_collection_hier');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'dns_domain_collection_hier');
-- DONE DEALING WITH TABLE dns_domain_collection_hier [3729633]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE l2_network_coll_l2_network
CREATE TABLE l2_network_coll_l2_network
(
	layer2_network_collection_id	integer NOT NULL,
	layer2_network_id	integer NOT NULL,
	layer2_network_id_rank	integer  NULL,
	start_date	timestamp without time zone  NULL,
	finish_date	timestamp without time zone  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'l2_network_coll_l2_network', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE l2_network_coll_l2_network ADD CONSTRAINT pk_l2_network_coll_l2_network PRIMARY KEY (layer2_network_collection_id, layer2_network_id);
ALTER TABLE l2_network_coll_l2_network ADD CONSTRAINT xak_l2netcol_l2netrank UNIQUE (layer2_network_collection_id, layer2_network_id_rank);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_l2netcl2net_collid ON l2_network_coll_l2_network USING btree (layer2_network_collection_id);
CREATE INDEX xif_l2netcl2net_l2netid ON l2_network_coll_l2_network USING btree (layer2_network_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK l2_network_coll_l2_network and layer2_network_collection
-- Skipping this FK since table does not exist yet
--ALTER TABLE l2_network_coll_l2_network
--	ADD CONSTRAINT fk_l2netcl2net_collid
--	FOREIGN KEY (layer2_network_collection_id) REFERENCES layer2_network_collection(layer2_network_collection_id);

-- consider FK l2_network_coll_l2_network and layer2_network
ALTER TABLE l2_network_coll_l2_network
	ADD CONSTRAINT fk_l2netcl2net_l2netid
	FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id);

-- TRIGGERS
-- consider NEW oid 3738543
CREATE OR REPLACE FUNCTION jazzhands.layer2_network_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	act	val_layer2_network_coll_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	act
	FROM	val_layer2_network_coll_type
	WHERE	layer2_network_collection_type =
		(select layer2_network_collection_type from layer2_network_collection
			where layer2_network_collection_id = NEW.layer2_network_collection_id);

	IF act.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from l2_network_coll_l2_network
		  where layer2_network_collection_id = NEW.layer2_network_collection_id;
		IF tally > act.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF act.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from l2_network_coll_l2_network
		  		inner join layer2_network_collection using (layer2_network_collection_id)
		  where layer2_network_id = NEW.layer2_network_id
		  and	layer2_network_collection_type = act.layer2_network_collection_type;
		IF tally > act.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Layer2 network may not be a member of more than % collections of type %',
				act.MAX_NUM_COLLECTIONS, act.layer2_network_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;
CREATE CONSTRAINT TRIGGER trigger_layer2_network_collection_member_enforce AFTER INSERT OR UPDATE ON l2_network_coll_l2_network DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE layer2_network_collection_member_enforce();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'l2_network_coll_l2_network');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'l2_network_coll_l2_network');
-- DONE DEALING WITH TABLE l2_network_coll_l2_network [3729792]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE l3_network_coll_l3_network
CREATE TABLE l3_network_coll_l3_network
(
	layer3_network_collection_id	integer NOT NULL,
	layer3_network_id	integer NOT NULL,
	layer3_network_id_rank	integer  NULL,
	start_date	timestamp without time zone  NULL,
	finish_date	timestamp without time zone  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'l3_network_coll_l3_network', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE l3_network_coll_l3_network ADD CONSTRAINT ak_l3netcol_l3netrank UNIQUE (layer3_network_collection_id, layer3_network_id_rank);
ALTER TABLE l3_network_coll_l3_network ADD CONSTRAINT pk_l3_network_coll_l3_network PRIMARY KEY (layer3_network_collection_id, layer3_network_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_l3netcol_l3_net_l3netcolid ON l3_network_coll_l3_network USING btree (layer3_network_collection_id);
CREATE INDEX xif_l3netcol_l3_net_l3netid ON l3_network_coll_l3_network USING btree (layer3_network_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK l3_network_coll_l3_network and layer3_network_collection
-- Skipping this FK since table does not exist yet
--ALTER TABLE l3_network_coll_l3_network
--	ADD CONSTRAINT fk_l3netcol_l3_net_l3netcolid
--	FOREIGN KEY (layer3_network_collection_id) REFERENCES layer3_network_collection(layer3_network_collection_id);

-- consider FK l3_network_coll_l3_network and layer3_network
ALTER TABLE l3_network_coll_l3_network
	ADD CONSTRAINT fk_l3netcol_l3_net_l3netid
	FOREIGN KEY (layer3_network_id) REFERENCES layer3_network(layer3_network_id);

-- TRIGGERS
-- consider NEW oid 3738553
CREATE OR REPLACE FUNCTION jazzhands.layer3_network_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	act	val_layer3_network_coll_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	act
	FROM	val_layer3_network_coll_type
	WHERE	layer3_network_collection_type =
		(select layer3_network_collection_type from layer3_network_collection
			where layer3_network_collection_id = NEW.layer3_network_collection_id);

	IF act.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from l3_network_coll_l3_network
		  where layer3_network_collection_id = NEW.layer3_network_collection_id;
		IF tally > act.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF act.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from l3_network_coll_l3_network
		  		inner join layer3_network_collection using (layer3_network_collection_id)
		  where layer3_network_id = NEW.layer3_network_id
		  and	layer3_network_collection_type = act.layer3_network_collection_type;
		IF tally > act.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Layer3 Network may not be a member of more than % collections of type %',
				act.MAX_NUM_COLLECTIONS, act.layer3_network_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;
CREATE CONSTRAINT TRIGGER trigger_layer3_network_collection_member_enforce AFTER INSERT OR UPDATE ON l3_network_coll_l3_network DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE layer3_network_collection_member_enforce();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'l3_network_coll_l3_network');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'l3_network_coll_l3_network');
-- DONE DEALING WITH TABLE l3_network_coll_l3_network [3729804]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE layer2_network_collection
CREATE TABLE layer2_network_collection
(
	layer2_network_collection_id	integer NOT NULL,
	layer2_network_collection_name	varchar(255) NOT NULL,
	layer2_network_collection_type	varchar(50)  NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'layer2_network_collection', true);
ALTER TABLE layer2_network_collection
	ALTER layer2_network_collection_id
	SET DEFAULT nextval('layer2_network_collection_layer2_network_collection_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE layer2_network_collection ADD CONSTRAINT ak_l2network_coll_name_type UNIQUE (layer2_network_collection_name, layer2_network_collection_type);
ALTER TABLE layer2_network_collection ADD CONSTRAINT pk_layer2_network_collection PRIMARY KEY (layer2_network_collection_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_l2netcoll_type ON layer2_network_collection USING btree (layer2_network_collection_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK layer2_network_collection and layer2_network_collection_hier
-- Skipping this FK since table does not exist yet
--ALTER TABLE layer2_network_collection_hier
--	ADD CONSTRAINT fk_l2net_collhier_chldl2net
--	FOREIGN KEY (child_l2_network_coll_id) REFERENCES layer2_network_collection(layer2_network_collection_id);

-- consider FK layer2_network_collection and layer2_network_collection_hier
-- Skipping this FK since table does not exist yet
--ALTER TABLE layer2_network_collection_hier
--	ADD CONSTRAINT fk_l2net_collhier_l2net
--	FOREIGN KEY (layer2_network_collection_id) REFERENCES layer2_network_collection(layer2_network_collection_id);

-- consider FK layer2_network_collection and l2_network_coll_l2_network
ALTER TABLE l2_network_coll_l2_network
	ADD CONSTRAINT fk_l2netcl2net_collid
	FOREIGN KEY (layer2_network_collection_id) REFERENCES layer2_network_collection(layer2_network_collection_id);
-- consider FK layer2_network_collection and property
-- Skipping this FK since column does not exist yet
--ALTER TABLE property
--	ADD CONSTRAINT fk_prop_l2_netcollid
--	FOREIGN KEY (layer2_network_collection_id) REFERENCES layer2_network_collection(layer2_network_collection_id);


-- FOREIGN KEYS TO
-- consider FK layer2_network_collection and val_layer2_network_coll_type
ALTER TABLE layer2_network_collection
	ADD CONSTRAINT fk_l2netcoll_type
	FOREIGN KEY (layer2_network_collection_type) REFERENCES val_layer2_network_coll_type(layer2_network_collection_type);

-- TRIGGERS
-- consider NEW oid 3738447
CREATE OR REPLACE FUNCTION jazzhands.validate_layer2_network_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.layer2_network_collection_type != NEW.layer2_network_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.layer2_network_collection_type = OLD.layer2_network_collection_type
		AND	p.layer2_network_collection_id = NEW.layer2_network_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'layer2_network_collection % of type % is used by % restricted properties.',
				NEW.layer2_network_collection_id, NEW.layer2_network_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	
END;
$function$
;
CREATE TRIGGER trigger_validate_layer2_network_collection_type_change BEFORE UPDATE OF layer2_network_collection_type ON layer2_network_collection FOR EACH ROW EXECUTE PROCEDURE validate_layer2_network_collection_type_change();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'layer2_network_collection');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'layer2_network_collection');
ALTER SEQUENCE layer2_network_collection_layer2_network_collection_id_seq
	 OWNED BY layer2_network_collection.layer2_network_collection_id;
-- DONE DEALING WITH TABLE layer2_network_collection [3729859]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE layer2_network_collection_hier
CREATE TABLE layer2_network_collection_hier
(
	layer2_network_collection_id	integer NOT NULL,
	child_l2_network_coll_id	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'layer2_network_collection_hier', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE layer2_network_collection_hier ADD CONSTRAINT pk_layer2_network_collection_h PRIMARY KEY (layer2_network_collection_id, child_l2_network_coll_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_l2net_collhier_chldl2net ON layer2_network_collection_hier USING btree (child_l2_network_coll_id);
CREATE INDEX xif_l2net_collhier_l2net ON layer2_network_collection_hier USING btree (layer2_network_collection_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK layer2_network_collection_hier and layer2_network_collection
ALTER TABLE layer2_network_collection_hier
	ADD CONSTRAINT fk_l2net_collhier_chldl2net
	FOREIGN KEY (child_l2_network_coll_id) REFERENCES layer2_network_collection(layer2_network_collection_id);
-- consider FK layer2_network_collection_hier and layer2_network_collection
ALTER TABLE layer2_network_collection_hier
	ADD CONSTRAINT fk_l2net_collhier_l2net
	FOREIGN KEY (layer2_network_collection_id) REFERENCES layer2_network_collection(layer2_network_collection_id);

-- TRIGGERS
-- consider NEW oid 3738540
CREATE OR REPLACE FUNCTION jazzhands.layer2_network_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	act	val_layer2_network_coll_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	act
	FROM	val_layer2_network_coll_type
	WHERE	layer2_network_collection_type =
		(select layer2_network_collection_type from layer2_network_collection
			where layer2_network_collection_id = NEW.layer2_network_collection_id);

	IF act.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Layer2 Network Collections of type % may not be hierarcical',
			act.layer2_network_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE CONSTRAINT TRIGGER trigger_layer2_network_collection_hier_enforce AFTER INSERT OR UPDATE ON layer2_network_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE layer2_network_collection_hier_enforce();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'layer2_network_collection_hier');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'layer2_network_collection_hier');
-- DONE DEALING WITH TABLE layer2_network_collection_hier [3729871]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE layer3_network_collection
CREATE TABLE layer3_network_collection
(
	layer3_network_collection_id	integer NOT NULL,
	layer3_network_collection_name	varchar(255) NOT NULL,
	layer3_network_collection_type	varchar(50)  NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'layer3_network_collection', true);
ALTER TABLE layer3_network_collection
	ALTER layer3_network_collection_id
	SET DEFAULT nextval('layer3_network_collection_layer3_network_collection_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE layer3_network_collection ADD CONSTRAINT ak_l3netcoll_name_type UNIQUE (layer3_network_collection_name, layer3_network_collection_type);
ALTER TABLE layer3_network_collection ADD CONSTRAINT pk_layer3_network_collection PRIMARY KEY (layer3_network_collection_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_l3_netcol_netcol_type ON layer3_network_collection USING btree (layer3_network_collection_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK layer3_network_collection and l3_network_coll_l3_network
ALTER TABLE l3_network_coll_l3_network
	ADD CONSTRAINT fk_l3netcol_l3_net_l3netcolid
	FOREIGN KEY (layer3_network_collection_id) REFERENCES layer3_network_collection(layer3_network_collection_id);
-- consider FK layer3_network_collection and layer3_network_collection_hier
-- Skipping this FK since table does not exist yet
--ALTER TABLE layer3_network_collection_hier
--	ADD CONSTRAINT fk_l3nethier_chld_l3netid
--	FOREIGN KEY (child_l3_network_coll_id) REFERENCES layer3_network_collection(layer3_network_collection_id);

-- consider FK layer3_network_collection and layer3_network_collection_hier
-- Skipping this FK since table does not exist yet
--ALTER TABLE layer3_network_collection_hier
--	ADD CONSTRAINT fk_l3nethierl3netid
--	FOREIGN KEY (layer3_network_collection_id) REFERENCES layer3_network_collection(layer3_network_collection_id);

-- consider FK layer3_network_collection and property
-- Skipping this FK since column does not exist yet
--ALTER TABLE property
--	ADD CONSTRAINT fk_prop_l3_netcoll_id
--	FOREIGN KEY (layer3_network_collection_id) REFERENCES layer3_network_collection(layer3_network_collection_id);


-- FOREIGN KEYS TO
-- consider FK layer3_network_collection and val_layer3_network_coll_type
ALTER TABLE layer3_network_collection
	ADD CONSTRAINT fk_l3_netcol_netcol_type
	FOREIGN KEY (layer3_network_collection_type) REFERENCES val_layer3_network_coll_type(layer3_network_collection_type);

-- TRIGGERS
-- consider NEW oid 3738449
CREATE OR REPLACE FUNCTION jazzhands.validate_layer3_network_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.layer3_network_collection_type != NEW.layer3_network_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.layer3_network_collection_type = OLD.layer3_network_collection_type
		AND	p.layer3_network_collection_id = NEW.layer3_network_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'layer3_network_collection % of type % is used by % restricted properties.',
				NEW.layer3_network_collection_id, NEW.layer3_network_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	
END;
$function$
;
CREATE TRIGGER trigger_validate_layer3_network_collection_type_change BEFORE UPDATE OF layer3_network_collection_type ON layer3_network_collection FOR EACH ROW EXECUTE PROCEDURE validate_layer3_network_collection_type_change();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'layer3_network_collection');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'layer3_network_collection');
ALTER SEQUENCE layer3_network_collection_layer3_network_collection_id_seq
	 OWNED BY layer3_network_collection.layer3_network_collection_id;
-- DONE DEALING WITH TABLE layer3_network_collection [3729899]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE layer3_network_collection_hier
CREATE TABLE layer3_network_collection_hier
(
	layer3_network_collection_id	integer NOT NULL,
	child_l3_network_coll_id	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'layer3_network_collection_hier', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE layer3_network_collection_hier ADD CONSTRAINT pk_layer3_network_collection_h PRIMARY KEY (layer3_network_collection_id, child_l3_network_coll_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_l3nethier_chld_l3netid ON layer3_network_collection_hier USING btree (child_l3_network_coll_id);
CREATE INDEX xif_l3nethierl3netid ON layer3_network_collection_hier USING btree (layer3_network_collection_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK layer3_network_collection_hier and layer3_network_collection
ALTER TABLE layer3_network_collection_hier
	ADD CONSTRAINT fk_l3nethier_chld_l3netid
	FOREIGN KEY (child_l3_network_coll_id) REFERENCES layer3_network_collection(layer3_network_collection_id);
-- consider FK layer3_network_collection_hier and layer3_network_collection
ALTER TABLE layer3_network_collection_hier
	ADD CONSTRAINT fk_l3nethierl3netid
	FOREIGN KEY (layer3_network_collection_id) REFERENCES layer3_network_collection(layer3_network_collection_id);

-- TRIGGERS
-- consider NEW oid 3738550
CREATE OR REPLACE FUNCTION jazzhands.layer3_network_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	act	val_layer3_network_coll_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	act
	FROM	val_layer3_network_coll_type
	WHERE	layer3_network_collection_type =
		(select layer3_network_collection_type from layer3_network_collection
			where layer3_network_collection_id = NEW.layer3_network_collection_id);

	IF act.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Layer3 Network Collections of type % may not be hierarcical',
			act.layer3_network_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE CONSTRAINT TRIGGER trigger_layer3_network_collection_hier_enforce AFTER INSERT OR UPDATE ON layer3_network_collection_hier DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE layer3_network_collection_hier_enforce();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'layer3_network_collection_hier');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'layer3_network_collection_hier');
-- DONE DEALING WITH TABLE layer3_network_collection_hier [3729911]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE logical_port [3720856]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'logical_port', 'logical_port');

-- FOREIGN KEYS FROM
ALTER TABLE layer2_connection DROP CONSTRAINT IF EXISTS fk_l2_conn_l1port;
ALTER TABLE layer2_connection DROP CONSTRAINT IF EXISTS fk_l2_conn_l2port;
ALTER TABLE logical_port_slot DROP CONSTRAINT IF EXISTS fk_lgl_port_slot_lgl_port_id;
ALTER TABLE network_interface DROP CONSTRAINT IF EXISTS fk_net_int_lgl_port_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.logical_port DROP CONSTRAINT IF EXISTS fk_logical_port_lg_port_type;
ALTER TABLE jazzhands.logical_port DROP CONSTRAINT IF EXISTS fk_logical_port_parent_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'logical_port');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.logical_port DROP CONSTRAINT IF EXISTS pk_logical_port;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_logical_port_lg_port_type";
DROP INDEX IF EXISTS "jazzhands"."xif_logical_port_parnet_id";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_logical_port ON jazzhands.logical_port;
DROP TRIGGER IF EXISTS trigger_audit_logical_port ON jazzhands.logical_port;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'logical_port');
---- BEGIN audit.logical_port TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'logical_port', 'logical_port');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'logical_port');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."logical_port_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'logical_port');
---- DONE audit.logical_port TEARDOWN


ALTER TABLE logical_port RENAME TO logical_port_v64;
ALTER TABLE audit.logical_port RENAME TO logical_port_v64;

CREATE TABLE logical_port
(
	logical_port_id	integer NOT NULL,
	logical_port_name	varchar(50) NOT NULL,
	logical_port_type	varchar(50)  NULL,
	parent_logical_port_id	integer  NULL,
	mac_address	macaddr  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'logical_port', false);
ALTER TABLE logical_port
	ALTER logical_port_id
	SET DEFAULT nextval('logical_port_logical_port_id_seq'::regclass);
INSERT INTO logical_port (
	logical_port_id,
	logical_port_name,
	logical_port_type,
	parent_logical_port_id,
	mac_address,		-- new column (mac_address)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	logical_port_id,
	logical_port_name,
	logical_port_type,
	parent_logical_port_id,
	NULL,		-- new column (mac_address)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM logical_port_v64;

INSERT INTO audit.logical_port (
	logical_port_id,
	logical_port_name,
	logical_port_type,
	parent_logical_port_id,
	mac_address,		-- new column (mac_address)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	logical_port_id,
	logical_port_name,
	logical_port_type,
	parent_logical_port_id,
	NULL,		-- new column (mac_address)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.logical_port_v64;

ALTER TABLE logical_port
	ALTER logical_port_id
	SET DEFAULT nextval('logical_port_logical_port_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE logical_port ADD CONSTRAINT pk_logical_port PRIMARY KEY (logical_port_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_logical_port_lg_port_type ON logical_port USING btree (logical_port_type);
CREATE INDEX xif_logical_port_parnet_id ON logical_port USING btree (parent_logical_port_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK logical_port and layer2_connection
ALTER TABLE layer2_connection
	ADD CONSTRAINT fk_l2_conn_l1port
	FOREIGN KEY (logical_port1_id) REFERENCES logical_port(logical_port_id);
-- consider FK logical_port and layer2_connection
ALTER TABLE layer2_connection
	ADD CONSTRAINT fk_l2_conn_l2port
	FOREIGN KEY (logical_port2_id) REFERENCES logical_port(logical_port_id);
-- consider FK logical_port and logical_port_slot
ALTER TABLE logical_port_slot
	ADD CONSTRAINT fk_lgl_port_slot_lgl_port_id
	FOREIGN KEY (logical_port_id) REFERENCES logical_port(logical_port_id);
-- consider FK logical_port and network_interface
ALTER TABLE network_interface
	ADD CONSTRAINT fk_net_int_lgl_port_id
	FOREIGN KEY (logical_port_id) REFERENCES logical_port(logical_port_id);

-- FOREIGN KEYS TO
-- consider FK logical_port and val_logical_port_type
ALTER TABLE logical_port
	ADD CONSTRAINT fk_logical_port_lg_port_type
	FOREIGN KEY (logical_port_type) REFERENCES val_logical_port_type(logical_port_type);
-- consider FK logical_port and logical_port
ALTER TABLE logical_port
	ADD CONSTRAINT fk_logical_port_parent_id
	FOREIGN KEY (parent_logical_port_id) REFERENCES logical_port(logical_port_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'logical_port');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'logical_port');
ALTER SEQUENCE logical_port_logical_port_id_seq
	 OWNED BY logical_port.logical_port_id;
DROP TABLE IF EXISTS logical_port_v64;
DROP TABLE IF EXISTS audit.logical_port_v64;
-- DONE DEALING WITH TABLE logical_port [3729923]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE logical_volume [3720879]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'logical_volume', 'logical_volume');

-- FOREIGN KEYS FROM
ALTER TABLE logical_volume_property DROP CONSTRAINT IF EXISTS fk_lvol_prop_lvid_fstyp;
ALTER TABLE logical_volume_purpose DROP CONSTRAINT IF EXISTS fk_lvpurp_lvid;
ALTER TABLE physicalish_volume DROP CONSTRAINT IF EXISTS fk_physvol_lvid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.logical_volume DROP CONSTRAINT IF EXISTS fk_logvol_device_id;
ALTER TABLE jazzhands.logical_volume DROP CONSTRAINT IF EXISTS fk_logvol_fstype;
ALTER TABLE jazzhands.logical_volume DROP CONSTRAINT IF EXISTS fk_logvol_vgid;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'logical_volume');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.logical_volume DROP CONSTRAINT IF EXISTS ak_logical_volume_filesystem;
ALTER TABLE jazzhands.logical_volume DROP CONSTRAINT IF EXISTS ak_logvol_devid_lvname;
ALTER TABLE jazzhands.logical_volume DROP CONSTRAINT IF EXISTS ak_logvol_lv_devid;
ALTER TABLE jazzhands.logical_volume DROP CONSTRAINT IF EXISTS pk_logical_volume;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_logvol_device_id";
DROP INDEX IF EXISTS "jazzhands"."xif_logvol_fstype";
DROP INDEX IF EXISTS "jazzhands"."xif_logvol_vgid";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_logical_volume ON jazzhands.logical_volume;
DROP TRIGGER IF EXISTS trigger_audit_logical_volume ON jazzhands.logical_volume;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'logical_volume');
---- BEGIN audit.logical_volume TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'logical_volume', 'logical_volume');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'logical_volume');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."logical_volume_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'logical_volume');
---- DONE audit.logical_volume TEARDOWN


ALTER TABLE logical_volume RENAME TO logical_volume_v64;
ALTER TABLE audit.logical_volume RENAME TO logical_volume_v64;

CREATE TABLE logical_volume
(
	logical_volume_id	integer NOT NULL,
	logical_volume_name	varchar(50) NOT NULL,
	logical_volume_type	varchar(50) NOT NULL,
	volume_group_id	integer NOT NULL,
	device_id	integer NOT NULL,
	logical_volume_size_in_bytes	bigint NOT NULL,
	logical_volume_offset_in_bytes	bigint  NULL,
	filesystem_type	varchar(50) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'logical_volume', false);
ALTER TABLE logical_volume
	ALTER logical_volume_id
	SET DEFAULT nextval('logical_volume_logical_volume_id_seq'::regclass);
ALTER TABLE logical_volume
	ALTER logical_volume_type
	SET DEFAULT 'legacy'::character varying;
INSERT INTO logical_volume (
	logical_volume_id,
	logical_volume_name,
	logical_volume_type,		-- new column (logical_volume_type)
	volume_group_id,
	device_id,
	logical_volume_size_in_bytes,
	logical_volume_offset_in_bytes,
	filesystem_type,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	logical_volume_id,
	logical_volume_name,
	'legacy'::character varying,		-- new column (logical_volume_type)
	volume_group_id,
	device_id,
	logical_volume_size_in_bytes,
	logical_volume_offset_in_bytes,
	filesystem_type,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM logical_volume_v64;

INSERT INTO audit.logical_volume (
	logical_volume_id,
	logical_volume_name,
	logical_volume_type,		-- new column (logical_volume_type)
	volume_group_id,
	device_id,
	logical_volume_size_in_bytes,
	logical_volume_offset_in_bytes,
	filesystem_type,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	logical_volume_id,
	logical_volume_name,
	'legacy',		-- new column (logical_volume_type)
	volume_group_id,
	device_id,
	logical_volume_size_in_bytes,
	logical_volume_offset_in_bytes,
	filesystem_type,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.logical_volume_v64;

ALTER TABLE logical_volume
	ALTER logical_volume_id
	SET DEFAULT nextval('logical_volume_logical_volume_id_seq'::regclass);
ALTER TABLE logical_volume
	ALTER logical_volume_type
	SET DEFAULT 'legacy'::character varying;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE logical_volume ADD CONSTRAINT ak_logical_volume_filesystem UNIQUE (logical_volume_id, filesystem_type);
ALTER TABLE logical_volume ADD CONSTRAINT ak_logvol_devid_lvname UNIQUE (device_id, logical_volume_name, logical_volume_type);
ALTER TABLE logical_volume ADD CONSTRAINT ak_logvol_lv_devid UNIQUE (logical_volume_id);
ALTER TABLE logical_volume ADD CONSTRAINT pk_logical_volume PRIMARY KEY (logical_volume_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif5logical_volume ON logical_volume USING btree (logical_volume_type);
CREATE INDEX xif_logvol_device_id ON logical_volume USING btree (device_id);
CREATE INDEX xif_logvol_fstype ON logical_volume USING btree (filesystem_type);
CREATE INDEX xif_logvol_vgid ON logical_volume USING btree (volume_group_id, device_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK logical_volume and logical_volume_property
ALTER TABLE logical_volume_property
	ADD CONSTRAINT fk_lvol_prop_lvid_fstyp
	FOREIGN KEY (logical_volume_id, filesystem_type) REFERENCES logical_volume(logical_volume_id, filesystem_type) DEFERRABLE;
-- consider FK logical_volume and logical_volume_purpose
ALTER TABLE logical_volume_purpose
	ADD CONSTRAINT fk_lvpurp_lvid
	FOREIGN KEY (logical_volume_id) REFERENCES logical_volume(logical_volume_id) DEFERRABLE;
-- consider FK logical_volume and physicalish_volume
ALTER TABLE physicalish_volume
	ADD CONSTRAINT fk_physvol_lvid
	FOREIGN KEY (logical_volume_id) REFERENCES logical_volume(logical_volume_id) DEFERRABLE;

-- FOREIGN KEYS TO
-- consider FK logical_volume and val_logical_volume_type
ALTER TABLE logical_volume
	ADD CONSTRAINT fk_log_volume_log_vol_type
	FOREIGN KEY (logical_volume_type) REFERENCES val_logical_volume_type(logical_volume_type);
-- consider FK logical_volume and device
ALTER TABLE logical_volume
	ADD CONSTRAINT fk_logvol_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id) DEFERRABLE;
-- consider FK logical_volume and val_filesystem_type
ALTER TABLE logical_volume
	ADD CONSTRAINT fk_logvol_fstype
	FOREIGN KEY (filesystem_type) REFERENCES val_filesystem_type(filesystem_type) DEFERRABLE;
-- consider FK logical_volume and volume_group
ALTER TABLE logical_volume
	ADD CONSTRAINT fk_logvol_vgid
	FOREIGN KEY (volume_group_id, device_id) REFERENCES volume_group(volume_group_id, device_id) DEFERRABLE;

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'logical_volume');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'logical_volume');
ALTER SEQUENCE logical_volume_logical_volume_id_seq
	 OWNED BY logical_volume.logical_volume_id;
DROP TABLE IF EXISTS logical_volume_v64;
DROP TABLE IF EXISTS audit.logical_volume_v64;
-- DONE DEALING WITH TABLE logical_volume [3729946]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE logical_volume_property [3720899]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'logical_volume_property', 'logical_volume_property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.logical_volume_property DROP CONSTRAINT IF EXISTS fk_lvol_prop_lvid_fstyp;
ALTER TABLE jazzhands.logical_volume_property DROP CONSTRAINT IF EXISTS fk_lvol_prop_lvpn_fsty;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'logical_volume_property');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.logical_volume_property DROP CONSTRAINT IF EXISTS ak_logical_vol_prop_fs_lv_name;
ALTER TABLE jazzhands.logical_volume_property DROP CONSTRAINT IF EXISTS pk_logical_volume_property;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_lvol_prop_lvid_fstyp";
DROP INDEX IF EXISTS "jazzhands"."xif_lvol_prop_lvpn_fsty";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_logical_volume_property ON jazzhands.logical_volume_property;
DROP TRIGGER IF EXISTS trigger_audit_logical_volume_property ON jazzhands.logical_volume_property;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'logical_volume_property');
---- BEGIN audit.logical_volume_property TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'logical_volume_property', 'logical_volume_property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'logical_volume_property');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."logical_volume_property_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'logical_volume_property');
---- DONE audit.logical_volume_property TEARDOWN


ALTER TABLE logical_volume_property RENAME TO logical_volume_property_v64;
ALTER TABLE audit.logical_volume_property RENAME TO logical_volume_property_v64;

CREATE TABLE logical_volume_property
(
	logical_volume_property_id	integer NOT NULL,
	logical_volume_id	integer  NULL,
	logical_volume_type	varchar(50)  NULL,
	logical_volume_purpose	varchar(50)  NULL,
	filesystem_type	varchar(50)  NULL,
	logical_volume_property_name	varchar(50)  NULL,
	logical_volume_property_value	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'logical_volume_property', false);
ALTER TABLE logical_volume_property
	ALTER logical_volume_property_id
	SET DEFAULT nextval('logical_volume_property_logical_volume_property_id_seq'::regclass);
INSERT INTO logical_volume_property (
	logical_volume_property_id,
	logical_volume_id,
	logical_volume_type,		-- new column (logical_volume_type)
	logical_volume_purpose,		-- new column (logical_volume_purpose)
	filesystem_type,
	logical_volume_property_name,
	logical_volume_property_value,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	logical_volume_property_id,
	logical_volume_id,
	'legacy',		-- new column (logical_volume_type)
	NULL,		-- new column (logical_volume_purpose)
	filesystem_type,
	logical_volume_property_name,
	logical_volume_property_value,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM logical_volume_property_v64;

INSERT INTO audit.logical_volume_property (
	logical_volume_property_id,
	logical_volume_id,
	logical_volume_type,		-- new column (logical_volume_type)
	logical_volume_purpose,		-- new column (logical_volume_purpose)
	filesystem_type,
	logical_volume_property_name,
	logical_volume_property_value,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	logical_volume_property_id,
	logical_volume_id,
	'legacy',		-- new column (logical_volume_type)
	NULL,		-- new column (logical_volume_purpose)
	filesystem_type,
	logical_volume_property_name,
	logical_volume_property_value,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.logical_volume_property_v64;

ALTER TABLE logical_volume_property
	ALTER logical_volume_property_id
	SET DEFAULT nextval('logical_volume_property_logical_volume_property_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE logical_volume_property ADD CONSTRAINT ak_logical_vol_prop_fs_lv_name UNIQUE (logical_volume_id, logical_volume_property_name);
ALTER TABLE logical_volume_property ADD CONSTRAINT pk_logical_volume_property PRIMARY KEY (logical_volume_property_id);

-- Table/Column Comments
COMMENT ON COLUMN logical_volume_property.filesystem_type IS 'THIS COLUMN IS DEPRECATED AND WILL BE REMOVED >= 0.66';
-- INDEXES
CREATE INDEX xif_lvol_prop_lvid_fstyp ON logical_volume_property USING btree (logical_volume_id, filesystem_type);
CREATE INDEX xif_lvol_prop_lvpn_fsty ON logical_volume_property USING btree (logical_volume_property_name, filesystem_type);
CREATE INDEX xif_lvprop_purpose ON logical_volume_property USING btree (logical_volume_purpose);
CREATE INDEX xif_lvprop_type ON logical_volume_property USING btree (logical_volume_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK logical_volume_property and logical_volume
ALTER TABLE logical_volume_property
	ADD CONSTRAINT fk_lvol_prop_lvid_fstyp
	FOREIGN KEY (logical_volume_id, filesystem_type) REFERENCES logical_volume(logical_volume_id, filesystem_type) DEFERRABLE;
-- consider FK logical_volume_property and val_logical_volume_property
ALTER TABLE logical_volume_property
	ADD CONSTRAINT fk_lvol_prop_lvpn_fsty
	FOREIGN KEY (logical_volume_property_name, filesystem_type) REFERENCES val_logical_volume_property(logical_volume_property_name, filesystem_type) DEFERRABLE;
-- consider FK logical_volume_property and val_logical_volume_purpose
ALTER TABLE logical_volume_property
	ADD CONSTRAINT fk_lvprop_purpose
	FOREIGN KEY (logical_volume_purpose) REFERENCES val_logical_volume_purpose(logical_volume_purpose);
-- consider FK logical_volume_property and val_logical_volume_type
ALTER TABLE logical_volume_property
	ADD CONSTRAINT fk_lvprop_type
	FOREIGN KEY (logical_volume_type) REFERENCES val_logical_volume_type(logical_volume_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'logical_volume_property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'logical_volume_property');
ALTER SEQUENCE logical_volume_property_logical_volume_property_id_seq
	 OWNED BY logical_volume_property.logical_volume_property_id;
DROP TABLE IF EXISTS logical_volume_property_v64;
DROP TABLE IF EXISTS audit.logical_volume_property_v64;
-- DONE DEALING WITH TABLE logical_volume_property [3729968]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE network_range [3721054]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'network_range', 'network_range');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.network_range DROP CONSTRAINT IF EXISTS fk_net_range_dns_domain_id;
ALTER TABLE jazzhands.network_range DROP CONSTRAINT IF EXISTS fk_net_range_start_netblock;
ALTER TABLE jazzhands.network_range DROP CONSTRAINT IF EXISTS fk_net_range_stop_netblock;
ALTER TABLE jazzhands.network_range DROP CONSTRAINT IF EXISTS fk_netrng_netrng_typ;
ALTER TABLE jazzhands.network_range DROP CONSTRAINT IF EXISTS fk_netrng_prngnblkid;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'network_range');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.network_range DROP CONSTRAINT IF EXISTS pk_network_range;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_netrng_dnsdomainid";
DROP INDEX IF EXISTS "jazzhands"."xif_netrng_netrng_typ";
DROP INDEX IF EXISTS "jazzhands"."xif_netrng_prngnblkid";
DROP INDEX IF EXISTS "jazzhands"."xif_netrng_startnetblk";
DROP INDEX IF EXISTS "jazzhands"."xif_netrng_stopnetblk";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_network_range ON jazzhands.network_range;
DROP TRIGGER IF EXISTS trigger_audit_network_range ON jazzhands.network_range;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'network_range');
---- BEGIN audit.network_range TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'network_range', 'network_range');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'network_range');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."network_range_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'network_range');
---- DONE audit.network_range TEARDOWN


ALTER TABLE network_range RENAME TO network_range_v64;
ALTER TABLE audit.network_range RENAME TO network_range_v64;

CREATE TABLE network_range
(
	network_range_id	integer NOT NULL,
	network_range_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	parent_netblock_id	integer NOT NULL,
	start_netblock_id	integer NOT NULL,
	stop_netblock_id	integer NOT NULL,
	dns_prefix	varchar(255)  NULL,
	dns_domain_id	integer  NULL,
	lease_time	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'network_range', false);
ALTER TABLE network_range
	ALTER network_range_id
	SET DEFAULT nextval('network_range_network_range_id_seq'::regclass);
INSERT INTO network_range (
	network_range_id,
	network_range_type,
	description,
	parent_netblock_id,
	start_netblock_id,
	stop_netblock_id,
	dns_prefix,
	dns_domain_id,
	lease_time,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	network_range_id,
	network_range_type,
	description,
	parent_netblock_id,
	start_netblock_id,
	stop_netblock_id,
	dns_prefix,
	dns_domain_id,
	lease_time,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM network_range_v64;

INSERT INTO audit.network_range (
	network_range_id,
	network_range_type,
	description,
	parent_netblock_id,
	start_netblock_id,
	stop_netblock_id,
	dns_prefix,
	dns_domain_id,
	lease_time,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	network_range_id,
	network_range_type,
	description,
	parent_netblock_id,
	start_netblock_id,
	stop_netblock_id,
	dns_prefix,
	dns_domain_id,
	lease_time,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.network_range_v64;

ALTER TABLE network_range
	ALTER network_range_id
	SET DEFAULT nextval('network_range_network_range_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE network_range ADD CONSTRAINT pk_network_range PRIMARY KEY (network_range_id);

-- Table/Column Comments
COMMENT ON COLUMN network_range.parent_netblock_id IS 'The netblock where the range appears.  This can be of a different type than start/stop netblocks, but start/stop need to be within the parent.';
-- INDEXES
CREATE INDEX xif_netrng_dnsdomainid ON network_range USING btree (dns_domain_id);
CREATE INDEX xif_netrng_netrng_typ ON network_range USING btree (network_range_type);
CREATE INDEX xif_netrng_prngnblkid ON network_range USING btree (parent_netblock_id);
CREATE INDEX xif_netrng_startnetblk ON network_range USING btree (start_netblock_id);
CREATE INDEX xif_netrng_stopnetblk ON network_range USING btree (stop_netblock_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK network_range and dns_domain
ALTER TABLE network_range
	ADD CONSTRAINT fk_net_range_dns_domain_id
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);
-- consider FK network_range and netblock
ALTER TABLE network_range
	ADD CONSTRAINT fk_net_range_start_netblock
	FOREIGN KEY (start_netblock_id) REFERENCES netblock(netblock_id);
-- consider FK network_range and netblock
ALTER TABLE network_range
	ADD CONSTRAINT fk_net_range_stop_netblock
	FOREIGN KEY (stop_netblock_id) REFERENCES netblock(netblock_id);
-- consider FK network_range and val_network_range_type
ALTER TABLE network_range
	ADD CONSTRAINT fk_netrng_netrng_typ
	FOREIGN KEY (network_range_type) REFERENCES val_network_range_type(network_range_type);
-- consider FK network_range and netblock
ALTER TABLE network_range
	ADD CONSTRAINT fk_netrng_prngnblkid
	FOREIGN KEY (parent_netblock_id) REFERENCES netblock(netblock_id);

-- TRIGGERS
-- consider NEW oid 3738591
CREATE OR REPLACE FUNCTION jazzhands.validate_network_range()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	v_nrt	val_network_range_type%ROWTYPE;
BEGIN
	SELECT	*
	INTO	v_nrt
	FROM	val_network_range_type
	WHERE	network_range_type = NEW.network_range_type;

	IF NEW.dns_domain_id IS NULL AND v_nrt.dns_domain_required = 'REQUIRED' THEN
		RAISE EXCEPTION 'For type %, dns_domain_id is required.',
			NEW.network_range_type
			USING ERRCODE = 'not_null_violation';
	ELSIF NEW.dns_domain_id IS NOT NULL AND
			v_nrt.dns_domain_required = 'PROHIBITED' THEN
		RAISE EXCEPTION 'For type %, dns_domain_id is prohibited.',
			NEW.network_range_type
			USING ERRCODE = 'not_null_violation';
	END IF;

END; $function$
;
CREATE TRIGGER trigger_validate_network_range BEFORE INSERT OR UPDATE OF dns_domain_id ON network_range FOR EACH ROW EXECUTE PROCEDURE validate_network_range();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'network_range');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'network_range');
ALTER SEQUENCE network_range_network_range_id_seq
	 OWNED BY network_range.network_range_id;
DROP TABLE IF EXISTS network_range_v64;
DROP TABLE IF EXISTS audit.network_range_v64;
-- DONE DEALING WITH TABLE network_range [3730125]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE person_company_attr
CREATE TABLE person_company_attr
(
	company_id	integer NOT NULL,
	person_id	integer NOT NULL,
	person_company_attr_name	integer  NULL,
	attribute_value	varchar(50)  NULL,
	attribute_value_timestamp	timestamp with time zone  NULL,
	attribute_value_person_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'person_company_attr', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE person_company_attr ADD CONSTRAINT ak_person_company_attr_name UNIQUE (company_id, person_id, person_company_attr_name);
ALTER TABLE person_company_attr ADD CONSTRAINT pk_person_company_attr PRIMARY KEY (company_id, person_id);

-- Table/Column Comments
COMMENT ON COLUMN person_company_attr.attribute_value IS 'string value of the attribute.';
COMMENT ON COLUMN person_company_attr.attribute_value_person_id IS 'person_id value of the attribute.';
-- INDEXES
CREATE INDEX xif2person_company_attr ON person_company_attr USING btree (attribute_value_person_id);
CREATE INDEX xif3person_company_attr ON person_company_attr USING btree (person_company_attr_name);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK person_company_attr and person_company
ALTER TABLE person_company_attr
	ADD CONSTRAINT fk_pers_comp_attr_person_comp_
	FOREIGN KEY (company_id, person_id) REFERENCES person_company(company_id, person_id);
-- consider FK person_company_attr and person
ALTER TABLE person_company_attr
	ADD CONSTRAINT fk_person_comp_att_pers_person
	FOREIGN KEY (attribute_value_person_id) REFERENCES person(person_id);
-- consider FK person_company_attr and val_person_company_attr_name
ALTER TABLE person_company_attr
	ADD CONSTRAINT fk_person_comp_attr_val_name
	FOREIGN KEY (person_company_attr_name) REFERENCES val_person_company_attr_name(person_company_attr_name);

-- TRIGGERS
-- consider NEW oid 3738640
CREATE OR REPLACE FUNCTION jazzhands.validate_pers_company_attr()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally			integer;
	v_pc_atr		val_person_company_attr_name%ROWTYPE;
	v_listvalue		Property.Property_Value%TYPE;
BEGIN

	SELECT	*
	INTO	v_pc_atr
	FROM	val_person_company_attr_name
	WHERE	person_company_attr_name = NEW.person_company_attr_name;

	IF v_pc_atr.person_company_attr_data_type IN
			('boolean', 'number', 'string', 'list') THEN
		IF NEW.attribute_value IS NULL THEN
			RAISE EXCEPTION 'attribute_value must be set for %',
				v_pc_atr.person_company_attr_data_type
				USING ERRCODE = 'not_null_violation';
		END IF;
		IF v_pc_atr.person_company_attr_data_type = 'boolean' THEN
			IF NEW.attribute_value NOT IN ('Y', 'N') THEN
				RAISE EXCEPTION 'attribute_value must be boolean (Y,N)'
					USING ERRCODE = 'integrity_constraint_violation';
			END IF;
		ELSIF v_pc_atr.person_company_attr_data_type = 'number' THEN
			IF NEW.attribute_value !~ '^-?(\d*\.?\d*){1}$' THEN
				RAISE EXCEPTION 'attribute_value must be a number'
					USING ERRCODE = 'integrity_constraint_violation';
			END IF;
		ELSIF v_pc_atr.person_company_attr_data_type = 'timestamp' THEN
			IF NEW.attribute_value_timestamp IS NULL THEN
				RAISE EXCEPTION 'attribute_value_timestamp must be set for %',
					v_pc_atr.person_company_attr_data_type
					USING ERRCODE = 'not_null_violation';
			END IF;
		ELSIF v_pc_atr.person_company_attr_data_type = 'list' THEN
			PERFORM 1
			FROM	val_person_company_attr_value
			WHERE	(person_company_attr_name,person_company_attr_value)
					IN
					(NEW.person_company_attr_name,NEW.person_company_attr_value)
			;
			IF NOT FOUND THEN
				RAISE EXCEPTION 'attribute_value must be valid'
					USING ERRCODE = 'integrity_constraint_violation';
			END IF;
		END IF;
	ELSIF v_pc_atr.person_company_attr_data_type = 'person_id' THEN
		IF NEW.attribute_value_timestamp IS NULL THEN
			RAISE EXCEPTION 'attribute_value_timestamp must be set for %',
				v_pc_atr.person_company_attr_data_type
				USING ERRCODE = 'not_null_violation';
		END IF;
	END IF;

	IF NEW.attribute_value IS NOT NULL AND
			(NEW.attribute_value_person_id IS NOT NULL OR
			NEW.attribute_value_timestamp IS NOT NULL) THEN
		RAISE EXCEPTION 'only one attribute_value may be set'
			USING ERRCODE = 'integrity_constraint_violation';
	ELSIF NEW.ttribute_value_person_id IS NOT NULL AND
			(NEW.attribute_value IS NOT NULL OR
			NEW.attribute_value_timestamp IS NOT NULL) THEN
		RAISE EXCEPTION 'only one attribute_value may be set'
			USING ERRCODE = 'integrity_constraint_violation';
	ELSIF NEW.attribute_value_timestamp IS NOT NULL AND
			(NEW.attribute_value_person_id IS NOT NULL OR
			NEW.attribute_value IS NOT NULL) THEN
		RAISE EXCEPTION 'only one attribute_value may be set'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;
	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_validate_pers_company_attr BEFORE INSERT OR UPDATE ON person_company_attr FOR EACH ROW EXECUTE PROCEDURE validate_pers_company_attr();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'person_company_attr');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'person_company_attr');
-- DONE DEALING WITH TABLE person_company_attr [3730246]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE physical_address [3721279]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'physical_address', 'physical_address');

-- FOREIGN KEYS FROM
ALTER TABLE person_location DROP CONSTRAINT IF EXISTS fk_persloc_physaddrid;
ALTER TABLE site DROP CONSTRAINT IF EXISTS fk_site_physaddr_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.physical_address DROP CONSTRAINT IF EXISTS fk_physaddr_company_id;
ALTER TABLE jazzhands.physical_address DROP CONSTRAINT IF EXISTS fk_physaddr_iso_cc;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'physical_address');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.physical_address DROP CONSTRAINT IF EXISTS ak_physaddr_compid_siterk;
ALTER TABLE jazzhands.physical_address DROP CONSTRAINT IF EXISTS pk_val_office_site;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1physical_address";
DROP INDEX IF EXISTS "jazzhands"."xif2physical_address";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_physical_address ON jazzhands.physical_address;
DROP TRIGGER IF EXISTS trigger_audit_physical_address ON jazzhands.physical_address;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'physical_address');
---- BEGIN audit.physical_address TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'physical_address', 'physical_address');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'physical_address');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."physical_address_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'physical_address');
---- DONE audit.physical_address TEARDOWN


ALTER TABLE physical_address RENAME TO physical_address_v64;
ALTER TABLE audit.physical_address RENAME TO physical_address_v64;

CREATE TABLE physical_address
(
	physical_address_id	integer NOT NULL,
	physical_address_type	varchar(50)  NULL,
	company_id	integer  NULL,
	site_rank	integer  NULL,
	description	varchar(4000)  NULL,
	display_label	varchar(100)  NULL,
	address_agent	varchar(100)  NULL,
	address_housename	varchar(255)  NULL,
	address_street	varchar(255)  NULL,
	address_building	varchar(255)  NULL,
	address_pobox	varchar(255)  NULL,
	address_neighborhood	varchar(255)  NULL,
	address_city	varchar(100)  NULL,
	address_subregion	character(18)  NULL,
	address_region	varchar(100)  NULL,
	postal_code	varchar(20)  NULL,
	iso_country_code	character(2) NOT NULL,
	address_freeform	varchar(50)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'physical_address', false);
ALTER TABLE physical_address
	ALTER physical_address_id
	SET DEFAULT nextval('physical_address_physical_address_id_seq'::regclass);
ALTER TABLE physical_address
	ALTER physical_address_type
	SET DEFAULT 'location'::character varying;
INSERT INTO physical_address (
	physical_address_id,
	physical_address_type,		-- new column (physical_address_type)
	company_id,
	site_rank,
	description,
	display_label,
	address_agent,
	address_housename,
	address_street,
	address_building,
	address_pobox,
	address_neighborhood,
	address_city,
	address_subregion,
	address_region,
	postal_code,
	iso_country_code,
	address_freeform,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	physical_address_id,
	'location'::character varying,		-- new column (physical_address_type)
	company_id,
	site_rank,
	description,
	display_label,
	address_agent,
	address_housename,
	address_street,
	address_building,
	address_pobox,
	address_neighborhood,
	address_city,
	address_subregion,
	address_region,
	postal_code,
	iso_country_code,
	address_freeform,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM physical_address_v64;

INSERT INTO audit.physical_address (
	physical_address_id,
	physical_address_type,		-- new column (physical_address_type)
	company_id,
	site_rank,
	description,
	display_label,
	address_agent,
	address_housename,
	address_street,
	address_building,
	address_pobox,
	address_neighborhood,
	address_city,
	address_subregion,
	address_region,
	postal_code,
	iso_country_code,
	address_freeform,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	physical_address_id,
	NULL,		-- new column (physical_address_type)
	company_id,
	site_rank,
	description,
	display_label,
	address_agent,
	address_housename,
	address_street,
	address_building,
	address_pobox,
	address_neighborhood,
	address_city,
	address_subregion,
	address_region,
	postal_code,
	iso_country_code,
	address_freeform,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.physical_address_v64;

ALTER TABLE physical_address
	ALTER physical_address_id
	SET DEFAULT nextval('physical_address_physical_address_id_seq'::regclass);
ALTER TABLE physical_address
	ALTER physical_address_type
	SET DEFAULT 'location'::character varying;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE physical_address ADD CONSTRAINT pk_val_office_site PRIMARY KEY (physical_address_id);
ALTER TABLE physical_address ADD CONSTRAINT uq_physaddr_compid_siterk UNIQUE (company_id, site_rank);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_physaddr_company_id ON physical_address USING btree (company_id);
CREATE INDEX xif_physaddr_iso_cc ON physical_address USING btree (iso_country_code);
CREATE INDEX xif_physaddr_type_val ON physical_address USING btree (physical_address_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK physical_address and person_location
ALTER TABLE person_location
	ADD CONSTRAINT fk_persloc_physaddrid
	FOREIGN KEY (physical_address_id) REFERENCES physical_address(physical_address_id);
-- consider FK physical_address and site
ALTER TABLE site
	ADD CONSTRAINT fk_site_physaddr_id
	FOREIGN KEY (physical_address_id) REFERENCES physical_address(physical_address_id);

-- FOREIGN KEYS TO
-- consider FK physical_address and company
ALTER TABLE physical_address
	ADD CONSTRAINT fk_physaddr_company_id
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK physical_address and val_country_code
ALTER TABLE physical_address
	ADD CONSTRAINT fk_physaddr_iso_cc
	FOREIGN KEY (iso_country_code) REFERENCES val_country_code(iso_country_code);
-- consider FK physical_address and val_physical_address_type
ALTER TABLE physical_address
	ADD CONSTRAINT fk_physaddr_type_val
	FOREIGN KEY (physical_address_type) REFERENCES val_physical_address_type(physical_address_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'physical_address');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'physical_address');
ALTER SEQUENCE physical_address_physical_address_id_seq
	 OWNED BY physical_address.physical_address_id;
DROP TABLE IF EXISTS physical_address_v64;
DROP TABLE IF EXISTS audit.physical_address_v64;
-- DONE DEALING WITH TABLE physical_address [3730362]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE property [3721329]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'property', 'property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_l2netid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_l3netid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_os_snapshot;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_pv_devcolid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_svc_env_coll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_acct_col;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_acctid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_acctrealmid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_compid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_devcolid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_dnsdomid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_nblk_coll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_nmtyp;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_osid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_person_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_prop_coll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pv_nblkcol_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_acct_colid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_compid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_dnsdomid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_pwdtyp;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_swpkgid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_tokcolid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_site_code;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_val_prsnid;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'property');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS pk_property;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif17property";
DROP INDEX IF EXISTS "jazzhands"."xif18property";
DROP INDEX IF EXISTS "jazzhands"."xif19property";
DROP INDEX IF EXISTS "jazzhands"."xif20property";
DROP INDEX IF EXISTS "jazzhands"."xif21property";
DROP INDEX IF EXISTS "jazzhands"."xif22property";
DROP INDEX IF EXISTS "jazzhands"."xif23property";
DROP INDEX IF EXISTS "jazzhands"."xif24property";
DROP INDEX IF EXISTS "jazzhands"."xif25property";
DROP INDEX IF EXISTS "jazzhands"."xif_prop_os_snapshot";
DROP INDEX IF EXISTS "jazzhands"."xif_prop_pv_devcolid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_account_id";
DROP INDEX IF EXISTS "jazzhands"."xifprop_acctcol_id";
DROP INDEX IF EXISTS "jazzhands"."xifprop_compid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_devcolid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_dnsdomid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_nmtyp";
DROP INDEX IF EXISTS "jazzhands"."xifprop_osid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_acct_colid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_compid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_dnsdomid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_pwdtyp";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_swpkgid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_tokcolid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_site_code";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS ckc_prop_isenbld;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_property ON jazzhands.property;
DROP TRIGGER IF EXISTS trigger_audit_property ON jazzhands.property;
DROP TRIGGER IF EXISTS trigger_validate_property ON jazzhands.property;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'property');
---- BEGIN audit.property TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'property', 'property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'property');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."property_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'property');
---- DONE audit.property TEARDOWN


ALTER TABLE property RENAME TO property_v64;
ALTER TABLE audit.property RENAME TO property_v64;

CREATE TABLE property
(
	property_id	integer NOT NULL,
	account_collection_id	integer  NULL,
	account_id	integer  NULL,
	account_realm_id	integer  NULL,
	company_collection_id	integer  NULL,
	company_id	integer  NULL,
	device_collection_id	integer  NULL,
	dns_domain_collection_id	integer  NULL,
	dns_domain_id	integer  NULL,
	layer2_network_collection_id	integer  NULL,
	layer3_network_collection_id	integer  NULL,
	netblock_collection_id	integer  NULL,
	operating_system_id	integer  NULL,
	operating_system_snapshot_id	integer  NULL,
	person_id	integer  NULL,
	property_collection_id	integer  NULL,
	service_env_collection_id	integer  NULL,
	site_code	varchar(50)  NULL,
	property_name	varchar(255) NOT NULL,
	property_type	varchar(50) NOT NULL,
	property_value	varchar(1024)  NULL,
	property_value_timestamp	timestamp without time zone  NULL,
	property_value_company_id	integer  NULL,
	property_value_account_coll_id	integer  NULL,
	property_value_device_coll_id	integer  NULL,
	property_value_nblk_coll_id	integer  NULL,
	property_value_password_type	varchar(50)  NULL,
	property_value_person_id	integer  NULL,
	property_value_sw_package_id	integer  NULL,
	property_value_token_col_id	integer  NULL,
	property_rank	integer  NULL,
	start_date	timestamp without time zone  NULL,
	finish_date	timestamp without time zone  NULL,
	is_enabled	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'property', false);
ALTER TABLE property
	ALTER property_id
	SET DEFAULT nextval('property_property_id_seq'::regclass);
ALTER TABLE property
	ALTER is_enabled
	SET DEFAULT 'Y'::bpchar;
INSERT INTO property (
	property_id,
	account_collection_id,
	account_id,
	account_realm_id,
	company_collection_id,		-- new column (company_collection_id)
	company_id,
	device_collection_id,
	dns_domain_collection_id,		-- new column (dns_domain_collection_id)
	dns_domain_id,
	layer2_network_collection_id,		-- new column (layer2_network_collection_id)
	layer3_network_collection_id,		-- new column (layer3_network_collection_id)
	netblock_collection_id,
	operating_system_id,
	operating_system_snapshot_id,
	person_id,
	property_collection_id,
	service_env_collection_id,
	site_code,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_device_coll_id,
	property_value_nblk_coll_id,
	property_value_password_type,
	property_value_person_id,
	property_value_sw_package_id,
	property_value_token_col_id,
	property_rank,
	start_date,
	finish_date,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	property_id,
	account_collection_id,
	account_id,
	account_realm_id,
	NULL,		-- new column (company_collection_id)
	company_id,
	device_collection_id,
	NULL,		-- new column (dns_domain_collection_id)
	dns_domain_id,
	NULL,		-- new column (layer2_network_collection_id)
	NULL,		-- new column (layer3_network_collection_id)
	netblock_collection_id,
	operating_system_id,
	operating_system_snapshot_id,
	person_id,
	property_collection_id,
	service_env_collection_id,
	site_code,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_device_coll_id,
	property_value_nblk_coll_id,
	property_value_password_type,
	property_value_person_id,
	property_value_sw_package_id,
	property_value_token_col_id,
	property_rank,
	start_date,
	finish_date,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM property_v64;

INSERT INTO audit.property (
	property_id,
	account_collection_id,
	account_id,
	account_realm_id,
	company_collection_id,		-- new column (company_collection_id)
	company_id,
	device_collection_id,
	dns_domain_collection_id,		-- new column (dns_domain_collection_id)
	dns_domain_id,
	layer2_network_collection_id,		-- new column (layer2_network_collection_id)
	layer3_network_collection_id,		-- new column (layer3_network_collection_id)
	netblock_collection_id,
	operating_system_id,
	operating_system_snapshot_id,
	person_id,
	property_collection_id,
	service_env_collection_id,
	site_code,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_device_coll_id,
	property_value_nblk_coll_id,
	property_value_password_type,
	property_value_person_id,
	property_value_sw_package_id,
	property_value_token_col_id,
	property_rank,
	start_date,
	finish_date,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	property_id,
	account_collection_id,
	account_id,
	account_realm_id,
	NULL,		-- new column (company_collection_id)
	company_id,
	device_collection_id,
	NULL,		-- new column (dns_domain_collection_id)
	dns_domain_id,
	NULL,		-- new column (layer2_network_collection_id)
	NULL,		-- new column (layer3_network_collection_id)
	netblock_collection_id,
	operating_system_id,
	operating_system_snapshot_id,
	person_id,
	property_collection_id,
	service_env_collection_id,
	site_code,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_device_coll_id,
	property_value_nblk_coll_id,
	property_value_password_type,
	property_value_person_id,
	property_value_sw_package_id,
	property_value_token_col_id,
	property_rank,
	start_date,
	finish_date,
	is_enabled,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.property_v64;

ALTER TABLE property
	ALTER property_id
	SET DEFAULT nextval('property_property_id_seq'::regclass);
ALTER TABLE property
	ALTER is_enabled
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE property ADD CONSTRAINT pk_property PRIMARY KEY (property_id);

-- Table/Column Comments
COMMENT ON TABLE property IS 'generic mechanism to create arbitrary associations between lhs database objects and assign them to zero or one other database objects/strings/lists/etc.  They are trigger enforced based on characteristics in val_property and val_property_value where foreign key enforcement does not work.';
COMMENT ON COLUMN property.property_id IS 'primary key for table to uniquely identify rows.';
COMMENT ON COLUMN property.account_collection_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.account_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.account_realm_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.company_id IS 'LHS settable based on val_property.  THIS COLUMN IS DEPRECATED AND WILL BE REMOVED >= 0.66';
COMMENT ON COLUMN property.device_collection_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.dns_domain_collection_id IS 'LHS settable based on val_property  THIS COLUMN IS DEPRECATED AND WILL BE REMOVED >= 0.66';
COMMENT ON COLUMN property.dns_domain_id IS 'LHS settable based on val_property.   THIS COLUMN IS BEING DEPRECATED IN FAVOR OF DNS_DOMAIN_COLLECTION_ID IN >= 0.66';
COMMENT ON COLUMN property.netblock_collection_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.operating_system_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.operating_system_snapshot_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.person_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.property_collection_id IS 'LHS settable based on val_property.  NOTE, this is actually collections of property_name,property_type';
COMMENT ON COLUMN property.service_env_collection_id IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.site_code IS 'LHS settable based on val_property';
COMMENT ON COLUMN property.property_name IS 'textual name of a property';
COMMENT ON COLUMN property.property_type IS 'textual type of a department';
COMMENT ON COLUMN property.property_value IS 'RHS - general purpose column for value of property not defined by other types.  This may be enforced by fk (trigger) if val_property.property_data_type is list (fk is to val_property_value).   permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_timestamp IS 'RHS - value is a timestamp , permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_company_id IS 'RHS - fk to company_id,  permitted based on val_property.property_data_type.  THIS COLUMN IS DEPRECATED AND WILL BE REMOVED >= 0.66';
COMMENT ON COLUMN property.property_value_account_coll_id IS 'RHS, fk to account_collection,    permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_device_coll_id IS 'RHS - fk to device_collection.    permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_nblk_coll_id IS 'RHS - fk to network_collection.    permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_password_type IS 'RHS - fk to val_password_type.     permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_person_id IS 'RHS - fk to person.     permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_sw_package_id IS 'RHS - fk to sw_package.  possibly will be deprecated.     permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_value_token_col_id IS 'RHS - fk to token_collection_id.     permitted based on val_property.property_data_type.';
COMMENT ON COLUMN property.property_rank IS 'for multivalues, specifies the order.  If set, this basically becomes part of the "ak" for the lhs.';
COMMENT ON COLUMN property.start_date IS 'date/time that the assignment takes effect or NULL.  .  The view v_property filters this out.';
COMMENT ON COLUMN property.finish_date IS 'date/time that the assignment ceases taking effect or NULL.  .  The view v_property filters this out.';
COMMENT ON COLUMN property.is_enabled IS 'indiciates if the property is temporarily disabled or not.  The view v_property filters this out.';
-- INDEXES
CREATE INDEX xif30property ON property USING btree (layer2_network_collection_id);
CREATE INDEX xif31property ON property USING btree (layer3_network_collection_id);
CREATE INDEX xif_prop_compcoll_id ON property USING btree (company_collection_id);
CREATE INDEX xif_prop_os_snapshot ON property USING btree (operating_system_snapshot_id);
CREATE INDEX xif_prop_pv_devcolid ON property USING btree (property_value_device_coll_id);
CREATE INDEX xif_prop_svc_env_coll_id ON property USING btree (service_env_collection_id);
CREATE INDEX xif_property_acctrealmid ON property USING btree (account_realm_id);
CREATE INDEX xif_property_dns_dom_collect ON property USING btree (dns_domain_collection_id);
CREATE INDEX xif_property_nblk_coll_id ON property USING btree (netblock_collection_id);
CREATE INDEX xif_property_person_id ON property USING btree (person_id);
CREATE INDEX xif_property_prop_coll_id ON property USING btree (property_collection_id);
CREATE INDEX xif_property_pv_nblkcol_id ON property USING btree (property_value_nblk_coll_id);
CREATE INDEX xif_property_val_prsnid ON property USING btree (property_value_person_id);
CREATE INDEX xifprop_account_id ON property USING btree (account_id);
CREATE INDEX xifprop_acctcol_id ON property USING btree (account_collection_id);
CREATE INDEX xifprop_compid ON property USING btree (company_id);
CREATE INDEX xifprop_devcolid ON property USING btree (device_collection_id);
CREATE INDEX xifprop_dnsdomid ON property USING btree (dns_domain_id);
CREATE INDEX xifprop_nmtyp ON property USING btree (property_name, property_type);
CREATE INDEX xifprop_osid ON property USING btree (operating_system_id);
CREATE INDEX xifprop_pval_acct_colid ON property USING btree (property_value_account_coll_id);
CREATE INDEX xifprop_pval_compid ON property USING btree (property_value_company_id);
CREATE INDEX xifprop_pval_pwdtyp ON property USING btree (property_value_password_type);
CREATE INDEX xifprop_pval_swpkgid ON property USING btree (property_value_sw_package_id);
CREATE INDEX xifprop_pval_tokcolid ON property USING btree (property_value_token_col_id);
CREATE INDEX xifprop_site_code ON property USING btree (site_code);

-- CHECK CONSTRAINTS
ALTER TABLE property ADD CONSTRAINT ckc_prop_isenbld
	CHECK (is_enabled = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK property and company_collection
ALTER TABLE property
	ADD CONSTRAINT fk_prop_compcoll_id
	FOREIGN KEY (company_collection_id) REFERENCES company_collection(company_collection_id);
-- consider FK property and layer2_network_collection
ALTER TABLE property
	ADD CONSTRAINT fk_prop_l2_netcollid
	FOREIGN KEY (layer2_network_collection_id) REFERENCES layer2_network_collection(layer2_network_collection_id);
-- consider FK property and layer3_network_collection
ALTER TABLE property
	ADD CONSTRAINT fk_prop_l3_netcoll_id
	FOREIGN KEY (layer3_network_collection_id) REFERENCES layer3_network_collection(layer3_network_collection_id);
-- consider FK property and operating_system_snapshot
ALTER TABLE property
	ADD CONSTRAINT fk_prop_os_snapshot
	FOREIGN KEY (operating_system_snapshot_id) REFERENCES operating_system_snapshot(operating_system_snapshot_id);
-- consider FK property and device_collection
ALTER TABLE property
	ADD CONSTRAINT fk_prop_pv_devcolid
	FOREIGN KEY (property_value_device_coll_id) REFERENCES device_collection(device_collection_id);
-- consider FK property and service_environment_collection
ALTER TABLE property
	ADD CONSTRAINT fk_prop_svc_env_coll_id
	FOREIGN KEY (service_env_collection_id) REFERENCES service_environment_collection(service_env_collection_id);
-- consider FK property and account_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_acct_col
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);
-- consider FK property and account
ALTER TABLE property
	ADD CONSTRAINT fk_property_acctid
	FOREIGN KEY (account_id) REFERENCES account(account_id);
-- consider FK property and account_realm
ALTER TABLE property
	ADD CONSTRAINT fk_property_acctrealmid
	FOREIGN KEY (account_realm_id) REFERENCES account_realm(account_realm_id);
-- consider FK property and company
ALTER TABLE property
	ADD CONSTRAINT fk_property_compid
	FOREIGN KEY (company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK property and device_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_devcolid
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);
-- consider FK property and dns_domain_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_dns_dom_collect
	FOREIGN KEY (dns_domain_collection_id) REFERENCES dns_domain_collection(dns_domain_collection_id);
-- consider FK property and dns_domain
ALTER TABLE property
	ADD CONSTRAINT fk_property_dnsdomid
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);
-- consider FK property and netblock_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_nblk_coll_id
	FOREIGN KEY (netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id);
-- consider FK property and val_property
ALTER TABLE property
	ADD CONSTRAINT fk_property_nmtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);
-- consider FK property and operating_system
ALTER TABLE property
	ADD CONSTRAINT fk_property_osid
	FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id);
-- consider FK property and person
ALTER TABLE property
	ADD CONSTRAINT fk_property_person_id
	FOREIGN KEY (person_id) REFERENCES person(person_id);
-- consider FK property and property_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_prop_coll_id
	FOREIGN KEY (property_collection_id) REFERENCES property_collection(property_collection_id);
-- consider FK property and netblock_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_pv_nblkcol_id
	FOREIGN KEY (property_value_nblk_coll_id) REFERENCES netblock_collection(netblock_collection_id);
-- consider FK property and account_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_acct_colid
	FOREIGN KEY (property_value_account_coll_id) REFERENCES account_collection(account_collection_id);
-- consider FK property and company
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_compid
	FOREIGN KEY (property_value_company_id) REFERENCES company(company_id) DEFERRABLE;
-- consider FK property and val_password_type
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_pwdtyp
	FOREIGN KEY (property_value_password_type) REFERENCES val_password_type(password_type);
-- consider FK property and sw_package
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_swpkgid
	FOREIGN KEY (property_value_sw_package_id) REFERENCES sw_package(sw_package_id);
-- consider FK property and token_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_tokcolid
	FOREIGN KEY (property_value_token_col_id) REFERENCES token_collection(token_collection_id);
-- consider FK property and site
ALTER TABLE property
	ADD CONSTRAINT fk_property_site_code
	FOREIGN KEY (site_code) REFERENCES site(site_code);
-- consider FK property and person
ALTER TABLE property
	ADD CONSTRAINT fk_property_val_prsnid
	FOREIGN KEY (property_value_person_id) REFERENCES person(person_id);

-- TRIGGERS
-- consider NEW oid 3738607
CREATE OR REPLACE FUNCTION jazzhands.validate_property()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally				integer;
	v_prop				VAL_Property%ROWTYPE;
	v_proptype			VAL_Property_Type%ROWTYPE;
	v_account_collection		account_collection%ROWTYPE;
	v_company_collection		company_collection%ROWTYPE;
	v_device_collection		device_collection%ROWTYPE;
	v_dns_domain_collection		dns_domain_collection%ROWTYPE;
	v_layer2_network_collection	layer2_network_collection%ROWTYPE;
	v_layer3_network_collection	layer3_network_collection%ROWTYPE;
	v_netblock_collection		netblock_collection%ROWTYPE;
	v_property_collection		property_collection%ROWTYPE;
	v_service_env_collection	service_environment_collection%ROWTYPE;
	v_num				integer;
	v_listvalue			Property.Property_Value%TYPE;
BEGIN

	-- Pull in the data from the property and property_type so we can
	-- figure out what is and is not valid

	BEGIN
		SELECT * INTO STRICT v_prop FROM VAL_Property WHERE
			Property_Name = NEW.Property_Name AND
			Property_Type = NEW.Property_Type;

		SELECT * INTO STRICT v_proptype FROM VAL_Property_Type WHERE
			Property_Type = NEW.Property_Type;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			RAISE EXCEPTION
				'Property name or type does not exist'
				USING ERRCODE = 'foreign_key_violation';
			RETURN NULL;
	END;

	-- Check to see if the property itself is multivalue.  That is, if only
	-- one value can be set for this property for a specific property LHS
	IF (v_prop.is_multivalue = 'N') THEN
		PERFORM 1 FROM Property WHERE
			Property_Id != NEW.Property_Id AND
			Property_Name = NEW.Property_Name AND
			Property_Type = NEW.Property_Type AND
			account_collection_id IS NOT DISTINCT FROM NEW.account_collection_id
				AND
			account_id IS NOT DISTINCT FROM NEW.account_id AND
			account_realm_id IS NOT DISTINCT FROM NEW.account_realm_id AND
			company_collection_id IS NOT DISTINCT FROM NEW.company_collection_id AND
			company_id IS NOT DISTINCT FROM NEW.company_id AND
			device_collection_id IS NOT DISTINCT FROM NEW.device_collection_id AND
			dns_domain_collection_id IS NOT DISTINCT FROM
				NEW.dns_domain_collection_id AND
			dns_domain_id IS NOT DISTINCT FROM NEW.dns_domain_id AND
			layer2_network_collection_id IS NOT DISTINCT FROM
				NEW.layer2_network_collection_id AND
			layer3_network_collection_id IS NOT DISTINCT FROM
				NEW.layer3_network_collection_id AND
			netblock_collection_id IS NOT DISTINCT FROM NEW.netblock_collection_id AND
			operating_system_id IS NOT DISTINCT FROM NEW.operating_system_id AND
			operating_system_snapshot_id IS NOT DISTINCT FROM
				NEW.operating_system_snapshot_id AND
			person_id IS NOT DISTINCT FROM NEW.person_id AND
			property_collection_id IS NOT DISTINCT FROM NEW.property_collection_id AND
			service_env_collection_id IS NOT DISTINCT FROM
				NEW.service_env_collection_id AND
			site_code IS NOT DISTINCT FROM NEW.site_code
		;

		IF FOUND THEN
			RAISE EXCEPTION
				'Property of type (%,%) already exists for given LHS and property is not multivalue',
				NEW.Property_Name, NEW.Property_Type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;
	ELSE
		-- check for the same lhs+rhs existing, which is basically a dup row
		PERFORM 1 FROM Property WHERE
			Property_Id != NEW.Property_Id AND
			Property_Name = NEW.Property_Name AND
			Property_Type = NEW.Property_Type AND
			account_collection_id IS NOT DISTINCT FROM NEW.account_collection_id
				AND
			account_id IS NOT DISTINCT FROM NEW.account_id AND
			account_realm_id IS NOT DISTINCT FROM NEW.account_realm_id AND
			company_collection_id IS NOT DISTINCT FROM NEW.company_collection_id AND
			company_id IS NOT DISTINCT FROM NEW.company_id AND
			device_collection_id IS NOT DISTINCT FROM NEW.device_collection_id AND
			dns_domain_collection_id IS NOT DISTINCT FROM
				NEW.dns_domain_collection_id AND
			dns_domain_id IS NOT DISTINCT FROM NEW.dns_domain_id AND
			layer2_network_collection_id IS NOT DISTINCT FROM
				NEW.layer2_network_collection_id AND
			layer3_network_collection_id IS NOT DISTINCT FROM
				NEW.layer3_network_collection_id AND
			netblock_collection_id IS NOT DISTINCT FROM NEW.netblock_collection_id AND
			operating_system_id IS NOT DISTINCT FROM NEW.operating_system_id AND
			operating_system_snapshot_id IS NOT DISTINCT FROM
				NEW.operating_system_snapshot_id AND
			person_id IS NOT DISTINCT FROM NEW.person_id AND
			property_collection_id IS NOT DISTINCT FROM NEW.property_collection_id AND
			service_env_collection_id IS NOT DISTINCT FROM
				NEW.service_env_collection_id AND
			site_code IS NOT DISTINCT FROM NEW.site_code AND
			property_value IS NOT DISTINCT FROM NEW.property_value AND
			property_value_timestamp IS NOT DISTINCT FROM
				NEW.property_value_timestamp AND
			property_value_company_id IS NOT DISTINCT FROM
				NEW.property_value_company_id AND
			property_value_account_coll_id IS NOT DISTINCT FROM
				NEW.property_value_account_coll_id AND
			property_value_device_coll_id IS NOT DISTINCT FROM
				NEW.property_value_device_coll_id AND
			property_value_nblk_coll_id IS NOT DISTINCT FROM
				NEW.property_value_nblk_coll_id AND
			property_value_password_type IS NOT DISTINCT FROM
				NEW.property_value_password_type AND
			property_value_person_id IS NOT DISTINCT FROM
				NEW.property_value_person_id AND
			property_value_sw_package_id IS NOT DISTINCT FROM
				NEW.property_value_sw_package_id AND
			property_value_token_col_id IS NOT DISTINCT FROM
				NEW.property_value_token_col_id AND
			start_date IS NOT DISTINCT FROM NEW.start_date AND
			finish_date IS NOT DISTINCT FROM NEW.finish_date
		;

		IF FOUND THEN
			RAISE EXCEPTION
				'Property of (n,t) (%,%) already exists for given property',
				NEW.Property_Name, NEW.Property_Type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;

	END IF;

	-- Check to see if the property type is multivalue.  That is, if only
	-- one property and value can be set for any properties with this type
	-- for a specific property LHS

	IF (v_proptype.is_multivalue = 'N') THEN
		PERFORM 1 FROM Property WHERE
			Property_Id != NEW.Property_Id AND
			Property_Type = NEW.Property_Type AND
			account_collection_id IS NOT DISTINCT FROM NEW.account_collection_id
				AND
			account_id IS NOT DISTINCT FROM NEW.account_id AND
			account_realm_id IS NOT DISTINCT FROM NEW.account_realm_id AND
			company_collection_id IS NOT DISTINCT FROM NEW.company_collection_id AND
			company_id IS NOT DISTINCT FROM NEW.company_id AND
			device_collection_id IS NOT DISTINCT FROM NEW.device_collection_id AND
			dns_domain_collection_id IS NOT DISTINCT FROM
				NEW.dns_domain_collection_id AND
			dns_domain_id IS NOT DISTINCT FROM NEW.dns_domain_id AND
			layer2_network_collection_id IS NOT DISTINCT FROM
				NEW.layer2_network_collection_id AND
			layer3_network_collection_id IS NOT DISTINCT FROM
				NEW.layer3_network_collection_id AND
			netblock_collection_id IS NOT DISTINCT FROM NEW.netblock_collection_id AND
			operating_system_id IS NOT DISTINCT FROM NEW.operating_system_id AND
			operating_system_snapshot_id IS NOT DISTINCT FROM
				NEW.operating_system_snapshot_id AND
			person_id IS NOT DISTINCT FROM NEW.person_id AND
			property_collection_id IS NOT DISTINCT FROM NEW.property_collection_id AND
			service_env_collection_id IS NOT DISTINCT FROM
				NEW.service_env_collection_id AND
			site_code IS NOT DISTINCT FROM NEW.site_code
		;

		IF FOUND THEN
			RAISE EXCEPTION
				'Property % of type % already exists for given LHS and property type is not multivalue',
				NEW.Property_Name, NEW.Property_Type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;
	END IF;

	-- now validate the property_value columns.
	tally := 0;

	--
	-- first determine if the property_value is set properly.
	--

	-- iterate over each of fk PROPERTY_VALUE columns and if a valid
	-- value is set, increment tally, otherwise raise an exception.
	IF NEW.Property_Value_Company_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'company_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Company_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Password_Type IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'password_type' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Password_Type' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Token_Col_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'token_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Token_Collection_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_SW_Package_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'sw_package_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be SW_Package_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Account_Coll_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'account_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be account_collection_id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_nblk_Coll_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'netblock_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be nblk_collection_id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Timestamp IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'timestamp' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Timestamp' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Person_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'person_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Person_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Device_Coll_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'device_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Device_Collection_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	-- at this point, tally will be set to 1 if one of the other property
	-- values is set to something valid.  Now, check the various options for
	-- PROPERTY_VALUE itself.  If a new type is added to the val table, this
	-- trigger needs to be updated or it will be considered invalid.  If a
	-- new PROPERTY_VALUE_* column is added, then it will pass through without
	-- trigger modification.  This should be considered bad.

	IF NEW.Property_Value IS NOT NULL THEN
		tally := tally + 1;
		IF v_prop.Property_Data_Type = 'boolean' THEN
			IF NEW.Property_Value != 'Y' AND NEW.Property_Value != 'N' THEN
				RAISE 'Boolean Property_Value must be Y or N' USING
					ERRCODE = 'invalid_parameter_value';
			END IF;
		ELSIF v_prop.Property_Data_Type = 'number' THEN
			BEGIN
				v_num := to_number(NEW.property_value, '9');
			EXCEPTION
				WHEN OTHERS THEN
					RAISE 'Property_Value must be numeric' USING
						ERRCODE = 'invalid_parameter_value';
			END;
		ELSIF v_prop.Property_Data_Type = 'list' THEN
			BEGIN
				SELECT Valid_Property_Value INTO STRICT v_listvalue FROM
					VAL_Property_Value WHERE
						Property_Name = NEW.Property_Name AND
						Property_Type = NEW.Property_Type AND
						Valid_Property_Value = NEW.Property_Value;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					RAISE 'Property_Value must be a valid value' USING
						ERRCODE = 'invalid_parameter_value';
			END;
		ELSIF v_prop.Property_Data_Type != 'string' THEN
			RAISE 'Property_Data_Type is not a known type' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_prop.Property_Data_Type != 'none' AND tally = 0 THEN
		RAISE 'One of the PROPERTY_VALUE fields must be set.' USING
			ERRCODE = 'invalid_parameter_value';
	END IF;

	IF tally > 1 THEN
		RAISE 'Only one of the PROPERTY_VALUE fields may be set.' USING
			ERRCODE = 'invalid_parameter_value';
	END IF;

	-- If the LHS contains a account_collection_ID, check to see if it must be a
	-- specific type (e.g. per-account), and verify that if so
	IF NEW.account_collection_id IS NOT NULL THEN
		IF v_prop.account_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_account_collection
					FROM account_collection WHERE
					account_collection_Id = NEW.account_collection_id;
				IF v_account_collection.account_collection_Type != v_prop.account_collection_type
				THEN
					RAISE 'account_collection_id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a account_collection_ID, check to see if it must be a
	-- specific type (e.g. per-account), and verify that if so
	IF NEW.account_collection_id IS NOT NULL THEN
		IF v_prop.account_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_account_collection
					FROM account_collection WHERE
					account_collection_Id = NEW.account_collection_id;
				IF v_account_collection.account_collection_Type != v_prop.account_collection_type
				THEN
					RAISE 'account_collection_id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a device_collection_ID, check to see if it must be a
	-- specific type (e.g. per-device), and verify that if so
	IF NEW.device_collection_id IS NOT NULL THEN
		IF v_prop.device_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_device_collection
					FROM device_collection WHERE
					device_collection_Id = NEW.device_collection_id;
				IF v_device_collection.device_collection_Type != v_prop.device_collection_type
				THEN
					RAISE 'device_collection_id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a dns_domain_collection_ID, check to see if it must be a
	-- specific type (e.g. per-dns_domain), and verify that if so
	IF NEW.dns_domain_collection_id IS NOT NULL THEN
		IF v_prop.dns_domain_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_dns_domain_collection
					FROM dns_domain_collection WHERE
					dns_domain_collection_Id = NEW.dns_domain_collection_id;
				IF v_dns_domain_collection.dns_domain_collection_Type != v_prop.dns_domain_collection_type
				THEN
					RAISE 'dns_domain_collection_id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a layer2_network_collection_ID, check to see if it must be a
	-- specific type (e.g. per-layer2_network), and verify that if so
	IF NEW.layer2_network_collection_id IS NOT NULL THEN
		IF v_prop.layer2_network_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_layer2_network_collection
					FROM layer2_network_collection WHERE
					layer2_network_collection_Id = NEW.layer2_network_collection_id;
				IF v_layer2_network_collection.layer2_network_collection_Type != v_prop.layer2_network_collection_type
				THEN
					RAISE 'layer2_network_collection_id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a layer3_network_collection_ID, check to see if it must be a
	-- specific type (e.g. per-layer3_network), and verify that if so
	IF NEW.layer3_network_collection_id IS NOT NULL THEN
		IF v_prop.layer3_network_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_layer3_network_collection
					FROM layer3_network_collection WHERE
					layer3_network_collection_Id = NEW.layer3_network_collection_id;
				IF v_layer3_network_collection.layer3_network_collection_Type != v_prop.layer3_network_collection_type
				THEN
					RAISE 'layer3_network_collection_id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a netblock_collection_ID, check to see if it must be a
	-- specific type (e.g. per-netblock), and verify that if so
	IF NEW.netblock_collection_id IS NOT NULL THEN
		IF v_prop.netblock_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_netblock_collection
					FROM netblock_collection WHERE
					netblock_collection_Id = NEW.netblock_collection_id;
				IF v_netblock_collection.netblock_collection_Type != v_prop.netblock_collection_type
				THEN
					RAISE 'netblock_collection_id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a property_collection_ID, check to see if it must be a
	-- specific type (e.g. per-property), and verify that if so
	IF NEW.property_collection_id IS NOT NULL THEN
		IF v_prop.property_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_property_collection
					FROM property_collection WHERE
					property_collection_Id = NEW.property_collection_id;
				IF v_property_collection.property_collection_Type != v_prop.property_collection_type
				THEN
					RAISE 'property_collection_id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a service_env_collection_ID, check to see if it must be a
	-- specific type (e.g. per-service_env), and verify that if so
	IF NEW.service_env_collection_id IS NOT NULL THEN
		IF v_prop.service_env_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_service_env_collection
					FROM service_env_collection WHERE
					service_env_collection_Id = NEW.service_env_collection_id;
				IF v_service_env_collection.service_env_collection_Type != v_prop.service_env_collection_type
				THEN
					RAISE 'service_env_collection_id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the RHS contains a account_collection_ID, check to see if it must be a
	-- specific type (e.g. per-account), and verify that if so
	IF NEW.Property_Value_Account_Coll_Id IS NOT NULL THEN
		IF v_prop.prop_val_acct_coll_type_rstrct IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_account_collection
					FROM account_collection WHERE
					account_collection_Id = NEW.Property_Value_Account_Coll_Id;
				IF v_account_collection.account_collection_Type != v_prop.prop_val_acct_coll_type_rstrct
				THEN
					RAISE 'Property_Value_Account_Coll_Id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the RHS contains a netblock_collection_ID, check to see if it must be a
	-- specific type and verify that if so
	IF NEW.Property_Value_nblk_Coll_Id IS NOT NULL THEN
		IF v_prop.prop_val_acct_coll_type_rstrct IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_netblock_collection
					FROM netblock_collection WHERE
					netblock_collection_Id = NEW.Property_Value_nblk_Coll_Id;
				IF v_netblock_collection.netblock_collection_Type != v_prop.prop_val_acct_coll_type_rstrct
				THEN
					RAISE 'Property_Value_nblk_Coll_Id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the RHS contains a device_collection_id, check to see if it must be a
	-- specific type and verify that if so
	IF NEW.Property_Value_Device_Coll_Id IS NOT NULL THEN
		IF v_prop.prop_val_dev_coll_type_rstrct IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_device_collection
					FROM device_collection WHERE
					device_collection_id = NEW.Property_Value_Device_Coll_Id;
				IF v_device_collection.device_collection_type !=
					v_prop.prop_val_dev_coll_type_rstrct
				THEN
					RAISE 'Property_Value_Device_Coll_Id must be of type %',
					v_prop.prop_val_dev_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- At this point, the RHS has been checked, so now we verify data
	-- set on the LHS

	-- There needs to be a stanza here for every "lhs".  If a new column is
	-- added to the property table, a new stanza needs to be added here,
	-- otherwise it will not be validated.  This should be considered bad.

	IF v_prop.Permit_Company_Id = 'REQUIRED' THEN
			IF NEW.Company_Id IS NULL THEN
				RAISE 'Company_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Company_Id = 'PROHIBITED' THEN
			IF NEW.Company_Id IS NOT NULL THEN
				RAISE 'Company_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Company_Collection_Id = 'REQUIRED' THEN
			IF NEW.Company_Collection_Id IS NULL THEN
				RAISE 'Company_Collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Company_Collection_Id = 'PROHIBITED' THEN
			IF NEW.Company_Collection_Id IS NOT NULL THEN
				RAISE 'Company_Collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Device_Collection_Id = 'REQUIRED' THEN
			IF NEW.Device_Collection_Id IS NULL THEN
				RAISE 'Device_Collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;

	ELSIF v_prop.Permit_Device_Collection_Id = 'PROHIBITED' THEN
			IF NEW.Device_Collection_Id IS NOT NULL THEN
				RAISE 'Device_Collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_DNS_Domain_Id = 'REQUIRED' THEN
			IF NEW.DNS_Domain_Id IS NULL THEN
				RAISE 'DNS_Domain_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_DNS_Domain_Id = 'PROHIBITED' THEN
			IF NEW.DNS_Domain_Id IS NOT NULL THEN
				RAISE 'DNS_Domain_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.permit_service_env_collection = 'REQUIRED' THEN
			IF NEW.service_env_collection_id IS NULL THEN
				RAISE 'service_env_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_service_env_collection = 'PROHIBITED' THEN
			IF NEW.service_env_collection_id IS NOT NULL THEN
				RAISE 'service_environment is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Operating_System_Id = 'REQUIRED' THEN
			IF NEW.Operating_System_Id IS NULL THEN
				RAISE 'Operating_System_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Operating_System_Id = 'PROHIBITED' THEN
			IF NEW.Operating_System_Id IS NOT NULL THEN
				RAISE 'Operating_System_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.permit_os_snapshot_id = 'REQUIRED' THEN
			IF NEW.operating_system_snapshot_id IS NULL THEN
				RAISE 'operating_system_snapshot_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_os_snapshot_id = 'PROHIBITED' THEN
			IF NEW.operating_system_snapshot_id IS NOT NULL THEN
				RAISE 'operating_system_snapshot_id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Site_Code = 'REQUIRED' THEN
			IF NEW.Site_Code IS NULL THEN
				RAISE 'Site_Code is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Site_Code = 'PROHIBITED' THEN
			IF NEW.Site_Code IS NOT NULL THEN
				RAISE 'Site_Code is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Account_Id = 'REQUIRED' THEN
			IF NEW.Account_Id IS NULL THEN
				RAISE 'Account_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Account_Id = 'PROHIBITED' THEN
			IF NEW.Account_Id IS NOT NULL THEN
				RAISE 'Account_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Account_Realm_Id = 'REQUIRED' THEN
			IF NEW.Account_Realm_Id IS NULL THEN
				RAISE 'Account_Realm_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Account_Realm_Id = 'PROHIBITED' THEN
			IF NEW.Account_Realm_Id IS NOT NULL THEN
				RAISE 'Account_Realm_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_account_collection_Id = 'REQUIRED' THEN
			IF NEW.account_collection_Id IS NULL THEN
				RAISE 'account_collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_account_collection_Id = 'PROHIBITED' THEN
			IF NEW.account_collection_Id IS NOT NULL THEN
				RAISE 'account_collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.permit_layer2_network_coll_id = 'REQUIRED' THEN
			IF NEW.layer2_network_collection_id IS NULL THEN
				RAISE 'layer2_network_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_layer2_network_coll_id = 'PROHIBITED' THEN
			IF NEW.layer2_network_collection_id IS NOT NULL THEN
				RAISE 'layer2_network_collection_id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.permit_layer3_network_coll_id = 'REQUIRED' THEN
			IF NEW.layer3_network_collection_id IS NULL THEN
				RAISE 'layer3_network_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_layer3_network_coll_id = 'PROHIBITED' THEN
			IF NEW.layer3_network_collection_id IS NOT NULL THEN
				RAISE 'layer3_network_collection_id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_netblock_collection_Id = 'REQUIRED' THEN
			IF NEW.netblock_collection_Id IS NULL THEN
				RAISE 'netblock_collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_netblock_collection_Id = 'PROHIBITED' THEN
			IF NEW.netblock_collection_Id IS NOT NULL THEN
				RAISE 'netblock_collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_property_collection_Id = 'REQUIRED' THEN
			IF NEW.property_collection_Id IS NULL THEN
				RAISE 'property_collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_property_collection_Id = 'PROHIBITED' THEN
			IF NEW.property_collection_Id IS NOT NULL THEN
				RAISE 'property_collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Person_Id = 'REQUIRED' THEN
			IF NEW.Person_Id IS NULL THEN
				RAISE 'Person_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Person_Id = 'PROHIBITED' THEN
			IF NEW.Person_Id IS NOT NULL THEN
				RAISE 'Person_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Property_Rank = 'REQUIRED' THEN
			IF NEW.property_rank IS NULL THEN
				RAISE 'property_rank is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Property_Rank = 'PROHIBITED' THEN
			IF NEW.property_rank IS NOT NULL THEN
				RAISE 'property_rank is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	RETURN NEW;
END;
$function$
;
CREATE TRIGGER trigger_validate_property BEFORE INSERT OR UPDATE ON property FOR EACH ROW EXECUTE PROCEDURE validate_property();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'property');
ALTER SEQUENCE property_property_id_seq
	 OWNED BY property.property_id;
DROP TABLE IF EXISTS property_v64;
DROP TABLE IF EXISTS audit.property_v64;
-- DONE DEALING WITH TABLE property [3730415]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE slot [3721501]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'slot', 'slot');

-- FOREIGN KEYS FROM
ALTER TABLE component_property DROP CONSTRAINT IF EXISTS fk_comp_prop_slt_slt_id;
ALTER TABLE component DROP CONSTRAINT IF EXISTS fk_component_prnt_slt_id;
ALTER TABLE inter_component_connection DROP CONSTRAINT IF EXISTS fk_intercomp_conn_slot1_id;
ALTER TABLE inter_component_connection DROP CONSTRAINT IF EXISTS fk_intercomp_conn_slot2_id;
ALTER TABLE logical_port_slot DROP CONSTRAINT IF EXISTS fk_lgl_port_slot_slot_id;
ALTER TABLE network_interface DROP CONSTRAINT IF EXISTS fk_net_int_phys_port_id;
ALTER TABLE network_interface DROP CONSTRAINT IF EXISTS fk_netint_slot_id;
ALTER TABLE physical_connection DROP CONSTRAINT IF EXISTS fk_physconn_physport1_id;
ALTER TABLE physical_connection DROP CONSTRAINT IF EXISTS fk_physconn_physport2_id;
ALTER TABLE physical_connection DROP CONSTRAINT IF EXISTS fk_physconn_slot1_id;
ALTER TABLE physical_connection DROP CONSTRAINT IF EXISTS fk_physconn_slot2_id;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.slot DROP CONSTRAINT IF EXISTS fk_slot_cmp_typ_tmp_id;
ALTER TABLE jazzhands.slot DROP CONSTRAINT IF EXISTS fk_slot_component_id;
ALTER TABLE jazzhands.slot DROP CONSTRAINT IF EXISTS fk_slot_slot_type_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'slot');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.slot DROP CONSTRAINT IF EXISTS ak_slot_slot_type_id;
ALTER TABLE jazzhands.slot DROP CONSTRAINT IF EXISTS pk_slot_id;
ALTER TABLE jazzhands.slot DROP CONSTRAINT IF EXISTS uq_slot_cmp_slt_tmplt_id;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_slot_cmp_typ_tmp_id";
DROP INDEX IF EXISTS "jazzhands"."xif_slot_component_id";
DROP INDEX IF EXISTS "jazzhands"."xif_slot_slot_type_id";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.slot DROP CONSTRAINT IF EXISTS checkslot_enbled__yes_no;
ALTER TABLE jazzhands.slot DROP CONSTRAINT IF EXISTS ckc_slot_slot_side;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_slot ON jazzhands.slot;
DROP TRIGGER IF EXISTS trigger_audit_slot ON jazzhands.slot;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'slot');
---- BEGIN audit.slot TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'slot', 'slot');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'slot');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."slot_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'slot');
---- DONE audit.slot TEARDOWN


ALTER TABLE slot RENAME TO slot_v64;
ALTER TABLE audit.slot RENAME TO slot_v64;

CREATE TABLE slot
(
	slot_id	integer NOT NULL,
	component_id	integer NOT NULL,
	slot_name	varchar(50) NOT NULL,
	slot_index	integer  NULL,
	slot_type_id	integer NOT NULL,
	component_type_slot_tmplt_id	integer  NULL,
	is_enabled	character(1) NOT NULL,
	physical_label	varchar(50)  NULL,
	mac_address	macaddr  NULL,
	description	varchar(255)  NULL,
	slot_x_offset	integer  NULL,
	slot_y_offset	integer  NULL,
	slot_z_offset	integer  NULL,
	slot_side	varchar(50)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'slot', false);
ALTER TABLE slot
	ALTER slot_id
	SET DEFAULT nextval('slot_slot_id_seq'::regclass);
ALTER TABLE slot
	ALTER is_enabled
	SET DEFAULT 'Y'::bpchar;
INSERT INTO slot (
	slot_id,
	component_id,
	slot_name,
	slot_index,
	slot_type_id,
	component_type_slot_tmplt_id,
	is_enabled,
	physical_label,
	mac_address,		-- new column (mac_address)
	description,
	slot_x_offset,
	slot_y_offset,
	slot_z_offset,
	slot_side,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	slot_id,
	component_id,
	slot_name,
	slot_index,
	slot_type_id,
	component_type_slot_tmplt_id,
	is_enabled,
	physical_label,
	NULL,		-- new column (mac_address)
	description,
	slot_x_offset,
	slot_y_offset,
	slot_z_offset,
	slot_side,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM slot_v64;

INSERT INTO audit.slot (
	slot_id,
	component_id,
	slot_name,
	slot_index,
	slot_type_id,
	component_type_slot_tmplt_id,
	is_enabled,
	physical_label,
	mac_address,		-- new column (mac_address)
	description,
	slot_x_offset,
	slot_y_offset,
	slot_z_offset,
	slot_side,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	slot_id,
	component_id,
	slot_name,
	slot_index,
	slot_type_id,
	component_type_slot_tmplt_id,
	is_enabled,
	physical_label,
	NULL,		-- new column (mac_address)
	description,
	slot_x_offset,
	slot_y_offset,
	slot_z_offset,
	slot_side,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.slot_v64;

ALTER TABLE slot
	ALTER slot_id
	SET DEFAULT nextval('slot_slot_id_seq'::regclass);
ALTER TABLE slot
	ALTER is_enabled
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE slot ADD CONSTRAINT ak_slot_slot_type_id UNIQUE (slot_id, slot_type_id);
ALTER TABLE slot ADD CONSTRAINT pk_slot_id PRIMARY KEY (slot_id);
ALTER TABLE slot ADD CONSTRAINT uq_slot_cmp_slt_tmplt_id UNIQUE (component_id, component_type_slot_tmplt_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif_slot_cmp_typ_tmp_id ON slot USING btree (component_type_slot_tmplt_id);
CREATE INDEX xif_slot_component_id ON slot USING btree (component_id);
CREATE INDEX xif_slot_slot_type_id ON slot USING btree (slot_type_id);

-- CHECK CONSTRAINTS
ALTER TABLE slot ADD CONSTRAINT checkslot_enbled__yes_no
	CHECK (is_enabled = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE slot ADD CONSTRAINT ckc_slot_slot_side
	CHECK ((slot_side)::text = ANY ((ARRAY['FRONT'::character varying, 'BACK'::character varying])::text[]));

-- FOREIGN KEYS FROM
-- consider FK slot and component_property
ALTER TABLE component_property
	ADD CONSTRAINT fk_comp_prop_slt_slt_id
	FOREIGN KEY (slot_id) REFERENCES slot(slot_id);
-- consider FK slot and component
ALTER TABLE component
	ADD CONSTRAINT fk_component_prnt_slt_id
	FOREIGN KEY (parent_slot_id) REFERENCES slot(slot_id);
-- consider FK slot and inter_component_connection
ALTER TABLE inter_component_connection
	ADD CONSTRAINT fk_intercomp_conn_slot1_id
	FOREIGN KEY (slot1_id) REFERENCES slot(slot_id);
-- consider FK slot and inter_component_connection
ALTER TABLE inter_component_connection
	ADD CONSTRAINT fk_intercomp_conn_slot2_id
	FOREIGN KEY (slot2_id) REFERENCES slot(slot_id);
-- consider FK slot and logical_port_slot
ALTER TABLE logical_port_slot
	ADD CONSTRAINT fk_lgl_port_slot_slot_id
	FOREIGN KEY (slot_id) REFERENCES slot(slot_id);
-- consider FK slot and network_interface
ALTER TABLE network_interface
	ADD CONSTRAINT fk_net_int_phys_port_id
	FOREIGN KEY (physical_port_id) REFERENCES slot(slot_id);
-- consider FK slot and network_interface
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_slot_id
	FOREIGN KEY (slot_id) REFERENCES slot(slot_id);
-- consider FK slot and physical_connection
ALTER TABLE physical_connection
	ADD CONSTRAINT fk_physconn_physport1_id
	FOREIGN KEY (physical_port1_id) REFERENCES slot(slot_id);
-- consider FK slot and physical_connection
ALTER TABLE physical_connection
	ADD CONSTRAINT fk_physconn_physport2_id
	FOREIGN KEY (physical_port2_id) REFERENCES slot(slot_id);
-- consider FK slot and physical_connection
ALTER TABLE physical_connection
	ADD CONSTRAINT fk_physconn_slot1_id
	FOREIGN KEY (slot1_id) REFERENCES slot(slot_id);
-- consider FK slot and physical_connection
ALTER TABLE physical_connection
	ADD CONSTRAINT fk_physconn_slot2_id
	FOREIGN KEY (slot2_id) REFERENCES slot(slot_id);

-- FOREIGN KEYS TO
-- consider FK slot and component_type_slot_tmplt
ALTER TABLE slot
	ADD CONSTRAINT fk_slot_cmp_typ_tmp_id
	FOREIGN KEY (component_type_slot_tmplt_id) REFERENCES component_type_slot_tmplt(component_type_slot_tmplt_id);
-- consider FK slot and component
ALTER TABLE slot
	ADD CONSTRAINT fk_slot_component_id
	FOREIGN KEY (component_id) REFERENCES component(component_id);
-- consider FK slot and slot_type
ALTER TABLE slot
	ADD CONSTRAINT fk_slot_slot_type_id
	FOREIGN KEY (slot_type_id) REFERENCES slot_type(slot_type_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'slot');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'slot');
ALTER SEQUENCE slot_slot_id_seq
	 OWNED BY slot.slot_id;
DROP TABLE IF EXISTS slot_v64;
DROP TABLE IF EXISTS audit.slot_v64;
-- DONE DEALING WITH TABLE slot [3730588]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE token [3721708]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'token', 'token');

-- FOREIGN KEYS FROM
ALTER TABLE account_token DROP CONSTRAINT IF EXISTS fk_acct_token_ref_token;
ALTER TABLE token_collection_token DROP CONSTRAINT IF EXISTS fk_tok_col_tok_token_id;
ALTER TABLE token_sequence DROP CONSTRAINT IF EXISTS fk_token_seq_ref_token;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.token DROP CONSTRAINT IF EXISTS fk_token_enc_id_id;
ALTER TABLE jazzhands.token DROP CONSTRAINT IF EXISTS fk_token_ref_v_token_status;
ALTER TABLE jazzhands.token DROP CONSTRAINT IF EXISTS fk_token_ref_v_token_type;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'token');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.token DROP CONSTRAINT IF EXISTS ak_token_token_key;
ALTER TABLE jazzhands.token DROP CONSTRAINT IF EXISTS pk_token;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_token_tokenstatus";
DROP INDEX IF EXISTS "jazzhands"."idx_token_tokentype";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.token DROP CONSTRAINT IF EXISTS sys_c0020104;
ALTER TABLE jazzhands.token DROP CONSTRAINT IF EXISTS sys_c0020105;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_token ON jazzhands.token;
DROP TRIGGER IF EXISTS trigger_audit_token ON jazzhands.token;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'token');
---- BEGIN audit.token TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'token', 'token');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'token');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."token_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'token');
---- DONE audit.token TEARDOWN


ALTER TABLE token RENAME TO token_v64;
ALTER TABLE audit.token RENAME TO token_v64;

CREATE TABLE token
(
	token_id	integer NOT NULL,
	token_type	varchar(50) NOT NULL,
	token_status	varchar(50)  NULL,
	token_serial	varchar(20)  NULL,
	zero_time	timestamp with time zone  NULL,
	time_modulo	integer  NULL,
	time_skew	integer  NULL,
	token_key	varchar(512)  NULL,
	encryption_key_id	integer  NULL,
	token_password	varchar(128)  NULL,
	expire_time	timestamp with time zone  NULL,
	is_token_locked	character(1) NOT NULL,
	token_unlock_time	timestamp with time zone  NULL,
	bad_logins	integer  NULL,
	last_updated	timestamp with time zone NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'token', false);
ALTER TABLE token
	ALTER token_id
	SET DEFAULT nextval('token_token_id_seq'::regclass);
ALTER TABLE token
	ALTER is_token_locked
	SET DEFAULT 'N'::bpchar;
INSERT INTO token (
	token_id,
	token_type,
	token_status,
	token_serial,
	zero_time,
	time_modulo,
	time_skew,
	token_key,
	encryption_key_id,
	token_password,		-- new column (token_password)
	expire_time,
	is_token_locked,		-- new column (is_token_locked)
	token_unlock_time,		-- new column (token_unlock_time)
	bad_logins,		-- new column (bad_logins)
	last_updated,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	token_id,
	token_type,
	token_status,
	token_serial,
	zero_time,
	time_modulo,
	time_skew,
	token_key,
	encryption_key_id,
	NULL,		-- new column (token_password)
	expire_time,
	'N'::bpchar,		-- new column (is_token_locked)
	NULL,		-- new column (token_unlock_time)
	NULL,		-- new column (bad_logins)
	last_updated,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM token_v64;

INSERT INTO audit.token (
	token_id,
	token_type,
	token_status,
	token_serial,
	zero_time,
	time_modulo,
	time_skew,
	token_key,
	encryption_key_id,
	token_password,		-- new column (token_password)
	expire_time,
	is_token_locked,		-- new column (is_token_locked)
	token_unlock_time,		-- new column (token_unlock_time)
	bad_logins,		-- new column (bad_logins)
	last_updated,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	token_id,
	token_type,
	token_status,
	token_serial,
	zero_time,
	time_modulo,
	time_skew,
	token_key,
	encryption_key_id,
	NULL,		-- new column (token_password)
	expire_time,
	NULL,		-- new column (is_token_locked)
	NULL,		-- new column (token_unlock_time)
	NULL,		-- new column (bad_logins)
	last_updated,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.token_v64;

ALTER TABLE token
	ALTER token_id
	SET DEFAULT nextval('token_token_id_seq'::regclass);
ALTER TABLE token
	ALTER is_token_locked
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE token ADD CONSTRAINT ak_token_token_key UNIQUE (token_key);
ALTER TABLE token ADD CONSTRAINT pk_token PRIMARY KEY (token_id);

-- Table/Column Comments
COMMENT ON COLUMN token.encryption_key_id IS 'encryption information for token_key, if used';
-- INDEXES
CREATE INDEX idx_token_tokenstatus ON token USING btree (token_status);
CREATE INDEX idx_token_tokentype ON token USING btree (token_type);

-- CHECK CONSTRAINTS
ALTER TABLE token ADD CONSTRAINT check_yes_no_tkn_islckd
	CHECK (is_token_locked = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE token ADD CONSTRAINT sys_c0020104
	CHECK (token_type IS NOT NULL);
ALTER TABLE token ADD CONSTRAINT sys_c0020105
	CHECK (last_updated IS NOT NULL);

-- FOREIGN KEYS FROM
-- consider FK token and account_token
ALTER TABLE account_token
	ADD CONSTRAINT fk_acct_token_ref_token
	FOREIGN KEY (token_id) REFERENCES token(token_id);
-- consider FK token and token_collection_token
ALTER TABLE token_collection_token
	ADD CONSTRAINT fk_tok_col_tok_token_id
	FOREIGN KEY (token_id) REFERENCES token(token_id);
-- consider FK token and token_sequence
ALTER TABLE token_sequence
	ADD CONSTRAINT fk_token_seq_ref_token
	FOREIGN KEY (token_id) REFERENCES token(token_id);

-- FOREIGN KEYS TO
-- consider FK token and encryption_key
ALTER TABLE token
	ADD CONSTRAINT fk_token_enc_id_id
	FOREIGN KEY (encryption_key_id) REFERENCES encryption_key(encryption_key_id);
-- consider FK token and val_token_status
ALTER TABLE token
	ADD CONSTRAINT fk_token_ref_v_token_status
	FOREIGN KEY (token_status) REFERENCES val_token_status(token_status);
-- consider FK token and val_token_type
ALTER TABLE token
	ADD CONSTRAINT fk_token_ref_v_token_type
	FOREIGN KEY (token_type) REFERENCES val_token_type(token_type);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'token');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'token');
ALTER SEQUENCE token_token_id_seq
	 OWNED BY token.token_id;
DROP TABLE IF EXISTS token_v64;
DROP TABLE IF EXISTS audit.token_v64;
-- DONE DEALING WITH TABLE token [3730795]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE volume_group [3722658]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'volume_group', 'volume_group');

-- FOREIGN KEYS FROM
ALTER TABLE logical_volume DROP CONSTRAINT IF EXISTS fk_logvol_vgid;
ALTER TABLE volume_group_purpose DROP CONSTRAINT IF EXISTS fk_val_volgrp_purp_vgid;
ALTER TABLE volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS fk_vgp_phy_vgrpid;
ALTER TABLE volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS fk_vgp_phy_vgrpid_devid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.volume_group DROP CONSTRAINT IF EXISTS fk_volgrp_devid;
ALTER TABLE jazzhands.volume_group DROP CONSTRAINT IF EXISTS fk_volgrp_rd_type;
ALTER TABLE jazzhands.volume_group DROP CONSTRAINT IF EXISTS fk_volgrp_volgrp_type;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'volume_group');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.volume_group DROP CONSTRAINT IF EXISTS ak_volgrp_devid_name_type;
ALTER TABLE jazzhands.volume_group DROP CONSTRAINT IF EXISTS ak_volume_group_devid_vgid;
ALTER TABLE jazzhands.volume_group DROP CONSTRAINT IF EXISTS ak_volume_group_vg_devid;
ALTER TABLE jazzhands.volume_group DROP CONSTRAINT IF EXISTS pk_volume_group;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_volgrp_devid";
DROP INDEX IF EXISTS "jazzhands"."xif_volgrp_rd_type";
DROP INDEX IF EXISTS "jazzhands"."xif_volgrp_volgrp_type";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_volume_group ON jazzhands.volume_group;
DROP TRIGGER IF EXISTS trigger_audit_volume_group ON jazzhands.volume_group;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'volume_group');
---- BEGIN audit.volume_group TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'volume_group', 'volume_group');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'volume_group');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."volume_group_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'volume_group');
---- DONE audit.volume_group TEARDOWN


ALTER TABLE volume_group RENAME TO volume_group_v64;
ALTER TABLE audit.volume_group RENAME TO volume_group_v64;

CREATE TABLE volume_group
(
	volume_group_id	integer NOT NULL,
	device_id	integer  NULL,
	component_id	integer  NULL,
	volume_group_name	varchar(50) NOT NULL,
	volume_group_type	varchar(50)  NULL,
	volume_group_size_in_bytes	bigint NOT NULL,
	raid_type	varchar(50)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'volume_group', false);
ALTER TABLE volume_group
	ALTER volume_group_id
	SET DEFAULT nextval('volume_group_volume_group_id_seq'::regclass);
INSERT INTO volume_group (
	volume_group_id,
	device_id,
	component_id,		-- new column (component_id)
	volume_group_name,
	volume_group_type,
	volume_group_size_in_bytes,
	raid_type,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	volume_group_id,
	device_id,
	NULL,		-- new column (component_id)
	volume_group_name,
	volume_group_type,
	volume_group_size_in_bytes,
	raid_type,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM volume_group_v64;

INSERT INTO audit.volume_group (
	volume_group_id,
	device_id,
	component_id,		-- new column (component_id)
	volume_group_name,
	volume_group_type,
	volume_group_size_in_bytes,
	raid_type,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	volume_group_id,
	device_id,
	NULL,		-- new column (component_id)
	volume_group_name,
	volume_group_type,
	volume_group_size_in_bytes,
	raid_type,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.volume_group_v64;

ALTER TABLE volume_group
	ALTER volume_group_id
	SET DEFAULT nextval('volume_group_volume_group_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE volume_group ADD CONSTRAINT ak_volume_group_devid_vgid UNIQUE (volume_group_id, device_id);
ALTER TABLE volume_group ADD CONSTRAINT ak_volume_group_vg_devid UNIQUE (volume_group_id, device_id);
ALTER TABLE volume_group ADD CONSTRAINT pk_volume_group PRIMARY KEY (volume_group_id);
ALTER TABLE volume_group ADD CONSTRAINT uq_volgrp_devid_name_type UNIQUE (device_id, component_id, volume_group_name, volume_group_type);

-- Table/Column Comments
COMMENT ON COLUMN volume_group.component_id IS 'if applicable, the component that hosts this volume group.  This is primarily used to indicate the hardware raid controller component that hosts the volume group.';
-- INDEXES
CREATE INDEX xif5volume_group ON volume_group USING btree (component_id);
CREATE INDEX xif_volgrp_devid ON volume_group USING btree (device_id);
CREATE INDEX xif_volgrp_rd_type ON volume_group USING btree (raid_type);
CREATE INDEX xif_volgrp_volgrp_type ON volume_group USING btree (volume_group_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK volume_group and logical_volume
ALTER TABLE logical_volume
	ADD CONSTRAINT fk_logvol_vgid
	FOREIGN KEY (volume_group_id, device_id) REFERENCES volume_group(volume_group_id, device_id) DEFERRABLE;
-- consider FK volume_group and volume_group_purpose
ALTER TABLE volume_group_purpose
	ADD CONSTRAINT fk_val_volgrp_purp_vgid
	FOREIGN KEY (volume_group_id) REFERENCES volume_group(volume_group_id) DEFERRABLE;
-- consider FK volume_group and volume_group_physicalish_vol
ALTER TABLE volume_group_physicalish_vol
	ADD CONSTRAINT fk_vgp_phy_vgrpid
	FOREIGN KEY (volume_group_id) REFERENCES volume_group(volume_group_id) DEFERRABLE;
-- consider FK volume_group and volume_group_physicalish_vol
ALTER TABLE volume_group_physicalish_vol
	ADD CONSTRAINT fk_vgp_phy_vgrpid_devid
	FOREIGN KEY (volume_group_id, device_id) REFERENCES volume_group(volume_group_id, device_id) DEFERRABLE;

-- FOREIGN KEYS TO
-- consider FK volume_group and component
ALTER TABLE volume_group
	ADD CONSTRAINT fk_vol_group_compon_id
	FOREIGN KEY (component_id) REFERENCES component(component_id);
-- consider FK volume_group and device
ALTER TABLE volume_group
	ADD CONSTRAINT fk_volgrp_devid
	FOREIGN KEY (device_id) REFERENCES device(device_id) DEFERRABLE;
-- consider FK volume_group and val_raid_type
ALTER TABLE volume_group
	ADD CONSTRAINT fk_volgrp_rd_type
	FOREIGN KEY (raid_type) REFERENCES val_raid_type(raid_type) DEFERRABLE;
-- consider FK volume_group and val_volume_group_type
ALTER TABLE volume_group
	ADD CONSTRAINT fk_volgrp_volgrp_type
	FOREIGN KEY (volume_group_type) REFERENCES val_volume_group_type(volume_group_type) DEFERRABLE;

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'volume_group');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'volume_group');
ALTER SEQUENCE volume_group_volume_group_id_seq
	 OWNED BY volume_group.volume_group_id;
DROP TABLE IF EXISTS volume_group_v64;
DROP TABLE IF EXISTS audit.volume_group_v64;
-- DONE DEALING WITH TABLE volume_group [3731869]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE volume_group_physicalish_vol [3722676]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'volume_group_physicalish_vol', 'volume_group_physicalish_vol');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS fk_physvol_vg_phsvol_dvid;
ALTER TABLE jazzhands.volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS fk_vg_physvol_vgrel;
ALTER TABLE jazzhands.volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS fk_vgp_phy_phyid;
ALTER TABLE jazzhands.volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS fk_vgp_phy_vgrpid;
ALTER TABLE jazzhands.volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS fk_vgp_phy_vgrpid_devid;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'volume_group_physicalish_vol');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS pk_volume_group_physicalish_vo;
ALTER TABLE jazzhands.volume_group_physicalish_vol DROP CONSTRAINT IF EXISTS uq_volgrp_pv_position;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_physvol_vg_phsvol_dvid";
DROP INDEX IF EXISTS "jazzhands"."xif_vg_physvol_vgrel";
DROP INDEX IF EXISTS "jazzhands"."xif_vgp_phy_phyid";
DROP INDEX IF EXISTS "jazzhands"."xif_vgp_phy_vgrpid";
DROP INDEX IF EXISTS "jazzhands"."xif_vgp_phy_vgrpid_devid";
DROP INDEX IF EXISTS "jazzhands"."xiq_volgrp_pv_position";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_volume_group_physicalish_vol ON jazzhands.volume_group_physicalish_vol;
DROP TRIGGER IF EXISTS trigger_audit_volume_group_physicalish_vol ON jazzhands.volume_group_physicalish_vol;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'volume_group_physicalish_vol');
---- BEGIN audit.volume_group_physicalish_vol TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'volume_group_physicalish_vol', 'volume_group_physicalish_vol');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'volume_group_physicalish_vol');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."volume_group_physicalish_vol_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'volume_group_physicalish_vol');
---- DONE audit.volume_group_physicalish_vol TEARDOWN


ALTER TABLE volume_group_physicalish_vol RENAME TO volume_group_physicalish_vol_v64;
ALTER TABLE audit.volume_group_physicalish_vol RENAME TO volume_group_physicalish_vol_v64;

CREATE TABLE volume_group_physicalish_vol
(
	physicalish_volume_id	integer NOT NULL,
	volume_group_id	integer NOT NULL,
	device_id	integer  NULL,
	volume_group_primary_pos	integer  NULL,
	volume_group_secondary_pos	integer  NULL,
	volume_group_relation	varchar(50) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'volume_group_physicalish_vol', false);
INSERT INTO volume_group_physicalish_vol (
	physicalish_volume_id,
	volume_group_id,
	device_id,
	volume_group_primary_pos,		-- new column (volume_group_primary_pos)
	volume_group_secondary_pos,		-- new column (volume_group_secondary_pos)
	volume_group_relation,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	physicalish_volume_id,
	volume_group_id,
	device_id,
	NULL,		-- new column (volume_group_primary_pos)
	NULL,		-- new column (volume_group_secondary_pos)
	volume_group_relation,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM volume_group_physicalish_vol_v64;

INSERT INTO audit.volume_group_physicalish_vol (
	physicalish_volume_id,
	volume_group_id,
	device_id,
	volume_group_primary_pos,		-- new column (volume_group_primary_pos)
	volume_group_secondary_pos,		-- new column (volume_group_secondary_pos)
	volume_group_relation,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	physicalish_volume_id,
	volume_group_id,
	device_id,
	NULL,		-- new column (volume_group_primary_pos)
	NULL,		-- new column (volume_group_secondary_pos)
	volume_group_relation,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.volume_group_physicalish_vol_v64;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE volume_group_physicalish_vol ADD CONSTRAINT pk_volume_group_physicalish_vo PRIMARY KEY (physicalish_volume_id, volume_group_id);
ALTER TABLE volume_group_physicalish_vol ADD CONSTRAINT uq_volgrp_pv_position UNIQUE (volume_group_id, volume_group_primary_pos) DEFERRABLE;

-- Table/Column Comments
COMMENT ON COLUMN volume_group_physicalish_vol.volume_group_primary_pos IS 'position within the primary raid, sometimes called span by at least one raid vendor.';
COMMENT ON COLUMN volume_group_physicalish_vol.volume_group_secondary_pos IS 'position within the secondary raid, sometimes called arm by at least one raid vendor.';
COMMENT ON COLUMN volume_group_physicalish_vol.volume_group_relation IS 'purpose of volume in raid (member, hotspare, etc, based on val table)
';
-- INDEXES
CREATE INDEX xif_physvol_vg_phsvol_dvid ON volume_group_physicalish_vol USING btree (physicalish_volume_id, device_id);
CREATE INDEX xif_vg_physvol_vgrel ON volume_group_physicalish_vol USING btree (volume_group_relation);
CREATE INDEX xif_vgp_phy_phyid ON volume_group_physicalish_vol USING btree (physicalish_volume_id);
CREATE INDEX xif_vgp_phy_vgrpid ON volume_group_physicalish_vol USING btree (volume_group_id);
CREATE INDEX xif_vgp_phy_vgrpid_devid ON volume_group_physicalish_vol USING btree (device_id, volume_group_id);
CREATE INDEX xiq_volgrp_pv_position ON volume_group_physicalish_vol USING btree (volume_group_id, volume_group_primary_pos);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK volume_group_physicalish_vol and physicalish_volume
ALTER TABLE volume_group_physicalish_vol
	ADD CONSTRAINT fk_physvol_vg_phsvol_dvid
	FOREIGN KEY (physicalish_volume_id, device_id) REFERENCES physicalish_volume(physicalish_volume_id, device_id) DEFERRABLE;
-- consider FK volume_group_physicalish_vol and val_volume_group_relation
ALTER TABLE volume_group_physicalish_vol
	ADD CONSTRAINT fk_vg_physvol_vgrel
	FOREIGN KEY (volume_group_relation) REFERENCES val_volume_group_relation(volume_group_relation) DEFERRABLE;
-- consider FK volume_group_physicalish_vol and physicalish_volume
ALTER TABLE volume_group_physicalish_vol
	ADD CONSTRAINT fk_vgp_phy_phyid
	FOREIGN KEY (physicalish_volume_id) REFERENCES physicalish_volume(physicalish_volume_id) DEFERRABLE;
-- consider FK volume_group_physicalish_vol and volume_group
ALTER TABLE volume_group_physicalish_vol
	ADD CONSTRAINT fk_vgp_phy_vgrpid
	FOREIGN KEY (volume_group_id) REFERENCES volume_group(volume_group_id) DEFERRABLE;
-- consider FK volume_group_physicalish_vol and volume_group
ALTER TABLE volume_group_physicalish_vol
	ADD CONSTRAINT fk_vgp_phy_vgrpid_devid
	FOREIGN KEY (volume_group_id, device_id) REFERENCES volume_group(volume_group_id, device_id) DEFERRABLE;

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'volume_group_physicalish_vol');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'volume_group_physicalish_vol');
DROP TABLE IF EXISTS volume_group_physicalish_vol_v64;
DROP TABLE IF EXISTS audit.volume_group_physicalish_vol_v64;
-- DONE DEALING WITH TABLE volume_group_physicalish_vol [3731888]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE x509_certificate [3722705]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'x509_certificate', 'x509_certificate');

-- FOREIGN KEYS FROM
ALTER TABLE x509_key_usage_attribute DROP CONSTRAINT IF EXISTS fk_x509_certificate;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS fk_x509_cert_cert;
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS fk_x509_cert_revoc_reason;
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS fk_x509cert_enc_id_id;

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('jazzhands', 'x509_certificate');

-- PRIMARY and ALTERNATE KEYS
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS ak_x509_cert_cert_ca_ser;
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS ak_x509_cert_ski;
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS pk_x509_certificate;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif3x509_certificate";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS check_yes_no_1933598984;
ALTER TABLE jazzhands.x509_certificate DROP CONSTRAINT IF EXISTS check_yes_no_31190954;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_x509_certificate ON jazzhands.x509_certificate;
DROP TRIGGER IF EXISTS trigger_audit_x509_certificate ON jazzhands.x509_certificate;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'x509_certificate');
---- BEGIN audit.x509_certificate TEARDOWN
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('audit', 'x509_certificate', 'x509_certificate');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO

-- EXTRA-SCHEMA constraints
SELECT schema_support.save_constraint_for_replay('audit', 'x509_certificate');

-- PRIMARY and ALTERNATE KEYS
-- INDEXES
DROP INDEX IF EXISTS "audit"."x509_certificate_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'x509_certificate');
---- DONE audit.x509_certificate TEARDOWN


ALTER TABLE x509_certificate RENAME TO x509_certificate_v64;
ALTER TABLE audit.x509_certificate RENAME TO x509_certificate_v64;

CREATE TABLE x509_certificate
(
	x509_cert_id	integer NOT NULL,
	friendly_name	varchar(255) NOT NULL,
	is_active	character(1) NOT NULL,
	is_certificate_authority	character(1) NOT NULL,
	signing_cert_id	integer  NULL,
	x509_ca_cert_serial_number	numeric  NULL,
	public_key	text  NULL,
	private_key	text  NULL,
	certificate_sign_req	text  NULL,
	subject	varchar(255) NOT NULL,
	subject_key_identifier	varchar(255)  NULL,
	valid_from	timestamp(6) without time zone NOT NULL,
	valid_to	timestamp(6) without time zone NOT NULL,
	x509_revocation_date	timestamp with time zone  NULL,
	x509_revocation_reason	varchar(50)  NULL,
	passphrase	varchar(255)  NULL,
	encryption_key_id	integer  NULL,
	ocsp_uri	varchar(255)  NULL,
	crl_uri	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'x509_certificate', false);
ALTER TABLE x509_certificate
	ALTER x509_cert_id
	SET DEFAULT nextval('x509_certificate_x509_cert_id_seq'::regclass);
ALTER TABLE x509_certificate
	ALTER is_active
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE x509_certificate
	ALTER is_certificate_authority
	SET DEFAULT 'N'::bpchar;
INSERT INTO x509_certificate (
	x509_cert_id,
	friendly_name,
	is_active,
	is_certificate_authority,
	signing_cert_id,
	x509_ca_cert_serial_number,
	public_key,
	private_key,
	certificate_sign_req,
	subject,
	subject_key_identifier,
	valid_from,
	valid_to,
	x509_revocation_date,
	x509_revocation_reason,
	passphrase,
	encryption_key_id,
	ocsp_uri,
	crl_uri,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	x509_cert_id,
	friendly_name,
	is_active,
	is_certificate_authority,
	signing_cert_id,
	x509_ca_cert_serial_number,
	public_key,
	private_key,
	certificate_sign_req,
	subject,
	subject_key_identifier,
	valid_from,
	valid_to,
	x509_revocation_date,
	x509_revocation_reason,
	passphrase,
	encryption_key_id,
	ocsp_uri,
	crl_uri,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM x509_certificate_v64;

INSERT INTO audit.x509_certificate (
	x509_cert_id,
	friendly_name,
	is_active,
	is_certificate_authority,
	signing_cert_id,
	x509_ca_cert_serial_number,
	public_key,
	private_key,
	certificate_sign_req,
	subject,
	subject_key_identifier,
	valid_from,
	valid_to,
	x509_revocation_date,
	x509_revocation_reason,
	passphrase,
	encryption_key_id,
	ocsp_uri,
	crl_uri,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	x509_cert_id,
	friendly_name,
	is_active,
	is_certificate_authority,
	signing_cert_id,
	x509_ca_cert_serial_number,
	public_key,
	private_key,
	certificate_sign_req,
	subject,
	subject_key_identifier,
	valid_from,
	valid_to,
	x509_revocation_date,
	x509_revocation_reason,
	passphrase,
	encryption_key_id,
	ocsp_uri,
	crl_uri,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.x509_certificate_v64;

ALTER TABLE x509_certificate
	ALTER x509_cert_id
	SET DEFAULT nextval('x509_certificate_x509_cert_id_seq'::regclass);
ALTER TABLE x509_certificate
	ALTER is_active
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE x509_certificate
	ALTER is_certificate_authority
	SET DEFAULT 'N'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE x509_certificate ADD CONSTRAINT ak_x509_cert_cert_ca_ser UNIQUE (signing_cert_id, x509_ca_cert_serial_number);
ALTER TABLE x509_certificate ADD CONSTRAINT ak_x509_cert_ski UNIQUE (subject_key_identifier);
ALTER TABLE x509_certificate ADD CONSTRAINT pk_x509_certificate PRIMARY KEY (x509_cert_id);

-- Table/Column Comments
COMMENT ON TABLE x509_certificate IS 'X509 specification Certificate.';
COMMENT ON COLUMN x509_certificate.x509_cert_id IS 'Uniquely identifies Certificate';
COMMENT ON COLUMN x509_certificate.friendly_name IS 'human readable name for certificate.  often just the CN.';
COMMENT ON COLUMN x509_certificate.is_active IS 'indicates certificate is in active use.  This is used by tools to decide how to show it; does not indicate revocation';
COMMENT ON COLUMN x509_certificate.signing_cert_id IS 'x509_cert_id for the certificate that has signed this one.';
COMMENT ON COLUMN x509_certificate.x509_ca_cert_serial_number IS 'Serial INTEGER assigned to the certificate within Certificate Authority. It uniquely identifies certificate within the realm of the CA.';
COMMENT ON COLUMN x509_certificate.public_key IS 'Textual representation of Certificate Public Key. Public Key is a component of X509 standard and is used for encryption.';
COMMENT ON COLUMN x509_certificate.private_key IS 'Textual representation of Certificate Private Key. Private Key is a component of X509 standard and is used for encryption.';
COMMENT ON COLUMN x509_certificate.subject IS 'Textual representation of a certificate subject. Certificate subject is a part of X509 certificate specifications.  This is the full subject from the certificate.  Friendly Name provides a human readable one.';
COMMENT ON COLUMN x509_certificate.subject_key_identifier IS 'colon seperate byte hex string with X509v3 SKI hash of the key in the same form as the x509 extension.  This should be NOT NULL but its hard to extract sometimes';
COMMENT ON COLUMN x509_certificate.valid_from IS 'Timestamp indicating when the certificate becomes valid and can be used.';
COMMENT ON COLUMN x509_certificate.valid_to IS 'Timestamp indicating when the certificate becomes invalid and can''t be used.';
COMMENT ON COLUMN x509_certificate.x509_revocation_date IS 'if certificate was revoked, when it was revokeed.  reason must also be set.   NULL means not revoked';
COMMENT ON COLUMN x509_certificate.x509_revocation_reason IS 'if certificate was revoked, why iit was revokeed.  date must also be set.   NULL means not revoked';
COMMENT ON COLUMN x509_certificate.passphrase IS 'passphrase to decrypt key.  If encrypted, encryption_key_id indicates how to decrypt.';
COMMENT ON COLUMN x509_certificate.encryption_key_id IS 'if set, encryption key information for decrypting passphrase.';
COMMENT ON COLUMN x509_certificate.ocsp_uri IS 'The URI (without URI: prefix) of the OCSP server for certs signed by this CA.  This is only valid for CAs.  This URI will be included in said certificates.';
COMMENT ON COLUMN x509_certificate.crl_uri IS 'The URI (without URI: prefix) of the CRL for certs signed by this CA.  This is only valid for CAs.  This URI will be included in said certificates.';
-- INDEXES
CREATE INDEX xif3x509_certificate ON x509_certificate USING btree (x509_revocation_reason);

-- CHECK CONSTRAINTS
ALTER TABLE x509_certificate ADD CONSTRAINT check_yes_no_1933598984
	CHECK (is_active = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));
ALTER TABLE x509_certificate ADD CONSTRAINT check_yes_no_31190954
	CHECK (is_certificate_authority = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK x509_certificate and x509_key_usage_attribute
ALTER TABLE x509_key_usage_attribute
	ADD CONSTRAINT fk_x509_certificate
	FOREIGN KEY (x509_cert_id) REFERENCES x509_certificate(x509_cert_id);

-- FOREIGN KEYS TO
-- consider FK x509_certificate and x509_certificate
ALTER TABLE x509_certificate
	ADD CONSTRAINT fk_x509_cert_cert
	FOREIGN KEY (signing_cert_id) REFERENCES x509_certificate(x509_cert_id);
-- consider FK x509_certificate and val_x509_revocation_reason
ALTER TABLE x509_certificate
	ADD CONSTRAINT fk_x509_cert_revoc_reason
	FOREIGN KEY (x509_revocation_reason) REFERENCES val_x509_revocation_reason(x509_revocation_reason);
-- consider FK x509_certificate and encryption_key
ALTER TABLE x509_certificate
	ADD CONSTRAINT fk_x509cert_enc_id_id
	FOREIGN KEY (encryption_key_id) REFERENCES encryption_key(encryption_key_id);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'x509_certificate');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'x509_certificate');
ALTER SEQUENCE x509_certificate_x509_cert_id_seq
	 OWNED BY x509_certificate.x509_cert_id;
DROP TABLE IF EXISTS x509_certificate_v64;
DROP TABLE IF EXISTS audit.x509_certificate_v64;
-- DONE DEALING WITH TABLE x509_certificate [3731917]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_property [3728247]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_property', 'v_property');
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'v_property');
DROP VIEW IF EXISTS jazzhands.v_property;
CREATE VIEW jazzhands.v_property AS
 SELECT property.property_id,
    property.account_collection_id,
    property.account_id,
    property.account_realm_id,
    property.company_collection_id,
    property.company_id,
    property.device_collection_id,
    property.dns_domain_collection_id,
    property.dns_domain_id,
    property.layer2_network_collection_id,
    property.layer3_network_collection_id,
    property.netblock_collection_id,
    property.operating_system_id,
    property.operating_system_snapshot_id,
    property.person_id,
    property.property_collection_id,
    property.service_env_collection_id,
    property.site_code,
    property.property_name,
    property.property_type,
    property.property_value,
    property.property_value_timestamp,
    property.property_value_company_id,
    property.property_value_account_coll_id,
    property.property_value_device_coll_id,
    property.property_value_nblk_coll_id,
    property.property_value_password_type,
    property.property_value_person_id,
    property.property_value_sw_package_id,
    property.property_value_token_col_id,
    property.property_rank,
    property.start_date,
    property.finish_date,
    property.is_enabled,
    property.data_ins_user,
    property.data_ins_date,
    property.data_upd_user,
    property.data_upd_date
   FROM property
  WHERE property.is_enabled = 'Y'::bpchar AND (property.start_date IS NULL AND property.finish_date IS NULL OR property.start_date IS NULL AND now() <= property.finish_date OR property.start_date <= now() AND property.finish_date IS NULL OR property.start_date <= now() AND now() <= property.finish_date);

delete from __recreate where type = 'view' and object = 'v_property';
-- DONE DEALING WITH TABLE v_property [3738009]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_acct_coll_prop_expanded [3728347]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_acct_coll_prop_expanded', 'v_acct_coll_prop_expanded');
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'v_acct_coll_prop_expanded');
DROP VIEW IF EXISTS jazzhands.v_acct_coll_prop_expanded;
CREATE VIEW jazzhands.v_acct_coll_prop_expanded AS
 SELECT v_acct_coll_expanded_detail.root_account_collection_id AS account_collection_id,
    v_property.property_id,
    v_property.property_name,
    v_property.property_type,
    v_property.property_value,
    v_property.property_value_timestamp,
    v_property.property_value_company_id,
    v_property.property_value_account_coll_id,
    v_property.property_value_nblk_coll_id,
    v_property.property_value_password_type,
    v_property.property_value_person_id,
    v_property.property_value_sw_package_id,
    v_property.property_value_token_col_id,
    v_property.property_rank,
	CASE val_property.is_multivalue
	    WHEN 'N'::bpchar THEN false
	    WHEN 'Y'::bpchar THEN true
	    ELSE NULL::boolean
	END AS is_multivalue,
	CASE ac.account_collection_type
	    WHEN 'per-user'::text THEN 0
	    ELSE
	    CASE v_acct_coll_expanded_detail.assign_method
		WHEN 'DirectAccountCollectionAssignment'::text THEN 10
		WHEN 'DirectDepartmentAssignment'::text THEN 200
		WHEN 'DepartmentAssignedToAccountCollection'::text THEN 300 + v_acct_coll_expanded_detail.dept_level + v_acct_coll_expanded_detail.acct_coll_level
		WHEN 'AccountAssignedToChildDepartment'::text THEN 400 + v_acct_coll_expanded_detail.dept_level
		WHEN 'AccountAssignedToChildAccountCollection'::text THEN 500 + v_acct_coll_expanded_detail.acct_coll_level
		WHEN 'DepartmentAssignedToChildAccountCollection'::text THEN 600 + v_acct_coll_expanded_detail.dept_level + v_acct_coll_expanded_detail.acct_coll_level
		WHEN 'ChildDepartmentAssignedToAccountCollection'::text THEN 700 + v_acct_coll_expanded_detail.dept_level + v_acct_coll_expanded_detail.acct_coll_level
		WHEN 'ChildDepartmentAssignedToChildAccountCollection'::text THEN 800 + v_acct_coll_expanded_detail.dept_level + v_acct_coll_expanded_detail.acct_coll_level
		ELSE 999
	    END
	END AS assign_rank
   FROM v_acct_coll_expanded_detail
     JOIN account_collection ac USING (account_collection_id)
     JOIN v_property USING (account_collection_id)
     JOIN val_property USING (property_name, property_type);

delete from __recreate where type = 'view' and object = 'v_acct_coll_prop_expanded';
-- DONE DEALING WITH TABLE v_acct_coll_prop_expanded [3738107]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_approval_instance_step_expanded
DROP VIEW IF EXISTS jazzhands.v_approval_instance_step_expanded;
CREATE VIEW jazzhands.v_approval_instance_step_expanded AS
 WITH RECURSIVE rai AS (
	 SELECT approval_instance_item.approval_instance_item_id AS root_item_id,
	    approval_instance_item.approval_instance_step_id AS root_step_id,
	    0 AS level,
	    approval_instance_item.approval_instance_step_id,
	    approval_instance_item.approval_instance_item_id,
	    approval_instance_item.next_approval_instance_item_id,
	    approval_instance_item.is_approved
	   FROM approval_instance_item
	  WHERE NOT (approval_instance_item.approval_instance_item_id IN ( SELECT approval_instance_item_1.next_approval_instance_item_id
		   FROM approval_instance_item approval_instance_item_1
		  WHERE approval_instance_item_1.next_approval_instance_item_id IS NOT NULL))
	UNION
	 SELECT rai.root_item_id,
	    rai.root_step_id,
	    rai.level + 1,
	    i.approval_instance_step_id,
	    i.approval_instance_item_id,
	    i.next_approval_instance_item_id,
	    i.is_approved
	   FROM approval_instance_item i
	     JOIN rai ON rai.next_approval_instance_item_id = i.approval_instance_item_id
	), q AS (
	 SELECT rai.root_item_id AS first_approval_instance_item_id,
	    rai.root_step_id,
	    rai.approval_instance_item_id,
	    rai.approval_instance_step_id,
	    rank() OVER (PARTITION BY rai.root_item_id ORDER BY rai.root_item_id, rai.level DESC) AS tier,
	    rai.level,
	    rai.is_approved
	   FROM rai
	)
 SELECT q.first_approval_instance_item_id,
    q.root_step_id,
    q.approval_instance_item_id,
    q.approval_instance_step_id,
    q.tier,
    q.level,
    q.is_approved
   FROM q;

delete from __recreate where type = 'view' and object = 'v_approval_instance_step_expanded';
-- DONE DEALING WITH TABLE v_approval_instance_step_expanded [3738248]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_property [3728247]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_property', 'v_property');
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'v_property');
DROP VIEW IF EXISTS jazzhands.v_property;
CREATE VIEW jazzhands.v_property AS
 SELECT property.property_id,
    property.account_collection_id,
    property.account_id,
    property.account_realm_id,
    property.company_collection_id,
    property.company_id,
    property.device_collection_id,
    property.dns_domain_collection_id,
    property.dns_domain_id,
    property.layer2_network_collection_id,
    property.layer3_network_collection_id,
    property.netblock_collection_id,
    property.operating_system_id,
    property.operating_system_snapshot_id,
    property.person_id,
    property.property_collection_id,
    property.service_env_collection_id,
    property.site_code,
    property.property_name,
    property.property_type,
    property.property_value,
    property.property_value_timestamp,
    property.property_value_company_id,
    property.property_value_account_coll_id,
    property.property_value_device_coll_id,
    property.property_value_nblk_coll_id,
    property.property_value_password_type,
    property.property_value_person_id,
    property.property_value_sw_package_id,
    property.property_value_token_col_id,
    property.property_rank,
    property.start_date,
    property.finish_date,
    property.is_enabled,
    property.data_ins_user,
    property.data_ins_date,
    property.data_upd_user,
    property.data_upd_date
   FROM property
  WHERE property.is_enabled = 'Y'::bpchar AND (property.start_date IS NULL AND property.finish_date IS NULL OR property.start_date IS NULL AND now() <= property.finish_date OR property.start_date <= now() AND property.finish_date IS NULL OR property.start_date <= now() AND now() <= property.finish_date);

delete from __recreate where type = 'view' and object = 'v_property';
-- DONE DEALING WITH TABLE v_property [3738009]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_token [3728269]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_token', 'v_token');
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'v_token');
DROP VIEW IF EXISTS jazzhands.v_token;
CREATE VIEW jazzhands.v_token AS
 SELECT t.token_id,
    t.token_type,
    t.token_status,
    t.token_serial,
    ts.token_sequence,
    ta.account_id,
    COALESCE(t.token_password, 'set'::character varying, NULL::character varying) AS token_password,
    t.zero_time,
    t.time_modulo,
    t.time_skew,
    t.is_token_locked,
    t.token_unlock_time,
    t.bad_logins,
    ta.issued_date,
    t.last_updated AS token_last_updated,
    ts.last_updated AS token_sequence_last_updated,
    t.last_updated AS lock_status_last_updated
   FROM token t
     LEFT JOIN token_sequence ts USING (token_id)
     LEFT JOIN account_token ta USING (token_id);

delete from __recreate where type = 'view' and object = 'v_token';
-- DONE DEALING WITH TABLE v_token [3738029]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_approval_matrix [3728463]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_approval_matrix', 'v_approval_matrix');
SELECT schema_support.save_dependant_objects_for_replay('approval_utils', 'v_approval_matrix');
DROP VIEW IF EXISTS approval_utils.v_approval_matrix;
CREATE VIEW approval_utils.v_approval_matrix AS
 SELECT ap.approval_process_id,
    ap.first_apprvl_process_chain_id,
    ap.approval_process_name,
    c.approval_chain_response_period AS approval_response_period,
    ap.approval_expiration_action,
    ap.attestation_frequency,
    ap.attestation_offset,
	CASE
	    WHEN ap.attestation_frequency::text = 'monthly'::text THEN to_char(now(), 'YYYY-MM'::text)
	    WHEN ap.attestation_frequency::text = 'weekly'::text THEN concat('week ', to_char(now(), 'WW'::text), ' - ', to_char(now(), 'YYY-MM-DD'::text))
	    WHEN ap.attestation_frequency::text = 'quarterly'::text THEN concat(to_char(now(), 'YYYY'::text), ' q', to_char(now(), 'Q'::text))
	    ELSE 'unknown'::text
	END AS current_attestation_name,
	CASE
	    WHEN ap.attestation_frequency::text = 'monthly'::text THEN date_trunc('month'::text, now())::timestamp without time zone + ((ap.attestation_offset || 'days'::text)::interval)
	    WHEN ap.attestation_frequency::text = 'weekly'::text THEN date_trunc('week'::text, now())::timestamp without time zone + ((ap.attestation_offset || 'days'::text)::interval)
	    WHEN ap.attestation_frequency::text = 'quarterly'::text THEN date_trunc('quarter'::text, now())::timestamp without time zone + ((ap.attestation_offset || 'days'::text)::interval)
	    ELSE '-infinity'::timestamp without time zone
	END AS current_attestation_begins,
    p.property_id,
    p.property_name,
    p.property_type,
    p.property_value,
    split_part(p.property_value::text, ':'::text, 1) AS property_val_lhs,
    split_part(p.property_value::text, ':'::text, 2) AS property_val_rhs,
    c.approval_process_chain_id,
    c.approving_entity,
    c.approval_process_chain_name,
    ap.description AS approval_process_description,
    c.description AS approval_chain_description
   FROM approval_process ap
     JOIN property_collection pc USING (property_collection_id)
     JOIN property_collection_property pcp USING (property_collection_id)
     JOIN property p USING (property_name, property_type)
     LEFT JOIN approval_process_chain c ON c.approval_process_chain_id = ap.first_apprvl_process_chain_id
  WHERE ap.approval_process_name::text = 'ReportingAttest'::text AND ap.approval_process_type::text = 'attestation'::text;

delete from __recreate where type = 'view' and object = 'v_approval_matrix';
-- DONE DEALING WITH TABLE v_approval_matrix [3738223]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_account_collection_approval_process [3728483]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_account_collection_approval_process', 'v_account_collection_approval_process');
SELECT schema_support.save_dependant_objects_for_replay('approval_utils', 'v_account_collection_approval_process');
DROP VIEW IF EXISTS approval_utils.v_account_collection_approval_process;
CREATE VIEW approval_utils.v_account_collection_approval_process AS
 WITH combo AS (
	 WITH foo AS (
		 SELECT mm.audit_seq_id,
		    mm.account_collection_id,
		    mm.account_collection_name,
		    mm.account_collection_type,
		    mm.login,
		    mm.account_id,
		    mm.person_id,
		    mm.company_id,
		    mm.first_name,
		    mm.last_name,
		    mm.manager_person_id,
		    mm.human_readable,
		    mm.manager_account_id,
		    mm.manager_login,
		    mm.manager_human_readable,
		    mx.approval_process_id,
		    mx.first_apprvl_process_chain_id,
		    mx.approval_process_name,
		    mx.approval_response_period,
		    mx.approval_expiration_action,
		    mx.attestation_frequency,
		    mx.attestation_offset,
		    mx.current_attestation_name,
		    mx.current_attestation_begins,
		    mx.property_id,
		    mx.property_name,
		    mx.property_type,
		    mx.property_value,
		    mx.property_val_lhs,
		    mx.property_val_rhs,
		    mx.approval_process_chain_id,
		    mx.approving_entity,
		    mx.approval_process_chain_name,
		    mx.approval_process_description,
		    mx.approval_chain_description
		   FROM approval_utils.v_account_collection_audit_results mm
		     JOIN approval_utils.v_approval_matrix mx ON mx.property_val_lhs = mm.account_collection_type::text
		  ORDER BY mm.manager_account_id, mm.account_id
		)
	 SELECT foo.login,
	    foo.account_id,
	    foo.person_id,
	    foo.company_id,
	    foo.manager_account_id,
	    foo.manager_login,
	    'account_collection_account'::text AS audit_table,
	    foo.audit_seq_id,
	    foo.approval_process_id,
	    foo.approval_process_chain_id,
	    foo.approving_entity,
	    foo.approval_process_description,
	    foo.approval_chain_description,
	    foo.approval_response_period,
	    foo.approval_expiration_action,
	    foo.attestation_frequency,
	    foo.current_attestation_name,
	    foo.current_attestation_begins,
	    foo.attestation_offset,
	    foo.approval_process_chain_name,
	    foo.account_collection_type AS approval_category,
	    concat('Verify ', foo.account_collection_type) AS approval_label,
	    foo.human_readable AS approval_lhs,
	    foo.account_collection_name AS approval_rhs
	   FROM foo
	UNION
	 SELECT mm.login,
	    mm.account_id,
	    mm.person_id,
	    mm.company_id,
	    mm.manager_account_id,
	    mm.manager_login,
	    'account_collection_account'::text AS audit_table,
	    mm.audit_seq_id,
	    mx.approval_process_id,
	    mx.approval_process_chain_id,
	    mx.approving_entity,
	    mx.approval_process_description,
	    mx.approval_chain_description,
	    mx.approval_response_period,
	    mx.approval_expiration_action,
	    mx.attestation_frequency,
	    mx.current_attestation_name,
	    mx.current_attestation_begins,
	    mx.attestation_offset,
	    mx.approval_process_chain_name,
	    mx.approval_process_name AS approval_category,
	    'Verify Manager'::text AS approval_label,
	    mm.human_readable AS approval_lhs,
	    concat('Reports to ', mm.manager_human_readable) AS approval_rhs
	   FROM approval_utils.v_approval_matrix mx
	     JOIN property p ON p.property_name::text = mx.property_val_rhs AND p.property_type::text = mx.property_val_lhs
	     JOIN approval_utils.v_account_collection_audit_results mm ON mm.account_collection_id = p.property_value_account_coll_id
	  WHERE p.account_id <> mm.account_id
	UNION
	 SELECT mm.login,
	    mm.account_id,
	    mm.person_id,
	    mm.company_id,
	    mm.manager_account_id,
	    mm.manager_login,
	    'person_company'::text AS audit_table,
	    pcm.audit_seq_id,
	    am.approval_process_id,
	    am.approval_process_chain_id,
	    am.approving_entity,
	    am.approval_process_description,
	    am.approval_chain_description,
	    am.approval_response_period,
	    am.approval_expiration_action,
	    am.attestation_frequency,
	    am.current_attestation_name,
	    am.current_attestation_begins,
	    am.attestation_offset,
	    am.approval_process_chain_name,
	    am.property_val_rhs AS approval_category,
		CASE
		    WHEN am.property_val_rhs = 'position_title'::text THEN 'Verify Position Title'::text
		    ELSE NULL::text
		END AS aproval_label,
	    mm.human_readable AS approval_lhs,
		CASE
		    WHEN am.property_val_rhs = 'position_title'::text THEN pcm.position_title
		    ELSE NULL::character varying
		END AS approval_rhs
	   FROM v_account_manager_map mm
	     JOIN approval_utils.v_person_company_audit_map pcm USING (person_id, company_id)
	     JOIN approval_utils.v_approval_matrix am ON am.property_val_lhs = 'person_company'::text AND am.property_val_rhs = 'position_title'::text
	)
 SELECT combo.login,
    combo.account_id,
    combo.person_id,
    combo.company_id,
    combo.manager_account_id,
    combo.manager_login,
    combo.audit_table,
    combo.audit_seq_id,
    combo.approval_process_id,
    combo.approval_process_chain_id,
    combo.approving_entity,
    combo.approval_process_description,
    combo.approval_chain_description,
    combo.approval_response_period,
    combo.approval_expiration_action,
    combo.attestation_frequency,
    combo.current_attestation_name,
    combo.current_attestation_begins,
    combo.attestation_offset,
    combo.approval_process_chain_name,
    combo.approval_category,
    combo.approval_label,
    combo.approval_lhs,
    combo.approval_rhs
   FROM combo
  WHERE combo.manager_account_id <> combo.account_id
  ORDER BY combo.manager_login, combo.account_id, combo.approval_label;

delete from __recreate where type = 'view' and object = 'v_account_collection_approval_process';
-- DONE DEALING WITH TABLE v_account_collection_approval_process [3738243]
--------------------------------------------------------------------
--
-- Process trigger procs in jazzhands
--
-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_automated_reporting_ac');
CREATE OR REPLACE FUNCTION jazzhands.account_automated_reporting_ac()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
	_numrpt	INTEGER;
	_r		RECORD;
BEGIN
	IF TG_OP = 'DELETE' THEN
		IF OLD.account_role != 'primary' THEN
			RETURN OLD;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.account_role != 'primary' AND OLD.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
	END IF;

	-- XXX check account realm to see if we should be inserting for this
	-- XXX account realm

	IF TG_OP = 'INSERT' THEN
		PERFORM auto_ac_manip.make_all_auto_acs_right(
			account_id := NEW.account_id, 
			account_realm_id := NEW.account_realm_id,
			login := NEW.login
		);
	ELSIF TG_OP = 'UPDATE' THEN
		PERFORM auto_ac_manip.rename_automated_report_acs(
			NEW.account_id, OLD.login, NEW.login, NEW.account_realm_id);
	ELSIF TG_OP = 'DELETE' THEN
		DELETE FROM account_collection_account WHERE account_id
			= OLD.account_id
		AND account_collection_id IN ( select account_collection_id
			FROM account_collection where account_collection_type
			= 'automated'
		);
		-- PERFORM auto_ac_manip.destroy_report_account_collections(
		-- 	account_id := OLD.account_id,
		-- 	account_realm_id := OLD.account_realm_id
		-- );
	END IF;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_collection_hier_enforce');
CREATE OR REPLACE FUNCTION jazzhands.account_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	act	val_account_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	act
	FROM	val_account_collection_type
	WHERE	account_collection_type =
		(select account_collection_type from account_collection
			where account_collection_id = NEW.account_collection_id);

	IF act.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Account Collections of type % may not be hierarcical',
			act.account_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'account_collection_member_enforce');
CREATE OR REPLACE FUNCTION jazzhands.account_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	act	val_account_collection_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	act
	FROM	val_account_collection_type
	WHERE	account_collection_type =
		(select account_collection_type from account_collection
			where account_collection_id = NEW.account_collection_id);

	IF act.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from account_collection_account
		  where account_collection_id = NEW.account_collection_id;
		IF tally > act.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF act.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from account_collection_account
		  		inner join account_collection using (account_collection_id)
		  where account_id = NEW.account_id
		  and	account_collection_type = act.account_collection_type;
		IF tally > act.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Account may not be a member of more than % collections of type %',
				act.MAX_NUM_COLLECTIONS, act.account_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'automated_ac_on_account');
CREATE OR REPLACE FUNCTION jazzhands.automated_ac_on_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
	_r		RECORD;
BEGIN
	IF TG_OP = 'DELETE' THEN
		IF OLD.account_role != 'primary' THEN
			RETURN OLD;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.account_role != 'primary' AND OLD.account_role != 'primary' THEN
			RETURN NEW;
		END IF;
	END IF;


	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE'  THEN
		PERFORM auto_ac_manip.make_site_acs_right(NEW.account_id);
		PERFORM auto_ac_manip.make_personal_acs_right(NEW.account_id);

		-- update the person's manager to match
		WITH RECURSIVE map AS (
			SELECT account_id as root_account_id,
				account_id, login, manager_account_id, manager_login
			FROM v_account_manager_map
			UNION
			SELECT map.root_account_id, m.account_id, m.login,
				m.manager_account_id, m.manager_login 
				from v_account_manager_map m
					join map on m.account_id = map.manager_account_id
			), x AS ( SELECT auto_ac_manip.make_auto_report_acs_right(
					account_id := manager_account_id,
					account_realm_id := NEW.account_realm_id,
					login := manager_login)
				FROM map
				WHERE root_account_id = NEW.account_id
			) SELECT count(*) INTO _tally FROM x;
	END IF;

	IF TG_OP = 'UPDATE'  THEN
		PERFORM auto_ac_manip.make_site_acs_right(OLD.account_id);
		PERFORM auto_ac_manip.make_personal_acs_right(OLD.account_id);
	END IF;

	-- when deleting, do nothing rather than calling the above, same as
	-- update; pointless because account is getting deleted anyway.

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'automated_ac_on_person_company');
CREATE OR REPLACE FUNCTION jazzhands.automated_ac_on_person_company()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
	_r		RECORD;
BEGIN
	IF ( TG_OP = 'INSERT' OR TG_OP = 'UPDATE' ) THEN
		PERFORM	auto_ac_manip.make_personal_acs_right(account_id)
		FROM	v_corp_family_account
				INNER JOIN person_company USING (person_id,company_id)
		WHERE	account_role = 'primary'
		AND		person_id = NEW.person_id
		AND		company_id = NEW.company_id;

		IF ( TG_OP = 'INSERT' OR ( TG_OP = 'UPDATE' AND 
				NEW.manager_person_id != OLD.manager_person_id ) 
		) THEN
			-- update the person's manager to match
			WITH RECURSIVE map As (
				SELECT account_id as root_account_id,
					account_id, login, manager_account_id, manager_login
				FROM v_account_manager_map
				UNION
				SELECT map.root_account_id, m.account_id, m.login,
					m.manager_account_id, m.manager_login 
					from v_account_manager_map m
						join map on m.account_id = map.manager_account_id
			), x AS ( SELECT auto_ac_manip.make_auto_report_acs_right(
						account_id := manager_account_id,
						account_realm_id := account_realm_id,
						login := manager_login)
					FROM map m
							join v_corp_family_account a ON
								a.account_id = m.root_account_id
					WHERE a.person_id = NEW.person_id
					AND a.company_id = NEW.company_id
			) SELECT count(*) into _tally from x;
			IF TG_OP = 'UPDATE' THEN
				PERFORM auto_ac_manip.make_auto_report_acs_right(
							account_id := account_id)
				FROM    v_corp_family_account
				WHERE   account_role = 'primary'
				AND     is_enabled = 'Y'
				AND     person_id = OLD.manager_person_id;
			END IF;
		END IF;
	END IF;

	IF ( TG_OP = 'DELETE' OR TG_OP = 'UPDATE' ) THEN
		PERFORM	auto_ac_manip.make_personal_acs_right(account_id)
		FROM	v_corp_family_account
				INNER JOIN person_company USING (person_id,company_id)
		WHERE	account_role = 'primary'
		AND		person_id = OLD.person_id
		AND		company_id = OLD.company_id;
	END IF;
	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_rec_prevent_dups');
CREATE OR REPLACE FUNCTION jazzhands.dns_rec_prevent_dups()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	-- should not be able to insert the same record(s) twice
	SELECT	count(*)
	  INTO	_tally
	  FROM	dns_record
	  WHERE
	  		( lower(dns_name) = lower(NEW.dns_name) OR 
				(dns_name IS NULL AND NEW.dns_name is NULL)
			)
		AND
	  		( dns_domain_id = NEW.dns_domain_id )
		AND
	  		( dns_class = NEW.dns_class )
		AND
	  		( dns_type = NEW.dns_type )
		AND 
	  		( dns_srv_service = NEW.dns_srv_service OR 
				(dns_srv_service IS NULL and NEW.dns_srv_service is NULL)
			)
		AND 
	  		( dns_srv_protocol = NEW.dns_srv_protocol OR 
				(dns_srv_protocol IS NULL and NEW.dns_srv_protocol is NULL)
			)
		AND 
	  		( dns_srv_port = NEW.dns_srv_port OR 
				(dns_srv_port IS NULL and NEW.dns_srv_port is NULL)
			)
		AND 
	  		( dns_value = NEW.dns_value OR 
				(dns_value IS NULL and NEW.dns_value is NULL)
			)
		AND
	  		( netblock_id = NEW.netblock_id OR 
				(netblock_id IS NULL AND NEW.netblock_id is NULL)
			)
		AND	is_enabled = 'Y'
	    AND dns_record_id != NEW.dns_record_id
	;

	IF _tally != 0 THEN
		RAISE EXCEPTION 'Attempt to insert the same dns record'
			USING ERRCODE = 'unique_violation';
	END IF;

	IF NEW.DNS_TYPE = 'A' OR NEW.DNS_TYPE = 'AAAA' THEN
		IF NEW.SHOULD_GENERATE_PTR = 'Y' THEN
			SELECT	count(*)
			 INTO	_tally
			 FROM	dns_record
			WHERE dns_class = 'IN' 
			AND dns_type = 'A' 
			AND should_generate_ptr = 'Y'
			AND is_enabled = 'Y'
			AND netblock_id = NEW.NETBLOCK_ID
			AND dns_record_id != NEW.DNS_RECORD_ID;
	
			IF _tally != 0 THEN
				RAISE EXCEPTION 'May not have more than one SHOULD_GENERATE_PTR record on the same IP on netblock_id %', NEW.netblock_id
					USING ERRCODE = 'JH201';
			END IF;
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_record_cname_checker');
CREATE OR REPLACE FUNCTION jazzhands.dns_record_cname_checker()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;	
	_dom	TEXT;
BEGIN
	_tally := 0;
	IF TG_OP = 'INSERT' OR NEW.DNS_TYPE != OLD.DNS_TYPE THEN
		IF NEW.DNS_TYPE = 'CNAME' THEN
			IF TG_OP = 'UPDATE' THEN
			SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE	
				 		NEW.dns_domain_id = x.dns_domain_id
				 AND	OLD.dns_record_id != x.dns_record_id
				 AND	(
				 			NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			ELSE
				-- only difference between above and this is the use of OLD
				SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE	
				 		NEW.dns_domain_id = x.dns_domain_id
				 AND	(
				 			NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			END IF;
		-- this clause is basically the same as above except = 'CANME'
		ELSIF NEW.DNS_TYPE != 'CNAME' THEN
			IF TG_OP = 'UPDATE' THEN
				SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE	x.dns_type = 'CNAME'
				 AND	NEW.dns_domain_id = x.dns_domain_id
				 AND	OLD.dns_record_id != x.dns_record_id
				 AND	(
				 			NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			ELSE
				-- only difference between above and this is the use of OLD
				SELECT	COUNT(*)
				  INTO	_tally
				  FROM	dns_record x
				 WHERE	x.dns_type = 'CNAME'
				 AND	NEW.dns_domain_id = x.dns_domain_id
				 AND	(
				 			NEW.dns_name IS NULL and x.dns_name is NULL
							or
							lower(NEW.dns_name) = lower(x.dns_name)
						)
				;
			END IF;
		END IF;
	END IF;

	IF _tally > 0 THEN
		SELECT soa_name INTO _dom FROM dns_domain
		WHERE dns_domain_id = NEW.dns_domain_id ;

		if NEW.dns_name IS NULL THEN
			RAISE EXCEPTION '% may not have CNAME and other records (%)', 
				_dom, _tally
				USING ERRCODE = 'unique_violation';
		ELSE
			RAISE EXCEPTION '%.% may not have CNAME and other records (%)', 
				NEW.dns_name, _dom, _tally
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'dns_record_update_nontime');
CREATE OR REPLACE FUNCTION jazzhands.dns_record_update_nontime()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_dnsdomainid	DNS_DOMAIN.DNS_DOMAIN_ID%type;
	_ipaddr			NETBLOCK.IP_ADDRESS%type;
	_mkold			boolean;
	_mknew			boolean;
	_mkdom			boolean;
	_mkip			boolean;
BEGIN
	_mkold = false;
	_mkold = false;
	_mknew = true;

	IF TG_OP = 'DELETE' THEN
		_mknew := false;
		_mkold := true;
		_mkdom := true;
		if  OLD.netblock_id is not null  THEN
			_mkip := true;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		_mkold := false;
		_mkdom := true;
		if  NEW.netblock_id is not null  THEN
			_mkip := true;
		END IF;
	ELSIF TG_OP = 'UPDATE' THEN
		IF OLD.DNS_DOMAIN_ID != NEW.DNS_DOMAIN_ID THEN
			_mkold := true;
			_mkip := true;
		END IF;
		_mkdom := true;

		IF OLD.dns_name IS DISTINCT FROM NEW.dns_name THEN
			_mknew := true;
			IF NEW.DNS_TYPE = 'A' OR NEW.DNS_TYPE = 'AAAA' THEN
				IF NEW.SHOULD_GENERATE_PTR = 'Y' THEN
					_mkip := true;
				END IF;
			END IF;
		END IF;

		IF OLD.SHOULD_GENERATE_PTR != NEW.SHOULD_GENERATE_PTR THEN
			_mkold := true;
			_mkip := true;
		END IF;

		IF (OLD.netblock_id IS DISTINCT FROM NEW.netblock_id) THEN
			_mkold := true;
			_mknew := true;
			_mkip := true;
		END IF;
	END IF;
				
	if _mkold THEN
		IF _mkdom THEN
			_dnsdomainid := OLD.dns_domain_id;
		ELSE
			_dnsdomainid := NULL;
		END IF;
		if _mkip and OLD.netblock_id is not NULL THEN
			SELECT	ip_address 
			  INTO	_ipaddr 
			  FROM	netblock 
			 WHERE	netblock_id  = OLD.netblock_id;
		ELSE
			_ipaddr := NULL;
		END IF;
		insert into DNS_CHANGE_RECORD
			(dns_domain_id, ip_address) VALUES (_dnsdomainid, _ipaddr);
	END IF;
	if _mknew THEN
		if _mkdom THEN
			_dnsdomainid := NEW.dns_domain_id;
		ELSE
			_dnsdomainid := NULL;
		END IF;
		if _mkip and NEW.netblock_id is not NULL THEN
			SELECT	ip_address 
			  INTO	_ipaddr 
			  FROM	netblock 
			 WHERE	netblock_id  = NEW.netblock_id;
		ELSE
			_ipaddr := NULL;
		END IF;
		insert into DNS_CHANGE_RECORD
			(dns_domain_id, ip_address) VALUES (_dnsdomainid, _ipaddr);
	END IF;
	IF TG_OP = 'DELETE' THEN
		return OLD;
	END IF;
	return NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'netblock_collection_hier_enforce');
CREATE OR REPLACE FUNCTION jazzhands.netblock_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	nct	val_netblock_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	nct
	FROM	val_netblock_collection_type
	WHERE	netblock_collection_type =
		(select netblock_collection_type from netblock_collection
			where netblock_collection_id = NEW.netblock_collection_id);

	IF nct.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Netblock Collections of type % may not be hierarcical',
			nct.netblock_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'netblock_collection_member_enforce');
CREATE OR REPLACE FUNCTION jazzhands.netblock_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	nct	val_netblock_collection_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	nct
	FROM	val_netblock_collection_type
	WHERE	netblock_collection_type =
		(select netblock_collection_type from netblock_collection
			where netblock_collection_id = NEW.netblock_collection_id);

	IF nct.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from netblock_collection_netblock
		  where netblock_collection_id = NEW.netblock_collection_id;
		IF tally > nct.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF nct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from netblock_collection_netblock
		  		inner join netblock_collection using (netblock_collection_id)
		  where netblock_id = NEW.netblock_id
		  and	netblock_collection_type = nct.netblock_collection_type;
		IF tally > nct.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Netblock may not be a member of more than % collections of type %',
				nct.MAX_NUM_COLLECTIONS, nct.netblock_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'property_collection_hier_enforce');
CREATE OR REPLACE FUNCTION jazzhands.property_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	pct	val_property_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	pct
	FROM	val_property_collection_type
	WHERE	property_collection_type =
		(select property_collection_type from property_collection
			where property_collection_id = NEW.property_collection_id);

	IF pct.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Property Collections of type % may not be hierarcical',
			pct.property_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'property_collection_member_enforce');
CREATE OR REPLACE FUNCTION jazzhands.property_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	pct	val_property_collection_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	pct
	FROM	val_property_collection_type
	WHERE	property_collection_type =
		(select property_collection_type from property_collection
			where property_collection_id = NEW.property_collection_id);

	IF pct.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from property_collection_property
		  where property_collection_id = NEW.property_collection_id;
		IF tally > pct.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF pct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from property_collection_property
		  		inner join property_collection using (property_collection_id)
		  where	
				property_name = NEW.property_name
		  and	property_type = NEW.property_type
		  and	property_collection_type = pct.property_collection_type;
		IF tally > pct.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Property may not be a member of more than % collections of type %',
				pct.MAX_NUM_COLLECTIONS, pct.property_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'service_environment_coll_hier_enforce');
CREATE OR REPLACE FUNCTION jazzhands.service_environment_coll_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	svcenvt	val_service_env_coll_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	svcenvt
	FROM	val_service_env_coll_type
	WHERE	service_env_collection_type =
		(select service_env_collection_type 
			from service_environment_collection
			where service_env_collection_id = 
				NEW.service_env_collection_id);

	IF svcenvt.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Service Environment Collections of type % may not be hierarcical',
			svcenvt.service_env_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'service_environment_collection_member_enforce');
CREATE OR REPLACE FUNCTION jazzhands.service_environment_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	svcenvt	val_service_env_coll_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	svcenvt
	FROM	val_service_env_coll_type
	WHERE	service_env_collection_type =
		(select service_env_collection_type 
			from service_environment_collection
			where service_env_collection_id = 
				NEW.service_env_collection_id);

	IF svcenvt.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from svc_environment_coll_svc_env
		  where service_env_collection_id = NEW.service_env_collection_id;
		IF tally > svcenvt.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF svcenvt.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from svc_environment_coll_svc_env
		  		inner join service_environment_collection 
					USING (service_env_collection_id)
		  where service_environment_id = NEW.service_environment_id
		  and	service_env_collection_type = 
					svcenvt.service_env_collection_type;
		IF tally > svcenvt.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Service Environment may not be a member of more than % collections of type %',
				svcenvt.MAX_NUM_COLLECTIONS, svcenvt.service_env_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'token_collection_hier_enforce');
CREATE OR REPLACE FUNCTION jazzhands.token_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	tct	val_token_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	tct
	FROM	val_token_collection_type
	WHERE	token_collection_type =
		(select token_collection_type from token_collection
			where token_collection_id = NEW.token_collection_id);

	IF tct.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Token Collections of type % may not be hierarcical',
			tct.token_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'token_collection_member_enforce');
CREATE OR REPLACE FUNCTION jazzhands.token_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	tct	val_token_collection_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	tct
	FROM	val_token_collection_type
	WHERE	token_collection_type =
		(select token_collection_type from token_collection
			where token_collection_id = NEW.token_collection_id);

	IF tct.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from token_collection_token
		  where token_collection_id = NEW.token_collection_id;
		IF tally > tct.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF tct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from token_collection_token
		  		inner join token_collection using (token_collection_id)
		  where token_id = NEW.token_id
		  and	token_collection_type = tct.token_collection_type;
		IF tally > tct.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Token may not be a member of more than % collections of type %',
				tct.MAX_NUM_COLLECTIONS, tct.token_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- Changed function
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_property');
CREATE OR REPLACE FUNCTION jazzhands.validate_property()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally				integer;
	v_prop				VAL_Property%ROWTYPE;
	v_proptype			VAL_Property_Type%ROWTYPE;
	v_account_collection		account_collection%ROWTYPE;
	v_company_collection		company_collection%ROWTYPE;
	v_device_collection		device_collection%ROWTYPE;
	v_dns_domain_collection		dns_domain_collection%ROWTYPE;
	v_layer2_network_collection	layer2_network_collection%ROWTYPE;
	v_layer3_network_collection	layer3_network_collection%ROWTYPE;
	v_netblock_collection		netblock_collection%ROWTYPE;
	v_property_collection		property_collection%ROWTYPE;
	v_service_env_collection	service_environment_collection%ROWTYPE;
	v_num				integer;
	v_listvalue			Property.Property_Value%TYPE;
BEGIN

	-- Pull in the data from the property and property_type so we can
	-- figure out what is and is not valid

	BEGIN
		SELECT * INTO STRICT v_prop FROM VAL_Property WHERE
			Property_Name = NEW.Property_Name AND
			Property_Type = NEW.Property_Type;

		SELECT * INTO STRICT v_proptype FROM VAL_Property_Type WHERE
			Property_Type = NEW.Property_Type;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			RAISE EXCEPTION
				'Property name or type does not exist'
				USING ERRCODE = 'foreign_key_violation';
			RETURN NULL;
	END;

	-- Check to see if the property itself is multivalue.  That is, if only
	-- one value can be set for this property for a specific property LHS
	IF (v_prop.is_multivalue = 'N') THEN
		PERFORM 1 FROM Property WHERE
			Property_Id != NEW.Property_Id AND
			Property_Name = NEW.Property_Name AND
			Property_Type = NEW.Property_Type AND
			account_collection_id IS NOT DISTINCT FROM NEW.account_collection_id
				AND
			account_id IS NOT DISTINCT FROM NEW.account_id AND
			account_realm_id IS NOT DISTINCT FROM NEW.account_realm_id AND
			company_collection_id IS NOT DISTINCT FROM NEW.company_collection_id AND
			company_id IS NOT DISTINCT FROM NEW.company_id AND
			device_collection_id IS NOT DISTINCT FROM NEW.device_collection_id AND
			dns_domain_collection_id IS NOT DISTINCT FROM
				NEW.dns_domain_collection_id AND
			dns_domain_id IS NOT DISTINCT FROM NEW.dns_domain_id AND
			layer2_network_collection_id IS NOT DISTINCT FROM
				NEW.layer2_network_collection_id AND
			layer3_network_collection_id IS NOT DISTINCT FROM
				NEW.layer3_network_collection_id AND
			netblock_collection_id IS NOT DISTINCT FROM NEW.netblock_collection_id AND
			operating_system_id IS NOT DISTINCT FROM NEW.operating_system_id AND
			operating_system_snapshot_id IS NOT DISTINCT FROM
				NEW.operating_system_snapshot_id AND
			person_id IS NOT DISTINCT FROM NEW.person_id AND
			property_collection_id IS NOT DISTINCT FROM NEW.property_collection_id AND
			service_env_collection_id IS NOT DISTINCT FROM
				NEW.service_env_collection_id AND
			site_code IS NOT DISTINCT FROM NEW.site_code
		;

		IF FOUND THEN
			RAISE EXCEPTION
				'Property of type (%,%) already exists for given LHS and property is not multivalue',
				NEW.Property_Name, NEW.Property_Type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;
	ELSE
		-- check for the same lhs+rhs existing, which is basically a dup row
		PERFORM 1 FROM Property WHERE
			Property_Id != NEW.Property_Id AND
			Property_Name = NEW.Property_Name AND
			Property_Type = NEW.Property_Type AND
			account_collection_id IS NOT DISTINCT FROM NEW.account_collection_id
				AND
			account_id IS NOT DISTINCT FROM NEW.account_id AND
			account_realm_id IS NOT DISTINCT FROM NEW.account_realm_id AND
			company_collection_id IS NOT DISTINCT FROM NEW.company_collection_id AND
			company_id IS NOT DISTINCT FROM NEW.company_id AND
			device_collection_id IS NOT DISTINCT FROM NEW.device_collection_id AND
			dns_domain_collection_id IS NOT DISTINCT FROM
				NEW.dns_domain_collection_id AND
			dns_domain_id IS NOT DISTINCT FROM NEW.dns_domain_id AND
			layer2_network_collection_id IS NOT DISTINCT FROM
				NEW.layer2_network_collection_id AND
			layer3_network_collection_id IS NOT DISTINCT FROM
				NEW.layer3_network_collection_id AND
			netblock_collection_id IS NOT DISTINCT FROM NEW.netblock_collection_id AND
			operating_system_id IS NOT DISTINCT FROM NEW.operating_system_id AND
			operating_system_snapshot_id IS NOT DISTINCT FROM
				NEW.operating_system_snapshot_id AND
			person_id IS NOT DISTINCT FROM NEW.person_id AND
			property_collection_id IS NOT DISTINCT FROM NEW.property_collection_id AND
			service_env_collection_id IS NOT DISTINCT FROM
				NEW.service_env_collection_id AND
			site_code IS NOT DISTINCT FROM NEW.site_code AND
			property_value IS NOT DISTINCT FROM NEW.property_value AND
			property_value_timestamp IS NOT DISTINCT FROM
				NEW.property_value_timestamp AND
			property_value_company_id IS NOT DISTINCT FROM
				NEW.property_value_company_id AND
			property_value_account_coll_id IS NOT DISTINCT FROM
				NEW.property_value_account_coll_id AND
			property_value_device_coll_id IS NOT DISTINCT FROM
				NEW.property_value_device_coll_id AND
			property_value_nblk_coll_id IS NOT DISTINCT FROM
				NEW.property_value_nblk_coll_id AND
			property_value_password_type IS NOT DISTINCT FROM
				NEW.property_value_password_type AND
			property_value_person_id IS NOT DISTINCT FROM
				NEW.property_value_person_id AND
			property_value_sw_package_id IS NOT DISTINCT FROM
				NEW.property_value_sw_package_id AND
			property_value_token_col_id IS NOT DISTINCT FROM
				NEW.property_value_token_col_id AND
			start_date IS NOT DISTINCT FROM NEW.start_date AND
			finish_date IS NOT DISTINCT FROM NEW.finish_date
		;

		IF FOUND THEN
			RAISE EXCEPTION
				'Property of (n,t) (%,%) already exists for given property',
				NEW.Property_Name, NEW.Property_Type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;

	END IF;

	-- Check to see if the property type is multivalue.  That is, if only
	-- one property and value can be set for any properties with this type
	-- for a specific property LHS

	IF (v_proptype.is_multivalue = 'N') THEN
		PERFORM 1 FROM Property WHERE
			Property_Id != NEW.Property_Id AND
			Property_Type = NEW.Property_Type AND
			account_collection_id IS NOT DISTINCT FROM NEW.account_collection_id
				AND
			account_id IS NOT DISTINCT FROM NEW.account_id AND
			account_realm_id IS NOT DISTINCT FROM NEW.account_realm_id AND
			company_collection_id IS NOT DISTINCT FROM NEW.company_collection_id AND
			company_id IS NOT DISTINCT FROM NEW.company_id AND
			device_collection_id IS NOT DISTINCT FROM NEW.device_collection_id AND
			dns_domain_collection_id IS NOT DISTINCT FROM
				NEW.dns_domain_collection_id AND
			dns_domain_id IS NOT DISTINCT FROM NEW.dns_domain_id AND
			layer2_network_collection_id IS NOT DISTINCT FROM
				NEW.layer2_network_collection_id AND
			layer3_network_collection_id IS NOT DISTINCT FROM
				NEW.layer3_network_collection_id AND
			netblock_collection_id IS NOT DISTINCT FROM NEW.netblock_collection_id AND
			operating_system_id IS NOT DISTINCT FROM NEW.operating_system_id AND
			operating_system_snapshot_id IS NOT DISTINCT FROM
				NEW.operating_system_snapshot_id AND
			person_id IS NOT DISTINCT FROM NEW.person_id AND
			property_collection_id IS NOT DISTINCT FROM NEW.property_collection_id AND
			service_env_collection_id IS NOT DISTINCT FROM
				NEW.service_env_collection_id AND
			site_code IS NOT DISTINCT FROM NEW.site_code
		;

		IF FOUND THEN
			RAISE EXCEPTION
				'Property % of type % already exists for given LHS and property type is not multivalue',
				NEW.Property_Name, NEW.Property_Type
				USING ERRCODE = 'unique_violation';
			RETURN NULL;
		END IF;
	END IF;

	-- now validate the property_value columns.
	tally := 0;

	--
	-- first determine if the property_value is set properly.
	--

	-- iterate over each of fk PROPERTY_VALUE columns and if a valid
	-- value is set, increment tally, otherwise raise an exception.
	IF NEW.Property_Value_Company_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'company_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Company_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Password_Type IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'password_type' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Password_Type' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Token_Col_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'token_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Token_Collection_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_SW_Package_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'sw_package_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be SW_Package_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Account_Coll_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'account_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be account_collection_id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_nblk_Coll_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'netblock_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be nblk_collection_id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Timestamp IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'timestamp' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Timestamp' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Person_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'person_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Person_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Device_Coll_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'device_collection_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Device_Collection_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	-- at this point, tally will be set to 1 if one of the other property
	-- values is set to something valid.  Now, check the various options for
	-- PROPERTY_VALUE itself.  If a new type is added to the val table, this
	-- trigger needs to be updated or it will be considered invalid.  If a
	-- new PROPERTY_VALUE_* column is added, then it will pass through without
	-- trigger modification.  This should be considered bad.

	IF NEW.Property_Value IS NOT NULL THEN
		tally := tally + 1;
		IF v_prop.Property_Data_Type = 'boolean' THEN
			IF NEW.Property_Value != 'Y' AND NEW.Property_Value != 'N' THEN
				RAISE 'Boolean Property_Value must be Y or N' USING
					ERRCODE = 'invalid_parameter_value';
			END IF;
		ELSIF v_prop.Property_Data_Type = 'number' THEN
			BEGIN
				v_num := to_number(NEW.property_value, '9');
			EXCEPTION
				WHEN OTHERS THEN
					RAISE 'Property_Value must be numeric' USING
						ERRCODE = 'invalid_parameter_value';
			END;
		ELSIF v_prop.Property_Data_Type = 'list' THEN
			BEGIN
				SELECT Valid_Property_Value INTO STRICT v_listvalue FROM
					VAL_Property_Value WHERE
						Property_Name = NEW.Property_Name AND
						Property_Type = NEW.Property_Type AND
						Valid_Property_Value = NEW.Property_Value;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					RAISE 'Property_Value must be a valid value' USING
						ERRCODE = 'invalid_parameter_value';
			END;
		ELSIF v_prop.Property_Data_Type != 'string' THEN
			RAISE 'Property_Data_Type is not a known type' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	IF v_prop.Property_Data_Type != 'none' AND tally = 0 THEN
		RAISE 'One of the PROPERTY_VALUE fields must be set.' USING
			ERRCODE = 'invalid_parameter_value';
	END IF;

	IF tally > 1 THEN
		RAISE 'Only one of the PROPERTY_VALUE fields may be set.' USING
			ERRCODE = 'invalid_parameter_value';
	END IF;

	-- If the LHS contains a account_collection_ID, check to see if it must be a
	-- specific type (e.g. per-account), and verify that if so
	IF NEW.account_collection_id IS NOT NULL THEN
		IF v_prop.account_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_account_collection
					FROM account_collection WHERE
					account_collection_Id = NEW.account_collection_id;
				IF v_account_collection.account_collection_Type != v_prop.account_collection_type
				THEN
					RAISE 'account_collection_id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a account_collection_ID, check to see if it must be a
	-- specific type (e.g. per-account), and verify that if so
	IF NEW.account_collection_id IS NOT NULL THEN
		IF v_prop.account_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_account_collection
					FROM account_collection WHERE
					account_collection_Id = NEW.account_collection_id;
				IF v_account_collection.account_collection_Type != v_prop.account_collection_type
				THEN
					RAISE 'account_collection_id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a device_collection_ID, check to see if it must be a
	-- specific type (e.g. per-device), and verify that if so
	IF NEW.device_collection_id IS NOT NULL THEN
		IF v_prop.device_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_device_collection
					FROM device_collection WHERE
					device_collection_Id = NEW.device_collection_id;
				IF v_device_collection.device_collection_Type != v_prop.device_collection_type
				THEN
					RAISE 'device_collection_id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a dns_domain_collection_ID, check to see if it must be a
	-- specific type (e.g. per-dns_domain), and verify that if so
	IF NEW.dns_domain_collection_id IS NOT NULL THEN
		IF v_prop.dns_domain_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_dns_domain_collection
					FROM dns_domain_collection WHERE
					dns_domain_collection_Id = NEW.dns_domain_collection_id;
				IF v_dns_domain_collection.dns_domain_collection_Type != v_prop.dns_domain_collection_type
				THEN
					RAISE 'dns_domain_collection_id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a layer2_network_collection_ID, check to see if it must be a
	-- specific type (e.g. per-layer2_network), and verify that if so
	IF NEW.layer2_network_collection_id IS NOT NULL THEN
		IF v_prop.layer2_network_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_layer2_network_collection
					FROM layer2_network_collection WHERE
					layer2_network_collection_Id = NEW.layer2_network_collection_id;
				IF v_layer2_network_collection.layer2_network_collection_Type != v_prop.layer2_network_collection_type
				THEN
					RAISE 'layer2_network_collection_id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a layer3_network_collection_ID, check to see if it must be a
	-- specific type (e.g. per-layer3_network), and verify that if so
	IF NEW.layer3_network_collection_id IS NOT NULL THEN
		IF v_prop.layer3_network_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_layer3_network_collection
					FROM layer3_network_collection WHERE
					layer3_network_collection_Id = NEW.layer3_network_collection_id;
				IF v_layer3_network_collection.layer3_network_collection_Type != v_prop.layer3_network_collection_type
				THEN
					RAISE 'layer3_network_collection_id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a netblock_collection_ID, check to see if it must be a
	-- specific type (e.g. per-netblock), and verify that if so
	IF NEW.netblock_collection_id IS NOT NULL THEN
		IF v_prop.netblock_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_netblock_collection
					FROM netblock_collection WHERE
					netblock_collection_Id = NEW.netblock_collection_id;
				IF v_netblock_collection.netblock_collection_Type != v_prop.netblock_collection_type
				THEN
					RAISE 'netblock_collection_id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a property_collection_ID, check to see if it must be a
	-- specific type (e.g. per-property), and verify that if so
	IF NEW.property_collection_id IS NOT NULL THEN
		IF v_prop.property_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_property_collection
					FROM property_collection WHERE
					property_collection_Id = NEW.property_collection_id;
				IF v_property_collection.property_collection_Type != v_prop.property_collection_type
				THEN
					RAISE 'property_collection_id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the LHS contains a service_env_collection_ID, check to see if it must be a
	-- specific type (e.g. per-service_env), and verify that if so
	IF NEW.service_env_collection_id IS NOT NULL THEN
		IF v_prop.service_env_collection_type IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_service_env_collection
					FROM service_env_collection WHERE
					service_env_collection_Id = NEW.service_env_collection_id;
				IF v_service_env_collection.service_env_collection_Type != v_prop.service_env_collection_type
				THEN
					RAISE 'service_env_collection_id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the RHS contains a account_collection_ID, check to see if it must be a
	-- specific type (e.g. per-account), and verify that if so
	IF NEW.Property_Value_Account_Coll_Id IS NOT NULL THEN
		IF v_prop.prop_val_acct_coll_type_rstrct IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_account_collection
					FROM account_collection WHERE
					account_collection_Id = NEW.Property_Value_Account_Coll_Id;
				IF v_account_collection.account_collection_Type != v_prop.prop_val_acct_coll_type_rstrct
				THEN
					RAISE 'Property_Value_Account_Coll_Id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the RHS contains a netblock_collection_ID, check to see if it must be a
	-- specific type and verify that if so
	IF NEW.Property_Value_nblk_Coll_Id IS NOT NULL THEN
		IF v_prop.prop_val_acct_coll_type_rstrct IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_netblock_collection
					FROM netblock_collection WHERE
					netblock_collection_Id = NEW.Property_Value_nblk_Coll_Id;
				IF v_netblock_collection.netblock_collection_Type != v_prop.prop_val_acct_coll_type_rstrct
				THEN
					RAISE 'Property_Value_nblk_Coll_Id must be of type %',
					v_prop.prop_val_acct_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- If the RHS contains a device_collection_id, check to see if it must be a
	-- specific type and verify that if so
	IF NEW.Property_Value_Device_Coll_Id IS NOT NULL THEN
		IF v_prop.prop_val_dev_coll_type_rstrct IS NOT NULL THEN
			BEGIN
				SELECT * INTO STRICT v_device_collection
					FROM device_collection WHERE
					device_collection_id = NEW.Property_Value_Device_Coll_Id;
				IF v_device_collection.device_collection_type !=
					v_prop.prop_val_dev_coll_type_rstrct
				THEN
					RAISE 'Property_Value_Device_Coll_Id must be of type %',
					v_prop.prop_val_dev_coll_type_rstrct
					USING ERRCODE = 'invalid_parameter_value';
				END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- let the database deal with the fk exception later
					NULL;
			END;
		END IF;
	END IF;

	-- At this point, the RHS has been checked, so now we verify data
	-- set on the LHS

	-- There needs to be a stanza here for every "lhs".  If a new column is
	-- added to the property table, a new stanza needs to be added here,
	-- otherwise it will not be validated.  This should be considered bad.

	IF v_prop.Permit_Company_Id = 'REQUIRED' THEN
			IF NEW.Company_Id IS NULL THEN
				RAISE 'Company_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Company_Id = 'PROHIBITED' THEN
			IF NEW.Company_Id IS NOT NULL THEN
				RAISE 'Company_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Company_Collection_Id = 'REQUIRED' THEN
			IF NEW.Company_Collection_Id IS NULL THEN
				RAISE 'Company_Collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Company_Collection_Id = 'PROHIBITED' THEN
			IF NEW.Company_Collection_Id IS NOT NULL THEN
				RAISE 'Company_Collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Device_Collection_Id = 'REQUIRED' THEN
			IF NEW.Device_Collection_Id IS NULL THEN
				RAISE 'Device_Collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;

	ELSIF v_prop.Permit_Device_Collection_Id = 'PROHIBITED' THEN
			IF NEW.Device_Collection_Id IS NOT NULL THEN
				RAISE 'Device_Collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_DNS_Domain_Id = 'REQUIRED' THEN
			IF NEW.DNS_Domain_Id IS NULL THEN
				RAISE 'DNS_Domain_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_DNS_Domain_Id = 'PROHIBITED' THEN
			IF NEW.DNS_Domain_Id IS NOT NULL THEN
				RAISE 'DNS_Domain_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.permit_service_env_collection = 'REQUIRED' THEN
			IF NEW.service_env_collection_id IS NULL THEN
				RAISE 'service_env_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_service_env_collection = 'PROHIBITED' THEN
			IF NEW.service_env_collection_id IS NOT NULL THEN
				RAISE 'service_environment is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Operating_System_Id = 'REQUIRED' THEN
			IF NEW.Operating_System_Id IS NULL THEN
				RAISE 'Operating_System_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Operating_System_Id = 'PROHIBITED' THEN
			IF NEW.Operating_System_Id IS NOT NULL THEN
				RAISE 'Operating_System_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.permit_os_snapshot_id = 'REQUIRED' THEN
			IF NEW.operating_system_snapshot_id IS NULL THEN
				RAISE 'operating_system_snapshot_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_os_snapshot_id = 'PROHIBITED' THEN
			IF NEW.operating_system_snapshot_id IS NOT NULL THEN
				RAISE 'operating_system_snapshot_id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Site_Code = 'REQUIRED' THEN
			IF NEW.Site_Code IS NULL THEN
				RAISE 'Site_Code is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Site_Code = 'PROHIBITED' THEN
			IF NEW.Site_Code IS NOT NULL THEN
				RAISE 'Site_Code is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Account_Id = 'REQUIRED' THEN
			IF NEW.Account_Id IS NULL THEN
				RAISE 'Account_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Account_Id = 'PROHIBITED' THEN
			IF NEW.Account_Id IS NOT NULL THEN
				RAISE 'Account_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Account_Realm_Id = 'REQUIRED' THEN
			IF NEW.Account_Realm_Id IS NULL THEN
				RAISE 'Account_Realm_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Account_Realm_Id = 'PROHIBITED' THEN
			IF NEW.Account_Realm_Id IS NOT NULL THEN
				RAISE 'Account_Realm_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_account_collection_Id = 'REQUIRED' THEN
			IF NEW.account_collection_Id IS NULL THEN
				RAISE 'account_collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_account_collection_Id = 'PROHIBITED' THEN
			IF NEW.account_collection_Id IS NOT NULL THEN
				RAISE 'account_collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.permit_layer2_network_coll_id = 'REQUIRED' THEN
			IF NEW.layer2_network_collection_id IS NULL THEN
				RAISE 'layer2_network_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_layer2_network_coll_id = 'PROHIBITED' THEN
			IF NEW.layer2_network_collection_id IS NOT NULL THEN
				RAISE 'layer2_network_collection_id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.permit_layer3_network_coll_id = 'REQUIRED' THEN
			IF NEW.layer3_network_collection_id IS NULL THEN
				RAISE 'layer3_network_collection_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.permit_layer3_network_coll_id = 'PROHIBITED' THEN
			IF NEW.layer3_network_collection_id IS NOT NULL THEN
				RAISE 'layer3_network_collection_id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_netblock_collection_Id = 'REQUIRED' THEN
			IF NEW.netblock_collection_Id IS NULL THEN
				RAISE 'netblock_collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_netblock_collection_Id = 'PROHIBITED' THEN
			IF NEW.netblock_collection_Id IS NOT NULL THEN
				RAISE 'netblock_collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_property_collection_Id = 'REQUIRED' THEN
			IF NEW.property_collection_Id IS NULL THEN
				RAISE 'property_collection_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_property_collection_Id = 'PROHIBITED' THEN
			IF NEW.property_collection_Id IS NOT NULL THEN
				RAISE 'property_collection_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Person_Id = 'REQUIRED' THEN
			IF NEW.Person_Id IS NULL THEN
				RAISE 'Person_Id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Person_Id = 'PROHIBITED' THEN
			IF NEW.Person_Id IS NOT NULL THEN
				RAISE 'Person_Id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_Property_Rank = 'REQUIRED' THEN
			IF NEW.property_rank IS NULL THEN
				RAISE 'property_rank is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_Property_Rank = 'PROHIBITED' THEN
			IF NEW.property_rank IS NOT NULL THEN
				RAISE 'property_rank is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.approval_instance_item_approval_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	NOTIFY approval_instance_item_approval_change;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.approval_instance_item_approved_immutable()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF OLD.is_approved != NEW.is_approved THEN
		RAISE EXCEPTION 'Approval may not be changed';
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.approval_instance_step_auto_complete()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	--
	-- on insert, if the parent was already marked as completed, fail.
	-- arguably, this should happen on updates as well
	--	possibly should move this to a before trigger
	--
	IF TG_OP = 'INSERT' THEN
		SELECT	count(*)
		INTO	_tally
		FROM	approval_instance_step
		WHERE	approval_instance_step_id = NEW.approval_instance_step_id
		AND		is_completed = 'Y';

		IF _tally > 0 THEN
			RAISE EXCEPTION 'Completed attestation cycles may not have items added';
		END IF;
	END IF;

	IF NEW.is_approved IS NOT NULL THEN
		SELECT	count(*)
		INTO	_tally
		FROM	approval_instance_item
		WHERE	approval_instance_step_id = NEW.approval_instance_step_id
		AND		approval_instance_item_id != NEW.approval_instance_item_id
		AND		is_approved IS NOT NULL;

		IF _tally = 0 THEN
			UPDATE	approval_instance_step
			SET		is_completed = 'Y',
					approval_instance_step_end = now()
			WHERE	approval_instance_step_id = NEW.approval_instance_step_id;
		END IF;
		
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.approval_instance_step_completed_immutable()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF ( OLD.is_completed ='Y' AND NEW.is_completed = 'N' ) THEN
		RAISE EXCEPTION 'Approval completion may not be reverted';
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.approval_instance_step_resolve_instance()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally INTEGER;
BEGIN
	SELECT	count(*)
	INTO	_tally
	FROM	approval_instance_step
	WHERE	is_completed = 'N'
	AND		approval_instance_id = NEW.approval_instance_id;

	IF _tally = 0 THEN
		UPDATE approval_instance
		SET	approval_end = now()
		WHERE	approval_instance_id = NEW.approval_instance_id;
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.company_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	dct	val_company_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	dct
	FROM	val_company_collection_type
	WHERE	company_collection_type =
		(select company_collection_type from company_collection
			where company_collection_id = NEW.company_collection_id);

	IF dct.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Company Collections of type % may not be hierarcical',
			dct.company_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.company_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	dct	val_company_collection_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	dct
	FROM	val_company_collection_type
	WHERE	company_collection_type =
		(select company_collection_type from company_collection
			where company_collection_id = NEW.company_collection_id);

	IF dct.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from company_collection_company
		  where company_collection_id = NEW.company_collection_id;
		IF tally > dct.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF dct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from company_collection_company
		  		inner join company_collection using (company_collection_id)
		  where company_id = NEW.company_id
		  and	company_collection_type = dct.company_collection_type;
		IF tally > dct.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Company may not be a member of more than % collections of type %',
				dct.MAX_NUM_COLLECTIONS, dct.company_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.delete_per_company_company_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	dcid			company_collection.company_collection_id%TYPE;
BEGIN
	SELECT	company_collection_id
	  FROM  company_collection
	  INTO	dcid
	 WHERE	company_collection_type = 'per-company'
	   AND	company_collection_id in
		(select company_collection_id
		 from company_collection_company
		where company_id = OLD.company_id
		)
	ORDER BY company_collection_id
	LIMIT 1;

	IF dcid IS NOT NULL THEN
		DELETE FROM company_collection_company
		WHERE company_collection_id = dcid;

		DELETE from company_collection
		WHERE company_collection_id = dcid;
	END IF;

	RETURN OLD;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	dct	val_dns_domain_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	dct
	FROM	val_dns_domain_collection_type
	WHERE	dns_domain_collection_type =
		(select dns_domain_collection_type from dns_domain_collection
			where dns_domain_collection_id = NEW.dns_domain_collection_id);

	IF dct.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'DNS Domain Collections of type % may not be hierarcical',
			dct.dns_domain_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.dns_domain_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	dct	val_dns_domain_collection_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	dct
	FROM	val_dns_domain_collection_type
	WHERE	dns_domain_collection_type =
		(select dns_domain_collection_type from dns_domain_collection
			where dns_domain_collection_id = NEW.dns_domain_collection_id);

	IF dct.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from dns_domain_collection_dns_dom
		  where dns_domain_collection_id = NEW.dns_domain_collection_id;
		IF tally > dct.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF dct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from dns_domain_collection_dns_dom
		  		inner join dns_domain_collection using (dns_domain_collection_id)
		  where dns_domain_id = NEW.dns_domain_id
		  and	dns_domain_collection_type = dct.dns_domain_collection_type;
		IF tally > dct.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'DNS Domain may not be a member of more than % collections of type %',
				dct.MAX_NUM_COLLECTIONS, dct.dns_domain_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.layer2_network_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	act	val_layer2_network_coll_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	act
	FROM	val_layer2_network_coll_type
	WHERE	layer2_network_collection_type =
		(select layer2_network_collection_type from layer2_network_collection
			where layer2_network_collection_id = NEW.layer2_network_collection_id);

	IF act.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Layer2 Network Collections of type % may not be hierarcical',
			act.layer2_network_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.layer2_network_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	act	val_layer2_network_coll_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	act
	FROM	val_layer2_network_coll_type
	WHERE	layer2_network_collection_type =
		(select layer2_network_collection_type from layer2_network_collection
			where layer2_network_collection_id = NEW.layer2_network_collection_id);

	IF act.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from l2_network_coll_l2_network
		  where layer2_network_collection_id = NEW.layer2_network_collection_id;
		IF tally > act.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF act.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from l2_network_coll_l2_network
		  		inner join layer2_network_collection using (layer2_network_collection_id)
		  where layer2_network_id = NEW.layer2_network_id
		  and	layer2_network_collection_type = act.layer2_network_collection_type;
		IF tally > act.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Layer2 network may not be a member of more than % collections of type %',
				act.MAX_NUM_COLLECTIONS, act.layer2_network_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.layer3_network_collection_hier_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	act	val_layer3_network_coll_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	act
	FROM	val_layer3_network_coll_type
	WHERE	layer3_network_collection_type =
		(select layer3_network_collection_type from layer3_network_collection
			where layer3_network_collection_id = NEW.layer3_network_collection_id);

	IF act.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Layer3 Network Collections of type % may not be hierarcical',
			act.layer3_network_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.layer3_network_collection_member_enforce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	act	val_layer3_network_coll_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	act
	FROM	val_layer3_network_coll_type
	WHERE	layer3_network_collection_type =
		(select layer3_network_collection_type from layer3_network_collection
			where layer3_network_collection_id = NEW.layer3_network_collection_id);

	IF act.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from l3_network_coll_l3_network
		  where layer3_network_collection_id = NEW.layer3_network_collection_id;
		IF tally > act.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF act.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from l3_network_coll_l3_network
		  		inner join layer3_network_collection using (layer3_network_collection_id)
		  where layer3_network_id = NEW.layer3_network_id
		  and	layer3_network_collection_type = act.layer3_network_collection_type;
		IF tally > act.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Layer3 Network may not be a member of more than % collections of type %',
				act.MAX_NUM_COLLECTIONS, act.layer3_network_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.legacy_approval_instance_step_notify_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF NEW.account_id IS NULL THEN
		SELECT	approver_account_id
		INTO	NEW.account_id
		FROM	legacy_approval_instance_step
		WHERE	legacy_approval_instance_step_id = NEW.legacy_approval_instance_step_id;
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.update_per_company_company_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	dcid		company_collection.company_collection_id%TYPE;
	newname		company_collection.company_collection_name%TYPE;
BEGIN
	IF NEW.company_name IS NOT NULL THEN
		newname = NEW.company_name || '_' || NEW.company_id;
	ELSE
		newname = 'per_d_dc_contrived_' || NEW.company_id;
	END IF;

	IF TG_OP = 'INSERT' THEN
		insert into company_collection
			(company_collection_name, company_collection_type)
		values
			(newname, 'per-company')
		RETURNING company_collection_id INTO dcid;
		insert into company_collection_company
			(company_collection_id, company_id)
		VALUES
			(dcid, NEW.company_id);
	ELSIF TG_OP = 'UPDATE'  THEN
		UPDATE	company_collection
		   SET	company_collection_name = newname
		 WHERE	company_collection_name != newname
		   AND	company_collection_type = 'per-company'
		   AND	company_collection_id in (
			SELECT	company_collection_id
			  FROM	company_collection_company
			 WHERE	company_id = NEW.company_id
			);
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.validate_account_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.account_collection_type != NEW.account_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.account_collection_type = OLD.account_collection_type
		AND	p.account_collection_id = NEW.account_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'account_collection % of type % is used by % restricted properties.',
				NEW.account_collection_id, NEW.account_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.validate_company_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.company_collection_type != NEW.company_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.company_collection_type = OLD.company_collection_type
		AND	p.company_collection_id = NEW.company_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'company_collection % of type % is used by % restricted properties.',
				NEW.company_collection_id, NEW.company_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.validate_device_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.device_collection_type != NEW.device_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.device_collection_type = OLD.device_collection_type
		AND	p.device_collection_id = NEW.device_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'device_collection % of type % is used by % restricted properties.',
				NEW.device_collection_id, NEW.device_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.validate_dns_domain_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.dns_domain_collection_type != NEW.dns_domain_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.dns_domain_collection_type = OLD.dns_domain_collection_type
		AND	p.dns_domain_collection_id = NEW.dns_domain_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'dns_domain_collection % of type % is used by % restricted properties.',
				NEW.dns_domain_collection_id, NEW.dns_domain_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.validate_layer2_network_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.layer2_network_collection_type != NEW.layer2_network_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.layer2_network_collection_type = OLD.layer2_network_collection_type
		AND	p.layer2_network_collection_id = NEW.layer2_network_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'layer2_network_collection % of type % is used by % restricted properties.',
				NEW.layer2_network_collection_id, NEW.layer2_network_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.validate_layer3_network_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.layer3_network_collection_type != NEW.layer3_network_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.layer3_network_collection_type = OLD.layer3_network_collection_type
		AND	p.layer3_network_collection_id = NEW.layer3_network_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'layer3_network_collection % of type % is used by % restricted properties.',
				NEW.layer3_network_collection_id, NEW.layer3_network_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.validate_netblock_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.netblock_collection_type != NEW.netblock_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.netblock_collection_type = OLD.netblock_collection_type
		AND	p.netblock_collection_id = NEW.netblock_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'netblock_collection % of type % is used by % restricted properties.',
				NEW.netblock_collection_id, NEW.netblock_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.validate_network_range()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	v_nrt	val_network_range_type%ROWTYPE;
BEGIN
	SELECT	*
	INTO	v_nrt
	FROM	val_network_range_type
	WHERE	network_range_type = NEW.network_range_type;

	IF NEW.dns_domain_id IS NULL AND v_nrt.dns_domain_required = 'REQUIRED' THEN
		RAISE EXCEPTION 'For type %, dns_domain_id is required.',
			NEW.network_range_type
			USING ERRCODE = 'not_null_violation';
	ELSIF NEW.dns_domain_id IS NOT NULL AND
			v_nrt.dns_domain_required = 'PROHIBITED' THEN
		RAISE EXCEPTION 'For type %, dns_domain_id is prohibited.',
			NEW.network_range_type
			USING ERRCODE = 'not_null_violation';
	END IF;

END; $function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.validate_pers_comp_attr_value()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally			integer;
BEGIN
	PERFORM 1
	FROM	val_person_company_attr_value
	WHERE	(person_company_attr_name,person_company_attr_value)
			IN
			(OLD.person_company_attr_name,OLD.person_company_attr_value)
	;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'attribute_value must be valid'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;

END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.validate_pers_company_attr()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally			integer;
	v_pc_atr		val_person_company_attr_name%ROWTYPE;
	v_listvalue		Property.Property_Value%TYPE;
BEGIN

	SELECT	*
	INTO	v_pc_atr
	FROM	val_person_company_attr_name
	WHERE	person_company_attr_name = NEW.person_company_attr_name;

	IF v_pc_atr.person_company_attr_data_type IN
			('boolean', 'number', 'string', 'list') THEN
		IF NEW.attribute_value IS NULL THEN
			RAISE EXCEPTION 'attribute_value must be set for %',
				v_pc_atr.person_company_attr_data_type
				USING ERRCODE = 'not_null_violation';
		END IF;
		IF v_pc_atr.person_company_attr_data_type = 'boolean' THEN
			IF NEW.attribute_value NOT IN ('Y', 'N') THEN
				RAISE EXCEPTION 'attribute_value must be boolean (Y,N)'
					USING ERRCODE = 'integrity_constraint_violation';
			END IF;
		ELSIF v_pc_atr.person_company_attr_data_type = 'number' THEN
			IF NEW.attribute_value !~ '^-?(\d*\.?\d*){1}$' THEN
				RAISE EXCEPTION 'attribute_value must be a number'
					USING ERRCODE = 'integrity_constraint_violation';
			END IF;
		ELSIF v_pc_atr.person_company_attr_data_type = 'timestamp' THEN
			IF NEW.attribute_value_timestamp IS NULL THEN
				RAISE EXCEPTION 'attribute_value_timestamp must be set for %',
					v_pc_atr.person_company_attr_data_type
					USING ERRCODE = 'not_null_violation';
			END IF;
		ELSIF v_pc_atr.person_company_attr_data_type = 'list' THEN
			PERFORM 1
			FROM	val_person_company_attr_value
			WHERE	(person_company_attr_name,person_company_attr_value)
					IN
					(NEW.person_company_attr_name,NEW.person_company_attr_value)
			;
			IF NOT FOUND THEN
				RAISE EXCEPTION 'attribute_value must be valid'
					USING ERRCODE = 'integrity_constraint_violation';
			END IF;
		END IF;
	ELSIF v_pc_atr.person_company_attr_data_type = 'person_id' THEN
		IF NEW.attribute_value_timestamp IS NULL THEN
			RAISE EXCEPTION 'attribute_value_timestamp must be set for %',
				v_pc_atr.person_company_attr_data_type
				USING ERRCODE = 'not_null_violation';
		END IF;
	END IF;

	IF NEW.attribute_value IS NOT NULL AND
			(NEW.attribute_value_person_id IS NOT NULL OR
			NEW.attribute_value_timestamp IS NOT NULL) THEN
		RAISE EXCEPTION 'only one attribute_value may be set'
			USING ERRCODE = 'integrity_constraint_violation';
	ELSIF NEW.ttribute_value_person_id IS NOT NULL AND
			(NEW.attribute_value IS NOT NULL OR
			NEW.attribute_value_timestamp IS NOT NULL) THEN
		RAISE EXCEPTION 'only one attribute_value may be set'
			USING ERRCODE = 'integrity_constraint_violation';
	ELSIF NEW.attribute_value_timestamp IS NOT NULL AND
			(NEW.attribute_value_person_id IS NOT NULL OR
			NEW.attribute_value IS NOT NULL) THEN
		RAISE EXCEPTION 'only one attribute_value may be set'
			USING ERRCODE = 'integrity_constraint_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.validate_property_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.property_collection_type != NEW.property_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.property_collection_type = OLD.property_collection_type
		AND	p.property_collection_id = NEW.property_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'property_collection % of type % is used by % restricted properties.',
				NEW.property_collection_id, NEW.property_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.validate_service_env_collection_type_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	integer;
BEGIN
	IF OLD.service_env_collection_type != NEW.service_env_collection_type THEN
		SELECT	COUNT(*)
		INTO	_tally
		FROM	property p
			join val_property vp USING (property_name,property_type)
		WHERE	vp.service_env_collection_type = OLD.service_env_collection_type
		AND	p.service_env_collection_id = NEW.service_env_collection_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'service_env_collection % of type % is used by % restricted properties.',
				NEW.service_env_collection_id, NEW.service_env_collection_type, _tally
				USING ERRCODE = 'foreign_key_violation';
		END IF;
	END IF;
	
END;
$function$
;

-- New function
CREATE OR REPLACE FUNCTION jazzhands.validate_val_network_range_type()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	IF NEW.dns_domain_required = 'REQUIRED' THEN
		PERFORM
		FROM	network_range
		WHERE	network_range_type = NEW.network_range_type
		AND		dns_domain_id IS NULL;

		IF FOUND THEN
			RAISE EXCEPTION 'dns_domain_id is not set on some ranges'
				USING ERRCODE = 'not_null_violation';
		END IF;
	ELSIF NEW.dns_domain_required = 'PROHIBITED' THEN
		PERFORM
		FROM	network_range
		WHERE	network_range_type = NEW.network_range_type
		AND		dns_domain_id IS NOT NULL;

		IF FOUND THEN
			RAISE EXCEPTION 'dns_domain_id is set on some ranges'
				USING ERRCODE = 'not_null_violation';
		END IF;
	END IF;

END; $function$
;

--
-- Process trigger procs in net_manip
--
--
-- Process trigger procs in network_strings
--
--
-- Process trigger procs in time_util
--
--
-- Process trigger procs in dns_utils
--
--
-- Process trigger procs in person_manip
--
--
-- Process trigger procs in auto_ac_manip
--
--
-- Process trigger procs in company_manip
--
--
-- Process trigger procs in port_support
--
--
-- Process trigger procs in port_utils
--
--
-- Process trigger procs in device_utils
--
--
-- Process trigger procs in netblock_utils
--
--
-- Process trigger procs in netblock_manip
--
--
-- Process trigger procs in physical_address_utils
--
--
-- Process trigger procs in component_utils
--
--
-- Process trigger procs in snapshot_manip
--
--
-- Process trigger procs in lv_manip
--
--
-- Process trigger procs in schema_support
--
--
-- Process trigger procs in approval_utils
--
DROP FUNCTION IF EXISTS approval_utils.build_attest (  );
-- Dropping obsoleted sequences....


-- Dropping obsoleted audit sequences....


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_device_id_dnsrecord;
ALTER TABLE device
	ADD CONSTRAINT fk_device_id_dnsrecord
	FOREIGN KEY (identifying_dns_record_id) REFERENCES dns_record(dns_record_id) DEFERRABLE;

ALTER TABLE physicalish_volume DROP CONSTRAINT IF EXISTS ak_physvolname_type_devid;
ALTER TABLE physicalish_volume
	ADD CONSTRAINT ak_physvolname_type_devid
	UNIQUE (device_id, physicalish_volume_name, physicalish_volume_type) DEFERRABLE;

-- index
DROP INDEX IF EXISTS "jazzhands"."idx_dns_record_lower_dns_name";
CREATE INDEX idx_dns_record_lower_dns_name ON dns_record USING btree (lower(dns_name::text));
-- triggers
CREATE TRIGGER trigger_validate_account_collection_type_change BEFORE UPDATE OF account_collection_type ON account_collection FOR EACH ROW EXECUTE PROCEDURE validate_account_collection_type_change();
CREATE TRIGGER trigger_validate_device_collection_type_change BEFORE UPDATE OF device_collection_type ON device_collection FOR EACH ROW EXECUTE PROCEDURE validate_device_collection_type_change();
CREATE TRIGGER trigger_validate_netblock_collection_type_change BEFORE UPDATE OF netblock_collection_type ON netblock_collection FOR EACH ROW EXECUTE PROCEDURE validate_netblock_collection_type_change();
CREATE TRIGGER trigger_validate_property_collection_type_change BEFORE UPDATE OF property_collection_type ON property_collection FOR EACH ROW EXECUTE PROCEDURE validate_property_collection_type_change();
CREATE TRIGGER trigger_validate_service_env_collection_type_change BEFORE UPDATE OF service_env_collection_type ON service_environment_collection FOR EACH ROW EXECUTE PROCEDURE validate_service_env_collection_type_change();

-- per-company collection population for existing companies
WITH col AS (
	INSERT INTO company_collection (
		company_collection_name, company_collection_type
	) SELECT company_name || '-historical', 'per-company'
	FROM company
	WHERE company_id NOT IN (
		select company_id
		from company_collection_company
		inner join company_collection using (company_collection_id)
		where company_collection_type = 'per-company'
		)
	ORDER BY company_id
	RETURNING *
) INSERT INTO company_collection_company
	(company_collection_id, company_id)
SELECT company_collection_id, company_id
FROM company_collection, company
WHERE company_collection_name = company_name || '-historical'
AND company_collection_type = 'per-company'
AND company_id NOT IN (
	select company_id
	from company_collection_company
		inner join company_collection using (company_collection_id)
	where company_collection_type = 'per-company'
	)
ORDER BY company_id;

delete from val_property_data_type where
	property_data_type = 'dns_domain_id';

DROP TRIGGER IF EXISTS trigger_automated_ac_on_person_company ON person_company;
CREATE TRIGGER trigger_automated_ac_on_person_company AFTER UPDATE OF is_management, is_exempt, is_full_time, person_id, company_id, manager_person_id ON person_company FOR EACH ROW EXECUTE PROCEDURE automated_ac_on_person_company();


-- Clean Up
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_saved_grants();
GRANT select on all tables in schema jazzhands to ro_role;
GRANT insert,update,delete on all tables in schema jazzhands to iud_role;
GRANT select on all sequences in schema jazzhands to ro_role;
GRANT usage on all sequences in schema jazzhands to iud_role;
GRANT select on all tables in schema audit to ro_role;
GRANT select on all sequences in schema audit to ro_role;
SELECT schema_support.end_maintenance();
select timeofday(), now();
