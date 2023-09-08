%define pkgname jazzhands-apache-api
%define prefix /usr/libexec/jazzhands/api/
Summary:    JazzHands-Apache-API - JazzHands API service
Vendor:     JazzHands
Name:       JazzHands-Apache-API
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
Apache-based JazzHands API service

%prep
%setup -q -n %{pkgname}-%{version}
make

%install
make  DESTDIR=%{buildroot} PREFIX=%{prefix} install

%clean
make  clean


%files
%attr (-, root, bin) /usr/libexec/jazzhands/api/JazzHands/Apache/API/Common.pm
%attr (-, root, bin) /usr/libexec/jazzhands/api/JazzHands/Apache/API/Container.pm
%attr (-, root, bin) /usr/libexec/jazzhands/api/JazzHands/Apache/API/Device.pm
