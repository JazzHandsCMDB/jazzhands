#!/usr/bin/env perl
#
# Copyright (c) 2016, Todd M. Kover
# All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

use strict;
use warnings;
use JazzHands::DBI;
use Data::Dumper;
use Getopt::Long;
use JSON::PP;
use Pod::Usage;
use FileHandle;

#use Carp;
#
#local $SIG{__WARN__} = \&Carp::cluck;

###############################################################################

package	DBThing;
use strict;
use warnings;
use JazzHands::Common qw(:all);
use Data::Dumper;
use Carp;

use parent 'JazzHands::Common';

our $errstr;

sub errstr {
	return ($errstr);
}

sub begin_work {
	my $self = shift;

	$self->{_dbh}->begin_work(@_);
}

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $opt   = &_options;

	my $service = $opt->{service};
	if ( !$service ) {
		$errstr = "Must specify db service to connect to";
		return undef;
	}

	my $dbh =
	  JazzHands::DBI->connect( $service, { AutoCommit => 0, RaiseError => 1 } );
	if ( !$dbh ) {
		$errstr = "Unable to connect to $service: " . $JazzHands::DBI::errstr;
		return undef;
	}

	my $self = $class->SUPER::new(@_);

	#my $self = {};
	#bless($self, $class );

	$self->{_schemachanges} = 0;

	$self->{_dbh} = $dbh;
	$self;
}

sub DESTROY {
	my $self = shift @_;

	$self->rollback;
	$self->disconnect;
}

sub fetch_table($$$) {
	my ( $self, $table, $pk ) = @_;

	my $dbh = $self->DBHandle();

	my $pkstr = "";
	if ( !defined($pk) ) {

		# required because the return hash is sorted on this
		return undef;
	} elsif ( ref($pk) eq 'ARRAY' ) {
		$pkstr = join( ",", @{$pk} );
	} else {
		$pkstr = $pk;
	}

	my $sth = $dbh->prepare_cached(
		qq{
		SELECT	*
		FROM	$table
		ORDER BY $pkstr
	}
	) || die dbh->errstr;

	$sth->execute || die $sth->{Statement}, ":", $sth->errstr;

	my $rv = {};
	while ( my $hr = $sth->fetchrow_hashref ) {
		my $k;
		if ( ref($pk) eq 'ARRAY' ) {
			$k = join( ",",
				map { ( defined( $hr->{$_} ) ) ? $hr->{$_} : "" } @{$pk} );
		} else {
			$k = $hr->{$pk};
		}

		$rv->{$k} = $hr;
	}
	$rv;
}

sub push_and_refetch {
	my $self = shift @_;
	my $opt  = &_options;

	my $dbh = $self->DBHandle();

	foreach my $sql ( $opt->{sql} ) {
		my @cols;
		foreach my $col ( keys( %{ $opt->{myrow} } ) ) {
			if ( $sql =~ s/%\{$col\}/:$col/g ) {
				push( @cols, $col );
			}
		}
		my $sth = $dbh->prepare_cached($sql);
		foreach my $col (@cols) {
			$sth->bind_param( ":$col", $opt->{myrow}->{$col} )
			  || die $sth->errstr;
		}
		$sth->execute || die $sth->errstr;
		$sth->finish;
	}

	my $match = {};
	for ( my $i = 0 ; $i <= $#{ $opt->{dbkey} } ; $i++ ) {
		$match->{ $opt->{dbkey}->[$i] } = $opt->{keyval}->[$i];
	}
	$self->DBFetch(
		table           => $opt->{table},
		match           => $match,
		result_set_size => 'exactlyone',
	);
}

sub get_cols {
	my ( $self, $table ) = @_;

	my $dbh = $self->DBHandle();

	my (@rv);
	foreach my $schema ( $self->get_search_path() ) {
		my $sth = $dbh->column_info( undef, $schema, $table, '%' )
		  || die $dbh->errstr;

		my $found;
		while ( my $hr = $sth->fetchrow_hashref() ) {
			next if ( $hr->{'TABLE_NAME'} ne $table );
			$found = 1;
			push(
				@rv,
				{
					'colname' => $hr->{'COLUMN_NAME'},
					'coltype' => $hr->{'TYPE_NAME'}
				}
			);
		}
		last if ($found);
	}
	@rv;
}

