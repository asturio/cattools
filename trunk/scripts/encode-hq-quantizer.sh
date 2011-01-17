#!/bin/bash
#
# This script is optimized for encoding with a quantizer, not with filesize or
# bitrate (actually the only way to 

# {{{ Helpful comments

# RIP DVD:
# ==============
# No DVD Copy: dvdcpy -o /opt/bigdata/claudio/dvdrip/ogmrip/tmp/dvdFysN7H -m -t
# 26 /dev/scd0

# CHAPTERS info:
# ==============
# dvdxchap -t ${TRACK} /dev/dvd > ${RIPPATH}chapters.txt
# cp /mnt/dvd/video_ts/vts_01_0.ifo ${RIPPATH}

# SUBTITLES:
# ==========
# (1)
# identify subtitles:
# mplayer -sid ${SID} ${RIPPATH}movie.vob
# Rip subtitles:
# tccat -i ${RIPPATH}movie.vob -L | tcextract -x ps1 -t vob -a ${HEXSID} > ${RIPPATH}subs-${SID}
# subtitle2vobsub -o ${RIPPATH}vobsubs -i ${RIPPATH}vts_01_0.ifo -a ${SID}< ${RIPPATH}subs-${SID}
# Check subtitle id:
# mkdir ${RIPPATH}${SID}
# subtitle2pgm -o ${RIPPATH}${SID}/${SID} -c 255,0,0,255 < ${RIPPATH}subs-${SID}
#
# or (2)
# mencoder -nocache -nosound -of rawaudio -ovc copy -o /dev/null -vobsubout /tmp/sub.AFV8OU -vobsuboutindex 0 -sid 0 -dvd-device /opt/bigdata/claudio/dvdrip/vdr/dvdJK8As0 dvd://1
# subp2pgm /tmp/sub.AFV8OU
# ocrad -v -f -F utf8 -l 0 -o /tmp/sub.AFV8OU0247.pgm.txt /tmp/sub.AFV8OU0247.pgm
# processing file `/tmp/sub.AFV8OU0247.pgm'
# ocrad -v -f -F utf8 -l 0 -o /tmp/sub.AFV8OU0049.pgm.txt /tmp/sub.AFV8OU0049.pgm
# processing file `/tmp/sub.AFV8OU0049.pgm'
# ocrad -v -f -F utf8 -l 0 -o /tmp/sub.AFV8OU0440.pgm.txt /tmp/sub.AFV8OU0440.pgm
# processing file `/tmp/sub.AFV8OU0440.pgm'

# }}}

# TODO: mplayer with start and endtime
#set -x
export LANG=C

# Defaults
# New select if container is mkv (h264+ogg) or avi (xvid+mp3)
export CONTAINER=avi
export QUANTIZER=2
export SCALEFACTOR=1

logAndRun() {
    echo "[`date --iso-8601=seconds`] $@" >> ${COMMANDS}
    $@
}

parseOpts() {
    args=`getopt -n encode-hq.sh -o x:t:a:d:D:T:q:c:z:w:IRh -- "$@"`
    if [ $? -ne 0 ]
    then
        usage
    fi

    eval set -- "$args"
    while [ "${1}" ]
    do
        case "${1}" in
        "--") INPUT=${2}; shift # Input file NEEDED
              [ "${INPUT}" ] && CONFIG=`basename ${INPUT}`.conf
              break
            ;;
        esac
        shift
    done
    [ -z "${INPUT}" -o ! -s "${INPUT}" ] && echo "Input Needed!" && usage

    readConfig
    eval set -- "$args"
    while [ "${1}" ]
    do
        case "${1}" in
        "-x") CROP=${2}; shift # Crop
            writeOpt CROP "${CROP}"
            ;;
        "-t") NAME=${2}; shift # Title
            writeOpt NAME "${NAME}"
            ;;
        "-a") TRACKS="${TRACKS} ${2}"; shift # Audio Tracks
            writeOpt TRACKS "${TRACKS}"
            ;;
        "-d") DVD="-dvd-device ${2}"; shift
            ;;
        "-D") DELAY="${2}"; shift
            ;;
        "-T") DVDTITLE=${2}; shift # Title
            ;;
        "-q") QUANTIZER=${2}; 
            writeOpt QUANTIZER "${QUANTIZER}"
            shift # Quantizer
            ;;
        "-c") CONTAINER=${2}; shift # Container
            writeOpt CONTAINER "${CONTAINER}"
            ;;
        "-z") 
            SCALEFACTOR=${2}; 
            unset SCALEWIDTH; 
            shift # SCALEFACTOR
            writeOpt SCALEFACTOR "${SCALEFACTOR}"
            writeOpt SCALEWIDTH ""
            ;;
        "-w") 
            SCALEWIDTH=${2}; 
            SCALEFACTOR=1;
            shift # SCALE Width
            writeOpt SCALEWIDTH "${SCALEWIDTH}"
            writeOpt SCALEFACTOR "1"
            ;;
        "-I") getDVDInfos
            ;;
        "-R") rippDVD
            ;;
        "-h") usage
            ;;
        esac
        shift
    done
}

