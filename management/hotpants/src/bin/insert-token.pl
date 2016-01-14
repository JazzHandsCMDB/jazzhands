#!/usr/bin/env perl

use JazzHands::TokenDB;
use Getopt::Long;
use strict;
use warnings;

my $ekpurpose = 'tokenkey';

my ( $type, $pin, $modulo, $encrypt );

$encrypt = 1;

GetOptions(
	'type=s'   => \$type,
	'pin=s'    => \$pin,
	'encrypt!' => \$encrypt,
) || die "must specify type and pin";

die "no type!" if ( !$type );
die "no pin!"  if ( !$pin );

my $tok = new JazzHands::TokenDB(service => 'stab',
	'keymap' => '/etc/tokenmap.json',
) || die $JazzHands::TokenDB::errstr;

$tok->add_token($type, $pin);

print $tok->url(), "\n";

$tok->commit;
$tok->disconnect;
