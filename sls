#!/bin/sh

scriptname=$(basename $0)

usage ()
{
    echo "Usage: $scriptname <machine:path>"
}

if [ $# -ne 1 ]; then
    usage
    exit 1
fi

arg="$1"

machine=$(echo "$arg" \
    | sed 's/:.*//')

path=$(echo "$arg" \
    | sed 's/.*://')    

ssh "$machine" ls "$path"
