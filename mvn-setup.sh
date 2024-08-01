#!/usr/bin/env -S bash -e
# To be sourced from other scripts. Tip: use the following lines to source it independently from the PWD,
# provided your script is in the same directory as this one:
#     SCRIPTS_DIR="$(readlink -f ${BASH_SOURCE[0]} | xargs dirname)"
#     source "$SCRIPTS_DIR/mvn-setup.sh"

if (( $NOORM_MAVEN_SETUP )); then
  echo "Maven was already set up."
  return
fi
NOORM_MAVEN_SETUP=1

DEFAULT_SETTINGS_XML="$HOME/.m2/settings-search-release.xml"
if ! [ -e "$DEFAULT_SETTINGS_XML" ]; then
  DEFAULT_SETTINGS_XML=""
fi
SETTINGS_XML="${SETTINGS_XML:-$DEFAULT_SETTINGS_XML}"

if [ -n "$SETTINGS_XML" ]; then
  # Necessary for older versions of projects, whose repository URLs might still use HTTP (not HTTPS).
  echo "Using Maven settings '$SETTINGS_XML'"
  export MAVEN_OPTS="$MAVEN_OPTS -s $SETTINGS_XML"
else
  # Should be safe in newer versions of projects.
  echo "Using default Maven settings"
fi

if ! [ -e "mvnw" ]; then
  # Only necessary in projects that do not have mvnw checked into their git repository.
  mvn -N wrapper:wrapper -Dmaven=3.5.2
fi
