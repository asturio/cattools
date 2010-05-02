#!/bin/bash

WIDTH=320
HEIGHT=240
ASPECTRATIO=4:3
FINAL_ASPECT=`echo "scale=4; ${WIDTH}/${HEIGHT}" | bc`
BITRATE=128k
ABITRATE=48k
FRAMERATE=21

INPUT=${1}
OUTPUT=`basename ${INPUT} | sed "s/\(.*\)\.[^.]*$/\1/"`.3gp

# find dimensions
ORIG_DIMENSION=`mplayer -vo null -frames 1 ${INPUT} 2> /dev/null| grep "VO:" | sed "s/.*=> \([0-9]*\)x\([0-9]*\) .*/\1:\2/"`
# echo "ORIG_DIMENSION: ${ORIG_DIMENSION}"
IWIDTH=`echo ${ORIG_DIMENSION} | cut -f 1 -d ":"`
IHEIGHT=`echo ${ORIG_DIMENSION} | cut -f 2 -d ":"`
ASPECT=`echo "scale=4; ${IWIDTH}/${IHEIGHT}" | bc`

# echo "Bring Aspect: ${ASPECT} => ${FINAL_ASPECT}"

DELTA=`echo "${ASPECT}*10000-${FINAL_ASPECT}*10000" | bc | cut -f1 -d.`
# echo "Delta: ${DELTA}"
if [ ${DELTA} -gt 0 ]
then
    OWIDTH=${WIDTH}
    OHEIGHT=`echo "${WIDTH}/${ASPECT}/2*2" | bc`
    PADTOPBOTTOM=`echo "(${HEIGHT}-${OHEIGHT})/2/2*2" | bc`
    OHEIGHT=`echo "${HEIGHT}-2*${PADTOPBOTTOM}" | bc`
    PADLEFTRIGHT=0
else
    OHEIGHT=${HEIGHT}
    OWIDTH=`echo "${HEIGHT}/${ASPECT}/2*2" | bc`
    PADLEFTRIGHT=`echo "(${WIDTH}-${OWIDTH})/2/2*2" | bc`
    OWIDTH=`echo "${WIDTH}-2*${PADLEFTRIGHT}" | bc`
    PADTOPBOTTOM=0
fi

echo "I**: Encoding Video ${INPUT} => ${OUTPUT}"
echo "I**: Scale movie to '${OWIDTH}x${OHEIGHT}'. Padding TB: ${PADTOPBOTTOM}, LR: ${PADLEFTRIGHT}"
echo "I**: Using VBitrate: ${BITRATE} and ABitrate: ${ABITRATE}"

mkdir 3gp 2> /dev/null
ffmpeg -v -1 -i ${INPUT} -vcodec libx264 -acodec libfaac -s ${OWIDTH}x${OHEIGHT} \
    -padtop ${PADTOPBOTTOM} -padbottom ${PADTOPBOTTOM} \
    -padleft ${PADLEFTRIGHT} -padright ${PADLEFTRIGHT} \
    -ab ${ABITRATE} -b ${BITRATE} \
    -aspect ${ASPECTRATIO} -r $FRAMERATE \
    3gp/${OUTPUT} 



