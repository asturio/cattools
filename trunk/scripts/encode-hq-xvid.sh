#!/bin/bash
#
# {{{ Helpful comments

# Only for DVD
# -dvdangle 1

# No DVD Copy: dvdcpy -o /opt/bigdata/claudio/dvdrip/ogmrip/tmp/dvdFysN7H -m -t 26 /dev/scd0

# Chapter info holen...
# dvdxchap -t ${TRACK} /dev/dvd > ${RIPPATH}chapters.txt
# cp /mnt/dvd/video_ts/vts_01_0.ifo ${RIPPATH}

# identify subtitles:
# mplayer -sid ${SID} ${RIPPATH}movie.vob
# Rip subtitles:
# tccat -i ${RIPPATH}movie.vob -L | tcextract -x ps1 -t vob -a ${HEXSID} > ${RIPPATH}subs-${SID}
# subtitle2vobsub -o ${RIPPATH}vobsubs -i ${RIPPATH}vts_01_0.ifo -a ${SID}< ${RIPPATH}subs-${SID}

# Check subtitle id:
# mkdir ${RIPPATH}${SID}
# subtitle2pgm -o ${RIPPATH}${SID}/${SID} -c 255,0,0,255 < ${RIPPATH}subs-${SID}

# Another method for ripping audio:
# mplayer ${RIPPATH}movie.vob -aid ${AID} -dumpaudio -dumpfile ${RIPPATH}audio${AID}.ac3
# HOW TO GET SUBGTITLES:
# mencoder -nocache -nosound -of rawaudio -ovc copy -o /dev/null -vobsubout /tmp/sub.AFV8OU -vobsuboutindex 0 -sid 0 -dvd-device /opt/bigdata/claudio/dvdrip/vdr/dvdJK8As0 dvd://1
# subp2pgm /tmp/sub.AFV8OU
# ocrad -v -f -F utf8 -l 0 -o /tmp/sub.AFV8OU0247.pgm.txt /tmp/sub.AFV8OU0247.pgm
# processing file `/tmp/sub.AFV8OU0247.pgm'
# ocrad -v -f -F utf8 -l 0 -o /tmp/sub.AFV8OU0049.pgm.txt /tmp/sub.AFV8OU0049.pgm
# processing file `/tmp/sub.AFV8OU0049.pgm'
# ocrad -v -f -F utf8 -l 0 -o /tmp/sub.AFV8OU0440.pgm.txt /tmp/sub.AFV8OU0440.pgm
# processing file `/tmp/sub.AFV8OU0440.pgm'


# Uncomment this do just echo the commands
#DEBUG=echo
# Uncomment this do echo to stdout
#DEBUG2="#"

# }}}
export LANG=C

# Defaults
export CONTAINER=avi
export QUANTIZER=2
export SCALEFACTOR=1

# New select if container is mkv (h264+ogg) or avi (xvid+mp3)

#set -x

parseOpts() {
    ### parse options
    args=`getopt -n encode-hq.sh -o i:x:t:a:d:D:T:q:c:Z:IRh -- "$@"`
    if [ $? -ne 0 ]
    then
        usage
    fi
    eval set -- "$args"
    # echo "ARGS: $args"
    # echo ""

    TRACKS="";
    while [ "$1" ]
    do
        case "$1" in
        "-i") INPUT=$2; shift # Input file NEEDED
              CONFIG=`basename ${INPUT}`.conf
            ;;
        "-x") CROP=$2; shift # Crop
            ;;
        "-t") NAME=$2; shift # Title
            ;;
        "-a") TRACKS="$TRACKS $2"; shift # Audio Tracks
            ;;
        "-d") DVD="-dvd-device $2"; shift
            ;;
        "-D") DELAY="$2"; shift
            ;;
        "-T") DVDTITLE=$2; shift # Title
            ;;
        "-q") QUANTIZER=$2; shift # Quantizer
            ;;
        "-c") CONTAINER=$2; shift # Container
            ;;
        "-Z") SCALEFACTOR=$2; shift # SCALEFACTOR
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

    [ -z "$INPUT" -o ! -s "$INPUT" ] && echo "Input Needed!" && usage

    [ "$NAME" ] && writeOpt NAME "$NAME"
    [ "$CROP" ] && writeOpt CROP "$CROP"
    [ "$TRACKS" ] && writeOpt TRACKS "$TRACKS"
}

