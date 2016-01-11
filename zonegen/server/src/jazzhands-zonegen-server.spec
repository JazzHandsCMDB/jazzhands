%define	prefix	/usr
%define	zgroot	libexec/jazzhands/zonegen

Summary:    jazzhands-zonegen-server - generates and pushes out zones
Vendor:     JazzHands
Name:       jazzhands-zonegen-server
Version:    __VERSION__
Release:    1
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
BuildArch:  noarch
Source0:    %{name}-%{version}.tar.gz
BuildRoot:  %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch:  noarch
Requires:   jazzhands-perl-common, perl-JazzHands-DBI, perl-Net-IP, bind
# bind is there for named-checkzone


%description
Generates zone and configuration from JazzHands database

%prep
%setup -q -n %{name}-%{version}
make -f Makefile.jazzhands

%install
make -f Makefile.jazzhands INSTALLROOT=%{buildroot} PREFIX=%{prefix} install

%clean
make -f Makefile.jazzhands INSTALROOT=%{buildroot} clean


%files
%defattr(755,root,root,-)
%{prefix}/%{zgroot}/generate-and-sync
%{prefix}/%{zgroot}/generate-zones

%post

if [ ! -d /var/lib/zonegen ] ; then 
	mkdir  -p /var/lib/zonegen/run
	mkdir  -p /var/lib/zonegen/auto-gen/perserver
	mkdir  -p /var/lib/zonegen/auto-gen/zones
	mkdir  -p /var/lib/zonegen/auto-gen/etc
	chown -R zonegen:zonegen /var/lib/zonegen/run
	chown -R zonegen:zonegen /var/lib/zonegen/auto-gen
fi
