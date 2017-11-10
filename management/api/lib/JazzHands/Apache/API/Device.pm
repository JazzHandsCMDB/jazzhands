package JazzHands::Apache::API::Device;
use strict;

use Apache2::RequestRec  ();
use Apache2::RequestIO   ();
use Apache2::RequestUtil ();
use Apache2::Connection  ();
use Apache2::Log         ();
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

my $handler_map = { network => \&network, };

sub handler {
	#
	# Request handle
	#
	my $r = shift;

	my $request = {};
	InitializeRequest( request => $request, handle => $r )
	  || return ReturnError($request);

	my $response = { status => undef };

	###
	### Validate the request
	###

	$r->content_type('application/json');
	my $json = JSON->new;
	$json->allow_blessed(1);

	$r->subprocess_env;

	# these next two need to be merged together.
	ProcessMessage($request) || return ReturnError($request);

	#
	# save some arguments passed from the message locally
	#
	my $admin     = $request->{meta}->{admin};
	my $force     = $request->{meta}->{force};
	my $debug     = $request->{meta}->{debug};
	my $dryrun    = $request->{meta}->{dryrun};
	my $client_ip = $request->{meta}->{client_ip};
	my $user      = $request->{meta}->{user};
	my $dbh       = $request->{meta}->{dbh};

	my $command = $request->{data}->{command};

	if ( $request->{meta}->{user_type} eq 'account' ) {
		$admin = CheckAdmin( $request, 'DeviceAdmin', 'API')
		  || return ReturnError($request);
	}

	#
	# Some arguments can be overriden by admins
	#
	if ( !$admin ) {
		if ( $request->{data}->{device_name} ) {
			$request->{status}->{meta}->{errorstate}->{message} =
			  sprintf( 'User %s is not authorized to set a device', $user );
			$r->log_error(
				sprintf(
					'Rejecting %s device_name request from %s: %s',
					$request->{data}->{command},
					$request->{meta}->{client_ip},
					$request->{status}->{meta}->{errorstate}->{message},
				)
			);
			return ReturnError($request);
		}
	}

	if ( !$request->{data}->{device_name} ) {
		$request->{data}->{device_name} = $request->{meta}->{device_name};
	}

	my $host = $request->{data}->{device_name};

	#
	# This is needed for Apache::DBI
	#
	Apache2::RequestUtil->request($r);

	$r->log_rerror(
		Apache2::Log::LOG_MARK,
		Apache2::Const::LOG_NOTICE,
		APR::Const::SUCCESS,
		sprintf(
			"Received %s request from %s",
			$request->{data}->{command}, $client_ip
		)
	);

	my $ret;

	###
	### the principal must either be a valid user or a host principal
	###

	if ($debug) {
		$r->log_rerror( Apache2::Log::LOG_MARK, Apache2::Const::LOG_DEBUG,
			APR::Const::SUCCESS, sprintf( 'Validating API user: %s', $user ) );
	}

	if ( !$command ) {
		$response->{status}  = 'error';
		$response->{message} = 'Unspecified command';
	} else {
		if ( !exists( $handler_map->{$command} ) ) {
			$response->{status}  = 'error';
			$response->{message} = "Invalid command $command";
		} else {
			$handler_map->{$command}->(
				dbh      => $dbh,
				request  => $request,
				response => $response
			) || return ReturnError($request);
		}
	}

  DONE:

	if ( !$response->{status} || $response->{status} ne 'success' ) {
		$r->log_rerror(
			Apache2::Log::LOG_MARK, Apache2::Const::LOG_ERR,
			APR::Const::SUCCESS,    "Rolling back transaction on error"
		);
		if ( !( $dbh->rollback ) ) {
			$r->log_rerror(
				Apache2::Log::LOG_MARK,
				Apache2::Const::LOG_ERR,
				APR::Const::SUCCESS,
				sprintf( "Error rolling back transaction: %s", $dbh->errstr )
			);
		}
	}
	if ($dryrun) {
		$r->log_rerror( Apache2::Log::LOG_MARK, Apache2::Const::LOG_INFO,
			APR::Const::SUCCESS,
			"Dry run requested.  Rolling back database transaction" );
		if ( !( $dbh->rollback ) ) {
			$r->log_rerror(
				Apache2::Log::LOG_MARK,
				Apache2::Const::LOG_ERR,
				APR::Const::SUCCESS,
				sprintf( "Error rolling back transaction: %s", $dbh->errstr )
			);
			$response->{status}  = 'error';
			$response->{message} = sprintf(
				'Error committing database transaction.  See server log for transaction %d for details',
				$r->connection->id );
		}
	} else {
		$r->log_rerror(
			Apache2::Log::LOG_MARK,
			Apache2::Const::LOG_DEBUG,
			APR::Const::SUCCESS,
			sprintf( "Committing database transaction for Apache request %d",
				$r->connection->id )
		);
		if ( !( $dbh->commit ) ) {
			$r->log_rerror(
				Apache2::Log::LOG_MARK,
				Apache2::Const::LOG_ERR,
				APR::Const::SUCCESS,
				sprintf( "Error committing transaction: %s", $dbh->errstr )
			);
			$response->{status}  = 'error';
			$response->{message} = 'Error committing database transaction';
		}
	}

	$dbh->disconnect;

	$r->log_rerror( Apache2::Log::LOG_MARK, Apache2::Const::LOG_INFO,
		APR::Const::SUCCESS,
		sprintf( 'Finished %s request', $request->{data}->{command}, ) );

	$r->print( $json->encode($response) );

	return Apache2::Const::OK;
}

sub network {
	my $opt = &_options(@_);

	my $dbh      = $opt->{dbh};
	my $request  = $opt->{request};
	my $data     = $opt->{request}->{data};
	my $r        = $opt->{request}->{handle};
	my $response = $opt->{response};
	my $meta     = $opt->{request}->{meta};

	my $error;
	##
	## Validate that the request is okay
	##
	if ( !$data->{device_name} ) {
		my $msg = "request must be for a specific device.";
		$request->{status}->{meta}->{errorstate}->{status} = "reject";
		$request->{status}->{meta}->{errorstate}->{message} =$msg;

		$r->log_rerror(
			Apache2::Log::LOG_MARK, Apache2::Const::LOG_ERR,
			APR::Const::SUCCESS,    'Bad Request: ' . $msg
		);
		return undef;
	}

	my $debug = 0;

	$response->{status} = 'reject';

	my $ret;
	if (
		!defined(
			$ret = runquery(
				description => 'Retrieving layer3 interfaces',
				request     => $r,
				debug       => $debug,
				dbh         => $dbh,
				allrows     => 1,
				query       => q {
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
				args => [ $data->{device_name} ]
			)
		)
	  )
	{
		$request->{status}->{meta}->{errorstate}->{message} =
		  "Database query failed.";
		return undef;
	}

	my $json = JSON->new;
	$json->allow_blessed(1);

	if ( !$ret->[0]->{data} ) {
		$request->{status}->{meta}->{errorstate}->{message} =
		  sprintf( "Unable to find information on %s", $data->{device_name} );
		return undef;
	}
	$response->{status} = 'success';
	$response->{json}   = $json->decode( $ret->[0]->{data} );

	1;
}

1;
