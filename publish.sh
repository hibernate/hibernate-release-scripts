#!/usr/bin/env -S bash -e

function usage() {
  echo "Usage:"
  echo
  echo "  $0 [options] <project> <release_version> <development_version>"
  echo
  echo "    <project>                One of [search,validator,ogm,orm]"
  echo "    <release_version>        The version to release (e.g. 6.0.1.Final)"
  echo "    <development_version>    The new version after the release (e.g. 6.0.2-SNAPSHOT)"
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
DEVELOPMENT_VERSION=$3
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

RELEASE_VERSION_FAMILY=$(echo "$RELEASE_VERSION" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')

if [ "$PROJECT" == "orm" ]; then
	./gradlew ciRelease closeAndReleaseSonatypeStagingRepository -x test --no-scan \
		-PreleaseVersion=$RELEASE_VERSION -PdevelopmentVersion=$DEVELOPMENT_VERSION -PgitRemote=origin -PgitBranch=$RELEASE_VERSION_FAMILY \
		-PSONATYPE_OSSRH_USER=$OSSRH_USER -PSONATYPE_OSSRH_PASSWORD=$OSSRH_PASSWORD \
		-Pgradle.publish.key=$PLUGIN_PORTAL_USERNAME -Pgradle.publish.secret=$PLUGIN_PORTAL_PASSWORD \
		-PhibernatePublishUsername=$OSSRH_USER -PhibernatePublishPassword=$OSSRH_PASSWORD \
		-DsigningPassword=$RELEASE_GPG_PASSPHRASE -DsigningKeyFile=$RELEASE_GPG_PRIVATE_KEY_PATH
else
	bash -xe "$SCRIPTS_DIR/deploy.sh" "$PROJECT"

	exec_or_dry_run bash -xe "$SCRIPTS_DIR/upload-distribution.sh" "$PROJECT" "$RELEASE_VERSION"
	exec_or_dry_run bash -xe "$SCRIPTS_DIR/upload-documentation.sh" "$PROJECT" "$RELEASE_VERSION" "$RELEASE_VERSION_FAMILY"

	bash -xe "$SCRIPTS_DIR/update-version.sh" "$PROJECT" "$DEVELOPMENT_VERSION"
	bash -xe "$SCRIPTS_DIR/push-upstream.sh" "$PROJECT" "$RELEASE_VERSION" "$BRANCH" "$PUSH_CHANGES"
fi

popd
