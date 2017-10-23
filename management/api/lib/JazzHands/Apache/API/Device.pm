package JazzHands::Apache::API::Device;
use strict;

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();
use Apache2::Connection ();
use Apache2::Log ();
use Apache2::Const -compile => qw(:common :log);
use APR::Table;
use APR::Const -compile => qw(:error SUCCESS);

use JazzHands::Common qw(:all);
use JazzHands::Apache::API::Common qw(:all);
use JazzHands::DBI;
use JazzHands::AppAuthAL;
use NetAddr::IP;
use DBI;
use JSON;

use Data::Dumper;

my $handler_map = {
	network => \&network,
};

sub handler {
	#
	# Request handle
	#
	my $r = shift;
	
	#
	# Admin is set if the remote side authenticates with a principal that
	# is associated with an administrator
	#
	my $admin = 0;

	#
	# force can be passsed by an administrator to override some functions
	# that would normally be disallowed.
	#
	my $force = 0;

	#
	# Debug can be requested by the client side to spew lots of things into
	# the logs (some of which are returned to the client)
	#
	my $debug = 0;

	#
	# Dry run can be requested by the client side to roll back the transaction
	#
	my $dryrun = 0;

	my $authapp = 'jazzhands-api';

	$r->content_type('application/json');
	my $json = JSON->new;
	$json->allow_blessed(1);

	#
	# This is needed for Apache::DBI
	#
	Apache2::RequestUtil->request($r);

	my $response = {
		status => undef
	};

	###
	### Validate the request
	###

	#
	# These things changed between Apache 2.2 and 2.4, so one of these
	# should work
	#
	my $client_ip;
	eval {
		$client_ip = $r->connection->client_ip;
	};
	if (!$client_ip) {
		eval {
			$client_ip = $r->connection->remote_ip;
		};
	}
	if ($r->method ne 'GET') {
		$response->{status} = 'error',
		$response->{message} = 'must present JSON data in a POST request';
		$r->print($json->encode($response));
		$r->log_error('not a POST request');
		return Apache2::Const::OK;
	}

	my $headers = $r->headers_in;
	$r->subprocess_env;

	my $json_data;
#	if($r->headers_in->{'Content-Length'}) {
#		$r->read($json_data, $r->headers_in->{'Content-Length'});
#	}

	my $request = {
		handle => $r,
		meta => {
			client_ip => $client_ip
		},
	};
#	eval { $request->{data} = $json->decode($json_data) };
#	if (!defined($request->{data})) {
#		$response->{status} = 'error';
#		$response->{message} = 'invalid JSON passed in POST request';
#	} elsif (!defined($request->{data}->{command}) ) {
#		$response->{status} = 'reject';
#		$response->{message} = 'no command given';
#	} elsif (!exists($handler_map->{$request->{data}->{command}})) {
#		$response->{status} = 'reject';
#		$response->{message} = sprintf('invalid command "%s"',
#			$request->{data}->{command});
#	}
#	
#	if ($request->{data}->{debug}) {
#		$debug = $request->{data}->{debug};
#	}
#	$request->{meta}->{debug} = $debug;
#	if ($request->{data}->{dryrun}) {
#		$dryrun = $request->{data}->{dryrun};
#	}
#
#	if (defined($response->{status})) {
#		$r->print($json->encode($response));
#		$r->log_error($response->{message}, ' in request from ',
#			$client_ip);
#		return Apache2::Const::OK;
#	}

	$r->log_rerror(
		Apache2::Log::LOG_MARK,
		Apache2::Const::LOG_NOTICE,
		APR::Const::SUCCESS,
		sprintf("Received %s request from %s",
			$request->{data}->{command},
			$client_ip
		)
	);

	my @errors;
	my $jhdbi = JazzHands::DBI->new;
	my $dbh = $jhdbi->connect_cached(
		application => $authapp,
		dbiflags => { AutoCommit => 0, PrintError => 0 },
		errors => \@errors
	);
	if (!$dbh) {
		$response->{status} = 'error';
		$response->{message} = 'error connecting to database';
		$r->print($json->encode($response));
		$r->log_error($response->{message} . ': ' . $JazzHands::DBI::errstr .
			", APPAUTHAL_CONFIG=" . $ENV{APPAUTHAL_CONFIG});
		 
		return Apache2::Const::OK;
	};

	$jhdbi->set_session_user('jazzhands-api');

	$dbh->do('set constraints all deferred');
#	$dbh->do('set client_min_messages = debug');

	my $ret;

	###
	### the principal must either be a valid user or a host principal
	###

	my $user = $ENV{REMOTE_USER} || 'host/01.dns-recurse.nym2.appnexus.net';

	#
	# We need to check for valid authentication realms here, but things
	# are not completely set up for that at this point.  Also, this should
	# move to its own authentication module
	#
	$user =~ s/@.*$//;
	$jhdbi->set_session_user('jazzhands-api/' . $user);
	$request->{meta}->{user} = $user;

	if ($debug) {
		$r->log_rerror(
			Apache2::Log::LOG_MARK,
			Apache2::Const::LOG_DEBUG,
			APR::Const::SUCCESS,
			sprintf(
				'Validating API user: %s',
				$user
			)
		);
	}

	my $host;
	if($user =~ m,^host/(.+)$,) {
		$host = $1;
	} else {
		if (!defined($ret = runquery(
			description => 'validating API user',
			request => $r,
			debug => $debug,
			dbh => $dbh,
			allrows => 1,
			query => q {
				SELECT
					login
				FROM
					property p JOIN
					account_collection ac ON
						(p.property_value_account_coll_id =
						ac.account_collection_id) JOIN
					v_acct_coll_acct_expanded acae ON
						(ac.account_collection_id =
						acae.account_collection_id) JOIN
					account a ON
						(acae.account_id = a.account_id)
					WHERE
						(property_name, property_type) =
							('ContainerAdmin', 'API') AND
						login = ?
			},
			args => [
				$user
			]
		))) {
			return Apache2::Const::OK;
		}
	
		if (@$ret) {
			if ($debug) {
				$r->log_rerror(
					Apache2::Log::LOG_MARK,
					Apache2::Const::LOG_DEBUG,
					APR::Const::SUCCESS,
					sprintf(
						'User %s is authorized to run API for containers',
						$user
					)
				);
			}
			$admin = 1;
			$request->{meta}->{admin} = 1;
		} else {
			$response->{status} = 'reject';
			$response->{message} =
				sprintf('User %s is not allowed to administer containers',
					$user);
			$r->log_error(
				sprintf(
					'Rejecting %s request from %s: %s',
					$request->{data}->{command},
					$client_ip,
					$response->{message}
				)
			);
			$r->print($json->encode($response));
			return Apache2::Const::OK;
		}
	
		$r->log_rerror(
			Apache2::Log::LOG_MARK,
			Apache2::Const::LOG_INFO,
			APR::Const::SUCCESS,
			sprintf(
				'%s request from admin user %s from %s',
				$request->{data}->{command},
				$user,
				$client_ip
			)
			);

		if ($admin) {
			if ($request->{force}) {
				$request->{meta}->{force} = 1;
			}
		}
	}

	my $path = $r->path_info();
	$path =~ m,^/device(/(.+$)),;
	my $command = $2;

	$request->{data}->{device_name} = $host;

	if(!$command) {
		$response->{status} = 'error';
		$response->{message} = 'Unspecified command';
	} else {
		if(! exists($handler_map->{$command}) ) {
			$response->{status} = 'error';
			$response->{message} = 'Invalid command $command';
		} else {
			$handler_map->{$command}->(
				dbh => $dbh,
				request => $request,
				response => $response
			);
		}
	}

DONE:

	if (!$response->{status} || $response->{status} ne 'success') {
		$r->log_rerror(
			Apache2::Log::LOG_MARK,
			Apache2::Const::LOG_ERR,
			APR::Const::SUCCESS,
			"Rolling back transaction on error"
			);
		if (!($dbh->rollback)) {
			$r->log_rerror(
				Apache2::Log::LOG_MARK,
				Apache2::Const::LOG_ERR,
				APR::Const::SUCCESS,
				sprintf("Error rolling back transaction: %s", $dbh->errstr)
				);
		}
	}
	if ($dryrun) {
		$r->log_rerror(
			Apache2::Log::LOG_MARK,
			Apache2::Const::LOG_INFO,
			APR::Const::SUCCESS,
			"Dry run requested.  Rolling back database transaction"
			);
		if (!($dbh->rollback)) {
			$r->log_rerror(
				Apache2::Log::LOG_MARK,
				Apache2::Const::LOG_ERR,
				APR::Const::SUCCESS,
				sprintf("Error rolling back transaction: %s", $dbh->errstr)
				);
			$response->{status} = 'error';
			$response->{message} = sprintf(
				'Error committing database transaction.  See server log for transaction %d for details',
					$r->connection->id
			);
		}
	} else {
		$r->log_rerror(
			Apache2::Log::LOG_MARK,
			Apache2::Const::LOG_DEBUG,
			APR::Const::SUCCESS,
			sprintf("Committing database transaction for Apache request %d",
				$r->connection->id
			));
		if (!($dbh->commit)) {
			$r->log_rerror(
				Apache2::Log::LOG_MARK,
				Apache2::Const::LOG_ERR,
				APR::Const::SUCCESS,
				sprintf("Error committing transaction: %s", $dbh->errstr)
				);
			$response->{status} = 'error';
			$response->{message} = 'Error committing database transaction';
		}
	}

	$dbh->disconnect;

	$r->log_rerror(
		Apache2::Log::LOG_MARK,
		Apache2::Const::LOG_INFO,
		APR::Const::SUCCESS,
		sprintf(
			'Finished %s request',
			$request->{data}->{command},
		)
	);

	$r->print($json->encode($response));

	return Apache2::Const::OK;
}

