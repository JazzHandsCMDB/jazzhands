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

my $statsroot = shift(@ARGV) || "/prod/www/stab/docs/stats/by_mclass";

sub get_device_functions {
	my ($dbh) = @_;

	my $q = qq{
		select  DEVICE_FUNCTION_TYPE
		  from  val_device_function_type
	};

	my $sth = $dbh->prepare($q) || die $dbh->errstr;
	$sth->execute || die $sth->errstr;

	my (@rv);
	while ( my ($dft) = $sth->fetchrow_array ) {
		push( @rv, $dft );
	}

	\@rv;
}

sub make_gnuplotfile {
	my ($statfn) = @_;

	my $tmpfile = "/tmp/graph-mclass-stats.cmdfile.$$";

	my $pc = new FileHandle(">$tmpfile");

	$pc->print(qq{set term png\n});
	$pc->print(qq{set grid xtics ytics \n});
	$pc->print(qq{set data style lines\n});
	$pc->print(qq{set xdata time\n});
	$pc->print(qq{set format x "\%m/\%y"\n});
	$pc->print(qq{set timefmt "\%Y\%m\%d"\n});
	$pc->print(qq{set key left\n});
	$pc->print(qq{set title "Number of Elements by Function"\n});
	$pc->print(qq{set xlabel "Date"\n});
	$pc->print(qq{set ylabel "Number of elements [1]"\n});
	$pc->print(qq{plot "$statfn" using 1:2 smooth bezier });
	$pc->print(qq{title "Number of elements in an mclass",});
	$pc->print(qq{     "$statfn" using 1:3 smooth bezier });
	$pc->print(qq{title "Total Number of elements"});
	$pc->close;
	$tmpfile;
}

sub generate_html {
	my ( $dft, $mclass, $total, $htmlfn, $imagename ) = @_;

	my $html = new FileHandle(">$htmlfn") || die "$htmlfn";
	my $cgi = new CGI;

	my $title = "Mclass breakdown for $dft";

	$html->print( $cgi->start_html( { -title => $title } ) );
	$html->print( $cgi->h1( { -align => 'center' }, $title ) );

	$html->print("\n\n");
	$html->print(
		$cgi->center(
			$cgi->img( { -align => 'center', -src => $imagename } )
			  . "\n"
		)
	);

	$html->print( $cgi->start_table( { -align => 'center', -border => 1 } ),
		"\n" );
	$html->print(
		$cgi->Tr(
			$cgi->td("Number of $dft devices in mclasses"),
			$cgi->td($mclass)
		)
	);
	$html->print(
		$cgi->Tr(
			$cgi->td("Total Number of $dft devices"),
			$cgi->td($total)
		)
	);
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

my $q = q{
	select 	to_char(whence, 'YYYYMMDD'),
			device_function_type, total_in_mclass, total
	  from	dev_function_mclass_history
	 where	dev_function_mclass_history.device_function_type = :1
	order by whence
};

my $sth = $dbh->prepare($q) || die $dbh->errstr;

my $functions = get_device_functions($dbh);
push( @$functions, "total" );

foreach my $dft (@$functions) {
	$sth->execute($dft) || die "$q/$dft: " . $sth->errstr;

	my $statfn = "/tmp/graph-mclass-stats.data.$$";
	my $statf = new FileHandle(">$statfn") || die "$statfn: $!";

	my ( $final_mclass, $final_total );
	while ( my ( $whence, $devfunctype, $mclass, $total ) =
		$sth->fetchrow_array )
	{
		$statf->print("$whence $mclass $total\n");
		$final_mclass = $mclass;
		$final_total  = $total;
	}

	my $imagename = "mclass_summary_$dft.png";
	my $imagefull = "$statsroot/$imagename";
	my $htmlfn    = "$statsroot/mclass_summary_$dft.html";

	my $cmdfn;
	$cmdfn = make_gnuplotfile($statfn);
	system("/usr/local/bin/gnuplot 2>/dev/null $cmdfn > $imagefull");

	generate_html( $dft, $final_mclass, $final_total, $htmlfn, $imagename );

	unlink($cmdfn);
	unlink($statfn);
}

generate_index_html( $functions, "$statsroot/index.html" );

sub generate_index_html {
	my ( $funcs, $fn ) = @_;

	my $cgi = new CGI;

	my $f = new FileHandle(">$fn") || die "$fn: $!";

	my $title = "Breakdown of Devices vs Devices in Mclasses";

	$f->print( $cgi->start_html( { -title => $title } ) );

	$f->print( $cgi->h2($title), "\n" );

	my $x = "";
	foreach my $dft (@$funcs) {
		my $pg = "mclass_summary_$dft.html";
		$x .= $cgi->li( $cgi->a( { -href => $pg }, $dft ) );
	}

	$f->print( $cgi->ul($x), "\n" );

	$f->print( $cgi->end_html );
	$f->close;
}

$dbh->rollback;
$dbh->disconnect;
