
SeverityNames=(
	Success=0x0:STATUS_SEVERITY_SUCCESS
	Informational=0x1:STATUS_SEVERITY_INFORMATIONAL
	Warning=0x2:STATUS_SEVERITY_WARNING
	Error=0x3:STATUS_SEVERITY_ERROR
	)

FacilityNames=(
	System=0x0:FACILITY_SYSTEM
	Runtime=0x1:FACILITY_RUNTIME
	User=0x100:FACILITY_USER
	)

OutputBase=16
MessageIdTypedef=WORD

;
;/* Message categories */
;

MessageId=0x1
SymbolicName=CAT_STARTUP
Language=English
Filter Startup
.

MessageId=0x2
SymbolicName=CAT_NORMAL_PROCESSING
Language=English
Normal Processing
.

MessageId=0x3
SymbolicName=CAT_CONNECTION_ERROR
Language=English
System connectivity problem
.

MessageId=0x4
SymbolicName=CAT_BAD_PASSWORD
Language=English
Bad Passwords
.

MessageId=0x5
SymbolicName=CAT_CONFIG_ERROR
Language=English
Configuration Error
.

MessageId=0x6
SymbolicName=CAT_RUNTIME_ERROR
Language=English
Runtime Errors (shouldn't happen)
.

MessageId=0x7
SymbolicName=CAT_CATEGORY_MAX
Language=English
Nothing to see here
.

MessageIdTypedef=DWORD

; /* MessageIds in the 0x0100s are for successes and non-errors */

MessageId=0x100
Severity=Informational
Facility=System
SymbolicName=MSG_LOADED
Language=English
PasswordMangler handler registered
.

MessageId=0x101
Severity=Informational
Facility=System
SymbolicName=MSG_PWCHANGE_STARTED
Language=English
Password change started for %1
.

MessageId=0x102
Severity=Informational
Facility=System
SymbolicName=MSG_PWCHANGE_SUCCESS
Language=English
Password change successful for %1
.

MessageId=0x103
Severity=Informational
Facility=System
SymbolicName=MSG_PWCHANGE_NO_USERID
Language=English
Attribute %1 not found for user %2.  Remote password will not be changed.
.

MessageId=0x104
Severity=Informational
Facility=System
SymbolicName=MSG_PWCHANGE_SET
Language=English
Password is being administratively set for %1.  Remote password will not be changed.
.

; /* MessageIds in the 0x0200s are for configuration errors */

MessageId=0x200
Severity=Error
Facility=System
SymbolicName=MSG_REGISTRY_OPEN_ERROR
Language=English
Error opening registry key %1
.

MessageId=0x201
Severity=Error
Facility=System
SymbolicName=MSG_AUTHUSER_ERROR
Language=English
No valid authentication user stored in registry %1\%2 or present in URL %4 from %1\%3.
.

MessageId=0x202
Severity=Error
Facility=System
SymbolicName=MSG_AUTHPASSWORD_ERROR
Language=English
No valid authentication password stored in registry %1\%2 or present in URL %4 from %1\%3.
.

MessageId=0x203
Severity=Error
Facility=System
SymbolicName=MSG_REGISTRY_LDAP_BASE_ERROR
Language=English
Error reading LDAP search base from registry %1\%2
.

MessageId=0x204
Severity=Error
Facility=System
SymbolicName=MSG_REGISTRY_CHANGE_URL_ERROR
Language=English
Error reading remote URL from registry %1\%2
.

MessageId=0x205
Severity=Error
Facility=System
SymbolicName=MSG_URL_ERROR
Language=English
URL %1 is bad - %2
.

; /* MessageIds in the 0x0300s are for user errors */

MessageId=0x300
Severity=Error
Facility=User
SymbolicName=MSG_PASSWORD_TOO_LONG
Language=English
Password is longer than %1 characters
.

MessageId=0x301
Severity=Error
Facility=User
SymbolicName=MSG_PASSWORD_REJECTED
Language=English
Remote server rejected password change for %1: %2
.

; /* MessageIds in the 0x0400s are for errors in the password setting process */

MessageId=0x400
Severity=Error
Facility=Runtime
SymbolicName=MSG_NO_USER
Language=English
User %1 was not found.  This error should never occur other than in debugging.
.

MessageId=0x401
Severity=Error
Facility=Runtime
SymbolicName=MSG_LDAP_QUERY_ERROR
Language=English
Error querying the LDAP server for user %1: %2
.

MessageId=0x402
Severity=Error
Facility=Runtime
SymbolicName=MSG_INTERNETOPEN_FAILED
Language=English
InternetOpen() failed changing password for %1: %2
.

MessageId=0x403
Severity=Error
Facility=Runtime
SymbolicName=MSG_INTERNETCONNECT_FAILED
Language=English
InternetConnect() failed changing password for %1: %2
.

MessageId=0x404
Severity=Error
Facility=Runtime
SymbolicName=MSG_URLENCODE_FAILED
Language=English
URL encoding of password failed while changing password for %1.  This shouldn't happen.
.

MessageId=0x405
Severity=Error
Facility=Runtime
SymbolicName=MSG_HTTPOPENREQUEST_FAILED
Language=English
HTTPOpenRequest() failed changing password for %1: %2
.

MessageId=0x406
Severity=Error
Facility=Runtime
SymbolicName=MSG_HTTPSENDREQUEST_FAILED
Language=English
HTTPSendRequest() failed changing password for %1: %2
.

MessageId=0x407
Severity=Error
Facility=Runtime
SymbolicName=MSG_BAD_STATUS
Language=English
Unexpected status from remote web server while changing password for %1.
Expected 200, received %2.
.

MessageId=0x408
Severity=Error
Facility=Runtime
SymbolicName=MSG_INTERNETREADFILE_FAILED
Language=English
InternetReadFile() failed changing password for %1: %2
.

MessageId=0x409
Severity=Error
Facility=Runtime
SymbolicName=MSG_NO_STATUS_RETURNED
Language=English
No status returned from server %2 changing password for %1
.

