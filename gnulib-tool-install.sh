#!/bin/sh

set -e

# Based on https://gcc.gnu.org/wiki/GitMirror#git-merge-changelog

cleanup ()
{
    rm -Rf $cleanups
}

mark_for_cleanup ()
{
    local f="$1"

    trap "cleanup" 0
    trap "cleanup; exit 1" 1 2 3 5 9 13 15

    cleanups="$cleanups $f"
}

find_gnulibtool ()
{
    local f=gnulib-tool
    local systemdir=/usr/bin
    if [ -f "$systemdir/$f" ]; then
	echo "$systemdir/$f"
	return
    fi

    sudo apt-get install gnulib
    if [ -f "$systemdir/$f" ]; then
	echo "$systemdir/$f"
	return
    fi

    local tmpdir
    tmpdir=$(mktemp -d)
    mark_for_cleanup "$tmpdir"

    (
	cd "$tmpdir"
	git clone git://git.savannah.gnu.org/gnulib.git
    )

    local localdir="$tmpdir/gnulib"
    echo "$localdir/$f"
}

do_install ()
{
    local tool="$1"

    local dir
    dir=$(mktemp -d)
    mark_for_cleanup "$dir"

    local builddir="$dir/build"

    (
	cd "$dir" 
	$gnulibtool --create-testdir --dir="$builddir" "$tool"
    )

    (
	cd "$builddir"
	./configure
	make
	sudo make install
    )
}

add_setting ()
{
    local f="$1"
    local line="$2"

    if grep -q "$line" "$f"; then
	return
    fi

    echo "$line" \
	>> "$f"
}

do_tool ()
{
    local tool="$1"

    local systemdir="/usr/local/bin/"
    if [ ! -f "$systemdir/$tool" ]; then
	do_install "$tool"
    fi

    case "$tool" in
	git-merge-changelog)
	    # global settings
	    git config --global merge.merge-changelog.name \
		"GNU-style ChangeLog merge driver"
	    git config --global merge.merge-changelog.driver \
		"/usr/local/bin/git-merge-changelog %O %A %B"
	    if [ -d .git ]; then
		# local settings
		add_setting ".git/info/attributes" \
		    "ChangeLog   merge=merge-changelog"
	    fi
	    ;;
    esac
}

usage ()
{
    local scriptname=$(basename $0)
    echo "Usage: $scriptname <tool>"
    exit 1
}

list_tools ()
{
    echo gnulib tools: $($gnulibtool --list \
	| grep -v '/')
}

main ()
{
    gnulibtool=$(find_gnulibtool)

    if [ $# -ne 1 ]; then
	usage
    fi

    if ! $gnulibtool --list | grep -q "^$1$" ; then
	list_tools
	usage
    fi

    do_tool "$1"
}

main "$@"
