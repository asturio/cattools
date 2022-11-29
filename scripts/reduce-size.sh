#!/bin/bash

function find_encoder() {
    for i in $*
    do
        if [ "$i" == "copy" ]
        then
            echo $i
            return 0
        fi
        if (ffmpeg -encoders 2> /dev/null| grep -i "^ ...[^X].. \<$i\>" > /dev/null)
        then
            echo $i
            return 0
        fi
    done
    echo No supported codec found in "'$*'">&2
}

function usage() {
cat << EOF

    Usage $SCRIPT:
     $SCRIPT [-a audio-codec] [-v video-codec] [-s] [-h] <Input-File>
        -a use a given audio codec for ffmpeg
        -v use a given video codec for ffmpeg
        -s smooth video
        -h resize video to hd720
EOF
    exit 1
}

function defineCodecs() {
    # Check if given codec is supported
    [ "x${ACODEC}" == "x" ] || ACODEC=`find_encoder ${ACODEC}`
    [ "x${VCODEC}" == "x" ] || VCODEC=`find_encoder ${VCODEC}`

    [ "x${ACODEC}" == "x" ] && ACODEC=`find_encoder libfdk_aac aac libvorbis libopus libmp3lame eac3 ac3 libtwolame`
    [ "x${VCODEC}" == "x" ] && VCODEC=`find_encoder libx264 libvpx-vp9 libvpx`
}


SUFFIX=""

while getopts a:v:sh opt
do
    case $opt in
    a)
        ACODEC=${OPTARG} ;;
    v)
        VCODEC=${OPTARG} ;;
    s)
        SMOOTH="Yes" ;;
    h)
        HD="Yes" ;;
    ?)
        usage ;;
    esac
done
shift $(($OPTIND - 1))

SCRIPT=`basename $0`
if [ $SCRIPT == "xreduce-size" ]
then
    RESPONSE=`zenity --list --checklist --title "Opções" --column "" --column "Ativar" s "Smooth" h "HD720"`
    if (echo $RESPONSE | grep Smooth > /dev/null)
    then
        SMOOTH="Yes"
    fi
    if (echo $RESPONSE | grep HD720 > /dev/null)
    then
        HD="Yes"
    fi
fi

if [ "x$SMOOTH" == "xYes" ]
then
    VFILTER="-vf hqdn3d"
    SUFFIX="${SUFFIX}-s" 
fi
if [ "x$HD" == "xYes" ]
then
    SIZE="-s hd720"
    SUFFIX="${SUFFIX}-h" 
fi

FILE=${1}
[ -f "${FILE}" ] || usage
FILESHORT=`basename "${FILE}"`

defineCodecs
echo "Using ${VCODEC}-${ACODEC}${SUFFIX}"

NEWFILE=${FILE%.*}-${VCODEC}-${ACODEC}${SUFFIX}.mkv
NEWSHORT=`basename "${NEWFILE}"`

FEEDBACK=echo
if (which notify-send > /dev/null)
then
    FEEDBACK=notify-send
fi

${FEEDBACK} Reduce-Size "Converting '${FILESHORT}' into '${NEWSHORT}'"

if [ -f "${NEWFILE}" ]
then
    ${FEEDBACK} Reduce-Size "${NEWFILE} exists already. Doing nothing."
    exit 1
fi

# TODO set some Encoder Options for the given codec to have a better quality and compression
case ${VCODEC} in
libx264)
    VCODEC="${VCODEC} -preset slow -crf 24" ;;
esac

ffmpeg -hide_banner -v info -i "${FILE}" -c:a ${ACODEC} -c:v ${VCODEC} ${VFILTER} ${SIZE} "${NEWFILE}"
RC=${?}
if [ ${RC} -ne 0 ]
then
    ${FEEDBACK} Reduce-Size "Error reducing video."
    exit 1
fi

${FEEDBACK} Reduce-Size "'${NEWSHORT}' done"
