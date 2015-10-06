Summary:    jazzhands-perl-tickets - JazzHands perl common utility modules
Vendor:     JazzHands
Name:       jazzhands-perl-tickets
Version:    0.64.5
Release:    1
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
BuildArch:  noarch
Source0:    %{name}-%{version}.tar.gz
BuildRoot:  %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildRequires: perl-ExtUtils-MakeMaker
BuildArch:  noarch

%description
Common utility modules used by JazzHands scripts.

%prep
%setup -q -n %{name}-%{version}

%{__perl} Makefile.PL INSTALLDIRS=vendor PREFIX="%{buildroot}%{_prefix}"  && %{__make}

%install

rm -rf %{buildroot}
make pure_install 

find %{buildroot} -type f -name .packlist -exec rm -f {} \;
find %{buildroot} -depth -type d -exec rmdir {} 2>/dev/null \;

%clean
rm -rf %{buildroot}


%files
%defattr(755,root,root,-)
%{perl_vendorlib}/JazzHands/Tickets/RT.pm
%{perl_vendorlib}/JazzHands/Tickets/JIRA.pm
%{perl_vendorlib}/JazzHands/Tickets.pm
#%{perl_vendorlib}x86_64-linux-thread-multi/auto/JazzHands/Common/.packlist
%{_mandir}/man3/JazzHands::Tickets.3pm.gz
#- %{_mandir}/man3/JazzHands::Tickets::RT.3pm.gz
#- %{_mandir}/man3/JazzHands::Tickets::JIRA.3pm.gz


%changelog
* Tue Oct  6 2015 Todd Kover <kovert@omniscient.com> 0.64.5-1
- add resolutionepoch to RT
* Mon Sep 28 2015 Todd Kover <kovert@omniscient.com> 0.64.4-1
  - initial release
