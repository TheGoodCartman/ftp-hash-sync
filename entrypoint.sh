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

autoconfirm=yes
case "${INPUT_PROTOCOL}" in
	ftp)
		if [ ! -z "${INPUT_HOSTKEY}" ]; then
			err "Unexpected host public key in FTP mode"
			exit 1
		fi

		if [ ! -z "${INPUT_CLIENTKEY}" ]; then
			err "Unexpected client private key in FTP mode"
			exit 1
		fi

		;;

	sftp)
		[ -d ~/.ssh/ ] || mkdir -p ~/.ssh/

		if [ -z "${INPUT_HOSTKEY}" ]; then
			warn "Not checking host SSH key"
		else
			log "Configuring host SSH key"
			autoconfirm=no
			echo "${INPUT_HOST} ${INPUT_HOSTKEY}" >>~/.ssh/known_hosts
			# Hash key, or else the SSH command ignores it
			cat ~/.ssh/known_hosts
			ssh-keygen -H -f ~/.ssh/known_hosts
			cat ~/.ssh/known_hosts
		fi

		if [ ! -z "${INPUT_CLIENTKEY}" ]; then
			log "Configuring client SSH key"
			echo "${INPUT_CLIENTKEY}" >>~/.ssh/github
		fi

		;;

	*)
		err "Invalid protocol \"${INPUT_PROTOCOL}\""
		exit 1
esac

log "Hashing files with $hashcmd"

cd "${INPUT_SOURCE}"

# Sort by file name
find -type f -print0 | xargs -0 "$hashcmd" | sort -k 2 >/localhashes

log "Fetching remote hash list"

export LFTP_PASSWORD="${INPUT_PASSWORD}"
if [ -z "${LFTP_PASSWORD}" ]; then
	# Also works as placeholder for LFTP when using SFTP with public key authentication
	export LFTP_PASSWORD=anonymous
fi

connect_boilerplate=$(cat <<EOF
set net:timeout "${INPUT_TIMEOUT}"
set net:max-retries "${INPUT_RETRIES}"
set sftp:auto-confirm ${autoconfirm}
set ftp:passive-mode yes
open -u "${INPUT_USERNAME}" --env-password "${INPUT_PROTOCOL}://${INPUT_HOST}"
EOF
)

if lftp -c "${connect_boilerplate}; get \"${INPUT_DESTINATION}/${INPUT_HASHFILE}\" -o /remotehashesorig"; then
	log "Succeeded"
	sort -k 2 /remotehashesorig >/remotehashes
else
	warn "Could not fetch remote files - assuming file did not exist"
	echo "">/remotehashes
fi

log "Creating sync script"

cat <<EOF >/syncscript
${connect_boilerplate}
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
