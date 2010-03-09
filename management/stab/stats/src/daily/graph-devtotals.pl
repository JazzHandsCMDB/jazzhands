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

use strict;
use warnings;
use JazzHands::DBI;
use FileHandle;
use CGI;
use POSIX;

my $statsroot = shift(@ARGV) || "/prod/www/stab/docs/stats";

sub make_gnuplotfile {
	my ( $statfn, $headers ) = @_;

	my $tmpfile = "/tmp/graph-devtotals-stats.cmdfile.$$";

	my $pc = new FileHandle(">$tmpfile");

	$pc->print(qq{set term png size 900,800\n});
	$pc->print(qq{set grid xtics ytics \n});
	$pc->print(qq{set data style lines\n});
	$pc->print(qq{set xdata time\n});
	$pc->print(qq{set timefmt "\%Y\%m\%d"\n});
	$pc->print(qq{set key left\n});
	$pc->print(qq{set title "Number of Elements by Function"\n});
	$pc->print(qq{set lmargin 12\n});
	$pc->print(qq{set rmargin 3\n});

	## top plot
	$pc->print(qq{set multiplot\n});
	$pc->print(qq{set size 1,0.25\n});
	$pc->print(qq{set origin 0,0.75\n});
	$pc->print(qq{set bmargin 1\n});
	$pc->print(qq{set format x ""\n});
	$pc->print(qq{set xlabel ""\n});
	$pc->print(qq{set ylabel ""\n});
	$pc->print(qq{set time ""\n});
	$pc->print(qq{plot });
	my $hdrno     = 2;
	my $totalhdrs = $#{@$headers};
	my $cnt       = 0;
	my $comma     = ",";

	for ( my $i = 0 ; $i <= $totalhdrs ; $i++ ) {
		my $header = @$headers[$i];
		if ( ( $header eq "total" ) || ( $header eq "server" ) ) {
			$cnt++;
			$pc->print(
				qq{     "$statfn" using 1:$hdrno smooth bezier }
			);
			$pc->print(qq{title "$header"$comma});
		}
		$comma = "" if ( $cnt >= 1 );
		$hdrno++;
	}
	$pc->print(qq{\n});

	# middle plot
	$pc->print(qq{set title ""\n});
	$pc->print(qq{set size 1,0.25\n});
	$pc->print(qq{set origin 0,0.5\n});
	$pc->print(qq{set nolog y\n});
	$pc->print(qq{set tmargin 0\n});
	$pc->print(qq{set bmargin 1\n});
	$pc->print(qq{plot });
	$hdrno     = 2;
	$totalhdrs = $#{@$headers};
	$cnt       = 0;
	$comma     = ",";

	for ( my $i = 0 ; $i <= $totalhdrs ; $i++ ) {
		my $header = @$headers[$i];
		if (       ( $header eq "router" )
			|| ( $header eq "netcam" )
			|| ( $header eq "switch" )
			|| ( $header eq "tdmaccess" )
			|| ( $header eq "printer" )
			|| ( $header eq "consolesrv" ) )
		{
			$cnt++;
			$pc->print(
				qq{     "$statfn" using 1:$hdrno smooth bezier }
			);
			$pc->print(qq{title "$header"$comma});
		}
		$comma = "" if ( $cnt >= 5 );
		$hdrno++;
	}
	$pc->print(qq{\n});

	# bottom plot
	$pc->print(qq{set title ""\n});
	$pc->print(qq{set xlabel "Date"\n});
	$pc->print(qq{set ylabel "Number of elements [1]"\n});

	#$pc->print(qq{set time "Graph created: %a %b %d %H:%M:%S %Y"\n});
	$pc->print(qq{set size 1,0.5\n});
	$pc->print(qq{set origin 0,0\n});
	$pc->print(qq{set nolog y\n});
	$pc->print(qq{set tmargin 0\n});
	$pc->print(qq{set bmargin 6\n});

	# XXX yrange likely to need to be adjusted in the future
	# based on eyeballing the plot.
	#
	# this can't be calculated b/c the plot uses curve smoothing
	# so the 'max' values listed in the data plot will not
	# necessarily match with what is actually plotted.
	#
	# yrange is needed to accomodate spikes in the data that
	# get smoothed out (generally due to errors or miscategorization
	# in new jazzhands entries.
	#
	$pc->print(qq{set yrange [ 0 : 60 ]\n});
	$pc->print(qq{set format x "\%m/\%y"\n});
	$pc->print(qq{plot });
	$hdrno     = 2;
	$totalhdrs = $#{@$headers};
	$comma     = ",";
	my $buf = "";

	for ( my $i = 0 ; $i <= $totalhdrs ; $i++ ) {
		my $header = @$headers[$i];
		$comma = "" if ( $i == $totalhdrs );
		if (       ( $header ne "total" )
			&& ( $header ne "server" )
			&& ( $header ne "router" )
			&& ( $header ne "netcam" )
			&& ( $header ne "switch" )
			&& ( $header ne "tdmaccess" )
			&& ( $header ne "printer" )
			&& ( $header ne "consolesrv" ) )
		{
			$buf .= qq{ "$statfn" using 1:$hdrno smooth bezier };
			$buf .= qq{title "$header"$comma};
		}
		$hdrno++;
	}
	$buf =~ s/\,$//;    # trim trailing comma

	$pc->print(qq{$buf\n});
	$pc->print(qq{set nomultiplot\n});

	$pc->close;
	$tmpfile;
}

