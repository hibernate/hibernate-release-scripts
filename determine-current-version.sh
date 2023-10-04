#!/usr/bin/env -S bash -e

SCRIPTS_DIR="$(readlink -f ${BASH_SOURCE[0]} | xargs dirname)"

PROJECT=$1
WORKSPACE=${WORKSPACE:-'.'}

if [ -z "$PROJECT" ]; then
	echo "ERROR: Project not supplied"
	exit 1
fi

if [ "$PROJECT" == "orm" ]; then
	grep hibernateVersion $WORKSPACE/gradle/version.properties|cut -d'=' -f2
else
	mvn -f $WORKSPACE/pom.xml org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.version -q -DforceStdout
fi
