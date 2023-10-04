#!/usr/bin/env -S bash -e

SCRIPTS_DIR="$(readlink -f ${BASH_SOURCE[0]} | xargs dirname)"

JIRA_KEY=$1
JIRA_VERSION=$2
WORKSPACE=${WORKSPACE:-'.'}

if [ -z "$JIRA_KEY" ]; then
	echo "ERROR: Jira key not supplied"
	exit 1
fi

if [ -z "$JIRA_VERSION" ]; then
	echo "ERROR: Jira version not supplied"
	exit 1
fi

JSON_RESPONSE=$(curl -sL "https://hibernate.atlassian.net/rest/api/2/project/${JIRA_KEY}/version?status=unreleased")
JIRA_VERSION_ID=$(echo "$JSON_RESPONSE" | sed -E "s/^.+,\"id\":\"([0-9]+)\",\"name\":\"${JIRA_VERSION//./\.}\".*/\1/")

if [ -z "$JIRA_VERSION_ID" ]; then
	echo "ERROR: Jira version id not found"
	exit 1
fi
echo $JIRA_VERSION_ID
