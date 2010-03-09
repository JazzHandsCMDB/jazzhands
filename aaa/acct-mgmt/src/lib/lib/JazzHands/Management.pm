
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

package JazzHands::Management;

use 5.008007;
use strict;
use warnings;

my $ErrMsg = undef;

# The following modules are objectified.  The goal is to move all of the modules
# out of the lower list to the upper list and make the tools use the objectified
# modules.

use DBI;
use JazzHands::Management::ApplicationInstance qw(:DEFAULT);
use JazzHands::Management::Application qw(:DEFAULT);
use JazzHands::Management::ConsoleACL qw(:DEFAULT);
use JazzHands::Management::DeviceCollection qw(:DEFAULT);
use JazzHands::Management::ProductionClass qw(:DEFAULT);
use JazzHands::Management::Sudoers qw(:DEFAULT);
use JazzHands::Management::UclassPropertyInstance qw(:DEFAULT);
use JazzHands::Management::UclassProperty qw(:DEFAULT);

#
# The following are the history, non-objectified modules.  Token.pm is
# in a half-done state; it uses objects internally, but it still depends
# on external functions which are non-objectified
#
use JazzHands::Management::Company qw(:DEFAULT);
use JazzHands::Management::Dept qw(:DEFAULT);
use JazzHands::Management::Token qw(:DEFAULT);
use JazzHands::Management::Uclass qw(:DEFAULT);
use JazzHands::Management::User qw(:DEFAULT);
use JazzHands::Management::Vendor qw(:DEFAULT);

use POSIX;

use vars qw($VERSION @EXPORT @ISA);

$VERSION = '1.0.1';    # $Date$

require Exporter;

our @ISA = ("Exporter");
*import = \&Exporter::import;

@EXPORT = qw (
  CheckEligibility
  OpenJHDBConnection
);

sub _options {
	my %ret = @_;
	for my $v ( grep { /^-/ } keys %ret ) {
		$ret{ substr( $v, 1 ) } = $ret{$v};
	}
	\%ret;
}

#
# open a connection to database  default to application 'acctmgt'.
#
#
sub OpenJHDBConnection {
	my $app   = shift;
	my $trace = shift;

	$app = "acctmgt" if ( !$app );

	my $dude = ( getpwuid($<) )[0] || 'unknown';

	my $dbh;
	if ( !( $dbh = JazzHands::DBI->connect($app) ) ) {
		return undef;
	}

	if ($trace) {
		my $q = "ALTER SESSION SET SQL_TRACE = TRUE";
		if ( my $sth = $dbh->prepare($q) ) {
			$sth->execute;
		}
	}

	{
		my $q = qq{
			begin
   				dbms_session.set_identifier ('$dude');
			end;
		};
		if ( my $sth = $dbh->prepare($q) ) {
			$sth->execute;
		}
	}

	$dbh->{PrintError} = 0;
	$dbh->{RaiseError} = 0;

	$dbh;
}

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $opt   = &_options;

	my $self = {};
	$self->{_dbh} =
	  $opt->{application}
	  ? OpenJHDBConnection( $opt->{application} )
	  : OpenJHDBConnection;
	return undef if !$self->{_dbh};
	if ( $opt->{dberrors} ) {
		$self->{_IncludeDBErrors} = 1;
	}

	$self->{_dbh}->{AutoCommit} = 0;
	bless $self, $class;
}

sub copy {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $opt   = &_options;

	return undef if !$proto->{_dbh};
	my $self = {};
	$self->{_dbh}             = $proto->{_dbh};
	$self->{_IncludeDBErrors} = $proto->{_IncludeDBErrors};

	bless $self, $class;
}

sub DBHandle {
	my $self = shift;

	if (@_) { $self->{_dbh} = shift }
	return $self->{_dbh};
}

sub Error {
	my $self = shift;

	if (@_) { $self->{_error} = shift }
	return $self->{_error};
}

sub commit {
	my $self = shift;

	if ( my $dbh = $self->DBHandle ) {
		return $dbh->commit;
	}
}

sub rollback {
	my $self = shift;

	if ( my $dbh = $self->DBHandle ) {
		return $dbh->rollback;
	}
}

sub disconnect {
	my $self = shift;

	if ( my $dbh = $self->DBHandle ) {
		return $dbh->disconnect;
	}
}

sub InitializeCache {
	my $self = shift;

	$self->{_cache} = {};
	return $self->{_cache};
}

sub Cache {
	my $self = shift;

	return $self->{_cache};
}

sub DBErrors {
	my $self = shift;

	if (@_) { $self->{_IncludeDBErrors} = shift }
	return $self->{_IncludeDBErrors};
}

sub DESTROY {
	my $self = shift;

	if ( ref($self) eq "JazzHands::Management" ) {
		if ( $self->{_dbh} ) {
			$self->{_dbh}->disconnect;
		}
	}
}

sub CheckEligibility {
	if ( !getuid() ) {
		print "You may not run this tool as root.\n";
		exit -1;
	}
}

1;
__END__

=head1 NAME

JazzHands::Management - Perl extension for manipulation to the JazzHands database

=head1 SYNOPSIS

  use JazzHands::Management;

=head1 DESCRIPTION

This is used to interface with the JazzHands database.  

=head2 EXPORT

Most of the child modules export into the caller's namespace.

=head1 AUTHORS

	Todd Kover
	Matthew Ragan

=cut

