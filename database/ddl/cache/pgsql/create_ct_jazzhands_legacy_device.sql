--
-- Copyright (c) 2020 Todd M. Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--

--
-- This is expected to go away and can probably be optimized to run on
-- each row changed and not just after all the table changes in a statement.
--
--

CREATE OR REPLACE VIEW jazzhands_cache.v_jazzhands_legacy_device_support AS
	SELECT device_id,
	CASE WHEN is_monitored > 0 THEN 'Y'::text ELSE 'N'::text
		END AS is_monitored,
	CASE WHEN should_fetch_config > 0 THEN 'Y'::text ELSE 'N'::text
		END AS should_fetch_config,
	CASE WHEN is_locally_managed > 0 THEN 'Y'::text ELSE 'N'::text
		END AS is_locally_managed,
	auto_mgmt_protocol
	FROM device LEFT JOIN
	(
		SELECT device_id,
			count(device_collection_id) FILTER (
				WHERE property_name = 'IsMonitoredDevice')
				AS is_monitored,
			count(device_collection_id) FILTER (
				WHERE property_name = 'ShouldConfigFetch')
				AS should_fetch_config,
			count(device_collection_id) FILTER (
				WHERE property_name = 'IsLocallyManagedDevice')
				AS is_locally_managed,
			min(property_value) FILTER (
				WHERE property_name = 'AutoMgmtProtocol') AS auto_mgmt_protocol
		FROM device_collection
			JOIN device_collection_device USING (device_collection_id)
			JOIN property USING (device_collection_id)
		WHERE property_type = 'JazzHandsLegacySupport'
			AND property_name IN ('IsMonitoredDevice',
				'ShouldConfigFetch',
				'IsLocallyManagedDevice',
				'AutoMgmtProtocol')
		GROUP BY 1
	) maps  USING (device_id)
;

SELECT * FROM schema_support.create_cache_table(
        cache_table_schema := 'jazzhands_cache',
        cache_table := 'ct_jazzhands_legacy_device_support',
        defining_view_schema := 'jazzhands_cache',
        defining_view := 'v_jazzhands_legacy_device_support',
	force := true
);


CREATE INDEX ix_jazzhands_legacy_device_device_id ON
	jazzhands_cache.ct_jazzhands_legacy_device_support(device_id);

ALTER TABLE jazzhands_cache.ct_jazzhands_legacy_device_support
ADD
PRIMARY KEY (device_id);


CREATE OR REPLACE FUNCTION jazzhands_cache.refresh_jazzhands_legacy_device_support(
	purge boolean default FALSE
) RETURNS void AS
$$
DECLARE
	i integer;
BEGIN
	IF purge THEN
		TRUNCATE TABLE jazzhands_cache.ct_jazzhands_legacy_device_support;
	END IF;

	DELETE FROM  jazzhands_cache.ct_jazzhands_legacy_device_support
	WHERE device_id NOT IN (select device_id FROM jazzhands.device);

	UPDATE jazzhands_cache.ct_jazzhands_legacy_device_support  ct
		SET is_monitored = v.is_monitored,
			should_fetch_config = v.should_fetch_config,
			is_locally_managed = v.is_locally_managed,
			auto_mgmt_protocol = v.auto_mgmt_protocol
	FROM jazzhands_cache.v_jazzhands_legacy_device_support v
	WHERE ct.device_id = v.device_id;

	INSERT INTO jazzhands_cache.ct_jazzhands_legacy_device_support
	SELECT * FROM jazzhands_cache.v_jazzhands_legacy_device_support
	WHERE device_id NOT IN (
		SELECT device_id FROM jazzhands_cache.ct_jazzhands_legacy_device_support
	);
END
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO jazzhands_legacy;


CREATE OR REPLACE FUNCTION jazzhands_cache.jazzhands_legacy_device_columns()
RETURNS TRIGGER AS $$
BEGIN
	--
	-- This should become per-row and only fire if it's an interesting
	-- device collection type.  Now it fires always, and is a bit heavy
	-- handed,
	PERFORM jazzhands_cache.refresh_jazzhands_legacy_device_support();
	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	END IF;
	RETURN NEW;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=jazzhands;

DROP TRIGGER IF EXISTS zz_trigger_jazzhands_legacy_device_columns_after
	 ON device_collection_device;
CREATE TRIGGER zz_trigger_jazzhands_legacy_device_columns_after
	AFTER INSERT OR UPDATE OR DELETE
	ON device_collection_device
	EXECUTE PROCEDURE jazzhands_cache.jazzhands_legacy_device_columns();

-- run this on device, too
-- This populates when a device is created so joins work

CREATE OR REPLACE FUNCTION jazzhands_cache.jazzhands_legacy_device_setup()
RETURNS TRIGGER AS $$
BEGIN
		PERFORM jazzhands_cache.refresh_jazzhands_legacy_device_support();
		IF TG_OP = 'DELETE' THEN
			RETURN OLD;
		END IF;
		RETURN NEW;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=jazzhands;

DROP TRIGGER IF EXISTS zz_trigger_jazzhands_legacy_device_setup_after
	 ON device;
CREATE TRIGGER zz_trigger_jazzhands_legacy_device_setup_after
	AFTER INSERT OR UPDATE OR DELETE
	ON device
	EXECUTE PROCEDURE jazzhands_cache.jazzhands_legacy_device_setup();





