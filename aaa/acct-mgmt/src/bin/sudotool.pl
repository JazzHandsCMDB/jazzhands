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

 sudotool - manage sudoers in JazzHands

=head1 SYNOPSIS

 sudotool --help

 sudotool --list-defaults
 sudotool --new-default --set value
 sudotool --new-default --edit
 sudotool --default id --set value
 sudotool --default id --edit
 sudotool --default id --delete
 sudotool --default id --add-to --mclass mclass
 sudotool --default id --remove-from --mclass mclass

 sudotool --list-cmnd-aliases
 sudotool --new-cmnd-alias CMD --set /bin/command
 sudotool --new-cmnd-alias CMD --edit
 sudotool --cmnd-alias CMD --set /bin/command
 sudotool --cmnd-alias CMD --edit
 sudotool --cmnd-alias CMD --show
 sudotool --cmnd-alias CMD --delete
 sudotool --cmnd-alias CMD --rename-to NEWCMD

 sudotool --cmnd-alias CMD { --user userid | --uclass uclass } --add-to
     --mclass mclass [ --run-as-user runasuserid | --run-as-uclass
     runasuclass ] [ --exec | --noexec ] [ --passwd | --nopasswd ]

 sudotool --cmnd-alias CMD { --user userid | --uclass uclass } 
     --remove-from --mclass mclass

 sudotool --show-dep [ --default id ] [ --mclass mclass ]
    [ --user userid | --uclass uclass ] [ --run-as-user runaslogin |
    --run-as-uclass runasuclass ]

 sudotool --enable-sudoers --mclass mclass
 sudotool --disable-sudoers --mclass mclass

 sudotool --show-sudoers --mclass mclass

=head1 DESCRIPTION

sudotool is a command-line interface for manipulating sudoers data
stored in JazzHands.

=head2 sudoers file

A sudoers file consists of three main parts: Defaults, Aliases, and
User Specifications. Defaults are sudo options that can be changed
from their default values via one or more Defaults entries in the
sudoers file. Aliases are of four types: user aliases, run as aliases,
host aliases, and command aliases. User Specifications determine which
commands a user may run (and as what user) on specified hosts. The
structure of the sudoers file is fairly complex and it's full
description is beyond the scope of this manual page. For more
information about the sudoers file please refer to L<sudoers(5)>.

=head2 sudoers in JazzHands

The data model for storing sudoers in JazzHands follows the general
philosophy of JazzHands. Certain restrictions have been introduced as to
what is allowed in the sudoers file to avoid unnecessarily complex
schema design. 

sudo permissions are granted on mclass/uclass basis, i.e. you specify
that users in the uclass U1 can run commands defined by the command
alias CMD on all machines in the mclass M as users in the uclass
U2. Permissions are granted for the mclass as a whole. You can't
single out one or a few machines out of an mclass, and have different
sudo permissions for just these machines. If you need different sudo
permissions for a subset of an mclass, you need to split these
machines off to another mclass. Similarly, you can't grant sudo
permissions to individual users, you must grant permissions for an
entire uclass. If you need to grant permissions to individual users,
you need to use a per-user uclass.

You must define a command alias for each command, or a group of
commands that you want to grant permissions to, i.e. you can't say
that users in the uclass U1 can run the command /bin/kill as root on
machines in the mclass M. You need to define a command alias first,
and then grant permissions for this command alias. Command aliases can
only contain command definitions, they cannot contain other command
aliases. The command alias ALL is pre-defined, and it can't be renamed
or modified.

Defaults are assigned on a per mclass basis, and they affect all hosts
and all users in that mclass. Defaults that affect only specific
hosts, or specific users are not supported.

The '!' operator is not supported. It is desirable to allow certain
users to run certain commands, and move away from the current practice
of allowing groups of users to run ALL commands except certain ones by
using the '!'  operator.

Inheritance of mclasses is supported. A child mclass inherits all
command aliases and user specifications from the parent mclass. User
specifications will be included in the sudoers file in the order of
how they are encountered in the inheritance chain. The most specific
defaults are included in the sudoers file.

Whenever command aliases and defaults are modified, sudotool uses
visudo to check for syntax errors. Syntactically incorrect entries are
not permitted to be entered into the database, but it is not advised
to rely on this functionality to ensure correctness and accuracy of
your sudo entries.

