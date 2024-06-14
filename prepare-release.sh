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

echo "Preparing the release ..."

pushd $WORKSPACE

# Set up git so that we can create commits
git config --local user.name "Hibernate CI"
git config --local user.email "ci@hibernate.org"

if [ "$PROJECT" == "orm" ]; then
	RELEASE_VERSION_BASIS=$(echo "$RELEASE_VERSION" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
	RELEASE_VERSION_FAMILY=$(echo "$RELEASE_VERSION" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')
	"$SCRIPTS_DIR/validate-release.sh" $PROJECT $RELEASE_VERSION_BASIS
	# set release version
	# update changelog from JIRA
	# tags the version
	# changes the version to the provided development version
	./gradlew clean releasePrepare -x test --no-scan \
		-PreleaseVersion=$RELEASE_VERSION -PdevelopmentVersion=$DEVELOPMENT_VERSION -PgitRemote=origin \
		-PSONATYPE_OSSRH_USER=$OSSRH_USER -PSONATYPE_OSSRH_PASSWORD=$OSSRH_PASSWORD \
		-Pgradle.publish.key=$PLUGIN_PORTAL_USERNAME -Pgradle.publish.secret=$PLUGIN_PORTAL_PASSWORD \
		-PhibernatePublishUsername=$OSSRH_USER -PhibernatePublishPassword=$OSSRH_PASSWORD \
		-DsigningPassword=$RELEASE_GPG_PASSPHRASE -DsigningKeyFile=$RELEASE_GPG_PRIVATE_KEY_PATH
else
	"$SCRIPTS_DIR/check-sourceforge-availability.sh"
	"$SCRIPTS_DIR/update-readme.sh" $PROJECT $RELEASE_VERSION "$WORKSPACE/README.md"
	"$SCRIPTS_DIR/update-changelog.sh" $PROJECT $RELEASE_VERSION "$WORKSPACE/changelog.txt"
	"$SCRIPTS_DIR/validate-release.sh" $PROJECT $RELEASE_VERSION
	"$SCRIPTS_DIR/update-version.sh" $PROJECT $RELEASE_VERSION $INHERITED_VERSION
	"$SCRIPTS_DIR/create-tag.sh" $PROJECT $RELEASE_VERSION
fi

popd

echo "Release ready: version is updated to $RELEASE_VERSION"
