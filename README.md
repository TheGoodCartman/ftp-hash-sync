GitHub Action - FTP hash sync
=============================

This GitHub action employs file hashing to synchronize with a remote FTP server.

It works by calculating a hash list of all the files on the input directory, then diffing it with the previous hash list available on the remote server, and uploading only the changed files.

Usage
-----

You can see a fully automated Jekyll build setup on the repository for my website, at [socram8888/orca.pet](https://github.com/socram8888/orca.pet/blob/master/.github/workflows/main.yml).

Example for GitHub Actions:

```yml
on: push
name: Publish Website
jobs:
	publish
	  - name: Publish
		uses: socram8888/ftp-hash-sync@v1
		with:
			host: ftp.example.com
			username: exampleuser
			password: ${{ secrets.FTP_PASSWORD }}
			destination: htdocs
```

Arguments
---------

| Argument    | Required | Example         | Default       | Description                                                                    |
|-------------|----------|-----------------|---------------|--------------------------------------------------------------------------------|
| host        |   Yes    | ftp.example.com | _unset_       | FTP host                                                                       |
| username    |   Yes    | marcos          | _unset_       | FTP username                                                                   |
| password    |   Yes    | Patata1234!     | _unset_       | FTP password. Don't put it here in plain text, use your repositories' secrets! |
| source      |    No    | website/        | ./            | Source folder. For Jekyll, for example, it would be _site/                     |
| destination |    No    | htdocs/         | ./            | Destination folder, such as htdocs for Apache.                                 |
| hashfile    |    No    | sha512          | sha256        | Any of "sha256", "sha512" or "md5".                                            |
| hashtype    |    No    | checksums       | hashes.sha256 | File name for the hash list, relative to the destination folder.               |

Caveats
-------

Currently the script always create all the folders needed for uploading the files, and will not remove the old structure even if the folders are empty.

It uses LFTP behind the scenes, so it should also work for SFTP and FTPS, but it is completely untested.
