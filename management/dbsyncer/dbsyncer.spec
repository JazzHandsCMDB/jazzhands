Name:   	jazzhands-dbsyncer
Version:        __VERSION__
Release:        0%{?dist}
Summary:        JazzHands Front Ends for Interaction with Approval System
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
Requires: jazzhands-perl-common >= 0.66.2
Requires: perl-jazzhands-dbi >= 0.66.1

%description

JazzHands Database Sync Software


%prep
rm -rf %{buildroot}
%setup -q -n %{name}-%{version}
make -f Makefile.jazzhands 

%install
make -f Makefile.jazzhands INSTALLROOT=%{buildroot} install

%clean
make -f Makefile.jazzhands clean
rm -rf %{buildroot}


%files
%defattr(755,root,root,-)
# /etc/init.d
/usr/libexec/jazzhands/dbsyncer/table-sync


