#!/usr/bin/env -S bash -e

SCRIPTS_DIR="$(readlink -f ${BASH_SOURCE[0]} | xargs dirname)"

PROJECT=$1
WORKSPACE=${WORKSPACE:-'.'}

pushd ${WORKSPACE}

if [ -z "$PROJECT" ]; then
	echo "ERROR: Project not supplied"
	exit 1
fi

if [ "$PROJECT" == "orm" ]; then
	./gradlew ciRelease closeAndReleaseSonatypeStagingRepository -x test --no-scan \
	-PreleaseVersion=$RELEASE_VERSION -PdevelopmentVersion=$DEVELOPMENT_VERSION -PgitRemote=origin -PgitBranch=$VERSION_FAMILY \
	-PSONATYPE_OSSRH_USER=$OSSRH_USER -PSONATYPE_OSSRH_PASSWORD=$OSSRH_PASSWORD \
	-Pgradle.publish.key=$PLUGIN_PORTAL_USERNAME -Pgradle.publish.secret=$PLUGIN_PORTAL_PASSWORD \
	-PhibernatePublishUsername=$OSSRH_USER -PhibernatePublishPassword=$OSSRH_PASSWORD \
	-DsigningPassword=$SIGNING_PASS -DsigningKeyFile=$SIGNING_KEYRING
else
	if [ "$PROJECT" == "ogm" ]; then
		ADDITIONAL_OPTIONS="-DmongodbProvider=external -DskipITs"
	else
		ADDITIONAL_OPTIONS=""
	fi

	source "$SCRIPTS_DIR/mvn-setup.sh"

	./mvnw -Pdocbook,documentation-pdf,dist,perf,relocation,release clean deploy -DskipTests=true -Dcheckstyle.skip=true -DperformRelease=true -Dmaven.compiler.useIncrementalCompilation=false $ADDITIONAL_OPTIONS
fi

popd
