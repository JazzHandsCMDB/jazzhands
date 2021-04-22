Summary:    python2.7-jazzhands-vault - python Vault interface
Vendor:     JazzHands
Name:       python-jazzhands-vault
Version:    __VERSION__
Release:    1
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
Source0:    %{name}-%{version}.tar.gz
BuildRoot:  %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch:  noarch
%if 0%{?suse_version}
BuildRequires: python >= 2.7
Requires: python >= 2.7
%else
BuildRequires: python2.7
Requires: python2.7
%endif

%define filelist %{name}-%{version}-filelist

%description
python2.7 Vault interface

%prep
%setup -q -n %{name}-%{version}

%build
python2.7 setup.py build

%install
export BUILDVERSION="%{version}-%{release}"
python2.7 setup.py install -O1 --root=%{buildroot} --record=%{filelist}

%files -f %{filelist}
%defattr(755,root,root,-)
%if %{_vendor} == "suse"
%dir /usr/lib/python2.7/site-packages/jazzhands_vault
%endif
