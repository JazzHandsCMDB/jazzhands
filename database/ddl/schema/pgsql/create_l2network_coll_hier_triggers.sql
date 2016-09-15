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

CREATE OR REPLACE FUNCTION layer2_network_collection_hier_enforce()
RETURNS TRIGGER AS $$
DECLARE
	act	val_layer2_network_coll_type%ROWTYPE;
BEGIN
	SELECT *
	INTO	act
	FROM	val_layer2_network_coll_type
	WHERE	layer2_network_collection_type =
		(select layer2_network_collection_type from layer2_network_collection
			where layer2_network_collection_id = NEW.layer2_network_collection_id);

	IF act.can_have_hierarchy = 'N' THEN
		RAISE EXCEPTION 'Layer2 Network Collections of type % may not be hierarcical',
			act.layer2_network_collection_type
			USING ERRCODE= 'unique_violation';
	END IF;
	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_layer2_network_collection_hier_enforce
	 ON layer2_network_collection_hier;
CREATE CONSTRAINT TRIGGER trigger_layer2_network_collection_hier_enforce
        AFTER INSERT OR UPDATE
        ON layer2_network_collection_hier
		DEFERRABLE INITIALLY IMMEDIATE
        FOR EACH ROW
        EXECUTE PROCEDURE layer2_network_collection_hier_enforce();


-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION layer2_network_collection_member_enforce()
RETURNS TRIGGER AS $$
DECLARE
	act	val_layer2_network_coll_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	act
	FROM	val_layer2_network_coll_type
	WHERE	layer2_network_collection_type =
		(select layer2_network_collection_type from layer2_network_collection
			where layer2_network_collection_id = NEW.layer2_network_collection_id);

	IF act.MAX_NUM_MEMBERS IS NOT NULL THEN
		select count(*)
		  into tally
		  from l2_network_coll_l2_network
		  where layer2_network_collection_id = NEW.layer2_network_collection_id;
		IF tally > act.MAX_NUM_MEMBERS THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF act.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		select count(*)
		  into tally
		  from l2_network_coll_l2_network
		  		inner join layer2_network_collection using (layer2_network_collection_id)
		  where layer2_network_id = NEW.layer2_network_id
		  and	layer2_network_collection_type = act.layer2_network_collection_type;
		IF tally > act.MAX_NUM_COLLECTIONS THEN
			RAISE EXCEPTION 'Layer2 network may not be a member of more than % collections of type %',
				act.MAX_NUM_COLLECTIONS, act.layer2_network_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_layer2_network_collection_member_enforce
	 ON l2_network_coll_l2_network;
CREATE CONSTRAINT TRIGGER trigger_layer2_network_collection_member_enforce
        AFTER INSERT OR UPDATE
        ON l2_network_coll_l2_network
		DEFERRABLE INITIALLY IMMEDIATE
        FOR EACH ROW
        EXECUTE PROCEDURE layer2_network_collection_member_enforce();


CREATE OR REPLACE FUNCTION l2_net_coll_member_enforce_on_type_change()
RETURNS TRIGGER AS $$
DECLARE
	l2ct		val_layer2_network_coll_type%ROWTYPE;
	old_l2ct	val_layer2_network_coll_type%ROWTYPE;
	tally integer;
BEGIN
	SELECT *
	INTO	l2ct
	FROM	val_layer2_network_coll_type
	WHERE	layer2_network_collection_type = NEW.layer2_network_collection_type;

	SELECT *
	INTO	old_l2ct
	FROM	val_layer2_network_coll_type
	WHERE	layer2_network_collection_type = OLD.layer2_network_collection_type;

	--
	-- We only need to check this if we are enforcing now where we didn't used
	-- to need to
	--
	IF l2ct.max_num_members IS NOT NULL AND
			l2ct.max_num_members IS DISTINCT FROM old_l2ct.max_num_members THEN
		select count(*)
		  into tally
		  from l2_network_coll_l2_network
		  where layer2_network_collection_id = NEW.layer2_network_collection_id;
		IF tally > l2ct.max_num_members THEN
			RAISE EXCEPTION 'Too many members'
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	IF l2ct.MAX_NUM_COLLECTIONS IS NOT NULL THEN
		SELECT MAX(l2count) FROM (
			SELECT
				COUNT(*) AS l2count
			FROM
				l2_network_coll_l2_network JOIN
				layer2_network_collection USING (layer2_network_collection_id)
			WHERE
				layer2_network_collection_type = NEW.layer2_network_collection_type
			GROUP BY
				layer2_network_id
		) x INTO tally;

		IF tally > l2ct.max_num_collections THEN
			RAISE EXCEPTION 'Layer2 network may not be a member of more than % collections of type %',
				l2ct.MAX_NUM_COLLECTIONS, l2ct.layer2_network_collection_type
				USING ERRCODE = 'unique_violation';
		END IF;
	END IF;

	RETURN NEW;
END;
$$
SET search_path=jazzhands
LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS l2_net_coll_member_enforce_on_type_change
	 ON layer2_network_collection;
CREATE CONSTRAINT TRIGGER l2_net_coll_member_enforce_on_type_change
        AFTER UPDATE OF layer2_network_collection_type
        ON layer2_network_collection
		DEFERRABLE INITIALLY IMMEDIATE
        FOR EACH ROW
        EXECUTE PROCEDURE l2_net_coll_member_enforce_on_type_change();

/*
DO $$
RAISE EXCEPTION 'Need to write tests cases and expand to other collections';
$$
*/
