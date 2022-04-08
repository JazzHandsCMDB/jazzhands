#!/bin/sh -e
#
# revoke a token
#

VAULT_ADDR="http://vault:8200"
export VAULT_ADDR

dir="$1"
shift
tokendest="$1"

if [ "$dir" = "" ] ; then
        echo 2>&1 must specify directory with the secret and role id, '(and optional full path to token)'
        exit
fi

if [ "x$tokendest" = "x" ] ; then
	tokendest="$dir/token"
fi


roleid=`cat $dir/roleid`
secretid=`cat $dir/secretid`

if [ -r "$tokendest" ] ; then
	token=`cat $tokendest`
	VAULT_TOKEN="$token" vault token revoke -self >/dev/null
	rm -f $tokendest
else
	echo 1>&2 No Token file.  Fail.
	exit 1
fi

exit 0
