#!/bin/sh -e

base="`dirname $0`"
here="`cd $base && pwd`"

TARROOT=${TARROOT:=${here}}

if [ "x$TARBALL" = "x" ] ; then
	TARBALL=$1
fi

FQTARBALL="$TARROOT/$TARBALL"

if [ ! -r "$FQTARBALL" ] ; then
	echo 1>&2 no tarball found
	exit 1
fi

if [ ! -r "$FQTARBALL" ] ; then
	echo 1>&2 $FQTARBALL does not exist
fi
spec=`tar -tf $FQTARBALL | grep spec | head`
(cd /tmp ; tar xpf $FQTARBALL $spec)

if [ -x /usr/bin/yum-builddep ] ;then
	 yum-builddep -y /tmp/$spec
elif [ -x /usr/bin/zypper ] ; then
	pkgs=`rpmspec -q --buildrequires /tmp/$spec`
	[ ! -z "$pkgs" ] && zypper --non-interactive install -y $pkgs
fi
exec rpmbuild -ta $FQTARBALL

