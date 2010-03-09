#!/usr/local/bin/perl
# Copyright (c) 2005-2010, Vonage Holdings Corp.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=head1 NAME

 consacltool - manage console ACLs in JazzHands

=head1 SYNOPSIS

 consacltool --help

 consacltool { --user userid | --uclass uclass } --add-to
     --mclass mclass [ --permissions rwbx ]

 consacltool { --user userid | --uclass uclass } --remove-from
     --mclass mclass [ --permissions rwbx ]

 consacltool { --user userid | --uclass uclass } --add-to-default

 consacltool { --user userid | --uclass uclass } --remove-from-default

 consacltool { --user userid | --uclass uclass } --sudo-grants-console
     [ --permissions rwbx ]

 consacltool { --user userid | --uclass uclass } --sudo-grants-nothing

 consacltool --show-dep [ --user userid | --uclass uclass ]
     [ --mclass mclass ]

 consacltool --show-conf

=head1 DESCRIPTION

consacltool is a command-line interface for manipulating console access
control lists. Access to console is granted on uclass/mclass basis,
i.e. you specify that users in uclass U have access to console to
hosts in mclass M. Optionally you can specify which permissions the
users have. Available permissions are 'r' for reading, 'w' for
writing, 'b' for sending break, and 'x' for exclusive access. Whenever
users have access to console on a certain machine, the 'r' privilege
is always granted, i.e. you can't grant just 'b' or 'wx'.

Inheritance of mclasses is supported. When you grant somebody console
access to machines in a parent mclass, machines in all child mclasses
inherit the permisions. Bitwise OR is performed between permissions
inherited from parent mclass, and permissions for the current
mclass. For example, if A is the parent mclass of B, and you grant
permissions 'rb' to the uclass U and mclass A, and permissions 'rw' to
the uclass U and mclass B, users in the uclass U will have permissions
'rwb' on the mclass B.

=head1 OPTIONS

=over 4

=cut

###############################################################################

BEGIN {
	my $dir = $0;
	if ( $dir =~ m,/, ) {
		$dir =~ s!^(.+)/[^/]+$!$1!;
	} else {
		$dir = ".";
	}

	#
	# Copy all of the entries in @INC, and prepend the fakeroot install
	# directory.
	#
	my @SAVEINC = @INC;
	foreach my $incentry (@SAVEINC) {
		unshift( @INC, "$dir/../../fakeroot.lib/$incentry" );
	}
	unshift( @INC, "$dir/../lib/lib" );
}

use strict;
use warnings;
use DBI;
use Getopt::Long;
use Pod::Usage;
use IO::File;
use File::Temp;
use JazzHands::Management qw(:DEFAULT);

## option variables

our $o_help;
our $o_add_to;
our $o_remove_from;
our $o_add_to_default;
our $o_remove_from_default;
our $o_sudo_grants_console;
our $o_sudo_grants_nothing;
our $o_mclass;
our $o_user;
our $o_uclass;
our $o_permissions;
our $o_show_dep;
our $o_show_conf;

GetOptions(
	'help'                => \$o_help,
	'add-to'              => \$o_add_to,
	'remove-from'         => \$o_remove_from,
	'add-to-default'      => \$o_add_to_default,
	'remove-from-default' => \$o_remove_from_default,
	'sudo-grants-console' => \$o_sudo_grants_console,
	'sudo-grants-nothing' => \$o_sudo_grants_nothing,
	'mclass=s'            => \$o_mclass,
	'user=s'              => \$o_user,
	'uclass=s'            => \$o_uclass,
	'permissions=s'       => \$o_permissions,
	'show-dep'            => \$o_show_dep,
	'show-conf'           => \$o_show_conf
) or exit(2);

my $jh;

main();
exit(0);

###############################################################################

sub main {
	my @options;

	check_excl_options(
		@options =
		  qw(--help --add-to --remove-from
		  --add-to-default --remove-from-default --sudo-grants-console
		  --sudo-grants-nothing --show-dep --show-conf)
	);

	die "Unable to open connection to JazzHands"
	  unless ( $jh =
		JazzHands::Management->new( application => 'acctmgt' ) );

	if    ( defined $o_help )                { cmd_help(); }
	elsif ( defined $o_add_to )              { cmd_add_to(); }
	elsif ( defined $o_remove_from )         { cmd_remove_from(); }
	elsif ( defined $o_add_to_default )      { cmd_add_to_default(); }
	elsif ( defined $o_remove_from_default ) { cmd_remove_from_default(); }
	elsif ( defined $o_sudo_grants_console ) { cmd_sudo_grants_console(); }
	elsif ( defined $o_sudo_grants_nothing ) { cmd_sudo_grants_nothing(); }
	elsif ( defined $o_show_dep )            { cmd_show_dep(); }
	elsif ( defined $o_show_conf )           { cmd_show_conf(); }
	else {
		die "one of: "
		  . join( ', ', @options )
		  . " must be specified\n";
	}
}

