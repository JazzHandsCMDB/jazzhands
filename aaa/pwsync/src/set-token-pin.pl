#!/usr/local/bin/perl -w
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

use strict;
use CGI;
use JazzHands::Management;

$contact = "nobody\@EXAMPLE.COM";

sub main {

	sub initialform {
		my $q      = shift;
		my $parm   = shift;
		my $reason = shift;

		print qq {
		<script>

			function verifyform(f) {
				var msg = "";
				var errors = 0;

				if (f.username.value == null || f.username.value == "") {
					msg = msg + "    Username was not specified\\n";
					errors++;
				}
				if (f.otp1.value == null || f.otp1.value == "") {
					msg = msg + "    First OTP value was not specified\\n";
					errors++;
				}
				if (f.otp2.value == null || f.otp2.value == "") {
					msg = msg + "    Second OTP value was not specified\\n";
					errors++;
				}
				if (f.pin.value == null || f.pin.value == "") {
					msg = msg + "    PIN was not specified\\n";
					errors++;
				} else if (f.pin.value != f.pinverify.value) {
					msg = msg + "    PINs given do not match\\n";
					errors++;
				}
				if (f.pin.value.length < 6) {
					msg = msg + "    PIN given is less than 6 characters\\n";
					errors++;
				}

				if (!errors) {
					return true;
				}

				if (errors) {
					alert ("There " + (errors > 1 ? "are " : "is ") + errors +
						" error" + (errors > 1 ? "s" : "") + " in your form.\\n\\n" +
						msg + "\\nPlease correct this and resubmit\\n");
				}
				return false;
			}

		</script>
		};

		print $q->start_form(
			-enctype  => &CGI::MULTIPART,
			-onsubmit => "return verifyform(this)"
		);

		print $q->hidden( -name => 'submittag', -default => 'button' );
		print qq {
		To provide access to a computer system, some kind of authentication is
		required.  At a basic level, all of the ways that can be used to do this
		can be broken down into one of three methods:

		<ul>
		<li>
			<b>Something You Know</b> - a password, your mother's maiden name, an
			ATM PIN
		<li>
			<b>Something You Have</b> - a one-time-password device, a smart card,
			a badge, an ATM card
		<li>
			<b>Something You Are</b> - identifying your voice, your fingerprints, your
			retina
		</ul>

		A one-time-password token, or OTP token is an example of a two-factor
		authentication device, which combines two different methods of authentication -
		in this case "Something You Have" and "Something You Know".  The "Something
		You Have" is the OTP token itself - if you don't have the token, you won't
		know what the next set of digits that you need to enter are.  The "Something
		You Know" is the PIN that you will set here.
		<p>
		After setting your PIN, it may take up to 15 minutes for this to
		be propagated to all authentication servers.  
		<p>
		};

		if ($reason) {
			print $q->span( { -style => 'Color: red;' },
				$reason . "\n" );
		}

		print $q->start_table(
			{ -border => 0, -width => '50%', -cellspacing => 10 } );
		print $q->Tr;
		print $q->td( { -align => 'right' }, "Enter your username: " );
		print $q->td(
			{ -align => 'left' },
			$q->textfield(
				-name  => 'username',
				-value => ( $parm->{username} or "" ),
				-size  => 25
			)
		);

		print $q->Tr;
		print $q->td(
			{ -colspan => 2 }, qq {
			Press the button on your token and enter the one-time password displayed on
			it.
		}
		);

		print $q->Tr;
		print $q->td( { -align => 'right' },
			"First one-time password: " );
		print $q->td(
			{ -align => 'left' },
			$q->textfield(
				-name  => 'otp1',
				-value => $parm->{otp1} || "",
				-size  => 25,
			)
		);

		print $q->Tr;
		print $q->td(
			{ -colspan => 2 }, qq {
			Wait for approximately 30 seconds, then press the button on your token
			again enter the next one-time password displayed on it.  This step
			is necessary to verify the token that you have, and to syncronize it with
			the authentication server.
		}
		);

		print $q->Tr;
		print $q->td( { -align => 'right' },
			"Second one-time password: " );
		print $q->td(
			{ -align => 'left' },
			$q->textfield(
				-name  => 'otp2',
				-value => $parm->{otp2} || "",
				-size  => 25,
			)
		);

		print $q->Tr;
		print $q->td(
			{ -colspan => 2 }, qq {
		Please choose a PIN to use with this token:
		<ul>
		<li>
			Your PIN must be at least 6 characters
		<li>
			Your PIN should be different from your normal password
		<li>
			Your PIN should be alphanumeric and not easily guessible
		<li>
			If you are assigned multiple tokens, the PIN for each token must be
			different from all others associated with your account.
		</ul>
		}
		);

		print $q->Tr;
		print $q->td( { -align => 'right' }, "Enter PIN: " );
		print $q->td(
			{ -align => 'left' },
			$q->password_field(
				-name  => 'pin',
				-value => $parm->{pin} || "",
				-size  => 25,
			)
		);

		print $q->Tr;
		print $q->td( { -align => 'right' }, "Enter PIN (again): " );
		print $q->td(
			{ -align => 'left' },
			$q->password_field(
				-name  => 'pinverify',
				-value => $parm->{pin} || "",
				-size  => 25,
			)
		);

		print $q->end_table;

		print $q->br( $q->submit("Set PIN") );

		print $q->endform . "\n";

		print $q->end_html . "\n";
		exit;
	}

	sub set_pin {
		my $q    = shift;
		my $parm = shift;

		my $serial;
		my $displayserial = "";
		my $tokens;
		my $tokenlist;
		my $token;

		my $CONTACT = "<a href='mailto:$contact'>$contact</a>";

		if ( length( $parm->{pin} ) < 6 ) {
			initialform( $q, $parm,
				"PIN must be at least 6 characters." );
			exit;
		}

		my $dbh = OpenJHDBConnection("tokenmgmt");

		if ( !$dbh ) {
			print $q->span(
				{ -style => "font-weight: bold; color: red;" },
				$q->br("Error connecting to database!")
			);
			exit;
		}
		$dbh->{AutoCommit} = 0;
		$tokens =
		  JazzHands::Management::Token::GetTokenAssignments( $dbh,
			login => $parm->{username} );

		my $verified = 0;
		if ( !$tokens ) {
			print $q->span(
				{ -style => 'Color: red;' },
"Error retrieving parameters from database.  Please try again",
				"later or contact $CONTACT for help.\n",
				$q->br($JazzHands::Management::Errmsg)
			);
		} elsif (@$tokens) {

	   #
	   # Loop through all of the users tokens to see if the OTPs given match
	   # any of them.
	   #
			foreach my $tok (@$tokens) {

		     #
		     # Check the first sequence number.  We don't want to update
		     # the sequence during the first pass; we'll pick it up once
		     # the token is fully verified.
		     #
				my $seq =
				  JazzHands::Management::Token::FindHOTP(
					$dbh,
					token_id => $tok->{token_id},
					otp      => $parm->{otp1},
					noupdate => 1
				  );

		    # First OTP didn't match this token, so this isn't the droid
		    # we're looking for

				next if ( !$seq );

		#
		# Check the second sequence number by specifically requesting
		# a check against the next sequence from the one returned above.
		# If this matches, the token is verified, and we want to have
		# the sequence in the database updated to match.
		#
				$seq = JazzHands::Management::Token::FindHOTP(
					$dbh,
					token_id => $tok->{token_id},
					otp      => $parm->{otp2},
					sequence => $seq + 1
				);

				# Second OTP didn't match this token

				next if ( !$seq );

				# Token sequences match

				$verified = 1;
				$token    = $tok;
				last;
			}
		}

		if ( !$verified ) {
			$dbh->disconnect;
			initialform( $q, $parm,
"One-time passwords given did not match any tokens assigned to you."
			);
			exit;
		}

		if ( $token->{token_pin} ) {
			print $q->span(
"A PIN has already been set for the token with serial",
				"number ",
				$token->{token_serial},
				".  Please contact $CONTACT ",
				"to have its PIN cleared."
			);
			$dbh->disconnect;
			exit;
		}

		if (
			JazzHands::Management::Token::SetTokenPIN(
				$dbh,
				token_id => $token->{token_id},
				pin      => $parm->{pin},
			)
		  )
		{
			print $q->span(
"There was an error setting the PIN for this token, ",
				"serial number ",
				$token->{token_serial},
".  Please contact $CONTACT to report this error:\n",
				br($JazzHands::Management::Errmsg),
			);
			$dbh->disconnect;
			exit;
		}
		print $q->span(
			"PIN was set for token with serial number ",
			$token->{token_serial},
".  It will take up to 15 minutes for this to be reflected to all of the authentication servers.\n"
		);
		$dbh->disconnect;
		exit;
	}
	my $q = new CGI;
	$q->default_dtd(
		[
			'-//W3C//DTr HTML 4.01 transitional//EN',
			'http://www.w3.org/TR/html4/loose.dtr'
		]
	);

	#
	# Fetch CGI parameters which may have been passed
	#
	my $parm;
	$parm = undef;
	$parm = $q->Vars;

	#
	# Parameters we're looking for:
	#
	#   'username'  - the username of the person authenticating
	#   'otp1'      - the first OTP of the token the user is entering
	#   'otp2'      - the second OTP of the token the user is entering
	#   'pin'       - the new PIN the user wants to set
	#

	print $q->header;
	print $q->start_html(
		-title => "Set Your OTP Token PIN",
		-style =>
		  { -code => "\tbody {background: white; color:black;}\n" }
	);
	print "\n";

	print $q->table(
		{ -border => 0, -width => '70%' },
		$q->Tr( $q->td("JazzHands"), "\n" ),
		$q->td(
			{ -align => 'center' },
			$q->h1("Set Your OTP Token PIN")
		)
	) );

	if (         !$parm->{username}
		  || !$parm->{otp1}
		  || !$parm->{otp2}
		  || !$parm->{pin} )
	  {

		  #
		  # Spew out initial form
		  #
		  initialform( $q, $parm );
	} else {
		  set_pin( $q, $parm );
	}
}

&main;
