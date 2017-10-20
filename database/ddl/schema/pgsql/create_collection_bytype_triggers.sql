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
 * this deals with the automated membership of by-coll-type collections
 */

CREATE OR REPLACE FUNCTION manip_device_collection_type_bytype()
	RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'DELETE' THEN
		IF OLD.device_collection_type NOT IN ('by-coll-type', 'per-device') THEN
			DELETE FROM device_collection
			WHERE device_collection_name = OLD.device_collection_type
			AND device_collection_type = 'by-coll-type';
		END IF;
		RETURN OLD;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.device_collection_type IN ('by-coll-type', 'per-device') AND
			OLD.device_collection_type NOT IN ('by-coll-type', 'per-device')
		THEN
			DELETE FROM device_collection
			WHERE device_collection_id = OLD.device_collection_id;
		ELSE
			UPDATE device_collection
			SET device_collection_name = NEW.device_collection_name
			WHERE device_collection_name = OLD.device_collection_type
			AND device_collection_type = 'by-coll-type';
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.device_collection_type NOT IN ('by-coll-type', 'per-device') THEN
			INSERT INTO device_collection (
				device_collection_name, device_collection_type
			) VALUES (
				NEW.device_collection_type, 'by-coll-type'
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
			WHERE device_collection_type = 'by-coll-type'
			AND device_collection_name = OLD.device_collection_type
		);

		IF TG_OP = 'DELETE' THEN
			RETURN OLD;
		ELSE
			RETURN NEW;
		END IF;
	END IF;

	IF NEW.device_collection_type IN ('per-device','by-coll-type') THEN
		RETURN NEW;
	END IF;


	IF TG_OP = 'UPDATE' THEN
		UPDATE device_collection_hier
		SET parent_device_collection_id = (
			SELECT device_collection_id
			FROM device_collection
			WHERE device_collection_type = 'by-coll-type'
			AND device_collection_name = NEW.device_collection_type
		),
			device_collection_id = NEW.device_collection_id
		WHERE parent_device_collection_id = (
			SELECT device_collection_id
			FROM device_collection
			WHERE device_collection_type = 'by-coll-type'
			AND device_collection_name = OLD.device_collection_type
		)
		AND device_collection_id = OLD.device_collection_id;
	ELSIF TG_OP = 'INSERT' THEN
		INSERT INTO device_collection_hier (
			parent_device_collection_id, device_collection_id
		) SELECT device_collection_id, NEW.device_collection_id
			FROM device_collection
			WHERE device_collection_type = 'by-coll-type'
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
		IF OLD.dns_domain_collection_type NOT IN ('by-coll-type', 'per-dns_domain') THEN
			DELETE FROM dns_domain_collection
			WHERE dns_domain_collection_name = OLD.dns_domain_collection_type
			AND dns_domain_collection_type = 'by-coll-type';
		END IF;
		RETURN OLD;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.dns_domain_collection_type IN ('by-coll-type', 'per-dns_domain') AND
			OLD.dns_domain_collection_type NOT IN ('by-coll-type', 'per-dns_domain')
		THEN
			DELETE FROM dns_domain_collection
			WHERE dns_domain_collection_id = OLD.dns_domain_collection_id;
		ELSE
			UPDATE dns_domain_collection
			SET dns_domain_collection_name = NEW.dns_domain_collection_name
			WHERE dns_domain_collection_name = OLD.dns_domain_collection_type
			AND dns_domain_collection_type = 'by-coll-type';
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.dns_domain_collection_type NOT IN ('by-coll-type', 'per-dns_domain') THEN
			INSERT INTO dns_domain_collection (
				dns_domain_collection_name, dns_domain_collection_type
			) VALUES (
				NEW.dns_domain_collection_type, 'by-coll-type'
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
			WHERE dns_domain_collection_type = 'by-coll-type'
			AND dns_domain_collection_name = OLD.dns_domain_collection_type
		);

		IF TG_OP = 'DELETE' THEN
			RETURN OLD;
		ELSE
			RETURN NEW;
		END IF;
	END IF;

	IF NEW.dns_domain_collection_type IN ('per-dns_domain','by-coll-type') THEN
		RETURN NEW;
	END IF;


	IF TG_OP = 'UPDATE' THEN
		UPDATE dns_domain_collection_hier
		SET dns_domain_collection_id = (
			SELECT dns_domain_collection_id
			FROM dns_domain_collection
			WHERE dns_domain_collection_type = 'by-coll-type'
			AND dns_domain_collection_name = NEW.dns_domain_collection_type
		),
			child_dns_domain_collection_id = NEW.dns_domain_collection_id
		WHERE dns_domain_collection_id = (
			SELECT dns_domain_collection_id
			FROM dns_domain_collection
			WHERE dns_domain_collection_type = 'by-coll-type'
			AND dns_domain_collection_name = OLD.dns_domain_collection_type
		)
		AND child_dns_domain_collection_id = OLD.dns_domain_collection_id;
	ELSIF TG_OP = 'INSERT' THEN
		INSERT INTO dns_domain_collection_hier (
			dns_domain_collection_id, child_dns_domain_collection_id
		) SELECT dns_domain_collection_id, NEW.dns_domain_collection_id
			FROM dns_domain_collection
			WHERE dns_domain_collection_type = 'by-coll-type'
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

