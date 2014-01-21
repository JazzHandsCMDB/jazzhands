%define prefix	/usr/share/php

Name:   	php-jazzhands-appauthal
Version:        0.2.7.1
Release:        1%{?dist}
Summary:        JazzHands App Authorization Abstraction Layer for php
Group:  	System Environment/Libraries
License:        BSD
URL:    	http://www.jazzhands.net/
Source0:        %{name}-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch:	noarch
#BuildRequires: 
Requires:      	php

%description

Rudimentary AppAuthAL database auth module for jazzhands 

%prep
%setup -q -n %{name}-%{version}

%build
echo Nothing to do

%install
mkdir -p $RPM_BUILD_ROOT/%{prefix}/jazzhands

cp dbauth.php $RPM_BUILD_ROOT/%{prefix}/jazzhands/dbauth.php



%clean
rm -rf %{buildroot}

%files
%defattr(755,root,root,-)
%{prefix}/jazzhands/dbauth.php

%changelog
* Mon Aug 27 2012 Todd Kover <kovert@omniscient.com> 0.2.7.0-1
 - add basic support for mysql
* Mon Aug 27 2012 Todd Kover <kovert@omniscient.com> 0.2.7.0-1
 - initial release

