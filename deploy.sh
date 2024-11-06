#!/usr/bin/env -S bash -e

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
fi

popd
