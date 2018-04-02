\set ON_ERROR_STOP

rollback;
begin;
set search_path=cloudapi,jazzhands;




/*

 cloudapi | gslb_group
 cloudapi | gslb_ip_address
 cloudapi | gslb_name
 cloudapi | gslb_name_gslb_group

These two need to be considered after the configuration data is done.  They
are not presently restored in a default dev db.

 cloudapi | gslb_resource_state
 cloudapi | gslb_resource_state_log

*/

CREATE TABLE cloud_jazz.gslb_zone (
	dns_domain_Id	integer,
	customer_id		integer,
	metadata		TEXT,
	primary key (dns_domain_id)
);

----------------------------------------------------------------------------
--
-- stuff that needs to be cleaned up
--
-- XXX NOTE: Some zones were deleted and recreated and that needs to be handled
-- correctlyish, _including_ renumbering of zones.
--
--
-- also figure out how to deal with things that appear in both regular domains
-- and gslb (such as devnxs.net).
--

DELETE FROM gslb_ip_address WHERE gslb_group_id IN
	(SELECT id FROM gslb_group WHERE is_deleted = 1);

DELETE FROM gslb_group WHERE is_deleted = 1;

DELETE FROM gslb_name WHERE is_deleted = 1;

DELETE FROM gslb_zone WHERE is_deleted = 1;

DELETE FROM gslb_ip_address WHERE gslb_group_id 
	NOT IN (SELECT gslb_group_id FROM gslb_name_gslb_group );

DELETE FROM gslb_group WHERE id 
	NOT IN (SELECT gslb_group_id FROM gslb_name_gslb_group );

savepoint cleanup;

----------------------------------------------------------------------------

--- XXX need an enforced "can_generate" on this, I think.
INSERT INTO val_dns_domain_type (
	dns_domain_type, description
) VALUES (
	'gslb', 'domain used for gslb'
);


--
-- gslb_zone -> dns_domain
--
DO $$
DECLARE
	myrole	TEXT;
	_t		INTEGER;
BEGIN
	SELECT current_role INTO myrole;

	SET role = dba;

	SET constraints ALL deferred;
	ALTER TABLE jazzhands.dns_domain DISABLE TRIGGER trig_userlog_dns_domain;
	ALTER TABLE gslb_name DROP CONSTRAINT gslb_name_gslb_zone_id_fkey;
	ALTER TABLE gslb_zone DROP CONSTRAINT gslb_zone_pkey;

	WITH gzone AS (
		SELECT *,
		row_number() OVER (ORDER BY id) AS rn
		FROM gslb_zone ORDER BY id
	), newdoms AS (
		INSERT INTO dns_domain (
			dns_domain_name, dns_domain_type, description,
			data_ins_user, data_ins_date
		) SELECT zone, 'gslb', description, myrole, created_on
		FROM gzone
		ORDER BY id
		RETURNING *
	), newrn AS (
		SELECT *,
		row_number() OVER (ORDER BY dns_domain_id) AS rn
		FROM newdoms
	), map AS (
		SELECT dns_domain_id, id as gslb_zone_id
		FROM gzone JOIN newrn USING (rn)
	), updatezonename  AS (
		UPDATE gslb_name n
		SET gslb_zone_id = map.dns_domain_id
		FROM map WHERE map.gslb_zone_id = n.gslb_zone_id
		RETURNING *
	), updatezone AS (
		UPDATE gslb_zone z
		SET id = map.dns_domain_id
		FROM map WHERE map.gslb_zone_id = z.id
		RETURNING *
	), u as (
		select count(*) FROM updatezonename
		UNION select count(*) FROM updatezone
	) select Count(*) INTO _t FROM u;

	ALTER TABLE gslb_zone
		ADD CONSTRAINT gslb_zone_pkey
		PRIMARY KEY (id);

	ALTER TABLE gslb_name
		ADD CONSTRAINT gslb_name_gslb_zone_id_fkey
		FOREIGN KEY (gslb_zone_id)
		REFERENCES gslb_zone(id);

	SET constraints ALL IMMEDIATE;

	ALTER TABLE jazzhands.dns_domain ENABLE TRIGGER trig_userlog_dns_domain;
	EXECUTE 'SET role ' || myrole;

	INSERT INTO cloud_jazz.gslb_zone (
		dns_domain_id, customer_id, metadata
	) SELECT id, customer_id,metadata FROM gslb_zone ORDER BY id;
END;
$$
;

CREATE VIEW gslb_zone_new AS 
SELECT
	dns_domain_id AS id,
	data_ins_date::timestamp without time zone AS created_on,
	dns_domain_name AS zone,
	customer_id,
	description,
	metadata
FROM	jazzhands.dns_domain
	JOIN cloud_jazz.gslb_zone USING (dns_domain_id)
WHERE dns_domain_type = 'gslb'
;

savepoint gslbzone;
SELECT schema_support.relation_diff (
        schema := 'cloudapi',
        old_rel := 'gslb_zone',
        new_rel := 'gslb_zone_new',
        prikeys := ARRAY['id']
);

