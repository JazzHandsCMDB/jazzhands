#!/usr/bin/env perl

use strict;
use warnings;
use JazzHands::DBI;
use DBI;
use DBD::SQLite;
use Data::Dumper;
use JazzHands::Common qw(:all);

###############################################################################

package	DBThing;
use strict;
use warnings;
use JazzHands::Common qw(:all);
use Data::Dumper;

use parent 'JazzHands::Common';

our $errstr;

sub errstr {
	return($errstr);
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
	if( ! $service ) {
		$errstr = "Must specify db service to connect to";
		return undef;
	}

	my $dbh = JazzHands::DBI->connect($service, {AutoCommit => 0, RaiseError => 0});
	if(!$dbh) {
		$errstr = "Unable to connect to $service: ".$JazzHands::DBI::errstr;
		return undef;
	}

	my $self = $class->SUPER::new(@_);

	#my $self = {};
	#bless($self, $class );

	$self->{_dbh}  = $dbh;
	$self;
}

sub DESTROY {
	my $self = shift @_;

	$self->{_dbh}->rollback;
	$self->{_dbh}->disconnect;
	$self->{_dbh} = undef;
}

sub fetch_table($$$) {
	my ($self, $table, $pk) = @_;

	my $dbh = $self->DBHandle();

	my $sth = $dbh->prepare_cached(qq{
		SELECT	*
		FROM	$table
	}) || die dbh->errstr;

	$sth->execute || die $sth->errstr;

	my $rv = {};
	while(my $hr = $sth->fetchrow_hashref) {
		my $k;
		if(ref($pk) eq 'ARRAY') {
			$k = join(",", map { $hr->{$_} } @{$pk});
		} else {
			$k = $hr->{$pk};
		}

		$rv->{$k} = $hr;
	}
	$rv;
}

sub get_cols {
	my ( $self, $table ) = @_;

	my $dbh = $self->DBHandle();

	my (@rv);
	foreach my $schema ($self->get_search_path() ) {
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
		last if($found);
	}
	@rv;
}

sub get_search_path($) {
	my ($self) = @_;
	my $dbh = $self->DBHandle();

	my @search;
	if($dbh->{Driver}->{Name} eq 'Pg') {
		my $sth = $dbh->prepare("show search_path") || die $dbh->errstr;
		$sth->execute || die $sth->errstr;
		while(my ($s) = $sth->fetchrow_array) {
			push(@search, $s);
		}
	} elsif($dbh->{Driver}->{Name} eq 'SQLite') {
		push(@search, 'main');
	} else {
		push(@search, undef);
	}
	@search
}

sub get_primary_key {
	my($self, $table) = @_;
	my $dbh = $self->DBHandle();

	my (@rv);
	foreach my $schema ($self->get_search_path() ) {
		my $sth = $dbh->primary_key_info(undef, $schema, $table);

		my $found;
		while(my $hr = $sth->fetchrow_hashref) {
			push(@rv, $hr->{COLUMN_NAME});
		}
	}
	if($#rv ==0) {
		return $rv[0];
	}
	@rv;
}

sub table_identical {
	my($self, $fromh, $table) = @_;

	my $up = $self->DBHandle();
	my $down = $fromh->DBHandle();

	my $sth = $down->table_info(undef, 'main', $table);

	my @upcols = $self->get_cols($table);
	my @dncols = $fromh->get_cols($table);

	if($#upcols != $#dncols) {
		return 0;
	}

	for(my $i = 0; $i < $#upcols; $i++) {
		if($upcols[$i]->{'colname'} ne $dncols[$i]->{'colname'}) {
			warn "mismatch on ", Dumper($upcols[$i], $dncols[$i]);
			return 0;
		}
		if($upcols[$i]->{'coltype'} ne $dncols[$i]->{'coltype'}) {
			warn "mismatch on ", Dumper($upcols[$i], $dncols[$i]);
			return 0;
		}
	}
	return 1;
}

