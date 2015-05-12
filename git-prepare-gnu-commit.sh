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
	matches=$(grep -c "$hf" "$files" || true)
	if [ $matches -eq 1 ]; then
	    local f
	    f=$(grep "$hf" "$files")
	    local base
	    base=$(echo $f \
		| sed "s%$hf%%")
	    if [ base = "" ]; then
		base="."
	    else
		base=$(echo "$base" \
		    | sed 's%/$%%')
	    fi
	    if [ -f "$pwd/$base/ChangeLog" ]; then
		if [ "$changelog" = "" ]; then
		    changelog="$base/ChangeLog"
		else
		    if [ "$changelog" != "$base/ChangeLog" ]; then
			echo "More than one changelog for hunk: $changelog and $base/ChangeLog"
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
	    echo "More than one match found for hunkfile $hf in patch files"
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
	echo Could not find ChangeLog for log hunk:
	cat "$hunk"
	echo please enter changelog directory, f.i. ., or gcc, or gcc/testsuite
	read dir
	if [ "$dir" != "" ] \
	    && [ -d "$pwd/$dir" ] \
	    && [ -f "$pwd/$dir/ChangeLog" ]; then
	    changelog="$dir/ChangeLog"
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
    local hunk="$3"
    local changelog="$4"

    local partial_log
    partial_log=$(mktemp)

    cat "$header" \
	> "$partial_log"
    echo \
	>> "$partial_log"
    cat "$preamble" \
	>> "$partial_log"
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
    local hunk="$3"
    local files="$4"

    get_changelog_for_log_hunk "$hunk" "$files"
    add_log_hunk "$header" "$preamble" "$hunk" "$changelog"
}

distribute_log ()
{
    local log="$1"
    local files="$2"

    local header
    header=$(mktemp)
    local preamble
    preamble=$(mktemp)
    local hunk
    hunk=$(mktemp)

    local found_hunk=false

    local in_header=true
    exec 3< "$log"
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
		do_log_hunk "$header" "$preamble" "$hunk" "$files"
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
		    echo "$line" \
			>> "$preamble"
		fi
	    fi
	fi
    done

    if [ -s "$hunk" ]; then
	do_log_hunk "$header" "$preamble" "$hunk" "$files"
    fi

    rm -f "$header" "$preamble" "$hunk"
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

	$EDITOR "$tmp"
    done

    rm -f "$tmp"
}

main ()
{
    local arg="$1"

    local range
    if echo "$range" | grep -q '\.\.'; then
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
