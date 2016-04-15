#!/bin/bash

check_command "rsync"

function bamboo_perform_rsync {
    for repo_id in ${BAMBOO_BACKUP_EXCLUDE_REPOS[@]}; do
      RSYNC_EXCLUDE_REPOS="${RSYNC_EXCLUDE_REPOS} --exclude=/shared/data/repositories/${repo_id}"
    done

    RSYNC_QUIET=-q
    if [ "${BAMBOO_VERBOSE_BACKUP}" == "TRUE" ]; then
        RSYNC_QUIET=
    fi

    mkdir -p ${BAMBOO_BACKUP_HOME}
    rsync -avh ${RSYNC_QUIET} --delete --delete-excluded --exclude=/caches/ --exclude=/shared/data/db.* --exclude=/shared/search/data/ --exclude=/export/ --exclude=/log/ --exclude=/plugins/.*/ --exclude=/tmp --exclude=/.lock --exclude=/shared/.lock ${RSYNC_EXCLUDE_REPOS} ${BAMBOO_HOME} ${BAMBOO_BACKUP_HOME}
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
