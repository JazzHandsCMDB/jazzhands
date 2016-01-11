%define name    jazzhands-approval
%define prefix	/usr/libexec/jazzhands/approval
%define release 0
Name:   	jazzhands-approval
Version:        __VERSION__
Release:        0%{?dist}
Summary:        JazzHands Front Ends for Interaction with Approval System
Group:  	System Environment/Libraries
License:        BSD
URL:    	http://www.jazzhands.net/
Source0:        %{name}-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch:	noarch
%if 0%{?suse_version}
%else
%if 0%{?rhel} < 6
BuildRequires: perl(ExtUtils::MakeMaker)
%else
BuildRequires: perl-ExtUtils-MakeMaker
%endif
%endif
Requires:      	perl-JazzHands-DBI,perl-JazzHands-AppAuthAL,jazzhands-perl-tickets

%description

System Tools for Administrative Baselining


%prep
%setup -q -n %{name}-%{version}
make -f Makefile.jazzhands BUILDPERL=%{__perl}

%install
make -f Makefile.jazzhands INSTALLROOT=%{buildroot} PREFIX=%{prefix} install

%clean
make -f Makefile.jazzhands clean


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


