%define prefix  /var/www/jazzhands-javascript-common

Summary:    Javascript used by all JazzHands systems
Vendor:     JazzHands
Name:       jazzhands-javascript-common
Version:    0.64.5
Release:    1
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
BuildArch:  noarch
Source0:   %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch:noarch

%description
Javascript used by all JazzHands systems (many external)

%prep
%setup -q -n %{name}-%{version}

%install
rm -rf %{buildroot}

mkdir -p %{buildroot}/%{prefix}

tar cf - `find . -name \*.js -o -name \*.css ` external/chosen/* | (cd %{buildroot}/%{prefix} ; tar xpf -)

%clean
rm -rf %{buildroot}


%files
%defattr(755,root,root,-)
%{prefix}//common.js
%{prefix}/external/scriptaculous/dragdrop.js
%{prefix}/external/scriptaculous/builder.js
%{prefix}/external/scriptaculous/effects.js
%{prefix}/external/scriptaculous/scriptaculous.js
%{prefix}/external/scriptaculous/unittest.js
%{prefix}/external/scriptaculous/sound.js
%{prefix}/external/scriptaculous/controls.js
%{prefix}/external/scriptaculous/slider.js
%{prefix}/external/jQuery/jquery.js
%{prefix}/external/jQuery/jquery-1.9.0.js
%{prefix}/external/prototype/prototype.js
%{prefix}/external/chosen/chosen-sprite.png
%{prefix}/external/chosen/chosen.css
%{prefix}/external/chosen/chosen.jquery.js
%{prefix}/external/datatables-1.10.9/jquery.dataTables.min.css
%{prefix}/external/datatables-1.10.9/jquery.dataTables.min.js

%changelog
* Fri Sep 25 2015 Todd Kover <kovert@omniscient.com> 0.64.5
- add datatables from https://www.datatables.net/
* Fri Sep 25 2015 Todd Kover <kovert@omniscient.com> 0.64.3
- add chosen
* Fri Jun  2 2014 Todd Kover <kovert@omniscient.com> 0.57.10
  - make it so that description stuff can be run multiple times
* Fri Sep 27 2013 Todd Kover <kovert@omniscient.com> 0.54.2-1
  - do away with "original" description in editabletext implementation
* Fri Sep 27 2013 Todd Kover <kovert@omniscient.com> 0.54.0-2
  - trim strings as they are edited with jquery editabletext
* Thu Feb 20 2013 Todd Kover <kovert@omniscient.com> 0.51.1-2
  - make work
