#!/bin/bash

FILE=$1

# avconv -i "$FILE" -c:v copy -c:a libfaac -qscale:a 74 "0new-$FILE"
avconv -i "$FILE" -c:v copy -c:a libvo_aacenc -b:a 112k "0new-112k-$FILE"
