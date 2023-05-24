
-- Copyright (c) 2023, Todd M. Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--	http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- $Id$
--

-- deprecated in v0.96.  Can be removed in >= 0.97

CREATE OR REPLACE VIEW val_physicalish_volume_type AS
SELECT	block_storage_device_type AS physicalish_volume_type,
	description,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM val_block_storage_device_type;

CREATE OR REPLACE VIEW physicalish_volume AS
SELECT	bsd.block_storage_device_id	AS physicalish_volume_id,
	bsd.block_storage_device_name AS physicalish_volume_name,
	bsd.block_storage_device_type AS physicalish_volume_type,
	bsd.device_id,
	vclv.logical_volume_id,
	CAST(
		CASE WHEN vclv.logical_volume_id IS NULL THEN bsd.component_id
		ELSE NULL END AS INTEGER) AS component_id,
	bsd.data_ins_user,
	bsd.data_ins_date,
	bsd.data_upd_user,
	bsd.data_upd_date
FROM block_storage_device bsd
	LEFT JOIN virtual_component_logical_volume vclv
		USING (component_id)
WHERE bsd.logical_volume_id IS NULL
;

---
--- XXX ^^^ That is probably WRONG.  device_id should come by other unholy
--- means, but I put this in to get unblocked..

CREATE OR REPLACE VIEW volume_group_physicalish_volume AS
SELECT	volume_group_id,
	block_storage_device_id AS physicalish_volume_id,
	device_id,
	volume_group_primary_position,
	volume_group_secondary_position,
	volume_group_relation,
	data_ins_user,
	data_ins_date,
	data_upd_user,
	data_upd_date
FROM volume_group_block_storage_device;
