#!/usr/bin/env -S bash -e

JIRA_CLOSE_TRANSITION_ID=2
JIRA_REOPEN_TRANSITION_ID=3

function usage() {
  echo "Usage:"
  echo
  echo "  $0 [options] <jira_key> <release_version> <next_version>"
  echo
  echo "    <jira_key>               The Jira project key (e.g. HHH)"
  echo "    <release_version>        The version to release (e.g. 6.0.1)"
  echo "    <next_version>           The new version to create (e.g. 6.0.2)"
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

while getopts 'dhb:' opt; do
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
  \?)
    usage
    exit 1
    ;;
  esac
done

shift $((OPTIND - 1))

SCRIPTS_DIR="$(readlink -f ${BASH_SOURCE[0]} | xargs dirname)"

JIRA_KEY=$1
RELEASE_VERSION=$2
NEXT_VERSION=$3

if [ -z "$JIRA_KEY" ]; then
	echo "ERROR: Jira key not supplied"
	exit 1
fi

if [ -z "$RELEASE_VERSION" ]; then
	echo "ERROR: Release version not supplied"
	exit 1
fi

if [ -z "$NEXT_VERSION" ]; then
	echo "ERROR: Next version not supplied"
	exit 1
fi

if [ "$PUSH_CHANGES" == 'true' ] && [ -z "$JIRA_API_TOKEN" ]; then
	echo "ERROR: Environment variable JIRA_API_TOKEN must not be empty"
	exit 1
fi

JIRA_VERSION_ID=$($SCRIPTS_DIR/determine-jira-version-id.sh $JIRA_KEY $RELEASE_VERSION)

response=$(exec_or_dry_run curl -L -s -w "\n%{http_code}" -X PUT \
	-u "\$JIRA_API_TOKEN" \
	-H 'Accept: application/json' \
	-H 'Content-Type: application/json' \
	-d '{"released": true}' \
	"https://hibernate.atlassian.net/rest/api/2/version/$JIRA_VERSION_ID")

if [ "$PUSH_CHANGES" == true ]; then
	jiraReleaseResponseCode=$(tail -n1 <<< "$response")  # get the last line
	jiraReleaseResponse=$(sed '$ d' <<< "$response")   # get all but the last line which contains the status code

	if [ "$jiraReleaseResponseCode" != 200 ]; then
		echo "$jiraReleaseResponse"
		echo "ERROR: Release failed because Jira version ${RELEASE_VERSION} could not be released"
		exit 1
	fi
else
	echo $response
fi

response=$(exec_or_dry_run curl -L -s -w "\n%{http_code}" -X POST \
	-u "\$JIRA_API_TOKEN" \
	-H 'Accept: application/json' \
	-H 'Content-Type: application/json' \
	-d '{"name": "'${NEXT_VERSION}'", "projectId": '${JIRA_PROJECT_ID}} \
	'https://hibernate.atlassian.net/rest/api/2/version')

if [ "$PUSH_CHANGES" == true ]; then
	jiraCreateVersionResponseCode=$(tail -n1 <<< "$response")  # get the last line
	jiraCreateVersionResponse=$(sed '$ d' <<< "$response")   # get all but the last line which contains the status code

	if [ "$jiraCreateVersionResponseCode" != 201 ]; then
		echo "$jiraCreateVersionResponse"
		echo "ERROR: Release failed because Jira version ${NEXT_VERSION} could not be created"
		exit 1
	fi
else
	echo $response
fi


