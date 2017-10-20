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

/*
 * this deals with the automated membership of by-type collections
 */

CREATE OR REPLACE FUNCTION manip_device_collection_type_bytype()
	RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'DELETE' THEN
		IF OLD.device_collection_type NOT IN ('by-type', 'per-device') THEN
			DELETE FROM device_collection
			WHERE device_collection_name = OLD.device_collection_type
			AND device_collection_type = 'by-type';
		END IF;
		RETURN OLD;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.device_collection_type IN ('by-type', 'per-device') AND
			OLD.device_collection_type NOT IN ('by-type', 'per-device')
		THEN
			DELETE FROM device_collection
			WHERE device_collection_id = OLD.device_collection_id;
		ELSE
			UPDATE device_collection
			SET device_collection_name = NEW.device_collection_name
			WHERE device_collection_name = OLD.device_collection_type
			AND device_collection_type = 'by-type';
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.device_collection_type NOT IN ('by-type', 'per-device') THEN
			INSERT INTO device_collection (
				device_collection_name, device_collection_type
			) VALUES (
				NEW.device_collection_type, 'by-type'
			);
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_manip_device_collection_type_bytype_del
	ON val_device_collection_type;
CREATE TRIGGER trigger_manip_device_collection_type_bytype_del
BEFORE DELETE 
	ON val_device_collection_type
	FOR EACH ROW 
	EXECUTE PROCEDURE manip_device_collection_type_bytype();

DROP TRIGGER IF EXISTS trigger_manip_device_collection_type_bytype_insup
	ON val_device_collection_type;
CREATE TRIGGER trigger_manip_device_collection_type_bytype_insup
AFTER INSERT OR UPDATE OF device_collection_type
	ON val_device_collection_type
	FOR EACH ROW 
	EXECUTE PROCEDURE manip_device_collection_type_bytype();

------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION manip_device_collection_bytype()
	RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'DELETE' OR
		( TG_OP = 'UPDATE' and OLD.device_collection_type = 'per-device')
	THEN
		DELETE FROM device_collection_hier
		WHERE device_collection_id = OLD.device_collection_id
		AND parent_device_collection_id IN (
			SELECT device_collection_id
			FROM device_collection
			WHERE device_collection_type = 'by-type'
			AND device_collection_name = OLD.device_collection_type
		);

		IF TG_OP = 'DELETE' THEN
			RETURN OLD;
		ELSE
			RETURN NEW;
		END IF;
	END IF;

	IF NEW.device_collection_type IN ('per-device','by-type') THEN
		RETURN NEW;
	END IF;

	
	IF TG_OP = 'UPDATE' THEN
		UPDATE device_collection_hier
		SET parent_device_collection_id = (
			SELECT device_collection_id
			FROM device_collection
			WHERE device_collection_type = 'by-type'
			AND device_collection_name = NEW.device_collection_type
		),
			device_collection_id = NEW.device_collection_id
		WHERE parent_device_collection_id = (
			SELECT device_collection_id
			FROM device_collection
			WHERE device_collection_type = 'by-type'
			AND device_collection_name = OLD.device_collection_type
		)
		AND device_collection_id = OLD.device_collection_id;
	ELSIF TG_OP = 'INSERT' THEN
		INSERT INTO device_collection_hier (
			parent_device_collection_id, device_collection_id
		) SELECT device_collection_id, NEW.device_collection_id
			FROM device_collection
			WHERE device_collection_type = 'by-type'
			AND device_collection_name = NEW.device_collection_type;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_manip_device_collection_bytype_del
	ON device_collection;
CREATE TRIGGER trigger_manip_device_collection_bytype_del
BEFORE DELETE 
	ON device_collection
	FOR EACH ROW 
	EXECUTE PROCEDURE manip_device_collection_bytype();

DROP TRIGGER IF EXISTS trigger_manip_device_collection_bytype_insup
	ON device_collection;
CREATE TRIGGER trigger_manip_device_collection_bytype_insup
AFTER INSERT OR UPDATE OF device_collection_type
	ON device_collection
	FOR EACH ROW 
	EXECUTE PROCEDURE manip_device_collection_bytype();

------------------------------------------------------------------------------
------------------------------------------------------------------------------
------------------------------------------------------------------------------


