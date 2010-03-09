
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

=head1 NAME

 JazzHands::Management::Sudoers - JazzHands Perl interface to manipulate sudoers

=head1 SYNOPSIS

 $jh->InitializeSudoCache(-cache_name => $cache_name);

 $defaults = $jh->GetSudoDefaultsForMclass(-mclassid => $mclassid);

 %al_def = $jh->GetSudoCmndAliasesForMclass(-mclassid => $mclassid);

 %uc_name = $jh->GetSudoUclassesForMclass(-mclassid => $mclassid);

 $user_aliases = $jh->GetSudoersUserAliases(%uc_name);

 $sudoers = $jh->GetSudoersFile(-mclassid => $mclassid);

 $is_success = $jh->WriteSudoersFile(-mclassid => $mclassid,
                                        -filename => $filename);

 $aref = $jh->GetSudoDefaults;

 $value = $jh->GetSudoDefault(-id => $id);

 $is_success = $jh->SetSudoDefault(-id => $id, -value => $value);

 $is_success = $jh->NewSudoDefault(-value => $value);

 $is_success = $jh->DeleteSudoDefault(-id => $id, -value => $value);

 $is_success = $jh->AddSudoDefaultToMclass(-id => $id,
                                          -mclass => $mclass);

 $is_success = $jh->RemoveSudoDefaultFromMclass(-mclass $mclass);

 @names = $jh->GetSudoCmndAliasNames;

 $value = $jh->GetSudoCmndAlias(-name $name);

 $is_success = $jh->SetSudoCmndAlias(-name $name, -value => $value);

 $is_success = NewSudoCmndAlias(-name => $name, -value => $value);

 $is_success = DeleteSudoCmndAlias(-name => $name);

 $is_success = RenameSudoCmndAlias(-name => $name, -newname => $newname);

 $is_success = AddSudoCmndAliasToMclass(
                   -name => $cmnd_alias,
                 { -uclass => $uclass | -user => $user }
                   -mclass => $mclass,
                 { -run_as_uclass => $uclass | -run_as_user => $user }
                 [ -exec_flag => $exec_flag, ]
                 [ -passwd_flag => $passwd_flag ]);

 $is_success = RemoveSudoCmndAliasFromMclass(
                   -name => $cmnd_alias,
                 { -uclass => $uclass | -user => $user }
                   -mclass => $mclass);

 $aref = GetSudoDependencies(
                   -name => $cmnd_alias,
                 [ -uclass => $uclass | -user => $user ]
                   -mclass => $mclass,
                 [ -run_as_uclass => $uclass | -run_as_user => $user ]
                 [ -default => $id ]);

 $is_success = ShouldGenerateSudoers(-mclass => $mclass, -flag => $yn);

=head1 DESCRIPTION

JazzHands::Management::Sudoers module provides an object oriented interface
to manipulate sudoers information in JazzHands, namely tables SUDO_ALIAS,
SUDO_DEFAULT, and SUDO_UCLASS_DEVICE_COLLECTION.

=head1 METHODS

=over 4

=cut

###############################################################################

package JazzHands::Management::Sudoers;

use strict;
use vars qw($VERSION @EXPORT @ISA);
use IO::File;
use FindBin qw($Script);

$VERSION = '1.0.0';

require Exporter;
our @ISA = ( "Exporter", "JazzHands::Management" );

@EXPORT = qw(
  InitializeSudoCache
  GetSudoDefaultsForMclass
  GetSudoCmndAliasesForMclass
  GetSudoUclassesForMclass
  GetSudoersUserAliases
  GetSudoersFile
  WriteSudoersFile
  GetSudoDefaults
  GetSudoDefault
  SetSudoDefault
  NewSudoDefault
  DeleteSudoDefault
  AddSudoDefaultToMclass
  RemoveSudoDefaultFromMclass
  GetSudoCmndAliasNames
  GetSudoCmndAlias
  SetSudoCmndAlias
  NewSudoCmndAlias
  DeleteSudoCmndAlias
  RenameSudoCmndAlias
  AddSudoCmndAliasToMclass
  RemoveSudoCmndAliasFromMclass
  GetSudoDependencies
  ShouldGenerateSudoers
);

our %__cache_query = (
	defaults => qq{
        select c.device_collection_id, sudo_value
        from sudo_default d, device_collection c
        where c.sudo_default_id = d.sudo_default_id
    },

	cmnd_aliases => qq{
        select device_collection_id, a.sudo_alias_name, sudo_alias_value
        from sudo_uclass_device_collection c, sudo_alias a
        where c.sudo_alias_name = a.sudo_alias_name
    },

	uclasses => qq{
        select distinct c1.device_collection_id, 'U', u1.uclass_id, u1.name
        from sudo_uclass_device_collection c1, uclass u1
        where c1.uclass_id = u1.uclass_id
        union
        select distinct c2.device_collection_id, 'R', 
               c2.run_as_uclass_id, u2.name
        from sudo_uclass_device_collection c2, uclass u2
        where c2.run_as_uclass_id = u2.uclass_id
        and c2.run_as_uclass_id is not null
    },

	user_spec => qq{
        select device_collection_id, sudo_alias_name, uclass_id,
               run_as_uclass_id, requires_password, can_exec_child
        from sudo_uclass_device_collection
        order by uclass_id
    },

	should_generate => qq{
        select device_collection_id, should_generate_sudoers
        from device_collection
    }
);

###############################################################################

sub import {
	JazzHands::Management::Sudoers->export_to_level( 1, @_ );
}

###############################################################################

sub _options {
	my %ret = @_;
	for my $v ( grep { /^-/ } keys %ret ) {
		$ret{ substr( $v, 1 ) } = $ret{$v};
	}
	\%ret;
}

###############################################################################

=pod

=item InitializeSudoCache(-cache_name => $cache_name)

