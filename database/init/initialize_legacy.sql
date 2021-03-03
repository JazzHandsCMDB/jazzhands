-- Copyright (c) 2019, Todd M. Kover
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
-- These are things needed to make jazzhands_legay work and will go away
-- in a future iteration
--

INSERT INTO val_property_type (
	property_type,
	description
) VALUES (
	'JazzHandsLegacySupport',
	'properties point to things that exist for jazzhands_legacy support'
);

INSERT INTO val_device_collection_type (
	device_collection_type,
	description,
	can_have_hierarchy
) VALUES (
	'JazzHandsLegacySupport',
	'device collections to make JazzHandsLegacySupport work',
	'N'
);

WITh dc AS (
	INSERT INTO device_collection (
		device_collection_name,
		device_collection_type,
		description
	) VALUES (
		'IsMonitoredDevice',
		'JazzHandsLegacySupport',
		'jazzhands_legacy.is_monitored is set'
	) RETURNING *
),vp AS (
	INSERT INTO val_property (
		property_name,
		property_type,
		description,
		property_data_type,
		permit_device_collection_id
	) VALUES (
		'IsMonitoredDevice',
		'JazzHandsLegacySupport',
		'jazzhands_legacy.is_monitored is set',
		'none',
		'REQUIRED'
	) RETURNING *
) INSERT INTO property (
		property_name, property_type, device_collection_id
) SELECT property_name, property_type, device_collection_id
FROM vp, dc;

WITh dc AS (
	INSERT INTO device_collection (
		device_collection_name,
		device_collection_type,
		description
	) VALUES (
		'ShouldConfigFetch',
		'JazzHandsLegacySupport',
		'jazzhands_legacy.should_fetch_config is set'
	) RETURNING *
),vp AS (
	INSERT INTO val_property (
		property_name,
		property_type,
		description,
		property_data_type,
		permit_device_collection_id
	) VALUES (
		'ShouldConfigFetch',
		'JazzHandsLegacySupport',
		'jazzhands_legacy.should_fetch_config is set',
		'none',
		'REQUIRED'
	) RETURNING *
) INSERT INTO property (
		property_name, property_type, device_collection_id
) SELECT property_name, property_type, device_collection_id
FROM vp, dc;

WITh dc AS (
	INSERT INTO device_collection (
		device_collection_name,
		device_collection_type,
		description
	) VALUES (
		'IsLocallyManagedDevice',
		'JazzHandsLegacySupport',
		'jazzhands_legacy.is_locally_managed is set'
	) RETURNING *
),vp AS (
	INSERT INTO val_property (
		property_name,
		property_type,
		description,
		property_data_type,
		permit_device_collection_id
	) VALUES (
		'IsLocallyManagedDevice',
		'JazzHandsLegacySupport',
		'jazzhands_legacy.is_locally_managed is set',
		'none',
		'REQUIRED'
	) RETURNING *
) INSERT INTO property (
		property_name, property_type, device_collection_id
) SELECT property_name, property_type, device_collection_id
FROM vp, dc;

----

INSERT INTO val_device_collection_type (
	device_collection_type,
	description,
	max_num_collections,
	can_have_hierarchy
) VALUES (
	'JazzHandsLegacySupport-AutoMgmtProtocol',
	'device collections to make JazzHandsLegacySupport work',
	1,
	'N'
);

INSERT INTO val_property (
	property_name,
	property_type,
	description,
	property_data_type,
	permit_device_collection_id,
	property_value_device_collection_type_restriction,
	is_multivalue
) VALUES (
	'AutoMgmtProtocol',
	'JazzHandsLegacySupport',
	'jazzhands_legacy.is_locally_managed is set',
	'list',
	'REQUIRED',
	'JazzHandsLegacySupport-AutoMgmtProtocol',
	'Y'
);

INSERT INTO val_property_value (
	property_name,
	property_type,
	valid_property_value,
	description
) VALUES (
	'AutoMgmtProtocol',
	'JazzHandsLegacySupport',
	'ssh',
	'ssh is the devices AutoMgmtProtocol'
);

INSERT INTO val_property_value (
	property_name,
	property_type,
	valid_property_value,
	description
) VALUES (
	'AutoMgmtProtocol',
	'JazzHandsLegacySupport',
	'telnet',
	'telnet is the-AutoMgmtProtocol'
);

WITH dc AS (
	INSERT INTO device_collection (
		device_collection_name,
		device_collection_type,
		description
	) VALUES (
		'ssh',
		'JazzHandsLegacySupport-AutoMgmtProtocol',
		'ssh is the devices AutoMgmtProtocol'
	) RETURNING *
) INSERT INTO property (
		property_name, property_type, property_value, device_collection_id
) SELECT 'AutoMgmtProtocol', 'JazzHandsLegacySupport', 'ssh', device_collection_id
FROM dc;


WITH dc AS (
	INSERT INTO device_collection (
		device_collection_name,
		device_collection_type,
		description
	) VALUES (
		'telnet',
		'JazzHandsLegacySupport-AutoMgmtProtocol',
		'telnet is the devices AutoMgmtProtocol'
	) RETURNING *
) INSERT INTO property (
		property_name, property_type, property_value, device_collection_id
) SELECT 'AutoMgmtProtocol', 'JazzHandsLegacySupport', 'telnet', device_collection_id
FROM dc;

