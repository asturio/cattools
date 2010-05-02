#!/bin/bash

# Global Variables
DIRS="/usr/share/pixmaps/backgrounds/ /usr/share/backgrounds/ /usr/share/xfce4/backdrops/"
TOTAL=0
VERBOSE=0

if [ -f $HOME/.set-backgroundrc ] 
then
    [ $VERBOSE -eq 1 ] && echo "Readong more dirs."
    source $HOME/.set-backgroundrc
fi

set_desktop_cmd() {
    ps -ef | grep ${USER} | while read line
    do
        case $line in
        *xfwm*)
            [ $VERBOSE -eq 1 ] && echo "I:Running xfce" 1>&2
            echo "xfdesktop --reload"
            return
            ;;
        *icewm-session*)
            [ $VERBOSE -eq 1 ] && echo "I:Running icewm" 1>&2
            echo "icewmbg -r"
            return
            ;;
        *gnome-session*)
            [ $VERBOSE -eq 1 ] && echo "I:Running gnome" 1>&2
            echo "gconftool -t string -s /desktop/gnome/background/picture_filename $WALLPAPER"
            return
            ;;
        *)
            continue
            ;;
        esac
    done
}

function usage {
cat << EOF
    $0 <option>:
    --all       Include from all images
    -a

    --verbose   Be verbose
    -v

    --adult     Include only adult images
    -A
EOF
}

args=`getopt -n set-background.sh -o avA -l all,verbose,adult -- "$@"`
if [ $? -ne 0 ]
then
    usage
    exit 1
fi
eval set -- $args

for opt in $@
do
    case $opt in
        # Add all directories
        -a|--all)
            DIRS="$DIRS $ADULT"
            ;;
        -A|--adult)
            DIRS=$ADULT
            ;;
        -v|--verbose)
            VERBOSE=1
            ;;
    esac
done


# Check which directories are there
for D in $DIRS
do
    [ -d "$D" ] && DIR="$DIR $D"
done
[ $VERBOSE -eq 1 ] && echo "I: dirs='$DIR'"

# Count all Images in the directories 
for f in `find $DIR -name "*.jpg" -o -name "*.png"`
do
    let TOTAL+=1
done

# Select a random one
NUMBER=$RANDOM
let NUMBER%=TOTAL

# Now find that file
CURRENT=0
for f in `find $DIR -name "*.jpg" -o -name "*.png"`
do
    if [ $CURRENT -eq $NUMBER ]
    then
	WALLPAPER=$f
        break
    fi
    let CURRENT+=1
done

# Link wallpaper to standard file
ln -snf $WALLPAPER $HOME/.background.link

[ $VERBOSE -eq 1 ] && echo "I:$WALLPAPER: $NUMBER of $TOTAL"

DESKTOPCMD=`set_desktop_cmd`

if [ "$DESKTOPCMD" ]
then
    [ $VERBOSE -eq 1 ] && echo "I:$DESKTOPCMD"
    $DESKTOPCMD 2> /dev/null
fi
