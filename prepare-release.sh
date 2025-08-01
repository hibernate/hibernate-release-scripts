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

if [ "$PROJECT" == "orm" ] || [ "$PROJECT" == "reactive" ] || [ "$PROJECT" == "models" ]; then
	RELEASE_VERSION_BASIS=$(echo "$RELEASE_VERSION" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
	RELEASE_VERSION_FAMILY=$(echo "$RELEASE_VERSION" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')
	"$SCRIPTS_DIR/validate-release.sh" $PROJECT $RELEASE_VERSION

	EXTRA_ARGS=""
	if [ -f "./jreleaser.yml" ] || [ "$USE_JRELEASER_RELEASE" == "true" ]; then
		EXTRA_ARGS+=" publishAllPublicationsToStagingRepository"
	fi

	# set release version
	# update changelog from JIRA
	# tags the version
	# changes the version to the provided development version
	./gradlew clean releasePrepare -x test --no-scan --no-daemon --no-build-cache \
		-PreleaseVersion=$RELEASE_VERSION -PdevelopmentVersion=$DEVELOPMENT_VERSION \
		-PgitRemote=origin -PgitBranch=$BRANCH $EXTRA_ARGS
else
	if [[ "$PROJECT" != "tools" && "$PROJECT" != "hcann" && "$PROJECT" != "localcache" && ! $PROJECT =~ ^infra-.+ ]]; then
		# These projects do not have a distribution bundle archive,
		#    hence we do not want to check the sourceforge availability as we will not be uploading anything.
		# There is also no version in the readme and no changelog file.
		"$SCRIPTS_DIR/check-sourceforge-availability.sh"
		"$SCRIPTS_DIR/update-readme.sh" $PROJECT $RELEASE_VERSION "$WORKSPACE/README.md"
		"$SCRIPTS_DIR/update-changelog.sh" $PROJECT $RELEASE_VERSION "$WORKSPACE/changelog.txt"
	fi
	"$SCRIPTS_DIR/validate-release.sh" $PROJECT $RELEASE_VERSION
	"$SCRIPTS_DIR/update-version.sh" $PROJECT $RELEASE_VERSION $INHERITED_VERSION
	"$SCRIPTS_DIR/create-tag.sh" $PROJECT $RELEASE_VERSION
fi

popd

echo "Release ready: version is updated to $RELEASE_VERSION"
