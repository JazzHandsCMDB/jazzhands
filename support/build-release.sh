#!/bin/sh -e
#
# Copyright (c) 2014-2016, Todd M. Kover
# All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


tarroot=`pwd`

ROOT=..

RELEASEDIR=/tmp/releaseit.$$
mkdir $RELEASEDIR



cat releases | sed 's/#.*$//' | grep '^[a-z]' | sed 's/^ *//' | 
while read dirname pkg ; do
	NAME=`(cd $ROOT/$dirname ; dpkg-parsechangelog | grep ^Source | head | awk '{print $NF}')`
	VERSION=`(cd $ROOT/$dirname ; dpkg-parsechangelog | grep ^Version | head | awk '{print $NF}')`
	rootname=${NAME}-${VERSION}

	spec=`(cd $ROOT/$dirname ; find . -name \*.spec -print |head -1 | sed 's,^\./,,')`

	mkdir $RELEASEDIR/$rootname

	(cd $ROOT ; git archive HEAD:${dirname} --format tar ) | (cd $RELEASEDIR/$rootname ; tar xpf  - )

	if [ ! -z "$pkg" ] ; then
		PKGARG="-e \"s/__PKG__/$PKG\""
		XPKGARG="--pkg $pkg"
	else
		PKGARG=""
		XPKGARG=""
	fi

	( sed < $ROOT/$dirname/$spec \
			$PKGARG \
			-e "s/__NAME__/$NAME/" \
			-e "s/__VERSION__/$VERSION/" ; \
		echo '%changelog' ; \
		./xchangelog $PKGARG --output rpm $ROOT/$dirname/debian/changelog 
	) > $RELEASEDIR/$rootname/$spec
	(cd $RELEASEDIR ; tar zcf $tarroot/${rootname}.tar.gz $rootname )
done

rm -rf $RELEASEDIR/

exit 0

# This is the old way that was done by pulling bits from the spec files.  This
# has been deprecated in favor of using the debian/dpkg bits.
#
#if [ 0 = 0 -a -x /usr/bin/rpm ] ; then
#	dirname=`dirname $input`
#	basename=`basename $input | sed s/.spec//`
#	if [ `expr $input : '.*\.spec'` -eq 0 ] ; then
#		echo 1>&2 $input is not a spec based release.  Unsupported.  DIE.
#		exit 1
#		rootname=$dirname
#	else
#		spec="$input"
#		echo Processing $spec ...
#		rootname=`rpm -q --specfile $ROOT/$spec --queryformat '%{name}-%{version}\n' | head -1`
#fi
