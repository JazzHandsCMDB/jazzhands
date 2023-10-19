package JazzHands::NetDev::Mgmt;

use strict;
use warnings;
use Data::Dumper;
use Socket;
use JazzHands::Common::Util qw(_options);
use JazzHands::Common::Error qw(:all);
use JSON::XS;

my $VERSION;
$VERSION = '0.81.7';

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $opt = &_options(@_);

	my $self = {};
	bless $self, $class;
}

sub connect {
	my $self = shift;
	if (!ref($self)) {
		return undef;
	}
	my $opt = &_options(@_);
	my $errors = $opt->{errors};
	my $debug = $opt->{debug_callback};

	if (!$opt->{credentials}) {
		SetError($errors,
			"credentials parameter must be passed to connect");
		return undef;
	}
	if (!$opt->{device}) {
		SetError($errors,
			"device parameter must be passed to connect");
		return undef;
	}   
	if (!ref($opt->{device})) {
		SetError($errors,
			"device parameter must be a device object");
		return undef;
	}   
	my $device = $opt->{device};
	
	if (!$device->{management_type}) {
		SetError($errors, "device management_type is unknown");
		return undef;
	}

	if (!$device->{hostname}) {
		SetError($errors, "device is missing hostname");
		return undef;
	}

	if (!$opt->{credentials}) {
		SetError($errors, "must pass credentials");
		return undef;
	}

	if (defined($debug)) {
		&$debug(
			1,
			sprintf(
				"Connecting to %s, type %s",
				$device->{hostname},
				$device->{management_type}
			)
		);
	}

	#
	# If we already have a connection to the device, just return
	#
	my $hostname = $device->{hostname};
	if (!$opt->{force_reconnect}) {
		if (defined($self->{connection_cache}->{$hostname}->{handle})) {
			if (defined($debug)) {
				&$debug(
					2,
					sprintf(
						"Using cached handle for device %s",
						$device->{hostname}
					)
				);
			}

			return $self->{connection_cache}->{$hostname};
		}
	}

	my $objtype = ref($self) . '::__devtype::' . $device->{management_type};
	eval "require $objtype";

	if ($@) {
		SetError($errors, sprintf("Error loading %s module: %s", $objtype, $@));
		return undef;
	}
	
	my $devobj;
	$devobj = 
		eval $objtype . 
			q{->new(
				device => $device, 
				credentials => $opt->{credentials},
				errors => $errors,
				debug => $opt->{debug}
				)
			};
	
	if ($@) {
		SetError($errors, sprintf("Error instantiating %s module object: %s", $objtype, $@));
		return undef;
	}
	

	if (!$devobj) {
		return undef;
	}
	$self->{connection_cache}->{$hostname} = $devobj;
	return $devobj;
}

sub commit {
	my $self = shift;
	if (!ref($self)) {
		return undef;
	}
	my $opt = &_options(@_);
	my $err = $opt->{errors};


	my $rc = 1;
	foreach my $device (values %{$self->{connection_cache}}) {
		if (!($device->commit(errors => $err))) {
			$rc = 0;
		}
	}
	return $rc;
}

sub disconnect {
	my $self = shift;
	if (!ref($self)) {
		return undef;
	}
	my $opt = &_options(@_);
	my $err = $opt->{errors};


	my $rc = 1;
	foreach my $hostname (keys %{$self->{connection_cache}}) {
		my $device = $self->{connection_cache}->{$hostname};
		if (!($device->disconnect(errors => $err))) {
			$rc = 0;
		}
		delete $self->{connection_cache}->{$hostname};
	}
	$rc;
}

1;
