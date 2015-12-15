package JazzHands::API::Container;
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
use JazzHands::API::Common qw(:all);
use JazzHands::DBI;
use JazzHands::AppAuthAL;
use NetAddr::IP;
use DBI;
use JSON;

use Data::Dumper;

my $handler_map = {
	add_container => \&add_container,
	remove_container => \&remove_container
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
	if ($r->method ne 'POST') {
		$response->{status} = 'error',
		$response->{message} = 'must present JSON data in a POST request';
		$r->print($json->encode($response));
		$r->log_error('not a POST request');
		return Apache2::Const::OK;
	}

	my $headers = $r->headers_in;
	$r->subprocess_env;

	my $json_data;
	$r->read($json_data, $r->headers_in->{'Content-Length'});

	my $request = {
		handle => $r,
		meta => {
			client_ip => $client_ip
		},
	};
	eval { $request->{data} = $json->decode($json_data) };
	if (!defined($request->{data})) {
		$response->{status} = 'error';
		$response->{message} = 'invalid JSON passed in POST request';
	} elsif (!defined($request->{data}->{command}) ) {
		$response->{status} = 'reject';
		$response->{message} = 'no command given';
	} elsif (!exists($handler_map->{$request->{data}->{command}})) {
		$response->{status} = 'reject';
		$response->{message} = sprintf('invalid command "%s"',
			$request->{data}->{command});
	}
	
	if ($request->{data}->{debug}) {
		$debug = $request->{data}->{debug};
	}
	$request->{meta}->{debug} = $debug;
	if ($request->{data}->{dryrun}) {
		$dryrun = $request->{data}->{dryrun};
	}

	if (defined($response->{status})) {
		$r->print($json->encode($response));
		$r->log_error($response->{message}, ' in request from ',
			$client_ip);
		return Apache2::Const::OK;
	}

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
	### the principal must be a valid admin user.
	###

	my $user = $ENV{REMOTE_USER} || '';

	##
	## Remove this before production stuffs
	##
	if (!$user && ($client_ip eq '127.0.0.1' || $client_ip eq '::1')) {
		$user = 'mdr';
	}

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

	$handler_map->{$request->{data}->{command}}->(
		dbh => $dbh,
		request => $request,
		response => $response
	);
	
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

sub add_container {
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
		!$request->{device_name} ||
		!$request->{parent_device_id} ||
		!$request->{ip_address}
	) {
		$response->{status} = 'reject';
		$response->{message} = "request must include device_name, parent_device_id, and ip_address";

		$r->log_rerror(
			Apache2::Log::LOG_MARK,
			Apache2::Const::LOG_ERR,
			APR::Const::SUCCESS,
			'Bad Request: ' . $response->{message}
		);
		return undef;
	}

	if (
		$request->{parent_device_id} !~ /^\d+$/
	) {
		$response->{status} = 'reject';
		$response->{message} = "parent_device_id must be numeric";

		$r->log_rerror(
			Apache2::Log::LOG_MARK,
			Apache2::Const::LOG_ERR,
			APR::Const::SUCCESS,
			'Bad Request: ' . $response->{message}
		);
		return undef;
	}
	
	my $ip_address;
	eval {
		$ip_address = NetAddr::IP->new($request->{ip_address});
	};

	if (!$ip_address) {
		$response->{status} = 'reject';
		$response->{message} = sprintf("ip_address %s is not valid",
			$request->{ip_address});

		$r->log_rerror(
			Apache2::Log::LOG_MARK,
			Apache2::Const::LOG_ERR,
			APR::Const::SUCCESS,
			'Bad Request: ' . $response->{message}
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
	if (!defined($ret = runquery(
		description => 'validating parent device',
		request => $r,
		debug => $meta->{debug},
		dbh => $dbh,
		allrows => 1,
		query => q {
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
		args => [
			$request->{parent_device_id}
		]
	))) {
		$response->{status} = 'failure';
		return undef;
	}

	if (!@$ret) {
		$response->{status} = 'reject';
		$response->{message} =
			sprintf('device_id %d may not be used as a container parent',
				$request->{parent_device_id});
		$r->log_error(
			sprintf(
				'Rejecting %s request from %s: %s',
				$request->{command},
				$meta->{client_ip},
				$response->{message}
			)
		);
		undef;
	}

	#
	# Validate that the device name to be inserted does not exist
	#
	if (!defined($ret = runquery(
		description => 'validating child device',
		request => $r,
		debug => $meta->{debug},
		dbh => $dbh,
		allrows => 1,
		query => q {
			SELECT
				device_id
			FROM
				device d
			WHERE
				device_name = ?
		},
		args => [
			$request->{device_name}
		]
	))) {
		$response->{status} = 'failure';
		return undef;
	}

	if (@$ret) {
		$response->{status} = 'reject';
		$response->{message} =
			sprintf('device with name %s already exists',
				$request->{device_name});
		$r->log_error(
			sprintf(
				'Rejecting %s request from %s: %s',
				$request->{command},
				$meta->{client_ip},
				$response->{message}
			)
		);
		return undef;
	}

	#
	# Validate that the DNS name to be inserted does not exist
	#
	if (!defined($ret = runquery(
		description => 'validating DNS name',
		request => $r,
		debug => $meta->{debug},
		dbh => $dbh,
		allrows => 1,
		query => q {
			SELECT
				dns_record_id
			FROM
				dns_record dr JOIN
				dns_domain dd USING (dns_domain_id)
			WHERE
				concat_ws('.', dns_name, soa_name) = ?
		},
		args => [
			$request->{device_name}
		]
	))) {
		$response->{status} = 'failure';
		return undef;
	}

	if (@$ret) {
		$response->{status} = 'reject';
		$response->{message} =
			sprintf('DNS record for name %s already exists',
				$request->{device_name});
		$r->log_error(
			sprintf(
				'Rejecting %s request from %s: %s',
				$request->{command},
				$meta->{client_ip},
				$response->{message}
			)
		);
		return undef;
	}

	#
	# Validate that the DNS domain for what we are trying to insert
	# is valid
	#
	if (!defined($ret = runquery(
		description => 'validating DNS domain',
		request => $r,
		debug => $meta->{debug},
		dbh => $dbh,
		allrows => 1,
		query => q {
			SELECT
				*
			FROM
				dns_utils.find_dns_domain(?)
		},
		args => [
			$request->{device_name}
		]
	))) {
		$response->{status} = 'failure';
		return undef;
	}

	if (!@$ret) {
		$response->{status} = 'reject';
		$response->{message} =
			sprintf('no DNS domain exists for %s',
				$request->{device_name});
		$r->log_error(
			sprintf(
				'Rejecting %s request from %s: %s',
				$request->{command},
				$meta->{client_ip},
				$response->{message}
			)
		);
		return undef;
	}

	#
	# Validate that the IP address passed is free
	#

	if (!defined($ret = runquery(
		description => 'validating IP address',
		request => $r,
		debug => $meta->{debug},
		dbh => $dbh,
		allrows => 1,
		query => q {
			SELECT
				netblock_id
			FROM
				netblock n
			WHERE
				ip_universe_id = 0 AND
				netblock_type = 'default' AND
				host(ip_address) = ?
		},
		args => [
			$ip_address->addr
		]
	))) {
		$response->{status} = 'failure';
		return undef;
	}

	if (@$ret) {
		$response->{status} = 'reject';
		$response->{message} =
			sprintf('IP address %s already exists',
				$ip_address->addr);
		$r->log_error(
			sprintf(
				'Rejecting %s request from %s: %s',
				$request->{command},
				$meta->{client_ip},
				$response->{message}
			)
		);
		return undef;
	}

	##
	## If we get here, everything should be okay to insert
	##

	if (!$request->{container_type}) {
		$request->{container_type} = 'Docker container';
	}

	#
	# Validate that the IP address passed is free
	#

	if (!defined($ret = runquery(
		description => 'inserting container device',
		request => $r,
		debug => $meta->{debug},
		dbh => $dbh,
		return_type => 'hashref',
		query => q {
			WITH vals AS (
				SELECT
					?::text AS device_name,
					?::integer AS parent_device_id,
					?::inet AS ip_address,
					?::text AS container_type
			), nb_ins AS (
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
			), dev_ins AS (
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
		},
		args => [
			$request->{device_name},
			$request->{parent_device_id},
			$ip_address->addr,
			$request->{container_type}
		]
	))) {
		$response->{status} = 'failure';
		return undef;
	}

	if (!$ret) {
		$response->{status} = 'failure';
		$response->{message} = 'error inserting container device';
		$r->log_error(
			sprintf(
				'Rejecting %s request from %s: %s',
				$request->{command},
				$meta->{client_ip},
				$response->{message}
			)
		);
		return undef;
	}

	$r->log_rerror(
		Apache2::Log::LOG_MARK,
		Apache2::Const::LOG_INFO,
		APR::Const::SUCCESS,
		sprintf('Inserted container %s as device_id %d onto parent device %d (%s), site %s, service environment %s',
			$request->{device_name},
			$ret->{device_id},
			$request->{parent_device_id},
			$ret->{parent_device_name},
			$ret->{site_code},
			$ret->{service_environment_name})
	);

	$response->{status} = 'success';
	$response->{device_id} = $ret->{device_id};

	return Apache2::Const::OK;
}


sub remove_container {
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
	if (!$request->{device_id}) {
		$response->{status} = 'reject';
		$response->{message} = "request must include device_id";

		$r->log_rerror(
			Apache2::Log::LOG_MARK,
			Apache2::Const::LOG_ERR,
			APR::Const::SUCCESS,
			'Bad Request: ' . $response->{message}
		);
		return undef;
	}

	if (
		$request->{device_id} !~ /^\d+$/
	) {
		$response->{status} = 'reject';
		$response->{message} = "device_id must be numeric";

		$r->log_rerror(
			Apache2::Log::LOG_MARK,
			Apache2::Const::LOG_ERR,
			APR::Const::SUCCESS,
			'Bad Request: ' . $response->{message}
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
	if (!defined($ret = runquery(
		description => 'validating container device',
		request => $r,
		debug => $meta->{debug},
		dbh => $dbh,
		allrows => 1,
		query => q {
			SELECT
				device_id
			FROM
				device d JOIN
				device_type USING (device_type_id)
			WHERE
				device_type_name = 'Docker container' AND
				device_id = ?
		},
		args => [
			$request->{device_id}
		]
	))) {
		$response->{status} = 'failure';
		return undef;
	}

	if (!@$ret) {
		$response->{status} = 'reject';
		$response->{message} =
			sprintf('device_id %d is not a docker container',
				$request->{device_id});
		$r->log_error(
			sprintf(
				'Rejecting %s request from %s: %s',
				$request->{command},
				$meta->{client_ip},
				$response->{message}
			)
		);
		undef;
	}

	##
	## If we get here, everything should be okay to delete
	##

	if (!$request->{container_type}) {
		$request->{container_type} = 'Docker container';
	}

	if (!defined($ret = runquery(
		description => 'deleting container device',
		request => $r,
		debug => $meta->{debug},
		dbh => $dbh,
		return_type => 'hashref',
		query => q {
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
			), nb_del AS (
				DELETE FROM
					netblock
				WHERE
					netblock_id IN (SELECT netblock_id FROM nb_ids)
			), ni_del AS (
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
		},
		args => [
			$request->{device_id},
		]
	))) {
		$response->{status} = 'failure';
		return undef;
	}

	if (!defined($ret = runquery(
		description => 'deleting container device',
		request => $r,
		debug => $meta->{debug},
		dbh => $dbh,
		return_type => 'hashref',
		query => q {
			DELETE FROM
				device
			WHERE
				device_id = ?
			RETURNING *
		},
		args => [
			$request->{device_id},
		]
	))) {
		$response->{status} = 'failure';
		return undef;
	}

	if (!$ret) {
		$response->{status} = 'failure';
		$response->{message} = 'error deleting container device';
		$r->log_error(
			sprintf(
				'Rejecting %s request from %s: %s',
				$request->{command},
				$meta->{client_ip},
				$response->{message}
			)
		);
		return undef;
	}

	$r->log_rerror(
		Apache2::Log::LOG_MARK,
		Apache2::Const::LOG_INFO,
		APR::Const::SUCCESS,
		sprintf('Deleted container device_id %d (%s)',
			$ret->{device_id},
			$ret->{device_name}
		)
	);

	$response->{status} = 'success';
	$response->{device_id} = $ret->{device_id};

	return Apache2::Const::OK;
}
1;

