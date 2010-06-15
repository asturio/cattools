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

# Uncomment this do just echo the commands
#DEBUG=echo
# Uncomment this do echo to stdout
#DEBUG2="#"

# }}}
set +x

parseOpts() {
    ### parse options
    args=`getopt -n encode-hq.sh -o i:b:s:x:t:S:E:z:a:d:D:T:IRh -- "$@"`
    if [ $? -ne 0 ]
    then
        usage
    fi
    eval set -- "$args"
    # echo "ARGS: $args"
    echo ""

    TRACKS="";
    while [ "$1" ]
    do
        case "$1" in
        "-a") TRACKS="$TRACKS $2"; shift # Audio Tracks
            ;;
        "-b") BITRATE=$2; shift; # Video Bitrate 
            unset TARGETSIZE; 
            writeOpt TARGETSIZE
            ;;
        "-d") DVD="-dvd-device $2"; shift
            ;;
        "-D") DELAY="$2"; shift
            ;;
        "-E") END="-endpos $2"; shift # End
            ;;
        "-h") usage
            ;;
        "-i") INPUT=$2; shift # Input file NEEDED
              CONFIG=`basename ${INPUT}`.conf
            ;;
        "-I") getDVDInfos
            ;;
        "-s") TARGETSIZE=$2; shift # File Size
              unset BITRATE;
              writeOpt BITRATE;
            ;;
        "-S") START="-sb $2"; shift # Start
            ;;
        "-R") rippDVD
            ;;
        "-t") NAME=$2; shift # Title
            ;;
        "-T") DVDTITLE=$2; shift # Title
            ;;
        "-x") CROP=$2; shift # Crop
            ;;
        "-z") SCALE=$2; shift # Scale
            ;;
        esac
        shift
    done

    [ -z "$INPUT" -o ! -s "$INPUT" ] && echo "Input Needed!" && usage

    [ "$NAME" ] && writeOpt NAME "$NAME"
    [ "$CROP" ] && writeOpt CROP "$CROP"
    [ "$SCALE" ] && writeOpt SCALE "$SCALE"
    [ "$TARGETSIZE" ] && writeOpt TARGETSIZE "$TARGETSIZE"
    [ "$BITRATE" ] && writeOpt BITRATE "$BITRATE"
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
    FRAMESLOG=$LOGDIR/01-framescount.log
    CROPLOG=$LOGDIR/02-cropdetect.log
    MPLAYERAUDIOLOG=$LOGDIR/03-mplayer-audio.log
    OGGENCLOG=$LOGDIR/04-oggenc.log
    SCALELOG=$LOGDIR/05-scale.log
    PASS1LOG=$LOGDIR/06-1pass.log
    PASS2LOG=$LOGDIR/07-2pass.log
    MERGELOG=$LOGDIR/08-merge.log
    COMMANDS=$LOGDIR/commands.txt

    [ "$NAME" ] || NAME=`readOpt NAME`
    [ "$NAME" ] || NAME=$INPUT
    [ "$TARGETSIZE" ] || TARGETSIZE=`readOpt TARGETSIZE`
    [ "$TARGETSIZE" ] || TARGETSIZE=700
    FILENAME=`echo ${NAME} | tr " 	" "__"`
    [ "$TRACKS" ] || TRACKS=`readOpt TRACKS`
    [ "$TRACKS" ] || TRACKS=0

    checkbins
}

