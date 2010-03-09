#!/bin/sh
# Copyright (c) 2005-2010, Vonage Holdings Corp.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#
# $Id$
#

PATH=usr/local/bin:/usr/local/sbin:/usr/vendor/bin:/usr/kerberos/bin:/usr/bin:/bin
export PATH

LOCKFILE=/prod/zonegen/run/zonegen.lock

cleanup() {
        cleaning up lockfile after signal
        rm -f $LOCKFILE
}

trap cleanup HUP INT TERM

tty >/dev/null 2>&1 
#
# if we're not a tty, do away with output
#
if [ $? = 1 ] ; then
	exec >/dev/null
	exec 2>/dev/null
fi

list=`find 2>/dev/null $LOCKFILE -mmin +180`
if [ ! -z "$list" ] ; then
	echo 1>&2 removing lockfile $LOCKFILE as three hours has past.
	rm -f $LOCKFILE
fi

umask 022

lockingon=no
if [ -z "$*" ] ; then
	if [ -r $LOCKFILE ] ; then
		echo Locked, Skipping.
		exit 0
	fi
	echo Locking
	lockingon=yes
	touch $LOCKFILE
fi

TMPFILE=/tmp/zonegenzonelist.$$
LIST=/prod/zonegen/etc/nameserver.conf

SRC_ROOT=/prod/zonegen/auto-gen/perserver
DST_ROOT=/prod/dns/auto-gen
RSYNC_RSH=/prod/zonegen/libexec/ssh-wrap

export RSYNC_RSH

KRB5CCNAME=/tmp/krb5cc_zonegen_$$_do_zonegen
export KRB5CCNAME

if [ -x  /prod/zonegen/libexec/generate-zones ] ; then
	echo 1>&2  "Generating Zones (This may take a while)..."
	/prod/zonegen/libexec/generate-zones "$@" >  /dev/null

	if [ -r $LIST ] ; then

		if [ -f /etc/krb5.keytab.zonegen ] ; then
			kinit -k -t /etc/krb5.keytab.zonegen zonegen
		fi
		sed -e 's/#.*//' $LIST | 
		while read ns servers ; do
			if [ "$servers" = "" ] ; then
				servers="$ns"
			fi
			if [ "$ns" != "" ] ; then
				servers=`echo $servers | sed 's/,/ /'`
				for host in $servers ; do
					echo 1>&2  "Processing $host (in $ns) ..."
					rsync </dev/null -rLpt --delete-after $SRC_ROOT/$ns/ ${host}:$DST_ROOT
					$RSYNC_RSH </dev/null >/dev/null $host sh $DST_ROOT/etc/zones-changed.rndc
				done
			fi
		done
	fi
fi

if [ "$lockingon" = "yes" ] ; then
	echo Unlocking
	rm -f $LOCKFILE
fi

kdestroy >/dev/null 2>&1

exit 0
