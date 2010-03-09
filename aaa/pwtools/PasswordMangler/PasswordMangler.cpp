/*
* Copyright (c) 2005-2010, Vonage Holdings Corp.
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
*     * Redistributions of source code must retain the above copyright
*       notice, this list of conditions and the following disclaimer.
*     * Redistributions in binary form must reproduce the above copyright
*       notice, this list of conditions and the following disclaimer in the
*       documentation and/or other materials provided with the distribution.
*
* THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
* EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
* DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
* LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
* ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
#include <tchar.h>
#include <windows.h>
#include <string.h>
#include <stdio.h>
#include <ntsecapi.h>
#include <iads.h>
#include <activeds.h>
#include <strsafe.h>
#include <WinInet.h>
#include "JazzHandsmsgcat.h"

#ifndef STATUS_SUCCESS
#define STATUS_SUCCESS ( (NTSTATUS) 0x00000000L )
#endif

#define EVENTSOURCE				TEXT("JazzHands")
#define REGISTRY_KEY			TEXT("Software\\JazzHands")
#define REGISTRY_URL			TEXT("PasswordChangeURL")
#define REGISTRY_AUTHUSER		TEXT("AuthUser")
#define REGISTRY_AUTHPASSWORD	TEXT("AuthPassword")

static char hexchar[16] = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
	'a', 'b', 'c', 'd', 'e', 'f'};

/*
Password "filter" for updating non-AD passwords

Installation: 
Copy the .dll file to c:\windows\system32

To register the password filter, update the following system registry key.

HKEY_LOCAL_MACHINE\
 SYSTEM\
 CurrentControlSet\
 Control\
 Lsa

If the Notification Packages subkey exists, add the name of your DLL to the
existing value data.  Do not overwrite the existing values, and do not
include the .dll extension.

If the Notification Packages subkey does not exist, add it, and then specify
the name of the DLL for the value data. Do not include the .dll extension.

*/

char    *base64_encode (char *, size_t);
void    __init_base64 ();
BOOL AddEventSource(LPTSTR, LPTSTR, DWORD);

int				__base64_initted = 0;
unsigned char	__base64_encode_table[64];
unsigned char	__base64_decode_table[256];
BOOL			URLEncode(char *src, char *dst, size_t *dstsz);

