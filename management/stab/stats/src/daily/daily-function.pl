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

my $oraclenow = strftime( "%F %T", gmtime($now) );

my $q = qq{
	insert into dev_function_history
		(whence, DEVICE_FUNCTION_TYPE, tally)
	select  :1, device_function_type, count(*) as tally
	  from  device_function     
	 where	data_ins_date <= :1
	group by device_function_type 
};
my $sth = $dbh->prepare($q) || die $dbh->errstr;
$sth->execute($oraclenow) || die $sth->errstr;

$q = qq {
	insert into dev_function_history
		(whence, DEVICE_FUNCTION_TYPE, tally)
	select :1, 'total', count(*)
	  from device
	 where	data_ins_date <= :1
};
$sth = $dbh->prepare($q) || die $dbh->errstr;
$sth->execute($oraclenow) || die $sth->errstr;

$dbh->commit;
$dbh->disconnect;
