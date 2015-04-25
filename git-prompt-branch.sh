#!/bin/sh

set -e

scriptname=$(basename $0)

echostderr ()
{
    echo "$@" \
	1>&2
}

catstderr ()
{
    cat "$@" \
	1>&2
}

usage ()
{
    echostderr "Usage: $scriptname <prompt> [ <repository dir> ]"
}

get_branch ()
{
    local prompt="$1"

    local tmp
    tmp=$(mktemp)

    git branch \
	> "$tmp"

    local nlines
    nlines=$(cat "$tmp" \
	| wc -l)

    while true; do
	catstderr -n "$tmp"

	local n
	echostderr "$prompt (1-$nlines)?"
	read -p "> " n

	if ! echo "$n" \
	    | grep -q '^[1-9][0-9]*$'; then
	    echostderr "not a valid selection: <$n>, please enter again"
	    continue	    
	fi
    
	branch=$(tail -n +$n "$tmp" \
	    | head -n 1)
	branch=$(echo "$branch" \
	    | sed 's/^\*//')
	branch=$(echo $branch)

	if  [ "$branch" = "" ]; then
	    echostderr "not a valid selection: <$n>, please enter again"
	    continue
	fi

	local confirmation
	echostderr "You chose branch: $branch. Please confirm (y/n)?"
	read -p "> " confirmation

	# Conver to lower case
	confirmation=$(echo "$confirmation" \
	    | tr '[A-Z]' '[a-z]')

	case "$confirmation" in
	    y|yes)
		break
		;;
	esac
    done

    rm -f "$tmp"

    echo "$branch"
}

main ()
{        
    local prompt="$1"
    if [ "$#" -eq 2 ]; then
	local dir="$2"
	if ! cd "$dir"; then
	    usage
	    exit 1
	fi
    elif [ "$#" -ne 1 ]; then
	usage
	exit 1
    fi

    get_branch "$prompt"
}

main "$@"
