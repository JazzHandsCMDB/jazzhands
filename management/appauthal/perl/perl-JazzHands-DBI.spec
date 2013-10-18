Summary:    JazzHands-DBI - database authentication abstraction for Perl
Vendor:     JazzHands
Name:       perl-JazzHands-DBI
Version:    0.53
Release:    1
License:    Unknown
Group:      System/Management
Url:        http://www.jazzhands.net/
BuildArch:  noarch

%description
DBI shim for JazzHands to support database authentication abstraction

%files
%attr (-, root, bin) %{perl_vendorlib}/JazzHands/DBI.pm
%attr (-, root, bin) %{perl_vendorarch}/auto/JazzHands/DBI/.packlist
%attr (-, root, bin) %{_mandir}/*/* 
