#!/bin/sh -e

base="`dirname $0`"
here="`cd $base && pwd`"

TARROOT=${TARROOT:=${here}}
DEBOUT=${DEBOUT:=${here}/deb}

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

# _sigh_  18.04 does not require it and that's the next LTS
if [ `lsb_release -sr` = '16.04' ] ; then
	sign=""
else
	siogn="--no-sign"
fi

mkdir /tmp/build.$$ && cd /tmp/build.$$
tar axpf $FQTARBALL
cd * && mk-build-deps --install --tool='apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends --yes' && dpkg-buildpackage $sign -tc

exec cp -p /tmp/build.$$/*.deb ${DEBOUT}
