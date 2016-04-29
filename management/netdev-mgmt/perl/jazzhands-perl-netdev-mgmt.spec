%define pkgname jazzhands-perl-netdev-mgmt
%define prefix %{perl_vendorlib}
Summary:    jazzhands-perl-netdev-mgmt - JazzHands network device management
Vendor:     JazzHands
Name:       jazzhands-perl-netdev-mgmt
Version:    __VERSION__
Release:    1
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
Source0:    %{pkgname}-%{version}.tar.gz
%if 0%{?suse_version}
%else
%if 0%{?rhel} < 6
BuildRequires: perl(ExtUtils::MakeMaker)
%else
BuildRequires: perl-ExtUtils-MakeMaker
%endif
%endif
BuildRoot:  %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch:  noarch

%description
JazzHands network device management

%prep
%setup -q -n %{pkgname}-%{version}
make -f Makefile.jazzhands

%install
make -f Makefile.jazzhands DESTDIR=%{buildroot} PREFIX=%{perl_vendorlib} install

%clean
make -f Makefile.jazzhands clean


%files
%defattr(755,root,root,-)
%dir %{perl_vendorlib}/JazzHands
%dir %{perl_vendorlib}/JazzHands/NetDev
%dir %{perl_vendorlib}/JazzHands/NetDev/Mgmt
%{perl_vendorlib}/JazzHands/NetDev/Mgmt.pm
%{perl_vendorlib}/JazzHands/NetDev/Mgmt/arista.pm
%{perl_vendorlib}/JazzHands/NetDev/Mgmt/juniper.pm
