#!/bin/sh -e
#
# Copyright (c) 2023, Todd M. Kover
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

DEBUG=""
# DEBUG="-ti --entrypoint=/bin/bash"

ERRORLOG=/tmp/$$.err.$$

UBUNTU="16.04 18.04 20.04 22.04"
# if one release is to be tested
UBUNTU="22.04"

exec 3>${ERRORLOG}

tarroot=`pwd`

docker build -f Dockerfile.opensuse -t jhsusetest:15 .
docker build -f Dockerfile.fedora -t jhfedoratest:latest .
for v in $UBUNTU ; do
	docker build -f Dockerfile.ubuntu \
		--build-arg ubuntuv=$v -t jhubuntutest:$v .
done

RELEASEDIR=/tmp/jazzhands$$
mkdir $RELEASEDIR

[ ! -d rpm ] && mkdir rpm
[ ! -d suse ] && mkdir suse
[ ! -d deb ] && mkdir deb

problems=""

LIST=""
if [ ! -z "$*" ] ; then
        for i in $* ; do
                LIST="$@"
        done
else
        LIST="*.tar.gz"
fi

for i in $LIST ; do
	if [ 0 = 0 ] ; then
		for v in $UBUNTU ; do
			docker run --rm -v `pwd`/build-one-deb.sh:/build-one-deb \
				-v `pwd`/deb:/deb -v `pwd`:/tarball \
				-e TARROOT=/tarball -e DEBOUT=/deb \
				-e TARBALL=$i \
				${DEBUG} jhubuntutest:$v  || echo 1>&3 ${i}:ubuntu$v
		done
	fi

	if [ 0 = 0 ] ; then
		docker run --rm -v `pwd`/build-one-rpm.sh:/build-one-rpm \
			-v `pwd`/rpm:/root/rpmbuild/RPMS \
			-v `pwd`:/tarball -e TARROOT=/tarball \
			-e TARBALL=$i ${DEBUG}  \
			jhfedoratest:latest  || echo 1>&3 ${i}:fedora
	fi

	if [ 1 = 1 ] ; then
		docker run --rm -v `pwd`/build-one-rpm.sh:/build-one-rpm \
			-v `pwd`/suse:/usr/src/packages/RPMS/ \
			-v `pwd`:/tarball -e TARROOT=/tarball \
			-e TARBALL=$i ${DEBUG}  \
			jhsusetest:15  || echo 1>&3 ${i}:suse
	fi

done

echo ++ Packages in $RELEASEDIR
echo ++ Problems:
for i in `cat $ERRORLOG` ; do echo $i ; done
