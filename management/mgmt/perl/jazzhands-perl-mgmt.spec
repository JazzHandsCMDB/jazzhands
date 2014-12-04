Name:   	jazzhands-perl-mgmt
Version:        0.59
Release:        1%{?dist}
Summary:        JazzHands Management Perl Libraries
Group:  	System Environment/Libraries
License:        BSD
URL:    	http://www.jazzhands.net/
Source0:        %{name}-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch:	noarch
BuildRequires:  perl-ExtUtils-MakeMaker
#Requires:      	php

%description

ORM for perl for JazzHands.

%prep
%setup -q -n %{name}-%{version}

echo Nothing to do for web site
echo Building perl modules
%{__perl} Makefile.PL INSTALLDIRS=vendor PREFIX="%{buildroot}%{_prefix}"  && %{__make}

%install
make pure_install

find %{buildroot} -type f -name .packlist -exec rm -f {} \;
find %{buildroot} -depth -type d -exec rmdir {} 2>/dev/null \;

%clean
#rm -rf %{buildroot}

%files
%defattr(755,root,root,-)
%{_mandir}/man3/JazzHands::Mgmt.3pm.gz
%{perl_vendorlib}//JazzHands/Mgmt.pm
%{perl_vendorlib}//JazzHands/Mgmt/Netblock.pm
%{perl_vendorlib}//JazzHands/Mgmt/Collection.pm



%changelog
* Thu Dec  4 2014 Todd Kover <kovert@omniscient.com> 0.59.1-1
  - deal with netmask_bits going away..
* Thu Mar  7 2013 Todd Kover <kovert@omniscient.com> 0.52.2-1
  - fix issue with inheritance from JazzHands::Common
* Thu Mar  7 2013 Todd Kover <kovert@omniscient.com> 0.52-1
  - migrate commit/rollback/etc to JH:Common
  - improvements to orering in DBFetch
  - better support for dealing with one and only one style nets
* Thu Feb 20 2013 Todd Kover <kovert@omniscient.com> 0.51.1-1
  - netblock collection improvements
* Thu Feb  7 2013 Todd Kover <kovert@omniscient.com> 0.51.1-1
  - initial release with netblocks and netblock collections
