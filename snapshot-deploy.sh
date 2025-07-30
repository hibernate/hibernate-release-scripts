#!/usr/bin/env -S bash -e

WORKSPACE="${WORKSPACE:-'.'}"
SCRIPTS_DIR="$(readlink -f ${BASH_SOURCE[0]} | xargs dirname)"

PROJECT="$1"
VERSION="$2"

if [ -z "$PROJECT" ]; then
	echo "ERROR: Project not supplied"
	exit 1
fi

if [ -z "$VERSION" ]; then
	echo "ERROR: Version not supplied"
	exit 1
fi

if ! [[ $VERSION =~ ^.+-SNAPSHOT$ ]]; then
	echo "ERROR: Supplied Version (${VERSION}) is not a SNAPSHOT"
	exit 1
fi

if [ "$PROJECT" == "search" ] || [ "$PROJECT" == "validator" ] || [ "$PROJECT" == "tools" ] || [ "$PROJECT" == "localcache" ] || [[ $PROJECT =~ ^infra-.+ ]]; then
  ./mvnw -Pci-build -DskipTests clean deploy
elif [ "$PROJECT" == "orm" ] || [ "$PROJECT" == "reactive" ] || [ "$PROJECT" == "models" ]; then
  ./gradlew clean publishAllPublicationsToSnapshotsRepository -x test --no-scan --no-daemon --no-build-cache --stacktrace
else
  echo "ERROR: Unknown project name $PROJECT"
  usage
  exit 1
fi