You can specify which external editor should be used by the --edit
option by setting the envrionment variable VISUAL or EDITOR. If
neither of the two is set, /bin/vi is used.

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
our $o_list_defaults;
our $o_new_default;
our $o_default;
our $o_set;
our $o_edit;
our $o_show;
our $o_delete;
our $o_add_to;
our $o_remove_from;
our $o_rename_to;
our $o_mclass;
our $o_show_dep;
our $o_list_cmnd_aliases;
our $o_new_cmnd_alias;
our $o_cmnd_alias;
our $o_user;
our $o_uclass;
our $o_run_as_user;
our $o_run_as_uclass;
our $o_exec;
our $o_passwd;
our $o_enable_sudoers;
our $o_disable_sudoers;
our $o_show_sudoers;

GetOptions(
	'help'              => \$o_help,
	'list-defaults'     => \$o_list_defaults,
	'new-default'       => \$o_new_default,
	'default=i'         => \$o_default,
	'set=s'             => \$o_set,
	'edit'              => \$o_edit,
	'show'              => \$o_show,
	'delete'            => \$o_delete,
	'add-to'            => \$o_add_to,
	'remove-from'       => \$o_remove_from,
	'rename-to=s'       => \$o_rename_to,
	'mclass=s'          => \$o_mclass,
	'show-dep'          => \$o_show_dep,
	'list-cmnd-aliases' => \$o_list_cmnd_aliases,
	'new-cmnd-alias=s'  => \$o_new_cmnd_alias,
	'cmnd-alias=s'      => \$o_cmnd_alias,
	'user=s'            => \$o_user,
	'uclass=s'          => \$o_uclass,
	'run-as-user=s'     => \$o_run_as_user,
	'run-as-uclass=s'   => \$o_run_as_uclass,
	'exec!'             => \$o_exec,
	'passwd!'           => \$o_passwd,
	'enable-sudoers'    => \$o_enable_sudoers,
	'disable-sudoers'   => \$o_disable_sudoers,
	'show-sudoers'      => \$o_show_sudoers
) or exit(2);

my $vi     = '/bin/vi';
my $visudo = '/usr/local/sbin/visudo';
my $jh;

main();
exit(0);

###############################################################################

