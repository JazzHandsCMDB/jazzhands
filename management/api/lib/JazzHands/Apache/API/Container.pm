package JazzHands::Apache::API::Container;
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

my $handler_map = {
	add_container             => \&add_container,
	remove_container          => \&remove_container,
	assign_container_netblock => \&assign_container_netblock
};

sub handler {
	#
	# Request handle
	#
	my $r = shift;

	my $request = {};
	InitializeRequest( request => $request, handle => $r )
	  || return ReturnError($request);

	#
	# This is needed for Apache::DBI
	#
	Apache2::RequestUtil->request($r);

	my $response = { status => undef };

	my $json = JSON->new;
	$json->allow_blessed(1);

	###
	### Validate the request
	###
	$r->content_type('application/json');
	if ( $r->method ne 'POST' ) {
		$response->{status}    = 'error',
		  $response->{message} = 'must present JSON data in a POST request';
		$r->print( $json->encode($response) );
		$r->log_error('not a POST request');
		return Apache2::Const::OK();
	}

	$r->subprocess_env;

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

	if ( !exists( $handler_map->{ $request->{data}->{command} } ) ) {
		$request->{status}->{meta}->{errorstate}->{status} = 'reject';
		$request->{status}->{meta}->{errorstate}->{message} =
		  sprintf( 'invalid command "%s"', $request->{data}->{command} );
	}

	if ( defined( $response->{status} ) ) {
		$r->print( $json->encode($response) );
		$r->log_error( $response->{message}, ' in request from ', $client_ip );
		return Apache2::Const::OK();
	}

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

	# XXX - this needs to be converted to ReturnError() better
	$admin = CheckAdmin( $request, 'ContainerAdmin', 'API', $user )
	  || return ReturnError($request);

	$r->log_rerror(
		Apache2::Log::LOG_MARK,
		Apache2::Const::LOG_INFO,
		APR::Const::SUCCESS,
		sprintf(
			'%s request from admin user %s from %s',
			$request->{data}->{command},
			$user, $client_ip
		)
	);
	if ($admin) {
		if ( $request->{force} ) {
			$request->{meta}->{force} = 1;
		}
	}

	$handler_map->{ $request->{data}->{command} }->(
		dbh      => $request->{meta}->{dbh},
		request  => $request,
		response => $response
	);

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

	return Apache2::Const::OK();
}