readConfig() {
    # Everything that is not generatet after parsing options should have a
    # default value.
    CONTAINER=`readOpt CONTAINER "${CONTAINER}"`
    NAME=`readOpt NAME "${NAME}"`
    QUANTIZER=`readOpt QUANTIZER "${QUANTIZER}"`
    SCALEFACTOR=`readOpt SCALEFACTOR "${SCALEFACTOR}"`
    SCALEWIDTH=`readOpt SCALEWIDTH "${SCALEWIDTH}"`
    TRACKS=`readOpt TRACKS "${TRACKS}"`

    # These will be calculated in the program.
    AUDIO=`readOpt AUDIO`
    AUDIOSIZE=`readOpt AUDIOSIZE`
    CROP=`readOpt CROP` 
    ESTIMATESECONDS=`readOpt ESTIMATESECONDS`
    VIDEO=`readOpt VIDEO`
    WORKDIR=`readOpt WORKDIR`
}

displayVariables() {
    echo "Using these parameters:"
    echo -n "C:'${CONTAINER}' " 
    echo -n "N:'${NAME}' "
    echo -n "Q:'${QUANTIZER}' "
    echo -n "SF:'${SCALEFACTOR}' "
    echo -n "SW:'${SCALEWIDTH}' "
    echo -n "T:'${TRACKS}' "

    echo -n "A:'${AUDIO}' "
    echo -n "AS:'${AUDIOSIZE}' "
    echo -n "ES:'${ESTIMATESECONDS}' "
    echo -n "V:'${VIDEO}' "
    echo -n "CROP:'${CROP}' "
    echo -n "WD:'${WORKDIR}' " 
    echo -n "FILE:'${FILENAME}' " 
    echo "" # EOL
    echo "" # NL
}

initialize() {
    if [ -z "${WORKDIR}" ]
    then
        WORKDIR=work-$$
        writeOpt WORKDIR "${WORKDIR}"
    fi
    LOGDIR=${WORKDIR}/logs

    [ -d ${LOGDIR} ] || mkdir -p ${LOGDIR}
    IDENTIFY=${LOGDIR}/00-identify.txt 
    CROPLOG=${LOGDIR}/01-cropdetect.log
    MPLAYERAUDIOLOG=${LOGDIR}/02-mplayer-audio.log
    AUDIOENCLOG=${LOGDIR}/03-audioenc.log
    VIDEOLOG=${LOGDIR}/04-video.log
    MERGELOG=${LOGDIR}/05-merge.log
    COMMANDS=${LOGDIR}/commands.txt

    [ "${NAME}" ] || NAME=${INPUT}
    FILENAME=`echo ${NAME} | tr " 	" "__"`
    if [ "${CONTAINER}" = "avi" ]
    then
        FILENAME="${FILENAME}.avi"
    else
        FILENAME="${FILENAME}.mkv"
    fi
    if [ -s "${FILENAME}" ]
    then
        FILENAME="${FILENAME}.new"
    fi
    [ "${TRACKS}" ] || TRACKS=0
}

