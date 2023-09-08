Summary:    python2.7-jazzhands-appauthal - generates unix credentials
Vendor:     JazzHands
Name:       python-jazzhands-appauthal
Version:    __VERSION__
Release:    1
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
Source0:    %{name}-%{version}.tar.gz
BuildRoot:  %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch:  noarch
BuildRequires: make
%if 0%{?suse_version}
BuildRequires: python >= 2.7
Requires: python >= 2.7
%else
BuildRequires: python2.7
Requires: python2.7
%endif

%define filelist %{name}-%{version}-filelist

%description
python2.7 version of JazzHands appauthal interface

%prep
%setup -q -n %{name}-%{version}

%build
python2.7 setup.py build

%install
export BUILDVERSION="%{version}-%{release}"
python2.7 setup.py install -O1 --root=%{buildroot} --record=%{filelist}

%files -f %{filelist}
%defattr(755,root,root,-)
%if 0%{?suse_version}
%dir /usr/lib/python2.7/site-packages/jazzhands_appauthal
%endif
