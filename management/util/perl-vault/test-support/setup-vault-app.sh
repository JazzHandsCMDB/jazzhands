#!/bin/sh -e
#
# setup an application in vault for approle and stashes the role/secretids.
#

token=""
while [ ! -f /scratch/vault-output	-o "$token" = "" ] ; do
	token=`grep ^Root.Token /scratch/vault-output	| awk '{print $NF}'`
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
				echo 2>&1 'must specify application name (and path to save role/secret id, and optional access mode)'
				exit 1
fi

if [ "$rodir" = "" ] ; then
				echo 2>&1 'must specify application name and path to save role/secret id, and optional access mode'
				exit 1
elif [ ! -d "$rodir" ] ; then
	mkdir -p "$rodir"
fi

if [ x"$rwdir" != x ] ; then
	if [ ! -d "$rwdir" ] ; then
		mkdir -p "$rwdir"
	fi
fi

VAULT_TOKEN=$token
export VAULT_TOKEN

###########################################################################
#
# setup ro policy

if [ -d "$rodir" ] ; then
	policy=${app}-policy-ro
	role=${app}-policy-ro
	vault policy delete ${policy} || true
	vault delete auth/approle/role/${role} || true

	(

	vault policy write $policy -	<<EOF
		path "secret/data/${app}/*" {
			capabilities = ["read"]
		}
		path "secret/metadata/${app}/*" {
			capabilities = ["list"]
		}
EOF
	vault write auth/approle/role/$role \
		secret_id_ttl=3h \
		token_ttl=3h \
		token_max_ttl=24h \
		secret_id_num_uses=80 \
		token_num_uses=0 \
		token_policies=$policy

	) >/dev/null

	roleid=`vault read -field=role_id auth/approle/role/${role}/role-id`
	secretid=`vault write -f -field=secret_id auth/approle/role/${role}/secret-id`
	echo $roleid > "${rodir}/roleid"
	echo $secretid > "${rodir}/secretid"
fi

###########################################################################
#
# setup rw policy
#

if [ -d "$rwdir" ] ; then
	policy=${app}-policy-rw
	role=${app}-policy-rw
	vault policy delete ${policy} || true
	vault delete auth/approle/role/${role} || true

	(

	vault policy write $policy -	<<EOF
		path "secret/data/${app}/*" {
			capabilities = ["create","delete","read","update"]
		}
		path "secret/metadata/${app}/*" {
			capabilities = ["delete", "list"]
		}
EOF

	vault write auth/approle/role/$role \
		secret_id_ttl=3h \
		token_ttl=3h \
		token_max_ttl=24h \
		secret_id_num_uses=80 \
		token_num_uses=0 \
		token_policies=$policy

	) >/dev/null

	roleid=`vault read -field=role_id auth/approle/role/${role}/role-id`
	secretid=`vault write -f -field=secret_id auth/approle/role/${role}/secret-id`
	echo $roleid > "${rwdir}/roleid"
	echo $secretid > "${rwdir}/secretid"
fi

#
# end policies
#
###########################################################################

exit 0
