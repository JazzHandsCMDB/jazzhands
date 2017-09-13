\set ON_ERROR_STOP 
-- rollback;
-- begin;

insert into val_x509_certificate_file_fmt
	(x509_file_format, description)
values	 
	('pem', 'human readable rsa certificate'),
	('der', 'binary representation'),
	('keytool', 'Java keystore .jks'),
	('pkcs12', 'PKCS12 .p12 file')
;

insert into val_x509_key_usage
	(x509_key_usg, description, is_extended)
values
	('digitalSignature',	'verifying digital signatures other than other certs/CRLs,  such as those used in an entity authentication service, a data origin authentication service, and/or an integrity service', 'N'),
	('nonRepudiation',	'verifying digital signatures other than other certs/CRLs, to provide a non-repudiation service that protects against the signing entity falsely denying some action.  Also known as contentCommitment', 'N'),
	('keyEncipherment',	'key is used for enciphering private or secret keys', 'N'),
	('dataEncipherment',	'key is used for directly enciphering raw user data without the use of an intermediate symmetric cipher', 'N'),
	('keyAgreement',	NULL, 'N'),
	('keyCertSign',		'key signs other certificates; must be set with ca bit', 'N'),
	('cRLSign',		'key is for verifying signatures on certificate revocation lists', 'N'),
	('encipherOnly',	'with keyAgreement bit, key used for enciphering data while performing key agreement', 'N'),
	('decipherOnly',	'with keyAgreement bit, key used for deciphering data while performing key agreement', 'N'),
	('serverAuth',		'SSL/TLS Web Server Authentication', 'Y'),
	('clientAuth',		'SSL/TLS Web Client Authentication', 'Y'),
	('codeSigning',		'Code signing', 'Y'),
	('emailProtection',	'E-mail Protection (S/MIME)', 'Y'),
	('timeStamping',	'Trusted Timestamping', 'Y'),
	('OCSPSigning',		'Signing OCSP Responses', 'Y')
;

insert into val_x509_key_usage_category
	(x509_key_usg_cat, description)
values
	('ca', 'used to identify a certificate authority'),
	('revocation', 'Used to identify entity that signs crl/ocsp responses'),
	('service', 'used to identify a service on the netowrk'),
	('server', 'used to identify a server as a client'),
	('application', 'cross-authenticate applications'),
	('account', 'used to identify an account/user/person')
;

insert into x509_key_usage_categorization
	(x509_key_usg_cat, x509_key_usg)
values
	('ca',  'keyCertSign'),
	('revocation',  'cRLSign'),
	('revocation',  'OCSPSigning'),
	('service',  'digitalSignature'),
	('service',  'keyEncipherment'),
	('service',  'serverAuth'),
	('application',  'digitalSignature'),
	('application',  'keyEncipherment'),
	('application',  'serverAuth')
;
-- rollback;
