#!/bin/sh -e
#
# This replaces a token in a file with one with other parameters but has the
# same policy.   This pretty much only exists to fake a low ttl to test auto-
# renewal code
#

VAULT_ADDR="http://vault:8200"
export VAULT_ADDR

roottoken=""
while [ ! -f /scratch/vault-output      -o "$roottoken" = "" ] ; do
        roottoken=`grep ^Root.Token /scratch/vault-output   | awk '{print $NF}'`
        [ "$roottoken" = "" ] && sleep 5
done


tokenfn="$1"
shift

if [ "$tokenfn" = "" ] ; then
        echo 2>&1 must specify path to token
        exit
fi

token=`cat $tokenfn`

policy=`env VAULT_TOKEN=$token vault token lookup -format json | jq -r .data.policies[1] `

newtoken=`VAULT_TOKEN=$roottoken vault token create -policy $policy "$@" -format json | jq -r .auth.client_token`
echo $newtoken > $tokenfn