Initializes internal cache with the results of an SQL query. The query
is selected from the %__cache_query hash using $cache_name as the
key. Each query in %__cache_query must return DEVICE_COLLECTION_ID as
the first column. The cache is stored as a hash reference
$self->{__sudo_cache_$cache_name}. The keys of the hash are
DEVICE_COLLECTION_IDs, values are array references. The array consists
of the remaining columns returned by the query. InitializeSudoCache
returns undef on error.

=cut

###############################################################################

sub InitializeSudoCache {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( $dbh, $aref, %h );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error(
			"InitializeSudoCache: Invalid class reference passed");
		return undef;
	}

	## get the query results

	$aref =
	  $dbh->selectall_arrayref( $__cache_query{ $opt->{cache_name} } );

	unless ($aref) {
		$self->Error("InitializeSudoCache: $DBI::errstr");
		return undef;
	}

	## now build the cache hash so that the first column of the query
	## results becomes the key of the hash, the value will be the
	## remaining columns as a list

	foreach (@$aref) {
		my $k = shift(@$_);
		push( @{ $h{$k} }, @$_ );
	}

	$self->{"__sudo_cache_$opt->{cache_name}"} = \%h;
}

###############################################################################

=pod

=item GetSudoDefaultsForMclass(-mclassid => $mclassid)

Returns sudo defaults for the MCLASS $mclassid. The function caches
the results of the database query for all MCLASSes such that
subsequent calls do not need to query the database.

=cut

###############################################################################

sub GetSudoDefaultsForMclass {
	my $self = shift;
	my $opt  = &_options(@_);

	unless ( exists $self->{__sudo_cache_defaults} ) {
		return undef
		  unless (
			$self->InitializeSudoCache( -cache_name => 'defaults' )
		  );
	}

	return undef
	  unless ( exists $self->{__sudo_cache_defaults}
		&& exists $self->{__sudo_cache_defaults}
		->{ $opt->{mclassid} } );

	return $self->{__sudo_cache_defaults}->{ $opt->{mclassid} }->[0];
}

###############################################################################

=pod

=item GetSudoCmndAliasesForMclass(-mclassid => $mclassid)

Returns a hash whose keys are command aliases for the MCLASS
$mclassid, and values are command definitions. The function caches
the results of the database query for all MCLASSes such that
subsequent calls do not need to query the database.

=cut

###############################################################################

sub GetSudoCmndAliasesForMclass {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( $aref, %h );

	unless ( exists $self->{__sudo_cache_cmnd_aliases} ) {
		return ()
		  unless (
			$self->InitializeSudoCache(
				-cache_name => 'cmnd_aliases'
			)
		  );
	}

	return ()
	  unless ( exists $self->{__sudo_cache_cmnd_aliases}
		&& exists $self->{__sudo_cache_cmnd_aliases}
		->{ $opt->{mclassid} } );

	$aref = $self->{__sudo_cache_cmnd_aliases}->{ $opt->{mclassid} };
	return @$aref;
}

###############################################################################

=pod

=item GetSudoUclassesForMclass(-mclassid => $mclassid)

Returns a hash whose keys are UCLASS_IDs of the UCLASSes that need to
be expanded in the sudoers file for the MCLASS $mclassid with either
'U' or 'R' prepended to the UCLASS_ID depending on whether it needs to
expand into a User_Alias or Runas_Alias. Values are the user alias
names as they will appear in the sudoers file. The user alias name
consists of the letter 'U' or 'R' followed by the UCLASS_ID followed
by the UCLASS name. The function caches the results of the database
query for all MCLASSes such that subsequent calls do not need to query
the database.

=cut

###############################################################################

sub GetSudoUclassesForMclass {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( @c, %uc_name );

	unless ( exists $self->{__sudo_cache_uclasses} ) {
		return ()
		  unless (
			$self->InitializeSudoCache( -cache_name => 'uclasses' )
		  );
	}

	return ()
	  unless ( exists $self->{__sudo_cache_uclasses}
		&& exists $self->{__sudo_cache_uclasses}
		->{ $opt->{mclassid} } );

	@c = @{ $self->{__sudo_cache_uclasses}->{ $opt->{mclassid} } };

	## @c = ('U', uclassid, uclassname, 'R', uclassid, uclassname, ...)

	while (@c) {
		my $utype    = shift(@c);    ## 'R' or 'U'
		my $uclassid = shift(@c);
		my $name     = shift(@c);

		$name = uc($name);
		$name =~ s/\W/_/g;
		$name = "${utype}${uclassid}_${name}";
		$uc_name{"$utype$uclassid"} = $name;
	}

	return %uc_name;
}

###############################################################################
#
# $wrapped_text = _wrap($sep, $nl, $maxlen, @strings);
#
# Joins @strings using $sep or $nl as separators such that the length of the
# string from $nl to the next $nl is not longer than $maxlen
#
###############################################################################

sub _wrap {
	my ( $sep, $nl, $maxlen, @strings ) = @_;
	my ( $line, @lines );

	return '' unless ( $line = shift(@strings) );

	while (@strings) {
		my $s = shift(@strings);
		my $tl = join( $sep, $line, $s );

		if ( length($tl) > $maxlen ) {
			push( @lines, $line );
			$line = $s;
		}

		else {
			$line = $tl;
		}
	}

	return join( $nl, @lines, $line );
}

###############################################################################

=pod

=item GetSudoersUserAliases(\%uc_name);

The input parameter %uc_name is a reference to a hash returned by the
method GetSudoUclassesForMclass. Returns the part of the sudoers file
which contains user aliases for the MCLASS $mclassid or undef on
error. Also modifies %uc_name such that values for uclasses containing
just a single login are set to this login. Uclasses that would expand
as empty are deleted from %uc_name.

=cut

###############################################################################

