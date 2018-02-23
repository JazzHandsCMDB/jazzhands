package JazzHands::Apache::API::Common;
use strict;

use Exporter 'import';
use Apache2::Const -compile => qw(:common :log);
use CGI;
use Time::HiRes qw(gettimeofday tv_interval);
use JazzHands::Common qw(:all :db);
use Data::Dumper;

use vars qw(@ISA @EXPORT $VERSION);

our @ISA = qw(Exporter);
our @EXPORT_OK =
  qw(runquery FindHashChild InitializeRequest CheckAdmin ProcessMessage ReturnError);
our %EXPORT_TAGS = (
	all => [
		qw(runquery FindHashChild InitializeRequest CheckAdmin ProcessMessage ReturnError)
	]
);

$VERSION = '0.65.0';

sub runquery {
	my $opt = &_options(@_);

	my $dbh          = $opt->{dbh};
	my $q            = $opt->{query};
	my $args         = $opt->{args};
	my $r            = $opt->{request};
	my $description  = $opt->{description} || 'unspecified action';
	my $errors       = $opt->{errors};
	my $report_error = 0;

	if ( exists( $opt->{report_error} ) ) {
		$report_error = $opt->{report_error};
	}

	if ( $opt->{debug} > 1 ) {
		if ($r) {
			$r->log_rerror( Apache2::Log::LOG_MARK, Apache2::Const::LOG_DEBUG,
				APR::Const::SUCCESS,
				sprintf( 'Running query %s', $description ) );
		}
		SetError( $errors, sprintf( 'Running query %s', $description ) );
	}

	if ( $r && $opt->{debug} > 2 ) {
		$r->log_rerror( Apache2::Log::LOG_MARK, Apache2::Const::LOG_DEBUG,
			APR::Const::SUCCESS,
			Data::Dumper->Dump( [ $q, $args ], [qw($query $args)] ) );
		SetError( $errors,
			Data::Dumper->Dump( [ $q, $args ], [qw($query $args)] ) );
	}

	if ( !exists( $opt->{return_type} ) ) {
		$opt->{return_type} = 'hashref';
	}

	my $sth;
	my $json = JSON->new;
	$json->allow_blessed(1);
	my $t0 = [gettimeofday];
	if ( !( $sth = $dbh->prepare_cached($q) ) ) {
		if ($r) {
			$r->log_error(
				sprintf(
					"Error preparing %s query: %s",
					$description, $dbh->errstr
				)
			);
		}
		SetError(
			$errors,
			sprintf(
				"Error preparing %s query: %s",
				$description, $dbh->errstr
			)
		);
		SetError( $opt->{usererror},
			sprintf( "Database query error %s", $description ) );
		if ($report_error) {
			if ($r) {
				$r->print(
					$json->encode(
						{
							status  => 'error',
							message => sprintf(
								"Database query error %s", $description
							)
						}
					)
				);
			}
		}
		return undef;
	}

	if ( !( $sth->execute( @{$args} ) ) ) {
		if ($r) {
			$r->log_error(
				sprintf(
					"Error executing %s query: %s",
					$description, $sth->errstr
				)
			);
		}
		SetError(
			$errors,
			sprintf(
				"Error executing %s query: %s",
				$description, $sth->errstr
			)
		);

		SetError( $opt->{usererror},
			sprintf( "Database query error %s", $description ) );

		if ( $r && $report_error ) {
			$r->print(
				$json->encode(
					{
						status => 'error',
						message =>
						  sprintf( "Database query error %s", $description )
					}
				)
			);
		}
		return undef;
	}
	#
	# If we have debug crap from the query, log it
	#
	if ( $sth->errstr ) {
		if ($r) {
			$r->log_rerror( Apache2::Log::LOG_MARK, Apache2::Const::LOG_DEBUG,
				APR::Const::SUCCESS, $sth->errstr
			);
		}
		SetError( $errors, $sth->errstr );
	}
	my $ret;
	if ( $opt->{allrows} ) {
		if ( $opt->{return_type} eq 'hashref' ) {
			if ( $opt->{hashkey} ) {
				$ret = $sth->fetchall_hashref( $opt->{hashkey} );
			} else {
				my $row;
				$ret = [];
				while ( $row = $sth->fetchrow_hashref ) {
					push @$ret, $row;
				}
			}
		} else {
			$ret = $sth->fetchall_arrayref;
		}
	} else {
		if ( $opt->{return_type} eq 'hashref' ) {
			$ret = $sth->fetchrow_hashref;
			if ( !$ret ) {
				$ret = {};
			}
		} else {
			$ret = $sth->fetch;
		}
	}
	$sth->finish;

	if ( $r && $opt->{debug} > 2 ) {
		my $elapsed = tv_interval($t0);
		$r->log_rerror(
			Apache2::Log::LOG_MARK,
			Apache2::Const::LOG_DEBUG,
			APR::Const::SUCCESS,
			sprintf(
				"Query time: %s\n%s",
				tv_interval($t0), Data::Dumper->Dump( [$ret], [qw($ret)] )
			)
		);
		SetError(
			$errors,
			sprintf(
				"Query time: %s\n%s",
				tv_interval($t0), Data::Dumper->Dump( [$ret], [qw($ret)] )
			)
		);
	}

	return $ret || [];
}

