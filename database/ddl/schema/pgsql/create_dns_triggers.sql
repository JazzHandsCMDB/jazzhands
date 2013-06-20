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
		PERFORM 1 FROM dns_domain WHERE dns_domain_id = OLD.dns_domain_id FOR UPDATE;
		RETURN OLD;
	ELSE
		PERFORM 1 FROM dns_domain WHERE dns_domain_id = NEW.dns_domain_id FOR UPDATE;
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
		UPDATE jazzhands.dns_domain SET zone_last_updated = now()
            WHERE dns_domain_id = NEW.dns_domain_id;

		IF NEW.dns_type = 'A' THEN
			UPDATE jazzhands.dns_domain SET zone_last_updated = now()
				WHERE dns_domain_id = netblock_utils.find_rvs_zone_from_netblock_id(NEW.netblock_id);
		END IF;

		IF TG_OP = 'UPDATE' THEN
			IF OLD.dns_domain_id != NEW.dns_domain_id THEN
				UPDATE jazzhands.dns_domain SET zone_last_updated = now()
					 WHERE dns_domain_id = OLD.dns_domain_id;
			END IF;
			IF NEW.dns_type = 'A' THEN
				IF OLD.netblock_id != NEW.netblock_id THEN
					UPDATE jazzhands.dns_domain SET zone_last_updated = now()
						 WHERE dns_domain_id = netblock_utils.find_rvs_zone_from_netblock_id(OLD.netblock_id);
				END IF;
			END IF;
		END IF;
	END IF;

    IF TG_OP = 'DELETE' THEN
        UPDATE jazzhands.dns_domain SET zone_last_updated = now()
			WHERE dns_domain_id = OLD.dns_domain_id;

        IF OLD.dns_type = 'A' THEN
			UPDATE jazzhands.dns_domain SET zone_last_updated = now()
                 WHERE  dns_domain_id = netblock_utils.find_rvs_zone_from_netblock_id(OLD.netblock_id);
        END IF;
    END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_dns_zone ON dns_record;
CREATE TRIGGER trigger_update_dns_zone AFTER INSERT OR DELETE OR UPDATE 
	ON dns_record FOR EACH ROW EXECUTE PROCEDURE update_dns_zone();

