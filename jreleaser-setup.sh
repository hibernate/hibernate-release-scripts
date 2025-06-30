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

EXPECTED_HASH="5a20df93b51654f6a06984a587e4c3595f5746b95f202b571d707315a2191efe"
JRELEASER_VERSION="1.19.0"

echo "About to install JReleaser."
wget "https://github.com/jreleaser/jreleaser/releases/download/v$JRELEASER_VERSION/jreleaser-$JRELEASER_VERSION.zip" -qO jreleaser.zip


DOWNLOADED_HASH=$(sha256sum jreleaser.zip | awk '{print $1}')
if [ "$DOWNLOADED_HASH" == "$EXPECTED_HASH" ]; then
    echo "Successfully verified the file hash"
else
    echo "Error: Failed the hash verification. Expected: $EXPECTED_HASH but got $DOWNLOADED_HASH instead"
    exit 1
fi
unzip -qq jreleaser.zip
mv "jreleaser-$JRELEASER_VERSION"/* $SCRIPTS_DIR/jreleaser
rm -r "jreleaser-$JRELEASER_VERSION"
rm jreleaser.zip

$SCRIPTS_DIR/jreleaser/bin/jreleaser --version
