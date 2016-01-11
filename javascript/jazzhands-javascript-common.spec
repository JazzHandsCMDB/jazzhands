%define prefix  /var/www/jazzhands-javascript-common

Summary:    Javascript used by all JazzHands systems
Vendor:     JazzHands
Name:       jazzhands-javascript-common
Version:    __VERSION__
Release:    1
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
BuildArch:  noarch
Source0:   %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch:noarch

%description
Javascript used by all JazzHands systems (many external)

%prep
%setup -q -n %{name}-%{version}
make -f Makefile.jazzhands

%install
make -f Makefile.jazzhands INSTALLROOT=%{buildroot} PREFIX=%{prefix} install

%clean
make -f Makefile.jazzhands clean

%files -f debian/jazzhands-javascript-common.install
%defattr(755,root,root,-)
