#!/usr/bin/env -S bash -e

function usage() {
  echo "Usage:"
  echo
  echo "  $0 [options] <project> <release_version> <development_version>"
  echo
  echo "    <project>                One of [search,validator,ogm,orm]"
  echo "    <release_version>        The version to release (e.g. 6.0.1)"
  echo "    <development_version>    The new version after the release (e.g. 6.0.2-SNAPSHOT)"
  echo
  echo "  Options"
  echo
  echo "    -h            Show this help and exit."
  echo "    -d            Dry run; do not push, deploy or publish anything."
}

function needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --$opt option"; fi; }

#--------------------------------------------
# Option parsing

function exec_or_dry_run() {
  "${@}"
}
PUSH_CHANGES=true

notesFile=""
while getopts 'dh-:' opt; do
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
  *)
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

if [ -z "$PROJECT" ]; then
	echo "ERROR: Project not supplied"
	usage
	exit 1
fi
if [ -z "$RELEASE_VERSION" ]; then
	echo "ERROR: Release version argument not supplied"
	usage
	exit 1
fi
if [ -z "$DEVELOPMENT_VERSION" ]; then
	echo "ERROR: Development version argument not supplied"
	exit 1
fi

if [ "$PROJECT" == "search" ]; then
  JIRA_KEY="HSEARCH"
  STRIPPED_SUFFIX_FOR_JIRA=""
elif [ "$PROJECT" == "validator" ]; then
  JIRA_KEY="HV"
  STRIPPED_SUFFIX_FOR_JIRA=""
elif [ "$PROJECT" == "ogm" ]; then
  JIRA_KEY="OGM"
  STRIPPED_SUFFIX_FOR_JIRA=""
elif [ "$PROJECT" == "orm" ]; then
  JIRA_KEY="HHH"
  STRIPPED_SUFFIX_FOR_JIRA=".Final"
elif [ "$PROJECT" == "tools" ]; then
  JIRA_KEY="HBX"
  STRIPPED_SUFFIX_FOR_JIRA=""
else
  echo "ERROR: Unknown project name $PROJECT"
  usage
  exit 1
fi

DEVELOPMENT_VERSION=${DEVELOPMENT_VERSION%-SNAPSHOT}
if [ -n "$STRIPPED_SUFFIX_FOR_JIRA" ]; then
  RELEASE_VERSION=${RELEASE_VERSION%$STRIPPED_SUFFIX_FOR_JIRA}
  DEVELOPMENT_VERSION=${DEVELOPMENT_VERSION%$STRIPPED_SUFFIX_FOR_JIRA}
fi

if [ "$PUSH_CHANGES" == 'true' ] && [ -z "$JIRA_WEBHOOK_SECRET" ]; then
	echo "ERROR: Environment variable JIRA_WEBHOOK_SECRET must not be empty"
	exit 1
fi

exec_or_dry_run curl -L --fail-with-body -X POST \
	-H "X-Automation-Webhook-Token: $JIRA_WEBHOOK_SECRET" \
	-H 'Content-Type: application/json' \
	-d '{"data":{"projectKey": "'${JIRA_KEY}'", "releaseVersion":"'${RELEASE_VERSION}'","nextVersion":"'${DEVELOPMENT_VERSION}'"}}' \
	https://api-private.atlassian.com/automation/webhooks/jira/a/1fec2f23-3f8e-486e-b8fe-85159188d8c8/01970d1d-d1fa-756b-98f0-53c1d7cfd676
