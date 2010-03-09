#!/usr/bin/perl -w
#
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

# $Id$

#
# installs properly formatted AAA files and do magic to make them authoritative
#
# $Id$
#
# -w prints the OS that this machine was identified as and exits
# (defaults bracketed)
# -r rootdir	[/] specifies where to create files
# -d etcdir	[/etc] specify where to create files (under $rootdir)
# -p passwd	[etcdir/passwd] specify passwd file to create
# -s shadow	[etcdir/shadow] specify shadow file to create
# -g group	[etcdir/group] specify group file to create
#
# -v  verbose output  (optional)
# -f  force changes (optional)
# -n  no-op (used by local-auth-update and may be accidentally passed to us)
#	placeholder to prevent it being used for real
#

BEGIN
{
	$ENV{'PATH'} = "/usr/bin:/usr/sbin:/bin:/sbin";
	require "ctime.pl";

}

use strict;
use Getopt::Std;
use Fcntl;

umask(0022);


my $DOTFILES_DIR="/usr/site/libdata/dotfiles";
my $indir = "/var/local/jazzhands";
my $STUBS_DIR = "/usr/site/libdata/pwfetch";

my(%opt);
getopts('nvfd:p:g:s:r:w', \%opt);

my $FORCE = 1 if($opt{f});

my $VERBOSE = 0;
$VERBOSE =1 if(defined($opt{'v'}));

my $HAVENEWPASSWD;  # global toggle bit.  grr

#============================================================================
#
# BEGIN main routine here.
#
#============================================================================


my $os = `uname -sr`;
$os =~ s/\s+//g;
my $ostok = $os;

# capitalize global variables for clarity!
my $ROOTDIR = $opt{'r'} || "/";
my $ETCDIR = $opt{'d'} || "$ROOTDIR/etc";
my $FILE_PASSWD = $opt{'p'} || $ETCDIR."/passwd";
my $FILE_SHADOW = $opt{'s'} || $ETCDIR."/shadow";
my $FILE_GROUP  = $opt{'g'} || $ETCDIR."/group";
my $FILE_SUDOERS = "$ETCDIR/sudoers";   # should let you spec via cmdline arg

my $WWWGROUPDIR="$ROOTDIR/prod/www/auth";
my $FILE_WWWGROUP= $WWWGROUPDIR."/groups";
my $DBALDIR="$ROOTDIR/var/local/auth-info";
my $CERTSDIR="$ROOTDIR/var/local/certs";

my $ZERO_LEN_SRC_IS_OK=0;  # used by RenameIfDifferent
my $ZERO_LEN_SRC_IS_BAD=1;
my $IGNORE_COMMENTS=1;     # used by CompareFiles, RenameIfDifferent
my $DONT_IGNORE_COMMENTS=0;

mkdir_p($ETCDIR);

if ($ostok =~ /^Linux/) {
	my $rhv = &get_linux_version;
	$ostok = $rhv;
}

# This really needs to be made unsucky and used consistantly.
$os = $ostok if($ostok =~ /Ubuntu/);

if(defined($opt{'w'})) {
	print "OS is '$ostok'\n";
	exit 0;
}


## get lock

# 
my %oldusers = &GatherUsersAndDirs($FILE_PASSWD);
# %oldusers gets tested in frob_homedirs
if (&gen_passwd("$indir/passwd")) {
	my $fail=1;
	# do a flush/sync here
	`/bin/sync`;
	my %newusers = &GatherUsersAndDirs($FILE_PASSWD);
	# %newusers gets tested in frob_homedirs

	# try to generate all other files by calling these
	# subroutines in series.
	#
	# if any of these routines returns a fail, don't try any more.
	# if we run into a failure at this point, the likely cause for
	# failure is a disk full or filesystem corruption situation,
	# and we certainly do not want to proceed in those cases.
	#
	# any failure condition within these routines will call
	# logit(), so there will be a record of failure.
	&frob_homedirs(\%oldusers, \%newusers) 		  &&
		&gen_group ("$indir/group") 		  &&	# must be found
		&gen_k5login_root ("$indir/k5login-root") &&	# must be found
		&gen_wwwgroup("$indir/wwwgroup") 	  &&	# optional
		&gen_sudoers("$indir/sudoers") 		  &&	# optional
		&gen_dbauth ( "$indir/dbal")		  &&	# optional
		&gen_certs ( "$indir/certs")		  &&	# optional
		($fail=0); 


	if ($fail) {
		## free lock
		&logit("placefiles encountered fatal error");
		die "$0: error encountered generating files!";
	}
	
} else {
	## free lock
	die "$0: unable to update /etc/passwd!";
}

exit 0;

#============================================================================
#
# BEGIN subroutines here.
#
#============================================================================

sub numerically { $a <=> $b; }

#
# given a username and directory, iterate through that directory and compare
# it against default dot files.  If the dot files are the same, then remove
# them.  Then attempt to remove the directory.  if it's empty it gets removed
# otherwise it hangs around.
#
# XXX logic - if home directory to be deleted does not contain the
#	name of the user, do not delete it.
#
# return 0 on failure
# return the number of files & directories that were deleted on success (>1)
#
# if the dotfiles package has changed then this may delete some or none
# of the dotfiles in a home directory being deleted.
#
sub cleanuphome {
	my($user, $dir) = @_;

	my $tally;

	if (!-d "$dir") {
		&logit("cleanuphome: $user has a home dir $dir, but does not exist; skipping\n");
		return(0);
	}
	if ($dir eq "/") {
		&logit("cleanuphome: $user has a home dir of '/'; skipping\n");
		return(0);
	}
	if($dir !~ m,^/,) {
		&logit("cleanuphome: $user has a home dir $dir, but it is not an absolute path; skipping\n");
		return(0);
	}
	if($dir !~ m,/$user$,) {
		&logit("cleanuphome: $user has a home dir $dir, but it does not seem to be a regular home dir; skipping\n");
		return(0);
	}

	if (opendir(DIR, $DOTFILES_DIR)) {
		foreach my $file (readdir(DIR)) {
			next if ($file =~ /^\./);  # ignore hidden files/directories

			if(-f "$DOTFILES_DIR/$file") {
				if(-f "$dir/.$file") {
					print "Comparing $DOTFILES_DIR/$file and $dir/.$file\n" if ($VERBOSE) ;
	
					if(CompareFiles("$DOTFILES_DIR/$file", "$dir/.$file", $IGNORE_COMMENTS)==0) {
						print "Going to delete $dir/.$file\n" if ($VERBOSE) ;
						if (!unlink("$dir/.$file")) {
							&logit("cleanuphome: unable to remove $dir/.$file\n");
						} else {
							$tally++;
						}
					}
				}
			}
		}
		closedir(DIR);

		print "Trying to remove directory $dir\n" if ($VERBOSE) ;
		rmdir($dir);   # ok if rmdir fails.
		++$tally;
	}
	return ($tally);
}

