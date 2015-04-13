#!/bin/bash
#
FILE=$1
L=$2

NEW=`echo $FILE | sed "s/^\(.*\)\.[^.]*$/\1/"`
if [ "x$3" = "x" ]
then
    TITLE="`echo $NEW| sed \"s/_/ /g\"`"
else
    TITLE="`echo $3| sed \"s/_/ /g\"`"
fi

echo mkvmerge -o $NEW.mkv --title \"$TITLE\" --language 1:$L $FILE
read a
mkvmerge -o "$NEW.mkv" --title "$TITLE" --language 1:$L $FILE

