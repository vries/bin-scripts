#!/bin/sh -x

set -e

# based on https://gcc.gnu.org/wiki/GitMirror

# create-git-with-svn --user vries --alternate /home/vries/gcc_versions/devel/src --branch gomp-4_0-branch

while [ $# -ne 0 ]; do
    case "$1" in
	"--user")
	    user="$2"
	    shift 2
	    ;;
	"--alternate")
	    alternate="$2"
	    shift 2
	    ;;
	"--branch")
	    svnbranches="$svnbranches $2"
	    shift 2
	    ;;
	*)
	    exit 1
done

if [ "$alternate" != "" ]; then
    if [ ! -d "$alternate" ]; then
	exit 1
    fi

    if [ ! -d "$alternate/.git" ]; then
	exit 1
    fi

    # script from https://github.com/dustin/bindir to add alternate
    add_alternate=git-alternate
    if ! which $add_alternate; then
	exit 1
    fi
fi

dir=gcc.git-with-svn

# remote repository origin
rep=git://gcc.gnu.org/git/gcc.git

rm -Rf $dir
mkdir $dir
cd $dir

git init

git remote add origin $rep

git config --add remote.origin.fetch 'refs/remotes/*:refs/remotes/svn/*'

if [ "$alternate" != "" ]; then
    "$add_alternate" "$alternate"
fi

git fetch

# Setup current release branches
svnbranches="$svnbranches gcc-4_9-branch gcc-4_8-branch gcc-5-branch"

# Setup trunk
svnbranches="$svnbranches trunk"

for b in $svnbranches; do
    git checkout -b $b svn/$b
done

git svn init -s --prefix=svn/ svn+ssh://$user@gcc.gnu.org/svn/gcc

git fetch

git svn rebase

gnulib-tool-install.sh git-merge-changelog
