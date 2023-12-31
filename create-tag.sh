#!/usr/bin/env -S bash -e

PROJECT=$1
RELEASE_VERSION=$2
WORKSPACE=${WORKSPACE:-'.'}

pushd ${WORKSPACE}

if [ -z "$PROJECT" ]; then
	echo "ERROR: Project not supplied"
	exit 1
fi
if [ -z "$RELEASE_VERSION" ]; then
	echo "ERROR: Release version argument not supplied"
	exit 1
fi

git commit -a -m "[Jenkins release job] Preparing release $RELEASE_VERSION"
git tag -a -m "Release $RELEASE_VERSION" "$RELEASE_VERSION"

popd
