#!/bin/sh

LANG=C
cd /local0/ps-mirror/wrkdir

STIME=`date "+%s"`
sh -e /root/efs-fup/ps-mirror.sh portsnap-master.freebsd.org /local0/ps-mirror/www
ETIME=`date "+%s"`
TTIME=`expr $ETIME - $STIME || true`
if [ $TTIME -lt 60 ]; then
	touch /local0/ps-mirror/initialized
else
	echo "Portsnap sync took $TTIME seconds"
fi
