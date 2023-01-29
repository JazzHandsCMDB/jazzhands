-- Copyright (c) 2016-2022 Todd Kover
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

-- $Id$


\set ON_ERROR_STOP

\t on
SAVEPOINT x509_tests;

-- \ir ../../ddl/schema/pgsql/create_x509_triggers.sql

--
-- Trigger tests
--
CREATE OR REPLACE FUNCTION x509_regression() RETURNS BOOLEAN AS $$
DECLARE
	crt			x509_signed_certificate%ROWTYPE;
	key			private_key%ROWTYPE;
	key2		private_key%ROWTYPE;
	csr			certificate_signing_request%ROWTYPE;
	pkhid		public_key_hash.public_key_hash_id%TYPE;
BEGIN
	RAISE NOTICE 'x509_regression: Cleanup Records from Previous Tests';

	--
	-- note - some of these will handle two different types of exceptions
	-- one happens when pl/perl is involved, one is when it's not.
	--

	RAISE NOTICE '++ x509_regression: Inserting testing data';

	INSERT INTO public_key_hash ( description ) VALUES ('JHTESTKEY1')
		RETURNING public_key_hash_id INTO pkhid;

	---- begin thing that will get deleted after column drop
	BEGIN
		INSERT INTO public_key_hash_hash (
			public_key_hash_id, x509_fingerprint_hash_algorighm, calculated_hash)
		VALUES
			(pkhid, 'sha1', '3d11fabecb351b2acf5e770a74d982f60aabd722'),
			(pkhid, 'sha256', 'fdda3d3506725d80cbdafe4eace4ec7e1b17be8e3c1cf2f5551af3b41d6053c1');

		RAISE NOTICE '... private key1';
		INSERT INTO private_key (
			private_key_encryption_type, public_key_hash_id, private_key
		) VALUES (
			'rsa', pkhid, '-----BEGIN RSA PRIVATE KEY-----
MIICXQIBAAKBgQDMDwODyQHABd51w6oiCOGL7+Y5xOFl1Ag0vkCgjxtCypxQJKJw
ob6f7ozzvjdZqMwuvMLq1JflY/T2C/6JN5a1Bc99A7k3kdNfiqgQLnmYHoEHYeRt
++4aPrWouC8dasILGyC8Qxu66wc7Z7nlx2vRgnwK+2vGSF73WDN6ciFoEwIDAQAB
AoGBAKtHOtsGABsOkhBlAMv6il6sKaF5uPuAwraKrrJWDDq+1/+JEHPbv6Z8VAFP
OyRdw6zDMhRsB2c6xGU14huI9kxRv5hN8/G/ei2DJBFaYAK/ov+gWqDwrh2dTnmv
CXT1WtMcCcs35hT0/Ol0p/pRIGmqMqJqDEP7bL29gTEe7FuhAkEA7Hc1Whq1DSX2
K/nj1b41fe0KndQ/V+Bg4/5Y1iYo4DKBc+xCm7UkbFrnVRgRripSAcqcaVrh3VyB
YI1LE5bJowJBANzqda5pUrjRmEYbDjYXmEJUsKWd8cNkVZDivI5EJsGnN/moEcFF
DHj6P9JPZ8zKcPdSQSkRnQtbZgSJKnC+rtECQHseuoW2wCwfZuSQ0QL6bYmqgUua
Nnz/1BMB3Klr5v6M7YA5NJk0IMnWLvrMdHA1ksth/jyQ2GdUgfyOtNd3PHcCQQDJ
iI7hFK5lcrfyxL3bNP0vDem0vPkQIlk4+s+/DYc5xR34gI3p/d7aApn0d4IfPlN+
HKjbGXlmIfRYkPWJszrxAkAO/L2Bxa37jiJhQIvzyP0YSPQP8TkJVd5ZAuZYdNoW
XnIepxee5+AQOE9jbVhgZZ5zkso+hG4Ov9pMX/O1xbvy
-----END RSA PRIVATE KEY-----'
		) RETURNING * INTO key;
		RAISE EXCEPTION 'a-ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE 'backwards compatability passed';
	END;
	---- end thing that will get deleted after column drop
	--- below does the same key as above that was rolled back and does
	--- it "correctly"

	INSERT INTO public_key_hash_hash (
		public_key_hash_id, x509_fingerprint_hash_algorighm, calculated_hash)
	VALUES
		(pkhid, 'sha1', '3d11fabecb351b2acf5e770a74d982f60aabd722'),
		(pkhid, 'sha256', 'fdda3d3506725d80cbdafe4eace4ec7e1b17be8e3c1cf2f5551af3b41d6053c1');

	INSERT INTO private_key (
		private_key_encryption_type, public_key_hash_id, private_key
	) VALUES (
		'rsa', pkhid, '-----BEGIN RSA PRIVATE KEY-----
MIICXQIBAAKBgQDMDwODyQHABd51w6oiCOGL7+Y5xOFl1Ag0vkCgjxtCypxQJKJw
ob6f7ozzvjdZqMwuvMLq1JflY/T2C/6JN5a1Bc99A7k3kdNfiqgQLnmYHoEHYeRt
++4aPrWouC8dasILGyC8Qxu66wc7Z7nlx2vRgnwK+2vGSF73WDN6ciFoEwIDAQAB
AoGBAKtHOtsGABsOkhBlAMv6il6sKaF5uPuAwraKrrJWDDq+1/+JEHPbv6Z8VAFP
OyRdw6zDMhRsB2c6xGU14huI9kxRv5hN8/G/ei2DJBFaYAK/ov+gWqDwrh2dTnmv
CXT1WtMcCcs35hT0/Ol0p/pRIGmqMqJqDEP7bL29gTEe7FuhAkEA7Hc1Whq1DSX2
K/nj1b41fe0KndQ/V+Bg4/5Y1iYo4DKBc+xCm7UkbFrnVRgRripSAcqcaVrh3VyB
YI1LE5bJowJBANzqda5pUrjRmEYbDjYXmEJUsKWd8cNkVZDivI5EJsGnN/moEcFF
DHj6P9JPZ8zKcPdSQSkRnQtbZgSJKnC+rtECQHseuoW2wCwfZuSQ0QL6bYmqgUua
Nnz/1BMB3Klr5v6M7YA5NJk0IMnWLvrMdHA1ksth/jyQ2GdUgfyOtNd3PHcCQQDJ
iI7hFK5lcrfyxL3bNP0vDem0vPkQIlk4+s+/DYc5xR34gI3p/d7aApn0d4IfPlN+
HKjbGXlmIfRYkPWJszrxAkAO/L2Bxa37jiJhQIvzyP0YSPQP8TkJVd5ZAuZYdNoW
XnIepxee5+AQOE9jbVhgZZ5zkso+hG4Ov9pMX/O1xbvy
-----END RSA PRIVATE KEY-----'
		) RETURNING * INTO key;

	RAISE NOTICE '... certificate signing request 1';
	INSERT INTO certificate_signing_request (
		friendly_name, subject, certificate_signing_request,
		public_key_hash_id, private_key_id
	) VALUES (
		'foo', 'bar', '-----BEGIN CERTIFICATE REQUEST-----
MIIBnDCCAQUCAQAwGzEZMBcGA1UEAwwQdGVzdC5leGFtcGxlLm9yZzCBnzANBgkq
hkiG9w0BAQEFAAOBjQAwgYkCgYEAzA8Dg8kBwAXedcOqIgjhi+/mOcThZdQINL5A
oI8bQsqcUCSicKG+n+6M8743WajMLrzC6tSX5WP09gv+iTeWtQXPfQO5N5HTX4qo
EC55mB6BB2HkbfvuGj61qLgvHWrCCxsgvEMbuusHO2e55cdr0YJ8Cvtrxkhe91gz
enIhaBMCAwEAAaBBMD8GCSqGSIb3DQEJDjEyMDAwLgYDVR0RBCcwJYIQdGVzdC5l
eGFtcGxlLm9yZ4IRdGVzdDIuZXhhbXBsZS5vcmcwDQYJKoZIhvcNAQELBQADgYEA
czV3cGPbE0X8FGlZ4c8lzRBqU8Hr8Xsxej2rNcfILCmfMDtXi9x5JUCLNex+Vwdc
6Ror1/h36NBjTTMVxNL7ShAypzM06aDBqi55ti8e8qNv2rXP1/BkJcoYnN0qVuTW
IkkCEMCcnoKNDmJyFTpX7QHYt1znqDG7umIS3p+gqKM=
-----END CERTIFICATE REQUEST-----',
		pkhid, key.private_key_id
	) RETURNING * INTO csr;

	RAISE NOTICE '... signed certificate 1';
	INSERT INTO x509_signed_certificate (
		x509_certificate_type, subject, friendly_name, subject_key_identifier,
		public_key, private_key_id, public_key_hash_id,
		certificate_signing_request_id, valid_from, valid_to
	) VALUES (
		'default', 'foo', 'bar', '2D:81:41:2E:F1:0E:8B:FE:80:E9:98:4F:17:4C:A0:BC:DC:BE:B7:E2',
		'-----BEGIN CERTIFICATE-----
MIICrzCCAhigAwIBAgIUHfFS98q90UCC/cGC477GOfe03VgwDQYJKoZIhvcNAQEL
BQAwGzEZMBcGA1UEAwwQdGVzdC5leGFtcGxlLm9yZzAgFw0yMjAxMjQxNzI4NDRa
GA8yMDcyMDExMjE3Mjg0NFowGzEZMBcGA1UEAwwQdGVzdC5leGFtcGxlLm9yZzCB
nzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEAzA8Dg8kBwAXedcOqIgjhi+/mOcTh
ZdQINL5AoI8bQsqcUCSicKG+n+6M8743WajMLrzC6tSX5WP09gv+iTeWtQXPfQO5
N5HTX4qoEC55mB6BB2HkbfvuGj61qLgvHWrCCxsgvEMbuusHO2e55cdr0YJ8Cvtr
xkhe91gzenIhaBMCAwEAAaOB7TCB6jAuBgNVHREEJzAlghB0ZXN0LmV4YW1wbGUu
b3JnghF0ZXN0Mi5leGFtcGxlLm9yZzAdBgNVHQ4EFgQULYFBLvEOi/6A6ZhPF0yg
vNy+t+IwVgYDVR0jBE8wTYAULYFBLvEOi/6A6ZhPF0ygvNy+t+KhH6QdMBsxGTAX
BgNVBAMMEHRlc3QuZXhhbXBsZS5vcmeCFB3xUvfKvdFAgv3BguO+xjn3tN1YMBEG
CWCGSAGG+EIBAQQEAwIGQDAMBgNVHRMBAf8EAjAAMAsGA1UdDwQEAwIF4DATBgNV
HSUEDDAKBggrBgEFBQcDATANBgkqhkiG9w0BAQsFAAOBgQB5AdPDcfPG5bHvNVi8
/tg1UtQQOSoMlHIb+Fu/3NyCX1Gk97X79aUcpcdtKBSjTjHOJWJv0UMdEByZK/z7
F3b1zTgX46xt721FvfITnir1dYe6sHsxP4eOanIw72aQAXZJ+7OMC1HLCz6AsRFE
nUS/000kIsBL4osVaAlelbzI+Q==
-----END CERTIFICATE-----', key.private_key_id, pkhid,
		csr.certificate_signing_request_id, '-infinity', 'infinity'
	) RETURNING * INTO crt;


	WITH p AS (
		INSERT INTO public_key_hash ( description ) VALUES ('JHTEST')
			RETURNING *
	) INSERT INTO private_key (
		private_key_encryption_type, public_key_hash_id, private_key
	) SELECT 'rsa', public_key_hash_id, '-- KEY2 --'
	FROM p RETURNING * INTO key2;

	RAISE NOTICE '++ x509_regression: Inserting testing data';

	RAISE NOTICE 'Checking if inserting a mismatched csr AND private_key public_key_hash_id fails...';
	BEGIN
		INSERT INTO x509_signed_certificate (
			x509_certificate_type, subject, friendly_name,
			subject_key_identifier, public_key_hash_id,
			public_key, private_key_id, certificate_signing_request_id,
			valid_from, valid_to
		) VALUES (
			'default', 'foo', 'bar',
			'91:B5:67:91:45:90:7C:03:53:B1:55:9B:8F:A9:26:86:28:1E:32:62', key2.public_key_hash_id,
			'-----BEGIN CERTIFICATE-----
MIICrzCCAhigAwIBAgIUC+15lE3cDUdxaeGxSt3ya4sepbowDQYJKoZIhvcNAQEL
BQAwGzEZMBcGA1UEAwwQdGVzdC5leGFtcGxlLm9yZzAgFw0yMjAxMjQxOTEwNDVa
GA8yMDcyMDExMjE5MTA0NVowGzEZMBcGA1UEAwwQdGVzdC5leGFtcGxlLm9yZzCB
nzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEAtN4kUrpTsyzEJjyZi1eBdpHsx8OI
GrbvvLpYVbNq7gVm87vicwrNXFkroRJXRjzpn8VTTBdOgfGBLIiUVUpkgfktlMWK
pY5BrjmOCYHWqRUwMG2lW1yE2rUnmJpxJZnf7u38axB/xpC6n8Y+LbLRjX3zv76O
z6bf3A/KpMEfIE0CAwEAAaOB7TCB6jAuBgNVHREEJzAlghB0ZXN0LmV4YW1wbGUu
b3JnghF0ZXN0Mi5leGFtcGxlLm9yZzAdBgNVHQ4EFgQUkbVnkUWQfANTsVWbj6km
higeMmIwVgYDVR0jBE8wTYAUkbVnkUWQfANTsVWbj6kmhigeMmKhH6QdMBsxGTAX
BgNVBAMMEHRlc3QuZXhhbXBsZS5vcmeCFAvteZRN3A1HcWnhsUrd8muLHqW6MBEG
CWCGSAGG+EIBAQQEAwIGQDAMBgNVHRMBAf8EAjAAMAsGA1UdDwQEAwIF4DATBgNV
HSUEDDAKBggrBgEFBQcDATANBgkqhkiG9w0BAQsFAAOBgQCULq28dPNwwZApFNor
wCFnkZRJbvX+IRJIy2UlQDx0RAPqXdtqwqSIfvOVdngOoLFN5Q62VC+B+abjP8Qn
f/2LFwRTe5s1ZJ3pEX9JS/io+GLy7l0HGHKKjOBggzWnYszY8VSPODEd5qLB+a6R
nM+LICtcTdIoL8QBAMKBrCUy1A==
-----END CERTIFICATE-----', key.private_key_id, csr.certificate_signing_request_id,
			'-infinity', 'infinity'
		) RETURNING * INTO crt;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation OR data_exception THEN
		RAISE NOTICE '... It did';
	WHEN OTHERS THEN
		RAISE EXCEPTION '... It did for unexpected reasons (% %)',
			SQLSTATE, SQLERRM ;
	END;

	RAISE NOTICE 'Checking if inserting a mismatched private_key  public_key_hash_id fails...';
	BEGIN
		INSERT INTO x509_signed_certificate (
			x509_certificate_type, subject, friendly_name,
			subject_key_identifier, public_key_hash_id,
			public_key, private_key_id,
			valid_from, valid_to
		) VALUES (
			'default', 'foo', 'bar',
			'91:B5:67:91:45:90:7C:03:53:B1:55:9B:8F:A9:26:86:28:1E:32:62', key2.public_key_hash_id,
			'-----BEGIN CERTIFICATE-----
MIICrzCCAhigAwIBAgIUHfFS98q90UCC/cGC477GOfe03VgwDQYJKoZIhvcNAQEL
BQAwGzEZMBcGA1UEAwwQdGVzdC5leGFtcGxlLm9yZzAgFw0yMjAxMjQxNzI4NDRa
GA8yMDcyMDExMjE3Mjg0NFowGzEZMBcGA1UEAwwQdGVzdC5leGFtcGxlLm9yZzCB
nzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEAzA8Dg8kBwAXedcOqIgjhi+/mOcTh
ZdQINL5AoI8bQsqcUCSicKG+n+6M8743WajMLrzC6tSX5WP09gv+iTeWtQXPfQO5
N5HTX4qoEC55mB6BB2HkbfvuGj61qLgvHWrCCxsgvEMbuusHO2e55cdr0YJ8Cvtr
xkhe91gzenIhaBMCAwEAAaOB7TCB6jAuBgNVHREEJzAlghB0ZXN0LmV4YW1wbGUu
b3JnghF0ZXN0Mi5leGFtcGxlLm9yZzAdBgNVHQ4EFgQULYFBLvEOi/6A6ZhPF0yg
vNy+t+IwVgYDVR0jBE8wTYAULYFBLvEOi/6A6ZhPF0ygvNy+t+KhH6QdMBsxGTAX
BgNVBAMMEHRlc3QuZXhhbXBsZS5vcmeCFB3xUvfKvdFAgv3BguO+xjn3tN1YMBEG
CWCGSAGG+EIBAQQEAwIGQDAMBgNVHRMBAf8EAjAAMAsGA1UdDwQEAwIF4DATBgNV
HSUEDDAKBggrBgEFBQcDATANBgkqhkiG9w0BAQsFAAOBgQB5AdPDcfPG5bHvNVi8
/tg1UtQQOSoMlHIb+Fu/3NyCX1Gk97X79aUcpcdtKBSjTjHOJWJv0UMdEByZK/z7
F3b1zTgX46xt721FvfITnir1dYe6sHsxP4eOanIw72aQAXZJ+7OMC1HLCz6AsRFE
nUS/000kIsBL4osVaAlelbzI+Q==
-----END CERTIFICATE-----', key.private_key_id,
			'-infinity', 'infinity'
		) RETURNING * INTO crt;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation OR data_exception THEN
		RAISE NOTICE '... It did';
	WHEN OTHERS THEN
		RAISE EXCEPTION '... It did for unexpected reasons (% %)',
			SQLSTATE, SQLERRM ;
	END;

	RAISE NOTICE 'Checking if inserting a mismatched csr public_key_hash_id fails...';
	BEGIN
		INSERT INTO x509_signed_certificate (
			x509_certificate_type, subject, friendly_name,
			subject_key_identifier, public_key_hash_id,
			public_key, certificate_signing_request_id,
			valid_from, valid_to
		) VALUES (
			'default', 'foo', 'bar',
			'91:B5:67:91:45:90:7C:03:53:B1:55:9B:8F:A9:26:86:28:1E:32:62', key2.public_key_hash_id,
			'-----BEGIN CERTIFICATE-----
MIICrzCCAhigAwIBAgIUHfFS98q90UCC/cGC477GOfe03VgwDQYJKoZIhvcNAQEL
BQAwGzEZMBcGA1UEAwwQdGVzdC5leGFtcGxlLm9yZzAgFw0yMjAxMjQxNzI4NDRa
GA8yMDcyMDExMjE3Mjg0NFowGzEZMBcGA1UEAwwQdGVzdC5leGFtcGxlLm9yZzCB
nzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEAzA8Dg8kBwAXedcOqIgjhi+/mOcTh
ZdQINL5AoI8bQsqcUCSicKG+n+6M8743WajMLrzC6tSX5WP09gv+iTeWtQXPfQO5
N5HTX4qoEC55mB6BB2HkbfvuGj61qLgvHWrCCxsgvEMbuusHO2e55cdr0YJ8Cvtr
xkhe91gzenIhaBMCAwEAAaOB7TCB6jAuBgNVHREEJzAlghB0ZXN0LmV4YW1wbGUu
b3JnghF0ZXN0Mi5leGFtcGxlLm9yZzAdBgNVHQ4EFgQULYFBLvEOi/6A6ZhPF0yg
vNy+t+IwVgYDVR0jBE8wTYAULYFBLvEOi/6A6ZhPF0ygvNy+t+KhH6QdMBsxGTAX
BgNVBAMMEHRlc3QuZXhhbXBsZS5vcmeCFB3xUvfKvdFAgv3BguO+xjn3tN1YMBEG
CWCGSAGG+EIBAQQEAwIGQDAMBgNVHRMBAf8EAjAAMAsGA1UdDwQEAwIF4DATBgNV
HSUEDDAKBggrBgEFBQcDATANBgkqhkiG9w0BAQsFAAOBgQB5AdPDcfPG5bHvNVi8
/tg1UtQQOSoMlHIb+Fu/3NyCX1Gk97X79aUcpcdtKBSjTjHOJWJv0UMdEByZK/z7
F3b1zTgX46xt721FvfITnir1dYe6sHsxP4eOanIw72aQAXZJ+7OMC1HLCz6AsRFE
nUS/000kIsBL4osVaAlelbzI+Q==
-----END CERTIFICATE-----', csr.certificate_signing_request_id,
			'-infinity', 'infinity'
		) RETURNING * INTO crt;
		RAISE EXCEPTION '... IT DID NOT. (%)', jsonb_pretty(to_jsonb(crt));
	EXCEPTION WHEN integrity_constraint_violation OR data_exception THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if updating a bum public_key_hash in x509_signed_cert fails...';
	BEGIN
		UPDATE x509_signed_certificate
		SET public_key_hash_id = key2.public_key_hash_id
		WHERE private_key_id = key.private_key_id;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation OR data_exception THEN
		RAISE NOTICE '... It did';
	WHEN OTHERS THEN
		RAISE EXCEPTION '... It did for unexpected reasons (% %)',
			SQLSTATE, SQLERRM ;
	END;

	RAISE NOTICE 'Checking if updating a bum public_key_hash in private_key fails...';
	BEGIN
		UPDATE private_key
		SET public_key_hash_id = key2.public_key_hash_id
		WHERE private_key_id = key.private_key_id;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation OR data_exception THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if updating a bum public_key_hash in certificate_signing_request fails...';
	BEGIN
		UPDATE certificate_signing_request
		SET public_key_hash_id = key2.public_key_hash_id
		WHERE certificate_signing_request_id = csr.certificate_signing_request_id;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation OR data_exception THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if updating a only private key in x509_signed_cert fails...';
	BEGIN
		UPDATE x509_signed_certificate
		SET private_key_id = key2.private_key_id
		WHERE x509_signed_certificate_id = crt.x509_signed_certificate_id;
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation OR data_exception THEN
		RAISE NOTICE '... It did';
	END;

	RAISE NOTICE 'Checking if inserting both an external id AND private key fails...';
	BEGIN
		INSERT INTO private_key (
			private_key_encryption_type, public_key_hash_id,
			private_key, external_id
		) VALUES (
			'rsa', key2.public_key_hash_id,
			'-----BEGIN RSA PRIVATE KEY-----
MIICXQIBAAKBgQDMDwODyQHABd51w6oiCOGL7+Y5xOFl1Ag0vkCgjxtCypxQJKJw
ob6f7ozzvjdZqMwuvMLq1JflY/T2C/6JN5a1Bc99A7k3kdNfiqgQLnmYHoEHYeRt
++4aPrWouC8dasILGyC8Qxu66wc7Z7nlx2vRgnwK+2vGSF73WDN6ciFoEwIDAQAB
AoGBAKtHOtsGABsOkhBlAMv6il6sKaF5uPuAwraKrrJWDDq+1/+JEHPbv6Z8VAFP
OyRdw6zDMhRsB2c6xGU14huI9kxRv5hN8/G/ei2DJBFaYAK/ov+gWqDwrh2dTnmv
CXT1WtMcCcs35hT0/Ol0p/pRIGmqMqJqDEP7bL29gTEe7FuhAkEA7Hc1Whq1DSX2
K/nj1b41fe0KndQ/V+Bg4/5Y1iYo4DKBc+xCm7UkbFrnVRgRripSAcqcaVrh3VyB
YI1LE5bJowJBANzqda5pUrjRmEYbDjYXmEJUsKWd8cNkVZDivI5EJsGnN/moEcFF
DHj6P9JPZ8zKcPdSQSkRnQtbZgSJKnC+rtECQHseuoW2wCwfZuSQ0QL6bYmqgUua
Nnz/1BMB3Klr5v6M7YA5NJk0IMnWLvrMdHA1ksth/jyQ2GdUgfyOtNd3PHcCQQDJ
iI7hFK5lcrfyxL3bNP0vDem0vPkQIlk4+s+/DYc5xR34gI3p/d7aApn0d4IfPlN+
HKjbGXlmIfRYkPWJszrxAkAO/L2Bxa37jiJhQIvzyP0YSPQP8TkJVd5ZAuZYdNoW
XnIepxee5+AQOE9jbVhgZZ5zkso+hG4Ov9pMX/O1xbvy
-----END RSA PRIVATE KEY-----', '/foo/bar/baz'
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did - %', SQLERRM;
	END;

	RAISE NOTICE 'Checking if inserting neither an external id AND private key fails...';
	BEGIN
		INSERT INTO private_key (
			private_key_encryption_type, public_key_hash_id
		) VALUES (
			'rsa', key2.public_key_hash_id
		);
		RAISE EXCEPTION '... IT DID NOT.';
	EXCEPTION WHEN integrity_constraint_violation THEN
		RAISE NOTICE '... It did - %', SQLERRM;
	END;

	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT x509_regression();
-- set search_path=jazzhands;
DROP FUNCTION x509_regression();

ROLLBACK TO x509_tests;

\t off
