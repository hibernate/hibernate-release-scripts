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
	echo "ERROR: deploy.sh should not be used with ORM, use publish.sh instead"
	exit 1
fi

if [ "$PROJECT" == "ogm" ]; then
	ADDITIONAL_OPTIONS="-DmongodbProvider=external -DskipITs"
else
	ADDITIONAL_OPTIONS=""
fi

source "$SCRIPTS_DIR/mvn-setup.sh"

./mvnw -Pdocbook,documentation-pdf,dist,perf,relocation,release clean deploy -DskipTests=true -Dcheckstyle.skip=true -DperformRelease=true -Dmaven.compiler.useIncrementalCompilation=false $ADDITIONAL_OPTIONS

popd
