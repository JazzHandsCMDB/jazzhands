%define name    jazzhands-stab
%define prefix	/var/www/stab
%define release 0
Name:   	jazzhands-stab
Version:        __VERSION__
Release:        0%{?dist}
Summary:        JazzHands STAB Web Front End
Group:  	System Environment/Libraries
License:        BSD
URL:    	http://www.jazzhands.net/
Source0:        %{name}-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch:	noarch
%if 0%{?suse_version}
%else
%if 0%{?rhel} < 6
BuildRequires: perl(ExtUtils::MakeMaker)
%else
BuildRequires: perl-ExtUtils-MakeMaker
%endif
%endif
Requires:      	jazzhands-perl-mgmt, jazzhands-perl-common >= 0.73.2, jazzhands-perl-stab = %{version} , jazzhands-javascript-common  >= 0.79.0

%description

System Tools for Administrative Baselining

%package -n jazzhands-perl-stab
group: System Environment/Libraries
Summary: Perl library for STAB
Requires: perl-Net-IP, perl-Net-DNS, perl-NetAddr-IP


%description -n jazzhands-perl-stab
Perl libraries for STAB

%prep
%setup -q -n %{name}-%{version}
make -f Makefile.jazzhands BUILDPERL=%{__perl}

%install
make -f Makefile.jazzhands INSTALLROOT=%{buildroot} prefix=%{prefix} BUILDPERL=%{__perl} install

%clean
make -f Makefile.jazzhands clean

%files -f debian/jazzhands-stab.install
%defattr(755,root,root,-)

%files -n jazzhands-perl-stab -f debian/jazzhands-perl-stab.install
