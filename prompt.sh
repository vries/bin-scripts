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
    echostderr "Usage: $scriptname <prompt> <item>+"
}

main ()
{
    local prompt="$1"
    shift

    local tmp
    tmp=$(mktemp)

    for s in "$@"; do
	echo "$s" >> "$tmp"
    done

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
    
	choice=$(tail -n +$n "$tmp" \
	    | head -n 1)
	choice=$(echo $choice)

	if  [ "$choice" = "" ]; then
	    echostderr "not a valid selection: <$n>, please enter again"
	    continue
	fi

	local confirmation
	echostderr "You chose: $choice. Please confirm (y/n)?"
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

    echo "$choice"
}

main "$@"
