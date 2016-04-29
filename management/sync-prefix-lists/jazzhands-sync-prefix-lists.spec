%define pkgname jazzhands-sync-prefix-lists
%define prefix /usr/libexec/jazzhands/sync-prefix-lists/
Summary:    jazzhands-sync-prefix-lists - JazzHands management of network device prefix-lists
Vendor:     JazzHands
Name:       jazzhands-sync-prefix-lists
Version:    __VERSION__
Release:    1
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
Source0:    %{pkgname}-%{version}.tar.gz
BuildRoot:  %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch:  noarch

%description
JazzHands management of network device prefix-lists

%prep
%setup -q -n %{pkgname}-%{version}
make -f Makefile.jazzhands

%install
make -f Makefile.jazzhands DESTDIR=%{buildroot} PREFIX=%{prefix} install

%clean
make -f Makefile.jazzhands clean


%files
%attr (-, root, bin) /usr/libexec/jazzhands/sync-prefix-lists/sync-prefix-lists
