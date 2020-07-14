#!/bin/sh

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

# Update "indextimes"
gunzip < /local0/ps-mirror/www/tl.gz |
    grep ^INDEX |
    awk -F \| ' { print $3 "|" $2 }' |
    sort > /local0/ps-mirror/wrkdir/tl
join -t '|' -v 1 /local0/ps-mirror/www/indextimes /local0/ps-mirror/wrkdir/tl |
    sort - //local0/ps-mirror/wrkdir/tl > /local0/ps-mirror/wrkdir/indextimes.tmp
mv /local0/ps-mirror/wrkdir/indextimes.tmp /local0/ps-mirror/www/indextimes
