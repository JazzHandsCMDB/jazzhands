#
# Copyright (c) 2011, 2013 Todd M. Kover
# Copyright (c) 2011, 2012, 2013 Matthew Ragan
# All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

###############################################################################

package JazzHands::Common::GenericDB;

use strict;
use Exporter;
use JazzHands::Common::Util qw(:all);
use JazzHands::Common::Error qw(:internal);
use DBI::Const::GetInfoType;
use Data::Dumper;
use Carp qw(cluck);


our $VERSION   = '1.0';

our @ISA	   = qw(Exporter );

our %EXPORT_TAGS = 
(
        'all' => [qw(
			Connect
			DBUpdate
			DBInsert
			DBDelete
			DBFetch
			DBHandle
			commit
			rollback
			disconnect
		)],
        'legacy' => [qw(
			dbh 
			run_update_from_hash 
		)],
);

Exporter::export_ok_tags('all');
Exporter::export_ok_tags('legacy');

#
# $dbkey and $keyval can either be scalars or arrays.
#
# if arrays, the array membership must match.
#
# table - table_name
# dbkey - scalar or array of column names that make up the tables pk
# keyval - scalar or array of values that describe the primary key.  This will
# 		be what is updated.  Must match dbkey for #elements/scalar
# hash - values on the lhs of the hash are set to the rhs.  hash_table_diff
#	can be used to determine what should be updated.
#
# NOTE NOTE NOTE:  This is deprecated!
sub run_update_from_hash {
	my($dbh, $table, $dbkey, $keyval, $hash) = @_;

	return DBUpdate(undef,
		dbhandle => $dbh,
		table => $table,
		dbkey => $dbkey,
		keyval => $keyval,
		hash => $hash
	);
}

#
# sets up a connection to the db
#
sub Connect {
	my $self = shift;
	my $opt = &_options(@_);

	#
	# This is here because JazzHands::DBI requires Common, which ends up
	# being circular.  Since Nothing is imported back up into the namespace,
	# this is probably ok.
	#
	require JazzHands::DBI;

	my $service = $opt->{service};
	my $svcargs= $opt->{svcargs} || {
			AutoCommit => 0,
			RaiseError => 0,
		};

	my $dbh;
	if (
		!( $dbh = JazzHands::DBI->connect( $service, $svcargs ) ) )
	{
		undef $dbh;
		$errstr = $JazzHands::DBI::errstr;
		return undef;
	}
	$self->DBHandle($dbh);
}


sub DBHandle {
	my $self = shift;

	if (@_) { $self->{_dbh} = shift }
	return $self->{_dbh};
}

sub dbh {
	&DBHandle(@_);
}