DWORD FindUser( WCHAR *UserName ) {
/*
	This function searches for a samaccountname starting at the given
	base that contains a jazzHandsSystemUserID parameter. If this username
	is found, we want to change this password elsewhere, otherwise this
	filter will return successful to just change it in AD.
	
	Arguments:
		UserName - samAccountName of user whose password changed.

	Return Value:
		Returns the external system_user_id associated with this account,
		or zero if it doesn't exist.
*/

HRESULT					hr;
HKEY					hKey;
DWORD					keySize;

IDirectorySearch		*pGCSearch;
IADsContainer			*pContainer;

ADS_SEARCH_HANDLE		hSearch;
ADS_SEARCHPREF_INFO		SearchPrefs[1];
ADS_SEARCH_COLUMN		col;
TCHAR					wFilter[1024];
TCHAR					wSearchBase[1024];
LPOLESTR				pszAttribute[1] = { TEXT("jazzHandsSystemUserID") };
WCHAR					SearchString[] = TEXT("(&(objectCategory=person)(objectClass=user)(sAMAccountName=%s))");

HANDLE					EventLog;
LPCTSTR					EventStr[10];

DWORD					dwAttrNameSize;
DWORD					dwNumPrefs;
DWORD					dwUserID;

DWORD					SysError = 0;
LPVOID					SysErrorStr = NULL;


	// 0 is an invalid SystemUserID
	dwUserID = 0;

	if ((EventLog = RegisterEventSource(NULL, EVENTSOURCE)) == NULL) {
		return dwUserID;
	}

	// Get parameters from the registry
	if (RegOpenKeyEx(HKEY_LOCAL_MACHINE, REGISTRY_KEY, 0,
			KEY_QUERY_VALUE, &hKey) != ERROR_SUCCESS) {

		EventStr[0] = REGISTRY_KEY;
		ReportEvent(
			EventLog,
			EVENTLOG_ERROR_TYPE,
			CAT_CONFIG_ERROR,
			MSG_REGISTRY_OPEN_ERROR,
			NULL,
			1,
			0,
			EventStr,
			NULL);

		DeregisterEventSource(EventLog);
		return 0;
	}

	// If we don't have a search base, bail

	keySize = sizeof(wSearchBase);
	if (RegQueryValueEx(hKey, L"QueryBase", NULL, NULL, (LPBYTE) wSearchBase,
			&keySize) != ERROR_SUCCESS) {
		RegCloseKey(hKey);

		EventStr[0] = REGISTRY_KEY;
		EventStr[1] = (LPCTSTR) wSearchBase;
		ReportEvent(
			EventLog,
			EVENTLOG_ERROR_TYPE,
			CAT_CONFIG_ERROR,
			MSG_REGISTRY_LDAP_BASE_ERROR,
			NULL,
			2,
			0,
			EventStr,
			NULL);

		DeregisterEventSource(EventLog);
		return 0;
	}

	// Done with the registry	

	RegCloseKey(hKey);

	// setup the search filter
//	if ( 0 >= swprintf( wFilter, (sizeof(wFilter)/sizeof(WCHAR))-1, SearchString, UserName ) ) {

	if ((StringCbPrintfExW(wFilter, sizeof(wFilter), NULL, NULL, 
		STRSAFE_NULL_ON_FAILURE, SearchString, UserName)) != S_OK) { 
		// there was a buffer overflow (UserName too long) or other error, give up
		return( dwUserID );

	}

	CoInitialize( NULL );

	// setup the search preferences
	SearchPrefs[0].dwSearchPref = ADS_SEARCHPREF_SEARCH_SCOPE;
	SearchPrefs[0].vValue.dwType = ADSTYPE_INTEGER;
	SearchPrefs[0].vValue.Integer = ADS_SCOPE_SUBTREE;
	dwNumPrefs = 1;
	dwAttrNameSize = 1;

	// bind to the search base
	if ( S_OK == ADsGetObject( wSearchBase, IID_IADsContainer, (void**) &pContainer) ) {
		// get a pointer to the directory search interface
		if ( S_OK == pContainer->QueryInterface( IID_IDirectorySearch, (void**) &pGCSearch ) ) {
			// set the search prefs
			pGCSearch->SetSearchPreference( &SearchPrefs[0], dwNumPrefs );
			// execute the search
			if ( S_OK == pGCSearch->ExecuteSearch( wFilter, pszAttribute, dwAttrNameSize, &hSearch ) ) {
				if ( pGCSearch->GetNextRow( hSearch ) != S_ADS_NOMORE_ROWS ) {
					// the user was found!
					// Get the attribute we want
					hr = pGCSearch->GetColumn( hSearch, *pszAttribute, &col );
					if ( SUCCEEDED(hr) )
					{
						dwUserID = col.pADsValues->Integer;
					} else {
						EventStr[0] = (LPTSTR) *pszAttribute;
						EventStr[1] = (LPTSTR) UserName;
						ReportEvent(
							EventLog,
							EVENTLOG_INFORMATION_TYPE,
							CAT_NORMAL_PROCESSING,
							MSG_PWCHANGE_NO_USERID,
							NULL,
							2,
							0,
							EventStr,
							NULL);
					}
				} else {
					EventStr[0] = (LPTSTR) UserName;
					ReportEvent(
						EventLog,
						EVENTLOG_ERROR_TYPE,
						CAT_CONFIG_ERROR,
						MSG_NO_USER,
						NULL,
						1,
						0,
						EventStr,
						NULL);
				}
				pGCSearch->CloseSearchHandle( hSearch );
			} else {
				SysError = GetLastError();
			}
			pGCSearch->Release();
		} else {
			SysError = GetLastError();
		}
		pContainer->Release();
	} else {
		SysError = GetLastError();
	}

	if (SysError) {
		FormatMessage(
			FORMAT_MESSAGE_ALLOCATE_BUFFER |
			FORMAT_MESSAGE_FROM_SYSTEM,
			NULL,
			SysError,
			MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
			(LPTSTR) &SysErrorStr,
			0, NULL);

		EventStr[0] = (LPCTSTR) UserName;
		EventStr[1] = (LPCTSTR) SysErrorStr;
		ReportEvent(
			EventLog,
			EVENTLOG_ERROR_TYPE,
			CAT_CONNECTION_ERROR,
			MSG_LDAP_QUERY_ERROR,
			NULL,
			2,
			0,
			EventStr,
			NULL);
		LocalFree(SysErrorStr);
	}

	CoUninitialize(); 

	DeregisterEventSource(EventLog);
	return( dwUserID );
}




BOOL NTAPI InitializeChangeNotify( void )
{
/*
	InitializeChangeNotify - exported by the DLL and called by the Local Security Authority

	This function is called when this DLL is loaded by the system.  Perform any initialization
	necessary for the DLL here.

	Arguments:
		NONE

	Return Value:
		TRUE - Initialization succeeded.
		FALSE - Initialization failed. This DLL will be unloaded by the system.
*/
	HKEY hKey;
	HANDLE EventLog;

	// If we don't have a message catalog registered, register it.  If
	// we can't register it, FAIL!!!

	if (RegOpenKeyEx(HKEY_LOCAL_MACHINE, 
			TEXT("SYSTEM\\CurrentControlSet\\Services\\EventLog\\Application\\JazzHands"),
			0, KEY_QUERY_VALUE, &hKey) != ERROR_SUCCESS) {

		if (!AddEventSource(
				EVENTSOURCE,
				TEXT("JazzHandsmsgcat.dll"),
				CAT_CATEGORY_MAX)) {
			return FALSE;
		}
	}

	// Not being able to open the event source shouldn't kill us, I guess

	if ((EventLog = RegisterEventSource(NULL, EVENTSOURCE)) == NULL) {
		return TRUE;
	}

	// Log our startup

	ReportEvent(
		EventLog,
		EVENTLOG_INFORMATION_TYPE,
		CAT_STARTUP,
		MSG_LOADED,
		NULL,
		0,
		0,
		NULL,
		NULL);

	DeregisterEventSource(EventLog);
	return( TRUE );
}