initialize() {
    WORKDIR=`readOpt WORKDIR`
    if [ -z "$WORKDIR" ]
    then
        WORKDIR=work-$$
        writeOpt WORKDIR "$WORKDIR"
    fi
    LOGDIR=$WORKDIR/logs

    [ -d $LOGDIR ] || mkdir -p $LOGDIR
    IDENTIFY=$LOGDIR/00-identify.txt
    CROPLOG=$LOGDIR/01-cropdetect.log
    MPLAYERAUDIOLOG=$LOGDIR/02-mplayer-audio.log
    AUDIOENCLOG=$LOGDIR/03-audioenc.log
    SCALELOG=$LOGDIR/04-scale.log
    VIDEOLOG=$LOGDIR/05-video.log
    MERGELOG=$LOGDIR/06-merge.log
    COMMANDS=$LOGDIR/commands.txt

    [ "$NAME" ] || NAME=`readOpt NAME`
    [ "$NAME" ] || NAME=$INPUT
    FILENAME=`echo ${NAME} | tr " 	" "__"`
    [ "$TRACKS" ] || TRACKS=`readOpt TRACKS`
    [ "$TRACKS" ] || TRACKS=0

    checkbins
}

checkbins() {
    BINS="mplayer mencoder oggenc mkvmerge mkfifo avibox lame"
    for i in $BINS
    do
        BIN=`which $i`
        if [ -z "$BIN" ]
        then
            echo "$i not found: Please install."
            exit
        fi
    done
}

usage() {
    echo "Usage:
    `basename $0` -i <file> -b <rate> -s <size> -x <crop> -t <title> -S <start> -E <end> -z <scale> -a <audio id> -d <dvd-dev> -IR
    Ex.: $0 -i VR_MOVIE.VRO -S 260000 -E 2:00:40 -s 700 -t \"Movie Name\"
    -i <input-file> - The file to encode. MANDATORY.
    -t <name>       - The name of the Movie.
    -x <crop>       - Crop with xxx:yyy:aa:bb. If not given, than autocrop.
    -a <audio id>   - The id of the audio track to encode, multiple -a
                      are allowed. The order will be preserved
    -D <delay>      - Audio Delay to use
    -I              - Gatter DVD Information
    -R              - Rip a DVD-Title.
    -d <dvd-device> - Set the DVD-Device. Used with -I or -R
    -T <title>      - Title number in DVD for use with -R and -I
    -h              - This help
    "
    exit 0
}

readOpt() {
    if [ -s $CONFIG ]
    then
        grep "^$1=" $CONFIG | sed "s|^$1=||"
    fi
}

writeOpt() {
    if [ -s $CONFIG ]
    then
        grep -v "^$1=" $CONFIG > $CONFIG.tmp
    fi
    echo "$1=$2" >> $CONFIG.tmp
    mv $CONFIG.tmp $CONFIG
}

