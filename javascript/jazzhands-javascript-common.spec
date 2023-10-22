%define prefix  /var/www/jazzhands-javascript-common
%define filelist %{name}-%{version}-filelist

Summary:    Javascript used by all JazzHands systems
Vendor:     JazzHands
Name:       jazzhands-javascript-common
Version:    __VERSION__
Release:    1
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
BuildArch:  noarch
Source0:   %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildRequires: make

%description
Javascript used by all JazzHands systems (many external)

%prep
%setup -q -n %{name}-%{version}
make

%install
make DESTDIR=%{buildroot} PREFIX=%{prefix} install
(cd %{buildroot}  && (find .%{prefix} \( -type f -o -type l \) -print) | sed s,^\.,,) |sort | uniq | tee > %{filelist}

%clean
make clean

%files -f %{filelist}
%defattr(755,root,root,-)
