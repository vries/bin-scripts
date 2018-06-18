#!/bin/bash

# This script accepts a range of git commits with commit log format:
#   input :=
#     <title line>
#     <emptyline>
#     <header>
#     [ <emptyline>
#       <preamble>
#       <hunk>
#       ( <emptyline>
#         <hunk> )* ]
#
# where header has the format:
#   header :=
#     <date> <SPACE> <SPACE> <name> <SPACE> <SPACE> <email> 
#     ( <TAB>  <SPACE>*      <name> <SPACE> <SPACE> <email> )*
#
# and hunk has the format:
#   hunk :=
#     ( <TAB> <STAR> <SPACE> <filename> <dot-terminated-multi-line> )+
#
# For each commit, it:
# - cherry-picks it to the current branch
# - updates the date in the header to the current date.
# - copies each hunk - prefixed by the header and preamble- to an appropriate
#   ChangeLog file. [ If it cannot determine the appropriate ChangeLog file, it
#   will ask the user to enter the appropriate ChangeLog file location. ]
#
# After these modifications are done, it invokes an editor for each local commit
# to inspect the result.
#

set -e

update_log_date ()
{
    local log="$1"
    local date=$(date +%Y-%m-%d)

    sed -i \
	"s/^[0-9][0-9]*-[0-9][0-9]*-[0-9][0-9]*/$date/" \
	$log
}

update_commit_log_date ()
{
    local commit="$1"
    local range="$commit^..$commit"

    local tmp
    tmp=$(mktemp)

    git log --pretty=format:%B "$range" \
	> "$tmp"
    update_log_date "$tmp"
    git commit --quiet --amend -F "$tmp"

    rm -f "$tmp"
}

files_from_commit ()
{
    local commit="$1"
    local range="$commit^..$commit"

    git log -p --pretty=format:%H "$range" \
	| grep '^diff' \
	| sed 's/^diff --git //' \
	| sed 's%^a/%%' \
	| sed 's% b/% %' \
	| sed 's/ /\n/' \
	| sort -u
}

find_changelog_for_log_hunk ()
{
    local hunk="$1"
    local files="$2"

    local hunkfiles
    # note: the grep belog has '^<TAB>\*<SPACE>' as pattern
    hunkfiles=$(grep '^	\* ' "$hunk" \
	| sed 's/\:.*//' \
	| sed 's/(.*//' \
	| sed 's/.*\* //')

    for hf in $hunkfiles; do
	local matches
	matches=$(grep -F -c "$hf" "$files" || true)
	if [ $matches -eq 1 ]; then
	    local f
	    f=$(grep -F "$hf" "$files")
	    local base
	    base=$(echo $f \
		| sed "s%$hf%%")
	    if [ base = "" ]; then
		base="."
	    else
		base=$(echo "$base" \
		    | sed 's%/$%%')
	    fi
	    if [ -f "$pwd/$base/$changelogname" ]; then
		if [ "$changelog" = "" ]; then
		    changelog="$base/$changelogname"
		else
		    if [ "$changelog" != "$base/$changelogname" ]; then
			echo "More than one changelog for hunk: $changelog and $base/$changelogname"
			changelog=""
			break
		    fi
		fi
	    else
		echo "No changelog found for hunkfile $hf at $base"
		changelog=""
		break
	    fi
	elif [ $matches -eq 0 ]; then
	    echo "No match for for hunkfile $hf in patch files"
	    changelog=""
	    break
	else
	    echo "More than one match found for hunkfile $hf in patch files:"
	    grep "$hf" "$files"
	    changelog=""
	    break
	fi
    done
}

get_changelog_for_log_hunk ()
{
    local hunk="$1"
    local files="$2"

    changelog=""

    find_changelog_for_log_hunk "$hunk" "$files"

    while [ "$changelog" = "" ]; do
	echo Could not find $changelogname for log hunk:
	cat "$hunk"
	echo please enter changelog directory, f.i. ., or gcc, or gcc/testsuite
	read dir
	if [ "$dir" != "" ] \
	    && [ -d "$pwd/$dir" ] \
	    && [ -f "$pwd/$dir/$changelogname" ]; then
	    changelog="$dir/$changelogname"
	fi
    done
    echo Using changelog: $changelog
}

prepend_file ()
{
    local a="$1"
    local b="$2"
    
    local copyb
    copyb=$(mktemp)

    cat "$b" \
	> "$copyb"

    cat "$a" \
	> "$b"
    cat "$copyb" \
	>> "$b"

    rm -f "$copyb"
}

