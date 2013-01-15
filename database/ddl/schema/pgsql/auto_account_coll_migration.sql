INSERT INTO val_account_collection_type (account_collection_type ,description, is_infrastructure_type) VALUES ('automated','automatic collections','N');
INSERT INTO account_collection (account_collection_name, account_collection_type) VALUES ('AppNexus_person','automated');
INSERT INTO account_collection (account_collection_name, account_collection_type) VALUES ('AppNexus_pseudouser','automated');

UPDATE company SET company_short_name ='appnexus' WHERE company_name ='AppNexus, Inc.';
UPDATE company SET company_short_name ='appnexus-eu' WHERE company_name ='AppNexus Europe, Ltd.';
UPDATE company SET company_short_name ='appnexus-il' WHERE company_name ='AppNexus Israel, Ltd.';

INSERT INTO account_collection (account_collection_name, account_collection_type) VALUES ('AppNexus_appnexus_person','automated');
INSERT INTO account_collection (account_collection_name, account_collection_type) VALUES ('AppNexus_appnexus-eu_person','automated');
INSERT INTO account_collection (account_collection_name, account_collection_type) VALUES ('AppNexus_appnexus-il_person','automated');
INSERT INTO account_collection (account_collection_name, account_collection_type) VALUES ('AppNexus_appnexus-il_pseudouser','automated');
INSERT INTO account_collection (account_collection_name, account_collection_type) VALUES ('AppNexus_appnexus-eu_pseudouser','automated');
INSERT INTO account_collection (account_collection_name, account_collection_type) VALUES ('AppNexus_appnexus_pseudouser','automated');

INSERT INTO account_collection (account_collection_name, account_collection_type) VALUES ('AppNexus_NYC2' ,'automated');
INSERT INTO account_collection (account_collection_name, account_collection_type) VALUES ('AppNexus_SEA1' ,'automated');
INSERT INTO account_collection (account_collection_name, account_collection_type) VALUES ('AppNexus_SFO1' ,'automated');
INSERT INTO account_collection (account_collection_name, account_collection_type) VALUES ('AppNexus_PDX1' ,'automated');
INSERT INTO account_collection (account_collection_name, account_collection_type) VALUES ('AppNexus_LHR1' ,'automated');
INSERT INTO account_collection (account_collection_name, account_collection_type) VALUES ('AppNexus_CVG1' ,'automated');
INSERT INTO account_collection (account_collection_name, account_collection_type) VALUES ('AppNexus_HAM1' ,'automated');
INSERT INTO account_collection (account_collection_name, account_collection_type) VALUES ('AppNexus_TLV1' ,'automated');
INSERT INTO account_collection (account_collection_name, account_collection_type) VALUES ('AppNexus_YYZ1' ,'automated');

BEGIN;
UPDATE account SET account_role='test' WHERE account_status = 'enabled' AND account_role='primary';
UPDATE account SET account_role='primary' WHERE account_status = 'enabled' AND account_role='test';
END;
