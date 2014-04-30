%define	prefix	/usr
%define	mkproot	libexec/jazzhands/mkpasswdfiles

Summary:    jazzhands-mkpasswdfiles - generates and pushes out zones
Vendor:     JazzHands
Name:       jazzhands-mkpasswdfiles
Version:    0.57.6
Release:    1
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
Source0:    %{name}-%{version}.tar.gz
BuildRoot:  %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch:  noarch
Requires:   jazzhands-perl-common, perl-JazzHands-DBI, 


%description
Generates unix credentials

%prep
%setup -q -n %{name}-%{version}

%install

rm -rf %{buildroot}
mkdir -p %{buildroot}/%{prefix}/%{mkproot}
for file in mkpasswdfiles.pl ; do
	newfn=`echo $file | sed 's/\..*$//'`
	install -m 555  $file %{buildroot}/%{prefix}/%{mkproot}/$newfn
done

%clean
rm -rf %{buildroot}

%files
%defattr(755,root,root,-)

%{prefix}/%{mkproot}/mkpasswdfiles

%post
if [ ! -d /var/lib/jazzhands/creds-mgmt-server/out ]  ;then
	mkdir -p /var/lib/jazzhands/creds-mgmt-server/out || true
else
	true
fi

%changelog
* Fri Mar 28 2014 Todd Kover <kovert@omniscient.com> 0.57.6
- actually selected out description from an account as a gecos override
* Fri Mar 28 2014 Todd Kover <kovert@omniscient.com> 0.57.5
- force uids and gids to integers
* Thu Mar 27 2014 Todd Kover <kovert@omniscient.com> 0.57.4
- fix gid overrides to work
* Tue Mar 25 2014 Todd Kover <kovert@omniscient.com> 0.57.2
- add PreferLocalSSHAuthorizedKeys per-user attribute
- migrate PreferLocal to be a UnixPasswdFileValue
* Mon Jan 27 2014 Todd Kover <kovert@omniscient.com> 0.56.9
- add PrerferLocal flag to users...
* Fri Jan 24 2014 Todd Kover <kovert@omniscient.com> 0.56.8
- add -random-sleep argument
* Fri Jan 24 2014 Todd Kover <kovert@omniscient.com> 0.56.7
- make group management work properly
* Wed Jan 22 2014 Todd Kover <kovert@omniscient.com> 0.56.1
- add a %post
* Fri Dec 20 2013 Todd Kover <kovert@omniscient.com> 0.56.0
- initial release
