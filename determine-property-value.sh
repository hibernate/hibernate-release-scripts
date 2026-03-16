#!/usr/bin/env -S bash -e

SCRIPTS_DIR="$(readlink -f ${BASH_SOURCE[0]} | xargs dirname)"

PROPERTY=$1
WORKSPACE=${WORKSPACE:-'.'}

if [ -z "$PROPERTY" ]; then
	echo "ERROR: Property not supplied"
	exit 1
fi

if [ ! -f "$WORKSPACE/pom.xml" ]; then
	echo "ERROR: Only works with maven projects."
	exit 1
fi

mvn -f "$WORKSPACE"/pom.xml org.apache.maven.plugins:maven-help-plugin:evaluate -Dexpression="$PROPERTY" -q -DforceStdout
