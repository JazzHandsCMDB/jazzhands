\set ON_ERROR_STOP

ALTER TABLE service_source_repository
	ADD CONSTRAINT  FK_service_source_repo_service_id
	FOREIGN KEY
	(service_id) REFERENCES service(service_id)
	DEFERRABLE;

ALTER TABLE service_source_repository
	ADD CONSTRAINT  FK_service_source_repo_srcrepoid
	FOREIGN KEY
	(source_repository_id) 
	REFERENCES source_repository(source_repository_id)
	DEFERRABLE;


ALTER TABLE service_version
	ADD CONSTRAINT  fk_service_version_service_id
	FOREIGN KEY
	(service_version_id) REFERENCES service_version(service_version_id)
	DEFERRABLE;


ALTER TABLE service_version_source_repository
	ADD CONSTRAINT  fk_service_version_source_repository_svi
	FOREIGN KEY
	(service_version_id) REFERENCES service_version(service_version_id)
	DEFERRABLE;


ALTER TABLE service_version_source_repository
	ADD CONSTRAINT  fk_service_version_source_repository_srcrepoid
	FOREIGN KEY
	(source_repository_id) 
	REFERENCES source_repository(source_repository_id)
	DEFERRABLE;

----------------------

ALTER TABLE service_software_repo
	ADD CONSTRAINT  fk_service_software_repo_service_id
	FOREIGN KEY
	(service_id) REFERENCES service(service_id)
	DEFERRABLE;

ALTER TABLE service_software_repo
	ADD CONSTRAINT  fk_service_software_repo_sw_pkg_repo_id
	FOREIGN KEY
	(sw_package_repository_id) 
	REFERENCES sw_package_repository(sw_package_repository_id)
	DEFERRABLE;

ALTER TABLE service_version_sw_package_repository
	ADD CONSTRAINT  fk_service_version_sw_package_repository_svi
	FOREIGN KEY
	(service_version_id) REFERENCES service_version(service_version_id)
	DEFERRABLE;

ALTER TABLE service_version_sw_package_repository
	ADD CONSTRAINT  fk_service_software_repo_sw_pkg_repo_id
	FOREIGN KEY
	(sw_package_repository_id) 
	REFERENCES sw_package_repository(sw_package_repository_id)
	DEFERRABLE;

----------------------

ALTER TABLE port_range
	ADD CONSTRAINT  fk_port_range_protocol
	FOREIGN KEY
	(protocol) 
	REFERENCES protocol(protocol)
	DEFERRABLE;

----------------------


ALTER TABLE service_endpoint_provider_collection_service_endpoint_provider
	ADD CONSTRAINT  fk_sepc_sep_coll_id
	FOREIGN KEY
	(service_endpoint_provider_collection_id) 
	REFERENCES service_endpoint_provider_collection(service_endpoint_provider_collection_id)
	DEFERRABLE;

ALTER TABLE service_endpoint_provider_collection_service_endpoint_provider
	ADD CONSTRAINT  fk_sepc_sep_epid
	FOREIGN KEY
	(service_endpoint_provider_id) 
	REFERENCES service_endpoint_provider(service_endpoint_provider_id)
	DEFERRABLE;

ALTER TABLE service_endpoint_provider_member
	ADD CONSTRAINT  fk_service_endpoint_provider_member_ep_id
	FOREIGN KEY
	(service_endpoint_provider_id) 
	REFERENCES service_endpoint_provider(service_endpoint_provider_id)
	DEFERRABLE;

ALTER TABLE service_endpoint_provider_member
	ADD CONSTRAINT  fk_service_endpoint_provider_member_siid
	FOREIGN KEY
	(service_instance_id) 
	REFERENCES service_instance(service_instance_id)
	DEFERRABLE;

ALTER TABLE service_endpoint
	ADD CONSTRAINT  fk_service_endpoint_dns_rec_id
	FOREIGN KEY
	(dns_record_id) 
	REFERENCES dns_record(dns_record_id)
	DEFERRABLE;

ALTER TABLE service_endpoint
	ADD CONSTRAINT  fk_service_endpoint_svc
	FOREIGN KEY
	(service_id) 
	REFERENCES service(service_id)
	DEFERRABLE;

ALTER TABLE service_endpoint
	ADD CONSTRAINT  fk_service_endpoint_dns_dom_id
	FOREIGN KEY
	(dns_domain_id) 
	REFERENCES dns_domain(dns_domain_id)
	DEFERRABLE;

ALTER TABLE service_endpoint_x509_certificate
	ADD CONSTRAINT  fk_service_endpoint_x509_certificate_seid
	FOREIGN KEY
	(service_endpoint_id)
	REFERENCES service_endpoint(service_endpoint_id)
	DEFERRABLE;

ALTER TABLE service_endpoint_x509_certificate
	ADD CONSTRAINT  fk_service_endpoint_x509_certificate_x509di
	FOREIGN KEY
	(x509_signed_certificate_id) 
	REFERENCES x509_signed_certificate(x509_signed_certificate_id)
	DEFERRABLE;

---

ALTER TABLE network_interface_netblock
	ADD CONSTRAINT AK_network_interface_netblock_devnblk_id
	UNIQUE (DEVICE_ID, NETBLOCK_ID);

ALTER TABLE service_instance
	ADD CONSTRAINT  fk_service_instance_dev_nblk
	FOREIGN KEY
	(device_id, netblock_id)
	REFERENCES network_interface_netblock(device_id,netblock_id)
	DEFERRABLE;

ALTER TABLE service_instance
	ADD CONSTRAINT  fk_service_instance_epid
	FOREIGN KEY
	(service_endpoint_Id)
	REFERENCES service_endpoint(service_endpoint_id)
	DEFERRABLE;

ALTER TABLE service_instance
	ADD CONSTRAINT  fk_service_instance_svcversionid
	FOREIGN KEY
	(service_version_Id)
	REFERENCES service_version(service_version_id)
	DEFERRABLE;

ALTER TABLE service_instance
	ADD CONSTRAINT  fk_service_instance_port_range
	FOREIGN KEY
	(port_range_id)
	REFERENCES port_range(port_range_id)
	DEFERRABLE;

-----------------------------------------------------------------------------
--
-- pickup with service_endpoint_service_sla
--