detectCropByTime() {
    if [ -z "$ESTIMATESECONDS" ]
    then
        ESTIMATESECONDS=`readOpt ESTIMATESECONDS`
    fi
    if [ -z "$ESTIMATESECONDS" ]
    then
        ESTIMATESECONDS=`mplayer -identify -frames 0 ${INPUT} 2> /dev/null | grep ID_LENGTH | cut -f2 -d= | cut -f1 -d.`
    fi
    [ "$ESTIMATESECONDS" ] || return 1
    echo "Detecting crop by time."
    myStartPos=0
    myEndPos=$ESTIMATESECONDS
    echo "Total Movie Seconds: $ESTIMATESECONDS"
    STEPS=`echo $ESTIMATESECONDS/10 | bc`
    echo "Checking 1 frame every $STEPS seconds."
    # myPositions=""
    # while true
    # do
    #     myStartPos=`echo ${myStartPos}+${STEPS} | bc`
    #     [ $myStartPos -gt $myEndPos ] && break
    #     myPositions="$myPositions $myStartPos"
    # done
    # echo "Checking in $myPositions"
    echo "Deteting CROP"
    rm -f ${CROPLOG}
    mplayer ${MPLAYERCROP} -sstep ${STEPS} ${INPUT} ${DEBUG2} >> ${CROPLOG} 2>&1
    CROP=`grep "crop=" ${CROPLOG} | tail -1 | cut -f2 -d= | cut -f1 -d")"`
    x=`echo $CROP | cut -f 1 -d:`
    y=`echo $CROP | cut -f 2 -d:`
    if [ $x -gt 0 -a $y -gt 0 ]
    then
        writeOpt CROP "$CROP"
    else 
        CROP=""
    fi
}

detectCrop() {
    # Find Crop:
    # Since 4.4.1 not working with -sstep $STEPS"
    # Since 4.4.3 not working with -sb Startbyte     GRRRRRRRrrrr
    MPLAYERCROP="-nolirc -vo null -nosound -nocache -vf cropdetect -frames 12 -speed 100"
    [ -z "${CROP}" ] && CROP=`readOpt CROP`
    [ -z "${CROP}" ] && detectCropByTime

    if [ -z "$CROP" ]
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
    FIFO=$WORKDIR/audio.fifo
    AUDIO=`readOpt AUDIO`
    if [ "$CONTAINER" == "avi" ]
    then
        [ -z "$AUDIO" ] && AUDIO=audio.$$.mp3 && writeOpt AUDIO "$AUDIO"
    else
        [ -z "$AUDIO" ] && AUDIO=audio.$$.ogg && writeOpt AUDIO "$AUDIO"
    fi

    rm -f $WORKDIR/audio.fifo

    AUDIOSIZE=`readOpt AUDIOSIZE`
    [ "$AUDIOSIZE" ] || AUDIOSIZE=0
    for track in $TRACKS
    do
        OUTPUT=$WORKDIR/$track-$AUDIO
        RC=`readOpt $OUTPUT`
        if [ "$RC" == "Done" -a -s $OUTPUT ]
        then
            echo "Audio $OUTPUT present, skiping encoding."
        else
            echo "Encoding Audio track $track."
            [ "$track" -ne "0" ] && AID="-aid $track"

            # First detect audio format:
            # echo " Detecting Audio format"
            # Not needed anymore. Dumpfile als normal Wave (WITH header), so oggenc can detect the format
            # AUDIOLINE=`mplayer -vo null -ao null -frames 2 ${AID} ${INPUT} 2> /dev/null | grep AUDIO`
            # ABITRATE=`echo $AUDIOLINE | awk '{print $2}'`
            # ACHANNELS=`echo $AUDIOLINE | awk '{print $4}'`
            # echo " Audio is ${ABITRATE} Hz and ${ACHANNELS} Channels."

            echo    "mkfifo ${FIFO}" >> $COMMANDS
            ${DEBUG} mkfifo ${FIFO}

            echo    "mplayer ${MPLAYEROPTS} ${AID} -ao pcm:fast:waveheader:file=${FIFO} ${INPUT}" >> $COMMANDS
            ${DEBUG} mplayer ${MPLAYEROPTS} ${AID} -ao pcm:fast:waveheader:file=${FIFO} ${INPUT} ${DEBUG2} >> $MPLAYERAUDIOLOG 2>&1 &

            # Explanation:
            # Input is -r(aw), -R(aw rate is) 48000 bits, Encode with -q(uality) 3, using 2 -C(hannels)
            # OGGENCOPTS="-r -R ${ABITRATE} -q 3 -C ${ACHANNELS} "
            OGGENCOPTS="-q 3"
            echo    "oggenc ${OGGENCOPTS} -o ${OUTPUT} ${FIFO}" >> $COMMANDS
            if [ "$CONTAINER" == "avi" ]
            then
                lame --nohist -h -r -s 48,0 --preset fast medium ${FIFO} ${OUTPUT} >> ${AUDIOENCLOG} 2>&1
            else
                ${DEBUG} oggenc ${OGGENCOPTS} -o ${OUTPUT} ${FIFO} ${DEBUG2} >> ${AUDIOENCLOG} 2>&1
            fi
            [ $? -eq 0 ] && writeOpt $OUTPUT "Done"
            ${DEBUG} rm ${FIFO} ${DEBUG2}
            sumAudioSize $OUTPUT
        fi
    done
}

