#!/bin/sh -e
#
# purge a secret from vault 
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
        echo 2>&1 'must specify application name (and path to secret)'
        exit
fi

if [ "$secret" = "" ] ; then
        echo 2>&1 'must specify secret name and path to secret.'
        exit
fi

VAULT_TOKEN=$token
export VAULT_TOKEN

vault delete secret/metadata/${app}/${secret} 

exit 0
