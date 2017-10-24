%define pkgname jazzhands-account-directory
%define prefix /var/www/account/directory
Summary:    JazzHands Directory - Account Phone/Etc Directory
Vendor:     JazzHands
Name:       %{pkgname}
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
Requires: perl, perl-JazzHands-DBI, perl-DBD-Pg, php-jazzhands-appauthal, php-pgsql, netpbm-progs, libjpeg, perl-Digest-SHA, jazzhands-javascript-common

%description
Rudimentary Web site for Acccount Directory

%prep
%setup -q -n %{pkgname}-%{version}
make -f Makefile.jazzhands

%install
make -f Makefile.jazzhands DESTDIR=%{buildroot} PREFIX=%{prefix} install

%clean
make -f Makefile.jazzhands clean

%files -f debian/jazzhands-account-directory.files
