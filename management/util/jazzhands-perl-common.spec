Summary:    jazzhands-perl-common - JazzHands perl common utility modules
Vendor:     JazzHands
Name:       jazzhands-perl-common
Version:    0.51.1
Release:    2
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

cd perl && %{__perl} Makefile.PL INSTALLDIRS=vendor --default

%install
rm -rf $RPM_BUILD_ROOT

cd perl && make pure_install PERL_INSTALL_ROOT=$RPM_BUILD_ROOT

find $RPM_BUILD_ROOT -type f -name .packlist -exec rm -f {} \;
find $RPM_BUILD_ROOT -depth -type d -exec rmdir {} 2>/dev/null \;

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
* Thu Feb 20 2013 Todd Kover <kovert@omniscient.com> 0.51.1-2
  - make work
