-- Copyright (c) 2021-2022, Todd M. Kover
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
--
-- $Id$
--

--
-- The messiness in service_utils.build_software_repository_uri is to deal
-- with unintentional double slashes.  It can _probably_ be smarter, or
-- there coulld be rules imposed on various fields to have or not have
-- slashes.  Arguably those rules are the better choice
--
CREATE OR REPLACE VIEW v_service_source_repository_uri AS
SELECT	service_id,
	is_enabled,
	is_primary,
	service_source_repository_id,
	source_repository_provider_id,
	source_repository_project_id,
	source_repository_project_name,
	source_repository_id,
	source_repository_name,
	source_repository_protocol,
	source_repository_uri_purpose,
	service_source_control_purpose,
	service_utils.build_software_repository_uri(
		template := concat_ws('/',
			regexp_replace(source_repository_uri, '/$', ''),
			regexp_replace(concat_ws('/',
				source_repository_template_path_fragment,
				source_repository_path_fragment,
				service_source_repository_path_fragment),
				'//', '/', 'g')
			),
		project_name := source_repository_project_name,
		repository_name := source_repository_name)
			AS source_repository_uri
FROM	service_source_repository
	JOIN source_repository USING (source_repository_id)
	JOIN source_repository_project USING
		(source_repository_provider_id, source_repository_project_id)
	JOIN source_repository_provider_uri_template
		USING (source_repository_provider_id)
;
