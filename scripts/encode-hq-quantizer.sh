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

# TODO: mplayer with start and endtime.
# TODO: converting avi2mkv: Problem with detect crop. and Aspect.
#set -x
export LANG=C

# Defaults
# New select if container is mkv (h264+ogg) or avi (xvid+mp3)
export CONTAINER=avi
export QUANTIZER=2
export SCALEFACTOR=1

logAndRun() {
    echo "[`date --iso-8601=seconds`] $@" >> ${COMMANDS}
    "$@"
    [ $? -eq 0 ] || (echo "ERROR: Aborting" && exit 1)
}

parseOpts() {
    args=`getopt -n $0 -o x:t:a:D:q:c:z:w:iIRT:d:h -- "$@"`
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
        "-I"|"-R")
            RIP=1
            break;
            ;;
        esac
        shift
    done

    if [ -z "${RIP}" ]
    then
        if [ -z "${INPUT}" -o ! -s "${INPUT}" ] 
        then
            echo "Input Needed!"
            usage
        fi
    fi

    [ "${INPUT}" ] && readConfig

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
        "-D") DELAY="${2}"; shift
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
        "-i")
            DEINTERLACE="pp=md"
            ;;

        # DVD-Rip
        "-I") getDVDInfos
            ;;
        "-R") rippDVD
            ;;
        "-T") DVDTITLE=${2}; shift # Title
            ;;
        "-d") DVD="-dvd-device ${2}"; shift
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
    echo -n "DEINT:'${DEINTERLACE}' " 
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
    SCALELOG=${LOGDIR}/03a-scalelog.log
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
    `basename ${0}` <input-file> -x <crop> -t <title> -a <audio id> -D <delay> -q <qual> -c <mkv|avi> -z <factor> -w <width> -i -IR -T <dvd-title> -d <dvd-device> -h
    Ex.: ${0} VR_MOVIE.VRO -t \"Movie Name\" -q 3 -c mkv
    <input-file>    - The file to encode. MANDATORY.
    -x <crop>       - Crop with xxx:yyy:aa:bb. If not given, than autocrop.
    -t <title>      - The name of the Movie.
    -a <audio id>   - The id of the audio track to encode, multiple -a
                      are allowed. The order will be preserved
    -D <delay>      - Audio Delay to use
    -q <qual>       - Quantizer (1-31, the lower the better, default 2) 
    -c <mkv|avi>    - Container type (avi or mkv). By now only with
    -z <factor>     - Scalefactor: scale width with this factor, should be between 0 and 1).
    -w <width>      - Scalewidth: select this width for the movie. 
    -i              - Deinterlace

    -I              - Gatter DVD Information
    -R              - Rip a DVD-Title.
    -T <dvd-title>  - Title number in DVD for use with -R and -I
    -d <dvd-device> - Set the DVD-Device. Used with -I or -R

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
    MPLAYERCROP="-nolirc -nojoystick -vo null -nosound -nocache -vf cropdetect -frames 12 -speed 100"
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
    # -vc null = no video codec (don't decode video) Problem if converting from mkv to avi
    # -vo null = no video output
    # -ao pcm:nowaveheader:file=fifo = output raw-audio to a file
    # -af volnorm=1 = normalize audio volume
    # -channels 2 = play audio in to channels
    # (unused: only DVD) -aid 137 = Audio ID, to play the right language }}}
    MPLAYEROPTS="-nolirc -nojoystick -nocache -noframedrop -noconfig all -mc 0 -vo null -af volnorm=1 -channels 2"
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
    # RAW_W=`grep ID_VIDEO_WIDTH ${IDENTIFY} | cut -f 2 -d =`
    # RAW_H=`grep ID_VIDEO_HEIGHT ${IDENTIFY} | cut -f 2 -d =`
    ORIGASPECT=`readOpt ORIGASPECT`
    if [ -z "$ORIGASPECT" ]
    then
        MPLAYERSCALE="-nolirc -vo null -nosound -nocache -vf crop=${CROP} -frames 1"
        CMD="mplayer ${MPLAYERSCALE} ${INPUT}"
        logAndRun ${CMD} > ${SCALELOG} 2>&1
        ORIGASPECT=`grep "VO:" ${SCALELOG} | awk '{print $5}'`
        writeOpt ORIGASPECT "$ORIGASPECT"
    fi
    ASPECT_W=`echo ${ORIGASPECT} | cut -f 1 -d x`
    ASPECT_H=`echo ${ORIGASPECT} | cut -f 2 -d x`
   
    getAspect
    CROP_W=`echo ${CROP} | cut -f 1 -d :`
    CROP_H=`echo ${CROP} | cut -f 2 -d :`

    # ratio = crop_width / (gdouble) crop_height * raw_height / raw_width * anumerator / adenominator;
    #RATIO=`echo "scale=4; ${CROP_W} / ${CROP_H} * ${ASPECT_H} / ${ASPECT_W} * ${NUMERATOR} / ${DENOMINATOR}" | bc `
    RATIO=`echo "scale=4; ${ASPECT_W} / ${ASPECT_H}" | bc `
    echo "Video info: ${ASPECT_W}x${ASPECT_H} (${NUMERATOR}:${DENOMINATOR}) crop ${CROP_W}x${CROP_H} ratio: ${RATIO}"

    SCALE_W=${ASPECT_W}
    if [ "x${SCALEWIDTH}" != "x" ]
    then
        [ -n "${SCALEWIDTH}" ] && [ ${SCALEWIDTH} -lt ${ASPECT_W} ] && SCALE_W=${SCALEWIDTH}
        SCALE_H=`echo "${SCALE_W}/${RATIO}/16*16" | bc`
        echo "Normal scaling to: ${SCALE_W} x ${SCALE_H}"
    fi

    if [ "x${SCALEFACTOR}" != "x1" ]
    then
        SCALE_W=`echo ${SCALE_W}*${SCALEFACTOR}/16*16 | bc` 
        SCALE_H=`echo "${SCALE_W}/${RATIO}/16*16" | bc`
        echo "Factor (${SCALEFACTOR}) scaling to: ${SCALE_W} x ${SCALE_H}"
    fi

    [ "x${SCALE_H}" == "x" ] || SCALE="${SCALE_W}:${SCALE_H}"
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
    [ "${DEINTERLACE}" ] && VFILTER="${DEINTERLACE},"
    VFILTER="${VFILTER}crop=${CROP},hqdn3d=2:1:2,harddup"
    [ "${SCALE}" ] && VFILTER="${VFILTER},scale=${SCALE}"

    if [ "${CONTAINER}" == "avi" ] 
    then
        # avi (xvid)
        # {{{ If we are implementing 2 passes
        # 2 pass
        # -o /dev/null -passlogfile <logfile> nocartoon:turbo:bitrate=24000000:pass=1
        # -o <file>    -passlogfile <logfile> nocartoon:bitrate=24000000:pass=2  
        # quant_type für kleine bitrate besser h263, sonst mpeg
        # (no)cartoon - video ist cartoon
        # turbo= für den 1. pass.
        # bitrate=24000000 (24000kbit/s) wird automatisch nach unten gekappt???
        # pass= welcher pass
        # }}}
        local quant_type="h263"
        [ $QUANTIZER -lt 4 ] && quant_type="mpeg" 
        XVIDOPTS="quant_type=${quant_type}:chroma_opt:vhq=3:bvhq=1:autoaspect:max_bframes=2:noqpel:trellis:nogreyscale:fixed_quant=${QUANTIZER}:threads=0:nogmc"
        CODECOPTS="-ovc xvid -xvidencopts ${XVIDOPTS}"
    else 
        # mkv (h264)
        # Explanation: {{{
        # subq=6 = good+ quality subpel. encode a bit faster. subpel Qualy.
        # weight_b = use weighted B-Frames
        # 8x8dct = Allow macroblock to chose between 8x8 and 4x4. Compress better
        # frameref=4 = Use 4 Frames to Predict B- and P-frames. OK Quality
        # partitions=p8x8,b8x8,i8x8,i4x4 = enable optional macroblock types
        # trellis=2 = Enable rate-distortion optimal quantization for final encode
        # bframes=3 = maximum 3 B-frames between I- and P-Frames (Better quality)
        # bitrate=${BITRATE} = the target video bitrate
        # direct_pred=auto = Type of motion prediction. spatial and temporal choice for each frame 
        # b_adapt=2 = How many b-frames will be used to reach bframes
        # me=umr = Fullpixel motion detection algorithm.
        # mixed_refs = Ermöglicht für jede 8x8- oder 16x8-Bewegungspartition die unabhängige Wahl eines Referenz-Frames.
        # cabac = Saves 10%-15% bitrate. A bit slower encoding and decoding.
        # threads=1 = Use only one CPU. Other setting will reduce compression quality
        # }}}
        XQUANT=`echo "scale=1; 12+6*l(${QUANTIZER})/l(2)" | bc -l`
        # From http://www.mplayerhq.hu/DOCS/HTML/en/menc-feat-x264.html
        # For version (1.0rc2 r26940) TODO Handle this automagicaly!  X264OPTS="subq=5:8x8dct:frameref=3:bframes=3:weight_b"
        X264OPTS="cabac:subq=6:8x8dct:frameref=4:bframes=3:weight_b:mixed_refs:me=umh:partitions=all:direct_pred=auto:trellis=2:b_adapt=2"
        X264OPTS="${X264OPTS}:crf=${XQUANT}:threads=1"
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
        AUDIOCODE=""
        for track in ${TRACKS}
        do
            lang=`getLanguageOfTrack $track`
            if [ "${CONTAINER}" == "avi" ]
            then
                MERGER=`which avibox`
                if [ "x${MERGER}" == "x" ]
                then
                    AUDIOCODE="${AUDIOCODE} -audiofile ${WORKDIR}/$track-${AUDIO}"
                else
                    AUDIOCODE="${AUDIOCODE} ${WORKDIR}/$track-${AUDIO}"
                fi
            else
                local langcode=""
                [ "x${lang}" != "x" ] && langcode="--language 0:$lang"
                AUDIOCODE="${AUDIOCODE} $langcode --sync 0:${DELAY} -D -S ${WORKDIR}/$track-${AUDIO}"
            fi
        done
        if [ "${CONTAINER}" == "avi" ]
        then
            if [ "$MERGER" ] 
            then
                MERGER="avibox -o ${FILENAME} -n -i ${VIDEO} ${AUDIOCODE}  -f XVID"
                logAndRun ${MERGER} > ${MERGELOG} 2>&1
            else
                # mencoder opts
                MENCODEROPTS="-nocache -noskip -noconfig all -mc 0 -ovc copy -oac copy -ffourcc DX50"
                MENCODEROPTS="${MENCODEROPTS} -audio-demuxer audio"
                MERGER="mencoder ${MENCODEROPTS} -o ${FILENAME} ${AUDIOCODE} ${VIDEO}"
                logAndRun ${MERGER} -info name="${NAME}" > ${MERGELOG} 2>&1
            fi
        else
            MERGEOPTS="-o ${FILENAME} --command-line-charset UTF-8 -d 0 -A -S ${VIDEO}"
            MERGER="mkvmerge ${MERGEOPTS} ${AUDIOCODE}"
            logAndRun ${MERGER} --title "${NAME}" > ${MERGELOG} 2>&1
        fi
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
    RET=""
    if [ -s mapping-${DVDTITLE}.txt ]
    then
        RET=`grep "ID_AID_${1}_LANG=" mapping-${DVDTITLE}.txt | cut -f 2 -d=` 
        if [ -z "${RET}" ] 
        then
            COUNT=`grep "ID_AID_.*_LANG=" mapping-${DVDTITLE}.txt | wc -l` 
            [ ${COUNT} -eq 1 ] && RET=`grep "ID_AID_.*_LANG=" mapping-${DVDTITLE}.txt | cut -f 2 -d=` 
        fi
    fi
    echo ${RET}
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
