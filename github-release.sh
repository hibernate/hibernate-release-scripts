#!/usr/bin/env -S bash -e


function usage() {
  echo "Usage:"
  echo
  echo "  $0 [options] <project> <release_version>"
  echo
  echo "    <project>                One of [search,validator,ogm,orm]"
  echo "    <release_version>        The version to release (e.g. 6.0.1)"
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

PROJECT=$1
RELEASE_VERSION=$2

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

if [ "$PROJECT" == "search" ]; then
  JIRA_KEY="HSEARCH"
  PROJECT_NAME="Search"
  STRIPPED_SUFFIX_FOR_TAG=""
elif [ "$PROJECT" == "validator" ]; then
  JIRA_KEY="HV"
  PROJECT_NAME="Validator"
  STRIPPED_SUFFIX_FOR_TAG=""
elif [ "$PROJECT" == "ogm" ]; then
  JIRA_KEY="OGM"
  PROJECT_NAME="OGM"
  STRIPPED_SUFFIX_FOR_TAG=""
elif [ "$PROJECT" == "orm" ]; then
  JIRA_KEY="HHH"
  PROJECT_NAME="ORM"
  STRIPPED_SUFFIX_FOR_TAG=".Final"
elif [ "$PROJECT" == "reactive" ]; then
  JIRA_KEY="HREACT"
  PROJECT_NAME="Reactive"
  STRIPPED_SUFFIX_FOR_TAG=".Final"
else
  echo "ERROR: Unknown project name $PROJECT"
  usage
  exit 1
fi

RELEASE_VERSION_FAMILY=$(echo "$RELEASE_VERSION" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')
RELEASE_VERSION_BASIS=$(echo "$RELEASE_VERSION" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
RELEASE_SUFFIX=$(echo "$RELEASE_VERSION" | sed -E 's/^[0-9]+\.[0-9]+\.[0-9]+(.*)/\1/')

if [ -n "$STRIPPED_SUFFIX_FOR_TAG" -a "$RELEASE_SUFFIX" == "$STRIPPED_SUFFIX_FOR_TAG" ]; then
  TAG_NAME=$RELEASE_VERSION_BASIS
else
  TAG_NAME=$RELEASE_VERSION
fi

if [ "$PUSH_CHANGES" == 'true' ] && [ -z "$GITHUB_API_TOKEN" ]; then
	echo "ERROR: Environment variable GITHUB_API_TOKEN must not be empty"
	exit 1
fi

docsUrl="https://docs.jboss.org/hibernate/orm/${RELEASE_VERSION_FAMILY}"
javadocsUrl="${docsUrl}/javadocs"
migrationGuideUrl="${docsUrl}/migration-guide/migration-guide.html"
introGuideUrl="${docsUrl}/introduction/html_single/Hibernate_Introduction.html"
userGuideUrl="${docsUrl}/userguide/html_single/Hibernate_User_Guide.html"
					
releaseName="Hibernate ${PROJECT_NAME} ${RELEASE_VERSION}"
releaseBody="""\
# Hibernate ${PROJECT_NAME} ${RELEASE_VERSION} released

Today, we published a new maintenance release of Hibernate ${PROJECT_NAME} ${RELEASE_VERSION_FAMILY}: ${RELEASE_VERSION}.

## What's new

This release introduces a few minor improvements as well as bug fixes.

You can find the full list of ${RELEASE_VERSION} changes [here](https://hibernate.atlassian.net/issues/?jql=project%20%3D%20${JIRA_KEY}%20AND%20fixVersion%20%3D%20${TAG_NAME}).

## Conclusion

For additional details, see:

- the [release page](https://hibernate.org/orm/releases/${RELEASE_VERSION_FAMILY}/)
- the [Migration Guide](${migrationGuideUrl})
- the [Introduction Guide](${introGuideUrl})
- the [User Guide](${userGuideUrl})

See also the following resources related to supported APIs:

- the [compatibility policy](https://hibernate.org/community/compatibility-policy/)
- the [incubating API report](${docsUrl}/incubating/incubating.txt) (\`@Incubating\`)
- the [deprecated API report](${docsUrl}/deprecated/deprecated.txt) (\`@Deprecated\` + \`@Remove\`)
- the [internal API report](${docsUrl}/internals/internal.txt) (internal packages, \`@Internal\`)

Visit the [website](https://hibernate.org/community/) for details on getting in touch with us."""

response=$(exec_or_dry_run curl -L -s -w "\n%{http_code}" \
	-X POST \
	-H 'Accept: application/vnd.github+json' \
	-H 'X-GitHub-Api-Version: 2022-11-28' \
	-H "Authorization: Bearer $GITHUB_API_TOKEN" \
	-d "{\"tag_name\":\"${TAG_NAME}\",\"name\":\"${releaseName}\",\"make_latest\":\"legacy\",\"body\":\"${releaseBody//$'\n'/\\n}\"}" \
	'https://api.github.com/repos/hibernate/hibernate-orm/releases')

if [ "$PUSH_CHANGES" == true ]; then
	githubCreateReleaseResponseCode=$(tail -n1 <<< "$response")  # get the last line
	githubCreateReleaseResponse=$(sed '$ d' <<< "$response")   # get all but the last line which contains the status code

	if [ "$githubCreateReleaseResponseCode" != 201 ]; then
		echo "$githubCreateReleaseResponse"
		echo "ERROR: Release failed because GitHub release could not be created"
		exit 1
	fi
else
	echo $response
fi
