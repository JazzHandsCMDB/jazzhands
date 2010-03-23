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

#
# $Id$
#
# This compares the database against what's actually in DNS.  This should be
# merged together with the other script in some fashion so the comparisions
# are always handled both ways.  This is work.
#

use warnings;
use strict;
use JazzHands::STAB;
use Net::DNS;
use Data::Dumper;

do_db_dns_compare();

sub find_best_ns {
	my($stab, $zone) = @_;

	my $lastns;

	my $res = Net::DNS::Resolver->new;
	my $query = $res->query($zone, "NS");

	if(!$query || !$query->answer) {
		$stab->error_return("Unable to find the registered nameserver for this host");
	}
	foreach my $rr (grep {$_->type eq 'NS'} $query->answer) {
		if(defined($rr->nsdname)) {
			my $nsdname = $rr->nsdname;
			$nsdname =~ tr/A-Z/a-z/;
			if($nsdname eq 'intauth00.EXAMPLE.COM') {
				return('intauth00.EXAMPLE.COM');
			} elsif($nsdname eq 'auth00.EXAMPLE.COM') {
				return('auth00.EXAMPLE.COM');
			}
			$lastns = $rr->nsdname;
		}
	}
	$lastns;
}

sub by_name {
	if($a->name =~ /^\d+$/ && $b->name =~ /^\d+$/) {
		return($a->name <=> $b->name);
	} else {
		return($a->name cmp $b->name);
	}
}

sub process_db_zone {
	my($stab, $ns, $domid, $zone) = @_;
	my $dbh = $stab->dbh || die "no dbh!";
	my $cgi = $stab->cgi || die "no cgi!";

	my $msg = "";

	# this query is shared with zone generation;  really wants to be
	# pulled into a zone perl module and shared.  (most of zone generation
	# should be pulled into a perl module and shared with stab and other
	# things.
	#
	# need to better deal with the reference dns record with a coalesce
	# column [XXX].  I've now changed it quite a bit.
	my $sth = $dbh->prepare_cached(qq{
		select  distinct
			d.dns_record_id, d.dns_name, d.dns_ttl, d.dns_class,
			d.dns_type, d.dns_value, d.dns_priority,
			ip_manip.v4_octet_from_int(ni.ip_address) as ip,
			ni.ip_address,
			rdns.dns_record_Id,
			rdns.dns_name,
			d.dns_srv_service, d.dns_srv_protocol,
			d.dns_srv_weight, d.dns_srv_port,
			d.is_enabled,
			(CASE WHEN(d.dns_name is NULL and
				   d.reference_dns_record_id is NULL)
				THEN 0
				ELSE 1
			 END
			) as sort_order,
			coalesce(rdns.dns_name, d.dns_name) as discerned_name
		  from  dns_record d
			left join netblock ni
				on d.netblock_id = ni.netblock_id
			left join dns_record rdns
				on rdns.dns_record_id =
					d.reference_dns_record_id
		 where  d.dns_domain_id = :1
		   and  d.dns_type != 'REVERSE_ZONE_BLOCK_PTR'
		   and	d.is_enabled = 'Y'	--- XXX
		order by discerned_name, d.dns_type, 
			ip_manip.v4_octet_from_int(ni.ip_address)
	}) || $stab->error_return("Unable to extract zone"); 

	$sth->execute($domid) || $stab->error_return($sth);

	my ($lastrec, $lasttype) = ("", "");

	#
	# Build up all records of the same type for the comparision, then
	# compare the hell out of them.
	#
	my @dbrec;
	while(my $hr = $sth->fetchrow_hashref) {
		# build the name of this record.  JazzHands is closer to a zone format,
		# so you can have the actual name in another record, which is weirdish
		my $rec;
		if($hr->{DISCERNED_NAME}) {
			$rec = join(".", $hr->{DISCERNED_NAME}, $zone);
		} else {
			$rec = $zone;
		}

		# 4right now, we only grok IN records
		if($hr->{DNS_CLASS} ne 'IN') {
			$msg .= $cgi->li("Can't process class ", $hr->{DNS_CLASS}, 
				"for ", $hr->{DISCERNED_NAME});
			next;
		}

		if($hr->{DNS_TYPE} =~ /^(NS|MX|CNAME)$/) {
			if($hr->{DNS_VALUE} =~ /\.$/) {
				$hr->{PROCESSED_VALUE} = $hr->{DNS_VALUE};
			} else {
				$hr->{PROCESSED_VALUE} = $hr->{DNS_VALUE}.".$zone";
			}
		} elsif($hr->{DNS_TYPE} eq 'A') {
			$hr->{PROCESSED_VALUE} = $hr->{IP};
		} else {
			$hr->{PROCESSED_VALUE} = $hr->{DNS_VALUE};
		}
		$hr->{PROCESSED_VALUE} =~ s/\.$//;

		# these get processed on the second iteration (and after the while
		# loop for the last one), so this is a bit kooky.
		if($lastrec eq $lasttype && $lastrec eq "") {
			push(@dbrec, $hr);
		} elsif($lastrec eq $rec && $lasttype eq $hr->{DNS_TYPE}) {
			push(@dbrec, $hr);
		} else {
			$msg .= compare_record_fromdb($stab, $lastrec, $ns, \@dbrec);
			undef @dbrec ;
			push(@dbrec, $hr);
		}
		$lastrec = $rec;
		$lasttype = $hr->{DNS_TYPE};
			

	}
	$msg .= compare_record_fromdb($stab, $lastrec, $ns, \@dbrec);

	return $msg;
}