sub FindHashChild {
	my $opt = _options(@_);

	my $key   = $opt->{key};
	my $value = $opt->{value};

	return if ( !$opt->{hash} || !$key );

	my $found      = [];
	my @searchlist = ( $opt->{hash} );

	while (@searchlist) {
		my $target = shift @searchlist;

		# push all children that are hashes or arrays onto the search list
		if ( ref($target) eq 'ARRAY' ) {
			unshift @searchlist,
			  ( grep { ref($_) eq 'ARRAY' || ref($_) eq 'HASH' } @$target );
		} elsif ( ref($target) eq 'HASH' ) {
			unshift @searchlist,
			  ( grep { ref($_) eq 'ARRAY' || ref($_) eq 'HASH' }
				  values %$target );
			if ( exists( $target->{$key} ) ) {
				if ( !defined($value) || ( $target->{$key} eq $value ) ) {
					push @$found, $target;
				}
			}
		}
	}
	return $found;
}

#
# basically dumps an eror to the output
#
sub ReturnError($) {
	my $request = shift @_;

	my $r    = $request->{handle};
	my $json = JSON->new;
	$json->allow_blessed(1);

	my $response;
	if ( $request->{status}->{meta}->{errorstate} ) {
		$response = {
			status => $request->{status}->{meta}->{errorstate}->{status}
			  || 'error',
			message => $request->{status}->{meta}->{errorstate}->{message},
		};
	}

	if ( !$response ) {
		$response = {
			status  => 'error',
			message => 'error pass thru failed.  seek help'
		};
	}

	$r->content_type('application/json');
	$r->print( $json->encode($response) );
	return Apache2::Const::OK;
}

#
# This is used to keep track of API-specific bits related to the request
# and is passed around.  It is expected that bits in here are set once early
# and not changed.
#
sub InitializeRequest {
	my $opt = _options(@_);

	my $request = $opt->{request} || {};
	my $r       = $opt->{handle};
	my $authapp = $opt->{authapp} || 'jazzhands-api';

	#
	# These things changed between Apache 2.2 and 2.4, so one of these
	# should work
	#
	my $client_ip;
	eval { $client_ip = $r->connection->client_ip; };
	if ( !$client_ip ) {
		eval { $client_ip = $r->connection->remote_ip; };
	}

	$request->{handle} = $r;
	$request->{meta} = { client_ip => $client_ip };

	my @errors;
	my $jhdbi = JazzHands::DBI->new;
	my $dbh   = $jhdbi->connect_cached(
		application => $authapp,
		dbiflags    => { AutoCommit => 0, PrintError => 0 },
		errors      => \@errors
	);
	if ( !$dbh ) {
		$request->{status}->{meta}->{errorstate}->{message} =
		  'error connecting to database';
		$r->log_error(
			    $request->{status}->{meta}->{errorstate}->{message} . ': '
			  . $JazzHands::DBI::errstr
			  . ", APPAUTHAL_CONFIG="
			  . $ENV{APPAUTHAL_CONFIG} );

		return undef;
	}

	$request->{meta}->{dbh} = $dbh;

	$jhdbi->set_session_user('jazzhands-api');

	#
	# XXX - figure out how to deal with host principals!
	#
	my $user = $r->user();

	$request->{meta}->{principal} = $user;

	#
	# We need to check for valid authentication realms here, but things
	# are not completely set up for that at this point.  Also, this should
	# move to its own authentication module
	#
	$user =~ s/@.*$//;

	# XXX should jazzhands-api be there?
	$jhdbi->set_session_user( 'jazzhands-api/' . $user );

	if ( $user =~ m,^host/(.+)$, ) {
		my $host = $user;
		$host =~ s,^host/,,;
		$request->{meta}->{device_name} = $host;
		$request->{meta}->{user_type}   = 'device';
	} else {
		$request->{meta}->{user_type} = 'account';
	}

	$request->{meta}->{user} = $user;

	#
	# Admin is set if the remote side authenticates with a principal that
	# is associated with an administrator
	#
	$request->{meta}->{admin} = 0;

	#
	# Debug can be requested by the client side to spew lots of things into
	# the logs (some of which are returned to the client)
	#

	$request->{meta}->{debug} = 0;
	#
	# force can be passsed by an administrator to override some functions
	# that would normally be disallowed.
	#

	$request->{meta}->{force} = 0;
	#
	# Dry run can be requested by the client side to roll back the transaction
	#

	$request->{meta}->{dryrun} = 0;
	$request;
}

