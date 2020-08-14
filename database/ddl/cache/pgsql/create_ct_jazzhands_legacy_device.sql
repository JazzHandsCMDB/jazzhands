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


----------------------------------------------------------------------------
--
-- This function is used by the cahce proess to make everything right.  This
-- is not what is used by the triggers.
--
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

SELECT jazzhands_cache.refresh_jazzhands_legacy_device_support();

----------------------------------------------------------------------------
----------------------------------------------------------------------------
--
-- Changes for ongoing triggers
--
----------------------------------------------------------------------------
----------------------------------------------------------------------------

-- XXX - make sure that I have the right triggers doing the right thing.

--
-- This never happens on jazzhands.device INSERTS because the columns aren't
-- there.  It only matters on deletes and updates.
--
----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION jazzhands_cache.jazzhands_legacy_device_columns_device_ins()
RETURNS TRIGGER AS $$
DECLARE
	_r	RECORD;
BEGIN
	-- RAISE NOTICE 'inserting cache record for %...', NEW.device_id;
	INSERT INTO jazzhands_cache.ct_jazzhands_legacy_device_support
		VALUES (NEW.device_id, 'N', 'N','N');
	RETURN NEW;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=jazzhands;

DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_device_ins
	 ON device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_device_ins
	AFTER INSERT
	ON device
	FOR EACH ROW
	EXECUTE PROCEDURE
		jazzhands_cache.jazzhands_legacy_device_columns_device_ins();

----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION jazzhands_cache.jazzhands_legacy_device_columns_device_del()
RETURNS TRIGGER AS $$
DECLARE
	_r	RECORD;
BEGIN
	-- RAISE NOTICE 'delete cache record for %...', OLD.device_id;
	DELETE FROM jazzhands_cache.ct_jazzhands_legacy_device_support
	WHERE device_id = OLD.device_id;
	RETURN OLD;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=jazzhands;

DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_device_del
	 ON device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_device_del
	BEFORE DELETE
	ON device
	FOR EACH ROW
	EXECUTE PROCEDURE
		jazzhands_cache.jazzhands_legacy_device_columns_device_del();

----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION jazzhands_cache.jazzhands_legacy_device_columns_device_upd()
RETURNS TRIGGER AS $$
DECLARE
	_tally	INTEGER;
BEGIN
	IF OLD.device_id != NEW.device_id THEN
		RAISE EXCEPTION 'device_id can not be changed at this time.'
			USING ERRCODE = 'error_in_assignment';
	END IF;
	RETURN NEW;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=jazzhands;

DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_device_upd
	 ON device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_device_upd
	AFTER UPDATE
	ON device
	FOR EACH ROW
	EXECUTE PROCEDURE
		jazzhands_cache.jazzhands_legacy_device_columns_device_upd();

----------------------------------------------------------------------------
----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION jazzhands_cache.jazzhands_legacy_device_columns_dcd_ins()
RETURNS TRIGGER AS $$
DECLARE
	_r	RECORD;
	_uq	TEXT[];
BEGIN
	-- RAISE NOTICE 'Inserting cache record for dc#% %...', NEW.device_collection_id, NEW.device_id;
	FOR _r IN SELECT * FROM property
		WHERE device_collection_id = NEW.device_collection_id
		AND property_type = 'JazzHandsLegacySupport'
	LOOP
		IF _r.property_name = 'IsMonitoredDevice' THEN
			_uq := array_append(_uq, 'is_monitored = ' ||
				quote_nullable('Y'));
		END IF;
		IF _r.property_name = 'ShouldConfigFetch' THEN
			_uq := array_append(_uq, 'should_fetch_config = ' ||
				quote_nullable('Y'));
		END IF;
		IF _r.property_name = 'IsLocallyManagedDevice' THEN
			_uq := array_append(_uq, 'is_locally_managed = ' ||
				quote_nullable('Y'));
		END IF;
		IF _r.property_name = 'AutoMgmtProtocol' THEN
			_uq := array_append(_uq, 'auto_mgmt_protocol = ' ||
				quote_nullable(_r.property_value));
		END IF;
	END LOOP;
	IF _uq IS NOT NULL THEN
		EXECUTE
			'UPDATE jazzhands_cache.ct_jazzhands_legacy_device_support SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  device_id = $1 RETURNING *'  USING NEW.device_id;
	END IF;

	RETURN NEW;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=jazzhands;

DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_dcd_ins
	 ON device_collection_device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_dcd_ins
	AFTER INSERT
	ON device_collection_device
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_cache.jazzhands_legacy_device_columns_dcd_ins();

----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION jazzhands_cache.jazzhands_legacy_device_columns_dcd_upd()
RETURNS TRIGGER AS $$
DECLARE
	_or		RECORD;
	_nr		RECORD;
	_ouq	TEXT[];
	_nuq	TEXT[];
	_q		TEXT;
	tally	INTEGER;
BEGIN
	-- RAISE NOTICE 'device_collection_device update trigger: % % % %',
	-- 	OLD.device_collection_id, OLD.device_id,
	-- 	NEW.device_collection_id, NEW.device_id;
	tally := 0;
	FOR _or IN
		SELECT 'old' as direction, *
		FROM property
		WHERE device_collection_id = OLD.device_collection_id
		AND property_type = 'JazzHandsLegacySupport'
		UNION
		SELECT 'new' as direction, *
		FROM property
		WHERE device_collection_id = NEW.device_collection_id
		AND property_type = 'JazzHandsLegacySupport'
	LOOP
		_ouq := NULL;
		_nuq := NULL;
		_nr := NULL;
		-- This is a hack
		IF _or.direction = 'new' THEN
			-- If the row was already processed, which is likely, abort
			--
			-- This code only gets executed when the device colletion is
			-- switching from something not legacy to legacy, which is dumb
			-- but could happen.
			IF tally > 0 THEN
				CONTINUE;
			END IF;
		ELSE
			-- build _ouq into stuff that changes in the old
			IF _or.property_name = 'IsMonitoredDevice' THEN
				_ouq := array_append(_ouq, 'is_monitored = ' ||
					quote_nullable('N'));
			END IF;
			IF _or.property_name = 'ShouldConfigFetch' THEN
				_ouq := array_append(_ouq, 'should_fetch_config = ' ||
					quote_nullable('N'));
			END IF;
			IF _or.property_name = 'IsLocallyManagedDevice' THEN
				_ouq := array_append(_ouq, 'is_locally_managed = ' ||
					quote_nullable('N'));
			END IF;
		END IF;

		-- get where it is moving to.
		IF OLD.device_collection_id != NEW.device_collection_id THEN
			SELECT * INTO _nr
			FROM property
			WHERE device_collection_id = NEW.device_collection_id
			AND property_type = 'JazzHandsLegacySupport'
			LIMIT 1;
		ELSE
			_nr := _or;
		END IF;

		IF  OLD.device_collection_id != NEW.device_collection_id THEN
			-- build _nuq into stuff that changes in the new
			IF _nr.property_name = 'IsMonitoredDevice' THEN
				_nuq := array_append(_nuq, 'is_monitored = ' ||
					quote_nullable('Y'));
			END IF;
			IF _nr.property_name = 'ShouldConfigFetch' THEN
				_nuq := array_append(_nuq, 'should_fetch_config = ' ||
					quote_nullable('Y'));
			END IF;
			IF _nr.property_name = 'IsLocallyManagedDevice' THEN
				_nuq := array_append(_nuq, 'is_locally_managed = ' ||
					quote_nullable('Y'));
			END IF;
		END IF;

		-- this one is special
		IF _or.property_name = 'AutoMgmtProtocol' THEN
			IF OLD.device_id != NEW.device_id THEN
				_ouq := array_append(_ouq, 'auto_mgmt_protocol = ' ||
					quote_nullable(_r.property_value));
				IF _nr IS NOT NULL THEN
					_nuq := array_append(_nuq, 'auto_mgmt_protocol = ' ||
						quote_nullable(_nr.property_value));
				ELSE
					_nuq := array_append(_nuq, 'auto_mgmt_protocol = ' ||
						quote_nullable(_r.property_value));
				END IF;
			ELSIF  OLD.device_collection_id != NEW.device_collection_id THEN
				-- device si the same, so adjust the new side.
				_nuq := array_append(_nuq, 'auto_mgmt_protocol = ' ||
					quote_nullable(_nr.property_value));
			ELSE
				RAISE EXCEPTION 'This should not happen: % % % %',
					jsonb_pretty(to_json(OLD)::jsonb),
					jsonb_pretty(to_json(NEW)::jsonb),
					jsonb_pretty(to_json(_or)::jsonb),
					jsonb_pretty(to_json(_nr)::jsonb);
			END IF;
		ELSIF _nr.property_name = 'AutoMgmtProtocol' THEN
			-- in this case, it's not changing from one type to another,
			-- old device is getting cleared and new device is getting set.
			_nuq := array_append(_nuq, 'auto_mgmt_protocol = ' ||
				quote_nullable(_nr.property_value));
		END IF;

		-- At this point, _or is popiulated with what needs to happen to
		-- the old device and _nr is populated with what needs to happen
		-- to the new device

		IF OLD.device_id = NEW.device_id THEN
			IF _or.property_name = _nr.property_name THEN
				_ouq := NULL;
			END IF;
			IF _ouq IS NOT NULL AND _nuq IS NOT NULL THEN
				_q := concat(
					array_to_string(_ouq, ', '), ', ',
					array_to_string(_nuq, ', ')
				);
			ELSIF _ouq IS NOT NULL THEN
				_q := array_to_string(_ouq, ', ');
			ELSIF _nuq IS NOT NULL THEN
				_q := array_to_string(_nuq, ', ');
			ELSE
				RAISE EXCEPTION 'THis should not happen % %', _ouq, _nuq;
			END IF;
			EXECUTE
				format('UPDATE %s SET %s WHERE device_id = $1 RETURNING *',
					'jazzhands_cache.ct_jazzhands_legacy_device_support',
					_q)
				USING OLD.device_id;
		ELSE
			-- device is getting taken out of old and put in new.  The
			-- device_id is changing, so tweaking needs to happen to both.
			RAISE NOTICE 'oine';
			EXECUTE
				format('UPDATE %s SET %s WHERE device_id = $1 RETURNING *',
					'jazzhands_cache.ct_jazzhands_legacy_device_support',
					array_to_string(_ouq, ', '))
				USING OLD.device_id;
			EXECUTE
				format('UPDATE %s SET %s WHERE device_id = $1 RETURNING *',
					'jazzhands_cache.ct_jazzhands_legacy_device_support',
					array_to_string(_nuq, ', '))
				USING NEW.device_id;
		END IF;

		tally := tally + 1;
	END LOOP;

	RETURN NEW;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=jazzhands;

DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_dcd_upd
	 ON device_collection_device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_dcd_upd
	AFTER UPDATE
	ON device_collection_device
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_cache.jazzhands_legacy_device_columns_dcd_upd();



----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION jazzhands_cache.jazzhands_legacy_device_columns_dcd_del()
RETURNS TRIGGER AS $$
DECLARE
	_r	RECORD;
	_uq	TEXT[];
BEGIN
	-- RAISE NOTICE 'Deleting cache record for dc#% %...', OLD.device_collection_id, OLD.device_id;
	FOR _r IN SELECT * FROM property
		WHERE device_collection_id = OLD.device_collection_id
		AND property_type = 'JazzHandsLegacySupport'
	LOOP
		IF _r.property_name = 'IsMonitoredDevice' THEN
			_uq := array_append(_uq, 'is_monitored = ' ||
				quote_nullable('N'));
		END IF;
		IF _r.property_name = 'ShouldConfigFetch' THEN
			_uq := array_append(_uq, 'should_fetch_config = ' ||
				quote_nullable('N'));
		END IF;
		IF _r.property_name = 'IsLocallyManagedDevice' THEN
			_uq := array_append(_uq, 'is_locally_managed = ' ||
				quote_nullable('N'));
		END IF;
		IF _r.property_name = 'AutoMgmtProtocol' THEN
			_uq := array_append(_uq, 'auto_mgmt_protocol = ' ||
				quote_nullable(_r.property_value));
		END IF;
	END LOOP;

	IF _uq IS NOT NULL THEN
		EXECUTE
			'UPDATE jazzhands_cache.ct_jazzhands_legacy_device_support SET ' ||
			array_to_string(_uq, ', ') ||
			' WHERE  device_id = $1 RETURNING *'  USING OLD.device_id;
	END IF;
	RETURN OLD;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=jazzhands;

DROP TRIGGER IF EXISTS trigger_jazzhands_legacy_device_columns_dcd_del
	 ON device_collection_device;
CREATE TRIGGER trigger_jazzhands_legacy_device_columns_dcd_del
	BEFORE DELETE
	ON device_collection_device
	FOR EACH ROW
	EXECUTE PROCEDURE jazzhands_cache.jazzhands_legacy_device_columns_dcd_del();
----------------------------------------------------------------------------
