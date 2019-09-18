
%define pkgname perl-jazzhands-appauthal
%define NVR %{pkgname}-%{version}-%{release}
%define maketest 1

Name:      perl-JazzHands-AppAuthAL
summary:   JazzHands-AppAuthAL - generic auth abstraction layer routines used by:
Version:   __VERSION__
release:   8
license:   Artistic
group:     Applications
url:       http://www.jazzhands.net/
Source:	   %{pkgname}-%{version}.tar.gz
%if 0%{?suse_version}
BuildRequires: perl(JazzHands::Common)
%else
%if 0%{?rhel} < 6
BuildRequires: perl(ExtUtils::MakeMaker)
%else
BuildRequires: perl-ExtUtils-MakeMaker
%endif
%endif
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
buildarch: noarch
prefix:    %(echo %{_prefix})
provides:  perl(JazzHands::AppAuthAL)
requires:  perl-JSON
requires:  jazzhands-perl-common >= 0.86.0

%description
I totally need to write this.

#
# This package was generated automatically with the cpan2rpm
# utility.  To get this software or for more information
# please visit: http://perl.arix.com/
#

%prep
%setup -q -n %{pkgname}-%{version}
make -f Makefile.jazzhands BUILDPERL=%{__perl}

%install
make -f Makefile.jazzhands DESTDIR=%{buildroot} prefix=%{prefix} BUILDPERL=%{__perl} install

%clean
make -f Makefile.jazzhands clean

%files
%defattr(-,root,root)
##  %doc Changes README
%{perl_vendorlib}/JazzHands/AppAuthAL.pm
%{_mandir}/man3/JazzHands::AppAuthAL.3pm.gz

