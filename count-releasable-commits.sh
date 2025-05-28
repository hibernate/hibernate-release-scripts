#!/usr/bin/env -S bash -e

function log() {
  echo 1>&2 "$@"
}

function usage() {
  log "Usage:"
  log
  log "  $0 <project>"
  log
  log "    <project>                One of [search,validator,ogm,orm,reactive]"
}

SCRIPTS_DIR="$(readlink -f ${BASH_SOURCE[0]} | xargs dirname)"

PROJECT=$1
WORKSPACE=${WORKSPACE:-'.'}

if [ "$PROJECT" == "search" ]; then
  MESSAGE_PATTERN='^HSEARCH-|^\[HSEARCH-'
elif [ "$PROJECT" == "validator" ]; then
  MESSAGE_PATTERN='^HV-|^\[HV-'
elif [ "$PROJECT" == "ogm" ]; then
  MESSAGE_PATTERN='^OGM-|^\[OGM-'
elif [ "$PROJECT" == "orm" ]; then
  MESSAGE_PATTERN='^HHH-|^\[HHH-'
elif [ "$PROJECT" == "tools" ]; then
  MESSAGE_PATTERN='^HBX-|^\[HBX-'
elif [ "$PROJECT" == "reactive" ]; then
  MESSAGE_PATTERN='^#[[:digit:]]+|^\[#[[:digit:]]+'
else
  log "ERROR: Unknown project name $PROJECT"
  usage
  exit 1
fi


LAST_RELEASE_COMMIT=$(git log --max-count=1 --author=Hibernate-CI --format='%H')
log "Last release-related commit: ${LAST_RELEASE_COMMIT}."
if [ -z "$LAST_RELEASE_COMMIT" ]
then
	log "No release-related commit. Assuming no releasable commits."
	log "Note: the very first release must be triggered manually."
	echo "0"
	exit 0
fi

# Displays the last few commits on stderr (thanks to tee) and just the count on stdout (thanks to wc)
git log $LAST_RELEASE_COMMIT..HEAD -E "--grep=${MESSAGE_PATTERN}" --format='  %H %s' \
  | tee >(echo 1>&2 "Releasable commits (max 10 displayed):"; tail -n 10 1>&2) \
  | wc -l
