-- transition physicalish_volume

CREATE TABLE block_storage_device (
	block_storage_device_id				bigint NOT NULL,
	block_storage_device_type			varchar(255) NOT NULL,
	device_id							integer	NOT NULL,
	block_storage_device_name			varchar(255) NOT NULL,
	uuid								uuid NULL,
	component_id						integer NULL,
	logical_volume_id					integer NULL,
	encrypted_block_storage_device_id	bigint NULL,
	mpath_disk_id						bigint NULL
);

ALTER TABLE block_storage_device
	ADD CONSTRAINT pk_block_storage_device PRIMARY KEY (block_storage_device_id);

ALTER TABLE block_storage_device
	ADD CONSTRAINT ak_block_storage_device UNIQUE (device_id, uuid);

ALTER TABLE block_storage_device ADD COLUMN data_ins_user varchar(255);
ALTER TABLE block_storage_device ADD COLUMN data_ins_date TIMESTAMP WITH TIME ZONE;
ALTER TABLE block_storage_device ADD COLUMN data_upd_user varchar(255);
ALTER TABLE block_storage_device ADD COLUMN data_upd_date TIMESTAMP WITH TIME ZONE;

CREATE TABLE val_block_storage_device_type (
	block_storage_device_type	varchar(255),
	description			varchar(512)
);

ALTER TABLE val_block_storage_device_type ADD COLUMN data_ins_user varchar(255);
ALTER TABLE val_block_storage_device_type ADD COLUMN data_ins_date TIMESTAMP WITH TIME ZONE;
ALTER TABLE val_block_storage_device_type ADD COLUMN data_upd_user varchar(255);
ALTER TABLE val_block_storage_device_type ADD COLUMN data_upd_date TIMESTAMP WITH TIME ZONE;

ALTER TABLE val_block_storage_device_type
	ADD CONSTRAINT pk_block_storage_device_type_block_storage_device_type PRIMARY KEY (block_storage_device_type);

CREATE TABLE encrypted_block_storage_device (
	encrypted_block_storage_device_id	bigint NOT NULL,
	block_storage_device_id		bigint NOT NULL,
	encryption_system			varchar(50) NOT NULL,
	encryption_key_id			integer NOT NULL,
	key_size					integer NOT NULL,		-- probably moves to encryption_key
	cipher						text NOT NULL,			-- probably moves to encryption_key
	offset_sector				integer,
	sector_size					integer
);

ALTER TABLE encrypted_block_storage_device ADD COLUMN data_ins_user varchar(255);
ALTER TABLE encrypted_block_storage_device ADD COLUMN data_ins_date TIMESTAMP WITH TIME ZONE;
ALTER TABLE encrypted_block_storage_device ADD COLUMN data_upd_user varchar(255);
ALTER TABLE encrypted_block_storage_device ADD COLUMN data_upd_date TIMESTAMP WITH TIME ZONE;

CREATE TABLE val_encryption_system (
	encryption_system	varchar(255),
	description			varchar(512)
);

ALTER TABLE val_encryption_system ADD COLUMN data_ins_user varchar(255);
ALTER TABLE val_encryption_system ADD COLUMN data_ins_date TIMESTAMP WITH TIME ZONE;
ALTER TABLE val_encryption_system ADD COLUMN data_upd_user varchar(255);
ALTER TABLE val_encryption_system ADD COLUMN data_upd_date TIMESTAMP WITH TIME ZONE;

ALTER TABLE val_encryption_system
	ADD CONSTRAINT pk_val_encryption_system_encryption_system PRIMARY KEY (encryption_system);

-- broken out from logical_volume

CREATE TABLE filesystem (
	block_storage_device_id		bigint NOT NULL,
	device_id			integer NOT NULL,
	filesystem_type		varchar(50) NOT NULL,
	mountpoint			varchar(4096) NULL
);

ALTER TABLE val_filesystem ADD COLUMN data_ins_user varchar(255);
ALTER TABLE val_filesystem ADD COLUMN data_ins_date TIMESTAMP WITH TIME ZONE;
ALTER TABLE val_filesystem ADD COLUMN data_upd_user varchar(255);
ALTER TABLE val_filesystem ADD COLUMN data_upd_date TIMESTAMP WITH TIME ZONE;

ALTER TABLE filesystem
	ADD CONSTRAINT ak_filesystem_block_storage_device_id UNIQUE (block_storage_device_id);

ALTER TABLE physicalish_volume ADD COLUMN block_storage_device_id bigint NULL;
ALTER TABLE physicalish_volume ADD COLUMN physicalish_volume_size_in_bytes bigint NULL;
ALTER TABLE physicalish_volume ADD COLUMN uuid uuid NULL;
ALTER TABLE volume_group ADD COLUMN uuid uuid NULL;
ALTER TABLE logical_volume ADD COLUMN uuid uuid NULL;

--
-- Foreign Keys
--

ALTER TABLE block_storage_device
	ADD CONSTRAINT fk_block_storage_device_device_id FOREIGN KEY (device_id)
		REFERENCES device(device_id);

ALTER TABLE block_storage_device
	ADD CONSTRAINT fk_block_storage_device_device_id FOREIGN KEY (device_id)
		REFERENCES device(device_id);

ALTER TABLE block_storage_device
	ADD CONSTRAINT fk_block_storage_device_block_storage_device_type FOREIGN KEY (block_storage_device_type)
		REFERENCES val_block_storage_device_type(block_storage_device_type);

ALTER TABLE block_storage_device
	ADD CONSTRAINT fk_block_storage_device_component_id FOREIGN KEY (component_id)
		REFERENCES component(component_id);

ALTER TABLE block_storage_device
	ADD CONSTRAINT fk_block_storage_device_logical_volume_id FOREIGN KEY (logical_volume_id)
		REFERENCES logical_volume(logical_volume_id);

ALTER TABLE block_storage_device
	ADD CONSTRAINT fk_block_storage_device_encrypted_block_storage_device_id FOREIGN KEY (encrypted_block_storage_device_id)
		REFERENCES encrypted_block_storage_device(encrypted_block_storage_device_id);

ALTER TABLE block_storage_device
	ADD CONSTRAINT fk_block_storage_device_mpath_disk_id FOREIGN KEY (mpath_disk_id)
		REFERENCES mpath_disk(mpath_disk_id);

ALTER TABLE encrypted_block_storage_device
	ADD CONSTRAINT fk_encrypted_block_storage_device_block_storage_device_id FOREIGN KEY (block_storage_device_id)
		REFERENCES block_storage_device(block_storage_device_id);

ALTER TABLE encrypted_block_storage_device
	ADD CONSTRAINT fk_encrypted_block_storage_device_encryption_system FOREIGN KEY (encryption_system)
		REFERENCES val_encryption_system(encryption_system);

ALTER TABLE filesystem
	ADD CONSTRAINT fk_filesystem_block_storage_device_id_device_id FOREIGN KEY (block_storage_device_id, device_id)
		REFERENCES block_storage_device(block_storage_device_id, device_id);

ALTER TABLE filesystem
	ADD CONSTRAINT fk_filesystem_filesystem_type FOREIGN KEY (filesystem_type)
		REFERENCES val_filesystem_type(filesystem_type);

