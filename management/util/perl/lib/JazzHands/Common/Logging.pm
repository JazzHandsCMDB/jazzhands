#
# Copyright (c) 2022 Todd M .Kover
# All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

###############################################################################

package JazzHands::Common::Logging;

use strict;
use Exporter;
use JazzHands::Common::Util qw(:all);
use JazzHands::Common::Error qw(:internal);
use Data::Dumper;
use Carp qw(cluck);
use Sys::Syslog;

our $VERSION = '1.0';

our @ISA = qw(Exporter );

my @tags = qw(
  initialize_logging
  loghandle
  log
);

our @EXPORT_OK = [@tags];

our %EXPORT_TAGS = (
	'all' => [@tags],
	'log' => [@tags],
);

Exporter::export_ok_tags('all');
Exporter::export_ok_tags('log');

############################################################################
#
# This section contains the routines that can be exported into other modules
# and are meant to make logging "just work"
#
############################################################################

#
# This initializes a "loghandle" which is stashed inside $self and a few
# very specific logging functions are exposed.
#
sub initialize_logging {
	my $self = shift @_;
	$self = shift if ( $#_ % 2 == 0 );
	my $opt = &_options(@_);

	my $logh = {};
	bless $logh, 'JazzHands::Common::Logging::Core';
	$self->{_loghandle} = $logh;

	my $something = 0;

	if ( $opt->{syslog} ) {
		if ( ref( $opt->{syslog} ) ne 'HASH' ) {
			our $errstr = "syslog argument must be a hash";
			return undef;
		}
		my $ident    = $opt->{syslog}->{ident};
		my $logopt   = $opt->{syslog}->{logopt};
		my $facility = $opt->{syslog}->{facility};
		my $logmask  = $opt->{syslog}->{logmask};

		if ( !$ident ) {
			$errstr = "Must pass ident to initialize_logging for syslog";
			return undef;
		}

		if ( !$logopt ) {
			$errstr = "Must pass logopt to initialize_logging for syslog";
			return undef;
		}

		if ( !$facility ) {
			$errstr = "Must pass facility to initialize_logging for syslog";
			return undef;
		}

		openlog( $ident, $logopt, $facility );
		if ($logmask) {
			setlogmask($logmask);
		}

		if ( !$ident ) {
			$errstr = "Must pass ident to initialize_logging for syslog";
			return undef;
		}

		$logh->{_syslog} = 1;
		my $something = 1;
		delete $opt->{syslog};
	}
	if ( $opt->{log4perl} ) {
		if ( ref( $opt->{log4perl} ) ne 'HASH' ) {
			our $errstr = "log4perl argument must be a hash";
			return undef;
		}

		require Log::Log4perl;
		my $logconfig  = $opt->{log4perl}->{config};
		my $loggername = $opt->{log4perl}->{loggername};

		if ( !$logconfig ) {
			$errstr = "Must pass logconfig to initialize_logging for log4perl";
			return undef;
		}

		if ( !$loggername ) {
			$errstr = "Must pass loggername to initialize_logging for log4perl";
			return undef;
		}

		# note that errors will raise an exception so this should
		# possibly be wrapped to allow it to return undef
		Log::Log4perl::init($logconfig);
		$logh->{_log4perl} = Log::Log4perl::get_logger($loggername);
		my $something = 1;
		delete $opt->{log4perl};
	}
	if ( my $h = $opt->{debug_callback} ) {
		$logh->{_debug_callback} = $h;
		delete $opt->{_debug_callback};
	}

	if ( my $h = $opt->{errorhandle} ) {
		$logh->{_errors} = $h;
		my $something = 1;
		delete $opt->{errorhandle};
	}

	if ( my $h = $opt->{messagehandle} ) {
		$logh->{_messages} = $h;
		my $something = 1;
		delete $opt->{messagehandle};
	} elsif ( my $h = $logh->{_errors} ) {
		$logh->{_messages} = $h;
	}

	if ( !$something ) {
		$logh->{_messages} = \*STDOUT;
		$logh->{_errors}   = \*STDERR;
	}

	if ( scalar keys( %{$opt} ) ) {
		$errstr = "Unknown option(s): " . join( ", ", keys %{$opt} );
		return undef;
	}

	$logh;
}

sub loghandle {
	my $self = shift @_;

	$self->{_loghandle} || $self->initialize_logging;
}

sub log {
	my $self = shift @_;

	$self->{loghandle} || $self->initialize_logging;
	$self->{_loghandle}->log(@_);
}

sub get_logger {
	my $self = shift @_;

	$self->{_loghandle} || $self->initialize_logging;
	$self->{_loghandle}->get_logger();
}

############################################################################
#
# These are all methods that are not exposed and are part of the
# class that actually does all the work.
#
############################################################################

package JazzHands::Common::Logging::Core;

use strict;
use Exporter;
use JazzHands::Common::Util qw(:all);
use JazzHands::Common::Error qw(:internal);
use Data::Dumper;
use Carp qw(cluck);
use Sys::Syslog;

#
# returns log4perl handle for doing log4perl operations.  If log4perl is not
# setup, returns undef
#
sub get_logger {
	my $self = shift @_;

	( exists( $self->{_log4perl} ) ) ? $self->{_log4perl} : undef;
}

sub log {
	my $self     = shift @_;
	my $facility = shift @_;

	my $fmt = shift @_;

	if ( $self->{_syslog} ) {
		my $mapping = {
			'trace'    => 'debug',
			'debug'    => 'debug',
			'info'     => 'info',
			'notice'   => 'notice',
			'warn'     => 'warnign',
			'warning'  => 'warning',
			'crit'     => 'crit',
			'critical' => 'crit',
			'error'    => 'error',
			'alert'    => 'alert',
			'emerg'    => 'emerg',
			'fatal'    => 'alert',
		};

		syslog( $mapping->{$facility}, sprintf $fmt, @_ );
	}
	if ( my $lp = $self->{_log4perl} ) {
		use Log::Log4perl::Level;

		my $mapping = {
			'trace'    => $TRACE,
			'debug'    => $DEBUG,
			'info'     => $INFO,
			'notice'   => $INFO,
			'warn'     => $WARN,
			'warning'  => $WARN,
			'crit'     => $ERROR,
			'critical' => $ERROR,
			'error'    => $ERROR,
			'alert'    => $FATAL,
			'emerg'    => $FATAL,
			'fatal'    => $FATAL,

		};

		$lp->log( $mapping->{$facility}, sprintf $fmt, @_ );

	}
	if ( my $h = $self->{_errors} ) {
		printf $h @_;
	}

}

sub SetDebug {
        my $self = shift;
        if (@_) { $self->{_debug} = shift; }
        return $self->{_debug};
}

sub SetDebugCallback {
        my $self = shift;
        if (@_) { $self->{_debug_callback} = shift; }
        return $self->{_debug_callback};
}

sub _Debug {
        my $self  = shift;
        my $level = shift;

        if ( defined($level) && $level <= $self->{_debug} && @_ ) {
                if ( $self->{_debug_callback} ) {
                        my $fmt = shift @_;
                        my $str = sprintf( $fmt, @_ );
                        &{ $self->{_debug_callback} }( $level, $str );
                } else {
        		$self->debug(@_);
                }
        }

}


# I hate this, but convert the list in @permited to arguments to _log()
# and otherwise just fail.
sub AUTOLOAD {
	my $self = shift @_;

	our $AUTOLOAD;

	my $f = $1 if $AUTOLOAD =~ /^.*::([^:]+)$/;

	my @permitted = (
		'trace', 'debug',    'info',  'notice', 'warn',  'warning',
		'crit',  'critical', 'error', 'alert',  'emerg', 'fatal',
	);

	return $self->log( $f, @_ ) if ( grep( $_ eq $f, @permitted ) );
	shift->${\"NEXT::$AUTOLOAD"}(@_);
}

DESTROY {
	if ( my $self = shift @_ ) {
		if ( $self->{_logmethod} eq 'syslog' ) {
			closelog();
		}
	}
}

1;

__END__


=head1 NAME


=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FILES


=head1 AUTHORS

=cut