sub add_container {
	my $opt = &_options(@_);

	my $dbh      = $opt->{dbh};
	my $request  = $opt->{request}->{data};
	my $r        = $opt->{request}->{handle};
	my $response = $opt->{response};
	my $meta     = $opt->{request}->{meta};

	my $error;
	##
	## Validate that the request is okay
	##
	if (   !$request->{device_name}
		|| !$request->{parent_device_id}
		|| !$request->{ip_address} )
	{
		$response->{status} = 'reject';
		$response->{message} =
		  "request must include device_name, parent_device_id, and ip_address";

		$r->log_rerror(
			Apache2::Log::LOG_MARK, Apache2::Const::LOG_ERR,
			APR::Const::SUCCESS,    'Bad Request: ' . $response->{message}
		);
		return undef;
	}

	if ( $request->{parent_device_id} !~ /^\d+$/ ) {
		$response->{status}  = 'reject';
		$response->{message} = "parent_device_id must be numeric";

		$r->log_rerror(
			Apache2::Log::LOG_MARK, Apache2::Const::LOG_ERR,
			APR::Const::SUCCESS,    'Bad Request: ' . $response->{message}
		);
		return undef;
	}

	my $ip_address;
	eval { $ip_address = NetAddr::IP->new( $request->{ip_address} ); };

	if ( !$ip_address ) {
		$response->{status} = 'reject';
		$response->{message} =
		  sprintf( "ip_address %s is not valid", $request->{ip_address} );

		$r->log_rerror(
			Apache2::Log::LOG_MARK, Apache2::Const::LOG_ERR,
			APR::Const::SUCCESS,    'Bad Request: ' . $response->{message}
		);
		return undef;
	}

	my $ret;
	##
	## This is a temporary hack until we do device_type_collections or the like
	##

	#
	# Validate that the parent is a physical server
	#
	if (
		!defined(
			$ret = runquery(
				description => 'validating parent device',
				request     => $r,
				debug       => $meta->{debug},
				dbh         => $dbh,
				allrows     => 1,
				query       => q {
			SELECT
				device_id
			FROM
				device_collection dc JOIN
				device_collection_device dcd USING (device_collection_id) JOIN
				device d USING (device_id)
			WHERE
				device_collection_type = 'device-function' AND
				device_collection_name = 'server' AND
				device_id = ?
		},
				args => [ $request->{parent_device_id} ]
			)
		)
	  )
	{
		$response->{status} = 'failure';
		return undef;
	}

	if ( !@$ret ) {
		$response->{status} = 'reject';
		$response->{message} =
		  sprintf( 'device_id %d may not be used as a container parent',
			$request->{parent_device_id} );
		$r->log_error(
			sprintf(
				'Rejecting %s request from %s: %s',
				$request->{command}, $meta->{client_ip},
				$response->{message}
			)
		);
		undef;
	}

	#
	# Validate that the device name to be inserted does not exist
	#
	if (
		!defined(
			$ret = runquery(
				description => 'validating child device',
				request     => $r,
				debug       => $meta->{debug},
				dbh         => $dbh,
				allrows     => 1,
				query       => q {
			SELECT
				device_id
			FROM
				device d
			WHERE
				device_name = ?
		},
				args => [ $request->{device_name} ]
			)
		)
	  )
	{
		$response->{status} = 'failure';
		return undef;
	}

	if (@$ret) {
		$response->{status}  = 'reject';
		$response->{message} = sprintf( 'device with name %s already exists',
			$request->{device_name} );
		$r->log_error(
			sprintf(
				'Rejecting %s request from %s: %s',
				$request->{command}, $meta->{client_ip},
				$response->{message}
			)
		);
		return undef;
	}

	#
	# Validate that the DNS name to be inserted does not exist
	#
	if (
		!defined(
			$ret = runquery(
				description => 'validating DNS name',
				request     => $r,
				debug       => $meta->{debug},
				dbh         => $dbh,
				allrows     => 1,
				query       => q {
			SELECT
				dns_record_id
			FROM
				dns_record dr JOIN
				dns_domain dd USING (dns_domain_id)
			WHERE
				concat_ws('.', dns_name, soa_name) = ?
		},
				args => [ $request->{device_name} ]
			)
		)
	  )
	{
		$response->{status} = 'failure';
		return undef;
	}

	if (@$ret) {
		$response->{status}  = 'reject';
		$response->{message} = sprintf( 'DNS record for name %s already exists',
			$request->{device_name} );
		$r->log_error(
			sprintf(
				'Rejecting %s request from %s: %s',
				$request->{command}, $meta->{client_ip},
				$response->{message}
			)
		);
		return undef;
	}

	#
	# Validate that the DNS domain for what we are trying to insert
	# is valid
	#
	if (
		!defined(
			$ret = runquery(
				description => 'validating DNS domain',
				request     => $r,
				debug       => $meta->{debug},
				dbh         => $dbh,
				allrows     => 1,
				query       => q {
			SELECT
				*
			FROM
				dns_utils.find_dns_domain(?)
		},
				args => [ $request->{device_name} ]
			)
		)
	  )
	{
		$response->{status} = 'failure';
		return undef;
	}

	if ( !@$ret ) {
		$response->{status} = 'reject';
		$response->{message} =
		  sprintf( 'no DNS domain exists for %s', $request->{device_name} );
		$r->log_error(
			sprintf(
				'Rejecting %s request from %s: %s',
				$request->{command}, $meta->{client_ip},
				$response->{message}
			)
		);
		return undef;
	}

	#
	# Validate that the IP address passed is free
	#

	if (
		!defined(
			$ret = runquery(
				description => 'validating IP address',
				request     => $r,
				debug       => $meta->{debug},
				dbh         => $dbh,
				return_type => 'hashref',
				query       => q {
			SELECT
				netblock_id,
				netblock_status
			FROM
				netblock n
			WHERE
				ip_universe_id = 0 AND
				netblock_type = 'default' AND
				host(ip_address) = ?
		},
				args => [ $ip_address->addr ]
			)
		)
	  )
	{
		$response->{status} = 'failure';
		return undef;
	}

	if ( %$ret && $ret->{netblock_status} ne 'Reserved' ) {
		$response->{status} = 'reject';
		$response->{message} =
		  sprintf( 'IP address %s already exists', $ip_address->addr );
		$r->log_error(
			sprintf(
				'Rejecting %s request from %s: %s',
				$request->{command}, $meta->{client_ip},
				$response->{message}
			)
		);
		return undef;
	}

	##
	## If we get here, everything should be okay to insert
	##

	if ( !$request->{container_type} ) {
		$request->{container_type} = 'Docker container';
	}

	#
	# If the netblock exists, then we want to set it to Allocated, otherwise
	# insert a new one
	#
	if (%$ret) {
		$r->log_rerror(
			Apache2::Log::LOG_MARK,
			Apache2::Const::LOG_DEBUG,
			APR::Const::SUCCESS,
			sprintf(
				"IP address %s was found with %s netblock %d",
				$ip_address->addr, $ret->{netblock_status},
				$ret->{netblock_id}
			)
		);

		#
		# Validate that the IP address passed is free
		#

		if (
			!defined(
				runquery(
					description => 'validating IP address',
					request     => $r,
					debug       => $meta->{debug},
					dbh         => $dbh,
					return_type => 'hashref',
					query       => q {
				DELETE FROM
					dns_record
				WHERE
					netblock_id = ?
			},
					args => [ $ret->{netblock_id} ]
				)
			)
		  )
		{
			$response->{status} = 'failure';
			return undef;
		}
	}
	my $netblock_handling = %$ret
	  ? q {
				UPDATE
					netblock n
				SET
					netblock_status = 'Allocated'
				FROM
					vals
				WHERE
					host(n.ip_address) = host(vals.ip_address) AND
					netblock_type = 'default' AND
					ip_universe_id = 0
				RETURNING *
		}
	  : q {
				INSERT INTO netblock (
					ip_address,
					netblock_type,
					ip_universe_id,
					is_single_address,
					can_subnet,
					netblock_status
				) SELECT
					vals.ip_address,
					'default',
					0,
					'Y',
					'N',
					'Allocated'
				FROM
					vals
				RETURNING *
		};

	if (
		!defined(
			$ret = runquery(
				description => 'inserting container device',
				request     => $r,
				debug       => $meta->{debug},
				dbh         => $dbh,
				return_type => 'hashref',
				query       => sprintf(
					q {
			WITH vals AS (
				SELECT
					?::text AS device_name,
					?::integer AS parent_device_id,
					?::inet AS ip_address,
					?::text AS container_type
			), nb_ins AS (%s),
			dev_ins AS (
				INSERT INTO device (
					device_type_id,
					device_name,
					site_code,
					parent_device_id,
					device_status,
					service_environment_id,
					is_virtual_device,
					is_monitored
				) SELECT
					dt.device_type_id,
					vals.device_name,
					d.site_code,
					vals.parent_device_id,
					'up',
					d.service_environment_id,
					'Y',
					'N'
				FROM
					vals,
					device d,
					device_type dt
				WHERE
					d.device_id = vals.parent_device_id AND
					dt.device_type_name = vals.container_type
				RETURNING *
			), ni_ins AS (
				INSERT INTO network_interface (
					device_id,
					network_interface_name,
					netblock_id,
					network_interface_type,
					should_monitor
				) SELECT
					dev_ins.device_id,
					'eth0',
					nb_ins.netblock_id,
					'broadcast',
					'N'
				FROM
					dev_ins,
					nb_ins
			), dns_ins AS (
				INSERT INTO dns_record (
					dns_name,
					dns_domain_id,
					dns_type,
					netblock_id
				) SELECT
					fd.dns_name,
					fd.dns_domain_id,
					'A',
					nb_ins.netblock_id
				FROM
					nb_ins,
					dns_utils.find_dns_domain(fqdn := (
						SELECT device_name FROM vals)
					) fd
			) SELECT
				dev_ins.device_id,
				dev_ins.site_code,
				se.service_environment_name,
				p.device_name AS parent_device_name
			FROM
				dev_ins JOIN
				service_environment se USING (service_environment_id) JOIN
				device p ON (p.device_id = dev_ins.parent_device_id)
		}, $netblock_handling
				),
				args => [
					$request->{device_name}, $request->{parent_device_id},
					$ip_address->addr,       $request->{container_type}
				]
			)
		)
	  )
	{
		$response->{status} = 'failure';
		return undef;
	}

	if ( !$ret ) {
		$response->{status}  = 'failure';
		$response->{message} = 'error inserting container device';
		$r->log_error(
			sprintf(
				'Rejecting %s request from %s: %s',
				$request->{command}, $meta->{client_ip},
				$response->{message}
			)
		);
		return undef;
	}

	$r->log_rerror(
		Apache2::Log::LOG_MARK,
		Apache2::Const::LOG_INFO,
		APR::Const::SUCCESS,
		sprintf(
			'Inserted container %s as device_id %d onto parent device %d (%s), site %s, service environment %s',
			$request->{device_name},      $ret->{device_id},
			$request->{parent_device_id}, $ret->{parent_device_name},
			$ret->{site_code},            $ret->{service_environment_name}
		)
	);

	$response->{status}    = 'success';
	$response->{device_id} = $ret->{device_id};

	return Apache2::Const::OK();
}

