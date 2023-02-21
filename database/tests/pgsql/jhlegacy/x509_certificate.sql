-- Copyright (c) 2021 Todd Kover
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

-- \ir ../../../ddl/legacy.sql

-- Trigger tests
--
CREATE OR REPLACE FUNCTION x509_certificate_regresssion() RETURNS BOOLEAN AS $$
DECLARE
	crt			x509_signed_certificate%ROWTYPE;
	key			private_key%ROWTYPE;
	key2		private_key%ROWTYPE;
	csr			certificate_signing_request%ROWTYPE;
	lc			x509_certificate%ROWTYPE;
	pkhid		public_key_hash.public_key_hash_id%TYPE;
BEGIN
	RAISE NOTICE 'x509_certificate_regresssion: Cleanup Records from Previous Tests';

	RAISE NOTICE '++ x509_certificate_regresssion: Inserting testing data';

	INSERT INTO public_key_hash ( description ) VALUES ('JHTEST')
		RETURNING public_key_hash_id INTO pkhid;

	INSERT INTO public_key_hash_hash (
		public_key_hash_id, x509_fingerprint_hash_algorighm, calculated_hash)
	VALUES
		(pkhid, 'sha1', '3d11fabecb351b2acf5e770a74d982f60aabd722'),
		(pkhid, 'sha256', 'fdda3d3506725d80cbdafe4eace4ec7e1b17be8e3c1cf2f5551af3b41d6053c1');

	INSERT INTO x509_certificate (
		friendly_name, public_key, private_key, public_key_hash_id,
		certificate_sign_req, subject, subject_key_identifier,
		valid_from, valid_to
	) VALUES (
		'testca', '-----BEGIN CERTIFICATE-----
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
-----END CERTIFICATE-----', '-----BEGIN RSA PRIVATE KEY-----
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
-----END RSA PRIVATE KEY-----', pkhid, '-----BEGIN CERTIFICATE REQUEST-----
MIIBnDCCAQUCAQAwGzEZMBcGA1UEAwwQdGVzdC5leGFtcGxlLm9yZzCBnzANBgkq
hkiG9w0BAQEFAAOBjQAwgYkCgYEAzA8Dg8kBwAXedcOqIgjhi+/mOcThZdQINL5A
oI8bQsqcUCSicKG+n+6M8743WajMLrzC6tSX5WP09gv+iTeWtQXPfQO5N5HTX4qo
EC55mB6BB2HkbfvuGj61qLgvHWrCCxsgvEMbuusHO2e55cdr0YJ8Cvtrxkhe91gz
enIhaBMCAwEAAaBBMD8GCSqGSIb3DQEJDjEyMDAwLgYDVR0RBCcwJYIQdGVzdC5l
eGFtcGxlLm9yZ4IRdGVzdDIuZXhhbXBsZS5vcmcwDQYJKoZIhvcNAQELBQADgYEA
czV3cGPbE0X8FGlZ4c8lzRBqU8Hr8Xsxej2rNcfILCmfMDtXi9x5JUCLNex+Vwdc
6Ror1/h36NBjTTMVxNL7ShAypzM06aDBqi55ti8e8qNv2rXP1/BkJcoYnN0qVuTW
IkkCEMCcnoKNDmJyFTpX7QHYt1znqDG7umIS3p+gqKM=
-----END CERTIFICATE REQUEST-----', 'CN=testca', '2D:81:41:2E:F1:0E:8B:FE:80:E9:98:4F:17:4C:A0:BC:DC:BE:B7:E2',
		now() - '1 day'::interval, now() + '45 days'::interval
	) RETURNING * INTO lc;

	SELECT * INTO crt FROM x509_signed_certificate
	WHERE x509_signed_certificate_id = lc.x509_cert_id;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'x509_signed_certificate did not propagate (%)', lc.x509_cert_id;
	END IF;

	SELECT * INTO key FROM private_key
	WHERE private_key_id = crt.private_key_id;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'private_key not found';
	END IF;

	SELECT * INTO csr FROM certificate_signing_request
	WHERE certificate_signing_request_id = crt.certificate_signing_request_id;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'certificate_signing_request did not propagate';
	END IF;

	IF crt.public_key != '-----BEGIN CERTIFICATE-----
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
-----END CERTIFICATE-----' THEN
		RAISE EXCEPTION 'public_key did not propoagate';
	END IF;

	IF key.private_key != '-----BEGIN RSA PRIVATE KEY-----
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
-----END RSA PRIVATE KEY-----' THEN
		RAISE EXCEPTION 'public_key did not propoagate';
	END IF;

	IF csr.certificate_signing_request != '-----BEGIN CERTIFICATE REQUEST-----
MIIBnDCCAQUCAQAwGzEZMBcGA1UEAwwQdGVzdC5leGFtcGxlLm9yZzCBnzANBgkq
hkiG9w0BAQEFAAOBjQAwgYkCgYEAzA8Dg8kBwAXedcOqIgjhi+/mOcThZdQINL5A
oI8bQsqcUCSicKG+n+6M8743WajMLrzC6tSX5WP09gv+iTeWtQXPfQO5N5HTX4qo
EC55mB6BB2HkbfvuGj61qLgvHWrCCxsgvEMbuusHO2e55cdr0YJ8Cvtrxkhe91gz
enIhaBMCAwEAAaBBMD8GCSqGSIb3DQEJDjEyMDAwLgYDVR0RBCcwJYIQdGVzdC5l
eGFtcGxlLm9yZ4IRdGVzdDIuZXhhbXBsZS5vcmcwDQYJKoZIhvcNAQELBQADgYEA
czV3cGPbE0X8FGlZ4c8lzRBqU8Hr8Xsxej2rNcfILCmfMDtXi9x5JUCLNex+Vwdc
6Ror1/h36NBjTTMVxNL7ShAypzM06aDBqi55ti8e8qNv2rXP1/BkJcoYnN0qVuTW
IkkCEMCcnoKNDmJyFTpX7QHYt1znqDG7umIS3p+gqKM=
-----END CERTIFICATE REQUEST-----' THEN
		RAISE EXCEPTION 'certificate_sign_req did not propoagate';
	END IF;

	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT x509_certificate_regresssion();
-- set search_path=jazzhands;
DROP FUNCTION x509_certificate_regresssion();

ROLLBACK TO x509_tests;

\t off
