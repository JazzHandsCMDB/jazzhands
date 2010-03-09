#
# $Id$
#

# Copyright (c) 2005-2010, Vonage Holdings Corp.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#
# $Id$
#

BEGIN {
	my $dir = $0;
	if($dir =~ m,/,) {
		$dir =~ s!^(.+)/[^/]+$!$1!;
	} else {
		$dir = ".";
	}
	#
	# Copy all of the entries in @INC, and prepend the fakeroot install
	# directory.
	#
	my @SAVEINC = @INC;
	foreach my $incentry (@SAVEINC) {
		unshift(@INC, "$dir/../../fakeroot.lib/$incentry");
	}
	unshift(@INC, "$dir/../lib/lib");
}

=head1 NAME

JazzHands::AuthToken - Perl module for encoding and decoding authentication tokens

=head1 SYNOPSIS

 ## Login page

 use JazzHands::AuthToken;
 $at = JazzHands::AuthToken->new
    or die $JazzHands::AuthToken::Error;
 $text = $at->Create(-login => 'joedoe')
    or die $at->Error;
 ## use $text as a cookie value 

 ## Application page

 use JazzHands::AuthToken;
 ## retrieve cookie value into $text
 $at = JazzHands::AuthToken->new
    or die $JazzHands::AuthToken::Error;
 $userinfo = $at->Decode($text)
    or die $at->Error;
 $login = $userinfo->{login};

 ## Application page using the Verify function
 ## Must be running in mod_perl in Apache 2

 use CGI;
 use CGI::Carp;
 use CGI::Cookie;
 use Apache2::Const -compile => qw(REDIRECT);
 use JazzHands::AuthToken;

 my $r = shift;
 my $q = CGI->new;
 my $auth = JazzHands::AuthToken->new
     or die $JazzHands::AuthToken::Error;

 my $userinfo = $auth->Verify(
    request => $r,
    required_properties => [ 'UserMgmt', 'GlobalSearchUser' ]
 );

 unless ($userinfo) {
    return Apache2::Const::REDIRECT if ($auth->ErrorCode eq 'REDIRECT');
    die "verification failed: " . $auth->Error;
 }

 print $q->header(-cookie => [ $auth->{cookie} ] );

=head1 DESCRIPTION

The JazzHands::AuthToken module is useful for implementing cookie-based
authentication mechanism for web applications. The module facilitates
storing of encrypted authentication information in a cookie, and it's
later retrieval, decoding, and verification.

=head1 METHODS

=cut

###############################################################################

package JazzHands::AuthToken;

use strict;
use warnings;

use Crypt::Blowfish;
use Crypt::CBC;
use MIME::Base64;
use Data::Dumper;
use Digest::SHA1 qw(sha1_base64);
use CGI qw(:standard);
use CGI::Cookie;
use Apache2::RequestRec;
use APR::Table;
use Apache2::Const -compile => qw(REDIRECT);
use JazzHands::Management;

our $KEYFILE = "/tmp/authuser.key";
our $AUTHTOKEN_MAGIC = 0xbeeff00d;
our $AUTHTOKEN_VERSION = 0x2;
our $LOGINPAGE = "/login";
our $AUTHDOMAIN = "example.com";
our $DBAUTHAPPL = "jh_websvcs_ro";
our ($Error, $ErrorCode);

my $cryptokey;

sub _options {
	my %ret = @_;
	for my $v (grep { /^-/ } keys %ret) {
		$ret{substr($v,1)} = $ret{$v};
	}
	\%ret;
}	   

###############################################################################
=pod

=head2 new(%options)

This is the constructor for creating new JazzHands::AuthToken objects.
The constructor's main purpose is to determine the encryption key. The
encryption key can be specified using the -key option, or it can be
retreived from a keyfile. If the -key option was not specified, and
the keyfile does not exist, a new encryption key is generated and
stored in the specified keyfile. The constructor returns a new
JazzHands::AuthToken object, or undef on error. When undef is returned,
the error message can be retrieved from $JazzHands::AuthToken::Error;

=over 4

=item -keyfile

Specifies the file where the encryption key is stored. If this
parameter is omitted, $JazzHands::AuthToken::KEYFILE is used.