######################################################################
#
# create a new home directory for a user assuming that the directory
# doesn't already exist.  populate it with dotfiles.
#
# XXX WTF
# In the event that the last component of the directory name does not match
# the username do not chown files to the user, just leave them in place.
# net result: files gets owned by root.
#
# return 1 on success.
# return 0 on failure.
#
sub makenewhome {
	my($user, $dir) = @_;
	my $fail=0;

	if (-d "$dir") {
		&logit("makenewhome: $user has a new home dir $dir, but it already exists; skipping\n");
		return(0);
	}
	if ($dir eq "/") {
		&logit("makenewhome: $user has a new home dir $dir, but it is the root dir; skipping\n");
		return(0);
	}
	if($dir !~ m,^/,) {
		&logit("makenewhome: $user has a new home dir $dir, but it is not an absolute path; skipping\n");
		return(0);
	}

	my $chown = 0;
	# \0 is because of some weird-ass issue with perl 5.8.0
	$chown = 1 if($dir =~ m,/$user[\0]*$,);

  	# if getpwnam or getgrnam fails, fall back to root
	my $uid = (getpwnam($user))[2] || 0;
	my $gid = (getgrnam($user))[2] || 0;

	&logit("makenewhome: creating $dir for $user\n");
	mkdir_p($dir);
	if($chown) {
		print "chowning $user:$user ($uid:$gid) $dir\n" if ($VERBOSE) ;
		chown($uid, $gid, $dir) 
	}

	if (opendir(DIR, $DOTFILES_DIR)) {
		foreach my $file (grep(-f "$DOTFILES_DIR/$_", readdir(DIR))) {
			my $cmd = "cp -p $DOTFILES_DIR/$file $dir/.$file";
			print "Running '$cmd'\n" if ($VERBOSE) ;
			`$cmd`;
			if ($?) {
				# check if cp failed here.
				&logit("makenewhome: $user '$cmd' failed, returned $?");
			}
			if($chown) {
				if ($VERBOSE) {
					print "chowning $user:$user ($uid:$gid) $dir/.$file\n";
				}
				chown($uid, $gid, "$dir/.$file");

				print "chmod 0755 $dir/.$file\n" if ($VERBOSE) ;
				# WTF why set execute bit on dotfiles ???
				chmod(0755, "$dir/.$file");
			}
		}
		closedir(DIR);
	} else {
		&logit("makenewhome: unable to open $DOTFILES_DIR for reading, $!");
	}
	# if an error was encountered, return a failure condition.
	return ($fail ? 0 : 1);
}

#
# given path name to password file to manipulate.
#
# return a reference to an array with keys of usernames and values of home
# directories.  
# WTF why a reference to an array
# return undef on failure.
#
sub GatherUsersAndDirs {
	my ($input)=@_;
	my (%rv);
	print "reading $input to save users:home directories mapping\n" if ($VERBOSE) ;
	if (open(PASSWD, $input)) {
		while(my $line = <PASSWD>) {
			my ($name, $dir) = (split(/:/, $line))[0,5];
			$rv{$name} = $dir;
		}
		close(PASSWD);
	} else {
		&logit("GatherUsersAndDirs: unable to read $input, $!");
		return undef;
	}
	return(%rv);
}

######################################################################
#
# compare files
#
# given 3 arguments
# #1 file1
# #2 file2
# #3 boolean on whether to ignore comments or not.
#
# XXX A file permissions/ownership change (as a result of override in
# cert file or dbauth file) will trigger a rename, though if the
# contents stayed the same, you wouldn just need chown/chmod
#
# A previous chown/chmod of tempfile of
# the existing file perms will be retained by default.  it is only
# override mode/ownerships case that must be accounted for here.
#
# maybe add a boolean flag to adjust behavior of CompareFiles here?
#
# return 1 if different or second does not exist
# return 0 if the first does not exist or they are the same.
#
#
sub CompareFiles {
	my ($src, $dest, $ignore_comments) = @_;

	my $founddiff = 0;

	if(! -r $src) {
		print "CompareFiles: source file $src was not found\n" if ($VERBOSE) ;
		return 0 ;
	}

	if(-r $dest) {
		# so src & dest exist.
		# check file perms first;  that way if the perms/ownerships have
		# changed then we can skip actually reading the files.

		my ($oldmode, $olduid, $oldgid) = (stat $src)[2,4,5];
		my ($newmode, $newuid, $newgid) = (stat $dest)[2,4,5];
		if (($oldmode != $newmode) || ($olduid != $newuid) || ($oldgid != $newgid)) {
			$founddiff=1;
			print "CompareFiles: perms or ownerships are different between $src and $dest, marking them as different\n" if ($VERBOSE) ;
		} else {
			open(OLD, "$src") || return 0;
			open(NEW, "$dest")|| return 0;

			while(!$founddiff) {
				my $oldline = <OLD> || undef;
				my $newline = <NEW> || undef;
				if ($newline && ($ignore_comments == $IGNORE_COMMENTS)) {
					# skip all comments
					while ($newline =~ /^\s*\#/) {
						$newline=<NEW>;
					}
				}
				if ($oldline && ($ignore_comments == $IGNORE_COMMENTS)) {
					# skip all comments
					while ($oldline =~ /^\s*\#/) {
						$oldline=<OLD>;
					}
				}
				if(!$oldline && !$newline) {
					last;
				} elsif(!$oldline || !$newline) {
					$founddiff = 1;
					last;
				}
					$founddiff = 1 if($oldline ne $newline);
				}
			close(OLD);
			close(NEW);
		}	
	} else {
		$founddiff++;
		print "CompareFiles: dest file $dest was not found\n" if ($VERBOSE) ;
	}

	$founddiff;
}

######################################################################
#
# given 4 files
# 1 is $src
# 2 is $dest
# given these two files, move $src to $dest if they're different.
#
# 3rd arg: if true then the src file must be non-zero.  if false
# or missing then src file can be zero-length.
# $ZERO_LEN_SRC_IS_OK =0 
# $ZERO_LEN_SRC_IS_BAD =1 
# change so this is a required arg.
#
# 4th arg: if true then ignore all lines with comments
# (lines that start with comments anyways.  the case of lines that have
# comments following non-comment data is not handled here)
#
# considers a nonexistant second file to be different
# nonexistant source directory is considered a noop/no move.
#
# return 1 if o.k. (regardless of whether files needed to
#	be copied or not)
# returns 0 on error: if the src file is zero
# 	length and the non-zero arg is true, or
#	if the actual rename ops fail.
#
# relies on global variable $FORCE
#
#
sub RenameIfDifferent {
	my($src, $dest, $nonzero, $ignore_comments) = @_;

	if(($nonzero == $ZERO_LEN_SRC_IS_BAD) && -z $src) {
		&logit("RenameIfDifferent: $src is zero-length but non-zero bit is set");
		return undef;
	}

	my $founddiff;

	# short-circuit CompareFiles if -f ($FORCE) was set.
	if($FORCE) {
		$founddiff=1 ;
	} else {
		$founddiff = CompareFiles($src, $dest, $ignore_comments);
		print "CompareFiles of $src and $dest returned $founddiff\n" if ($VERBOSE) ;
	}


	if($founddiff != 0) {
		if (!&my_rename($dest, ${dest}.".prev")) {
			&logit("RenameIfDifferent: rename ($dest, ${dest}.prev) failed, $!");
			# abort!
			return 0;
		} else {
			print "moved $dest to $dest.prev\n" if ($VERBOSE);
		}
		if (!&my_rename($src, $dest)) {
			&logit("RenameIfDifferent: rename ($src, $dest) failed, $!");
			# abort and revert changes, if possible!
			&my_rename(${dest}.".prev", $dest); # don't check for failure, because
							# we be screwed, regardless
			return 0;
		} else {
			print "moved $src to $dest\n" if ($VERBOSE);
		}
	} else {
		unlink($src);
	}

	# return success if we get this far.
	return 1;
}

