#!/bin/bash

check_command "rsync"

function bamboo_perform_rsync {
    for exclude in ${BAMBOO_BACKUP_EXCLUDE}; do
      RSYNC_EXCLUDE="${RSYNC_EXCLUDE} --exclude=${exclude}"
    done

    RSYNC_QUIET=-q
    if [ "${BAMBOO_VERBOSE_BACKUP}" == "TRUE" ]; then
        RSYNC_QUIET=
    fi

    mkdir -p ${BAMBOO_BACKUP_HOME}
    rsync -avh ${RSYNC_QUIET} --numeric-ids --sparse \
        --delete --delete-excluded \
        --exclude=temp --exclude=exports \
        --exclude=build-dir --exclude=build_logs --exclude=artifacts \
        ${RSYNC_EXCLUDE} \
        ${BAMBOO_HOME} ${BAMBOO_BACKUP_HOME}
    if [ $? != 0 ]; then
        bail "Unable to rsync from ${BAMBOO_HOME} to ${BAMBOO_BACKUP_HOME}"
    fi
}

function bamboo_prepare_home {
    bamboo_perform_rsync
    info "Prepared backup of ${BAMBOO_HOME} to ${BAMBOO_BACKUP_HOME}"
}

function bamboo_backup_home {
    bamboo_perform_rsync
    info "Performed backup of ${BAMBOO_HOME} to ${BAMBOO_BACKUP_HOME}"
}

function bamboo_restore_home {
    RSYNC_QUIET=-q
    if [ "${BAMBOO_VERBOSE_BACKUP}" == "TRUE" ]; then
        RSYNC_QUIET=
    fi

    rsync -av ${RSYNC_QUIET} ${BAMBOO_RESTORE_HOME}/ ${BAMBOO_HOME}/
    info "Performed restore of ${BAMBOO_RESTORE_HOME} to ${BAMBOO_HOME}"
}
