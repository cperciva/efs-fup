#!/bin/sh

echo "Paths:"
cat /var/log/nginx/access.log.0 |
    cut -f 7 -d ' ' |
    cut -f 1-2 -d / |
    sort |
    uniq -c

echo
echo "User-Agents:"
cat /var/log/nginx/access.log.0 |
    cut -f 6 -d '"' |
    sort |
    uniq -c

grep '"portsnap (' /var/log/nginx/access.log.0 > /root/portsnap-access.log

echo
echo "Portsnap latest.ssl user-agents:"
grep 'GET /latest.ssl' /root/portsnap-access.log |
    cut -f 6 -d '"' |
    sort |
    uniq -c

echo
echo "Snapshot fetches:"
grep 'GET /s/' /root/portsnap-access.log | wc -l

echo
echo "Text patches:"
grep 'GET /tp/' /root/portsnap-access.log |
    cut -f 7 -d ' ' |
    cut -f 3 -d '/' |
    sort |
    uniq -c
