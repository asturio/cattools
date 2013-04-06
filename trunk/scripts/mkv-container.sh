#!/bin/bash
#
FILE=$1
L=$2

NEW=`echo $FILE | sed "s/^\(.*\)\.[^.]*$/\1/"`
TITLE="`echo $NEW| sed \"s/_/ /g\"`"

echo mkvmerge -o $NEW.mkv --title \"$TITLE\" --language 1:$L $FILE
read a
mkvmerge -o "$NEW.mkv" --title "$TITLE" --language 1:$L $FILE

