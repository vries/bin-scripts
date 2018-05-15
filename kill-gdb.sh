#!/bin/sh

ids=$(ps -u vries \
    | egrep 'gdb$' \
    | awk '{print $1}')

for id in $ids; do
    kill -9 $id
done
