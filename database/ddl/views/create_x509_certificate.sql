--
-- Copyright (c) 2016, Todd M. Kover
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

--
-- This is a backwards compatibility view that will be removed after release
-- 0.72.
--

CREATE OR REPLACE VIEW x509_certificate AS
	SELECT crt.x509_signed_certificate_id AS x509_cert_id,
	crt.friendly_name,
	crt.is_active,
	crt.is_certificate_authority,
	crt.signing_cert_id,
	crt.x509_ca_cert_serial_number,
	crt.public_key,
	key.private_key,
	csr.certificate_signing_request AS certificate_sign_req,
	crt.subject,
	crt.subject_key_identifier,
	crt.valid_from::timestamp,
	crt.valid_to::timestamp,
	crt.x509_revocation_date,
	crt.x509_revocation_reason,
	key.passphrase,
	key.encryption_key_id,
	crt.ocsp_uri,
	crt.crl_uri,
	crt.data_ins_user,
	crt.data_ins_date,
	crt.data_upd_user,
	crt.data_upd_date
FROM x509_signed_certificate crt
	LEFT JOIN private_key key USING (private_key_id)
	LEFT JOIN certificate_signing_request csr
		USING (certificate_signing_request_id)

/*
 **** leaving this out because of the weird x509_cert_id ****
UNION
	SELECT key.private_key_id AS x509_cert_id,
	csr.friendly_name,
	key.is_active,
	'N'::character(1) AS is_certificate_authority,
	NULL AS signing_cert_id,
	NULL AS x509_ca_cert_serial_number,
	NULL AS public_key,
	key.private_key,
	csr.certificate_signing_request AS certificate_sign_req,
	csr.subject,
	key.subject_key_identifier,
	'-infinity'::timestamp AS valid_from,
	'infinity'::timestamp AS valid_to,
	NULL AS x509_revocation_date,
	NULL AS x509_revocation_reason,
	key.passphrase,
	key.encryption_key_id,
	NULL AS ocsp_uri,
	NULL AS crl_uri,
	key.data_ins_user,
	key.data_ins_date,
	key.data_upd_user,
	key.data_upd_date
FROM private_key key
	INNER JOIN certificate_signing_request csr
		USING (private_key_id)
WHERE	private_key_id 
	NOT IN (select private_key_id FROM x509_signed_certificate
		WHERE private_key_id IS NOT NULL)
*/
;

alter view x509_certificate alter column is_active set default 'Y';
alter view x509_certificate alter column is_certificate_authority set default 'N';

