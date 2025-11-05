#!/usr/bin/env -S bash -e

function usage() {
  echo "Usage:"
  echo
  echo "  $0 [options] <project> <release_version> <development_version> <branch>"
  echo
  echo "    <project>                One of [search,validator,ogm,orm,reactive,tools,hcann,localcache,infra-*]"
  echo "    <release_version>        The version to release (e.g. 6.0.1.Final)"
  echo "    <development_version>    The new version after the release (e.g. 6.0.2-SNAPSHOT)"
  echo "    <branch>                 The branch we want to release"
  echo
  echo "  Options"
  echo
  echo "    -h            Show this help and exit."
  echo "    -d            Dry run; do not push, deploy or publish anything."
}

function needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --$opt option"; fi; }

#--------------------------------------------
# Option parsing

function exec_or_dry_run() {
  "${@}"
}
PUSH_CHANGES=true
DRY_RUN=false
USE_JRELEASER_RELEASE=false
NOTES_FILE=""

while getopts 'djh-:' opt; do
  if [ "$opt" = "-" ]; then
    # long option: reformulate opt and OPTARG
    #     - extract long option name
    opt="${OPTARG%%=*}"
    #     - extract long option argument (may be empty)
    OPTARG="${OPTARG#"$opt"}"
    #     - remove assigning `=`
    OPTARG="${OPTARG#=}"
  fi
  case "$opt" in
  h)
    usage
    exit 0
    ;;
  j)
    USE_JRELEASER_RELEASE=true
    ;;
  d)
    # Dry run
    echo "DRY RUN: will not push/deploy/publish anything."
    DRY_RUN=true
    PUSH_CHANGES=false
    export JRELEASER_DRY_RUN=true
    function exec_or_dry_run() {
      echo "DRY RUN; would have executed:" "${@}"
    }
    ;;
  notes)
    needs_arg
    NOTES_FILE="$OPTARG"
    echo "Using external notes-file : $notesFile"
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
DEVELOPMENT_VERSION=$3
BRANCH=$4
WORKSPACE=${WORKSPACE:-'.'}

pushd ${WORKSPACE}

if [ -z "$PROJECT" ]; then
	echo "ERROR: Project not supplied"
	exit 1
fi

if [ -z "$RELEASE_VERSION" ]; then
	echo "ERROR: Release version not supplied"
	exit 1
fi

if [ -z "$DEVELOPMENT_VERSION" ]; then
	echo "ERROR: Development version not supplied"
	exit 1
fi

#--------------------------------------------
# Environment variables

if [ -z "$RELEASE_GPG_PRIVATE_KEY_PATH" ]; then
  echo "ERROR: environment variable RELEASE_GPG_PRIVATE_KEY_PATH is not set"
  exit 1
fi

#--------------------------------------------
# GPG

function gpg_import() {
	local privateKeyPath="$1"
	shift
	local keyId
	keyId=$(gpg "${@}" --batch --import "$privateKeyPath" 2>&1 | tee >(cat 1>&2) | grep 'key.*: secret key imported' | sed -E 's/.*key ([^:]+):.*/\1/')
	# output the fingerprint of the imported key
	gpg "${@}" --list-secret-keys --with-colon "$keyId" | sed -E '2!d;s/.*:([^:]+):$/\1/'
}

function gpg_delete() {
	local fingerprint="$1"
	shift
	gpg "${@}" --batch --yes --delete-secret-keys "$fingerprint"
}

#--------------------------------------------
# Cleanup on exit

function cleanup() {
  if [ -n "$IMPORTED_KEY" ]; then
    echo "Deleting imported GPG private key..."
    gpg_delete "$IMPORTED_KEY" || true
  fi
  if [ -d "$RELEASE_GPG_HOMEDIR" ]; then
    echo "Cleaning up GPG homedir..."
    rm -rf "$RELEASE_GPG_HOMEDIR" || true
    echo "Clearing GPG agent..."
    gpg-connect-agent reloadagent /bye || true
  fi
}

trap "cleanup" EXIT

#--------------------------------------------
function log() {
  echo 1>&2 "$@"
}

