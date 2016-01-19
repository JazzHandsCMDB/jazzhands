#!/bin/bash
#
# chkconfig: 2345 90 80
# dbsyncer
# description: Start database syncer processes
#
# $Revision: 1.0 $

# Source function library.
[ -r /etc/init.d/functions ] && . /etc/init.d/functions

PATH=/usr/local/sbin:/usr/sbin:/sbin:/usr/local/bin:/bin:/usr/bin
PROG=/usr//libexec/jazzhands/dbsyncer/table-sync

PIDROOT=/var/run/dbsyncer.
DBSYNCERDIR=/etc/jazzhands/dbsyncer/

PROCESS_DBSYNCER_ARGS=""
SHORTPROG=`basename $PROG`

# Source networking configuration.
[ -f /etc/sysconfig/${SHORTPROG} ] &&  . /etc/sysconfig/${SHORTPROG}
[ -f /etc/default/${SHORTPROG} ] &&  . /etc/default/${SHORTPROG}

SHORTPROG_ARGS="$PROCESS_DBSYNCER_ARGS"

RETVAL=0

[ -z "${DBSYNCERDIR}" -o ! -d "${DBSYNCERDIR}" ]  && exit 0
[ -z "`ls ${DBSYNCERDIR}/*.json 2>/dev/null`" ] && exit 0

start() {
    running=0
    started=0
    echo -n $"Starting ${SHORTPROG}: "
    ALL_RETVAL=0
    (cd ${DBSYNCERDIR} && ls -1 *.json) | while read json ; do
        root=`echo $json | sed 's/.json$//'`
        PIDFILE="${PIDROOT}$root".pid
	pid=`head -1 ${PIDFILE}`
        if [ -s "$PIDFILE" -a -e /proc/$pid ] ; then
            running=`expr $running + 1`
            continue;
	fi

	echo starting $json
	$PROG --config "$DBSYNCERDIR/$json" ${SHORTPROG_ARGS}
	RETVAL=$?
        if [ -z "$ALL_RETVAL" -o $RETVAL -gt 0 ] ; then
            ALL_RETVAL=$RETVAL
        fi
	sleep 1
	pgrep -f "$PROG.*$root" > $PIDFILE
        started=`expr $started + 1`
    done

    if [ "$running" -gt 0 -a "$started" -gt 0 ] ; then
        echo -n $"some run, some not"
        echo $"some run, some not"
        echo
        return $ALL_RETVAL
    elif [ "$running" -gt 0 -a "$started" -eq 0 ] ; then
		echo -n $"already running.";
		#echo $"already running.";
		echo
		return 1
    elif [ "$running" -eq 0 -a "$started" -eq 0 ] ; then
		echo -n $"failed.";
		#echo $"failed.";
		echo
		return 1
    fi

    [ $ALL_RETVAL -eq 0 ] && echo -n "Started ${SHORTPROG}: "
    echo
    return $ALL_RETVAL
}

stop() {
	echo -n $"Stopping ${SHORTPROG}: "
    stopped=0
    ALL_RETVAL=0
    (cd ${DBSYNCERDIR} && ls -1 *.json) | while read json ; do
        root=`echo $json | sed 's/.json$//'`
        PIDFILE="${PIDROOT}$root".pid
	    if [ -f $PIDFILE ]; then
		    PID=`cat $PIDFILE`
		    if [ "$PID" ]; then
			    kill $PID >/dev/null 2>&1
		    fi
	    fi
	    RETVAL=$?
        if [ -z "$ALL_RETVAL" -o $RETVAL -gt 0 ] ; then
            ALL_RETVAL=$RETVAL
        fi
	[ $RETVAL -eq 0 ] && rm -f $PIDFILE
        stopped=`expr $stopped + 1`
    done

    [ $ALL_RETVAL -eq 0 ] && echo "Stopped ${SHORTPROG}: "
    echo
    return $ALL_RETVAL
}

restart() {
	stop
	start
}

# See how we were called.
case "$1" in
  start)
		start
		;;
  startdebug)
		start debug
		;;
  startnodaemon)
		start nodaemon
		;;
  stop)
		stop
		;;
  restart)
		restart
		;;
  status)
		status $PROG
		RETVAL=$?
		;;
  *)
		echo $"Usage: $0 {start|startdebug|startnodaemon|stop|restart|status}"
		exit 1
		;;
esac

exit $RETVAL

