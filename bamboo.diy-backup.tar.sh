#!/bin/bash

check_command "tar"

function bamboo_backup_archive {
    mkdir -p ${BAMBOO_BACKUP_ARCHIVE_ROOT}
    BAMBOO_BACKUP_ARCHIVE_NAME=$(perl -we 'use Time::Piece; my $sydTime = localtime; print "bamboo-", $sydTime->strftime("%Y%m%d-%H%M%S-"), substr($sydTime->epoch, -3), ".tar.gz"')

    info "Archiving ${BAMBOO_BACKUP_ROOT} into ${BAMBOO_BACKUP_ARCHIVE_ROOT}/${BAMBOO_BACKUP_ARCHIVE_NAME}"
    tar -czf ${BAMBOO_BACKUP_ARCHIVE_ROOT}/${BAMBOO_BACKUP_ARCHIVE_NAME} -C ${BAMBOO_BACKUP_ROOT} .
    info "Archived ${BAMBOO_BACKUP_ROOT} into ${BAMBOO_BACKUP_ARCHIVE_ROOT}/${BAMBOO_BACKUP_ARCHIVE_NAME}"
}

function bamboo_restore_archive {
    if [ -f ${BAMBOO_BACKUP_ARCHIVE_NAME} ]; then
        BAMBOO_BACKUP_ARCHIVE_NAME=${BAMBOO_BACKUP_ARCHIVE_NAME}
    else
        BAMBOO_BACKUP_ARCHIVE_NAME=${BAMBOO_BACKUP_ARCHIVE_ROOT}/${BAMBOO_BACKUP_ARCHIVE_NAME}
    fi
    tar -xzf ${BAMBOO_BACKUP_ARCHIVE_NAME} -C ${BAMBOO_RESTORE_ROOT}

    info "Extracted ${BAMBOO_BACKUP_ARCHIVE_NAME} into ${BAMBOO_RESTORE_ROOT}"
}
