#
# Copyright (c) 2022-2023 Todd M .Kover
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
use Sys::Syslog;

use vars qw(@CARP_NOT);

=head1 NAME

JazzHands::Common::Logging - common loging routines

=head1 SYNOPSIS

use JazzHands::Common qw(:log);
use JazzHands::Common qw(:all);

$self->initialize_logging(%hash);

$logh = $self->loghandle;

$logh->log(facilty, sprintf style);

$logh->{trace,debug,info,notice,warn,warning,crit,critical,error,alert,emerg,fatal}(sprintf style)

$logh->SetDebugCallback(func);
$logh->SetDebug(#);
$logh->_Debug();

logging routines that are used mostly by child classes that inherit from
JazzHands::Common to make logging "just work".

It is not meant to be called directly but via JazzHands::Common.

=head1 DESCRIPTION

This module is meant to abstract away logging so that various utilities can
just call routines for logging and "it just works."  It is meant to require
minimal other perl modules in order to get logging, but using those is
possible.  It's possible to configure logging to stderr/stdout, syslog or
to pass on to Log4perl.   It also provides interfaces very similar to
Log::Log4perl and Sys::Syslog, so it can be a near drop in replacement.

This module has evolved over time from other error, debugging and other
logging routines in various support libraries.

There are three routines that get pulled into the class that inherits from
JazzHands::Common (based on :all or :log .  Not specifying anything imports
nothing log related).  THose routines are initalize_logging, loghandle
and log.

The initialize_logging routine will take an optional hash to define how to
log.   It is possible to configure multiple endpoints and they will all get
logged to.   Not passing or not expicitly calling it will cause it to log
everything to STDERR.

The hash can look like:

{
	syslog => {
		ident => 'ident',
		logopt => 'logopt',
		facility => 'facility',
		logmask => 'logmask',
	}, log4perl => {
		log4perl config hash with at  lest config and loggername
	}, debug_callback => function_to_call_back,
	messagehandle => $filehandle_for_messages,
	errorhandle => $path_for_errors,
	messagefilename => $path_for_messages,
	errorfilename => $path_for_errors,
}

Setting both a handle and filename for errors and messages will cause the
handle to win.

The loghandle function will return a JazzHands::Common::Logging::Core object
that is how more complex interactions happen.

The log function is simliar to Sys::Syslog's syslog() call.

=head2 JazzHands::Common::Logging::Core

The loghandle routine returns a type of this object.  It's meant to be the
primary interface for logging and has a bunch of subroutines.  It also
provides interfaces simlar to Sys::Syslog and Log::Log4perl and this is where
the drop in or near drop in replacement can be used.

The routine get_logger passes through to if log4perl is cofigured, otherwise
returns undef.

There are a bunch of facilities that can be called (see the synopsis) to
log to _that_ facility based on the underlying log technology.  If the
underlying log technology does not define something, a reasonable
approximation is made.

=head2 Debug logging

Debug logging gets ignored unless a level is set with SetDebug.  This allows
things to call debugging which can be off by default.

The _Debug internal call honors SetDebugging.  The debug function does not. 

=head1 SEE ALSO

Sys::Syslog, Log::Log4perl


=head1 AUTHORS

Todd Kover (kovert@omniscient.com)
Matthew Ragan (mdr@sucksless.net)

=cut

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
		$something = 1;
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
		$something = 1;
		delete $opt->{log4perl};
	}
	if ( my $h = $opt->{debug_callback} ) {
		$logh->{_debug_callback} = $h;
		delete $opt->{_debug_callback};
	}

	if ( my $h = $opt->{errorhandle} ) {
		$logh->{_errors} = $h;
		$something = 1;
		delete $opt->{errorhandle};
	} elsif(my $fn = $opt->{errorfilename} ) {
		my $f = $logh->{_errors} = new FileHandle(">>$fn");
		if(!$f) {
			$errstr = "errorfilename($fn): $!";
			return undef;
		}
		$logh->{_errors} = $f;
		$something = 1;
	}

	if ( my $h = $opt->{messagehandle} ) {
		$logh->{_messages} = $h;
		$something = 1;
		delete $opt->{messagehandle};
	} elsif(my $fn = $opt->{messagefilename} ) {
		my $f = $logh->{_messages} = new FileHandle(">>$fn");
		if(!$f) {
			$errstr = "messagefilename($fn): $!";
			return undef;
		}
		$logh->{_messages} = $f;
	} elsif ( my $eh = $logh->{_errors} ) {
		$logh->{_messages} = $eh;
	}

	if ( !$something ) {
		$logh->{_messages} = \*STDERR;
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

	$self->{_loghandle} || $self->initialize_logging;
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
use Carp qw(carp cluck croak confess);
use Sys::Syslog;

use vars qw(@CARP_NOT);

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
			'warn'     => 'warning',
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
		require Log::Log4perl::Level;

		my $mapping = {
			'trace'    => $Log::Log4perl::Level::TRACE,
			'debug'    => $Log::Log4perl::Level::DEBUG,
			'info'     => $Log::Log4perl::Level::INFO,
			'notice'   => $Log::Log4perl::Level::INFO,
			'warn'     => $Log::Log4perl::Level::WARN,
			'warning'  => $Log::Log4perl::Level::WARN,
			'crit'     => $Log::Log4perl::Level::ERROR,
			'critical' => $Log::Log4perl::Level::ERROR,
			'error'    => $Log::Log4perl::Level::ERROR,
			'alert'    => $Log::Log4perl::Level::FATAL,
			'emerg'    => $Log::Log4perl::Level::FATAL,
			'fatal'    => $Log::Log4perl::Level::FATAL,

		};

		$lp->log( $mapping->{$facility}, sprintf $fmt, @_ );

	}

	# messages/errors.  The line is kind of arbitrary
	if ( 1 ) {
		my $mapping = {
			'trace'    => '_messages',
			'debug'    => '_messages',
			'info'     => '_messages',
			'notice'   => '_messages',
			'warn'     => '_messages',
			'warning'  => '_messages',
			'crit'     => '_errors',
			'critical' => '_errors',
			'error'    => '_errors',
			'alert'    => '_errors',
			'emerg'    => '_errors',
			'fatal'    => '_errors',
		};
		if ( my $h = $self->{ $mapping->{$facility} } ) {
			$fmt =~ s/\n*$/\n/ if($fmt);
			$h->print(sprintf($fmt, @_));
		}
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

sub logdie {
	my $self = shift @_;

	$self->fatal(@_) && die @_;
}

sub logwarn  {
	my $self = shift @_;

	$self->warn(@_) && die @_;
}

sub logcarp {
	my $self = shift @_;

	$self->warn(@_) && carp @_;
}

sub logcluck {
	my $self = shift @_;

	$self->warn(@_) && cluck @_;
}

sub logcroak {
	my $self = shift @_;

	$self->fatal(@_) && croak @_;
}

sub logconfess {
	my $self = shift @_;

	$self->fatal(@_) && confess @_;
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
