%define prefix  /var/www/jazzhands-javascript-common

Summary:    Javascript used by all JazzHands systems
Vendor:     JazzHands
Name:       jazzhands-javascript-common
Version:    0.51
Release:    1
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
BuildArch:  noarch
Source0:	%{name}.tgz
BuildRoot:      %{_tmppath}/%{name}-root
BuildArch:	noarch

%description
Javascript used by all JazzHands systems (many external)

%prep
%setup -q -n %{name}

%install
rm -rf %{buildroot}

mkdir -p %{buildroot}/%{prefix}

tar cf - `find . -name \*.js` | (cd %{buildroot}/%{prefix} ; tar xpf -)

%clean
rm -rf %{buildroot}


%files
%defattr(755,root,root,-)
%{prefix}//common.js
%{prefix}//external/scriptaculous/dragdrop.js
%{prefix}//external/scriptaculous/builder.js
%{prefix}//external/scriptaculous/effects.js
%{prefix}//external/scriptaculous/scriptaculous.js
%{prefix}//external/scriptaculous/unittest.js
%{prefix}//external/scriptaculous/sound.js
%{prefix}//external/scriptaculous/controls.js
%{prefix}//external/scriptaculous/slider.js
%{prefix}//external/jQuery/jquery.js
%{prefix}//external/jQuery/jquery-1.9.0.js
%{prefix}//external/prototype/prototype.js


%changelog
* Thu Feb 20 2013 Todd Kover <kovert@omniscient.com> 0.51.1-2
  - make work
