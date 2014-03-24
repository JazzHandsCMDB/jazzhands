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
# $Id$
#

BEGIN {
	my $dir = $0;
	if ( $dir =~ m,/, ) {
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
		unshift( @INC, "$dir/../../fakeroot.lib/$incentry" );

	}
	unshift( @INC, "$dir/../lib/lib" );
}

use strict;
use Getopt::Std;
use JazzHands::Management qw(:DEFAULT);
use MIME::Base64;

my (%opt);
getopts( 'vn', \%opt );

my $dbh = OpenJHDBConnection("tokenload") || die $DBI::errstr;
$dbh->{AutoCommit} = 0;

END { $dbh->disconnect if $dbh; }

my $verbose = 0;
$verbose = 1 if ( $opt{v} );

my @keyxor = (
	0xefd5015c, 0xa0eae6f1, 0xf49376ee, 0xf895ef48,
	0x061a76d8, 0x1ab97dcd, 0x0ef2da71, 0xe334e04d
);

#
# Check statement is used to determine if the token is already in the
# database
#
my $checksth = $dbh->prepare(
	qq {
	SELECT
		Token_ID, 
		Time_Util.Epoch(Token_Last_Updated) AS Token_Last_Updated
	FROM
		V_Token
	WHERE
		Token_Serial = :serial
}
);

if ( !$checksth ) {
	printf STDERR "Error preparing check statement: %s\n", DBI::errstr;
	exit -1;
}

#
# Insert statement is used to put a new token into the database
#
my $insertsth = $dbh->prepare(
	qq {
	INSERT INTO
		Token(
			Token_Type,
			Token_Status,
			Token_Serial,
			Token_Key,
			Last_Updated
		)
	VALUES
		(
			'ETOKEN_OTP32',
			'DISABLED',
			:serial,
			:key,
			TO_DATE(:tstamp, 'YYYY-MM-DD HH24:MI:SS')
		)
	RETURNING Token_ID INTO :tokenid
}
);

if ( !$insertsth ) {
	printf STDERR "Error preparing insert statement: %s\n", DBI::errstr;
	exit -1;
}

#
# Insert statement is used to reset values for a token in the database
#
my $updatesth = $dbh->prepare(
	qq {
	UPDATE
		Token
	SET
		Token_Type = 'ETOKEN_OTP32',
		Token_Status = 'DISABLED',
		Token_Serial = :serial,
		Zero_Time = NULL,
		Time_Modulo = NULL,
		Time_Skew = NULL,
		Token_Key = :key,
		Token_PIN = NULL,
		Last_Updated = TO_DATE(:tstamp, 'YYYY-MM-DD HH24:MI:SS')
	WHERE
		Token_ID = :tokenid
}
);

if ( !$updatesth ) {
	printf STDERR "Error preparing update statement: %s\n", DBI::errstr;
	exit -1;
}

#
# Sequence for a new token
#
my $insertseq = $dbh->prepare(
	qq {
	INSERT INTO
		Token_Sequence (
			Token_ID,
			Token_Sequence,
			Last_Updated
		)
	VALUES
		(
			:tokenid,
			0,
			TO_DATE(:tstamp, 'YYYY-MM-DD HH24:MI:SS')
		)
}
);

if ( !$insertseq ) {
	printf STDERR "Error preparing insert statement: %s\n", DBI::errstr;
	exit -1;
}

#
# Sequence for an existing token
#
my $updateseq = $dbh->prepare(
	qq {
	UPDATE
		Token_Sequence
	SET
		Token_Sequence = 0,
		Last_Updated = TO_DATE(:tstamp, 'YYYY-MM-DD HH24:MI:SS')
	WHERE
		Token_ID = :tokenid
}
);

if ( !$updateseq ) {
	printf STDERR "Error preparing update statement: %s\n", DBI::errstr;
	exit -1;
}

while (<>) {
	chomp;
	my ( $version, $serial, $key, $timestamp ) = split ',';
	$timestamp = time if !$timestamp;
	my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime($timestamp);
	my $timestr = sprintf(
		"%04d-%02d-%02d %02d:%02d:%02d",
		$year + 1900,
		$mon + 1, $mday, $hour, $min, $sec
	);
	if ( $version > 1 ) {
		my @upkey = unpack( 'N8', decode_base64($key) );
		foreach my $i ( 0 .. 7 ) {
			$upkey[$i] ^= $keyxor[$i];
		}
		$key = encode_base64( pack( 'N8', @upkey ) );
	}

	if ( $serial !~ /^ALNG/ ) {
		$serial = 'ALNG' . uc($serial);
	}

	$checksth->bind_param( ":serial", $serial );
	if ( !( $checksth->execute ) ) {
		print STDERR "Error checking token serial: %s\n", DBI::errstr;
		exit -1;
	}
	my ( $tokenid, $lastupdate ) = $checksth->fetchrow_array;
	$checksth->finish;
	if ($tokenid) {
		if ( $lastupdate >= $timestamp ) {
			printf STDERR "Skipping token %s\n", $serial
			  if $verbose;
			next;
		}
		printf STDERR "Writing new key for existing token %s\n", $serial
		  if $verbose;

		#
		# Token already exists
		#
		$updatesth->bind_param( ":serial",  $serial );
		$updatesth->bind_param( ":key",     $key );
		$updatesth->bind_param( ":tokenid", $tokenid );
		$updatesth->bind_param( ":tstamp",  $timestr );
		if ( !( $updatesth->execute ) ) {
			print STDERR "Error updating token serial %s: %s\n",
			  $serial,
			  DBI::errstr;
			exit -1;
		}
		$updateseq->bind_param( ":tokenid", $tokenid );
		$updateseq->bind_param( ":tstamp",  $timestr );
		if ( !( $updateseq->execute ) ) {
			print STDERR "Error updating token serial %s: %s\n",
			  $serial,
			  DBI::errstr;
			exit -1;
		}
	} else {

		#
		# Token does not exist
		#
		printf STDERR "Inserting token %s\n", $serial if $verbose;
		$insertsth->bind_param( ":serial", $serial );
		$insertsth->bind_param( ":key",    $key );
		$insertsth->bind_param_inout( ":tokenid", \$tokenid, 32 );
		$insertsth->bind_param( ":tstamp", $timestr );
		if ( !( $insertsth->execute ) ) {
			print STDERR "Error updating token serial %s: %s\n",
			  $serial,
			  DBI::errstr;
			exit -1;
		}
		$insertseq->bind_param( ":tokenid", $tokenid );
		$insertseq->bind_param( ":tstamp",  $timestr );
		if ( !( $insertseq->execute ) ) {
			print STDERR "Error updating token serial %s: %s\n",
			  $serial,
			  DBI::errstr;
			exit -1;
		}
	}
}
$dbh->commit;
$dbh->disconnect;
