#!/usr/bin/env -S bash -e

MESSAGE=""

while getopts 'm:' opt; do
  case "$opt" in
  m)
    MESSAGE="$OPTARG"
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
NEW_VERSION=$2
# If set, Project version is inherited from parent (maven requires a different command)
VERSION_INHERITED=$3
WORKSPACE=${WORKSPACE:-'.'}

if [ -z "$PROJECT" ]; then
	echo "ERROR: Project not supplied"
	exit 1
fi
if [ -z "$MESSAGE" ]; then
	echo "ERROR: Commit message was not supplied"
	exit 1
fi
if [ -z "$NEW_VERSION" ]; then
	echo "ERROR: New version argument not supplied"
	exit 1
fi

echo "Setting version to '$NEW_VERSION'";

pushd $WORKSPACE

if [ -f "./gradlew" ]; then
	# Gradle-based build
	if [ -f "./gradle/version.properties" ]; then
  	# ORM/Reactive custom version location:
  	sed -i "s/^projectVersion=.*$/projectVersion=$NEW_VERSION/g" ./gradle/version.properties
  	sed -i "s/^hibernateVersion=.*$/hibernateVersion=$NEW_VERSION/g" ./gradle/version.properties
  else
    # More standard location for other gradle-based projects:
    sed -i "s/^version=.*$/version=$NEW_VERSION/g" gradle.properties
  fi
else
	# Maven-based build
	source "$SCRIPTS_DIR/mvn-setup.sh"

	if [ -f bom/pom.xml ] && [ "$PROJECT" == "ogm" ]; then
		./mvnw -Prelocation clean versions:set -DnewVersion=$NEW_VERSION -DgenerateBackupPoms=false -f bom/pom.xml
	elif [ -z "$VERSION_INHERITED" ]; then
		./mvnw -Prelocation clean versions:set -DnewVersion=$NEW_VERSION -DgenerateBackupPoms=false
	else
			# Version inherited from parent
			./mvnw -Prelocation versions:update-parent -DparentVersion="[1.0, $NEW_VERSION]" -DgenerateBackupPoms=false -DallowSnapshots=true
			./mvnw -Prelocation -N versions:update-child-modules -DgenerateBackupPoms=false
	fi
fi

git commit -a -m "$MESSAGE"

popd
