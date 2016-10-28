#!/bin/sh

# Copyright (c) 2016, Todd M. Kover
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
# $Id$
#

#
# This takes a whitespace (tab, ideally) delimited file from stdin 
# where the first column is a list of zones to refresh and then runs rndc
# reload on them.   Note that if there are views, this won't work...
#
#

PATH=usr/local/bin:/usr/local/sbin:/usr/vendor/bin:/usr/kerberos/bin:/usr/bin:/bin
export PATH

tmpfile=/tmp/inzones.$$

sed 's/#.*//' > $tmpfile

if [ -x /usr/libexec/jazzhands/zonesgen/ingest-zones.local.replace ] ; then
	cat $tmpfile | /usr/libexec/jazzhands/zonesgen/ingest-zones.local.replace "$@"
	code=$?
	rm -f $tmpfile
	exit $code
elif [ -x /usr/libexec/jazzhands/zonesgen/ingest-zones.pre ] ; then
	cat $tmpfile | /usr/libexec/jazzhands/zonesgen/ingest-zones.pre "$@"
fi

#
# figure out if there were actually any zones; if so, run rndc reconfig.
# then keep a list of zones and reload them.
#
# note that this default ignores views, which will cause problems.  If views
# are used, then one of the above commands needs to be used
#
# Note that only the first argument is used such that in the future it may be
# possible to add additonal lines to the list of zones for view support or
# some such and any replacement or other script should be mindful of this
# possibility. 
#
reconfig=0
zones=""
cat $tmpfile |
	cat $tmpfile | while read zone ; do
		if [ -z "$zone" ] ; then
			continue
		fi
		reconfig=1
		$zones="$zones $zone"
	done
done

if [ "$reconfig" = 1 ] ;then
	rndc reconfig
fi

for zone in $zone ; do
		rndc reload $zone
done


exit 0
if [ -x /usr/libexec/jazzhands/zonesgen/ingest-zones.post ] ; then
	cat $tmpfile | /usr/libexec/jazzhands/zonesgen/ingest-zones.post "$@"
fi

rm -f $tmpfile

exit 0
