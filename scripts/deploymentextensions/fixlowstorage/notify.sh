#!/bin/bash

# Copyright (c) Microsoft Corporation. All Rights Reserved.
# Licensed under the MIT license. See LICENSE file on the project webpage for details.

set -x

# Settings
    usage_threshold_percent=33 # Default to a third of the disk.

# Paths and file names.
    current_script_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    script_name=`basename "$0"`

check_usage_threshold()
{
    # List of <usage>%<path>
    # for example:
    #   "4%/"
    #   "1%/datadisks/disk1"
    diskUsages=`df --output=ipcent,target | grep -v -i "use%\|mounted on" | tr -d ' '`

    # Iterate over list of <usage>%<path> pairs.
    while read diskUsage ; do
        # Split usage and path
        diskUsageArray=(`echo "$diskUsage" | tr '%' ' '`)
        percentUsed=${diskUsageArray[0]}
        directoryPath=${diskUsageArray[1]}

        log "Directory $directoryPath on machine $HOSTNAME is using $percentUsed percent of available space"

        # Alert for unexpected values (indicative of possible errors in script and/or unexpected cases)
        if [[ -n ${diskUsageArray[2]} ]] ; then
            log "Error in script $script_name. Too many values"
            log "Extraneous value: ${diskUsageArray[2]}"

            continue
        fi
        if [[ -z $percentUsed ]] || [[ -z $directoryPath ]] ; then
            log "Error in script $script_name. Missing disk usage percentage or file system path"

            continue
        fi

        # Alert when threshold is exceeded.
        if (( $(echo "$percentUsed > $usage_threshold_percent" | bc -l) )) ; then

            # Help clarify messaging by appending trailing slash to directory.
            if [[ $directoryPath != '/' ]] ; then
                directoryPath="${directoryPath}/"
            fi

            # Message
            
            log "Please cleanup this directory at your earliest convenience."
            log "The top subfolders or subfiles in $directoryPath are:"
            # Get list of subitems and filesize, sort them, grab top five, indent, newline.
            printf "`du -sh $directoryPath* 2> /dev/null | sort -h -r | head -n 5 | sed -e 's/^/  /'`"
            echo

        fi

        # Newline between exections
        echo

    done <<< "$diskUsages"
}

###############################################
# START CORE EXECUTION
###############################################

log "Checking for low disk space"

# Update working directory
pushd $current_script_path

# Parse commandline argument, source utilities. Exit on failure.
source sharedOperations.sh || exit 1

# Rotate log (if machine support it). Exit on failure.
source rotateLog.sh || exit 1

# Pre-conditionals
exit_if_limited_user

check_usage_threshold

# Restore working directory
popd