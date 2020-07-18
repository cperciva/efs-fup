#!/bin/sh

# Fetch json from Amazon
fetch -q https://ip-ranges.amazonaws.com/ip-ranges.json

# We want all AWS IP addresses...
jq -r '.prefixes[].ip_prefix' < ip-ranges.json |
    tr './' ' ' |
    perl -ne '
	@_ = split / /;
	$s = $_[0] * 16777216 + $_[1] * 65536 + $_[2] * 256 + $_[3];
	$e = $s + 2 ** (32 - $_[4]);
	print "$s $e\n"' |
    sort -n > ip-ranges

# ... but with overlapping and duplicate ranges collapsed
echo "4294967295 4294967295" >> ip-ranges
LE=0
while read S E; do
	if [ $LE -eq 0 ]; then
		LS=$S
		LE=$E
	elif [ $LE -ge $S ]; then
		if [ $E -gt $LE ]; then
			LE=$E
		fi
	else
		echo "$LS $LE"
		LS=$S
		LE=$E
	fi
done < ip-ranges > aws-ips

# Clean up
rm ip-ranges.json ip-ranges