###############################################################################
#
# check_excl_options(@list_of_options)
#
# Dies with an error message when more than one of the command-line
# options in @list_of_options has been specified. Options must have a
# corresponding "our" variable with the same name as the option,
# except the initial "--" is replaced with "o_" and dashes with
# underscores. For example, there must be "our" variable
# $o_list_defaults for the command-line option --list-defaults
#
###############################################################################

sub check_excl_options {
	no strict 'refs';
	my ( $s, @o ) = ( 0, @_ );

	foreach my $r (@o) {
		$r =~ s/^--/o_/;
		$r =~ s/-/_/g;
		$s += ( defined($$r) ? 1 : 0 );
	}

	if ( $s > 1 ) {
		die "options " . join( ', ', @_ ) . " cannot be combined\n";
	}
}

###############################################################################

=pod

=item --help

Print short help message and exit.

=cut

###############################################################################

sub cmd_help {
	check_excl_options(qw(--help --mclass --user --uclass --permissions));

	pod2usage(0);
}

###############################################################################

=pod

=item { --uclass uclass | --user userid } --add-to --mclass mclass
[ --permissions rwbx ]

Grant the user userid or the uclass uclass access to console on
machines in the mclass mclass. You can optionally specify which
permission are to be assigned. The default is rwbx.

=cut

###############################################################################

sub cmd_add_to {
	check_excl_options(qw(--user --uclass));

	unless ( defined($o_uclass) || defined($o_user) ) {
		die "one of: --uclass, --user must be specified\n";
	}

	unless ( defined($o_mclass) ) {
		die "option --mclass is required\n";
	}

	die $jh->Error
	  . "\n"
	  unless (
		$jh->AddConsACLToMclass(
			-uclass      => $o_uclass,
			-user        => $o_user,
			-mclass      => $o_mclass,
			-permissions => $o_permissions
		)
	  );
}

###############################################################################

=pod

=item { --uclass uclass | --user userid } --remove-from --mclass mclass

Revoke access to console on machines in the mclass mclass from the
user userid or uclass uclass.

=cut

###############################################################################

sub cmd_remove_from {
	check_excl_options(qw(--remove-from --permissions));
	check_excl_options(qw(--user --uclass));

	unless ( defined($o_uclass) || defined($o_user) ) {
		die "one of: --uclass, --user must be specified\n";
	}

	unless ( defined($o_mclass) ) {
		die "option --mclass is required\n";
	}

	die $jh->Error
	  . "\n"
	  unless (
		$jh->RemoveConsACLFromMclass(
			-uclass => $o_uclass,
			-user   => $o_user,
			-mclass => $o_mclass
		)
	  );
}

###############################################################################

=pod

=item { --uclass uclass | --user userid } --add-to-default

Grant the user userid or the uclass uclass access to console on
all machines with permissions rwbx.

=cut

###############################################################################

sub cmd_add_to_default {
	check_excl_options(qw(--user --uclass));

	unless ( defined($o_uclass) || defined($o_user) ) {
		die "one of: --uclass, --user must be specified\n";
	}

	die $jh->Error
	  . "\n"
	  unless (
		$jh->AddConsACLToDefault(
			-uclass => $o_uclass,
			-user   => $o_user
		)
	  );
}

###############################################################################

=pod

=item { --uclass uclass | --user userid } --remove-from-default

Revoke access to console on all machines from the user userid or
uclass uclass. This option only revokes access granted with the option
--add-to-default. Individual per-mclass grants are not affected by
this option.

=cut

###############################################################################

sub cmd_remove_from_default {
	check_excl_options(qw(--remove-from --permissions));
	check_excl_options(qw(--user --uclass));

	unless ( defined($o_uclass) || defined($o_user) ) {
		die "one of: --uclass, --user must be specified\n";
	}

	die $jh->Error
	  . "\n"
	  unless (
		$jh->RemoveConsACLFromMclass(
			-uclass => $o_uclass,
			-user   => $o_user
		)
	  );
}