sub remove_container {
	my $opt = &_options(@_);

	my $dbh      = $opt->{dbh};
	my $request  = $opt->{request}->{data};
	my $r        = $opt->{request}->{handle};
	my $response = $opt->{response};
	my $meta     = $opt->{request}->{meta};

	my $error;
	##
	## Validate that the request is okay
	##
	if ( !$request->{device_id} ) {
		$response->{status}  = 'reject';
		$response->{message} = "request must include device_id";

		$r->log_rerror(
			Apache2::Log::LOG_MARK, Apache2::Const::LOG_ERR,
			APR::Const::SUCCESS,    'Bad Request: ' . $response->{message}
		);
		return undef;
	}

	if ( $request->{device_id} !~ /^\d+$/ ) {
		$response->{status}  = 'reject';
		$response->{message} = "device_id must be numeric";

		$r->log_rerror(
			Apache2::Log::LOG_MARK, Apache2::Const::LOG_ERR,
			APR::Const::SUCCESS,    'Bad Request: ' . $response->{message}
		);
		return undef;
	}

	my $ret;
	##
	## This is a temporary hack until we do device_type_collections or the like
	##

	#
	# Validate that the device is a container device
	#
	if (
		!defined(
			$ret = runquery(
				description => 'validating container device',
				request     => $r,
				debug       => $meta->{debug},
				dbh         => $dbh,
				allrows     => 1,
				query       => q {
			SELECT
				device_id
			FROM
				device d JOIN
				device_type USING (device_type_id)
			WHERE
				device_type_name = 'Docker container' AND
				device_id = ?
		},
				args => [ $request->{device_id} ]
			)
		)
	  )
	{
		$response->{status} = 'failure';
		return undef;
	}

	if ( !@$ret ) {
		$response->{status} = 'reject';
		$response->{message} =
		  sprintf( 'device_id %d is not a docker container',
			$request->{device_id} );
		$r->log_error(
			sprintf(
				'Rejecting %s request from %s: %s',
				$request->{command}, $meta->{client_ip},
				$response->{message}
			)
		);
		undef;
	}

	##
	## If we get here, everything should be okay to delete
	##

	my $netblock_handling = $request->{remove_netblock}
	  ? q {
				DELETE FROM
					netblock
				WHERE
					netblock_id IN (SELECT netblock_id FROM nb_ids)
		}
	  : q{
				UPDATE
					netblock n
				SET
					netblock_status = 'Reserved'
				FROM
					nb_ids
				WHERE
					n.netblock_id = nb_ids.netblock_id
		};

	if (
		!defined(
			$ret = runquery(
				description => 'deleting container device',
				request     => $r,
				debug       => $meta->{debug},
				dbh         => $dbh,
				return_type => 'hashref',
				query       => sprintf(
					q {
			WITH vals AS (
				SELECT
					?::integer AS device_id
			), nb_ids AS (
				SELECT
					netblock_id
				FROM
					network_interface JOIN
					vals USING (device_id)
			), dns_del AS (
				DELETE FROM
					dns_record
				WHERE
					netblock_id IN (SELECT netblock_id FROM nb_ids)
			), nb_del AS (%s),
			ni_del AS (
				DELETE FROM
					network_interface
				WHERE
					device_id = (SELECT device_id FROM vals)
			), dc AS (
				SELECT
					device_collection_id
				FROM
					vals JOIN
					device_collection_device dcd USING (device_id) JOIN
					device_collection dc USING (device_collection_id)
				WHERE
					device_collection_type = 'per-device'
			), dcd_del AS (
				DELETE FROM
					device_collection_device
				WHERE
					device_id = (SELECT device_id FROM vals)
			)
			DELETE FROM
				device_collection
			WHERE
				device_collection_id = 
					(SELECT device_collection_id FROM dc)
		}, $netblock_handling
				),
				args => [ $request->{device_id}, ]
			)
		)
	  )
	{
		$response->{status} = 'failure';
		return undef;
	}

	if (
		!defined(
			$ret = runquery(
				description => 'deleting container device',
				request     => $r,
				debug       => $meta->{debug},
				dbh         => $dbh,
				return_type => 'hashref',
				query       => q {
			DELETE FROM
				device
			WHERE
				device_id = ?
			RETURNING *
		},
				args => [ $request->{device_id}, ]
			)
		)
	  )
	{
		$response->{status} = 'failure';
		return undef;
	}

	if ( !$ret ) {
		$response->{status}  = 'failure';
		$response->{message} = 'error deleting container device';
		$r->log_error(
			sprintf(
				'Rejecting %s request from %s: %s',
				$request->{command}, $meta->{client_ip},
				$response->{message}
			)
		);
		return undef;
	}

	$r->log_rerror(
		Apache2::Log::LOG_MARK,
		Apache2::Const::LOG_INFO,
		APR::Const::SUCCESS,
		sprintf(
			'Deleted container device_id %d (%s)',
			$ret->{device_id}, $ret->{device_name}
		)
	);

	$response->{status}    = 'success';
	$response->{device_id} = $ret->{device_id};

	return Apache2::Const::OK();
}