checkbins() {
    BINS="mplayer mencoder oggenc mkvmerge mkfifo lame" # Avibox
    for i in ${BINS}
    do
        BIN=`which ${i}`
        if [ -z "${BIN}" ]
        then
            echo "${i} not found: Please install."
            exit
        fi
    done
}

usage() {
    echo "Usage:
    `basename ${0}` <input-file> -x <crop> -t <title> -z <scalefactor> -a <audio id> -d <dvd-dev> -IR
    Ex.: ${0} -i VR_MOVIE.VRO -S 260000 -E 2:00:40 -s 700 -t \"Movie Name\"
    <input-file> - The file to encode. MANDATORY.
    -x <crop>       - Crop with xxx:yyy:aa:bb. If not given, than autocrop.
    -t <name>       - The name of the Movie.
    -a <audio id>   - The id of the audio track to encode, multiple -a
                      are allowed. The order will be preserved
    -d <dvd-device> - Set the DVD-Device. Used with -I or -R
    -D <delay>      - Audio Delay to use
    -T <title>      - Title number in DVD for use with -R and -I
    -q              - Quantizer (the lower the better, default 2)
    -c              - Container type (avi or mkv). By now only with
    -z              - Scalefactor: scale width with this factor, should be between 0 and 1).
    -w              - Scalewidth: select this width for the movie. 
    -I              - Gatter DVD Information
    -R              - Rip a DVD-Title.
    -h              - This help
    "
    exit 0
}

readOpt() {
    RET=""
    if [ -s ${CONFIG} ]
    then
        RET=`grep "^${1}=" ${CONFIG} | sed "s|^${1}=||"`
    fi
    if [ "${RET}" ] 
    then
        echo ${RET}
    else
        echo ${2}
    fi
}

writeOpt() {
    if [ -s ${CONFIG} ]
    then
        grep -v "^${1}=" ${CONFIG} > ${CONFIG}.tmp
    fi
    [ "${2}" ] && echo "${1}=${2}" >> ${CONFIG}.tmp
    mv ${CONFIG}.tmp ${CONFIG}
}

detectCropByTime() {
    # Since 4.4.3 not working with -sb Startbyte     GRRRRRRRrrrr
    MPLAYERCROP="-nolirc -vo null -nosound -nocache -vf cropdetect -frames 12 -speed 100"
    if [ -z "${ESTIMATESECONDS}" ]
    then
        ESTIMATESECONDS=`grep ID_LENGTH ${IDENTIFY} | cut -f2 -d= | cut -f1 -d.`
        writeOpt ESTIMATESECONDS "${ESTIMATESECONDS}"
    fi
    [ "${ESTIMATESECONDS}" ] || return 1
    STEPS=`echo ${ESTIMATESECONDS}/10 | bc`
    echo "Detecting CROP by time. Analysing one frame every ${STEPS} seconds. Movie Lenght: ${ESTIMATESECONDS}"
    # myStartPos=0
    # myEndPos=${ESTIMATESECONDS}
    rm -f ${CROPLOG}
    CMD="mplayer ${MPLAYERCROP} -sstep ${STEPS} ${INPUT}"
    logAndRun ${CMD} > ${CROPLOG} 2>&1
    CROP=`grep "crop=" ${CROPLOG} | tail -1 | cut -f2 -d= | cut -f1 -d")"`
    x=`echo ${CROP} | cut -f 1 -d:`
    y=`echo ${CROP} | cut -f 2 -d:`
    if [ ${x} -gt 0 -a ${y} -gt 0 ]
    then
        writeOpt CROP "${CROP}"
    else 
        CROP=""
    fi
}

detectCrop() {
    # Find Crop:
    [ -z "${CROP}" ] && detectCropByTime

    if [ -z "${CROP}" ]
    then
        echo "CROP could not be detected. Try to detect it manualy using"
        echo " mplayer -vf cropdetect and "
        echo " mplayer -vf retangle=<CROP>"
        echo " Then pass the crop to the script using the -x option."
        exit 1
    fi
    echo " Cropping to ${CROP}"
}

