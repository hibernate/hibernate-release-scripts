#!/usr/bin/env -S bash -e

SCRIPTS_DIR="$(readlink -f ${BASH_SOURCE[0]} | xargs dirname)"

RELEASE_VERSION=$1
WORKSPACE=${WORKSPACE:-'.'}

if [ -z "$RELEASE_VERSION" ]; then
	echo "ERROR: Release version not supplied"
	exit 1
fi

RELEASE_VERSION_FAMILY=$(echo "$RELEASE_VERSION" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')
if echo "$RELEASE_VERSION" | grep -q -P '^[0-9]+\.[0-9]+\.0\.(?!Final$).*'; then
	# Alpha/Beta/CR release: next snapshot keeps the same version numbers
	echo "${RELEASE_VERSION_FAMILY}.0-SNAPSHOT"
else
	NEXT_MINOR=$(echo "$RELEASE_VERSION" | sed -E 's/^[0-9]+\.[0-9]+\.([0-9]+).*/\1/' | awk '{print $0+1}')
	echo "${RELEASE_VERSION_FAMILY}.${NEXT_MINOR}-SNAPSHOT"
fi