# REST URL used for getting all issues of given release - see https://docs.atlassian.com/jira/REST/latest/#d2e2450
jiraIssuesResponse=$(curl -sL "https://hibernate.atlassian.net/rest/api/2/search/?jql=project%20%3D%20${JIRA_KEY}%20AND%20fixVersion%20%3D%20${RELEASE_VERSION}%20ORDER%20BY%20issuetype%20ASC&fields=issuetype,summary&maxResults=200")
jiraIssueUrls=$(echo "$jiraIssuesResponse" | sed -nE 's/(https:\/\/hibernate\.atlassian\.net\/rest\/api\/2\/issue\/[0-9]+)/\n\1\n/gp' | grep https://hibernate.atlassian.net/rest/api/2/issue/)

# Close resolved issues. Remove fix version from Done non-resolved issues.
# Move issues Undone non-resolved issues to next version.
while IFS= read -r jiraIssueUrl; do
	jiraIssueResponse=$(curl -sL "$jiraIssueUrl")
	jiraIssueId=$(echo "$jiraIssueResponse" | sed -nE 's/^\{[^{]+"id":"([^"]+)".+/\1/p' )
	jiraIssueKey=$(echo "$jiraIssueResponse" | sed -nE 's/^\{[^{]+"key":"([^"]+)".+/\1/p' )
	jiraIssueStatus=$(echo "$jiraIssueResponse" | sed -nE 's/.*"status":\{([^{]+)\,"statusCategory".+/\1/p' | sed -nE 's/.*"name":"([^"]+)".+/\1/p' )
	if [ "$jiraIssueStatus" == "Resolved" ]; then
		response=$(exec_or_dry_run curl -L -s -w "\n%{http_code}" -X POST \
			-u "\$JIRA_API_TOKEN" \
			-H 'Accept: application/json' \
			-H 'Content-Type: application/json' \
			-d '{"transition":{"id":"'${JIRA_CLOSE_TRANSITION_ID}'"}}' \
			"https://hibernate.atlassian.net/rest/api/2/issue/${jiraIssueId}/transitions")

		if [ "$PUSH_CHANGES" == true ]; then
			jiraCloseIssueResponseCode=$(tail -n1 <<< "$response")  # get the last line
			jiraCloseIssueResponse=$(sed '$ d' <<< "$response")   # get all but the last line which contains the status code

			if [ "$jiraCloseIssueResponseCode" != 201 ]; then
				echo "$jiraCloseIssueResponse"
				echo "ERROR: Release failed because Jira issue ${jiraIssueKey} could not be closed"
				exit 1
			fi
		else
			echo $response
		fi
	elif [ "$jiraIssueStatus" == "Closed" ]; then
	
		if [ "$jiraIssueResolution" != "Fixed" ]; then
			response=$(exec_or_dry_run curl -L -s -w "\n%{http_code}" -X POST \
				-u "\$JIRA_API_TOKEN" \
				-H 'Accept: application/json' \
				-H 'Content-Type: application/json' \
				-d '{"transition":{"id":"'${JIRA_REOPEN_TRANSITION_ID}'"}}' \
				"https://hibernate.atlassian.net/rest/api/2/issue/${jiraIssueId}/transitions")

			if [ "$PUSH_CHANGES" == true ]; then
				jiraReopenIssueResponseCode=$(tail -n1 <<< "$response")  # get the last line
				jiraReopenIssueResponse=$(sed '$ d' <<< "$response")   # get all but the last line which contains the status code

				if [ "$jiraReopenIssueResponseCode" != 201 ]; then
					echo "$jiraReopenIssueResponse"
					echo "ERROR: Release failed because Jira issue ${jiraIssueKey} could not be reopened"
					exit 1
				fi
			else
				echo $response
			fi
			
			response=$(exec_or_dry_run curl -L -s -w "\n%{http_code}" -X POST \
				-u "\$JIRA_API_TOKEN" \
				-H 'Accept: application/json' \
				-H 'Content-Type: application/json' \
				-d '{"transition":{"id":"'${JIRA_CLOSE_TRANSITION_ID}'"},"update":{"fixVersions":[{"remove":"'${RELEASE_VERSION}'"}]},"fields":{"resolution":{"name":"'${jiraIssueResolution}'"}}}' \
				"https://hibernate.atlassian.net/rest/api/2/issue/${jiraIssueId}/transitions")

			if [ "$PUSH_CHANGES" == true ]; then
				jiraCloseIssueResponseCode=$(tail -n1 <<< "$response")  # get the last line
				jiraCloseIssueResponse=$(sed '$ d' <<< "$response")   # get all but the last line which contains the status code

				if [ "$jiraCloseIssueResponseCode" != 201 ]; then
					echo "$jiraCloseIssueResponse"
					echo "ERROR: Release failed because Jira issue ${jiraIssueKey} could not be closed"
					exit 1
				fi
			else
				echo $response
			fi
		else
			echo "Ignoring already closed Jira issue: ${jiraIssueKey}"
		fi
	else
		response=$(exec_or_dry_run curl -L -s -w "\n%{http_code}" -X POST \
			-u "\$JIRA_API_TOKEN" \
			-H 'Accept: application/json' \
			-H 'Content-Type: application/json' \
			-d '{"update":{"fixVersions":[{"remove":"'${RELEASE_VERSION}'"},{"add":"'${NEXT_VERSION}'"}]}}' \
			"https://hibernate.atlassian.net/rest/api/2/issue/${jiraIssueId}")

		if [ "$PUSH_CHANGES" == true ]; then
			jiraMoveIssueResponseCode=$(tail -n1 <<< "$response")  # get the last line
			jiraMoveIssueResponse=$(sed '$ d' <<< "$response")   # get all but the last line which contains the status code

			if [ "$jiraMoveIssueResponseCode" != 201 ]; then
				echo "$jiraMoveIssueResponse"
				echo "ERROR: Release failed because Jira issue ${jiraIssueKey} could not be moved to next version"
				exit 1
			fi
		else
			echo $response
		fi
	fi
done <<< "$jiraIssueUrls"


		