CREATE OR REPLACE FUNCTION manip_service_env_collection_type_bytype()
	RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'DELETE' THEN
		IF OLD.service_env_collection_type NOT IN ('by-coll-type', 'per-service_environment') THEN
			DELETE FROM service_environment_collection
			WHERE service_env_collection_name = OLD.service_env_collection_type
			AND service_env_collection_type = 'by-coll-type';
		END IF;
		RETURN OLD;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.service_env_collection_type IN ('by-coll-type', 'per-service_environment') AND
			OLD.service_env_collection_type NOT IN ('by-coll-type', 'per-service_environment')
		THEN
			DELETE FROM service_environment_collection
			WHERE service_env_collection_id = OLD.service_env_collection_id;
		ELSE
			UPDATE service_environment_collection
			SET service_env_collection_name = NEW.service_env_collection_name
			WHERE service_env_collection_name = OLD.service_env_collection_type
			AND service_env_collection_type = 'by-coll-type';
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.service_env_collection_type NOT IN ('by-coll-type', 'per-service_environment') THEN
			INSERT INTO service_environment_collection (
				service_env_collection_name, service_env_collection_type
			) VALUES (
				NEW.service_env_collection_type, 'by-coll-type'
			);
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_manip_service_env_collection_type_bytype_del
	ON val_service_env_coll_type;
CREATE TRIGGER trigger_manip_service_env_collection_type_bytype_del
BEFORE DELETE
	ON val_service_env_coll_type
	FOR EACH ROW
	EXECUTE PROCEDURE manip_service_env_collection_type_bytype();

DROP TRIGGER IF EXISTS trigger_manip_service_env_collection_type_bytype_insup
	ON val_service_env_coll_type;
CREATE TRIGGER trigger_manip_service_env_collection_type_bytype_insup
AFTER INSERT OR UPDATE OF service_env_collection_type
	ON val_service_env_coll_type
	FOR EACH ROW
	EXECUTE PROCEDURE manip_service_env_collection_type_bytype();

