%define pkgname jazzhands-perl-redfish
%define prefix %{perl_vendorlib}
Summary:    jazzhands-perl-redfish - JazzHands Redfish device management
Vendor:     JazzHands
Name:       jazzhands-perl-redfish
Version:    __VERSION__
Release:    1
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
Source0:    %{pkgname}-%{version}.tar.gz
BuildRequires: make
%if 0%{?suse_version}
%else
BuildRequires: perl-generators
BuildRequires: perl-interpreter
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
make -f Makefile.jazzhands  DESTDIR=%{buildroot} PREFIX=%{perl_vendorlib} install

%clean
make -f Makefile.jazzhands clean


%files
%defattr(755,root,root,-)
%dir %{perl_vendorlib}/JazzHands
%{perl_vendorlib}/JazzHands/Redfish.pm