function determineJReleaserConfigFile() {
  log "Start determining JReleaser config file..."
  local CONFIG_FILE=""
  if [ -f "./jreleaser.yml" ]; then
    # There is a jreleaser.yml in the project root. Using this configuration:
    CONFIG_FILE="./jreleaser.yml"
  else
    BRANCH_NAME=$BRANCH
    log "Current branch is: $BRANCH_NAME"

    # Reactive and Models are using a different "target" directory, hence, a different JReleaser config:
    if [ "$PROJECT" == "reactive" ] || [ "$PROJECT" == "models" ]; then
      CONFIG_FILE="$SCRIPTS_DIR/jreleaser/configuration/jreleaser_alternative.yml"
    else
      CONFIG_FILE="$SCRIPTS_DIR/jreleaser/configuration/jreleaser.yml"
    fi
  fi
  echo "$CONFIG_FILE"
}

function uploadArtifactsToCentralAndPublishToGitHub() {
	if [ -f "./jreleaser.yml" ] || [ "$USE_JRELEASER_RELEASE" == "true" ]; then
		# JReleaser-based build
		source "$SCRIPTS_DIR/jreleaser-setup.sh"

    local CONFIG_FILE=$(determineJReleaserConfigFile)

    # We are using "staged deployments" here.
    # The idea is that we first just upload the bundle do more work and then publish it.
    # The stages are controlled by the `JRELEASER_MAVENCENTRAL_STAGE` parameter.
    #
    # See also: https://jreleaser.org/guide/latest/reference/deploy/maven/maven-central.html#_staged_deployments

    if [ -f "$SCRIPTS_DIR/jreleaser/github-release-note-template/$PROJECT.tpl" ]; then
      cp "$SCRIPTS_DIR/jreleaser/github-release-note-template/$PROJECT.tpl" "$SCRIPTS_DIR/jreleaser/changelog.tpl"
    else
      cp "$SCRIPTS_DIR/jreleaser/github-release-note-template/generic.tpl" "$SCRIPTS_DIR/jreleaser/changelog.tpl"
    fi

    # determine the main body of the release notes..
    local NOTES_CONTENT=""
    if [ -n "$NOTES_FILE" -a -f "$NOTES_FILE" ]; then
      # a notes file was passed to the script - read its contents as the main content
      NOTES_CONTENT=$(cat "$NOTES_FILE")
    else
      # use the generic content
      NOTES_CONTENT="This release introduces a few minor improvements as well as bug fixes."
    fi

    local STRIPPED_SUFFIX_FOR_TAG=""
    if [ "$PROJECT" == "orm" ] || [ "$PROJECT" == "reactive" ]; then
      STRIPPED_SUFFIX_FOR_TAG=".Final"
    fi

    local RELEASE_VERSION_FAMILY=$(echo "$RELEASE_VERSION" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')
    local RELEASE_VERSION_BASIS=$(echo "$RELEASE_VERSION" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
    local RELEASE_SUFFIX=$(echo "$RELEASE_VERSION" | sed -E 's/^[0-9]+\.[0-9]+\.[0-9]+(.*)/\1/')

    local TAG_NAME=""
    if [ -n "$STRIPPED_SUFFIX_FOR_TAG" -a "$RELEASE_SUFFIX" == "$STRIPPED_SUFFIX_FOR_TAG" ]; then
      TAG_NAME=$RELEASE_VERSION_BASIS
    else
      TAG_NAME=$RELEASE_VERSION
    fi

    # we print the template into a "known" location" so that the
    # other "main" template can reference it and so that we could use properties in the release notes as well:
    #
    # but if the main template does not use the partial, we still pass the content of the notes through -P to JReleaser.
    echo "$NOTES_CONTENT" > "$SCRIPTS_DIR/jreleaser/notesContent.tpl"

    # Note: we add the "currentBranch" parameter so that the hook to push the changes to the remote is executed
    #  before JReleaser creates tags and GH releases:
		JRELEASER_MAVENCENTRAL_STAGE="UPLOAD" "$SCRIPTS_DIR/jreleaser/bin/jreleaser" full-release \
				-Djreleaser.project.version="$RELEASE_VERSION" \
				-Djreleaser.project.java.group.id=$($SCRIPTS_DIR/determine-current-project-groupid.sh $PROJECT) \
				--config-file $CONFIG_FILE \
				--basedir $(realpath $WORKSPACE) \
				-PreleaseVersionFamily="$RELEASE_VERSION_FAMILY" -PreleaseVersion="$RELEASE_VERSION" -PnotesContent="$NOTES_CONTENT" -PtagName="$TAG_NAME" -PcurrentBranch="$BRANCH"
	else
	  echo "Release cannot complete without a JReleaser configuration."
	  exit 1
	fi
}

function publishUploadedArtifactsOnCentral() {
	if [ -f "./jreleaser.yml" ] || [ "$USE_JRELEASER_RELEASE" == "true" ]; then
    local DEPLOYMENT_ID=$1
    if [ -z "$DEPLOYMENT_ID" ]; then
    	echo "ERROR: Deployment ID not supplied"
    	exit 1
    fi
    local CONFIG_FILE=$(determineJReleaserConfigFile)

    # JReleaser-based build
		source "$SCRIPTS_DIR/jreleaser-setup.sh"

    # Note that for the deploy (which should just publish the uploaded bundle on Maven Central) action
    #  we do not need to run the release-success hook, hance we don't need the `currentBranch` parameter here:
		JRELEASER_MAVENCENTRAL_STAGE="PUBLISH" JRELEASER_DEPLOY_MAVEN_MAVENCENTRAL_DEPLOYMENT_ID="$DEPLOYMENT_ID" \
		    JRELEASER_SKIP_TAG="true" JRELEASER_SKIP_RELEASE="true" "$SCRIPTS_DIR/jreleaser/bin/jreleaser" deploy \
				-Djreleaser.project.version="$RELEASE_VERSION" \
				-Djreleaser.project.java.group.id=$($SCRIPTS_DIR/determine-current-project-groupid.sh $PROJECT) \
				--config-file $CONFIG_FILE \
				--basedir $(realpath $WORKSPACE)
	fi
}

function currentDeploymentId() {
  local JRELEASER_LOG_FILE="$(realpath $WORKSPACE)/out/jreleaser/trace.log"
  local DEPLOYMENT_ID=$(grep 'Bundle .* uploaded as deployment ' $JRELEASER_LOG_FILE | awk '{print $NF}')
  log "Found the deployment id: $DEPLOYMENT_ID"
  echo "$DEPLOYMENT_ID"
}

#--------------------------------------------

#--------------------------------------------
# Actual script

# keep the RELEASE_GPG_HOMEDIR just for the sake of the old release jobs,
# if those relied on this env variable:
export RELEASE_GPG_HOMEDIR="$SCRIPTS_DIR/.gpg"
#we probably can remove the following env variable once all releases are using JReleaser:
export GNUPGHOME="$RELEASE_GPG_HOMEDIR"
# this env variable is used by JReleaser to find the keys to sing things:
export JRELEASER_GPG_HOMEDIR="$RELEASE_GPG_HOMEDIR"

mkdir -p -m 700 "$RELEASE_GPG_HOMEDIR"
IMPORTED_KEY="$(gpg_import "$RELEASE_GPG_PRIVATE_KEY_PATH")"
if [ -z "$IMPORTED_KEY" ]; then
	echo "Failed to import GPG key"
	exit 1
fi

git config --local user.name "Hibernate CI"
git config --local user.email "ci@hibernate.org"

RELEASE_VERSION_FAMILY=$(echo "$RELEASE_VERSION" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')

exec_or_dry_run bash -xe "$SCRIPTS_DIR/upload-documentation.sh" "$PROJECT" "$RELEASE_VERSION" "$RELEASE_VERSION_FAMILY"
uploadArtifactsToCentralAndPublishToGitHub
DEPLOYMENT_ID=$(currentDeploymentId)
exec_or_dry_run bash -xe "$SCRIPTS_DIR/deploy-gradle-plugin.sh" "$PROJECT"
if [ "$PROJECT" == "search" ] || [ "$PROJECT" == "validator" ]; then
  exec_or_dry_run bash -xe "$SCRIPTS_DIR/upload-distribution.sh" "$PROJECT" "$RELEASE_VERSION"
fi

exec_or_dry_run bash -xe "$SCRIPTS_DIR/update-version.sh" -m "[Jenkins release job] Preparing next development iteration" "$PROJECT" "$DEVELOPMENT_VERSION"
exec_or_dry_run bash -xe "$SCRIPTS_DIR/push-upstream.sh" "$PROJECT" "$RELEASE_VERSION" "$BRANCH" "$PUSH_CHANGES"

publishUploadedArtifactsOnCentral "$DEPLOYMENT_ID"

popd
