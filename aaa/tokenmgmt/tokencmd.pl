#!/usr/local/bin/perl -w

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

BEGIN {
	my $dir = $0;
	if($dir =~ m,/,) {
		$dir =~ s!^(.+)/[^/]+$!$1!;
	} else {
		$dir = ".";
	}
	#
	# Copy all of the entries in @INC, and prepend the fakeroot install
	# directory.
	#
	my @SAVEINC = @INC;
	foreach my $incentry (@SAVEINC) {
		unshift(@INC, "$dir/../../fakeroot.lib/$incentry");
	}
	unshift(@INC, "$dir/../lib/lib");
}

use strict;
use CGI qw(:standard);
use JazzHands::Management qw(:DEFAULT);
use Sys::Syslog qw(:standard :macros);
use Time::HiRes qw(tv_interval gettimeofday);
use CGI::Cookie;
use JazzHands::AuthToken;
use JSON::XS;

# This needs to not be here
                
my $AUTHDOMAIN = 'example.com';

sub loggit {
	syslog(LOG_ERR, @_);
#	printf STDERR @_;
}

sub tokencommand {
	openlog("tokencmd", "pid", LOG_LOCAL6);

	my $r = shift;

	my $auth;
	my $header = {
		-type => 'application/json'
	};
	my $response = {};
	if (!($auth = new JazzHands::AuthToken)) {
		loggit("Unable to initialize AuthToken object");
		$response = {
			errorcode => 'fatal',
			usererror => 'Fatal error performing authentication'
		};
		goto BAIL;
	}

	my $userinfo = $auth->Verify(
		request => $r
	);
	if (!$userinfo) {
		$response = {
			errorcode => 'unauthorized',
			usererror => 'Not authorized or session timeout'
		};
		goto BAIL;
	}
	my $appuser = $userinfo->{login};

	my $jhdbh;
	if (!($jhdbh = JazzHands::Management->new(application => 'tokenmgmt',
			appuser => $appuser))) {
		loggit("unable to open connection to JazzHands DB");
		$response = {
			errorcode => 'dberror',
			usererror => 'Fatal database error'
		};
		goto BAIL;
	}

	my $dbh = $jhdbh->DBHandle;

	my $authuser;

	if (!defined($authuser = $jhdbh->GetUser(login => $appuser))) {
		loggit("unable to get user information for authenticated user " .
			$appuser . ": " . $jhdbh->Error);
		$response = {
			errorcode => 'unauthorized',
			usererror => 'Not authorized or session timeout'
		};
		goto BAIL;
	}
	if (!ref($authuser)) {
		loggit("unable to get user information for authenticated user " .
			$authuser);
		$response = {
			errorcode => 'unauthorized',
			usererror => 'Not authorized or session timeout'
		};
		goto BAIL;
	}

	my $sysuid  = lc(param("userid"));
	my $tokenid  = lc(param("tokenid"));

	my $sth;
	my $q;

	my $user;
	my $tokenlist;
	my $authorized = 0;

	if ($sysuid) {
		#
		# Determine whether the admin is permitted to do things to this user
		#

		my $perm;

		#
		# ... first see if this is a global admin
		#
		$q = q {
			SELECT
				Property_Value
			FROM
				V_User_Prop_Expanded
			WHERE
				System_User_ID = :1 AND
				UClass_Property_Type = 'UserMgmt' AND
				UClass_Property_Name = 'GlobalTokenAdmin'
		};

		if (!($sth = $dbh->prepare($q))) {
			loggit("Unable to prepare database query: " . $dbh->errstr);
			$response = {
				errorcode => 'dberror',
				usererror => 'Fatal database error'
			};
			goto BAIL;
		}
		if (!($sth->execute($authuser->Id))) {
			loggit("Unable to execute database query: " . $sth->errstr);
			$response = {
				errorcode => 'dberror',
				usererror => 'Fatal database error'
			};
			goto BAIL;
		}
		my $userlist;
		$perm = ($sth->fetchrow_array)[0];
		$sth->finish;
		if ($perm && $perm eq 'Y') {
			$authorized = 1;
		} else {
			#
			# ... it wasn't, so see if they are authorized for this particular
			# user
			#
			$q = q {
				SELECT UNIQUE
					SU.System_User_ID
				FROM
					V_User_Prop_Expanded UPE JOIN
					MV_Uclass_User_Expanded UUE ON
						(Property_Value_Uclass_ID = UUE.Uclass_Id) JOIN
					System_User SU ON (UUE.System_User_ID = SU.System_User_ID)
				WHERE   
					UPE.System_User_ID = :adminsysuid AND
					SU.System_User_ID = :usersysuid AND
					UClass_Property_Type = 'UserMgmt' AND
					UClass_Property_Name = 'TokenAdminForUclass'
			};
			if (!($sth = $dbh->prepare($q))) {
				loggit("Unable to prepare database query: " . $dbh->errstr);
				$response = {
					errorcode => 'dberror',
					usererror => 'Fatal database error'
				};
				goto BAIL;
			}
			$sth->bind_param(':adminsysuid', $authuser->Id);
			$sth->bind_param(':usersysuid', $sysuid);
			if (!($sth->execute)) {
				loggit("Unable to execute database query: " . $sth->errstr);
				$response = {
					errorcode => 'dberror',
					usererror => 'Fatal database error'
				};
				goto BAIL;
			}
			if ($perm = ($sth->fetchrow_array)[0]) {
				$authorized = 1;
			}
			$sth->finish;
		}
		if (!$authorized) {
			$response = {
				errorcode => 'unauthorized-user',
				usererror => 'You are not authorized to manage this user'
			};
			goto BAIL;
		}

		if (!defined($user = $jhdbh->GetUser(id => $sysuid))) {
			loggit("unable to get user information for user " .
				$appuser . ": " . $jhdbh->Error);
			$response = {
				errorcode => 'baduser',
				usererror => 'User does not exist'
			};
			goto BAIL;
		}
	}

	if ($tokenid) {
		$authorized = 0;
		#
		# Determine whether the admin is permitted to do things to this token
		#

		my $perm;

		#
		# ... first see if this is a global admin
		#
		$q = q {
			SELECT
				Property_Value
			FROM
				V_User_Prop_Expanded
			WHERE
				System_User_ID = :1 AND
				UClass_Property_Type = 'TokenMgmt' AND
				UClass_Property_Name = 'GlobalAdmin'
		};

		if (!($sth = $dbh->prepare($q))) {
			loggit("Unable to prepare database query: " . $dbh->errstr);
			$response = {
				errorcode => 'dberror',
				usererror => 'Fatal database error'
			};
			goto BAIL;
		}
		if (!($sth->execute($authuser->Id))) {
			loggit("Unable to execute database query: " . $sth->errstr);
			$response = {
				errorcode => 'dberror',
				usererror => 'Fatal database error'
			};
			goto BAIL;
		}
		my $userlist;
		$perm = ($sth->fetchrow_array)[0];
		$sth->finish;
		if ($perm && $perm eq 'Y') {
			$authorized = 1;
		} else {
			#
			# ... it wasn't, so see if they are authorized for this particular
			# token
			#
			$q = q {
				SELECT UNIQUE
					Token_ID
				FROM
					V_User_Prop_Expanded UPE JOIN
					Token_Collection TC ON
						(Property_Value_Token_Col_ID = Token_Collection_ID) JOIN
					Token_Collection_Member USING (Token_Collection_ID) JOIN
					V_Token USING (Token_ID)
				WHERE   
					UPE.System_User_ID = :adminsysuid AND
					Token_ID = :tokenid AND
					UClass_Property_Type = 'TokenMgmt' AND
					UClass_Property_Name = 'ManageTokenCollection'
			};
			if (!($sth = $dbh->prepare($q))) {
				loggit("Unable to prepare database query: " . $dbh->errstr);
				$response = {
					errorcode => 'dberror',
					usererror => 'Fatal database error'
				};
				goto BAIL;
			}
			$sth->bind_param(':adminsysuid', $authuser->Id);
			$sth->bind_param(':tokenid', $tokenid);
			if (!($sth->execute)) {
				loggit("Unable to execute database query: " . $sth->errstr);
				$response = {
					errorcode => 'dberror',
					usererror => 'Fatal database error'
				};
				goto BAIL;
			}
			if ($perm = ($sth->fetchrow_array)[0]) {
				$authorized = 1;
			}
			$sth->finish;
		}
		if (!$authorized) {
			loggit("User %s not authorized to use this tool",
				$authuser->Login);
			$response = {
				errorcode => 'unauthorized-token',
				usererror => 'You are not authorized to manage this token'
			};
			goto BAIL;
		}
	}

	my $command = param('command');
	#
	# If we get here, the user or token parameters have been validated,
	# so just go for it.
	#
	if ($command eq 'getuser') {
		if (!$user) {
			#
			# If we haven't fetched a user that was passed...
			#
			if (!$tokenid) {
				$response = {
					errorcode => 'fatal',
					usererror => 'Parameter error'
				};
				goto BAIL;
			}
			$q = q {
				SELECT
					System_User_ID
				FROM
					System_User_Token JOIN
					System_User USING (System_User_ID)
				WHERE
					Token_ID = :tokenid AND
					System_User_Type <> 'pseudouser'
			};

			if (!($sth = $dbh->prepare($q))) {
				loggit("Unable to prepare database query: " . $dbh->errstr);
				$response = {
					errorcode => 'dberror',
					usererror => 'Fatal database error'
				};
				goto BAIL;
			}
			$sth->bind_param(':tokenid', $tokenid);
			if (!($sth->execute)) {
				loggit("Unable to execute database query: " . $sth->errstr);
				$response = {
					errorcode => 'dberror',
					usererror => 'Fatal database error'
				};
				goto BAIL;
			}
			$sysuid = ($sth->fetchrow_array)[0];
			$sth->finish;
			if (!$sysuid) {
				$response = {
					errorcode => 'unassignedtoken',
					usererror => 'Token is not assigned'
				};
				goto BAIL;
			}

			if (!defined($user = $jhdbh->GetUser(id => $sysuid))) {
				loggit("unable to get user information for user " .
					$appuser . ": " . $jhdbh->Error);
				$response = {
					errorcode => 'baduser',
					usererror => 'User does not exist'
				};
				goto BAIL;
			}
		}
		$response->{user} = {
			userid => $user->Id,
			login => $user->Login,
			first_name => $user->FirstName,
			last_name => $user->LastName,
			status => $user->Status,
			title => $user->Title
		};
		$q = q {
			SELECT
				Token_ID,
				Token_Serial,
				TT.Description,
				Token_Status,
				Is_User_Token_Locked,
				Token_PIN,
				TO_CHAR(Token_Unlock_Time, 'YYYY-MM-DD HH24:MI:SS') 
					AS Token_Unlock_Time,
				TO_CHAR(Issued_Date, 'YYYY-MM-DD') AS Issued_Date
			FROM
				V_Token JOIN
				Val_Token_Type TT USING (Token_Type)
			WHERE
				System_User_ID = :sysuid
		};

		if (!($sth = $dbh->prepare($q))) {
			loggit("Unable to prepare database query: " . $dbh->errstr);
			$response = {
				errorcode => 'dberror',
				usererror => 'Fatal database error'
			};
			goto BAIL;
		}
		$sth->bind_param(':sysuid', $user->Id);
		if (!($sth->execute)) {
			loggit("Unable to execute database query: " . $sth->errstr);
			$response = {
				errorcode => 'dberror',
				usererror => 'Fatal database error'
			};
			goto BAIL;
		}
		while (my @token = $sth->fetchrow_array) {
			push @{$response->{user}->{tokens}}, {
				tokenid => $token[0],
				serial => $token[1],
				type => $token[2],
				status => $token[3],
				locked => $token[4] eq 'Y' ? 1 : 0,
				pin => $token[5] ? 1 : 0,
				unlock_time => $token[6],
				issued_date => $token[7]
			};
		}
		$sth->finish;
	} elsif ($command eq 'unassign') {
		if (!$user || !$tokenid) {
			$response = {
				errorcode => 'fatal',
				usererror => 'Parameter error'
			};
			goto BAIL;
		}
		my $ret = $jhdbh->UnassignToken(
			token_id => $tokenid,
			login => $user->{login}
		);
		if ($ret) {
			$response = {
				errorcode => 'error',
				usererror => $ret
			};
			goto BAIL;
		} else {
			$response = {
				success => 1
			};
		}
	} elsif ($command eq 'assign') {
		if (!$user || !$tokenid) {
			$response = {
				errorcode => 'fatal',
				usererror => 'Parameter error'
			};
			goto BAIL;
		}
		my $ret = $jhdbh->AssignToken(
			token_id => $tokenid,
			login => $user->Login
		);
		if ($ret) {
			$response = {
				errorcode => 'error',
				usererror => $ret
			};
			goto BAIL;
		} else {
			$response = {
				success => 1
			};
		}
	} elsif ($command eq 'resetpic') {
		if (!$tokenid) {
			$response = {
				errorcode => 'fatal',
				usererror => 'Parameter error'
			};
			goto BAIL;
		}
		my $ret = $jhdbh->ResetTokenPIN(
			token_id => $tokenid
		);
		if ($ret) {
			$response = {
				errorcode => 'error',
				usererror => $ret
			};
			goto BAIL;
		} else {
			$response = {
				success => 1
			};
		}
	} elsif ($command eq 'setstatus') {
		my $status = param('value');
		if (!$tokenid || !$status) {
			$response = {
				errorcode => 'fatal',
				usererror => 'Parameter error'
			};
			goto BAIL;
		}
		my $ret;
		$ret = $jhdbh->SetTokenStatus(
			token_id => $tokenid,
			status => uc($status)
		);
		if ($ret) {
			$response = {
				errorcode => 'error',
				usererror => $ret
			};
			goto BAIL;
		}
		if (lc($status) eq 'destroyed') {
			$ret = $jhdbh->UnassignToken(
				token_id => $tokenid
			);
			if ($ret) {
				$response = {
					errorcode => 'error',
					usererror => $ret
				};
				goto BAIL;
			}
		}
		$response = {
			success => 1
		};
	} elsif ($command eq 'gethistory') {
		if (!$tokenid && !$user) {
			$response = {
				errorcode => 'fatal',
				usererror => 'Parameter error'
			};
			goto BAIL;
		}

		# Get the list of tokens assignment periods that we want to report
		# on.  There is the possibility that the token serial number may
		# be inaccurate if it has changed since the audit log has
		# been written, however this should never, ever happen under any
		# remotely normal conditions, so we're going to ignore it, since
		# the database query will get very nasty to take that into
		# consideration.  This will only affect the assignment/unassignment
		# logs.

		$q = q {
			SELECT
				System_User_ID,
				Login,
				Token_ID,
				Token_Serial,
				Time_Util.Epoch(Issued_Date) AS Issued_Date,
				Time_Util.Epoch(AUD#Timestamp) AS AUD#Timestamp,
				AUD#Action,
				AUD#User
			FROM
				AUD$System_User_Token JOIN 
				System_User USING (System_User_ID) JOIN
				Token USING (Token_ID)
			WHERE
				AUD#Action IN ('INS', 'DEL') AND
		};

		if ($tokenid) {
			if ($user) {
				$q .= "System_User_ID = :sysuid AND Token_ID = :tokenid";
			} else {
				$q .= "Token_ID = :tokenid";
			}
		} else {
			$q .= "System_User_ID = :sysuid";
		}
		$q .= " ORDER BY System_User_Id, Token_Id, AUD#Timestamp";

		if (!($sth = $dbh->prepare($q))) {
			loggit("Unable to prepare database query getting history: " .
				$dbh->errstr);
			$response = {
				errorcode => 'dberror',
				usererror => 'Fatal database error'
			};
			goto BAIL;
		}
		if ($user) {
			$sth->bind_param(':sysuid', $user->Id);
		}
		if ($tokenid) {
			$sth->bind_param(':tokenid', $tokenid);
		}
		if (!($sth->execute)) {
			loggit("Unable to execute database query getting history: " .
				$sth->errstr);
			$response = {
				errorcode => 'dberror',
				usererror => 'Fatal database error'
			};
			goto BAIL;
		}
		my @assignments;
		my $assignment;
		#
		# With the query above, each row will either be the start of an
		# assignment, or the end of the assignment from the previous row.
		#
		while (my ($sysuid, $login, $tokid, $serial, $issued, $timestamp, 
				$action, $person) = $sth->fetchrow_array) {
			if ($action eq 'INS') {
				$assignment = {
					system_user_id => $sysuid,
					login => $login,
					token_id => $tokid,
					serial => $serial,
					start_time => $timestamp,
					end_time => undef,
					assignactor => $person
				};
				push @assignments, $assignment;
			}
			if ($action eq 'DEL') {
				if (!$assignment || ($assignment->{token_id} != $tokid)) {
					# This should never happen (a delete without an insert),
					# but we should be able to deal with it
					$assignment = {
						system_user_id => $sysuid,
						login => $login,
						token_id => $tokid,
						serial => $serial,
						start_time => $issued,
						end_time => $timestamp,
						assignactor => "Unknown?"
					};
					push @assignments, $assignment;
				} else {
					$assignment->{end_time} = $timestamp;
					$assignment->{unassignactor} = $person;
				}
				$assignment = undef;
			}
		}
		$sth->finish;
		#
		# Ok, we now have all of our token assignment ranges, so get all
		# of the events that happened to these tokens during those ranges
		#
		$q = q {
			SELECT
				Token_ID,
				Token_Serial,
				Token_Status,
				Token_Key,
				Token_PIN,
				Time_Util.EPOCH(AUD#Timestamp),
				AUD#User
			FROM
				AUD$Token
			WHERE
				Token_ID = :tokid AND
				AUD#Timestamp >= TO_DATE(:starttime, 
					'YYYY-MM-DD HH24:MI:SS') AND
				AUD#Timestamp <= TO_DATE(:endtime,
					'YYYY-MM-DD HH24:MI:SS')
			ORDER BY AUD#Timestamp
		};

		if (!($sth = $dbh->prepare($q))) {
			loggit("Unable to prepare database query getting token events: " .
				$dbh->errstr);
			$response = {
				errorcode => 'dberror',
				usererror => 'Fatal database error'
			};
			goto BAIL;
		}
#		my ($sec, $min, $hour, $mday, $mon, $year) = localtime;
#		my $now = sprintf("%04d-%02d-%02d %02d:%02d:%02d",
#			$year + 1900, $mon + 1, $mday, $hour, $min, $sec);
		my $logs = [];		
		my @events;
		if (!@assignments) {
			$response->{events} = {};
			goto BAIL;
		}
		foreach my $range (@assignments) {
			# This shouldn't happen
			next if (!$range->{token_id});
			# Log the assignment (if there is one)
			if ($range->{system_user_id}) {
				push @events, {
					token_id => $range->{token_id},
					serial => $range->{serial},
					system_user_id => $range->{system_user_id},
					login => $range->{login},
					event => "Token Assigned",
					actor => spliteventuser($range->{assignactor}),
					timestamp => $range->{start_time}
				};
			}
			$sth->bind_param(':tokid', $range->{token_id});
			my ($sec, $min, $hour, $mday, $mon, $year) = 
				localtime($range->{start_time});
			my $starttime = sprintf("%04d-%02d-%02d %02d:%02d:%02d",
				$year + 1900, $mon + 1, $mday, $hour, $min, $sec);
			($sec, $min, $hour, $mday, $mon, $year) = 
				localtime($range->{end_time} || time());
			my $endtime = sprintf("%04d-%02d-%02d %02d:%02d:%02d",
				$year + 1900, $mon + 1, $mday, $hour, $min, $sec);
			$sth->bind_param(':starttime', $starttime);
			$sth->bind_param(':endtime', $endtime);
			if (!($sth->execute)) {
				loggit("Unable to execute database query getting events: " .
					$sth->errstr);
				$response = {
					errorcode => 'dberror',
					usererror => 'Fatal database error'
				};
				goto BAIL;
			}
			my $savedstatus;
			while (my ($tokenid, $serial, $status, $key, $pic, $timestamp,
					$actor) = $sth->fetchrow_array) {
				# If we don't have a record, make a baseline
				if (!$savedstatus) {
					$savedstatus = {
						status => 'DISABLED',
						key => $key,
						pic => undef
					};
				}
				if ($status ne $savedstatus->{status}) {
					push @events, {
						token_id => $range->{token_id},
						serial => $serial,
						system_user_id => $range->{system_user_id},
						login => $range->{login},
						event => "Status Changed",
						actor => spliteventuser($actor),
						timestamp => $timestamp,
						previous => $savedstatus->{status},
						current => $status
					};
					$savedstatus->{status} = $status;
				}
				if ($key ne $savedstatus->{key}) {
					$savedstatus->{key} = $key;
					push @events, {
						token_id => $range->{token_id},
						serial => $serial,
						system_user_id => $range->{system_user_id},
						login => $range->{login},
						event => "Token Reprogrammed",
						actor => spliteventuser($actor),
						timestamp => $timestamp,
					}
				}
				my $action = undef;
				if ($savedstatus->{pic}) {
					if (!$pic) {
						$action = "PIC Cleared";
					} elsif ($savedstatus->{pic} ne $pic) {
						$action = "PIC Changed";
					}
				} elsif ($pic) {
					$action = "PIC Set";
				}

				if ($action) {
					$savedstatus->{pic} = $pic;
					push @events, {
						token_id => $range->{token_id},
						serial => $serial,
						system_user_id => $range->{system_user_id},
						login => $range->{login},
						event => $action,
						actor => spliteventuser($actor),
						timestamp => $timestamp,
					};
				}
			}
			if ($range->{end_time}) {
				# Log the unassignment
				push @events, {
					token_id => $range->{token_id},
					serial => $range->{serial},
					system_user_id => $range->{system_user_id},
					login => $range->{login},
					event => "Token Unassigned",
					actor => spliteventuser($range->{unassignactor}),
					timestamp => $range->{end_time}
				}
			}
			$response->{events} = \@events;
		}
		$sth->finish;
	} else {
		$response = {
			errorcode => 'invalidcommand',
			usererror => 'Invalid server command'
		};
		goto BAIL;
	}

	$jhdbh->commit();
	BAIL:
	if (defined($jhdbh)) {
		$jhdbh->rollback();
	}
	print header($header);
	print encode_json $response;
	closelog;
	undef $jhdbh;
}

sub spliteventuser {
	my $user = shift;
	return '' if !$user;
	my ($dbuser, $appuser) = split m%/%, $user;
	if ($appuser) {
		return lc($appuser);
	} else {
		return $dbuser;
	}
}

&tokencommand (shift);
