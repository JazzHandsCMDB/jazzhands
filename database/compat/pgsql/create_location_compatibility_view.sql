-— Copyright (c) 2014, Todd M. Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--       http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- $Id$
--

CREATE OR REPLACE VIEW location
AS
SELECT
	rack_location_id	AS location_id,
	rack_id,
	rack_u_offset_of_device_top,
	rack_side,
	NULL::integer		AS inter_device_offset,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM rack_location;

CREATE OR REPLACE FUNCTION ins_location_transition()
RETURNS TRIGGER
AS $$
DECLARE
	_r		RACK_LOCATION%rowtype;
BEGIN
	IF NEW.location_id is not null THEN
		INSERT INTO rack_location (
			rack_location_id,
			rack_id,
			rack_u_offset_of_device_top,
			rack_side
		) VALUES (
			NEW.location_id,
			NEW.rack_id,
			NEW.rack_u_offset_of_device_top,
			NEW.rack_side
		) RETURNING * INTO _r;
	ELSE
		INSERT INTO rack_location (
			rack_id,
			rack_u_offset_of_device_top,
			rack_side
		) VALUES (
			NEW.rack_id,
			NEW.rack_u_offset_of_device_top,
			NEW.rack_side
		) RETURNING * INTO _r;
	END IF;

	NEW.location_id := _r.rack_location_id;
	NEW.rack_id := _r.rack_id;
	NEW.rack_u_offset_of_device_top := _r.rack_u_offset_of_device_top;
	NEW.rack_side := _r.rack_side;
	NEW.inter_device_offset := 0;
	NEW.data_ins_user := _r.data_ins_user;
	NEW.data_ins_date := _r.data_ins_date;
	NEW.data_upd_user := _r.data_upd_user;
	NEW.data_upd_date := _r.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_ins_location_transition ON location;
CREATE TRIGGER trigger_ins_location_transition
INSTEAD OF INSERT ON location
FOR EACH ROW EXECUTE PROCEDURE ins_location_transition();


----

CREATE OR REPLACE FUNCTION upd_location_transition()
RETURNS TRIGGER
AS $$
DECLARE
	_r		RACK_LOCATION%rowtype;
	_u		varchar[][];
	_i		varchar[];
	upd		text;
BEGIN
	select * INTO _r from rack_location where rack_location_id = OLD.location_id;

	if _r.rack_location_id != NEW.location_id THEN
		_i = ARRAY[ 'rack_location_id', NEW.location_id::text ];
		_u = _u || ARRAY[_i];
		
	END IF;

	if _R.rack_id != NEW.rack_id THEN
		_i = ARRAY[ 'rack_id', NEW.rack_id::text ];
		_u = _u || ARRAY[_i];
	END IF;

	if _R.rack_u_offset_of_device_top != NEW.rack_u_offset_of_device_top THEN
		_i[1] = 'rack_u_offset_of_device_top';
		_i[2] = NEW.rack_u_offset_of_device_top;
		_i = ARRAY[ 'rack_u_offset_of_device_top', NEW.rack_u_offset_of_device_top::text ];
		_u = _u || ARRAY[_i];
	END IF;

	if _R.rack_side != NEW.rack_side THEN
		_i = ARRAY[ 'rack_side', '''' || NEW.rack_side || '''' ];
		_u = _u || _i;
	END IF;

	upd := '';
	IF array_length(_u, 1) > 0 THEN
		foreach _i SLICE 1 IN ARRAY _u
		LOOP
			IF char_length(upd) > 0 THEN
				upd := upd || ', ';
			END IF;
			upd := upd || _i[1] || ' = ' || _i[2] ;
		END LOOP;
		upd := 'UPDATE rack_location SET ' || upd || ' WHERE rack_location_id = ' || _r.rack_location_id;
		EXECUTE upd;
	END IF;

	select * INTO _r from rack_location where rack_location_id = NEW.location_id;
	NEW.location_id := _r.rack_location_id;
	NEW.rack_id := _r.rack_id;
	NEW.rack_u_offset_of_device_top := _r.rack_u_offset_of_device_top;
	NEW.rack_side := _r.rack_side;
	NEW.inter_device_offset := 0;
	NEW.data_ins_user := _r.data_ins_user;
	NEW.data_ins_date := _r.data_ins_date;
	NEW.data_upd_user := _r.data_upd_user;
	NEW.data_upd_date := _r.data_upd_date;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_upd_location_transition ON location;
CREATE TRIGGER trigger_upd_location_transition
INSTEAD OF UPDATE ON location
FOR EACH ROW EXECUTE PROCEDURE upd_location_transition();


----

CREATE OR REPLACE FUNCTION del_location_transition()
RETURNS TRIGGER
AS $$
DECLARE
	_r		RACK_LOCATION%rowtype;
BEGIN
	select * INTO _r from rack_location where rack_location_id = OLD.location_id;

	OLD.location_id := _r.rack_location_id;
	OLD.rack_id := _r.rack_id;
	OLD.rack_u_offset_of_device_top := _r.rack_u_offset_of_device_top;
	OLD.rack_side := _r.rack_side;
	OLD.inter_device_offset := 0;
	OLD.data_ins_user := _r.data_ins_user;
	OLD.data_ins_date := _r.data_ins_date;
	OLD.data_upd_user := _r.data_upd_user;
	OLD.data_upd_date := _r.data_upd_date;

	delete from rack_location where rack_location_id = OLD.location_id;

	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_del_location_transition ON location;
CREATE TRIGGER trigger_del_location_transition
INSTEAD OF DELETE ON location
FOR EACH ROW EXECUTE PROCEDURE del_location_transition();

