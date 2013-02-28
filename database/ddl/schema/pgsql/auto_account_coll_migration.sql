INSERT INTO val_account_collection_type (account_collection_type ,description, is_infrastructure_type) VALUES ('automated','automatic collections','N');

BEGIN;
UPDATE account SET account_role='test' WHERE account_status = 'enabled' AND account_role='primary';
UPDATE account SET account_role='primary' WHERE account_status = 'enabled' AND account_role='test';
END;
