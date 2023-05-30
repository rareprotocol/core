#!/bin/bash

# This finds all the .sol files in the `src` directory and then copies over the ABIs
# asscociated with those files
find src -type f -exec basename {} \; | sed 's/\.[^.]*$//' |  awk '{ printf "%s.json\n", $0 }' | \
while IFS= read -r filename; do
    find out/ -type f -name "$filename" -exec cp {} abis/ \;
done 