######################################################################
#
# create a directory and everything leading up to it
# returns value of the last mkdir.  because mkdir(directories)
# is attempted regardless of whether it exists, and mkdir will
# return 0 if directory exists, we return no useful value.
#
sub mkdir_p {
	my($dir) = @_;
	my $mode = 0755;

	my(@d) = split(m-/-, $dir);
	my $ne = $#d+1;
	for (my $i = 2; $i <= $ne; $i++) {
		my(@dir) = split(m-/-, $dir);
		splice(@dir, $i);
		my $thing = join("/", @dir);
		mkdir($thing, $mode);
	}
}

sub get_linux_version {
	my $issue = "/etc/issue";

	open(LINV, "$issue") || return undef;
	my $v = <LINV>;
	close(LINV);

	my ($linv, $what, $stuff);
	if($v) {
		$v =~ /^(\S+)/;
		my $os = $1;
		$v =~ /(\S+)\s+release\s+(\S+)\s+/;
		($what, $linv) = ($1, $2, $3);
		if ($os eq "Red") {
			if($what ne 'Linux') {
				$linv = "RedHat$what$linv";
			} else {
				$linv = "RedHat$linv";
			}
		} elsif($os =~ "CentOS") {
			$linv = "CentOS$linv";
		} else {
			$v =~ /^(Ubuntu\s+\d+)\./;
			my $os = $1;
			if($os) {
				$linv = $os;
				$linv =~ s/\s+//;
			}

		}
	}

	if(!$linv || !length($linv)) {
		if(-f "/etc/debian_version") {
			$linv= 'Debian';
		}
	}

	$linv;
}


######################################################################
#
# routine to log actions to /var/local/pwfetch/log
# we do this rather than syslog() in case there is something
# that we do not want the world to see/know about, as syslog
# is usually writing to globally readable files.
#
# returns nothing.
#
# rely on global var $indir
#
sub logit {
	my ($msg)=@_;
	my $logfile=$indir ."/log";
	my $timestr=&ctime(time);
	my $curumask=umask;  # catch case where logit() is called 
			     # someplace where umask has been
			     # temporarily changed
	umask (022);

	chomp $msg;
	chomp $timestr;

	if (open(L, ">>$logfile")) {
		printf L "[%s] %s\n", $timestr, $msg;
		if ($VERBOSE) {   # echo to stdout
			printf "[%s] %s\n", $timestr, $msg;
		}
		close(L);
	} else {
		# syslog this message?
		warn "unable to write to $logfile, $!";
	}
	umask($curumask);	# restore umask.

	return;
}


