#!/bin/sh

set -e

# Based on https://gcc.gnu.org/wiki/GitMirror#git-merge-changelog

cleanup ()
{

    if [ "$cleanups" != "" ]; then
	rm -Rf $cleanups
    fi

    if [ "$keeps" != "" ]; then
	echo "Kept dirs: $keeps"
    fi
}

install_cleanup ()
{
    trap "cleanup" 0
    trap "cleanup; exit 1" 1 2 3 5 9 13 15
}

mark_for_cleanup ()
{
    local f="$1"

    install_cleanup

    cleanups="$cleanups $f"
}

mark_to_keep ()
{
    local f="$1"

    install_cleanup

    keeps="$keeps $f"
}

find_gnulib ()
{
    local f=gnulib-tool
    local d=gnulib

    local systembindir=/usr/bin
    local systemlibdir=/usr/share

    if [ -f "$systembindir/$f" ] \
	&& [ -d "$systemlibdir/$d" ]; then
	 "$systemdir/$f"
	 gnulibtool="$systembindir/$f"
	 gnulib="$systemlibdir/$d"
    fi

    sudo apt-get install gnulib
    if [ -f "$systembindir/$f" ] \
	&& [ -d "$systemlibdir/$d" ]; then
	 "$systemdir/$f"
	 gnulibtool="$systembindir/$f"
	 gnulib="$systemlibdir/$d"
    fi

    local tmpdir
    tmpdir=$(mktemp -d)
    mark_for_cleanup "$tmpdir"

    (
	cd "$tmpdir"
	git clone git://git.savannah.gnu.org/gnulib.git
    )

    gnulib="$tmpdir/gnulib"
    gnulibtool="$gnulib/$f"
}

do_install ()
{
    local tool="$1"

    local dir
    dir=$(mktemp -d)
    if ! $keep; then
	mark_for_cleanup "$dir"
    else
	mark_to_keep "$dir"
    fi

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

is_tool ()
{
    local tool="$1"
    if $gnulibtool --list \
	| grep -q "^$tool$" ; then
	return 0
    fi

    return 1
}

main ()
{
    find_gnulib

    keep=false
    if [ "$1" = "--keep" ]; then
	keep=true
	shift
    fi

    if [ $# -ne 1 ]; then
	usage
    fi
    local tool="$1"

    if ! is_tool "$tool"; then
	list_tools
	usage
    fi

    do_tool "$tool"
}

main "$@"
