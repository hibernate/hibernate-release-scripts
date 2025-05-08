#!/usr/bin/env -S bash -e
# To be sourced from other scripts. Tip: use the following lines to source it independently from the PWD,
# provided your script is in the same directory as this one:
#     SCRIPTS_DIR="$(readlink -f ${BASH_SOURCE[0]} | xargs dirname)"
#     source "$SCRIPTS_DIR/jreleaser-setup.sh"

SCRIPTS_DIR="$(readlink -f ${BASH_SOURCE[0]} | xargs dirname)"

if [ -f "${SCRIPTS_DIR}/jreleaser/bin/jreleaser" ]; then
  echo "JReleaser was already set up. Skipping installation"
  $SCRIPTS_DIR/jreleaser/bin/jreleaser --version
  return
fi

echo "About to install JReleaser."
wget https://github.com/jreleaser/jreleaser/releases/download/v1.18.0/jreleaser-1.18.0.zip -qO jreleaser.zip
unzip -qq jreleaser.zip
mv jreleaser-1.18.0/* $SCRIPTS_DIR/jreleaser
rm -r jreleaser-1.18.0
rm jreleaser.zip

$SCRIPTS_DIR/jreleaser/bin/jreleaser --version
