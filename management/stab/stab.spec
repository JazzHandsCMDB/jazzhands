%define name    jazzhands-stab
%define prefix	/var/www/stab
%define release 0
%define filelist %{name}-%{version}-filelist
%define wwwlist %{name}-%{version}-wwwlist

Name:   	jazzhands-stab
Version:        __VERSION__
Release:        0%{?dist}
Summary:        JazzHands STAB Web Front End
Group:  	System Environment/Libraries
License:        BSD
URL:    	http://www.jazzhands.net/
Source0:        %{name}-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildRequires:	make
BuildArch:	noarch
%if 0%{?suse_version}
BuildRequires: perl(ExtUtils::MakeMaker)
%else
BuildRequires: perl-generators
BuildRequires: perl-interpreter
%if 0%{?rhel} < 6
BuildRequires: perl(ExtUtils::MakeMaker)
%else
BuildRequires: perl-ExtUtils-MakeMaker
%endif
%endif
Requires:      	jazzhands-perl-mgmt, jazzhands-perl-common >= 0.86.0, jazzhands-perl-stab = %{version} , jazzhands-javascript-common  >= 0.79.0, perl-jazzhands-dbi >= 0.86.0


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
make  BUILDPERL=%{__perl}

%install
make  DESTDIR=%{buildroot} prefix=%{prefix} BUILDPERL=%{__perl} install
(cd %{buildroot} ; ( find .%{perl_vendorlib}/JazzHands ; find .%{_mandir} -name '*.pm*' -type f -print) | sed s,^\.,,) |sort | uniq | tee > %{filelist}
(cd %{buildroot} ; ( find ./var/www | sed s,^\.,,) ) |sort | uniq | tee > %{wwwlist}

%clean
make  clean
rm -f %{filelist}

%if 0%{?suse_version}
%files -n jazzhands-stab -f %{wwwlist}
%else
%files -n jazzhands-stab -f debian/jazzhands-stab.install
%endif
%defattr(755,root,root,-)

%files -n jazzhands-perl-stab -f %{filelist}
%{_mandir}/man3/JazzHands::STAB.3pm.gz
%{_mandir}/man3/JazzHands::STAB::DBAccess.3pm.gz
%{_mandir}/man3/JazzHands::STAB::Device.3pm.gz

