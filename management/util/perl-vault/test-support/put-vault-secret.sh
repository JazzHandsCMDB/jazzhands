#!/bin/sh -e
#
# put a secret in vault
#
#

token=""
while [ ! -f /scratch/vault-output  -o "$token" = "" ] ; do
	token=`grep ^Root.Token /scratch/vault-output  | awk '{print $NF}'`
	[ "$token" = "" ] && sleep 5
done

VAULT_ADDR="http://vault:8200"
export VAULT_ADDR 

app="$1"
shift
secret="$1"
shift

if [ "$app" = "" ] ; then
        echo 2>&1 must specify application name '(and secret path and some key value pairs)'
        exit 1
fi

if [ "$secret" = "" ] ; then
        echo 2>&1 'must specify application name, secret path (and some key value pairs)'
        exit 1
fi

if [ "x$1" = "x" ] ; then
        echo 2>&1 must specify some key values to set
        exit 1
fi

VAULT_TOKEN=$token
export VAULT_TOKEN

vault kv put secret/${app}/${secret} $@

exit 0