=item -key

The encryption key itself. If not specified, the encryption key is
read from the keyfile. If the keyfile does not exist, a new encryption
key is generated and written to the keyfile.

=back

=cut
###############################################################################

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $opt = &_options;

	my $self = {};
	my $keyfile = $opt->{keyfile} || $KEYFILE;
	if ($opt->{key}) {
		$self->{key} = $opt->{key};
	} elsif ($cryptokey) {
		$self->{key} = $cryptokey;
	} else {
		my $key;
		if (! -f $keyfile) {
			if (!open (KEYFILE, ">$keyfile")) {
				$Error = "Unable to write encryption key: $!";
				return undef;
			}
			$key = Crypt::CBC->random_bytes(8);
			print KEYFILE encode_base64($key);
			close KEYFILE;
		} else {
			if (!open(KEYFILE, "<$keyfile")) {
				$Error = "Unable to read encryption key: $!";
				return undef;
			}
			chomp($key = <KEYFILE>);
			close KEYFILE;
			$key = decode_base64($key);
		}
		$self->{key} = $key;
		$cryptokey = $key;
	}
	bless $self;
}


###############################################################################
=pod

=head2 Error($errmsg)

When $errmsg is passed, the internal error message variable as well as
$JazzHands::AuthToken::Error is set to $errmsg. Returns the value of the
internal error message variable.

=cut
###############################################################################

sub Error {
	my $self = shift;

	if(@_) { $self->{_error} = $Error = shift }
	return $self->{_error};
}


###############################################################################
=pod

=head2 ErrorCode($code)

When $code is passed, the internal error code variable as well as
$JazzHands::AuthToken::ErrorCode is set to $code. Returns the value of
the internal error code variable. Please note that currently only the
Verify function sets the internal error code.

=cut
###############################################################################

sub ErrorCode {
	my $self = shift;

	if(@_) { $self->{_error_code} = $ErrorCode = shift }
	return $self->{_error_code};
}


###############################################################################
=pod

=head2 Create(%options)

The function creates a new authentication token which is basicaly a
hash consisting of login, authentication type, idle timeout,
expiration time, timestamp, and secondary authentication information,
and passes this hash to Timestamp. Returns the encrypted token as
returned by Timestamp, or undef on error.

=over 4

=item -login

Specifies the login to be encoded in the token. This option is
mandatory.

=item -authtype

Specifies the authentication type to be encoded in the
token. Optional. The default value is 'level1'.

=item -idle

Specifies the idle timeout of the token in seconds. Optional. The
default value is 900.

=item -lifetime

Specifies the total token lifetime in seconds. The expiration time of
the token is calculated by adding the specified lifetime to the
current time. Optional. The default value is 36000 (10 hours).

=item -secondaryauthinfo

Optional opaque data to be stored in the encoded token.

=back

=cut
###############################################################################

sub Create {
	my $self = shift;
	my $opt = &_options;

	return undef if !$self->{key};
	return undef if !$opt->{login} && !$opt->{token};

	$self->Error(undef);
	# default to 15 minute idle timeout, 10 hour session lifetime

	# secondaryauthinfo is opaque data that contains additional information
	# specific to the authentication type.  For example, this contains the
	# token ID used to authenticate for OTP and enrollment auth types

	my $token = {
		login => $opt->{login},
		authtype => $opt->{authtype} || 'level1',
		idle => $opt->{idle} || 900,
		expire => time() + ($opt->{lifetime} || 36000),
		timestamp => time(),
		secondaryauthinfo => $opt->{secondaryauthinfo} || ''
	};

	return $self->Timestamp($token);
}


###############################################################################
=pod

=head2 Timestamp($token)

The function timestamps the unencrypted authentication token $token,
adds the token version and magic number for integrity verification
when the token is later decrypted, encrypts the token, and URL-encodes
the encrypted data. Returns the encrypted and encoded string or undef
on error.

=cut
###############################################################################

