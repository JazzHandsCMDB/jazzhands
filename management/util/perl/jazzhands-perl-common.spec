Summary:    jazzhands-perl-common - JazzHands perl common utility modules
Vendor:     JazzHands
Name:       jazzhands-perl-common
Version:    __VERSION__
Release:    1
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
BuildArch:  noarch
Source0:    %{name}-%{version}.tar.gz
BuildRoot:  %{_tmppath}/%{name}-%{version}-%{release}-buildroot
%if 0%{?suse_version}
%else
%if 0%{?rhel} < 6
BuildRequires: perl(ExtUtils::MakeMaker)
%else
BuildRequires: perl-ExtUtils-MakeMaker
%endif
%endif
BuildArch:  noarch

%description
Common utility modules used by JazzHands scripts.

%prep
%setup -q -n %{name}-%{version}
make -f Makefile.jazzhands BUILDPERL=%{__perl}

%install
make -f Makefile.jazzhands INSTALLROOT=%{buildroot} prefix=%{prefix} BUILDPERL=%{__perl} install

%clean
make -f Makefile.jazzhands clean


%files
%defattr(755,root,root,-)
%dir %{perl_vendorlib}/JazzHands
%dir %{perl_vendorlib}/JazzHands/Common
%{perl_vendorlib}/JazzHands/Common/Error.pm
%{perl_vendorlib}/JazzHands/Common/GenericDB.pm
%{perl_vendorlib}/JazzHands/Common/Util.pm
%{perl_vendorlib}/JazzHands/Common.pm
#%{perl_vendorlib}x86_64-linux-thread-multi/auto/JazzHands/Common/.packlist
%{_mandir}/man3/JazzHands::Common.3pm.gz
%{_mandir}/man3/JazzHands::Common::Error.3pm.gz
%{_mandir}/man3/JazzHands::Common::GenericDB.3pm.gz
%{_mandir}/man3/JazzHands::Common::Util.3pm.gz

