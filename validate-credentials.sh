#!/usr/bin/env -S bash -e

PROJECT=$1
WORKSPACE=${WORKSPACE:-'.'}

pushd ${WORKSPACE}

if [ -z "$PROJECT" ]; then
	echo "ERROR: Project not supplied"
	exit 1
fi

# TODO: do we actually want to do this ???

# GRADLE_PUBLISH_KEY` / `GRADLE_PUBLISH_SECRET
#if [ "$PROJECT" == "orm" ] || [ "$PROJECT" == "tools" ]; then
#  if [ -z "$GRADLE_PUBLISH_KEY" ]; then
#  	echo "ERROR: Project not supplied"
#  	exit 1
#  fi
#fi

popd
