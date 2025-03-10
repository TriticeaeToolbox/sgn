#! /usr/bin/env bash

#
# REMOVE OLD TEMP FILES FROM THE TEMP DIRECTORY
# This script will remove any files older than the set number of days
# from the temp directory (defined as cluster_shared_tempdir in sgn_local.conf)
#
# Arguments:
#   first = the number of days as the max age of the temp files (7 by default)
#

MAX_AGE_DAYS=${1:-7}
SGN_LOCAL_CONF="/home/production/cxgn/sgn/sgn_local.conf"
SGN_CONF="/home/production/cxgn/sgn/sgn.conf"
TMP_DIR=""

# Get the shared temp directory from the .conf file(s)
if [ -e "$SGN_LOCAL_CONF" ]; then
  echo "--> getting tmp directory from $SGN_LOCAL_CONF..."
  conf=$(cat "$SGN_LOCAL_CONF" | grep cluster_shared_tempdir)
  parts=($conf)
  TMP_DIR=${parts[1]}
fi
if [ -z $TMP_DIR ] && [ -e "$SGN_CONF" ]; then
  echo "--> getting tmp directory from $SGN_CONF..."
  conf=$(cat "$SGN_CONF" | grep cluster_shared_tempdir)
  parts=($conf)
  TMP_DIR=${parts[1]}
fi

# Make sure tmp directory is defined
if [ -z "$TMP_DIR" ]; then
  echo "ERROR: Temp directory is not defined in the .conf files!"
  exit 1
fi

# Make sure tmp directory exists
if [ ! -d "$TMP_DIR" ]; then
  echo "ERROR: Temp directory $TMP_DIR does not exist!"
  exit 1
fi

# Find old files in tmp directory
echo "--> finding temp files older than $MAX_AGE_DAYS days in $TMP_DIR..."
files=$(find "$TMP_DIR" -mtime +$MAX_AGE_DAYS -type f -ls)

echo "$files" | while read line; do
  filename=$(echo "$line" | awk '{print $NF}')
  if [ ! -z "$filename" ] && [ -e "$filename" ]; then
    base=$(basename $filename)
    if [[ "$base" != git_* ]]; then
      echo "--> removing $filename"
      rm "$filename"
    fi
  fi
done