sub GetSudoersUserAliases {
	my ( $self, $ucnref ) = @_;
	my $text = '';

	foreach my $ruclassid ( sort { $a cmp $b } keys %$ucnref ) {
		my ( $uclassid, $ids, @logins, $login );

		## strip the initial 'U' or 'R' from $ruclassid to get $uclassid

		$uclassid = $ruclassid;
		$uclassid =~ s/^[RU]//;

		## expand the uclass into the list of logins

		return undef
		  unless ( $ids =
			$self->GetAllUsersFromUclass( $uclassid, 0 ) );

		foreach my $key ( keys(%$ids) ) {
			$login = $self->GetUserFullData($key)->[0];
			push( @logins, $login );
		}

		## delete empty uclasses from $ucnref

		if ( $#logins < 0 ) {
			delete $ucnref->{$ruclassid};
		}

		## if the uclass expanded into a single login, modify $ucnref
		## appropriately

		elsif ( $#logins == 0 ) {
			$ucnref->{$ruclassid} = $login;
		}

		## otherwise write the expansion to the output

		else {
			my @sl = sort { $a cmp $b } @logins;
			my $ur_alias =
			  $ruclassid =~ /^U/ ? 'User_Alias' : 'Runas_Alias';

			$text .= _wrap(
				", ",
				",\\\n\t",
				70,
				"$ur_alias $ucnref->{$ruclassid} = "
				  . shift(@sl),
				sort { $a cmp $b } @sl
			) . "\n";
		}
	}

	return $text;
}

###############################################################################

=pod

=item GetSudoersFile(-mclassid => $mclassid)

Returns the content of the sudoers file for the MCLASS $mclassid. The
function caches the results of the database query for all MCLASSes
such that subsequent calls do not need to query the database.

=cut

###############################################################################

sub GetSudoersFile {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( @ids, $text, $default, %sg, %cmnd, %ucn, @uspec );

	$text =
"# Do not edit this file, it is generated automatically. All changes\n"
	  . "# made by hand will be lost.\n"
	  . "# Generated on "
	  . scalar( gmtime(time) )
	  . " by $Script\n"
	  . "# Sudoers.pm "
	  . '$Revision$' . "\n\n";

	%cmnd = %ucn = @uspec = ();

	## initialize the user spec cache

	unless ( exists $self->{__sudo_cache_user_spec} ) {
		return undef
		  unless (
			$self->InitializeSudoCache(
				-cache_name => 'user_spec'
			)
		  );
	}

	## initialize the cache which holds the information about which
	## mclasses sudoers files should be generated for

	unless ( exists $self->{__sudo_cache_should_generate} ) {
		return undef
		  unless (
			$self->InitializeSudoCache(
				-cache_name => 'should_generate'
			)
		  );
	}

	## determine the mclass id if the mclass name was specified

	if ( defined $opt->{mclass} ) {
		my ( $dbh, $q, $sth, @row );

		if ( ref($self) ) {
			$dbh = $self->DBHandle;
		}

		if ( !$dbh ) {
			$self->Error(
				"GetSudoersFile: Invalid class reference passed"
			);
			return undef;
		}

		$q = qq{
            select device_collection_id from device_collection where name = ?
        };

		unless ( $sth = $dbh->prepare($q) ) {
			$self->Error("GetSudoersFile: $DBI::errstr");
			return undef;
		}

		unless ( $sth->execute( $opt->{mclass} ) ) {
			$self->Error("GetSudoersFile: $DBI::errstr");
			return undef;
		}

		unless ( @row = $sth->fetchrow_array ) {
			$self->Error( "GetSudoersFile: "
				  . "mclass $opt->{mclass} does not exist" );
			return undef;
		}

		$opt->{mclassid} = $row[0];
	}

	## include a comment if generation of this sudoers file is disabled

	return undef
	  unless ( exists $self->{__sudo_cache_should_generate}
		&& exists $self->{__sudo_cache_should_generate}
		->{ $opt->{mclassid} } );

	%sg = %{ $self->{__sudo_cache_should_generate} };

	if ( $sg{ $opt->{mclassid} }->[0] eq 'N' ) {
		$text =
		  "\n#### Generation of this sudoers file is disabled ####\n\n"
		  . $text;
	}

	## build the inheritance sequence of MCLASS_IDs

	@ids = $self->GetParentsForMclass( $opt->{mclassid}, 1 );
	push( @ids, $opt->{mclassid} );

	## walk the MCLASS inheritance tree from the top down
	## and build the data structures that will be used later

	foreach my $mclassid (@ids) {
		my $d =
		  $self->GetSudoDefaultsForMclass( -mclassid => $mclassid );
		my %u =
		  $self->GetSudoUclassesForMclass( -mclassid => $mclassid );
		my %c =
		  $self->GetSudoCmndAliasesForMclass( -mclassid => $mclassid );

		## more specific defaults replace less specific ones

		$default = $d if ( defined $d );

		## uclass and command aliases are merged

		%ucn  = ( %ucn,  %u ) if (%u);
		%cmnd = ( %cmnd, %c ) if (%c);

		next
		  unless ( exists $self->{__sudo_cache_user_spec}
			&& exists $self->{__sudo_cache_user_spec}
			->{$mclassid} );

		## user specifications are merged too

		push( @uspec,
			@{ $self->{__sudo_cache_user_spec}->{$mclassid} } );
	}

	## add defaults to the output

	$text .= "# Defaults specification\n\n";

	if ( defined $default ) {
		chomp($default);
		$text .= "Defaults $default\n\n";
	}

	$text .= "# Cmnd alias specification\n\n";

	## add command aliases to the output

	foreach ( sort { $a cmp $b } keys %cmnd ) {
		next if ( $_ eq 'ALL' );
		chomp( $cmnd{$_} );
		$text .= "Cmnd_Alias $_ = $cmnd{$_}\n";
	}

	$text .= "\n# User alias specification\n\n";

	## add user aliases to the output

	if (%ucn) {
		$text .= $self->GetSudoersUserAliases( \%ucn );
	}

	$text .= "\n# User privilege specification\n\n";

	## add user specifications to the output

	while (@uspec) {
		my $cmnd_alias = shift(@uspec);
		my $uclass_id  = shift(@uspec);
		my $run_asid   = shift(@uspec) || 'ALL';
		my $ynpass     = shift(@uspec);
		my $ynexec     = shift(@uspec);
		my ( $uclass, $runas );

		## user specifications for empty uclasses are excluded

		next if ( !exists( $ucn{"U$uclass_id"} ) );
		next if ( $run_asid ne 'ALL' && !exists( $ucn{"R$run_asid"} ) );

		$uclass = $ucn{"U$uclass_id"};
		$runas = $run_asid eq 'ALL' ? 'ALL' : $ucn{"R$run_asid"};

		## $ynpass and $ynexec can be NULL, 'Y', or 'N'

		$ynpass =
		  defined($ynpass)
		  ? ( $ynpass eq 'Y' ? 'PASSWD:' : 'NOPASSWD:' )
		  : '';

		$ynexec =
		  defined($ynexec)
		  ? ( $ynexec eq 'Y' ? 'EXEC:' : 'NOEXEC:' )
		  : '';

		$text .= "$uclass ALL = ($runas) $ynpass$ynexec$cmnd_alias\n";
	}

	return $text;
}

