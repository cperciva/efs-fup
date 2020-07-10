#!/bin/sh

cat /var/log/nginx/access.log.0 |
    cut -f 7 -d ' ' |
    cut -f 1-2 -d / |
    sort |
    uniq -c
