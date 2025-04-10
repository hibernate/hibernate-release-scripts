#!/usr/bin/env -S bash -e
# To be sourced from other scripts. Tip: use the following lines to source it independently from the PWD,
# provided your script is in the same directory as this one:
#     SCRIPTS_DIR="$(readlink -f ${BASH_SOURCE[0]} | xargs dirname)"
#     source "$SCRIPTS_DIR/jreleaser-setup.sh"

if [ -d "jreleaser" ]; then
  echo "JReleaser was already set up. Skipping installation"
  ./jreleaser/bin/jreleaser --version
  return
fi

echo "About to install JReleaser."
wget https://github.com/jreleaser/jreleaser/releases/download/v1.17.0/jreleaser-1.17.0.zip -qO jreleaser.zip
unzip -qq jreleaser.zip
mv jreleaser-1.17.0 jreleaser
rm jreleaser.zip

./jreleaser/bin/jreleaser --version