------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION manip_service_env_collection_bytype()
	RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'DELETE' OR
		( TG_OP = 'UPDATE' and OLD.service_env_collection_type = 'per-service_environment')
	THEN
		DELETE FROM service_environment_coll_hier
		WHERE child_service_env_coll_id = OLD.service_env_collection_id
		AND service_env_collection_id IN (
			SELECT service_env_collection_id
			FROM service_environment_collection
			WHERE service_env_collection_type = 'by-coll-type'
			AND service_env_collection_name = OLD.service_env_collection_type
		);

		IF TG_OP = 'DELETE' THEN
			RETURN OLD;
		ELSE
			RETURN NEW;
		END IF;
	END IF;

	IF NEW.service_env_collection_type IN ('per-service_environment','by-coll-type') THEN
		RETURN NEW;
	END IF;


	IF TG_OP = 'UPDATE' THEN
		UPDATE service_environment_coll_hier
		SET service_env_collection_id = (
			SELECT service_env_collection_id
			FROM service_environment_collection
			WHERE service_env_collection_type = 'by-coll-type'
			AND service_env_collection_name = NEW.service_env_collection_type
		),
			child_service_env_coll_id = NEW.service_env_collection_id
		WHERE service_env_collection_id = (
			SELECT service_env_collection_id
			FROM service_environment_collection
			WHERE service_env_collection_type = 'by-coll-type'
			AND service_env_collection_name = OLD.service_env_collection_type
		)
		AND child_service_env_coll_id = OLD.service_env_collection_id;
	ELSIF TG_OP = 'INSERT' THEN
		INSERT INTO service_environment_coll_hier (
			service_env_collection_id, child_service_env_coll_id
		) SELECT service_env_collection_id, NEW.service_env_collection_id
			FROM service_environment_collection
			WHERE service_env_collection_type = 'by-coll-type'
			AND service_env_collection_name = NEW.service_env_collection_type;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_manip_service_env_collection_bytype_del
	ON service_environment_collection;
CREATE TRIGGER trigger_manip_service_env_collection_bytype_del
BEFORE DELETE
	ON service_environment_collection
	FOR EACH ROW
	EXECUTE PROCEDURE manip_service_env_collection_bytype();

DROP TRIGGER IF EXISTS trigger_manip_service_env_collection_bytype_insup
	ON service_environment_collection;
CREATE TRIGGER trigger_manip_service_env_collection_bytype_insup
AFTER INSERT OR UPDATE OF service_env_collection_type
	ON service_environment_collection
	FOR EACH ROW
	EXECUTE PROCEDURE manip_service_env_collection_bytype();

------------------------------------------------------------------------------
------------------------------------------------------------------------------
------------------------------------------------------------------------------



CREATE OR REPLACE FUNCTION manip_layer2_network_collection_type_bytype()
	RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'DELETE' THEN
		IF OLD.layer2_network_collection_type NOT IN ('by-coll-type', 'per-layer2_network') THEN
			DELETE FROM layer2_network_collection
			WHERE layer2_network_collection_name = OLD.layer2_network_collection_type
			AND layer2_network_collection_type = 'by-coll-type';
		END IF;
		RETURN OLD;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.layer2_network_collection_type IN ('by-coll-type', 'per-layer2_network') AND
			OLD.layer2_network_collection_type NOT IN ('by-coll-type', 'per-layer2_network')
		THEN
			DELETE FROM layer2_network_collection
			WHERE layer2_network_collection_id = OLD.layer2_network_collection_id;
		ELSE
			UPDATE layer2_network_collection
			SET layer2_network_collection_name = NEW.layer2_network_collection_name
			WHERE layer2_network_collection_name = OLD.layer2_network_collection_type
			AND layer2_network_collection_type = 'by-coll-type';
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.layer2_network_collection_type NOT IN ('by-coll-type', 'per-layer2_network') THEN
			INSERT INTO layer2_network_collection (
				layer2_network_collection_name, layer2_network_collection_type
			) VALUES (
				NEW.layer2_network_collection_type, 'by-coll-type'
			);
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_manip_layer2_network_collection_type_bytype_del
	ON val_layer2_network_coll_type;
CREATE TRIGGER trigger_manip_layer2_network_collection_type_bytype_del
BEFORE DELETE
	ON val_layer2_network_coll_type
	FOR EACH ROW
	EXECUTE PROCEDURE manip_layer2_network_collection_type_bytype();

DROP TRIGGER IF EXISTS trigger_manip_layer2_network_collection_type_bytype_insup
	ON val_layer2_network_coll_type;
CREATE TRIGGER trigger_manip_layer2_network_collection_type_bytype_insup
AFTER INSERT OR UPDATE OF layer2_network_collection_type
	ON val_layer2_network_coll_type
	FOR EACH ROW
	EXECUTE PROCEDURE manip_layer2_network_collection_type_bytype();

