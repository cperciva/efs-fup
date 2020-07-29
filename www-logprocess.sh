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

# Gather portsnap statistics
grep '"portsnap (' /var/log/nginx/access.log.0 > /root/portsnap-access.log
cp /local0/ps-mirror/www/indextimes /root/indextimes
grep 'GET /tp/' /root/portsnap-access.log > /root/portsnap-access-tp.log
perl -e '
	open my $h, "<", "/root/efs-fup/aws-ips";
	chomp(my @ranges = <$h>);
	close $h;
	while (<>) {
		@_ = split / /;
		$ip = $_[0];
		if ($ip =~ /^[0-9.]+$/) {
			@_ = split /\./, $ip;
			$n = $_[0] * 16777216 + $_[1] * 65536 + $_[2] * 256 + $_[3];
			for $r (@ranges) {
				@_ = split / /, $r;
				print if ($_[0] <= $n && $n < $_[1]);
			}
		}
	}' < /root/portsnap-access-tp.log > /root/portsnap-access-tp-aws.log
cat /root/portsnap-access-tp.log |
    cut -f 2,6 -d '"' |
    cut -f 3- -d '/' |
    sed -e 's/-/|/; s/\./|/; s/"/|/' |
    cut -f 1,2,4 -d '|' |
    sort |
    join -t '|' -o 1.2,1.3,2.2 - /local0/ps-mirror/www/indextimes |
    sort |
    join -t '|' -o 1.2,1.3,2.2 - /local0/ps-mirror/www/indextimes |
    sed -E 's/([^|]*)\|(.*)/\2|\1/' |
    sed -E 's/portsnap \([^,]+, (.*)\)/\1/' |
    sort -k3 -t '|' > /root/indexupdates
( cat /root/indexupdates; echo "0|0|0" ) |
    tr '|' ' ' |
    while read A B R; do
	if [ "$R" != "$LR" ]; then
		if ! [ -z "$LR" ]; then
			echo "$T|$LR"
		fi
		T=0
	fi
	TT=$((B - A))
	if [ $TT -gt 2419200 ]; then
		TT=0
	fi
	T=$((T + TT))
	LR="$R"
done > /root/portsnap-usage-by-version
cat /root/portsnap-access-tp-aws.log |
    cut -f 2,6 -d '"' |
    cut -f 3- -d '/' |
    sed -e 's/-/|/; s/\./|/; s/"/|/' |
    cut -f 1,2,4 -d '|' |
    sort |
    join -t '|' -o 1.2,1.3,2.2 - /local0/ps-mirror/www/indextimes |
    sort |
    join -t '|' -o 1.2,1.3,2.2 - /local0/ps-mirror/www/indextimes |
    sed -E 's/([^|]*)\|(.*)/\2|\1/' |
    sed -E 's/portsnap \([^,]+, (.*)\)/\1/' |
    sort -k3 -t '|' > /root/indexupdates-aws
( cat /root/indexupdates-aws; echo "0|0|0" ) |
    tr '|' ' ' |
    while read A B R; do
	if [ "$R" != "$LR" ]; then
		if ! [ -z "$LR" ]; then
			echo "$T|$LR"
		fi
		T=0
	fi
	TT=$((B - A))
	if [ $TT -gt 2419200 ]; then
		TT=0
	fi
	T=$((T + TT))
	LR="$R"
done > /root/portsnap-usage-by-version-aws

echo
echo "Portsnap snapshot fetches:"
grep 'GET /s/' /root/portsnap-access.log | wc -l

echo
echo "Seconds of updates fetched by FreeBSD version:"
cat /root/portsnap-usage-by-version

echo
echo "Seconds of updates fetched by FreeBSD EC2 version:"
cat /root/portsnap-usage-by-version-aws

echo
echo "Total days of updates fetched:"
cat /root/portsnap-usage-by-version |
    tr '|' ' ' |
    while read A R; do
	T=$((T + A))
	expr $T / 86400 || true
    done |
    tail -1
