#!/usr/bin/env -S bash -e

PROJECT=$1
RELEASE_VERSION=$2
BRANCH=$3
PUSH_CHANGES=${4:-false}

if [ -z "$PROJECT" ]; then
	echo "ERROR: Project not supplied"
	exit 1
fi
if [ -z "$RELEASE_VERSION" ]; then
	echo "ERROR: Release version argument not supplied"
	exit 1
fi
if [ -z "$BRANCH" ]; then
	echo "Branch not supplied"
	 exit 1
fi

if [ "$PUSH_CHANGES" = true ] ; then
	echo "Pushing changes to the upstream repository."
	# Make sure to use the HEAD:<target> syntax,
	# because the branch may not be checked out (we may be in "detached head" state)
	git push origin HEAD:$BRANCH
fi
if [ "$PUSH_CHANGES" != true ] ; then
	echo "WARNING: Not pushing changes to the upstream repository."
fi
