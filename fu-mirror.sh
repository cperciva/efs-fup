#!/bin/sh

# Branched from:
# $FreeBSD: user/cperciva/freebsd-update-mirror/umirror.sh 339903 2018-10-30 01:39:22Z cperciva $

# Check parameters
TOPDIR=$1
if [ -z "${TOPDIR}" ]; then
	echo "usage: $0 TOPDIR"
	exit 1
fi

# Synthesize parameters used for original umirror.sh script
MASTER=http://update-master.freebsd.org
KEYHASH=706ec1d81ee915193c3aefaa2192e11aa9ba68c08ae93962cdab2510362d1c1f
PRIVDIR=$TOPDIR/privdir/
PUBDIR=$TOPDIR/www/
EXCLUDES=$(dirname $(realpath $0))/excludes

# Sanity-check the key hash
if echo "${KEYHASH}" | grep -qvE "^[0-9a-f]{64}$"; then
	echo "Invalid keyhash value: ${KEYHASH}"
	exit 1
fi

# Make sure the excludes file is readable
if ! [ -r "${EXCLUDES}" ]; then
	echo "Cannot read excludes file: ${EXCLUDES}"
	exit 1
fi

# Create public and private directories if needed
if ! mkdir -p "${PUBDIR}"; then
	echo "Cannot create public directory: ${PUBDIR}"
	exit 1
fi
if ! mkdir -p "${PRIVDIR}"; then
	echo "Cannot create private directory: ${PRIVDIR}"
	exit 1
fi

# Fetch pub.ssl
if ! [ -r "${PRIVDIR}/pub.ssl" ] ||
    ! [ `sha256 -q "${PRIVDIR}/pub.ssl"` = "${KEYHASH}" ]; then
	rm -f "${PRIVDIR}/pub.ssl"
	fetch -o "${PRIVDIR}/pub.ssl" "${MASTER}/pub.ssl" 2>/dev/null
	if ! [ -r "${PRIVDIR}/pub.ssl" ]; then
		echo "Failed to fetch pub.ssl"
		exit 1
	fi
	if ! [ `sha256 -q "${PRIVDIR}/pub.ssl"` = "${KEYHASH}" ]; then
		echo "Hash of pub.ssl does not match keyhash"
		exit 1
	fi
fi

# Fetch latest.ssl
rm -f "${PRIVDIR}/latest.ssl"
fetch -o "${PRIVDIR}/latest.ssl" "${MASTER}/latest.ssl" 2>/dev/null
if ! [ -r "${PRIVDIR}/latest.ssl" ]; then
	echo "Failed to fetch latest.ssl"
	exit 1
fi

# Verify signature on latest.ssl
if ! openssl rsautl -pubin -inkey "${PRIVDIR}/pub.ssl" -verify	\
    < "${PRIVDIR}/latest.ssl" > "${PRIVDIR}/tag" 2>/dev/null; then
	echo "Invalid signature file"
	exit 1
fi
if ! [ `wc -l < "${PRIVDIR}/tag"` = 1 ] ||
    grep -qvE "^[0-9a-f]{64}$" < "${PRIVDIR}/tag"; then
	echo "Invalid signature file"
	exit 1
fi
FLISTHASH=`cat "${PRIVDIR}/tag"`

# Fetch file list
if ! [ -r "${PRIVDIR}/flist" ] ||
   ! [ `sha256 -q "${PRIVDIR}/flist"` = "${FLISTHASH}" ]; then
	rm -f "${PRIVDIR}/flist"
	fetch -o "${PRIVDIR}/flist" "${MASTER}/flist-${FLISTHASH}" 2>/dev/null
	if ! [ -r "${PRIVDIR}/flist" ]; then
		echo "Failed to fetch flist-${FLISTHASH}"
		exit 1
	fi
	if ! [ `sha256 -q "${PRIVDIR}/flist"` = "${FLISTHASH}" ]; then
		echo "Hash of flist-${FLISTHASH} is incorrect"
		exit 1
	fi
fi

# Sanity-check file list
if grep -qvE "^[a-z0-9]+ [0-9a-f]{64} [0-9a-f]{64}$"		\
    < "${PRIVDIR}/flist"; then
	echo "File list is invalid: flist-${FLISTHASH}"
	exit 1
fi

