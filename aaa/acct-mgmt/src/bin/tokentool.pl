#!/usr/local/bin/perl -w
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

#
# $Id$
#

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
use DBI;
use Getopt::Long qw(:config no_ignore_case bundling);
use JazzHands::Management qw(:DEFAULT);
use Pod::Usage;

#=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
#
# die because of a problem with the DBI module.  Print the error message
# from the oracle module.
#
sub dbdie {
	if (DBI::errstr) {
		die "DB Problem: "
		  . join( " ", @_ ) . ": "
		  . DBI::errstr . "\n";
	} else {
		die join( " ", @_ ) . "\n";
	}
}

my $help    = 0;
my $force   = 0;
my $list    = 0;
my $verbose = 0;

# Process options.  '-l/--list' are given for compatibility with other *tool
# tools.

GetOptions(
	'help|h'    => \$help,
	'force|f'   => \$force,
	'verbose|v' => \$verbose,
	'list|l'    => \$list,
);

if ($help) {
	pod2usage(
		-exitval => -1,
		-verbose => 2
	);
}

my $dbh;
if ( !( $dbh = JazzHands::Management->new( application => 'tokenmgmt' ) ) ) {
	print STDERR "Unable to open connection to JazzHands\n";
	exit -1;
}

my $command = shift;
if ( !$command && !$list ) {
	print STDERR "Command must be given.\n";
	print STDERR "Usage: $0 command ...\n";
	print STDERR "Run '$0 --help' for more information\n";
	exit -1;
}