###############################################################################

=pod

=item WriteSudoersFile(-mclassid => $mclassid, -filename => $filename)

Calls GetSudoersFile and writes the result to the file $filename.

=cut

###############################################################################

sub WriteSudoersFile {
	my $self  = shift;
	my $opt   = &_options(@_);
	my $tmpfn = $opt->{filename} . ".$$";
	my ( $text, $fh, %sg );

	## initialize the cache which holds the information about which
	## mclasses sudoers files should be generated for

	unless ( exists $self->{__sudo_cache_should_generate} ) {
		return undef
		  unless (
			$self->InitializeSudoCache(
				-cache_name => 'should_generate'
			)
		  );
	}

	return undef
	  unless ( exists $self->{__sudo_cache_should_generate}
		&& exists $self->{__sudo_cache_should_generate}
		->{ $opt->{mclassid} } );

	## stop if should_generate = 'N'

	%sg = %{ $self->{__sudo_cache_should_generate} };

	if ( $sg{ $opt->{mclassid} }->[0] eq 'N' ) {
		$self->Error("WriteSudoersFile: should_generate = 'N'");
		return undef;
	}

	## get the sudoers file content

	return undef unless ( $text = $self->GetSudoersFile(@_) );

	## write the content to a temporary file

	unless ( $fh = IO::File->new(">$tmpfn") ) {
		$self->Error("WriteSudoersFile: can't open $tmpfn");
		return undef;
	}

	print $fh $text;
	$fh->close;

	## rename the temporary file to $opt->{filename}

	unlink( $opt->{filename} );

	unless ( rename( $tmpfn, $opt->{filename} ) ) {
		$self->Error("WriteSudoersFile: rename failed: $!");
		unlink($tmpfn);
		return undef;
	}

	return 1;
}

###############################################################################

=pod

=item GetSudoDefaults

Returns a reference to a list of lists. The first column of each list
is sudo_default_id, the second is sudo_value.

=cut

###############################################################################

sub GetSudoDefaults {
	my $self = shift;
	my ( $dbh, $q, $aref );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error("GetSudoDefaults: Invalid class reference passed");
		return undef;
	}

	$q = qq{
        select sudo_default_id, sudo_value from sudo_default
        order by sudo_default_id
    };

	unless ( $aref = $dbh->selectall_arrayref($q) ) {
		$self->Error("GetSudoDefaults: $DBI::errstr");
		return undef;
	}

	return $aref;
}

###############################################################################

=pod

=item GetSudoDefault(-id => $id)

Returns the sudo_value of the sudo default with sudo_default_id = $id.

=cut

###############################################################################

sub GetSudoDefault {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( $dbh, $q, $sth, @row );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error("GetSudoDefault: Invalid class reference passed");
		return undef;
	}

	$q = qq{select sudo_value from sudo_default where sudo_default_id = ?};

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("GetSudoDefault: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $opt->{id} ) ) {
		$self->Error("GetSudoDefault: $DBI::errstr");
		return undef;
	}

	unless ( @row = $sth->fetchrow_array ) {
		$self->Error( "GetSudoDefault: "
			  . "sudo_default_id $opt->{id} does not exist" );
		return undef;
	}

	return $row[0];
}

###############################################################################

=pod

=item SetSudoDefault(-id => $sudo_default_id, -value => $sudo_value)

Sets the sudo_value of the sudo default with sudo_default_id = $id to
$sudo_value.

=cut

###############################################################################

sub SetSudoDefault {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( $dbh, $q, $sth );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error("SetSudoDefault: Invalid class reference passed");
		return undef;
	}

	$q =
	  qq{update sudo_default set sudo_value = ? where sudo_default_id = ?};

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("SetSudoDefault: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $opt->{value}, $opt->{id} ) ) {
		$self->Error("SetSudoDefault: $DBI::errstr");
		return undef;
	}

	unless ( $sth->rows ) {
		$self->Error( "SetSudoDefault: "
			  . "sudo_default_id $opt->{id} does not exist" );
		return undef;
	}

	$dbh->commit;
	return 1;
}

###############################################################################

=pod

=item NewSudoDefault(-value => $value)

Creates a new entry in the sudo_default table with the value $value.

=cut

###############################################################################

sub NewSudoDefault {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( $dbh, $q, $sth );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error("NewSudoDefault: Invalid class reference passed");
		return undef;
	}

	$q = qq{insert into sudo_default(sudo_value)  values(?)};

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("NewSudoDefault: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $opt->{value} ) ) {
		$self->Error("NewSudoDefault: $DBI::errstr");
		return undef;
	}

	unless ( $sth->rows ) {
		$self->Error(
			"NewSudoDefault: this should not happen, seek help");
		return undef;
	}

	$dbh->commit;
	return 1;
}