sub compare_record_fromdb {
	my($stab, $rec, $ns, $dbrec) = @_;
	my $cgi = $stab->cgi || die "no cgi!";

	my $msg = "";

	my $res = new Net::DNS::Resolver;
	$res->nameservers( $ns );

	my $type = $dbrec->[0]->{DNS_TYPE};

	my(@zonerec);

	my $lookuprec = $rec;
	if($type eq 'SRV') {
		if($dbrec->[0]->{DNS_SRV_SERVICE}) {
			$lookuprec = join(".",
				$dbrec->[0]->{DNS_SRV_SERVICE}, "_".
				$dbrec->[0]->{DNS_SRV_PROTOCOL},
				$lookuprec);
		}
	}

	my $q = $res->query($lookuprec, $dbrec->[0]->{DNS_TYPE});
	if($q) {
		foreach my $rr ($q->answer) {
			if($rr->type eq $type) {
				push(@zonerec, $rr);
			} else {
				;
			}
		}
	}

	if($#zonerec >= 0) {
		$msg .= compare_record($stab, $type, $rec, $ns, $dbrec, \@zonerec);
	} else {
		if($type eq 'SRV') {
			$msg .= $cgi->pre(Dumper($dbrec, \@zonerec));
		}
		my @dbval;
		foreach my $r (@$dbrec) {
			if(defined($r->{IP_ADDRESS})) {
				push(@dbval, $r->{IP});
			} elsif(defined($r->{DNS_VALUE})) {
				push(@dbval, $r->{DNS_VALUE});
			} else {
				push(@dbval, $cgi->b("No Value Set"));
			}
		}
		my $dbval = "";
		$dbval = " (". join(",", @dbval). ")" if($#dbval >= 0);
		my $m = $cgi->li("$rec of type $type$dbval is in the DB, not in DNS");
		if($type !~ /^(A|NS|CNAME|SRV|TXT)$/) {
			$msg = $cgi->li($cgi->b($m));
		} else {
			$msg .= $cgi->li($m);
		}
	}

	$msg;
}

#
# for now, I just want to compare the database to the zone.  The other way
# is interesting, but don't want to build it all out just now.  (That's in
# dns-reconcile.pl.  That needs to be folded into here.  [XXX]
#
sub compare_record {
	my($stab, $type, $rec, $ns, $dbrec, $zonerec) = @_;
	my $cgi = $stab->cgi;

	my $msg = "";

	#
	# compare the database to the zone
	#
	foreach my $dbr (@$dbrec) {
		my $nosup = 0;
		my $found = 0;
		foreach my $zr (@$zonerec) {
			if($zr->type eq 'NS') {
				if($zr->nsdname eq $dbr->{PROCESSED_VALUE}) {
					$found = 1;
					last;
				}
			} elsif($zr->type eq 'A') {
				if($zr->address eq $dbr->{PROCESSED_VALUE}) {
					$found = 1;
					last;
				}
			} elsif($zr->type eq 'CNAME') {
				if($zr->cname eq $dbr->{PROCESSED_VALUE}) {
					$found = 1;
					last;
				}
			} elsif($zr->type eq 'SRV') {
				# first we check the case where the SRV record is slapped
				# into the DNS_VALUE.
				my($pri,$srv,$proto,$weight,$port,$target);
				if(!defined($dbr->{DNS_SRV_SERVICE})) {
					($pri,$weight,$port,$target) = split(/\s+/, 
						$dbr->{PROCESSED_VALUE});
				} else {
					($pri,$weight,$port,$target) = (
						$dbr->{DNS_PRIORITY},
						$dbr->{DNS_SRV_WEIGHT},
						$dbr->{DNS_SRV_PORT},
						$dbr->{PROCESSED_VALUE});
				}
				if ( $pri == $zr->priority &&
					 $weight == $zr->weight &&
					 $port == $zr->port &&
					 $target == $zr->target) {
						$found = 1;
						last;
				} 
			} elsif($zr->type eq 'TXT') {
				$dbr->{PROCESSED_VALUE} =~ s/^"//;
				$dbr->{PROCESSED_VALUE} =~ s/"$//;
				if($dbr->{PROCESSED_VALUE} eq $zr->txtdata) {
					$found = 1;
					last;
				}
			} else {
				$nosup = 1;
			}
		}
		if($nosup) {
			$msg .= $cgi->li($cgi->b("JazzHands rec $rec ($type) not supported"));
		} elsif(!$found) {
			$msg .= $cgi->li("JazzHands record $rec ($type) value ", $dbr->{PROCESSED_VALUE}, " is not in the Zone.");
		}
	}

	$msg;
}

#
# This needs to go away once the version in the perl module 
#
sub device_from_name { 
	my($stab, $name) = @_; 
	my $dbh = $stab->dbh;

	my $q = qq{
		select  device_id, device_name,
			device_type_id, serial_number, 
			asset_tag, operating_system_id,
			status, production_state,
			ownership_status,
			is_monitored,
			is_locally_managed,
			identifying_dns_record_id,
			SHOULD_FETCH_CONFIG,
			PARENT_DEVICE_ID,
			IS_VIRTUAL_DEVICE,
			AUTO_MGMT_PROTOCOL
		  from  device
		 where  device_name = :1
	};       
	my $sth = $stab->prepare($q) || $stab->return_db_err($dbh);
	$sth->execute($name) || $stab->return_db_err($sth);

	$sth->fetchrow_hashref;
}

sub device_link {
	my($stab, $name, $altname) = @_;

	$altname = $name if(!$altname);

	my $cgi = $stab->cgi || die "no cgi!";

	my $dev = device_from_name($stab, $name);

	if(!$dev) {
		return($name);
	} else {
		return($cgi->a({-href=>"../device/device.pl?devid=".$dev->{'DEVICE_ID'}},
			$altname));
	}

}

#############################################################################

sub do_db_dns_compare {
	my $stab = new JazzHands::STAB || die "no stab!";
	my $cgi = $stab->cgi || die "no cgi!";

	my $domid = $stab->cgi_parse_param("DNS_DOMAIN_ID") || $stab->error_return("you must specify a domain");

	my $domain = $stab->get_dns_domain_from_id($domid) || $stab->error_return("unknown domain id $domid");
	my $zone = $domain->{'SOA_NAME'};

	my $ns = $stab->cgi_parse_param('zone') || find_best_ns($stab, $zone);

	if($zone =~ /in-addr.arpa/) {
		$stab->error_return("This only works with Forward Zones");
	}

	my $msg = process_db_zone($stab, $ns, $domid, $zone);
	print $cgi->header;
	print $stab->start_html({-title=>"Reconcilation issues with db for $zone"});
	print $cgi->center("Note:  JazzHands == STAB");
	print $cgi->div({-align=>'center'}, 
		$cgi->a({-href=>"../dns/?dnsdomainid=$domid"}, $zone));
	print $cgi->div({-align=>'center'}, "Compare to $ns");
	print $cgi->ul($msg);
	$msg = undef;

	print $cgi->end_html;

	$stab->rollback;
}