sub main {
	my @options;

	check_excl_options(
		@options =
		  qw(--help --list-defaults
		  --new-default --default --list-cmnd-aliases --new-cmnd-alias
		  --cmnd-alias --enable-sudoers --disable-sudoers --show-sudoers)
	);

	die "Unable to open connection to JazzHands"
	  unless ( $jh =
		JazzHands::Management->new( application => 'acctmgt' ) );

	if    ( defined $o_help )              { cmd_help(); }
	elsif ( defined $o_show_dep )          { cmd_show_dep(); }
	elsif ( defined $o_list_defaults )     { cmd_list_defaults(); }
	elsif ( defined $o_new_default )       { cmd_new_default(); }
	elsif ( defined $o_default )           { cmd_default(); }
	elsif ( defined $o_list_cmnd_aliases ) { cmd_list_cmnd_aliases(); }
	elsif ( defined $o_new_cmnd_alias )    { cmd_new_cmnd_alias(); }
	elsif ( defined $o_cmnd_alias )        { cmd_cmnd_alias(); }
	elsif ( defined $o_enable_sudoers )    { cmd_enable_sudoers(); }
	elsif ( defined $o_disable_sudoers )   { cmd_disable_sudoers(); }
	elsif ( defined $o_show_sudoers )      { cmd_show_sudoers(); }
	else {
		die "one of: "
		  . join( ', ', @options, '--show-dep' )
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
	check_excl_options(
		qw(--help --set --edit --show --delete --add-to
		  --remove-from --rename-to --mclass --user --uclass --run-as-user
		  --run-as-uclas --exec --passwd --show-dep)
	);

	pod2usage(0);
}

###############################################################################

=pod

=item --show-dep [ --default id ] [ --mclass mclass ]
[ --user userid | --uclass uclass ] [ --run-as-user runasuserid |
--run-as-uclass runasuclass ]

Shows dependencies for the specified default, mclass, uclass, or
runasuclass. If you specify more than one parameter, they are combined
using a logical AND operator. For each user specification, or default
assignment which matches the specified parameters, the command prints
the following information:

            mclass:
   sudo_default_id:
generation enabled:
     command alias:
            uclass:
       uclass type:
     run as uclass:
run as uclass type:
 password required:
    can exec child:

=cut

###############################################################################

sub cmd_show_dep {
	my $aref;

	check_excl_options(
		qw(--show-dep --set --edit --show --delete --add-to
		  --remove-from --rename-to --exec --passwd)
	);

	check_excl_options(qw(--user --uclass));
	check_excl_options(qw(--run-as-user --run-as-uclass));

	$aref = $jh->GetSudoDependencies(
		-cmnd_alias    => $o_cmnd_alias,
		-mclass        => $o_mclass,
		-uclass        => $o_uclass,
		-user          => $o_user,
		-run_as_user   => $o_run_as_user,
		-run_as_uclass => $o_run_as_uclass,
		-default       => $o_default
	);

	die $jh->Error . "\n"
	  unless ( defined $aref );

	foreach my $row (@$aref) {
		my $mclass     = shift(@$row);
		my $default_id = shift(@$row) || '';
		my $should_gen = shift(@$row) || '';
		my $cmnd_alias = shift(@$row) || '';
		my $uclass     = shift(@$row) || '';
		my $utype      = shift(@$row) || '';
		my $runas      = shift(@$row) || '';
		my $rutype     = shift(@$row) || '';
		my $ynpass     = shift(@$row) || '';
		my $ynexec     = shift(@$row) || '';

		print "            mclass: $mclass\n"
		  . "   sudo_default_id: $default_id\n"
		  . "generation enabled: $should_gen\n"
		  . "     command alias: $cmnd_alias\n"
		  . "            uclass: $uclass\n"
		  . "       uclass type: $utype\n"
		  . "     run as uclass: $runas\n"
		  . "run as uclass type: $rutype\n"
		  . " password required: $ynpass\n"
		  . "    can exec child: $ynexec\n\n";
	}
}

###############################################################################

=pod

=item --list-defaults

List all sudo defaults. The first column is the SUDO_DEFAULT_ID, the
second column is the SUDO_VALUE.

=cut

###############################################################################

sub cmd_list_defaults {
	my $aref;

	check_excl_options(
		qw(--list-defaults --set --edit --show --delete
		  --add-to --remove-from --rename-to --mclass --user --uclass
		  --run-as-user --run-as-uclass --exec --passwd --show-dep)
	);

	$aref = $jh->GetSudoDefaults;

	die $jh->Error . "\n" unless ($aref);

	foreach my $row (@$aref) {
		my ( $id, $value ) = @$row;

		chomp($value);
		print "$id: $value\n";
	}
}

###############################################################################

sub cmd_new_default {
	my @options;

	check_excl_options(
		qw(--new-default --show --delete --add-to
		  --remove-from --rename-to --mclass --user --uclass --run-as-user
		  --run-as-uclass --exec --passwd --show-dep)
	);

	check_excl_options( @options = qw(--set --edit) );

	if    ( defined $o_set )  { cmd_new_default_set(); }
	elsif ( defined $o_edit ) { cmd_new_default_edit(); }
	else {
		die "one of: "
		  . join( ', ', @options )
		  . " must be specified\n";
	}
}

###############################################################################

=pod

=item --new-default --set value

Create a new sudo default entry in the SUDO_DEFAULT table, and assign
the value value to the new entry.

=cut

###############################################################################

sub cmd_new_default_set {
	exit(1) unless ( visudo_check("Defaults $o_set\n") );

	die $jh->Error . "\n"
	  unless ( $jh->NewSudoDefault( -value => $o_set ) );
}

###############################################################################

=pod

=item --new-default --edit

Create a new sudo default entry in the SUDO_DEFAULT table, and invoke
an external editor to edit the new value.

=cut

###############################################################################

sub cmd_new_default_edit {
	my $value;

	if ( defined( $value = visudo_check_edit( 'Defaults ', '' ) ) ) {
		die $jh->Error . "\n"
		  unless ( $jh->NewSudoDefault( -value => $value ) );
	}
}

###############################################################################

sub cmd_default {
	my @options;

	check_excl_options(
		qw(--default --show --user --uclass
		  --run-as-user --run-as-uclass --exec --passwd)
	);

	check_excl_options(
		@options =
		  qw(--set --edit --delete --add-to
		  --rename-to --remove-from)
	);

	if    ( defined $o_set )         { cmd_default_set(); }
	elsif ( defined $o_edit )        { cmd_default_edit(); }
	elsif ( defined $o_delete )      { cmd_default_delete(); }
	elsif ( defined $o_add_to )      { cmd_default_add_to(); }
	elsif ( defined $o_remove_from ) { cmd_default_remove_from(); }
	else {
		die "one of: "
		  . join( ', ', @options )
		  . " must be specified\n";
	}
}

###############################################################################

=pod

=item --default id --set value

Set the value of the sudo default with the SUDO_DEFAULT_ID id to value.

=cut

###############################################################################

sub cmd_default_set {
	check_excl_options(qw(--set --mclass));

	exit(1) unless ( visudo_check("Defaults $o_set\n") );

	die $jh->Error . "\n"
	  unless ( $jh->SetSudoDefault( -id => $o_default, -value => $o_set ) );
}

###############################################################################

=pod

=item --default id --edit

Invoke an external editor to edit the value of the sudo default with
the SUDO_DEFAULT_ID id.

=cut

###############################################################################

sub cmd_default_edit {
	my ( $new_value, $old_value );

	check_excl_options(qw(--edit --mclass));

	die $jh->Error
	  . "\n"
	  unless (
		defined(
			$old_value = $jh->GetSudoDefault( -id => $o_default )
		)
	  );

	if (
		defined(
			$new_value =
			  visudo_check_edit( 'Defaults ', $old_value )
		)
	  )
	{
		if ( $new_value eq $old_value ) {
			warn "no change\n";
		}

		else {
			die $jh->Error
			  . "\n"
			  unless (
				$jh->SetSudoDefault(
					-id    => $o_default,
					-value => $new_value
				)
			  );
		}
	}
}

###############################################################################

=pod

=item --default id --delete

Delete sudo default with SUDO_DEFAULT_ID id from the database.

=cut

###############################################################################

sub cmd_default_delete {
	check_excl_options(qw(--delete --mclass));

	die $jh->Error . "\n"
	  unless ( $jh->DeleteSudoDefault( -id => $o_default ) );
}

###############################################################################

=pod

=item --default id --add-to --mclass mclass

Assign the sudo default with the SUDO_DEFAULT_ID id to the mclass
mclass. An mclass can have up to one sudo default entries assigned to
it. Any previous assignment of sudo defaults for this mclass is
overwritten.

=cut

###############################################################################

sub cmd_default_add_to {
	unless ( defined $o_mclass ) {
		die "option --mclass is required\n";
	}

	die $jh->Error
	  . "\n"
	  unless (
		$jh->AddSudoDefaultToMclass(
			-id     => $o_default,
			-mclass => $o_mclass
		)
	  );
}

###############################################################################

=pod

=item --default id --remove-from --mclass mclass

Remove any and all sudo defaults from the mclass mclass. The parameter
id is required, but it is ignored. This should be fixed in the next
version.

=cut

###############################################################################

sub cmd_default_remove_from {
	unless ( defined $o_mclass ) {
		die "option --mclass is required\n";
	}

	die $jh->Error . "\n"
	  unless ( $jh->RemoveSudoDefaultFromMclass( -mclass => $o_mclass ) );
}

###############################################################################

=pod

=item --list-cmnd-aliases

List the names of all sudo command aliases.

=cut

###############################################################################

sub cmd_list_cmnd_aliases {
	my $aref;

	check_excl_options(
		qw(--list-cmnd-aliases --set --edit --show
		  --delete --add-to --remove-from --rename-to --mclass --user
		  --uclass --run-as-user --run-as-uclass --exec --passwd
		  --show-dep)
	);

	$aref = $jh->GetSudoCmndAliasNames;

	die $jh->Error . "\n" unless ($aref);

	print join( "\n", @$aref );
	print "\n" if (@$aref);
}

###############################################################################

sub cmd_new_cmnd_alias {
	my @options;

	check_excl_options(
		qw(--new-cmnd-alias --show --delete --add-to
		  --remove-from --rename-to --mclass --user --uclass --run-as-uclass
		  --exec --passwd --show-dep)
	);

	check_excl_options( @options = qw(--set --edit) );

	if    ( defined $o_set )  { cmd_new_cmnd_alias_set(); }
	elsif ( defined $o_edit ) { cmd_new_cmnd_alias_edit(); }
	else {
		die "one of: "
		  . join( ', ', @options )
		  . " must be specified\n";
	}
}

###############################################################################

=pod

=item --new-cmnd-alias CMD --set /bin/command

Create a new command alias with the name CMD, and set the value of the
command alias to be /bin/command.

=cut

###############################################################################

sub cmd_new_cmnd_alias_set {
	exit(1)
	  unless ( visudo_check("Cmnd_Alias $o_new_cmnd_alias = $o_set\n") );

	die $jh->Error
	  . "\n"
	  unless (
		$jh->NewSudoCmndAlias(
			-name  => $o_new_cmnd_alias,
			-value => $o_set
		)
	  );
}

###############################################################################

=pod

=item --new-cmnd-alias CMD --edit

Create a new command alias with the name CMD, and invoke an external
editor to edit the new value.

=cut

###############################################################################

sub cmd_new_cmnd_alias_edit {
	my $value;

	if (
		defined(
			$value = visudo_check_edit(
				"Cmnd_Alias $o_new_cmnd_alias = ", ''
			)
		)
	  )
	{
		die $jh->Error
		  . "\n"
		  unless (
			$jh->NewSudoCmndAlias(
				-name  => $o_new_cmnd_alias,
				-value => $value
			)
		  );
	}
}

###############################################################################

sub cmd_cmnd_alias {
	my @options;

	check_excl_options(
		@options =
		  qw(--set --edit --show --delete --add-to
		  --remove-from --rename-to --show-dep)
	);

	if    ( defined $o_set )         { cmd_cmnd_alias_set(); }
	elsif ( defined $o_edit )        { cmd_cmnd_alias_edit(); }
	elsif ( defined $o_show )        { cmd_cmnd_alias_show(); }
	elsif ( defined $o_delete )      { cmd_cmnd_alias_delete(); }
	elsif ( defined $o_add_to )      { cmd_cmnd_alias_add_to(); }
	elsif ( defined $o_remove_from ) { cmd_cmnd_alias_remove_from(); }
	elsif ( defined $o_rename_to )   { cmd_cmnd_alias_rename_to(); }
	else {
		die "one of: "
		  . join( ', ', @options )
		  . " must be specified\n";
	}
}

###############################################################################

=pod

=item --cmnd-alias CMD --set /bin/command

Set the value of the command alias CMD to be /bin/command.

=cut

###############################################################################

sub cmd_cmnd_alias_set {
	check_excl_options(
		qw(--set --mclass --user --uclass --run-as-user
		  --run-as-uclass --exec --passwd)
	);

	exit(1) unless ( visudo_check("Cmnd_Alias $o_cmnd_alias = $o_set\n") );

	die $jh->Error
	  . "\n"
	  unless (
		$jh->SetSudoCmndAlias(
			-name  => $o_cmnd_alias,
			-value => $o_set
		)
	  );
}

###############################################################################

=pod

=item --cmnd-alias CMD --edit

Invoke an external editor to edit the value of the command alias CMD.

=cut

###############################################################################

sub cmd_cmnd_alias_edit {
	my ( $new_value, $old_value );

	check_excl_options(
		qw(--edit --mclass --user --uclass
		  --run-as-user --run-as-uclass --exec --passwd)
	);

	die $jh->Error
	  . "\n"
	  unless (
		defined(
			$old_value =
			  $jh->GetSudoCmndAlias( -name => $o_cmnd_alias )
		)
	  );

	if (
		defined(
			$new_value = visudo_check_edit(
				"Cmnd_Alias $o_cmnd_alias = ", $old_value
			)
		)
	  )
	{
		if ( $new_value eq $old_value ) {
			warn "no change\n";
		}

		else {
			die $jh->Error
			  . "\n"
			  unless (
				$jh->SetSudoCmndAlias(
					-name  => $o_cmnd_alias,
					-value => $new_value
				)
			  );
		}
	}
}

###############################################################################

=pod

=item --cmnd-alias CMD --show

Show the value of the command alias CMD.

=cut

###############################################################################

sub cmd_cmnd_alias_show {
	my $value;

	check_excl_options(
		qw(--show --mclass --user --uclass
		  --run-as-user --run-as-uclass --exec --passwd)
	);

	die $jh->Error
	  . "\n"
	  unless (
		defined(
			$value = $jh->GetSudoCmndAlias( -name => $o_cmnd_alias )
		)
	  );
	chomp($value);
	print "$value\n";
}

###############################################################################

=pod

=item --cmnd-alias CMD --delete

Delete the command alias with the name CMD.

=cut

###############################################################################

sub cmd_cmnd_alias_delete {
	check_excl_options(
		qw(--delete --mclass --user --uclass
		  --run-as-user --run-as-uclass --exec --passwd)
	);

	die $jh->Error . "\n"
	  unless (
		defined( $jh->DeleteSudoCmndAlias( -name => $o_cmnd_alias ) ) );
}

###############################################################################

=pod

=item --cmnd-alias CMD { --user userid | --uclass uclass } --add-to
--mclass mclass [ --run-as-user runasuserid | --run-as-uclass
runasuclass ] [ --exec | --noexec ] [ --passwd | --nopasswd ]

Create a new user specification which allows the user userid or users
in the uclass uclass to execute commands specified by the command
alias CMD as the user runasuserid or users in the runasuclass
uclass. runasuclass can be ALL in which case the permitted user(s)
will be able to execute the commands specified by the alias CMD as any
user.  Parameters --exec, --noexec, --passwd, and --nopasswd are
optional and are used to add the EXEC, NOEXEC, PASSWD, and NOPASSWD
tags to the command alias.

=cut

###############################################################################

sub cmd_cmnd_alias_add_to {
	check_excl_options(qw(--user --uclass));
	check_excl_options(qw(--run-as-user --run-as-uclass));

	unless ( defined($o_uclass) || defined($o_user) ) {
		die "one of: --uclass, --user must be specified\n";
	}

	unless ( defined($o_run_as_uclass) || defined($o_run_as_user) ) {
		die
		  "one of: --run-as-uclass, --run-as-user must be specified\n";
	}

	unless ( defined($o_mclass) ) {
		die "option --mclass is required\n";
	}

	die $jh->Error
	  . "\n"
	  unless (
		defined(
			$jh->AddSudoCmndAliasToMclass(
				-name          => $o_cmnd_alias,
				-mclass        => $o_mclass,
				-user          => $o_user,
				-uclass        => $o_uclass,
				-run_as_user   => $o_run_as_user,
				-run_as_uclass => $o_run_as_uclass,
				-exec_flag     => $o_exec,
				-passwd_flag   => $o_passwd
			)
		)
	  );
}

###############################################################################

=pod

=item --cmnd-alias CMD { --user userid | --uclass uclass }
--remove-from --mclass mclass

Remove the user specification which allows commands specified by the
command alias CMD to be executed by the user userid or users in the
uclass uclass on servers in the mclass mclass.

=cut

###############################################################################

sub cmd_cmnd_alias_remove_from {
	check_excl_options(qw(--user --uclass));
	check_excl_options(qw(--run-as-user --run-as-uclass));

	unless ( defined($o_uclass) || defined($o_user) ) {
		die "one of: --uclass, --user must be specified\n";
	}

	unless ( defined($o_mclass) ) {
		die "option --mclass is required\n";
	}

	die $jh->Error
	  . "\n"
	  unless (
		defined(
			$jh->RemoveSudoCmndAliasFromMclass(
				-name   => $o_cmnd_alias,
				-mclass => $o_mclass,
				-user   => $o_user,
				-uclass => $o_uclass
			)
		)
	  );
}

###############################################################################

=pod

=item --cmnd-alias CMD --rename-to NEWCMD

Rename the command alias CMD to the new name NEWCMD.

=cut

###############################################################################

sub cmd_cmnd_alias_rename_to {
	check_excl_options(
		qw(--rename-to --mclass --user --uclass
		  --run-as-user --run-as-uclass --exec --passwd)
	);

	die $jh->Error
	  . "\n"
	  unless (
		defined(
			$jh->RenameSudoCmndAlias(
				-name    => $o_cmnd_alias,
				-newname => $o_rename_to
			)
		)
	  );
}

###############################################################################

=pod

=item --disable-sudoers --mclass mclass

Disable generating of the sudoers file for the specified mclass.

=cut

###############################################################################

sub cmd_disable_sudoers {
	check_excl_options(
		qw(--disable-sudoers --set --edit --show
		  --delete --add-to --remove-from --rename-to --show-dep --user
		  --uclass --run-as-user --run-as-uclass --exec --passwd
		  --show-dep)
	);

	unless ( defined $o_mclass ) {
		die "option --mclass is required\n";
	}

	die $jh->Error
	  . "\n"
	  unless (
		defined(
			$jh->ShouldGenerateSudoers(
				-mclass => $o_mclass,
				-flag   => 'N'
			)
		)
	  );
}

###############################################################################

=pod

=item --enable-sudoers --mclass mclass

Enable generating of the sudoers file for the specified mclass.

=cut

###############################################################################

sub cmd_enable_sudoers {
	check_excl_options(
		qw(--enable-sudoers --set --edit --show
		  --delete --add-to --remove-from --rename-to --show-dep --user
		  --uclass --run-as-user --run-as-uclass --exec --passwd
		  --show-dep)
	);

	unless ( defined $o_mclass ) {
		die "option --mclass is required\n";
	}

	die $jh->Error
	  . "\n"
	  unless (
		defined(
			$jh->ShouldGenerateSudoers(
				-mclass => $o_mclass,
				-flag   => 'Y'
			)
		)
	  );
}

###############################################################################

=pod

=item --show-sudoers --mclass mclass

Print the sudoers file for the specified mclass.

=cut

###############################################################################

sub cmd_show_sudoers {
	my $text;

	check_excl_options(
		qw(--show-sudoers --set --edit --show --delete
		  --add-to --remove-from --rename-to --show-dep --user --uclass
		  --run-as-user --run-as-uclass --exec --passwd --show-dep)
	);

	die "option --mclass is required\n" unless ( defined $o_mclass );

	$text = $jh->GetSudoersFile( -mclass => $o_mclass );

	die $jh->Error . "\n" unless ( defined $text );

	print $text;
}

###############################################################################
#
# $new_value = edit_value($old_value)
#
# Spawns an external editor to edit the value $old_value, and returns
# the edited value. The external editor can be specified using the
# environment variables VISUAL or EDITOR. If neither is defined,
# /bin/vi is used.
#
###############################################################################

sub edit_value {
	my $value   = shift;
	my $editor  = $ENV{VISUAL} || $ENV{EDITOR} || $vi;
	my $fh      = File::Temp->new or die "can't open tempfile\n";
	my $tmpname = $fh->filename;
	my $cmd     = "$editor $tmpname";

	print $fh $value;
	$fh->close;
	system($cmd);

	if ( $? == -1 ) {
		die "failed to execute $cmd: $!\n";
	}

	elsif ( $? & 127 ) {
		die "$cmd died with signal %d\n", ( $? & 127 );
	}

	elsif ( $? != 0 ) {
		## this should be die instead of warn, but /bin/vi sometimes
		## exits with a non-zero status code even when nothing is
		## wrong
		warn sprintf( "$cmd exited with value %d\n", $? >> 8 );
	}

	$fh = IO::File->new($tmpname) or die "can't open $tmpname\n";
	$value = '';

	while (<$fh>) {
		$value .= $_;
	}

	$fh->close;

	return $value;
}

###############################################################################
#
# $ok = visudo_check($value)
#
# Writes $value to a temporary file and calls visudo to check it. Dies
# if there are any problems executing visudo, return undef if $value is
# incorrect, 1 if correct
#
###############################################################################

sub visudo_check {
	my $value   = shift;
	my $fh      = File::Temp->new or die "can't open tempfile\n";
	my $tmpname = $fh->filename;
	my $cmd     = "$visudo -csf $tmpname";
	my $output;

	print $fh "$value\n";
	$fh->close;
	$output = `$cmd 2>&1`;

	if ( $? == -1 ) {
		print STDERR $output;
		die "failed to execute $cmd: $!\n";
	}

	elsif ( $? & 127 ) {
		print STDERR $output;
		die "$cmd died with signal %d\n", ( $? & 127 );
	}

	print STDERR $output unless ( $output =~ m|/tmp/\S+ file parsed OK| );

	return ( $? >> 8 ) ? undef : 1;
}

###############################################################################

sub visudo_check_edit {
	my $prepend = shift;
	my $value   = shift;
	my ( $ok, $l );

	do {
		$value = edit_value($value);

		unless ( $ok = visudo_check("$prepend$value") ) {
			do {
				print STDERR "What now: (e)dit or (q)uit? ";
				exit unless ( defined( $l = <STDIN> ) );
				chomp($l);
			} until ( $l eq 'e' || $l eq 'q' );
		}
	} until ( $ok || $l eq 'q' );

	return $ok ? $value : undef;
}

=pod

=back

=head1 EXAMPLES

Create a new default with the parameter ignore_dot:

 s7~:$ ./sudotool.pl --new-default --set ignore_dot

List all defaults to find out the sudo_default_id of the newly created
entry:

 s7~:$ ./sudotool.pl --list-defaults
 12009: ignore_dot

Assign the default with the sudo_default_id 12009 to the mclass
dbreports:

 s7~:$ ./sudotool.pl --default 12009 --add-to --mclass dbreports

Create new command aliases for kill and lsof:

 s7~:$ ./sudotool.pl --new-cmnd-alias KILL --set /bin/kill
 s7~:$ ./sudotool.pl --new-cmnd-alias LSOF --set /usr/local/bin/lsof

Grant users in the dba uclass permissions to run all commands as any
user on all machines in the dbreports mclass:

 s7~:$ ./sudotool.pl --cmnd-alias ALL --uclass dba --add-to --mclass dbreports --run-as-uclass ALL

Grant the user bjech permissions to run the kill command as root on
all machines in the dbreports mclass:

 s7~:$ ./sudotool.pl --cmnd-alias KILL --user bjech --add-to --mclass dbreports --run-as-user root

Grant the user swm permissions to run the lsof command as oracle on
all machines in the dbreports mclass:

 s7~:$ ./sudotool.pl --cmnd-alias LSOF --uclass swm --add-to --mclass dbreports --run-as-user oracle --nopasswd

Check whether sudoers file generation is enabled for the mclass dbreports:

 s7~:$ ./sudotool.pl --show-dep --mclass dbreports | grep enabled | uniq
 generation enabled: Y

Show the mclasses where DBAs have full sudo:

 s7~:$ ./sudotool.pl --show-dep --uclass dba --cmnd-alias ALL --run-as-user ALL | grep mclass
 mclass: asterisk-servers
 mclass: dbreports

Show how the sudoers file for the dbreports mclass looks like:

 s7~:$ ./sudotool.pl --show-sudoers --mclass dbreports
 # Do not edit this file, it is generated automatically. All changes
 # made by hand will be lost. For assistance with changes to this
 # file please contact nobody@example.com
 # Generated on Wed Aug 22 19:18:57 2007 by sudotool.pl
 # Sudoers.pm $Revision$

 # Defaults specification

 Defaults ignore_dot

 # Cmnd alias specification

 Cmnd_Alias KILL = /bin/kill
 Cmnd_Alias LSOF = /usr/local/bin/lsof

 # User alias specification

 User_Alias UCLASS_36_DBA = bjech, cbowman, dvvedenskiy, gsievers,\
        jmark, kovert, mabdulrasheed, mcross, mdr, mslawinski, mvanwinkle,\
        rbuda, sramirez, syelimeli, vkrishnamurthy

 # User privilege specification

 UCLASS_36_DBA ALL = (ALL) ALL
 bjech ALL = (root) KILL
 swm ALL = (oracle) NOPASSWD:LSOF

=head1 SEE ALSO

sudo(8), sudoers(5), mclasstool(1), uclasstool(1)

=head1 AUTHOR

Bernard Jech