sub list_container_netblocks {
	my $opt = &_options(@_);

	my $dbh      = $opt->{dbh};
	my $request  = $opt->{request}->{data};
	my $r        = $opt->{request}->{handle};
	my $response = $opt->{response};
	my $meta     = $opt->{request}->{meta};

	my $error;
	##
	## Validate that the request is okay
	##
	if ( !$request->{assignment_status} ) {
		$request->{assignment_status} = 'assigned';
	}
	my $valid_status = [qw(assigned available pools)];
	if ( !( grep { $_ eq $request->{assignment_status} } @$valid_status ) ) {
		$response->{status} = 'reject';
		$response->{message} =
		  "assignment_status must be one of "
		  . join( ',', sort @$valid_status );

		$r->log_rerror(
			Apache2::Log::LOG_MARK, Apache2::Const::LOG_ERR,
			APR::Const::SUCCESS,    'Bad Request: ' . $response->{message}
		);
		return undef;
	}

	if ( $request->{assignment_status} ne 'assigned' && $request->{device_id} )
	{

		$response->{status} = 'reject';
		$response->{message} =
		  "assignment_status must be 'assigned' if device_id is set";

		$r->log_rerror(
			Apache2::Log::LOG_MARK, Apache2::Const::LOG_ERR,
			APR::Const::SUCCESS,    'Bad Request: ' . $response->{message}
		);
		return undef;
	}
	if ( $request->{device_id} && $request->{device_id} !~ /^\d+$/ ) {
		$response->{status}  = 'reject';
		$response->{message} = "device_id must be numeric";

		$r->log_rerror(
			Apache2::Log::LOG_MARK, Apache2::Const::LOG_ERR,
			APR::Const::SUCCESS,    'Bad Request: ' . $response->{message}
		);
		return undef;
	}

	return Apache2::Const::OK();
}