sumAudioSize() {
    tAUDIOSIZE=`ls -l ${1} | awk '{print $5}'`
    AUDIOSIZE=`echo "scale=2;${AUDIOSIZE}+${tAUDIOSIZE}/1024/1024" | bc`
    if [ "$AUDIOSIZE" == "0" ]
    then
        echo "Error: Audio not encoded"
        exit 1
    fi

    echo " Audio size is now ${AUDIOSIZE} Mb"
    writeOpt AUDIOSIZE "$AUDIOSIZE"
}

getAspect() {
    ASPECT=`grep ID_VIDEO_ASPECT stream-infos.txt | cut -f 2 -d = | cut -f 1 -d .`
    NUMERATOR=1
    DENOMINATOR=1
    case $ASPECT in
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
    RAW_W=`grep ID_VIDEO_WIDTH stream-infos.txt | cut -f 2 -d =`
    RAW_H=`grep ID_VIDEO_HEIGHT stream-infos.txt | cut -f 2 -d =`
    getAspect
    CROP_W=`echo $CROP | cut -f 1 -d :`
    CROP_H=`echo $CROP | cut -f 2 -d :`

    # ratio = crop_width / (gdouble) crop_height * raw_height / raw_width * anumerator / adenominator;
    RATIO=`echo "scale=4; $CROP_W / $CROP_H * $RAW_H / $RAW_W * $NUMERATOR / $DENOMINATOR" | bc `
    echo "Video info: ${RAW_W}x${RAW_H} ($NUMERATOR:$DENOMINATOR) crop ${CROP_W}x${CROP_H} ratio: $RATIO"

    SCALE_W=$CROP_W
    SCALE_H=`echo "$SCALE_W/$RATIO/16*16" | bc`
    echo "Normal scaling to: $SCALE_W x $SCALE_H"

    SCALE_W=`echo $SCALE_W*$SCALEFACTOR/16*16 | bc` 
    SCALE_H=`echo "$SCALE_W/$RATIO/16*16" | bc`
    echo "Factor ($SCALEFACTOR) scaling to: $SCALE_W x $SCALE_H"

    SCALE="$SCALE_W:$SCALE_H"
}