sub Timestamp {
	my $self = shift;
	my $token = shift;

	if (!$token || !$self->{key}) {
		$self->Error("Error in passed parameters");
		return undef;
	}

	$token->{timestamp} = time();
	my $authtoken = pack('NNZ*Z*NNNZ*',
		$AUTHTOKEN_MAGIC,
		$AUTHTOKEN_VERSION,
		$token->{login},
		$token->{authtype},
		$token->{idle},
		$token->{expire},
		$token->{timestamp},
		$token->{secondaryauthinfo}
	);

	my $digest = sha1_base64($authtoken);
	$authtoken .= pack('Z*', $digest);

	my $cipher;
	if (!($cipher = Crypt::CBC->new(-key => $self->{key},
			-cipher => 'Blowfish',
			-header => 'randomiv',
			))) {
		$self->Error ("Unable to encrypt authtoken due to cipher problem");
		return undef;
	}
	if (!($authtoken = encode_base64($cipher->encrypt($authtoken)))) {
		$self->Error ("Error encrypting authtoken");
		return undef;
	}
	chomp($authtoken);
	$authtoken =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
	return $authtoken;
}


###############################################################################
=pod

=head2 Decode($encoded_token)

The function decodes and decrypts $encoded_token, verifies the magic
number, version, expiration and idle time, and returns undef on error
or a reference to a hash with the following members: login, authtype,
idle, expire, timestamp, and secondaryauthinfo.

=cut
###############################################################################

sub Decode {
	my $self = shift;
	my $authtoken = shift;

	if (!$authtoken || !$self->{key}) {
		$self->Error("Error in passed parameters");
		return undef;
	}

	$self->Error(undef);
	my $cipher;
	if (!($cipher = Crypt::CBC->new(-key => $self->{key},
			-cipher => 'Blowfish',
			-header => 'randomiv',
			))) {
		$self->Error("Unable to decrypt authtoken due to cipher problem");
		return undef;
	}
	$authtoken =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
	eval { $authtoken = ($cipher->decrypt(decode_base64($authtoken))); };
	if (!$authtoken) {
		$self->Error ("Error decrypting authtoken");
		return undef;
	}
	my ($magic) = unpack('N', $authtoken);
	if ($magic ne $AUTHTOKEN_MAGIC) {
		$self->Error ("Authentication magic does not match!");
		return undef;
	}

	my ($version) = unpack('x[N]N', $authtoken);

	if ($version == 2) {
		my ($login, $authtype, $idle, $expire, $timestamp, 
				$secondaryauthinfo, $digest);
		eval { ($login, $authtype, $idle, $expire, $timestamp, 
					$secondaryauthinfo, $digest) =
				unpack('x[N]x[N]Z*Z*NNNZ*Z*', $authtoken); };

		if (!$login) {
			$self->Error('Bad authentication token');
			return undef;
		}
		# repack to check the digest

		my $authtoken = pack('NNZ*Z*NNNZ*',
			$AUTHTOKEN_MAGIC,
			$AUTHTOKEN_VERSION,
			$login,
			$authtype,
			$idle,
			$expire,
			$timestamp,
			$secondaryauthinfo
		);
		my $checkdigest = sha1_base64($authtoken);
		if ($digest ne $checkdigest) {
			$self->Error('Auth digest does not match: %s/%s',
				$digest, $checkdigest);
			return undef;
		}
	
		if ($expire < time()) {
			$self->Error ("Auth token has expired (session)");
			return undef;
		}
		if ($timestamp + $idle < time()) {
			$self->Error ("Auth token has expired (idle)");
			return undef;
		}

		return {
			login => $login,
			authtype => $authtype,
			idle => $idle,
			expire => $expire,
			timestamp => $timestamp,
			secondaryauthinfo => $secondaryauthinfo
		};
	} else {
		$self->Error("Unknown authtoken version");
		return undef;
	}	
}


###############################################################################
=pod

=head2 Verify(%options)

The function Verify combines retreiving of the encoded token from a
cookie, and it's decoding and verification into a complex function to
simplify the application code of the calling web application. Returns
the decoded token as returned by Decode or undef on error. When undef
is returned, the caller should call the ErrorCode function, and if it
returns 'REDIRECT', redirect to the login page. ErrorCode can also
return 'FATAL' or 'UNAUTHORIZED', and the error message can be
obtained by calling the Error function.