------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION manip_layer2_network_collection_bytype()
	RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'DELETE' OR
		( TG_OP = 'UPDATE' and OLD.layer2_network_collection_type = 'per-layer2_network')
	THEN
		DELETE FROM layer2_network_collection_hier
		WHERE child_l2_network_coll_id = OLD.layer2_network_collection_id
		AND layer2_network_collection_id IN (
			SELECT layer2_network_collection_id
			FROM layer2_network_collection
			WHERE layer2_network_collection_type = 'by-coll-type'
			AND layer2_network_collection_name = OLD.layer2_network_collection_type
		);

		IF TG_OP = 'DELETE' THEN
			RETURN OLD;
		ELSE
			RETURN NEW;
		END IF;
	END IF;

	IF NEW.layer2_network_collection_type IN ('per-layer2_network','by-coll-type') THEN
		RETURN NEW;
	END IF;


	IF TG_OP = 'UPDATE' THEN
		UPDATE layer2_network_collection_hier
		SET layer2_network_collection_id = (
			SELECT layer2_network_collection_id
			FROM layer2_network_collection
			WHERE layer2_network_collection_type = 'by-coll-type'
			AND layer2_network_collection_name = NEW.layer2_network_collection_type
		),
			child_l2_network_coll_id = NEW.layer2_network_collection_id
		WHERE layer2_network_collection_id = (
			SELECT layer2_network_collection_id
			FROM layer2_network_collection
			WHERE layer2_network_collection_type = 'by-coll-type'
			AND layer2_network_collection_name = OLD.layer2_network_collection_type
		)
		AND child_l2_network_coll_id = OLD.layer2_network_collection_id;
	ELSIF TG_OP = 'INSERT' THEN
		INSERT INTO layer2_network_collection_hier (
			layer2_network_collection_id, child_l2_network_coll_id
		) SELECT layer2_network_collection_id, NEW.layer2_network_collection_id
			FROM layer2_network_collection
			WHERE layer2_network_collection_type = 'by-coll-type'
			AND layer2_network_collection_name = NEW.layer2_network_collection_type;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_manip_layer2_network_collection_bytype_del
	ON layer2_network_collection;
CREATE TRIGGER trigger_manip_layer2_network_collection_bytype_del
BEFORE DELETE
	ON layer2_network_collection
	FOR EACH ROW
	EXECUTE PROCEDURE manip_layer2_network_collection_bytype();

DROP TRIGGER IF EXISTS trigger_manip_layer2_network_collection_bytype_insup
	ON layer2_network_collection;
CREATE TRIGGER trigger_manip_layer2_network_collection_bytype_insup
AFTER INSERT OR UPDATE OF layer2_network_collection_type
	ON layer2_network_collection
	FOR EACH ROW
	EXECUTE PROCEDURE manip_layer2_network_collection_bytype();

------------------------------------------------------------------------------
------------------------------------------------------------------------------
------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION manip_layer3_network_collection_type_bytype()
	RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'DELETE' THEN
		IF OLD.layer3_network_collection_type NOT IN ('by-coll-type', 'per-layer3_network') THEN
			DELETE FROM layer3_network_collection
			WHERE layer3_network_collection_name = OLD.layer3_network_collection_type
			AND layer3_network_collection_type = 'by-coll-type';
		END IF;
		RETURN OLD;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.layer3_network_collection_type IN ('by-coll-type', 'per-layer3_network') AND
			OLD.layer3_network_collection_type NOT IN ('by-coll-type', 'per-layer3_network')
		THEN
			DELETE FROM layer3_network_collection
			WHERE layer3_network_collection_id = OLD.layer3_network_collection_id;
		ELSE
			UPDATE layer3_network_collection
			SET layer3_network_collection_name = NEW.layer3_network_collection_name
			WHERE layer3_network_collection_name = OLD.layer3_network_collection_type
			AND layer3_network_collection_type = 'by-coll-type';
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.layer3_network_collection_type NOT IN ('by-coll-type', 'per-layer3_network') THEN
			INSERT INTO layer3_network_collection (
				layer3_network_collection_name, layer3_network_collection_type
			) VALUES (
				NEW.layer3_network_collection_type, 'by-coll-type'
			);
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_manip_layer3_network_collection_type_bytype_del
	ON val_layer3_network_coll_type;
