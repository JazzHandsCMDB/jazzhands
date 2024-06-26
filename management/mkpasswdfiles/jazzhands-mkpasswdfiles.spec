%define	prefix	/usr
%define	mkproot	libexec/jazzhands/mkpasswdfiles

Summary:    jazzhands-mkpasswdfiles - generates unix credentials
Vendor:     JazzHands
Name:       jazzhands-mkpasswdfiles
Version:    __VERSION__
Release:    1
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
Source0:    %{name}-%{version}.tar.gz
BuildRoot:  %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch:  noarch
BuildRequires: make
Requires:   jazzhands-perl-common, perl-JazzHands-DBI,


%description
Generates unix credentials

%prep
%setup -q -n %{name}-%{version}
make

%install
make  DESTDIR=%{buildroot} PREFIX=%{prefix} install

%clean
make  clean

%files
%defattr(755,root,root,-)
%{prefix}/%{mkproot}/mkpasswdfiles

%post
if [ ! -d /var/lib/jazzhands/creds-mgmt-server/out ]  ;then
	mkdir -p /var/lib/jazzhands/creds-mgmt-server/out || true
else
	true
fi
