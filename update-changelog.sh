#!/usr/bin/env -S bash -e

########################################################################################################################
# The purpose of this tool is to update the changelog.txt using JIRA's REST API to get the required information
########################################################################################################################

PROJECT=$1
RELEASE_VERSION=$2
CHANGELOG=$3

if [ -z "$PROJECT" ]; then
	echo "ERROR: Project argument not supplied"
	exit 1
fi
if [ -z "$RELEASE_VERSION" ]; then
	echo "ERROR: Release version argument not supplied"
	exit 1
fi
if [ -z "$CHANGELOG" ]; then
	echo "ERROR: changelog path not supplied"
	exit 1
fi
if ! [ -w "$CHANGELOG" ]; then
  echo "ERROR: '$CHANGELOG' is not a valid file"
  exit 1
fi

case "$PROJECT" in
  'validator')
    JIRA_KEY="HV"
    ;;
  'search')
    JIRA_KEY="HSEARCH"
    ;;
  'orm')
      JIRA_KEY="HHH"
      ;;
  'ogm')
    JIRA_KEY="OGM"
    ;;
  *)
    echo "ERROR: Unknown project: $PROJECT"
    exit 1
    ;;
esac

STRIPPED_SUFFIX_FOR_TAG=""
if [ "$PROJECT" == "orm" ] || [ "$PROJECT" == "reactive" ]; then
  STRIPPED_SUFFIX_FOR_TAG=".Final"
fi

RELEASE_VERSION_FAMILY=$(echo "$RELEASE_VERSION" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')
RELEASE_VERSION_BASIS=$(echo "$RELEASE_VERSION" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
RELEASE_SUFFIX=$(echo "$RELEASE_VERSION" | sed -E 's/^[0-9]+\.[0-9]+\.[0-9]+(.*)/\1/')

JIRA_FIX_VERSION_LABEL=""
if [ -n "$STRIPPED_SUFFIX_FOR_TAG" -a "$RELEASE_SUFFIX" == "$STRIPPED_SUFFIX_FOR_TAG" ]; then
  JIRA_FIX_VERSION_LABEL=$RELEASE_VERSION_BASIS
else
  JIRA_FIX_VERSION_LABEL=$RELEASE_VERSION
fi

########################################################################################################################
# Fetches the JIRA version information.
# We are dealing with something like this
#
# ...,
# {
#     "self": "https://hibernate.atlassian.net/rest/api/latest/version/18754",
#     "id": "18754",
#     "description": "Bugfixes for MongoDB, Neo4j and CouchDB backends",
#     "name": "4.1.2.Final",
#     "archived": false,
#     "released": true,
#     "releaseDate": "2015-02-27",
#     "userReleaseDate": "27/Feb/2015",
#     "projectId": 10160
# },
# ...
function jira_version() {
  # REST URL used to retrieve all release versions of the project - https://docs.atlassian.com/jira/REST/latest/#d2e4023
  jira_versions_url="https://hibernate.atlassian.net/rest/api/latest/project/${JIRA_KEY}/versions"
  curl "$jira_versions_url" | jq ".[] | select(.name | . == \"${JIRA_FIX_VERSION_LABEL}\")"
}

#######################################################################################################################
# Lists issues from JIRA as JSON
function list_jira_issues() {
  local next_token=""
  if [[ -n "$2" ]]; then
      next_token="&nextPageToken=$2"
  fi
  # REST URL used for getting all issues of given release - see https://docs.atlassian.com/jira/REST/latest/#d2e2450
  jira_issues_url="https://hibernate.atlassian.net/rest/api/3/search/jql/?jql=project%20%3D%20${JIRA_KEY}%20AND%20fixVersion%20%3D%20${JIRA_FIX_VERSION_LABEL}${1}%20ORDER%20BY%20issuetype%20ASC&fields=issuetype,summary&maxResults=200${token_param}"

  curl "$jira_issues_url"
}

#######################################################################################################################
# Creates the required update for changelog.txt. It creates the following:
#
# <version> (<date>)
# -------------------------
#
# ** <issue-type-1>
#    * PROJECT-<key> - <summary>
#    ...
#
# ** <issue-type-2>
#    * PROJECT-<key> - <summary>
#    ...
#
function create_changelog_update() {
  local ID=$1
  if [ "$PROJECT" == "orm" ]; then
    echo "Changes in $RELEASE_VERSION ($(date +'%B %d, %Y'))"
    echo "------------------------------------------------------------------------------------------------------------------------"
  else
    echo "$RELEASE_VERSION ($(date +%Y-%m-%d))"
    echo "-------------------------"
  fi
  echo ""
  echo "https://hibernate.atlassian.net/projects/${JIRA_KEY}/versions/$ID"
  echo ""
  local previous_issuetype=""
  while true; do
    JSON_RESPONSE=$(list_jira_issues "" "${NEXT_PAGE_TOKEN}")
    NEXT_PAGE_TOKEN=$(echo "${JSON_RESPONSE}" | jq -r '.nextPageToken //""')

    echo $JSON_RESPONSE | jq -r '.issues[] | (.fields.issuetype.name + "\t" + .key + "\t" + .fields.summary)' |
      while IFS=$'\t' read -r issuetype key summary; do
        if [ "$previous_issuetype" != "$issuetype" ]; then
          previous_issuetype="$issuetype"
          echo ""
          echo "** $issuetype"
        fi
        echo "    * $key $summary"
      done
    if [[ -z "${NEXT_PAGE_TOKEN}" ]]; then
      break
    fi
  done

  echo ""
}

########################################################################################################################
# Putting it all together
########################################################################################################################

JIRA_VERSION="$(jira_version)"
if [ -z "$JIRA_VERSION" ]; then
  echo "ERROR: Version $JIRA_FIX_VERSION_LABEL does not exist in JIRA"
  exit 1
fi
if [ "$PROJECT" == "search" ] || [ "$PROJECT" == "validator" ]; then
  if [ "true" != "$(echo "$JIRA_VERSION" | jq '.released' )" ]; then
    echo "ERROR: Version $JIRA_FIX_VERSION_LABEL is not yet released in JIRA"
    exit 1
  fi
fi
NON_FIXED="$(list_jira_issues "%20AND%20(resolution%20IS%20EMPTY%20OR%20resolution%20!%3D%20Fixed)" | jq -r '.issues[] | (.key)')"
if [ -n "$NON_FIXED" ]; then
  echo -e "ERROR: Version $JIRA_FIX_VERSION_LABEL has issues that are not marked as 'Fixed' in JIRA:\n$NON_FIXED"
  exit 1
fi

JIRA_VERSION_ID="$(echo $JIRA_VERSION | jq -r ".id")"

changelog_update_file="$(mktemp)"
trap "rm -f $changelog_update_file" EXIT
create_changelog_update $JIRA_VERSION_ID > "$changelog_update_file"
sed -i "3r$changelog_update_file" "$CHANGELOG"
git add "$CHANGELOG"
git commit -m "[Jenkins release job] changelog.txt updated by release build ${RELEASE_VERSION}"