###############################################################################

=pod

=item DeleteSudoDefault(-id => $sudo_default_id)

Deletes then entry in the sudo_defaults table with the specified
sudo_default_id.

=cut

###############################################################################

sub DeleteSudoDefault {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( $dbh, $q, $sth );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error(
			"DeleteSudoDefault: Invalid class reference passed");
		return undef;
	}

	$q = qq{delete from sudo_default where sudo_default_id = ?};

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("DeleteSudoDefault: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $opt->{id} ) ) {
		$self->Error("DeleteSudoDefault: $DBI::errstr");
		return undef;
	}

	unless ( $sth->rows ) {
		$self->Error( "DeleteSudoDefault: "
			  . "sudo_default_id $opt->{id} does not exist" );
		return undef;
	}

	$dbh->commit;
	return 1;
}

###############################################################################

=pod

=item AddSudoDefaultToMclass(-id => $sudo_default_id, -mclass $mclass)

Assigns sudo default with the sudo_default_id $sudo_default_id to the
mclass $mclass. previous sudo_default_id in the device_collection
table is overwritten.

=cut

###############################################################################

sub AddSudoDefaultToMclass {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( $dbh, $q, $sth, @row, $mclassid );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error(
			"AddSudoDefaultToMclass: Invalid class reference passed"
		);
		return undef;
	}

	$q =
	  qq{select device_collection_id from device_collection where name = ?};

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("AddSudoDefaultToMclass: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $opt->{mclass} ) ) {
		$self->Error("AddSudoDefaultToMclass: $DBI::errstr");
		return undef;
	}

	unless ( @row = $sth->fetchrow_array ) {
		$self->Error( "AddSudoDefaultToMclass: "
			  . "mclass $opt->{mclass} does not exist" );
		return undef;
	}

	$mclassid = $row[0];
	$sth->finish;

	$q = qq{
        update device_collection set sudo_default_id = ?
        where device_collection_id = ?
    };

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("AddSudoDefaultToMclass: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $opt->{id}, $mclassid ) ) {
		$self->Error("AddSudoDefaultToMclass: $DBI::errstr");
		return undef;
	}

	unless ( $sth->rows ) {
		$self->Error( "AddSudoDefaultToMclass: "
			  . "sudo_default_id $opt->{id} does not exist" );
		return undef;
	}

	$dbh->commit;
	return 1;
}

###############################################################################

=pod

=item RemoveSudoDefaultFromMclass(-mclass $mclass)

Remove sudo default from mclass $mclass, and set sudo_default_id to NULL.

=cut

###############################################################################

sub RemoveSudoDefaultFromMclass {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( $dbh, $q, $sth, @row, $mclassid );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error( "RemoveSudoDefaultFromMclass: "
			  . "Invalid class reference passed" );
		return undef;
	}

	$q =
	  qq{select device_collection_id from device_collection where name = ?};

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("RemoveSudoDefaultFromMclass: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $opt->{mclass} ) ) {
		$self->Error("RemoveSudoDefaultFromMclass: $DBI::errstr");
		return undef;
	}

	unless ( @row = $sth->fetchrow_array ) {
		$self->Error( "RemoveSudoDefaultFromMclass: "
			  . "mclass $opt->{mclass} does not exist" );
		return undef;
	}

	$mclassid = $row[0];
	$sth->finish;

	$q = qq{
        update device_collection set sudo_default_id = NULL
        where device_collection_id = ?
    };

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("RemoveSudoDefaultFromMclass: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute($mclassid) ) {
		$self->Error("RemoveSudoDefaultFromMclass: $DBI::errstr");
		return undef;
	}

	unless ( $sth->rows ) {
		$self->Error( "RemoveSudoDefaultFromMclass: "
			  . "this should not happen, seek help" );
		return undef;
	}

	$dbh->commit;
	return 1;
}

###############################################################################

=pod

=item GetSudoCmndAliasNames

Returns a reference to a list of sudo command aliases.

=cut

###############################################################################

sub GetSudoCmndAliasNames {
	my $self = shift;
	my ( $dbh, $q, $aref );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error(
			"GetSudoCmndAliases: Invalid class reference passed");
		return undef;
	}

	$q =
	  qq{select sudo_alias_name from sudo_alias order by sudo_alias_name};

	unless ( $aref = $dbh->selectcol_arrayref($q) ) {
		$self->Error("GetSudoCmndAliases: $DBI::errstr");
		return undef;
	}

	return $aref;
}

###############################################################################

=pod

=item GetSudoCmndAlias(-name => $name)

Returns the value of sudo command alias with the name $name.

=cut

###############################################################################

sub GetSudoCmndAlias {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( $dbh, $q, $sth, @row );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error(
			"GetSudoCmndAlias: Invalid class reference passed");
		return undef;
	}

	$q =
	  qq{select sudo_alias_value from sudo_alias where sudo_alias_name = ?};

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("GetSudoCmndAlias: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $opt->{name} ) ) {
		$self->Error("GetSudoCmndAlias: $DBI::errstr");
		return undef;
	}

	unless ( @row = $sth->fetchrow_array ) {
		$self->Error( "GetSudoCmndAlias: "
			  . "sudo_alias_name $opt->{name} does not exist" );
		return undef;
	}

	return $row[0];
}

###############################################################################

=pod

=item SetSudoCmndAlias(-name => $name, -value => $value)

Sets the value of a sudo command alias with the name $name to the value $value.

=cut

###############################################################################

