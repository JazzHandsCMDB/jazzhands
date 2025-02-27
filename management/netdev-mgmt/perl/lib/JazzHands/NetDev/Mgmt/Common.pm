package JazzHands::NetDev::Mgmt::Common;

use strict;
use warnings;
use Data::Dumper;

#
# This is meant to be included by the __devtype libraries
#

use vars qw(@ISA %EXPORT_TAGS @EXPORT);

use Exporter;    # 'import';

our @ISA = qw( Exporter);

our @EXPORT;
our @EXPORT_OK = qw(GetExtendedIPAddressInformation);
our %EXPORT_TAGS = (
        'all' => [ @EXPORT_OK ],
);


sub GetExtendedIPAddressInformation {
	my $self = shift @_;

	# These are per device-type
	my $info = $self->GetIPAddressInformation(@_);
	my $vlan = $self->GetVLANs(@_);

	foreach my $iface (keys %{$info}) {
		if(my $xp = $vlan->{interfaces}->{$iface}) {
			$info->{$iface}->{encapsulation}->{type} = '802.1q';
			$info->{$iface}->{encapsulation}->{tag} = $xp->{id};
			$info->{$iface}->{encapsulation}->{name} = $xp->{name};
		}
	}
	$info;
}

1;
