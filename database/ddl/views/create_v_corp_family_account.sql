-- Copyright (c) 2013-2014, Todd M. Kover
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

create or replace view v_corp_family_account
AS
SELECT	*
  FROM	account 
 WHERE	account_realm_id in (
	SELECT	account_realm_id
	 FROM	property
	WHERE	property_name = '_root_account_realm_id'
	 AND	property_type = 'Defaults'
);

