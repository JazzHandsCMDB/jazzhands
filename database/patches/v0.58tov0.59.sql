/*
 *
 * Copyright (c) 2014 Todd Kover
 * All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
	Brute force query that clears out dup netblocks os that a unique
	construct can be put in:

with foo as (
select network_interface_id, device_Id, network_interface_name,netblock_id,
        ni.description,ip_address, dns.dns_name, dom.soa_name,
        coalesce(ni.data_upd_user,ni.data_ins_user) as dick
from network_interface ni
        join netblock nb using (netblock_id)
        left join dns_record dns using (netblock_id)
        left join dns_domain dom using (dns_domain_id)
where 
	netblock_id in (
                select netblock_id from network_interface
                where netblock_id is not null
                group by netblock_id having count(*) > 1)
and 
network_interface_id not in (
                select max(network_interface_id) 
		from network_interface
		group by netblock_id
                )
), purp as (
 delete from network_interface_purpose where network_interface_id in
	( select network_interface_id from foo) returning * 
) delete 
from network_interface 
where network_interface_id in
( select network_interface_id from purp )
or
network_interface_id in
( select network_interface_id from foo )

;

*/

\set ON_ERROR_STOP
SELECT schema_support.begin_maintenance();

/*
	Invoked:
	--suffix=v58
	schema_support.get_columns
	schema_support.get_pk_columns
	schema_support.quote_ident_array
	schema_support.retrieve_functions
	schema_support.save_dependant_objects_for_replay
	schema_support.undo_audit_row
	service_environment
	netblock_single_address_ni
	network_interface_netblock_to_ni
	network_interface_drop_tt
	netblock
	svc_environment_coll_svc_env
	network_interface_netblock
	device
	property
	property_collection
	property_collection_hier
	property_collection_property
	val_property_collection_type
	val_property
	sw_package
	sw_package_release
	network_service
	appaal_instance
	voe
	device_utils.monitoring_off_in_rack
	device_utils.purge_l1_connection_from_port
	device_utils.purge_physical_path
	device_utils.purge_physical_ports
	device_utils.purge_power_ports
	device_utils.retire_device
	device_utils.retire_rack
	del_v_corp_family_account
	dns_record_cname_checker
	ins_v_corp_family_account
	net_int_nb_single_address
	net_int_netblock_to_nbn_compat_after
	net_int_netblock_to_nbn_compat_before
	netblock_collection_hier_enforce
	netblock_complain_on_mismatch
	netblock_single_address_ni
	retire_netblock_columns
	upd_v_corp_family_account
	netblock_utils.calculate_intermediate_netblocks
	netblock_utils.delete_netblock
	netblock_utils.find_free_netblocks
	netblock_utils.find_rvs_zone_from_netblock_id
	netblock_utils.list_unallocated_netblocks
	netblock_utils.list_unallocated_netblocks
	person_manip.add_account_non_person
	check_svcenv_colllection_hier_loop
	check_token_colllection_hier_loop
	delete_per_svc_env_svc_env_collection
	update_per_svc_env_svc_env_collection
	delete_peruser_account_collection
	update_peruser_account_collection
	person_manip.add_person
	person_manip.add_user
	person_manip.purge_person
	person_manip.purge_account
	create_new_unix_account
	validate_property
	netblock_manip.allocate_netblock
	netblock_manip.delete_netblock
	person_manip.add_user_non_person
	v_account_collection_expanded
	v_acct_coll_expanded
	v_company_hier
	v_device_coll_hier_detail
	v_nblk_coll_netblock_expanded
	v_netblock_hier
	v_person_company_expanded
	v_physical_connection
	check_device_colllection_hier_loop
	manipulate_netblock_parentage_before
	validate_netblock
	netblock_utils.find_free_netblock
	v_department_company_expanded
	v_application_role
	v_property
	v_acct_coll_prop_expanded
	service_environment_collection_member_enforce
	netblock_utils.id_tag
	v_corp_family_account
	validate_netblock_parentage
	service_environment_collection_member_enforce
	netblock_utils.find_best_parent_id
	person_manip.pick_login
	v_corp_family_account
	v_device_col_account_cart
	v_device_col_account_col_cart
	v_device_col_acct_col_unixgroup
	v_device_col_acct_col_unixlogin
	v_device_collection_account_ssh_key
	v_person_company_expanded
	v_unix_account_overrides
	v_unix_group_mappings
	v_unix_group_overrides
	v_unix_mclass_settings
	v_unix_passwd_mappings
*/

DO $$
	-- deal with _root_account_realm_id 
	DECLARE x INTEGER;
	BEGIN
		SELECT count(*)
		INTO x
		FROM val_property
		WHERE property_name = '_root_account_realm_id'
		AND property_type  = 'Defaults';

		IF x = 0 THEN
			INSERT INTO val_property (
				property_name, property_type, 
				description, 
				is_multivalue, property_data_type, permit_account_realm_id
			) VALUES (
				'_root_account_realm_id', 'Defaults', 
				'define the corporate family account realm',
				'N', 'none', 'REQUIRED'
			);
		END IF;

		SELECT account_realm_id
		INTO x
		FROM property
		WHERE property_name = '_root_account_realm_id'
		AND property_type  = 'Defaults';

		IF x IS NULL THEN
			SELECT count(*)
			INTO x
			FROM val_property
			WHERE property_name = '_rootcompanyid'
			AND property_type  = 'Defaults';
			
			IF x > 0 THEN
				INSERT INTO property (
					property_name, property_type,
					account_realm_id
				) VALUES  (
					'_root_account_realm_id', 'Defaults',
					(select account_realm_id
						from account_realm_company
							where company_id IN (
								select  property_value_company_id
						    	from  property
								where  property_name = '_rootcompanyid'
								and  property_type = 'Defaults'
							)
						)
				);
			END IF;
			-- not making _rootcompanyid go away, but should
		END IF;
	END;
$$;

/*
 * populate network_interface_netblock before putting triggers in 
 */

/*  This is not actually getting into 0.59 but will likely be in a point
	release.

insert into network_interface_netblock
	(network_interface_id, netblock_id)
select network_interface_id, netblock_id
from network_interface where
	(network_interface_id, netblock_id) NOT IN
		(SELECT network_interface_id, netblock_id 
		from network_interface_netblock
		)
and netblock_id is not NULL
;
 */

CREATE SEQUENCE service_environment_service_environment_id_seq;
CREATE SEQUENCE property_collection_property_collection_id_seq;

--------------------------------------------------------------------
-- DEALING WITH proc schema_support.get_columns -> get_columns 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 401169
CREATE OR REPLACE FUNCTION schema_support.get_columns(_schema text, _table text)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
DECLARE
	cols		text[];
	_r			record;
BEGIN
	FOR _r IN SELECT  a.attname as colname,
	    pg_catalog.format_type(a.atttypid, a.atttypmod) as coltype,
	    a.attnotnull, a.attnum
	FROM    pg_catalog.pg_attribute a
				INNER JOIN pg_class c on a.attrelid = c.oid
				INNER JOIN pg_namespace n on n.oid = c.relnamespace
	WHERE   c.relname = _table
		  AND	n.nspname = _schema
	  AND   a.attnum > 0
	  AND   NOT a.attisdropped
		  AND	lower(a.attname) not like 'data_%'
	ORDER BY a.attnum
	LOOP
		SELECT array_append(cols, _r.colname::text) INTO cols;
	END LOOP;
	RETURN cols;
END;
$function$
;

-- DONE WITH proc schema_support.get_columns -> get_columns 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc schema_support.get_pk_columns -> get_pk_columns 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 401168
CREATE OR REPLACE FUNCTION schema_support.get_pk_columns(_schema text, _table text)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
DECLARE
	cols		text[];
	_r			RECORD;
BEGIN
	for _r IN SELECT a.attname
  			FROM pg_class c
				INNER JOIN pg_namespace n on n.oid = c.relnamespace
				INNER JOIN pg_index i ON i.indrelid = c.oid
				INNER JOIN pg_attribute  a ON   a.attrelid = c.oid AND
								a.attnum = any(i.indkey)
			WHERE	c.relname = _table
			AND		n.nspname = _schema
			AND		indisprimary
	LOOP
		SELECT array_append(cols, _r.attname::text) INTO cols;
	END LOOP;
	RETURN cols;
END;
$function$
;

-- DONE WITH proc schema_support.get_pk_columns -> get_pk_columns 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc schema_support.quote_ident_array -> quote_ident_array 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 401170
CREATE OR REPLACE FUNCTION schema_support.quote_ident_array(_input text[])
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
DECLARE
	_rv		text[];
	x		text;
BEGIN
	FOREACH x IN ARRAY _input
	LOOP
		SELECT array_append(_rv, quote_ident(x)) INTO _rv;
	END LOOP;
	RETURN _rv;
END;
$function$
;

-- DONE WITH proc schema_support.quote_ident_array -> quote_ident_array 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc schema_support.retrieve_functions -> retrieve_functions 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 401173
CREATE OR REPLACE FUNCTION schema_support.retrieve_functions(schema character varying, object character varying, dropit boolean DEFAULT false)
 RETURNS text[]
 LANGUAGE plpgsql
AS $function$
DECLARE
	_r		RECORD;
	_fn		TEXT;
	_cmd	TEXT;
	_rv		TEXT[];
BEGIN
	FOR _r IN SELECT n.nspname, p.proname, 
				coalesce(u.usename, 'public') as owner,
				pg_get_functiondef(p.oid) as funcdef,
				pg_get_function_identity_arguments(p.oid) as idargs
		FROM    pg_catalog.pg_proc  p
				INNER JOIN pg_catalog.pg_namespace n on n.oid = p.pronamespace
				INNER JOIN pg_catalog.pg_language l on l.oid = p.prolang
				INNER JOIN pg_catalog.pg_user u on u.usesysid = p.proowner
		WHERE   n.nspname = schema
		  AND	p.proname = object
	LOOP
		_fn = _r.nspname || '.' || _r.proname || '(' || _r.idargs || ')';
		_rv = _rv || _fn;

		IF dropit  THEN
			_cmd = 'DROP FUNCTION ' || _fn || ';';
			EXECUTE _cmd;
		END IF;
	END LOOP;
	RETURN _rv;
END;
$function$
;

-- DONE WITH proc schema_support.retrieve_functions -> retrieve_functions 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc schema_support.save_dependant_objects_for_replay -> save_dependant_objects_for_replay 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('schema_support', 'save_dependant_objects_for_replay', 'save_dependant_objects_for_replay');

-- DROP OLD FUNCTION
-- consider old oid 438958
DROP FUNCTION IF EXISTS schema_support.save_dependant_objects_for_replay(schema character varying, object character varying, dropit boolean);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 438958
DROP FUNCTION IF EXISTS schema_support.save_dependant_objects_for_replay(schema character varying, object character varying, dropit boolean);
-- consider NEW oid 401163
CREATE OR REPLACE FUNCTION schema_support.save_dependant_objects_for_replay(schema character varying, object character varying, dropit boolean DEFAULT true, doobjectdeps boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO schema_support
AS $function$
DECLARE
	_r		RECORD;
	_cmd	TEXT;
	_ddl	TEXT;
BEGIN
	RAISE NOTICE 'processing %.%', schema, object;
	-- process stored procedures
	FOR _r in SELECT  distinct np.nspname::text, dependent.proname::text
		FROM   pg_depend dep
			INNER join pg_type dependee on dependee.oid = dep.refobjid
			INNER join pg_namespace n on n.oid = dependee.typnamespace
			INNER join pg_proc dependent on dependent.oid = dep.objid
			INNER join pg_namespace np on np.oid = dependent.pronamespace
			WHERE   dependee.typname = object
			  AND	  n.nspname = schema
	LOOP
		RAISE NOTICE '1 dealing with  %.%', _r.nspname, _r.proname;
		PERFORM schema_support.save_constraint_for_replay(_r.nspname, _r.proname, dropit);
		PERFORM schema_support.save_dependant_objects_for_replay(_r.nspname, _r.proname, dropit);
		PERFORM schema_support.save_function_for_replay(_r.nspname, _r.proname, dropit);
	END LOOP;

	-- save any triggers on the view
	FOR _r in SELECT distinct n.nspname::text, dependee.relname::text, dependee.relkind
		FROM pg_depend
		JOIN pg_rewrite ON pg_depend.objid = pg_rewrite.oid
		JOIN pg_class as dependee ON pg_rewrite.ev_class = dependee.oid
		JOIN pg_class as dependent ON pg_depend.refobjid = dependent.oid
		JOIN pg_namespace n on n.oid = dependee.relnamespace
		JOIN pg_namespace sn on sn.oid = dependent.relnamespace
		JOIN pg_attribute ON pg_depend.refobjid = pg_attribute.attrelid
   			AND pg_depend.refobjsubid = pg_attribute.attnum
		WHERE dependent.relname = object
  		AND sn.nspname = schema
	LOOP
		IF _r.relkind = 'v' THEN
			RAISE NOTICE '2 dealing with  %.%', _r.nspname, _r.relname;
			PERFORM * FROM save_dependant_objects_for_replay(_r.nspname, _r.relname, dropit);
			PERFORM schema_support.save_view_for_replay(_r.nspname, _r.relname, dropit);
		END IF;
	END LOOP;
	IF doobjectdeps THEN
		PERFORM schema_support.save_trigger_for_replay(schema, object, dropit);
		PERFORM schema_support.save_constraint_for_replay('jazzhands', 'table');
	END IF;
END;
$function$
;

-- DONE WITH proc schema_support.save_dependant_objects_for_replay -> save_dependant_objects_for_replay 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc schema_support.undo_audit_row -> undo_audit_row 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 401171
CREATE OR REPLACE FUNCTION schema_support.undo_audit_row(in_table text, in_audit_schema text DEFAULT 'audit'::text, in_schema text DEFAULT 'jazzhands'::text, in_start_time timestamp without time zone DEFAULT NULL::timestamp without time zone, in_end_time timestamp without time zone DEFAULT NULL::timestamp without time zone, in_aud_user text DEFAULT NULL::text, in_audit_ids integer[] DEFAULT NULL::integer[])
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
	tally	integer;
	pks		text[];
	cols	text[];
	q		text;
	val		text;
	x		text;
	_whcl	text;
	_eq		text;
	setstr	text;
	_r		record;
	_c		record;
	_br		record;
	_vals	text[];
BEGIN
	tally := 0;
	pks := schema_support.get_pk_columns(in_schema, in_table);
	cols := schema_support.get_columns(in_schema, in_table);
	q = '';
	IF in_start_time is not NULL THEN
		IF q = '' THEN
			q := q || 'WHERE ';
		ELSE
			q := q || 'AND ';
		END IF;
		q := q || quote_ident('aud#timestamp') || ' >= ' || quote_literal(in_start_time);
	END IF;
	IF in_end_time is not NULL THEN
		IF q = '' THEN
			q := q || 'WHERE ';
		ELSE
			q := q || 'AND ';
		END IF;
		q := q || quote_ident('aud#timestamp') || ' <= ' || quote_literal(in_end_time);
	END IF;
	IF in_aud_user is not NULL THEN
		IF q = '' THEN
			q := q || 'WHERE ';
		ELSE
			q := q || 'AND ';
		END IF;
		q := q || quote_ident('aud#user') || ' = ' || quote_literal(in_aud_user);
	END IF;
	IF in_audit_ids is not NULL THEN
		IF q = '' THEN
			q := q || 'WHERE ';
		ELSE
			q := q || 'AND ';
		END IF;
		q := q || quote_ident('aud#seq') || ' IN ( ' ||
			array_to_string(in_audit_ids, ',') || ')';
	END IF;

	-- Iterate over all the rows that need to be replayed
	q := 'SELECT * from ' || quote_ident(in_audit_schema) || '.' ||
			quote_ident(in_table) || ' ' || q || ' ORDER BY "aud#seq" desc';
	FOR _r IN EXECUTE q
	LOOP
		IF _r."aud#action" = 'DEL' THEN
			-- Build up a list of rows that need to be inserted
			_vals = NULL;
			FOR _c IN SELECT * FROM json_each_text( row_to_json(_r) )
			LOOP
				IF _c.key !~ 'data|aud' THEN
					IF _c.value IS NULL THEN
						SELECT array_append(_vals, 'NULL') INTO _vals;
					ELSE
						SELECT array_append(_vals, quote_literal(_c.value)) INTO _vals;
					END IF;
				END IF;
			END LOOP;
			_eq := 'INSERT INTO ' || quote_ident(in_schema) || '.' ||
				quote_ident(in_table) || ' ( ' ||
				array_to_string(
					schema_support.quote_ident_array(cols), ',') || 
					') VALUES (' ||  array_to_string(_vals, ',', NULL) || ')';
		ELSIF _r."aud#action" in ('INS', 'UPD') THEN
			-- Build up a where clause for this table to get a unique row
			-- based on the primary key
			FOREACH x IN ARRAY pks
			LOOP
				_whcl := '';
				FOR _c IN SELECT * FROM json_each_text( row_to_json(_r) )
				LOOP
					IF _c.key = x THEN
						IF _whcl != '' THEN
							_whcl := _whcl || ', ';
						END IF;
						IF _c.value IS NULL THEN
							_whcl = _whcl || quote_ident(_c.key) || ' = NULL ';
						ELSE
							_whcl = _whcl || quote_ident(_c.key) || ' =  ' ||
								quote_nullable(_c.value);
						END IF;
					END IF;
				END LOOP;
			END LOOP;

			IF _r."aud#action" = 'INS' THEN
				_eq := 'DELETE FROM ' || quote_ident(in_schema) || '.' ||
					quote_ident(in_table) || ' WHERE ' || _whcl;
			ELSIF _r."aud#action" = 'UPD' THEN
				-- figure out what rows have changed and do an update if
				-- they have.  NOTE:  This may result in no change being
				-- replayed if a row did not actually change
				setstr = '';
				FOR _c IN SELECT * FROM json_each_text( row_to_json(_r) )
				LOOP
					--
					-- Iterate over all the columns and if they have changed,
					-- then build an update statement
					--
					IF _c.key !~ 'aud#|data_(ins|upd)_(user|date)' THEN
						EXECUTE 'SELECT ' || _c.key || ' FROM ' ||
							quote_ident(in_schema) || '.' ||
								quote_ident(in_table)  ||
							' WHERE ' || _whcl
							INTO val;
						IF ( _c.value IS NULL  AND val IS NOT NULL) OR
							( _c.value IS NOT NULL AND val IS NULL) OR
							(_c.value::text NOT SIMILAR TO val::text) THEN
							IF char_length(setstr) > 0 THEN
								setstr = setstr || ',
								';
							END IF;
							IF _c.value IS NOT  NULL THEN
								setstr = setstr || _c.key || ' = ' ||  
									quote_nullable(_c.value) || ' ' ;
							ELSE
								setstr = setstr || _c.key || ' = ' ||  
									' NULL ' ;
							END IF;
						END IF;
					END IF;
				END LOOP;
				IF char_length(setstr) > 0 THEN
					_eq := 'UPDATE ' || quote_ident(in_schema) || '.' ||
						quote_ident(in_table) || 
						' SET ' || setstr || ' WHERE ' || _whcl;
				END IF;
			END IF;
		END IF;
		IF _eq IS NOT NULL THEN
			tally := tally + 1;
			RAISE NOTICE '%', _eq;
			EXECUTE _eq;
		END IF;
	END LOOP;
	RETURN tally;
END;
$function$
;

-- DONE WITH proc schema_support.undo_audit_row -> undo_audit_row 
--------------------------------------------------------------------

-- Dropping obsoleted sequences....


-- Dropping obsoleted audit sequences....


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
-- triggers


-- Clean Up
SELECT schema_support.replay_saved_grants();
SELECT schema_support.replay_object_recreates();

--------------------------------------------------------------------
-- DEALING WITH TABLE service_environment [280382]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'service_environment', 'service_environment');

-- FOREIGN KEYS FROM
ALTER TABLE network_service DROP CONSTRAINT IF EXISTS fk_netsvc_csvcenv;
ALTER TABLE appaal_instance DROP CONSTRAINT IF EXISTS fk_appaal_i_fk_applic_svcenv;
ALTER TABLE sw_package_release DROP CONSTRAINT IF EXISTS fk_sw_pkg_rel_ref_vsvcenv;
ALTER TABLE voe DROP CONSTRAINT IF EXISTS fk_voe_ref_v_svcenv;
ALTER TABLE svc_environment_coll_svc_env DROP CONSTRAINT IF EXISTS fk_svc_env_col_svc_env;
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_device_fk_dev_v_svcenv;
ALTER TABLE sw_package DROP CONSTRAINT IF EXISTS fk_sw_pkg_ref_v_prod_state;


-- FOREIGN KEYS TO
ALTER TABLE jazzhands.service_environment DROP CONSTRAINT IF EXISTS fk_val_svcenv_prodstate;
ALTER TABLE jazzhands.service_environment DROP CONSTRAINT IF EXISTS pk_service_environment;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1service_environment";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_update_per_svc_env_svc_env_collection ON jazzhands.service_environment;
DROP TRIGGER IF EXISTS trigger_audit_service_environment ON jazzhands.service_environment;
DROP TRIGGER IF EXISTS trig_userlog_service_environment ON jazzhands.service_environment;
DROP TRIGGER IF EXISTS trigger_delete_per_svc_env_svc_env_collection ON jazzhands.service_environment;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'service_environment');
---- BEGIN audit.service_environment TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."service_environment_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'service_environment');
---- DONE audit.service_environment TEARDOWN


ALTER TABLE service_environment RENAME TO service_environment_v58;
ALTER TABLE audit.service_environment RENAME TO service_environment_v58;

CREATE TABLE service_environment
(
	service_environment_id	integer NOT NULL,
	service_environment_name	varchar(50) NOT NULL,
	production_state	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'service_environment', false);
ALTER TABLE service_environment
	ALTER service_environment_id
	SET DEFAULT nextval('service_environment_service_environment_id_seq'::regclass);

INSERT INTO service_environment (
	service_environment_id,		-- new column (service_environment_id)
	service_environment_name,		-- new column (service_environment_name)
	production_state,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	nextval('service_environment_service_environment_id_seq'::regclass),		-- new column (service_environment_id)
	service_environment,		-- new column (service_environment_name)
	production_state,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM service_environment_v58;

INSERT INTO audit.service_environment (
	service_environment_id,		-- new column (service_environment_id)
	service_environment_name,		-- new column (service_environment_name)
	production_state,
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
	b.service_environment_id,		-- new column (service_environment_id)
	a.service_environment,		-- new column (service_environment_name)
	a.production_state,
	a.description,
	a.data_ins_user,
	a.data_ins_date,
	a.data_upd_user,
	a.data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.service_environment_v58 a
	left join service_environment b on
		a.service_environment = b.service_environment_name;

ALTER TABLE service_environment
	ALTER service_environment_id
	SET DEFAULT nextval('service_environment_service_environment_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE service_environment ADD CONSTRAINT pk_service_environment PRIMARY KEY (service_environment_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif1service_environment ON service_environment USING btree (production_state);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK service_environment and device
-- gets created later
-- ALTER TABLE device
--	ADD CONSTRAINT fk_device_fk_dev_v_svcenv
--	FOREIGN KEY (service_environment_id) REFERENCES service_environment(service_environment_id);

-- consider FK service_environment and sw_package
-- created later
--ALTER TABLE sw_package
--	ADD CONSTRAINT fk_sw_pkg_ref_v_prod_state
--	FOREIGN KEY (service_environment_id) REFERENCES service_environment(service_environment_id);

-- consider FK service_environment and svc_environment_coll_svc_env
-- created later
--ALTER TABLE svc_environment_coll_svc_env
--	ADD CONSTRAINT fk_svc_env_col_svc_env
--	FOREIGN KEY (service_environment_id) REFERENCES service_environment(service_environment_id);

-- consider FK service_environment and network_service
-- ALTER TABLE network_service
-- 	ADD CONSTRAINT fk_netsvc_csvcenv
-- 	FOREIGN KEY (service_environment_id) REFERENCES service_environment(service_environment_id);

-- consider FK service_environment and appaal_instance
-- ALTER TABLE appaal_instance
-- 	ADD CONSTRAINT fk_appaal_i_fk_applic_svcenv
-- 	FOREIGN KEY (service_environment_id) REFERENCES service_environment(service_environment_id);

-- FOREIGN KEYS TO
-- consider FK service_environment and val_production_state
ALTER TABLE service_environment
	ADD CONSTRAINT fk_val_svcenv_prodstate
	FOREIGN KEY (production_state) REFERENCES val_production_state(production_state);


-- TRIGGERS
CREATE TRIGGER trigger_delete_per_svc_env_svc_env_collection BEFORE DELETE ON service_environment FOR EACH ROW EXECUTE PROCEDURE delete_per_svc_env_svc_env_collection();

-- XXX - may need to include trigger function
CREATE TRIGGER trigger_update_per_svc_env_svc_env_collection AFTER INSERT OR UPDATE ON service_environment FOR EACH ROW EXECUTE PROCEDURE update_per_svc_env_svc_env_collection();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'service_environment');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'service_environment');
ALTER SEQUENCE service_environment_service_environment_id_seq
	 OWNED BY service_environment.service_environment_id;
DROP TABLE IF EXISTS service_environment_v58;
DROP TABLE IF EXISTS audit.service_environment_v58;
-- DONE DEALING WITH TABLE service_environment [369659]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE network_interface_netblock [280022]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'network_interface_netblock', 'network_interface_netblock');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.network_interface_netblock DROP CONSTRAINT IF EXISTS fk_netint_nb_netint_id;
ALTER TABLE jazzhands.network_interface_netblock DROP CONSTRAINT IF EXISTS fk_netint_nb_nblk_id;
ALTER TABLE jazzhands.network_interface_netblock DROP CONSTRAINT IF EXISTS pk_network_interface_netblock;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif_netint_nb_netint_id";
DROP INDEX IF EXISTS "jazzhands"."xif_netint_nb_nblk_id";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_network_interface_netblock ON jazzhands.network_interface_netblock;
DROP TRIGGER IF EXISTS trigger_audit_network_interface_netblock ON jazzhands.network_interface_netblock;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'network_interface_netblock');
---- BEGIN audit.network_interface_netblock TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."network_interface_netblock_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'network_interface_netblock');
---- DONE audit.network_interface_netblock TEARDOWN


ALTER TABLE network_interface_netblock RENAME TO network_interface_netblock_v58;
ALTER TABLE audit.network_interface_netblock RENAME TO network_interface_netblock_v58;

CREATE TABLE network_interface_netblock
(
	network_interface_id	integer NOT NULL,
	netblock_id	integer NOT NULL,
	network_interface_rank	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'network_interface_netblock', false);
ALTER TABLE network_interface_netblock
	ALTER network_interface_rank
	SET DEFAULT 0;
INSERT INTO network_interface_netblock (
	network_interface_id,
	netblock_id,
	network_interface_rank,		-- new column (network_interface_rank)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	network_interface_id,
	netblock_id,
	0,		-- new column (network_interface_rank)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM network_interface_netblock_v58;

INSERT INTO audit.network_interface_netblock (
	network_interface_id,
	netblock_id,
	network_interface_rank,		-- new column (network_interface_rank)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	network_interface_id,
	netblock_id,
	NULL,		-- new column (network_interface_rank)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.network_interface_netblock_v58;

ALTER TABLE network_interface_netblock
	ALTER network_interface_rank
	SET DEFAULT 0;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE network_interface_netblock ADD CONSTRAINT pk_network_interface_netblock PRIMARY KEY (network_interface_id, netblock_id);
ALTER TABLE network_interface_netblock ADD CONSTRAINT ak_netint_nblk_nblk_id UNIQUE (netblock_id);
ALTER TABLE network_interface_netblock ADD CONSTRAINT ak_network_interface_nblk_ni_r UNIQUE (network_interface_id, network_interface_rank);

-- Table/Column Comments
COMMENT ON COLUMN network_interface_netblock.network_interface_rank IS 'specifies the order of priority for the ip address.  generally only the highest priority matters (or highest priority v4 and v6) and is the "primary" if the underlying device supports it.';
-- INDEXES
CREATE INDEX xif_netint_nb_nblk_id ON network_interface_netblock USING btree (network_interface_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK network_interface_netblock and netblock
ALTER TABLE network_interface_netblock
	ADD CONSTRAINT fk_netint_nb_netint_id
	FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id) DEFERRABLE;
-- consider FK network_interface_netblock and network_interface
-- Skipping this FK since table does not exist yet
--ALTER TABLE network_interface_netblock
--	ADD CONSTRAINT fk_netint_nb_nblk_id
--	FOREIGN KEY (network_interface_id) REFERENCES network_interface(network_interface_id) DEFERRABLE;


-- TRIGGERS

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'network_interface_netblock');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'network_interface_netblock');
DROP TABLE IF EXISTS network_interface_netblock_v58;
DROP TABLE IF EXISTS audit.network_interface_netblock_v58;
-- DONE DEALING WITH TABLE network_interface_netblock [369256]
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc network_interface_drop_tt -> network_interface_drop_tt 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 375726
CREATE OR REPLACE FUNCTION jazzhands.network_interface_drop_tt()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally INTEGER;
BEGIN
	SELECT  count(*)
	  INTO  _tally
	  FROM  pg_catalog.pg_class
	 WHERE  relname = '__network_interface_netblocks'
	   AND  relpersistence = 't';

	IF _tally > 0 THEN
		DROP TABLE IF EXISTS __network_interface_netblocks;
	END IF;

	SET CONSTRAINTS FK_NETINT_NB_NETINT_ID IMMEDIATE;
	SET CONSTRAINTS FK_NETINT_NB_NBLK_ID IMMEDIATE;

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$function$
;

-- Dropping obsoleted sequences....


-- Dropping obsoleted audit sequences....


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
-- triggers


-- XXX - may need to include trigger function
--    CREATE TRIGGER trigger_network_interface_drop_tt_netint_nb AFTER INSERT OR DELETE OR UPDATE ON network_interface_netblock FOR EACH STATEMENT EXECUTE PROCEDURE network_interface_drop_tt();

-- DONE WITH proc network_interface_drop_tt -> network_interface_drop_tt 
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH proc network_interface_netblock_to_ni -> network_interface_netblock_to_ni 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 375724
CREATE OR REPLACE FUNCTION jazzhands.network_interface_netblock_to_ni()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_r		network_interface_netblock%ROWTYPE;
	_rank	network_interface_netblock.network_interface_rank%TYPE;
	_tally	INTEGER;
BEGIN
	SELECT  count(*)
	  INTO  _tally
	  FROM  pg_catalog.pg_class
	 WHERE  relname = '__network_interface_netblocks'
	   AND  relpersistence = 't';

	IF _tally = 0 THEN
		CREATE TEMPORARY TABLE IF NOT EXISTS __network_interface_netblocks (
			network_interface_id INTEGER, netblock_id INTEGER
		);
	END IF;
	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
		SELECT count(*) INTO _tally FROM __network_interface_netblocks
		WHERE network_interface_id = NEW.network_interface_id
		AND netblock_id = NEW.netblock_id;
		if _tally >  0 THEN
			RETURN NEW;
		END IF;
		INSERT INTO __network_interface_netblocks
			(network_interface_id, netblock_id)
		VALUES (NEW.network_interface_id,NEW.netblock_id);
	ELSIF TG_OP = 'DELETE' THEN
		SELECT count(*) INTO _tally FROM __network_interface_netblocks
		WHERE network_interface_id = OLD.network_interface_id
		AND netblock_id = OLD.netblock_id;
		if _tally >  0 THEN
			RETURN OLD;
		END IF;
		INSERT INTO __network_interface_netblocks
			(network_interface_id, netblock_id)
		VALUES (OLD.network_interface_id,OLD.netblock_id);
	END IF;

	IF TG_OP = 'INSERT' THEN
		SELECT min(network_interface_rank), count(*)
		INTO _rank, _tally
		FROM network_interface_netblock
		WHERE network_interface_id = NEW.network_interface_id;

		IF _tally = 0 OR NEW.network_interface_rank <= _rank THEN
			UPDATE network_interface set netblock_id = NEW.netblock_id
			WHERE network_interface_id = NEW.network_interface_id
			AND netblock_id IS DISTINCT FROM (NEW.netblock_id)
			;
		END IF;
	ELSIF TG_OP = 'DELETE'  THEN
		-- if we started to disallow NULLs, just ignore this for now
		BEGIN
			UPDATE network_interface
				SET netblock_id = NULL
				WHERE network_interface_id = OLD.network_interface_id
				AND netblock_id = OLD.netblock_id;
		EXCEPTION WHEN null_value_not_allowed THEN
			RAISE DEBUG 'null_value_not_allowed';
		END;
		RETURN OLD;
	ELSIF TG_OP = 'UPDATE'  THEN
		SELECT min(network_interface_rank)
			INTO _rank
			FROM network_interface_netblock
			WHERE network_interface_id = NEW.network_interface_id;

		IF NEW.network_interface_rank <= _rank THEN
			UPDATE network_interface
				SET network_interface_id = NEW.network_interface_id,
					netblock_id = NEW.netblock_id
				WHERE network_interface_Id = OLD.network_interface_id
				AND netblock_id IS NOT DISTINCT FROM ( OLD.netblock_id );
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

--    CREATE TRIGGER trigger_network_interface_netblock_to_ni AFTER INSERT OR DELETE OR UPDATE ON network_interface_netblock FOR EACH ROW EXECUTE PROCEDURE network_interface_netblock_to_ni();

-- DONE WITH proc network_interface_netblock_to_ni -> network_interface_netblock_to_ni 
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH proc netblock_single_address_ni -> netblock_single_address_ni 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 375684
CREATE OR REPLACE FUNCTION jazzhands.netblock_single_address_ni()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	IF (NEW.is_single_address = 'N' AND OLD.is_single_address = 'Y') OR
		(NEW.netblock_type != 'default' AND OLD.netblock_type = 'default')
			THEN
		select count(*)
		INTO _tally
		FROM network_interface
		WHERE netblock_id = NEW.netblock_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'network interfaces must refer to single ip addresses of type default address (%,%)', NEW.ip_address, NEW.netblock_id
				USING errcode = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- DONE WITH proc netblock_single_address_ni -> netblock_single_address_ni 
--------------------------------------------------------------------

-- Dropping obsoleted sequences....


-- Dropping obsoleted audit sequences....


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
-- triggers


--------------------------------------------------------------------
-- DEALING WITH TABLE netblock [279932]

SELECT schema_support.save_view_for_replay('jazzhands', 'v_netblock_hier');

DROP TRIGGER IF EXISTS trigger_validate_netblock_parentage ON jazzhands.netblock;
DROP TRIGGER IF EXISTS zzzz_trigger_retire_netblock_columns ON jazzhands.netblock;
DROP TRIGGER IF EXISTS trigger_netblock_complain_on_mismatch ON jazzhands.netblock;
DROP TRIGGER IF EXISTS tb_a_validate_netblock ON jazzhands.netblock;
DROP TRIGGER IF EXISTS tb_manipulate_netblock_parentage ON jazzhands.netblock;
DROP TRIGGER IF EXISTS aaa_ta_manipulate_netblock_parentage ON jazzhands.netblock;

