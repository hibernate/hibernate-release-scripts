#!/usr/bin/env -S bash -e


function usage() {
  echo "Usage:"
  echo
  echo "  $0 [options] <project> <release_version>"
  echo
  echo "    <project>                One of [search,validator,ogm,orm,reactive]"
  echo "    <release_version>        The version to release (e.g. 6.0.1)"
  echo
  echo "  Options"
  echo
  echo "    -h            Show this help and exit."
  echo "    -d            Dry run; do not push, deploy or publish anything."
}

#--------------------------------------------
# Option parsing

function exec_or_dry_run() {
  "${@}"
}
PUSH_CHANGES=true

while getopts 'dhb:' opt; do
  case "$opt" in
  h)
    usage
    exit 0
    ;;
  d)
    # Dry run
    echo "DRY RUN: will not push/deploy/publish anything."
    PUSH_CHANGES=false
    function exec_or_dry_run() {
      echo "DRY RUN; would have executed:" "${@}"
    }
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
RELEASE_VERSION=$2

if [ -z "$PROJECT" ]; then
	echo "ERROR: Project not supplied"
	exit 1
fi
if [ -z "$RELEASE_VERSION" ]; then
	echo "ERROR: Release version argument not supplied"
	exit 1
fi

if [ "$PROJECT" == "search" ]; then
  PROJECT_MESSAGE_PREFIX='[HSEARCH] '
elif [ "$PROJECT" == "validator" ]; then
  PROJECT_MESSAGE_PREFIX='[HV] '
elif [ "$PROJECT" == "ogm" ]; then
  PROJECT_MESSAGE_PREFIX='[OGM] '
elif [ "$PROJECT" == "orm" ]; then
  PROJECT_MESSAGE_PREFIX='[ORM] '
elif [ "$PROJECT" == "tools" ]; then
  PROJECT_MESSAGE_PREFIX='[HBX] '
elif [ "$PROJECT" == "reactive" ]; then
  PROJECT_MESSAGE_PREFIX='[HR] '
else
  PROJECT_MESSAGE_PREFIX=''
fi

RELEASE_DATE=$(date +%Y-%m-%d)
RELEASE_VERSION_FAMILY=$(echo "$RELEASE_VERSION" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')
RELEASE_FILE_NAME="./_data/projects/${PROJECT}/releases/${RELEASE_VERSION_FAMILY}/${RELEASE_VERSION}.yml"
cat >> $RELEASE_FILE_NAME <<EOF
date: ${RELEASE_DATE}
EOF
git config user.email ci@hibernate.org
git config user.name Hibernate-CI
git add $RELEASE_FILE_NAME
git commit -m "${PROJECT_MESSAGE_PREFIX}${RELEASE_VERSION}"

# How many times should we try to push-wait-pull-retry before we quit:
MAX_ATTEMPTS=5
# Delay between attempts in seconds:
DELAY_BETWEEN_TRIES=5

# We've already committed the changes so now it's just a matter of pushing them to remote.
# If someone/something managed to push an update to the branch we work with before us we'll pull with rebase
# and try to push again:
for (( i=1; i<=$MAX_ATTEMPTS; i++ ))
do
  echo "Attempt $i of $MAX_ATTEMPTS: Pushing changes..."

  exec_or_dry_run git push origin HEAD:production

  if [ $? -eq 0 ]; then
    echo "Git push successful!"
    exit 0
  fi

  echo "Push failed. Waiting for $DELAY_BETWEEN_TRIES seconds before trying again..."
  sleep $DELAY_BETWEEN_TRIES

  if [ $i -lt $MAX_ATTEMPTS ]; then
    echo "Rebasing and will try again..."
    exec_or_dry_run git pull --rebase origin production

    if [ $? -ne 0 ]; then
      echo "Rebase failed. Something is totally wrong here. Failing the build..."
      exit 1
    fi
  fi
done

echo "Failed to push after $MAX_ATTEMPTS attempts."
exit 1
