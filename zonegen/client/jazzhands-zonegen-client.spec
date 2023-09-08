%define	prefix	/usr
%define	zgroot	libexec/jazzhands/zonegen

Summary:    jazzhands-zonegen-client - generates and pushes out zones
Vendor:     JazzHands
Name:       jazzhands-zonegen-client
Version:    __VERSION__
Release:    1
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
BuildArch:  noarch
Source0:    %{name}-%{version}.tar.gz
BuildRoot:  %{_tmppath}/%{name}-%{version}-%{release}-buildroot
Requires:   jazzhands-perl-common, perl-JazzHands-DBI, perl-Net-IP, bind
# bind is there for named-checkzone
BuildRequires: make


%description
Deals with zonegen on nameservers that receive zones


%prep
%setup -q -n %{name}-%{version}
make

%install
make  DESTDIR=%{buildroot} PREFIX=%{prefix}/%{zgroot} install

%clean
make  DESTDIR=%{buildroot} clean


%files
%defattr(755,root,root,-)
%{prefix}/%{zgroot}/ingest-zonegen-changes