ALTER TABLE jazzhands.netblock DROP COLUMN IF EXISTS netmask_bits;
ALTER TABLE jazzhands.netblock DROP COLUMN IF EXISTS is_ipv4_address;

ALTER TABLE audit.netblock DROP COLUMN IF EXISTS netmask_bits;
ALTER TABLE audit.netblock DROP COLUMN IF EXISTS is_ipv4_address;

CREATE TRIGGER tb_a_validate_netblock 
	BEFORE INSERT OR UPDATE 
	OF netblock_id, ip_address, netblock_type, 
	is_single_address, can_subnet, parent_netblock_id, ip_universe_id 
	ON netblock 
	FOR EACH ROW 
	EXECUTE PROCEDURE validate_netblock();

CREATE TRIGGER tb_manipulate_netblock_parentage 
	BEFORE INSERT OR UPDATE OF ip_address, netblock_type, ip_universe_id,
	netblock_id, can_subnet, is_single_address 
	ON netblock 
	FOR EACH ROW 
	EXECUTE PROCEDURE manipulate_netblock_parentage_before();

CREATE CONSTRAINT TRIGGER trigger_validate_netblock_parentage 
	AFTER INSERT OR UPDATE OF netblock_id, ip_address, netblock_type, 
	is_single_address, can_subnet,parent_netblock_id, ip_universe_id 
	ON netblock 
	DEFERRABLE INITIALLY DEFERRED 
	FOR EACH ROW 
	EXECUTE PROCEDURE validate_netblock_parentage();

CREATE CONSTRAINT TRIGGER aaa_ta_manipulate_netblock_parentage 
	AFTER INSERT OR DELETE 
	ON netblock NOT 
	DEFERRABLE INITIALLY IMMEDIATE 
	FOR EACH ROW 
	EXECUTE PROCEDURE manipulate_netblock_parentage_after();

CREATE TRIGGER trigger_netblock_single_address_ni BEFORE UPDATE OF is_single_address, netblock_type ON netblock FOR EACH ROW EXECUTE PROCEDURE netblock_single_address_ni();


-- DONE DEALING WITH TABLE netblock [369167]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE svc_environment_coll_svc_env [280508]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'svc_environment_coll_svc_env', 'svc_environment_coll_svc_env');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.svc_environment_coll_svc_env DROP CONSTRAINT IF EXISTS fk_svc_env_col_svc_env;
ALTER TABLE jazzhands.svc_environment_coll_svc_env DROP CONSTRAINT IF EXISTS fk_svc_env_coll_svc_coll_id;
ALTER TABLE jazzhands.svc_environment_coll_svc_env DROP CONSTRAINT IF EXISTS pk_svc_environment_coll_svc_en;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif1svc_environment_coll_svc_e";
DROP INDEX IF EXISTS "jazzhands"."xif2svc_environment_coll_svc_e";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_service_environment_collection_member_enforce ON jazzhands.svc_environment_coll_svc_env;
DROP TRIGGER IF EXISTS trig_userlog_svc_environment_coll_svc_env ON jazzhands.svc_environment_coll_svc_env;
DROP TRIGGER IF EXISTS trigger_audit_svc_environment_coll_svc_env ON jazzhands.svc_environment_coll_svc_env;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'svc_environment_coll_svc_env');
---- BEGIN audit.svc_environment_coll_svc_env TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."svc_environment_coll_svc_env_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'svc_environment_coll_svc_env');
---- DONE audit.svc_environment_coll_svc_env TEARDOWN


ALTER TABLE svc_environment_coll_svc_env RENAME TO svc_environment_coll_svc_env_v58;
ALTER TABLE audit.svc_environment_coll_svc_env RENAME TO svc_environment_coll_svc_env_v58;

CREATE TABLE svc_environment_coll_svc_env
(
	service_env_collection_id	integer NOT NULL,
	service_environment_id	integer NOT NULL,
	description	varchar(4000)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'svc_environment_coll_svc_env', false);
INSERT INTO svc_environment_coll_svc_env (
	service_env_collection_id,
	service_environment_id,		-- new column (service_environment_id)
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	x.service_env_collection_id,
	b.service_environment_id,		-- new column (service_environment_id)
	x.description,
	x.data_ins_user,
	x.data_ins_date,
	x.data_upd_user,
	x.data_upd_date
FROM svc_environment_coll_svc_env_v58 x
	join service_environment b ON x.service_environment =
		b.service_environment_name;
	

INSERT INTO audit.svc_environment_coll_svc_env (
	service_env_collection_id,
	service_environment_id,		-- new column (service_environment_id)
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
	x.service_env_collection_id,
	b.service_environment_id,		-- new column (service_environment_id)
	x.description,
	x.data_ins_user,
	x.data_ins_date,
	x.data_upd_user,
	x.data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.svc_environment_coll_svc_env_v58 x
	join service_environment b ON x.service_environment =
		b.service_environment_name;


-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE svc_environment_coll_svc_env ADD CONSTRAINT pk_svc_environment_coll_svc_en PRIMARY KEY (service_env_collection_id, service_environment_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif1svc_environment_coll_svc_e ON svc_environment_coll_svc_env USING btree (service_environment_id);
CREATE INDEX xif2svc_environment_coll_svc_e ON svc_environment_coll_svc_env USING btree (service_env_collection_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK svc_environment_coll_svc_env and service_environment
ALTER TABLE svc_environment_coll_svc_env
	ADD CONSTRAINT fk_svc_env_col_svc_env
	FOREIGN KEY (service_environment_id) REFERENCES service_environment(service_environment_id);
-- consider FK svc_environment_coll_svc_env and service_environment_collection
ALTER TABLE svc_environment_coll_svc_env
	ADD CONSTRAINT fk_svc_env_coll_svc_coll_id
	FOREIGN KEY (service_env_collection_id) REFERENCES service_environment_collection(service_env_collection_id);


-- TRIGGERS
CREATE CONSTRAINT TRIGGER trigger_service_environment_collection_member_enforce AFTER INSERT OR UPDATE ON svc_environment_coll_svc_env DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE service_environment_collection_member_enforce();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'svc_environment_coll_svc_env');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'svc_environment_coll_svc_env');
DROP TABLE IF EXISTS svc_environment_coll_svc_env_v58;
DROP TABLE IF EXISTS audit.svc_environment_coll_svc_env_v58;
-- DONE DEALING WITH TABLE svc_environment_coll_svc_env [369786]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE device [279424]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'device', 'device');


-- FOREIGN KEYS FROM
-- Skipping this FK since table been dropped
ALTER TABLE physical_port DROP CONSTRAINT IF EXISTS fk_phys_port_dev_id;
ALTER TABLE device_layer2_network DROP CONSTRAINT IF EXISTS fk_device_l2_net_devid;
ALTER TABLE device_ticket DROP CONSTRAINT IF EXISTS fk_dev_tkt_dev_id;
ALTER TABLE network_interface_purpose DROP CONSTRAINT IF EXISTS fk_netint_purpose_device_id;
ALTER TABLE mlag_peering DROP CONSTRAINT IF EXISTS fk_mlag_peering_devid2;
ALTER TABLE device_management_controller DROP CONSTRAINT IF EXISTS fk_dev_mgmt_ctlr_dev_id;
ALTER TABLE network_service DROP CONSTRAINT IF EXISTS fk_netsvc_device_id;
ALTER TABLE chassis_location DROP CONSTRAINT IF EXISTS fk_chass_loc_chass_devid;
ALTER TABLE layer1_connection DROP CONSTRAINT IF EXISTS fk_l1conn_ref_device;
ALTER TABLE device_management_controller DROP CONSTRAINT IF EXISTS fk_dvc_mgmt_ctrl_mgr_dev_id;
ALTER TABLE device_collection_device DROP CONSTRAINT IF EXISTS fk_devcolldev_dev_id;
ALTER TABLE device_ssh_key DROP CONSTRAINT IF EXISTS fk_dev_ssh_key_ssh_key_id;
ALTER TABLE mlag_peering DROP CONSTRAINT IF EXISTS fk_mlag_peering_devid1;
ALTER TABLE network_interface DROP CONSTRAINT IF EXISTS fk_netint_device_id;
ALTER TABLE snmp_commstr DROP CONSTRAINT IF EXISTS fk_snmpstr_device_id;
ALTER TABLE device_note DROP CONSTRAINT IF EXISTS fk_device_note_device;
ALTER TABLE device_encapsulation_domain DROP CONSTRAINT IF EXISTS fk_dev_encap_domain_devid;
ALTER TABLE static_route DROP CONSTRAINT IF EXISTS fk_statrt_devsrc_id;
ALTER TABLE device_power_interface DROP CONSTRAINT IF EXISTS fk_device_device_power_supp;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_chasloc_chass_devid;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_fk_dev_v_svcenv;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_dev_os_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_dev_devtp_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_fk_voe;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_site_code;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_dev_rack_location_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_fk_dev_val_stat;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_asset_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_vownerstatus;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_ref_voesymbtrk;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_dev_chass_loc_id_mod_enfc;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_company__id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_dnsrecord;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_ref_parent_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS fk_device_reference_val_devi;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ak_device_rack_location_id;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ak_device_chassis_location_id;
SELECT schema_support.save_constraint_for_replay('jazzhands', 'device');
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS pk_device;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_dev_ismonitored";
DROP INDEX IF EXISTS "jazzhands"."xif16device";
DROP INDEX IF EXISTS "jazzhands"."idx_dev_iddnsrec";
DROP INDEX IF EXISTS "jazzhands"."idx_dev_dev_status";
DROP INDEX IF EXISTS "jazzhands"."idx_dev_voeid";
DROP INDEX IF EXISTS "jazzhands"."idx_dev_islclymgd";
DROP INDEX IF EXISTS "jazzhands"."idx_dev_ownershipstatus";
DROP INDEX IF EXISTS "jazzhands"."idx_device_type_location";
DROP INDEX IF EXISTS "jazzhands"."idx_dev_osid";
DROP INDEX IF EXISTS "jazzhands"."xif18device";
DROP INDEX IF EXISTS "jazzhands"."idx_dev_svcenv";
DROP INDEX IF EXISTS "jazzhands"."xifdevice_sitecode";
DROP INDEX IF EXISTS "jazzhands"."xif17device";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ckc_is_monitored_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069052;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ckc_is_virtual_device_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069059;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS dev_osid_notnull;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ckc_should_fetch_conf_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069057;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069054;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ckc_is_baselined_device;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069056;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069051;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069060;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS sys_c0069061;
ALTER TABLE jazzhands.device DROP CONSTRAINT IF EXISTS ckc_is_locally_manage_device;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_verify_device_voe ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_update_per_device_device_collection ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_audit_device ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_device_one_location_validate ON jazzhands.device;
DROP TRIGGER IF EXISTS trig_userlog_device ON jazzhands.device;
DROP TRIGGER IF EXISTS trigger_delete_per_device_device_collection ON jazzhands.device;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'device');
---- BEGIN audit.device TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."device_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'device');
---- DONE audit.device TEARDOWN


ALTER TABLE device RENAME TO device_v58;
ALTER TABLE audit.device RENAME TO device_v58;

CREATE TABLE device
(
	device_id	integer NOT NULL,
	device_type_id	integer NOT NULL,
	company_id	integer  NULL,
	asset_id	integer  NULL,
	device_name	varchar(255)  NULL,
	site_code	varchar(50)  NULL,
	identifying_dns_record_id	integer  NULL,
	host_id	varchar(255)  NULL,
	physical_label	varchar(255)  NULL,
	rack_location_id	integer  NULL,
	chassis_location_id	integer  NULL,
	parent_device_id	integer  NULL,
	description	varchar(255)  NULL,
	device_status	varchar(50) NOT NULL,
	operating_system_id	integer NOT NULL,
	service_environment_id	integer NOT NULL,
	voe_id	integer  NULL,
	auto_mgmt_protocol	varchar(50)  NULL,
	voe_symbolic_track_id	integer  NULL,
	is_locally_managed	character(1) NOT NULL,
	is_monitored	character(1) NOT NULL,
	is_virtual_device	character(1) NOT NULL,
	should_fetch_config	character(1) NOT NULL,
	date_in_service	timestamp with time zone  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);

SELECT schema_support.build_audit_table('audit', 'jazzhands', 'device', false);
ALTER TABLE device
	ALTER device_id
	SET DEFAULT nextval('device_device_id_seq'::regclass);
ALTER TABLE device
	ALTER operating_system_id
	SET DEFAULT 0;
ALTER TABLE device
	ALTER is_locally_managed
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE device
	ALTER is_virtual_device
	SET DEFAULT 'N'::bpchar;
ALTER TABLE device
	ALTER should_fetch_config
	SET DEFAULT 'Y'::bpchar;

INSERT INTO device (
	device_id,
	device_type_id,
	company_id,
	asset_id,
	device_name,
	site_code,
	identifying_dns_record_id,
	host_id,
	physical_label,
	rack_location_id,
	chassis_location_id,
	parent_device_id,
	description,
	device_status,
	operating_system_id,
	service_environment_id,	-- new column (service_environment_id)
	voe_id,
	auto_mgmt_protocol,
	voe_symbolic_track_id,
	is_locally_managed,
	is_monitored,
	is_virtual_device,
	should_fetch_config,
	date_in_service,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	d.device_id,
	d.device_type_id,
	d.company_id,
	d.asset_id,
	d.device_name,
	d.site_code,
	d.identifying_dns_record_id,
	d.host_id,
	d.physical_label,
	d.rack_location_id,
	d.chassis_location_id,
	d.parent_device_id,
	d.description,
	d.device_status,
	d.operating_system_id,
	se.service_environment_id,	-- new column (service_environment_id)
	d.voe_id,
	d.auto_mgmt_protocol,
	d.voe_symbolic_track_id,
	d.is_locally_managed,
	d.is_monitored,
	d.is_virtual_device,
	d.should_fetch_config,
	d.date_in_service,
	d.data_ins_user,
	d.data_ins_date,
	d.data_upd_user,
	d.data_upd_date
FROM device_v58 d
	join service_environment se on
		d.service_environment = se.service_environment_name;

INSERT INTO audit.device (
	device_id,
	device_type_id,
	company_id,
	asset_id,
	device_name,
	site_code,
	identifying_dns_record_id,
	host_id,
	physical_label,
	rack_location_id,
	chassis_location_id,
	parent_device_id,
	description,
	device_status,
	service_environment_id,		-- new column (service_environment_id)
	operating_system_id,
	voe_id,
	auto_mgmt_protocol,
	voe_symbolic_track_id,
	is_locally_managed,
	is_monitored,
	is_virtual_device,
	should_fetch_config,
	date_in_service,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	d.device_id,
	d.device_type_id,
	d.company_id,
	d.asset_id,
	d.device_name,
	d.site_code,
	d.identifying_dns_record_id,
	d.host_id,
	d.physical_label,
	d.rack_location_id,
	d.chassis_location_id,
	d.parent_device_id,
	d.description,
	d.device_status,
	se.service_environment_id,	-- new column (service_environment_id)
	d.operating_system_id,
	d.voe_id,
	d.auto_mgmt_protocol,
	d.voe_symbolic_track_id,
	d.is_locally_managed,
	d.is_monitored,
	d.is_virtual_device,
	d.should_fetch_config,
	d.date_in_service,
	d.data_ins_user,
	d.data_ins_date,
	d.data_upd_user,
	d.data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.device_v58 d
	join service_environment se on
		d.service_environment = se.service_environment_name;

ALTER TABLE device
	ALTER device_id
	SET DEFAULT nextval('device_device_id_seq'::regclass);
ALTER TABLE device
	ALTER operating_system_id
	SET DEFAULT 0;
ALTER TABLE device
	ALTER is_locally_managed
	SET DEFAULT 'Y'::bpchar;
ALTER TABLE device
	ALTER is_virtual_device
	SET DEFAULT 'N'::bpchar;
ALTER TABLE device
	ALTER should_fetch_config
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE device ADD CONSTRAINT pk_device PRIMARY KEY (device_id);
ALTER TABLE device ADD CONSTRAINT ak_device_chassis_location_id UNIQUE (chassis_location_id);
-- Temporarily disabled.  *sigh*
-- ALTER TABLE device ADD CONSTRAINT ak_device_rack_location_id UNIQUE (rack_location_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xifdevice_sitecode ON device USING btree (site_code);
CREATE INDEX xif17device ON device USING btree (company_id);
CREATE INDEX xif18device ON device USING btree (asset_id);
CREATE INDEX idx_dev_svcenv ON device USING btree (service_environment_id);
CREATE INDEX idx_device_type_location ON device USING btree (device_type_id);
CREATE INDEX idx_dev_osid ON device USING btree (operating_system_id);
CREATE INDEX idx_dev_voeid ON device USING btree (voe_id);
CREATE INDEX idx_dev_dev_status ON device USING btree (device_status);
CREATE INDEX idx_dev_islclymgd ON device USING btree (is_locally_managed);
CREATE INDEX idx_dev_ismonitored ON device USING btree (is_monitored);
CREATE INDEX xif16device ON device USING btree (chassis_location_id, parent_device_id, device_type_id);
CREATE INDEX idx_dev_iddnsrec ON device USING btree (identifying_dns_record_id);

-- CHECK CONSTRAINTS
ALTER TABLE device ADD CONSTRAINT ckc_is_locally_manage_device
	CHECK ((is_locally_managed = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_locally_managed)::text = upper((is_locally_managed)::text)));
ALTER TABLE device ADD CONSTRAINT sys_c0069051
	CHECK (device_id IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069060
	CHECK (should_fetch_config IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT dev_osid_notnull
	CHECK (operating_system_id IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT ckc_should_fetch_conf_device
	CHECK ((should_fetch_config = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((should_fetch_config)::text = upper((should_fetch_config)::text)));
ALTER TABLE device ADD CONSTRAINT sys_c0069057
	CHECK (is_monitored IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT sys_c0069052
	CHECK (device_type_id IS NOT NULL);
ALTER TABLE device ADD CONSTRAINT ckc_is_monitored_device
	CHECK ((is_monitored = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_monitored)::text = upper((is_monitored)::text)));
ALTER TABLE device ADD CONSTRAINT ckc_is_virtual_device_device
	CHECK ((is_virtual_device = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_virtual_device)::text = upper((is_virtual_device)::text)));
ALTER TABLE device ADD CONSTRAINT sys_c0069059
	CHECK (is_virtual_device IS NOT NULL);

-- FOREIGN KEYS FROM
-- consider FK device and device_layer2_network
ALTER TABLE device_layer2_network
	ADD CONSTRAINT fk_device_l2_net_devid
	FOREIGN KEY (device_id) REFERENCES device(device_id);

-- consider FK device and physical_port
ALTER TABLE physical_port
	ADD CONSTRAINT fk_phys_port_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);

-- consider FK device and mlag_peering
ALTER TABLE mlag_peering
	ADD CONSTRAINT fk_mlag_peering_devid2
	FOREIGN KEY (device2_id) REFERENCES device(device_id);

-- consider FK device and device_ticket
ALTER TABLE device_ticket
	ADD CONSTRAINT fk_dev_tkt_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);

-- consider FK device and network_interface_purpose
ALTER TABLE network_interface_purpose
	ADD CONSTRAINT fk_netint_purpose_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);

-- consider FK device and chassis_location
ALTER TABLE chassis_location
	ADD CONSTRAINT fk_chass_loc_chass_devid
	FOREIGN KEY (chassis_device_id) REFERENCES device(device_id) DEFERRABLE;

-- consider FK device and network_service
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);

-- consider FK device and device_management_controller
ALTER TABLE device_management_controller
	ADD CONSTRAINT fk_dev_mgmt_ctlr_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);

-- consider FK device and layer1_connection
ALTER TABLE layer1_connection
	ADD CONSTRAINT fk_l1conn_ref_device
	FOREIGN KEY (tcpsrv_device_id) REFERENCES device(device_id);

-- consider FK device and device_management_controller
ALTER TABLE device_management_controller
	ADD CONSTRAINT fk_dvc_mgmt_ctrl_mgr_dev_id
	FOREIGN KEY (manager_device_id) REFERENCES device(device_id);

-- consider FK device and device_collection_device
ALTER TABLE device_collection_device
	ADD CONSTRAINT fk_devcolldev_dev_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);

-- consider FK device and device_ssh_key
ALTER TABLE device_ssh_key
	ADD CONSTRAINT fk_dev_ssh_key_ssh_key_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);

-- consider FK device and mlag_peering
ALTER TABLE mlag_peering
	ADD CONSTRAINT fk_mlag_peering_devid1
	FOREIGN KEY (device1_id) REFERENCES device(device_id);

-- consider FK device and snmp_commstr
ALTER TABLE snmp_commstr
	ADD CONSTRAINT fk_snmpstr_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);

-- consider FK device and network_interface
ALTER TABLE network_interface
	ADD CONSTRAINT fk_netint_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);

-- consider FK device and static_route
ALTER TABLE static_route
	ADD CONSTRAINT fk_statrt_devsrc_id
	FOREIGN KEY (device_src_id) REFERENCES device(device_id);

-- consider FK device and device_power_interface
ALTER TABLE device_power_interface
	ADD CONSTRAINT fk_device_device_power_supp
	FOREIGN KEY (device_id) REFERENCES device(device_id);

-- consider FK device and device_note
ALTER TABLE device_note
	ADD CONSTRAINT fk_device_note_device
	FOREIGN KEY (device_id) REFERENCES device(device_id);

-- consider FK device and device_encapsulation_domain
ALTER TABLE device_encapsulation_domain
	ADD CONSTRAINT fk_dev_encap_domain_devid
	FOREIGN KEY (device_id) REFERENCES device(device_id);

-- FOREIGN KEYS TO
-- consider FK device and asset
ALTER TABLE device
	ADD CONSTRAINT fk_device_asset_id
	FOREIGN KEY (asset_id) REFERENCES asset(asset_id);

-- consider FK device and chassis_location
ALTER TABLE device
	ADD CONSTRAINT fk_chasloc_chass_devid
	FOREIGN KEY (chassis_location_id) REFERENCES chassis_location(chassis_location_id) DEFERRABLE;

-- consider FK device and service_environment
ALTER TABLE device
	ADD CONSTRAINT fk_device_fk_dev_v_svcenv
	FOREIGN KEY (service_environment_id) REFERENCES service_environment(service_environment_id);

-- consider FK device and operating_system
ALTER TABLE device
	ADD CONSTRAINT fk_dev_os_id
	FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id);

-- consider FK device and voe_symbolic_track
ALTER TABLE device
	ADD CONSTRAINT fk_device_ref_voesymbtrk
	FOREIGN KEY (voe_symbolic_track_id) REFERENCES voe_symbolic_track(voe_symbolic_track_id);

-- consider FK device and device_type
ALTER TABLE device
	ADD CONSTRAINT fk_dev_devtp_id
	FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id);

-- consider FK device and voe
ALTER TABLE device
	ADD CONSTRAINT fk_device_fk_voe
	FOREIGN KEY (voe_id) REFERENCES voe(voe_id);

-- consider FK device and chassis_location
ALTER TABLE device
	ADD CONSTRAINT fk_dev_chass_loc_id_mod_enfc
	FOREIGN KEY (chassis_location_id, parent_device_id, device_type_id) REFERENCES chassis_location(chassis_location_id, chassis_device_id, module_device_type_id) DEFERRABLE;

-- consider FK device and company
ALTER TABLE device
	ADD CONSTRAINT fk_device_company__id
	FOREIGN KEY (company_id) REFERENCES company(company_id);

-- consider FK device and site
ALTER TABLE device
	ADD CONSTRAINT fk_device_site_code
	FOREIGN KEY (site_code) REFERENCES site(site_code);

-- consider FK device and dns_record
ALTER TABLE device
	ADD CONSTRAINT fk_device_dnsrecord
	FOREIGN KEY (identifying_dns_record_id) REFERENCES dns_record(dns_record_id);

-- consider FK device and device
ALTER TABLE device
	ADD CONSTRAINT fk_device_ref_parent_device
	FOREIGN KEY (parent_device_id) REFERENCES device(device_id);
-- consider FK device and val_device_auto_mgmt_protocol
ALTER TABLE device
	ADD CONSTRAINT fk_device_reference_val_devi
	FOREIGN KEY (auto_mgmt_protocol) REFERENCES val_device_auto_mgmt_protocol(auto_mgmt_protocol);

-- consider FK device and rack_location
ALTER TABLE device
	ADD CONSTRAINT fk_dev_rack_location_id
	FOREIGN KEY (rack_location_id) REFERENCES rack_location(rack_location_id);

-- consider FK device and val_device_status
ALTER TABLE device
	ADD CONSTRAINT fk_device_fk_dev_val_stat
	FOREIGN KEY (device_status) REFERENCES val_device_status(device_status);


-- TRIGGERS
CREATE TRIGGER trigger_delete_per_device_device_collection BEFORE DELETE ON device FOR EACH ROW EXECUTE PROCEDURE delete_per_device_device_collection();

-- XXX - may need to include trigger function
CREATE TRIGGER trigger_verify_device_voe BEFORE INSERT OR UPDATE ON device FOR EACH ROW EXECUTE PROCEDURE verify_device_voe();

-- XXX - may need to include trigger function
CREATE TRIGGER trigger_update_per_device_device_collection AFTER INSERT OR UPDATE ON device FOR EACH ROW EXECUTE PROCEDURE update_per_device_device_collection();

-- XXX - may need to include trigger function
CREATE TRIGGER trigger_device_one_location_validate BEFORE INSERT OR UPDATE ON device FOR EACH ROW EXECUTE PROCEDURE device_one_location_validate();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'device');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'device');
ALTER SEQUENCE device_device_id_seq
	 OWNED BY device.device_id;
DROP TABLE IF EXISTS device_v58;
DROP TABLE IF EXISTS audit.device_v58;
-- DONE DEALING WITH TABLE device [368665]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE property [280306]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'property', 'property');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_osid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_compid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_person_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_acctid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_nblk_coll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_acct_colid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_l3netid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_acct_col;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_site_code;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_val_prsnid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_nmtyp;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_svc_env_coll_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_compid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_prop_l2netid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_pwdtyp;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_dnsdomid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_swpkgid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_devcolid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_tokcolid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pval_dnsdomid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_acctrealmid;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS fk_property_pv_nblkcol_id;
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS pk_property;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_compid";
DROP INDEX IF EXISTS "jazzhands"."xif24property";
DROP INDEX IF EXISTS "jazzhands"."xif17property";
DROP INDEX IF EXISTS "jazzhands"."xifprop_acctcol_id";
DROP INDEX IF EXISTS "jazzhands"."xif19property";
DROP INDEX IF EXISTS "jazzhands"."xifprop_site_code";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_swpkgid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_dnsdomid";
DROP INDEX IF EXISTS "jazzhands"."xif18property";
DROP INDEX IF EXISTS "jazzhands"."xif22property";
DROP INDEX IF EXISTS "jazzhands"."xifprop_account_id";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_pwdtyp";
DROP INDEX IF EXISTS "jazzhands"."xifprop_nmtyp";
DROP INDEX IF EXISTS "jazzhands"."xif23property";
DROP INDEX IF EXISTS "jazzhands"."xifprop_dnsdomid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_devcolid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_acct_colid";
DROP INDEX IF EXISTS "jazzhands"."xif21property";
DROP INDEX IF EXISTS "jazzhands"."xifprop_compid";
DROP INDEX IF EXISTS "jazzhands"."xifprop_pval_tokcolid";
DROP INDEX IF EXISTS "jazzhands"."xif20property";
DROP INDEX IF EXISTS "jazzhands"."xifprop_osid";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.property DROP CONSTRAINT IF EXISTS ckc_prop_isenbld;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_validate_property ON jazzhands.property;
DROP TRIGGER IF EXISTS trigger_audit_property ON jazzhands.property;
DROP TRIGGER IF EXISTS trig_userlog_property ON jazzhands.property;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'property');
---- BEGIN audit.property TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."property_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'property');
---- DONE audit.property TEARDOWN


ALTER TABLE property RENAME TO property_v58;
ALTER TABLE audit.property RENAME TO property_v58;

CREATE TABLE property
(
	property_id	integer NOT NULL,
	account_collection_id	integer  NULL,
	account_id	integer  NULL,
	account_realm_id	integer  NULL,
	company_id	integer  NULL,
	device_collection_id	integer  NULL,
	dns_domain_id	integer  NULL,
	netblock_collection_id	integer  NULL,
	layer2_network_id	integer  NULL,
	layer3_network_id	integer  NULL,
	operating_system_id	integer  NULL,
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
	property_value_dns_domain_id	integer  NULL,
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
	company_id,
	device_collection_id,
	dns_domain_id,
	netblock_collection_id,
	layer2_network_id,
	layer3_network_id,
	operating_system_id,
	person_id,
	property_collection_id,		-- new column (property_collection_id)
	service_env_collection_id,
	site_code,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_dns_domain_id,
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
	company_id,
	device_collection_id,
	dns_domain_id,
	netblock_collection_id,
	layer2_network_id,
	layer3_network_id,
	operating_system_id,
	person_id,
	NULL,		-- new column (property_collection_id)
	service_env_collection_id,
	site_code,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_dns_domain_id,
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
FROM property_v58;

INSERT INTO audit.property (
	property_id,
	account_collection_id,
	account_id,
	account_realm_id,
	company_id,
	device_collection_id,
	dns_domain_id,
	netblock_collection_id,
	layer2_network_id,
	layer3_network_id,
	operating_system_id,
	person_id,
	property_collection_id,		-- new column (property_collection_id)
	service_env_collection_id,
	site_code,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_dns_domain_id,
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
	company_id,
	device_collection_id,
	dns_domain_id,
	netblock_collection_id,
	layer2_network_id,
	layer3_network_id,
	operating_system_id,
	person_id,
	NULL,		-- new column (property_collection_id)
	service_env_collection_id,
	site_code,
	property_name,
	property_type,
	property_value,
	property_value_timestamp,
	property_value_company_id,
	property_value_account_coll_id,
	property_value_dns_domain_id,
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
FROM audit.property_v58;

ALTER TABLE property
	ALTER property_id
	SET DEFAULT nextval('property_property_id_seq'::regclass);
ALTER TABLE property
	ALTER is_enabled
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE property ADD CONSTRAINT pk_property PRIMARY KEY (property_id);

-- Table/Column Comments
COMMENT ON TABLE property IS 'generic property instance that describes system wide properties, as well as properties for various values of columns used throughout the db for configuration, acls, defaults, etc; also used to relate some tables';
COMMENT ON COLUMN property.property_id IS 'primary key for table to uniquely identify rows.';
COMMENT ON COLUMN property.account_collection_id IS 'user collection that properties may be set on.';
COMMENT ON COLUMN property.account_id IS 'system user that properties may be set on.';
COMMENT ON COLUMN property.company_id IS 'company that properties may be set on.';
COMMENT ON COLUMN property.device_collection_id IS 'device collection that properties may be set on.';
COMMENT ON COLUMN property.dns_domain_id IS 'dns domain that properties may be set on.';
COMMENT ON COLUMN property.operating_system_id IS 'operating system that properties may be set on.';
COMMENT ON COLUMN property.site_code IS 'site_code that properties may be set on';
COMMENT ON COLUMN property.property_name IS 'textual name of a property';
COMMENT ON COLUMN property.property_type IS 'textual type of a department';
COMMENT ON COLUMN property.property_value IS 'general purpose column for value of property not defined by other types.  This may be enforced by fk (trigger) if val_property.property_data_type is list (fk is to val_property_value).';
COMMENT ON COLUMN property.property_value_timestamp IS 'property is defined as a timestamp';
COMMENT ON COLUMN property.start_date IS 'date/time that the assignment takes effect';
COMMENT ON COLUMN property.finish_date IS 'date/time that the assignment ceases taking effect';
COMMENT ON COLUMN property.is_enabled IS 'indiciates if the property is temporarily disabled or not.';
-- INDEXES
CREATE INDEX xif23property ON property USING btree (layer2_network_id);
CREATE INDEX xifprop_nmtyp ON property USING btree (property_name, property_type);
CREATE INDEX xifprop_devcolid ON property USING btree (device_collection_id);
CREATE INDEX xifprop_dnsdomid ON property USING btree (dns_domain_id);
CREATE INDEX xif25property ON property USING btree (property_collection_id);
CREATE INDEX xifprop_pval_tokcolid ON property USING btree (property_value_token_col_id);
CREATE INDEX xifprop_compid ON property USING btree (company_id);
CREATE INDEX xif21property ON property USING btree (service_env_collection_id);
CREATE INDEX xifprop_pval_acct_colid ON property USING btree (property_value_account_coll_id);
CREATE INDEX xif20property ON property USING btree (netblock_collection_id);
CREATE INDEX xifprop_osid ON property USING btree (operating_system_id);
CREATE INDEX xif17property ON property USING btree (property_value_person_id);
CREATE INDEX xifprop_acctcol_id ON property USING btree (account_collection_id);
CREATE INDEX xif24property ON property USING btree (layer3_network_id);
CREATE INDEX xifprop_pval_compid ON property USING btree (property_value_company_id);
CREATE INDEX xifprop_site_code ON property USING btree (site_code);
CREATE INDEX xif19property ON property USING btree (property_value_nblk_coll_id);
CREATE INDEX xif18property ON property USING btree (person_id);
CREATE INDEX xifprop_pval_dnsdomid ON property USING btree (property_value_dns_domain_id);
CREATE INDEX xifprop_pval_swpkgid ON property USING btree (property_value_sw_package_id);
CREATE INDEX xifprop_account_id ON property USING btree (account_id);
CREATE INDEX xifprop_pval_pwdtyp ON property USING btree (property_value_password_type);
CREATE INDEX xif22property ON property USING btree (account_realm_id);

-- CHECK CONSTRAINTS
ALTER TABLE property ADD CONSTRAINT ckc_prop_isenbld
	CHECK (is_enabled = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK property and dns_domain
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_dnsdomid
	FOREIGN KEY (property_value_dns_domain_id) REFERENCES dns_domain(dns_domain_id);

-- consider FK property and netblock_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_pv_nblkcol_id
	FOREIGN KEY (property_value_nblk_coll_id) REFERENCES netblock_collection(netblock_collection_id);

-- consider FK property and account_realm
ALTER TABLE property
	ADD CONSTRAINT fk_property_acctrealmid
	FOREIGN KEY (account_realm_id) REFERENCES account_realm(account_realm_id);

-- consider FK property and token_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_tokcolid
	FOREIGN KEY (property_value_token_col_id) REFERENCES token_collection(token_collection_id);

-- consider FK property and device_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_devcolid
	FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id);

-- consider FK property and dns_domain
ALTER TABLE property
	ADD CONSTRAINT fk_property_dnsdomid
	FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id);

-- consider FK property and sw_package
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_swpkgid
	FOREIGN KEY (property_value_sw_package_id) REFERENCES sw_package(sw_package_id);

-- consider FK property and layer2_network
ALTER TABLE property
	ADD CONSTRAINT fk_prop_l2netid
	FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id);

