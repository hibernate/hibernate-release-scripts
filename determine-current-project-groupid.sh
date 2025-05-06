#!/usr/bin/env -S bash -e

SCRIPTS_DIR="$(readlink -f ${BASH_SOURCE[0]} | xargs dirname)"

PROJECT=$1
WORKSPACE=${WORKSPACE:-'.'}

if [ -z "$PROJECT" ]; then
	echo "ERROR: Project not supplied"
	exit 1
fi

if [ "$PROJECT" == "orm" ]; then
  BRANCH_NAME=$(git symbolic-ref -q HEAD)
  BRANCH_NAME=${BRANCH_NAME##refs/heads/}
  BRANCH_NAME=${BRANCH_NAME:-HEAD}

  if [[ $BRANCH_NAME =~ ^5\..+ ]]; then
    echo "org.hibernate"
  else
    echo "org.hibernate.orm"
  fi
elif [ "$PROJECT" == "reactive" ]; then
	echo "org.hibernate.reactive"
elif [ "$PROJECT" == "models" ]; then
	echo "org.hibernate.models"
elif [ -f './gradlew' ]; then
	# Gradle-based build
	echo "ERROR: An unsupported Gradle project: $PROJECT"
	exit 1
else
	# Maven-based build

	mvn -f $WORKSPACE/pom.xml org.apache.maven.plugins:maven-help-plugin:evaluate -Dexpression=project.groupId -q -DforceStdout
fi
