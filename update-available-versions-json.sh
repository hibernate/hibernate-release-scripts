#!/usr/bin/env -S bash -e

PROJECT=$1
VERSION_FAMILY=$2
WORKSPACE=${WORKSPACE:-'.'}

if [ -z "$PROJECT" ]; then
	echo "ERROR: Project not supplied"
	exit 1
fi
if [ -z "$VERSION_FAMILY" ]; then
	echo "ERROR: Version family argument not supplied"
	exit 1
fi

pushd ${WORKSPACE}

wget -q http://docs.jboss.org/hibernate/_available-versions/${PROJECT}.json -O "available-${PROJECT}.json"
if [ ! -s ${PROJECT}.json ]; then
  echo "Error downloading the ${PROJECT}.json descriptor. Exiting."
  exit 1
fi

if jq -e "contains([\"$VERSION_FAMILY\"])" "available-${PROJECT}.json" >/dev/null; then
  echo "Version '$VERSION_FAMILY' already exists."
else
  echo "Version '$VERSION_FAMILY' not found. Adding..."

  if jq ". + [\"$VERSION_FAMILY\"]" "available-${PROJECT}.json" > "available-${PROJECT}-updated.json"; then
    echo "Uploading updated file..."
    rsync -z --progress "available-${PROJECT}-updated.json" "filemgmt-prod-sync.jboss.org:/docs_htdocs/hibernate/_available-versions/${PROJECT}.json"
    rm -f "available-${PROJECT}-updated.json"
  else
    echo "Error: Failed to add available version '$VERSION_FAMILY'..."
    exit 1
  fi
fi

popd
