#!/bin/bash
set -e

GIFDIR=~/gifs

tmpfile=$(mktemp --dry-run)
mkdir -p $GIFDIR

grep -oh "http[^ ]*\.gif" ~/campfire-logs/* -r | while read -r line; do
  grep -q "$line" $GIFDIR/downloaded && continue
  echo -n "Downloading gif $line... "
  if curl -s -L $line > $tmpfile; then
    sha=$(sha1sum $tmpfile | awk '{print $1}')
    echo "$line $sha" >> $GIFDIR/downloaded
    if [ ! -f "$GIFDIR/$sha.gif" ]; then
      mv $tmpfile $GIFDIR/$sha.gif
      echo
    else
      echo "Duplicated!"
    fi
  else
    echo "Failed!"
  fi
done
