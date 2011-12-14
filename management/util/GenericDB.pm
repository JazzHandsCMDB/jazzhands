#
# $Id$
#

=head1 NAME


=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FILES

=head1 AUTHORS

=cut


###############################################################################

package JazzHands::GenericDB;

use strict;
use Exporter;
use vars qw(@EXPORT @EXPORT_OK @ISA $VERSION);

$VERSION   = '1.0';

@ISA	   = qw(Exporter);
@EXPORT    = qw(_dbx hash_table_diff val_person_contact_type hash_table_diff run_update_from_hash);
@EXPORT_OK = qw( );

our $direction = 'lower';

###############################################################################

sub _dbx {
	# XXX if oracle, return upper case, otherwise lower case
	my $x = shift;

	my $dir = $direction;

	if(ref($x)) { 
		if(ref($x) eq 'HASH') {
			my $r = {};
			foreach my $k (keys %$x) {
				if($direction eq 'lower') {
					$r->{ lc($k) } = $x->{$k};
				} else {
					$r->{ uc($k) } = $x->{$k};
				}
			}
			return $r;
		} else {
			return undef;
		}
	} else {
		if($direction eq 'lower') {
			return lc($x);
		} else {
			return uc($x);
		}
	}
}

#
# This takes two hash tables and returns the differences between the two,
# essentially returning the items in the second hash.

# - If the second hash is not defined, it returns the first hash
# - If a key is in hash1 but does not exist in hash2, it is not included
# - if a key is in hash1 but exists and not defined in hash2, its included
# - if a key is not in hash1, it will not be included
# - if a key exists in hash1 but not defined and is not defined in hash2,
#       it will be included
# - if its defined and both, and they differ, it will be included
sub hash_table_diff {
	my($hash1, $hash2) = @_;

	my %rv;
	if(!defined($hash2)) {
		%rv = %$hash1;
	} else {
		foreach my $key (keys %$hash1) {
			next if(!exists($hash2->{$key}));
			#- warn "comparing $hash1->{$key} && $hash2->{$key}\n";
			if(!defined($hash1->{$key}) && !defined($hash2->{$key})) {
				next;
			} elsif(defined($hash1->{$key}) && !defined($hash2->{$key})) {
				$rv{$key} = undef;
			} elsif((!defined($hash1->{$key})&&defined($hash2->{$key})) || $hash1->{$key} ne $hash2->{$key}) {
				#- warn "no match, adding $key";
				$rv{$key} = $hash2->{$key};
			}
		}
	}
	\%rv;
}

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
sub run_update_from_hash {
	my($dbh, $table, $dbkey, $keyval, $hash) = @_;

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
		# 'tis a scalar
		$update_whereclause = "$dbkey = :pk__$dbkey";
	} elsif(ref($dbkey) eq 'ARRAY') {
		$update_whereclause = "";
		if( (scalar @$dbkey) != (scalar @$keyval) ) {
			# die?
			return undef;
		}
		for(my $i=0 ; $i < (scalar @$dbkey); $i++) {
			if(length($update_whereclause)) {
				$update_whereclause .= " and ";
			}
			$update_whereclause .= $$dbkey[$i] . " = :pk__".$$dbkey[$i];
		}
	} else {
		# die?
		return undef;
	}
	my $q = qq{
		update $table
		   set $setq
		 where $update_whereclause
	};

	my $sth = $dbh->prepare_cached($q) || die $dbh->errstr;


	#
	# bind variables
	#
	if(!ref($dbkey)) {
		$sth->bind_param(":pk__$dbkey", $keyval) || die $sth->errstr;
	} elsif(ref($dbkey) eq 'ARRAY') {
		# sanity checking was done above.
		for(my $i=0 ; $i < (scalar @$dbkey); $i++) {
			my $tkey = $$dbkey[$i];
			my $tval = $$keyval[$i];
			$sth->bind_param(":pk__$tkey", $tval) || $sth->errstr;
		}
	}
	foreach my $key (keys %$hash) {
		$sth->bind_param(":$key", $hash->{$key}) || $sth->errstr;
	}
	$sth->execute || $sth->errstr;
	1;
}

1;

__END__