-- consider FK property and val_password_type
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_pwdtyp
	FOREIGN KEY (property_value_password_type) REFERENCES val_password_type(password_type);

-- consider FK property and val_property
ALTER TABLE property
	ADD CONSTRAINT fk_property_nmtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);

-- consider FK property and person
ALTER TABLE property
	ADD CONSTRAINT fk_property_val_prsnid
	FOREIGN KEY (property_value_person_id) REFERENCES person(person_id);

-- consider FK property and service_environment_collection
ALTER TABLE property
	ADD CONSTRAINT fk_prop_svc_env_coll_id
	FOREIGN KEY (service_env_collection_id) REFERENCES service_environment_collection(service_env_collection_id);

-- consider FK property and company
ALTER TABLE property
	ADD CONSTRAINT fk_property_compid
	FOREIGN KEY (company_id) REFERENCES company(company_id);

-- consider FK property and layer3_network
ALTER TABLE property
	ADD CONSTRAINT fk_prop_l3netid
	FOREIGN KEY (layer3_network_id) REFERENCES layer3_network(layer3_network_id);

-- consider FK property and account_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_acct_col
	FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id);

-- consider FK property and site
ALTER TABLE property
	ADD CONSTRAINT fk_property_site_code
	FOREIGN KEY (site_code) REFERENCES site(site_code);

-- consider FK property and property_collection
-- skipping; does not exist yet
--ALTER TABLE property
--	ADD CONSTRAINT fk_property_prop_coll_id
--	FOREIGN KEY (property_collection_id) REFERENCES property_collection(property_collection_id);

-- consider FK property and person
ALTER TABLE property
	ADD CONSTRAINT fk_property_person_id
	FOREIGN KEY (person_id) REFERENCES person(person_id);

-- consider FK property and account
ALTER TABLE property
	ADD CONSTRAINT fk_property_acctid
	FOREIGN KEY (account_id) REFERENCES account(account_id);

-- consider FK property and account_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_acct_colid
	FOREIGN KEY (property_value_account_coll_id) REFERENCES account_collection(account_collection_id);

-- consider FK property and netblock_collection
ALTER TABLE property
	ADD CONSTRAINT fk_property_nblk_coll_id
	FOREIGN KEY (netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id);

-- consider FK property and operating_system
ALTER TABLE property
	ADD CONSTRAINT fk_property_osid
	FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id);

-- consider FK property and company
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_compid
	FOREIGN KEY (property_value_company_id) REFERENCES company(company_id);

-- TRIGGERS
CREATE TRIGGER trigger_validate_property BEFORE INSERT OR UPDATE ON property FOR EACH ROW EXECUTE PROCEDURE validate_property();

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'property');
ALTER SEQUENCE property_property_id_seq
	 OWNED BY property.property_id;
DROP TABLE IF EXISTS property_v58;
DROP TABLE IF EXISTS audit.property_v58;
-- DONE DEALING WITH TABLE property [369544]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE property_collection
CREATE TABLE property_collection
(
	property_collection_id	integer NOT NULL,
	property_collection_name	varchar(255) NOT NULL,
	property_collection_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'property_collection', true);
ALTER TABLE property_collection
	ALTER property_collection_id
	SET DEFAULT nextval('property_collection_property_collection_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE property_collection ADD CONSTRAINT pk_property_collection PRIMARY KEY (property_collection_id);
ALTER TABLE property_collection ADD CONSTRAINT ak_uqpropcoll_name_type UNIQUE (property_collection_name, property_collection_type);

-- Table/Column Comments
COMMENT ON TABLE property_collection IS 'Collections of Property Name/Types.  Used for grouping properties for different purposes';
-- INDEXES
CREATE INDEX xif1property_collection ON property_collection USING btree (property_collection_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK property_collection and property_collection_hier
-- Skipping this FK since table does not exist yet
--ALTER TABLE property_collection_hier
--	ADD CONSTRAINT fk_propcollhier_propcolid
--	FOREIGN KEY (property_collection_id) REFERENCES property_collection(property_collection_id);

-- consider FK property_collection and property_collection_property
-- Skipping this FK since table does not exist yet
--ALTER TABLE property_collection_property
--	ADD CONSTRAINT fk_prop_coll_prop_prop_coll_id
--	FOREIGN KEY (property_collection_id) REFERENCES property_collection(property_collection_id);

-- consider FK property_collection and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_prop_coll_id
	FOREIGN KEY (property_collection_id) REFERENCES property_collection(property_collection_id);
-- consider FK property_collection and property_collection_hier
-- Skipping this FK since table does not exist yet
--ALTER TABLE property_collection_hier
--	ADD CONSTRAINT fk_propcollhier_chldpropcoll_i
--	FOREIGN KEY (child_property_collection_id) REFERENCES property_collection(property_collection_id);


-- FOREIGN KEYS TO
-- consider FK property_collection and val_property_collection_type
-- Skipping this FK since table does not exist yet
--ALTER TABLE property_collection
--	ADD CONSTRAINT fk_propcol_propcoltype
--	FOREIGN KEY (property_collection_type) REFERENCES val_property_collection_type(property_collection_type);


-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'property_collection');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'property_collection');
ALTER SEQUENCE property_collection_property_collection_id_seq
	 OWNED BY property_collection.property_collection_id;
-- DONE DEALING WITH TABLE property_collection [369580]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE property_collection_hier
CREATE TABLE property_collection_hier
(
	property_collection_id	integer NOT NULL,
	child_property_collection_id	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'property_collection_hier', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE property_collection_hier ADD CONSTRAINT pk_property_collection_hier PRIMARY KEY (property_collection_id, child_property_collection_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xif2property_collection_hier ON property_collection_hier USING btree (child_property_collection_id);
CREATE INDEX xif1property_collection_hier ON property_collection_hier USING btree (property_collection_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK property_collection_hier and property_collection
ALTER TABLE property_collection_hier
	ADD CONSTRAINT fk_propcollhier_chldpropcoll_i
	FOREIGN KEY (child_property_collection_id) REFERENCES property_collection(property_collection_id);
-- consider FK property_collection_hier and property_collection
ALTER TABLE property_collection_hier
	ADD CONSTRAINT fk_propcollhier_propcolid
	FOREIGN KEY (property_collection_id) REFERENCES property_collection(property_collection_id);

-- TRIGGERS

SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'property_collection_hier');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'property_collection_hier');
-- DONE DEALING WITH TABLE property_collection_hier [369592]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE property_collection_property
CREATE TABLE property_collection_property
(
	property_collection_id	integer NOT NULL,
	property_name	varchar(255) NOT NULL,
	property_type	varchar(50) NOT NULL,
	property_id_rank	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'property_collection_property', true);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE property_collection_property ADD CONSTRAINT pk_property_collection_propert PRIMARY KEY (property_collection_id, property_name, property_type);
ALTER TABLE property_collection_property ADD CONSTRAINT xakprop_coll_prop_rank UNIQUE (property_collection_id, property_id_rank);

-- Table/Column Comments
COMMENT ON TABLE property_collection_property IS 'name,type members of a property collection';
COMMENT ON COLUMN property_collection_property.property_name IS 'property name for validation purposes';
COMMENT ON COLUMN property_collection_property.property_type IS 'property type for validation purposes';
-- INDEXES
CREATE INDEX xifprop_coll_prop_prop_coll_id ON property_collection_property USING btree (property_collection_id);
CREATE INDEX xifprop_coll_prop_namtyp ON property_collection_property USING btree (property_name, property_type);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK property_collection_property and val_property
-- Skipping this FK since table does not exist yet
--ALTER TABLE property_collection_property
--	ADD CONSTRAINT fk_prop_col_propnamtyp
--	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);

-- consider FK property_collection_property and property_collection
ALTER TABLE property_collection_property
	ADD CONSTRAINT fk_prop_coll_prop_prop_coll_id
	FOREIGN KEY (property_collection_id) REFERENCES property_collection(property_collection_id);

-- TRIGGERS

-- XXX - may need to include trigger function
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'property_collection_property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'property_collection_property');
-- DONE DEALING WITH TABLE property_collection_property [369602]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE val_property_collection_type
CREATE TABLE val_property_collection_type
(
	property_collection_type	varchar(50) NOT NULL,
	description	varchar(4000)  NULL,
	max_num_members	integer  NULL,
	max_num_collections	integer  NULL,
	can_have_hierarchy	character(1) NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'val_property_collection_type', true);
ALTER TABLE val_property_collection_type
	ALTER can_have_hierarchy
	SET DEFAULT 'Y'::bpchar;

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE val_property_collection_type ADD CONSTRAINT pk_property_collction_type PRIMARY KEY (property_collection_type);

-- Table/Column Comments
COMMENT ON COLUMN val_property_collection_type.max_num_members IS 'Maximum INTEGER of members in a given collection of this type
';
COMMENT ON COLUMN val_property_collection_type.max_num_collections IS 'Maximum INTEGER of collections a given member can be a part of of this type.
';
COMMENT ON COLUMN val_property_collection_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE val_property_collection_type ADD CONSTRAINT check_yes_no_1132635988
	CHECK (can_have_hierarchy = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK val_property_collection_type and property_collection
ALTER TABLE property_collection
	ADD CONSTRAINT fk_propcol_propcoltype
	FOREIGN KEY (property_collection_type) REFERENCES val_property_collection_type(property_collection_type);

-- FOREIGN KEYS TO

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_property_collection_type');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_property_collection_type');
-- DONE DEALING WITH TABLE val_property_collection_type [370477]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE val_property [281156]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'val_property', 'val_property');

-- FOREIGN KEYS FROM
ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_nmtyp;
ALTER TABLE val_property_value DROP CONSTRAINT IF EXISTS fk_valproval_namtyp;


-- FOREIGN KEYS TO
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_propdttyp;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_val_prop_nblk_coll_type;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_pv_actyp_rst;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS fk_valprop_proptyp;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS pk_val_property;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xif3val_property";
DROP INDEX IF EXISTS "jazzhands"."xif1val_property";
DROP INDEX IF EXISTS "jazzhands"."xif4val_property";
DROP INDEX IF EXISTS "jazzhands"."xif2val_property";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_prodstate;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pdnsdomid;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_606225804;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_cmp_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pdevcol_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_354296970;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1279736247;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_sitec;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_2139007167;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_osid;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_2016888554;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pacct_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_pucls_id;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS check_prp_prmt_1279736503;
ALTER TABLE jazzhands.val_property DROP CONSTRAINT IF EXISTS ckc_val_prop_ismulti;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_val_property ON jazzhands.val_property;
DROP TRIGGER IF EXISTS trigger_audit_val_property ON jazzhands.val_property;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'val_property');
---- BEGIN audit.val_property TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."val_property_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'val_property');
---- DONE audit.val_property TEARDOWN


ALTER TABLE val_property RENAME TO val_property_v58;
ALTER TABLE audit.val_property RENAME TO val_property_v58;

