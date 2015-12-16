Summary:    JazzHands-Apache-API - JazzHands API service
Vendor:     JazzHands
Name:       JazzHands-Apache-API
Version:    0.65.0
Release:    1
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
Source0:    %{name}-%{version}.tar.gz
BuildRequires: perl-ExtUtils-MakeMaker
BuildRoot:  %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch:  noarch

%description
Apache-based JazzHands API service

%prep
%setup -q -n %{name}-%{version}

%{__make}

%build

%install
%{__make} DESTDIR=%{buildroot} install

%clean

rm -rf %{buildroot}

%files
%attr (-, root, bin) /usr/libexec/jazzhands/api/JazzHands/Apache/API/Common.pm
%attr (-, root, bin) /usr/libexec/jazzhands/api/JazzHands/Apache/API/Container.pm
