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
use JazzHands::Common::Error qw(:all);
use DBI::Const::GetInfoType;
use Data::Dumper;

our $VERSION   = '1.0';

our @ISA	   = qw(Exporter);

our %EXPORT_TAGS = 
(
        'all' => [qw(run_update_from_hash 
			DBUpdate
			DBInsert
			DBDelete
			DBFetch
		)],
);

Exporter::export_ok_tags('all');

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

	warn "foo!\n";

	return DBUpdate(undef,
		dbhandle => $dbh,
		table => $table,
		dbkey => $dbkey,
		keyval => $keyval,
		hash => $hash
	);
}

sub DBUpdate {
	my $self = shift;
	my $opt = &_options(@_);

	my ($dbh, $table, $dbkey, $keyval, $hash);
	# accept either because STAB uses dbh
	if (!($dbh = $opt->{dbhandle})) {
		$dbh = $opt->{dbh};
	}
	if(!$dbh) {
		SetError($opt->{errors},
			"must pass dbhandle parameter to DBFetch");
		return undef;
	}
	if (!($table = $opt->{table})) {
		SetError($opt->{errors},
			"must pass table parameter to DBUpdate");
		return undef;
	}
	if (!($dbkey = $opt->{dbkey})) {
		SetError($opt->{errors},
			"must pass dbkey parameter to DBUpdate");
		return undef;
	}
	if (!($hash = $opt->{hash})) {
		SetError($opt->{errors},
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
			SetError($opt->{errors},
				"DBUpdate: must be same number of values as keys");
			return undef;
		}
		for(my $i=0 ; $i < (scalar @$dbkey); $i++) {
			if(length($update_whereclause)) {
				$update_whereclause .= " and ";
			}
			$update_whereclause .= $$dbkey[$i] . " = :pk__".$$dbkey[$i];
		}
	} else {
		foreach my $key (keys %$dbkey) {
			if(length($update_whereclause)) {
				$update_whereclause .= " and ";
			}
			$update_whereclause .= $key . " = :pk__".$key;
		}
	}
	my $q = qq{
		update $table
		   set $setq
		 where $update_whereclause
	};

	my $sth;
	if (!($sth = $dbh->prepare_cached($q))) {
		SetError($opt->{errors}, 
			sprintf("DBUpdate: Error preparing database statement %s",
				$dbh->errstr));
		return undef;
	}


	#
	# bind variables
	#
	if(!ref($dbkey)) {
		if (!($sth->bind_param(":pk__$dbkey", $keyval))) {
			SetError($opt->{errors}, 
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
				SetError($opt->{errors}, 
					sprintf("DBUpdate: Unable to bind key for %s: %s",
						$tkey, $sth->errstr));
				return undef;
			}
		}
	} else {
		foreach my $key (keys %$dbkey) {
			if (!($sth->bind_param(":pk__".$key, $dbkey->{$key}))) {
				SetError($opt->{errors}, 
					sprintf("DBUpdate: Unable to bind key for %s: %s",
						$key, $sth->errstr));
				return undef;
			}
		}
	}
	foreach my $key (keys %$hash) {
		if (!($sth->bind_param(":$key", $hash->{$key}))) {
			SetError($opt->{errors}, 
				sprintf("DBUpdate: Unable to bind value for %s: %s",
					$key, $sth->errstr));
			return undef;
		}
	}
	if (!($sth->execute)) {
		SetError($opt->{errors}, 
			sprintf("DBUpdate: Error executing update: %s",
				$sth->errstr));
		return undef;
	}
	1;
}

