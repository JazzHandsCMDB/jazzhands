Summary:    perl-JazzHands-LDAP - JazzHands LDAP management for perl
Vendor:     JazzHands
Name:       perl-JazzHands-LDAP
Version:    1.0
Release:    0
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
BuildArch:  noarch

%description
JazzHands LDAP connection and management modules for perl

%files
%attr (-, root, bin) %{perl_vendorlib}/JazzHands/LDAP.pm
%attr (-, root, bin) %{perl_vendorarch}/auto/JazzHands/LDAP/.packlist
%attr (-, root, bin) %{_mandir}/*/* 
