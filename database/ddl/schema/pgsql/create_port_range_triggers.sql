/*
 * Copyright (c) 2021 Todd Kover
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
-- These triggers enforce that things that are direct to host can't become
-- accidentaly not direct to host.  It's possible, even probable that these
-- should be folded into other triggers, but due to time constraints did not
-- want to do that now.
--

\set ON_ERROR_STOP

CREATE OR REPLACE FUNCTION port_range_manage_singleton()
RETURNS TRIGGER AS $$
DECLARE
	_r		RECORD;
BEGIN
	IF NEW.is_singleton IS NULL THEN
		IF NEW.port_start = NEW.port_end THEN
			NEW.is_singleton = true;
		ELSE
			NEW.is_singleton = false;
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_port_range_manage_singleton
	ON port_range;
CREATE TRIGGER trigger_port_range_manage_singleton
	BEFORE INSERT
	ON port_range
	FOR EACH ROW
	EXECUTE PROCEDURE port_range_manage_singleton();


------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION port_range_sanity_check()
RETURNS TRIGGER AS $$
DECLARE
	_r		RECORD;
BEGIN
	IF NOT NEW.is_singleton THEN
		SELECT *
		INTO _r
		FROM val_port_range_type
		WHERE port_range_type = NEW.port_range_type
		AND protocol = NEW.protocol;

		IF NOT _r.range_permitted THEN
			RAISE EXCEPTION 'Ranges are not permitted on %:%',
				NEW.port_range_type, NEW.protocol
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSE
		IF NEW.port_start != NEW.port_end THEN
			RAISE EXCEPTION 'singletons may not have a different start and end port'
				USING ERRCODE = 'invalid_parameter_value';
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_port_range_sanity_check
	ON port_range;
CREATE CONSTRAINT TRIGGER trigger_port_range_sanity_check
	AFTER INSERT OR UPDATE OF port_start, port_end, is_singleton
	ON port_range
	FOR EACH ROW
	EXECUTE PROCEDURE port_range_sanity_check();

------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION val_port_range_sanity_check()
RETURNS TRIGGER AS $$
DECLARE
	_tally INTEGER;
BEGIN
	IF NOT NEW.range_permitted  THEN
		SELECT count(*)
		INTO _tally
		fROM port_range
		WHERE protocol = NEW.protocol
		AND port_range_type = NEW.port_range_type
		AND port_start != port_end;

		IF _tally > 0 THEN
			RAISE EXCEPTION 'Existing %:% have ranges',
				NEW.port_range_type, NEW.protocol
				USING ERRCODE = 'invalid_parameter_value',
				HINT = 'check port_start and port_end on existing records';
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_val_port_range_sanity_check
	ON val_port_range_type;
CREATE CONSTRAINT TRIGGER trigger_val_port_range_sanity_check
	AFTER UPDATE OF range_permitted
	ON val_port_range_type
	FOR EACH ROW
	EXECUTE PROCEDURE val_port_range_sanity_check();
