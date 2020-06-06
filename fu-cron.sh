#!/bin/sh

STIME=`date "+%s"`
sh -e /root/efs-fup/fu-mirror.sh /local0/fu-mirror
ETIME=`date "+%s"`
TTIME=`expr $ETIME - $STIME || true`
if [ $TTIME -lt 60 ]; then
	touch /local0/fu-mirror/www/initialized
else
	echo "FreeBSD Update sync took $TTIME seconds"
fi
