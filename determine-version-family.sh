#!/usr/bin/env -S bash -e

SCRIPTS_DIR="$(readlink -f ${BASH_SOURCE[0]} | xargs dirname)"

RELEASE_VERSION=$1
WORKSPACE=${WORKSPACE:-'.'}

if [ -z "$RELEASE_VERSION" ]; then
	echo "ERROR: Release version not supplied"
	exit 1
fi

echo "$RELEASE_VERSION" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/'
