#!/usr/local/bin/perl
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

use warnings;
use strict;
use POSIX;
use JazzHands::DBI;

my $now = time;

my $dbh = JazzHands::DBI->connect( 'stab_stats', { AutoCommit => 0 } ) || die;

{
	my $dude = ( getpwuid($<) )[0] || 'unknown';
	my $q = qq{ 
		begin
			dbms_session.set_identifier ('$dude');
		end;
	};
	if ( my $sth = $dbh->prepare($q) ) {
		$sth->execute;
	}
}

my $nullq = qq{
	select	count(*)
	  from	device d
		inner join device_function df
			on df.device_id = d.device_id
	 where	d.composite_os_version_id is NULL
	   and	df.device_function_type = 'server'
	   and	d.data_ins_date <= :1
};
my $nullsth = $dbh->prepare($nullq) || die $dbh->errstr;

my $eqq = qq{
select  count(*)
  from  device d
	inner join composite_os_version cos
		on cos.composite_os_version_id = d.composite_os_version_id
	inner join device_function df
		on df.device_id = d.device_id
 where	cos.version_name = :2
   and	df.device_function_type = 'server'
   and	d.data_ins_date <= :1
};
my $eqsth = $dbh->prepare($eqq) || die $dbh->errstr;

my $neqq = qq{
select  count(*)
  from  device d
	inner join composite_os_version cos
		on cos.composite_os_version_id = d.composite_os_version_id
	inner join device_function df
		on df.device_id = d.device_id
 where	cos.version_name != :2
   and	df.device_function_type = 'server'
   and	d.data_ins_date <= :1
};
my $neqsth = $dbh->prepare($neqq) || die $dbh->errstr;

my $insertq = qq{
	insert into dev_baseline_history (
		whence, unknown_version, baselined, legacy
	) values (
		:1, :2, :3, :4
	)
};
my $insertsth = $dbh->prepare($insertq) || die $dbh->errstr;

my $whence = strftime( "%F %T", gmtime($now) );

$nullsth->execute($whence) || die $nullsth->errstr;
my $null_total = ( $nullsth->fetchrow_array )[0] || 0;
$nullsth->finish;

$eqsth->execute( $whence, 'legacy' ) || die $eqsth->errstr;
my $legacy_total = ( $eqsth->fetchrow_array )[0] || 0;
$eqsth->finish;

$neqsth->execute( $whence, 'legacy' ) || die $neqsth->errstr;
my $baselined_total = ( $neqsth->fetchrow_array )[0] || 0;
$neqsth->finish;

$insertsth->execute( $whence, $null_total, $baselined_total, $legacy_total )
  || die $insertsth->errstr;

$dbh->commit;
$dbh->disconnect;
