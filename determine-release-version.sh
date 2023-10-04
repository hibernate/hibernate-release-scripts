#!/usr/bin/env -S bash -e

SCRIPTS_DIR="$(readlink -f ${BASH_SOURCE[0]} | xargs dirname)"

CURRENT_VERSION=$1
WORKSPACE=${WORKSPACE:-'.'}

if [ -z "$CURRENT_VERSION" ]; then
	echo "ERROR: Current version not supplied"
	exit 1
fi

RELEASE_VERSION=$(echo "$CURRENT_VERSION" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
echo "$RELEASE_VERSION.Final"