sub SetSudoCmndAlias {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( $dbh, $q, $sth );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error(
			"SetSudoCmndAlias: Invalid class reference passed");
		return undef;
	}

	if ( $opt->{name} eq 'ALL' ) {
		$self->Error("SetSudoCmndAlias: Alias ALL cannot be modified");
		return undef;
	}

	$q = qq{
        update sudo_alias set sudo_alias_value = ? where sudo_alias_name = ?
    };

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("SetSudoCmndAlias: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $opt->{value}, $opt->{name} ) ) {
		$self->Error("SetSudoCmndAlias: $DBI::errstr");
		return undef;
	}

	unless ( $sth->rows ) {
		$self->Error( "SetSudoCmndAlias: "
			  . "sudo_default_id $opt->{name} does not exist" );
		return undef;
	}

	$dbh->commit;
	return 1;
}

###############################################################################

=pod

=item NewSudoCmndAlias(-name => $name, -value => $value)

Creates a new sudo command alias entry with the name $name and value $value.

=cut

###############################################################################

sub NewSudoCmndAlias {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( $dbh, $q, $sth );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error(
			"NewSudoCmndAlias: Invalid class reference passed");
		return undef;
	}

	$q = qq{
        insert into sudo_alias(sudo_alias_name, sudo_alias_value)
        values(?, ?)
    };

	unless ( $opt->{name} =~ /^[A-Z][A-Z0-9_]*$/ ) {
		$self->Error("NewSudoCmndAlias: Invalid command alias name");
		return undef;
	}

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("NewSudoCmndAlias: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $opt->{name}, $opt->{value} ) ) {
		$self->Error("NewSudoCmndAlias: $DBI::errstr");
		return undef;
	}

	unless ( $sth->rows ) {
		$self->Error(
			"NewSudoCmndAlias: this should not happen, seek help");
		return undef;
	}

	$dbh->commit;
	return 1;
}

###############################################################################

=pod

=item DeleteSudoCmndAlias(-name => $name)

Deletes the sudo command alias with then name $name.

=cut

###############################################################################

sub DeleteSudoCmndAlias {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( $dbh, $q, $sth );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error(
			"DeleteSudoCmndAlias: Invalid class reference passed");
		return undef;
	}

	if ( $opt->{name} eq 'ALL' ) {
		$self->Error(
			"DeleteSudoCmndAlias: Alias ALL cannot be deleted");
		return undef;
	}

	$q = qq{delete from sudo_alias where sudo_alias_name = ?};

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("DeleteSudoCmndAlias: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $opt->{name} ) ) {
		$self->Error("DeleteSudoCmndAlias: $DBI::errstr");
		return undef;
	}

	unless ( $sth->rows ) {
		$self->Error( "DeleteSudoCmndAlias: "
			  . "command alias $opt->{name} does not exist" );
		return undef;
	}

	$dbh->commit;
	return 1;
}

###############################################################################

=pod

=item RenameSudoCmndAlias(-name => $name, -newname => $newname)

Rename the sudo command alias with the name $name to the new name $newname.

=cut

###############################################################################

sub RenameSudoCmndAlias {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( $dbh, $q, $sth );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error(
			"RenameSudoCmndAlias: Invalid class reference passed");
		return undef;
	}

	if ( $opt->{name} eq 'ALL' ) {
		$self->Error(
			"RenameSudoCmndAlias: Alias ALL cannot be renamed");
		return undef;
	}

	unless ( $opt->{newname} =~ /^[A-Z][A-Z0-9_]*$/ ) {
		$self->Error("RenameSudoCmndAlias: Invalid command alias name");
		return undef;
	}

	## defer the foreign key constraint

	$q = qq{set constraints all deferred};

	unless ( $dbh->do($q) ) {
		$self->Error("RenameSudoCmndAlias: $DBI::errstr");
		return undef;
	}

	## rename the command alias in the sudo_alias table

	$q = qq{
	update sudo_alias set sudo_alias_name = ?
        where sudo_alias_name = ?
    };

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("RenameSudoCmndAlias: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $opt->{newname}, $opt->{name} ) ) {
		$self->Error("RenameSudoCmndAlias: $DBI::errstr");
		return undef;
	}

	unless ( $sth->rows ) {
		$self->Error( "RenameSudoCmndAlias: "
			  . "command alias $opt->{name} does not exist" );
		$dbh->rollback;
		return undef;
	}

	## rename the command alias in the sudo_uclass_device_collection table

	$q = qq{
        update sudo_uclass_device_collection set sudo_alias_name = ?
        where sudo_alias_name = ?
    };

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("RenameSudoCmndAlias: $DBI::errstr");
		$dbh->rollback;
		return undef;
	}

	unless ( $sth->execute( $opt->{newname}, $opt->{name} ) ) {
		$self->Error("RenameSudoCmndAlias: $DBI::errstr");
		$dbh->rollback;
		return undef;
	}

	$dbh->commit;
	return 1;
}

###############################################################################

=pod

=item AddSudoCmndAliasToMclass(-name => $name, -mclass => $mclass,
-user => $user, -uclass => $uclass, -run_as_user => $run_as_user,
-run_as_uclass => $run_as_uclass, -exec_flag => $exec_flag,
-passwd_flag => $passwd_flag)

Creates an entry in the sudo_uclass_device_collection table, which
assigns a command alias to uclass/mclass combination. $user, $uclass,
$run_as_user, and $run_as_uclass are uclass names, $mclass is an
mclass name, and $exec_flag and $passwd_flag can be undef, 0, or 1. If
-user is specified, the uclass type is 'per-user', if -uclass is
specified, the uclass type is 'systems'. Similarly, if -run_as_user is
specified, the uclass type is 'per-user', if -run_as_uclass is
specified, the uclass type is 'systems'.

=cut

###############################################################################

