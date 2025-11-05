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
  ./gradlew releaseGradlePluginPerform
fi

if [ "$PROJECT" == "tools" ]; then
  ./mvnw deploy -DpublishPlugin=true -DperformRelease=true \
        -Pdocbook,documentation-pdf,dist,perf,relocation,release \
    		-DskipTests=true -Dcheckstyle.skip=true
fi

popd