CREATE TRIGGER trigger_manip_layer3_network_collection_type_bytype_del
BEFORE DELETE
	ON val_layer3_network_coll_type
	FOR EACH ROW
	EXECUTE PROCEDURE manip_layer3_network_collection_type_bytype();

DROP TRIGGER IF EXISTS trigger_manip_layer3_network_collection_type_bytype_insup
	ON val_layer3_network_coll_type;
CREATE TRIGGER trigger_manip_layer3_network_collection_type_bytype_insup
AFTER INSERT OR UPDATE OF layer3_network_collection_type
	ON val_layer3_network_coll_type
	FOR EACH ROW
	EXECUTE PROCEDURE manip_layer3_network_collection_type_bytype();

------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION manip_layer3_network_collection_bytype()
	RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'DELETE' OR
		( TG_OP = 'UPDATE' and OLD.layer3_network_collection_type = 'per-layer3_network')
	THEN
		DELETE FROM layer3_network_collection_hier
		WHERE child_l3_network_coll_id = OLD.layer3_network_collection_id
		AND layer3_network_collection_id IN (
			SELECT layer3_network_collection_id
			FROM layer3_network_collection
			WHERE layer3_network_collection_type = 'by-coll-type'
			AND layer3_network_collection_name = OLD.layer3_network_collection_type
		);

		IF TG_OP = 'DELETE' THEN
			RETURN OLD;
		ELSE
			RETURN NEW;
		END IF;
	END IF;

	IF NEW.layer3_network_collection_type IN ('per-layer3_network','by-coll-type') THEN
		RETURN NEW;
	END IF;


	IF TG_OP = 'UPDATE' THEN
		UPDATE layer3_network_collection_hier
		SET layer3_network_collection_id = (
			SELECT layer3_network_collection_id
			FROM layer3_network_collection
			WHERE layer3_network_collection_type = 'by-coll-type'
			AND layer3_network_collection_name = NEW.layer3_network_collection_type
		),
			child_l3_network_coll_id = NEW.layer3_network_collection_id
		WHERE layer3_network_collection_id = (
			SELECT layer3_network_collection_id
			FROM layer3_network_collection
			WHERE layer3_network_collection_type = 'by-coll-type'
			AND layer3_network_collection_name = OLD.layer3_network_collection_type
		)
		AND child_l3_network_coll_id = OLD.layer3_network_collection_id;
	ELSIF TG_OP = 'INSERT' THEN
		INSERT INTO layer3_network_collection_hier (
			layer3_network_collection_id, child_l3_network_coll_id
		) SELECT layer3_network_collection_id, NEW.layer3_network_collection_id
			FROM layer3_network_collection
			WHERE layer3_network_collection_type = 'by-coll-type'
			AND layer3_network_collection_name = NEW.layer3_network_collection_type;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_manip_layer3_network_collection_bytype_del
	ON layer3_network_collection;
CREATE TRIGGER trigger_manip_layer3_network_collection_bytype_del
BEFORE DELETE
	ON layer3_network_collection
	FOR EACH ROW
	EXECUTE PROCEDURE manip_layer3_network_collection_bytype();

DROP TRIGGER IF EXISTS trigger_manip_layer3_network_collection_bytype_insup
	ON layer3_network_collection;
CREATE TRIGGER trigger_manip_layer3_network_collection_bytype_insup
AFTER INSERT OR UPDATE OF layer3_network_collection_type
	ON layer3_network_collection
	FOR EACH ROW
	EXECUTE PROCEDURE manip_layer3_network_collection_bytype();