NTSTATUS NTAPI PasswordChangeNotify( PUNICODE_STRING UserName, ULONG RelativeId, PUNICODE_STRING Password )
{
/*
  PasswordChangeNotify - exported by the DLL and called by the Local Security Authority

  This function is called to notify this DLL that a password was changed.
	Meaning that all the password filters approved the password and the new
	password has in-fact been stored.

	Arguments:
		UserName - Samaccountname of user whose password changed.
    RelativeId - RID of the user whose password changed.
    NewPassword - Cleartext new password for the user.
	
	Return Value:
		STATUS_SUCCESS is the only return value for this function.  Errors are ingnored by
		the caller as the password has already been changed and cannot be unchanged.
*/
	return( STATUS_SUCCESS );
}


BOOL NTAPI PasswordFilter( PUNICODE_STRING UserName, PUNICODE_STRING FullName, PUNICODE_STRING Password, BOOL SetOperation )
{
/*
	PasswordFilter - exported by the DLL and called by the Local Security
		Authority

	This function is called to notify this DLL that a password change is in
	progress.  The value returned by this function determines if the new
	password will be accepted by the system.  Note: in the case where multiple
	password filters are loaded, then any filter can veto the password change.

	Arguments:
		UserName - Samaccountname of user whose password changed.
		FullName - Displayname of the user whose password changed.
		NewPassword - Cleartext new password for the user.
		SetOperation - TRUE if the password was SET rather than CHANGED.

	Return Value:
		TRUE - The password change can proceed
		FALSE - The password change may not proceed

	Note: the PUNICODE_STRING struct
		Length - Specifies the length, in bytes, of the string pointed to by
			the Buffer member, not including the terminating NULL character,
			if any.
		MaximumLength - Specifies the total size, in bytes, of memory
			allocated for Buffer. 
		Buffer - Pointer to a wide-character string. Note that the strings
			returned by the various LSA functions might not be null terminated. 
*/

	HKEY			hKey;

	PWCHAR			User = NULL;
	PWCHAR			Pass = NULL;
	BOOL			bSuccessful = TRUE;

	// Connection information

	TCHAR 			*authUserName = NULL;
	TCHAR 			*authPassword = NULL;
	TCHAR 			*urlText = NULL;
	TCHAR 			*HostName = NULL;

	DWORD			dwPassLen;
	DWORD			dwUserLen;
	size_t			sz;
	size_t			passsz;
	size_t			setsz;

	DWORD			UserID;
	DWORD			status;
	DWORD			statusSize = 0;
	DWORD			keySize;

	HINTERNET		hInet = NULL;
	HINTERNET		hSession = NULL;
	HINTERNET		hRequest = NULL;

	BOOL			bStatus;
	char 			*FullAuthHdr = NULL;
	char 			*tmpptr = NULL;
	char 			*encodedAuthHdr = NULL;
	URL_COMPONENTS	Url;

	char			*pass;
	char			*encodedpass;
	char   			postBuffer[4096];
	TCHAR			*errorBuffer;

	static TCHAR hdrs[] =
		TEXT("Content-Type: application/x-www-form-urlencoded");
	static char *authhdr = "Authorization: Basic ";

	DWORD SysError = 0;
	LPVOID SysErrorStr = NULL;

	HANDLE					EventLog;
	LPCTSTR					EventStr[10];
	DWORD					EventID = 0;

	FILE *f = NULL;

	if ((EventLog = RegisterEventSource(NULL, EVENTSOURCE)) == NULL) {
		return TRUE;
	}


	User = (PWCHAR) HeapAlloc( GetProcessHeap(), HEAP_ZERO_MEMORY,
		UserName->Length + sizeof( WCHAR ) );
	if ( User == NULL ) {
		// couldn't allocate memory, let the password through unchallenged
		goto CLEANUP;
	}

	Pass = (PWCHAR) HeapAlloc( GetProcessHeap(), HEAP_ZERO_MEMORY,
		Password->Length + sizeof( WCHAR ) );
	if ( Pass == NULL ) {
		goto CLEANUP;
	}

	CopyMemory( User, UserName->Buffer, UserName->Length );
	CopyMemory( Pass, Password->Buffer, Password->Length );

	// This needs to get ripped out when we're done with the debugging

	EventStr[0] = User;
	ReportEvent(
		EventLog,
		EVENTLOG_INFORMATION_TYPE,
		CAT_NORMAL_PROCESSING,
		MSG_PWCHANGE_STARTED,
		NULL,
		1,
		0,
		EventStr,
		NULL);

	// Get parameters from the registry
	if (RegOpenKeyEx(HKEY_LOCAL_MACHINE, REGISTRY_KEY, 0,
			KEY_QUERY_VALUE, &hKey) == ERROR_SUCCESS) {

		if (RegQueryValueEx(hKey, REGISTRY_URL, NULL, NULL, NULL,
				&keySize) == ERROR_SUCCESS) {
			keySize += sizeof(TCHAR);
			if ((urlText = (TCHAR *) HeapAlloc( GetProcessHeap(), 
					HEAP_ZERO_MEMORY, keySize)) == NULL) {
				goto CLEANUP;
			}
			if (RegQueryValueEx(hKey, REGISTRY_URL, NULL, NULL, 
					(LPBYTE) urlText, &keySize) != ERROR_SUCCESS) {
				goto CLEANUP;
			}
		} else {

			EventStr[0] = REGISTRY_KEY;
			EventStr[1] = REGISTRY_URL;
			ReportEvent(
				EventLog,
				EVENTLOG_ERROR_TYPE,
				CAT_CONFIG_ERROR,
				MSG_REGISTRY_CHANGE_URL_ERROR,
				NULL,
				1,
				0,
				EventStr,
				NULL);

			goto CLEANUP;
		}
		if (RegQueryValueEx(hKey, REGISTRY_AUTHUSER, NULL, NULL, NULL,
				&keySize) == ERROR_SUCCESS) {
			keySize += sizeof(TCHAR);
			if ((authUserName = (TCHAR *) HeapAlloc( GetProcessHeap(), 
					HEAP_ZERO_MEMORY, keySize)) == NULL) {
				goto CLEANUP;
			}
			if (RegQueryValueEx(hKey, REGISTRY_AUTHUSER, NULL, NULL, 
					(LPBYTE) authUserName, &keySize) != ERROR_SUCCESS) {
				goto CLEANUP;
			}
		}
		if (RegQueryValueEx(hKey, REGISTRY_AUTHPASSWORD, NULL, NULL, NULL,
				&keySize) == ERROR_SUCCESS) {
			keySize += sizeof(TCHAR);
			if ((authPassword = (TCHAR *) HeapAlloc( GetProcessHeap(), 
					HEAP_ZERO_MEMORY, keySize)) == NULL) {
				goto CLEANUP;
			}
			if (RegQueryValueEx(hKey, REGISTRY_AUTHPASSWORD, NULL, NULL, 
					(LPBYTE) authPassword, &keySize) != ERROR_SUCCESS) {
				goto CLEANUP;
			}
		}
		RegCloseKey(hKey);
	} else {
		EventStr[0] = REGISTRY_KEY;
		ReportEvent(
			EventLog,
			EVENTLOG_ERROR_TYPE,
			CAT_CONFIG_ERROR,
			MSG_REGISTRY_OPEN_ERROR,
			NULL,
			1,
			0,
			EventStr,
			NULL);
	}
	hKey = NULL;

	// Done with the registry	

	// If we're setting the password, just return successfully, otherwise we
	// may get ourselves into a loop

	if (SetOperation) {
		EventStr[0] = User;
		ReportEvent(
			EventLog,
			EVENTLOG_INFORMATION_TYPE,
			CAT_NORMAL_PROCESSING,
			MSG_PWCHANGE_SET,
			NULL,
			1,
			0,
			EventStr,
			NULL);
		return bSuccessful;
	}
	if ( !(UserID = FindUser( User )) ) {

		// This user does not have a corresponding SystemUserID, so don't try
		// to change the password elsewhere.  We've already logged this,
		// so no need to here.

		goto CLEANUP;
	}

	// If we get to this point, anything below should default to disallowing
	// the password change
	bSuccessful = FALSE;

	dwPassLen = Password->Length / sizeof( WCHAR );
	dwUserLen = UserName->Length / sizeof( WCHAR );

	// Get the pieces that we're interested in split out of the URL

	memset(&Url, 0, sizeof(Url));
	Url.dwStructSize = (DWORD) sizeof(Url);
	Url.dwSchemeLength = 1;
	Url.dwHostNameLength = 1;
	Url.dwUserNameLength = 1;
	Url.dwPasswordLength = 1;
	Url.dwUrlPathLength = 1;

	keySize = 0;
	if (!InternetCrackUrl(
			urlText,
			0,
			0,
			&Url)) {
		SysError = GetLastError();
		goto CLEANUP;
	}

	if ((HostName = (TCHAR *) HeapAlloc( GetProcessHeap(), 
			HEAP_ZERO_MEMORY, (Url.dwHostNameLength + 1) * sizeof(TCHAR))) 
			== NULL) {
		goto CLEANUP;
	}
	memcpy(HostName, Url.lpszHostName, Url.dwHostNameLength * sizeof(TCHAR));

	if (Url.lpszUserName) {
		// If we have a username here, override what we read out of the
		// registry
		if ( authUserName != NULL ) {
			SecureZeroMemory( authUserName, lstrlen(authUserName) * 
				sizeof(TCHAR));
			HeapFree( GetProcessHeap(), 0, authUserName );
		}
		if ((authUserName = (TCHAR *) HeapAlloc( GetProcessHeap(), 
				HEAP_ZERO_MEMORY, (Url.dwUserNameLength + 1) * sizeof(TCHAR)))
				== NULL) {
			goto CLEANUP;
		}
		memcpy(authUserName, Url.lpszUserName,
			Url.dwUserNameLength * sizeof(TCHAR));
	}

	if (Url.lpszPassword) {
		// If we have a username here, override what we read out of the
		// registry
		if ( authPassword != NULL ) {
			SecureZeroMemory( authPassword, lstrlen(authPassword) *
				sizeof(TCHAR));
			HeapFree( GetProcessHeap(), 0, authPassword );
		}
		if ((authPassword = (TCHAR *) HeapAlloc( GetProcessHeap(), 
				HEAP_ZERO_MEMORY, (Url.dwPasswordLength + 1) * sizeof(TCHAR)))
				== NULL) {
			goto CLEANUP;
		}
		memcpy(authPassword, Url.lpszPassword, 
			Url.dwPasswordLength * sizeof(TCHAR));
	}

	// If we don't have a username or password to authenticate to the web
	// service, bail

	if (!authUserName) {
		EventStr[0] = REGISTRY_KEY;
		EventStr[1] = REGISTRY_AUTHUSER;
		EventStr[2] = REGISTRY_URL;
		EventStr[3] = urlText;
		EventStr[4] = User;
		ReportEvent(
			EventLog,
			EVENTLOG_ERROR_TYPE,
			CAT_CONFIG_ERROR,
			MSG_AUTHUSER_ERROR,
			NULL,
			5,
			0,
			EventStr,
			NULL);
		goto CLEANUP;
	}
	if (!authPassword) {

		EventStr[0] = REGISTRY_KEY;
		EventStr[1] = REGISTRY_AUTHPASSWORD;
		EventStr[2] = REGISTRY_URL;
		EventStr[3] = urlText;
		EventStr[4] = User;
		ReportEvent(
			EventLog,
			EVENTLOG_ERROR_TYPE,
			CAT_CONFIG_ERROR,
			MSG_AUTHUSER_ERROR,
			NULL,
			5,
			0,
			EventStr,
			NULL);
		goto CLEANUP;
	}

	if (!(hInet = InternetOpen(
			TEXT("PwdReset"), 
			INTERNET_OPEN_TYPE_PRECONFIG,
			NULL, 
			NULL,
			0))) {
		EventID = MSG_INTERNETOPEN_FAILED;
		goto CLEANUP;
	}

	wcstombs_s(&passsz, NULL, 0, Pass, _TRUNCATE);

	if ((pass = (char *) HeapAlloc( GetProcessHeap(), 
			HEAP_ZERO_MEMORY, passsz))
			== NULL) {
		goto CLEANUP;
	}
	wcstombs_s(&passsz, pass, passsz, Pass, _TRUNCATE);

	URLEncode(pass, NULL, &sz);

	if ((encodedpass = (char *) HeapAlloc( GetProcessHeap(), 
			HEAP_ZERO_MEMORY, sz))
			== NULL) {
		goto CLEANUP;
	}

	bStatus = URLEncode(pass, encodedpass, &sz);
	SecureZeroMemory( pass, passsz );
	HeapFree(GetProcessHeap(), 0, pass);
	
	if (!bStatus) {
		EventStr[0] = User;
		ReportEvent(
			EventLog,
			EVENTLOG_ERROR_TYPE,
			CAT_RUNTIME_ERROR,
			MSG_URLENCODE_FAILED,
			NULL,
			1,
			0,
			EventStr,
			NULL);
		goto CLEANUP;
	}
		
	// If this gets truncated, that's just too damn bad

	/*
	 * Ensure that the source=ActiveDirectory parameter is sent, because
	 * otherwise it may cause loops.
	 * /

	sprintf_s(postBuffer, sizeof(postBuffer),
		"userid=%d&password=%s&source=ActiveDirectory",
		UserID, encodedpass);
	postBuffer[sizeof(postBuffer)] = '\0';

	SecureZeroMemory(pass, sz * sizeof(char));
	HeapFree(GetProcessHeap(), 0, encodedpass);

	if (!(hSession = InternetConnect(
			hInet,
			HostName,
			Url.nPort,
			NULL,
			NULL,
			INTERNET_SERVICE_HTTP,
			0,
			0
			))) {
	
		EventID = MSG_INTERNETCONNECT_FAILED;
		goto CLEANUP;
	}

	// InternetSetOption doesn't seem to do the right thing the first time,
	// so we're just going to build the Authorization header manually. Vv.

	if ((FullAuthHdr = (char *) HeapAlloc( GetProcessHeap(), HEAP_ZERO_MEMORY,
		strlen(authhdr) + 2 * (lstrlen(authUserName) + lstrlen(authPassword))
		  + 1)) == NULL) {
		goto CLEANUP;
	}
	CopyMemory( FullAuthHdr, authhdr, strlen(authhdr));
	tmpptr = FullAuthHdr + strlen(authhdr);
	sz = lstrlen(authUserName);
	wcstombs_s(&setsz, tmpptr, (2 * sz) + 1, authUserName, _TRUNCATE);

	tmpptr[sz] = ':';
	setsz = lstrlen(authPassword);
	wcstombs_s(&setsz, tmpptr + sz + 1, (2 * setsz) + 1, authPassword,
		_TRUNCATE);

	if ((encodedAuthHdr = base64_encode(tmpptr, strlen(tmpptr))) == NULL) {
		goto CLEANUP;
	}
	CopyMemory( tmpptr, encodedAuthHdr, strlen(encodedAuthHdr));
	SecureZeroMemory( encodedAuthHdr, strlen(encodedAuthHdr));
	free(encodedAuthHdr );

	if (!(hRequest = HttpOpenRequest (
			hSession,
			TEXT("POST"),									// Method
			Url.lpszUrlPath,						// Object name
			HTTP_VERSION,							// Version
			TEXT(""),										// Referrer
			NULL,									// Accept types
			INTERNET_FLAG_SECURE|
			INTERNET_FLAG_KEEP_CONNECTION|
			INTERNET_FLAG_NO_CACHE_WRITE|
			INTERNET_FLAG_NO_AUTH,
													// Flags
			0										// Context
			))) {
		EventID = MSG_HTTPOPENREQUEST_FAILED;
		goto CLEANUP;
	}

	HttpAddRequestHeadersA (
		hRequest,
		FullAuthHdr,
		(DWORD) strlen(FullAuthHdr),
		HTTP_ADDREQ_FLAG_ADD
		);

	if (!(HttpSendRequest(
			hRequest, 
			hdrs, 
			(DWORD) lstrlen(hdrs), 
			postBuffer, 
			(DWORD) strlen(postBuffer)))) {
		EventID = MSG_HTTPSENDREQUEST_FAILED;
		goto CLEANUP;
	}

	statusSize = sizeof(status);
	HttpQueryInfo(
		hRequest,
		HTTP_QUERY_FLAG_NUMBER|HTTP_QUERY_STATUS_CODE,
		&status,
		&statusSize,
		NULL);

	if (status != 200) {

		statusSize = (DWORD) sizeof(postBuffer);
		HttpQueryInfo(
			hRequest,
			HTTP_QUERY_STATUS_TEXT,
			&postBuffer,
			&statusSize,
			NULL);

		// If we didn't get a success, bail

		EventStr[0] = User;
		EventStr[1] = (LPCTSTR) postBuffer;
		ReportEvent(
			EventLog,
			EVENTLOG_ERROR_TYPE,
			CAT_CONNECTION_ERROR,
			MSG_BAD_STATUS,
			NULL,
			2,
			0,
			EventStr,
			NULL);
		goto CLEANUP;
	}

	if (!InternetReadFile(
			hRequest,
			postBuffer,
			(DWORD) sizeof(postBuffer),
			&statusSize)) {
		EventID = MSG_INTERNETREADFILE_FAILED;
		goto CLEANUP;
	}
	if (statusSize == 0) {
		EventStr[0] = User;
		EventStr[1] = HostName;
		
		ReportEvent(
			EventLog,
			EVENTLOG_ERROR_TYPE,
			CAT_CONNECTION_ERROR,
			MSG_NO_STATUS_RETURNED,
			NULL,
			2,
			0,
			EventStr,
			NULL);
		goto CLEANUP;
	}

	// Should be null-terminated, but just in case
	postBuffer[statusSize] = '\0';

	if (strstr(postBuffer, "Success") == NULL) {

		if (sizeof(TCHAR) > 1) {
			mbstowcs_s(&setsz, NULL, 0, postBuffer, _TRUNCATE);

			if ((errorBuffer = (TCHAR *) HeapAlloc( GetProcessHeap(), 
					HEAP_ZERO_MEMORY, setsz))
					== NULL) {
				goto CLEANUP;
			}
			mbstowcs_s(&setsz, errorBuffer, setsz, postBuffer,
				_TRUNCATE);

			EventStr[0] = User;
			EventStr[1] = errorBuffer;
			ReportEvent(
				EventLog,
				EVENTLOG_AUDIT_FAILURE,
				CAT_BAD_PASSWORD,
				MSG_PASSWORD_REJECTED,
				NULL,
				2,
				0,
				EventStr,
				NULL);
			HeapFree(GetProcessHeap(), 0, encodedpass);
		} else {
			EventStr[0] = User;
			EventStr[1] = (LPCTSTR)postBuffer;
			ReportEvent(
				EventLog,
				EVENTLOG_AUDIT_FAILURE,
				CAT_BAD_PASSWORD,
				MSG_PASSWORD_REJECTED,
				NULL,
				2,
				0,
				EventStr,
				NULL);
		}
		goto CLEANUP;
	}
	
	EventStr[0] = User;
	ReportEvent(
		EventLog,
		EVENTLOG_AUDIT_SUCCESS,
		CAT_NORMAL_PROCESSING,
		MSG_PWCHANGE_SUCCESS,
		NULL,
		1,
		0,
		EventStr,
		NULL);
	bSuccessful = TRUE;
	
CLEANUP:
	if (EventID) {
		SysError = GetLastError();
		FormatMessage(
			FORMAT_MESSAGE_ALLOCATE_BUFFER |
			FORMAT_MESSAGE_FROM_HMODULE,
			GetModuleHandle(TEXT("wininet.dll")),
			SysError,
			0,
			(LPTSTR) &SysErrorStr,
			0, NULL);
		SysError = GetLastError();
		EventStr[0] = User;
		EventStr[1] = (LPCTSTR) SysErrorStr;
		ReportEvent(
			EventLog,
			EVENTLOG_ERROR_TYPE,
			CAT_CONNECTION_ERROR,
			EventID,
			NULL,
			2,
			0,
			EventStr,
			NULL);
		LocalFree(SysErrorStr);
	}
	
	DeregisterEventSource(EventLog);

	if ( hKey != NULL) {
		RegCloseKey(hKey);
	}
	if ( FullAuthHdr != NULL ) {
		SecureZeroMemory( FullAuthHdr, strlen(FullAuthHdr));
		HeapFree( GetProcessHeap(), 0, FullAuthHdr );
	}
	if ( authUserName != NULL ) {
		SecureZeroMemory( authUserName, lstrlen(authUserName) * sizeof(TCHAR));
		HeapFree( GetProcessHeap(), 0, authUserName );
	}
	if ( authPassword != NULL ) {
		SecureZeroMemory( authPassword, lstrlen(authPassword) * sizeof(TCHAR));
		HeapFree( GetProcessHeap(), 0, authPassword );
	}
	if ( HostName != NULL ) {
		SecureZeroMemory( HostName, lstrlen(HostName) * sizeof(TCHAR));
		HeapFree( GetProcessHeap(), 0, HostName );
	}
	if ( urlText != NULL ) {
		SecureZeroMemory( urlText, lstrlen(urlText) * sizeof(TCHAR));
		HeapFree( GetProcessHeap(), 0, urlText );
	}
	if ( hRequest != NULL) {
		InternetCloseHandle(hRequest);
	}
	if ( hSession != NULL) {
		InternetCloseHandle(hSession);
	}
	if ( hInet != NULL ) {
		InternetCloseHandle(hInet);
	}
	
	if ( User != NULL ) {
		// securely zero out our data copies so they leave no traces
		SecureZeroMemory( User, UserName->Length + sizeof( WCHAR ) );
		// free the memory
		HeapFree( GetProcessHeap(), 0, User );
	}

	if ( Pass != NULL ) {
		SecureZeroMemory( Pass, Password->Length + sizeof( WCHAR ) );
		HeapFree( GetProcessHeap(), 0, Pass );
	}

	
	return( bSuccessful );
}

void __init_base64() {
	int i;  
	
	memset(__base64_decode_table, 0xff, 256);
	
	for (i=0; i < 26; i++) {
		__base64_encode_table[i] = 'A' + i;
		__base64_decode_table['A' + i] = i;
		__base64_encode_table[26 + i] = 'a' + i;
		__base64_decode_table['a' + i] = 26 + i;
	}  
	for (i=0; i <= 9; i++) {
		__base64_encode_table[52 + i] = '0' + i; 
		__base64_decode_table['0' + i] = 52 + i;
	}
	__base64_encode_table[62] = '+';
	__base64_decode_table['+'] = 62;
	__base64_encode_table[63] = '/';
	__base64_decode_table['/'] = 63;
	__base64_decode_table['='] = 0;
		
	__base64_initted = 1; 
} 

char *base64_encode(char *in, unsigned int size) {
	unsigned char *buf, *out;
	unsigned int i;

	if (!__base64_initted) {
		__init_base64();
	}

	if (!in || (size < 1)) {
		return (char *)NULL;
	}

	/* Allocate memory for base64 string.  This will always be no more than
	 * ((size / 3  + 1) * 4) + 3
	 */

	if ((buf = (unsigned char *)malloc(((size / 3 + 1) * 4) + 3)) == NULL) {
		return (char *)NULL;
	}
	out = buf;
	for (i = 0; i < size; i+=3) {
		out[0] = __base64_encode_table[in[0] >> 2];
		out[1] = __base64_encode_table[((in[0] & 3) << 4) |
			(((i + 1 < size) ? in[1] : 0) >> 4)];
		out[2] = (i + 1 < size) ? __base64_encode_table[
				((in[1] & 0xf) << 2) | (((i + 2 < size) ? in[2] : 0) >> 6)] : '=';
		out[3] = (i + 2 < size) ? __base64_encode_table[in[2] & 0x3f] : '=';
		in += 3;
		out += 4;
	}

	*out = '\0';

	return (char *)buf;

}

