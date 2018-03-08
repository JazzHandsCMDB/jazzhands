/*
 * Copyright (c) 2018 Todd Kover
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

\set ON_ERROR_STOP

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION site_netblock_ins()
RETURNS TRIGGER AS $$
DECLARE
	_tally	INTEGER;
BEGIN
	WITH i AS (
		INSERT INTO netblock_collection_netblock
			(netblock_collection_id, netblock_id)
		SELECT netblock_collection_id, NEW.netblock_id
			FROM property
			WHERE property_type = 'automated'
			AND property_name = 'per-site-netblock_collection'
			AND site_code = NEW.site_code
		RETURNING *
	) SELECT count(*) INTO _tally FROM i;

	IF _tally != 1 THEN
		RAISE 'Inserted % rows, not 1.', _tally;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_site_netblock_ins
	ON site_netblock;
CREATE TRIGGER trigger_site_netblock_ins
	INSTEAD OF INSERT ON site_netblock
	FOR EACH ROW
	EXECUTE PROCEDURE site_netblock_ins();

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION site_netblock_upd()
RETURNS TRIGGER AS $$
DECLARE
	upd_query	TEXT[];
BEGIN
	upd_query := NULL;
	IF OLD.site_code != NEW.site_code THEN
		upd_query := array_append(upd_query,
			'netblock_collection_id = ' ||
				( SELECT netblock_collection_id
					FROM property
					WHERE property_type = 'automated'
					AND property_name = 'per-site-netblock_collection'
					AND site_code = NEW.site_code
				)
		);
	END IF;

	IF OLD.netblock_id != NEW.netblock_id THEN
		upd_query := array_append(upd_query,
			'netblock_id = ' || NEW.netblock_id
		);
	END IF;

	IF upd_query IS NOT NULL THEN
		EXECUTE 'UPDATE netblock_collection_netblock SET ' ||
			array_to_string(upd_query, ', ') ||
			' WHERE netblock_id = $1 
				AND netblock_collection_id IN 
				( SELECT netblock_collection_id
					FROM property
					WHERE property_type = $3
					AND property_name = $4
					AND site_code = $2
				)
			RETURNING *'
			USING OLD.netblock_id, OLD.site_code,
				'automated', 'per-site-netblock_collection';
	END IF;
	RETURN NEW;

END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_site_netblock_upd
	ON site_netblock;
CREATE TRIGGER trigger_site_netblock_upd
	INSTEAD OF UPDATE ON site_netblock
	FOR EACH ROW
	EXECUTE PROCEDURE site_netblock_upd();

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION site_netblock_del()
RETURNS TRIGGER AS $$
DECLARE
BEGIN
	DELETE FROM netblock_collection_netblock
	WHERE netblock_collection_id IN (
		SELECT netblock_collection_id
			FROM property
			WHERE property_type = 'automated'
			AND property_name = 'per-site-netblock_collection'
			AND site_code = OLD.site_code
		)
	AND netblock_id = OLD.netblock_id;

	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_site_netblock_del
	ON site_netblock;
CREATE TRIGGER trigger_site_netblock_del
	INSTEAD OF DELETE ON site_netblock
	FOR EACH ROW
	EXECUTE PROCEDURE site_netblock_del();

---------------------------------------------------------------------------
---------------------------------------------------------------------------
--
-- triggers below are on site
--
--
---------------------------------------------------------------------------
---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ins_site_netblock_collections()
RETURNS TRIGGER AS $$
DECLARE
	_hate	INTEGER;
BEGIN

	WITH nc AS (
		INSERT INTO netblock_collection (
			netblock_collection_name, netblock_collection_type
		) VALUES (
			NEW.site_code, 'per-site'
		) RETURNING *
	), p AS (
		INSERT INTO property (
			property_name, property_type, site_code,
			netblock_collection_id
		) SELECT
			'per-site-netblock_collection', 'automated', NEW.site_code,
			netblock_collection_id
			FROM nc
		RETURNING *
	) SELECT count(*) INTO _hate FROM p;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;


DROP TRIGGER IF EXISTS trigger_ins_site_netblock_collections ON dns_record;
CREATE TRIGGER trigger_ins_site_netblock_collections
	AFTER INSERT 
	ON site
	FOR EACH ROW
	EXECUTE PROCEDURE ins_site_netblock_collections();

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION upd_site_netblock_collections()
RETURNS TRIGGER AS $$
BEGIN
	--
	-- The property site_code is not adjusted here because that's a fk
	-- that anything renaming the site code would need to deal with
	-- if renaming a property and that is just too confusing.
	--
	UPDATE netblock_collection
		SET netblock_collection_name = NEW.site_code
		WHERE netblock_collection_name = OLD.site_code
		AND netblock_collection_type = 'per-site';

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_upd_site_netblock_collections ON dns_record;
CREATE TRIGGER trigger_upd_site_netblock_collections
	AFTER UPDATE 
	ON site
	FOR EACH ROW
	EXECUTE PROCEDURE upd_site_netblock_collections();

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION del_site_netblock_collections()
RETURNS TRIGGER AS $$
DECLARE
	_hate	INTEGER;
BEGIN
	WITH p AS (
		DELETE FROM property
		WHERE property_type = 'automated'
		AND property_name = 'per-site-netblock_collection'
		AND site_code = OLD.site_code
		RETURNING *
	),  nc AS (
		DELETE FROM netblock_collection
		WHERE netblock_collection_id IN (
			SELECT netblock_collection_id from p
		)
		RETURNING *
	) SELECT count(*) INTO _hate FROM nc;

	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;


DROP TRIGGER IF EXISTS trigger_del_site_netblock_collections ON dns_record;
CREATE TRIGGER trigger_del_site_netblock_collections
	BEFORE DELETE
	ON site
	FOR EACH ROW
	EXECUTE PROCEDURE del_site_netblock_collections();

---------------------------------------------------------------------------
