#!/usr/bin/env -S bash -e

function usage() {
  echo "Usage:"
  echo
  echo "  $0 [options] <project> <release_version> <development_version> <branch>"
  echo
  echo "    <project>                One of [search,validator,ogm,orm,reactive,tools,hcann,infra-*]"
  echo "    <release_version>        The version to release (e.g. 6.0.1.Final)"
  echo "    <development_version>    The new version after the release (e.g. 6.0.2-SNAPSHOT)"
  echo "    <branch>                 The branch we want to release"
  echo
  echo "  Options"
  echo
  echo "    -h            Show this help and exit."
  echo "    -d            Dry run; do not push, deploy or publish anything."
}

#--------------------------------------------
# Option parsing

function exec_or_dry_run() {
  "${@}"
}
PUSH_CHANGES=true
DRY_RUN=false

while getopts 'dhb:' opt; do
  case "$opt" in
  h)
    usage
    exit 0
    ;;
  d)
    # Dry run
    echo "DRY RUN: will not push/deploy/publish anything."
    DRY_RUN=true
    PUSH_CHANGES=false
    function exec_or_dry_run() {
      echo "DRY RUN; would have executed:" "${@}"
    }
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
DEVELOPMENT_VERSION=$3
BRANCH=$4
WORKSPACE=${WORKSPACE:-'.'}

pushd ${WORKSPACE}

if [ -z "$PROJECT" ]; then
	echo "ERROR: Project not supplied"
	exit 1
fi

if [ -z "$RELEASE_VERSION" ]; then
	echo "ERROR: Release version not supplied"
	exit 1
fi

if [ -z "$DEVELOPMENT_VERSION" ]; then
	echo "ERROR: Development version not supplied"
	exit 1
fi

#--------------------------------------------
# Environment variables

if [ -z "$RELEASE_GPG_PRIVATE_KEY_PATH" ]; then
  echo "ERROR: environment variable RELEASE_GPG_PRIVATE_KEY_PATH is not set"
  exit 1
fi

#--------------------------------------------
# GPG

function gpg_import() {
	local privateKeyPath="$1"
	shift
	local keyId
	keyId=$(gpg "${@}" --batch --import "$privateKeyPath" 2>&1 | tee >(cat 1>&2) | grep 'key.*: secret key imported' | sed -E 's/.*key ([^:]+):.*/\1/')
	# output the fingerprint of the imported key
	gpg "${@}" --list-secret-keys --with-colon "$keyId" | sed -E '2!d;s/.*:([^:]+):$/\1/'
}

function gpg_delete() {
	local fingerprint="$1"
	shift
	gpg "${@}" --batch --yes --delete-secret-keys "$fingerprint"
}

#--------------------------------------------
# Cleanup on exit

function cleanup() {
  if [ -n "$IMPORTED_KEY" ]; then
    echo "Deleting imported GPG private key..."
    gpg_delete "$IMPORTED_KEY" || true
  fi
  if [ -d "$RELEASE_GPG_HOMEDIR" ]; then
    echo "Cleaning up GPG homedir..."
    rm -rf "$RELEASE_GPG_HOMEDIR" || true
    echo "Clearing GPG agent..."
    gpg-connect-agent reloadagent /bye || true
  fi
}

trap "cleanup" EXIT

#--------------------------------------------
# Actual script

# keep the RELEASE_GPG_HOMEDIR just for the sake of the old release jobs,
# if those relied on this env variable:
export RELEASE_GPG_HOMEDIR="$SCRIPTS_DIR/.gpg"
#we probably can remove the following env variable once all releases are using JReleaser:
export GNUPGHOME="$RELEASE_GPG_HOMEDIR"
# this env variable is used by JReleaser to find the keys to sing things:
export JRELEASER_GPG_HOMEDIR="$RELEASE_GPG_HOMEDIR"

mkdir -p -m 700 "$RELEASE_GPG_HOMEDIR"
IMPORTED_KEY="$(gpg_import "$RELEASE_GPG_PRIVATE_KEY_PATH")"
if [ -z "$IMPORTED_KEY" ]; then
  echo "Failed to import GPG key"
  exit 1
fi

RELEASE_VERSION_FAMILY=$(echo "$RELEASE_VERSION" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')

if [ "$PROJECT" == "orm" ] || [ "$PROJECT" == "reactive" ] || [ "$PROJECT" == "models" ]; then
	git config user.email ci@hibernate.org
	git config user.name Hibernate-CI

  EXTRA_ARGS=""
	if [ "$DRY_RUN" == "true" ]; then
	  EXTRA_ARGS=" --dry-run"
	fi

	if [ -f "./jreleaser.yml" ]; then
		# JReleaser-based build
		source "$SCRIPTS_DIR/jreleaser-setup.sh"
		# Execute a JReleaser command such as 'full-release'
		$SCRIPTS_DIR/jreleaser/bin/jreleaser full-release -Djreleaser.project.version="$RELEASE_VERSION"
	else
	 EXTRA_ARGS+=" closeAndReleaseSonatypeStagingRepository"
	fi

	./gradlew releasePerform -x test \
  				--no-scan --no-daemon --no-build-cache --stacktrace $EXTRA_ARGS \
  				-PreleaseVersion=$RELEASE_VERSION -PdevelopmentVersion=$DEVELOPMENT_VERSION \
  				-PdocPublishBranch=production -PgitRemote=origin -PgitBranch=$BRANCH
else
	bash -xe "$SCRIPTS_DIR/deploy.sh" "$PROJECT"
	if [[ "$PROJECT" != "tools" && "$PROJECT" != "hcann" && ! $PROJECT =~ ^infra-.+ ]]; then
		exec_or_dry_run bash -xe "$SCRIPTS_DIR/upload-distribution.sh" "$PROJECT" "$RELEASE_VERSION"
		exec_or_dry_run bash -xe "$SCRIPTS_DIR/upload-documentation.sh" "$PROJECT" "$RELEASE_VERSION" "$RELEASE_VERSION_FAMILY"
	fi

	bash -xe "$SCRIPTS_DIR/update-version.sh" "$PROJECT" "$DEVELOPMENT_VERSION"
	bash -xe "$SCRIPTS_DIR/push-upstream.sh" "$PROJECT" "$RELEASE_VERSION" "$BRANCH" "$PUSH_CHANGES"
fi

popd
