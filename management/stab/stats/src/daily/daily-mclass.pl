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

sub get_device_functions {
	my ($dbh) = @_;

	my $q = qq{
		select	DEVICE_FUNCTION_TYPE
		  from	val_device_function_type
	};

	my $sth = $dbh->prepare($q) || die $dbh->errstr;
	$sth->execute || die $sth->errstr;

	my (@rv);
	while ( my ($dft) = $sth->fetchrow_array ) {
		push( @rv, $dft );
	}

	\@rv;
}

sub get_inmclass_total {
	my ( $dbh, $whence, $dft ) = @_;

	my $sth;
	if ( defined($dft) ) {
		my $q = qq{
			select  count(*) 
			  from  device  d 
				 inner join device_collection_member dcm
					  on dcm.device_id = d.device_id
				 inner join device_collection dc
					  on dc.device_collection_id = dcm.device_collection_id
					  and dc.device_collection_type = 'mclass'  
				 inner join device_function df
					  on df.device_id =  d.device_id
			 where  dcm.data_ins_date < :1
			   and  df.DEVICE_FUNCTION_TYPE = :2
			   and	dc.name != 'genericnetwork'
			};
		$sth = $dbh->prepare($q) || die $dbh->errstr;
		$sth->execute( $whence, $dft ) || die $sth->errstr;
	} else {
		my $q = qq{
			select  count(*) 
			  from  device  d 
				 inner join device_collection_member dcm
					  on dcm.device_id = d.device_id
				 inner join device_collection dc
					  on dc.device_collection_id = dcm.device_collection_id
					  and dc.device_collection_type = 'mclass'  
			 where  dcm.data_ins_date < :1
			   and	dc.name != 'genericnetwork'
			};
		$sth = $dbh->prepare($q) || die $dbh->errstr;
		$sth->execute($whence) || die $sth->errstr;
	}

	my $total = ( $sth->fetchrow_array )[0];
	$total;
}

sub get_device_total {
	my ( $dbh, $whence, $dft ) = @_;

	my $sth;
	if ( defined($dft) ) {
		my $q = qq{
			select  count(*)
			  from  device  d
			        inner join device_function df
			                on df.device_id =  d.device_id
			 where  d.data_ins_date < :1
			   and  df.DEVICE_FUNCTION_TYPE = :2
		};
		$sth = $dbh->prepare($q) || die $dbh->errstr;
		$sth->execute( $whence, $dft ) || die $sth->errstr;
	} else {
		my $q = qq{
			select  count(*)
			  from  device  d
			 where  d.data_ins_date < :1
		};
		$sth = $dbh->prepare($q) || die $dbh->errstr;
		$sth->execute($whence) || die $sth->errstr;
	}
	my $total = ( $sth->fetchrow_array )[0];
	$total;
}

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

my $functions = get_device_functions($dbh);

my $whence = strftime( "%F %T", gmtime($now) );
my $q = qq{
	insert into dev_function_mclass_history (
		whence, device_function_type, total_in_mclass, total
	) values (
		:1, :2, :3, :4
	)
};
my $sth = $dbh->prepare($q) || die $dbh->errstr;

foreach my $dft (@$functions) {
	my $inmclass = get_inmclass_total( $dbh, $whence, $dft );
	my $all = get_device_total( $dbh, $whence, $dft );

	$sth->execute( $whence, $dft, $inmclass, $all ) || die $sth->errstr;
}

my $tot_inmclass = get_inmclass_total( $dbh, $whence );
my $total = get_device_total( $dbh, $whence );
$sth->execute( $whence, 'total', $tot_inmclass, $total ) || die $sth->errstr;

$dbh->commit;
$dbh->disconnect;
