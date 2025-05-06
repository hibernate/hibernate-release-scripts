#!/usr/bin/env -S bash -e

SCRIPTS_DIR="$(readlink -f ${BASH_SOURCE[0]} | xargs dirname)"

PROJECT=$1
WORKSPACE=${WORKSPACE:-'.'}

if [ -f "./jreleaser.yml" ]; then
  # There is a jreleaser.yml in the project root. Using this configuration:
  echo "./jreleaser.yml"
  exit 0
fi

if [ -z "$PROJECT" ]; then
	echo "ERROR: Project not supplied"
	exit 1
fi

BRANCH_NAME=$(git symbolic-ref -q HEAD)
BRANCH_NAME=${BRANCH_NAME##refs/heads/}
BRANCH_NAME=${BRANCH_NAME:-HEAD}

if [ "$PROJECT" == "orm" ]; then
  if [ "$BRANCH_NAME" == "main" ]; then
	  echo "$SCRIPTS_DIR/jreleaser/configuration/jreleaser_manual.yml"
  else
    echo "$SCRIPTS_DIR/jreleaser/configuration/jreleaser_automatic.yml"
  fi
elif [ "$PROJECT" == "reactive" ]; then
	echo "$SCRIPTS_DIR/jreleaser/configuration/jreleaser_automatic_alternative.yml"
elif [ "$PROJECT" == "models" ]; then
	echo "$SCRIPTS_DIR/jreleaser/configuration/jreleaser_automatic_alternative.yml"
else
	echo "$SCRIPTS_DIR/jreleaser/configuration/jreleaser_manual.yml"
fi
