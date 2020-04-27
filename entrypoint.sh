#!/bin/bash -e

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
		log_error "Unsupported hash type ${INPUT_HASHTYPE}"
		exit 1
esac
