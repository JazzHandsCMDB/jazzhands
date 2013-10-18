#use 5.008001;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
	NAME			=> 'JazzHands::DBI',
	VERSION_FROM	=>  'lib/JazzHands/DBI.pm',
	INSTALLDIRS		=> 'vendor'
);
