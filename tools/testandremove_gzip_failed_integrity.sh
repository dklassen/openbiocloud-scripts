#!/bin/bash
bash -e 

# Test and remove and .gz files that do not pass the integrity check
# NOTE: add the removal part.

if [ -d "$1" ]; then
    find $1 -name "*.nt.gz" -print | xargs gunzip -t
fi