sub process_stats {
	my ( $statf, $whence, $headers, $stuff ) = @_;

	$whence =~ s/\s.*$//;
	$whence =~ s,/,-,g;

	my $totalhdrs = $#{@$headers};
	$statf->print("$whence ");

	my $valsprinted = 0;
	foreach my $hdr (@$headers) {
		if ( defined( $stuff->{$hdr} ) ) {
			$statf->print( $stuff->{$hdr} . " " );
		} else {
			$statf->print("0 ");
		}
		$valsprinted++;
	}
	for ( my $i = $valsprinted ; $i >= 0 ; $i-- ) {
		$statf->print("0 ");
	}
	$statf->print("\n");
}

sub generate_html {
	my ( $stats, $headers, $htmlfn, $imagename ) = @_;

	my $html = new FileHandle(">$htmlfn") || die "$htmlfn";
	my $cgi = new CGI;

	$html->print(
		$cgi->start_html( { -title => 'Elements in System DB' } ) );
	$html->print(
		$cgi->h1( { -align => 'center' }, 'Elements in System DB' ) );

	$html->print("\n\n");
	$html->print(
		$cgi->center(
			$cgi->img( { -align => 'center', -src => $imagename } )
			  . "\n"
		)
	);

	$html->print( $cgi->start_table( { -align => 'center', -border => 1 } ),
		"\n" );

	foreach my $header (@$headers) {
		$html->print(
			$cgi->Tr(
				$cgi->td(
"Number of $header elements in JazzHands"
				),
				$cgi->td(
					(
						(
							defined(
								$stats
								  ->{$header}
							)
						) ? $stats->{$header} : ""
					)
				)
			)
		);
	}

	$html->print( $cgi->end_table, "\n" );
	$html->print( $cgi->hr, "Last Generated: ", ctime(time), "\n" );

	$html->print( $cgi->end_html, "\n" );

	$html->close;
}

############################################################################
#
# everything starts here
#
############################################################################

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

my $statfn = "/tmp/graph-devtotals-stats.data.$$";
my $statf = new FileHandle(">$statfn") || die "$statfn: $!";

my $q = q{
	select 	to_char(whence, 'YYYYMMDD'),
		device_function_type, tally
	  from	dev_function_history
	order by whence
};

my $sth = $dbh->prepare($q) || die $dbh->errstr;
$sth->execute || die $sth->errstr;

my (@headers);
push( @headers, 'total' );
my (%stats);
my $lastwhence = "";
my $total      = 0;
while ( my ( $whence, $devfunctype, $tally ) = $sth->fetchrow_array ) {
	if ( $whence ne $lastwhence ) {
		if ( length($lastwhence) ) {
			process_stats( $statf, $whence, \@headers, \%stats );
		}
		undef %stats;
		$lastwhence = $whence;
	}
	$stats{$devfunctype} = $tally;
	if ( !grep( $devfunctype eq $_, @headers ) ) {
		push( @headers, $devfunctype );
	}
	$total++;
}

if ( defined($lastwhence) ) {
	process_stats( $statf, $lastwhence, \@headers, \%stats );
}

my $imagename = "devices_total.png";
my $imagefull = "$statsroot/$imagename";
my $htmlfn    = "$statsroot/devices_total.html";

my $cmdfn;
if ($total) {
	$cmdfn = make_gnuplotfile( $statfn, \@headers );
	system("/usr/local/bin/gnuplot 2>/dev/null $cmdfn > $imagefull");
}

generate_html( \%stats, \@headers, $htmlfn, $imagename );

unlink($cmdfn);
unlink($statfn);

$dbh->rollback;
$dbh->disconnect;