=over 4

=item -authtype

Specifies the required authentication type of the token. If the
authentication type in the decoded token does not match this value, an
error is indicated, and undef is returned. The option -authtype can be
a string, or a reference to an array of strings. If an array reference
is used, the decoded token must match at least one of the specified
types. If this option is omitted, 'level1' is used.

=item -authtoken

The text string of the encoded token. If the -authtoken option is
omitted, the -request must point to an Apache2::RequestRec object, and
the function will attempt to retrieve the encoded token from the
cookie named 'authtoken-xxx' where xxx is one of the authentication
types passed in the -authtype option.

=item -request

An Apache2::RequestRec object. If this option is specified, the
function will retrieve the encoded token from the appropriate cookie
if necessary, and it will also set the request headers appropriately
for the HTTP redirect if a redirect to a login page is necessary. The
location of the login page is stored in $JazzHands::AuthToken::LOGINPAGE.

=item -required_properties

If this option is specified, the function will also verify whether the
user encoded in the 'login' field of the authentication token has at
least one of the specified UCLASS properties in JazzHands. The
-required_properties option must be a reference to an array of strings
with an even number of elements. The odd elements are
UCLASS_PROPERTY_TYPEs, and the even elements are
UCLASS_PROPERTY_NAMEs.

=item -dbhandle

This option is used only if the -required_properties option is used.
It points to a JazzHands::Management object to be used for communicating to
JazzHands. If this option is not specified, the Verify function will open
it's own connection to JazzHands using the DBAAL entry
$JazzHands::AuthToken::DBAUTHAPPL.

=back

=cut
###############################################################################