sub network {
	my $opt = &_options(@_);

	my $dbh = $opt->{dbh};
	my $request = $opt->{request}->{data};
	my $r = $opt->{request}->{handle};
	my $response = $opt->{response};
	my $meta = $opt->{request}->{meta};

	my $error;
	##
	## Validate that the request is okay
	##
	if (
		!$request->{device_name} 
	) {
		$response->{status} = 'reject';
		$response->{message} = "request must include device_name";

		$r->log_rerror(
			Apache2::Log::LOG_MARK,
			Apache2::Const::LOG_ERR,
			APR::Const::SUCCESS,
			'Bad Request: ' . $response->{message}
		);
		return undef;
	}

	my $debug = 0;

	$response->{status} = 'reject';

	my $ret;
	if (!defined($ret = runquery(
		description => 'Retrieving layer3 interfaces',
		request => $r,
		debug => $debug,
		dbh => $dbh,
		allrows => 1,
		query => q {
			SELECT	to_json(array_agg(to_json(x) ORDER BY network_interface_id)) as data
			FROM (
			SELECT	network_interface_id,
				device_id,
				network_interface_name,
				network_interface_type,
				mac_addr,
				nb.agg as netblocks,
				snb.agg as shared_netblocks
			FROM	network_interface
				LEFT JOIN	( SELECT network_interface_id, 
							json_agg(json_build_object(
								'ip_address', ip_address, 
								'network_interface_rank', network_interface_rank
							) ORDER BY ip_address,network_interface_rank) as agg
					FROM network_interface_netblock 
						JOIN netblock USING (netblock_id)
					GROUP BY network_interface_id
				) nb USING (network_interface_id)
				LEFT JOIN	(
					SELECT network_interface_id, 
							json_agg(json_build_object(
								'shared netblock_id', shared_netblock_id,
								'shared_netblock_protocol', shared_netblock_protocol, 
								'ip_address', ip_address, 
								'priority', priority 
							) ORDER BY ip_address) as agg
					FROM	shared_netblock_network_int
						JOIN shared_netblock USING (shared_netblock_id)
						JOIN netblock USING (netblock_id)
					GROUP BY network_interface_id
				) snb  USING (network_interface_id)
			) x
			JOIN device d USING (device_id)
			WHERE	device_name = ?
		},
		args => [
			$request->{device_name}
		]
	))) {
		return Apache2::Const::OK;
	}
	
	my $json = JSON->new;
	$json->allow_blessed(1);

	$response->{status} = 'success';
	$response->{json} = $json->decode($ret->[0]->{data});

	return Apache2::Const::OK;
}