sub CheckAdmin($$$;$) {
	my ( $request, $name, $type, $user ) = @_;

	$user = $request->{meta}->{user} if ( !$user );

	$type = 'API' if ( !$type );

	my $r = $request->{handle};

	if ( $request->{meta}->{debug} ) {
		$r->log_rerror( Apache2::Log::LOG_MARK,
			Apache2::Const::LOG_DEBUG,
			APR::Const::SUCCESS,
			sprintf( 'Validating API user: %s', $request->{meta}->{user} )
		);
	}
	my $ret;
	if (
		!defined(
			$ret = runquery(
				description => 'validating API user',
				request     => $r,
				debug       => $request->{meta}->{debug},
				dbh         => $request->{meta}->{dbh},
				allrows     => 1,
				query       => q {
			SELECT
				login
			FROM
				property p JOIN
				v_acct_coll_acct_expanded acae ON
					(p.property_value_account_coll_id =
					acae.account_collection_id) JOIN
				account a ON
					(acae.account_id = a.account_id)
				WHERE
					(property_name, property_type) = (?, ?)
				AND
					login = ?
		},
				args => [ $name, $type, $user ]
			)
		)
	  )
	{
		$request->{status}->{meta}->{errorstate}->{message} =
		  "Temporary error validating user principal";
		return undef;
	}

	if (@$ret) {
		if ( $request->{meta}->{debug} ) {
			$r->log_rerror(
				Apache2::Log::LOG_MARK,
				Apache2::Const::LOG_DEBUG,
				APR::Const::SUCCESS,
				sprintf( 'User %s is authorized for selected action', $user )
			);
		}
		$request->{meta}->{admin} = 1;
	} else {
		$request->{status}->{meta}->{errorstate}->{message} =
		  sprintf( 'User %s is not authorized for selected action', $user );
		$r->log_error(
			sprintf(
				'Rejecting %s request from %s: %s',
				$request->{data}->{command},
				$request->{meta}->{client_ip},
				$request->{status}->{meta}->{errorstate}->{message},
			)
		);
		return undef;
	}

	$r->log_rerror(
		Apache2::Log::LOG_MARK,
		Apache2::Const::LOG_INFO,
		APR::Const::SUCCESS,
		sprintf(
			'%s request from admin user %s from %s',
			$request->{data}->{command}, $user,
			$request->{meta}->{client_ip},
		)
	);
	if ( $request->{meta}->{admin} ) {
		if ( $request->{force} ) {
			$request->{meta}->{force} = 1;
		}
	}
	$request->{meta}->{admin};
}

#
# given a requests, handles post data or headers and DTRT
#
sub ProcessMessage($;$) {
	my $request = shift @_;
	my $root    = shift @_;

	my $r = $request->{handle};

	my $path;
	if ( !$root ) {
		$path = $r->path_info();
		$path =~ s,^.*/([^/]+)/?,$1,;
	}

	my $json = JSON->new;
	$json->allow_blessed(1);
	my $headers = $r->headers_in;

	if ( $r->headers_in->{'Content-Length'} ) {
		my $json_data;
		$r->read( $json_data, $r->headers_in->{'Content-Length'} );

		eval { $request->{data} = $json->decode($json_data) };
		if ( !defined( $request->{data} ) ) {
			$request->{status}->{meta}->{errorstate}->{status} = 'error';
			$request->{status}->{meta}->{errorstate}->{message} =
			  'invalid JSON passed in POST request';
		} else {
			if ( $request->{data}->{debug} ) {
				$request->{meta}->{debug} = $request->{data}->{debug};
			}
			if ( $request->{data}->{dryrun} ) {
				$request->{meta}->{debug} = $request->{data}->{dryrun};
			}
		}
	} else {
		$request->{data} = {};
		if ( my $cgi = new CGI($r) ) {
			foreach my $p ( $cgi->param() ) {
				$request->{data}->{$p} = $cgi->param($p);
			}
		}
	}

	if ( !$request->{data}->{command} ) {
		$request->{data}->{command} = $path;
	}

	if (   !$request->{data}->{command}
		|| !length( $request->{data}->{command} ) )
	{
		$request->{status}->{meta}->{errorstate}->{status} = 'reject';
		$request->{status}->{meta}->{errorstate}->{message} =
		  'no command given';
	}

	return !exists( $request->{status}->{meta}->{errorstate} );
}

1;