sub Verify {
    my $self = shift;
    my $opt = &_options;
    my ($types, $type, $authtoken, $userinfo, $r, $jhdbh, $user);

    $self->{_error_code} = $ErrorCode = 'FATAL';

    ## Process the -authtype option, and make sure $types is an array
    ## reference to the authtypes that we want to verify. 'level1' is
    ## the default.

    $types = [ 'level1' ];
    
    if ($opt->{authtype}) {
	my $a = $opt->{authtype};
	$types = ref($a) eq 'ARRAY' ? $a : [ $a ];
    }

    if ($opt->{authtoken}) {
	$authtoken = $opt->{authtoken};
    }

    ## If -authtoken was not specified, attempt to fetch the authtoken
    ## from a cookie. The -request parameter is required.

    else {
	my ($r, %cookies);

	unless ($r = $opt->{request}) {
	    $self->Error("Error in passed parameters");
	    return undef;
	}

	%cookies = CGI::Cookie->fetch($r);

	## Try all cookies named authtoken-xxx, where xxx is one of
	## the authtypes. The first cookie found is the one which
	## wins. Also remember which authtype we used to fetch the
	## cookie.

	foreach (@$types) {
	    if (exists $cookies{"authtoken-$_"}) {
		$authtoken = $cookies{"authtoken-$_"}->value;
		$type = $_;
		last;
	    }
	}
    }

    ## If we do not have an authtoken now, or if it can't be decoded
    ## indicate a redirect to the caller.

    unless ($authtoken && ($userinfo = $self->Decode($authtoken))) {
	my $r = $opt->{request};

	$self->{_redirect} = 1;

	## If an Apache2::RequestRec object was passed in the -request
	## option, setup the redirect.

	if ($r) {
	    my $uri = $r->uri;

	    $type = $types->[0];
	    $uri =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
	    $r->headers_out->set(Location => $LOGINPAGE . 
	        '?referrer=' . $uri . '&authtype=' . $type);
	    $r->status(Apache2::Const::REDIRECT);
	}

	$self->ErrorCode('REDIRECT');
	return undef;
    }

    ## If we have not figured out the authtype yet, do so now.

    unless ($type) {
	foreach (@$types) {
	    if ($userinfo->{authtype} eq $_) {
		$type = $_;
		last;
	    }
	}
    }

    ## If the authtype in $userinfo does not match any of the desired
    ## authtypes, return an error.

    unless ($type && $userinfo->{authtype} eq $type) {
	$self->Error("authtype does not match");
	return undef;
    }

    ## Get a Database handle from the -dbhandle option, or if the
    ## option was not specified, open a new connection.

    if ($opt->{dbhandle}) {
	$jhdbh = $opt->{dbhandle};
    }

    else {
	if (!($jhdbh = JazzHands::Management->new(
		  application => $DBAUTHAPPL, dberrors => 1))) {
	    $self->Error("unable to open connection to Database");
	    return undef;
	}
    }

    ## Verify we have a valid user in $userinfo

    if (!defined($user = $jhdbh->GetUser(login => $userinfo->{login}))) {
	$self->Error('unable to get user information for authenticated user ' .
		     $userinfo->{login} . ' : ' . $jhdbh->Error);
	return undef;
    }

    if (!ref($user)) {
	$self->Error('unable to get user information for authenticated user ' .
		     $userinfo->{login});
	return undef;
    }

    if ($opt->{required_properties}) {
	my $p = $opt->{required_properties};
	my ($dbh, $sql, $sth, $t, $n, @tn, @pv, $ref);

	## The -required_properties option must be a reference to an
	## array with an even number of elements.

	unless (ref($p) eq 'ARRAY' && !(@$p % 2)) {
	    $self->Error("Error in passed parameters");
	    return undef;
	}

	$dbh = $jhdbh->DBHandle;

	## Assemble the query

        $sql = q{
            select uclass_property_name, property_value,
              property_value_company_id, property_value_password_type,
              property_value_token_col_id, property_value_uclass_id
            from v_user_prop_expanded where system_user_id = ? and
        };

	while (($t, $n) = splice(@$p, 0, 2)) {
	    push(@tn, "(uclass_property_type = '$t' " . 
		 "and uclass_property_name = '$n')");
	}

	$sql .= '(' . join(' or ', @tn) . ')';

	## Prepare and execute the query.

	if (!($sth = $dbh->prepare($sql))) {
	    $self->Error("Unable to prepare database query: " . $dbh->errstr);
	    return undef;
	}

	if (!($sth->execute($user->Id))) {
	    $self->Error("Unable to execute database query: " . $sth->errstr);
	    return undef;
	}

	## Fetch the results, and build an array of hash references.

	while ($ref = $sth->fetchrow_hashref) {
	    push(@pv, $ref);
	}

	$sth->finish;
	$dbh->disconnect unless ($opt->{dbhandle});

	## Store the results in the 'properties' field

	if (@pv) {
	    $self->{properties} = \@pv;
	}

	## or if there were no results, report that the user does not
	## have any of the required properties.

	else {
	    $self->Error('Authenticated user ' . $userinfo->{login} .
			 ' does not have any of the required properties');
	    $self->ErrorCode('UNAUTHORIZED');
	    return undef;
	}
    }

    ## Set the 'token' and 'cookie' fields, and return the result.

    return undef unless ($self->{token} = $self->Timestamp($userinfo));
	
    $self->{cookie} = new CGI::Cookie(-name   => "authtoken-$type",
				      -value  => $self->{token},
				      -path   => '/',
				      -domain => $AUTHDOMAIN);

    $self->{_error_code} = $ErrorCode = undef;
    return $userinfo;
}

1;

=pod

=head1 GLOBAL VARIABLES

The following module global variables can be used to configure the
behavior of the module:

=over

=item $JazzHands::AuthToken::KEYFILE

The location of the keyfile where the encryption key is stored. The
default value is '/tmp/authuser.key'.

=item $JazzHands::AuthToken::LOGINPAGE

The location of the login page to which the application should be
redirected when the token is expired or invalid. The default value is
'/login'.

=item $JazzHands::AuthToken::AUTHDOMAIN

The domain name for the authentication cookie. The default value is
'example.com'

=item $JazzHands::AuthToken::DBAUTHAPPL

The name of the DBAAL entry (aka application name) to be used for
connection to the JazzHands database. The default value is
'jh_websvcs_ro'.

=back

=head1 SEE ALSO

L<JazzHands::Management>, L<CGI>, L<CGI::Cookie>, L<Apache2::RequestRec>,
L<Crypt::CBC>