encodeAudio() {
    # Explanation: {{{
    # -nolirc = turn off lirc (remote control) support
    # -nocache = turn off caching
    # -noframedrop = read all the frames
    # -mc 0 = no A/V-sync correction
    # -vc null = no video codec (don't decode video)
    # -vo null = no video output
    # -ao pcm:nowaveheader:file=fifo = output raw-audio to a file
    # -af volnorm=1 = normalize audio volume
    # -channels 2 = play audio in to channels
    # (unused: only DVD) -aid 137 = Audio ID, to play the right language }}}
    MPLAYEROPTS="-nolirc -nocache -noframedrop -mc 0 -vc null -vo null -af volnorm=1 -channels 2"
    FIFO=${WORKDIR}/audio.fifo
    if [ "${CONTAINER}" == "avi" ]
    then
        [ -z "${AUDIO}" ] && AUDIO=audio.mp3 && writeOpt AUDIO "${AUDIO}"
    else
        [ -z "${AUDIO}" ] && AUDIO=audio.ogg && writeOpt AUDIO "${AUDIO}"
    fi

    rm -f ${WORKDIR}/audio.fifo

    [ "${AUDIOSIZE}" ] || AUDIOSIZE=0
    for track in ${TRACKS}
    do
        OUTPUT=${WORKDIR}/$track-${AUDIO}
        RC=`readOpt ${OUTPUT}`
        if [ "${RC}" == "Done" -a -s ${OUTPUT} ]
        then
            echo "Audio ${OUTPUT} present, skiping encoding."
        else
            echo "Encoding Audio track $track."
            [ "$track" -ne "0" ] && AID="-aid $track"

            logAndRun mkfifo ${FIFO}

            CMD="mplayer ${MPLAYEROPTS} ${AID} -ao pcm:fast:waveheader:file=${FIFO} ${INPUT}"
            logAndRun ${CMD} >> ${MPLAYERAUDIOLOG} 2>&1 &

            if [ "${CONTAINER}" == "avi" ]
            then
                MP3ENCOPTS="--nohist -v -V 6 -h"
                ENCODER="lame ${MP3ENCOPTS} ${FIFO} ${OUTPUT}"
            else
                OGGENCOPTS="-q 4"
                ENCODER="oggenc ${OGGENCOPTS} -o ${OUTPUT} ${FIFO}"
            fi
            logAndRun ${ENCODER} >> ${AUDIOENCLOG} 2>&1
            [ $? -eq 0 ] && writeOpt ${OUTPUT} "Done"
            logAndRun rm ${FIFO}
            sumAudioSize ${OUTPUT}
        fi
    done
}

sumAudioSize() {
    tAUDIOSIZE=`ls -l ${1} | awk '{print $5}'`
    AUDIOSIZE=`echo "scale=2;${AUDIOSIZE}+${tAUDIOSIZE}/1024/1024" | bc`
    if [ "${AUDIOSIZE}" == "0" ]
    then
        echo "Error: Audio not encoded"
        exit 1
    fi

    echo " Audio size is now ${AUDIOSIZE} Mb"
    writeOpt AUDIOSIZE "${AUDIOSIZE}"
}

getAspect() {
    ASPECT=`grep ID_VIDEO_ASPECT ${IDENTIFY} | cut -f 2 -d = | cut -f 1 -d .`
    NUMERATOR=1
    DENOMINATOR=1
    case ${ASPECT} in
        "0")
            NUMERATOR=4
            DENOMINATOR=3
            ;;
        "1"|"3")
            NUMERATOR=16
            DENOMINATOR=9
            ;;
    esac
}

