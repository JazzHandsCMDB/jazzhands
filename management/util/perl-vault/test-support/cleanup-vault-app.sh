#!/bin/sh -e
#
# delete app and secrets related to a test application
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
rodir="$1"
shift
rwdir="$1"

if [ "$app" = "" ] ; then
        echo 2>&1 'must specify application name (and path with role/secert id seaved)'
        exit 1
fi

if [ "$rodir" = "" ] ; then
        echo 2>&1 'must specify application name, path to save creds, and optional access mode'
        exit 1
elif [ -d "$rodir" ] ; then
	VAULT_TOKEN=$token
	export VAULT_TOKEN

	policy=${app}-policy-ro
	role=${app}-policy-ro

	vault delete secret/metadata/${app}/secret || true
	vault policy delete ${policy} || true
	vault delete auth/approle/role/${role} || true

	rm -rf $rodir
else
	echo 2>&1 "No rodir $rodir"
fi

if [ "$rwdir" = "" ] ; then
	true
elif [ -d "$rwdir" ] ; then
	VAULT_TOKEN=$token
	export VAULT_TOKEN

	policy=${app}-policy-rw
	rwle=${app}-policy-rw

	vault delete secret/metadata/${app}/secret || true
	vault policy delete ${policy} || true
	vault delete auth/approle/role/${role} || true

	rm -rf $rwdir
else
	echo 2>&1 "No rwdir $rwdir"
fi




exit 0
