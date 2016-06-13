#!/bin/bash
# For Blackmagic Production 4K DNG files. Converts to Prores, in the current directory
# The camera stores the files with this file naming:
#   Reel/BMPC4KNC_1_2016-05-23_0248_C0000/BMPC4KNC_1_2016-05-23_0248_C0000_######.dng
# This script assumes they are in a format like that 

# There is only one command line argument - the directory that the camera creates for the shots ('reel').
if [ "$1" == "" ]
then
    echo "$0: Usage: dng2prores <path to DNG reel directory>. "
    echo "The Prores clips will be written to you current directory. "
    exit 1
fi
if [ ! -d "$1" ]
then
    echo "$0: $1 is not a directory!"
    echo "Enter the path to the reel."
    exit 1
fi


CLEAN_ARG1=${1%/*}

REEL_DIR="$(readlink -f $CLEAN_ARG1)"

TOTAL_SHOTS="$(find $REEL_DIR -iname *.dng -printf "%h\n" | uniq | wc -l)"
if [ $TOTAL_SHOTS -eq 0 ]
then
    echo "No DNG files found there. Exiting"
    exit 1
fi

# The destination of the copy is implied as the current directory. So first, validate
# that the current directory has permissions:

if [ ! -w . ]
then
    echo "Current directory is not writable. Exiting"
    exit 1
fi

# Loop through the reel and process each shot one at a time
SHOT_COUNTER=1
for SHOT_DIR in $(find $REEL_DIR -name *.dng -printf "%h\n" | uniq)
do
    echo "Shot "$SHOT_COUNTER" of "$TOTAL_SHOTS
    
    SHOT="$(basename $SHOT_DIR)"
    # Verify enough free space
    DNG_SIZE="$(du -s $SHOT_DIR | awk '{print $1}')"
    FREE_SPACE="$(df . | tail -1 | awk '{print $4}')"
    SPACE_NEEDED="$(($DNG_SIZE * 2))"
    
    if [ $SPACE_NEEDED -gt $FREE_SPACE ]
    then
        read -p  "Not much space left on disk. Continue anyway? " -n 1 -r
        echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]
      then
        exit 1
      fi
    fi
    TEMPY="$(mktemp -d)"    
    # Convert each dng file to ppm
    find $SHOT_DIR -iname *.dng | parallel --no-notice --bar "dcraw -h -c {} > $TEMPY/{/.}.ppm" # -h means half size

    echo "Writing "$(pwd)/$SHOT.mov
    # Build the ppms into a prores proxy file:
    # -profile flag values:
    #     0 = Prores Proxy
    #     1 = Prores LT
    #     2 = Prores 422
    #     4 = Prores HQ
    # -r frame rate
    ffmpeg -r 30 -i $TEMPY/$SHOT"_00%04d.ppm" -i $SHOT_DIR/$SHOT.wav  -vcodec prores -profile:v 0 -acodec pcm_s16le ./$SHOT.mov

    rm $TEMPY/*
    ((SHOT_COUNTER++))
    echo
done

echo "Finished making Prores clips from "$REEL_DIR
