Name:   	jazzhands-perl-mgmt
Version:        __VERSION__
Release:        0%{?dist}
Summary:        JazzHands Management Perl Libraries
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
#Requires:      	php

%description

ORM for perl for JazzHands. (to be deprecated0

%prep
%setup -q -n %{name}-%{version}
make -f Makefile.jazzhands BUILDPERL=%{__perl}

%install
make -f Makefile.jazzhands INSTALLROOT=%{buildroot} prefix=%{prefix} BUILDPERL=%{__perl} install

%clean
make -f Makefile.jazzhands clean

%files
%defattr(-,root,root)
##  %doc Changes README
%{perl_vendorlib}/*
%{_mandir}/man3/*

