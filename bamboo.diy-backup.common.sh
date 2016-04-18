#!/bin/bash

check_command "curl"
check_command "jq"

BAMBOO_HTTP_AUTH="-u ${BAMBOO_BACKUP_USER}:${BAMBOO_BACKUP_PASS}"

: ${BAMBOO_PAUSE_WAIT_TIMEOUT:=20}

# The name of the product
PRODUCT=Bamboo

function bamboo_pause {
    curl ${CURL_OPTIONS} ${BAMBOO_HTTP_AUTH} -X POST -H "Accept:application/json" -H "Content-type: application/json" "${BAMBOO_URL}/rest/api/latest/server/pause?os_authType=basic"
    if [ $? != 0 ]; then
        bail "Pausing this ${PRODUCT} instance failed"
    fi

    # Check the server status to see if its been paused
    # Expected result {"state":"PAUSED","reindexInProgress":false}
    BAMBOO_STATUS_RESULT=$(curl ${CURL_OPTIONS} ${BAMBOO_HTTP_AUTH} -X POST -H "Accept:application/json" -H "Content-type: application/json" "${BAMBOO_URL}/rest/api/latest/server?os_authType=basic")

    local wait_till=$(( $(date +%s) + "${BAMBOO_PAUSE_WAIT_TIMEOUT}" ))
    while [ -z "${BAMBOO_STATUS_RESULT}" ] || \
        [ "$(echo ${BAMBOO_STATUS_RESULT} | jq -r ".state" | tr -d '\r')" != 'PAUSED' ] || \
        [ "$(echo ${BAMBOO_STATUS_RESULT} | jq -r ".reindexInProgress" | tr -d '\r')" != 'false' ];
    do
        if [ "$(date +%s)" -gt "${wait_till}" ]; then
            bail "Unable to pause ${PRODUCT} instance. Result was '$BAMBOO_STATUS_RESULT'"
        fi
        sleep 2;
        info "Waiting for ${PRODUCT} instance to pause..."
    done

    info "${PRODUCT} instance paused"
}

function bamboo_resume {
    curl ${CURL_OPTIONS} ${BAMBOO_HTTP_AUTH} -X POST -H "Accept:application/json" -H "Content-type: application/json" "${BAMBOO_URL}/rest/api/latest/server/resume?os_authType=basic"
    if [ $? != 0 ]; then
        bail "Unable to resume ${PRODUCT} instance"
    fi

    info "${PRODUCT} instance resume"
}

function freeze_mount_point {
    info "Freezing filesystem at mount point ${1}"

    sudo fsfreeze -f ${1} > /dev/null
}

function unfreeze_mount_point {
    info "Unfreezing filesystem at mount point ${1}"

    sudo fsfreeze -u ${1} > /dev/null 2>&1
}

function mount_device {
    local DEVICE_NAME="$1"
    local MOUNT_POINT="$2"

    sudo mount "${DEVICE_NAME}" "${MOUNT_POINT}" > /dev/null
    success "Mounted device ${DEVICE_NAME} to ${MOUNT_POINT}"
}

function add_cleanup_routine() {
    cleanup_queue+=($1)
    trap run_cleanup EXIT
}

function run_cleanup() {
    info "Cleaning up..."
    for cleanup in ${cleanup_queue[@]}
    do
        ${cleanup}
    done
}

function check_mount_point {
    local MOUNT_POINT="${1}"

    # mountpoint check will return a non-zero exit code when mount point is free
    mountpoint -q "${MOUNT_POINT}"
    if [ $? == 0 ]; then
        error "The directory mount point ${MOUNT_POINT} appears to be taken"
        bail "Please stop ${PRODUCT}. Stop PostgreSQL if it is running. Unmount the device and detach the volume"
    fi
}

# This removes config.lock, index.lock, gc.pid, and refs/heads/*.lock
function cleanup_locks {
    local HOME_DIRECTORY="$1"

    # From the shopt man page:
    # globstar
    #           If set, the pattern ‘**’ used in a filename expansion context will match all files and zero or
    #           more directories and subdirectories. If the pattern is followed by a ‘/’, only directories and subdirectories match.
    # shopt -s globstar

    # Remove lock files in the repositories
    # sudo -u ${BAMBOO_UID} rm -f ${HOME_DIRECTORY}/shared/data/repositories/*/{HEAD,config,index,gc,packed-refs,stash-packed-refs}.{pid,lock}
    # sudo -u ${BAMBOO_UID} rm -f ${HOME_DIRECTORY}/shared/data/repositories/*/refs/**/*.lock
    # sudo -u ${BAMBOO_UID} rm -f ${HOME_DIRECTORY}/shared/data/repositories/*/stash-refs/**/*.lock
    # sudo -u ${BAMBOO_UID} rm -f ${HOME_DIRECTORY}/shared/data/repositories/*/logs/**/*.lock
}
