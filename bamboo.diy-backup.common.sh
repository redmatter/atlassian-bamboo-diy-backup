#!/bin/bash

check_command "curl"
check_command "jq"

BAMBOO_HTTP_AUTH="-u ${BAMBOO_BACKUP_USER}:${BAMBOO_BACKUP_PASS}"

# The name of the product
PRODUCT=Bamboo

function bamboo_lock {
    BAMBOO_LOCK_RESULT=$(curl ${CURL_OPTIONS} ${BAMBOO_HTTP_AUTH} -X POST -H "Content-type: application/json" "${BAMBOO_URL}/mvc/maintenance/lock")
    if [ -z "${BAMBOO_LOCK_RESULT}" ]; then
        bail "Locking this ${PRODUCT} instance failed"
    fi

    BAMBOO_LOCK_TOKEN=$(echo ${BAMBOO_LOCK_RESULT} | jq -r ".unlockToken" | tr -d '\r')
    if [ -z "${BAMBOO_LOCK_TOKEN}" ]; then
        bail "Unable to find lock token. Result was '$BAMBOO_LOCK_RESULT'"
    fi

    info "locked with '$BAMBOO_LOCK_TOKEN'"
}

function bamboo_unlock {
    BAMBOO_UNLOCK_RESULT=$(curl ${CURL_OPTIONS} ${BAMBOO_HTTP_AUTH} -X DELETE -H "Accept: application/json" -H "Content-type: application/json" "${BAMBOO_URL}/mvc/maintenance/lock?token=${BAMBOO_LOCK_TOKEN}")
    if [ $? != 0 ]; then
        bail "Unable to unlock instance with lock ${BAMBOO_LOCK_TOKEN}"
    fi

    info "${PRODUCT} instance unlocked"
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
    shopt -s globstar

    # Remove lock files in the repositories
    sudo -u ${BAMBOO_UID} rm -f ${HOME_DIRECTORY}/shared/data/repositories/*/{HEAD,config,index,gc,packed-refs,stash-packed-refs}.{pid,lock}
    sudo -u ${BAMBOO_UID} rm -f ${HOME_DIRECTORY}/shared/data/repositories/*/refs/**/*.lock
    sudo -u ${BAMBOO_UID} rm -f ${HOME_DIRECTORY}/shared/data/repositories/*/stash-refs/**/*.lock
    sudo -u ${BAMBOO_UID} rm -f ${HOME_DIRECTORY}/shared/data/repositories/*/logs/**/*.lock
}