scaleWithBitrate() {
    # Calculate every time, as the size or bitrate can be changed.
    ORIGASPECT=`readOpt ORIGASPECT`
    if [ -z "$ORIGASPECT" ]
    then
        MPLAYERSCALE="-nolirc -vo null -nosound -nocache -vf crop=${CROP} -frames 2"
        echo    "mplayer ${MPLAYERSCALE} ${INPUT} ${DEBUG2}" >> $COMMANDS
        ${DEBUG} mplayer ${MPLAYERSCALE} ${INPUT} ${DEBUG2} > ${SCALELOG} 2>&1
        ORIGASPECT=`grep "VO:" ${SCALELOG} | awk '{print $5}'`
        writeOpt ORIGASPECT "$ORIGASPECT"
        echo "ORIGASPECT: $ORIGASPECT"
    fi

    if [ -z "${SCALE}" ]
    then
        # Scaling with
        # ARc = (Wc x (ARa / PRdvd )) / Hc  and
        # ResY = INT(SQRT( 1000*Bitrate/25/ARc/CQ )/16) * 16 and
        # ResX = INT( ResY * ARc / 16) * 16
        echo "Detecting scale"
        PRdvd=1.25
        CQ=0.25
        ARa=`echo $ORIGASPECT | sed "s/x/\//"`
        ARa=`echo "scale=4; $ARa" | bc`
        aW=`echo ${ORIGASPECT} | cut -f1 -dx`
        aH=`echo ${ORIGASPECT} | cut -f2 -dx`
        Wc=`echo ${CROP} | cut -f1 -d:`
        Hc=`echo ${CROP} | cut -f2 -d:`
        ARc=`echo "scale=4; (${Wc} * (${ARa} / ${PRdvd})) / $Hc" | bc`
        echo "Original aspect is ${ORIGASPECT} (${ARa}) ARc=${ARc}"
        ResY=`echo "sqrt(1000*${BITRATE}/25/${ARc}/${CQ})/16*16" | bc`
        [ $ResY -gt $aH ] && ResY=$aH && REDUCE=1
        ResX=`echo "(${ResY} * ${ARc} / 16) * 16" | bc`
        [ $ResX -gt $aW ] && ResX=$aW
        SCALE="${ResX}:${ResY}"
    fi
    echo " Scaling from ${ORIGASPECT} => ${SCALE}"
}

encodeVideo() {
    VIDEO=`readOpt VIDEO`
    [ -z "$VIDEO" ] && VIDEO=$WORKDIR/video.$$.avi && writeOpt VIDEO "$VIDEO"
    # Explanation: {{{
    # subq=5 = good quality subpel. encode a bit faster
    # b_pyramid = Use B-Frames as references to predict next frames. Increases compresssion (CHANGED in new mplayer)
    # weight_b = use weighted B-Frames
    # 8x8dct = Allow macroblock to chose between 8x8 and 4x4. Compress better
    # frameref=2 = Use 2 Frames to Predict B- and P-frames. OK Quality
    # mixed_refs = 8x8 and 16x8 motion partition can use different reference frames.
    # partitions=p8x8,b8x8,i8x8,i4x4 = enable optional macroblock types
    # trellis=1 = Enable rate-distortion optimal quantization for final encode
    # bframes=2 = maximum 2 B-frames between I- and P-Frames (Better quality)
    # bitrate=${BITRATE} = the target video bitrate
    # direct_pred=auto = Type of motion prediction. spatial and temporal choice for each frame }}}

    XVIDOPTS="quant_type=h263:chroma_opt:vhq=2:bvhq=1:autoaspect:max_bframes=2:noqpel:trellis:nogreyscale:fixed_quant=$QUANTIZER:threads=2"

    X264OPTS="subq=5:weight_b:8x8dct:frameref=2:mixed_refs:partitions=p8x8,b8x8,i8x8,i4x4:trellis=1"
    X264OPTS="$X264OPTS:bframes=2:bitrate=${BITRATE}:direct_pred=auto" # FIXME BITRATE

    CODEC="-ovc x264"
    CODEC="-ovc xvid"

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
    MENCODEROPTS="-nocache -noslices -noconfig all -oac pcm -srate 8000 -af channels=1,lavcresample=8000 -sws 7 -zoom -mc 0 ${CODEC}"

    # hqdn3d=2:1:2 = High Quality/Precision Denoise (better compression, smooth images)
    # harddup = don't drop duplicate frames.
    # SCALE removed from vf "-vf scale..."
    VFILTER="crop=${CROP},hqdn3d=2:1:2,harddup"
    [ "${SCALE}" ] && VFILTER="$VFILTER,scale=${SCALE}" # Don't Scale anymore. "Höchstens auf ein 16" FIXME 

    encodePass1
}

