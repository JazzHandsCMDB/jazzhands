Summary:    JazzHands-DBI - database authentication abstraction for Perl
Vendor:     JazzHands
Name:       perl-JazzHands-DBI
Version:    0.53
Release:    1
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
Source0:    %{name}-%{version}.tar.gz
BuildRequires: perl-ExtUtils-MakeMaker
BuildRoot:  %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch:  noarch

%description
DBI shim for JazzHands to support database authentication abstraction

%prep
%setup -q -n %{name}-%{version}

%{__perl} Makefile.PL INSTALLDIRS=vendor --default
%{__make}

%install

%{__make} pure_install PERL_INSTALL_ROOT=%{buildroot}

%clean

rm -rf %{buildroot}

%files
%attr (-, root, bin) %{perl_vendorlib}/JazzHands/DBI.pm
%attr (-, root, bin) %{perl_vendorarch}/auto/JazzHands/DBI/.packlist
%attr (-, root, bin) %{_mandir}/*/* 