if ( $list || ( $command && $command eq 'list' ) ) {
	my %validlisttypes = (
		"enabled"    => 1,
		"disabled"   => 1,
		"lost"       => 1,
		"stolen"     => 1,
		"destroyed"  => 1,
		"assigned"   => 1,
		"unassigned" => 1,
		"pinset"     => 1,
		"pinunset"   => 1,
		"locked"     => 1,
		"unlocked"   => 1,
	);

	my $target;
	my @types;
	my $serial;
	my $tokenid;
	my $login;

	while ( $target = shift ) {
		if ( $validlisttypes{$target} ) {
			push @types, $target;
			next;
		}
		if ( $target eq "user" || $target eq "login" ) {
			$login = shift;
			if ( !$login ) {
				print STDERR "Usage: $0 list $target <login>\n";
				exit -1;
			}
			next;
		}

		# If we've started going through types of tokens to list, then
		# everything needs to be a token type
		if (@types) {
			print STDERR
			  "Error: $target is not a valid list parameter.\n";
			print STDERR "Choose from: ",
			  ( join( ",", keys %validlisttypes ) ), "\n";
			exit -1;
		}
		if ( $target eq "tokenid" ) {
			$tokenid = shift;
			if ( !$tokenid ) {
				print STDERR
				  "Usage: $0 list tokenid <tokenid>\n";
				exit -1;
			}
			last;
		}
		if ( $target eq "token" ) {
			$serial = shift;
			if ( !$serial ) {
				print STDERR "Usage: $0 list token <serial>\n";
				exit -1;
			}
			last;
		}
		$serial = $target;
	}

	# If we didn't get a specific serial or tokenid...
	if ( !$serial && !$tokenid ) {
		my $tokenlist;
		my @args;
		if (@types) {
			push @args, types => \@types;
		}
		if ($login) {
			push @args, login => $login;
		}
		$tokenlist = $dbh->GetTokens(@args);
		if ($tokenlist) {
			my @displaylist;
			if ($tokenid) {
				@displaylist =
				  sort { $a->{token_id} <=> $b->{token_id} }
				  @$tokenlist;
			} else {
				@displaylist =
				  sort { $a->{serial} cmp $b->{serial} }
				  @$tokenlist;
			}
			foreach my $token (@displaylist) {
				$token->dump( brief => 1 );
			}
		}
		exit;
	} else {
		my $token;
		if ($tokenid) {
			$token = $dbh->GetToken( token_id => $tokenid );
			if ( !$token ) {
				printf STDERR "No token with tokenid %s\n",
				  $tokenid;
				exit 1;
			}
		} else {
			$token = $dbh->GetToken( serial => $serial );
			if ( !$token ) {
				printf STDERR "No token with serial %s\n",
				  $serial;
				exit 1;
			}
		}
		$token->dump;
	}
	exit 0;
} elsif ( $command eq 'assign' ) {
	my $token = shift;
	my $by_id = 0;

	if ( $token eq 'token' ) {
		$token = shift;
	}
	if ( $token eq 'id' ) {
		$by_id = 1;
		$token = shift;
	} elsif ( $token eq 'serial' ) {
		$token = shift;
	}

	if ( !defined($token) ) {
		print STDERR "Token not specified in token assignment\n";
		exit 1;
	}

	my $user = shift;
	if ( $user eq 'to' ) {
		$user = shift;
	}
	if ( $user eq 'user' || $user eq 'login' ) {
		$user = shift;
	}

	if ( !$user ) {
		print STDERR "User not specified in token assignment\n";
		exit 1;
	}

	my $replacecmd = shift;
	my $replace;
	my $replace_id = 0;
	my $replacestatus;
	if ($replacecmd) {
		$replacestatus = shift;
		$replace       = shift;

		if ( $replace && $replace eq 'token' ) {
			$replace = shift;
		}
		if ( $replace && $replace eq 'id' ) {
			$replace_id = 1;
			$replace    = shift;
		} elsif ( $replace && $replace eq 'serial' ) {
			$replace = shift;
		}

		if (       $replacecmd ne "replacing"
			|| !$replace
			|| !$replacestatus )
		{
			print STDERR
			  "Syntax for replacement token is '... replacing ";
			print STDERR "<status> <tokenspec>'\n";
			exit 1;
		}
	}

	my @parms = (
		( $by_id ? "token_id" : "serial" ) => $token,
		login => $user
	);
	if ($replacecmd) {
		push @parms,
		  (
			( $replace_id ? "replace_id" : "replace" ) => $replace,
			replace_status => $replacestatus
		  );
	}
	my $ret = $dbh->AssignToken(@parms);

	if ($ret) {
		print STDERR "Unable to assign token: $ret\n";
	} else {
		print "Token assigned.\n";
	}
	exit;
} elsif ( $command eq 'unassign' ) {
	my $token = shift;
	my $by_id = 0;

	if ( $token eq 'token' ) {
		$token = shift;
	}
	if ( $token eq 'id' ) {
		$by_id = 1;
		$token = shift;
	} elsif ( $token eq 'serial' ) {
		$token = shift;
	}

	if ( !defined($token) ) {
		print STDERR "Token not specified in token assignment\n";
		exit 1;
	}

	my $user = shift;
	if ($user) {
		if ( $user eq 'from' ) {
			$user = shift;
		}

		if ( $user eq 'user' || $user eq 'login' ) {
			$user = shift;
		}

		if ( !$user ) {
			print STDERR "User not specified\n";
			exit 1;
		}
	}

	my @parms = ( ( $by_id ? "token_id" : "serial" ) => $token );
	if ($user) {
		push @parms, login => $user;
	}
	my $ret = $dbh->UnassignToken(@parms);

	if ($ret) {
		print STDERR "Unable to unassign token: $ret\n";
	} else {
		print "Token unassigned.\n";
	}
	exit;
} elsif ( $command eq 'setstatus' ) {
	my $token = shift;
	my $by_id = 0;

	if ( $token eq 'token' ) {
		$token = shift;
	}
	if ( $token eq 'id' || $token eq 'tokenid' ) {
		$by_id = 1;
		$token = shift;
	} elsif ( $token eq 'serial' ) {
		$token = shift;
	}

	if ( !defined($token) ) {
		print STDERR "Token not specified in token assignment\n";
		exit 1;
	}

	my $status = shift;
	if ( !$status ) {
		print STDERR "Status not specified\n";
		exit 1;
	}

	my $tokenobj;
	if ($by_id) {
		$tokenobj = $dbh->GetToken( token_id => $token );
		if ( !$tokenobj ) {
			printf STDERR "No token with tokenid %s\n", $token;
			exit 1;
		}
	} else {
		$tokenobj = $dbh->GetToken( serial => $token );
		if ( !$token ) {
			printf STDERR "No token with serial %s\n", $token;
			exit 1;
		}
	}

	my $ret = $dbh->SetTokenStatus(
		token_id => $tokenobj->{token_id},
		status   => uc($status)
	);

	if ($ret) {
		print STDERR "Unable to set token status: $ret\n";
	} else {
		print "Token status set to $status.\n";
	}
	exit;
} elsif ( $command eq 'reset' ) {
	my $token = shift;
	my $by_id = 0;

	if ( $token eq 'pin' ) {
		$token = shift;
		if ( $token eq 'for' ) {
			$token = shift;
		}
	}

	if ( $token eq 'token' ) {
		$token = shift;
	}
	if ( $token eq 'id' ) {
		$by_id = 1;
		$token = shift;
	} elsif ( $token eq 'serial' ) {
		$token = shift;
	}

	if ( !defined($token) ) {
		print STDERR "Token to reset not specified\n";
		exit 1;
	}

	my @parms = ( ( $by_id ? "token_id" : "serial" ) => $token );
	my $ret = $dbh->ResetTokenPIN(@parms);

	if ($ret) {
		print STDERR "Unable to reset token PIN: $ret\n";
	} else {
		print "Token PIN reset.\n";
	}
	exit;
} elsif ( $command eq 'unlock' ) {
	my $token = shift;
	my $by_id = 0;

	if ( $token eq 'token' ) {
		$token = shift;
	}
	if ( $token eq 'id' ) {
		$by_id = 1;
		$token = shift;
	} elsif ( $token eq 'serial' ) {
		$token = shift;
	}

	if ( !defined($token) ) {
		print STDERR "Token to unlock not specified\n";
		exit 1;
	}

	my @parms = ( ( $by_id ? "token_id" : "serial" ) => $token );
	my $ret = $dbh->UnlockToken(@parms);

	if ($ret) {
		print STDERR "Unable to unlock token: $ret\n";
	} else {
		print "Token unlocked.\n";
	}
	exit;
} else {
	print STDERR "ERROR: $command is not a valid command\n";
	print STDERR "Run '$0 --help' for more information\n";
	exit -1;
}