BOOL AddEventSource(
	LPTSTR pszSrcName,	// event source name
	LPTSTR pszMsgDLL,	// path for message DLL
	DWORD  dwNum)		// number of categories
{
	HKEY hk; 
	DWORD dwData, dwDisp; 
	TCHAR szBuf[MAX_PATH]; 
	TCHAR szSysDir[MAX_PATH]; 

	// Create the event source as a subkey of the log. 

	if (FAILED(StringCbPrintfEx(szBuf, sizeof(szBuf), NULL, NULL, 
			STRSAFE_NULL_ON_FAILURE, 
			TEXT("SYSTEM\\CurrentControlSet\\Services\\EventLog\\Application\\%s"),
			pszSrcName))) {
		return FALSE;
	}

	if (RegCreateKeyEx(HKEY_LOCAL_MACHINE, szBuf, 
			 0, NULL, REG_OPTION_NON_VOLATILE,
			 KEY_WRITE, NULL, &hk, &dwDisp)) 
	{
		return FALSE;
	}

	GetSystemDirectory(szSysDir, sizeof(szSysDir));
	StringCbPrintfEx(szBuf, sizeof(szBuf), NULL, NULL, 
		STRSAFE_NULL_ON_FAILURE, TEXT("%s\\%s"), szSysDir, pszMsgDLL); 
	
	// Set the name of the message file. 
 
	if (RegSetValueEx(hk,		  		// subkey handle 
		TEXT("EventMessageFile"),				// value name 
		0,								// must be zero 
		REG_EXPAND_SZ,					// value type 
		(LPBYTE) szBuf,			  		// pointer to value data 
		(DWORD) (lstrlen(szBuf) + 1) * sizeof(TCHAR)))		// length of value data 
	{
		RegCloseKey(hk); 
		return FALSE;
	}
 
	// Set the supported event types. 
 
	dwData = EVENTLOG_ERROR_TYPE | EVENTLOG_WARNING_TYPE | 
		  EVENTLOG_INFORMATION_TYPE | EVENTLOG_AUDIT_FAILURE |
		  EVENTLOG_AUDIT_SUCCESS; 
 
	if (RegSetValueEx(hk,			// subkey handle 
			  TEXT("TypesSupported"),  	// value name 
			  0,					// must be zero 
			  REG_DWORD,			// value type 
			  (LPBYTE) &dwData,  	// pointer to value data 
			  sizeof(DWORD)))	 	// length of value data 
	{
		RegCloseKey(hk); 
		return FALSE;
	}
 
	// Set the category message file and number of categories.

	if (RegSetValueEx(hk,				  		// subkey handle 
			  TEXT("CategoryMessageFile"),	  		// value name 
			  0,								// must be zero 
			  REG_EXPAND_SZ,				 	// value type 
			  (LPBYTE) szBuf,		  		// pointer to value data 
			  (DWORD) (lstrlen(szBuf)+1) * sizeof(TCHAR)))	// length of value data 
	{
		RegCloseKey(hk); 
		return FALSE;
	}
 
	if (RegSetValueEx(hk,		// subkey handle 
			  TEXT("CategoryCount"),	// value name 
			  0,				// must be zero 
			  REG_DWORD,		// value type 
			  (LPBYTE) &dwNum,	// pointer to value data 
			  sizeof(DWORD)))	// length of value data 
	{
		RegCloseKey(hk); 
		return FALSE;
	}

	RegCloseKey(hk); 
	return TRUE;
}