CREATE OR REPLACE FUNCTION manip_dns_domain_collection_type_bytype()
	RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'DELETE' THEN
		IF OLD.dns_domain_collection_type NOT IN ('by-type', 'per-dns_domain') THEN
			DELETE FROM dns_domain_collection
			WHERE dns_domain_collection_name = OLD.dns_domain_collection_type
			AND dns_domain_collection_type = 'by-type';
		END IF;
		RETURN OLD;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.dns_domain_collection_type IN ('by-type', 'per-dns_domain') AND
			OLD.dns_domain_collection_type NOT IN ('by-type', 'per-dns_domain')
		THEN
			DELETE FROM dns_domain_collection
			WHERE dns_domain_collection_id = OLD.dns_domain_collection_id;
		ELSE
			UPDATE dns_domain_collection
			SET dns_domain_collection_name = NEW.dns_domain_collection_name
			WHERE dns_domain_collection_name = OLD.dns_domain_collection_type
			AND dns_domain_collection_type = 'by-type';
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.dns_domain_collection_type NOT IN ('by-type', 'per-dns_domain') THEN
			INSERT INTO dns_domain_collection (
				dns_domain_collection_name, dns_domain_collection_type
			) VALUES (
				NEW.dns_domain_collection_type, 'by-type'
			);
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_manip_dns_domain_collection_type_bytype_del
	ON val_dns_domain_collection_type;
CREATE TRIGGER trigger_manip_dns_domain_collection_type_bytype_del
BEFORE DELETE 
	ON val_dns_domain_collection_type
	FOR EACH ROW 
	EXECUTE PROCEDURE manip_dns_domain_collection_type_bytype();

DROP TRIGGER IF EXISTS trigger_manip_dns_domain_collection_type_bytype_insup
	ON val_dns_domain_collection_type;
CREATE TRIGGER trigger_manip_dns_domain_collection_type_bytype_insup
AFTER INSERT OR UPDATE OF dns_domain_collection_type
	ON val_dns_domain_collection_type
	FOR EACH ROW 
	EXECUTE PROCEDURE manip_dns_domain_collection_type_bytype();

------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION manip_dns_domain_collection_bytype()
	RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'DELETE' OR
		( TG_OP = 'UPDATE' and OLD.dns_domain_collection_type = 'per-dns_domain')
	THEN
		DELETE FROM dns_domain_collection_hier
		WHERE child_dns_domain_collection_id = OLD.dns_domain_collection_id
		AND dns_domain_collection_id IN (
			SELECT dns_domain_collection_id
			FROM dns_domain_collection
			WHERE dns_domain_collection_type = 'by-type'
			AND dns_domain_collection_name = OLD.dns_domain_collection_type
		);

		IF TG_OP = 'DELETE' THEN
			RETURN OLD;
		ELSE
			RETURN NEW;
		END IF;
	END IF;

	IF NEW.dns_domain_collection_type IN ('per-dns_domain','by-type') THEN
		RETURN NEW;
	END IF;

	
	IF TG_OP = 'UPDATE' THEN
		UPDATE dns_domain_collection_hier
		SET dns_domain_collection_id = (
			SELECT dns_domain_collection_id
			FROM dns_domain_collection
			WHERE dns_domain_collection_type = 'by-type'
			AND dns_domain_collection_name = NEW.dns_domain_collection_type
		),
			child_dns_domain_collection_id = NEW.dns_domain_collection_id
		WHERE dns_domain_collection_id = (
			SELECT dns_domain_collection_id
			FROM dns_domain_collection
			WHERE dns_domain_collection_type = 'by-type'
			AND dns_domain_collection_name = OLD.dns_domain_collection_type
		)
		AND child_dns_domain_collection_id = OLD.dns_domain_collection_id;
	ELSIF TG_OP = 'INSERT' THEN
		INSERT INTO dns_domain_collection_hier (
			dns_domain_collection_id, child_dns_domain_collection_id
		) SELECT dns_domain_collection_id, NEW.dns_domain_collection_id
			FROM dns_domain_collection
			WHERE dns_domain_collection_type = 'by-type'
			AND dns_domain_collection_name = NEW.dns_domain_collection_type;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_manip_dns_domain_collection_bytype_del
	ON dns_domain_collection;
CREATE TRIGGER trigger_manip_dns_domain_collection_bytype_del
BEFORE DELETE 
	ON dns_domain_collection
	FOR EACH ROW 
	EXECUTE PROCEDURE manip_dns_domain_collection_bytype();

DROP TRIGGER IF EXISTS trigger_manip_dns_domain_collection_bytype_insup
	ON dns_domain_collection;
CREATE TRIGGER trigger_manip_dns_domain_collection_bytype_insup
AFTER INSERT OR UPDATE OF dns_domain_collection_type
	ON dns_domain_collection
	FOR EACH ROW 
	EXECUTE PROCEDURE manip_dns_domain_collection_bytype();

------------------------------------------------------------------------------
------------------------------------------------------------------------------
------------------------------------------------------------------------------

