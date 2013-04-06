#!/bin/bash

FILE=$1

avconv -i "$FILE" -c:v copy -c:a libfaac -qscale:a 74 "0new-$FILE"