sub AddSudoCmndAliasToMclass {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( $dbh, $q, $sth, @row );
	my ( $mclassid, $uclass, $utype, $uclassid, $runasid, $ynexec,
		$ynpass );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error( "AddSudoCmndAliasToMclass: "
			  . "Invalid class reference passed" );
		return undef;
	}

	## get the mclass_id

	$q =
	  qq{select device_collection_id from device_collection where name = ?};

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("AddSudoCmndAliasToMclass: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $opt->{mclass} ) ) {
		$self->Error("AddSudoCmndAliasToMclass: $DBI::errstr");
		return undef;
	}

	unless ( @row = $sth->fetchrow_array ) {
		$self->Error( "AddSudoCmndAliasToMclass: "
			  . "mclass $opt->{mclass} does not exist" );
		return undef;
	}

	$mclassid = $row[0];
	$sth->finish;

	## get the uclass_id

	$uclass = defined( $opt->{user} ) ? $opt->{user} : $opt->{uclass};
	$utype  = defined( $opt->{user} ) ? 'per-user'   : 'systems';

	$q =
	  qq{select uclass_id from uclass where name = ? and uclass_type = ?};

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("AddSudoCmndAliasToMclass: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $uclass, $utype ) ) {
		$self->Error("AddSudoCmndAliasToMclass: $DBI::errstr");
		return undef;
	}

	unless ( @row = $sth->fetchrow_array ) {
		$self->Error( "AddSudoCmndAliasToMclass: "
			  . "uclass $uclass of type $utype does not exist" );
		return undef;
	}

	$uclassid = $row[0];
	$sth->finish;

	## get the runasid

	$uclass =
	  defined( $opt->{run_as_user} )
	  ? $opt->{run_as_user}
	  : $opt->{run_as_uclass};
	$utype = defined( $opt->{run_as_user} ) ? 'per-user' : 'systems';

	if ( $uclass ne 'ALL' ) {
		unless ( $sth->execute( $uclass, $utype ) ) {
			$self->Error("AddSudoCmndAliasToMclass: $DBI::errstr");
			return undef;
		}

		unless ( @row = $sth->fetchrow_array ) {
			$self->Error( "AddSudoCmndAliasToMclass: "
				  . "uclass $uclass of type $utype does not exist"
			);
			return undef;
		}

		$runasid = $row[0];
		$sth->finish;
	}

	## get the flags

	$ynexec =
	  defined( $opt->{exec_flag} )
	  ? ( $opt->{exec_flag} ? 'Y' : 'N' )
	  : undef;
	$ynpass =
	  defined( $opt->{passwd_flag} )
	  ? ( $opt->{passwd_flag} ? 'Y' : 'N' )
	  : undef;

	$q = qq{
        insert into sudo_uclass_device_collection
        (sudo_alias_name, device_collection_id,
        uclass_id, run_as_uclass_id, requires_password, can_exec_child)
        values(?, ?, ?, ?, ?, ?)
    };

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("AddSudoCmndAliasToMclass: $DBI::errstr");
		return undef;
	}

	unless (
		$sth->execute(
			$opt->{name}, $mclassid, $uclassid,
			$runasid,     $ynpass,   $ynexec
		)
	  )
	{
		$self->Error("AddSudoCmndAliasToMclass: $DBI::errstr");
		return undef;
	}

	unless ( $sth->rows ) {
		$self->Error( "AddSudoCmndAliasToMclass: "
			  . "this should not happen, seek help" );
		return undef;
	}

	$dbh->commit;
	return 1;
}

###############################################################################

=pod

=item RemoveSudoCmndAliasFromMclass(-name => $cmnd_alias, -uclass =>
$uclass, -user => $user, -mclass => $mclass);

Removes an entry from the sudo_uclass_device_collection table
specified by the command alias name, uclass name, and the mclass name.

=cut

###############################################################################

sub RemoveSudoCmndAliasFromMclass {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( $dbh, $q, $sth, @row, $uclass, $utype, $mclassid, $uclassid );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error( "RemoveSudoCmndAliasFromMclass: "
			  . "Invalid class reference passed" );
		return undef;
	}

	## get the mclass_id

	$q =
	  qq{select device_collection_id from device_collection where name = ?};

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("RemoveSudoCmndAliasFromMclass: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $opt->{mclass} ) ) {
		$self->Error("RemoveSudoCmndAliasFromMclass: $DBI::errstr");
		return undef;
	}

	unless ( @row = $sth->fetchrow_array ) {
		$self->Error( "RemoveSudoCmndAliasFromMclass: "
			  . "mclass $opt->{mclass} does not exist" );
		return undef;
	}

	$mclassid = $row[0];
	$sth->finish;

	## get the uclass_id

	$uclass = defined( $opt->{user} ) ? $opt->{user} : $opt->{uclass};
	$utype  = defined( $opt->{user} ) ? 'per-user'   : 'systems';

	$q =
	  qq{select uclass_id from uclass where name = ? and uclass_type = ?};

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("RemoveSudoCmndAliasFromMclass: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $uclass, $utype ) ) {
		$self->Error("RemoveSudoCmndAliasFromMclass: $DBI::errstr");
		return undef;
	}

	unless ( @row = $sth->fetchrow_array ) {
		$self->Error( "RemoveSudoCmndAliasFromMclass: "
			  . "uclass $uclass of type $utype does not exist" );
		return undef;
	}

	$uclassid = $row[0];
	$sth->finish;

	$q = qq{
        delete from sudo_uclass_device_collection
        where sudo_alias_name = ? and device_collection_id = ?
        and uclass_id = ?
    };

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("RemoveSudoCmndAliasFromMclass: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $opt->{name}, $mclassid, $uclassid ) ) {
		$self->Error("RemoveSudoCmndAliasFromMclass: $DBI::errstr");
		return undef;
	}

	unless ( $sth->rows ) {
		$self->Error( "RemoveSudoCmndAliasFromMclass: "
			  . "the specified entry does not exist" );
		return undef;
	}

	$dbh->commit;
	return 1;
}

###############################################################################

=pod