BOOL URLEncode(
		char	*src,
		char	*dst,
		size_t	*dstsz) {

	/* 
		URLEncode - take a single-byte character string and URL Encode it

		src 	- pointer to the null-termited source string
		dst 	- pointer to a buffer to contain the encoded string.  Can
				  be NULL to only return the size of the resulting string.
		dstsz	- pointer to the size of the buffer.  This variable will
				  contain the actual number of bytes written including the
				  null, or the actual number of bytes needed to store the
				  resultant string and a terminating null if dst is NULL

		Returns TRUE if the string was stored successfully, or if dst is NULL,
		or FALSE if the string was truncated.  The resulting string is always
		null-terminated if dst is non-NULL and dstsz is at least 1.
	*/

	size_t	count = 0;
	BOOL	encode = FALSE;

	/* Get rid of obvious error conditions first.  */

	/* If dstsz is NULL */
	if (dstsz == NULL) {
		return FALSE;
	}

	/* If dst is non-NULL, but its size is invalid */
	if (*dstsz <= 1 && dst == NULL) {
		*dstsz = 0;
		return FALSE;
	}
	
	while (*src) {
		encode = FALSE;
		count++;

		if (*src < 0x1f || *src > 0x7f) {
			encode = TRUE;
		}
		switch (*src) {
			case '$':
			case '&':
			case '+':
			case ',':
			case '/':
			case ':':
			case ';':
			case '=':
			case '?':
			case '@':
			case ' ':
			case '"':
			case '<':
			case '>':
			case '#':
			case '%':
			case '{':
			case '}':
			case '|':
			case '\\':
			case '^':
			case '\'':
			case '~':
			case '[':
			case ']':
			case '`':
				encode = TRUE;
				count += 2;
				break;
			default:
				;
		}
		/* If we're just counting, loop */
		if (dst == NULL) {
			src++;
			continue;
		}
		/* If we don't have room to store at least this character and a null */
		if (count >= *dstsz) {
			*dst = '\0';
			return FALSE;
		}
		if (encode) {
			*dst++ = '%';
			*dst++ = hexchar[(*src >> 4) & 0xf];
			*dst++ = hexchar[*src++ & 0xf];
		} else {
			*dst++ = *src++;
		}
	}
	if (dst) {
		*dst = '\0';
	}
	*dstsz = count + 1;
	return TRUE;
}
