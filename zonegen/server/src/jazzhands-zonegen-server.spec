%define	prefix	/usr
%define	zgroot	libexec/jazzhands/zonegen

Summary:    jazzhands-zonegen-server - generates and pushes out zones
Vendor:     JazzHands
Name:       jazzhands-zonegen-server
Version:    0.58.7
Release:    1
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
BuildArch:  noarch
Source0:    %{name}-%{version}.tar.gz
BuildRoot:  %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch:  noarch
Requires:   jazzhands-perl-common, perl-JazzHands-DBI, perl-Net-IP, bind
# bind is there for named-checkzone


%description
Generates zone and configuration from JazzHands database

%prep
%setup -q -n %{name}-%{version}

%install

rm -rf %{buildroot}
mkdir -p %{buildroot}/%{prefix}/%{zgroot}
for file in generate-and-sync.sh generate-zones.pl ; do
	newfn=`echo $file | sed 's/\..*$//'`
	install -m 555  $file %{buildroot}/%{prefix}/%{zgroot}/$newfn
done

%clean
rm -rf %{buildroot}


%files
%defattr(755,root,root,-)

%{prefix}/%{zgroot}/generate-and-sync
%{prefix}/%{zgroot}/generate-zones

%post

if [ ! -d /var/lib/zonegen ] ; then 
	mkdir  -p /var/lib/zonegen/run
	mkdir  -p /var/lib/zonegen/auto-gen/perserver
	mkdir  -p /var/lib/zonegen/auto-gen/zones
	mkdir  -p /var/lib/zonegen/auto-gen/etc
	chown -R zonegen:zonegen /var/lib/zonegen/run
	chown -R zonegen:zonegen /var/lib/zonegen/auto-gen
fi

%changelog
* Thu Sep 11 2014 Todd Kover <kovert@omniscient.com> 0.58.7
- add support for generating additional acls independent of sites
* Thu Sep 11 2014 Todd Kover <kovert@omniscient.com> 0.58.6
- better handle exclusions for child subnets assigned to different sites
* Thu Sep 11 2014 Todd Kover <kovert@omniscient.com> 0.58.5
- add --nogen option and more verbosity/debug
* Wed Jun 25 2014 Todd Kover <kovert@omniscient.com> 0.58.4.2
- fix path to spec file
* Wed Jun 25 2014 Todd Kover <kovert@omniscient.com> 0.58.4.1
- remove extra my that unfortunately change of a variable
* Tue Jun 24 2014 Todd Kover <kovert@omniscient.com> 0.58.4
- migrate to generate-and-sync from do-zone-generation
* Fri Jun 20 2014 Todd Kover <kovert@omniscient.com> 0.58.3
- generate the allzone_hostfile smartly, update docs
- update docs wit detail of other changes that went in recently
- make the mtime of a zone the same as the db's last generated date
* Mon Jun  9 2014 Todd Kover <kovert@omniscient.com> 0.57.10
- migrate zonegen to Net::IP from Net::Netmask
- convert to postgresql native inetbaseness for ipv4
- make in-addr generation work for ipv6
- put ip6.arpa zones in their own directory
* Wed Apr 30 2014 Todd Kover <kovert@omniscient.com> 0.57.7
- make the acl root dir exist before creating file
- sort pool records so they always end up in the same order
- Update zonegen to use new dns_change-record table. 
- Generate a site netblocks acl file
* Thu Oct 17 2013 Todd Kover <kovert@omniscient.com> 0.55.0
- dhcp_range -> network_range
- network range: dhcp prefix, dns_domain
- Use A record ttl in PTR
- perltidy
* Wed Oct 16 2013 Todd Kover <kovert@omniscient.com> 0.54.1
- pull TTL for NS records from actual child NS records when setting up delegations
* Wed Sep 25 2013 Todd Kover <kovert@omniscient.com> 0.54.0
- deal with v0.54 and moving v4_netblock_id to netblock_id
* Fri Jul 26 2013 Todd Kover <kovert@omniscient.com> 0.52.6.2-1
- commit for each zone update
* Tue May 28 2013 Todd Kover <kovert@omniscient.com> 0.52.6.1-1
- fix perl syntax error
* Tue May 28 2013 Todd Kover <kovert@omniscient.com> 0.52.6.1-1
- fix perl syntax error
* Tue May 28 2013 Todd Kover <kovert@omniscient.com> 0.52.6-1
- only run rndc reload/reconfig when zones change
* Thu Apr 18 2013 Todd Kover <kovert@omniscient.com> 0.52.5-1
- order by dns_type after other entries
* Thu Apr 18 2013 Todd Kover <kovert@omniscient.com> 0.52.4-1
- improve generation of SRV records
- make dumpzone not regenerate every zone
- fully qualify ns records with domain if appropriate
* Thu Apr 18 2013 Todd Kover <kovert@omniscient.com> 0.52.3-1
- fix use of minimum and ttl in generated zones
* Wed Apr 17 2013 Todd Kover <kovert@omniscient.com> 0.52.2-1
- fix signal handling in do-zone-generation
* Wed Apr 17 2013 Todd Kover <kovert@omniscient.com> 0.52.1-1
- print debugging to stderr when not invoked vi a tty.  silence is tty normal
- unlink allzone file when generated, do not otherwise
- print more info on steps when invoked from a tty
- make extractions have correct soa serial number before db is updated
  to minimize the amount of time between update of dns_domain and commit
- generate zones without an soabump if the file is not there
- deal properly with no last date being set in zone generation
- use script invocation time as time for new zones
- properly regenerate zones that are not there for initial deployment
* Thu Mar  7 2013 Todd Kover <kovert@omniscient.com> 0.52-1
- initial release
