Summary:    jazzhands-perl-vault - JazzHands HashiCorp Vault LIbrary
Vendor:     JazzHands
Name:       jazzhands-perl-vault
Version:    __VERSION__
Release:    1
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
BuildArch:  noarch
Source0:    %{name}-%{version}.tar.gz
BuildRoot:  %{_tmppath}/%{name}-%{version}-%{release}-buildroot
Requires:   jazzhands-perl-common >= 0.86.0
%if 0%{?suse_version}
BuildRequires: perl(JazzHands::Common)
%else
%if 0%{?rhel} < 6
BuildRequires: perl(ExtUtils::MakeMaker)
%else
BuildRequires: perl-ExtUtils-MakeMaker
%endif
%endif
BuildArch:  noarch

%description
Very basic routines to allow jazzhands tools to interact with Hashicorp vault

%prep
%setup -q -n %{name}-%{version}
make -f Makefile.jazzhands BUILDPERL=%{__perl}

%install
make -f Makefile.jazzhands DESTDIR=%{buildroot} prefix=%{prefix} BUILDPERL=%{__perl} install

%clean
make -f Makefile.jazzhands clean

%files
%defattr(755,root,root,-)
%{perl_vendorlib}/JazzHands/Vault.pm
%{_mandir}/man3/JazzHands::Vault.3pm.gz