CREATE TABLE val_property
(
	property_name	varchar(255) NOT NULL,
	property_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	is_multivalue	character(1) NOT NULL,
	prop_val_acct_coll_type_rstrct	varchar(50)  NULL,
	prop_val_nblk_coll_type_rstrct	varchar(50)  NULL,
	property_data_type	varchar(50) NOT NULL,
	permit_account_collection_id	character(10) NOT NULL,
	permit_account_id	character(10) NOT NULL,
	permit_account_realm_id	character(10) NOT NULL,
	permit_company_id	character(10) NOT NULL,
	permit_device_collection_id	character(10) NOT NULL,
	permit_dns_domain_id	character(10) NOT NULL,
	permit_layer2_network_id	character(10) NOT NULL,
	permit_layer3_network_id	character(10) NOT NULL,
	permit_netblock_collection_id	character(10) NOT NULL,
	permit_operating_system_id	character(10) NOT NULL,
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
	ALTER permit_device_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_dns_domain_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer2_network_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer3_network_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_netblock_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_operating_system_id
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
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_device_collection_id,
	permit_dns_domain_id,
	permit_layer2_network_id,
	permit_layer3_network_id,
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_person_id,
	permit_property_collection_id,		-- new column (permit_property_collection_id)
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
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_device_collection_id,
	permit_dns_domain_id,
	permit_layer2_network_id,
	permit_layer3_network_id,
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_person_id,
	'PROHIBITED'::bpchar,		-- new column (permit_property_collection_id)
	permit_service_env_collection,
	permit_site_code,
	permit_property_rank,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_property_v58;

INSERT INTO audit.val_property (
	property_name,
	property_type,
	description,
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_device_collection_id,
	permit_dns_domain_id,
	permit_layer2_network_id,
	permit_layer3_network_id,
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_person_id,
	permit_property_collection_id,		-- new column (permit_property_collection_id)
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
	is_multivalue,
	prop_val_acct_coll_type_rstrct,
	prop_val_nblk_coll_type_rstrct,
	property_data_type,
	permit_account_collection_id,
	permit_account_id,
	permit_account_realm_id,
	permit_company_id,
	permit_device_collection_id,
	permit_dns_domain_id,
	permit_layer2_network_id,
	permit_layer3_network_id,
	permit_netblock_collection_id,
	permit_operating_system_id,
	permit_person_id,
	NULL,		-- new column (permit_property_collection_id)
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
FROM audit.val_property_v58;

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
	ALTER permit_device_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_dns_domain_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer2_network_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_layer3_network_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_netblock_collection_id
	SET DEFAULT 'PROHIBITED'::bpchar;
ALTER TABLE val_property
	ALTER permit_operating_system_id
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
COMMENT ON TABLE val_property IS 'valid values and attributes for (name,type) pairs in the property table';
COMMENT ON COLUMN val_property.property_name IS 'property name for validation purposes';
COMMENT ON COLUMN val_property.property_type IS 'property type for validation purposes';
COMMENT ON COLUMN val_property.is_multivalue IS 'If N, acts like an ak on property.(*_id,property_type)';
COMMENT ON COLUMN val_property.property_data_type IS 'which of the property_table_* columns should be used for this value';
COMMENT ON COLUMN val_property.permit_account_collection_id IS 'defines how company id should be used in the property for this (name,type)';
COMMENT ON COLUMN val_property.permit_account_id IS 'defines how company id should be used in the property for this (name,type)';
COMMENT ON COLUMN val_property.permit_company_id IS 'defines how company id should be used in the property for this (name,type)';
COMMENT ON COLUMN val_property.permit_device_collection_id IS 'defines how company id should be used in the property for this (name,type)';
COMMENT ON COLUMN val_property.permit_dns_domain_id IS 'defines how company id should be used in the property for this (name,type)';
-- INDEXES
CREATE INDEX xif1val_property ON val_property USING btree (property_data_type);
CREATE INDEX xif3val_property ON val_property USING btree (prop_val_acct_coll_type_rstrct);
CREATE INDEX xif2val_property ON val_property USING btree (property_type);
CREATE INDEX xif4val_property ON val_property USING btree (prop_val_nblk_coll_type_rstrct);

-- CHECK CONSTRAINTS
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_2016888554
	CHECK (permit_account_realm_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_1279736247
	CHECK (permit_layer3_network_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_271462566
	CHECK (permit_property_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_354296970
	CHECK (permit_netblock_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pdevcol_id
	CHECK (permit_device_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pdnsdomid
	CHECK (permit_dns_domain_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_prodstate
	CHECK (permit_service_env_collection = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_1279736503
	CHECK (permit_layer2_network_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pacct_id
	CHECK (permit_account_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_osid
	CHECK (permit_operating_system_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_2139007167
	CHECK (permit_property_rank = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_sitec
	CHECK (permit_site_code = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT check_prp_prmt_606225804
	CHECK (permit_person_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_cmp_id
	CHECK (permit_company_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_pucls_id
	CHECK (permit_account_collection_id = ANY (ARRAY['REQUIRED'::bpchar, 'PROHIBITED'::bpchar, 'ALLOWED'::bpchar]));
ALTER TABLE val_property ADD CONSTRAINT ckc_val_prop_ismulti
	CHECK (is_multivalue = ANY (ARRAY['Y'::bpchar, 'N'::bpchar]));

-- FOREIGN KEYS FROM
-- consider FK val_property and val_property_value
-- Skipping this FK since table does not exist yet
ALTER TABLE val_property_value
	ADD CONSTRAINT fk_valproval_namtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);

-- consider FK val_property and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_nmtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);
-- consider FK val_property and property_collection_property
ALTER TABLE property_collection_property
	ADD CONSTRAINT fk_prop_col_propnamtyp
	FOREIGN KEY (property_name, property_type) REFERENCES val_property(property_name, property_type);

-- FOREIGN KEYS TO
-- consider FK val_property and val_property_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_proptyp
	FOREIGN KEY (property_type) REFERENCES val_property_type(property_type);

-- consider FK val_property and val_account_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_pv_actyp_rst
	FOREIGN KEY (prop_val_acct_coll_type_rstrct) REFERENCES val_account_collection_type(account_collection_type);

-- consider FK val_property and val_netblock_collection_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_val_prop_nblk_coll_type
	FOREIGN KEY (prop_val_nblk_coll_type_rstrct) REFERENCES val_netblock_collection_type(netblock_collection_type);

-- consider FK val_property and val_property_data_type
ALTER TABLE val_property
	ADD CONSTRAINT fk_valprop_propdttyp
	FOREIGN KEY (property_data_type) REFERENCES val_property_data_type(property_data_type);


-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'val_property');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'val_property');
DROP TABLE IF EXISTS val_property_v58;
DROP TABLE IF EXISTS audit.val_property_v58;
-- DONE DEALING WITH TABLE val_property [370434]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE sw_package [280520]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'sw_package', 'sw_package');

-- FOREIGN KEYS FROM
ALTER TABLE sw_package_relation DROP CONSTRAINT IF EXISTS fk_sw_pkgrel_ref_sw_pkg;

ALTER TABLE sw_package_release DROP CONSTRAINT IF EXISTS fk_sw_pkg_ref_sw_pkg_rel;

ALTER TABLE property DROP CONSTRAINT IF EXISTS fk_property_pval_swpkgid;

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.sw_package DROP CONSTRAINT IF EXISTS fk_sw_pkg_ref_v_prod_state;
ALTER TABLE jazzhands.sw_package DROP CONSTRAINT IF EXISTS fk_swpkg_ref_vswpkgtype;
ALTER TABLE jazzhands.sw_package DROP CONSTRAINT IF EXISTS pk_sw_package;
-- INDEXES
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_audit_sw_package ON jazzhands.sw_package;
DROP TRIGGER IF EXISTS trig_userlog_sw_package ON jazzhands.sw_package;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'sw_package');
---- BEGIN audit.sw_package TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."sw_package_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'sw_package');
---- DONE audit.sw_package TEARDOWN


ALTER TABLE sw_package RENAME TO sw_package_v58;
ALTER TABLE audit.sw_package RENAME TO sw_package_v58;

CREATE TABLE sw_package
(
	sw_package_id	integer NOT NULL,
	sw_package_name	varchar(50) NOT NULL,
	sw_package_type	varchar(50) NOT NULL,
	description	varchar(255)  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'sw_package', false);
ALTER TABLE sw_package
	ALTER sw_package_id
	SET DEFAULT nextval('sw_package_sw_package_id_seq'::regclass);
INSERT INTO sw_package (
	sw_package_id,
	sw_package_name,
	sw_package_type,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	sw_package_id,
	sw_package_name,
	sw_package_type,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM sw_package_v58 sw;

INSERT INTO audit.sw_package (
	sw_package_id,
	sw_package_name,
	sw_package_type,
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
	sw.sw_package_id,
	sw.sw_package_name,
	sw.sw_package_type,
	sw.description,
	sw.data_ins_user,
	sw.data_ins_date,
	sw.data_upd_user,
	sw.data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.sw_package_v58 sw;

ALTER TABLE sw_package
	ALTER sw_package_id
	SET DEFAULT nextval('sw_package_sw_package_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE sw_package ADD CONSTRAINT pk_sw_package PRIMARY KEY (sw_package_id);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK sw_package and sw_package_release
-- Skipping this FK since table does not exist yet
--ALTER TABLE sw_package_release
--	ADD CONSTRAINT fk_sw_pkg_ref_sw_pkg_rel
--	FOREIGN KEY (sw_package_id) REFERENCES sw_package(sw_package_id);

-- consider FK sw_package and property
ALTER TABLE property
	ADD CONSTRAINT fk_property_pval_swpkgid
	FOREIGN KEY (property_value_sw_package_id) REFERENCES sw_package(sw_package_id);
-- consider FK sw_package and sw_package_relation
ALTER TABLE sw_package_relation
	ADD CONSTRAINT fk_sw_pkgrel_ref_sw_pkg
	FOREIGN KEY (related_sw_package_id) REFERENCES sw_package(sw_package_id);


-- FOREIGN KEYS TO
-- consider FK sw_package and val_sw_package_type
ALTER TABLE sw_package
	ADD CONSTRAINT fk_swpkg_ref_vswpkgtype
	FOREIGN KEY (sw_package_type) REFERENCES val_sw_package_type(sw_package_type);


-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'sw_package');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'sw_package');
ALTER SEQUENCE sw_package_sw_package_id_seq
	 OWNED BY sw_package.sw_package_id;
DROP TABLE IF EXISTS sw_package_v58;
DROP TABLE IF EXISTS audit.sw_package_v58;
-- DONE DEALING WITH TABLE sw_package [369798]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE sw_package_release [280545]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'sw_package_release', 'sw_package_release');

-- FOREIGN KEYS FROM
ALTER TABLE voe_sw_package DROP CONSTRAINT IF EXISTS fk_voe_swpkg_ref_swpkg_rel;
ALTER TABLE sw_package_relation DROP CONSTRAINT IF EXISTS fk_swpkgrltn_ref_swpkgrel;


-- FOREIGN KEYS TO
ALTER TABLE jazzhands.sw_package_release DROP CONSTRAINT IF EXISTS fk_sw_pkg_ref_sw_pkg_rel;
ALTER TABLE jazzhands.sw_package_release DROP CONSTRAINT IF EXISTS fk_sw_pkg_rel_ref_vdevarch;
ALTER TABLE jazzhands.sw_package_release DROP CONSTRAINT IF EXISTS fk_sw_package_type;
ALTER TABLE jazzhands.sw_package_release DROP CONSTRAINT IF EXISTS fk_sw_pkg_rel_ref_vsvcenv;
ALTER TABLE jazzhands.sw_package_release DROP CONSTRAINT IF EXISTS fk_sw_pkg_rel_ref_sys_user;
ALTER TABLE jazzhands.sw_package_release DROP CONSTRAINT IF EXISTS fk_sw_pkg_rel_ref_vswpkgfmt;
ALTER TABLE jazzhands.sw_package_release DROP CONSTRAINT IF EXISTS fk_sw_pkg_rel_ref_sw_pkg_rep;
ALTER TABLE jazzhands.sw_package_release DROP CONSTRAINT IF EXISTS pk_sw_package_release;
ALTER TABLE jazzhands.sw_package_release DROP CONSTRAINT IF EXISTS ak_uq_sw_pkg_rel_comb_sw_packa;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_sw_pkg_rel_sw_pkg_id";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_sw_package_release ON jazzhands.sw_package_release;
DROP TRIGGER IF EXISTS trigger_audit_sw_package_release ON jazzhands.sw_package_release;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'sw_package_release');
---- BEGIN audit.sw_package_release TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."sw_package_release_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'sw_package_release');
---- DONE audit.sw_package_release TEARDOWN


ALTER TABLE sw_package_release RENAME TO sw_package_release_v58;
ALTER TABLE audit.sw_package_release RENAME TO sw_package_release_v58;

CREATE TABLE sw_package_release
(
	sw_package_release_id	integer NOT NULL,
	sw_package_id	integer NOT NULL,
	sw_package_version	varchar(50) NOT NULL,
	sw_package_format	varchar(50) NOT NULL,
	sw_package_type	varchar(50)  NULL,
	creation_account_id	integer NOT NULL,
	processor_architecture	varchar(50) NOT NULL,
	service_environment_id	integer NOT NULL,
	sw_package_repository_id	integer NOT NULL,
	uploading_principal	varchar(255)  NULL,
	package_size	integer  NULL,
	installed_package_size_kb	integer  NULL,
	pathname	varchar(1024)  NULL,
	md5sum	varchar(255)  NULL,
	description	varchar(255)  NULL,
	instantiation_date	timestamp with time zone  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'sw_package_release', false);
ALTER TABLE sw_package_release
	ALTER sw_package_release_id
	SET DEFAULT nextval('sw_package_release_sw_package_release_id_seq'::regclass);
INSERT INTO sw_package_release (
	sw_package_release_id,
	sw_package_id,
	sw_package_version,
	sw_package_format,
	sw_package_type,
	creation_account_id,
	processor_architecture,
	service_environment_id,		-- new column (service_environment_id)
	sw_package_repository_id,
	uploading_principal,
	package_size,
	installed_package_size_kb,
	pathname,
	md5sum,
	description,
	instantiation_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	sw.sw_package_release_id,
	sw.sw_package_id,
	sw.sw_package_version,
	sw.sw_package_format,
	sw.sw_package_type,
	sw.creation_account_id,
	sw.processor_architecture,
	se.service_environment_id ,	-- new column (service_environment_id)
	sw.sw_package_repository_id,
	sw.uploading_principal,
	sw.package_size,
	sw.installed_package_size_kb,
	sw.pathname,
	sw.md5sum,
	sw.description,
	sw.instantiation_date,
	sw.data_ins_user,
	sw.data_ins_date,
	sw.data_upd_user,
	sw.data_upd_date
FROM sw_package_release_v58 sw
	inner join service_environment se on
		sw.service_environment = se.service_environment_name;

INSERT INTO audit.sw_package_release (
	sw_package_release_id,
	sw_package_id,
	sw_package_version,
	sw_package_format,
	sw_package_type,
	creation_account_id,
	processor_architecture,
	service_environment_id,		-- new column (service_environment_id)
	sw_package_repository_id,
	uploading_principal,
	package_size,
	installed_package_size_kb,
	pathname,
	md5sum,
	description,
	instantiation_date,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	sw.sw_package_release_id,
	sw.sw_package_id,
	sw.sw_package_version,
	sw.sw_package_format,
	sw.sw_package_type,
	sw.creation_account_id,
	sw.processor_architecture,
	se.service_environment_id,	-- new column (service_environment_id)
	sw.sw_package_repository_id,
	sw.uploading_principal,
	sw.package_size,
	sw.installed_package_size_kb,
	sw.pathname,
	sw.md5sum,
	sw.description,
	sw.instantiation_date,
	sw.data_ins_user,
	sw.data_ins_date,
	sw.data_upd_user,
	sw.data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.sw_package_release_v58 sw
	inner join service_environment se on
		sw.service_environment = se.service_environment_name;

ALTER TABLE sw_package_release
	ALTER sw_package_release_id
	SET DEFAULT nextval('sw_package_release_sw_package_release_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE sw_package_release ADD CONSTRAINT ak_uq_sw_pkg_rel_comb_sw_packa UNIQUE (sw_package_id, sw_package_version, processor_architecture, sw_package_repository_id);
ALTER TABLE sw_package_release ADD CONSTRAINT pk_sw_package_release PRIMARY KEY (sw_package_release_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX idx_sw_pkg_rel_sw_pkg_id ON sw_package_release USING btree (sw_package_id);

-- CHECK CONSTRAINTS

-- FOREIGN KEYS FROM
-- consider FK sw_package_release and sw_package_relation
ALTER TABLE sw_package_relation
	ADD CONSTRAINT fk_swpkgrltn_ref_swpkgrel
	FOREIGN KEY (sw_package_release_id) REFERENCES sw_package_release(sw_package_release_id);

-- consider FK sw_package_release and voe_sw_package
ALTER TABLE voe_sw_package
	ADD CONSTRAINT fk_voe_swpkg_ref_swpkg_rel
	FOREIGN KEY (sw_package_release_id) REFERENCES sw_package_release(sw_package_release_id);


-- FOREIGN KEYS TO
-- consider FK sw_package_release and val_sw_package_format
ALTER TABLE sw_package_release
	ADD CONSTRAINT fk_sw_pkg_rel_ref_vswpkgfmt
	FOREIGN KEY (sw_package_format) REFERENCES val_sw_package_format(sw_package_format);

-- consider FK sw_package_release and account
ALTER TABLE sw_package_release
	ADD CONSTRAINT fk_sw_pkg_rel_ref_sys_user
	FOREIGN KEY (creation_account_id) REFERENCES account(account_id);

-- consider FK sw_package_release and sw_package_repository
ALTER TABLE sw_package_release
	ADD CONSTRAINT fk_sw_pkg_rel_ref_sw_pkg_rep
	FOREIGN KEY (sw_package_repository_id) REFERENCES sw_package_repository(sw_package_repository_id);

-- consider FK sw_package_release and sw_package
ALTER TABLE sw_package_release
	ADD CONSTRAINT fk_sw_pkg_ref_sw_pkg_rel
	FOREIGN KEY (sw_package_id) REFERENCES sw_package(sw_package_id);

-- consider FK sw_package_release and val_processor_architecture
ALTER TABLE sw_package_release
	ADD CONSTRAINT fk_sw_pkg_rel_ref_vdevarch
	FOREIGN KEY (processor_architecture) REFERENCES val_processor_architecture(processor_architecture);

ALTER TABLE SW_PACKAGE_RELEASE
	ADD CONSTRAINT FK_SW_PACKAGE_TYPE 
	FOREIGN KEY (SW_PACKAGE_TYPE) 
	REFERENCES VAL_SW_PACKAGE_TYPE (SW_PACKAGE_TYPE)  ;

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'sw_package_release');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'sw_package_release');
ALTER SEQUENCE sw_package_release_sw_package_release_id_seq
	 OWNED BY sw_package_release.sw_package_release_id;
DROP TABLE IF EXISTS sw_package_release_v58;
DROP TABLE IF EXISTS audit.sw_package_release_v58;
-- DONE DEALING WITH TABLE sw_package_release [369823]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE network_service [280059]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'network_service', 'network_service');

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
ALTER TABLE jazzhands.network_service DROP CONSTRAINT IF EXISTS fk_netsvc_dnsid_id;
ALTER TABLE jazzhands.network_service DROP CONSTRAINT IF EXISTS fk_netsvc_netint_id;
ALTER TABLE jazzhands.network_service DROP CONSTRAINT IF EXISTS fk_netsvc_csvcenv;
ALTER TABLE jazzhands.network_service DROP CONSTRAINT IF EXISTS fk_netsvc_device_id;
ALTER TABLE jazzhands.network_service DROP CONSTRAINT IF EXISTS fk_netsvc_netsvctyp_id;
ALTER TABLE jazzhands.network_service DROP CONSTRAINT IF EXISTS pk_service;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."idx_netsvc_svcenv";
DROP INDEX IF EXISTS "jazzhands"."ix_netsvc_netintid";
DROP INDEX IF EXISTS "jazzhands"."ix_netsvc_dnsidrecid";
DROP INDEX IF EXISTS "jazzhands"."ix_netsvc_netdevid";
DROP INDEX IF EXISTS "jazzhands"."idx_netsvc_ismonitored";
DROP INDEX IF EXISTS "jazzhands"."idx_netsvc_netsvctype";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.network_service DROP CONSTRAINT IF EXISTS ckc_is_monitored_network_;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_network_service ON jazzhands.network_service;
DROP TRIGGER IF EXISTS trigger_audit_network_service ON jazzhands.network_service;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'network_service');
---- BEGIN audit.network_service TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."network_service_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'network_service');
---- DONE audit.network_service TEARDOWN


ALTER TABLE network_service RENAME TO network_service_v58;
ALTER TABLE audit.network_service RENAME TO network_service_v58;

CREATE TABLE network_service
(
	network_service_id	integer NOT NULL,
	name	varchar(255)  NULL,
	description	varchar(255)  NULL,
	network_service_type	varchar(50) NOT NULL,
	is_monitored	character(1)  NULL,
	device_id	integer  NULL,
	network_interface_id	integer  NULL,
	dns_record_id	integer  NULL,
	service_environment_id	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'network_service', false);
ALTER TABLE network_service
	ALTER network_service_id
	SET DEFAULT nextval('network_service_network_service_id_seq'::regclass);

INSERT INTO network_service (
	network_service_id,
	name,
	description,
	network_service_type,
	is_monitored,
	device_id,
	network_interface_id,
	dns_record_id,
	service_environment_id,		-- new column (service_environment_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	ns.network_service_id,
	ns.name,
	ns.description,
	ns.network_service_type,
	ns.is_monitored,
	ns.device_id,
	ns.network_interface_id,
	ns.dns_record_id,
	se.service_environment_id,	-- new column (service_environment_id)
	ns.data_ins_user,
	ns.data_ins_date,
	ns.data_upd_user,
	ns.data_upd_date
FROM network_service_v58 ns
	inner join service_environment se on
		ns.service_environment = se.service_environment_name;

INSERT INTO audit.network_service (
	network_service_id,
	name,
	description,
	network_service_type,
	is_monitored,
	device_id,
	network_interface_id,
	dns_record_id,
	service_environment_id,		-- new column (service_environment_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	ns.network_service_id,
	ns.name,
	ns.description,
	ns.network_service_type,
	ns.is_monitored,
	ns.device_id,
	ns.network_interface_id,
	ns.dns_record_id,
	se.service_environment_id,	-- new column (service_environment_id)
	ns.data_ins_user,
	ns.data_ins_date,
	ns.data_upd_user,
	ns.data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.network_service_v58 ns
	inner join service_environment se on
		ns.service_environment = se.service_environment_name;

ALTER TABLE network_service
	ALTER network_service_id
	SET DEFAULT nextval('network_service_network_service_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE network_service ADD CONSTRAINT pk_service PRIMARY KEY (network_service_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX idx_netsvc_ismonitored ON network_service USING btree (is_monitored);
CREATE INDEX idx_netsvc_netsvctype ON network_service USING btree (network_service_type);
CREATE INDEX idx_netsvc_svcenv ON network_service USING btree (service_environment_id);
CREATE INDEX ix_netsvc_netintid ON network_service USING btree (network_interface_id);
CREATE INDEX ix_netsvc_netdevid ON network_service USING btree (device_id);
CREATE INDEX ix_netsvc_dnsidrecid ON network_service USING btree (dns_record_id);

-- CHECK CONSTRAINTS
ALTER TABLE network_service ADD CONSTRAINT ckc_is_monitored_network_
	CHECK ((is_monitored IS NULL) OR ((is_monitored = ANY (ARRAY['Y'::bpchar, 'N'::bpchar])) AND ((is_monitored)::text = upper((is_monitored)::text))));

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- consider FK network_service and device
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_device_id
	FOREIGN KEY (device_id) REFERENCES device(device_id);
-- consider FK network_service and service_environment
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_csvcenv
	FOREIGN KEY (service_environment_id) REFERENCES service_environment(service_environment_id);
-- consider FK network_service and val_network_service_type
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_netsvctyp_id
	FOREIGN KEY (network_service_type) REFERENCES val_network_service_type(network_service_type);

-- consider FK network_service and network_interface
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_netint_id
	FOREIGN KEY (network_interface_id) REFERENCES network_interface(network_interface_id);

-- consider FK network_service and dns_record
-- Skipping this FK since table does not exist yet
ALTER TABLE network_service
	ADD CONSTRAINT fk_netsvc_dnsid_id
	FOREIGN KEY (dns_record_id) REFERENCES dns_record(dns_record_id);


-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'network_service');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'network_service');
ALTER SEQUENCE network_service_network_service_id_seq
	 OWNED BY network_service.network_service_id;
DROP TABLE IF EXISTS network_service_v58;
DROP TABLE IF EXISTS audit.network_service_v58;
-- DONE DEALING WITH TABLE network_service [369297]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE appaal_instance [279262]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'appaal_instance', 'appaal_instance');

-- FOREIGN KEYS FROM
ALTER TABLE appaal_instance_property DROP CONSTRAINT IF EXISTS fk_appaalins_ref_appaalinsprop;
ALTER TABLE appaal_instance_device_coll DROP CONSTRAINT IF EXISTS fk_appaalins_ref_appaalinsdcol;


-- FOREIGN KEYS TO
ALTER TABLE jazzhands.appaal_instance DROP CONSTRAINT IF EXISTS fk_appaal_ref_appaal_inst;
ALTER TABLE jazzhands.appaal_instance DROP CONSTRAINT IF EXISTS fk_appaal_inst_filgrpacctcolid;
ALTER TABLE jazzhands.appaal_instance DROP CONSTRAINT IF EXISTS fk_appaal_i_fk_applic_svcenv;
ALTER TABLE jazzhands.appaal_instance DROP CONSTRAINT IF EXISTS fk_appaal_i_reference_fo_accti;
ALTER TABLE jazzhands.appaal_instance DROP CONSTRAINT IF EXISTS pk_appaal_instance;
-- INDEXES
DROP INDEX IF EXISTS "jazzhands"."xifappaal_inst_filgrpacctcolid";
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.appaal_instance DROP CONSTRAINT IF EXISTS ckc_file_mode_appaal_i;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trig_userlog_appaal_instance ON jazzhands.appaal_instance;
DROP TRIGGER IF EXISTS trigger_audit_appaal_instance ON jazzhands.appaal_instance;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'appaal_instance');
---- BEGIN audit.appaal_instance TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."appaal_instance_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'appaal_instance');
---- DONE audit.appaal_instance TEARDOWN


ALTER TABLE appaal_instance RENAME TO appaal_instance_v58;
ALTER TABLE audit.appaal_instance RENAME TO appaal_instance_v58;

CREATE TABLE appaal_instance
(
	appaal_instance_id	integer NOT NULL,
	appaal_id	integer  NULL,
	service_environment_id	integer NOT NULL,
	file_mode	integer NOT NULL,
	file_owner_account_id	integer NOT NULL,
	file_group_acct_collection_id	integer  NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'appaal_instance', false);
ALTER TABLE appaal_instance
	ALTER appaal_instance_id
	SET DEFAULT nextval('appaal_instance_appaal_instance_id_seq'::regclass);

INSERT INTO appaal_instance (
	appaal_instance_id,
	appaal_id,
	service_environment_id,		-- new column (service_environment_id)
	file_mode,
	file_owner_account_id,
	file_group_acct_collection_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	ai.appaal_instance_id,
	ai.appaal_id,
	se.service_environment_id,	-- new column (service_environment_id)
	ai.file_mode,
	ai.file_owner_account_id,
	ai.file_group_acct_collection_id,
	ai.data_ins_user,
	ai.data_ins_date,
	ai.data_upd_user,
	ai.data_upd_date
FROM appaal_instance_v58 ai
	inner join service_environment se on
		ai.service_environment = se.service_environment_name;

INSERT INTO audit.appaal_instance (
	appaal_instance_id,
	appaal_id,
	service_environment_id,		-- new column (service_environment_id)
	file_mode,
	file_owner_account_id,
	file_group_acct_collection_id,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	ai.appaal_instance_id,
	ai.appaal_id,
	se.service_environment_id,	-- new column (service_environment_id)
	ai.file_mode,
	ai.file_owner_account_id,
	ai.file_group_acct_collection_id,
	ai.data_ins_user,
	ai.data_ins_date,
	ai.data_upd_user,
	ai.data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.appaal_instance_v58 ai
	inner join service_environment se on
		ai.service_environment = se.service_environment_name;

ALTER TABLE appaal_instance
	ALTER appaal_instance_id
	SET DEFAULT nextval('appaal_instance_appaal_instance_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE appaal_instance ADD CONSTRAINT pk_appaal_instance PRIMARY KEY (appaal_instance_id);

-- Table/Column Comments
-- INDEXES
CREATE INDEX xifappaal_inst_filgrpacctcolid ON appaal_instance USING btree (file_group_acct_collection_id);

-- CHECK CONSTRAINTS
ALTER TABLE appaal_instance ADD CONSTRAINT ckc_file_mode_appaal_i
	CHECK ((file_mode >= 0) AND (file_mode <= 4095));

-- FOREIGN KEYS FROM
-- consider FK appaal_instance and appaal_instance_device_coll
ALTER TABLE appaal_instance_device_coll
	ADD CONSTRAINT fk_appaalins_ref_appaalinsdcol
	FOREIGN KEY (appaal_instance_id) REFERENCES appaal_instance(appaal_instance_id);

-- consider FK appaal_instance and appaal_instance_property
ALTER TABLE appaal_instance_property
	ADD CONSTRAINT fk_appaalins_ref_appaalinsprop
	FOREIGN KEY (appaal_instance_id) REFERENCES appaal_instance(appaal_instance_id);


-- FOREIGN KEYS TO
-- consider FK appaal_instance and account
ALTER TABLE appaal_instance
	ADD CONSTRAINT fk_appaal_i_reference_fo_accti
	FOREIGN KEY (file_owner_account_id) REFERENCES account(account_id);

-- consider FK appaal_instance and service_environment
ALTER TABLE appaal_instance
	ADD CONSTRAINT fk_appaal_i_fk_applic_svcenv
	FOREIGN KEY (service_environment_id) REFERENCES service_environment(service_environment_id);
-- consider FK appaal_instance and account_collection
ALTER TABLE appaal_instance
	ADD CONSTRAINT fk_appaal_inst_filgrpacctcolid
	FOREIGN KEY (file_group_acct_collection_id) REFERENCES account_collection(account_collection_id);

-- consider FK appaal_instance and appaal
ALTER TABLE appaal_instance
	ADD CONSTRAINT fk_appaal_ref_appaal_inst
	FOREIGN KEY (appaal_id) REFERENCES appaal(appaal_id);


-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'appaal_instance');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'appaal_instance');
ALTER SEQUENCE appaal_instance_appaal_instance_id_seq
	 OWNED BY appaal_instance.appaal_instance_id;
DROP TABLE IF EXISTS appaal_instance_v58;
DROP TABLE IF EXISTS audit.appaal_instance_v58;
-- DONE DEALING WITH TABLE appaal_instance [368503]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE voe [422124]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'voe', 'voe');

-- FOREIGN KEYS FROM
ALTER TABLE voe_relation DROP CONSTRAINT IF EXISTS fk_voe_ref_voe_rel_voe;
ALTER TABLE voe_symbolic_track DROP CONSTRAINT IF EXISTS fk_voe_symbtrk_ref_pendvoe;
ALTER TABLE voe_sw_package DROP CONSTRAINT IF EXISTS fk_voe_swpkg_ref_voe;
ALTER TABLE voe_relation DROP CONSTRAINT IF EXISTS fk_voe_ref_voe_rel_rltdvoe;
ALTER TABLE voe_symbolic_track DROP CONSTRAINT IF EXISTS fk_voe_symbtrk_ref_actvvoe;
ALTER TABLE device DROP CONSTRAINT IF EXISTS fk_device_fk_voe;


-- FOREIGN KEYS TO
ALTER TABLE jazzhands.voe DROP CONSTRAINT IF EXISTS fk_voe_ref_vvoestate;
ALTER TABLE jazzhands.voe DROP CONSTRAINT IF EXISTS fk_voe_ref_v_svcenv;
ALTER TABLE jazzhands.voe DROP CONSTRAINT IF EXISTS ak_uq_voe_voe_name_sw_vonage_o;
ALTER TABLE jazzhands.voe DROP CONSTRAINT IF EXISTS pk_vonage_operating_env;
-- INDEXES
-- CHECK CONSTRAINTS, etc
ALTER TABLE jazzhands.voe DROP CONSTRAINT IF EXISTS sys_c0033905;
ALTER TABLE jazzhands.voe DROP CONSTRAINT IF EXISTS sys_c0033906;
ALTER TABLE jazzhands.voe DROP CONSTRAINT IF EXISTS sys_c0033904;
-- TRIGGERS, etc
DROP TRIGGER IF EXISTS trigger_audit_voe ON jazzhands.voe;
DROP TRIGGER IF EXISTS trig_userlog_voe ON jazzhands.voe;
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'voe');
---- BEGIN audit.voe TEARDOWN

-- FOREIGN KEYS FROM

-- FOREIGN KEYS TO
-- INDEXES
DROP INDEX IF EXISTS "audit"."voe_aud#timestamp_idx";
-- CHECK CONSTRAINTS, etc
-- TRIGGERS, etc
SELECT schema_support.save_dependant_objects_for_replay('audit', 'voe');
---- DONE audit.voe TEARDOWN


ALTER TABLE voe RENAME TO voe_v58;
ALTER TABLE audit.voe RENAME TO voe_v58;

CREATE TABLE voe
(
	voe_id	integer NOT NULL,
	voe_name	varchar(50) NOT NULL,
	voe_state	varchar(50) NOT NULL,
	sw_package_repository_id	integer NOT NULL,
	service_environment_id	integer NOT NULL,
	data_ins_user	varchar(255)  NULL,
	data_ins_date	timestamp with time zone  NULL,
	data_upd_user	varchar(255)  NULL,
	data_upd_date	timestamp with time zone  NULL
);
SELECT schema_support.build_audit_table('audit', 'jazzhands', 'voe', false);
ALTER TABLE voe
	ALTER voe_id
	SET DEFAULT nextval('voe_voe_id_seq'::regclass);
INSERT INTO voe (
	voe_id,
	voe_name,
	voe_state,
	sw_package_repository_id,
	service_environment_id,		-- new column (service_environment_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
) SELECT
	v.voe_id,
	v.voe_name,
	v.voe_state,
	v.sw_package_repository_id,
	se.service_environment_id,	-- new column (service_environment_id)
	v.data_ins_user,
	v.data_ins_date,
	v.data_upd_user,
	v.data_upd_date
FROM voe_v58 v
	inner join service_environment se on
		v.service_environment = se.service_environment_name;

INSERT INTO audit.voe (
	voe_id,
	voe_name,
	voe_state,
	sw_package_repository_id,
	service_environment_id,		-- new column (service_environment_id)
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
) SELECT
	v.voe_id,
	v.voe_name,
	v.voe_state,
	v.sw_package_repository_id,
	se.service_environment_id,	-- new column (service_environment_id)
	v.data_ins_user,
	v.data_ins_date,
	v.data_upd_user,
	v.data_upd_date,
	"aud#action",
	"aud#timestamp",
	"aud#user",
	"aud#seq"
FROM audit.voe_v58 v
	inner join service_environment se on
		v.service_environment = se.service_environment_name;

ALTER TABLE voe
	ALTER voe_id
	SET DEFAULT nextval('voe_voe_id_seq'::regclass);

-- PRIMARY AND ALTERNATE KEYS
ALTER TABLE voe ADD CONSTRAINT ak_uq_voe_voe_name_sw_vonage_o UNIQUE (voe_name, sw_package_repository_id);
ALTER TABLE voe ADD CONSTRAINT pk_vonage_operating_env PRIMARY KEY (voe_id);

-- Table/Column Comments
-- INDEXES

-- CHECK CONSTRAINTS
ALTER TABLE voe ADD CONSTRAINT sys_c0033904
	CHECK (voe_id IS NOT NULL);
ALTER TABLE voe ADD CONSTRAINT sys_c0033906
	CHECK (voe_state IS NOT NULL);
ALTER TABLE voe ADD CONSTRAINT sys_c0033905
	CHECK (voe_name IS NOT NULL);

-- FOREIGN KEYS FROM
-- consider FK voe and voe_sw_package
ALTER TABLE voe_sw_package
	ADD CONSTRAINT fk_voe_swpkg_ref_voe
	FOREIGN KEY (voe_id) REFERENCES voe(voe_id);

-- consider FK voe and voe_relation
ALTER TABLE voe_relation
	ADD CONSTRAINT fk_voe_ref_voe_rel_rltdvoe
	FOREIGN KEY (related_voe_id) REFERENCES voe(voe_id);

-- consider FK voe and voe_symbolic_track
ALTER TABLE voe_symbolic_track
	ADD CONSTRAINT fk_voe_symbtrk_ref_actvvoe
	FOREIGN KEY (active_voe_id) REFERENCES voe(voe_id);

-- consider FK voe and voe_relation
ALTER TABLE voe_relation
	ADD CONSTRAINT fk_voe_ref_voe_rel_voe
	FOREIGN KEY (voe_id) REFERENCES voe(voe_id);

-- consider FK voe and voe_symbolic_track
ALTER TABLE voe_symbolic_track
	ADD CONSTRAINT fk_voe_symbtrk_ref_pendvoe
	FOREIGN KEY (pending_voe_id) REFERENCES voe(voe_id);

-- consider FK voe and device
ALTER TABLE device
	ADD CONSTRAINT fk_device_fk_voe
	FOREIGN KEY (voe_id) REFERENCES voe(voe_id);


-- FOREIGN KEYS TO
-- consider FK voe and service_environment
ALTER TABLE voe
	ADD CONSTRAINT fk_voe_ref_v_svcenv
	FOREIGN KEY (service_environment_id) REFERENCES service_environment(service_environment_id);

-- consider FK voe and val_voe_state
ALTER TABLE voe
	ADD CONSTRAINT fk_voe_ref_vvoestate
	FOREIGN KEY (voe_state) REFERENCES val_voe_state(voe_state);

-- TRIGGERS
SELECT schema_support.rebuild_stamp_trigger('jazzhands', 'voe');
SELECT schema_support.rebuild_audit_trigger('audit', 'jazzhands', 'voe');
ALTER SEQUENCE voe_voe_id_seq
	 OWNED BY voe.voe_id;
DROP TABLE IF EXISTS voe_v58;
DROP TABLE IF EXISTS audit.voe_v58;
-- DONE DEALING WITH TABLE voe [403478]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH property collection triggers


/*
 * Copyright (c) 2014 Todd Kover
 * All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


--
-- $HeadURL$
-- $Id$
--

CREATE OR REPLACE FUNCTION property_collection_hier_enforce()
RETURNS TRIGGER AS $$
DECLARE
	pct	val_property_collection_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	pct
	FROM	val_property_collection_type
	WHERE	property_collection_type =
		(select property_collection_type from property_collection
			where property_collection_id = NEW.parent_property_collection_id);

	IF pct.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Device Collections of type % may not be hierarcical',
			pct.property_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_property_collection_hier_enforce
	 ON property_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_property_collection_hier_enforce
	AFTER INSERT OR UPDATE 
	ON property_collection_hier
		DEFERRABLE INITIALLY IMMEDIATE
	FOR EACH ROW
	EXECUTE PROCEDURE property_collection_hier_enforce();


-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION property_collection_member_enforce()
RETURNS TRIGGER AS $$
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
		  and	property_type = NEW.property_typw
		  and	property_collection_type = pct.property_collection_type;
		IF tally > pct.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Device may not be a member of more than % collections of type %',
				pct.MAX_NUM_COLLECTIONS, pct.property_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_property_collection_member_enforce
	 ON property_collection_property;
CREATE CONSTRAINT TRIGGER trigger_property_collection_member_enforce
	AFTER INSERT OR UPDATE 
	ON property_collection_property
		DEFERRABLE INITIALLY IMMEDIATE
	FOR EACH ROW
	EXECUTE PROCEDURE property_collection_member_enforce();

-- DONE DEALING WITH property collection triggers
--------------------------------------------------------------------




--------------------------------------------------------------------
-- DEALING WITH proc device_utils.monitoring_off_in_rack -> monitoring_off_in_rack 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 408441
CREATE OR REPLACE FUNCTION device_utils.monitoring_off_in_rack(_in_rack_id integer)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
BEGIN
	BEGIN
		PERFORM local_hooks.monitoring_off_in_rack_early(
			_in_rack_id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	UPDATE device
	  SET	is_monitored = 'N'
	 WHERE	is_monitored = 'Y'
	 AND	device_id in (
	 		SELECT device_id
			 FROM	device
			 	INNER JOIN rack_location 
					USING (rack_location_id)
			WHERE	rack_id = 67
	);

	BEGIN
		PERFORM local_hooks.monitoring_off_in_rack_late(
			_in_rack_id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	RETURN true;
END;
$function$
;

-- DONE WITH proc device_utils.monitoring_off_in_rack -> monitoring_off_in_rack 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc device_utils.purge_l1_connection_from_port -> purge_l1_connection_from_port 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 408435
CREATE OR REPLACE FUNCTION device_utils.purge_l1_connection_from_port(_in_portid integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_r	RECORD;
BEGIN
	FOR _r IN 
		SELECT * FROM layer1_connection WHERE
			physical_port1_id = _in_portid or physical_port2_id = _in_portid
	LOOP
		PERFORM device_utils.purge_physical_path(
			_r.layer1_connection_id
		);
		DELETE from layer1_connection WHERE layer1_connection_id =
			_r.layer1_connection_id;
	END LOOP;
END;
$function$
;

-- DONE WITH proc device_utils.purge_l1_connection_from_port -> purge_l1_connection_from_port 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc device_utils.purge_physical_path -> purge_physical_path 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 408434
CREATE OR REPLACE FUNCTION device_utils.purge_physical_path(_in_l1c integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_r	RECORD;
BEGIN
	FOR _r IN 
	      SELECT  pc.physical_connection_id,
			pc.cable_type,
			p1.physical_port_id as pc_p1_physical_port_id,
			p1.port_name as pc_p1_physical_port_name,
			d1.device_id as pc_p1_device_id,
			d1.device_name as pc_p1_device_name,
			p2.physical_port_id as pc_p2_physical_port_id,
			p2.port_name as pc_p2_physical_port_name,
			d2.device_id as pc_p2_device_id,
			d2.device_name as pc_p2_device_name
		  FROM  v_physical_connection vpc
			INNER JOIN physical_connection pc
				USING (physical_connection_id)
			INNER JOIN physical_port p1
				ON p1.physical_port_id = pc.physical_port1_id
			INNER JOIN device d1
				ON d1.device_id = p1.device_id
			INNER JOIN physical_port p2
				ON p2.physical_port_id = pc.physical_port2_id
			INNER JOIN device d2
				ON d2.device_id = p2.device_id
		WHERE   vpc.layer1_connection_id = _in_l1c
		ORDER BY level
	LOOP
		DELETE from physical_connecion where physical_connection_id =
			_r.physical_connection_id;
	END LOOP;
END;
$function$
;

-- DONE WITH proc device_utils.purge_physical_path -> purge_physical_path 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc device_utils.purge_physical_ports -> purge_physical_ports 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 408436
CREATE OR REPLACE FUNCTION device_utils.purge_physical_ports(_in_devid integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_r	RECORD;
BEGIN
	FOR _r IN 
		SELECT * FROM physical_port WHERE device_id = _in_devid
	LOOP
		PERFORM device_utils.purge_l1_connection_from_port(
			_r.physical_port_id
		);
		DELETE from physical_port WHERE physical_port_id =
			_r.physical_port_id;
	END LOOP;
END;
$function$
;

-- DONE WITH proc device_utils.purge_physical_ports -> purge_physical_ports 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc device_utils.purge_power_ports -> purge_power_ports 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 408437
CREATE OR REPLACE FUNCTION device_utils.purge_power_ports(_in_devid integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_r	RECORD;
BEGIN
	DELETE FROM device_power_connection
	 WHERE  ( device_id = _in_devid AND
				power_interface_port IN
				(SELECT power_interface_port
				   FROM device_power_interface
				  WHERE device_id = _in_devid
				)
			)
	 OR	     ( rpc_device_id = _in_devid AND
			rpc_power_interface_port IN
				(SELECT power_interface_port
				   FROM device_power_interface
				  WHERE device_id = _in_devid
				)
			);

	DELETE FROM device_power_interface
	 WHERE  device_id = _in_devid;
END;
$function$
;

-- DONE WITH proc device_utils.purge_power_ports -> purge_power_ports 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc device_utils.retire_device -> retire_device 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 408438
CREATE OR REPLACE FUNCTION device_utils.retire_device(in_device_id integer, retire_modules boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally		INTEGER;
	_r			RECORD;
	_d			DEVICE%ROWTYPE;
	_mgrid		DEVICE.DEVICE_ID%TYPE;
	_purgedev	boolean;
BEGIN
	_purgedev := false;

	BEGIN
		PERFORM local_hooks.device_retire_early(in_Device_Id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	SELECT * INTO _d FROM device WHERE device_id = in_Device_id;
	delete from dns_record where netblock_id in (
		select netblock_id 
		from network_interface where device_id = in_Device_id
	);

	delete from network_interface_purpose where device_id = in_Device_id;
	delete from network_interface where device_id = in_Device_id;

	PERFORM device_utils.purge_physical_ports( in_Device_id);
	PERFORM device_utils.purge_power_ports( in_Device_id);

	delete from property where device_collection_id in (
		SELECT	dc.device_collection_id 
		  FROM	device_collection dc
				INNER JOIN device_collection_device dcd
		 			USING (device_collection_id)
		WHERE	dc.device_collection_type = 'per-device'
		  AND	dcd.device_id = in_Device_id
	);

	delete from device_collection_device where device_id = in_Device_id;
	delete from snmp_commstr where device_id = in_Device_id;

		
	IF _d.rack_location_id IS NOT NULL  THEN
		UPDATE device SET rack_location_id = NULL 
		WHERE device_id = in_Device_id;

		-- This should not be permitted based on constraints, but in case
		-- that constraint had to be disabled...
		SELECT	count(*)
		  INTO	tally
		  FROM	device
		 WHERE	rack_location_id = _d.RACK_LOCATION_ID;

		IF tally = 0 THEN
			DELETE FROM rack_location 
			WHERE rack_location_id = _d.RACK_LOCATION_ID;
		END IF;
	END IF;

	IF _d.chassis_location_id IS NOT NULL THEN
		RAISE EXCEPTION 'Retiring modules is not supported yet.';
	END IF;

	SELECT	manager_device_id
	INTO	_mgrid
	 FROM	device_management_controller
	WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc'
	LIMIT 1;

	IF _mgrid IS NOT NULL THEN
		DELETE FROM device_management_controller
		WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc'
			AND manager_device_id = _mgrid;

		PERFORM device_utils.retire_device( manager_device_id)
		  FROM	device_management_controller
		WHERE	device_id = in_Device_id AND device_mgmt_control_type = 'bmc';
	END IF;

	BEGIN
		PERFORM local_hooks.device_retire_late(in_Device_Id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	SELECT count(*)
	INTO tally
	FROM device_note
	WHERE device_id = in_Device_id;

	--
	-- If there is no notes or serial number its save to remove
	-- 
	IF tally = 0 AND _d.SERIAL_NUMBER is NULL THEN
		_purgedev := true;
	END IF;

	IF _purgedev THEN
		--
		-- If there is an fk violation, we just preserve the record but
		-- delete all the identifying characteristics
		--
		BEGIN
			DELETE FROM device where device_id = in_Device_Id;
			return false;
		EXCEPTION WHEN foreign_key_violation THEN
			PERFORM 1;
		END;
	END IF;

	UPDATE device SET 
		device_name =NULL,
		service_environment = 'unallocated',
		device_status = 'removed',
		voe_symbolic_track_id = NULL,
		is_monitored = 'N',
		should_fetch_config = 'N',
		description = NULL
	WHERE device_id = in_Device_id;

	return true;
END;
$function$
;

-- DONE WITH proc device_utils.retire_device -> retire_device 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc device_utils.retire_rack -> retire_rack 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 408440
CREATE OR REPLACE FUNCTION device_utils.retire_rack(_in_rack_id integer)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_r	RECORD;
BEGIN

	BEGIN
		PERFORM local_hooks.rack_retire_early(_in_rack_id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	FOR _r IN SELECT device_id
			FROM device 
				INNER JOIN rack_location using (rack_location_id)
				INNER JOIN rack using (rack_id)
			WHERE rack_id = _in_rack_id
	LOOP
		PERFORM device_utils.retire_device( _r.device_id, true );
	END LOOP;

	BEGIN
		PERFORM local_hooks.racK_retire_late(_in_rack_id, false);
	EXCEPTION WHEN invalid_schema_name OR undefined_function THEN
		PERFORM 1;
	END;

	BEGIN
		DELETE FROM RACK where rack_id = _in_rack_id;
		RETURN false;
	EXCEPTION WHEN foreign_key_violation THEN
		UPDATE rack SET
			room = NULL,
			sub_room = NULL,
			rack_row = NULL,
			rack_name = 'none',
			description = 'retired'
		WHERE	rack_id = _in_rack_id;
	END;
	RETURN true;
END;
$function$
;

-- DONE WITH proc device_utils.retire_rack -> retire_rack 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc del_v_corp_family_account -> del_v_corp_family_account 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 408608
CREATE OR REPLACE FUNCTION jazzhands.del_v_corp_family_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	acct_realm_id	account_realm.account_realm_id%TYPE;
BEGIN
	SELECT	account_realm_id
	INTO	acct_realm_id
	FROM	property
	WHERE	property_name = '_root_account_realm_id'
	AND	property_type = 'Defaults';

	IF acct_realm_id != OLD.account_realm_id THEN
		RAISE EXCEPTION 'Invalid account_realm_id'
		USING ERRCODE = 'foreign_key_violation';
	END IF;

	DELETE FROM account where account_id = OLD.account_id;
END;
$function$
;

-- DONE WITH proc del_v_corp_family_account -> del_v_corp_family_account 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc dns_record_cname_checker -> dns_record_cname_checker 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 408537
CREATE OR REPLACE FUNCTION jazzhands.dns_record_cname_checker()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
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
				 			NEW.dns_name IS NULL and x.DNS_NAME is NULL
							or
							NEW.dns_name = x.DNS_NAME
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
				 			NEW.dns_name IS NULL and x.DNS_NAME is NULL
							or
							NEW.dns_name = x.DNS_NAME
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
				 			NEW.dns_name IS NULL and x.DNS_NAME is NULL
							or
							NEW.dns_name = x.DNS_NAME
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
				 			NEW.dns_name IS NULL and x.DNS_NAME is NULL
							or
							NEW.dns_name = x.DNS_NAME
						)
				;
			END IF;
		END IF;
	END IF;

	IF _tally > 0 THEN
		SELECT soa_name INTO _dom FROM dns_domain
		WHERE dns_domain_id = NEW.dns_domain_id ;

		if NEW.DNS_NAME IS NULL THEN
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

-- DONE WITH proc dns_record_cname_checker -> dns_record_cname_checker 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc ins_v_corp_family_account -> ins_v_corp_family_account 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 408606
CREATE OR REPLACE FUNCTION jazzhands.ins_v_corp_family_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	acct_realm_id	account_realm.account_realm_id%TYPE;
BEGIN
	SELECT	account_realm_id
	INTO	acct_realm_id
	FROM	property
	WHERE	property_name = '_root_account_realm_id'
	AND	property_type = 'Defaults';

	IF acct_realm_id != NEW.account_realm_id THEN
		RAISE EXCEPTION 'Invalid account_realm_id'
		USING ERRCODE = 'foreign_key_violation';
	END IF;

	INSERT INTO account VALUES (NEW.*);

END;
$function$
;

-- DONE WITH proc ins_v_corp_family_account -> ins_v_corp_family_account 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc net_int_nb_single_address -> net_int_nb_single_address 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 408543
CREATE OR REPLACE FUNCTION jazzhands.net_int_nb_single_address()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	IF NEW.netblock_id IS NOT NULL THEN
		select count(*)
		INTO _tally
		FROM netblock
		WHERE netblock_id = NEW.netblock_id
		AND is_single_address = 'Y'
		AND netblock_type = 'default';

		IF _tally = 0 THEN
			RAISE EXCEPTION 'network interfaces must refer to single ip addresses of type default (%,%)', NEW.network_interface_id, NEW.netblock_id
				USING errcode = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- DONE WITH proc net_int_nb_single_address -> net_int_nb_single_address 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc net_int_netblock_to_nbn_compat_after -> net_int_netblock_to_nbn_compat_after 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 408547
CREATE OR REPLACE FUNCTION net_int_netblock_to_nbn_compat_after() 
RETURNS TRIGGER AS $$
DECLARE
	_tally	INTEGER;
BEGIN
	SELECT  count(*)
	  INTO  _tally
	  FROM  pg_catalog.pg_class
	 WHERE  relname = '__network_interface_netblocks'
	   AND  relpersistence = 't';

	IF _tally = 0 THEN
		CREATE TEMPORARY TABLE IF NOT EXISTS __network_interface_netblocks (
			network_interface_id INTEGER, netblock_id INTEGER
		);
	END IF;
	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
		SELECT count(*) INTO _tally FROM __network_interface_netblocks
		WHERE network_interface_id = NEW.network_interface_id
		AND netblock_id IS NOT DISTINCT FROM ( NEW.netblock_id );
		if _tally >  0 THEN
			RETURN NEW;
		END IF;
		INSERT INTO __network_interface_netblocks
			(network_interface_id, netblock_id)
		VALUES (NEW.network_interface_id,NEW.netblock_id);
	ELSIF TG_OP = 'DELETE' THEN
		SELECT count(*) INTO _tally FROM __network_interface_netblocks
		WHERE network_interface_id = OLD.network_interface_id
		AND netblock_id IS NOT DISTINCT FROM ( OLD.netblock_id );
		if _tally >  0 THEN
			RETURN OLD;
		END IF;
		INSERT INTO __network_interface_netblocks
			(network_interface_id, netblock_id)
		VALUES (OLD.network_interface_id,OLD.netblock_id);
	END IF;

	IF TG_OP = 'INSERT' THEN
		IF NEW.netblock_id IS NOT NULL THEN
			SELECT COUNT(*)
			INTO _tally
			FROM	network_interface_netblock
			WHERE	network_interface_id = NEW.network_interface_id
			AND		netblock_id = NEW.netblock_id;

			IF _tally = 0 THEN
				SELECT COUNT(*)
				INTO _tally
				FROM	network_interface_netblock
				WHERE	network_interface_id != NEW.network_interface_id
				AND		netblock_id = NEW.netblock_id;

				IF _tally != 0  THEN
					UPDATE network_interface_netblock
					SET network_interface_id = NEW.network_interface_id
					WHERE netblock_id = NEW.netblock_id;
				ELSE
					INSERT INTO network_interface_netblock
						(network_interface_id, netblock_id)
					VALUES
						(NEW.network_interface_id, NEW.netblock_id);
				END IF;
			END IF;
		END IF;
	ELSIF TG_OP = 'UPDATE'  THEN
		IF OLD.netblock_id is NULL and NEW.netblock_ID is NOT NULL THEN
			SELECT COUNT(*)
			INTO _tally
			FROM	network_interface_netblock
			WHERE	network_interface_id = NEW.network_interface_id
			AND		netblock_id = NEW.netblock_id;

			IF _tally = 0 THEN
				INSERT INTO network_interface_netblock
					(network_interface_id, netblock_id)
				VALUES
					(NEW.network_interface_id, NEW.netblock_id);
			END IF;
		ELSIF OLD.netblock_id IS NOT NULL and NEW.netblock_id is NOT NULL THEN
			IF OLD.netblock_id != NEW.netblock_id THEN
				UPDATE network_interface_netblock
					SET network_interface_id = NEW.network_interface_Id,
						netblock_id = NEW.netblock_id
						WHERE network_interface_id = OLD.network_interface_id
						AND netblock_id = OLD.netblock_id
						AND netblock_id != NEW.netblock_id
				;
			END IF;
		END IF;
		SET CONSTRAINTS FK_NETINT_NB_NETINT_ID IMMEDIATE;
		SET CONSTRAINTS FK_NETINT_NB_NBLK_ID IMMEDIATE;
	ELSIF TG_OP = 'DELETE' THEN
		IF OLD.netblock_id IS NOT NULL THEN
			DELETE from network_interface_netblock
				WHERE network_interface_id = OLD.network_interface_id
				AND netblock_id = OLD.netblock_id;
		END IF;
		SET CONSTRAINTS FK_NETINT_NB_NETINT_ID IMMEDIATE;
		SET CONSTRAINTS FK_NETINT_NB_NBLK_ID IMMEDIATE;
		RETURN OLD;
	END IF;
	RETURN NEW;
END;
$$ 
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

-- DONE WITH proc net_int_netblock_to_nbn_compat_after -> net_int_netblock_to_nbn_compat_after 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc net_int_netblock_to_nbn_compat_before -> net_int_netblock_to_nbn_compat_before 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 408545
CREATE OR REPLACE FUNCTION jazzhands.net_int_netblock_to_nbn_compat_before()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	SET CONSTRAINTS FK_NETINT_NB_NETINT_ID DEFERRED;
	SET CONSTRAINTS FK_NETINT_NB_NBLK_ID DEFERRED;
	RETURN OLD;
END;
$function$
;

-- DONE WITH proc net_int_netblock_to_nbn_compat_before -> net_int_netblock_to_nbn_compat_before 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc netblock_collection_hier_enforce -> netblock_collection_hier_enforce 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'netblock_collection_hier_enforce', 'netblock_collection_hier_enforce');

DROP TRIGGER IF EXISTS trigger_netblock_collection_hier_enforce
	 ON netblock_collection_hier;

-- DROP OLD FUNCTION
-- consider old oid 396926
DROP FUNCTION IF EXISTS netblock_collection_hier_enforce();

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 396926
DROP FUNCTION IF EXISTS netblock_collection_hier_enforce();
-- consider NEW oid 408588
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
		RAISE EXCEPTION 'Device Collections of type % may not be hierarcical',
			nct.netblock_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$function$
;

-- DONE WITH proc netblock_collection_hier_enforce -> netblock_collection_hier_enforce 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc netblock_complain_on_mismatch -> netblock_complain_on_mismatch 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'netblock_complain_on_mismatch', 'netblock_complain_on_mismatch');

-- DROP OLD FUNCTION
-- consider old oid 396866
DROP FUNCTION IF EXISTS netblock_complain_on_mismatch();

-- DONE WITH proc netblock_complain_on_mismatch -> netblock_complain_on_mismatch 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc netblock_single_address_ni -> netblock_single_address_ni 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'netblock_single_address_ni', 'netblock_single_address_ni');

DROP TRIGGER IF EXISTS trigger_netblock_single_address_ni ON netblock;


-- DROP OLD FUNCTION
-- consider old oid 400274
DROP FUNCTION IF EXISTS netblock_single_address_ni();

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 400274
DROP FUNCTION IF EXISTS netblock_single_address_ni();
-- consider NEW oid 408509
CREATE OR REPLACE FUNCTION jazzhands.netblock_single_address_ni()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	_tally	INTEGER;
BEGIN
	IF (NEW.is_single_address = 'N' AND OLD.is_single_address = 'Y') OR
		(NEW.netblock_type != 'default' AND OLD.netblock_type = 'default')
			THEN
		select count(*)
		INTO _tally
		FROM network_interface
		WHERE netblock_id = NEW.netblock_id;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'network interfaces must refer to single ip addresses of type default address (%,%)', NEW.ip_address, NEW.netblock_id
				USING errcode = 'foreign_key_violation';
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

CREATE CONSTRAINT TRIGGER trigger_netblock_collection_hier_enforce
	AFTER INSERT OR UPDATE
	ON netblock_collection_hier
		DEFERRABLE INITIALLY IMMEDIATE
	FOR EACH ROW
	EXECUTE PROCEDURE netblock_collection_hier_enforce();

-- DONE WITH proc netblock_single_address_ni -> netblock_single_address_ni 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc retire_netblock_columns -> retire_netblock_columns 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'retire_netblock_columns', 'retire_netblock_columns');

-- DROP OLD FUNCTION
-- consider old oid 396864
DROP FUNCTION IF EXISTS retire_netblock_columns();

-- DONE WITH proc retire_netblock_columns -> retire_netblock_columns 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc upd_v_corp_family_account -> upd_v_corp_family_account 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 408610
CREATE OR REPLACE FUNCTION jazzhands.upd_v_corp_family_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	acct_realm_id	account_realm.account_realm_id%TYPE;
	setstr		TEXT;
	_r		RECORD;
	val		TEXT;
BEGIN
	SELECT	account_realm_id
	INTO	acct_realm_id
	FROM	property
	WHERE	property_name = '_root_account_realm_id'
	AND	property_type = 'Defaults';

	IF acct_realm_id != OLD.account_realm_id OR
			acct_realm_id != NEW.account_realm_id THEN
		RAISE EXCEPTION 'Invalid account_realm_id'
		USING ERRCODE = 'foreign_key_violation';
	END IF;

	setstr = '';
	FOR _r IN SELECT * FROM json_each_text( row_to_json(NEW) )
	LOOP
		IF _r.key NOT SIMILAR TO 'data_(ins|upd)_(user|date)' THEN
			EXECUTE 'SELECT ' || _r.key ||' FROM account
				WHERE account_id = ' || OLD.account_id
				INTO val;
			IF ( _r.value IS NULL  AND val IS NOT NULL) OR
				( _r.value IS NOT NULL AND val IS NULL) OR
				(_r.value::text NOT SIMILAR TO val::text) THEN
				-- RAISE NOTICE 'Changing %: "%" to "%"', _r.key, val, _r.value;
				IF char_length(setstr) > 0 THEN
					setstr = setstr || ',
					';
				END IF;
				IF _r.value IS NOT  NULL THEN
					setstr = setstr || _r.key || ' = ' ||  
						quote_nullable(_r.value) || ' ' ;
				ELSE
					setstr = setstr || _r.key || ' = ' ||  
						' NULL ' ;
				END IF;
			END IF;
		END IF;
	END LOOP;


	IF char_length(setstr) > 0 THEN
		setstr = 'UPDATE account SET ' || setstr || '
			WHERE	account_id = ' || OLD.account_id;
		-- RAISE NOTICE 'executing %', setstr;
		EXECUTE setstr;
	END IF;
	RETURN NEW;

END;
$function$
;

-- DONE WITH proc upd_v_corp_family_account -> upd_v_corp_family_account 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc netblock_utils.calculate_intermediate_netblocks -> calculate_intermediate_netblocks 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 408453
CREATE OR REPLACE FUNCTION netblock_utils.calculate_intermediate_netblocks(ip_block_1 inet DEFAULT NULL::inet, ip_block_2 inet DEFAULT NULL::inet)
 RETURNS TABLE(ip_addr inet)
 LANGUAGE plpgsql
AS $function$
DECLARE
	current_nb		inet;
	new_nb			inet;
	min_addr		inet;
	max_addr		inet;
BEGIN
	IF ip_block_1 IS NULL OR ip_block_2 IS NULL THEN
		RAISE EXCEPTION 'Must specify both ip_block_1 and ip_block_2';
	END IF;

	IF family(ip_block_1) != family(ip_block_2) THEN
		RAISE EXCEPTION 'families of ip_block_1 and ip_block_2 must match';
	END IF;

	-- Make sure these are network blocks
	ip_block_1 := network(ip_block_1);
	ip_block_2 := network(ip_block_2);

	-- If the blocks are subsets of each other, then error

	IF ip_block_1 <<= ip_block_2 OR ip_block_2 <<= ip_block_1 THEN
		RAISE EXCEPTION 'netblocks intersect each other';
	END IF;

	-- Order the blocks correctly

	IF ip_block_1 > ip_block_2 THEN
		new_nb := ip_block_1;
		ip_block_1 := ip_block_2;
		ip_block_2 := new_nb;
	END IF;

	current_nb := ip_block_1;
	max_addr := broadcast(ip_block_1);

	-- Loop through bumping the netmask up and seeing if the destination block is in the new block
	LOOP
		new_nb := network(set_masklen(current_nb, masklen(current_nb) - 1));

		-- If the block is in our new larger netblock, then exit this loop
		IF (new_nb >>= ip_block_2) THEN
			current_nb := broadcast(current_nb) + 1;
			EXIT;
		END IF;
	
		-- If the max address of the new netblock is larger than the last one, then it's empty
		IF set_masklen(broadcast(new_nb), 32) > set_masklen(max_addr, 32) THEN
			ip_addr := set_masklen(max_addr + 1, masklen(current_nb));
			RETURN NEXT;
			max_addr := broadcast(new_nb);
		END IF;
		current_nb := new_nb;
	END LOOP;

	-- Now loop through there to find the unused blocks at the front

	LOOP
		IF host(current_nb) = host(ip_block_2) THEN
			RETURN;
		END IF;
		current_nb := set_masklen(current_nb, masklen(current_nb) + 1);
		IF NOT (current_nb >>= ip_block_2) THEN
			ip_addr := current_nb;
			RETURN NEXT;
			current_nb := broadcast(current_nb) + 1;
			CONTINUE;
		END IF;
	END LOOP;
	RETURN;
END;
$function$
;

-- DONE WITH proc netblock_utils.calculate_intermediate_netblocks -> calculate_intermediate_netblocks 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc netblock_utils.delete_netblock -> delete_netblock 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('netblock_utils', 'delete_netblock', 'delete_netblock');

-- DROP OLD FUNCTION
-- consider old oid 396810
DROP FUNCTION IF EXISTS netblock_utils.delete_netblock(in_netblock_id integer);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 396810
DROP FUNCTION IF EXISTS netblock_utils.delete_netblock(in_netblock_id integer);
-- consider NEW oid 408445
CREATE OR REPLACE FUNCTION netblock_utils.delete_netblock(in_netblock_id integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	par_nbid	jazzhands.netblock.netblock_id%type;
BEGIN
	/*
	 * Update netblocks that use this as a parent to point to my parent
	 */
	SELECT
		netblock_id INTO par_nbid
	FROM
		jazzhands.netblock
	WHERE 
		netblock_id = in_netblock_id;
	
	UPDATE
		jazzhands.netblock
	SET
		parent_netblock_id = par_nbid
	WHERE
		parent_netblock_id = in_netblock_id;
	
	/*
	 * Now delete the record
	 */
	DELETE FROM jazzhands.netblock WHERE netblock_id = in_netblock_id;
END;
$function$
;

-- DONE WITH proc netblock_utils.delete_netblock -> delete_netblock 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc netblock_utils.find_free_netblocks -> find_free_netblocks 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_free_netblocks', 'find_free_netblocks');

-- DROP OLD FUNCTION
-- consider old oid 396814
DROP FUNCTION IF EXISTS netblock_utils.find_free_netblocks(parent_netblock_id integer, netmask_bits integer, single_address boolean, allocate_from_bottom boolean, max_addresses integer);
-- consider old oid 396815
DROP FUNCTION IF EXISTS netblock_utils.find_free_netblocks(parent_netblock_list integer[], netmask_bits integer, single_address boolean, allocate_from_bottom boolean, max_addresses integer);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 396814
DROP FUNCTION IF EXISTS netblock_utils.find_free_netblocks(parent_netblock_id integer, netmask_bits integer, single_address boolean, allocate_from_bottom boolean, max_addresses integer);
-- consider old oid 396815
DROP FUNCTION IF EXISTS netblock_utils.find_free_netblocks(parent_netblock_list integer[], netmask_bits integer, single_address boolean, allocate_from_bottom boolean, max_addresses integer);
-- consider NEW oid 408449
CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblocks(parent_netblock_id integer, netmask_bits integer DEFAULT NULL::integer, single_address boolean DEFAULT false, allocation_method text DEFAULT NULL::text, max_addresses integer DEFAULT 1024, desired_ip_address inet DEFAULT NULL::inet, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024)
 RETURNS TABLE(ip_address inet, netblock_type character varying, ip_universe_id integer)
 LANGUAGE plpgsql
AS $function$
BEGIN
	RETURN QUERY SELECT * FROM netblock_utils.find_free_netblocks(
		parent_netblock_list := ARRAY[parent_netblock_id],
		netmask_bits := netmask_bits,
		single_address := single_address,
		allocation_method := allocation_method,
		desired_ip_address := desired_ip_address,
		max_addresses := max_addresses);
END;
$function$
;
-- consider NEW oid 408450
CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblocks(parent_netblock_list integer[], netmask_bits integer DEFAULT NULL::integer, single_address boolean DEFAULT false, allocation_method text DEFAULT NULL::text, max_addresses integer DEFAULT 1024, desired_ip_address inet DEFAULT NULL::inet, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024)
 RETURNS TABLE(ip_address inet, netblock_type character varying, ip_universe_id integer)
 LANGUAGE plpgsql
AS $function$
DECLARE
	parent_nbid		jazzhands.netblock.netblock_id%TYPE;
	netblock_rec	jazzhands.netblock%ROWTYPE;
	inet_list		inet[];
	current_ip		inet;
	saved_method	text;
	min_ip			inet;
	max_ip			inet;
	matches			integer;
	rnd_matches		integer;
	max_rnd_value	bigint;
	rnd_value		bigint;
	family_bits		integer;
BEGIN
	matches := 0;
	saved_method = allocation_method;

	IF allocation_method IS NOT NULL AND allocation_method
			NOT IN ('top', 'bottom', 'random', 'default') THEN
		RAISE 'address_type must be one of top, bottom, random, or default'
		USING ERRCODE = 'invalid_parameter_value';
	END IF;

	--
	-- Sanitize masklen input.  This is a little complicated.
	--
	-- If a single address is desired, we always use a /32 or /128
	-- in the parent loop and everything else is ignored
	--
	-- Otherwise, if netmask_bits is passed, that wins, otherwise
	-- the netmask of whatever is passed with desired_ip_address wins
	--
	-- If none of these are the case, then things are wrong and we
	-- bail
	--

	IF NOT single_address THEN 
		IF desired_ip_address IS NOT NULL AND netmask_bits IS NULL THEN
			netmask_bits := masklen(desired_ip_address);
		ELSIF desired_ip_address IS NOT NULL AND 
				netmask_bits IS NOT NULL THEN
			desired_ip_address := set_masklen(desired_ip_address,
				netmask_bits);
		END IF;
		IF netmask_bits IS NULL THEN
			RAISE EXCEPTION 'netmask_bits must be set'
			USING ERRCODE = 'invalid_parameter_value';
		END IF;
		IF allocation_method = 'random' THEN
			RAISE EXCEPTION 'random netblocks may only be returned for single addresses'
			USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	FOREACH parent_nbid IN ARRAY parent_netblock_list LOOP
		rnd_matches := 0;
		--
		-- Restore this, because we may have overrridden it for a previous
		-- block
		--
		allocation_method = saved_method;
		SELECT 
			* INTO netblock_rec
		FROM
			jazzhands.netblock n
		WHERE
			n.netblock_id = parent_nbid;

		IF NOT FOUND THEN
			RAISE EXCEPTION 'Netblock % does not exist', parent_nbid;
		END IF;

		family_bits := 
			(CASE family(netblock_rec.ip_address) WHEN 4 THEN 32 ELSE 128 END);

		-- If desired_ip_address is passed, then allocation_method is
		-- irrelevant

		IF desired_ip_address IS NOT NULL THEN
			--
			-- If the IP address is not the same family as the parent block,
			-- we aren't going to find it
			--
			IF family(desired_ip_address) != 
					family(netblock_rec.ip_address) THEN
				CONTINUE;
			END IF;
			allocation_method := 'bottom';
		END IF;

		--
		-- If allocation_method is 'default' or NULL, then use 'bottom'
		-- unless it's for a single IPv6 address in a netblock larger than 
		-- rnd_masklen_threshold
		--
		IF allocation_method IS NULL OR allocation_method = 'default' THEN
			allocation_method := 
				CASE WHEN 
					single_address AND 
					family(netblock_rec.ip_address) = 6 AND
					masklen(netblock_rec.ip_address) <= rnd_masklen_threshold
				THEN
					'random'
				ELSE
					'bottom'
				END;
		END IF;

		IF allocation_method = 'random' AND 
				family_bits - masklen(netblock_rec.ip_address) < 2 THEN
			-- Random allocation doesn't work if we don't have enough
			-- bits to play with, so just do sequential.
			allocation_method := 'bottom';
		END IF;

		IF single_address THEN 
			netmask_bits := family_bits;
			IF desired_ip_address IS NOT NULL THEN
				desired_ip_address := set_masklen(desired_ip_address,
					masklen(netblock_rec.ip_address));
			END IF;
		ELSIF netmask_bits <= masklen(netblock_rec.ip_address) THEN
			-- If the netmask is not for a smaller netblock than this parent,
			-- then bounce to the next one, because maybe it's larger
			RAISE DEBUG
				'netblock (%) is not larger than netmask_bits of % - skipping',
				masklen(netblock_rec.ip_address),
				netmask_bits;
			CONTINUE;
		END IF;

		IF netmask_bits > family_bits THEN
			RAISE EXCEPTION 'netmask_bits must be no more than % for netblock %',
				family_bits,
				netblock_rec.ip_address;
		END IF;

		--
		-- Short circuit the check if we're looking for a specific address
		-- and it's not in this netblock
		--

		IF desired_ip_address IS NOT NULL AND
				NOT (desired_ip_address <<= netblock_rec.ip_address) THEN
			RAISE DEBUG 'desired_ip_address % is not in netblock %',
				desired_ip_address,
				netblock_rec.ip_address;
			CONTINUE;
		END IF;

		IF single_address AND netblock_rec.can_subnet = 'Y' THEN
			RAISE EXCEPTION 'single addresses may not be assigned to to a block where can_subnet is Y';
		END IF;

		IF (NOT single_address) AND netblock_rec.can_subnet = 'N' THEN
			RAISE EXCEPTION 'Netblock % (%) may not be subnetted',
				netblock_rec.ip_address,
				netblock_rec.netblock_id;
		END IF;

		RAISE DEBUG 'Searching netblock % (%) using the % allocation method',
			netblock_rec.netblock_id,
			netblock_rec.ip_address,
			allocation_method;

		IF desired_ip_address IS NOT NULL THEN
			min_ip := desired_ip_address;
			max_ip := desired_ip_address + 1;
		ELSE
			min_ip := netblock_rec.ip_address;
			max_ip := broadcast(min_ip) + 1;
		END IF;

		IF allocation_method = 'top' THEN
			current_ip := network(set_masklen(max_ip - 1, netmask_bits));
		ELSIF allocation_method = 'random' THEN
			max_rnd_value := (x'7fffffffffffffff'::bigint >> CASE 
				WHEN family_bits - masklen(netblock_rec.ip_address) >= 63
				THEN 0
				ELSE 63 - (family_bits - masklen(netblock_rec.ip_address))
				END) - 2;
			-- random() appears to only do 32-bits, which is dumb
			-- I'm pretty sure that all of the casts are not required here,
			-- but better to make sure
			current_ip := min_ip + 
					((((random() * x'7fffffff'::bigint)::bigint << 32) + 
					(random() * x'ffffffff'::bigint)::bigint + 1)
					% max_rnd_value) + 1;
		ELSE -- it's 'bottom'
			current_ip := set_masklen(min_ip, netmask_bits);
		END IF;

		-- For single addresses, make the netmask match the netblock of the
		-- containing block, and skip the network and broadcast addresses
		-- We shouldn't need to skip for IPv6 addresses, but some things
		-- apparently suck

		IF single_address THEN
			current_ip := set_masklen(current_ip, 
				masklen(netblock_rec.ip_address));
			--
			-- If we're not allocating a single /31 or /32 for IPv4 or
			-- /127 or /128 for IPv6, then we want to skip the all-zeros
			-- and all-ones addresses
			--
			IF masklen(netblock_rec.ip_address) < (family_bits - 1) AND
					desired_ip_address IS NULL THEN
				current_ip := current_ip + 
					CASE WHEN allocation_method = 'top' THEN -1 ELSE 1 END;
				min_ip := min_ip + 1;
				max_ip := max_ip - 1;
			END IF;
		END IF;

		RAISE DEBUG 'Starting with IP address % with step masklen of %',
			current_ip,
			netmask_bits;

		WHILE (
				current_ip >= min_ip AND
				current_ip < max_ip AND
				matches < max_addresses AND
				rnd_matches < rnd_max_count
		) LOOP
			RAISE DEBUG '   Checking netblock %', current_ip;

			PERFORM * FROM jazzhands.netblock n WHERE
				n.ip_universe_id = netblock_rec.ip_universe_id AND
				n.netblock_type = netblock_rec.netblock_type AND
				-- A block with the parent either contains or is contained
				-- by this block
				n.parent_netblock_id = netblock_rec.netblock_id AND
				CASE WHEN single_address THEN
					n.ip_address = current_ip
				ELSE
					(n.ip_address >>= current_ip OR current_ip >>= n.ip_address)
				END;
			IF NOT FOUND AND (inet_list IS NULL OR
					NOT (current_ip = ANY(inet_list))) THEN
				find_free_netblocks.netblock_type :=
					netblock_rec.netblock_type;
				find_free_netblocks.ip_universe_id :=
					netblock_rec.ip_universe_id;
				find_free_netblocks.ip_address := current_ip;
				RETURN NEXT;
				inet_list := array_append(inet_list, current_ip);
				matches := matches + 1;
				-- Reset random counter if we found something
				rnd_matches := 0;
			ELSIF allocation_method = 'random' THEN
				-- Increase random counter if we didn't find something
				rnd_matches := rnd_matches + 1;
			END IF;

			-- Select the next IP address
			current_ip := 
				CASE WHEN single_address THEN
					CASE 
						WHEN allocation_method = 'bottom' THEN current_ip + 1
						WHEN allocation_method = 'top' THEN current_ip - 1
						ELSE min_ip + ((
							((random() * x'7fffffff'::bigint)::bigint << 32) 
							+ 
							(random() * x'ffffffff'::bigint)::bigint + 1
							) % max_rnd_value) + 1 
					END
				ELSE
					CASE WHEN allocation_method = 'bottom' THEN 
						network(broadcast(current_ip) + 1)
					ELSE 
						network(current_ip - 1)
					END
				END;
		END LOOP;
	END LOOP;
	RETURN;
END;
$function$
;

-- DONE WITH proc netblock_utils.find_free_netblocks -> find_free_netblocks 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc netblock_utils.find_rvs_zone_from_netblock_id -> find_rvs_zone_from_netblock_id 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_rvs_zone_from_netblock_id', 'find_rvs_zone_from_netblock_id');

-- DROP OLD FUNCTION
-- consider old oid 396812
DROP FUNCTION IF EXISTS netblock_utils.find_rvs_zone_from_netblock_id(in_netblock_id integer);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 396812
DROP FUNCTION IF EXISTS netblock_utils.find_rvs_zone_from_netblock_id(in_netblock_id integer);
-- consider NEW oid 408447
CREATE OR REPLACE FUNCTION netblock_utils.find_rvs_zone_from_netblock_id(in_netblock_id integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
	v_rv	jazzhands.dns_domain.dns_domain_id%type;
	v_domid	jazzhands.dns_domain.dns_domain_id%type;
	v_lhsip	jazzhands.netblock.ip_address%type;
	v_rhsip	jazzhands.netblock.ip_address%type;
	nb_match CURSOR ( in_nb_id jazzhands.netblock.netblock_id%type) FOR
		select  rootd.dns_domain_id,
				 network(set_masklen(nb.ip_address, masklen(root.ip_address))),
				 network(root.ip_address)
		  from  jazzhands.netblock nb,
			jazzhands.netblock root
				inner join jazzhands.dns_record rootd
					on rootd.netblock_id = root.netblock_id
					and rootd.dns_type = 'REVERSE_ZONE_BLOCK_PTR'
		 where
		  	nb.netblock_id = in_nb_id;
BEGIN
	v_rv := NULL;
	OPEN nb_match(in_netblock_id);
	LOOP
		FETCH  nb_match INTO v_domid, v_lhsip, v_rhsip;
		if NOT FOUND THEN
			EXIT;
		END IF;

		if v_lhsip = v_rhsip THEN
			v_rv := v_domid;
			EXIT;
		END IF;
	END LOOP;
	CLOSE nb_match;
	return v_rv;
END;
$function$
;

-- DONE WITH proc netblock_utils.find_rvs_zone_from_netblock_id -> find_rvs_zone_from_netblock_id 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc netblock_utils.list_unallocated_netblocks -> list_unallocated_netblocks 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 408452
CREATE OR REPLACE FUNCTION netblock_utils.list_unallocated_netblocks(netblock_id integer DEFAULT NULL::integer, ip_address inet DEFAULT NULL::inet, ip_universe_id integer DEFAULT 0, netblock_type text DEFAULT 'default'::text)
 RETURNS TABLE(ip_addr inet)
 LANGUAGE plpgsql
AS $function$
DECLARE
	ip_array		inet[];
	netblock_rec	RECORD;
	parent_nbid		jazzhands.netblock.netblock_id%TYPE;
	family_bits		integer;
	idx				integer;
BEGIN
	IF netblock_id IS NOT NULL THEN
		SELECT * INTO netblock_rec FROM jazzhands.netblock n WHERE n.netblock_id = 
			list_unallocated_netblocks.netblock_id;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'netblock_id % not found', netblock_id;
		END IF;
		IF netblock_rec.is_single_address = 'Y' THEN
			RETURN;
		END IF;
		ip_address := netblock_rec.ip_address;
		ip_universe_id := netblock_rec.ip_universe_id;
		netblock_type := netblock_rec.netblock_type;
	ELSIF ip_address IS NULL THEN
		RAISE EXCEPTION 'netblock_id or ip_address must be passed';
	END IF;
	SELECT ARRAY(
		SELECT 
			n.ip_address
		FROM
			netblock n
		WHERE
			n.ip_address <<= list_unallocated_netblocks.ip_address AND
			n.ip_universe_id = list_unallocated_netblocks.ip_universe_id AND
			n.netblock_type = list_unallocated_netblocks.netblock_type AND
			is_single_address = 'N' AND
			can_subnet = 'N'
		ORDER BY
			n.ip_address
	) INTO ip_array;

	IF array_length(ip_array, 1) IS NULL THEN
		ip_addr := ip_address;
		RETURN NEXT;
		RETURN;
	END IF;

	ip_array := array_prepend(
		list_unallocated_netblocks.ip_address - 1, 
		array_append(
			ip_array, 
			broadcast(list_unallocated_netblocks.ip_address) + 1
			));

	idx := 1;
	WHILE idx < array_length(ip_array, 1) LOOP
		RETURN QUERY SELECT cin.ip_addr FROM
			netblock_utils.calculate_intermediate_netblocks(ip_array[idx], ip_array[idx + 1]) cin;
		idx := idx + 1;
	END LOOP;

	RETURN;
END;
$function$
;

-- DONE WITH proc netblock_utils.list_unallocated_netblocks -> list_unallocated_netblocks 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc netblock_utils.list_unallocated_netblocks -> list_unallocated_netblocks 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 408452
CREATE OR REPLACE FUNCTION netblock_utils.list_unallocated_netblocks(netblock_id integer DEFAULT NULL::integer, ip_address inet DEFAULT NULL::inet, ip_universe_id integer DEFAULT 0, netblock_type text DEFAULT 'default'::text)
 RETURNS TABLE(ip_addr inet)
 LANGUAGE plpgsql
AS $function$
DECLARE
	ip_array		inet[];
	netblock_rec	RECORD;
	parent_nbid		jazzhands.netblock.netblock_id%TYPE;
	family_bits		integer;
	idx				integer;
BEGIN
	IF netblock_id IS NOT NULL THEN
		SELECT * INTO netblock_rec FROM jazzhands.netblock n WHERE n.netblock_id = 
			list_unallocated_netblocks.netblock_id;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'netblock_id % not found', netblock_id;
		END IF;
		IF netblock_rec.is_single_address = 'Y' THEN
			RETURN;
		END IF;
		ip_address := netblock_rec.ip_address;
		ip_universe_id := netblock_rec.ip_universe_id;
		netblock_type := netblock_rec.netblock_type;
	ELSIF ip_address IS NULL THEN
		RAISE EXCEPTION 'netblock_id or ip_address must be passed';
	END IF;
	SELECT ARRAY(
		SELECT 
			n.ip_address
		FROM
			netblock n
		WHERE
			n.ip_address <<= list_unallocated_netblocks.ip_address AND
			n.ip_universe_id = list_unallocated_netblocks.ip_universe_id AND
			n.netblock_type = list_unallocated_netblocks.netblock_type AND
			is_single_address = 'N' AND
			can_subnet = 'N'
		ORDER BY
			n.ip_address
	) INTO ip_array;

	IF array_length(ip_array, 1) IS NULL THEN
		ip_addr := ip_address;
		RETURN NEXT;
		RETURN;
	END IF;

	ip_array := array_prepend(
		list_unallocated_netblocks.ip_address - 1, 
		array_append(
			ip_array, 
			broadcast(list_unallocated_netblocks.ip_address) + 1
			));

	idx := 1;
	WHILE idx < array_length(ip_array, 1) LOOP
		RETURN QUERY SELECT cin.ip_addr FROM
			netblock_utils.calculate_intermediate_netblocks(ip_array[idx], ip_array[idx + 1]) cin;
		idx := idx + 1;
	END LOOP;

	RETURN;
END;
$function$
;

-- DONE WITH proc netblock_utils.list_unallocated_netblocks -> list_unallocated_netblocks 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc person_manip.add_account_non_person -> add_account_non_person 

-- DROP OLD FUNCTION
-- consider old oid 396774
DROP FUNCTION IF EXISTS person_manip.add_account_non_person(_company_id integer, _account_status character varying, _login character varying, _description character varying);

-- DONE WITH proc person_manip.add_account_non_person -> add_account_non_person 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc person_manip.add_person -> add_person 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('person_manip', 'add_person', 'add_person');

-- DROP OLD FUNCTION
-- consider old oid 396773
DROP FUNCTION IF EXISTS person_manip.add_person(__person_id integer, first_name character varying, middle_name character varying, last_name character varying, name_suffix character varying, gender character varying, preferred_last_name character varying, preferred_first_name character varying, birth_date date, _company_id integer, external_hr_id character varying, person_company_status character varying, is_manager character varying, is_exempt character varying, is_full_time character varying, employee_id integer, hire_date date, termination_date date, person_company_relation character varying, job_title character varying, department character varying, login character varying, OUT _person_id integer, OUT _account_collection_id integer, OUT _account_id integer);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 396773
DROP FUNCTION IF EXISTS person_manip.add_person(__person_id integer, first_name character varying, middle_name character varying, last_name character varying, name_suffix character varying, gender character varying, preferred_last_name character varying, preferred_first_name character varying, birth_date date, _company_id integer, external_hr_id character varying, person_company_status character varying, is_manager character varying, is_exempt character varying, is_full_time character varying, employee_id integer, hire_date date, termination_date date, person_company_relation character varying, job_title character varying, department character varying, login character varying, OUT _person_id integer, OUT _account_collection_id integer, OUT _account_id integer);
-- consider NEW oid 408400
CREATE OR REPLACE FUNCTION person_manip.add_person(__person_id integer, first_name character varying, middle_name character varying, last_name character varying, name_suffix character varying, gender character varying, preferred_last_name character varying, preferred_first_name character varying, birth_date date, _company_id integer, external_hr_id character varying, person_company_status character varying, is_manager character varying, is_exempt character varying, is_full_time character varying, employee_id character varying, hire_date date, termination_date date, person_company_relation character varying, job_title character varying, department character varying, login character varying, OUT _person_id integer, OUT _account_collection_id integer, OUT _account_id integer)
 RETURNS record
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_account_realm_id INTEGER;
BEGIN
	SELECT	
		xxx.person_id,
		xxx.dept_account_collection_id,
		xxx.account_id
	INTO
		_person_id,
		_account_collection_id,
		_account_id
	FROM	person_manip.add_user (
			person_id := __person_id,
			first_name := first_name,
			middle_name := middle_name,
			last_name := last_name,
			name_suffix := name_suffix,
			gender := gender,
			preferred_last_name := preferred_last_name,
			preferred_first_name := preferred_first_name,
			birth_date := birth_date,
			company_id := _company_id,
			external_hr_id := external_hr_id,
			person_company_status := person_company_status,
			is_manager := is_manager,
			is_exempt := is_exempt,
			is_full_time := is_full_time,
			employee_id := employee_id,
			hire_date := hire_date,
			termination_date := termination_date,
			person_company_relation := person_company_relation,
			job_title := job_title,
			department_name := department,
			login := login
		) xxx; 
END;
$function$
;

-- DONE WITH proc person_manip.add_person -> add_person 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc person_manip.add_user -> add_user 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('person_manip', 'add_user', 'add_user');

-- DROP OLD FUNCTION
-- consider old oid 396771
DROP FUNCTION IF EXISTS person_manip.add_user(company_id integer, person_company_relation character varying, login character varying, first_name character varying, middle_name character varying, last_name character varying, name_suffix character varying, gender character varying, preferred_last_name character varying, preferred_first_name character varying, birth_date date, external_hr_id character varying, person_company_status character varying, is_manager character varying, is_exempt character varying, is_full_time character varying, employee_id integer, hire_date date, termination_date date, job_title character varying, department_name character varying, description character varying, unix_uid character varying, INOUT person_id integer, OUT dept_account_collection_id integer, OUT account_id integer);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 396771
DROP FUNCTION IF EXISTS person_manip.add_user(company_id integer, person_company_relation character varying, login character varying, first_name character varying, middle_name character varying, last_name character varying, name_suffix character varying, gender character varying, preferred_last_name character varying, preferred_first_name character varying, birth_date date, external_hr_id character varying, person_company_status character varying, is_manager character varying, is_exempt character varying, is_full_time character varying, employee_id integer, hire_date date, termination_date date, job_title character varying, department_name character varying, description character varying, unix_uid character varying, INOUT person_id integer, OUT dept_account_collection_id integer, OUT account_id integer);
-- consider NEW oid 408398
CREATE OR REPLACE FUNCTION person_manip.add_user(company_id integer, person_company_relation character varying, login character varying DEFAULT NULL::character varying, first_name character varying DEFAULT NULL::character varying, middle_name character varying DEFAULT NULL::character varying, last_name character varying DEFAULT NULL::character varying, name_suffix character varying DEFAULT NULL::character varying, gender character varying DEFAULT NULL::character varying, preferred_last_name character varying DEFAULT NULL::character varying, preferred_first_name character varying DEFAULT NULL::character varying, birth_date date DEFAULT NULL::date, external_hr_id character varying DEFAULT NULL::character varying, person_company_status character varying DEFAULT 'enabled'::character varying, is_manager character varying DEFAULT 'N'::character varying, is_exempt character varying DEFAULT 'Y'::character varying, is_full_time character varying DEFAULT 'Y'::character varying, employee_id text DEFAULT NULL::text, hire_date date DEFAULT NULL::date, termination_date date DEFAULT NULL::date, job_title character varying DEFAULT NULL::character varying, department_name character varying DEFAULT NULL::character varying, description character varying DEFAULT NULL::character varying, unix_uid character varying DEFAULT NULL::character varying, INOUT person_id integer DEFAULT NULL::integer, OUT dept_account_collection_id integer, OUT account_id integer)
 RETURNS record
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	_account_realm_id INTEGER;
	_account_type VARCHAR;
	_uid INTEGER;
	_uxaccountid INTEGER;
	_companyid INTEGER;
	_personid INTEGER;
	_accountid INTEGER;
BEGIN
	IF company_id is NULL THEN
		RAISE EXCEPTION 'Must specify company id';
	END IF;
	_companyid := company_id;

	SELECT arc.account_realm_id 
	  INTO _account_realm_id 
	  FROM account_realm_company arc
	 WHERE arc.company_id = _companyid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Cannot find account_realm_id with company id %', company_id;
	END IF;

	IF login is NULL THEN
		IF first_name IS NULL or last_name IS NULL THEN 
			RAISE EXCEPTION 'Must specify login name or first name+last name';
		ELSE 
			login := person_manip.pick_login(
				in_account_realm_id	:= _account_realm_id,
				in_first_name := coalesce(preferred_first_name, first_name),
				in_middle_name := middle_name,
				in_last_name := coalesce(preferred_last_name, last_name)
			);
		END IF;
	END IF;

	IF person_company_relation = 'pseudouser' THEN
		person_id := 0;
		_account_type := 'pseudouser';
	ELSE
		_account_type := 'person';
		IF person_id IS NULL THEN
			INSERT INTO person (first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
				VALUES (first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
			RETURNING person.person_id into _personid;
			person_id = _personid;
		ELSE
			INSERT INTO person (person_id, first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date)
				VALUES (person_id, first_name, middle_name, last_name, name_suffix, gender, preferred_first_name, preferred_last_name, birth_date);
		END IF;
		INSERT INTO person_company
			(person_id,company_id,external_hr_id,person_company_status,is_management, is_exempt, is_full_time, employee_id,hire_date,termination_date,person_company_relation, position_title)
			VALUES
			(person_id, company_id, external_hr_id, person_company_status, is_manager, is_exempt, is_full_time, employee_id, hire_date, termination_date, person_company_relation, job_title);
		INSERT INTO person_account_realm_company ( person_id, company_id, account_realm_id) VALUES ( person_id, company_id, _account_realm_id);
	END IF;

	INSERT INTO account ( login, person_id, company_id, account_realm_id, account_status, description, account_role, account_type)
		VALUES (login, person_id, company_id, _account_realm_id, person_company_status, description, 'primary', _account_type)
	RETURNING account.account_id INTO account_id;

	IF department_name IS NOT NULL THEN
		dept_account_collection_id = person_manip.get_account_collection_id(department_name, 'department');
		INSERT INTO account_collection_account (account_collection_id, account_id) VALUES ( dept_account_collection_id, account_id);
	END IF;

	IF unix_uid IS NOT NULL THEN
		_accountid = account_id;
		SELECT	aui.account_id
		  INTO	_uxaccountid
		  FROM	account_unix_info aui
		 WHERE	aui.account_id = _accountid;

		--
		-- This is creatd by trigger for non-pseudousers, which will
		-- eventually change, so this is here once it goes away.
		--
		IF _uxaccountid IS NULL THEN
			IF unix_uid = 'auto' THEN
				_uid :=  person_manip.get_unix_uid(_account_type);
			ELSE
				_uid := unix_uid::int;
			END IF;

			PERFORM person_manip.setup_unix_account(
				in_account_id := account_id,
				in_account_type := _account_type,
				in_uid := _uid
			);
		END IF;
	END IF;
END;
$function$
;

-- DONE WITH proc person_manip.add_user -> add_user 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc person_manip.purge_person -> purge_person 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 408406
CREATE OR REPLACE FUNCTION person_manip.purge_person(in_person_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	aid	INTEGER;
BEGIN
	FOR aid IN select account_id 
			FROM account 
			WHERE person_id = in_person_id
	LOOP
		PERFORM person_manip.purge_account ( aid );
	END LOOP; 

	DELETE FROM person_contact WHERE person_id = in_person_id;
	DELETE FROM person_location WHERE person_id = in_person_id;
	DELETE FROM person_company WHERE person_id = in_person_id;
	DELETE FROM person_account_realm_company WHERE person_id = in_person_id;
	DELETE FROM person WHERE person_id = in_person_id;
END;
$function$
;

-- DONE WITH proc person_manip.purge_person -> purge_person 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc person_manip.purge_account -> purge_account 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('person_manip', 'purge_account', 'purge_account');

-- DROP OLD FUNCTION
-- consider old oid 396778
DROP FUNCTION IF EXISTS person_manip.purge_account(in_account_id integer);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 396778
DROP FUNCTION IF EXISTS person_manip.purge_account(in_account_id integer);
-- consider NEW oid 408405
CREATE OR REPLACE FUNCTION person_manip.purge_account(in_account_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	-- note the per-user account collection is removed in triggers

	DELETE FROM account_assignd_cert where ACCOUNT_ID = in_account_id;
	DELETE FROM account_token where ACCOUNT_ID = in_account_id;
	DELETE FROM account_unix_info where ACCOUNT_ID = in_account_id;
	DELETE FROM klogin where ACCOUNT_ID = in_account_id;
	DELETE FROM property where ACCOUNT_ID = in_account_id;
	DELETE FROM account_password where ACCOUNT_ID = in_account_id;
	DELETE FROM unix_group where account_collection_id in
		(select account_collection_id from account_collection 
			where account_collection_name in
				(select login from account where account_id = in_account_id)
				and account_collection_type in ('unix-group')
		);
	DELETE FROM account_collection_account where ACCOUNT_ID = in_account_id;

	DELETE FROM account_collection where account_collection_name in
		(select login from account where account_id = in_account_id)
		and account_collection_type in ('per-user', 'unix-group');

	DELETE FROM account where ACCOUNT_ID = in_account_id;
END;
$function$
;

-- DONE WITH proc person_manip.purge_account -> purge_account 
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH proc create_new_unix_account -> create_new_unix_account 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'create_new_unix_account', 'create_new_unix_account');

-- DROP OLD FUNCTION
-- consider old oid 415872

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 415872
-- consider NEW oid 408496
CREATE OR REPLACE FUNCTION jazzhands.create_new_unix_account()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
	unix_id INTEGER;
	_account_collection_id integer;
BEGIN
	IF NEW.person_id != 0 THEN
		PERFORM person_manip.setup_unix_account(
			in_account_id := NEW.account_id,
			in_account_type := NEW.account_type
		);
	END IF;
	RETURN NEW;	
END;
$function$
;

DROP TRIGGER trigger_create_new_unix_account on account;
CREATE TRIGGER trigger_create_new_unix_account
AFTER INSERT
    ON account
    FOR EACH ROW
    EXECUTE PROCEDURE create_new_unix_account();

-- DONE WITH proc create_new_unix_account -> create_new_unix_account 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc validate_property -> validate_property 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_property', 'validate_property');

-- DROP OLD FUNCTION
-- consider old oid 415853

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 415853
-- DROP FUNCTION IF EXISTS validate_property();
-- consider NEW oid 408471
CREATE OR REPLACE FUNCTION jazzhands.validate_property()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	tally			integer;
	v_prop			VAL_Property%ROWTYPE;
	v_proptype		VAL_Property_Type%ROWTYPE;
	v_account_collection	account_collection%ROWTYPE;
	v_netblock_collection	netblock_collection%ROWTYPE;
	v_num			integer;
	v_listvalue		Property.Property_Value%TYPE;
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
			((Company_Id IS NULL AND NEW.Company_Id IS NULL) OR
				(Company_Id = NEW.Company_Id)) AND
			((Device_Collection_Id IS NULL AND NEW.Device_Collection_Id IS NULL) OR
				(Device_Collection_Id = NEW.Device_Collection_Id)) AND
			((DNS_Domain_Id IS NULL AND NEW.DNS_Domain_Id IS NULL) OR
				(DNS_Domain_Id = NEW.DNS_Domain_Id)) AND
			((Operating_System_Id IS NULL AND NEW.Operating_System_Id IS NULL) OR
				(Operating_System_Id = NEW.Operating_System_Id)) AND
			((service_env_collection_id IS NULL AND NEW.service_env_collection_id IS NULL) OR
				(service_env_collection_id = NEW.service_env_collection_id)) AND
			((Site_Code IS NULL AND NEW.Site_Code IS NULL) OR
				(Site_Code = NEW.Site_Code)) AND
			((Account_Id IS NULL AND NEW.Account_Id IS NULL) OR
				(Account_Id = NEW.Account_Id)) AND
			((Account_Realm_Id IS NULL AND NEW.Account_Realm_Id IS NULL) OR
				(Account_Realm_Id = NEW.Account_Realm_Id)) AND
			((account_collection_Id IS NULL AND NEW.account_collection_Id IS NULL) OR
				(account_collection_Id = NEW.account_collection_Id)) AND
			((netblock_collection_Id IS NULL AND NEW.netblock_collection_Id IS NULL) OR
				(netblock_collection_Id = NEW.netblock_collection_Id)) AND
			((layer2_network_id IS NULL AND NEW.layer2_network_id IS NULL) OR
				(layer2_network_id = NEW.layer2_network_id)) AND
			((layer3_network_id IS NULL AND NEW.layer3_network_id IS NULL) OR
				(layer3_network_id = NEW.layer3_network_id)) AND
			((person_id IS NULL AND NEW.Person_id IS NULL) OR
				(Person_Id = NEW.person_id)) AND
			((property_collection_id IS NULL AND NEW.property_collection_id IS NULL) OR
				(property_collection_id = NEW.property_collection_id))
			;

		IF FOUND THEN
			RAISE EXCEPTION 
				'Property of type % already exists for given LHS and property is not multivalue',
				NEW.Property_Type
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
			((Company_Id IS NULL AND NEW.Company_Id IS NULL) OR
				(Company_Id = NEW.Company_Id)) AND
			((Device_Collection_Id IS NULL AND NEW.Device_Collection_Id IS NULL) OR
				(Device_Collection_Id = NEW.Device_Collection_Id)) AND
			((DNS_Domain_Id IS NULL AND NEW.DNS_Domain_Id IS NULL) OR
				(DNS_Domain_Id = NEW.DNS_Domain_Id)) AND
			((Operating_System_Id IS NULL AND NEW.Operating_System_Id IS NULL) OR
				(Operating_System_Id = NEW.Operating_System_Id)) AND
			((service_env_collection_id IS NULL AND NEW.service_env_collection_id IS NULL) OR
				(service_env_collection_id = NEW.service_env_collection_id)) AND
			((Site_Code IS NULL AND NEW.Site_Code IS NULL) OR
				(Site_Code = NEW.Site_Code)) AND
			((Person_id IS NULL AND NEW.Person_id IS NULL) OR
				(Person_Id = NEW.Person_Id)) AND
			((Account_Id IS NULL AND NEW.Account_Id IS NULL) OR
				(Account_Id = NEW.Account_Id)) AND
			((Account_Id IS NULL AND NEW.Account_Id IS NULL) OR
				(Account_Id = NEW.Account_Id)) AND
			((Account_Realm_id IS NULL AND NEW.Account_Realm_id IS NULL) OR
				(Account_Realm_id = NEW.Account_Realm_id)) AND
			((account_collection_Id IS NULL AND NEW.account_collection_Id IS NULL) OR
				(account_collection_Id = NEW.account_collection_Id)) AND
			((layer2_network_id IS NULL AND NEW.layer2_network_id IS NULL) OR
				(layer2_network_id = NEW.layer2_network_id)) AND
			((layer3_network_id IS NULL AND NEW.layer3_network_id IS NULL) OR
				(layer3_network_id = NEW.layer3_network_id)) AND
			((netblock_collection_Id IS NULL AND NEW.netblock_collection_Id IS NULL) OR
				(netblock_collection_Id = NEW.netblock_collection_Id)) AND
			((property_collection_Id IS NULL AND NEW.property_collection_Id IS NULL) OR
				(property_collection_Id = NEW.property_collection_Id))
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
	IF NEW.Property_Value_DNS_Domain_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'dns_domain_id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be DNS_Domain_Id' USING
				ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;
	IF NEW.Property_Value_Person_Id IS NOT NULL THEN
		IF v_prop.Property_Data_Type = 'Person_Id' THEN
			tally := tally + 1;
		ELSE
			RAISE 'Property value may not be Person_Id' USING
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

	-- If the RHS contains a account_collection_ID, check to see if it must be a
	-- specific type (e.g. per-user), and verify that if so
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

	IF v_prop.Permit_layer2_network_id = 'REQUIRED' THEN
			IF NEW.layer2_network_id IS NULL THEN
				RAISE 'layer2_network_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_layer2_network_id = 'PROHIBITED' THEN
			IF NEW.layer2_network_id IS NOT NULL THEN
				RAISE 'layer2_network_id is prohibited.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	END IF;

	IF v_prop.Permit_layer3_network_id = 'REQUIRED' THEN
			IF NEW.layer3_network_id IS NULL THEN
				RAISE 'layer3_network_id is required.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
	ELSIF v_prop.Permit_layer3_network_id = 'PROHIBITED' THEN
			IF NEW.layer3_network_id IS NOT NULL THEN
				RAISE 'layer3_network_id is prohibited.'
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

-- DONE WITH proc validate_property -> validate_property 
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH proc netblock_manip.allocate_netblock -> allocate_netblock 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('netblock_manip', 'allocate_netblock', 'allocate_netblock');

-- DROP OLD FUNCTION
-- consider old oid 446106
DROP FUNCTION IF EXISTS netblock_manip.allocate_netblock(parent_netblock_id integer, netmask_bits integer, address_type text, can_subnet boolean, allocate_from_bottom boolean, description character varying, netblock_status character varying);
-- consider old oid 446107
DROP FUNCTION IF EXISTS netblock_manip.allocate_netblock(parent_netblock_list integer[], netmask_bits integer, address_type text, can_subnet boolean, allocate_from_bottom boolean, description character varying, netblock_status character varying);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 446106
DROP FUNCTION IF EXISTS netblock_manip.allocate_netblock(parent_netblock_id integer, netmask_bits integer, address_type text, can_subnet boolean, allocate_from_bottom boolean, description character varying, netblock_status character varying);
-- consider old oid 446107
DROP FUNCTION IF EXISTS netblock_manip.allocate_netblock(parent_netblock_list integer[], netmask_bits integer, address_type text, can_subnet boolean, allocate_from_bottom boolean, description character varying, netblock_status character varying);
-- consider NEW oid 408458
CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock(parent_netblock_id integer, netmask_bits integer DEFAULT NULL::integer, address_type text DEFAULT 'netblock'::text, can_subnet boolean DEFAULT true, allocation_method text DEFAULT NULL::text, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024, ip_address inet DEFAULT NULL::inet, description character varying DEFAULT NULL::character varying, netblock_status character varying DEFAULT 'Allocated'::character varying)
 RETURNS netblock
 LANGUAGE plpgsql
AS $function$
DECLARE
	netblock_rec	RECORD;
BEGIN
	SELECT * into netblock_rec FROM netblock_manip.allocate_netblock(
		parent_netblock_list := ARRAY[parent_netblock_id],
		netmask_bits := netmask_bits,
		address_type := address_type,
		can_subnet := can_subnet,
		description := description,
		allocation_method := allocation_method,
		ip_address := ip_address,
		rnd_masklen_threshold := rnd_masklen_threshold,
		rnd_max_count := rnd_max_count,
		netblock_status := netblock_status
	);
	RETURN netblock_rec;
END;
$function$
;
-- consider NEW oid 408459
CREATE OR REPLACE FUNCTION netblock_manip.allocate_netblock(parent_netblock_list integer[], netmask_bits integer DEFAULT NULL::integer, address_type text DEFAULT 'netblock'::text, can_subnet boolean DEFAULT true, allocation_method text DEFAULT NULL::text, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024, ip_address inet DEFAULT NULL::inet, description character varying DEFAULT NULL::character varying, netblock_status character varying DEFAULT 'Allocated'::character varying)
 RETURNS netblock
 LANGUAGE plpgsql
AS $function$
DECLARE
	parent_rec		RECORD;
	netblock_rec	RECORD;
	inet_rec		RECORD;
	loopback_bits	integer;
	inet_family		integer;
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

	-- Lock the parent row, which should keep parallel processes from
	-- trying to obtain the same address

	FOR parent_rec IN SELECT * FROM jazzhands.netblock WHERE netblock_id = 
			ANY(allocate_netblock.parent_netblock_list) FOR UPDATE LOOP

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
			loopback_bits,
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
			inet_rec,
			masklen(inet_rec),
			parent_rec.netblock_type,
			'Y',
			'N',
			parent_rec.ip_universe_id,
			allocate_netblock.description,
			allocate_netblock.netblock_status
		) RETURNING * INTO netblock_rec;

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

		RETURN netblock_rec;
	END IF;
END;
$function$
;

-- DONE WITH proc netblock_manip.allocate_netblock -> allocate_netblock 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc netblock_manip.delete_netblock -> delete_netblock 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('netblock_manip', 'delete_netblock', 'delete_netblock');

-- DROP OLD FUNCTION
-- consider old oid 446104
DROP FUNCTION IF EXISTS netblock_manip.delete_netblock(in_netblock_id integer);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 446104
DROP FUNCTION IF EXISTS netblock_manip.delete_netblock(in_netblock_id integer);
-- consider NEW oid 408456
CREATE OR REPLACE FUNCTION netblock_manip.delete_netblock(in_netblock_id integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	par_nbid	jazzhands.netblock.netblock_id%type;
BEGIN
	/*
	 * Update netblocks that use this as a parent to point to my parent
	 */
	SELECT
		netblock_id INTO par_nbid
	FROM
		jazzhands.netblock
	WHERE 
		netblock_id = in_netblock_id;
	
	UPDATE
		jazzhands.netblock
	SET
		parent_netblock_id = par_nbid
	WHERE
		parent_netblock_id = in_netblock_id;
	
	/*
	 * Now delete the record
	 */
	DELETE FROM jazzhands.netblock WHERE netblock_id = in_netblock_id;
END;
$function$
;

-- DONE WITH proc netblock_manip.delete_netblock -> delete_netblock 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc person_manip.add_user_non_person -> add_user_non_person 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 408401
CREATE OR REPLACE FUNCTION person_manip.add_user_non_person(_company_id integer, _account_status character varying, _login character varying, _description character varying)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
	__account_id INTEGER;
BEGIN
    SELECT account_id
     INTO  __account_id
     FROM  person_manip.add_user(
	company_id := _company_id,
	person_company_relation := 'pseudouser',
	login := _login,
	description := _description,
	person_company_status := 'enabled'
    );
	RETURN __account_id;
END;
$function$
;

-- DONE WITH proc person_manip.add_user_non_person -> add_user_non_person 
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH proc check_svcenv_colllection_hier_loop -> check_svcenv_colllection_hier_loop 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 408490
CREATE OR REPLACE FUNCTION jazzhands.check_svcenv_colllection_hier_loop()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	IF NEW.service_env_collection_id = 
		NEW.child_service_env_coll_id THEN
			RAISE EXCEPTION 'svcenv Collection Loops Not Pernitted '
			USING ERRCODE = 20704;	/* XXX */
	END IF;
	RETURN NEW;
END;
$function$
;

-- DONE WITH proc check_svcenv_colllection_hier_loop -> check_svcenv_colllection_hier_loop 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc check_token_colllection_hier_loop -> check_token_colllection_hier_loop 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 408488
CREATE OR REPLACE FUNCTION jazzhands.check_token_colllection_hier_loop()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	IF NEW.token_collection_id = NEW.child_token_collection_id THEN
		RAISE EXCEPTION 'token Collection Loops Not Pernitted '
			USING ERRCODE = 20704;	/* XXX */
	END IF;
	RETURN NEW;
END;
$function$
;

-- DONE WITH proc check_token_colllection_hier_loop -> check_token_colllection_hier_loop 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc delete_per_svc_env_svc_env_collection -> delete_per_svc_env_svc_env_collection 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'delete_per_svc_env_svc_env_collection', 'delete_per_svc_env_svc_env_collection');

-- DROP OLD FUNCTION
-- consider old oid 454596

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 454596
-- consider NEW oid 408525
CREATE OR REPLACE FUNCTION jazzhands.delete_per_svc_env_svc_env_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	secid	service_environment_collection.service_env_collection_id%TYPE;
BEGIN
	SELECT	service_env_collection_id
	  FROM  service_environment_collection
	  INTO	secid
	 WHERE	service_env_collection_type = 'per-environment'
	   AND	service_env_collection_id in
		(select service_env_collection_id
		 from svc_environment_coll_svc_env
		where service_environment_id = OLD.service_environment_id
		)
	ORDER BY service_env_collection_id
	LIMIT 1;

	IF secid IS NOT NULL THEN
		DELETE FROM svc_environment_coll_svc_env
		WHERE service_env_collection_id = secid;

		DELETE from service_environment_collection
		WHERE service_env_collection_id = secid;
	END IF;

	RETURN OLD;
END;
$function$
;

-- DONE WITH proc delete_per_svc_env_svc_env_collection -> delete_per_svc_env_svc_env_collection 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc update_per_svc_env_svc_env_collection -> update_per_svc_env_svc_env_collection 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'update_per_svc_env_svc_env_collection', 'update_per_svc_env_svc_env_collection');

-- DROP OLD FUNCTION
-- consider old oid 454598

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 454598
-- consider NEW oid 408527
CREATE OR REPLACE FUNCTION jazzhands.update_per_svc_env_svc_env_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	secid		service_environment_collection.service_env_collection_id%TYPE;
BEGIN
	IF TG_OP = 'INSERT' THEN
		insert into service_environment_collection
			(service_env_collection_name, service_env_collection_type)
		values
			(NEW.service_environment_name, 'per-environment')
		RETURNING service_env_collection_id INTO secid;
		insert into svc_environment_coll_svc_env
			(service_env_collection_id, service_environment_id)
		VALUES
			(secid, NEW.service_environment_id);
	ELSIF TG_OP = 'UPDATE'  AND OLD.service_environment_id != NEW.service_environment_id THEN
		UPDATE	service_environment_collection
		   SET	service_env_collection_name = NEW.service_environment_name
		 WHERE	service_env_collection_name != NEW.service_environment_name
		   AND	service_env_collection_type = 'per-environment'
		   AND	service_environment_id in (
			SELECT	service_environment_id
			  FROM	svc_environment_coll_svc_env
			 WHERE	service_environment_id = 
				NEW.service_environment_id
			);
	END IF;
	RETURN NEW;
END;
$function$
;

-- DONE WITH proc update_per_svc_env_svc_env_collection -> update_per_svc_env_svc_env_collection 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc delete_peruser_account_collection -> delete_peruser_account_collection 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'delete_peruser_account_collection', 'delete_peruser_account_collection');

-- DROP OLD FUNCTION
-- consider old oid 454549

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 454549
-- consider NEW oid 408474
CREATE OR REPLACE FUNCTION jazzhands.delete_peruser_account_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	def_acct_rlm	account_realm.account_realm_id%TYPE;
	acid			account_collection.account_collection_id%TYPE;
BEGIN
	IF TG_OP = 'DELETE' THEN
		SELECT	account_realm_id
		  INTO	def_acct_rlm
		  FROM	property
		 WHERE	property_name = '_root_account_realm_id'
		    and	property_type = 'Defaults';

		IF def_acct_rlm is not NULL AND OLD.account_realm_id = def_acct_rlm THEN
				SELECT	account_collection_id
				  INTO	acid
				  FROM	account_collection ac
						INNER JOIN account_collection_account aca
							USING (account_collection_id)
				 WHERE	aca.account_id = OLD.account_Id
				   AND	ac.account_collection_type = 'per-user';

				 DELETE from account_collection_account
				  where account_collection_id = acid;

				 DELETE from account_collection
				  where account_collection_id = acid;
		END IF;
	END IF;
	RETURN OLD;
END;
$function$
;

-- DONE WITH proc delete_peruser_account_collection -> delete_peruser_account_collection 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc update_peruser_account_collection -> update_peruser_account_collection 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'update_peruser_account_collection', 'update_peruser_account_collection');

-- DROP OLD FUNCTION
-- consider old oid 454551

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 454551
-- consider NEW oid 408476
CREATE OR REPLACE FUNCTION jazzhands.update_peruser_account_collection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$
DECLARE
	def_acct_rlm	account_realm.account_realm_id%TYPE;
	acid			account_collection.account_collection_id%TYPE;
BEGIN
	SELECT	account_realm_id
	  INTO	def_acct_rlm
	  FROM	property
	 WHERE	property_name = '_root_account_realm_id'
	    and	property_type = 'Defaults';

	IF def_acct_rlm is not NULL AND NEW.account_realm_id = def_acct_rlm THEN
		if TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.account_realm_id != NEW.account_realm_id) THEN
			insert into account_collection 
				(account_collection_name, account_collection_type)
			values
				(NEW.login, 'per-user')
			RETURNING account_collection_id INTO acid;
			insert into account_collection_account 
				(account_collection_id, account_id)
			VALUES
				(acid, NEW.account_id);
		END IF;

		IF TG_OP = 'UPDATE' AND OLD.login != NEW.login THEN
			IF OLD.account_realm_id = NEW.account_realm_id THEN
				update	account_collection
				    set	account_collection_name = NEW.login
				  where	account_collection_type = 'per-user'
				    and	account_collection_name = OLD.login;
			END IF;
		END IF;
	END IF;

	-- remove the per-user entry if the new account realm is not the default
	IF TG_OP = 'UPDATE'  THEN
		IF def_acct_rlm is not NULL AND OLD.account_realm_id = def_acct_rlm AND NEW.account_realm_id != OLD.account_realm_id THEN
		    SELECT  account_collection_id
		INTO    acid
		FROM    account_collection ac
			INNER JOIN account_collection_account aca
					USING (account_collection_id)
		WHERE  aca.account_id = NEW.account_Id
		AND     ac.account_collection_type = 'per-user';

			DELETE from account_collection_account
				WHERE account_collection_id = acid;

			DELETE from account_collection
				WHERE account_collection_id = acid;
		END IF;
	END IF;
	RETURN NEW;
END;
$function$
;

-- DONE WITH proc update_peruser_account_collection -> update_peruser_account_collection 
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE v_account_collection_expanded [454434]
-- Save grants for later reapplication
SELECT schema_support.save_view_for_replay('jazzhands', 'v_account_collection_expanded');

CREATE VIEW v_account_collection_expanded AS
 WITH RECURSIVE var_recurse(level, root_account_collection_id, account_collection_id, array_path, cycle) AS (
	 SELECT 0 AS level,
	    a.account_collection_id AS root_account_collection_id,
	    a.account_collection_id,
	    ARRAY[a.account_collection_id] AS array_path,
	    false AS cycle
	   FROM account_collection a
	UNION ALL
	 SELECT x.level + 1 AS level,
	    x.root_account_collection_id,
	    ach.child_account_collection_id AS account_collection_id,
	    ach.child_account_collection_id || x.array_path AS array_path,
	    ach.child_account_collection_id = ANY (x.array_path) AS cycle
	   FROM var_recurse x
	     JOIN account_collection_hier ach ON x.account_collection_id = ach.account_collection_id
	  WHERE NOT x.cycle
	)
 SELECT var_recurse.level,
    var_recurse.root_account_collection_id,
    var_recurse.account_collection_id
   FROM var_recurse;

delete from __recreate where type = 'view' and object = 'v_account_collection_expanded';
-- DONE DEALING WITH TABLE v_account_collection_expanded [408317]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_acct_coll_expanded [454410]
-- Save grants for later reapplication
SELECT schema_support.save_dependant_objects_for_replay('jazzhands', 'v_acct_coll_expanded');
SELECT schema_support.save_view_for_replay('jazzhands', 'v_acct_coll_expanded');
CREATE VIEW v_acct_coll_expanded AS
 WITH RECURSIVE acct_coll_recurse(level, root_account_collection_id, account_collection_id, array_path, rvs_array_path, cycle) AS (
	 SELECT 0 AS level,
	    ac.account_collection_id AS root_account_collection_id,
	    ac.account_collection_id,
	    ARRAY[ac.account_collection_id] AS array_path,
	    ARRAY[ac.account_collection_id] AS rvs_array_path,
	    false AS bool
	   FROM account_collection ac
	UNION ALL
	 SELECT x.level + 1 AS level,
	    x.root_account_collection_id,
	    ach.account_collection_id,
	    x.array_path || ach.account_collection_id AS array_path,
	    ach.account_collection_id || x.rvs_array_path AS rvs_array_path,
	    ach.account_collection_id = ANY (x.array_path) AS cycle
	   FROM acct_coll_recurse x
	     JOIN account_collection_hier ach ON x.account_collection_id = ach.child_account_collection_id
	  WHERE NOT x.cycle
	)
 SELECT acct_coll_recurse.level,
    acct_coll_recurse.account_collection_id,
    acct_coll_recurse.root_account_collection_id,
    array_to_string(acct_coll_recurse.array_path, '/'::text) AS text_path,
    acct_coll_recurse.array_path,
    acct_coll_recurse.rvs_array_path
   FROM acct_coll_recurse;

delete from __recreate where type = 'view' and object = 'v_acct_coll_expanded';
-- DONE DEALING WITH TABLE v_acct_coll_expanded [408327]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_company_hier [454448]
-- Save grants for later reapplication
SELECT schema_support.save_view_for_replay('jazzhands', 'v_company_hier');
CREATE VIEW v_company_hier AS
 WITH RECURSIVE var_recurse(level, root_company_id, company_id, person_id, array_path, cycle) AS (
	 SELECT 0 AS level,
	    c.company_id AS root_company_id,
	    c.company_id,
	    pc.person_id,
	    ARRAY[c.company_id] AS array_path,
	    false AS cycle
	   FROM company c
	     JOIN person_company pc USING (company_id)
	UNION ALL
	 SELECT x.level + 1 AS level,
	    x.company_id AS root_company_id,
	    c.company_id,
	    pc.person_id,
	    c.company_id || x.array_path AS array_path,
	    c.company_id = ANY (x.array_path) AS cycle
	   FROM var_recurse x
	     JOIN company c ON c.parent_company_id = x.company_id
	     JOIN person_company pc ON c.company_id = pc.company_id
	  WHERE NOT x.cycle
	)
 SELECT DISTINCT var_recurse.root_company_id,
    var_recurse.company_id
   FROM var_recurse;

delete from __recreate where type = 'view' and object = 'v_company_hier';
-- DONE DEALING WITH TABLE v_company_hier [408361]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_device_coll_hier_detail [454391]
-- Save grants for later reapplication
SELECT schema_support.save_view_for_replay('jazzhands', 'v_device_coll_hier_detail');
CREATE VIEW v_device_coll_hier_detail AS
 WITH RECURSIVE var_recurse(root_device_collection_id, device_collection_id, parent_device_collection_id, device_collection_level, array_path, cycle) AS (
	 SELECT device_collection.device_collection_id AS root_device_collection_id,
	    device_collection.device_collection_id,
	    device_collection.device_collection_id AS parent_device_collection_id,
	    0 AS device_collection_level,
	    ARRAY[device_collection.device_collection_id] AS "array",
	    false AS bool
	   FROM device_collection
	UNION ALL
	 SELECT x.root_device_collection_id,
	    dch.device_collection_id,
	    dch.parent_device_collection_id,
	    x.device_collection_level + 1 AS device_collection_level,
	    dch.parent_device_collection_id || x.array_path AS array_path,
	    dch.parent_device_collection_id = ANY (x.array_path)
	   FROM var_recurse x
	     JOIN device_collection_hier dch ON x.parent_device_collection_id = dch.device_collection_id
	  WHERE NOT x.cycle
	)
 SELECT var_recurse.root_device_collection_id AS device_collection_id,
    var_recurse.parent_device_collection_id,
    var_recurse.device_collection_level
   FROM var_recurse;

delete from __recreate where type = 'view' and object = 'v_device_coll_hier_detail';
-- DONE DEALING WITH TABLE v_device_coll_hier_detail [408308]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_nblk_coll_netblock_expanded [454366]
-- Save grants for later reapplication
SELECT schema_support.save_view_for_replay('jazzhands', 'v_nblk_coll_netblock_expanded');
CREATE VIEW v_nblk_coll_netblock_expanded AS
 WITH RECURSIVE var_recurse(level, root_collection_id, netblock_collection_id, child_netblock_collection_id, array_path, cycle) AS (
	 SELECT 0 AS level,
	    u.netblock_collection_id AS root_collection_id,
	    u.netblock_collection_id,
	    u.netblock_collection_id AS child_netblock_collection_id,
	    ARRAY[u.netblock_collection_id] AS array_path,
	    false AS cycle
	   FROM netblock_collection u
	UNION ALL
	 SELECT x.level + 1 AS level,
	    x.netblock_collection_id AS root_netblock_collection_id,
	    uch.netblock_collection_id,
	    uch.child_netblock_collection_id,
	    uch.child_netblock_collection_id || x.array_path AS array_path,
	    uch.child_netblock_collection_id = ANY (x.array_path) AS cycle
	   FROM var_recurse x
	     JOIN netblock_collection_hier uch ON x.child_netblock_collection_id = uch.netblock_collection_id
	  WHERE NOT x.cycle
	)
 SELECT DISTINCT var_recurse.root_collection_id AS netblock_collection_id,
    netblock_collection_netblock.netblock_id
   FROM var_recurse
     JOIN netblock_collection_netblock USING (netblock_collection_id);

delete from __recreate where type = 'view' and object = 'v_nblk_coll_netblock_expanded';
-- DONE DEALING WITH TABLE v_nblk_coll_netblock_expanded [408283]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_netblock_hier [454356]
-- Save grants for later reapplication
SELECT schema_support.save_view_for_replay('jazzhands', 'v_netblock_hier');
CREATE VIEW v_netblock_hier AS
 WITH RECURSIVE var_recurse(netblock_level, root_netblock_id, ip, netblock_id, ip_address, netblock_status, is_single_address, description, parent_netblock_id, site_code, array_path, array_ip_path, cycle) AS (
	 SELECT 0 AS netblock_level,
	    nb.netblock_id AS root_netblock_id,
	    net_manip.inet_dbtop(nb.ip_address) AS ip,
	    nb.netblock_id,
	    nb.ip_address,
	    nb.netblock_status,
	    nb.is_single_address,
	    nb.description,
	    nb.parent_netblock_id,
	    snb.site_code,
	    ARRAY[nb.netblock_id] AS "array",
	    ARRAY[nb.ip_address] AS "array",
	    false AS bool
	   FROM netblock nb
	     LEFT JOIN site_netblock snb ON snb.netblock_id = nb.netblock_id
	  WHERE nb.is_single_address = 'N'::bpchar
	UNION ALL
	 SELECT x.netblock_level + 1 AS netblock_level,
	    x.root_netblock_id,
	    net_manip.inet_dbtop(nb.ip_address) AS ip,
	    nb.netblock_id,
	    nb.ip_address,
	    nb.netblock_status,
	    nb.is_single_address,
	    nb.description,
	    nb.parent_netblock_id,
	    snb.site_code,
	    x.array_path || nb.netblock_id AS array_path,
	    x.array_ip_path || nb.ip_address AS array_ip_path,
	    nb.netblock_id = ANY (x.array_path)
	   FROM var_recurse x
	     JOIN netblock nb ON x.netblock_id = nb.parent_netblock_id
	     LEFT JOIN site_netblock snb ON snb.netblock_id = nb.netblock_id
	  WHERE nb.is_single_address = 'N'::bpchar AND NOT x.cycle
	)
 SELECT var_recurse.netblock_level,
    var_recurse.root_netblock_id,
    var_recurse.ip,
    var_recurse.netblock_id,
    var_recurse.ip_address,
    var_recurse.netblock_status,
    var_recurse.is_single_address,
    var_recurse.description,
    var_recurse.parent_netblock_id,
    var_recurse.site_code,
    array_to_string(var_recurse.array_path, '/'::text) AS text_path,
    var_recurse.array_path,
    var_recurse.array_ip_path
   FROM var_recurse;

delete from __recreate where type = 'view' and object = 'v_netblock_hier';
-- DONE DEALING WITH TABLE v_netblock_hier [408271]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_person_company_expanded [454371]
-- Save grants for later reapplication
SELECT schema_support.save_view_for_replay('jazzhands', 'v_person_company_expanded');
CREATE VIEW v_person_company_expanded AS
 WITH RECURSIVE var_recurse(level, root_company_id, company_id, person_id, array_path, cycle) AS (
	 SELECT 0 AS level,
	    c.company_id AS root_company_id,
	    c.company_id,
	    pc.person_id,
	    ARRAY[c.company_id] AS array_path,
	    false AS bool
	   FROM company c
	     JOIN person_company pc USING (company_id)
	UNION ALL
	 SELECT x.level + 1 AS level,
	    x.company_id AS root_company_id,
	    c.company_id,
	    pc.person_id,
	    c.company_id || x.array_path AS array_path,
	    c.company_id = ANY (x.array_path) AS cycle
	   FROM var_recurse x
	     JOIN company c ON c.parent_company_id = x.company_id
	     JOIN person_company pc ON c.company_id = pc.company_id
	  WHERE NOT x.cycle
	)
 SELECT DISTINCT var_recurse.root_company_id AS company_id,
    var_recurse.person_id
   FROM var_recurse;

delete from __recreate where type = 'view' and object = 'v_person_company_expanded';
-- DONE DEALING WITH TABLE v_person_company_expanded [408288]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_physical_connection [454458]
-- Save grants for later reapplication
SELECT schema_support.save_view_for_replay('jazzhands', 'v_physical_connection');
CREATE VIEW v_physical_connection AS
 WITH RECURSIVE var_recurse(level, layer1_connection_id, physical_connection_id, layer1_physical_port1_id, layer1_physical_port2_id, physical_port1_id, physical_port2_id, array_path, cycle) AS (
	 SELECT 0,
	    l1.layer1_connection_id,
	    pc.physical_connection_id,
	    l1.physical_port1_id AS layer1_physical_port1_id,
	    l1.physical_port2_id AS layer1_physical_port2_id,
	    pc.physical_port1_id,
	    pc.physical_port2_id,
	    ARRAY[l1.physical_port1_id] AS array_path,
	    false AS cycle
	   FROM layer1_connection l1
	     JOIN physical_connection pc USING (physical_port1_id)
	UNION ALL
	 SELECT x.level + 1,
	    x.layer1_connection_id,
	    pc.physical_connection_id,
	    x.physical_port1_id AS layer1_physical_port1_id,
	    x.physical_port2_id AS layer1_physical_port2_id,
	    pc.physical_port1_id,
	    pc.physical_port2_id,
	    pc.physical_port2_id || x.array_path AS array_path,
	    pc.physical_port2_id = ANY (x.array_path) AS cycle
	   FROM var_recurse x
	     JOIN physical_connection pc ON x.physical_port2_id = pc.physical_port1_id
	)
 SELECT var_recurse.level,
    var_recurse.layer1_connection_id,
    var_recurse.physical_connection_id,
    var_recurse.layer1_physical_port1_id,
    var_recurse.layer1_physical_port2_id,
    var_recurse.physical_port1_id,
    var_recurse.physical_port2_id
   FROM var_recurse;

delete from __recreate where type = 'view' and object = 'v_physical_connection';
-- DONE DEALING WITH TABLE v_physical_connection [408371]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH proc check_device_colllection_hier_loop -> check_device_colllection_hier_loop 


-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider NEW oid 408486
CREATE OR REPLACE FUNCTION jazzhands.check_device_colllection_hier_loop()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	IF NEW.device_collection_id = NEW.parent_device_collection_id THEN
		RAISE EXCEPTION 'device Collection Loops Not Pernitted '
			USING ERRCODE = 20704;	/* XXX */
	END IF;
	RETURN NEW;
END;
$function$
;

-- DONE WITH proc check_device_colllection_hier_loop -> check_device_colllection_hier_loop 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc manipulate_netblock_parentage_before -> manipulate_netblock_parentage_before 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'manipulate_netblock_parentage_before', 'manipulate_netblock_parentage_before');

-- DROP OLD FUNCTION
-- consider old oid 485787

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 485787
-- consider NEW oid 408500
CREATE OR REPLACE FUNCTION jazzhands.manipulate_netblock_parentage_before()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO jazzhands
AS $function$

DECLARE
	nbtype				record;
	v_netblock_type		val_netblock_type.netblock_type%TYPE;
BEGIN
	/*
	 * Get the parameters for the given netblock type to see if we need
	 * to do anything
	 */

	RAISE DEBUG 'Performing % on netblock %', TG_OP, NEW.netblock_id;

	SELECT * INTO nbtype FROM val_netblock_type WHERE
		netblock_type = NEW.netblock_type;

	IF (NOT FOUND) OR nbtype.db_forced_hierarchy != 'Y' THEN
		RETURN NEW;
	END IF;

	/*
	 * Find the correct parent netblock
	 */

	RAISE DEBUG 'Setting forced hierarchical netblock %', NEW.netblock_id;
	NEW.parent_netblock_id := netblock_utils.find_best_parent_id(
		NEW.ip_address,
		NULL,
		NEW.netblock_type,
		NEW.ip_universe_id,
		NEW.is_single_address,
		NEW.netblock_id
		);

	RAISE DEBUG 'Setting parent for netblock % (%, type %, universe %, single-address %) to %',
		NEW.netblock_id, NEW.ip_address, NEW.netblock_type,
		NEW.ip_universe_id, NEW.is_single_address,
		NEW.parent_netblock_id;

	/*
	 * If we are an end-node, then we're done
	 */

	IF NEW.is_single_address = 'Y' THEN
		RETURN NEW;
	END IF;

	/*
	 * If we're updating and we're a container netblock, find
	 * all of the children of our new parent that should be ours and take
	 * them.  They will already be guaranteed to be of the correct
	 * netblock_type and ip_universe_id.  We can't do this for inserts
	 * because the row doesn't exist causing foreign key problems, so
	 * that needs to be done in an after trigger.
	 */
	IF TG_OP = 'UPDATE' THEN
		RAISE DEBUG 'Setting parent for all child netblocks of parent netblock % that belong to %',
			NEW.parent_netblock_id,
			NEW.netblock_id;
		UPDATE
			netblock
		SET
			parent_netblock_id = NEW.netblock_id
		WHERE
			parent_netblock_id = NEW.parent_netblock_id AND
			ip_address <<= NEW.ip_address AND
			netblock_id != NEW.netblock_id;

		RAISE DEBUG 'Setting parent for all child netblocks of netblock % that no longer belong to it to %',
			NEW.parent_netblock_id,
			NEW.netblock_id;
		RAISE DEBUG 'Setting parent % to %',
			OLD.netblock_id,
			OLD.parent_netblock_id;
		UPDATE
			netblock
		SET
			parent_netblock_id = OLD.parent_netblock_id
		WHERE
			parent_netblock_id = NEW.netblock_id AND
			(ip_universe_id != NEW.ip_universe_id OR
			 netblock_type != NEW.netblock_type OR
			 NOT(ip_address <<= NEW.ip_address));
	END IF;

	RETURN NEW;
END;
$function$
;

-- DONE WITH proc manipulate_netblock_parentage_before -> manipulate_netblock_parentage_before 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc validate_netblock -> validate_netblock 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_netblock', 'validate_netblock');

-- DROP OLD FUNCTION
-- consider old oid 485785

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 485785
-- consider NEW oid 408498

CREATE OR REPLACE FUNCTION validate_netblock()
RETURNS TRIGGER AS $$
DECLARE
	nbtype				RECORD;
	v_netblock_id		netblock.netblock_id%TYPE;
	parent_netblock		RECORD;
	netmask_bits		integer;
BEGIN
	IF NEW.ip_address IS NULL THEN
		RAISE EXCEPTION 'Column ip_address may not be null'
			USING ERRCODE = 'not_null_violation';
	END IF;

	SELECT * INTO nbtype FROM val_netblock_type WHERE
		netblock_type = NEW.netblock_type;

	IF NEW.is_single_address = 'Y' THEN
		IF nbtype.db_forced_hierarchy = 'Y' THEN
			RAISE DEBUG 'Calculating netmask for new netblock';

			v_netblock_id := netblock_utils.find_best_parent_id(
				NEW.ip_address,
				NULL,
				NEW.netblock_type,
				NEW.ip_universe_id,
				NEW.is_single_address,
				NEW.netblock_id
				);

			IF v_netblock_id IS NULL THEN
				RAISE EXCEPTION 'A single address (%) must be the child of a parent netblock, which must have can_subnet=N', NEW.ip_address
					USING ERRCODE = 'JH105';
			END IF;

			SELECT masklen(ip_address) INTO netmask_bits FROM
				netblock WHERE netblock_id = v_netblock_id;

			NEW.ip_address := set_masklen(NEW.ip_address, netmask_bits);
		END IF;
	END IF;

	/* Done with handling of netmasks */

	IF NEW.can_subnet = 'Y' AND NEW.is_single_address = 'Y' THEN
		RAISE EXCEPTION 'Single addresses may not be subnettable'
			USING ERRCODE = 'JH106';
	END IF;

	IF NEW.is_single_address = 'N' AND (NEW.ip_address != cidr(NEW.ip_address))
			THEN
		RAISE EXCEPTION
			'Non-network bits must be zero if is_single_address is N for %',
			NEW.ip_address
			USING ERRCODE = 'JH103';
	END IF;

	/*
	 * Commented out check for RFC1918 space.  This is probably handled
	 * well enough by the ip_universe/netblock_type additions, although
	 * it's possible that netblock_type may need to have an additional
	 * field added to allow people to be stupid (for example,
	 * allow_duplicates='Y','N','RFC1918')
	 */

/*
	IF NOT net_manip.inet_is_private(NEW.ip_address) THEN
*/
			PERFORM netblock_id
			   FROM netblock
			  WHERE ip_address = NEW.ip_address AND
					ip_universe_id = NEW.ip_universe_id AND
					netblock_type = NEW.netblock_type AND
					is_single_address = NEW.is_single_address;
			IF (TG_OP = 'INSERT' AND FOUND) THEN
				RAISE EXCEPTION 'Unique Constraint Violated on IP Address: %',
					NEW.ip_address
					USING ERRCODE= 'unique_violation';
			END IF;
			IF (TG_OP = 'UPDATE') THEN
				IF (NEW.ip_address != OLD.ip_address AND FOUND) THEN
					RAISE EXCEPTION
						'Unique Constraint Violated on IP Address: %',
						NEW.ip_address
						USING ERRCODE = 'unique_violation';
				END IF;
			END IF;
/*
	END IF;
*/

	/*
	 * Parent validation is performed in the deferred after trigger
	 */

	 RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;


-- DONE WITH proc validate_netblock -> validate_netblock 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc netblock_utils.find_free_netblock -> find_free_netblock 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_free_netblock', 'find_free_netblock');

-- DROP OLD FUNCTION
-- consider old oid 485745

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 485745
-- consider NEW oid 408448
CREATE OR REPLACE FUNCTION netblock_utils.find_free_netblock(parent_netblock_id integer, netmask_bits integer DEFAULT NULL::integer, single_address boolean DEFAULT false, allocation_method text DEFAULT NULL::text, desired_ip_address inet DEFAULT NULL::inet, rnd_masklen_threshold integer DEFAULT 110, rnd_max_count integer DEFAULT 1024)
 RETURNS TABLE(ip_address inet, netblock_type character varying, ip_universe_id integer)
 LANGUAGE plpgsql
AS $function$
BEGIN
	RETURN QUERY SELECT * FROM netblock_utils.find_free_netblocks(
			parent_netblock_id := parent_netblock_id,
			netmask_bits := netmask_bits,
			single_address := single_address,
			allocate_from_bottom := allocate_from_bottom,
			desired_ip_address := desired_ip_address,
			max_addresses := 1);
END;
$function$
;

-- DONE WITH proc netblock_utils.find_free_netblock -> find_free_netblock 
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE v_department_company_expanded [485594]
-- Save grants for later reapplication
SELECT schema_support.save_view_for_replay('jazzhands', 'v_department_company_expanded');
CREATE VIEW v_department_company_expanded AS
 WITH RECURSIVE var_recurse(level, root_company_id, company_id, account_collection_id, array_path, cycle) AS (
	 SELECT 0 AS level,
	    c.company_id AS root_company_id,
	    c.company_id,
	    d.account_collection_id,
	    ARRAY[c.company_id] AS array_path,
	    false AS bool
	   FROM company c
	     JOIN department d USING (company_id)
	UNION ALL
	 SELECT x.level + 1 AS level,
	    x.company_id AS root_company_id,
	    c.company_id,
	    d.account_collection_id,
	    c.company_id || x.array_path AS array_path,
	    c.company_id = ANY (x.array_path) AS cycle
	   FROM var_recurse x
	     JOIN company c ON c.parent_company_id = x.company_id
	     JOIN department d ON c.company_id = d.company_id
	  WHERE NOT x.cycle
	)
 SELECT DISTINCT var_recurse.root_company_id AS company_id,
    var_recurse.account_collection_id
   FROM var_recurse;

delete from __recreate where type = 'view' and object = 'v_department_company_expanded';
-- DONE DEALING WITH TABLE v_department_company_expanded [408293]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_application_role [485657]
-- Save grants for later reapplication
SELECT schema_support.save_view_for_replay('jazzhands', 'v_application_role');
CREATE VIEW v_application_role AS
 WITH RECURSIVE var_recurse(role_level, role_id, parent_role_id, root_role_id, root_role_name, role_name, role_path, role_is_leaf, array_path, cycle) AS (
	 SELECT 0 AS role_level,
	    device_collection.device_collection_id AS role_id,
	    NULL::integer AS parent_role_id,
	    device_collection.device_collection_id AS root_role_id,
	    device_collection.device_collection_name AS root_role_name,
	    device_collection.device_collection_name AS role_name,
	    '/'::text || device_collection.device_collection_name::text AS role_path,
	    'N'::text AS role_is_leaf,
	    ARRAY[device_collection.device_collection_id] AS array_path,
	    false AS cycle
	   FROM device_collection
	  WHERE device_collection.device_collection_type::text = 'appgroup'::text AND NOT (device_collection.device_collection_id IN ( SELECT device_collection_hier.device_collection_id
		   FROM device_collection_hier))
	UNION ALL
	 SELECT x.role_level + 1 AS role_level,
	    dch.device_collection_id AS role_id,
	    dch.parent_device_collection_id AS parent_role_id,
	    x.root_role_id,
	    x.root_role_name,
	    dc.device_collection_name AS role_name,
	    (((x.role_path || '/'::text) || dc.device_collection_name::text))::character varying(255) AS role_path,
		CASE
		    WHEN lchk.parent_device_collection_id IS NULL THEN 'Y'::text
		    ELSE 'N'::text
		END AS role_is_leaf,
	    dch.parent_device_collection_id || x.array_path AS array_path,
	    dch.parent_device_collection_id = ANY (x.array_path) AS cycle
	   FROM var_recurse x
	     JOIN device_collection_hier dch ON x.role_id = dch.parent_device_collection_id
	     JOIN device_collection dc ON dch.device_collection_id = dc.device_collection_id
	     LEFT JOIN device_collection_hier lchk ON dch.device_collection_id = lchk.parent_device_collection_id
	  WHERE NOT x.cycle
	)
 SELECT DISTINCT var_recurse.role_level,
    var_recurse.role_id,
    var_recurse.parent_role_id,
    var_recurse.root_role_id,
    var_recurse.root_role_name,
    var_recurse.role_name,
    var_recurse.role_path,
    var_recurse.role_is_leaf,
    var_recurse.array_path,
    var_recurse.cycle
   FROM var_recurse;

delete from __recreate where type = 'view' and object = 'v_application_role';
-- DONE DEALING WITH TABLE v_application_role [408352]
--------------------------------------------------------------------



--------------------------------------------------------------------
-- DEALING WITH TABLE v_property [485579]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_property', 'v_property');
CREATE VIEW v_property AS
 SELECT property.property_id,
    property.account_collection_id,
    property.account_id,
    property.account_realm_id,
    property.company_id,
    property.device_collection_id,
    property.dns_domain_id,
    property.netblock_collection_id,
    property.layer2_network_id,
    property.layer3_network_id,
    property.operating_system_id,
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
    property.property_value_dns_domain_id,
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
-- DONE DEALING WITH TABLE v_property [408278]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE v_acct_coll_prop_expanded [485647]
-- Save grants for later reapplication
SELECT schema_support.save_view_for_replay('jazzhands', 'v_acct_coll_prop_expanded');
CREATE VIEW v_acct_coll_prop_expanded AS
 SELECT v_acct_coll_expanded_detail.root_account_collection_id AS account_collection_id,
    v_property.property_id,
    v_property.property_name,
    v_property.property_type,
    v_property.property_value,
    v_property.property_value_timestamp,
    v_property.property_value_company_id,
    v_property.property_value_account_coll_id,
    v_property.property_value_dns_domain_id,
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
-- DONE DEALING WITH TABLE v_acct_coll_prop_expanded [408346]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH proc service_environment_collection_member_enforce -> service_environment_collection_member_enforce 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'service_environment_collection_member_enforce', 'service_environment_collection_member_enforce');

-- DROP OLD FUNCTION
-- consider old oid 504394

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 504394
-- consider NEW oid 408603
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
			RAISE EXCEPTION 'Device may not be a member of more than % collections of type %',
				svcenvt.MAX_NUM_COLLECTIONS, svcenvt.service_env_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- DONE WITH proc service_environment_collection_member_enforce -> service_environment_collection_member_enforce 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc netblock_utils.id_tag -> id_tag 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('netblock_utils', 'id_tag', 'id_tag');

-- DROP OLD FUNCTION
-- consider old oid 504260
DROP FUNCTION IF EXISTS netblock_utils.id_tag();

-- DONE WITH proc netblock_utils.id_tag -> id_tag 
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH TABLE v_corp_family_account [504207]
-- Save grants for later reapplication

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_corp_family_account', 'v_corp_family_account');
CREATE VIEW v_corp_family_account AS
 SELECT account.account_id,
    account.login,
    account.person_id,
    account.company_id,
    account.account_realm_id,
    account.account_status,
    account.account_role,
    account.account_type,
    account.description,
    account.data_ins_user,
    account.data_ins_date,
    account.data_upd_user,
    account.data_upd_date
   FROM account
  WHERE (account.account_realm_id IN ( SELECT property.account_realm_id
           FROM property
          WHERE property.property_name::text = '_root_account_realm_id'::text AND property.property_type::text = 'Defaults'::text));

delete from __recreate where type = 'view' and object = 'v_corp_family_account';
-- DONE DEALING WITH TABLE v_corp_family_account [408381]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH proc validate_netblock_parentage -> validate_netblock_parentage 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'validate_netblock_parentage', 'validate_netblock_parentage');

-- DROP OLD FUNCTION
-- consider old oid 504313
-- consider NEW oid 408505

CREATE OR REPLACE FUNCTION validate_netblock_parentage()
RETURNS TRIGGER AS $$
DECLARE
	nbrec			record;
	realnew			record;
	nbtype			record;
	parent_nbid		netblock.netblock_id%type;
	ipaddr			inet;
	parent_ipaddr	inet;
	single_count	integer;
	nonsingle_count	integer;
	pip	    		netblock.ip_address%type;
BEGIN

	RAISE DEBUG 'Validating % of netblock %', TG_OP, NEW.netblock_id;

	SELECT * INTO nbtype FROM val_netblock_type WHERE
		netblock_type = NEW.netblock_type;

	/*
	 * It's possible that due to delayed triggers that what is stored in
	 * NEW is not current, so fetch the current values
	 */

	SELECT * INTO realnew FROM netblock WHERE netblock_id =
		NEW.netblock_id;
	IF NOT FOUND THEN
		/*
		 * If the netblock isn't there, it was subsequently deleted, so
		 * our parentage doesn't need to be checked
		 */
		RETURN NULL;
	END IF;


	/*
	 * If the parent changed above (or somewhere else between update and
	 * now), just bail, because another trigger will have been fired that
	 * we can do the full check with.
	 */
	IF NEW.parent_netblock_id != realnew.parent_netblock_id AND
		realnew.parent_netblock_id IS NOT NULL
	THEN
		RAISE DEBUG '... skipping for now';
		RETURN NULL;
	END IF;

	/*
	 * Validate that parent and all children are of the same netblock_type and
	 * in the same ip_universe.  We care about this even if the
	 * netblock type is not a validated type.
	 */

	RAISE DEBUG 'Verifying child ip_universe and type match';
	PERFORM netblock_id FROM netblock WHERE
		parent_netblock_id = realnew.netblock_id AND
		netblock_type != realnew.netblock_type AND
		ip_universe_id != realnew.ip_universe_id;

	IF FOUND THEN
		RAISE EXCEPTION 'Netblock children must all be of the same type and universe as the parent'
			USING ERRCODE = 'JH109';
	END IF;

	RAISE DEBUG '... OK';

	/*
	 * validate that this netblock is attached to its correct parent
	 */
	IF realnew.parent_netblock_id IS NULL THEN
		IF nbtype.is_validated_hierarchy='N' THEN
			RETURN NULL;
		END IF;
		RAISE DEBUG 'Checking hierarchical netblock_id % with NULL parent',
			NEW.netblock_id;

		IF realnew.is_single_address = 'Y' THEN
			RAISE 'A single address (%) must be the child of a parent netblock, which must have can_subnet=N',
				realnew.ip_address
				USING ERRCODE = 'JH105';
		END IF;

		/*
		 * Validate that a netblock has a parent, unless
		 * it is the root of a hierarchy
		 */
		parent_nbid := netblock_utils.find_best_parent_id(
			realnew.ip_address,
			NULL,
			realnew.netblock_type,
			realnew.ip_universe_id,
			realnew.is_single_address,
			realnew.netblock_id
		);

		IF parent_nbid IS NOT NULL THEN
			SELECT * INTO nbrec FROM netblock WHERE netblock_id =
				parent_nbid;

			RAISE EXCEPTION 'Netblock % (%) has NULL parent; should be % (%)',
				realnew.netblock_id, realnew.ip_address,
				parent_nbid, nbrec.ip_address USING ERRCODE = 'JH102';
		END IF;

		/*
		 * Validate that none of the other top-level netblocks should
		 * belong to this netblock
		 */
		PERFORM netblock_id FROM netblock WHERE
			parent_netblock_id IS NULL AND
			netblock_id != NEW.netblock_id AND
			netblock_type = NEW.netblock_type AND
			ip_universe_id = NEW.ip_universe_id AND
			ip_address <<= NEW.ip_address;
		IF FOUND THEN
			RAISE EXCEPTION 'Other top-level netblocks should belong to this parent'
				USING ERRCODE = 'JH108';
		END IF;
	ELSE
	 	/*
		 * Reject a block that is self-referential
		 */
	 	IF realnew.parent_netblock_id = realnew.netblock_id THEN
			RAISE EXCEPTION 'Netblock may not have itself as a parent'
				USING ERRCODE = 'JH101';
		END IF;

		SELECT * INTO nbrec FROM netblock WHERE netblock_id =
			realnew.parent_netblock_id;

		/*
		 * This shouldn't happen, but may because of deferred constraints
		 */
		IF NOT FOUND THEN
			RAISE EXCEPTION 'Parent netblock % does not exist',
			realnew.parent_netblock_id
			USING ERRCODE = 'foreign_key_violation';
		END IF;

		IF nbrec.is_single_address = 'Y' THEN
			RAISE EXCEPTION 'A parent netblock (% for %) may not be a single address',
			nbrec.netblock_id, realnew.ip_address
			USING ERRCODE = 'JH10A';
		END IF;

		IF nbrec.ip_universe_id != realnew.ip_universe_id OR
				nbrec.netblock_type != realnew.netblock_type THEN
			RAISE EXCEPTION 'Netblock children must all be of the same type and universe as the parent'
			USING ERRCODE = 'JH109';
		END IF;

		IF nbtype.is_validated_hierarchy='N' THEN
			RETURN NULL;
		ELSE
			parent_nbid := netblock_utils.find_best_parent_id(
				realnew.ip_address,
				NULL,
				realnew.netblock_type,
				realnew.ip_universe_id,
				realnew.is_single_address,
				realnew.netblock_id
				);

			IF realnew.can_subnet = 'N' THEN
				PERFORM netblock_id FROM netblock WHERE
					parent_netblock_id = realnew.netblock_id AND
					is_single_address = 'N';
				IF FOUND THEN
					RAISE EXCEPTION 'A non-subnettable netblock (%) may not have child network netblocks',
					realnew.netblock_id
					USING ERRCODE = 'JH10B';
				END IF;
			END IF;
			IF realnew.is_single_address = 'Y' THEN
				SELECT * INTO nbrec FROM netblock
					WHERE netblock_id = realnew.parent_netblock_id;
				IF (nbrec.can_subnet = 'Y') THEN
					RAISE 'Parent netblock % for single-address % must have can_subnet=N',
						nbrec.netblock_id,
						realnew.ip_address
						USING ERRCODE = 'JH10D';
				END IF;
				IF (masklen(realnew.ip_address) != 
						masklen(nbrec.ip_address)) THEN
					RAISE 'Parent netblock % does not have the same netmask as single-address child % (% vs %)',
						parent_nbid, realnew.netblock_id,
						masklen(nbrec.ip_address),
						masklen(realnew.ip_address)
						USING ERRCODE = 'JH105';
				END IF;
			END IF;
			IF (parent_nbid IS NULL OR realnew.parent_netblock_id != parent_nbid) THEN
				SELECT ip_address INTO parent_ipaddr FROM netblock
				WHERE
					netblock_id = parent_nbid;
				SELECT ip_address INTO ipaddr FROM netblock WHERE
					netblock_id = realnew.parent_netblock_id;

				RAISE EXCEPTION
					'Parent netblock % (%) for netblock % (%) is not the correct parent (should be % (%))',
					realnew.parent_netblock_id, ipaddr,
					realnew.netblock_id, realnew.ip_address,
					parent_nbid, parent_ipaddr
					USING ERRCODE = 'JH102';
			END IF;
			/*
			 * Validate that all children are is_single_address='Y' or
			 * all children are is_single_address='N'
			 */
			SELECT count(*) INTO single_count FROM netblock WHERE
				is_single_address='Y' and parent_netblock_id =
				realnew.parent_netblock_id;
			SELECT count(*) INTO nonsingle_count FROM netblock WHERE
				is_single_address='N' and parent_netblock_id =
				realnew.parent_netblock_id;

			IF (single_count > 0 and nonsingle_count > 0) THEN
				SELECT * INTO nbrec FROM netblock WHERE netblock_id =
					realnew.parent_netblock_id;
				RAISE EXCEPTION 'Netblock % (%) may not have direct children for both single and multiple addresses simultaneously',
					nbrec.netblock_id, nbrec.ip_address
					USING ERRCODE = 'JH107';
			END IF;
			/*
			 *  If we're updating and we changed our ip_address (including
			 *  netmask bits), then check that our children still belong to
			 *  us
			 */
			 IF (TG_OP = 'UPDATE' AND NEW.ip_address != OLD.ip_address) THEN
				PERFORM netblock_id FROM netblock WHERE
					parent_netblock_id = realnew.netblock_id AND
					((is_single_address = 'Y' AND NEW.ip_address !=
						ip_address::cidr) OR
					(is_single_address = 'N' AND realnew.netblock_id !=
						netblock_utils.find_best_parent_id(netblock_id)));
				IF FOUND THEN
					RAISE EXCEPTION 'Update for netblock % (%) causes parent to have children that do not belong to it',
						realnew.netblock_id, realnew.ip_address
						USING ERRCODE = 'JH10E';
				END IF;
			END IF;

			/*
			 * Validate that none of the children of the parent netblock are
			 * children of this netblock (e.g. if inserting into the middle
			 * of the hierarchy)
			 */
			IF (realnew.is_single_address = 'N') THEN
				PERFORM netblock_id FROM netblock WHERE
					parent_netblock_id = realnew.parent_netblock_id AND
					netblock_id != realnew.netblock_id AND
					ip_address <<= realnew.ip_address;
				IF FOUND THEN
					RAISE EXCEPTION 'Other netblocks have children that should belong to parent % (%)',
						realnew.parent_netblock_id, realnew.ip_address
						USING ERRCODE = 'JH108';
				END IF;
			END IF;
		END IF;
	END IF;

	RETURN NULL;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;


-- DONE WITH proc validate_netblock_parentage -> validate_netblock_parentage 
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH proc service_environment_collection_member_enforce -> service_environment_collection_member_enforce 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'service_environment_collection_member_enforce', 'service_environment_collection_member_enforce');

-- DROP OLD FUNCTION
-- consider old oid 504394

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 504394
-- consider NEW oid 408603
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
			RAISE EXCEPTION 'Device may not be a member of more than % collections of type %',
				svcenvt.MAX_NUM_COLLECTIONS, svcenvt.service_env_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$function$
;

-- DONE WITH proc service_environment_collection_member_enforce -> service_environment_collection_member_enforce 
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH proc netblock_utils.find_best_parent_id -> find_best_parent_id 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('netblock_utils', 'find_best_parent_id', 'find_best_parent_id');

-- DROP OLD FUNCTION
-- consider old oid 517331
DROP FUNCTION IF EXISTS netblock_utils.find_best_parent_id(in_netblock_id integer);
-- consider old oid 517330
DROP FUNCTION IF EXISTS netblock_utils.find_best_parent_id(in_ipaddress inet, in_netmask_bits integer, in_netblock_type character varying, in_ip_universe_id integer, in_is_single_address character, in_netblock_id integer, in_fuzzy_can_subnet boolean, can_fix_can_subnet boolean);

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 517331
DROP FUNCTION IF EXISTS netblock_utils.find_best_parent_id(in_netblock_id integer);
-- consider old oid 517330
DROP FUNCTION IF EXISTS netblock_utils.find_best_parent_id(in_ipaddress inet, in_netmask_bits integer, in_netblock_type character varying, in_ip_universe_id integer, in_is_single_address character, in_netblock_id integer, in_fuzzy_can_subnet boolean, can_fix_can_subnet boolean);
-- consider NEW oid 408444
CREATE OR REPLACE FUNCTION netblock_utils.find_best_parent_id(in_netblock_id integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
	nbrec		RECORD;
BEGIN
	SELECT * INTO nbrec FROM jazzhands.netblock WHERE 
		netblock_id = in_netblock_id;

	RETURN netblock_utils.find_best_parent_id(
		nbrec.ip_address,
		masklen(nbrec.ip_address),
		nbrec.netblock_type,
		nbrec.ip_universe_id,
		nbrec.is_single_address,
		in_netblock_id
	);
END;
$function$
;
-- consider NEW oid 408443
CREATE OR REPLACE FUNCTION netblock_utils.find_best_parent_id(in_ipaddress inet, in_netmask_bits integer DEFAULT NULL::integer, in_netblock_type character varying DEFAULT 'default'::character varying, in_ip_universe_id integer DEFAULT 0, in_is_single_address character DEFAULT 'N'::bpchar, in_netblock_id integer DEFAULT NULL::integer, in_fuzzy_can_subnet boolean DEFAULT false, can_fix_can_subnet boolean DEFAULT false)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO jazzhands
AS $function$
DECLARE
	par_nbid	jazzhands.netblock.netblock_id%type;
BEGIN
	IF (in_netmask_bits IS NOT NULL) THEN
		in_IpAddress := set_masklen(in_IpAddress, in_Netmask_Bits);
	END IF;

	select  Netblock_Id
	  into	par_nbid
	  from  ( select Netblock_Id, Ip_Address
		    from jazzhands.netblock
		   where
		   	in_IpAddress <<= ip_address
		    and is_single_address = 'N'
			and netblock_type = in_netblock_type
			and ip_universe_id = in_ip_universe_id
		    and (
				(in_is_single_address = 'N' AND 
					masklen(ip_address) < masklen(In_IpAddress))
				OR
				(in_is_single_address = 'Y' AND can_subnet = 'N' AND
					(in_Netmask_Bits IS NULL 
						OR masklen(Ip_Address) = in_Netmask_Bits))
			)
			and (in_netblock_id IS NULL OR
				netblock_id != in_netblock_id)
		order by masklen(ip_address) desc
	) subq LIMIT 1;

	IF par_nbid IS NULL AND in_is_single_address = 'Y' AND in_fuzzy_can_subnet THEN
		select  Netblock_Id
		  into	par_nbid
		  from  ( select Netblock_Id, Ip_Address, Netmask_Bits
			    from jazzhands.netblock
			   where
			   	in_IpAddress <<= ip_address
			    and is_single_address = 'N'
				and netblock_type = in_netblock_type
				and ip_universe_id = in_ip_universe_id
			    and 
					(in_is_single_address = 'Y' AND can_subnet = 'Y' AND
						(in_Netmask_Bits IS NULL 
							OR masklen(Ip_Address) = in_Netmask_Bits))
				and (in_netblock_id IS NULL OR
					netblock_id != in_netblock_id)
				and netblock_id not IN (
					select parent_netblock_id from jazzhands.netblock 
						where is_single_address = 'N'
						and parent_netblock_id is not null
				)
			order by masklen(ip_address) desc
		) subq LIMIT 1;

		IF can_fix_can_subnet AND par_nbid IS NOT NULL THEN
			UPDATE netblock SET can_subnet = 'N' where netblock_id = par_nbid;
		END IF;
	END IF;


	return par_nbid;
END;
$function$
;

-- DONE WITH proc netblock_utils.find_best_parent_id -> find_best_parent_id 
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH proc person_manip.pick_login -> pick_login 

-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('person_manip', 'pick_login', 'pick_login');

-- DROP OLD FUNCTION
-- consider old oid 584763

-- RECREATE FUNCTION

-- DROP OLD FUNCTION (in case type changed)
-- consider old oid 584763
-- consider NEW oid 593420
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
    id				account.account_id%TYPE;
	fn		text;
	ln		text;
BEGIN
	-- remove special characters
	fn = regexp_replace(lower(in_first_name), '[^a-z]', '', 'g');
	ln = regexp_replace(lower(in_last_name), '[^a-z]', '', 'g');
	_acctrealmid := in_account_realm_id;
	-- Try first initial, last name
	_login = lpad(lower(fn), 1) || lower(ln);
	SELECT account_id into id FROM account where account_realm_id = _acctrealmid
		AND login = _login;

	IF id IS NULL THEN
		RETURN _login;
	END IF;

	-- Try first initial, middle initial, last name
	if in_middle_name IS NOT NULL THEN
		_login = lpad(lower(fn), 1) || lpad(lower(in_middle_name), 1) || lower(ln);
		SELECT account_id into id FROM account where account_realm_id = _acctrealmid
			AND login = _login;
		IF id IS NULL THEN
			RETURN _login;
		END IF;
	END IF;

	-- if length of first+last is <= 10 then try that.
	_login = lower(fn) || lower(ln);
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

-- DONE WITH proc person_manip.pick_login -> pick_login 
--------------------------------------------------------------------



--------------------------------------------------------------------
-- DEALING WITH TABLE v_acct_coll_acct_expanded [600750]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_acct_coll_acct_expanded', 'v_acct_coll_acct_expanded');
CREATE VIEW v_acct_coll_acct_expanded AS
 SELECT DISTINCT ace.account_collection_id,
    aca.account_id
   FROM v_acct_coll_expanded ace
     JOIN v_account_collection_account aca ON aca.account_collection_id = ace.root_account_collection_id;

delete from __recreate where type = 'view' and object = 'v_acct_coll_acct_expanded';
-- DONE DEALING WITH TABLE v_acct_coll_acct_expanded [616847]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_col_acct_col_unixgroup
CREATE OR REPLACE VIEW v_device_col_acct_col_unixgroup AS
 SELECT DISTINCT dchd.device_collection_id,
    ace.account_collection_id
   FROM v_device_coll_hier_detail dchd
     JOIN v_property dcu ON dcu.device_collection_id = dchd.parent_device_collection_id
     JOIN v_acct_coll_expanded ace ON dcu.account_collection_id = ace.root_account_collection_id
  WHERE dcu.property_name::text = 'UnixGroup'::text AND dcu.property_type::text = 'MclassUnixProp'::text;

delete from __recreate where type = 'view' and object = 'v_device_col_acct_col_unixgroup';
-- DONE DEALING WITH TABLE v_device_col_acct_col_unixgroup [593366]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_col_acct_col_unixlogin
CREATE OR REPLACE VIEW v_device_col_acct_col_unixlogin AS
 SELECT DISTINCT dchd.device_collection_id,
    dcu.account_collection_id,
    vuue.account_id
   FROM v_device_coll_hier_detail dchd
     JOIN v_property dcu ON dcu.device_collection_id = dchd.parent_device_collection_id
     JOIN v_acct_coll_acct_expanded vuue ON vuue.account_collection_id = dcu.account_collection_id
  WHERE dcu.property_name::text = 'UnixLogin'::text AND dcu.property_type::text = 'MclassUnixProp'::text;

delete from __recreate where type = 'view' and object = 'v_device_col_acct_col_unixlogin';
-- DONE DEALING WITH TABLE v_device_col_acct_col_unixlogin [593361]
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH TABLE v_corp_family_account [586078]
-- Save grants for later reapplication
SELECT schema_support.save_grants_for_replay('jazzhands', 'v_corp_family_account', 'v_corp_family_account');
CREATE OR REPLACE VIEW v_corp_family_account AS
 SELECT account.account_id,
    account.login,
    account.person_id,
    account.company_id,
    account.account_realm_id,
    account.account_status,
    account.account_role,
    account.account_type,
    account.description,
    account.data_ins_user,
    account.data_ins_date,
    account.data_upd_user,
    account.data_upd_date
   FROM account
  WHERE (account.account_realm_id IN ( SELECT property.account_realm_id
           FROM property
          WHERE property.property_name::text = '_root_account_realm_id'::text AND property.property_type::text = 'Defaults'::text));

delete from __recreate where type = 'view' and object = 'v_corp_family_account';
-- DONE DEALING WITH TABLE v_corp_family_account [593356]
--------------------------------------------------------------------

--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_unix_account_overrides
CREATE VIEW v_unix_account_overrides AS
 WITH perdevtomclass AS (
         SELECT hdc.device_collection_id AS host_device_collection_id,
            mdc.device_collection_id AS mclass_device_collection_id,
            hdcd.device_id
           FROM device_collection hdc
             JOIN device_collection_device hdcd USING (device_collection_id)
             JOIN device_collection_device mdcd USING (device_id)
             JOIN device_collection mdc ON mdcd.device_collection_id = mdc.device_collection_id
          WHERE hdc.device_collection_type::text = 'per-device'::text AND mdc.device_collection_type::text = 'mclass'::text
        ), dcmap AS (
         SELECT v_device_coll_hier_detail.device_collection_id,
            v_device_coll_hier_detail.parent_device_collection_id,
            v_device_coll_hier_detail.device_collection_level
           FROM v_device_coll_hier_detail
        UNION
         SELECT p.host_device_collection_id AS device_collection_id,
            d.parent_device_collection_id,
            d.device_collection_level
           FROM perdevtomclass p
             JOIN v_device_coll_hier_detail d ON d.device_collection_id = p.mclass_device_collection_id
        )
 SELECT property_list.device_collection_id,
    property_list.account_id,
    array_agg(property_list.setting ORDER BY property_list.rn) AS setting
   FROM ( SELECT select_for_ordering.device_collection_id,
            select_for_ordering.account_id,
            select_for_ordering.setting,
            row_number() OVER () AS rn
           FROM ( SELECT dc_acct_prop_list.device_collection_id,
                    dc_acct_prop_list.account_id,
                    unnest(ARRAY[dc_acct_prop_list.property_name, dc_acct_prop_list.property_value]) AS setting
                   FROM ( SELECT dchd.device_collection_id,
                            acae.account_id,
                            p.property_name,
                            COALESCE(p.property_value, p.property_value_password_type) AS property_value,
                            row_number() OVER (PARTITION BY dchd.device_collection_id, acae.account_id, acpe.property_name ORDER BY dchd.device_collection_level, acpe.assign_rank, acpe.property_id) AS ord
                           FROM v_acct_coll_prop_expanded acpe
                             JOIN v_acct_coll_acct_expanded acae USING (account_collection_id)
                             JOIN v_property p USING (property_id)
                             JOIN dcmap dchd ON dchd.parent_device_collection_id = p.device_collection_id
                          WHERE (p.property_type::text = ANY (ARRAY['UnixPasswdFileValue'::character varying, 'UnixGroupFileProperty'::character varying, 'MclassUnixProp'::character varying]::text[])) AND (p.property_name::text <> ALL (ARRAY['UnixLogin'::character varying, 'UnixGroup'::character varying, 'UnixGroupMemberOverride'::character varying]::text[]))) dc_acct_prop_list
                  WHERE dc_acct_prop_list.ord = 1) select_for_ordering) property_list
  GROUP BY property_list.device_collection_id, property_list.account_id;

delete from __recreate where type = 'view' and object = 'v_unix_account_overrides';
-- DONE DEALING WITH TABLE v_unix_account_overrides [593381]
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_col_account_cart
CREATE VIEW v_device_col_account_cart AS
 WITH x AS (
         SELECT v_device_col_acct_col_unixlogin.device_collection_id,
            v_device_col_acct_col_unixlogin.account_id,
            NULL::character varying[] AS setting
           FROM v_device_col_acct_col_unixlogin
             JOIN account USING (account_id)
             JOIN account_unix_info USING (account_id)
        UNION
         SELECT v_unix_account_overrides.device_collection_id,
            v_unix_account_overrides.account_id,
            v_unix_account_overrides.setting
           FROM v_unix_account_overrides
             JOIN account USING (account_id)
             JOIN account_unix_info USING (account_id)
             JOIN v_device_col_acct_col_unixlogin USING (device_collection_id, account_id)
        )
 SELECT xx.device_collection_id,
    xx.account_id,
    xx.setting
   FROM ( SELECT x.device_collection_id,
            x.account_id,
            x.setting,
            row_number() OVER (PARTITION BY x.device_collection_id, x.account_id ORDER BY x.setting) AS rn
           FROM x) xx
  WHERE xx.rn = 1;

delete from __recreate where type = 'view' and object = 'v_device_col_account_cart';
-- DONE DEALING WITH TABLE v_device_col_account_cart [593386]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_unix_group_overrides
CREATE VIEW v_unix_group_overrides AS
 WITH perdevtomclass AS (
         SELECT hdc.device_collection_id AS host_device_collection_id,
            mdc.device_collection_id AS mclass_device_collection_id,
            hdcd.device_id
           FROM device_collection hdc
             JOIN device_collection_device hdcd USING (device_collection_id)
             JOIN device_collection_device mdcd USING (device_id)
             JOIN device_collection mdc ON mdcd.device_collection_id = mdc.device_collection_id
          WHERE hdc.device_collection_type::text = 'per-device'::text AND mdc.device_collection_type::text = 'mclass'::text
        ), dcmap AS (
         SELECT v_device_coll_hier_detail.device_collection_id,
            v_device_coll_hier_detail.parent_device_collection_id,
            v_device_coll_hier_detail.device_collection_level
           FROM v_device_coll_hier_detail
        UNION
         SELECT p.host_device_collection_id AS device_collection_id,
            d.parent_device_collection_id,
            d.device_collection_level
           FROM perdevtomclass p
             JOIN v_device_coll_hier_detail d ON d.device_collection_id = p.mclass_device_collection_id
        )
 SELECT property_list.device_collection_id,
    property_list.account_collection_id,
    array_agg(property_list.setting ORDER BY property_list.rn) AS setting
   FROM ( SELECT select_for_ordering.device_collection_id,
            select_for_ordering.account_collection_id,
            select_for_ordering.setting,
            row_number() OVER () AS rn
           FROM ( SELECT dc_acct_prop_list.device_collection_id,
                    dc_acct_prop_list.account_collection_id,
                    unnest(ARRAY[dc_acct_prop_list.property_name, dc_acct_prop_list.property_value]) AS setting
                   FROM ( SELECT dchd.device_collection_id,
                            acpe.account_collection_id,
                            p.property_name,
                            COALESCE(p.property_value, p.property_value_password_type) AS property_value,
                            row_number() OVER (PARTITION BY dchd.device_collection_id, acpe.account_collection_id, acpe.property_name ORDER BY dchd.device_collection_level, acpe.assign_rank, acpe.property_id) AS ord
                           FROM v_acct_coll_prop_expanded acpe
                             JOIN unix_group ug USING (account_collection_id)
                             JOIN v_property p USING (property_id)
                             JOIN dcmap dchd ON dchd.parent_device_collection_id = p.device_collection_id
                          WHERE (p.property_type::text = ANY (ARRAY['UnixPasswdFileValue'::character varying, 'UnixGroupFileProperty'::character varying, 'MclassUnixProp'::character varying]::text[])) AND (p.property_name::text <> ALL (ARRAY['UnixLogin'::character varying, 'UnixGroup'::character varying, 'UnixGroupMemberOverride'::character varying]::text[]))) dc_acct_prop_list
                  WHERE dc_acct_prop_list.ord = 1) select_for_ordering) property_list
  GROUP BY property_list.device_collection_id, property_list.account_collection_id;

delete from __recreate where type = 'view' and object = 'v_unix_group_overrides';
-- DONE DEALING WITH TABLE v_unix_group_overrides [593396]
--------------------------------------------------------------------


--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_col_account_col_cart
CREATE VIEW v_device_col_account_col_cart AS
 WITH x AS (
         SELECT v_device_col_acct_col_unixgroup.device_collection_id,
            v_device_col_acct_col_unixgroup.account_collection_id,
            NULL::character varying[] AS setting
           FROM v_device_col_acct_col_unixgroup
             JOIN account_collection USING (account_collection_id)
             JOIN unix_group USING (account_collection_id)
        UNION
         SELECT v_unix_group_overrides.device_collection_id,
            v_unix_group_overrides.account_collection_id,
            v_unix_group_overrides.setting
           FROM v_unix_group_overrides
        )
 SELECT xx.device_collection_id,
    xx.account_collection_id,
    xx.setting
   FROM ( SELECT x.device_collection_id,
            x.account_collection_id,
            x.setting,
            row_number() OVER (PARTITION BY x.device_collection_id, x.account_collection_id ORDER BY x.setting) AS rn
           FROM x) xx
  WHERE xx.rn = 1;

delete from __recreate where type = 'view' and object = 'v_device_col_account_col_cart';
-- DONE DEALING WITH TABLE v_device_col_account_col_cart [593401]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_device_collection_account_ssh_key
CREATE VIEW v_device_collection_account_ssh_key AS
 SELECT allkeys.device_collection_id,
    allkeys.account_id,
    array_agg(allkeys.ssh_public_key) AS ssh_public_key
   FROM ( SELECT keylist.device_collection_id,
            keylist.account_id,
            keylist.ssh_public_key
           FROM ( SELECT dchd.device_collection_id,
                    ac.account_id,
                    ssh_key.ssh_public_key
                   FROM device_collection_ssh_key dcssh
                     JOIN ssh_key USING (ssh_key_id)
                     JOIN v_acct_coll_acct_expanded ac USING (account_collection_id)
                     JOIN account a USING (account_id)
                     JOIN v_device_coll_hier_detail dchd ON dchd.parent_device_collection_id = dcssh.device_collection_id
                UNION
                 SELECT NULL::integer AS device_collection_id,
                    ask.account_id,
                    skey.ssh_public_key
                   FROM account_ssh_key ask
                     JOIN ssh_key skey USING (ssh_key_id)) keylist
          ORDER BY keylist.account_id, COALESCE(keylist.device_collection_id, 0), keylist.ssh_public_key) allkeys
  GROUP BY allkeys.device_collection_id, allkeys.account_id;

delete from __recreate where type = 'view' and object = 'v_device_collection_account_ssh_key';
-- DONE DEALING WITH TABLE v_device_collection_account_ssh_key [593371]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH TABLE v_person_company_expanded [586046]
-- Save grants for later reapplication
SELECT schema_support.save_view_for_replay('jazzhands', 'v_person_company_expanded');
CREATE VIEW v_person_company_expanded AS
 WITH RECURSIVE var_recurse(level, root_company_id, company_id, parent_company_id, person_id, array_path, cycle) AS (
         SELECT 0 AS level,
            c.company_id AS root_company_id,
            c.company_id,
            c.parent_company_id,
            pc.person_id,
            ARRAY[c.company_id] AS array_path,
            false AS cycle
           FROM company c
             JOIN person_company pc USING (company_id)
        UNION ALL
         SELECT x.level + 1 AS level,
            x.root_company_id,
            c.company_id,
            c.parent_company_id,
            x.person_id,
            c.company_id || x.array_path AS array_path,
            c.company_id = ANY (x.array_path) AS cycle
           FROM var_recurse x
             JOIN company c ON x.parent_company_id = c.company_id
          WHERE NOT x.cycle
        )
 SELECT var_recurse.company_id,
    var_recurse.person_id
   FROM var_recurse;

delete from __recreate where type = 'view' and object = 'v_person_company_expanded';
-- DONE DEALING WITH TABLE v_person_company_expanded [593263]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_unix_mclass_settings
CREATE VIEW v_unix_mclass_settings AS
 SELECT property_list.device_collection_id,
    array_agg(property_list.setting ORDER BY property_list.rn) AS mclass_setting
   FROM ( SELECT select_for_ordering.device_collection_id,
            select_for_ordering.setting,
            row_number() OVER () AS rn
           FROM ( SELECT dc.device_collection_id,
                    unnest(ARRAY[dc.property_name, dc.property_value]) AS setting
                   FROM ( SELECT dcd.device_collection_id,
                            p.property_name,
                            COALESCE(p.property_value, p.property_value_password_type) AS property_value,
                            row_number() OVER (PARTITION BY dcd.device_collection_id, p.property_name ORDER BY dcd.device_collection_level, p.property_id) AS ord
                           FROM v_device_coll_hier_detail dcd
                             JOIN v_property p ON p.device_collection_id = dcd.parent_device_collection_id
                          WHERE p.property_type::text = 'MclassUnixProp'::text AND p.account_collection_id IS NULL) dc
                  WHERE dc.ord = 1) select_for_ordering) property_list
  GROUP BY property_list.device_collection_id;

delete from __recreate where type = 'view' and object = 'v_unix_mclass_settings';
-- DONE DEALING WITH TABLE v_unix_mclass_settings [593376]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_unix_passwd_mappings
CREATE VIEW v_unix_passwd_mappings AS
 WITH passtype AS (
         SELECT ap.account_id,
            ap.password,
            ap.expire_time,
            ap.change_time,
            subq.device_collection_id,
            subq.password_type,
            subq.ord
           FROM ( SELECT dchd.device_collection_id,
                    p.property_value_password_type AS password_type,
                    row_number() OVER (PARTITION BY dchd.device_collection_id) AS ord
                   FROM v_property p
                     JOIN v_device_coll_hier_detail dchd ON dchd.parent_device_collection_id = p.device_collection_id
                  WHERE p.property_name::text = 'UnixPwType'::text AND p.property_type::text = 'MclassUnixProp'::text) subq
             JOIN account_password ap USING (password_type)
             JOIN account_unix_info a USING (account_id)
          WHERE subq.ord = 1
        ), accts AS (
         SELECT a.account_id,
            a.login,
            a.person_id,
            a.company_id,
            a.account_realm_id,
            a.account_status,
            a.account_role,
            a.account_type,
            a.description,
            a.data_ins_user,
            a.data_ins_date,
            a.data_upd_user,
            a.data_upd_date,
            aui.unix_uid,
            aui.unix_group_acct_collection_id,
            aui.shell,
            aui.default_home
           FROM account a
             JOIN account_unix_info aui USING (account_id)
             JOIN val_person_status vps ON a.account_status::text = vps.person_status::text
          WHERE vps.is_disabled = 'N'::bpchar
        ), extra_groups AS (
         SELECT p.device_collection_id,
            acae.account_id,
            array_agg(ac.account_collection_name) AS group_names
           FROM v_property p
             JOIN device_collection dc USING (device_collection_id)
             JOIN account_collection ac USING (account_collection_id)
             JOIN account_collection pac ON pac.account_collection_id = p.property_value_account_coll_id
             JOIN v_acct_coll_acct_expanded acae ON pac.account_collection_id = acae.account_collection_id
          WHERE p.property_type::text = 'MclassUnixProp'::text AND p.property_name::text = 'UnixGroupMemberOverride'::text AND dc.device_collection_type::text <> 'mclass'::text
          GROUP BY p.device_collection_id, acae.account_id
        )
 SELECT s.device_collection_id,
    s.account_id,
    s.login,
    s.crypt,
    s.unix_uid,
    s.unix_group_name,
    regexp_replace(s.gecos, ' +'::text, ' '::text, 'g'::text) AS gecos,
    regexp_replace(
        CASE
            WHEN s.forcehome IS NOT NULL AND s.forcehome::text ~ '/$'::text THEN concat(s.forcehome, s.login)
            WHEN s.home IS NOT NULL AND s.home::text ~ '^/'::text THEN s.home::text
            WHEN s.hometype::text = 'generic'::text THEN concat(COALESCE(s.homeplace, '/home'::character varying), '/', 'generic')
            WHEN s.home IS NOT NULL AND s.home::text ~ '/$'::text THEN concat(s.home, '/', s.login)
            WHEN s.homeplace IS NOT NULL AND s.homeplace::text ~ '/$'::text THEN concat(s.homeplace, '/', s.login)
            ELSE concat(COALESCE(s.homeplace, '/home'::character varying), '/', s.login)
        END, '/+'::text, '/'::text, 'g'::text) AS home,
    s.shell,
    s.ssh_public_key,
    s.setting,
    s.mclass_setting,
    s.group_names AS extra_groups
   FROM ( SELECT o.device_collection_id,
            a.account_id,
            a.login,
            COALESCE(o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceCrypt'::text)]::text,
                CASE
                    WHEN pwt.expire_time IS NOT NULL AND now() < pwt.expire_time OR (now() - pwt.change_time) < concat(COALESCE((( SELECT v_property.property_value
                       FROM v_property
                      WHERE v_property.property_type::text = 'Defaults'::text AND v_property.property_name::text = '_maxpasswdlife'::text))::text, 90::text), 'days')::interval THEN pwt.password
                    ELSE NULL::character varying
                END::text, '*'::text) AS crypt,
            COALESCE(o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceUserUID'::text)]::integer, a.unix_uid) AS unix_uid,
            ugac.account_collection_name AS unix_group_name,
                CASE
                    WHEN a.description IS NOT NULL THEN a.description::text
                    ELSE concat(COALESCE(p.preferred_first_name, p.first_name), ' ',
                    CASE
                        WHEN p.middle_name IS NOT NULL AND length(p.middle_name::text) = 1 THEN concat(p.middle_name, '.')::character varying
                        ELSE p.middle_name
                    END, ' ', COALESCE(p.preferred_last_name, p.last_name), ' ')
                END AS gecos,
            COALESCE(o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceHome'::text)], a.default_home) AS home,
            COALESCE(o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceShell'::text)], a.shell) AS shell,
            o.setting,
            mcs.mclass_setting,
            o.setting[( SELECT i.i + 1
                   FROM generate_subscripts(o.setting, 1) i(i)
                  WHERE o.setting[i.i]::text = 'ForceHome'::text)] AS forcehome,
            mcs.mclass_setting[( SELECT i.i + 1
                   FROM generate_subscripts(mcs.mclass_setting, 1) i(i)
                  WHERE mcs.mclass_setting[i.i]::text = 'HomePlace'::text)] AS homeplace,
            mcs.mclass_setting[( SELECT i.i + 1
                   FROM generate_subscripts(mcs.mclass_setting, 1) i(i)
                  WHERE mcs.mclass_setting[i.i]::text = 'UnixHomeType'::text)] AS hometype,
            ssh.ssh_public_key,
            extra_groups.group_names
           FROM accts a
             JOIN v_device_col_account_cart o USING (account_id)
             JOIN device_collection dc USING (device_collection_id)
             JOIN person p USING (person_id)
             JOIN unix_group ug ON a.unix_group_acct_collection_id = ug.account_collection_id
             JOIN account_collection ugac ON ugac.account_collection_id = ug.account_collection_id
             LEFT JOIN extra_groups USING (device_collection_id, account_id)
             LEFT JOIN v_device_collection_account_ssh_key ssh ON a.account_id = ssh.account_id AND (ssh.device_collection_id IS NULL OR ssh.device_collection_id = o.device_collection_id)
             LEFT JOIN v_unix_mclass_settings mcs ON mcs.device_collection_id = dc.device_collection_id
             LEFT JOIN passtype pwt ON o.device_collection_id = pwt.device_collection_id AND a.account_id = pwt.account_id) s
  ORDER BY s.device_collection_id, s.account_id;

delete from __recreate where type = 'view' and object = 'v_unix_passwd_mappings';
-- DONE DEALING WITH TABLE v_unix_passwd_mappings [593391]
--------------------------------------------------------------------
--------------------------------------------------------------------
-- DEALING WITH NEW TABLE v_unix_group_mappings
CREATE VIEW v_unix_group_mappings AS
 WITH accts AS (
         SELECT a_1.account_id,
            a_1.login,
            a_1.person_id,
            a_1.company_id,
            a_1.account_realm_id,
            a_1.account_status,
            a_1.account_role,
            a_1.account_type,
            a_1.description,
            a_1.data_ins_user,
            a_1.data_ins_date,
            a_1.data_upd_user,
            a_1.data_upd_date
           FROM account a_1
             JOIN account_unix_info USING (account_id)
             JOIN val_person_status vps ON a_1.account_status::text = vps.person_status::text
          WHERE vps.is_disabled = 'N'::bpchar
        ), ugmap AS (
         SELECT dch.device_collection_id,
            vace.account_collection_id
           FROM v_property p
             JOIN v_device_coll_hier_detail dch ON p.device_collection_id = dch.parent_device_collection_id
             JOIN v_account_collection_expanded vace ON vace.root_account_collection_id = p.account_collection_id
          WHERE p.property_name::text = 'UnixGroup'::text AND p.property_type::text = 'MclassUnixProp'::text
        UNION
         SELECT dch.device_collection_id,
            uag.account_collection_id
           FROM v_property p
             JOIN v_device_coll_hier_detail dch ON p.device_collection_id = dch.parent_device_collection_id
             JOIN v_acct_coll_acct_expanded vace USING (account_collection_id)
             JOIN accts a_1 ON vace.account_id = a_1.account_id
             JOIN account_unix_info aui ON a_1.account_id = aui.account_id
             JOIN unix_group ug ON ug.account_collection_id = aui.unix_group_acct_collection_id
             JOIN account_collection uag ON ug.account_collection_id = uag.account_collection_id
          WHERE p.property_name::text = 'UnixLogin'::text AND p.property_type::text = 'MclassUnixProp'::text
        ), dcugm AS (
         SELECT dch.device_collection_id,
            p.account_collection_id,
            aca.account_id
           FROM v_property p
             JOIN unix_group ug USING (account_collection_id)
             JOIN v_device_coll_hier_detail dch ON p.device_collection_id = dch.parent_device_collection_id
             JOIN v_acct_coll_acct_expanded aca ON p.property_value_account_coll_id = aca.account_collection_id
          WHERE p.property_name::text = 'UnixGroupMemberOverride'::text AND p.property_type::text = 'MclassUnixProp'::text
        ), grp_members AS (
         SELECT actoa.account_id,
            actoa.device_collection_id,
            actoa.account_collection_id,
            ui.unix_uid,
            ui.unix_group_acct_collection_id,
            ui.shell,
            ui.default_home,
            ui.data_ins_user,
            ui.data_ins_date,
            ui.data_upd_user,
            ui.data_upd_date,
            a_1.login,
            a_1.person_id,
            a_1.company_id,
            a_1.account_realm_id,
            a_1.account_status,
            a_1.account_role,
            a_1.account_type,
            a_1.description,
            a_1.data_ins_user,
            a_1.data_ins_date,
            a_1.data_upd_user,
            a_1.data_upd_date
           FROM ( SELECT dc_1.device_collection_id,
                    ae.account_collection_id,
                    ae.account_id
                   FROM device_collection dc_1,
                    v_acct_coll_acct_expanded ae
                     JOIN unix_group unix_group_1 USING (account_collection_id)
                     JOIN account_collection inac USING (account_collection_id)
                  WHERE dc_1.device_collection_type::text = 'mclass'::text
                UNION
                 SELECT dcugm.device_collection_id,
                    dcugm.account_collection_id,
                    dcugm.account_id
                   FROM dcugm) actoa
             JOIN account_unix_info ui USING (account_id)
             JOIN accts a_1 USING (account_id)
        ), grp_accounts AS (
         SELECT g.account_id,
            g.device_collection_id,
            g.account_collection_id,
            g.unix_uid,
            g.unix_group_acct_collection_id,
            g.shell,
            g.default_home,
            g.data_ins_user,
            g.data_ins_date,
            g.data_upd_user,
            g.data_upd_date,
            g.login,
            g.person_id,
            g.company_id,
            g.account_realm_id,
            g.account_status,
            g.account_role,
            g.account_type,
            g.description,
            g.data_ins_user_1 AS data_ins_user,
            g.data_ins_date_1 AS data_ins_date,
            g.data_upd_user_1 AS data_upd_user,
            g.data_upd_date_1 AS data_upd_date
           FROM grp_members g(account_id, device_collection_id, account_collection_id, unix_uid, unix_group_acct_collection_id, shell, default_home, data_ins_user, data_ins_date, data_upd_user, data_upd_date, login, person_id, company_id, account_realm_id, account_status, account_role, account_type, description, data_ins_user_1, data_ins_date_1, data_upd_user_1, data_upd_date_1)
             JOIN accts USING (account_id)
             JOIN v_unix_passwd_mappings USING (device_collection_id, account_id)
        )
 SELECT dc.device_collection_id,
    ac.account_collection_id,
    ac.account_collection_name AS group_name,
    COALESCE(o.setting[( SELECT i.i + 1
           FROM generate_subscripts(o.setting, 1) i(i)
          WHERE o.setting[i.i]::text = 'ForceGroupGID'::text)]::integer, unix_group.unix_gid) AS unix_gid,
    unix_group.group_password,
    o.setting,
    mcs.mclass_setting,
    array_agg(DISTINCT a.login ORDER BY a.login) AS members
   FROM device_collection dc
     JOIN ugmap USING (device_collection_id)
     JOIN account_collection ac USING (account_collection_id)
     JOIN unix_group USING (account_collection_id)
     LEFT JOIN v_device_col_account_col_cart o USING (device_collection_id, account_collection_id)
     LEFT JOIN grp_accounts a(account_id, device_collection_id, account_collection_id, unix_uid, unix_group_acct_collection_id, shell, default_home, data_ins_user, data_ins_date, data_upd_user, data_upd_date, login, person_id, company_id, account_realm_id, account_status, account_role, account_type, description, data_ins_user_1, data_ins_date_1, data_upd_user_1, data_upd_date_1) USING (device_collection_id, account_collection_id)
     LEFT JOIN v_unix_mclass_settings mcs ON mcs.device_collection_id = dc.device_collection_id
  GROUP BY dc.device_collection_id, ac.account_collection_id, ac.account_collection_name, unix_group.unix_gid, unix_group.group_password, o.setting, mcs.mclass_setting
  ORDER BY dc.device_collection_id, ac.account_collection_id;

delete from __recreate where type = 'view' and object = 'v_unix_group_mappings';
-- DONE DEALING WITH TABLE v_unix_group_mappings [593406]
--------------------------------------------------------------------


-- Dropping obsoleted sequences....


-- Dropping obsoleted audit sequences....


-- Processing tables with no structural changes
-- Some of these may be redundant
-- fk constraints
-- triggers

-- wtf
alter table netblock_collection_netblock
	rename constraint pk_account_collection_account to
		pk_netblock_collecton_netblock;

alter table device_collection
	rename constraint pk_networkdevicecoll to
		pk_device_collection;

alter table netblock_collection_netblock
	rename constraint pk_netblock_collecton_netblock to
		pk_netblock_collection_netbloc;

ALTER TABLE NETWORK_INTERFACE_NETBLOCK
	ADD CONSTRAINT FK_NETINT_NB_NBLK_ID 
	FOREIGN KEY (NETWORK_INTERFACE_ID) 
	REFERENCES NETWORK_INTERFACE (NETWORK_INTERFACE_ID)  
	DEFERRABLE  INITIALLY IMMEDIATE;

-- consider FK service_environment and sw_package_release
ALTER TABLE sw_package_release
	ADD CONSTRAINT fk_sw_pkg_rel_ref_vsvcenv
 	FOREIGN KEY (service_environment_id) REFERENCES service_environment(service_environment_id);

DROP TRIGGER IF EXISTS trigger_check_device_collection_hier_loop ON device_collection_hier;
DROP TRIGGER IF EXISTS trigger_check_svcenv_collection_hier_loop ON service_environment_coll_hier;
DROP TRIGGER IF EXISTS trigger_check_token_collection_hier_loop ON token_collection_hier;
DROP TRIGGER IF EXISTS trigger_del_v_corp_family_account ON v_corp_family_account;
DROP TRIGGER IF EXISTS trigger_dns_record_cname_checker ON dns_record;
DROP TRIGGER IF EXISTS trigger_ins_v_corp_family_account ON v_corp_family_account;
DROP TRIGGER IF EXISTS trigger_net_int_nb_single_address ON network_interface;
DROP TRIGGER IF EXISTS trigger_net_int_netblock_to_nbn_compat_after ON network_interface;
DROP TRIGGER IF EXISTS trigger_net_int_netblock_to_nbn_compat_before ON network_interface;
DROP TRIGGER IF EXISTS trigger_netblock_single_address_ni ON netblock;
DROP TRIGGER IF EXISTS trigger_network_interface_drop_tt_netint_ni ON network_interface;
DROP TRIGGER IF EXISTS trigger_upd_v_corp_family_account ON v_corp_family_account;

CREATE TRIGGER trigger_check_device_collection_hier_loop AFTER INSERT OR UPDATE ON device_collection_hier FOR EACH ROW EXECUTE PROCEDURE check_device_colllection_hier_loop();
CREATE TRIGGER trigger_check_svcenv_collection_hier_loop AFTER INSERT OR UPDATE ON service_environment_coll_hier FOR EACH ROW EXECUTE PROCEDURE check_svcenv_colllection_hier_loop();
CREATE TRIGGER trigger_check_token_collection_hier_loop AFTER INSERT OR UPDATE ON token_collection_hier FOR EACH ROW EXECUTE PROCEDURE check_token_colllection_hier_loop();
CREATE TRIGGER trigger_del_v_corp_family_account INSTEAD OF DELETE ON v_corp_family_account FOR EACH ROW EXECUTE PROCEDURE del_v_corp_family_account();
CREATE TRIGGER trigger_dns_record_cname_checker BEFORE INSERT OR UPDATE OF dns_type ON dns_record FOR EACH ROW EXECUTE PROCEDURE dns_record_cname_checker();
CREATE TRIGGER trigger_ins_v_corp_family_account INSTEAD OF INSERT ON v_corp_family_account FOR EACH ROW EXECUTE PROCEDURE ins_v_corp_family_account();
CREATE TRIGGER trigger_net_int_nb_single_address BEFORE INSERT OR UPDATE OF netblock_id ON network_interface FOR EACH ROW EXECUTE PROCEDURE net_int_nb_single_address();
--   CREATE TRIGGER trigger_net_int_netblock_to_nbn_compat_after AFTER INSERT OR DELETE OR UPDATE OF network_interface_id, netblock_id ON network_interface FOR EACH ROW EXECUTE PROCEDURE net_int_netblock_to_nbn_compat_after();
--   CREATE TRIGGER trigger_net_int_netblock_to_nbn_compat_before BEFORE DELETE ON network_interface FOR EACH ROW EXECUTE PROCEDURE net_int_netblock_to_nbn_compat_before();
CREATE TRIGGER trigger_netblock_single_address_ni BEFORE UPDATE OF is_single_address, netblock_type ON netblock FOR EACH ROW EXECUTE PROCEDURE netblock_single_address_ni();
--    CREATE TRIGGER trigger_network_interface_drop_tt_netint_ni AFTER INSERT OR DELETE OR UPDATE ON network_interface FOR EACH STATEMENT EXECUTE PROCEDURE network_interface_drop_tt();
CREATE TRIGGER trigger_upd_v_corp_family_account INSTEAD OF UPDATE ON v_corp_family_account FOR EACH ROW EXECUTE PROCEDURE upd_v_corp_family_account();

-- just in case they were here since they were redone above. 
delete from __recreate where 
	ddl ~ 'trigger_check_device_collection_hier_loop' OR
	ddl ~ 'trigger_check_svcenv_collection_hier_loop' OR
	ddl ~ 'trigger_check_token_collection_hier_loop' OR
	ddl ~ 'trigger_del_v_corp_family_account' OR
	ddl ~ 'trigger_dns_record_cname_checker' OR
	ddl ~ 'trigger_ins_v_corp_family_account' OR
	ddl ~ 'trigger_net_int_nb_single_address' OR
	ddl ~ 'trigger_net_int_netblock_to_nbn_compat_after' OR
	ddl ~ 'trigger_net_int_netblock_to_nbn_compat_before' OR
	ddl ~ 'trigger_netblock_single_address_ni' OR
	ddl ~ 'trigger_network_interface_drop_tt_netint_ni' OR
	ddl ~ 'trigger_upd_v_corp_family_account';


update __regrants set
	regrant = regexp_replace(regrant, 'allocate_netblock\([^\)]+\)',
'allocate_netblock(parent_netblock_id integer, netmask_bits integer, address_type text, can_subnet boolean, allocation_method text, rnd_masklen_threshold integer, rnd_max_count integer, ip_address inet, description character varying, netblock_status character varying)')
where object = 'allocate_netblock'
and schema = 'netblock_manip';

update __regrants set
	regrant = regexp_replace(regrant, 'add_person\([^\)]+\)',
'add_person(__person_id integer, first_name character varying, middle_name character varying, last_name character varying, name_suffix character varying, gender character varying, preferred_last_name character varying, preferred_first_name character varying, birth_date date, _company_id integer, external_hr_id character varying, person_company_status character varying, is_manager character varying, is_exempt character varying, is_full_time character varying, employee_id character varying, hire_date date, termination_date date, person_company_relation character varying, job_title character varying, department character varying, login character varying, OUT _person_id integer, OUT _account_collection_id integer, OUT _account_id integer)')
where object = 'add_person'
and schema = 'person_manip';

drop index if exists idx_netblock_host_ip_address;
create index idx_netblock_host_ip_address  ON netblock
USING btree (host(ip_address));


--
-- stuff that should not be replayed (grants should)
--
DROP FUNCTION IF EXISTS  netblock_utils.find_free_netblock(integer, integer, boolean, boolean);
delete from __recreate where schema = 'jazzhands' and object = 'validate_netblock_parentage';

-- Clean Up
SELECT schema_support.replay_object_recreates();
SELECT schema_support.replay_saved_grants();

-- RAISE EXCEPTION 'Not done';
SELECT schema_support.end_maintenance();