###############################################################################

=pod

=item { --uclass uclass | --user userid } --sudo-grants-console
[ --permissions rwbx ]

Set the "sudo grants console" attribute for the uclass uclass or the
user userid. If this attribute is set for a uclass or a user, the
specified user(s) will have console access to all machines where they
have a full sudo access. Console access permissions can be optionally
specified.

=cut

###############################################################################

sub cmd_sudo_grants_console {
	check_excl_options(qw(--user --uclass));

	unless ( defined($o_uclass) || defined($o_user) ) {
		die "one of: --uclass, --user must be specified\n";
	}

	die $jh->Error
	  . "\n"
	  unless (
		$jh->AddSudoGrantsConsole(
			-uclass      => $o_uclass,
			-user        => $o_user,
			-permissions => $o_permissions
		)
	  );
}

###############################################################################

=pod

=item { --uclass uclass | --user userid } --sudo-grants-nothing
[ --permissions rwbx ]

Remove the "sudo grants console" attribute from the uclass uclass or the
user userid.

=cut

###############################################################################

sub cmd_sudo_grants_nothing {
	check_excl_options(qw(--user --uclass));

	unless ( defined($o_uclass) || defined($o_user) ) {
		die "one of: --uclass, --user must be specified\n";
	}

	die $jh->Error
	  . "\n"
	  unless (
		$jh->RemoveSudoGrantsConsole(
			-uclass => $o_uclass,
			-user   => $o_user
		)
	  );
}

###############################################################################

=pod

=item --show-dep [ --mclass mclass ] [ --user userid | --uclass uclass ]

Shows dependencies for the specified mclass, uclass, or userid. If you
specify more than one parameter, they are combined using a logical AND
operator. For each user specification, or default assignment which
matches the specified parameters, the command prints the following
information:

            mclass:
            uclass:
       uclass type:
     property name:
       permissions:

=cut

###############################################################################

sub cmd_show_dep {
	my $aref;

	check_excl_options(qw(--show-dep --permissions));
	check_excl_options(qw(--user --uclass));

	$aref = $jh->GetConsACLDependencies(
		-mclass => $o_mclass,
		-uclass => $o_uclass,
		-user   => $o_user
	);

	die $jh->Error . "\n"
	  unless ( defined $aref );

	foreach my $row (@$aref) {
		my $mclass = shift(@$row) || '';
		my $uclass = shift(@$row);
		my $utype  = shift(@$row);
		my $pname  = shift(@$row);
		my $perm   = shift(@$row);

		print "            mclass: $mclass\n"
		  . "            uclass: $uclass\n"
		  . "       uclass type: $utype\n"
		  . "     property name: $pname\n"
		  . "       permissions: $perm\n\n";
	}
}

###############################################################################

=pod

=item --show-conf

Print the contents of the file nconsole.conf.

=cut

###############################################################################

sub cmd_show_conf {
	my $text;

	check_excl_options(
		qw(--show-conf --mclass --user --uclass --permissions));
	$text = $jh->GetNconsoleConf;

	die $jh->Error . "\n" unless ( defined $text );

	print $text;
}

=pod

=back

=head1 EXAMPLES

Grant uclass sysarch access to console of all machines:

 s7:~$ consacltool --uclass sysarch --add-to-default

Grant uclass dba access to console of machines in the dbservers mclass:

 s7:~$ consacltool --uclass dba --add-to --mclass dbservers

Grant user swm read-only access to console of machines in the
sysarch-test mclass:

 s7:~$ consacltool --user swm --add-to --mclass sysarch-test --permissions r

Show the mclasses DBAs have access to console on:

 s7:~$ consacltool --show-dep --uclass dba | grep mclass
 mclass: dbservers

Show how the nconsole.conf file looks like:

 s7:~$ consacltool --show-conf

=head1 BUGS

Due to a limitation in the netconsole software, granting console access
to mclasses containing a device with a name which does not start with
a letter is not currently possible.

If a user is a member of multiple uclasses, and different access
permissions are granted to these uclasses for a given mclass, the user
will have permissions of the uclass with the highest uclass_id.

=head1 SEE ALSO

mclasstool(1), uclasstool(1)

=head1 AUTHOR

Bernard Jech
