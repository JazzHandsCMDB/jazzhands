/*
 * Copyright (c) 2017 Todd Kover
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

CREATE OR REPLACE FUNCTION v_person_company_ins() RETURNS TRIGGER AS $$
DECLARE
	_pc	person_company%ROWTYPE;
BEGIN
	INSERT INTO person_company (
        company_id, person_id, person_company_status,
        person_company_relation, is_exempt, is_management, 
		is_full_time,
        description, position_title, hire_date, termination_date,
        manager_person_id, nickname
	) VALUES (
        NEW.company_id, NEW.person_id, NEW.person_company_status,
        NEW.person_company_relation, NEW.is_exempt, NEW.is_management, 
		NEW.is_full_time,
        NEW.description, NEW.position_title, NEW.hire_date, NEW.termination_date,
        NEW.manager_person_id, NEW.nickname
	) RETURNING * INTO _pc;

	IF NEW.employee_id IS NOT NULL THEN
		INSERT INTO person_company_attribute (
			company_id, person_id, person_company_attribute_name,
			attribute_value
		) VALUES  (
			NEW.company_id, NEW.person_id, 'employee_id',
			NEW.employee_id
		);
	END IF;

	IF NEW.payroll_id IS NOT NULL THEN
		INSERT INTO person_company_attribute (
			company_id, person_id, person_company_attribute_name,
			attribute_value
		) VALUES  (
			NEW.company_id, NEW.person_id, 'payroll_id',
			NEW.payroll_id
		);
	END IF;

	IF NEW.external_hr_id IS NOT NULL THEN
		INSERT INTO person_company_attribute (
			company_id, person_id, person_company_attribute_name,
			attribute_value
		) VALUES  (
			NEW.company_id, NEW.person_id, 'external_hr_id',
			NEW.external_hr_id
		);
	END IF;

	IF NEW.badge_system_id IS NOT NULL THEN
		INSERT INTO person_company_attribute (
			company_id, person_id, person_company_attribute_name,
			attribute_value
		) VALUES  (
			NEW.company_id, NEW.person_id, 'badge_system_id',
			NEW.badge_system_id
		);
	END IF;

	IF NEW.supervisor_person_id IS NOT NULL THEN
		INSERT INTO person_company_attribute (
			company_id, person_id, person_company_attribute_name,
			attribute_value_person_id
		) VALUES  (
			NEW.company_id, NEW.person_id, 'supervisor_person_id',
			NEW.attribute_value_person_id
		);
	END IF;

	--
	-- deal with any trigger changes or whatever, tho most of these should
	-- be noops.
	--

	NEW.company_id := _pc.company_id;
	NEW.person_id := _pc.person_id;
	NEW.person_company_status := _pc.person_company_status;
	NEW.person_company_relation := _pc.person_company_relation;
	NEW.is_exempt := _pc.is_exempt;
	NEW.is_management := _pc.is_management;
	NEW.is_full_time := _pc.is_full_time;
	NEW.description := _pc.description;
	NEW.position_title := _pc.position_title;
	NEW.hire_date := _pc.hire_date;
	NEW.termination_date := _pc.termination_date;
	NEW.manager_person_id := _pc.manager_person_id;
	NEW.nickname := _pc.nickname;
	NEW.data_ins_user := _pc.data_ins_user;
	NEW.data_ins_date := _pc.data_ins_date;
	NEW.data_upd_user := _pc.data_upd_user;
	NEW.data_upd_date := _pc.data_upd_date;


	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_v_person_company_ins
	ON v_person_company;
CREATE TRIGGER trigger_v_person_company_ins
	INSTEAD OF INSERT ON v_person_company
	FOR EACH ROW
	EXECUTE PROCEDURE v_person_company_ins();

----------------------------------------------------------------------------


CREATE OR REPLACE FUNCTION v_person_company_del() RETURNS TRIGGER AS $$
BEGIN
	DELETE FROM person_company_attribute
	WHERE person_id = OLD.person_id
	AND company_id = OLD.company_id
	AND person_company_attribute_name IN (
		'employee_id', 'payroll_id', 'external_hr_id',
		'badge_system_id', 'supervisor_person_id'
	);

	DELETE FROM person_company
	WHERE person_id = OLD.person_id
	AND company_id = OLD.company_id;

	RETURN OLD;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_v_person_company_del
	ON v_person_company;
CREATE TRIGGER trigger_v_person_company_del
	INSTEAD OF DELETE
	ON v_person_company
	FOR EACH ROW
	EXECUTE PROCEDURE v_person_company_del();

----------------------------------------------------------------------------


CREATE OR REPLACE FUNCTION v_person_company_upd() RETURNS TRIGGER AS $$
DECLARE
	upd_query	TEXT[];
	_pc		person_company%ROWTYPE;
BEGIN
	upd_query := NULL;

	IF NEW.company_id IS DISTINCT FROM OLD.company_id THEN
		upd_query := array_append(upd_query,
			'company_id = ' || quote_nullable(NEW.company_id));
	END IF;
	IF NEW.person_id IS DISTINCT FROM OLD.person_id THEN
		upd_query := array_append(upd_query,
			'person_id = ' || quote_nullable(NEW.person_id));
	END IF;
	IF NEW.person_company_status IS DISTINCT FROM OLD.person_company_status THEN
		upd_query := array_append(upd_query,
			'person_company_status = ' || quote_nullable(NEW.person_company_status));
	END IF;
	IF NEW.person_company_relation IS DISTINCT FROM OLD.person_company_relation THEN
		upd_query := array_append(upd_query,
			'person_company_relation = ' || quote_nullable(NEW.person_company_relation));
	END IF;
	IF NEW.is_exempt IS DISTINCT FROM OLD.is_exempt THEN
		upd_query := array_append(upd_query,
			'is_exempt = ' || quote_nullable(NEW.is_exempt));
	END IF;
	IF NEW.is_management IS DISTINCT FROM OLD.is_management THEN
		upd_query := array_append(upd_query,
			'is_management = ' || quote_nullable(NEW.is_management));
	END IF;
	IF NEW.is_full_time IS DISTINCT FROM OLD.is_full_time THEN
		upd_query := array_append(upd_query,
			'is_full_time = ' || quote_nullable(NEW.is_full_time));
	END IF;
	IF NEW.description IS DISTINCT FROM OLD.description THEN
		upd_query := array_append(upd_query,
			'description = ' || quote_nullable(NEW.description));
	END IF;
	IF NEW.position_title IS DISTINCT FROM OLD.position_title THEN
		upd_query := array_append(upd_query,
			'position_title = ' || quote_nullable(NEW.position_title));
	END IF;
	IF NEW.hire_date IS DISTINCT FROM OLD.hire_date THEN
		upd_query := array_append(upd_query,
			'hire_date = ' || quote_nullable(NEW.hire_date));
	END IF;
	IF NEW.termination_date IS DISTINCT FROM OLD.termination_date THEN
		upd_query := array_append(upd_query,
			'termination_date = ' || quote_nullable(NEW.termination_date));
	END IF;
	IF NEW.manager_person_id IS DISTINCT FROM OLD.manager_person_id THEN
		upd_query := array_append(upd_query,
			'manager_person_id = ' || quote_nullable(NEW.manager_person_id));
	END IF;
	IF NEW.nickname IS DISTINCT FROM OLD.nickname THEN
		upd_query := array_append(upd_query,
			'nickname = ' || quote_nullable(NEW.nickname));
	END IF;

	IF upd_query IS NOT NULL THEN
		EXECUTE 'UPDATE person_company SET ' ||
		array_to_string(upd_query, ', ') ||
		' WHERE company_id = $1 AND person_id = $2 RETURNING *'
		USING OLD.company_id, OLD.person_id
		INTO _pc;

		NEW.company_id := _pc.company_id;
		NEW.person_id := _pc.person_id;
		NEW.person_company_status := _pc.person_company_status;
		NEW.person_company_relation := _pc.person_company_relation;
		NEW.is_exempt := _pc.is_exempt;
		NEW.is_management := _pc.is_management;
		NEW.is_full_time := _pc.is_full_time;
		NEW.description := _pc.description;
		NEW.position_title := _pc.position_title;
		NEW.hire_date := _pc.hire_date;
		NEW.termination_date := _pc.termination_date;
		NEW.manager_person_id := _pc.manager_person_id;
		NEW.nickname := _pc.nickname;
		NEW.data_ins_user := _pc.data_ins_user;
		NEW.data_ins_date := _pc.data_ins_date;
		NEW.data_upd_user := _pc.data_upd_user;
		NEW.data_upd_date := _pc.data_upd_date;
	END IF;

	IF NEW.employee_id IS NOT NULL AND OLD.employee_id IS DISTINCT FROM NEW.employee_id  THEN
		INSERT INTO person_company_attribute AS pca (
			company_id, person_id, person_company_attribute_name, attribute_value
		) VALUES (
			NEW.company_id, NEW.person_id, 'employee_id', NEW.employee_id
		) ON CONFLICT ON CONSTRAINT pk_person_company_attribute
		DO UPDATE
			SET	attribute_value = NEW.employee_id
			WHERE pca.person_company_attribute_name = 'employee_id'
			AND pca.person_id = NEW.person_id
			AND pca.company_id = NEW.company_id;

	END IF;

	IF NEW.payroll_id IS NOT NULL AND OLD.payroll_id IS DISTINCT FROM NEW.payroll_id THEN
		INSERT INTO person_company_attribute AS pca (
			company_id, person_id, person_company_attribute_name, attribute_value
		) VALUES (
			NEW.company_id, NEW.person_id, 'payroll_id', NEW.payroll_id
		) ON CONFLICT ON CONSTRAINT pk_person_company_attribute
		DO
			UPDATE
			SET	attribute_value = NEW.payroll_id
			WHERE pca.person_company_attribute_name = 'payroll_id'
			AND pca.person_id = NEW.person_id
			AND pca.company_id = NEW.company_id;
	END IF;

	IF NEW.external_hr_id IS NOT NULL AND OLD.external_hr_id IS DISTINCT FROM NEW.external_hr_id THEN
		INSERT INTO person_company_attribute AS pca (
			company_id, person_id, person_company_attribute_name, attribute_value
		) VALUES (
			NEW.company_id, NEW.person_id, 'external_hr_id', NEW.external_hr_id
		) ON CONFLICT ON CONSTRAINT pk_person_company_attribute
		DO
			UPDATE
			SET	attribute_value = NEW.external_hr_id
			WHERE pca.person_company_attribute_name = 'external_hr_id'
			AND pca.person_id = NEW.person_id
			AND pca.company_id = NEW.company_id;
	END IF;

	IF NEW.badge_system_id IS NOT NULL AND OLD.badge_system_id IS DISTINCT FROM NEW.badge_system_id THEN
		INSERT INTO person_company_attribute AS pca (
			company_id, person_id, person_company_attribute_name, attribute_value
		) VALUES (
			NEW.company_id, NEW.person_id, 'badge_system_id', NEW.badge_system_id
		) ON CONFLICT ON CONSTRAINT pk_person_company_attribute
		DO
			UPDATE
			SET	attribute_value = NEW.badge_system_id
			WHERE pca.person_company_attribute_name = 'badge_system_id'
			AND pca.person_id = NEW.person_id
			AND pca.company_id = NEW.company_id;
	END IF;

	IF NEW.supervisor_person_id IS NOT NULL AND OLD.supervisor_person_id IS DISTINCT FROM NEW.supervisor_person_id THEN
		INSERT INTO person_company_attribute AS pca (
			company_id, person_id, person_company_attribute_name, attribute_value
		) VALUES (
			NEW.company_id, NEW.person_id, 'supervisor__id', NEW.supervisor_person_id
		) ON CONFLICT ON CONSTRAINT pk_person_company_attribute
		DO
			UPDATE
			SET	attribute_value = NEW.supervisor_person_id
			WHERE pca.person_company_attribute_name = 'supervisor_id'
			AND pca.person_id = NEW.person_id
			AND pca.company_id = NEW.company_id;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_v_person_company_upd
	ON v_person_company;
CREATE TRIGGER trigger_v_person_company_upd
	INSTEAD OF UPDATE
	ON v_person_company
	FOR EACH ROW
	EXECUTE PROCEDURE v_person_company_upd();

----------------------------------------------------------------------------