setScale() {
    # Scale without a bitrate
    RAW_W=`grep ID_VIDEO_WIDTH ${IDENTIFY} | cut -f 2 -d =`
    RAW_H=`grep ID_VIDEO_HEIGHT ${IDENTIFY} | cut -f 2 -d =`
    getAspect
    CROP_W=`echo ${CROP} | cut -f 1 -d :`
    CROP_H=`echo ${CROP} | cut -f 2 -d :`

    # ratio = crop_width / (gdouble) crop_height * raw_height / raw_width * anumerator / adenominator;
    RATIO=`echo "scale=4; ${CROP_W} / ${CROP_H} * ${RAW_H} / ${RAW_W} * ${NUMERATOR} / ${DENOMINATOR}" | bc `
    echo "Video info: ${RAW_W}x${RAW_H} (${NUMERATOR}:${DENOMINATOR}) crop ${CROP_W}x${CROP_H} ratio: ${RATIO}"

    SCALE_W=${CROP_W}
    [ -n "${SCALEWIDTH}" ] && [ ${SCALEWIDTH} -lt ${CROP_W} ] && SCALE_W=${SCALEWIDTH}
    SCALE_H=`echo "${SCALE_W}/${RATIO}/16*16" | bc`
    echo "Normal scaling to: ${SCALE_W} x ${SCALE_H}"

    SCALE_W=`echo ${SCALE_W}*${SCALEFACTOR}/16*16 | bc` 
    SCALE_H=`echo "${SCALE_W}/${RATIO}/16*16" | bc`
    echo "Factor (${SCALEFACTOR}) scaling to: ${SCALE_W} x ${SCALE_H}"

    SCALE="${SCALE_W}:${SCALE_H}"
}

encodeVideo() {
    [ -z "${VIDEO}" ] && VIDEO=${WORKDIR}/video.avi && writeOpt VIDEO "${VIDEO}"

    # Explanation: {{{
    # -nocache = set no cache
    # -noslices = draw frame at once
    # -oac pcm = convert audio to pcm
    # -srate 8000 = with bis bitrate
    # -af channels=1,lavcresample=8000   = mono audio with 8000 Hz
    # -sws 7 = for zoom use gauss
    # -zoom = do software scaling
    # -mc 0 = no A/V sync delta
    # -ovc x264 = encode video with x264
    # }}}
    MENCODEROPTS="-nocache -noslices -noconfig all -oac pcm -srate 8000 -af channels=1,lavcresample=8000 -sws 7 -zoom -mc 0 "

    # hqdn3d=2:1:2 = High Quality/Precision Denoise (better compression, smooth images)
    # harddup = don't drop duplicate frames.
    # SCALE removed from vf "-vf scale..."
    VFILTER="crop=${CROP},hqdn3d=2:1:2,harddup"
    [ "${SCALE}" ] && VFILTER="${VFILTER},scale=${SCALE}"

    if [ "${CONTAINER}" == "avi" ] 
    then
        XVIDOPTS="quant_type=h263:chroma_opt:vhq=2:bvhq=1:autoaspect:max_bframes=2:noqpel:trellis:nogreyscale:fixed_quant=${QUANTIZER}:threads=2"
        CODECOPTS="-ovc xvid -xvidencopts ${XVIDOPTS}"
    else
    # Explanation: {{{
    # subq=5 = good quality subpel. encode a bit faster. subpel Qualy.
    # b_pyramid = Use B-Frames as references to predict next frames. Increases compresssion 
    #   (CHANGED in new mplayer)
    # weight_b = use weighted B-Frames
    # 8x8dct = Allow macroblock to chose between 8x8 and 4x4. Compress better
    # frameref=2 = Use 2 Frames to Predict B- and P-frames. OK Quality
    # partitions=p8x8,b8x8,i8x8,i4x4 = enable optional macroblock types
    # trellis=1 = Enable rate-distortion optimal quantization for final encode
    # bframes=2 = maximum 2 B-frames between I- and P-Frames (Better quality)
    # bitrate=${BITRATE} = the target video bitrate
    # direct_pred=auto = Type of motion prediction. spatial and temporal choice for each frame 
    # deblock=-1,-1 = deblock filter
    # b_adapt=2 = How many b-frames will be used to reach bframes
    # me=umr = Fullpixel motion detection algorithm.
    # merange=16 = Radius for me=umr
    # }}}
        XQUANT=`echo "scale=1; 12+6*l(${QUANTIZER})/l(2)" | bc -l`
        X264OPTS="deblock=-1,-1:subq=8:direct_pred=auto:frameref=5:b_adapt=2:me=umh:merange=16:rc_lookahead=50:bframes=3:trellis=1"
        # From http://www.mplayerhq.hu/DOCS/HTML/en/menc-feat-x264.html
        X264OPTS="subq=5:8x8dct:frameref=3:bframes=3:b_pyramid:weight_b"
        X264OPTS="${X264OPTS}:crf=${XQUANT}:threads=2"
        CODECOPTS="-ovc x264 -x264encopts ${X264OPTS}"
    fi

    # Enplanation: Put all together
    MENCODEROPTS="${MENCODEROPTS} ${CODECOPTS}"

    # Encode Video
    VIDEODONE=`readOpt ${VIDEO}`
    if [ "${VIDEODONE}" == "Done" -a -s ${VIDEO} ]
    then
        echo "Video already done. Skipping."
    else
        VIDEODONE=""
        echo "ENCONDING the video..."
        CMD="mencoder ${MENCODEROPTS} -vf ${VFILTER} -o ${VIDEO} ${INPUT}"
        logAndRun ${CMD} > ${VIDEOLOG} 2>&1
        [ $? -eq 0 ] && writeOpt ${VIDEO} "Done" && VIDEODONE=Done
    fi
}

