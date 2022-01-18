-- Copyright (c) 2021-2022 Todd Kover
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

-- search path jazzhands - if this is being fixed up
-- \ir ../../../ddl/schema/pgsql/create_x509_triggers.sql
-- this is typically set outside but left here
-- set search_path=jazzhands_legacy;
-- \ir ../../../ddl/legacy.sql

--
-- Trigger tests
--
CREATE OR REPLACE FUNCTION deprecated_x509_regression() RETURNS BOOLEAN AS $$
DECLARE
	x509ca		x509_certificate%ROWTYPE;
	x509		x509_certificate%ROWTYPE;
	crt			x509_signed_certificate%ROWTYPE;
	key			private_key%ROWTYPE;
	key2		private_key%ROWTYPE;
	csr			certificate_signing_request%ROWTYPE;
	pkhidca		public_key_hash.public_key_hash_id%TYPE;
	pkhid		public_key_hash.public_key_hash_id%TYPE;
	pkhid2		public_key_hash.public_key_hash_id%TYPE;
	_d			RECORD;
	_r			RECORD;
BEGIN
	RAISE NOTICE 'deprecated_x509_regression: Cleanup Records from Previous Tests';

	RAISE NOTICE '++ deprecated_x509_regression: Inserting testing data';

	INSERT INTO public_key_hash ( description ) VALUES ('testca')
		RETURNING public_key_hash_id INTO pkhidca;
	INSERT INTO public_key_hash_hash (
		public_key_hash_id, x509_fingerprint_hash_algorighm, calculated_hash)
	VALUES
		(pkhidca, 'sha1', '39245fc8eb02fe7d6eb9ee8ed702b1c2d7ba7945'),
		(pkhidca, 'sha256', 'c4d532b45d1731bd3ad9d7af31d6ea1120658a1db83354c0e3dd5a13a145dfde');

	INSERT INTO public_key_hash ( description ) VALUES ('test')
		RETURNING public_key_hash_id INTO pkhid;
	INSERT INTO public_key_hash_hash (
		public_key_hash_id, x509_fingerprint_hash_algorighm, calculated_hash)
	VALUES
		(pkhid, 'sha1', 'b0afa78c070984c2292c13d07403f8c8d2d30994'),
		(pkhid, 'sha256', '23194389db6a58ca4b5e676599d61e686ec16ec8afabf7ad27fe903822548099');

	INSERT INTO public_key_hash ( description ) VALUES ('test')
		RETURNING public_key_hash_id INTO pkhid2;
	INSERT INTO public_key_hash_hash (
		public_key_hash_id, x509_fingerprint_hash_algorighm, calculated_hash)
	VALUES
		(pkhid2, 'sha1', '0458033a7ffd86d1ed4c54f1382a5707e8e0d1d1'),
		(pkhid2, 'sha256', 'dc850d8dc0de56d4c23eb6c5d74381d051bc62953e1804d1470b99f3d68e5e28');

	INSERT INTO x509_certificate (
		friendly_name, is_certificate_authority,
		signing_cert_id, x509_ca_cert_serial_number,
		public_key, private_key, certificate_sign_req, subject,
		subject_key_identifier, public_key_hash_id,
		valid_from, valid_to
	) VALUES (
		'myca', 'Y',
		NULL, NULL,
'-----BEGIN CERTIFICATE-----
MIICWTCCAcKgAwIBAgIUfB68s959NjEn0Jd0fCIfOg39xzcwDQYJKoZIhvcNAQEL
BQAwDzENMAsGA1UEAwwEbXljYTAeFw0yMjAxMjUyMDU4MjRaFw0zMjAxMjMyMDU4
MjRaMA8xDTALBgNVBAMMBG15Y2EwgZ8wDQYJKoZIhvcNAQEBBQADgY0AMIGJAoGB
AMENMhxEbjhX70x/DL/i1uPJ42sSlyzcqd5uNZAgASvX3PWl1NuPxRldp0pkH+HR
/ebHzovrdhJl6OKUnOFHhDkraKAeT0LXx7GnevNojubPk+ehFiYUBud9u58i2ITc
pPJQDWMIbTCN/obqmEZmZQxCCGUgkXDwwpWbUfZGmNq7AgMBAAGjgbEwga4wHQYD
VR0OBBYEFG6ibCG0YS+VFwVYLh4Uv19IKh2xMEoGA1UdIwRDMEGAFG6ibCG0YS+V
FwVYLh4Uv19IKh2xoROkETAPMQ0wCwYDVQQDDARteWNhghR8Hryz3n02MSfQl3R8
Ih86Df3HNzARBglghkgBhvhCAQEEBAMCBkAwDAYDVR0TAQH/BAIwADALBgNVHQ8E
BAMCBeAwEwYDVR0lBAwwCgYIKwYBBQUHAwEwDQYJKoZIhvcNAQELBQADgYEAUkA2
VQNti4JeIuMDcvg+ymMBQFNk/IYFCkyv6nEsnuEoxs+hR+DHluNeKy6Ug37bFZci
lXzffUOhrwxNyj+B950gf2A17yqCEO1TUhrMmBTNsNqOKZ4D7hf113ho13c7sOts
ESzyI4Z4zpiLqdh2JKk6bm61sbJiq9sK5PR9/E4=
-----END CERTIFICATE-----','-----BEGIN RSA PRIVATE KEY-----
MIICXQIBAAKBgQDBDTIcRG44V+9Mfwy/4tbjyeNrEpcs3KnebjWQIAEr19z1pdTb
j8UZXadKZB/h0f3mx86L63YSZejilJzhR4Q5K2igHk9C18exp3rzaI7mz5PnoRYm
FAbnfbufItiE3KTyUA1jCG0wjf6G6phGZmUMQghlIJFw8MKVm1H2RpjauwIDAQAB
AoGBAJ50Vk0dXdqhUqlXHv/hEMCnVSLtf2gzNrp7eztxCYUTCSoXkz8kIoNPe6Bz
zjdsRRrHpaDzA1bWjvBrStkd+kgFKRHKxuWNw+cmOGgoiq70sEtJU93jsVH4jJ2I
ZlrnGosNiE4W0v2c115J5mORDSSx6CpGTcEeod8rQJleoxUBAkEA6I6XRmlDhgZ2
D0dtrlPFntKQHRXKrofAsXg1tLUDgZlTN+65zn+ApEXVQ1IAS9iwu31gYg/eVoEV
TSETd5j/PQJBANSDHq2/sduIVDemvNofTQ2UapUP2zVM8ef8pOAvhUBK40gmwNXe
XGHuUsVA4S0MVIZUXU7qUCUhYN8FKBq0YVcCQDpUeZEJmgwl1rriWZpeHLVHbyo8
awf3uNdKpX3b4TNCd+MRl705sdSCR4mJKdXcVgfQ3Ln77PKZkfQ0laNr1qkCQQCU
+Q3qkzUlRl5zXMmKxuKHIIHO2Py8UqJKFEuodOeeeGD31WLdCjIM3LrdWGwB3mDq
gf2fMpbYUJvN+5lvjv+lAkBPB37iISWKCORIrXXqj0MEZm8xULwvK4dpz+Lo3iR+
Sa5OmRSdB3QTQLJYAXUpFNjWStlp745trTdtWCDKq4vq
-----END RSA PRIVATE KEY-----
','-----BEGIN CERTIFICATE REQUEST-----
MIIBTjCBuAIBADAPMQ0wCwYDVQQDDARteWNhMIGfMA0GCSqGSIb3DQEBAQUAA4GN
ADCBiQKBgQDBDTIcRG44V+9Mfwy/4tbjyeNrEpcs3KnebjWQIAEr19z1pdTbj8UZ
XadKZB/h0f3mx86L63YSZejilJzhR4Q5K2igHk9C18exp3rzaI7mz5PnoRYmFAbn
fbufItiE3KTyUA1jCG0wjf6G6phGZmUMQghlIJFw8MKVm1H2RpjauwIDAQABoAAw
DQYJKoZIhvcNAQELBQADgYEAlJLqThibx2dAea7n4vL2J6q8iDFHzftliFzp8C82
sJDQxuSwkRow0S5QfdloIFupflDowqN+aq8EEm4Rhtd6a+AjirSBBjn1B5AsLRMG
vchNlLMWbnLpKO7hWibl2epMmyEOOdU1dKspRFw4xPZevl0wiFJ4u3i+n8tcTkIE
7aA=
-----END CERTIFICATE REQUEST-----', 'myca',
		'6E:A2:6C:21:B4:61:2F:95:17:05:58:2E:1E:14:BF:5F:48:2A:1D:B1', pkhidca,
		now() - '1 week'::interval, now() + '90 days'::interval
	) RETURNING * INTO x509ca;

	SELECT * INTO _d FROM x509_certificate
		WHERE x509_cert_id = x509ca.x509_cert_id;
	IF _d != x509ca THEN
		RAISE EXCEPTION 'Insert does not match';
	END IF;

	INSERT INTO x509_certificate (
		friendly_name, is_certificate_authority,
		signing_cert_id, x509_ca_cert_serial_number,
		public_key, private_key, certificate_sign_req, subject,
		subject_key_identifier, public_key_hash_id,
		valid_from, valid_to
	) VALUES (
		'mycert.example.org', 'N',
		x509ca.x509_cert_id, 10,
'-----BEGIN CERTIFICATE-----
MIIChDCCAe2gAwIBAgIDEMeIMA0GCSqGSIb3DQEBCwUAMA8xDTALBgNVBAMMBG15
Y2EwHhcNMjIwMTI1MjEwMTAzWhcNMzIwMTIzMjEwMTAzWjAbMRkwFwYDVQQDDBB0
ZXN0LmV4YW1wbGUub3JnMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDUFPW9
OaeDuAoGxaXVwrSwpWC9XEYN9uXRtYEaaOcpHS4vHalkTo+lXwp8b7hEGo7y3P1S
6HSMngBI0UxG0mLGYpVQpKOhJX/+6kMoPB086v1uy90sMrgpMkYP4SND3DEGtsXx
MCvqc2+CaqvqFfmdc1S39w0uXlxbBMUL7buSRwIDAQABo4HhMIHeMC4GA1UdEQQn
MCWCEHRlc3QuZXhhbXBsZS5vcmeCEXRlc3QyLmV4YW1wbGUub3JnMB0GA1UdDgQW
BBSRC7whKI+lne9iCL6l1TR4n+mvijBKBgNVHSMEQzBBgBRuomwhtGEvlRcFWC4e
FL9fSCodsaETpBEwDzENMAsGA1UEAwwEbXljYYIUfB68s959NjEn0Jd0fCIfOg39
xzcwEQYJYIZIAYb4QgEBBAQDAgZAMAwGA1UdEwEB/wQCMAAwCwYDVR0PBAQDAgXg
MBMGA1UdJQQMMAoGCCsGAQUFBwMBMA0GCSqGSIb3DQEBCwUAA4GBAGDl/uMtAgmf
BYTZAk3o1x+/y9jc6JZvO3D6GxwwinR5RETjhu5qsKvqaZrldtl0zndWqJVrTekS
LYmn7ebbBvcii9UANBjEVXa0TDkUa0H3f6F/CFdxEYP0g/a2FeFHUiTvrDZx951o
CO/i3wPwrIJZ8GFI22bcYJyqUcEWQu1F
-----END CERTIFICATE-----','-----BEGIN RSA PRIVATE KEY-----
MIICXQIBAAKBgQDUFPW9OaeDuAoGxaXVwrSwpWC9XEYN9uXRtYEaaOcpHS4vHalk
To+lXwp8b7hEGo7y3P1S6HSMngBI0UxG0mLGYpVQpKOhJX/+6kMoPB086v1uy90s
MrgpMkYP4SND3DEGtsXxMCvqc2+CaqvqFfmdc1S39w0uXlxbBMUL7buSRwIDAQAB
AoGAPxFQlonrn8b97E+gZjX1h8ZWQ1mKV6LBayB/mPvzKg3MayR1+CdInlPqCWEr
uczwD5baGmqYJiziRsU+2py71FomvF5TMppkYuYxiGhTpX+Ydg6F147Na8VdbdIH
IMSJzyVTeb87L960TxIyw39fpHROX7Dg5MD4rUIZfCAV0dkCQQD4LXUeh3Z500su
BggDD6lpCI+nimfCjsh5LnCa7y9+qJiSQqmZxZnDN1pqV1mztnf4t4wRVM/D86Tf
TNEoC3ADAkEA2sQ/IWRO9OEpcvZva1k9WRQ7Hh/nuZ3D1YPeziGnKQW1cONkWF/J
E+Pa1gXOjYrUaBhRYhE//F5pAPt27QRLbQJBANkwnxCqqEqRWXfbm2Nib3YWIfIT
tB6Wamdy9uUAceY8kdleMaL7RUeMx7nM3BnklDW8G/6G5JSuQxmQ1nJfIBUCQFXF
gbb23BoYuaaQRmkBSRNG4lLSUYkt+N0a4d1RxndH/LZxASPBElZRDLjC+BP4rYTO
nAHmH380CNlQvnT5LRUCQQDct+sZPeDjq3ptsfqUHgDrOAmyfrgKFzT47qDBieKt
KRN5Ai2QbA1KLzA3xuv1CyKbYdBHYHIgvf/9YRA4QCWI
-----END RSA PRIVATE KEY-----','-----BEGIN CERTIFICATE REQUEST-----
MIIBnDCCAQUCAQAwGzEZMBcGA1UEAwwQdGVzdC5leGFtcGxlLm9yZzCBnzANBgkq
hkiG9w0BAQEFAAOBjQAwgYkCgYEA1BT1vTmng7gKBsWl1cK0sKVgvVxGDfbl0bWB
GmjnKR0uLx2pZE6PpV8KfG+4RBqO8tz9Uuh0jJ4ASNFMRtJixmKVUKSjoSV//upD
KDwdPOr9bsvdLDK4KTJGD+EjQ9wxBrbF8TAr6nNvgmqr6hX5nXNUt/cNLl5cWwTF
C+27kkcCAwEAAaBBMD8GCSqGSIb3DQEJDjEyMDAwLgYDVR0RBCcwJYIQdGVzdC5l
eGFtcGxlLm9yZ4IRdGVzdDIuZXhhbXBsZS5vcmcwDQYJKoZIhvcNAQELBQADgYEA
TRnHD6TFfszIxpetPVCiGDgkagHvEOKfg8/fZLvAkxLk9JYZFbwhBY5JtmvMLoxc
4hmbJM4hegMIWDVO/g7pzlZ9TM1g3+LmI2TTOo3xgoZQiL86SmG0EHVQhrVUhATe
03EKyIV79xa4mDhTZA9of+VP6AEfjbMskVkuFPLkVEY=
-----END CERTIFICATE REQUEST-----',
		'test.example.org',
		'91:0B:BC:21:28:8F:A5:9D:EF:62:08:BE:A5:D5:34:78:9F:E9:AF:8A', pkhid ,
		now() - '1 week'::interval, now() + '90 days'::interval
	) RETURNING * INTO x509ca;


	SELECT * INTO _d FROM x509_certificate
		WHERE x509_cert_id = x509.x509_cert_id;
	IF _d != x509 THEN
		RAISE EXCEPTION 'Insert does not match';
	END IF;

	RAISE NOTICE '++ : inserting with no key or csr';
	BEGIN
		INSERT INTO x509_certificate (
			friendly_name, is_certificate_authority,
			signing_cert_id, x509_ca_cert_serial_number,
			public_key, private_key, certificate_sign_req, subject,
			subject_key_identifier, public_key_hash_id,
			valid_from, valid_to
		) VALUES (
			'mypubliconlycert.example.org', 'N',
			x509ca.x509_cert_id, 10,
			'-----BEGIN CERTIFICATE-----
MIICiTCCAfKgAwIBAgIDEMeJMA0GCSqGSIb3DQEBCwUAMA8xDTALBgNVBAMMBG15
Y2EwHhcNMjIwMTI1MjEwODM2WhcNMzIwMTIzMjEwODM2WjAnMSUwIwYDVQQDDBxt
eXB1YmxpY29ubHljZXJ0LmV4YW1wbGUub3JnMIGfMA0GCSqGSIb3DQEBAQUAA4GN
ADCBiQKBgQDaNbvhtQYSPuaOrBi3aZD9H/DZk4yukVayxByUBdVmECreJ/ICRBkm
TMOLIS3InbETyr55jqXQ7EothEa4UalE9uO2IHUCd/yBk3ZnUkVvRqnB8rzpE8S2
BlFlIKIooVDPx3CWCpU9S9H/t3BkPSPefn2hcj0DcWlPwz83RnLrlwIDAQABo4Ha
MIHXMCcGA1UdEQQgMB6CHG15cHVibGljb25seWNlcnQuZXhhbXBsZS5vcmcwHQYD
VR0OBBYEFFKyJieSb7ePnQu81hc3ABEP3/wDMEoGA1UdIwRDMEGAFG6ibCG0YS+V
FwVYLh4Uv19IKh2xoROkETAPMQ0wCwYDVQQDDARteWNhghR8Hryz3n02MSfQl3R8
Ih86Df3HNzARBglghkgBhvhCAQEEBAMCBkAwDAYDVR0TAQH/BAIwADALBgNVHQ8E
BAMCBeAwEwYDVR0lBAwwCgYIKwYBBQUHAwEwDQYJKoZIhvcNAQELBQADgYEAOTNN
PpZjp7oSTm0JR0YFmsJhtXaSwNEZ6/GrxSysa2O+St2Z11wt5RwH6xEaQ+K5FpkG
msk1b2lJcIrh4jsRWN5vgCHbqI3/5VmFUbdlURV/XEbmvHwLOcnT13auHF2jcyTx
cclC0mCAUN5Om2XYBtlajwq/4wV00i5VgwehS+0=
-----END CERTIFICATE-----',
			NULL, NULL, 'mypubliconlycert.example.org',
			'52:B2:26:27:92:6F:B7:8F:9D:0B:BC:D6:17:37:00:11:0F:DF:FC:03', pkhid2 ,
			now() - '1 week'::interval, now() + '90 days'::interval
		) RETURNING * INTO _r;

		SELECT * INTO _d FROM x509_certificate
			WHERE x509_cert_id = _r.x509_cert_id;
		IF _d != _r THEN
			RAISE EXCEPTION 'Insert does not match: % %',
				to_jsonb(_r), to_jsonb(_d);
		END IF;
		RAISE EXCEPTION '%', 'a-ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;


	RAISE NOTICE '++ : inserting with only crt, key ';
	BEGIN
		INSERT INTO x509_certificate (
			friendly_name, is_certificate_authority,
			signing_cert_id, x509_ca_cert_serial_number,
			public_key, private_key, certificate_sign_req, subject,
			subject_key_identifier, public_key_hash_id,
			valid_from, valid_to
		) VALUES (
			'mywithkey.example.org', 'N',
			x509ca.x509_cert_id, 10,
'-----BEGIN CERTIFICATE-----
MIICiTCCAfKgAwIBAgIDEMeJMA0GCSqGSIb3DQEBCwUAMA8xDTALBgNVBAMMBG15
Y2EwHhcNMjIwMTI1MjEwODM2WhcNMzIwMTIzMjEwODM2WjAnMSUwIwYDVQQDDBxt
eXB1YmxpY29ubHljZXJ0LmV4YW1wbGUub3JnMIGfMA0GCSqGSIb3DQEBAQUAA4GN
ADCBiQKBgQDaNbvhtQYSPuaOrBi3aZD9H/DZk4yukVayxByUBdVmECreJ/ICRBkm
TMOLIS3InbETyr55jqXQ7EothEa4UalE9uO2IHUCd/yBk3ZnUkVvRqnB8rzpE8S2
BlFlIKIooVDPx3CWCpU9S9H/t3BkPSPefn2hcj0DcWlPwz83RnLrlwIDAQABo4Ha
MIHXMCcGA1UdEQQgMB6CHG15cHVibGljb25seWNlcnQuZXhhbXBsZS5vcmcwHQYD
VR0OBBYEFFKyJieSb7ePnQu81hc3ABEP3/wDMEoGA1UdIwRDMEGAFG6ibCG0YS+V
FwVYLh4Uv19IKh2xoROkETAPMQ0wCwYDVQQDDARteWNhghR8Hryz3n02MSfQl3R8
Ih86Df3HNzARBglghkgBhvhCAQEEBAMCBkAwDAYDVR0TAQH/BAIwADALBgNVHQ8E
BAMCBeAwEwYDVR0lBAwwCgYIKwYBBQUHAwEwDQYJKoZIhvcNAQELBQADgYEAOTNN
PpZjp7oSTm0JR0YFmsJhtXaSwNEZ6/GrxSysa2O+St2Z11wt5RwH6xEaQ+K5FpkG
msk1b2lJcIrh4jsRWN5vgCHbqI3/5VmFUbdlURV/XEbmvHwLOcnT13auHF2jcyTx
cclC0mCAUN5Om2XYBtlajwq/4wV00i5VgwehS+0=
-----END CERTIFICATE-----','-----BEGIN RSA PRIVATE KEY-----
MIICXgIBAAKBgQDaNbvhtQYSPuaOrBi3aZD9H/DZk4yukVayxByUBdVmECreJ/IC
RBkmTMOLIS3InbETyr55jqXQ7EothEa4UalE9uO2IHUCd/yBk3ZnUkVvRqnB8rzp
E8S2BlFlIKIooVDPx3CWCpU9S9H/t3BkPSPefn2hcj0DcWlPwz83RnLrlwIDAQAB
AoGBALhrCWrsb0EkX/7ce9cnJR6IzClWhmNS+g8Dp5OCiqRDrbcr02EO5KJ15h3D
4MnYXDv58ZkSchlsWhS14n8MpRzPTJ3kzKDLDxosPyobOjA2dWxpfR8Dxh+jxlFI
1XJfCdT+yL7jpQWxUjajAZz5csrdeUaGBEMjxnSbh6frGw0BAkEA/zmIpAD5UQ11
fyIGBvi/X4yJeuU0GTtt3PgEpANElJj/cCf4L65I0DE12FmLDliC0YGk4efIiuFG
IFRrUd/gtwJBANrfarrDi1NqcoEt6iXhBFoU+vImiVMuB21Wixrhuk1U8O6ZEU8w
yff+5DX7Bj3mYsFbcFscvqAo3GM+fktErCECQQCMnBvljwvMVcfn1MzRRnXYpEqR
xHjhddZfKN0Vpx8/ZtND7SFU04YV/SaXHS35J1ZbKju2ocXgjZ/e6+N8ZgUdAkEA
zNDlf4AdkSG7pUbiJjA7clDPxGprd3tLV/X0lmNFg7hI/f4fRIvTdE8CH8GYRbSi
FW8L5Tcw649RLU39wVGyAQJAQSKStUsDsckzcuroGA/TDi/NKL4RTAv9oV6gMDPB
utyXJj8gr0B21rp/N5y496yJbwHJQDUl71s3MK+iipSf/Q==
-----END RSA PRIVATE KEY-----',
			NULL,'mywithkey.example.org',
			'52:B2:26:27:92:6F:B7:8F:9D:0B:BC:D6:17:37:00:11:0F:DF:FC:03', pkhid2,
			now() - '1 week'::interval, now() + '90 days'::interval
		) RETURNING * INTO _r;

		SELECT * INTO _d FROM x509_certificate
			WHERE x509_cert_id = _r.x509_cert_id;
		IF _d != _r THEN
			RAISE EXCEPTION 'Insert does not match: % %',
				jsonb_pretty(to_jsonb(_r)), jsonb_pretty(to_jsonb(_d));
		END IF;
		RAISE EXCEPTION '%', 'a-ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;

	RAISE NOTICE '++ : inserting with only crt, csr ';
	BEGIN
		INSERT INTO x509_certificate (
			friendly_name, is_certificate_authority,
			signing_cert_id, x509_ca_cert_serial_number,
			public_key, private_key, certificate_sign_req, subject,
			subject_key_identifier, public_key_hash_id,
			valid_from, valid_to
		) VALUES (
			'mywithcsr.example.org', 'N',
			x509ca.x509_cert_id, 10,
			'-----BEGIN CERTIFICATE-----
MIICiTCCAfKgAwIBAgIDEMeJMA0GCSqGSIb3DQEBCwUAMA8xDTALBgNVBAMMBG15
Y2EwHhcNMjIwMTI1MjEwODM2WhcNMzIwMTIzMjEwODM2WjAnMSUwIwYDVQQDDBxt
eXB1YmxpY29ubHljZXJ0LmV4YW1wbGUub3JnMIGfMA0GCSqGSIb3DQEBAQUAA4GN
ADCBiQKBgQDaNbvhtQYSPuaOrBi3aZD9H/DZk4yukVayxByUBdVmECreJ/ICRBkm
TMOLIS3InbETyr55jqXQ7EothEa4UalE9uO2IHUCd/yBk3ZnUkVvRqnB8rzpE8S2
BlFlIKIooVDPx3CWCpU9S9H/t3BkPSPefn2hcj0DcWlPwz83RnLrlwIDAQABo4Ha
MIHXMCcGA1UdEQQgMB6CHG15cHVibGljb25seWNlcnQuZXhhbXBsZS5vcmcwHQYD
VR0OBBYEFFKyJieSb7ePnQu81hc3ABEP3/wDMEoGA1UdIwRDMEGAFG6ibCG0YS+V
FwVYLh4Uv19IKh2xoROkETAPMQ0wCwYDVQQDDARteWNhghR8Hryz3n02MSfQl3R8
Ih86Df3HNzARBglghkgBhvhCAQEEBAMCBkAwDAYDVR0TAQH/BAIwADALBgNVHQ8E
BAMCBeAwEwYDVR0lBAwwCgYIKwYBBQUHAwEwDQYJKoZIhvcNAQELBQADgYEAOTNN
PpZjp7oSTm0JR0YFmsJhtXaSwNEZ6/GrxSysa2O+St2Z11wt5RwH6xEaQ+K5FpkG
msk1b2lJcIrh4jsRWN5vgCHbqI3/5VmFUbdlURV/XEbmvHwLOcnT13auHF2jcyTx
cclC0mCAUN5Om2XYBtlajwq/4wV00i5VgwehS+0=
-----END CERTIFICATE-----', NULL, '-----BEGIN CERTIFICATE REQUEST-----
MIIBZjCB0AIBADAnMSUwIwYDVQQDDBxteXB1YmxpY29ubHljZXJ0LmV4YW1wbGUu
b3JnMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDaNbvhtQYSPuaOrBi3aZD9
H/DZk4yukVayxByUBdVmECreJ/ICRBkmTMOLIS3InbETyr55jqXQ7EothEa4UalE
9uO2IHUCd/yBk3ZnUkVvRqnB8rzpE8S2BlFlIKIooVDPx3CWCpU9S9H/t3BkPSPe
fn2hcj0DcWlPwz83RnLrlwIDAQABoAAwDQYJKoZIhvcNAQELBQADgYEAEvQxg8eC
RQ5Gz6O6YzyL/th+qZicw1uJ6sXtaCudvnHUo2J+x5kE5XcGncg2I7moGSgYzar1
mbd738Msit/VdnfwxAXKcOG8357CvSoJyYxVnw7Fe9eMirllCo9X920LpT9lkeME
VH0uu0O6nm4JLKuxho3o6/eZ3cz+uaUMJ28=
-----END CERTIFICATE REQUEST-----',
			'mywithcsr.example.org',
			'52:B2:26:27:92:6F:B7:8F:9D:0B:BC:D6:17:37:00:11:0F:DF:FC:03', pkhid2 ,
			now() - '1 week'::interval, now() + '90 days'::interval
		) RETURNING * INTO _r;

		SELECT * INTO _d FROM x509_certificate
			WHERE x509_cert_id = _r.x509_cert_id;
		IF _d != _r THEN
			RAISE EXCEPTION 'Insert does not match';
		END IF;
		RAISE EXCEPTION '%', 'a-ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;

	RAISE NOTICE '++ : inserting with only key (ths is horrible, horrible, horrible, gross)... ';
	BEGIN
		INSERT INTO x509_certificate (
			friendly_name, is_certificate_authority,
			signing_cert_id, x509_ca_cert_serial_number,
			public_key, private_key, certificate_sign_req, subject,
			subject_key_identifier, public_key_hash_id,
			valid_from, valid_to
		) VALUES (
			'mywithcsr.example.org', 'N',
			x509ca.x509_cert_id, 10,
			NULL, '-----BEGIN RSA PRIVATE KEY-----
MIICXgIBAAKBgQDaNbvhtQYSPuaOrBi3aZD9H/DZk4yukVayxByUBdVmECreJ/IC
RBkmTMOLIS3InbETyr55jqXQ7EothEa4UalE9uO2IHUCd/yBk3ZnUkVvRqnB8rzp
E8S2BlFlIKIooVDPx3CWCpU9S9H/t3BkPSPefn2hcj0DcWlPwz83RnLrlwIDAQAB
AoGBALhrCWrsb0EkX/7ce9cnJR6IzClWhmNS+g8Dp5OCiqRDrbcr02EO5KJ15h3D
4MnYXDv58ZkSchlsWhS14n8MpRzPTJ3kzKDLDxosPyobOjA2dWxpfR8Dxh+jxlFI
1XJfCdT+yL7jpQWxUjajAZz5csrdeUaGBEMjxnSbh6frGw0BAkEA/zmIpAD5UQ11
fyIGBvi/X4yJeuU0GTtt3PgEpANElJj/cCf4L65I0DE12FmLDliC0YGk4efIiuFG
IFRrUd/gtwJBANrfarrDi1NqcoEt6iXhBFoU+vImiVMuB21Wixrhuk1U8O6ZEU8w
yff+5DX7Bj3mYsFbcFscvqAo3GM+fktErCECQQCMnBvljwvMVcfn1MzRRnXYpEqR
xHjhddZfKN0Vpx8/ZtND7SFU04YV/SaXHS35J1ZbKju2ocXgjZ/e6+N8ZgUdAkEA
zNDlf4AdkSG7pUbiJjA7clDPxGprd3tLV/X0lmNFg7hI/f4fRIvTdE8CH8GYRbSi
FW8L5Tcw649RLU39wVGyAQJAQSKStUsDsckzcuroGA/TDi/NKL4RTAv9oV6gMDPB
utyXJj8gr0B21rp/N5y496yJbwHJQDUl71s3MK+iipSf/Q==
-----END RSA PRIVATE KEY-----', NULL, 'mywithcsr.example.org',
			'52:B2:26:27:92:6F:B7:8F:9D:0B:BC:D6:17:37:00:11:0F:DF:FC:03', pkhid2 ,
			now() - '1 week'::interval, now() + '90 days'::interval
		) RETURNING * INTO _r;

		SELECT * INTO _d FROM private_key
			WHERE private_key_id = _r.x509_cert_id;
		IF _d.private_key != _r.private_key THEN
			RAISE EXCEPTION 'Insert does not match: % %',
				jsonb_pretty(to_jsonb(_r)), jsonb_pretty(to_jsonb(_d));
		END IF;
		RAISE EXCEPTION '%', 'a-ok' USING ERRCODE = 'JH999';
	EXCEPTION WHEN SQLSTATE 'JH999' THEN
		RAISE NOTICE '.... it did! (%)', SQLERRM;
	END;


	RAISE NOTICE '++ deprecated_x509_regression: Wrapping up';
	RETURN true;
END;
$$ LANGUAGE plpgsql;

-- set search_path=public;
SELECT deprecated_x509_regression();
-- set search_path=jazzhands;
DROP FUNCTION deprecated_x509_regression();

ROLLBACK TO x509_tests;

\t off