------------------------------------------------------------------------------
------------------------------------------------------------------------------
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION manip_company_collection_type_bytype()
	RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'DELETE' THEN
		IF OLD.company_collection_type NOT IN ('by-coll-type', 'per-company') THEN
			DELETE FROM company_collection
			WHERE company_collection_name = OLD.company_collection_type
			AND company_collection_type = 'by-coll-type';
		END IF;
		RETURN OLD;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.company_collection_type IN ('by-coll-type', 'per-company') AND
			OLD.company_collection_type NOT IN ('by-coll-type', 'per-company')
		THEN
			DELETE FROM company_collection
			WHERE company_collection_id = OLD.company_collection_id;
		ELSE
			UPDATE company_collection
			SET company_collection_name = NEW.company_collection_name
			WHERE company_collection_name = OLD.company_collection_type
			AND company_collection_type = 'by-coll-type';
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.company_collection_type NOT IN ('by-coll-type', 'per-company') THEN
			INSERT INTO company_collection (
				company_collection_name, company_collection_type
			) VALUES (
				NEW.company_collection_type, 'by-coll-type'
			);
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_manip_company_collection_type_bytype_del
	ON val_company_collection_type;
CREATE TRIGGER trigger_manip_company_collection_type_bytype_del
BEFORE DELETE
	ON val_company_collection_type
	FOR EACH ROW
	EXECUTE PROCEDURE manip_company_collection_type_bytype();

DROP TRIGGER IF EXISTS trigger_manip_company_collection_type_bytype_insup
	ON val_company_collection_type;
CREATE TRIGGER trigger_manip_company_collection_type_bytype_insup
AFTER INSERT OR UPDATE OF company_collection_type
	ON val_company_collection_type
	FOR EACH ROW
	EXECUTE PROCEDURE manip_company_collection_type_bytype();

------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION manip_company_collection_bytype()
	RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'DELETE' OR
		( TG_OP = 'UPDATE' and OLD.company_collection_type = 'per-company')
	THEN
		DELETE FROM company_collection_hier
		WHERE child_company_collection_id = OLD.company_collection_id
		AND company_collection_id IN (
			SELECT company_collection_id
			FROM company_collection
			WHERE company_collection_type = 'by-coll-type'
			AND company_collection_name = OLD.company_collection_type
		);

		IF TG_OP = 'DELETE' THEN
			RETURN OLD;
		ELSE
			RETURN NEW;
		END IF;
	END IF;

	IF NEW.company_collection_type IN ('per-company','by-coll-type') THEN
		RETURN NEW;
	END IF;


	IF TG_OP = 'UPDATE' THEN
		UPDATE company_collection_hier
		SET company_collection_id = (
			SELECT company_collection_id
			FROM company_collection
			WHERE company_collection_type = 'by-coll-type'
			AND company_collection_name = NEW.company_collection_type
		),
			child_company_collection_id = NEW.company_collection_id
		WHERE company_collection_id = (
			SELECT company_collection_id
			FROM company_collection
			WHERE company_collection_type = 'by-coll-type'
			AND company_collection_name = OLD.company_collection_type
		)
		AND child_company_collection_id = OLD.company_collection_id;
	ELSIF TG_OP = 'INSERT' THEN
		INSERT INTO company_collection_hier (
			company_collection_id, child_company_collection_id
		) SELECT company_collection_id, NEW.company_collection_id
			FROM company_collection
			WHERE company_collection_type = 'by-coll-type'
			AND company_collection_name = NEW.company_collection_type;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_manip_company_collection_bytype_del
	ON company_collection;
CREATE TRIGGER trigger_manip_company_collection_bytype_del
BEFORE DELETE
	ON company_collection
	FOR EACH ROW
	EXECUTE PROCEDURE manip_company_collection_bytype();

DROP TRIGGER IF EXISTS trigger_manip_company_collection_bytype_insup
	ON company_collection;
CREATE TRIGGER trigger_manip_company_collection_bytype_insup
AFTER INSERT OR UPDATE OF company_collection_type
	ON company_collection
	FOR EACH ROW
	EXECUTE PROCEDURE manip_company_collection_bytype();

