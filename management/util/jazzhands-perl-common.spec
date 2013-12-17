Summary:    jazzhands-perl-common - JazzHands perl common utility modules
Vendor:     JazzHands
Name:       jazzhands-perl-common
Version:    0.56.2
Release:    1
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
BuildArch:  noarch
Source0:	%{name}.tgz
BuildRoot:      %{_tmppath}/%{name}-root
BuildArch:	noarch

%description
Common utility modules used by JazzHands scripts.

%prep
%setup -q -n %{name}

cd perl && %{__perl} Makefile.PL INSTALLDIRS=vendor PREFIX="%{buildroot}%{_prefix}"  && %{__make}

%install

rm -rf %{buildroot}
cd perl && make pure_install 

find %{buildroot} -type f -name .packlist -exec rm -f {} \;
find %{buildroot} -depth -type d -exec rmdir {} 2>/dev/null \;

%clean
rm -rf %{buildroot}


%files
%defattr(755,root,root,-)
%{perl_vendorlib}/JazzHands/Common/Error.pm
%{perl_vendorlib}/JazzHands/Common/GenericDB.pm
%{perl_vendorlib}/JazzHands/Common/Util.pm
%{perl_vendorlib}/JazzHands/Common.pm
#%{perl_vendorlib}x86_64-linux-thread-multi/auto/JazzHands/Common/.packlist
%{_mandir}/man3/JazzHands::Common.3pm.gz
%{_mandir}/man3/JazzHands::Common::Error.3pm.gz
%{_mandir}/man3/JazzHands::Common::GenericDB.3pm.gz
%{_mandir}/man3/JazzHands::Common::Util.3pm.gz


%changelog
* Tue Dec 17 2013 Todd Kover <kovert@omniscient.com> 0.56.3-1
  - make _dbx handle references to arrays instead of returning undef
  - remove warn that made it out accidentally
* Tue Dec  3 2013 Todd Kover <kovert@omniscient.com> 0.55-1
  - make _dbx handle references to arrays instead of returning undef
  - remove warn that made it out accidentally
* Thu Mar  7 2013 Todd Kover <kovert@omniscient.com> 0.52-2
  - allow match option to DBetch to take a simple hash
  - warnings fixes
  - migrate DBHandle/commont/rollback/disconnct from JH::Mgmt
  - other DB improvements
  - allow _options to take a hash
* Thu Feb 20 2013 Todd Kover <kovert@omniscient.com> 0.51.1-2
  - make work