sub get_search_path($) {
	my ($self) = @_;
	my $dbh = $self->DBHandle();

	my @search;
	if ( $dbh->{Driver}->{Name} eq 'Pg' ) {
		my $sth = $dbh->prepare("show search_path") || die $dbh->errstr;
		$sth->execute || die $sth->errstr;
		while ( my ($e) = $sth->fetchrow_array ) {
			foreach my $s ( split( /,/, $e ) ) {
				push( @search, $s );
			}
		}
	} elsif ( $dbh->{Driver}->{Name} eq 'SQLite' ) {
		push( @search, 'main' );
	} else {
		push( @search, undef );
	}
	@search;
}

sub get_primary_key {
	my ( $self, $table ) = @_;
	my $dbh = $self->DBHandle();

	my (@rv);
	foreach my $schema ( $self->get_search_path() ) {
		my $sth = $dbh->primary_key_info( undef, $schema, $table ) || next;

		my $found;
		while ( my $hr = $sth->fetchrow_hashref ) {
			push( @rv, $hr->{COLUMN_NAME} );
		}
	}
	if ( $#rv == 0 ) {
		return $rv[0];
	}
	@rv;
}

sub table_identical {
	my ( $self, $fromh, $table ) = @_;

	my $up   = $self->DBHandle();
	my $down = $fromh->DBHandle();

	my $sth = $down->table_info( undef, 'main', $table );

	my @upcols = $self->get_cols($table);
	my @dncols = $fromh->get_cols($table);

	if ( $#upcols != $#dncols ) {
		return 0;
	}

	for ( my $i = 0 ; $i < $#upcols ; $i++ ) {
		if ( $upcols[$i]->{'colname'} ne $dncols[$i]->{'colname'} ) {
			$self->_Debug(
				4,
				"colname mismatch on ",
				Dumper( $upcols[$i], $dncols[$i] )
			);
			return 0;
		}
		if ( $upcols[$i]->{'coltype'} ne $dncols[$i]->{'coltype'} ) {
			$self->_Debug(
				4,
				"coltype mismatch on ",
				Dumper( $upcols[$i], $dncols[$i] )
			);
			return 0;
		}
	}
	return 1;
}

sub table_exists {
	my ( $self, $table ) = @_;

	my $dbh = $self->DBHandle();
	foreach my $schema ( $self->get_search_path() ) {
		my $sth = $dbh->table_info( undef, $schema, $table );

		while ( my $hr = $sth->fetchrow_hashref ) {
			if ( $hr->{TABLE_NAME} eq $table ) {
				return 1;
			}
		}
	}
	return 0;
}

sub drop_table {
	my ( $self, $table ) = @_;

	$self->DBHandle()->do("drop table $table") || die $self->DBHandle()->errstr;
}