------------------------------------------------------------------------------
------------------------------------------------------------------------------
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION manip_netblock_collection_type_bytype()
	RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'DELETE' THEN
		IF OLD.netblock_collection_type NOT IN ('by-coll-type', 'per-netblock') THEN
			DELETE FROM netblock_collection
			WHERE netblock_collection_name = OLD.netblock_collection_type
			AND netblock_collection_type = 'by-coll-type';
		END IF;
		RETURN OLD;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.netblock_collection_type IN ('by-coll-type', 'per-netblock') AND
			OLD.netblock_collection_type NOT IN ('by-coll-type', 'per-netblock')
		THEN
			DELETE FROM netblock_collection
			WHERE netblock_collection_id = OLD.netblock_collection_id;
		ELSE
			UPDATE netblock_collection
			SET netblock_collection_name = NEW.netblock_collection_name
			WHERE netblock_collection_name = OLD.netblock_collection_type
			AND netblock_collection_type = 'by-coll-type';
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.netblock_collection_type NOT IN ('by-coll-type', 'per-netblock') THEN
			INSERT INTO netblock_collection (
				netblock_collection_name, netblock_collection_type
			) VALUES (
				NEW.netblock_collection_type, 'by-coll-type'
			);
		END IF;
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_manip_netblock_collection_type_bytype_del
	ON val_netblock_collection_type;
CREATE TRIGGER trigger_manip_netblock_collection_type_bytype_del
BEFORE DELETE
	ON val_netblock_collection_type
	FOR EACH ROW
	EXECUTE PROCEDURE manip_netblock_collection_type_bytype();

DROP TRIGGER IF EXISTS trigger_manip_netblock_collection_type_bytype_insup
	ON val_netblock_collection_type;
CREATE TRIGGER trigger_manip_netblock_collection_type_bytype_insup
AFTER INSERT OR UPDATE OF netblock_collection_type
	ON val_netblock_collection_type
	FOR EACH ROW
	EXECUTE PROCEDURE manip_netblock_collection_type_bytype();

------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION manip_netblock_collection_bytype()
	RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'DELETE' OR
		( TG_OP = 'UPDATE' and OLD.netblock_collection_type = 'per-netblock')
	THEN
		DELETE FROM netblock_collection_hier
		WHERE child_netblock_collection_id = OLD.netblock_collection_id
		AND netblock_collection_id IN (
			SELECT netblock_collection_id
			FROM netblock_collection
			WHERE netblock_collection_type = 'by-coll-type'
			AND netblock_collection_name = OLD.netblock_collection_type
		);

		IF TG_OP = 'DELETE' THEN
			RETURN OLD;
		ELSE
			RETURN NEW;
		END IF;
	END IF;

	IF NEW.netblock_collection_type IN ('per-netblock','by-coll-type') THEN
		RETURN NEW;
	END IF;


	IF TG_OP = 'UPDATE' THEN
		UPDATE netblock_collection_hier
		SET netblock_collection_id = (
			SELECT netblock_collection_id
			FROM netblock_collection
			WHERE netblock_collection_type = 'by-coll-type'
			AND netblock_collection_name = NEW.netblock_collection_type
		),
			child_netblock_collection_id = NEW.netblock_collection_id
		WHERE netblock_collection_id = (
			SELECT netblock_collection_id
			FROM netblock_collection
			WHERE netblock_collection_type = 'by-coll-type'
			AND netblock_collection_name = OLD.netblock_collection_type
		)
		AND child_netblock_collection_id = OLD.netblock_collection_id;
	ELSIF TG_OP = 'INSERT' THEN
		INSERT INTO netblock_collection_hier (
			netblock_collection_id, child_netblock_collection_id
		) SELECT netblock_collection_id, NEW.netblock_collection_id
			FROM netblock_collection
			WHERE netblock_collection_type = 'by-coll-type'
			AND netblock_collection_name = NEW.netblock_collection_type;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_manip_netblock_collection_bytype_del
	ON netblock_collection;
CREATE TRIGGER trigger_manip_netblock_collection_bytype_del
BEFORE DELETE
	ON netblock_collection
	FOR EACH ROW
	EXECUTE PROCEDURE manip_netblock_collection_bytype();

DROP TRIGGER IF EXISTS trigger_manip_netblock_collection_bytype_insup
	ON netblock_collection;
CREATE TRIGGER trigger_manip_netblock_collection_bytype_insup
AFTER INSERT OR UPDATE OF netblock_collection_type
	ON netblock_collection
	FOR EACH ROW
	EXECUTE PROCEDURE manip_netblock_collection_bytype();

------------------------------------------------------------------------------
------------------------------------------------------------------------------
------------------------------------------------------------------------------
