#!/bin/bash
# For Blackmagic Production 4K DNG files. Converts to Prores, in the current directory
# The camera stores the files with this file naming:
#   Reel/BMPC4KNC_1_2016-05-23_0248_C0000/BMPC4KNC_1_2016-05-23_0248_C0000_######.dng
# This script assumes they are in a format much like that

# There is only one command line argument - the directory that the camera creates for the shot.
# (in next version, this needs to be the parent directory ('reel').
if [ "$1" == "" ]; then
    echo
    echo "$0: Enter the name of the DNG shot directory."
    echo
    exit 1
fi
if [ ! -d "$1" ]; then
    echo
    echo "$0: $1 is not a directory! Enter the name of the directory with the shot in it."
    echo
    exit 1
fi

# The destination of the copy is implied as the current directory. So first, validate
# that the current directory has permissions and enough space:

# permissions
if [ -w . ]
then
    echo
    echo "Prores clips will be written to " $(pwd)
    echo
else
    echo
    echo "Current directory is not writable. Exiting"
    echo
    exit
fi

SHOT=${1%/}

# free space
DNG_SIZE="$(du -s $SHOT | awk '{print $1}')"
FREE_SPACE="$(df . | tail -1 | awk '{print $4}')"
SPACE_NEEDED="$(($DNG_SIZE * 2000))"

if [ $SPACE_NEEDED -gt $FREE_SPACE ]
then
    read -p  "Not much space left on disk. Continue anyway? " -n 1 -r
    echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]
  then
    exit 1
  fi
fi

# Convert from CinemaDNG to ppm:
TEMPY="$(mktemp -d)"
mkdir $TEMPY/"$1"
ls $SHOT/*.dng | parallel --no-notice --bar "dcraw -c {} > $TEMPY/{.}.ppm"

# Build the ppms into a prores proxy file:
# -profile flag values:
#     0 = Prores Proxy
#     1 = Prores LT
#     2 = Prores 422
#     4 = Prores HQ
ffmpeg -i $TEMPY/$SHOT/$SHOT"_00%04d.ppm" -c:v prores -profile:v 0 -c:a pcm_s16le ./$SHOT.mov
#rm $TEMPY/$SHOT/*

# Try to do some kind of checksums or at least count the number of frames
