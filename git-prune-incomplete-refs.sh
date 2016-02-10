#!/bin/sh

set -e

refs=$(git repack -adl 2>&1 \
    | grep 'warning.*references pruned commits' \
    | awk '{print $4}' \
    | sed "s/'//g")

for f in $refs; do
    echo "Removing ref $f referencing pruned commit"
    git update-ref -d $f
done