sub mktable {
	my ( $self, $fromh, $table ) = @_;

	$self->{_schemachanges}++;

	my $old = $fromh->DBHandle();
	my $new = $self->DBHandle();

	my @cols = $fromh->get_cols($table);

	my @pk = $fromh->get_primary_key($table);

	my $pkstr = "";
	if ( $#pk >= 0 ) {
		$pkstr = join( " ", ", PRIMARY KEY (", join( ",", @pk ), ")" );
	}

	my $q =
	    qq{CREATE TABLE $table (\n\t }
	  . join( ",\n\t", map { join( " ", $_->{colname}, $_->{coltype} ) } @cols )
	  . $pkstr . ")";

	my $sth = $new->prepare(
		qq{
		$q;
	}
	) || die "$q: ", $new->errstr;
	$sth->execute || die $sth->{Statement}, ":", $sth->errstr;
}

#
# copies a table identified as $table from $fromh into $self.
#
# $pk is only needed if it can not be discerned (such as views)
#
sub copy_table($$$;$) {
	my ( $self, $fromh, $table, $tbcfg ) = @_;

	# my $down = $self->DBHandle();
	# my $up = $fromh->DBHandle();

	my $pk;
	if ( $tbcfg && exists( $tbcfg->{pk} ) ) {
		$pk = $tbcfg->{pk};
	}

	$self->_Debug( 2, "Copying table %s", $table );
	#
	# Arguably, this can all be smarter about transactions, since the
	# current approach blocks the db for the entire sync cycle on
	# impacted rows.
	if ( !$self->table_identical( $fromh, $table ) ) {
		if ( $self->table_exists($table) ) {
			$self->drop_table($table);
			$self->_Debug( 3, "Table structure mismatch, dropping %s", $table );
		}
		$self->_Debug( 2, "Creating table %s", $table );
		$self->mktable( $fromh, $table );
	}

	if ( !$pk ) {
		my @pk;
		@pk = $fromh->get_primary_key($table);
		$pk = \@pk;
	}

	#
	# needs to handle multi-column pks
	#
	my $fromt = $fromh->fetch_table( $table, $pk );
	my $downt = $self->fetch_table( $table, $pk );

	#
	# go through everything upstream and make sure everything downstream is there
	#
	my ( $ins, $upd, $del ) = ( 0, 0, 0 );
	foreach my $k ( keys %{$fromt} ) {
		my $dbk = $k;
		if ( ref($pk) eq 'ARRAY' ) {
			$dbk = join( ",",
				map { ( defined( $fromt->{$_} ) ) ? $fromt->{$_} : "" }
				  @{$pk} );
		}
		if ( !defined( $downt->{$k} ) ) {
			$ins++;
			if (
				!(
					$self->DBInsert(
						table => $table,
						hash  => $fromt->{$k},
					)
				)
			  )
			{
				die join( " ", $self->Error() );
			}
		} else {
			my $diff = $self->hash_table_diff( $downt->{$k}, $fromt->{$k} );

			my $dbkey = $k;
			if ( scalar keys %{$diff} ) {
				if ( ref $pk eq 'ARRAY' ) {
					my @dbkey = split( /,/, $dbkey );
					$dbkey = \@dbkey;
				}

				# this happens if one of the keys is NULL.  Should probably be
				# rethink
				if ( $#{$dbkey} > $#{$pk} ) {
					warn sprintf
					  "dbkey is too big for %s, skipping (%s vs %s) [%d vs %d]\n",
					  $k, join( ",", @{$dbkey} ),
					  join( ",", @{$pk} ),
					  scalar $dbkey, scalar $pk;
				} elsif ( $#{$dbkey} < $#{$pk} ) {
					for ( my $i = $#{$dbkey} ; $i < $#{$pk} ; $i++ ) {
						push( @{$dbkey}, undef );
					}
				}

				if ( $tbcfg->{pushback} ) {
					foreach my $col ( keys(%$diff) ) {
						if (
							grep( $_ eq $col, keys( %{ $tbcfg->{pushback} } ) )
						  )
						{
							$fromt->{$k} = $fromh->push_and_refetch(
								sql      => $tbcfg->{pushback}->{$col},
								table    => $table,
								dbkey    => $pk,
								keyval   => $dbkey,
								myrow    => $downt->{$k},
								theirrow => $fromt->{$k},
							);
						}
					}
				}
				$diff = $self->hash_table_diff( $downt->{$k}, $fromt->{$k} );
			}

			# The previous check may have made things in sync, and thus
			# nothing to update.
			if ( scalar keys %{$diff} ) {
				$upd++;
				if (
					!(
						$self->DBUpdate(
							table  => $table,
							dbkey  => $pk,
							keyval => $dbkey,
							hash   => $diff,
						)
					)
				  )
				{
					die join( " ", $self->Error() );
				}
			}
		}
	}

	#
	# go through everything downstream and make sure its upstream, or purge
	#
	foreach my $k ( keys %{$downt} ) {
		if ( !defined( $fromt->{$k} ) ) {
			$del++;
			my $dbkey = $k;
			if ( ref $pk eq 'ARRAY' ) {
				my @dbkey = split( /,/, $dbkey );
				$dbkey = \@dbkey;
			}

			# this happens if one of the keys is NULL.  Should probably be
			# rethink
			if ( $#{$dbkey} > $#{$pk} ) {
				warn sprintf
				  "dbkey is too big for %s, skipping (%s vs %s) [%d vs %d]\n",
				  $k, join( ",", @{$dbkey} ),
				  join( ",", @{$pk} ),
				  scalar $dbkey, scalar $pk;
			} elsif ( $#{$dbkey} < $#{$pk} ) {
				for ( my $i = $#{$dbkey} ; $i < $#{$pk} ; $i++ ) {
					push( @{$dbkey}, undef );
				}
			}

			if (
				!(
					$self->DBDelete(
						table  => $table,
						dbkey  => $pk,
						keyval => $dbkey,
					)
				)
			  )
			{
				die join( " ", $self->Error() );
			}
		}
	}
	$self->_Debug( 1, "\tStats: %d inserted; %d updated; %d deleted",
		$ins, $upd, $del );

}

sub sync_dbs {
	my $self     = shift @_;
	my $config   = shift @_;
	my $upstream = shift @_;

	my @tables = @_;

	my $tablemap = $config->{tablemap};
	foreach my $table ( sort keys( %{$tablemap} ) ) {
		next if ( @tables && !grep( $_ eq $table, @tables ) );
		$self->_Debug( 1, "Synchronizing table %s", $table );
		$self->copy_table( $upstream, $table, $tablemap->{$table} );
	}

	if ( $config->{postsyn} ) {
		foreach my $s ( @{ $config->{postsync} } ) {
			$self->_Debug( 5, "Executing sync post '%s'", $s );
			$self->DBHandle->do($s);
		}
	}

	if ( $self->{_schemachanges} ) {
		if ( $config->{postschema} ) {
			foreach my $s ( @{ $config->{postschema} } ) {
				$self->_Debug( 5, "Executing schema post '%s'", $s );
				$self->DBHandle->do($s);
			}
		}
	}

}

###############################################################################

=head1 NAME

table-sync - Keeps a local database in sync with a remote one

=head1 SYNOPSIS

	table-sync [ --no-daemonize ] [ --loop ] [ --debug ... ] --config /path/to/config

=head1 DESCRIPTION

Based on the contents of a config file, use JazzHands::DBI to connect to
a source database and a destination database and sync tables (or views)
based on a JSON config file.

Primary keys are determined if possible, it is also possible to set them,
which is usually necessary for views.

It is also possible to set the sync to run sql on the upstream database
if they are different and re-comparing.  This allows having a locally
updatable copy for some fields.  Any column in the db can be replaced in
the sql (it gets translated to bind parameters which should help with speed),
then the primary key is repulled for another comparision and possible download.

The decision on what to do with the data is handled remotely.

Daemonize is on by default.  When a daemon, the script wakes up every loop
seconds and repeats.  When not a deamon it runs once and exits unless loop
is set. 

When not invoked as a daemon, level one of debugging is turned on. 

This has been tested with sqlite and postgresql.

=head1 EXAMPLE CONFIG
{
	"from": "remote-db",
	"to": "local-db"
	"tablemap": {
		"v_account": {
			"pk": [
				"account_id"
			]
		},
		"account_password": null,
		"v_hotpants_token": {
			"pushback": {
				"token_sequence": "SELECT token_utils.set_sequence(%{token_id},%{token_sequence},%{last_updated});"
			},
			"pk": [
				"token_id"
			]
		},
	},
	"postschema": [
		"grant select on all tables in schema public to hotpants"
	],
	"postsync": [
		"SELECT log_update();"
	],
}

This config connects to remote-db, and local-db and syncs v_account,
account_password and v_hotpants_token.  The primary key is specified for two
of the tables.

In the event that there is a mismatch in v_hotpants_token.token_sequence,
the sql is called (replacing columns with bind variables and binding them)
and the column repulled for sync.

The postschema stanzas are run anytime there is a schema change.

The postsync stanzas are run at the end of every sync.

=head1 BUGS

There liekly are some.

=head1 AUTHORS

Todd Kover

=cut

###############################################################################

package main;

my ( $daemonize, $loop, $cfgname, $debug );

$daemonize = 1;

GetOptions(
	"config=s"   => \$cfgname,
	"daemonize!" => \$daemonize,
	"loop=i"     => \$loop,
	"debug+"     => \$debug,
) || die pod2usage();

die "Must specify config option\n" if ( !$cfgname );

my $fh = new FileHandle($cfgname) || die "$cfgname: $!";
my $config = decode_json( join( "\n", $fh->getlines() ) )
  || die "Unable to parse $cfgname";
$fh->close;

my $up   = new DBThing( service => $config->{from} ) || die $DBThing::errstr;
my $down = new DBThing( service => $config->{to} )   || die $DBThing::errstr;

$up->disconnect;

if ( !defined($debug) && $daemonize ) {
	$debug = 0;
} else {
	$debug = 1;
}
$down->SetDebug($debug);

if ($daemonize) {
	$loop = 300 if ( !$loop );

	$down->daemonize() || die "failed to daemonize";

}

$up = new DBThing( service => $config->{from} ) || die $DBThing::errstr;

do {
	$down->sync_dbs( $config, $up, @ARGV );
	$down->commit || die $down->errstr;
	$up->commit   || die $up->errstr;
	sleep($loop) if ($loop);
} while ($loop);