sub DBInsert {
	my $self = shift;
	my $opt = &_options(@_);

	my ($dbh, $table, $hash);
	# accept either because STAB uses dbh
	if (!($dbh = $opt->{dbhandle})) {
		$dbh = $opt->{dbh};
	}
	if(!$dbh) {
		SetError($opt->{errors},
			"must pass dbhandle parameter to DBFetch");
		return undef;
	}
	if (!($table = $opt->{table})) {
		SetError($opt->{errors},
			"must pass table parameter to DBInsert");
		return undef;
	}
	if (!($hash = $opt->{hash})) {
		SetError($opt->{errors},
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
        SetError($opt->{errors},
            sprintf("DBInsert: Error preparing database statement %s",
				$dbh->errstr));
        return undef;
    }
	foreach my $key (keys %$hash) {
		if (!($sth->bind_param(":$key", $hash->{$key}))) {
			SetError($opt->{errors}, 
				sprintf("DBInsert: Unable to bind value for %s: %s",
					$key, $sth->errstr));
			return undef;
		}
	}
	if (!($sth->execute)) {
		SetError($opt->{errors}, 
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
	1;
}

sub DBDelete {
	my $self = shift;
	my $opt = &_options(@_);

	my ($dbh, $table, $dbkey, $keyval, $hash);
	# accept either because STAB uses dbh
	if (!($dbh = $opt->{dbhandle})) {
		$dbh = $opt->{dbh};
	}
	if(!$dbh) {
		SetError($opt->{errors},
			"must pass dbhandle parameter to DBFetch");
		return undef;
	}
	if (!($table = $opt->{table})) {
		SetError($opt->{errors},
			"must pass table parameter to DBDelete");
		return undef;
	}
	if (!($dbkey = $opt->{dbkey})) {
		SetError($opt->{errors},
			"must pass dbkey parameter to DBDelete");
		return undef;
	}
	$keyval = $opt->{keyval};

	#
	# first build the query
	#

	my $update_whereclause;
	if(!ref($dbkey)) {
		$update_whereclause = "$dbkey = :pk__$dbkey";
	} elsif(ref($dbkey) eq 'ARRAY') {
		$update_whereclause = "";
		if( (scalar @$dbkey) != (scalar @$keyval) ) {
			SetError($opt->{errors},
				"DBDelete: must be same number of values as keys");
			return undef;
		}
		for(my $i=0 ; $i < (scalar @$dbkey); $i++) {
			if(length($update_whereclause)) {
				$update_whereclause .= " and ";
			}
			$update_whereclause .= $$dbkey[$i] . " = :pk__".$$dbkey[$i];
		}
	} else {
		foreach my $key (keys %$dbkey) {
			if(length($update_whereclause)) {
				$update_whereclause .= " and ";
			}
			$update_whereclause .= $key . " = :pk__".$key;
		}
	}
	my $q = qq{
		delete from $table
		 where $update_whereclause
	};

	my $sth;
	if (!($sth = $dbh->prepare_cached($q))) {
		SetError($opt->{errors}, 
			sprintf("DBDelete: Error preparing database statement %s",
				$dbh->errstr));
		return undef;
	}

	#
	# bind variables
	#

	if(!ref($dbkey)) {
		if (!($sth->bind_param(":pk__$dbkey", $keyval))) {
			SetError($opt->{errors}, 
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
				SetError($opt->{errors}, 
					sprintf("DBDelete: Unable to bind key for %s: %s",
						$tkey, $sth->errstr));
				return undef;
			}
		}
	} else {
		foreach my $key (keys %$dbkey) {
			if (!($sth->bind_param(":pk__".$key, $dbkey->{$key}))) {
				SetError($opt->{errors}, 
					sprintf("DBDelete: Unable to bind key for %s: %s",
						$key, $sth->errstr));
				return undef;
			}
		}
	}
	if (!($sth->execute)) {
		SetError($opt->{errors}, 
			sprintf("DBDelete: Error executing update: %s",
				$sth->errstr));
		return undef;
	}
	1;
}

sub DBFetch {
	my $self = shift;
	my $opt = &_options(@_);

	my ($dbh, $table);
	# accept either because STAB uses dbh
	if (!($dbh = $opt->{dbhandle})) {
		$dbh = $opt->{dbh};
	}
	if(!$dbh) {
		SetError($opt->{errors},
			"must pass dbhandle parameter to DBFetch");
		return undef;
	}
	if (!($table = $opt->{table})) {
		SetError($opt->{errors},
			"must pass table parameter to DBFetch");
		return undef;
	}

	my $q = sprintf("SELECT * FROM %s", $table);

	my (@where, @params);
	if ($opt->{match}) {
		while (my $matchentry = shift @{$opt->{match}}) {
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
	if (@where) {
		$q .= " WHERE " . join(' AND ', @where);
	}
	SetError($opt->{debug}, "Query: " . $q);
	SetError($opt->{debug}, "Params: " . join(',', @params));
	my $sth;
	if (!($sth = $dbh->prepare_cached($q))) {
		SetError($opt->{errors}, 
			sprintf("DBFetch: Error preparing database statement %s",
				$dbh->errstr));
		return undef;
	}

	if (!($sth->execute(@params))) {
		SetError($opt->{errors}, 
			sprintf("DBFetch: Error executing update: %s",
				$sth->errstr));
		return undef;
	}

	my $rows = [];
	while (my $row = $sth->fetchrow_hashref) {
		push @$rows, _dbx($row);
	}
	$sth->finish;
	return $rows;
}

1;

__END__


=head1 NAME


=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FILES


=head1 AUTHORS

=cut

