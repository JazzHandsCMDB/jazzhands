%define name    jazzhands-approval
%define prefix	/usr/libexec/jazzhands/approval
%define release 0
Name:   	jazzhands-approval
Version:        0.64.11
Release:        0%{?dist}
Summary:        JazzHands Front Ends for Interaction with Approval System
Group:  	System Environment/Libraries
License:        BSD
URL:    	http://www.jazzhands.net/
Source0:        %{name}-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch:	noarch
BuildRequires:  perl-ExtUtils-MakeMaker
Requires:      	perl-JazzHands-DBI,perl-JazzHands-AppAuthAL,jazzhands-perl-tickets

%description

System Tools for Administrative Baselining


%prep
%setup -q -n %{name}-%{version}
echo Building perl modules
cd lib && %{__perl} Makefile.PL INSTALLDIRS=vendor --default

%install
rm -rf $RPM_BUILD_ROOT

mkdir -p  $RPM_BUILD_ROOT/etc/init.d/

cp -p process-jira-issue-approvals.init.d $RPM_BUILD_ROOT/etc/init.d/process-jira-issue-approvals
cp -p process-rt-queue-approvals.init.d $RPM_BUILD_ROOT/etc/init.d/process-rt-queue-approvals

mkdir -p $RPM_BUILD_ROOT/%{prefix}
cp -p approval-email.pl $RPM_BUILD_ROOT/%{prefix}/approval-email
cp -p build-approvals.pl $RPM_BUILD_ROOT/%{prefix}/build-approvals
cp -p process-rt-queue-approvals.pl $RPM_BUILD_ROOT/%{prefix}/process-rt-queue-approvals
cp -p process-jira-issue-approvals.pl $RPM_BUILD_ROOT/%{prefix}/process-jira-issue-approvals

# module stuff
cd lib && make pure_install PERL_INSTALL_ROOT=$RPM_BUILD_ROOT
find $RPM_BUILD_ROOT -type f -name .packlist -exec rm -f {} \;
find $RPM_BUILD_ROOT -depth -type d -exec rmdir {} 2>/dev/null \;
find %{buildroot} -name Makefile -print |xargs rm -f 

%clean
rm -rf %{buildroot}

%post
/etc/init.d/process-jira-issue-approvals status | grep "is running" >/dev/null
if [ $? -eq 0 ]; then
    /etc/init.d/process-jira-issue-approvals restart
fi

/etc/init.d/process-rt-queue-approvals status | grep "is running" >/dev/null
if [ $? -eq 0 ]; then
    /etc/init.d/process-rt-queue-approvals restart
fi


%files
%defattr(755,root,root,-)
/etc/init.d/process-jira-issue-approvals
/etc/init.d/process-rt-queue-approvals
%{prefix}/approval-email
%{prefix}/build-approvals
%{prefix}/process-rt-queue-approvals
%{prefix}/process-jira-issue-approvals
%{perl_vendorlib}/JazzHands/Approvals.pm
%{_mandir}/man3/JazzHands::Approvals.3pm.gz


%changelog
* Mon Nov 16 2015 Todd Kover <kovert@omniscient.com> 0.64.11
- fix whence on approval-email call when no date is passed in
* Thu Nov 12 2015 Todd Kover <kovert@omniscient.com> 0.64.10
- add build-approvals script
* Thu Nov 12 2015 Todd Kover <kovert@omniscient.com> 0.64.9
- add reminder-gap
- move much to the database for approval messages 
* Tue Nov 10 2015 Todd Kover <kovert@omniscient.com> 0.64.8
- add max escalation level support to approval utils
* Mon Nov  2 2015 Todd Kover <kovert@omniscient.com> 0.64.7
- add docs to rt, jira
- add random-sleep argument everywhere
* Mon Oct 19 2015 Todd Kover <kovert@omniscient.com> 0.64.6
- add optional automated-escalation
* Tue Sep 30 2015 Todd Kover <kovert@omniscient.com> 0.64.5
- add delay towards doing resubmissions
* Tue Sep 29 2015 Todd Kover <kovert@omniscient.com> 0.64.4
- add rt and jira management
* Fri Sep 25 2015 Todd Kover <kovert@omniscient.com> 0.64.2
- initial release