######################################################################
# generate /etc/passwd, /etc/shadow
#
# $indir/passwd generated by mkpasswdfiles 
#
# given 1 arg (input file, fetched)
# returns 1 on success, 0 on failure.
#
sub gen_passwd {
	my ($fetchfile)=@_;
	my $fail=0;

	print "Checking for $fetchfile\n" if ($VERBOSE);
	if(-f "$fetchfile") {
		my(%passwd);
		my(%shadow);
		print "Found $fetchfile, processing\n" if ($VERBOSE);
		if (open(P, "$fetchfile")) {
			while(defined(my $line = <P>)) {
				chomp($line);
				my($user, $rest) = split(/:/, $line, 2);
				$passwd{$user} = $rest;
			}
			close(P);
	
			#
			# now, iterate through the users, look at their shells, see if they're
			# valid, if not, try to make them valid, if that doesn't work, set them
			# to /bin/false
			#
			# (we do this now rather than later to avoid mucking with the default 
			# passwd entries)
			#
			foreach my $user (keys(%passwd)) {
				my @ary = split(/:/, $passwd{$user});
	
				my $shell = $ary[5];

				# CASE: is $shell is not an absolute path
				#       and can be found in the cwd, and is
				#	executable.  This can occur under ubuntu
				#	if cwd is /etc, and there is a directory
				#	/etc/csh which is created as part of the
				#	csh package
				# if(! -x $shell) {
				if($shell !~ m,^/, || ! -x $shell) {
					$shell =~ s,^/[^/]+$,$1,;
					foreach my $dir ("/usr/bin", "/bin", "/usr/local/bin", "/usr/pkg/bin") {
						if (-x "$dir/$shell" && -f "$dir/$shell") {
							$shell = "$dir/$shell";
							last;
						}
					}

					# if the above foreach() loop did not identify an absolute
					# path to a shell to use, and $shell is one of the
					# metavalues that pwgen will insert, use the bourne shell
					# as a default
					if($shell =~ /^(tcsh|sh|csh|bash|zsh|ksh)$/) {
						$shell = "/bin/sh";
					}
	
					# if $shell is a symlink or directory, then -x
					# will be satisfied, so add -f test
					#if(!-x $shell) {
					if(!-x $shell || !-f $shell) {
						$shell = "/bin/false";
					}
				}

				$ary[5] = $shell;
				$passwd{$user} = join(":", @ary);
			}

			#
			# read in the stub shadow file, for reference.
			# not having it available is not a fatal error.
			#
			if(-f "$STUBS_DIR/shadow.$ostok") {
				if (open(S, "$STUBS_DIR/shadow.$ostok")) {
					while(defined(my $line = <S>)) {
						chomp($line);
						my($user, $rest) = split(/:/, $line, 2);
						$shadow{$user} = $rest;
					}
					close(S);
				} else {
 					&logit("gen_passwd: unable to read $STUBS_DIR/shadow.$ostok, $! (proceeding)");
				}
			} else {
 				&logit("gen_passwd: unable to find $STUBS_DIR/shadow.$ostok (proceeding)");
			}

			#
			# if there is a system version, THAT version overrides whatever is in
			# the database, with the exception of a crypt, which wins out
			# in the version pulled down.
			#
			# a passwd stub file is a requirement.
			#
			if(-f "$STUBS_DIR/passwd.$ostok") {

				if (open(P, "$STUBS_DIR/passwd.$ostok")) {
					while(defined(my $line = <P>)) {
						next if($line =~ /^#/);
						chomp($line);
						my($user, $rest) = split(/:/, $line, 2);
						if(defined($passwd{$user})) {
							my @stub = split(/:/, $rest);
							my @db = split(/:/, $passwd{$user});
							# this should be the crypt/md5/whatever
							$stub[0] = $db[0];
							$passwd{$user} = join(":", @stub);

							#
							# deal with users that vendor gives no shell (smmsp).
							#
							if($rest =~ s/:$//) {
								$passwd{$user} .= ":";
							}

							# since we have a password defined, we don't use the stub
							# shadow file entry
							undef($shadow{$user});
						} else {
							$passwd{$user} = $rest;
						}
					}
					close(P);
				} else {
 					&logit("gen_passwd: unable to read $STUBS_DIR/passwd.$ostok, $! (fatal)");
					$fail=1;
				}
			} else {
 				&logit("gen_passwd: unable to find $STUBS_DIR/passwd.$ostok, $! (fatal)");
				$fail=1;
 				warn "Are you getting pwfetch to work on a new OS ?";
				# things that must be done:
				# create stub files for passwd.*, shadow.*, group.* with per-OS suffix
				# modify package depends.*, init.* in metafiles directory, if needed
				#
			}

			my(%passwd_by_uid);
			my(%shadow_by_uid);
			if (!$fail && !$passwd{root}) {
 				&logit("gen_passwd: no password info for 'root' (fatal)");
				$fail=1;
			}
			if (!$fail && (split(/:/, $passwd{root}))[0] eq "*") {
 				&logit("gen_passwd: no valid crypt for 'root' (fatal)");
				$fail=1;
			}

			if (!$fail) {
				foreach my $user (sort(keys(%passwd))) {
					my($crypt,$uid, $rest) = split(/:/, $passwd{$user}, 3);

					# never, ever allow empty passwords!
					$crypt = "*NO*PASSWORD*" if($crypt eq "");

					if(defined($shadow{$user})) {
						$shadow_by_uid{$uid} .= ${user}. ":". $shadow{$user};
					} else {
						$shadow_by_uid{$uid} .= "${user}:${crypt}:::::::";
					}
					$shadow_by_uid{$uid} .= "\n";

					# [XXX] should probably check for dups and do something with them?
					# not using an array because this is likely to be very sparse.
					#
					# we do it this way to allow users to share the same uid which
					# is occasionally, but rarely needed.
					#
					$passwd_by_uid{$uid} .= join(":", ( $user, "x", $uid, $rest)). "\n";
				}

				#
				# now actually go and create the passwrd file for this host
				#
				if($os =~ /^SunOS5/ || $ostok eq 'Debian' || $ostok =~ /RedHat/ || $ostok =~ /CentOS/ || $os =~ /Ubuntu/) {
					my $curumask=umask();  # save current umask
					my $newpasswd = "${FILE_PASSWD}.$$";
					my $newshadow = "${FILE_SHADOW}.$$";
					if (open(P, ">$newpasswd")) {
						foreach my $uid (sort numerically keys(%passwd_by_uid)) {
							if (!print P $passwd_by_uid{$uid}) {
								&logit("gen_passwd: failed write to $newpasswd , $!");
								$fail=1;
								last;  # terminate the loop.
							}
						}
						close(P);

						# if the write to /etc/passwd.$$ failed, don't bother trying
						# /etc/shadow.$$
						if (!$fail) {
							umask 077;  # temporarily change umask so that
							    	# file gets created as mode 0600.
							if(open(S, ">$newshadow")) {
								foreach my $uid (sort numerically keys(%shadow_by_uid)) {
									if (!print S $shadow_by_uid{$uid}) {
										&logit("gen_passwd: failed write to $newshadow , $!");
										$fail=1;
										last;  # terminate the loop.
									}
								}
								close(S);
							} else {
								unlink("/etc/passwd.$$");
								&logit("gen_passwd: unable to open $newshadow for writing, $!");
								$fail=1;
							}
							umask($curumask);  # restore umask
						}
		
						# we can't combine these two if (!$fail) blocks
						# because the write to /etc/passwd.$$ could have succeeded
						# while the write to /etc/shadow.$$ failed
						if (!$fail) {
							# HAVENEWPASSWD is a global
							$HAVENEWPASSWD = RenameIfDifferent($newpasswd, $FILE_PASSWD, $ZERO_LEN_SRC_IS_BAD, $DONT_IGNORE_COMMENTS);
							RenameIfDifferent($newshadow, $FILE_SHADOW, $ZERO_LEN_SRC_IS_BAD, $DONT_IGNORE_COMMENTS);
						}
					} else {
						&logit("gen_passwd: unable to open $newpasswd for writing, $!");
						$fail=1;
					}
				} # foreach user
			} # !$fail

		} else {
			&logit("gen_passwd: unable to read $fetchfile, $!");
		} # cannot read fetchfile
	} else {
		# ! fetchfile
		&logit("gen_passwd: given $fetchfile but it was not found, $!");
		$fail=1;
	}
	
	# if an error was encountered, return a failure condition.
	return ($fail ? 0 : 1);
}

######################################################################
# generate ~root/.k5login
#
# this needs to be expanded to handle any k5login file, but probably needs
# some smarts about it, which is why it's not done now.
#
# /var/local/pwfetch/k5login-root is generated by mkpasswdfiles 
#
# given 1 arg, the pathname to k5login-root file.
# returns 1 on success, 0 on failure.
#
sub gen_k5login_root {
	my ($fetchfile)=@_;
	my $fail=0;

	print "Checking for $fetchfile\n" if ($VERBOSE);
	if(-f $fetchfile) {
		print "Found $fetchfile, processing\n" if ($VERBOSE);
		my $roothome = (getpwnam("root"))[7];
		my $curumask=umask();  # save current umask
		umask(0077);  # change umask to create this file as mode 0600.

		# roothome is expected to be '/' or '/root'.
		if(-d "$ROOTDIR/$roothome") {
			my $k5login = "$ROOTDIR/$roothome/.k5login";

			if (&conditional_copy($fetchfile, $k5login, $ZERO_LEN_SRC_IS_BAD)) {
				print "conditional_copy of $fetchfile to $k5login returned OK\n" if ($VERBOSE);
			} else {
				$fail=1;
				&logit("gen_k5login_root: conditional_copy of $fetchfile to $k5login failed!");
			}
		} else {
			&logit("gen_k5login_root: root user homedir is missing, ${ROOTDIR}/${roothome}???");
			$fail=1;

		}
		umask($curumask);  # restore umask
	} else {
		&logit("gen_k5login_root: given $fetchfile but it was not found, $!");
		$fail=1;
	}

	# if an error was encountered, return a failure condition.
	return ($fail ? 0 : 1);
}


######################################################################
# generate /etc/sudoers
#
# generated by mkpasswdfiles 
#
# given 1 arg, the pathname to the fetched sudoers file.
# returns 1 on success, 0 on failure.
sub gen_sudoers {
	my($fetchfile)=@_;
	my $fail=0;

	print "Checking for $fetchfile\n" if ($VERBOSE);
	# not having a sudoers file is not a failure condition.
	if (-f $fetchfile) {
		print "Found $fetchfile, processing\n" if ($VERBOSE);
		my $curumask=umask();  	# save current umask
		umask(0227);  		# change umask to create this file as mode 0440.
		if (&conditional_copy($fetchfile, $FILE_SUDOERS, $ZERO_LEN_SRC_IS_OK)) {
			# extra chown/chmod for paranoid minds
			chown(0, 0, $FILE_SUDOERS);
			chmod(0440, $FILE_SUDOERS);
			print "conditional_copy of $fetchfile to $FILE_SUDOERS returned OK\n" if ($VERBOSE) ;
		} else {
			$fail=1;
			&logit("gen_sudoers: conditional_copy of $fetchfile to $FILE_SUDOERS failed!");
		}
		umask($curumask);  # restore umask
	}

	# if an error was encountered, return a failure condition.
	return ($fail ? 0 : 1);
}

######################################################################
# generate /etc/group
#
# generated by mkpasswdfiles 
sub gen_group {
	my ($fetchfile)=@_;
	my $fail=0;

	print "Checking for $fetchfile\n" if ($VERBOSE);
	if(-f "$fetchfile") {
		my(%group);
		print "Found $fetchfile, processing\n" if ($VERBOSE);
		if (open(G, "$fetchfile")) {
			while(defined(my $line = <G>)) {
				chomp($line);
				my($group, $rest) = split(/:/, $line, 2);
				$group{$group} = $rest;
			}
			close(G);

			if(-f "$STUBS_DIR/group.$ostok") {
				if (open(G, "$STUBS_DIR/group.$ostok")) {
					while(defined(my $line = <G>)) {
						next if($line =~ /^#/);
						chomp($line);
						my($group, $pw, $gid, $members) = split(/:/, $line, 4);
						#
						# we favor the group information in the stub file, with the
						# exception of the membership, which we merge
						#
						my(%members);
						if(defined($group{$group})) {
							my($omem) = (split(/:/, ($group{$group})))[2];
							if(defined($omem)) {
								foreach my $dude (split(/,/, $omem)) {
									$members{$dude}++;
								}
							}
						}
						if(defined($members)) {
							foreach my $dude (split(/,/, $members)) {
								$members{$dude}++;
							}
						}
						my $all = join(",", (sort(keys(%members))));
						$group{$group} = "$pw:$gid:".$all;
					}
					close(G);

					my(%group_by_gid);
					foreach my $group (keys(%group)) {
						my($pw, $gid, $members) = split(/:/, $group{$group});
						$group_by_gid{$gid} .= "$group:$pw:$gid:$members\n";
					}
		
					#
					# groups are pretty consistant across OS's
					#
					my $newgroup = "${FILE_GROUP}.$$";
					if (open(G, ">$newgroup")) {
						foreach my $gid (sort numerically keys(%group_by_gid)) {
							if (!print(G $group_by_gid{$gid})) {
								# abort!
								$fail=1;
								&logit("gen_group: write to $newgroup failed, $!");
							}
						}
						close(G);
						if (!$fail) {
							chmod(0644, $newgroup);
							RenameIfDifferent($newgroup, $FILE_GROUP, $ZERO_LEN_SRC_IS_BAD, $DONT_IGNORE_COMMENTS);
						}
					} else {
						&logit("gen_group: open $newgroup for writing failed, $!");
						$fail=1;
					} 

				} else {
					&logit("gen_group: unable to read $STUBS_DIR/group.$ostok (fatal)");
					$fail=1;
				}
			} else {
				&logit("gen_group: unable to find stub group file $STUBS_DIR/group.$ostok (fatal)");
				$fail=1;
			}

		} else {
			&logit("gen_group: unable to read $fetchfile, $!");
		}
	} else {
		&logit("gen_group: given $fetchfile but it was not found, $!");
		$fail=1;
	} #!found

	# if an error was encountered, return a failure condition.
	return ($fail ? 0 : 1);
}

######################################################################
# generate /prod/www/auth/groups
#
# generated by mkpasswdfiles 
#
# return 1 on success, 0 on failure.
#
sub gen_wwwgroup {
	my ($fetchfile)=@_;
	my $fail=0;

	print "Checking for $fetchfile\n" if ($VERBOSE);
	# not having a wwwgroup file is not a failure condition.
	if (-f $fetchfile) {
		print "Found $fetchfile, processing\n" if ($VERBOSE);
		if (! -d $WWWGROUPDIR) {
			mkdir_p($WWWGROUPDIR);   # check failure condition from this?
		}

		if (&conditional_copy($fetchfile, $FILE_WWWGROUP, $ZERO_LEN_SRC_IS_OK)) {
			print "conditional_copy of $fetchfile to $FILE_WWWGROUP returned OK\n" if ($VERBOSE) ;
		} else {
			$fail=1;
			&logit("gen_wwwgroup: conditional_copy of $fetchfile to $FILE_WWWGROUP failed!");
		}
	}
	# if an error was encountered, return a failure condition.
	return ($fail ? 0 : 1);
}

######################################################################
#
# given 3 args:
#	1. source file  (probably something in /var/local/pwfetch)
#	2. name of final destination file  (something in /etc, probably)
#	3. is the zero/non-zero bit passed to RenameIfDifferent
# copy src to dest, IF any changes.   abort on error.
#
# return 1 on success, 0 on failure.
#
sub conditional_copy {
	my ($src,$dest,$nonzero)=@_;
	my $fail=0;
	my $newfile="$src.$$";  # XXX just a temporary, scratch file.

	if( -f $src) {
        	if (open(SRC, $src)) {
			print "copying from $src to $newfile\n" if ($VERBOSE) ;
        		if (open(SCRATCH, ">$newfile")) {
        			while(<SRC>) {
					if (!print(SCRATCH)) {
						$fail=1;
						# most likely, we've got a disk full/file
						# truncation issue here.
						&logit("conditional_copy: write to $newfile failed, $!");
						last;
					}
				}
        			close(SCRATCH);
				if (!$fail) {
        				if (!RenameIfDifferent($newfile, $dest, $nonzero, $IGNORE_COMMENTS)) {
						$fail=1;
						&logit("conditional_copy: RenameIfDifferent($newfile,$dest) failed!");
					}
				}
			} else {
				&logit("gen_sudoers: unable to open $newfile for writing, $!");
				$fail=1;
			}
        		close(SRC);
		} else {
			&logit("conditional_copy: unable to read $src, $!");
			$fail=1;
		}
	} else {
		&logit("conditional_copy: passed $src but it was not found, $!");
		$fail=1;
	}

	# if an error was encountered, return a failure condition.
	return ($fail ? 0 : 1);
}

######################################################################
# generate /var/local/auth-info/*
#
# generated by mkpasswdfiles 
#
# process file 'dbal' downloaded from pwfetch server.
# format is series of records:
#
# ^Application:[whitespace]<application name>$
# ^[content to be saved to /var/local/auth-info/<application name>$
# ^"  "$
#
# line beginning with string 'Application:' is record demarcation
# if ^Mode:[whitespace]<octal perms>$ is seen, then apply that to
# generated file.
# change to:
# AuthFileMode:
# AuthFileUser:
# AuthFileGroup:
# to override default of 0644/root/root
#
# need to clean this up.  merge with gen_certs ?
#
# XXX remove auth files if they disappear from the dbal file?  current
# behavior is to leave old ones behind
#
# return 1 on success
# return 0 on fail.
sub gen_dbauth {
	my($fetchfile)=@_;
	my $fail=0;

	print "Checking for $fetchfile\n" if ($VERBOSE);
	# not having a dbauth file is not a failure condition.
	if( -f $fetchfile) {
		print "Found $fetchfile, processing\n" if ($VERBOSE);
		my $umask = umask;
		# creates as 0755 (per umask set above as 022)
		# if paranoid, this could be changed to 0711
		if (! -d ${DBALDIR}) {
			mkdir_p($DBALDIR);
		}
		umask 022;
		if (open(IN, $fetchfile)) {
			my ($newfile, $tmpfile, $applname,$newmode,$newuser, $newgroup);
			while (<IN>) {
				if (($applname) = /^Application:\s+(.*)/) {
					close OUT;  # first time this loop
						    # runs, close OUT will
						    # fail.
					# we found a new record.  if we are still processing an open record,
					# dump the info to disk, reinitialize variables, and then
					# start processing the new record.
					if ($newfile) {   
						my $ok=&conditional_deploy ($tmpfile, $newfile,
					 		$newmode, $newuser, $newgroup,
					 		$ZERO_LEN_SRC_IS_OK, $IGNORE_COMMENTS);
						$fail = ($ok ? 0 : 1);
						if ($fail) {
							&logit("conditional_deploy of $tmpfile to $newfile failed");
							# break out of this loop.
							last;
						}
					}
					$newmode="";   # reset
					$newuser="";   # reset
					$newgroup="";  # reset
					$newfile = "/${DBALDIR}/${applname}";
					$tmpfile = "${newfile}.$$";
					if (open (OUT, ">$tmpfile")) {
						print "Writing to $tmpfile\n" if ($VERBOSE) ;
					} else {
						&logit("gen_dbauth: unable to create $tmpfile, $!");
						$fail=1;
						# break out of this loop.
						last;
					}
					next;
				}

				# ignore all lines up to the first Application: record
				next if (!$newfile);   

				# see also /trunk/prod/infrastructure/aaa/mkpasswdfiles
				# check for any of these fields, and apply if found
				# (and do not pass them along to the file we are creating)
				# AuthFileMode:
				# AuthFileUser:
				# AuthFileGroup:
				if (/^AuthFile(Mode|User|Group):/) {
					# if this field is found, it's a permissions override
					# this value gets passed along to the generated file,
					# as well.
					#
					my($field,$value)=(/^(\S+):\s*(.*)$/);
					chomp $value;
					if ($field eq "AuthFileMode") {
						# do not validate the file mode other than checking
						# that it smells like an octal permission string.
						if ($value !~ /^\d\d\d\d?$/) {
							&logit("gen_dbauth: read bad perms '$value' for $newfile, ignoring");
						} else {
							$newmode=$value;
						}
					} elsif ($field =~ /^AuthFileUser$/) {
						# check that the given field is an alphabetic string and
						# not a numeric (presuming that a uid/gid has been spec'd 
						# if the latter is true, which is bad because we need
						# the username/groupname and not uid/gid.
						# the default user is root.
						if ($value =~ /^\d*$/) {
							&logit("gen_dbauth: read bad user '$value' for $newfile, ignoring");
						} else {
							$newuser=$value;
						}
					} elsif ($field =~ /^AuthFileUser$/) {
						# check that the given field is an alphabetic string and
						# not a numeric (presuming that a uid/gid has been spec'd 
						# if the latter is true, which is bad because we need
						# the username/groupname and not uid/gid.
						# the default group is root.
						if ($value =~ /^\d*$/) {
							&logit("gen_dbauth: read bad group '$value' for $newfile, ignoring");
						} else {
							$newgroup=$value;
						}
					}
					# ok to pass these fields along, I presume?
				}  # if AuthFileMode/Group/User

				if (!print OUT) {
					&logit("gen_dbauth: unable to create $tmpfile, $!");
					$fail=1;
				}
			}
			close(IN);
	
			close OUT;  # this may fail.
			if ($newfile && !$fail) {
				my $ok=&conditional_deploy ($tmpfile, $newfile,
					 $newmode, $newuser, $newgroup,
					 $ZERO_LEN_SRC_IS_OK, $IGNORE_COMMENTS);
				if (!$ok) {
					&logit("conditional_deploy of $tmpfile to $newfile failed");
				}
				$fail = ($ok ? 0 : 1);
			}
		} else {
			&logit("gen_dbauth: unable to read $fetchfile, $!");
			$fail=1;
		}
		umask $umask;  # restore
	}
	# if an error was encountered, return a failure condition.
	return ($fail ? 0 : 1);
}

######################################################################
#
# we updated the passwd file, so we go through and create home directories
# for people and deposit dot files if they don't exist.  If the home directory
# is not /, and the username is not the last component, then we copy dot files
# but we leave everything chown'd to root.
#
# given refs to %oldusers and %newusers
#
# return 1 on success
# return 0 on failure
#
# for now, rely on global var $HAVENEWPASSWD
#
#
sub frob_homedirs {
	my ($oldusers,$newusers)=@_;
	
	print "Frobbing homedirs\n" if ($VERBOSE);

	# check if oldusers & newusers are valid.
	if (!$oldusers) {
		&logit("frob_homedirs: array \%oldusers is empty (prior to /etc/passwd changes), not changing any home directories!");
		return 0;
	}
	if (!$newusers) {
		&logit("frob_homedirs: array \%newusers is empty (post /etc/passwd changes), not changing any home directories!");
		return 0;
	}

	if($HAVENEWPASSWD) {
		foreach my $user (keys(%$newusers)) {
			if(defined($$oldusers{$user})) {
				if($$oldusers{$user} eq $$newusers{$user}) {
					print "user $user found in old and new /etc/passwd\n" if ($VERBOSE);
					delete($$oldusers{$user});
					delete($$newusers{$user});
				} else {
					print "user $user found in old and new /etc/passwd but changed home directories from  $$oldusers{$user} to  $$newusers{$user}\n" if ($VERBOSE);
					my $ret=cleanuphome($user, $$oldusers{$user});
					if (!$ret && $VERBOSE) {
						print "cleanuphome($user,$$oldusers{$user}) failed\n";
						# this is not necessarily a bad thing.
					}
					makenewhome($user, $$newusers{$user});
					# makenewhome failing is not necessarily a bad thing.
					delete($$oldusers{$user});
				}
			} else {
				print "new user $user make home dir $$newusers{$user}\n" if ($VERBOSE);
				makenewhome($user, $$newusers{$user});
				# makenewhome failing is not necessarily a bad thing.
			}
		}
	
		#
		# we should just be left with people who were deleted so we clean them
		# up, if possible
		#
		foreach my $user (keys(%$oldusers)) {
			my $ret=cleanuphome($user, $$oldusers{$user});
			if (!$ret && $VERBOSE) {
				print "cleanuphome($user,$$oldusers{$user}) failed\n";
				# this is not necessarily a bad thing.
			}
		}
	}
	return (1);
}


######################################################################
# generate /var/local/certs/*
#
# to be generated by mkpasswdfiles, one day 
#
# process file 'certs' downloaded from pwfetch server.
# format is series of records:
#
# ^CertFileName:[whitespace]<cert name>$
# ^<any other field>:[whitespace]<values>$   XXX 
# ^[content to be saved to /var/local/certs/<cert name>$
# ^"  "$
# this is expected to be a series of .key and .crt files (ascii
# armored) generated from openssl concatenated together on the
# server side.  should still work if these are binary/non-armored,
# but no guarantees.
# all data in the 'fields' such as CertName may be processed by
# placefiles but not passed along to generated file.
#
# line beginning with string 'CertFileName:' is record demarcation
# file names expected to be *.crt, *.key, and possibly *.pem
#
# routine has support for optional fields of (similar to gen_dbauth)
# CertFileMode
# CertFileUser
# CertFileGroup
# if found, will override default perms of 0644, root, root
# unsure if there will be JazzHands support for this, but it'll be
# easier to code it in now rather than later...
#
# XXX remove cert files if they disappear from the certs file?
#
# return 1 on success
# return 0 on fail.
sub gen_certs {
	my($fetchfile)=@_;
	my $fail=0;

	print "Checking for $fetchfile\n" if ($VERBOSE);
	# not having a cert file is not a failure condition.
	if( -f $fetchfile) {
		print "Found $fetchfile, processing\n" if ($VERBOSE);
		if (! -d ${CERTSDIR}) {
			mkdir_p($CERTSDIR);
		}
		if (open(IN, $fetchfile)) {
			my ($newfile, $tmpfile, $certname);
			my ($newuser, $newgroup, $newmode);
			while (<IN>) {
				if (($certname) = /^CertFileName:\s+(.*)/) {
					close OUT;
					# if we are still processing an open record,
					# and found a new record, dump the old info to disk
					# and start processing the new record.
					if ($newfile) {
						my $ok=&conditional_deploy ($tmpfile, $newfile,
					 		$newmode, $newuser, $newgroup,
					 		$ZERO_LEN_SRC_IS_OK, $IGNORE_COMMENTS);
						$fail = ($ok ? 0 : 1);
						if ($fail) {
							&logit("conditional_deploy of $tmpfile to $newfile failed");
							# break out of this loop.
							last;
						}
					}
					$newmode="";   # reset
					$newuser="";   # reset
					$newgroup="";  # reset
					$newfile = "/${CERTSDIR}/${certname}";
					$tmpfile = "${newfile}.$$";
					if (open (OUT, ">$tmpfile")) {
						print "Writing to $tmpfile\n" if ($VERBOSE);
					} else {
						&logit("gen_certs: unable to create $tmpfile, $!");
						$fail=1;
						# break out of this loop.
						last;
					}
					next;
				}

				# ignore all lines up to the first CertFileName: record
				next if (!$newfile);   

				# now, look for other fields that are significant to us
				# processing the record, but not to be passed along
				# to the cert file we are creating:
				# CertFileMode:
				# CertFileUser:
				# CertFileGroup:
				if (/^CertFile(Mode|User|Group):/) {
					# if this field is found, it's a permissions override
					# this value gets passed along to the generated file,
					# as well.
					#
					my($field,$value)=(/^(\S+):\s*(.*)$/);
					chomp $value;
					if ($field eq "CertFileMode") {
						# do not validate the file mode other than checking
						# that it smells like an octal permission string.
						if ($value !~ /^\d\d\d\d?$/) {
							&logit("gen_certs: read bad perms '$value' for $newfile, ignoring");
						} else {
							$newmode=$value;
						}
					} elsif ($field =~ /^CertFileUser$/) {
						# check that the given field is an alphabetic string and
						# not a numeric (presuming that a uid/gid has been spec'd 
						# if the latter is true, which is bad because we need
						# the username/groupname and not uid/gid.
						# the default user is root.
						if ($value =~ /^\d*$/) {
							&logit("gen_certs: read bad user '$value' for $newfile, ignoring");
						} else {
							$newuser=$value;
						}
					} elsif ($field =~ /^CertFileGroup$/) {
						# check that the given field is an alphabetic string and
						# not a numeric (presuming that a uid/gid has been spec'd 
						# if the latter is true, which is bad because we need
						# the username/groupname and not uid/gid.
						# the default group is root.
						if ($value =~ /^\d*$/) {
							&logit("gen_certs: read bad group '$value' for $newfile, ignoring");
						} else {
							$newgroup=$value;
						}
					}
					next;	# we do not want to pass these fields along to the
					 	# generated certificate file, so short-circuit this loop
						# iteration
				}  # if CertFileMode/Group/User

				if (!print OUT) {
					&logit("gen_certs: unable to create $tmpfile, $!");
					$fail=1;
				}
			}
			close(IN);
	
			close OUT;  # this may fail.
			if ($newfile && !$fail) {
				my $ok=&conditional_deploy ($tmpfile, $newfile,
					 $newmode, $newuser, $newgroup,
					 $ZERO_LEN_SRC_IS_OK, $IGNORE_COMMENTS);
				$fail = ($ok ? 0 : 1);
							
				if ($fail) {
					&logit("conditional_deploy of $tmpfile to $newfile failed");
				}
			}
		} else {
			&logit("gen_certs: unable to read $fetchfile, $!");
			$fail=1;
		}
	} else {
		print "gen:certs: no cert file was given, skipping.\n" if $VERBOSE; 
		$fail=0;
	}

	# if an error was encountered, return a failure condition.
	return ($fail ? 0 : 1);
}



#
# given these args
# 1 the working file  - string must be non-empty and file must exist.
# 2 the final destination.  (copy is not actually done; just used for stat'ing)
#		string must be non-empty, but the file does not need to exist.
# 3 octal perm string to override default file perms.  can be empty/undef.
# 4 user ownership override.  can be empty/undef
# 5 group ownership override.  can be empty/undef
#
# note that a user_override or group_override of '0' will be treated
# as undef due to comparison below, but that's ok because
# the user/group overrides must be strings and not numerics.
#
# copy tmpfile to dest_file if changes or if dest_file does not exist
#
# return 1 on success.
# return 0 on failure.  not having a tmpfile is a failure.
#

sub set_file_perms {
	my ($tmpfile, $dest_file, $mode_override, $user_override, $group_override)=@_;
	my $ret=1;

	if (!$tmpfile || ! -f $tmpfile || !$dest_file) {
		&logit("set_file_perms: given invalid scratch file '$tmpfile' or dest file '$dest_file'");
		return (0);
	}
	
	if (! -f $dest_file) {
		# default is 0644.  Is this wise ???
		# if a non-default value was specified then chmod the working file.
		if ($mode_override) {
			# perm override was found
			# mode_override should be a number [octal]
			# but at this point, it has been converted
			# into a string, so we need to convert back.
			$ret=chmod (oct($mode_override), $tmpfile);
			print "set_file_perms: perm override $mode_override $tmpfile\n" if ($VERBOSE);
		}

		# default is root/root.  if a non-default value was spec'd
		# then chown the working file.
		if ($user_override || $group_override) {
			my $setuid=0;   # not setuid in the normal sense
			my $setgid=0;   # not setgid in the normal sense
			if ($user_override) {
				my $tmpuid = getpwnam($user_override);
				if ($tmpuid) {
					$setuid=$tmpuid;
					# emit message only if RenameIfDifferent actually renames it???
					print "set_file_perms: ownership override user=$user_override uid=$tmpuid $tmpfile\n" if ($VERBOSE);
				} else {
					&logit("set_file_perms: invalid file ownership override user=$user_override $tmpfile");
				}
			}
			if ($group_override) {
				my $tmpgid = getgrnam($group_override);
				if ($tmpgid) {
					$setgid=$tmpgid;
					# emit message only if RenameIfDifferent actually renames it???
					print "set_file_perms: group ownership override group=$group_override gid=$tmpgid $tmpfile\n" if ($VERBOSE);
				} else {
					&logit("set_file_perms: invalid file group ownership override group=$group_override $tmpfile");
				}
			}
			$ret=chown $setuid, $setgid, $tmpfile;
		}
	} else {
		# file already exists, so use existing perms as default values.
		my ($mode, $uid, $gid) = (stat $dest_file)[2,4,5];
		my ($setmode)=$mode & 0777;
		my ($setuid)=$uid;  # not setuid in the normal sense
		my ($setgid)=$uid;  # not setgid in the normal sense
		if ($mode_override) {
			# perm override was found
			$setmode=oct($mode_override);   # mode_override is a string, convert to numeric
			&logit("set_file_perms: perm override $mode_override $tmpfile");
		}
		$ret = chmod ($setmode, $tmpfile);

		if ($user_override) {
			my $tmpuid = getpwnam($user_override);
			if ($tmpuid) {
				$setuid=$tmpuid;
				# emit message only if RenameIfDifferent actually renames it???
				print "set_file_perms: ownership override user=$user_override uid=$tmpuid $tmpfile\n" if ($VERBOSE);
			} else {
				&logit("set_file_perms: invalid file ownership override user=$user_override $tmpfile");
			}
		}

		if ($group_override) {
			my $tmpgid = getgrnam($group_override);
			if ($tmpgid) {
				$setgid=$tmpgid;
				# emit message only if RenameIfDifferent actually renames it???
				print "set_file_perms: group ownership override group=$group_override gid=$tmpgid $tmpfile\n" if ($VERBOSE);
			} else {
				&logit("set_file_perms: invalid file group ownership override group=$group_override $tmpfile");
			}
		}
		# the default is root/root anyways, so skip the chown 
		if ($setuid || $setgid) {
			$ret=chown ($setuid, $setgid, $tmpfile);
			if (!$ret) {
				&logit("set_file_perms: chown ($setuid, $setgid, $tmpfile) failed, $!");
			}
		}
	}
	return $ret;   # returns the return value of chmod/chown?
}


#
# can't think of a good name besides conditional_deploy
#
# given several args (to be assed to set_file_perms or RenameIfDifferent
#
# 1 work/scratch file
# 2 destination file
# 3 file perm override (can be undef/empty string)
# 4 file user ownership override (can be undef/empty string)
# 5 file group ownership override (can be undef/empty string)
# 6 bitflag toggle on whether zero length files are acceptable or
#	generates an error
# 7 bitflag toggle on whether to ignore comment lines when
#	doing file compare.
# 
# return 1 on success
# return 0 on failure.
#
sub conditional_deploy {
	my($tmpfile, $newfile, $newmode, $newuser, $newgroup, $zerolentoggle, $ignore_comments)=@_;
	my $ret;

	if ($VERBOSE) {
		print "called conditional_deploy to copy from $tmpfile to $newfile\n";
		printf "  with mode override of %s\n", $newmode if ($newmode);
		printf "  with user override of %s\n", $newuser if ($newuser);
		printf "  with group override of %s\n", $newgroup if ($newgroup);
		printf "  with zero-len-ok? %s\n", $zerolentoggle?"yes":"no";
		printf "  with ignore-comments? %s\n", $ignore_comments?"yes":"no";
	}

	if (&set_file_perms($tmpfile, $newfile, $newmode, $newuser, $newgroup)) {
		if (! -f $newfile) {
			$ret=&my_rename($tmpfile, $newfile);
		} else {
			$ret=RenameIfDifferent($tmpfile, $newfile, $zerolentoggle, $ignore_comments);
		}
	} else {
		# set_file_perms failed some how.
		# set_file_perms will have already generated an error message.
		$ret=0;
		&logit("conditional_deploy: set_file_perms on $tmpfile failed!");
	}
	return ($ret);
}


#
# wrapper in front of perl function rename()
# rename() will fail if $SRC and $DEST are not on the same filesystem
# under solaris and linux.  (the rename system call will return errno
# EXDEV in this case).
#
# so, to accomodate this , mv is called instead
#
# return 1 on success, 0 on failure.
#
# presumes stat device of 0 is a failure condition .  not sure if this
# is actually always true .
#
sub my_rename {
	my($SRC, $DEST)=@_;
	if (! -f $SRC) {
		warn "my_rename: '$SRC' does not exist";
		return 0;
	}
	my ($srcdev) = (stat($SRC))[0];
	if ($srcdev <=0) {
		warn "my_rename: stat failed on $SRC, $!, aborted rename";
		return 0;
	}
	# can't do stat on $DEST in case it does not exist yet.
	# we presume that the directory it belong in does, so stat
	# that instead.
	my ($destbase)=($DEST=~m,(.*)/[^/]+,);
	my ($destdev) = (stat($destbase))[0];
	if ($destdev <=0) {
		warn "my_rename: stat failed on $destbase, $!, aborted rename";
		return 0;
	}

	# if source and dest are on the same filesystem
	# than just call rename().
	# otherwise, call a subshell and mv.
	#
	# perhaps... writing this routine in the name of completeness
	# was more work than it was worth.
	if ($srcdev == $destdev) {
		return rename($SRC,$DEST);
	} else {
		system("mv $SRC $DEST");
		# catch return of system?
		if ($?) {
			#presume failure.
			warn "my_rename: mv '$SRC' '$DEST' failed, $!";
			return 0;
		}
	}
	# if we get this far, cheer
	return 1;
}
