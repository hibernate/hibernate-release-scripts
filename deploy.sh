#!/usr/bin/env -S bash -e

while getopts 'd:' opt; do
  case "$opt" in
  d)
    # Dry run
    echo "DRY RUN: will not push/deploy/publish anything."
    export JRELEASER_DRY_RUN=true
    ;;
  \?)
    usage
    exit 1
    ;;
  esac
done

SCRIPTS_DIR="$(readlink -f ${BASH_SOURCE[0]} | xargs dirname)"

PROJECT=$1
WORKSPACE=${WORKSPACE:-'.'}

pushd ${WORKSPACE}

if [ -z "$PROJECT" ]; then
	echo "ERROR: Project not supplied"
	exit 1
fi

if [ "$PROJECT" == "orm" ] || [ "$PROJECT" == "reactive" ]; then
  PROJECT_NAME=$([ "$PROJECT" == "orm" ] && echo "ORM" || echo "Reactive")
	echo "ERROR: deploy.sh should not be used with $PROJECT_NAME, use publish.sh instead"
	exit 1
fi

if [ -f "./gradlew" ]; then
	# Gradle-based build

	./gradlew --no-scan --no-daemon --no-build-cache publish
else
	# Maven-based build

	if [ "$PROJECT" == "ogm" ]; then
		ADDITIONAL_OPTIONS="-DmongodbProvider=external -DskipITs"
	else
		ADDITIONAL_OPTIONS=""
	fi

	source "$SCRIPTS_DIR/mvn-setup.sh"

	# if there's no JReleaser file available the deploy command will use the nexus-staging plugin and deploy to nexus itself.
	# otherwise the deploy plugin pushes the artifacts to a local directory that jreleaser will work with:
	./mvnw clean deploy \
		-Pdocbook,documentation-pdf,dist,perf,relocation,release \
		-DperformRelease=true \
		-DskipTests=true -Dcheckstyle.skip=true \
		-Dmaven.compiler.useIncrementalCompilation=false \
		-Ddevelocity.enabled=false \
		-Dscan=false -Dno-build-cache \
		-Dgradle.cache.remote.enabled=false -Dgradle.cache.local.enabled=false \
		-Ddevelocity.cache.remote.enabled=false -Ddevelocity.cache.local.enabled=false \
	 	$ADDITIONAL_OPTIONS

	if [ -f "./jreleaser.yml" ]; then
		# JReleaser-based build
		export JRELEASER_GPG_HOMEDIR="$RELEASE_GPG_HOMEDIR"
		# Get the jreleaser downloader
		curl -sL https://git.io/get-jreleaser > get_jreleaser.java
		# Download JReleaser with version = <version>
		# Change <version> to a tagged JReleaser release
		# or leave it out to pull `latest`.
		java get_jreleaser.java
		# Let's check we've got the right version
		java -jar jreleaser-cli.jar --version
		# Execute a JReleaser command such as 'full-release'
		java -jar jreleaser-cli.jar -Djreleaser.project.version="$RELEASE_VERSION"
	fi
fi

popd
