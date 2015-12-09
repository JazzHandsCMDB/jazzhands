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

--
-- Basics about network_ranges and dns:
--
-- Ensure that dns_domain_id is set when its supposed to be
--
CREATE OR REPLACE FUNCTION validate_network_range()
RETURNS TRIGGER
AS $$
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

END; $$
SET search_path=jazzhands
LANGUAGE plpgsql
SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_network_range
	ON network_range;
CREATE TRIGGER trigger_validate_network_range
	BEFORE INSERT OR UPDATE OF dns_domain_id
	ON network_range
	FOR EACH ROW EXECUTE PROCEDURE
		jazzhands.validate_network_range();

----------------------------------------------------------------------------
--
-- if a type is switching to 'Y', make sure that this does not create
-- invalid data.
--
CREATE OR REPLACE FUNCTION validate_val_network_range_type()
RETURNS TRIGGER
AS $$
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

END; $$
SET search_path=jazzhands
LANGUAGE plpgsql
SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_validate_val_network_range_type
	ON val_network_range_type;
CREATE TRIGGER trigger_validate_val_network_range_type
	BEFORE UPDATE OF dns_domain_required
	ON val_network_range_type
	FOR EACH ROW EXECUTE PROCEDURE
		jazzhands.validate_val_network_range_type();

----------------------------------------------------------------------------
