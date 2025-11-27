#!/usr/bin/env -S bash -e

function usage() {
  echo "Usage:"
  echo
  echo "  $0 [options] <project> <release_version> <development_version>"
  echo
  echo "    <project>                One of [search,validator,ogm,orm,reactive,tools,hcann,localcache,infra-*]]"
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

function needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --$opt option"; fi; }

#--------------------------------------------
# Option parsing

function exec_or_dry_run() {
  "${@}"
}
PUSH_CHANGES=true
# Default to a well-known CI environment variable
BRANCH="$BRANCH_NAME"
NOTES_FILE="-"

while getopts 'djhb:-:' opt; do
  if [ "$opt" = "-" ]; then
    # long option: reformulate opt and OPTARG
    #     - extract long option name
    opt="${OPTARG%%=*}"
    #     - extract long option argument (may be empty)
    OPTARG="${OPTARG#"$opt"}"
    #     - remove assigning `=`
    OPTARG="${OPTARG#=}"
  fi
  case "$opt" in
  b)
    BRANCH="$OPTARG"
    ;;
  h)
    usage
    exit 0
    ;;
  j)
    USE_JRELEASER_RELEASE=true
    ;;
  d)
    # Dry run
    echo "DRY RUN: will not push/deploy/publish anything."
    PUSH_CHANGES=false
    export JRELEASER_DRY_RUN=true
    function exec_or_dry_run() {
      echo "DRY RUN; would have executed:" "${@}"
    }
    ;;
  notes)
    needs_arg
    NOTES_FILE="$OPTARG"
    echo "Using external notes-file : $notesFile"
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
elif [ "$PROJECT" == "models" ]; then
  echo 'No JIRA project available'
elif [ "$PROJECT" == "localcache" ]; then
  echo 'No JIRA project available'
elif [[ $PROJECT =~ ^infra-.+ ]]; then
  echo 'No JIRA project available'
else
  echo "ERROR: Unknown project name $PROJECT"
  usage
  exit 1
fi

RELEASE_VERSION_BASIS=$(echo "$RELEASE_VERSION" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
NEXT_VERSION_BASIS=$(echo "$DEVELOPMENT_VERSION" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')

if [ "$PUSH_CHANGES" != "true" ]; then
	ADDITIONAL_OPTIONS="-d"
fi

if [ "$USE_JRELEASER_RELEASE" == "true" ]; then
	ADDITIONAL_OPTIONS="${ADDITIONAL_OPTIONS} -j"
fi

bash -xe "$SCRIPTS_DIR/prepare-release.sh" $ADDITIONAL_OPTIONS -b "$BRANCH" -v "$DEVELOPMENT_VERSION" "$PROJECT" "$RELEASE_VERSION"

#bash -xe "$SCRIPTS_DIR/jira-release.sh" $ADDITIONAL_OPTIONS "$JIRA_PROJECT" "$RELEASE_VERSION_BASIS" "$NEXT_VERSION_BASIS"

bash -xe "$SCRIPTS_DIR/publish.sh" --notes="$NOTES_FILE" $ADDITIONAL_OPTIONS "$PROJECT" "$RELEASE_VERSION" "$DEVELOPMENT_VERSION" "$BRANCH"