# Handle files
while read ID FHASH FDECHASH; do
	# Have we already handled this file?
	if [ -f "${PRIVDIR}/done-${ID}" ]; then
		continue
	fi

	# Fetch the (encrypted) file
	if ! [ -r "${PRIVDIR}/tar-${ID}" ] ||
	   ! [ `sha256 -q "${PRIVDIR}/tar-${ID}"` = "${FHASH}" ]; then
		rm -f "${PRIVDIR}/tar-${ID}"
		fetch -o "${PRIVDIR}/tar-${ID}" "${MASTER}/tar-${ID}"	\
		    2>/dev/null
		if ! [ -r "${PRIVDIR}/tar-${ID}" ]; then
			echo "Failed to fetch tar-${ID}"
			exit 1
		fi
		if ! [ `sha256 -q "${PRIVDIR}/tar-${ID}"` = "${FHASH}" ]; then
			echo "Hash of tar-${ID} is incorrect"
			exit 1
		fi
		echo "Fetched tar-${ID}"
	fi

	# Fetch the decryption key
	if ! [ -r "${PRIVDIR}/key-${ID}" ]; then
		fetch -o "${PRIVDIR}/key-${ID}" "${MASTER}/key-${ID}"	\
		    2>/dev/null
		if ! [ -r "${PRIVDIR}/key-${ID}" ]; then
			continue
		fi
		echo "Fetched key-${ID}"
	fi

	# Attempt to decrypt the file
	if ! [ -r "${PRIVDIR}/dec-${ID}" ]; then
		if ! openssl enc -aes-256-cbc -d		\
		-pass "file:${PRIVDIR}/key-${ID}" -md md5	\
		    < "${PRIVDIR}/tar-${ID}" > "${PRIVDIR}/dec-${ID}"; then
			echo "Decrypting tar-${ID} failed"
			exit 1
		fi
	fi

	# Does the decrypted file have the right hash?
	if ! [ `sha256 -q "${PRIVDIR}/dec-${ID}"` = "${FDECHASH}" ]; then
		rm "${PRIVDIR}/key-${ID}"
		rm "${PRIVDIR}/dec-${ID}"
		echo "Decrypting tar-${ID} failed"
		exit 1
	fi

	# Extract the bits
	# Use a 4-way parallel extract for large archives to optimize
	# throughput on slow filesystems.
	if [ `stat -f '%z' "${PRIVDIR}/dec-${ID}"` -gt 10000000 ]; then
		# If the tar we downloaded is old, it's likely to contain bits
		# we don't want; generate an archive with files excluded in
		# order to avoid reading unwanted bits 4x over.
		if [ `find "${PRIVDIR}/tar-${ID}" -mtime +365d | wc -l` -eq 1 ]; then
			tar -cf "${PRIVDIR}/dec-${ID}.tmp" -X "${EXCLUDES}" "@${PRIVDIR}/dec-${ID}"
			mv "${PRIVDIR}/dec-${ID}.tmp" "${PRIVDIR}/dec-${ID}"
		fi
		tar -xf "${PRIVDIR}/dec-${ID}" -X "${EXCLUDES}" -C "${PUBDIR}" --include './*/*/*/[0123]*' &
		tar -xf "${PRIVDIR}/dec-${ID}" -X "${EXCLUDES}" -C "${PUBDIR}" --include './*/*/*/[4567]*' &
		tar -xf "${PRIVDIR}/dec-${ID}" -X "${EXCLUDES}" -C "${PUBDIR}" --include './*/*/*/[89ab]*' &
		tar -xf "${PRIVDIR}/dec-${ID}" -X "${EXCLUDES}" -C "${PUBDIR}" --exclude './*/*/*/[0123456789ab]*' &
		wait
	else
		tar -xf "${PRIVDIR}/dec-${ID}" -X "${EXCLUDES}" -C "${PUBDIR}"
	fi

	# Delete files which we no longer need
	rm "${PRIVDIR}/dec-${ID}" "${PRIVDIR}/tar-${ID}" "${PRIVDIR}/key-${ID}"

	# We've done this file.
	touch "${PRIVDIR}/done-${ID}"
done < "${PRIVDIR}/flist"

# Delete excluded directories
while read DIR; do
	if [ -d "${PUBDIR}/${DIR}" ]; then
		rm -r "${PUBDIR}/${DIR}"
	fi
done < "${EXCLUDES}"