undef $dbh;

exit 0;

__END__;

=head1 tokentool

tokentool -- manage tokens and token assignments

=head1 SYNOPSIS

tokentool I<command> [ I<arguments> ]

=head1 DESCRIPTION

tokentool is used to manage one-time password tokens and their assignments
to users.

tokentool can perform any of the following tasks:

=over 4

=item viewing information about a token or its assignments

=item assigning a token to or unassigning a token from a user

=item resetting the PIN for a token

=item unlocking a locked-out token

=back

=head1 TOKEN SPECIFICATION

In all of the commands below, B<E<lt>tokenspecE<gt>> is defined as the following:

=over 4

=item [B<token>] [B<serial>] I<serial>

specify a token by serial number.  Both B<token> and B<serial> are optional,
and one or both of them may be omitted, so all of the following are
equivalent:

=over 4

=item B<token serial ALNG00116EFF>

=item B<token ALNG00116EFF>

=item B<serial ALNG00116EFF>

=item B<ALNG00116EFF>

=back

=item [B<token>] B<tokenid> I<tokenid>

specify a token by serial internal ID.  B<token> is optional.  B<tokenid>
must be specified.  Both of the following are equivalent:

=over 4

=item B<token tokenid 1924>

=item B<tokenid 1924>

=back

=back

=head1 LISTING COMMANDS

=over 4

=item S<B<list> [B<disabled>] [B<lost>] [B<destroyed>] [B<stolen>] [B<enabled>] [B<assigned>] [B<unassigned>] [B<locked>] [B<unlocked>] [B<pinset>] [B<pinunset>]>

list all tokens.  This will will give a tabular list of the following
information: internal tokenid, serial number, token status (B<E>-Enabled, 
B<D>-Disabled, B<L>-Lost, B<X>-Destroyed), PIN status, ('+' if set), 
lock status ('*' if locked), and owner.

=item B<list> B<E<lt>tokenspecE<gt>>

list details for token specified by B<E<lt>tokenspecE<gt>>

=item B<list user> I<login>

show tokens assigned to user I<login>

=back

=head1 ASSIGNMENT COMMANDS

=over 4

=item S<B<assign> B<E<lt>tokenspecE<gt>> [B<to>] [B<user|login>] I<login>>

assign a token specified by B<E<lt>tokenspecE<gt>> to user I<login>.  If
the token is already assigned to another user, this command will fail.

=item S<B<assign> B<E<lt>tokenspecE<gt>> [B<to>] [B<user|login>] I<login> B<replacing> I<status> B<E<lt>tokenspecE<gt>>>

assigns a token specified by the first B<E<lt>tokenspecE<gt>> to user I<login>,
copying PIN data from the old token, and marking the token specified by
the second B<E<lt>tokenspecE<gt>> as having status I<status>.  Typically,
I<status> should be one of 'lost', 'destroyed', or 'stolen' if
a user is being assigned a replacement token, but any status value allowed
by the B<status> command below is permissible.  If the new token is
already assigned to another user or if the old token is not currently
assigned to this user, this command will fail.

=item S<B<unassign> B<E<lt>tokenspecE<gt>> [[B<from>] [B<user|login>] I<login>]>

unassign a token with serial I<serial>.  If the I<login> is not given, this
completely unassigns a token.  If I<login> is a pseudouser, then the token
is unassigned from just that pseudouser.  It is an error to remove the token
from the primary user (i.e. non-pseudouser) without removing it from all
pseudousers which the token may also be associated with.

=item S<B<reset> [B<pin>] [B<for>] B<E<lt>tokenspecE<gt>>>

Reset the PIN for a token specified by B<E<lt>tokenspecE<gt>>.

=item S<B<setstatus> B<E<lt>tokenspecE<gt>>> I<status>

Set the status of the token specified to I<status>.  Valid statuses are
B<enabled>, B<disabled>, B<lost>, B<stolen>, and B<destroyed>.  A token will
not authenticate a user unless it has a status of B<enabled>.

=back

=head1 RETURN VALUE

0 on success, 1 on failure

=head1 EXAMPLES

=over 4

=item B<tokentool list token ALNG12345678>

show details on the token with serial number ALNG12345678

=item B<tokentool list user joebob>

show details on the token(s) assigned to user jimbob

=item B<tokentool assign ALNG12345678 to jimbob>

assigns token with serial number ALNG12345678 to jimbob

=item B<tokentool assign ALNG12345678 to jimbob replacing lost ALNG98765432>

assigns token with serial number ALNG12345678 to jimbob, copying the PIN
information from token with serial number ALNG98765432 and setting its
status to 'lost'.

=item B<tokentool reset ALNG12345678>

resets the PIN for token with serial number ALNG12345678 to allow the
user to choose a new one.

=head1 SEE ALSO

L<mclasstool(8)>, L<uclasstool(8)>, L<depttool(8)>, L<grouptool(8)>, L<usertool(8)>,

=cut