sub assign_container_netblock {
	my $opt = &_options(@_);

	my $dbh      = $opt->{dbh};
	my $request  = $opt->{request}->{data};
	my $r        = $opt->{request}->{handle};
	my $response = $opt->{response};
	my $meta     = $opt->{request}->{meta};

	my $error;
	##
	## Validate that the request is okay
	##
	if (   !$request->{device_id}
		|| !$request->{netblock_address} )
	{
		$response->{status} = 'reject';
		$response->{message} =
		  "request must include device_id and netblock_address";

		$r->log_rerror(
			Apache2::Log::LOG_MARK, Apache2::Const::LOG_ERR,
			APR::Const::SUCCESS,    'Bad Request: ' . $response->{message}
		);
		return undef;
	}

	if ( $request->{device_id} !~ /^\d+$/ ) {
		$response->{status}  = 'reject';
		$response->{message} = "device_id must be numeric";

		$r->log_rerror(
			Apache2::Log::LOG_MARK, Apache2::Const::LOG_ERR,
			APR::Const::SUCCESS,    'Bad Request: ' . $response->{message}
		);
		return undef;
	}

	my $netblock_address;
	eval {
		$netblock_address = NetAddr::IP->new( $request->{netblock_address} );
	};

	if ( !$netblock_address ) {
		$response->{status}  = 'reject';
		$response->{message} = sprintf( "netblock_address %s is not valid",
			$request->{netblock_address} );

		$r->log_rerror(
			Apache2::Log::LOG_MARK, Apache2::Const::LOG_ERR,
			APR::Const::SUCCESS,    'Bad Request: ' . $response->{message}
		);
		return undef;
	}

	my $ret;
	##
	## This is a temporary hack until we do device_type_collections or the like
	##

	#
	# Validate that the device_id is a physical server
	#
	if (
		!defined(
			$ret = runquery(
				description => 'validating parent device',
				request     => $r,
				debug       => $meta->{debug},
				dbh         => $dbh,
				allrows     => 1,
				query       => q {
			SELECT
				device_id
			FROM
				device_collection dc JOIN
				device_collection_device dcd USING (device_collection_id) JOIN
				device d USING (device_id)
			WHERE
				device_collection_type = 'device-function' AND
				device_collection_name = 'server' AND
				device_id = ?
		},
				args => [ $request->{device_id} ]
			)
		)
	  )
	{
		$response->{status} = 'failure';
		return undef;
	}

	if ( !@$ret ) {
		$response->{status} = 'reject';
		$response->{message} =
		  sprintf( 'device_id %d may not be used as a container host',
			$request->{device_id} );
		$r->log_error(
			sprintf(
				'Rejecting %s request from %s: %s',
				$request->{command}, $meta->{client_ip},
				$response->{message}
			)
		);
		undef;
	}

	#
	# Validate that the netblock passed is valid to be used to house containers
	#
	if (
		!defined(
			$ret = runquery(
				description => 'validating container netblock status',
				request     => $r,
				debug       => $meta->{debug},
				dbh         => $dbh,
				allrows     => 1,
				query       => q {
			SELECT
				netblock_id
			FROM
				layer3_network_collection l3c JOIN
				l3_network_coll_l3_network l3ncn USING
					(layer3_network_collection_id) JOIN
				layer3_network l3n USING (layer3_network_id) JOIN
				netblock USING (netblock_id)
			WHERE
				(layer3_network_collection_name, 
					layer3_network_collection_type) = 
					('ValidLayer3Networks', 'ContainerManagement') AND
				ip_address >> ?::inet
		},
				args => [$netblock_address]
			)
		)
	  )
	{
		$response->{status} = 'failure';
		return undef;
	}

	if ( !@$ret ) {
		$response->{status} = 'reject';
		$response->{message} =
		  sprintf( '%s is not part of a container manageable network',
			$netblock_address );
		$r->log_error(
			sprintf(
				'Rejecting %s request from %s: %s',
				$request->{command}, $meta->{client_ip},
				$response->{message}
			)
		);
		return undef;
	}

	#
	# Validate that all of the netblocks in the address block given either
	# are already allocated to a network_range for this device, they are
	# Reserved and not assigned to any other device, or don't exist
	#

	return Apache2::Const::OK();
}

1;

