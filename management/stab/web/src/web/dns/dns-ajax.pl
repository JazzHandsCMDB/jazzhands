
# Copyright (c) 2013-2017 Todd Kover
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

#
# $Id$
#

use strict;
use warnings;
use FileHandle;
use CGI;
use JazzHands::STAB;
use Data::Dumper;
use JSON::PP;

do_dns_ajax();

sub do_dns_ajax {
	my $stab = new JazzHands::STAB( ajax => 'yes' )
	  || die "Could not create STAB";
	my $cgi = $stab->cgi || die "Could not create cgi";
	my $passedin = $stab->cgi_parse_param('passedin') || undef;

	my $mime = $stab->cgi_parse_param('MIME_TYPE') || 'text';
	my $what = $stab->cgi_parse_param('what')      || 'none';
	my $dnsrecid = $stab->cgi_parse_param('DNS_RECORD_ID');
	my $dnsdomid = $stab->cgi_parse_param('DNS_DOMAIN_ID');
	my $query = $stab->cgi_parse_param('query');

	#
	# passedin contains all the arguments that were passed to the original
	# calling page.  This is sort of gross but basically is used to ensure
	# that fields that were filled in get properly filled in on error
	# conditions that send things back.
	if ($passedin) {
		$passedin =~ s/^.*\?//;
		foreach my $pair ( split( /[;&]/, $passedin ) ) {
			my ( $var, $val ) = split( /=/, $pair, 2 );
			next if ( $var eq 'devid' );
			next if ( $var eq '__notemsg__' );
			next if ( $var eq '__errmsg__' );
			$val = $cgi->unescape($val);
			$cgi->param( $var, $val );
		}
	}

	if ( $mime eq 'xml' ) {
		print $cgi->header("text/xml");
		print '<?xml version="1.0" encoding="utf-8" ?>', "\n\n";
	} elsif ( $mime ne 'json' ) {
		print $cgi->header("text/json");
	} else {
		print $cgi->header("text/html");
	}

	$what = "" if ( !defined($what) );

	if ( $what eq 'Protocols' ) {
		my $r = {};
		$r->{'DNS_SRV_PROTOCOL'} = {
			'_tcp' => 'tcp',
			'_udp' => 'udp',
		};
		my $j = JSON::PP->new->utf8;
		print $j->encode($r);
	} elsif ( $what eq 'Services' ) {
		my $r = {};
		$r->{'DNS_SRV_SERVICE'} = {};
		my $sth = $stab->prepare(
			qq{
			select  dns_srv_service, description
			  from  val_dns_srv_service;
		}
		);
		$sth->execute || die $sth->errstr;
		my $j = JSON::PP->new->utf8;
		while ( my ( $srv, $d ) = $sth->fetchrow_array ) {
			$r->{'DNS_SRV_SERVICE'}->{$srv} = $d;
		}
		print $j->encode($r);
	} elsif ( $what eq 'domains' ) {
		my $type  = $stab->cgi_parse_param('type');
		my $where = "";
		if ($type) {
			$where = "WHERE dns_domain_type = :dnsdomaintype";
		}
		my $r = $stab->build_dns_drop( undef, $type );
		my $j = JSON::PP->new->utf8;
		print $j->encode($r);
	} elsif ( $what eq 'dnsaddrow' ) {
		my $types   = $stab->build_dns_type_drop();
		my $classes = $stab->build_dns_classes_drop();
		my $r       = {
			'classes' => $classes,
			'types'   => $types,
		};
		my $j = JSON::PP->new->utf8;
		print $j->encode($r);
	} elsif ( $what eq 'dnsref' ) {
		my $r = {
			types   => [ 'A', 'AAAA', 'CNAME' ],
			domains => $stab->build_dns_drop($dnsdomid),

		};
		my $sth = $stab->prepare(
			qq{
	 			select  dns.dns_record_id,
		     			dns.dns_type,
		     			dns.dns_name,
					dns.dns_domain_id,
		     			dom.soa_name
	      			from  dns_record dns
		     			left join dns_domain dom using (dns_domain_id)
	     			where  dns.dns_value_record_id = ?
	     			order by dns_domain_id, dns_name
		}
		);
		$sth->execute($dnsrecid) || die $sth->errstr;
		while ( my $hr = $sth->fetchrow_hashref ) {
			push( @{ $r->{records} }, $hr );
		}

		my $j = JSON::PP->new->utf8;
		print $j->encode($r);
	} elsif ( $what eq 'domains' ) {
		my $r   = {};
		my $sth = $stab->prepare(
			qq{
	 			select  dns.dns_domain_id,
					soa_name
	      			from  dns_domain
	     			order by dns_domain_id;
		}
		);
		$sth->execute() || die $sth->errstr;
		while ( my $hr = $sth->fetchrow_hashref ) {
			my $row = {
				value => $hr->{dns_domain_id},
				text  => $hr->{soa_name},
			};
			if ( $dnsdomid && $dnsdomid == $hr->{dns_domain_id} ) {
				$row->{'selected'} = 'true';
			}
			push( @{ $r->{domains} }, $row );
		}

		my $j = JSON::PP->new->utf8;
		print $j->encode($r);
	} elsif ( $what eq 'dnsref' ) {
		my $sth = $stab->prepare(
			qq{
			select	dns.dns_record_id,
					dns.dns_domain_id,
					dom.soa_name,
					dns.dns_name
		  	from	dns_record dns 
		  			inner join dns_domain dom using (dns_domain_id)
		 	where	dns_record_id = ?
		 	limit 1
		}
		) || $stab->return_db_err();
		$sth->execute($dnsrecid) || die $sth->errstr;

		my $row = $sth->fetchrow_hashref;
		$sth->finish;
		my $id     = "";
		my $prefix = "";
		my $fix    = "";
		$id = $row->{ _dbx('DNS_RECORD_ID') };
		my $doms = "";
		if ($row) {
			my $type;    # not used at the moment.
			$doms =
			  $stab->build_dns_drop( $row->{ _dbx('DNS_DOMAIN_ID') }, $type );
		}
		my $j = JSON::PP->new->utf8;
		my $r = { 'domains' => $doms, };
		print $j->encode($r);
	} elsif ( $what eq 'cname-complete' ) {
		my $r = {
			query => 'unit',
		};

		my $sth = $stab->prepare(
			qq{
			select	dns.dns_record_id,
					dom.soa_name,
					dns.dns_name
		  	from	dns_record dns 
		  			inner join dns_domain dom using (dns_domain_id)
		 	where	coalesce(dns_name, '.', soa_name) LIKE ?
			and 	dns_type in ('A','AAAA','CNAME')
			and		dns_value_record_id IS NULL
			and		reference_dns_record_id IS NULL
			order by dns_name, soa_name
		 	limit 10
		}
		) || $stab->return_db_err();
		$sth->execute($query."%") || die $sth->errstr;

		while(my ($id,$soa,$dns) = $sth->fetchrow_array) {
			push(@{ $r->{suggestions} },
				{ value => join(".", $dns,$soa), data => $id });
		}
		my $j = JSON::PP->new->utf8;
		print $j->encode($r);
	} else {

		# catch-all error condition
		print $cgi->div( { -style => 'text-align: center; padding: 50px', },
			$cgi->em("not implemented yet.") );
	}

	if ( $mime eq 'xml' ) {
		print "</response>\n";
	}

	my $dbh = $stab->dbh;
	if ( $dbh && $dbh->{'Active'} ) {
		$dbh->commit;
	}
	undef $stab;
}