add_log_hunk ()
{
    local header="$1"
    local preamble="$2"
    local subheader="$3"
    local hunk="$4"
    local changelog="$5"

    local partial_log
    partial_log=$(mktemp)

    cat "$header" \
	> "$partial_log"
    echo \
	>> "$partial_log"
    cat "$preamble" \
	>> "$partial_log"
    if [ -s "$subheader" ]; then
	cat "$subheader" \
	    >> "$partial_log"
	echo \
	    >> "$partial_log"
    fi
    cat "$hunk" \
	>> "$partial_log"
    echo \
	>> "$partial_log"
    
    prepend_file "$partial_log" "$pwd/$changelog"
    git commit --amend -a --no-edit --quiet

    rm -f "$partial_log"
}

do_log_hunk ()
{
    local header="$1"
    local preamble="$2"
    local subheader="$3"
    local hunk="$4"
    local files="$5"

    get_changelog_for_log_hunk "$hunk" "$files"
    add_log_hunk "$header" "$preamble" "$subheader" "$hunk" "$changelog"
}

distribute_log ()
{
    local log="$1"
    local files="$2"

    local header
    header=$(mktemp)
    local preamble
    preamble=$(mktemp)
    local subheader
    subheader=$(mktemp)
    local hunk
    hunk=$(mktemp)
    local log2
    log2=$(mktemp)

    local found_hunk=false
    local found_subheader=false

    awk '/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/{p=1};
         //{if (p) { print $0; }}
	' \
	"$log" \
	> "$log2"
    local in_header=true
    exec 3< "$log2"
    while IFS='' read -u 3 line; do
	if $in_header; then
	    if [ "$line" = "" ]; then
		in_header=false
		continue
	    else
		echo "$line" \
		    >> "$header"
	    fi
	else
	    if [ "$line" = "" ]; then
		if [ -s "$hunk" ]; then
		    do_log_hunk "$header" "$preamble" "$subheader" "$hunk" "$files"
		fi
		echo -n \
		    > "$hunk"
	    else
		if echo "$line" | egrep -q '^[	]\* '; then
		    found_hunk=true
		fi
		if $found_hunk; then
		    echo "$line" \
			>> "$hunk"
		else
		    if echo "$line" \
			| egrep -i -q '^[	][0-9][0-9][0-9][0-9]'; then
			echo "$line" \
			    > "$subheader"
		    else
			echo "$line" \
			    >> "$preamble"
		    fi
		fi
	    fi
	fi
    done

    if [ -s "$hunk" ]; then
	if $debug; then
	    echo HEADER:
	    cat $header
	    echo PREAMBLE:
	    cat $preamble
	    echo SUBHEADER:
	    cat $subheader
	    echo HUNK:
	    cat $hunk
	    echo FILES:
	    cat $files
	fi
	do_log_hunk "$header" "$preamble" "$subheader" "$hunk" "$files"
    fi

    rm -f "$header" "$preamble" "$subheader" "$hunk"
}

distribute_commit_log ()
{
    local current="$1"

    local files
    files=$(mktemp)

    files_from_commit "$current" \
	> "$files"

    local log
    log=$(mktemp)

    git log --pretty=format:%b "$current^..$current" \
	> "$log"

    distribute_log "$log" "$files"

    rm -f "$log" "$files"
}

inspect_range ()
{
    local range="$1"

    local tmp
    tmp=$(mktemp)

    local picked_commits
    picked_commits=$(git log --reverse --pretty=format:%H "$range" \
	2> /dev/null)

    local c
    for c in $picked_commits; do
	local changelogs
	changelogs=$(files_from_commit $c \
	    | grep ChangeLog)

	echo -n \
	    > "$tmp"

	echo '# Do not edit file -- temporary file only' \
	    >> "$tmp"

	echo $changelogs \
	    | sed 's/ /\n/g' \
	    >> "$tmp"
	echo \
	    >> "$tmp"

	git show "$c" $changelogs \
	    >> "$tmp"

	eval $EDITOR "$tmp"
    done

    rm -f "$tmp"
}

main ()
{
    debug=false
    changelogname=ChangeLog
    while [ $# -gt 0]; do
	if [ "$1" = "-c" ]; then
	    changelogname="$2"
	    shift 2
	    continue
	elif [ "$1" = "-d" ]; then
	    debug=true
	else
	    break
	fi
    done

    local arg="$1"
    local range
    if echo "$arg" | grep -q '\.\.'; then
	range="$arg"
    else
	range="$arg^..$arg"
    fi

    pwd=$(pwd -P)

    local head
    head=$(git rev-parse HEAD)

    local commits
    commits=$(git log --reverse --pretty=format:%H "$range" \
	2> /dev/null)

    local c
    for c in $commits; do
	git cherry-pick "$c" \
	    > /dev/null

	local current="HEAD"

	update_commit_log_date "$current"

	distribute_commit_log "$current"
    done

    inspect_range "$head..HEAD"
}

main "$@"
