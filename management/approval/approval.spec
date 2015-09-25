%define name    jazzhands-approval
%define prefix	/usr/libexec/jazzhands/approval
%define release 0
Name:   	jazzhands-approval
Version:        0.64.2
Release:        0%{?dist}
Summary:        JazzHands Front Ends for Interaction with Approval System
Group:  	System Environment/Libraries
License:        BSD
URL:    	http://www.jazzhands.net/
Source0:        %{name}-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch:	noarch
BuildRequires:  perl-ExtUtils-MakeMaker
Requires:      	perl-JazzHands-DBI,perl-JazzHands-AppAuthAL

%description

System Tools for Administrative Baselining


%prep
%setup -q -n %{name}-%{version}

echo Nothing to do for web site
# There will be modules
# echo Building perl modules
# cd perl/src && %{__perl} Makefile.PL INSTALLDIRS=vendor --default



%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/%{prefix}

cp -p approval-email.pl $RPM_BUILD_ROOT/%{prefix}/approval-email

# module stuff
# cd perl/src && make pure_install PERL_INSTALL_ROOT=$RPM_BUILD_ROOT
# find $RPM_BUILD_ROOT -type f -name .packlist -exec rm -f {} \;
# find $RPM_BUILD_ROOT -depth -type d -exec rmdir {} 2>/dev/null \;
# find %{buildroot} -name Makefile -print |xargs rm -f 

%clean
rm -rf %{buildroot}

%files
%defattr(755,root,root,-)
%{prefix}/approval-email

%changelog
* Fri Sep 25 2015 Todd Kover <kovert@omniscient.com> 0.64.2
- initial release