checkbins() {
    BINS="mplayer mencoder oggenc mkvmerge mkfifo"
    for i in $BINS
    do
        BLA=`which $i`
        if [ -z "$BLA" ]
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
    -s <targetsize> - The wished filesize. Don\'t use with -b
    -b <bitrate>    - The wished bitrate. Don\'t use with -s
    -S <start>      - The Starting Byte for beginning the encoding.
    -E <end>        - The Ending Time of the encoding.
    -x <crop>       - Crop with xxx:yyy:aa:bb. If not given, than autocrop.
    -z <scale>      - Scale with WxH. If empty, than autoscale 
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

detectCrop() {
    # Find Crop:
    # Since 4.4.1 not working with -sstep $STEPS"
    MPLAYERCROP="-nolirc -vo null -nosound -nocache -vf cropdetect -frames 12 -speed 100"
    if [ -z "${CROP}" ]
    then
        CROP=`readOpt CROP`
        if [ -z "${CROP}" ]
        then
            STARTFRAME=`getStartFrame`
            ENDFRAME=`getEndFrame`
            MOVIEFRAMES=`echo ${ENDFRAME}-${STARTFRAME} | bc`
            MOVIESIZE=`echo ${FILESIZE}*${MOVIEFRAMES}/${TOTALFRAMES} | bc`
            # FIXME Hier ist der Fehler START UND ENDFRAME FALSCH
            myStartSize=`getStartSize`
            echo "Movie Frames: $MOVIEFRAMES ($STARTFRAME - $ENDFRAME) (size $MOVIESIZE bytes) (start: $myStartSize)"
            STEPS=`echo $MOVIESIZE/10 | bc`
            myEndSize=`echo $myStartSize+$MOVIESIZE | bc`
            while true
            do
                myStartSize=`echo ${myStartSize}+${STEPS} | bc`
                [ $myStartSize -gt $myEndSize ] && break
                myPositions="$myPositions $myStartSize"
            done
            echo "Checking in $myPositions"
            echo "Deteting CROP"
            rm -f ${CROPLOG}
            for STEP in $myPositions
            do
                echo "mplayer ${MPLAYERCROP} ${INPUT} ${DEBUG2} -sb $STEP" >> ${CROPLOG} 
                      mplayer ${MPLAYERCROP} ${INPUT} ${DEBUG2} -sb $STEP >> ${CROPLOG} 2>&1
            done
            CROPS=`grep "crop=" ${CROPLOG} | cut -f 2 -d= | cut -f1 -d")"`
            x=0
            y=0
            dx=10240
            dy=10240
            for myCROP in $CROPS
            do
                myX=`echo "$myCROP" | cut -f 1 -d ":"`
                myY=`echo "$myCROP" | cut -f 2 -d ":"`
                myDX=`echo "$myCROP" | cut -f 3 -d ":"`
                myDY=`echo "$myCROP" | cut -f 4 -d ":"`
                [ $myX -gt $x ] && x=$myX
                [ $myY -gt $y ] && y=$myY
                [ $myDX -lt $dx ] && dx=$myDX
                [ $myDY -lt $dy ] && dy=$myDY
            done
            CROP="$x:$y:$dx:$dy"
            writeOpt CROP "$CROP"
        fi
    fi
    if [ -z "$CROP" ]
    then
        echo "CROP could not be detected. Try to detect if manualy using"
        echo " mplayer -vf cropdetect and "
        echo " mplayer -vf retangle=<CROP>"
        echo " Then pass the crop to the script using the -x option."
        exit 1
    fi
    echo " Cropping to ${CROP}"
}

getStartFrame() {
    myStartFrame=1
    if [ "${START}" ]
    then
        # This is just a guess, and is used only to compute how many frames are to be encoded using -S and -E
        myStartSize=`getStartSize`
        let myRestSize=FILESIZE-myStartSize
        myStartFrame=`echo ${myRestSize}*${TOTALFRAMES}/${FILESIZE} | bc`
        # echo "Restsize: $myRestSize" 1>&2
    fi
    echo $myStartFrame
}

getStartSize() {
    myStartSize=0
    if [ "${START}" ]
    then
        myStartSize=`echo ${START} | cut -f 2 -d " "`
        # echo "Startsize: $myStartSize" 1>&2
    fi
    echo $myStartSize
}

getEndFrame() {
    myEndFrame=`readOpt TOTALFRAMES`
    if [ "${END}" ]
    then
        myTime=`echo "${END}:" | cut -f 2 -d " "`
        myHours=`echo $myTime | cut -f 1 -d :`
        myMinutes=`echo $myTime | cut -f 2 -d :`
        mySeconds=`echo $myTime | cut -f 3 -d :`
        if [ -z "$myMinutes" -a -z "$mySeconds" ] 
            then mySeconds=$myHours; myMinutes=0; myHours=0
        elif [ -z "$mySeconds" ] 
            then mySeconds=$myMinutes; myMinutes=$myHours; myHours=0
        fi
        # Factor of 0.80 is an approximation. VRO Files say they are longer than real
        myParttime=`echo "($myHours * 60 * 60 + $myMinutes * 60 + $mySeconds) * 0.80" | bc`
        myEndFrame=`echo "$STARTFRAME + $myParttime * 25" | bc`
    fi
    echo $myEndFrame
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
    [ -z "$AUDIO" ] && AUDIO=audio.$$.ogg && writeOpt AUDIO "$AUDIO"

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

            echo    "mplayer ${MPLAYEROPTS} ${AID} -ao pcm:fast:waveheader:file=${FIFO} ${START} ${END} ${INPUT}" >> $COMMANDS
            ${DEBUG} mplayer ${MPLAYEROPTS} ${AID} -ao pcm:fast:waveheader:file=${FIFO} ${START} ${END} ${INPUT} ${DEBUG2} >> $MPLAYERAUDIOLOG 2>&1 &

            # Explanation:
            # Input is -r(aw), -R(aw rate is) 48000 bits, Encode with -q(uality) 3, using 2 -C(hannels)
            # OGGENCOPTS="-r -R ${ABITRATE} -q 3 -C ${ACHANNELS} "
            OGGENCOPTS="-q 3"
            echo    "oggenc ${OGGENCOPTS} -o ${OUTPUT} ${FIFO}" >> $COMMANDS
            ${DEBUG} oggenc ${OGGENCOPTS} -o ${OUTPUT} ${FIFO} ${DEBUG2} >> ${OGGENCLOG} 2>&1
            [ $? -eq 0 ] && writeOpt $OUTPUT "Done"
            ${DEBUG} rm ${FIFO} ${DEBUG2}
            sumAudioSize $OUTPUT
        fi
    done
    getMovieLength
}

sumAudioSize() {
    tAUDIOSIZE=`ls -l ${1} | awk '{print $5}'`
    AUDIOSIZE=`echo "scale=2;${AUDIOSIZE}+${tAUDIOSIZE}/1024/1024" | bc`
    echo " Audio size is now ${AUDIOSIZE} Mb"
    writeOpt AUDIOSIZE "$AUDIOSIZE"
}

getMovieLength() {
    [ "$MOVIESECONDS" ] || MOVIESECONDS=`readOpt MOVIESECONDS`
    if [ -z "$MOVIESECONDS" ]
    then
        # Compute movie seconds from oggenc.log - See only first Track
        MOVIESECONDS=`grep "File length" ${OGGENCLOG} | head -1 | \
            sed -e "s/File length:/scale=4;/" -e "s/m/*60+/" -e "s/,/./" -e "s/s$//" | bc`
        echo " Audio length = ${MOVIESECONDS}s"
        writeOpt MOVIESECONDS $MOVIESECONDS
    fi
}

setBitRate() {
    if [ -z "$BITRATE" ] # TARGETSIZE is allways set.
    then
        echo "Reading Bitrate."
        BITRATE=`readOpt BITRATE`
        # Bitrate is: (TargetSizeMb-AudioSizeMb)*1024*1024/MovieSeconds*8/1000
        if [ -z "$BITRATE" ] 
        then
            echo "Calculating Bitrate from Targetsize."
            BITRATE=`echo "(${TARGETSIZE}-${AUDIOSIZE})*1024*1024*8/${MOVIESECONDS}/1000-1" | bc `
        fi
        BITRATE=${BITRATE:=800}
        if [ $BITRATE -gt $MAXBITRATE ]
        then
            echo "Reducing video bitrate $BITRATE => $MAXBITRATE"
            BITRATE=${MAXBITRATE}
            TARGETSIZE=`echo "(${BITRATE}*${MOVIESECONDS}*1000)/(1024*1024*8)+${AUDIOSIZE}" | bc`
        fi
        if [ $BITRATE -lt $MINBITRATE ]
        then
            echo "Raising video bitrate $BITRATE => $MINBITRATE"
            BITRATE=${MINBITRATE}
            TARGETSIZE=`echo "(${BITRATE}*${MOVIESECONDS}*1000)/(1024*1024*8)+${AUDIOSIZE}" | bc`
        fi
    else
        TARGETSIZE=`echo "(${BITRATE}*${MOVIESECONDS}*1000)/(1024*1024*8)+${AUDIOSIZE}" | bc`
    fi
    writeOpt BITRATE "$BITRATE"
    writeOpt TARGETSIZE "$TARGETSIZE"

    echo " Movie bitrate will be ${BITRATE}bps, size ca. ${TARGETSIZE} Mb"
}

setScale() {
    # Calculate every time, as the size or bitrate can be changed.
    ORIGASPECT=`readOpt ORIGASPECT`
    if [ -z "$ORIGASPECT" ]
    then
        MPLAYERSCALE="-nolirc -vo null -nosound -nocache -vf crop=${CROP} -frames 2"
        echo    "mplayer ${MPLAYERSCALE} ${START} ${INPUT} ${DEBUG2}" >> $COMMANDS
        ${DEBUG} mplayer ${MPLAYERSCALE} ${START} ${INPUT} ${DEBUG2} > ${SCALELOG} 2>&1
        ORIGASPECT=`grep "VO:" ${SCALELOG} | awk '{print $5}'`
        writeOpt ORIGASPECT "$ORIGASPECT"
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
        if [ "${SCALE}" == "${aW}:${aH}" -a "$REDUCE" = "1" ]
        then
            echo "Scale to original size. Should recalculate bitrate."
            recalcuteBitrateFromScale
        fi
    fi
    echo " Scaling from ${ORIGASPECT} => ${SCALE}"
}

recalcuteBitrateFromScale() {
    BITRATE=`echo "${ResY}*${ResY}*${CQ}*${ARc}*25/1000+1" | bc`
    echo "I would make with this bitrate: ${BITRATE}"
    setBitRate
}


encodeVideo() {
    VIDEO=`readOpt VIDEO`
    [ -z "$VIDEO" ] && VIDEO=$WORKDIR/video.$$.avi && writeOpt VIDEO "$VIDEO"
    PASSLOG=`readOpt PASSLOG`
    [ -z "$PASSLOG" ] && PASSLOG=$WORKDIR/passlog.$$.txt && writeOpt PASSLOG "$PASSLOG"
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
    X264OPTS="subq=5:weight_b:8x8dct:frameref=2:mixed_refs:partitions=p8x8,b8x8,i8x8,i4x4:trellis=1"
    X264OPTS="$X264OPTS:bframes=2:bitrate=${BITRATE}:direct_pred=auto"

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
    # -passlogfile ${PASSLOG} = logfile for encoding }}}
    MENCODEROPTS="-nocache -noslices -oac pcm -srate 8000 -af channels=1,lavcresample=8000 -sws 7 -zoom -mc 0 -ovc x264 -passlogfile ${PASSLOG}"

    # hqdn3d=2:1:2 = High Quality/Precision Denoise (better compression, smooth images)
    # harddup = don't drop duplicate frames.
    # SCALE removed from vf "-vf scale..."
    VFILTER="crop=${CROP},hqdn3d=2:1:2,harddup"
    VFILTER="$VFILTER,scale=${SCALE}"

    encodePass1

    encodePass2
}

encodePass1() {
    # pass=1 = first pass
    # turbo=2 = don't do CPU intensive work in 1st pass.
    X264OPTS1="-x264encopts ${X264OPTS}:pass=1:turbo=2"

    # Enplanation: Put all together
    MENCODEROPTS1="${MENCODEROPTS} ${X264OPTS1}"

    # Encode Video 1. pass
    VIDEOPASS1=`readOpt VIDEO1`
    if [ "$VIDEOPASS1" == "Done" -a -s $PASSLOG ]
    then
        echo "1st pass already done. Skipping."
    else
        VIDEOPASS1=""
        echo "ENCONDING the video: 1st pass."
        echo    "mencoder ${MENCODEROPTS1} -vf ${VFILTER} -o /dev/null ${START} -endpos ${MOVIESECONDS} ${INPUT}" \
        >> $COMMANDS
        ${DEBUG} mencoder ${MENCODEROPTS1} -vf ${VFILTER} \
            -o /dev/null ${START} -endpos ${MOVIESECONDS} ${INPUT} ${DEBUG2} > $PASS1LOG 2>&1
        [ $? -eq 0 ] && writeOpt VIDEO1 "Done" && VIDEOPASS1=Done
    fi
}

encodePass2() {
    # pass=2 = second pass
    X264OPTS2="-x264encopts ${X264OPTS}:pass=2"

    # Enplanation: Put all together
    MENCODEROPTS2="${MENCODEROPTS} ${X264OPTS2}"

    # Encode Video 2. pass
    if [ "$VIDEOPASS1" == "Done" ]
    then
        VIDEOPASS2=`readOpt VIDEO2`
        if [ "$VIDEOPASS2" == "Done" -a -s $VIDEO ]
        then
            echo "2nd pass already done. Skipping."
        else
            VIDEOPASS2=""
            echo "ENCONDING the video: 2nd pass."
            echo    "mencoder ${MENCODEROPTS2} -vf ${VFILTER} -o ${VIDEO} ${START} -endpos ${MOVIESECONDS} ${INPUT}" \
            >> $COMMANDS
            ${DEBUG} mencoder ${MENCODEROPTS2} -vf ${VFILTER} \
                -o ${VIDEO} ${START} -endpos ${MOVIESECONDS} ${INPUT} ${DEBUG2} > $PASS2LOG 2>&1
            [ $? -eq 0 ] && writeOpt VIDEO2 "Done" && VIDEOPASS2=Done
        fi
    fi
}

estimateSize() {
    # {{{ How this work
    # (800+112)*3600*1000/1024/1024/8
    # (VideoBitRate+AudioBitRate)*LengthSeconds*A*B*C
    # C = 8 (Bits -> Bytes)
    # B = 1024 (Kib -> Mib)
    # A = 1000/1024 ( Mib -> Mb) }}}
    [ -s mapping-$DVDTITLE.txt ] && ESTIMATEDLENGTH=`grep "ID_LENGTH=" mapping-$DVDTITLE.txt | cut -f2 -d=`
    [ "$ESTIMATEDLENGTH" ] || ESTIMATEDLENGTH=`mplayer -identify -frames 2 -vo null -ao null ${INPUT} 2> /dev/null| grep ID_LENGTH | cut -f 2 -d =`
    countFrames
    let ESTIMATEDLENGTH2=TOTALFRAMES/25
    if [ "$BITRATE" ]
    then
        tracks=0
        for i in $TRACKS
        do
            let tracks=tracks+1
        done
        ESTIMATEDSIZE=`echo "($BITRATE+$tracks*112)*$ESTIMATEDLENGTH*1000/1024/1024/8" | bc`
        echo "Size will be ca. $ESTIMATEDSIZE Mb."
        ESTIMATEDSIZE2=`echo "($BITRATE+$tracks*112)*$ESTIMATEDLENGTH2*1000/1024/1024/8" | bc`
        echo "Size will be ca. $ESTIMATEDSIZE2 Mb. (method 2)"
    fi
}

countFrames() {
    TOTALFRAMES=`readOpt TOTALFRAMES`
    if [ -z "${TOTALFRAMES}" ]
    then
        echo "Counting total frames: "
        mplayer -nosound -vo null -nocache -speed 100 ${INPUT} 2> /dev/null > $FRAMESLOG
        TOTALFRAMES=`tail -c 1000 ${FRAMESLOG} | sed "s//\n/g" | grep "V:" | tail -1 | cut -f 2 -d " " | cut -f 1 -d "/"`
        writeOpt TOTALFRAMES $TOTALFRAMES
    fi
    echo "Total frames: $TOTALFRAMES"
    FILESIZE=`ls -l ${INPUT} | awk '{print $5}'`
}

mergeStream() {
# Explanation: {{{
# -d 0 = copy video Track 0
# -A = no Audio
# -S = no subs
# -D = no video
# --language 0:ger = Audio stream 0 is german (can be used more times)
# --sync 0:-100 Delay Audio in -100 ms (skip 100ms of video frames) }}}
    if [ "$VIDEOPASS2" == "Done" ]
    then
        echo "Merging streams"
        MERGEOPTS="-o ${FILENAME}.mkv --command-line-charset UTF-8 -d 0 -A -S ${VIDEO}"
        AUDIOCODE=""
        for track in $TRACKS
        do
            lang=`getLanguageOfTrack $track`
            AUDIOCODE="$AUDIOCODE --language 0:$lang --sync 0:$DELAY -D -S $WORKDIR/$track-${AUDIO}"
        done
        echo    "mkvmerge $MERGEOPTS $AUDIOCODE --title \"${NAME}\"" >> $COMMANDS
        ${DEBUG} mkvmerge $MERGEOPTS $AUDIOCODE --title "${NAME}" > $MERGELOG 2>&1
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

MAXBITRATE=1500
MINBITRATE=750
DELAY=0

# TODO: Add option for part-jobs (Only encode audio, or detect things, or encode video, or merge files)


# do work

parseOpts "$@"

initialize

estimateSize

detectCrop

encodeAudio

setBitRate

setScale

encodeVideo

mergeStream

##### OLD CODE

# HOW TO GET SUBGTITLES:
# mencoder -nocache -nosound -of rawaudio -ovc copy -o /dev/null -vobsubout /tmp/sub.AFV8OU -vobsuboutindex 0 -sid 0 -dvd-device /opt/bigdata/claudio/dvdrip/vdr/dvdJK8As0 dvd://1
# subp2pgm /tmp/sub.AFV8OU
# ocrad -v -f -F utf8 -l 0 -o /tmp/sub.AFV8OU0247.pgm.txt /tmp/sub.AFV8OU0247.pgm
# processing file `/tmp/sub.AFV8OU0247.pgm'
# ocrad -v -f -F utf8 -l 0 -o /tmp/sub.AFV8OU0049.pgm.txt /tmp/sub.AFV8OU0049.pgm
# processing file `/tmp/sub.AFV8OU0049.pgm'
# ocrad -v -f -F utf8 -l 0 -o /tmp/sub.AFV8OU0440.pgm.txt /tmp/sub.AFV8OU0440.pgm
# processing file `/tmp/sub.AFV8OU0440.pgm'

# vim:set foldmethod=marker:
