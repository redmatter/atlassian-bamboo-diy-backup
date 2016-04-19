#!/bin/bash

check_command "tar"
check_command "gpg-zip"

function bamboo_backup_archive {
    if [[ -z ${BAMBOO_BACKUP_GPG_RECIPIENT} ]]; then
        bail "In order to encrypt the backup you must set the 'BAMBOO_BACKUP_GPG_RECIPIENT' configuration variable. Exiting..."
    fi
    mkdir -p ${BAMBOO_BACKUP_ARCHIVE_ROOT}
    BAMBOO_BACKUP_ARCHIVE_NAME=$(perl -we 'use Time::Piece; my $sydTime = localtime; print "bamboo-", $sydTime->strftime("%Y%m%d-%H%M%S-"), substr($sydTime->epoch, -3), ".tar.gz.gpg"')

    info "Archiving ${BAMBOO_BACKUP_ROOT} into ${BAMBOO_BACKUP_ARCHIVE_ROOT}/${BAMBOO_BACKUP_ARCHIVE_NAME}"
    info "Encrypting for ${BAMBOO_BACKUP_GPG_RECIPIENT}"
    (
        # in a subshell to avoid changing working dir on the caller
        cd ${BAMBOO_BACKUP_ROOT}
        gpg-zip --encrypt --recipient ${BAMBOO_BACKUP_GPG_RECIPIENT} \
            --output ${BAMBOO_BACKUP_ARCHIVE_ROOT}/${BAMBOO_BACKUP_ARCHIVE_NAME} .
    )
    info "Archived ${BAMBOO_BACKUP_ROOT} into ${BAMBOO_BACKUP_ARCHIVE_ROOT}/${BAMBOO_BACKUP_ARCHIVE_NAME}"
}

function bamboo_restore_archive {
    if [ -f ${BAMBOO_BACKUP_ARCHIVE_NAME} ]; then
        BAMBOO_BACKUP_ARCHIVE_NAME=${BAMBOO_BACKUP_ARCHIVE_NAME}
    else
        BAMBOO_BACKUP_ARCHIVE_NAME=${BAMBOO_BACKUP_ARCHIVE_ROOT}/${BAMBOO_BACKUP_ARCHIVE_NAME}
    fi
    gpg-zip --tar-args "-C ${BAMBOO_RESTORE_ROOT}" --decrypt ${BAMBOO_BACKUP_ARCHIVE_NAME}

    info "Extracted ${BAMBOO_BACKUP_ARCHIVE_NAME} into ${BAMBOO_RESTORE_ROOT}"
}
