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
Requires:   jazzhands-perl-common >= 0.73.2, perl-JazzHands-DBI, perl-Net-IP, bind, jq, perl-JSON
# bind is there for named-checkzone
BuildRequires: make


%description
Generates zone and configuration from JazzHands database

%prep
%setup -q -n %{name}-%{version}
make

%install
make  DESTDIR=%{buildroot} PREFIX=%{prefix}/%{zgroot} install

%clean
make  DESTDIR=%{buildroot} clean


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
