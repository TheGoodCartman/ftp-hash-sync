#!/bin/bash

set -e
set -o pipefail

log() {
	echo -e "\e[92m---\e[39m $*"
}

warn() {
	echo -e "\e[93m***\e[39m $*" >&2
}

err() {
	echo -e "\e[91m!!!\e[39m $*" >&2
}

if [ -z "${INPUT_HASHFILE}" ]; then
	err "Invalid hash file"
	exit 1
fi

case "${INPUT_HASHTYPE}" in
	sha256)
		hashcmd=sha256sum
		;;

	sha512)
		hashcmd=sha512sum
		;;

	md5)
		hashcmd=md5sum
		;;

	*)
		err "Unsupported hash type \"${INPUT_HASHTYPE}\""
		exit 1
esac

log "Hashing files with $hashcmd"

cd "${INPUT_SOURCE}"

# Sort by file name
find -type f -print0 | xargs -0 "$hashcmd" | sort -k 2 >/localhashes

log "Fetching remote hash list"

export LFTP_PASSWORD="${INPUT_PASSWORD}"

if lftp -c "open -u \"${INPUT_USERNAME}\" --env-password \"${INPUT_HOST}\"; get \"${INPUT_DESTINATION}/${INPUT_HASHFILE}\" -o /remotehashesorig"; then
	log "Succeeded"
	sort -k 2 /remotehashesorig >/remotehashes
else
	warn "Could not fetch remote files - assuming file did not exist"
	echo "">/remotehashes
fi

log "Creating sync script"

cat <<EOF >/syncscript
open -u "${INPUT_USERNAME}" --env-password "${INPUT_HOST}"
set passive yes
cd "${INPUT_DESTINATION}"
EOF

# Make directories
find -type d | sed -nr 's|^\./(.*)|mkdir -f "\1"|p' >>/syncscript

# Diff returns non-zero if there are differences - disable error checking for the next line
set +e

# Diff, then remove first 3 lines (with filenames)
diff -U0 /remotehashes /localhashes | tail -n +3 >/hashdiff

# Reenable error checking
set -e

# First RMs
sed -nr 's|^-[^ ]+ +\./(.*)$|rm "\1"|p' /hashdiff >>/syncscript

# The PUTs
sed -nr 's|^\+[^ ]+ +\./(.*)$|put "\1" -o "\1"|p' /hashdiff >>/syncscript

cat <<EOF >>/syncscript
put /localhashes -o "${INPUT_HASHFILE}"
EOF

log "Running script"

cat /syncscript
lftp -f /syncscript

log "Done"
