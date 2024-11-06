#!/usr/bin/env -S bash -e

PROJECT=$1
RELEASE_VERSION=$2
WORKSPACE=${WORKSPACE:-'.'}
CHANGELOG=$WORKSPACE/changelog.txt
README=$WORKSPACE/README.md

pushd ${WORKSPACE}

if [ -z "$PROJECT" ]; then
	echo "ERROR: Project not supplied"
	exit 1
fi
if [ -z "$RELEASE_VERSION" ]; then
	echo "ERROR: Release version argument not supplied"
	exit 1
fi

if [ "$PROJECT" == "search" ]; then
  STRIPPED_SUFFIX_FOR_TAG=""
elif [ "$PROJECT" == "validator" ]; then
  STRIPPED_SUFFIX_FOR_TAG=""
elif [[ "$PROJECT" =~ ^infra-.+ ]]; then
  STRIPPED_SUFFIX_FOR_TAG=""
elif [ "$PROJECT" == "ogm" ]; then
  STRIPPED_SUFFIX_FOR_TAG=""
elif [ "$PROJECT" == "orm" ]; then
  STRIPPED_SUFFIX_FOR_TAG=".Final"
elif [ "$PROJECT" == "reactive" ]; then
  STRIPPED_SUFFIX_FOR_TAG=".Final"
elif [ "$PROJECT" == "hcann" ]; then
  STRIPPED_SUFFIX_FOR_TAG=""
else
  echo "ERROR: Unknown project name $PROJECT"
  exit 1
fi


RELEASE_VERSION_BASIS=$(echo "$RELEASE_VERSION" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
RELEASE_SUFFIX=$(echo "$RELEASE_VERSION" | sed -E 's/^[0-9]+\.[0-9]+\.[0-9]+(.*)/\1/')

if [ -n "$STRIPPED_SUFFIX_FOR_TAG" -a "$RELEASE_SUFFIX" == "$STRIPPED_SUFFIX_FOR_TAG" ]; then
  TAG_NAME=$RELEASE_VERSION_BASIS
else
  TAG_NAME=$RELEASE_VERSION
fi

git fetch origin $TAG_NAME || true

if [ `git tag -l | grep $TAG_NAME` ]
then
	echo "ERROR: tag '$TAG_NAME' already exists, aborting. If you really want to release this version, delete the tag in the workspace first."
	exit 1
else
	echo "SUCCESS: tag '$TAG_NAME' does not exist"
fi

# ORM does this as part of its prepare Gradle task
if [ "$PROJECT" != "orm" ] && [ "$PROJECT" != "reactive" ]; then
	# Only check README updates if it's actually possible that it contains things to update
	if grep -Eq "^\*?Version: .*\*?$|<version>" $README
	then
		if grep -q "$RELEASE_VERSION" $README
		then
			echo "SUCCESS: $README looks updated"
		else
			echo "ERROR: $README has not been updated"
			exit 1
		fi
	fi

	# Only check the changelog updates if the changelog file actually exists:
	if [ -f $CHANGELOG ]; then
		if grep -q "$RELEASE_VERSION" $CHANGELOG ;
		then
			echo "SUCCESS: $CHANGELOG looks updated"
		else
			echo "ERROR: $CHANGELOG has not been updated"
			exit 1
		fi
	fi
fi

popd