mergeStream() {
# Explanation: {{{
# -d 0 = copy video Track 0
# -A = no Audio
# -S = no subs
# -D = no video
# --language 0:ger = Audio stream 0 is german (can be used more times)
# --sync 0:-100 Delay Audio in -100 ms (skip 100ms of video frames) }}}
    if [ "${VIDEODONE}" == "Done" ]
    then
        echo "Merging streams"
        MERGEOPTS="-o ${FILENAME} --command-line-charset UTF-8 -d 0 -A -S ${VIDEO}"
        AUDIOCODE=""
        for track in ${TRACKS}
        do
            lang=`getLanguageOfTrack $track`
            if [ "${CONTAINER}" == "avi" ]
            then
                AUDIOCODE="${AUDIOCODE} ${WORKDIR}/$track-${AUDIO}"
            else
                AUDIOCODE="${AUDIOCODE} --language 0:$lang --sync 0:${DELAY} -D -S ${WORKDIR}/$track-${AUDIO}"
            fi
        done
        if [ "${CONTAINER}" == "avi" ]
        then
            MERGER=`which avibox`
            if [ "$MERGER" ] 
            then
                MERGER="avibox -o ${FILENAME} -n -i ${VIDEO} ${AUDIOCODE}  -f XVID"
            else
                MERGER="mencoder -o ${FILENAME} -mc 0 -noskip -ovc copy -oac copy -audiofile ${AUDIOCODE} ${VIDEO}"
            fi
        else
            MERGER="mkvmerge ${MERGEOPTS} ${AUDIOCODE} --title \"${NAME}\""
        fi
        logAndRun ${MERGER} > ${MERGELOG} 2>&1
    fi
}

getDVDInfos() {
    if [ ! -s mapping-${DVDTITLE}.txt ]
    then
        echo "Getting DVD Language Mapping for Title ${DVDTITLE}"
        mplayer -frames 2 -vo null -ao null -identify ${DVD} dvd://${DVDTITLE} 2> /dev/null | grep "^ID_" > mapping-${DVDTITLE}.txt
    fi
    exit 0
}

getStreamInfos() {
    if [ ! -s ${IDENTIFY} ]
    then
        echo "Getting Stream Infos"
        mplayer -frames 0 -vo null -ao null -identify ${INPUT} 2> /dev/null | grep "^ID_" > ${IDENTIFY}
    fi
}

getLanguageOfTrack() {
    if [ -s mapping-${DVDTITLE}.txt ]
    then
        grep "ID_AID_${1}_LANG=" mapping-${DVDTITLE}.txt | cut -f 2 -d=
    else
        echo "de"
    fi
}

rippDVD() {
    mplayer -dumpstream -noframedrop -nocache -dumpfile dvddump-${DVDTITLE}.vob ${DVD} dvd://${DVDTITLE} 
    getDVDInfos
}

DELAY=0

# do work

checkbins

parseOpts "$@"

initialize

displayVariables

getStreamInfos

detectCrop

setScale

encodeAudio

encodeVideo

mergeStream

# vim:set foldmethod=marker:
