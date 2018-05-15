#!/bin/bash

setindentstring() {
    indentstring=$(for n in $(seq 1 $indent); do \
	echo -n " "; \
	done)
}

increase_indent() {
    indent=$(($indent + $indentsize))
    setindentstring

    component=$(echo "$line" | sed 's/^BEGIN://;s/$//')
    componentindex=$(($componentindex + 1))
    components[$componentindex]="$component"
}

decrease_indent() {
    indent=$(($indent - $indentsize))
    setindentstring
    componentindex=$(($componentindex - 1))
}

pp_ics () {
    summarytmp="$1"
    descriptiontmp="$2"
    timetmp="$3"
    time2tmp="$4"
    resttmp="$5"

    componentindex=0
    indent=0
    indentsize=2
    indentstring=""
    component=""
    while IFS="" read -r line; do
	if echo "$line" | grep -q "^END:"; then
	    decrease_indent
	fi

	if [ "${components[$componentindex]}" = "VEVENT" ]; then
	    if echo "$line" | grep -q "^DESCRIPTION:";  then
		line=$(echo "$line" | \
		    sed 's/^DESCRIPTION://')
		echo -e "$line" \
		    > "$descriptiontmp"
		continue
	    fi

	    if echo "$line" | grep -q "^SUMMARY:"; then
		line=$(echo "$line" \
		    | sed 's/^SUMMARY://')
		echo "$line" \
		    >> $summarytmp
		continue
	    fi

	    if echo "$line" | grep -q '^X-ALT-DESC;FMTTYPE=text/html:'; then
		:
		continue
	    fi

	    if echo "$line" | grep -q "^DTSTART;";  then
		#DTSTART;TZID="Pacific Time":20161122T100000
		#DTEND;TZID="Pacific Time":20161122T110000

		line=$(echo "$line" | \
		    sed 's/^DTSTART;//')
		tz=$(echo $line | sed 's/^.*TZID="\(.*\)".*$/\1/')
		t=$(echo $line | sed 's/.*://')
		d=$(echo $t | sed 's/T.*//')
		t=$(echo $t | sed 's/.*T//')
		echo "timezone: $tz" >> "$timetmp"
		echo "date: ${d:0:4}-${d:4:2}-${d:6:2}" >> "$timetmp"
		echo -n "time: ${t:0:2}h${t:2:2}" >> "$timetmp"
		continue
	    fi

	    if echo "$line" | grep -q "^DTEND;";  then
		#DTSTART;TZID="Pacific Time":20161122T100000
		#DTEND;TZID="Pacific Time":20161122T110000

		line=$(echo "$line" | \
		    sed 's/^DTEND;//')
		tz=$(echo $line | sed 's/^.*TZID="\(.*\)".*$/\1/')
		t=$(echo $line | sed 's/.*://')
		d=$(echo $t | sed 's/T.*//')
		t=$(echo $t | sed 's/.*T//')

		echo -n "${t:0:2}h${t:2:2}" >> "$time2tmp"
	    fi
	fi

	echo -n "$indentstring" \
	    >> "$resttmp"
	/bin/echo -E "$line" \
	    >> "$resttmp"

	if echo "$line" | grep -q "^BEGIN:"; then
	    increase_indent
	fi
    done
}

alloc_temps () {
    tmp=$(mktemp)
    summary=$(mktemp)
    description=$(mktemp)
    time=$(mktemp)
    time2=$(mktemp)
    rest=$(mktemp)
    trap cleanup_temps EXIT
}

concat() {
    cat "$summary"

    cat "$time"
    echo -n " - " 
    cat "$time2"
    echo

    echo
    
    cat "$description"

    echo

    cat "$rest"
}

cleanup_temps() {
    rm -f "$tmp" "$summary" "$description" "$time" "$time2" "$rest"
}

main() {
    file="$1"

    alloc_temps

    cat "$file" \
	| sed ':a;/$/{N;s/\n	//;ba}' \
	| dos2unix \
	| pp_ics "$summary" "$description" "$time" "$time2" "$rest"

    concat \
	>> "$tmp"

    emacs "$tmp"
}

main "$@"
