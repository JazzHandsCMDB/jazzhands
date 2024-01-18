%define pkgname jazzhands-redfish-utils
%define prefix /usr
Summary:    JazzHands-redfish-utils - JazzHands redfish management utilities
Vendor:     JazzHands
Name:       JazzHands-redfish-utils
Version:    __VERSION__
Release:    1
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
Source0:    %{pkgname}-%{version}.tar.gz
BuildRequires: make
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
JazzHands network device management utilities

%prep
%setup -q -n %{pkgname}-%{version}
make

%install
make DESTDIR=%{buildroot} PREFIX=%{prefix} install

%clean
make clean

%files
%attr (-, root, bin) %{prefix}/sbin/redfish_bmc_reset
