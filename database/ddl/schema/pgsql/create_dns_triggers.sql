/*
 * Copyright (c) 2012 Todd Kover
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

CREATE OR REPLACE FUNCTION dns_rec_before() RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'DELETE' THEN
		PERFORM 1 FROM jazzhands.dns_domain WHERE dns_domain_id IN (
		    OLD.dns_domain_id, netblock_utils.find_rvs_zone_from_netblock_id(OLD.netblock_id)
		)
		FOR UPDATE;

		RETURN OLD;
	ELSIF TG_OP = 'INSERT' THEN
		IF NEW.netblock_id IS NOT NULL THEN
			PERFORM 1 FROM jazzhands.dns_domain WHERE dns_domain_id IN (
		    	NEW.dns_domain_id, netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
			) FOR UPDATE;
		END IF;

		RETURN NEW;
	ELSE
		IF OLD.netblock_id IS DISTINCT FROM NEW.netblock_id THEN
			IF OLD.netblock_id IS NOT NULL THEN
				PERFORM 1 FROM jazzhands.dns_domain WHERE dns_domain_id IN (
			    	OLD.dns_domain_id, netblock_utils.find_rvs_zone_from_netblock_id(OLD.netblock_id))
				FOR UPDATE;
			END IF;
			IF NEW.netblock_id IS NOT NULL THEN
				PERFORM 1 FROM jazzhands.dns_domain WHERE dns_domain_id IN (
			    	NEW.dns_domain_id, netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
				)
				FOR UPDATE;
			END IF;
		ELSE
			IF NEW.netblock_id IS NOT NULL THEN
				PERFORM 1 FROM jazzhands.dns_domain WHERE dns_domain_id IN (
			    	NEW.dns_domain_id, netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
				) FOR UPDATE;
			END IF;
		END IF;

		RETURN NEW;
	END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_rec_before ON dns_record;
CREATE TRIGGER trigger_dns_rec_before 
	BEFORE INSERT OR DELETE OR UPDATE 
	ON dns_record 
	FOR EACH ROW
	EXECUTE PROCEDURE dns_rec_before();

CREATE OR REPLACE FUNCTION update_dns_zone() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
		UPDATE jazzhands.dns_domain SET zone_last_updated = clock_timestamp()
            WHERE dns_domain_id = NEW.dns_domain_id
			AND ( zone_last_updated < last_generated
			OR zone_last_updated is NULL);

		IF TG_OP = 'UPDATE' THEN
			IF OLD.dns_domain_id != NEW.dns_domain_id THEN
				UPDATE jazzhands.dns_domain SET zone_last_updated = clock_timestamp()
					 WHERE dns_domain_id = OLD.dns_domain_id
					 AND ( zone_last_updated < last_generated or zone_last_updated is NULL );
			END IF;
			IF NEW.netblock_id != OLD.netblock_id THEN
				UPDATE jazzhands.dns_domain SET zone_last_updated = clock_timestamp()
					 WHERE dns_domain_id in (
						 netblock_utils.find_rvs_zone_from_netblock_id(OLD.netblock_id),
						 netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
					)
				     AND ( zone_last_updated < last_generated or zone_last_updated is NULL );
			END IF;
		ELSIF TG_OP = 'INSERT' AND NEW.netblock_id is not NULL THEN
			UPDATE jazzhands.dns_domain SET zone_last_updated = clock_timestamp()
				WHERE dns_domain_id = 
					netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id)
				AND ( zone_last_updated < last_generated or zone_last_updated is NULL );

		END IF;
	END IF;

    IF TG_OP = 'DELETE' THEN
        UPDATE jazzhands.dns_domain SET zone_last_updated = clock_timestamp()
			WHERE dns_domain_id = OLD.dns_domain_id
			AND ( zone_last_updated < last_generated or zone_last_updated is NULL );

		IF OLD.dns_type = 'A' OR OLD.dns_type = 'AAAA' THEN
			UPDATE jazzhands.dns_domain SET zone_last_updated = clock_timestamp()
                 WHERE  dns_domain_id = netblock_utils.find_rvs_zone_from_netblock_id(OLD.netblock_id)
				 AND ( zone_last_updated < last_generated or zone_last_updated is NULL );
        END IF;
    END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_dns_zone ON dns_record;
CREATE CONSTRAINT TRIGGER trigger_update_dns_zone 
	AFTER INSERT OR DELETE OR UPDATE 
	ON dns_record 
	INITIALLY DEFERRED
	FOR EACH ROW 
	EXECUTE PROCEDURE update_dns_zone();

---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION dns_rec_type_validation() RETURNS TRIGGER AS $$
BEGIN
	IF NEW.dns_type in ('A', 'AAAA') AND NEW.netblock_id IS NULL THEN
		RAISE EXCEPTION 'Attempt to set % record without a Netblock',
			NEW.dns_type;
	END IF;

	IF NEW.netblock_Id is not NULL and 
			( NEW.dns_value IS NOT NULL OR NEW.dns_value_record_id IS NOT NULL ) THEN
		RAISE EXCEPTION 'Both dns_value and netblock_id may not be set';
	END IF;

	IF NEW.dns_value IS NOT NULL AND NEW.dns_value_record_id IS NOT NULL THEN
		RAISE EXCEPTION 'Both dns_value and dns_value_record_id may not be set';
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_dns_rec_a_type_validation ON dns_record;
CREATE TRIGGER trigger_dns_rec_a_type_validation 
	BEFORE INSERT OR UPDATE 
	ON dns_record 
	FOR EACH ROW 
	EXECUTE PROCEDURE dns_rec_type_validation();
