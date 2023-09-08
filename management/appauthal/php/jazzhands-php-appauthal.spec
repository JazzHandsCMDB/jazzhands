%define prefix	/usr/share/php

Name:   	php-jazzhands-appauthal
Version:        __VERSION__
Release:        1%{?dist}
Summary:        JazzHands App Authorization Abstraction Layer for php
Group:  	System Environment/Libraries
License:        BSD
URL:    	http://www.jazzhands.net/
Source0:        %{name}-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch:	noarch
BuildRequires:	make
#BuildRequires:
Requires:      	php

%description

Rudimentary AppAuthAL database auth module for jazzhands

%prep
%setup -q -n %{name}-%{version}
make

%install
make  DESTDIR=%{buildroot} PREFIX=%{prefix} install

%clean
make  clean

%files
%defattr(755,root,root,-)
%{prefix}/jazzhands/dbauth.php
