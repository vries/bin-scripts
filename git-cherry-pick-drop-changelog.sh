#!/bin/sh

current=$(git br \
		 | grep '^\*' \
		 | sed 's/\* //')

pick="$1"

git br pick-in-progress $pick

git ch pick-in-progress
changelogs=$(git show \
		    | grep '^diff.*ChangeLog' \
		    | awk '{print $3}' \
		    | sed 's#^a/##')

tmp=$(mktemp)
git show $changelogs > $tmp

patch -p1 -R < $tmp
rm -f $tmp
git commit --amend --no-edit $changelogs

git ch $current

git cherry-pick pick-in-progress

git br -D pick-in-progress

EDITOR='sed -i "s/git-svn-id: .*//"' git commit -e --amend
