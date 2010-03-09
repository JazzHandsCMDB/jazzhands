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

# $Id$
#
package JazzHands::Management::Vendor;

#
# helpers
#
use warnings;
use strict;
use vars qw($VERSION @EXPORT @ISA);

$VERSION = '2.0.0';

require Exporter;
our @ISA = ( "Exporter", "JazzHands::Management" );
@EXPORT = qw(
  ExtendVendor
  FindCompanyManagementListForUser
  FindExtensionCandidates
  FindVendors
);

#
# modules
#
use Time::Local qw(timegm_nocheck);

sub ticks_at_end_of_next_quarter($) {
	my ($ticks) = @_;
	my (@gm)    = gmtime($ticks);

	#
	# JAN thru MAR is end of MAR
	# APR thru JUN is end of JUN
	# JUL thru SEP is end of SEP
	# OCT thru DEC is end of DEC
	#
	if ( $gm[4] >= 0 && $gm[4] <= 2 ) {
		$gm[3] = 31;
		$gm[4] = 2;
	} elsif ( $gm[4] >= 3 && $gm[4] <= 5 ) {
		$gm[3] = 30;
		$gm[4] = 5;
	} elsif ( $gm[4] >= 6 && $gm[4] <= 8 ) {
		$gm[3] = 30;
		$gm[4] = 8;
	} elsif ( $gm[4] >= 9 && $gm[4] <= 11 ) {
		$gm[3] = 31;
		$gm[4] = 11;
	}

	#
	# end of month
	#
	$gm[0] = 59;
	$gm[1] = 59;
	$gm[2] = 23;

	#
	# build a new tick
	#
	return timegm_nocheck(@gm);
}

sub timestamp($) {
	my ($ticks) = @_;
	my (@gm);

	@gm = gmtime($ticks);

	return sprintf(
		"%04d-%02d-%02d %02d:%02d:%02d",
		$gm[5] + 1900,
		$gm[4] + 1,
		$gm[3], $gm[2], $gm[1], $gm[0]
	);
}

sub FindCompanyManagementListForUser {
	my ( $self, $login, $days ) = @_;
	my ($dbh);
	my ($hash);
	my ($sql);
	my ($sth);

	#
	# database handle
	#
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error("Invalid class reference passed");
		return undef;
	}

	#
	# query to get all access
	#
	$sql = qq(
		SELECT DISTINCT c.company_id, c.company_name
		FROM system_user u, company c
		WHERE u.company_id = c.company_id
		AND u.system_user_type = 'vendor'
		AND u.system_user_status IN ('enabled', 'onleave-enable')
	);
	if ( !( $sth = $dbh->prepare_cached($sql) ) ) {
		$JazzHands::Management::Errmsg =
		  "prepare_cached failed for: \"$sql\"";
		return undef;
	}
	if ( !$sth->execute ) {
		$JazzHands::Management::Errmsg = "execute failed for: \"$sql\"";
		return undef;
	}
	if ( !( $hash = $sth->fetchall_hashref("COMPANY_ID") ) ) {
		$JazzHands::Management::Errmsg =
		  "fetchall_hashref failed for: \"$sql\"";
		return undef;
	}

	#
	# success
	#
	return $hash;
}

sub FindExtensionCandidates {
	my ( $self, $company_id, $days ) = @_;
	my ($dbh);
	my ($hash);
	my ($sql);
	my ($sth);

	#
	# database handle
	#
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error("Invalid class reference passed");
		return undef;
	}

	#
	# query to get all access
	#
	$sql = qq(
		SELECT
			c.company_id,
			u.first_name,
			u.last_name,
			u.system_user_id,
			to_char(u.hire_date, 'YYYY-MM-DD') hire_date,
			to_char(u.termination_date, 'YYYY-MM-DD') termination_date,
			trunc(u.termination_date - sysdate) days_left
		FROM system_user u, company c
		WHERE u.company_id = c.company_id
		AND u.company_id = $company_id
		AND u.system_user_type = 'vendor'
		AND u.system_user_status in ('enabled', 'onleave-enable')
		AND (u.termination_date IS NULL OR u.termination_date - sysdate < $days)
	);
	if ( !( $sth = $dbh->prepare_cached($sql) ) ) {
		$JazzHands::Management::Errmsg =
		  "prepare_cached failed for: \"$sql\"";
		return undef;
	}
	if ( !$sth->execute ) {
		$JazzHands::Management::Errmsg = "execute failed for: \"$sql\"";
		return undef;
	}
	if ( !( $hash = $sth->fetchall_hashref("SYSTEM_USER_ID") ) ) {
		$JazzHands::Management::Errmsg =
		  "fetchall_hashref failed for: \"$sql\"";
		return undef;
	}

	return $hash;
}

