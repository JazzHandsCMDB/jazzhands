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

CREATE OR REPLACE FUNCTION check_service_relationship_rhs()
RETURNS TRIGGER AS $$
DECLARE
	_t	BOOLEAN;
	_id	INTEGER;
	_re	TEXT;
BEGIN
	IF NEW.service_version_restriction IS NOT NULL THEN
		IF NEW.service_version_restriction_service_id IS NULL THEN
			RAISE EXCEPTION 'If service_version_restriction is set, service_version_restriction_service_id must also be set'
				USING ERRCODE = 'not_null_violation';
		END IF;

		--
		-- Either use the user specified regex or the default one and
		-- check the relationship against it
		--

		SELECT st.service_version_restriction_regular_expression
		INTO _re
		FROM val_service_type st
		JOIN service USING (service_type)
		JOIn service_version USING (service_id)
		WHERE service_version_id = NEW.service_version_id;

		IF _re IS NULL THEN
			_re := '^((<=? [-_\.a-z0-9]+) (>=? [-_\.a-z0-9]+)|(([<>]=?|=) [-_\.a-z0-9]+))$';
		END IF;

		IF NEW.service_version_restriction !~_re THEN
			RAISE EXCEPTION 'restriction must match rules for this service type'
				USING ERRCODE = 'invalid_parameter_value',
				HINT = format('Using regexp %s', _re);
		END IF;
	END IF;

	IF NEW.related_service_version_id IS NOT NULL THEN
		IF NEW.related_service_version_id IS NOT NULL THEN
			SELECT v1.service_id = v2.service_id INTO _t
			FROM service_version v1, service_version v2
			WHERE v1.service_version_id = NEW.service_version_id
			AND v2.service_version_id = NEW.related_service_version_id;
			IF _t THEN
				RAISE EXCEPTION 'service_version_restriction_service_id and '
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
		END IF;
	END IF;

	IF NEW.service_version_restriction_service_id IS NOT NULL THEN
		IF NEW.related_service_version_id IS NOT NULL  THEN
			IF NEW.service_version_restriction IS NULL THEN
				RAISE EXCEPTION 'If service_version_restriction_service_id and related_service_version_id is set, service_version_restriction must also be set'
					USING ERRCODE = 'not_null_violation';
			END IF;

			--
			-- make sure service_version_restriction_service_id points to
			-- the same service as related_service_version_id
			--
			SELECT service_id
			INTO _id
			FROM service_version
			WHERE service_version_id = NEW.related_service_version_id;

			IF _id != NEW.service_version_restriction_service_id THEN
				RAISE EXCEPTION 'service_version_restriction_service_id and related_service_version_id must point to the same services.'
					USING ERRCODE = 'invalid_parameter_value';
			END IF;
		END IF;

		SELECT service_id
		INTO _id
		FROM service_version
		WHERE service_version_id = NEW.service_version_id;

		IF _id = NEW.service_version_restriction_service_id THEN
			RAISE EXCEPTION 'May not relate to oneself'
					USING ERRCODE = 'invalid_parameter_value';
		END IF;
	ELSE
		IF NEW.related_service_version_id IS NULL THEN
			RAISE EXCEPTION 'One of service_version_restriction_service_id and related_service_version_id must be set.'
				USING ERRCODE = 'not_null_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_check_service_relationship_rhs
	ON service_relationship;
CREATE CONSTRAINT TRIGGER trigger_check_service_relationship_rhs
	AFTER INSERT OR UPDATE OF related_service_version_id,
		service_version_restriction_service_id,
		service_version_restriction
	ON service_relationship
	FOR EACH ROW
	EXECUTE PROCEDURE check_service_relationship_rhs();

-----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION check_service_type_relation_regexp_change()
RETURNS TRIGGER AS $$
DECLARE
	_r	RECORD;
BEGIN
	IF NEW.service_version_restriction_regular_expression IS NOT NULL THEN
		FOR _r IN
			SELECT sr.*
			FROM service_relationship sr
			JOIN service_version USING (service_version_id)
			WHERE service_type = NEW.service_type
			AND service_version_restriction IS NOT NULL
			AND service_version_restriction !~
				NEW.service_version_restriction_regular_expression
		LOOP
			RAISE EXCEPTION 'Existing service_relationships must match type.'
				USING ERRCODE = 'invalid_parameter_value',
				HINT = format('Check relationship %s',
					_r.service_relationship_id);
		END LOOP;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_check_service_type_relation_regexp_change
	ON val_service_type;
CREATE CONSTRAINT TRIGGER trigger_check_service_type_relation_regexp_change
	AFTER UPDATE OF service_version_restriction_regular_expression
	ON val_service_type
	FOR EACH ROW
	EXECUTE PROCEDURE check_service_type_relation_regexp_change();

