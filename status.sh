#!/bin/sh

# Get current status
CSTATUS=`sysrc -n nginx_enable`

# New status is "YES", unless...
NSTATUS=YES

# Portsnap bits are not synched or more than 2h old
if [ `find /local0/ps-mirror/initialized -mtime -2h 2>/dev/null | wc -l` -ne 1 ]; then
	NSTATUS=NO
fi

# FreeBSD Update bits are not synched or more than 6h old
if [ `find /local0/fu-mirror/initialized -mtime -6h 2>/dev/null | wc -l` -ne 1 ]; then
	NSTATUS=NO
fi

# Do we need to turn things off?
if [ "${NSTATUS}${CSTATUS}" = "NOYES" ]; then
	echo "Mirror is unhealthy"
	/usr/local/etc/rc.d/nginx stop
	sysrc nginx_enable=$NSTATUS
fi

# Do we need to turn things on?
if [ "${NSTATUS}${CSTATUS}" = "YESNO" ]; then
	echo "Mirror is healthy"
	sysrc nginx_enable=$NSTATUS
	/usr/local/etc/rc.d/nginx start
fi
