#!/bin/sh -e
#
# get a token using approle
#

VAULT_ADDR="http://vault:8200"
export VAULT_ADDR

dir="$1"
shift
tokendest="$1"

if [ "$dir" = "" ] ; then
        echo 2>&1 must specify directory with the secret and role id '(and optional full path to store token'
        exit
fi

if [ "x$tokendest" = "x" ] ; then
	tokendest="$dir/token"
fi


roleid=`cat $dir/roleid`
secretid=`cat $dir/secretid`

token=`vault write auth/approle/login role_id=$roleid secret_id=$secretid -format=json | jq -r .auth.client_token`
echo $token > $tokendest 
