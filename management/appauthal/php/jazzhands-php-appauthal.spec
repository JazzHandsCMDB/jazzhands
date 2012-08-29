%define name    php-jazzhands-appauthal
%define prefix	/usr/share/php
%define version 0.2.7.0
%define release 1
Name:   	%{name}
Version:        %{version}
Release:        %{release}%{?dist}
Summary:        JazzHands App Authorization Abstraction Layer for php
Group:  	System Environment/Libraries
License:        BSD
URL:    	http://www.jazzhands.net/
Source0:	%{name}.tgz
BuildRoot:      %{_tmppath}/%{name}-root
BuildArch:	noarch
#BuildRequires: 
Requires:      	php

%description

Rudimentary AppAuthAL database auth module for jazzhands 

%prep
%setup -q -n %{name}

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
 - initial release

