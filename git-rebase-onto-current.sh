#!/bin/bash -x

set -e

branch="$1"

git cherry-pick --abort || true

onto=$(git br | grep '^\*' | awk '{print $2}')

tmpbranch="rebasing-$branch"

git br "$tmpbranch"

git ch "$tmpbranch"

if ! git cherry-pick $onto..$branch; then
    bash
    while ! git cherry-pick --continue; do
	bash
    done
fi

git br -D "$branch"

git br -m "$branch"
