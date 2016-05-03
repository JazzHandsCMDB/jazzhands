-- Copyright (c) 2016, Todd M. Kover
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

CREATE OR REPLACE VIEW v_person AS
SELECT	person_id,
	description,
	coalesce(preferred_first_name, first_name) as first_name,
	middle_name,
	coalesce(preferred_last_name, last_name) as last_name,
	name_suffix,
	gender,
	preferred_first_name,
	preferred_last_name,
	first_name as legal_first_name,
	last_name as legal_last_name,
	nickname,
	birth_date,
	diet,
	shirt_size,
	pant_size,
	hat_size,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM 	person
;
