-- Copyright (c) 2011-2019, Todd M. Kover
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

-- Copyright (c) 2005-2010, Vonage Holdings Corp.
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--     * Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--     * Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
-- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
-- $Id$
--
create or replace view v_device_collection_hier_detail as 
WITH RECURSIVE var_recurse (
	root_device_collection_id,
	device_collection_id,
	parent_device_collection_id,
	device_collection_level,
	array_path,
	cycle
) as (
	SELECT	device_collection_id	as root_device_collection_id,
		device_collection_id	as device_collection_id,
		device_collection_id	as parent_device_collection_id,
		0			as device_collection_level,
		ARRAY[device_collection_id],
		false
	FROM	device_collection
UNION  ALL
	SELECT	x.root_device_collection_id	as root_device_collection_id,
		dch.child_device_collection_id AS device_collection_id,
		dch.device_collection_id AS parent_device_collection_id,
		x.device_collection_level + 1 as device_collection_level,
		dch.device_collection_id || x.array_path AS array_path,
		dch.device_collection_id = ANY(x.array_path)
	 FROM	var_recurse x
		inner join device_collection_hier dch
			on x.parent_device_collection_id = 
				dch.child_device_collection_id
	WHERE
		NOT x.cycle
) SELECT
	root_device_collection_id	as device_collection_id,
	parent_device_collection_id	as parent_device_collection_id,
	device_collection_level		as device_collection_level
FROM	var_recurse;

