package JazzHands::Redfish;


use strict;
use warnings;
use Data::Dumper;
use Socket;
use IO::Socket::SSL;
use JazzHands::Common::Util qw(_options );
use JazzHands::Common::Error qw(:all);
use JSON::XS;
use LWP::UserAgent;

my $VERSION;
$VERSION = '0.87.3';

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $opt = &_options(@_);

	my $self = {};
	bless $self, $class;
}

sub SendCommand {
	my $self;
	if (ref($_[0])) {
		$self = shift;
	}
	my $opt = &_options(@_);
	my $err = $opt->{errors};

	my $timeout = $opt->{timeout} || 30;
	my $credentials = $opt->{credentials} || $self->{credentials};
	if (!$credentials) {
		SetError($err,
			"credentials parameter must be passed to SendCommand");
		return undef;
	}
	if (!$opt->{url}) {
		SetError($err,
			"url parameter must be passed to SendCommand");
		return undef;
	}

	my $default_method = 'GET';
	my $method = $opt->{http_method};
	my $json_req;
	if ($opt->{arguments}) {
		$default_method = 'POST';
		eval { 
			$json_req = JSON::XS->new->pretty(1)->encode($opt->{arguments});
		};
		if (!$json_req) {
			SetError($opt->{errors}, 'unable to encode JSON');
			return undef;
		}
	}
	my $device = $opt->{device};
	my $ua = LWP::UserAgent->new(
		ssl_opts => {
			SSL_verify_mode   => SSL_VERIFY_NONE,
			verify_hostname => 0,
		}
	);
	$ua->agent("provisioning/1.0");
	$ua->timeout($timeout);
	my $header = HTTP::Headers->new;
	$header->authorization_basic(
		$credentials->{username},
		$credentials->{password});
	$header->header('Accept' => 'text/html,application/json');
	$header->header('Content-Type' => 'application/json');
	my $req = HTTP::Request->new(
		$method || $default_method,
		'https://' . ($device->{hostname} || $opt->{hostname}) . $opt->{url},
		$header,
		$json_req);

	if ($opt->{debug} > 1) {
		printf STDERR "URL: %s\n", $opt->{url};
	}
	my $res;
	eval {
		local $SIG{ALRM} = sub { die "timeout"; };
		alarm($timeout);
		$res = $ua->request($req);
		alarm(0);
	};
	if ($@ eq 'timeout') {
		SetError($err, "connection timed out");
		return undef;
	}
	if (!$res) {
		SetError($err, "Bad return");
		return undef;
	}
	if (!$res->is_success) {
		SetError($err, $res->status_line);
		return undef;
	}
	undef $ua;
	my $result;
	eval { $result = JSON::XS->new->decode($res->content) };
	if ($opt->{debug} > 1) {
		print Data::Dumper->Dump([$result], ["Response"]);
	}
	if ($result->{error}) {
		SetError($err, $result->{error}->{message});
		return undef;
	}
	return $result;
}

1;
