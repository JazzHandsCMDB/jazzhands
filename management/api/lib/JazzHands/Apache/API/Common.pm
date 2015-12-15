package JazzHands::Apache::API::Common;
use strict;

use Exporter 'import';
use JazzHands::Common qw(:all);
use Time::HiRes qw(gettimeofday tv_interval);

use vars qw(@ISA @EXPORT $VERSION);

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(runquery FindHashChild );
our %EXPORT_TAGS = (all => [ qw(runquery FindHashChild) ] );

$VERSION = '0.65.0';

sub runquery {
	my $opt = &_options(@_);

	my $dbh = $opt->{dbh};;
	my $q = $opt->{query};
	my $args = $opt->{args};
	my $r = $opt->{request};
	my $description = $opt->{description} || 'unspecified action';
	my $errors = $opt->{errors};;
	my $report_error = 0;

	if (exists($opt->{report_error})) {
		$report_error = $opt->{report_error};
	}

	if ($opt->{debug} > 1) {
		if ($r) {
			$r->log_rerror(
				Apache2::Log::LOG_MARK,
				Apache2::Const::LOG_DEBUG,
				APR::Const::SUCCESS,
				sprintf(
					'Running query %s',
					$description)
				);
		}
		SetError($errors, sprintf('Running query %s', $description));
	}

	if ($r && $opt->{debug} > 2) {
		$r->log_rerror(
			Apache2::Log::LOG_MARK,
			Apache2::Const::LOG_DEBUG,
			APR::Const::SUCCESS,
			Data::Dumper->Dump([$q, $args], [ qw($query $args)])
		);
		SetError($errors,
			Data::Dumper->Dump([$q, $args], [ qw($query $args)]));
	}

	if (!exists($opt->{return_type})) {
		$opt->{return_type} = 'hashref';
	}

	my $sth;
	my $json = JSON->new;
	my $t0 = [gettimeofday];
	if (!($sth = $dbh->prepare_cached($q))) {
		if ($r) {
			$r->log_error(
				sprintf("Error preparing %s query: %s",
					$description,
					$dbh->errstr
				));
		}
		SetError($errors,
			sprintf("Error preparing %s query: %s",
				$description,
				$dbh->errstr
			));
		SetError($opt->{usererror},
			sprintf("Database query error %s", $description)
		);
		if ($report_error) {	
			if ($r) {
				$r->print($json->encode(
					{
						status => 'error',
						message => sprintf("Database query error %s",
							$description)
					}));
			}
		}
		return undef;
	}
	
	if (!($sth->execute(@{$args}))) {
		if ($r) {
			$r->log_error(
				sprintf("Error executing %s query: %s",
					$description,
					$sth->errstr
				));
		}
		SetError($errors,
			sprintf("Error executing %s query: %s",
				$description,
				$sth->errstr
			));
			
		SetError($opt->{usererror},
			sprintf("Database query error %s", $description)
		);
			
		if ($r && $report_error) {
			$r->print($json->encode(
				{
					status => 'error',
					message => sprintf("Database query error %s",
						$description)
				}));
		}
		return undef;
	}
	#
	# If we have debug crap from the query, log it
	#
	if ($sth->errstr) {
		if ($r) {
			$r->log_rerror(
				Apache2::Log::LOG_MARK,
				Apache2::Const::LOG_DEBUG,
				APR::Const::SUCCESS,
				$sth->errstr);
		}
		SetError($errors, $sth->errstr);
	}
	my $ret;
	if ($opt->{allrows}) {
		if ($opt->{return_type} eq 'hashref') {
			if ($opt->{hashkey}) {
				$ret = $sth->fetchall_hashref($opt->{hashkey});
			} else {
				my $row;
				$ret = [];
				while ($row = $sth->fetchrow_hashref) {
					push @$ret, $row;
				}
			}
		} else {
			$ret = $sth->fetchall_arrayref;
		}
	} else {
		if ($opt->{return_type} eq 'hashref') {
			$ret = $sth->fetchrow_hashref;
			if (!$ret) {
				$ret = {};
			}
		} else {
			$ret = $sth->fetch;
		}
	}
	$sth->finish;

	if ($r && $opt->{debug} > 2) {
		my $elapsed = tv_interval($t0);
		$r->log_rerror(
			Apache2::Log::LOG_MARK,
			Apache2::Const::LOG_DEBUG,
			APR::Const::SUCCESS,
			sprintf ("Query time: %s\n%s",
				tv_interval($t0),
				Data::Dumper->Dump([$ret], [ qw($ret)])
			)
		);
		SetError($errors, 
			sprintf ("Query time: %s\n%s",
				tv_interval($t0),
				Data::Dumper->Dump([$ret], [ qw($ret)])
			)
		);
	}

	return $ret || [];
}

sub FindHashChild {
	my $opt = _options(@_);

	my $key = $opt->{key};
	my $value = $opt->{value};

	return if (!$opt->{hash} || !$key);

	my $found = [];
	my @searchlist = ($opt->{hash});

	while (@searchlist) {
		my $target = shift @searchlist;
		# push all children that are hashes or arrays onto the search list
		if (ref($target) eq 'ARRAY') {
			unshift @searchlist,
				(grep { ref($_) eq 'ARRAY' || ref($_) eq 'HASH' } @$target);
		} elsif (ref($target) eq 'HASH') {
			unshift @searchlist,
				(grep { ref($_) eq 'ARRAY' || ref($_) eq 'HASH' }
					values %$target);
			if (exists($target->{$key})) {
				if (!defined($value) || ($target->{$key} eq $value)) {
					push @$found, $target;
				}
			}
		}
	}
	return $found;
}

1;

