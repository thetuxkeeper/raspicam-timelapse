#!/bin/bash

# config parameters
. `dirname $0`/sync.conf || { echo "Error loading config file" >&2; exit 1; }

# default sync function
sync_directory() {
    # sync
    $SYNC_COMMAND $OPTS $OPTS_DIR $ROOT_DIR/ $SYNC_DEST
}

sync_file() {
    # change to directory so we can sync with relative path (--relative parameter of rsync)
    cd "$ROOT_DIR"
    # sync
    $SYNC_COMMAND $OPTS $OPTS_FILE $FILE $SYNC_DEST
}

# overwrite sync function with own implementation
. `dirname $0`/sync.inc.sh || true

# if used with inotify 
## first parameter is the watched directory
## the second the relative path to the file
# if used as batch cronjob
## first parameter is the directory to sync recursively
# strip trailing slashes
ROOT_DIR=`realpath "$1"`
FILE="$2"

if [ $# -eq 1 ] && [ -d "$ROOT_DIR" ]
then
    sync_directory
elif [ $# -eq 2 ] && [ -e "$ROOT_DIR"/"$FILE" ]
then
    sync_file
fi