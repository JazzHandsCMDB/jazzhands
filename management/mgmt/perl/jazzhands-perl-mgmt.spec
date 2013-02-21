%define name    jazzhands-perl-mgmt
%define version 0.51.1
%define release 1
Name:   	%{name}
Version:        %{version}
Release:        %{release}%{?dist}
Summary:        JazzHands Management Perl Libraries
Group:  	System Environment/Libraries
License:        BSD
URL:    	http://www.jazzhands.net/
Source0:	%{name}.tgz
BuildRoot:      %{_tmppath}/%{name}-root
BuildArch:	noarch
#BuildRequires: 
Requires:      	php

%description

System Tools for Administrative Baselining

%prep
%setup -q -n %{name}

echo Nothing to do for web site
echo Building perl modules
%{__perl} Makefile.PL INSTALLDIRS=vendor --default

%install
rm -rf $RPM_BUILD_ROOT

make pure_install PERL_INSTALL_ROOT=$RPM_BUILD_ROOT

find $RPM_BUILD_ROOT -type f -name .packlist -exec rm -f {} \;
find $RPM_BUILD_ROOT -depth -type d -exec rmdir {} 2>/dev/null \;

%clean
rm -rf %{buildroot}

%files
%defattr(755,root,root,-)
%{_mandir}/man3/JazzHands::Mgmt.3pm.gz
%{perl_vendorlib}//JazzHands/Mgmt.pm
%{perl_vendorlib}//JazzHands/Mgmt/Netblock.pm
%{perl_vendorlib}//JazzHands/Mgmt/NetblockCollection.pm



%changelog
* Thu Feb 20 2013 Todd Kover <kovert@omniscient.com> 0.51.1-1
  - netblock collection improvements
* Thu Feb  7 2013 Todd Kover <kovert@omniscient.com> 0.51.1-1
  - initial release with netblocks and netblock collections
