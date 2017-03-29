%define pkgname perl-jazzhands-dbi

Summary:    JazzHands-DBI - database authentication abstraction for Perl
Vendor:     JazzHands
Name:       perl-JazzHands-DBI
Version:    __VERSION__
Release:    1
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
Source0:    %{pkgname}-%{version}.tar.gz
%if 0%{?suse_version}
BuildRequires: perl(JazzHands::AppAuthAL)
%else
%if 0%{?rhel} < 6
BuildRequires: perl(ExtUtils::MakeMaker)
%else
BuildRequires: perl-ExtUtils-MakeMaker
%endif
%endif
Requires:   jazzhands-perl-common >= 0.73.2
Requires:   perl-JazzHands-AppAuthAL >= 0.79.2
BuildRoot:  %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch:  noarch

%description
DBI shim for JazzHands to support database authentication abstraction

%prep
%setup -q -n %{pkgname}-%{version}
make -f Makefile.jazzhands BUILDPERL=%{__perl}

%install
make -f Makefile.jazzhands INSTALLROOT=%{buildroot} prefix=%{prefix} BUILDPERL=%{__perl} install

%clean
make -f Makefile.jazzhands INSTALLROOT=%{buildroot} clean


%files
%attr (-, root, bin) %{perl_vendorlib}/JazzHands/DBI.pm
%attr (-, root, bin) %{_mandir}/*/*m*