sub DBUpdate {
	my $self;
	$self = shift if ($#_ % 2 == 0);
	my $opt = &_options(@_);

	my ($dbh, $table, $dbkey, $keyval, $hash);

	# accept either because STAB uses dbh
	$dbh = $opt->{dbhandle} || $opt->{dbh};

	#
	# this is so the routines can be called outside the OO framework
	#
	my $errsave;
	if($opt->{errors}) {
		$errsave = $opt->{errors};
	} elsif($self) {
		$errsave = \$self->{_errors};
	}

	#
	# Check the object for a valid database handle if one wasn't passed
	#
	if (!$dbh) {
		eval { $dbh = $self->DBHandle };
	}

	if(!$dbh) {
		SetError($errsave,
			"must pass dbhandle parameter to DBUpdate");
		return undef;
	}
	if (!($table = $opt->{table})) {
		SetError($errsave,
			"must pass table parameter to DBUpdate");
		return undef;
	}
	if (!($dbkey = $opt->{dbkey})) {
		SetError($errsave,
			"must pass dbkey parameter to DBUpdate");
		return undef;
	}
	if (!($hash = $opt->{hash})) {
		SetError($errsave,
			"must pass hash parameter to DBUpdate");
		return undef;
	}
	$keyval = $opt->{keyval};

	#
	# first build the query
	#
	my $setq = "";
	my $sofar = "";
	foreach my $key (keys %$hash) {
		$setq .= "$sofar$key = :$key";
		$sofar = ",\n\t";
	}

	if(!length($setq)) {
		return undef;
	}

	my $update_whereclause;
	if(!ref($dbkey)) {
		$update_whereclause = "$dbkey = :pk__$dbkey";
	} elsif(ref($dbkey) eq 'ARRAY') {
		$update_whereclause = "";
		if( (scalar @$dbkey) != (scalar @$keyval) ) {
			SetError($$errsave,
				"DBUpdate: must be same number of values as keys");
			return undef;
		}
		for(my $i=0 ; $i < (scalar @$dbkey); $i++) {
			if(length($update_whereclause)) {
				$update_whereclause .= " and ";
			}
			$update_whereclause .= $$dbkey[$i] . " IS NOT DISTINCT FROM :pk__".$$dbkey[$i];
		}
	} else {
		foreach my $key (keys %$dbkey) {
			if(length($update_whereclause)) {
				$update_whereclause .= " and ";
			}
			$update_whereclause .= $key . " IS NOT DISTINCT FROM :pk__".$key;
		}
	}
	my $q = qq{
		update $table
		   set $setq
		 where $update_whereclause
	};

	my $sth;
	if (!($sth = $dbh->prepare_cached($q))) {
		SetError($$errsave,
			sprintf("DBUpdate: Error preparing database statement %s",
				$dbh->errstr));
		return undef;
	}


	#
	# bind variables
	#
	if(!ref($dbkey)) {
		if (!($sth->bind_param(":pk__$dbkey", $keyval))) {
			SetError($$errsave, 
				sprinf("DBUpdate: Unable to bind key for %s: %s",
					$dbkey, $sth->errstr));
			return undef;
		}
	} elsif(ref($dbkey) eq 'ARRAY') {
		# sanity checking was done above.
		for(my $i=0 ; $i < (scalar @$dbkey); $i++) {
			my $tkey = $$dbkey[$i];
			my $tval = $$keyval[$i];
			if (!($sth->bind_param(":pk__$tkey", $tval))) {
				SetError($$errsave, 
					sprintf("DBUpdate: Unable to bind key for %s: %s",
						$tkey, $sth->errstr));
				return undef;
			}
		}
	} else {
		foreach my $key (keys %$dbkey) {
			if (!($sth->bind_param(":pk__".$key, $dbkey->{$key}))) {
				SetError($$errsave, 
					sprintf("DBUpdate: Unable to bind key for %s: %s",
						$key, $sth->errstr));
				return undef;
			}
		}
	}
	foreach my $key (keys %$hash) {
		if (!($sth->bind_param(":$key", $hash->{$key}))) {
			SetError($$errsave, 
				sprintf("DBUpdate: Unable to bind value for %s: %s",
					$key, $sth->errstr));
			return undef;
		}
	}
	my $ret;
	if (!($ret = $sth->execute)) {
		SetError($$errsave, 
			sprintf("DBUpdate: Error executing update: %s",
				$sth->errstr));
		return undef;
	}
	$sth->finish;
	$ret;
}

sub DBInsert {
	my $self;
	$self = shift if ($#_ % 2 == 0);
	my $opt = &_options(@_);

	my ($dbh, $table, $hash);

	# accept either because STAB uses dbh
	$dbh = $opt->{dbhandle} || $opt->{dbh};

	my $errsave;
	if($opt->{errors}) {
		$errsave = $opt->{errors};
	} elsif($self) {
		$errsave = $self->{_errors};
	}

	#
	# Check the object for a valid database handle if one wasn't passed
	#
	if (!$dbh) {
		eval { $dbh = $self->DBHandle };
	}

	if(!$dbh) {
		SetError($errsave,
			"must pass dbhandle parameter to DBInsert");
		return undef;
	}
	if (!($table = $opt->{table})) {
		SetError($errsave,
			"must pass table parameter to DBInsert");
		return undef;
	}
	if (!($hash = $opt->{hash})) {
		SetError($errsave,
			"must pass hash parameter to DBInsert");
		return undef;
	}

	my %qtemplate = (
		'PostgreSQL' => q {
			WITH ins AS (
				INSERT INTO %s (%s) VALUES (%s) RETURNING *
			) SELECT * FROM ins
		},
		'default' => q {
			INSERT INTO %s (%s) VALUES (%s)
		},
	);
	my $dbtype = $dbh->get_info($GetInfoType{SQL_DBMS_NAME});

	my $q = sprintf(
		($qtemplate{$dbtype} || $qtemplate{default}),
		$opt->{table},
		(join ', ', keys %{$hash}),
		(join ', ', map { ':' . $_ } keys %{$hash})
		);

    my $sth; 
    if (!($sth = $dbh->prepare_cached($q))) { 
        SetError($errsave,
            sprintf("DBInsert: Error preparing database statement %s",
				$dbh->errstr));
        return undef;
    }
	foreach my $key (keys %$hash) {
		if (!($sth->bind_param(":$key", $hash->{$key}))) {
			SetError($errsave, 
				sprintf("DBInsert: Unable to bind value for %s: %s",
					$key, $sth->errstr));
			return undef;
		}
	}
	my $ret;
	if (!($ret = $sth->execute)) {
		SetError($errsave, 
			sprintf("DBInsert: Error executing insert: %s",
				$sth->errstr));
		return undef;
	}

	#
	#  This needs to be changed to support other databases correctly
	#
	if ($dbtype eq 'PostgreSQL') {
		my $row = $sth->fetchrow_hashref;

		foreach my $key (keys %$row) {
			$hash->{$key} = $row->{$key}
		}
	}
	$sth->finish;
	$ret;
}

sub DBDelete {
	my $self;
	$self = shift if ($#_ % 2 == 0);
	my $opt = &_options(@_);

	my ($dbh, $table, $dbkey, $keyval, $hash);

	# accept either because STAB uses dbh
	$dbh = $opt->{dbhandle} || $opt->{dbh};

	#
	# this is so the routines can be called outside the OO framework
	#
	my $errsave;
	if($opt->{errors}) {
		$errsave = $opt->{errors};
	} elsif($self) {
		$errsave = \$self->{_errors};
	}

	#
	# Check the object for a valid database handle if one wasn't passed
	#
	if (!$dbh) {
		eval { $dbh = $self->DBHandle };
	}
	if(!$dbh) {
		SetError($errsave,
			"must pass dbhandle parameter to DBDelete");
		return undef;
	}
	if (!($table = $opt->{table})) {
		SetError($errsave,
			"must pass table parameter to DBDelete");
		return undef;
	}
	if (!($dbkey = $opt->{dbkey})) {
		SetError($errsave,
			"must pass dbkey parameter to DBDelete");
		return undef;
	}
	$keyval = $opt->{keyval};

	#
	# first build the query
	#

	my $update_whereclause;
	my $multikey = 0;
	if(!ref($dbkey)) {
		$update_whereclause = "$dbkey = :pk__$dbkey";
	} elsif(ref($dbkey) eq 'ARRAY') {
		$update_whereclause = "";
		if( (scalar @$dbkey) != (scalar @$keyval) ) {
			SetError($errsave,
				"DBDelete: must be same number of values as keys");
			return undef;
		}
		for(my $i=0 ; $i < (scalar @$dbkey); $i++) {
			if(length($update_whereclause)) {
				$update_whereclause .= " and ";
			}
			if (ref($keyval->[$i]) eq 'ARRAY') {
				$update_whereclause .= $$dbkey[$i] . "= ANY( :pk__".$$dbkey[$i] . ')';
				$multikey++;
			} else {
				$update_whereclause .= $$dbkey[$i] . " IS NOT DISTINCT FROM :pk__".$$dbkey[$i];
			}
		}
	} else {
		foreach my $key (keys %$dbkey) {
			if(length($update_whereclause)) {
				$update_whereclause .= " and ";
			}
			if (ref($dbkey->{$key}) eq 'ARRAY') {
				$update_whereclause .= $key . " = ANY( :pk__".$key .')';
				$multikey++;
			} else {
				$update_whereclause .= $key . " IS NOT DISTINCT FROM :pk__".$key;
			}
		}
	}
	#
	# This is just for safety
	#
	if ($multikey > 1) {
		SetError($errsave, 'only one multivalue key may be passed to DBDelete');
		return undef;
	}
	my $q = qq{
		delete from $table
		 where $update_whereclause
	};

	my $sth;
	if (!($sth = $dbh->prepare_cached($q))) {
		SetError($errsave, 
			sprintf("DBDelete: Error preparing database statement %s",
				$dbh->errstr));
		return undef;
	}

	#
	# bind variables
	#

	if(!ref($dbkey)) {
		if (!($sth->bind_param(":pk__$dbkey", $keyval))) {
			SetError($errsave, 
				sprinf("DBDelete: Unable to bind key for %s: %s",
					$dbkey, $sth->errstr));
			return undef;
		}
	} elsif(ref($dbkey) eq 'ARRAY') {
		# sanity checking was done above.
		for(my $i=0 ; $i < (scalar @$dbkey); $i++) {
			my $tkey = $$dbkey[$i];
			my $tval = $$keyval[$i];
			if (!($sth->bind_param(":pk__$tkey", $tval))) {
				SetError($errsave, 
					sprintf("DBDelete: Unable to bind key for %s: %s",
						$tkey, $sth->errstr));
				return undef;
			}
		}
	} else {
		foreach my $key (keys %$dbkey) {
			if (!($sth->bind_param(":pk__".$key, $dbkey->{$key}))) {
				SetError($errsave, 
					sprintf("DBDelete: Unable to bind key for %s: %s",
						$key, $sth->errstr));
				return undef;
			}
		}
	}

	my $ret;
	if (!($ret = $sth->execute)) {
		SetError($errsave, 
			sprintf("DBDelete: Error executing update: %s",
				$sth->errstr));
		return undef;
	}
	$sth->finish;
	$ret;
}

sub DBFetch {
	my $self;
	$self = shift if ($#_ % 2 == 0);
	my $opt = &_options(@_);

	my ($dbh, $table);

	# accept either because STAB uses dbh
	$dbh = $opt->{dbhandle} || $opt->{dbh};

	#
	# this is so the routines can be called outside the OO framework
	#
	my $errsave;
	if($opt->{errors}) {
		$errsave = $opt->{errors};
	} elsif($self) {
		$errsave = \$self->{_errors};
	}

	#
	# Check the object for a valid database handle if one wasn't passed
	#
	if (!$dbh) {
		eval { $dbh = $self->DBHandle };
	}
	if(!$dbh) {
		SetError($errsave,
			"must pass dbhandle parameter to DBFetch");
		return undef;
	}
	if (!($table = $opt->{table})) {
		SetError($errsave,
			"must pass table parameter to DBFetch");
		return undef;
	}

	my $q = sprintf("SELECT * FROM %s", $table);

	if (ref($opt->{match}) eq 'HASH') {
		my @match;
		foreach my $k (sort keys %{$opt->{match}}) {
			push @match, {
				'key' => $k,
				'value' => $opt->{match}->{$k},
			};
		}
		$opt->{match} = \@match;
	} elsif(ref($opt->{match}) eq 'ARRAY') {
		if (ref($opt->{match}->[0]) ne 'HASH') {
			my @match;
			while (@{$opt->{match}}) {
				push @match, { 
					key => shift @{$opt->{match}},
					value => shift @{$opt->{match}} 
				};
			}
			$opt->{match} = \@match;
		}
	} else {
		SetError($errsave,
			"Match must be a reference to a hash or an array"
			);
		return undef;
	}
	my ($where, $params) = parsematch($opt->{match});
	if (@{$where}) {
		$q .= " WHERE " . join(' AND ', @{$where});
	}
	if ($opt->{order}) {
		$q .= " ORDER BY ";
		if (!ref($opt->{order})) {
			$q .= $opt->{order};
		} elsif (ref($opt->{order}) eq 'ARRAY') {
			$q .= join ',', @{$opt->{order}};
		} else {
			SetError($errsave,
				"Value for 'order' parameter must be scalar or array reference"
				);
			return undef;
		}
	}
	SetError($opt->{debug}, "Query: " . $q);
	SetError($opt->{debug}, "Params: " . join(',', @{$params}));
	my $sth;
	if (!($sth = $dbh->prepare_cached($q))) {
		SetError($errsave, 
			sprintf("DBFetch: Error preparing database statement %s",
				$dbh->errstr));
		return undef;
	}

	if (!($sth->execute(@{$params}))) {
		SetError($errsave, 
			sprintf("DBFetch: Error executing update: %s",
				$sth->errstr));
		return undef;
	}

	my $rows = [];
	while (my $row = $sth->fetchrow_hashref) {
		push @$rows, $row;
	}
	$sth->finish;
	if (defined($opt->{result_set_size})) {
		if ($opt->{result_set_size} eq 'count') {
			if (!@{$rows}) {
				return 0E0;
			} else {
				return $#$rows + 1;
			}
		} elsif ($opt->{result_set_size} eq 'exactlyone') {
			if (!@{$rows}) {
				SetError($errsave, "No rows returned");
				return undef;
			} elsif ($#$rows > 0) {
				SetError($errsave, "Multiple rows returned");
				return undef;
			}
			return $rows->[0];
		} elsif ($opt->{result_set_size} eq 'first') {
				return $rows->[0];
		}
	}
	return $rows;
}

sub parsematch {
	my $match = shift;
	my (@where, @params);
	if ($match) {
		while (my $matchentry = shift @{$match}) {
			next if !$matchentry->{key};
			if (!exists($matchentry->{matchtype})) {
				$matchentry->{matchtype} = "eq";
			}
			$matchentry->{matchtype} = lc($matchentry->{matchtype});
			my $operator;
			if ($matchentry->{matchtype} eq "eq") {
				$operator = "=";
			} elsif ($matchentry->{matchtype} eq "ne") {
				$operator = "!=";
			} elsif ($matchentry->{matchtype} eq "like") {
				$operator = "LIKE";
			} elsif ($matchentry->{matchtype} eq "notlike") {
				$operator = "NOT LIKE";
			} elsif ($matchentry->{matchtype} eq "regex") {
				$operator = "~";
			} elsif ($matchentry->{matchtype} eq "notregex") {
				$operator = "!~";
			}
			if ($matchentry->{matchtype} eq "eq" &&
					!defined($matchentry->{value})) {
				push @where, sprintf("%s IS NULL", $matchentry->{key});
			} elsif ($matchentry->{matchtype} eq "ne" &&
					!defined($matchentry->{value})) {
				push @where, sprintf("%s IS NOT NULL", $matchentry->{key});
			} else {
				if (ref($matchentry->{value}) eq 'ARRAY') {
					push @where, sprintf("%s %s ANY (?)",
						$matchentry->{key}, $operator);
				} else {
					push @where,
						sprintf("%s %s ?", $matchentry->{key}, $operator);
				}
				push @params, $matchentry->{value};
			}
		}
	}
	return (\@where, \@params);
}



sub commit {
	my $self = shift;

	if ( my $dbh = $self->DBHandle ) {
		my $x = $dbh->commit;
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
		my $rv = $dbh->disconnect;
		$self->{_dbh} = undef;
		return $rv;
	}
}

sub DESTROY {
	my $self = shift;
	if($self && ref($self)) {
		$self->rollback;
		$self->disconnect;
	}
}

1;

__END__


=head1 NAME


=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FILES


=head1 AUTHORS

=cut

