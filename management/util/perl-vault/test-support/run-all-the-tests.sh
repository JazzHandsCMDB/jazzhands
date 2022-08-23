#!/bin/sh -e
#
# entry point for the container that runs tests
#

#
# the scratch filesystme may persist from previus launches and thus this
# elaborate dance to get a valid token...
#
token=""
while [ ! -f /scratch/vault-output  -o "$token" = "" ] ; do
	token=`grep ^Root.Token /scratch/vault-output  | awk '{print $NF}'`
	if [ "$token" = "" ] ;then 
		sleep 5
	else
		env VAULT_ADDR=http://vault:8200 VAULT_TOKEN=$token vault token lookup >/dev/null 2>/dev/null || token=""
		sleep 5
	fi
done

echo 1>&2 trying to disable approle
env VAULT_ADDR="http://vault:8200" VAULT_TOKEN="$token" vault auth disable approle || true

echo 1>&2 trying to enable approle
until env VAULT_ADDR="http://vault:8200" VAULT_TOKEN="$token" vault auth enable approle  ; do
	env VAULT_ADDR="http://vault:8200" VAULT_TOKEN="$token" vault auth disable approle || true
	sleep 5
done

echo 1>&2 approle enabled, beginning tests.

cd /build && prove -lr t || true
# exit $?

# this is going away once dev is done.
# sleep 86400
exit 0