sub table_exists {
	my($self, $table) = @_;

	my $dbh = $self->DBHandle();
	foreach my $schema ($self->get_search_path() ) {
		my $sth = $dbh->table_info(undef, $schema, $table);

		while(my $hr = $sth->fetchrow_hashref) {
			if($hr->{TABLE_NAME} eq $table) {
				return 1;
			}
		}
	}
	return 0;
}

sub drop_table {
	my($self, $table) = @_;

	$self->DBHandle()->do("drop table $table") || die $self->DBHandle()->errstr;
}

sub mktable {
	my($self, $fromh, $table) = @_;

	my $old = $fromh->DBHandle();
	my $new = $self->DBHandle();

	my @cols = $fromh->get_cols($table);

	my @pk = $fromh->get_primary_key($table);

	my $pkstr = "";
	if($#pk >= 0) {
		$pkstr = join(" ", 
			", PRIMARY KEY (", 
			join(",", @pk), 
			")");
	}

	my $q = qq{CREATE TABLE $table (\n\t }.
		join(",\n\t", map { 
				join(" ", $_->{colname},$_->{coltype}) 
			} @cols).$pkstr.")";
		;

	my $sth = $new->prepare(qq{
		$q;
	}) || die $new->errstr;
	$sth->execute || die $sth->{Statement}, ":", $sth->errstr;
	
}

#
# copies a table identified as $table from $fromh into $self.
#
# $pk is only needed if it can not be discerned (such as views)
#
sub copy_table($$$;$) {
	my($self, $fromh, $table, $pk) = @_;

	# my $down = $self->DBHandle();
	# my $up = $fromh->DBHandle();

	warn "copy $table";
	if(! $self->table_identical($fromh, $table) ) {
		if($self->table_exists($table)) {
			$self->drop_table($table);
			warn "MISMATCH, DROP";
		}
		warn "creating table";
		$self->mktable($fromh, $table);
	}

	if(!$pk) {
		my @pk;
		@pk = $fromh->get_primary_key($table);
		$pk = \@pk;
	}

	#
	# needs to handle multi-column pks
	#
	my $fromt = $fromh->fetch_table($table, $pk);
	my $downt = $self->fetch_table($table, $pk);


	#
	# go through everything upstream and make sure everything downstream is there 
	#
	my ($ins,$upd,$del)= (0,0,0);
	foreach my $k (keys %{$fromt}) {
		if(!defined($downt->{$k})) {
			# warn "insert $k";
			$ins++;
			if(!($self->DBInsert(
						table => $table,
						hash => $fromt->{$k},
					))) {
				die join(" ", $self->Error() );
			}
		} else {
			my $diff = $self->hash_table_diff($downt->{$k}, $fromt->{$k});
			if (scalar keys %{$diff}) {
				# warn "update $k";
				$upd++;
				if(!($self->DBUpdate(
							table => $table,
							dbkey => $pk,
							keyval => $k,
							hash => $diff,
						))) {
					die join(" ", $self->Error() );
				}
			}
		}
	}

	#
	# go through everything downstream and make sure its upstream, or purge
	#
	foreach my $k (keys %{$downt}) {
		if(!defined($fromt->{$k})) {
				$del++;
				if(!($self->DBDelete(
							table => $table,
							dbkey => $pk,
							keyval => $k,
						))) {
					die join(" ", $self->Error() );
				}
		}
	}
	warn "\tinsert $ins, update $upd, delete $del\n";

}

###############################################################################

package main;

my $up = new DBThing(service => 'hotpants') || die $DBThing::errstr;
my $down = new DBThing(service => 'hotpants-local') || die $DBThing::errstr;

# $down->begin_work() || die $down->errstr;


my $tablemap = {
	'token' => 'token_id',
	'account' => 'account_id',
	'token_sequence' => 'token_sequence',
	'account_token' => 'account_id',
	'account_collection_account' => 'account_id',
};

foreach my $table (keys(%{$tablemap})) {
	warn "sync $table...\n";
	$down->copy_table($up, $table);
}


$down->commit || die $down->errstr;
# $up->commit || die $up->errstr;
# $up->rollback;
