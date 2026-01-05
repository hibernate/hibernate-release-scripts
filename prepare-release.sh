#!/usr/bin/env -S bash -e

# Default to a well-known CI environment variable
BRANCH="$BRANCH_NAME"

while getopts 'djv:b:' opt; do
  case "$opt" in
  d)
    DRY_RUN=true
    ;;
  j)
    USE_JRELEASER_RELEASE=true
    ;;
  b)
    BRANCH="$OPTARG"
    ;;
  v)
    DEVELOPMENT_VERSION="$OPTARG"
    ;;
  \?)
    usage
    exit 1
    ;;
  esac
done
shift $((OPTIND - 1))

SCRIPTS_DIR="$(readlink -f ${BASH_SOURCE[0]} | xargs dirname)"

PROJECT=$1
RELEASE_VERSION=$2
INHERITED_VERSION=$3
if [ -n "$3" ]; then
  DEVELOPMENT_VERSION=$3
fi
WORKSPACE=${WORKSPACE:-'.'}

if [ -z "$PROJECT" ]; then
	echo "ERROR: Project not supplied"
	exit 1
fi
if [ -z "$RELEASE_VERSION" ]; then
	echo "ERROR: Release version argument not supplied"
	exit 1
else
	echo "Setting version to '$RELEASE_VERSION'";
fi
if [ "$PROJECT" == "orm" ]; then
  if [ -z "$DEVELOPMENT_VERSION" ]; then
    echo "ERROR: Development version argument not supplied"
    exit 1
  else
    echo "Setting development version to '$DEVELOPMENT_VERSION'";
  fi
fi

if [ -z "$BRANCH" ]; then
  BRANCH="$(git branch --show-current)"
  echo "Inferred release branch: $BRANCH"
fi

echo "Preparing the release ..."

pushd $WORKSPACE

# Set up git so that we can create commits
git config --local user.name "Hibernate CI"
git config --local user.email "ci@hibernate.org"

# Make sure we aren't in a detached state, as otherwise JReleaser may get confused...
git checkout "$BRANCH"
git pull origin "$BRANCH"
# we fetch the tags so that JReleaser can find the "previous" one
git fetch --tags

"$SCRIPTS_DIR/validate-credentials.sh" $PROJECT
if [ -f "$WORKSPACE/README.md" ]; then
  "$SCRIPTS_DIR/update-readme.sh" $PROJECT $RELEASE_VERSION "$WORKSPACE/README.md"
fi
if [ "$PROJECT" == "orm" ] || [ "$PROJECT" == "search" ] || [ "$PROJECT" == "validator" ]; then
  "$SCRIPTS_DIR/update-changelog.sh" $PROJECT $RELEASE_VERSION "$WORKSPACE/changelog.txt"
fi
"$SCRIPTS_DIR/validate-release.sh" $PROJECT $RELEASE_VERSION

"$SCRIPTS_DIR/update-version.sh" -m "[Jenkins release job] Preparing release $RELEASE_VERSION" $PROJECT $RELEASE_VERSION $INHERITED_VERSION

if [ "$PROJECT" == "orm" ] || [ "$PROJECT" == "reactive" ] || [ "$PROJECT" == "models" ]; then
	RELEASE_VERSION_BASIS=$(echo "$RELEASE_VERSION" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
	RELEASE_VERSION_FAMILY=$(echo "$RELEASE_VERSION" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')

	./gradlew clean releasePrepare -x test --no-scan --no-daemon --no-build-cache
else
  	if [ "$PROJECT" == "ogm" ]; then
  		ADDITIONAL_OPTIONS="-DmongodbProvider=external -DskipITs"
  	else
  		ADDITIONAL_OPTIONS=""
  	fi

  	source "$SCRIPTS_DIR/mvn-setup.sh"

  	./mvnw clean deploy \
  		-Pdocbook,documentation-pdf,dist,perf,relocation,release \
  		-DperformRelease=true \
  		-DskipTests=true -Dcheckstyle.skip=true \
  		-Dmaven.compiler.useIncrementalCompilation=false \
  		-Ddevelocity.enabled=false \
  		-Dscan=false -Dno-build-cache \
  		-Dgradle.cache.remote.enabled=false -Dgradle.cache.local.enabled=false \
  		-Ddevelocity.cache.remote.enabled=false -Ddevelocity.cache.local.enabled=false \
  	 	$ADDITIONAL_OPTIONS
fi

# Let's check that there are any artifacts in the [staging-dir]/maven and some documentation in [staging-dir]/documentation
# See the "jreleaser/configuration" directory for the staging directories used by different projects:
STAGING_ROOT_DIRECTORY=""
if [ "$PROJECT" == "reactive" ] || [ "$PROJECT" == "models" ]; then
    STAGING_ROOT_DIRECTORY="build/staging-deploy"
else
    STAGING_ROOT_DIRECTORY="target/staging-deploy"
fi

if [ -z $(find "$STAGING_ROOT_DIRECTORY/maven" -mindepth 1 -print -quit) ]; then
  echo "$PROJECT main artifacts are missing from the staging directory. Aborting the release!"
  exit 1
fi

if [ "$PROJECT" == "orm" ] || [ "$PROJECT" == "reactive" ] || [ "$PROJECT" == "validator" ] || [ "$PROJECT" == "search" ]; then
  if [ -z $(find "$STAGING_ROOT_DIRECTORY/documentation" -mindepth 1 -print -quit) ]; then
    echo "$PROJECT documentation is missing from the staging directory. Aborting the release!"
    exit 1
  fi
fi

popd

echo "Release ready: version is updated to $RELEASE_VERSION"
