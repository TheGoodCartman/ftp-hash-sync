#!/bin/bash

set -e
set -o pipefail

log() {
	echo -e "\e[92m---\e[39m $*"
}

warn() {
	echo -e "\e[91m***\e[39m $*" >&2
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

log "Using hash command $hashcmd"
cd "${INPUT_SOURCE}"
find -type f -print0 | xargs -0 "$hashcmd" | sort >"${INPUT_HASHFILE}"

log "Fetching remote hash list"
remotelist=$(mktemp)
log "CWD: $(pwd)"
log "Tmp: $remotelist"