=item GetSudoDependencies([ -cmnd_alias => $cmnd_alias, ]
[ -user => $user, ] [ -uclass => $uclass, ] [ -mclass => $mclass, ]
[ -run_as_user => $run_as_user, ] [ -run_as_uclass => $run_as_uclass, ] 
[ -default => $id ]);

Return a reference to a list of lists of sudo dependencies. The
columns in the list are mclass, sudo_default_id,
should_generate_sudoers, sudo_alias_name, uclass, uclass type, run as
uclass, run as uclass type, requires_password, can_exec_child. If any
of the optional parameters are specified, only entries matching the
parameter are returned.

=cut

###############################################################################

sub GetSudoDependencies {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( $dbh, $q, $sth, $aref );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error(
			"GetSudoDependencies: Invalid class reference passed");
		return undef;
	}

	## assemble the SQL query

	$q = qq{
        select dc.name, dc.sudo_default_id, dc.should_generate_sudoers,
               s.sudo_alias_name, u.name, u.uclass_type,
               nvl(ru.name, 'ALL') runas, ru.uclass_type runas_type,
               s.requires_password, s.can_exec_child
        from sudo_uclass_device_collection s,
               device_collection dc, uclass u, uclass ru
        where s.run_as_uclass_id = ru.uclass_id (+)
        and s.uclass_id = u.uclass_id (+)
        and s.device_collection_id (+) = dc.device_collection_id
        and ((s.sudo_alias_name is null and dc.sudo_default_id is not null) or
             s.sudo_alias_name is not null)
    };

	if ( defined $opt->{cmnd_alias} ) {
		$q .= 'and s.sudo_alias_name = :1 ';
	}

	if ( defined $opt->{mclass} ) {
		$q .= 'and dc.name = :2 ';
	}

	if ( defined $opt->{user} ) {
		$q .= qq{and u.name = :3 and u.uclass_type = 'per-user'};
	}

	if ( defined $opt->{uclass} ) {
		$q .= qq{and u.name = :3 and u.uclass_type = 'systems'};
	}

	if ( defined $opt->{run_as_user} ) {
		if ( $opt->{run_as_user} eq 'ALL' ) {
			$q .= 'and ru.name is null ';
		}

		else {
			$q .=
			  qq{and ru.name = :5 and ru.uclass_type = 'per-user'};
		}
	}

	if ( defined $opt->{run_as_uclass} ) {
		if ( $opt->{run_as_uclass} eq 'ALL' ) {
			$q .= 'and ru.name is null ';
		}

		else {
			$q .=
			  qq{and ru.name = :5 and ru.uclass_type = 'systems'};
		}
	}

	if ( defined $opt->{default} ) {
		$q .= qq{
            and dc.sudo_default_id = :4
        };
	}

	$q .= 'order by 1, 5, 4';

	## prepare the query

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("GetSudoDependencies: $DBI::errstr");
		return undef;
	}

	## bind parameters

	if ( defined $opt->{cmnd_alias} ) {
		$sth->bind_param( 1, $opt->{cmnd_alias} );
	}

	if ( defined $opt->{mclass} ) {
		$sth->bind_param( 2, $opt->{mclass} );
	}

	if ( defined $opt->{user} ) {
		$sth->bind_param( 3, $opt->{user} );
	}

	if ( defined $opt->{uclass} ) {
		$sth->bind_param( 3, $opt->{uclass} );
	}

	if ( defined $opt->{default} ) {
		$sth->bind_param( 4, $opt->{default} );
	}

	if ( defined $opt->{run_as_user} ) {
		if ( $opt->{run_as_user} ne 'ALL' ) {
			$sth->bind_param( 5, $opt->{run_as_user} );
		}
	}

	if ( defined $opt->{run_as_uclass} ) {
		if ( $opt->{run_as_uclass} ne 'ALL' ) {
			$sth->bind_param( 5, $opt->{run_as_uclass} );
		}
	}

	## execute the query

	unless ( $sth->execute ) {
		$self->Error("GetSudoDependencies: $DBI::errstr");
		return undef;
	}

	return $sth->fetchall_arrayref;
}

###############################################################################

=pod

=item ShouldGenerateSudoers(-mclass $mclass, -flag $yn)

Set the should_generate_sudoers to 'Y' or 'N' for the specified
mclass. -flag should be 'Y' or 'N'.

=cut

###############################################################################

sub ShouldGenerateSudoers {
	my $self = shift;
	my $opt  = &_options(@_);
	my ( $dbh, $q, $sth, @row, $mclassid );

	if ( ref($self) ) {
		$dbh = $self->DBHandle;
	}

	if ( !$dbh ) {
		$self->Error(
			"ShouldGenerateSudoers: Invalid class reference passed"
		);
		return undef;
	}

	$q =
	  qq{select device_collection_id from device_collection where name = ?};

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("ShouldGenerateSudoers: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $opt->{mclass} ) ) {
		$self->Error("ShouldGenerateSudoers: $DBI::errstr");
		return undef;
	}

	unless ( @row = $sth->fetchrow_array ) {
		$self->Error( "ShouldGenerateSudoers: "
			  . "mclass $opt->{mclass} does not exist" );
		return undef;
	}

	$mclassid = $row[0];
	$sth->finish;

	$q = qq{
        update device_collection set should_generate_sudoers = ?
        where device_collection_id = ?
    };

	unless ( $sth = $dbh->prepare($q) ) {
		$self->Error("ShouldGenerateSudoers: $DBI::errstr");
		return undef;
	}

	unless ( $sth->execute( $opt->{flag}, $mclassid ) ) {
		$self->Error("ShouldGenerateSudoers: $DBI::errstr");
		return undef;
	}

	unless ( $sth->rows ) {
		$self->Error( "ShouldGenerateSudoers: "
			  . "this should not happen, seek help" );
		return undef;
	}

	$dbh->commit;
	return 1;
}

1;

=pod

=back

=head1 AUTHOR

Bernard Jech

=cut

