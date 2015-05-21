#!/bin/bash

set -e

link_dir ()
{
    local dir="$1"
    if [ -d "$upstream/$dir" ]; then
	return
    fi

    local url
    local files
    case "$dir" in
	"dustin.bindir")
	    url="https://github.com/dustin/bindir"
	    files="git-alternate"
	    ;;
    esac

    (
	cd "$upstream"
	git clone "$url" "$dir"
    )

    local f
    for f in $files; do
	ln -fs "$upstream/$dir/$f" "$bindir"
	echo "$f" >> "$bindir/.gitignore"
    done
}

main ()
{
    bindir=$(cd $(dirname $0); pwd -P)

    upstream="$bindir/upstream"
    if [ ! -d "$upstream" ]; then
	mkdir -p "$upstream"
	echo $(basename "$upstream") >> "$bindir/.gitignore"
    fi

    link_dir "dustin.bindir"
}

main "$@"