sub FindVendors {
	my ( $self, $company_id, $status_caller ) = @_;
	my ($dbh);
	my ($hash);
	my ($sql);
	my ($status_condition);
	my ($status_input) = [ 'enabled', 'onleave-enable' ];
	my ($sth);

	#
	# sanity
	#
	if ( !defined($company_id) ) {
		$JazzHands::Management::Errmsg = "company_id is unset";
		return undef;
	}

	#
	# database handle
	#
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error("Invalid class reference passed");
		return undef;
	}

	#
	# use status from caller
	#
	if ($status_caller) {

		#
		# sanitize
		#
		$status_caller =~ s/'/\'/g;

		#
		# and use
		#
		$status_input = $status_caller;
	}

	#
	# make status condition
	#
	if ( ref($status_input) eq "ARRAY" ) {
		$status_condition =
		  "'" . join( "', '", @{$status_input} ) . "'";
	} elsif ( ref($status_input) ) {
		$self->Error(
"Invalid status reference passed.  use undef, simple, or array reference."
		);
		return undef;
	} else {
		$status_condition = "'" . $status_input . "'";
	}

	#
	# query to get vendor list
	#
	$sql = qq(
		SELECT
			c.company_id,
			u.first_name,
			u.last_name,
			u.system_user_id,
			to_char(u.hire_date, 'YYYY-MM-DD') hire_date,
			to_char(u.termination_date, 'YYYY-MM-DD') termination_date,
			trunc(u.termination_date - sysdate) days_left
		FROM system_user u, company c
		WHERE u.company_id = c.company_id
		AND u.company_id = $company_id
		AND u.system_user_type = 'vendor'
		AND u.system_user_status in ($status_condition)
	);

	#
	# get it
	#
	if ( !( $sth = $dbh->prepare_cached($sql) ) ) {
		$JazzHands::Management::Errmsg =
		  "prepare_cached failed for: \"$sql\"";
		return undef;
	}
	if ( !$sth->execute ) {
		$JazzHands::Management::Errmsg = "execute failed for: \"$sql\"";
		return undef;
	}
	if ( !( $hash = $sth->fetchall_hashref("SYSTEM_USER_ID") ) ) {
		$JazzHands::Management::Errmsg =
		  "fetchall_hashref failed for: \"$sql\"";
		return undef;
	}

	#
	# return it
	#
	return $hash;
}

sub ExtendVendor {
	my ( $self, $suid, $method ) = @_;
	my ($dbh);

	#
	# database handle
	#
	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}
	if ( !$dbh ) {
		$self->Error("Invalid class reference passed");
		return undef;
	}

	#
	# pick the method
	#
	if ( $method eq "quarterly" ) {
		return extend_vendor_access_quarterly( $dbh, $suid );
	}

	#
	# input validation
	#
	$JazzHands::Management::Errmsg = "method was not 'quarterly': $method";
	return 0;
}

sub extend_vendor_access_quarterly($$) {
	my ( $dbh, $suid ) = @_;
	my ($quarterly_date);
	my ($quarterly_ticks) = ticks_at_end_of_next_quarter(time);
	my ($sql);

	#
	# convert to string
	#
	$quarterly_date = timestamp($quarterly_ticks);

	#
	# sql
	#
	$sql = qq(
		UPDATE system_user SET
		termination_date = '$quarterly_date'
		WHERE system_user_id = $suid
	);
	if ( $dbh->do($sql) != 1 ) {
		$JazzHands::Management::Errmsg = "do update filed: \"$sql\"";
		return undef;
	}

	#
	# done
	#
	return 1;
}

1;
