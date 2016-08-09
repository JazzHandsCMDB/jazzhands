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

\set ON_ERROR_STOP


--
-- $HeadURL$
-- $Id$
--

CREATE OR REPLACE FUNCTION layer3_network_collection_hier_enforce()
RETURNS TRIGGER AS $$
DECLARE
	act	val_layer3_network_coll_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	act
	FROM	val_layer3_network_coll_type
	WHERE	layer3_network_collection_type =
		(select layer3_network_collection_type from layer3_network_collection
			where layer3_network_collection_id = NEW.layer3_network_collection_id);

	IF act.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Layer3 Network Collections of type % may not be hierarcical',
			act.layer3_network_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_layer3_network_collection_hier_enforce
	 ON layer3_network_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_layer3_network_collection_hier_enforce
        AFTER INSERT OR UPDATE 
        ON layer3_network_collection_hier
		DEFERRABLE INITIALLY IMMEDIATE
        FOR EACH ROW
        EXECUTE PROCEDURE layer3_network_collection_hier_enforce();


-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION layer3_network_collection_member_enforce()
RETURNS TRIGGER AS $$
DECLARE
	act	val_layer3_network_coll_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	act
	FROM	val_layer3_network_coll_type
	WHERE	layer3_network_collection_type =
		(select layer3_network_collection_type from layer3_network_collection
			where layer3_network_collection_id = NEW.layer3_network_collection_id);

	IF act.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from l3_network_coll_l3_network
		  where layer3_network_collection_id = NEW.layer3_network_collection_id;
		IF tally > act.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF act.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from l3_network_coll_l3_network
		  		inner join layer3_network_collection using (layer3_network_collection_id)
		  where layer3_network_id = NEW.layer3_network_id
		  and	layer3_network_collection_type = act.layer3_network_collection_type;
		IF tally > act.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Layer3 Network may not be a member of more than % collections of type %',
				act.MAX_NUM_COLLECTIONS, act.layer3_network_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_layer3_network_collection_member_enforce
	 ON l3_network_coll_l3_network;
CREATE CONSTRAINT TRIGGER trigger_layer3_network_collection_member_enforce
        AFTER INSERT OR UPDATE 
        ON l3_network_coll_l3_network
		DEFERRABLE INITIALLY IMMEDIATE
        FOR EACH ROW
        EXECUTE PROCEDURE layer3_network_collection_member_enforce();

CREATE OR REPLACE FUNCTION l3_net_coll_member_enforce_on_type_change()
RETURNS TRIGGER AS $$
DECLARE
	l3ct		val_layer3_network_coll_type%ROWTYPE;
	old_l3ct	val_layer3_network_coll_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	l3ct
	FROM	val_layer3_network_coll_type
	WHERE	layer3_network_collection_type = NEW.layer3_network_collection_type;

	SELECT *
	INTO	old_l3ct
	FROM	val_layer3_network_coll_type
	WHERE	layer3_network_collection_type = OLD.layer3_network_collection_type;

	--
	-- We only need to check this if we are enforcing now where we didn't used
	-- to need to
	--
	IF l3ct.max_num_members IS NOT NULL AND 
			l3ct.max_num_members IS DISTINCT FROM old_l3ct.max_num_members THEN
		select count(*)
		  into tally
		  from l3_network_coll_l3_network
		  where layer3_network_collection_id = NEW.layer3_network_collection_id;
		IF tally > l3ct.max_num_members THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF l3ct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		SELECT MAX(l3count) FROM (
			SELECT
				COUNT(*) AS l3count
			FROM
				l3_network_coll_l3_network JOIN
				layer3_network_collection USING (layer3_network_collection_id)
			WHERE
				layer3_network_collection_type = NEW.layer3_network_collection_type
			GROUP BY
				layer3_network_id
		) x INTO tally;

		IF tally > l3ct.max_num_collections THEN
			RAISE EXCEPTION 'Layer2 network may not be a member of more than % collections of type %',
				l3ct.MAX_NUM_COLLECTIONS, l3ct.layer3_network_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS l3_net_coll_member_enforce_on_type_change
	 ON layer3_network_collection;
CREATE CONSTRAINT TRIGGER l3_net_coll_member_enforce_on_type_change
        AFTER UPDATE OF layer3_network_collection_type
        ON layer3_network_collection
		DEFERRABLE INITIALLY IMMEDIATE
        FOR EACH ROW
        EXECUTE PROCEDURE l3_net_coll_member_enforce_on_type_change();

/*
DO $$
RAISE EXCEPTION 'Need to write tests cases and expand to other collections';
$$
*/
