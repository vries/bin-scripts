#!/bin/sh

base="$1"

if echo "$base" | grep -q '\.\.'; then
    range="$1"
else
    range="$base..HEAD"
fi

commits=$(git log --reverse --pretty=%h "$range")

n=1
for ch in $commits; do
    cr="$ch^..$ch"

    fnr=$(printf "%.4u" $n)
    fnm=$(git log --pretty=%f "$cr")
    f=$fnr-$fnm.patch

    echo "$f"
    rm -f "$f"

    git log -p --stat --pretty=%B "$cr" >> "$f"

    n=$(($n + 1))
done
