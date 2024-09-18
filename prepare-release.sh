#!/usr/bin/env -S bash -e

SCRIPTS_DIR="$(readlink -f ${BASH_SOURCE[0]} | xargs dirname)"

PROJECT=$1
RELEASE_VERSION=$2
INHERITED_VERSION=$3
DEVELOPMENT_VERSION=$3
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

if [ "$PROJECT" == "orm" ] || [ "$PROJECT" == "reactive" ]; then
	RELEASE_VERSION_BASIS=$(echo "$RELEASE_VERSION" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
	RELEASE_VERSION_FAMILY=$(echo "$RELEASE_VERSION" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')
	"$SCRIPTS_DIR/validate-release.sh" $PROJECT $RELEASE_VERSION
	# set release version
	# update changelog from JIRA
	# tags the version
	# changes the version to the provided development version
	./gradlew clean releasePrepare -x test --no-scan --no-daemon \
		-PreleaseVersion=$RELEASE_VERSION -PdevelopmentVersion=$DEVELOPMENT_VERSION -PgitRemote=origin -PgitBranch=$BRANCH -PdocPublishBranch="production" \
		-PSONATYPE_OSSRH_USER=$OSSRH_USER -PSONATYPE_OSSRH_PASSWORD=$OSSRH_PASSWORD \
		-Pgradle.publish.key=$PLUGIN_PORTAL_USERNAME -Pgradle.publish.secret=$PLUGIN_PORTAL_PASSWORD \
		-PhibernatePublishUsername=$OSSRH_USER -PhibernatePublishPassword=$OSSRH_PASSWORD \
		-DsigningPassword=$RELEASE_GPG_PASSPHRASE -DsigningKeyFile=$RELEASE_GPG_PRIVATE_KEY_PATH
else
	if [[ "$PROJECT" != "infra-theme" && "$PROJECT" != "infra-extensions" ]]; then
		# Infra projects do not have a distribution bundle archive,
		#    hence we do not want to check the sourceforge availability as we will not be uploading anything.
		# There is also no versions in the readme and no changelog that we can fetch from JIRA,
		#    as there is no JIRA for these infra projects,
		#    hence we only run these steps if it's not an infra project:
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
