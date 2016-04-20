Summary:    jazzhands-perl-tickets - JazzHands perl common utility modules
Vendor:     JazzHands
Name:       jazzhands-perl-tickets
Version:    __VERSION__
Release:    1
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
BuildArch:  noarch
Source0:    %{name}-%{version}.tar.gz
BuildRoot:  %{_tmppath}/%{name}-%{version}-%{release}-buildroot
%if 0%{?suse_version}
%else
%if 0%{?rhel} < 6
BuildRequires: perl(ExtUtils::MakeMaker)
%else
BuildRequires: perl-ExtUtils-MakeMaker
%endif
%endif
BuildArch:  noarch

%description
Common Interfaces for interacting with ticketing systems.

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
%{perl_vendorlib}/JazzHands/Tickets/KACE.pm
%{perl_vendorlib}/JazzHands/Tickets.pm
#%{perl_vendorlib}x86_64-linux-thread-multi/auto/JazzHands/Common/.packlist
%{_mandir}/man3/JazzHands::Tickets.3pm.gz
#- %{_mandir}/man3/JazzHands::Tickets::RT.3pm.gz
#- %{_mandir}/man3/JazzHands::Tickets::JIRA.3pm.gz
#- %{_mandir}/man3/JazzHands::Tickets::KACE.3pm.gz

