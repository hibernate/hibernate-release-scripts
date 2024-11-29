#!/usr/bin/env -S bash -e

function usage() {
  echo "Usage:"
  echo
  echo "  $0 [options] <project> <release_version> <development_version>"
  echo
  echo "    <project>                One of [search,validator,ogm,orm,reactive,tools,hcann,infra-*]]"
  echo "    <release_version>        The version to release (e.g. 6.0.1.Final)"
  echo "    <development_version>    The new version after the release (e.g. 6.0.2-SNAPSHOT)"
  echo
  echo "  Options"
  echo
  echo "    -h            Show this help and exit."
  echo "    -b <branch>   The branch to push to (e.g. main or 6.0)."
  echo "                  Defaults to the name of the current branch."
  echo "    -d            Dry run; do not push, deploy or publish anything."
}

#--------------------------------------------
# Option parsing

function exec_or_dry_run() {
  "${@}"
}
PUSH_CHANGES=true
# Default to a well-known CI environment variable
BRANCH="$BRANCH_NAME"

while getopts 'dhb:' opt; do
  case "$opt" in
  b)
    BRANCH="$OPTARG"
    ;;
  h)
    usage
    exit 0
    ;;
  d)
    # Dry run
    echo "DRY RUN: will not push/deploy/publish anything."
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

WORKSPACE="${WORKSPACE:-'.'}"
SCRIPTS_DIR="$(readlink -f ${BASH_SOURCE[0]} | xargs dirname)"
PROJECT="$1"
if [ -z "$PROJECT" ]; then
  echo "ERROR: Project not supplied"
  usage
  exit 1
fi
shift
RELEASE_VERSION="$1"
if [ -z "$RELEASE_VERSION" ]; then
  echo "ERROR: Release version not supplied"
  usage
  exit 1
fi
shift
DEVELOPMENT_VERSION="$1"
if [ -z "$DEVELOPMENT_VERSION" ]; then
  echo "ERROR: Development version not supplied"
  usage
  exit 1
fi
shift

#--------------------------------------------
# Defaults / computed

if [ -z "$BRANCH" ]; then
  BRANCH="$(git branch --show-current)"
  echo "Inferred release branch: $BRANCH"
fi
if (( $# > 0 )); then
  echo "ERROR: Extra arguments:" "${@}"
  usage
  exit 1
fi

RELEASE_VERSION_FAMILY=$(echo "$RELEASE_VERSION" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')

if [ "$RELEASE_VERSION" = "$RELEASE_VERSION_FAMILY" ]; then
  echo "ERROR: Could not extract family from release version $RELEASE_VERSION"
  usage
  exit 1
else
  echo "Inferred release version family: $RELEASE_VERSION_FAMILY"
fi

if [ "$PROJECT" == "search" ]; then
  JIRA_PROJECT="HSEARCH"
elif [ "$PROJECT" == "validator" ]; then
  JIRA_PROJECT="HV"
elif [ "$PROJECT" == "ogm" ]; then
  JIRA_PROJECT="OGM"
elif [ "$PROJECT" == "orm" ]; then
  JIRA_PROJECT="HHH"
elif [ "$PROJECT" == "reactive" ]; then
  JIRA_PROJECT="HREACT"
elif [ "$PROJECT" == "tools" ]; then
  JIRA_PROJECT="HBX"
elif [[ $PROJECT =~ ^infra-.+ ]]; then
  echo 'No JIRA project available'
else
  echo "ERROR: Unknown project name $PROJECT"
  usage
  exit 1
fi

RELEASE_VERSION_BASIS=$(echo "$RELEASE_VERSION" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
NEXT_VERSION_BASIS=$(echo "$DEVELOPMENT_VERSION" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')

#--------------------------------------------
# Environment variables

if [ -z "$RELEASE_GPG_HOMEDIR" ]; then
  echo "ERROR: environment variable RELEASE_GPG_HOMEDIR is not set"
  exit 1
fi
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

if [ -e "$RELEASE_GPG_HOMEDIR" ]; then
  echo "ERROR: temporary gpg homedir '$RELEASE_GPG_HOMEDIR' must not exist"
  exit 1
fi
mkdir -p -m 700 "$RELEASE_GPG_HOMEDIR"
export GNUPGHOME="$RELEASE_GPG_HOMEDIR"
IMPORTED_KEY="$(gpg_import "$RELEASE_GPG_PRIVATE_KEY_PATH")"
if [ -z "$IMPORTED_KEY" ]; then
  echo "Failed to import GPG key"
  exit 1
fi

if [ "$PUSH_CHANGES" != "true" ]; then
	ADDITIONAL_OPTIONS="-d"
fi

bash -xe "$SCRIPTS_DIR/prepare-release.sh" "$PROJECT" "$RELEASE_VERSION"

#bash -xe "$SCRIPTS_DIR/jira-release.sh" $ADDITIONAL_OPTIONS "$JIRA_PROJECT" "$RELEASE_VERSION_BASIS" "$NEXT_VERSION_BASIS"

bash -xe "$SCRIPTS_DIR/publish.sh" $ADDITIONAL_OPTIONS "$PROJECT" "$RELEASE_VERSION" "$DEVELOPMENT_VERSION" "$BRANCH"
