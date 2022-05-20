#!/bin/sh -e
#
# check of a vault token is valid
#

VAULT_ADDR="http://vault:8200"
export VAULT_ADDR

dir="$1"
shift
tokendest="$1"

if [ "$dir" = "" ] ; then
        echo 2>&1 'must specify directory with token and optional full path.'
        exit 1
fi

if [ "x$tokendest" = "x" ] ; then
	tokendest="$dir/token"
fi


if [ -r $dir/token ] ; then
	VAULT_TOKEN=`cat $tokendest` vault token lookup 2>/dev/null
	exit $?
fi

exit 1