encodePass1() {
    # pass=1 = first pass
    X264OPTS1="-x264encopts ${X264OPTS}"

    CODECOPTS="-x264encopts ${X264OPTS}"
    [ "$CONTAINER" == "avi" ] && CODECOPTS="-xvidencopts $XVIDOPTS"

    # Enplanation: Put all together
    MENCODEROPTS1="${MENCODEROPTS} ${CODECOPTS}"

    # Encode Video 1. pass
    VIDEOPASS1=`readOpt VIDEO1`
    if [ "$VIDEOPASS1" == "Done" -a -s ${VIDEO} ]
    then
        echo "1st pass already done. Skipping."
    else
        VIDEOPASS1=""
        echo "ENCONDING the video: 1st pass."
        echo    "mencoder ${MENCODEROPTS1} -vf ${VFILTER} -o ${VIDEO} ${INPUT}" \
        >> $COMMANDS
        ${DEBUG} mencoder ${MENCODEROPTS1} -vf ${VFILTER} \
            -o ${VIDEO} ${INPUT} ${DEBUG2} > $VIDEOLOG 2>&1
        [ $? -eq 0 ] && writeOpt VIDEO1 "Done" && VIDEOPASS1=Done
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
    if [ "$VIDEOPASS1" == "Done" ]
    then
        echo "Merging streams"
        MERGEOPTS="-o ${FILENAME}.mkv --command-line-charset UTF-8 -d 0 -A -S ${VIDEO}"
        AUDIOCODE=""
        for track in $TRACKS
        do
            lang=`getLanguageOfTrack $track`
            if [ "${CONTAINER}" == "avi" ]
            then
                AUDIOCODE="$AUDIOCODE $WORKDIR/$track-${AUDIO}"
            else
                AUDIOCODE="$AUDIOCODE --language 0:$lang --sync 0:$DELAY -D -S $WORKDIR/$track-${AUDIO}"
            fi
        done
        echo    "mkvmerge $MERGEOPTS $AUDIOCODE --title \"${NAME}\"" >> $COMMANDS
        if [ "${CONTAINER}" == "avi" ]
        then
            avibox -o ${FILENAME}.avi -n -i ${VIDEO} ${AUDIOCODE}  -f XVID 
        else
            ${DEBUG} mkvmerge $MERGEOPTS $AUDIOCODE --title "${NAME}" > $MERGELOG 2>&1
        fi
    fi
}

getDVDInfos() {
    if [ ! -s mapping-$DVDTITLE.txt ]
    then
        echo "Getting DVD Language Mapping for Title $DVDTITLE"
        mplayer -frames 2 -vo null -ao null -identify $DVD dvd://$DVDTITLE 2> /dev/null | grep "^ID_" > mapping-$DVDTITLE.txt
    fi
    exit 0
}

getStreamInfos() {
    if [ ! -s stream-infos.txt ]
    then
        echo "Getting Stream Infos"
        mplayer -frames 0 -vo null -ao null -identify ${INPUT} 2> /dev/null | grep "^ID_" > stream-infos.txt
    fi
}

getLanguageOfTrack() {
    if [ -s mapping-$DVDTITLE.txt ]
    then
        grep "ID_AID_${1}_LANG=" mapping-$DVDTITLE.txt | cut -f 2 -d=
    else
        echo "de"
    fi
}

rippDVD() {
    mplayer -dumpstream -noframedrop -nocache -dumpfile dvddump-$DVDTITLE.vob $DVD dvd://$DVDTITLE 
    getDVDInfos
}

DELAY=0

# TODO: Add option for part-jobs (Only encode audio, or detect things, or encode video, or merge files)

# do work

parseOpts "$@"

initialize

getStreamInfos

detectCrop

setScale

encodeAudio

encodeVideo

mergeStream

# vim:set foldmethod=marker:
