#!/bin/bash

set -e

# script to cherry-pick range $branch..commit-$branch from repository $rep
# to local branch $lbranch, and commit to the underlying svn repository

rep="$1"
branch="$2"
lbranch="$3"
if [ "$lbranch" = "" ]; then
    lbranch="$branch"
fi

# Fetch the commit-master and base branch
git fetch -p $rep commit-$branch
git fetch -p $rep $branch

commits=$(git log --pretty=%H $rep/$branch..$rep/commit-$branch)
touch ../RECENT_COMMITS
for c in $commits; do
    if ! grep -q "diff --git.*ChangeLog" <(git show $c); then
	echo "no ChangeLog entry found in $c"
	exit 1
    fi
    if grep -q $c ../RECENT_COMMITS; then
	echo "diff between $rep $branch and commit-$branch contains" \
	    "recently pushed commit"
	exit 1
    fi
done

# Check out the local master branch, and throw away local changes.
git checkout $lbranch
git reset --hard svn/$lbranch

# Get the latest remote objects
git pull --prune || true

# Rebase on top of the latest remote changes
git svn rebase

# Copy the changes that are to be committed local
git cherry-pick $rep/$branch..$rep/commit-$branch


# for now, keep to 0, until we encounter the first actual failure
n_retry=0

# try to commit
i=0
while true; do
    if git svn dcommit; then
	break;
    fi

    if [ $i -eq $n_retry ]; then
	break;
    fi
    i=$(($i + 1))

    # There may be several reasons why the command failed.
    # We're dealing here with only one.
    git pull
    git svn rebase
done

for c in $commits; do
    echo $c >> ../RECENT_COMMITS || true
done
