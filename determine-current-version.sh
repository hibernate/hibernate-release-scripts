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
elif [ "$PROJECT" == "reactive" ]; then
	# For example, if `version.properties` contains `projectVersion=2.4.5-SNAPSHOT`, it returns `2.4.5-SNAPSHOT`
	grep projectVersion $WORKSPACE/gradle/version.properties|cut -d'=' -f2
elif [ "$PROJECT" == "models" ]; then
	cat $WORKSPACE/version.txt
elif [ -f './gradlew' ]; then
	# Gradle-based build
	grep hibernateVersion $WORKSPACE/gradle/version.properties|cut -d'=' -f2
else
	# Maven-based build

	mvn -f $WORKSPACE/pom.xml org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.version -q -DforceStdout
fi
